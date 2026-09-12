#include "sa_legacy_bridge.h"

#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/variant.hpp>

#include "app/platform/linux/NativeAssetIdentity.h"
#include "app/platform/linux/NativeLodCatalog.h"
#include "app/platform/linux/StreamPager.h"
#include "app/platform/linux/TimeCycle.h"
#include "sa_region_plan.h"

#include <algorithm>
#include <array>
#include <bit>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <limits>
#include <map>
#include <mutex>
#include <string>
#include <tuple>
#include <type_traits>
#include <vector>

namespace godot {
namespace {

constexpr float kMinRadius = 1.0f;
constexpr float kMaxRadius = 2000.0f;
constexpr int32_t kMaxInstances = 4096;
constexpr int64_t kDefaultBudgetItems = 64;
constexpr int64_t kMinBudgetItems = 1;
constexpr int64_t kMaxBudgetItems = 4096;
constexpr std::array<int, 9> kSampleHours{0, 5, 6, 7, 12, 19, 20, 22, 24};

// P1-A04 frozen single-chain profile: explicit bounded real encounter, never
// invented positions/COL. Actual catalog + COL prove the rest at OpenGame.
constexpr int kFrozenChildModel = 3991;
constexpr int kFrozenParentModel = 4043;
constexpr uint32_t kFrozenChildRecord = 0;
constexpr uint32_t kFrozenParentRecord = 24;
constexpr size_t kFrozenChildLocal = 0;
constexpr size_t kFrozenParentLocal = 24;

std::mutex s_PagerMutex;
SALegacyBridge* s_PagerOwner = nullptr;

bool IsMainThread() {
    const OS* os = OS::get_singleton();
    return os && os->get_thread_caller_id() == os->get_main_thread_id();
}

Dictionary Result(bool ok, const String& error = String()) {
    Dictionary result;
    result["ok"] = ok;
    result["error"] = error;
    return result;
}

String ErrorString(const char* error) {
    return String::utf8(error ? error : "unknown bridge error");
}

std::string Utf8(const String& value) {
    const CharString utf8 = value.utf8();
    return std::string(utf8.get_data(), static_cast<size_t>(utf8.length()));
}

bool Finite(float value) {
    return std::isfinite(value);
}

double SteadyMs() {
    return std::chrono::duration<double, std::milli>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}

String SourceString(const std::string& value) {
    return String::utf8(value.data(), static_cast<int64_t>(value.size()));
}

Dictionary ArchiveMemberIdentity(const NativeAssetIdentity::ArchiveMember& source) {
    Dictionary identity;
    identity["archive"] = SourceString(source.archive);
    identity["member"] = SourceString(source.member);
    return identity;
}

Dictionary ModelIdentity(const WorldShotMesh& source) {
    NativeAssetIdentity::ArchiveMember dff{
        source.sourceArchiveName,
        source.sourceModelName + ".dff",
    };
    Dictionary identity;
    identity["dff"] = ArchiveMemberIdentity(dff);
    identity["model_id"] = source.sourceModelId;
    return identity;
}

Dictionary GeometryIdentity(const WorldShotMesh& source, const WorldShotSurface& surface) {
    Dictionary identity;
    identity["model"] = ModelIdentity(source);
    identity["index"] = surface.sourceGeometry;
    return identity;
}

Dictionary MaterialIdentity(const WorldShotMesh& source, const WorldShotSurface& surface) {
    Dictionary identity;
    identity["geometry"] = GeometryIdentity(source, surface);
    identity["slot"] = surface.sourceMaterial;
    return identity;
}

Dictionary TextureIdentity(const WorldShotImage& source) {
    Array lineage;
    for (const auto& member : source.sourceIdentity.lineage) {
        lineage.push_back(ArchiveMemberIdentity(member));
    }
    Dictionary identity;
    identity["lineage"] = lineage;
    identity["owner"] = ArchiveMemberIdentity(source.sourceIdentity.owner);
    identity["name"] = SourceString(source.sourceIdentity.name);
    identity["filter"] = static_cast<int64_t>(source.sourceIdentity.filter);
    return identity;
}

const char* NonfiniteName(float value) {
    if (std::isnan(value)) {
        return "nan";
    }
    return std::signbit(value) ? "-inf" : "+inf";
}

// P1-A06: typed plan failures carry indices/reason; main rebuilds the exact
// former structured failure (nonfinite_uv etc) without parsing strings.
void BuildPlanFailurePayload(const WorldShotScene& scene, const RegionPlanFailure& failure,
                             String& error, String& errorCode, Dictionary& errorContext) {
    errorContext = Dictionary();
    errorCode = String();
    const auto meshOk = failure.meshIndex < scene.meshes.size();
    switch (failure.kind) {
    case RegionPlanFailure::Kind::NoMeshes:
        error = "pager returned no meshes";
        return;
    case RegionPlanFailure::Kind::TooManyImages:
        error = "pager returned too many images";
        return;
    case RegionPlanFailure::Kind::BadImageDimensions:
        error = "decoded texture dimensions are out of range";
        return;
    case RegionPlanFailure::Kind::BadImageBytes:
        error = "decoded texture byte size is invalid";
        return;
    case RegionPlanFailure::Kind::ImageBytesLimit:
        error = "decoded texture publication exceeds the size limit";
        return;
    case RegionPlanFailure::Kind::EmptyMesh:
        error = "pager returned a mesh with no triangles";
        return;
    case RegionPlanFailure::Kind::TriangleLimit:
        error = "pager scene exceeds the triangle limit";
        return;
    case RegionPlanFailure::Kind::AttributeMismatch:
        error = "pager mesh attribute sizes are inconsistent";
        return;
    case RegionPlanFailure::Kind::BadPosition:
        error = "pager position is nonfinite or out of range";
        return;
    case RegionPlanFailure::Kind::BadNormal:
        error = "pager normal is nonfinite or out of range";
        return;
    case RegionPlanFailure::Kind::NonfiniteUv: {
        if (!meshOk) {
            error = "pager returned nonfinite UV for model ''";
            errorCode = "nonfinite_uv";
            return;
        }
        const auto& mesh = scene.meshes[failure.meshIndex];
        const size_t triangle = failure.uvIndex / 6;
        const size_t safeTriangle =
            triangle < mesh.surfaces.size() ? triangle : 0;
        const auto& surface = mesh.surfaces[safeTriangle];
        const String model = SourceString(mesh.sourceModelName);
        error = String("pager returned nonfinite UV for model '") + model +
            "' (id " + String::num_int64(mesh.sourceModelId) + ")";
        errorCode = "nonfinite_uv";
        errorContext["archive"] = SourceString(mesh.sourceArchiveName);
        errorContext["model"] = model;
        errorContext["model_id"] = mesh.sourceModelId;
        errorContext["txd"] = SourceString(mesh.sourceTxdName);
        errorContext["placement_id"] = static_cast<int64_t>(mesh.sourcePlacementId);
        errorContext["geometry"] = surface.sourceGeometry;
        errorContext["triangle"] = surface.sourceTriangle;
        errorContext["material_slot"] = surface.sourceMaterial;
        errorContext["uv_component"] = (failure.uvIndex % 2 == 0) ? "u" : "v";
        errorContext["value"] = NonfiniteName(failure.badValue);
        return;
    }
    case RegionPlanFailure::Kind::BadMaterialColor:
        error = "pager material color is outside [0,1]";
        return;
    case RegionPlanFailure::Kind::BadImageIndex: {
        if (!meshOk) {
            error = "pager material references an invalid image";
            errorCode = "invalid_image_index";
            return;
        }
        const auto& mesh = scene.meshes[failure.meshIndex];
        const size_t safeTriangle =
            failure.triangle < mesh.surfaces.size() ? failure.triangle : 0;
        errorCode = failure.missingTexture ? "missing_texture" : "invalid_image_index";
        error = String("pager material references an invalid image for model '") +
            SourceString(mesh.sourceModelName) + "' txd '" + SourceString(mesh.sourceTxdName) +
            "' triangle " + String::num_int64(mesh.surfaces[safeTriangle].sourceTriangle);
        errorContext["model"] = SourceString(mesh.sourceModelName);
        errorContext["model_id"] = mesh.sourceModelId;
        errorContext["txd"] = SourceString(mesh.sourceTxdName);
        errorContext["archive"] = SourceString(mesh.sourceArchiveName);
        errorContext["geometry"] = mesh.surfaces[safeTriangle].sourceGeometry;
        errorContext["triangle"] = mesh.surfaces[safeTriangle].sourceTriangle;
        errorContext["material_slot"] = mesh.surfaces[safeTriangle].sourceMaterial;
        errorContext["placement_id"] = static_cast<int64_t>(mesh.sourcePlacementId);
        return;
    }
    case RegionPlanFailure::Kind::BadTextureIdentity: {
        if (!meshOk) {
            error = "pager returned invalid texture identity";
            errorCode = "invalid_texture_identity";
            return;
        }
        const auto& mesh = scene.meshes[failure.meshIndex];
        const size_t safeTriangle =
            failure.triangle < mesh.surfaces.size() ? failure.triangle : 0;
        const auto& surface = mesh.surfaces[safeTriangle];
        const char* reason =
            failure.reason.empty() ? "invalid" : failure.reason.c_str();
        error = String("pager returned invalid texture identity for model '") +
            SourceString(mesh.sourceModelName) + "' (id " + String::num_int64(mesh.sourceModelId) +
            "), image " + String::num_int64(failure.imageIndex) + ": " + reason;
        errorCode = "invalid_texture_identity";
        errorContext["archive"] = SourceString(mesh.sourceArchiveName);
        errorContext["model"] = SourceString(mesh.sourceModelName);
        errorContext["model_id"] = mesh.sourceModelId;
        errorContext["txd"] = SourceString(mesh.sourceTxdName);
        errorContext["placement_id"] = static_cast<int64_t>(mesh.sourcePlacementId);
        errorContext["geometry"] = surface.sourceGeometry;
        errorContext["triangle"] = surface.sourceTriangle;
        errorContext["material_slot"] = surface.sourceMaterial;
        errorContext["image_index"] = failure.imageIndex;
        errorContext["reason"] = reason;
        if (failure.imageIndex >= 0 &&
            static_cast<size_t>(failure.imageIndex) < scene.images.size()) {
            const auto& image = scene.images[static_cast<size_t>(failure.imageIndex)];
            if (image.hasSourceIdentity) {
                errorContext["texture_identity"] = TextureIdentity(image);
            }
        }
        return;
    }
    case RegionPlanFailure::Kind::BadSurfaceValues:
        error = "pager surface values are nonfinite or out of range";
        return;
    case RegionPlanFailure::Kind::None:
        error = "pager scene validation failed";
        return;
    }
    error = "pager scene validation failed";
}

// (P1-A06: former per-pixel/per-triangle validation now lives in sa_region_plan.)

Ref<ImageTexture> MakeTexture(const WorldShotImage& source) {
    PackedByteArray bytes;
    bytes.resize(static_cast<int64_t>(source.rgba.size()));
    std::memcpy(bytes.ptrw(), source.rgba.data(), source.rgba.size());
    const Ref<Image> image = Image::create_from_data(source.w, source.h, false, Image::FORMAT_RGBA8, bytes);
    if (image.is_null() || image->is_empty()) {
        return {};
    }
    return ImageTexture::create_from_image(image);
}

// P1-A06: main only copies prepacked CPU floats into Godot Packed arrays and
// issues one add_surface_from_arrays per surface unit. No pixel/triangle
// attribute rescans here; validation/classification/grouping lives in
// sa_region_plan (worker). Bounded outer metadata lookups only.
bool AddPlannedSurface(const WorldShotMesh& source, const RegionPlanSurface& planned,
                       Ref<ArrayMesh>& mesh, Dictionary& material,
                       const std::vector<Ref<ImageTexture>>& textures,
                       const WorldShotScene& scene, String& error) {
    const size_t vertexCount = planned.positions.size() / 3;
    if (planned.positions.size() % 3 != 0 || vertexCount == 0 ||
        vertexCount > static_cast<size_t>(std::numeric_limits<int32_t>::max()) ||
        planned.normals.size() != vertexCount * 3 || planned.uvs.size() != vertexCount * 2 ||
        planned.day.size() != vertexCount * 4 || planned.night.size() != vertexCount * 4) {
        error = "surface vertex count is out of range";
        return false;
    }

    PackedVector3Array positions;
    PackedVector3Array normals;
    PackedVector2Array uvs;
    PackedColorArray dayColors;
    PackedFloat32Array nightColors;
    positions.resize(static_cast<int64_t>(vertexCount));
    normals.resize(static_cast<int64_t>(vertexCount));
    uvs.resize(static_cast<int64_t>(vertexCount));
    dayColors.resize(static_cast<int64_t>(vertexCount));
    nightColors.resize(static_cast<int64_t>(vertexCount * 4));

    // Pinned float32 Godot ABI: the worker already produced these exact
    // layouts. Do not turn one surface into thousands of main-thread API sets.
    static_assert(sizeof(Vector3) == 3 * sizeof(float));
    static_assert(sizeof(Vector2) == 2 * sizeof(float));
    static_assert(sizeof(Color) == 4 * sizeof(float));
    static_assert(std::is_trivially_copyable_v<Vector3> && std::is_standard_layout_v<Vector3>);
    static_assert(std::is_trivially_copyable_v<Vector2> && std::is_standard_layout_v<Vector2>);
    static_assert(std::is_trivially_copyable_v<Color> && std::is_standard_layout_v<Color>);
    auto* positionData = positions.ptrw();
    auto* normalData = normals.ptrw();
    auto* uvData = uvs.ptrw();
    auto* dayData = dayColors.ptrw();
    auto* nightData = nightColors.ptrw();
    if (!positionData || !normalData || !uvData || !dayData || !nightData) {
        error = "Godot could not allocate planned surface buffers";
        return false;
    }
    std::memcpy(static_cast<void*>(positionData), planned.positions.data(), planned.positions.size() * sizeof(float));
    std::memcpy(static_cast<void*>(normalData), planned.normals.data(), planned.normals.size() * sizeof(float));
    std::memcpy(static_cast<void*>(uvData), planned.uvs.data(), planned.uvs.size() * sizeof(float));
    std::memcpy(static_cast<void*>(dayData), planned.day.data(), planned.day.size() * sizeof(float));
    std::memcpy(nightData, planned.night.data(), planned.night.size() * sizeof(float));

    Array arrays;
    arrays.resize(Mesh::ARRAY_MAX);
    arrays[Mesh::ARRAY_VERTEX] = positions;
    arrays[Mesh::ARRAY_NORMAL] = normals;
    arrays[Mesh::ARRAY_COLOR] = dayColors;
    arrays[Mesh::ARRAY_TEX_UV] = uvs;
    arrays[Mesh::ARRAY_CUSTOM0] = nightColors;
    const uint64_t customFlags = static_cast<uint64_t>(Mesh::ARRAY_CUSTOM_RGBA_FLOAT)
        << static_cast<uint64_t>(Mesh::ARRAY_FORMAT_CUSTOM0_SHIFT);
    const int32_t before = mesh->get_surface_count();
    mesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, arrays, TypedArray<Array>(),
                                  Dictionary(), customFlags);
    if (mesh->get_surface_count() != before + 1) {
        error = "Godot rejected an ArrayMesh surface";
        return false;
    }
    const auto publishedFormat = mesh->surface_get_format(before);
    if (!publishedFormat.has_flag(Mesh::ARRAY_FORMAT_TEX_UV)) {
        error = "Godot omitted ArrayMesh UV attributes";
        return false;
    }
    if (publishedFormat.has_flag(Mesh::ARRAY_FLAG_COMPRESS_ATTRIBUTES)) {
        error = "Godot compressed ArrayMesh attributes; finite source UVs cannot be preserved";
        return false;
    }

    // Bounded single-representative metadata lookup (no attribute rescan).
    const size_t triangle = planned.representativeTriangle;
    const auto& surface = source.surfaces[triangle];
    const int image = planned.imageIndex;
    if (image >= 0) {
        if (static_cast<size_t>(image) >= textures.size() ||
            static_cast<size_t>(image) >= scene.images.size()) {
            error = "pager material references an invalid image";
            return false;
        }
        material["texture"] = textures[static_cast<size_t>(image)];
        material["filter"] = static_cast<int64_t>(scene.images[static_cast<size_t>(image)].filter);
        material["texture_identity"] = TextureIdentity(scene.images[static_cast<size_t>(image)]);
    } else {
        material["texture"] = Variant();
        material["filter"] = int64_t{0};
        material["texture_identity"] = Dictionary();
    }
    material["color"] = Color(planned.color[0], planned.color[1], planned.color[2], planned.color[3]);
    material["ambient"] = static_cast<double>(planned.ambient);
    material["diffuse"] = static_cast<double>(planned.diffuse);
    material["alpha_mode"] = RegionPlanAlphaName(planned.alpha);
    material["family"] = "world";
    material["source_model"] = SourceString(source.sourceModelName);
    material["source_material_slot"] = surface.sourceMaterial;
    material["source_geometry"] = surface.sourceGeometry;
    material["model_identity"] = ModelIdentity(source);
    material["geometry_identity"] = GeometryIdentity(source, surface);
    material["material_identity"] = MaterialIdentity(source, surface);
    return true;
}

// One mesh-metadata finish unit: bounded outer checks + mesh dict. No pixel
// or triangle rescans.
bool FinishPlannedMeshMetadata(const WorldShotMesh& source, const Ref<ArrayMesh>& mesh,
                               const TypedArray<Dictionary>& materials, Dictionary& output,
                               String& error) {
    if (mesh.is_null() || mesh->get_surface_count() <= 0 ||
        mesh->get_surface_count() != materials.size()) {
        error = "ArrayMesh publication is incomplete";
        return false;
    }
    output["mesh"] = mesh;
    output["surface_materials"] = materials;
    output["source_model"] = SourceString(source.sourceModelName);
    output["source_model_id"] = source.sourceModelId;
    output["source_txd"] = SourceString(source.sourceTxdName);
    output["source_archive"] = SourceString(source.sourceArchiveName);
    output["source_placement_id"] = static_cast<int64_t>(source.sourcePlacementId);
    return true;
}

template<size_t N>
Color InterpolateRgb(const uint8_t (&first)[N], const uint8_t (&second)[N], float weight) {
    static_assert(N >= 3);
    return Color(
        std::lerp(static_cast<float>(first[0]), static_cast<float>(second[0]), weight) / 255.0f,
        std::lerp(static_cast<float>(first[1]), static_cast<float>(second[1]), weight) / 255.0f,
        std::lerp(static_cast<float>(first[2]), static_cast<float>(second[2]), weight) / 255.0f,
        1.0f);
}

// --- P1-A04 single-chain helpers (actual render + COL packet, no gameplay). ---

std::string LowerAscii(std::string value) {
    for (auto& c : value) {
        if (c >= 'A' && c <= 'Z') {
            c += 'a' - 'A';
        }
    }
    return value;
}

std::string NormalizeIplKey(const std::string& value) {
    std::string out = LowerAscii(value);
    for (auto& c : out) {
        if (c == '/') {
            c = '\\';
        }
    }
    return out;
}

bool FinitePlacement(const NativeCollisionPlacement& placement) {
    for (float v : placement.Position) {
        if (!Finite(v) || std::abs(v) > 1'000'000.0f) {
            return false;
        }
    }
    for (float v : placement.Quaternion) {
        if (!Finite(v)) {
            return false;
        }
    }
    float norm = 0.0f;
    for (float v : placement.Quaternion) {
        norm += v * v;
    }
    return Finite(norm) && norm > 1e-9f;
}

Dictionary PlacementDictionary(const NativeCollisionPlacement& placement) {
    Dictionary dict;
    dict["ipl"] = SourceString(placement.Ipl);
    dict["record"] = static_cast<int64_t>(placement.Record);
    dict["binary"] = placement.Binary;
    dict["position_sa"] = Vector3(placement.Position[0], placement.Position[1], placement.Position[2]);
    dict["quaternion_sa"] =
        Quaternion(placement.Quaternion[0], placement.Quaternion[1], placement.Quaternion[2],
                   placement.Quaternion[3]);
    return dict;
}

bool ValidateEffectiveCol(const NativeCollisionModel& col, uint32_t expectedFaces, String& error) {
    if (!col.Unsupported.empty()) {
        error = "effective COL is unsupported";
        return false;
    }
    if (col.Empty) {
        error = "effective COL is empty";
        return false;
    }
    if (col.Version < 1 || col.Version > 4) {
        error = "effective COL version out of range";
        return false;
    }
    if (!col.ValidatedHeaderId || col.HeaderId != kFrozenChildModel) {
        error = "effective COL header provenance mismatch";
        return false;
    }
    if (col.Library.empty() || col.Name.empty()) {
        error = "effective COL library/name missing";
        return false;
    }
    if (col.Vertices.empty() || col.Faces.empty()) {
        error = "effective COL geometry empty";
        return false;
    }
    if (expectedFaces != 0 && col.Faces.size() != expectedFaces) {
        error = "effective COL face count mismatch";
        return false;
    }
    constexpr size_t kMaxColElements = 1u << 20;
    if (col.Vertices.size() > kMaxColElements || col.Faces.size() > kMaxColElements ||
        col.Spheres.size() > kMaxColElements || col.Boxes.size() > kMaxColElements) {
        error = "effective COL element count out of range";
        return false;
    }
    for (float v : col.Min) {
        if (!Finite(v)) {
            error = "effective COL bounds_min nonfinite";
            return false;
        }
    }
    for (float v : col.Max) {
        if (!Finite(v)) {
            error = "effective COL bounds_max nonfinite";
            return false;
        }
    }
    for (float v : col.BoundCenter) {
        if (!Finite(v)) {
            error = "effective COL bound_center nonfinite";
            return false;
        }
    }
    if (!Finite(col.BoundRadius) || col.BoundRadius < 0.0f) {
        error = "effective COL bound_radius invalid";
        return false;
    }
    for (int axis = 0; axis < 3; ++axis) {
        if (col.Min[axis] > col.Max[axis]) {
            error = "effective COL bounds inverted";
            return false;
        }
    }
    for (const auto& v : col.Vertices) {
        for (float c : v) {
            if (!Finite(c)) {
                error = "effective COL vertex nonfinite";
                return false;
            }
        }
    }
    const uint64_t vertexCount = col.Vertices.size();
    for (const auto& face : col.Faces) {
        for (uint32_t index : face.Vertices) {
            if (static_cast<uint64_t>(index) >= vertexCount) {
                error = "effective COL face index outside array";
                return false;
            }
        }
    }
    for (const auto& sphere : col.Spheres) {
        for (float c : sphere.Center) {
            if (!Finite(c)) {
                error = "effective COL sphere center nonfinite";
                return false;
            }
        }
        if (!Finite(sphere.Radius) || sphere.Radius < 0.0f) {
            error = "effective COL sphere radius invalid";
            return false;
        }
    }
    for (const auto& box : col.Boxes) {
        for (float c : box.Min) {
            if (!Finite(c)) {
                error = "effective COL box min nonfinite";
                return false;
            }
        }
        for (float c : box.Max) {
            if (!Finite(c)) {
                error = "effective COL box max nonfinite";
                return false;
            }
        }
        for (int axis = 0; axis < 3; ++axis) {
            if (box.Min[axis] > box.Max[axis]) {
                error = "effective COL box bounds inverted";
                return false;
            }
        }
    }
    return true;
}

} // namespace

// P1-A06 bounded ownership: exactly one current conversion plus ONE retiring
// generation. Separate Ref holds prevent clearing one container from
// destroying the whole generation; each texture/mesh/dict drop is one
// budgeted unit with honest cascade timing.
struct SALegacyBridge::StagedConversion {
    uint64_t requestId = 0;
    uint64_t epoch = 0;
    std::unique_ptr<RawRegionPacket> raw;
    std::vector<Ref<ImageTexture>> textures;
    struct MeshState {
        Ref<ArrayMesh> mesh;
        TypedArray<Dictionary> materials;
        size_t nextSurface = 0;
        bool metaDone = false;
    };
    std::vector<MeshState> meshStates;
    std::vector<Dictionary> meshDicts;
    TypedArray<Dictionary> finalMeshes;
    size_t nextTexture = 0;
    size_t surfMeshIdx = 0;
    size_t surfacesDone = 0;
    size_t metaIdx = 0;
    bool pairedDone = false;
    int childMeshIndex = -1;
    int parentMeshIndex = -1;
    bool lodSelected = false;
    Dictionary collisionLineage;
    int64_t surfaceCount = 0;
    double msTotal = 0.0;
    double msMax = 0.0;
    int64_t frames = 0;
};

struct SALegacyBridge::RetiringGeneration {
    std::vector<Ref<ImageTexture>> textures;
    std::vector<Ref<ArrayMesh>> meshes;
    std::vector<Dictionary> dicts;
};

Dictionary SALegacyBridge::BuildProgressLocked(const String& phase, int64_t done,
                                              int64_t total) const {
    Dictionary progress;
    progress["phase"] = phase;
    progress["items_done"] = done;
    progress["items_total"] = total;
    progress["retire_pending"] = RetirePendingLocked();
    progress["staged_discards"] = m_StagedDiscards;
    progress["retire_ms_total"] = m_RetireMsTotal;
    progress["retire_ms_max_item"] = m_RetireMsMaxItem;
    return progress;
}

int64_t SALegacyBridge::RetirePendingLocked() const {
    if (!m_Retiring) {
        return 0;
    }
    return static_cast<int64_t>(m_Retiring->textures.size() + m_Retiring->meshes.size() +
                                m_Retiring->dicts.size());
}

void SALegacyBridge::DrainRetiringLocked(int64_t quota) {
    if (!m_Retiring || quota <= 0) {
        return;
    }
    int64_t remaining = quota;
    const auto drop = [&](auto& holds) {
        const double started = SteadyMs();
        holds.pop_back();
        const double elapsed = SteadyMs() - started;
        m_RetireMsTotal += elapsed;
        m_RetireMsMaxItem = std::max(m_RetireMsMaxItem, elapsed);
    };
    // Drop dicts first while separate texture/mesh holds keep resources alive;
    // each pop is one honest unit (cascade included in this call's wall time).
    while (remaining > 0 && !m_Retiring->dicts.empty()) {
        drop(m_Retiring->dicts);
        --remaining;
    }
    while (remaining > 0 && !m_Retiring->meshes.empty()) {
        drop(m_Retiring->meshes);
        --remaining;
    }
    while (remaining > 0 && !m_Retiring->textures.empty()) {
        drop(m_Retiring->textures);
        --remaining;
    }
    if (m_Retiring->dicts.empty() && m_Retiring->meshes.empty() &&
        m_Retiring->textures.empty()) {
        m_Retiring.reset();
    }
}

void SALegacyBridge::FlushRetiringUnbudgetedLocked() {
    // Explicit unbudgeted flush for sync diagnostics and teardown: destroy all
    // holds without quota. Separate vectors already prevent a single-container
    // avalanche; each pop still runs its honest cascade on main.
    if (!m_Retiring) {
        return;
    }
    m_Retiring->dicts.clear();
    m_Retiring->meshes.clear();
    m_Retiring->textures.clear();
    m_Retiring.reset();
}

void SALegacyBridge::DiscardConversionToRetiringLocked() {
    if (!m_Conversion) {
        return;
    }
    // Admission is closed while retiring is non-empty: conversion is only
    // admitted when retiring is empty, so a discard always finds an empty
    // slot. Repeated cancel cannot append generation vectors because the
    // cancel ack is one-shot and admission stays closed until retiring drains.
    if (m_Retiring) {
        // Defensive: retiring occupied means gating was violated. Do not append
        // (no vector growth); destroy staged Godot holds inline and retire raw.
        m_Conversion->textures.clear();
        m_Conversion->meshStates.clear();
        m_Conversion->meshDicts.clear();
        if (m_StagedDiscards < std::numeric_limits<int64_t>::max()) {
            ++m_StagedDiscards;
        }
        if (m_Conversion->raw && m_Worker) {
            m_Worker->Retire(std::move(m_Conversion->raw));
        }
        m_Conversion.reset();
        return;
    }
    m_Retiring = std::make_unique<RetiringGeneration>();
    for (auto& texture : m_Conversion->textures) {
        if (texture.is_valid()) {
            m_Retiring->textures.push_back(texture);
        }
    }
    for (auto& state : m_Conversion->meshStates) {
        if (state.mesh.is_valid()) {
            m_Retiring->meshes.push_back(state.mesh);
        }
        for (int64_t i = 0; i < state.materials.size(); ++i) {
            m_Retiring->dicts.push_back(state.materials[i]);
        }
    }
    for (auto& dict : m_Conversion->meshDicts) {
        if (!dict.is_empty()) {
            m_Retiring->dicts.push_back(dict);
        }
    }
    if (!m_Conversion->collisionLineage.is_empty()) {
        m_Retiring->dicts.push_back(m_Conversion->collisionLineage);
    }
    m_Conversion->textures.clear();
    m_Conversion->meshStates.clear();
    m_Conversion->meshDicts.clear();
    if (m_StagedDiscards < std::numeric_limits<int64_t>::max()) {
        ++m_StagedDiscards;
    }
    // Raw returns to the worker for off-mutex destruction BEFORE Stop/join.
    if (m_Conversion->raw && m_Worker) {
        m_Worker->Retire(std::move(m_Conversion->raw));
    }
    m_Conversion.reset();
}

bool SALegacyBridge::ConversionMatchesExposedLocked() const {
    return m_Conversion && m_ExposedActive && !m_ExposedCancelled &&
        m_Conversion->requestId == m_ExposedRequestId &&
        m_Conversion->epoch == m_ExposedEpoch;
}

bool SALegacyBridge::InitConversionLocked(std::unique_ptr<RawRegionPacket> packet, String& error,
                                          String& errorCode, Dictionary& errorContext) {
    error = String();
    errorCode = String();
    errorContext = Dictionary();
    if (!packet) {
        error = "region worker returned no packet";
        errorCode = "worker_stopped";
        return false;
    }
    // Retain-then-retire: on immediate terminals (parse/plan/revision/outer
    // mismatch) there is no staged Godot state yet; the owned raw returns to
    // the worker for off-mutex destruction (never inline heavy destroy here).
    auto retireRaw = [this](std::unique_ptr<RawRegionPacket> doomed) {
        if (doomed && m_Worker) {
            m_Worker->Retire(std::move(doomed));
        }
    };
    if (!packet->Error.empty()) {
        error = ErrorString(packet->Error.c_str());
        retireRaw(std::move(packet));
        return false;
    }
    if (!packet->PlanReady || !packet->PlanOk) {
        BuildPlanFailurePayload(packet->Scene, packet->PlanFailure, error, errorCode,
                                errorContext);
        retireRaw(std::move(packet));
        return false;
    }
    if (m_PublicationRevision == std::numeric_limits<int64_t>::max()) {
        error = "publication revision exhausted";
        retireRaw(std::move(packet));
        return false;
    }
    const WorldShotScene& scene = packet->Scene;
    const RegionPlan& plan = packet->Plan;
    if (plan.imageModes.size() != scene.images.size() ||
        plan.meshes.size() != scene.meshes.size()) {
        error = "pager mesh attribute sizes are inconsistent";
        retireRaw(std::move(packet));
        return false;
    }
    auto conv = std::make_unique<StagedConversion>();
    conv->requestId = packet->Request.RequestId;
    conv->epoch = packet->Request.SessionEpoch;
    conv->raw = std::move(packet);
    conv->textures.resize(scene.images.size());
    conv->meshStates.resize(plan.meshes.size());
    conv->meshDicts.resize(plan.meshes.size());
    conv->nextTexture = 0;
    conv->surfMeshIdx = 0;
    conv->surfacesDone = 0;
    conv->metaIdx = 0;
    conv->pairedDone = false;
    conv->childMeshIndex = -1;
    conv->parentMeshIndex = -1;
    conv->lodSelected = false;
    conv->surfaceCount = static_cast<int64_t>(RegionPlanTotalSurfaces(plan));
    conv->msTotal = 0.0;
    conv->msMax = 0.0;
    conv->frames = 0;
    m_Conversion = std::move(conv);
    return true;
}

int64_t SALegacyBridge::ConversionTotalLocked() const {
    if (!m_Conversion || !m_Conversion->raw) {
        return 0;
    }
    return static_cast<int64_t>(RegionPlanTotalUnits(m_Conversion->raw->Plan));
}

int64_t SALegacyBridge::ConversionDoneLocked() const {
    if (!m_Conversion) {
        return 0;
    }
    const auto& conv = *m_Conversion;
    int64_t done = static_cast<int64_t>(conv.nextTexture + conv.surfacesDone + conv.metaIdx +
                                        (conv.pairedDone ? 1 : 0));
    const int64_t total = ConversionTotalLocked();
    if (done > total) {
        done = total;
    }
    return done;
}

String SALegacyBridge::ConversionPhaseLocked() const {
    if (!m_Conversion || !m_Conversion->raw) {
        return "idle";
    }
    const auto& conv = *m_Conversion;
    const auto& plan = conv.raw->Plan;
    if (conv.nextTexture < conv.textures.size()) {
        return "textures";
    }
    if (conv.surfacesDone < RegionPlanTotalSurfaces(plan)) {
        return "surfaces";
    }
    if (conv.metaIdx < conv.meshStates.size()) {
        return "metadata";
    }
    return "paired";
}

SALegacyBridge::AdvanceOutcome SALegacyBridge::AdvanceConversionLocked(int64_t quota,
                                                                       String& error) {
    error = String();
    if (!m_Conversion || !m_Conversion->raw) {
        return AdvanceOutcome::NeedMore;
    }
    if (quota <= 0) {
        return AdvanceOutcome::NeedMore;
    }
    auto& conv = *m_Conversion;
    ++conv.frames;
    const WorldShotScene& scene = conv.raw->Scene;
    const RegionPlan& plan = conv.raw->Plan;
    const std::vector<NativePlacementIdentity>& rendered = conv.raw->Rendered;

    auto noteTime = [&](double startMs) {
        const double endMs = SteadyMs();
        const double dt = endMs - startMs;
        conv.msTotal += dt;
        if (dt > conv.msMax) {
            conv.msMax = dt;
        }
    };

    while (conv.nextTexture < conv.textures.size() && quota > 0) {
        const double startMs = SteadyMs();
        Ref<ImageTexture> texture = MakeTexture(scene.images[conv.nextTexture]);
        noteTime(startMs);
        --quota;
        if (texture.is_null()) {
            error = "Godot rejected a decoded RGBA texture";
            return AdvanceOutcome::Error;
        }
        conv.textures[conv.nextTexture] = texture;
        ++conv.nextTexture;
    }
    if (conv.nextTexture < conv.textures.size()) {
        return AdvanceOutcome::NeedMore;
    }

    const size_t totalSurfaces = RegionPlanTotalSurfaces(plan);
    while (conv.surfacesDone < totalSurfaces && quota > 0) {
        while (conv.surfMeshIdx < conv.meshStates.size() &&
               conv.meshStates[conv.surfMeshIdx].nextSurface >=
                   plan.meshes[conv.surfMeshIdx].surfaces.size()) {
            ++conv.surfMeshIdx;
        }
        if (conv.surfMeshIdx >= conv.meshStates.size()) {
            error = "ArrayMesh publication is incomplete";
            return AdvanceOutcome::Error;
        }
        auto& state = conv.meshStates[conv.surfMeshIdx];
        const auto& plannedMesh = plan.meshes[conv.surfMeshIdx];
        const size_t surfIdx = state.nextSurface;
        if (surfIdx >= plannedMesh.surfaces.size()) {
            error = "ArrayMesh publication is incomplete";
            return AdvanceOutcome::Error;
        }
        const auto& plannedSurface = plannedMesh.surfaces[surfIdx];
        const size_t srcIdx = plannedMesh.sourceMeshIndex;
        if (srcIdx >= scene.meshes.size() ||
            plannedSurface.representativeTriangle >= scene.meshes[srcIdx].surfaces.size()) {
            error = "ArrayMesh publication is incomplete";
            return AdvanceOutcome::Error;
        }
        const auto& sourceMesh = scene.meshes[srcIdx];
        const double startMs = SteadyMs();
        if (state.mesh.is_null()) {
            state.mesh.instantiate();
        }
        Dictionary material;
        String surfError;
        bool ok = false;
        if (!state.mesh.is_null()) {
            ok = AddPlannedSurface(sourceMesh, plannedSurface, state.mesh, material,
                                   conv.textures, scene, surfError);
        } else {
            surfError = "ArrayMesh publication is incomplete";
        }
        noteTime(startMs);
        --quota;
        if (!ok) {
            error = surfError;
            return AdvanceOutcome::Error;
        }
        state.materials.push_back(material);
        ++state.nextSurface;
        ++conv.surfacesDone;
        if (state.nextSurface >= plannedMesh.surfaces.size()) {
            ++conv.surfMeshIdx;
        }
    }
    if (conv.surfacesDone < totalSurfaces) {
        return AdvanceOutcome::NeedMore;
    }

    while (conv.metaIdx < conv.meshStates.size() && quota > 0) {
        const auto& plannedMesh = plan.meshes[conv.metaIdx];
        const size_t srcIdx = plannedMesh.sourceMeshIndex;
        if (srcIdx >= scene.meshes.size()) {
            error = "ArrayMesh publication is incomplete";
            return AdvanceOutcome::Error;
        }
        const auto& sourceMesh = scene.meshes[srcIdx];
        auto& state = conv.meshStates[conv.metaIdx];
        const double startMs = SteadyMs();
        Dictionary out;
        String metaError;
        const bool ok =
            FinishPlannedMeshMetadata(sourceMesh, state.mesh, state.materials, out, metaError);
        noteTime(startMs);
        --quota;
        if (!ok) {
            error = metaError;
            return AdvanceOutcome::Error;
        }
        conv.meshDicts[conv.metaIdx] = out;
        state.metaDone = true;
        ++conv.metaIdx;
    }
    if (conv.metaIdx < conv.meshStates.size()) {
        return AdvanceOutcome::NeedMore;
    }
    if (conv.meshDicts.empty() && !plan.meshes.empty()) {
        error = "validated scene produced no Godot meshes";
        return AdvanceOutcome::Error;
    }

    if (!conv.pairedDone) {
        if (quota <= 0) {
            return AdvanceOutcome::NeedMore;
        }
        const double startMs = SteadyMs();
        int childMeshIndex = -1;
        int parentMeshIndex = -1;
        bool lodSelected = false;
        String pairError;
        bool pairOk = true;
        // P1-A04 single-chain resolution (bounded outer metadata, no rescans).
        if (m_HasLodPair && m_Catalog && m_EffectiveCol) {
            if (rendered.size() != scene.meshes.size()) {
                pairError = "LOD supplement render identity count mismatch";
                pairOk = false;
            } else {
                for (size_t i = 0; pairOk && i < rendered.size(); ++i) {
                    if (rendered[i] == m_Decision.Child) {
                        if (childMeshIndex >= 0) {
                            pairError = "LOD supplement duplicate child render";
                            pairOk = false;
                            break;
                        }
                        childMeshIndex = static_cast<int>(i);
                    }
                    if (rendered[i] == m_Decision.Parent) {
                        if (parentMeshIndex >= 0) {
                            pairError = "LOD supplement duplicate parent render";
                            pairOk = false;
                            break;
                        }
                        parentMeshIndex = static_cast<int>(i);
                    }
                }
                if (pairOk && (childMeshIndex >= 0 || parentMeshIndex >= 0)) {
                    if (childMeshIndex < 0 || parentMeshIndex < 0) {
                        pairError = "LOD supplement half pair present (pair rejected)";
                        pairOk = false;
                    } else if (childMeshIndex >= static_cast<int>(scene.meshes.size()) ||
                               parentMeshIndex >= static_cast<int>(scene.meshes.size()) ||
                               childMeshIndex >= static_cast<int>(conv.meshDicts.size()) ||
                               parentMeshIndex >= static_cast<int>(conv.meshDicts.size())) {
                        pairError = "LOD supplement mesh index outside publication";
                        pairOk = false;
                    } else {
                        const auto& childScene =
                            scene.meshes[static_cast<size_t>(childMeshIndex)];
                        const auto& parentScene =
                            scene.meshes[static_cast<size_t>(parentMeshIndex)];
                        if (childScene.tris <= 0 || childScene.pos.empty() ||
                            parentScene.tris <= 0 || parentScene.pos.empty()) {
                            pairError = "LOD supplement pair geometry empty (pair rejected)";
                            pairOk = false;
                        } else {
                            lodSelected = true;
                        }
                    }
                }
            }
        }
        Dictionary lineage;
        if (pairOk && lodSelected) {
            if (!FinitePlacement(m_ChildPlacement) || !FinitePlacement(m_ParentPlacement)) {
                pairError = "LOD supplement authored placement nonfinite";
                pairOk = false;
            } else {
                String colError;
                if (!m_EffectiveCol ||
                    !ValidateEffectiveCol(*m_EffectiveCol, m_Decision.EffectiveColFaces,
                                          colError)) {
                    pairError = colError.is_empty() ? "LOD supplement effective COL invalid"
                                                    : colError;
                    pairOk = false;
                } else if (m_EffectiveColLibrary.empty() ||
                           m_EffectiveColLibrary != m_EffectiveCol->Library) {
                    pairError = "LOD supplement effective COL library mismatch";
                    pairOk = false;
                } else {
                    const NativeCollisionModel& col = *m_EffectiveCol;
                    const int64_t vertexCount = static_cast<int64_t>(col.Vertices.size());
                    const int64_t faceCount = static_cast<int64_t>(col.Faces.size());
                    const int64_t sphereCount = static_cast<int64_t>(col.Spheres.size());
                    const int64_t boxCount = static_cast<int64_t>(col.Boxes.size());
                    if (vertexCount <= 0 || faceCount <= 0) {
                        pairError = "LOD supplement effective COL counters invalid";
                        pairOk = false;
                    } else {
                        PackedFloat32Array vertices;
                        vertices.resize(vertexCount * 3);
                        for (int64_t i = 0; i < vertexCount; ++i) {
                            const auto& v = col.Vertices[static_cast<size_t>(i)];
                            vertices.set(i * 3, v[0]);
                            vertices.set(i * 3 + 1, v[1]);
                            vertices.set(i * 3 + 2, v[2]);
                        }
                        PackedInt32Array faceIndices;
                        faceIndices.resize(faceCount * 3);
                        bool faceOk = true;
                        for (int64_t i = 0; pairOk && faceOk && i < faceCount; ++i) {
                            const auto& face = col.Faces[static_cast<size_t>(i)];
                            for (int k = 0; k < 3; ++k) {
                                const uint32_t index = face.Vertices[static_cast<size_t>(k)];
                                if (static_cast<uint64_t>(index) >=
                                        static_cast<uint64_t>(vertexCount) ||
                                    index > static_cast<uint32_t>(
                                                std::numeric_limits<int32_t>::max())) {
                                    pairError =
                                        "LOD supplement effective COL face index outside array";
                                    pairOk = false;
                                    faceOk = false;
                                    break;
                                }
                                faceIndices.set(i * 3 + k, static_cast<int32_t>(index));
                            }
                        }
                        if (pairOk) {
                            PackedByteArray faceSurfaces;
                            faceSurfaces.resize(faceCount * 4);
                            for (int64_t i = 0; i < faceCount; ++i) {
                                const auto& surface =
                                    col.Faces[static_cast<size_t>(i)].Surface;
                                faceSurfaces.set(i * 4, surface.Material);
                                faceSurfaces.set(i * 4 + 1, surface.Flags);
                                faceSurfaces.set(i * 4 + 2, surface.Brightness);
                                faceSurfaces.set(i * 4 + 3, surface.Light);
                            }
                            PackedFloat32Array sphereData;
                            sphereData.resize(sphereCount * 4);
                            PackedByteArray sphereSurfaces;
                            sphereSurfaces.resize(sphereCount * 4);
                            for (int64_t i = 0; i < sphereCount; ++i) {
                                const auto& sphere = col.Spheres[static_cast<size_t>(i)];
                                sphereData.set(i * 4, sphere.Center[0]);
                                sphereData.set(i * 4 + 1, sphere.Center[1]);
                                sphereData.set(i * 4 + 2, sphere.Center[2]);
                                sphereData.set(i * 4 + 3, sphere.Radius);
                                sphereSurfaces.set(i * 4, sphere.Surface.Material);
                                sphereSurfaces.set(i * 4 + 1, sphere.Surface.Flags);
                                sphereSurfaces.set(i * 4 + 2, sphere.Surface.Brightness);
                                sphereSurfaces.set(i * 4 + 3, sphere.Surface.Light);
                            }
                            PackedFloat32Array boxData;
                            boxData.resize(boxCount * 6);
                            PackedByteArray boxSurfaces;
                            boxSurfaces.resize(boxCount * 4);
                            for (int64_t i = 0; i < boxCount; ++i) {
                                const auto& box = col.Boxes[static_cast<size_t>(i)];
                                boxData.set(i * 6, box.Min[0]);
                                boxData.set(i * 6 + 1, box.Min[1]);
                                boxData.set(i * 6 + 2, box.Min[2]);
                                boxData.set(i * 6 + 3, box.Max[0]);
                                boxData.set(i * 6 + 4, box.Max[1]);
                                boxData.set(i * 6 + 5, box.Max[2]);
                                boxSurfaces.set(i * 4, box.Surface.Material);
                                boxSurfaces.set(i * 4 + 1, box.Surface.Flags);
                                boxSurfaces.set(i * 4 + 2, box.Surface.Brightness);
                                boxSurfaces.set(i * 4 + 3, box.Surface.Light);
                            }
                            Dictionary childDict;
                            childDict["model_id"] =
                                static_cast<int64_t>(m_Decision.Child.ModelId);
                            childDict["model"] = SourceString(m_Decision.Child.Model);
                            childDict["mesh_index"] = static_cast<int64_t>(childMeshIndex);
                            childDict["uses_collision"] = true;
                            childDict["placement"] = PlacementDictionary(m_ChildPlacement);
                            Dictionary parentDict;
                            parentDict["model_id"] =
                                static_cast<int64_t>(m_Decision.Parent.ModelId);
                            parentDict["model"] = SourceString(m_Decision.Parent.Model);
                            parentDict["mesh_index"] = static_cast<int64_t>(parentMeshIndex);
                            parentDict["uses_collision"] = false;
                            parentDict["effective_alias"] = "child";
                            parentDict["placement"] = PlacementDictionary(m_ParentPlacement);
                            Dictionary colDict;
                            colDict["status"] = "ready";
                            colDict["library"] = SourceString(col.Library);
                            colDict["header_id"] = static_cast<int64_t>(col.HeaderId);
                            colDict["header_name"] = SourceString(col.Name);
                            colDict["version"] = static_cast<int64_t>(col.Version);
                            colDict["vertex_count"] = vertexCount;
                            colDict["faces"] = faceCount;
                            colDict["spheres"] = sphereCount;
                            colDict["boxes"] = boxCount;
                            colDict["bounds_min"] =
                                Vector3(col.Min[0], col.Min[1], col.Min[2]);
                            colDict["bounds_max"] =
                                Vector3(col.Max[0], col.Max[1], col.Max[2]);
                            colDict["bound_center"] = Vector3(
                                col.BoundCenter[0], col.BoundCenter[1], col.BoundCenter[2]);
                            colDict["bound_radius"] = col.BoundRadius;
                            colDict["vertices"] = vertices;
                            colDict["face_indices"] = faceIndices;
                            colDict["face_surfaces"] = faceSurfaces;
                            colDict["sphere_data"] = sphereData;
                            colDict["sphere_surfaces"] = sphereSurfaces;
                            colDict["box_data"] = boxData;
                            colDict["box_surfaces"] = boxSurfaces;
                            lineage["generation"] = m_PublicationRevision + 1;
                            lineage["scope"] = "single-chain-data-not-gameplay";
                            lineage["link"] = "bound";
                            lineage["collision_transferred"] = true;
                            lineage["child"] = childDict;
                            lineage["parent"] = parentDict;
                            lineage["col"] = colDict;
                        }
                    }
                }
            }
        }
        TypedArray<Dictionary> finalMeshes;
        if (pairOk) {
            for (size_t i = 0; i < conv.meshDicts.size(); ++i) {
                Dictionary entry = conv.meshDicts[i];
                entry["lod_chain_alternate"] =
                    lodSelected && static_cast<int>(i) == parentMeshIndex;
                conv.meshDicts[i] = entry;
                finalMeshes.push_back(entry);
            }
            if (finalMeshes.is_empty() && !plan.meshes.empty()) {
                pairError = "validated scene produced no Godot meshes";
                pairOk = false;
            } else {
                conv.finalMeshes = finalMeshes;
                conv.collisionLineage = lineage;
                conv.childMeshIndex = childMeshIndex;
                conv.parentMeshIndex = parentMeshIndex;
                conv.lodSelected = lodSelected;
            }
        }
        noteTime(startMs);
        --quota;
        if (!pairOk) {
            error = pairError;
            return AdvanceOutcome::Error;
        }
        conv.pairedDone = true;
        return AdvanceOutcome::Ready;
    }
    return AdvanceOutcome::Ready;
}

Dictionary SALegacyBridge::BuildReadyPayloadLocked() {
    auto& conv = *m_Conversion;
    const RawRegionPacket& raw = *conv.raw;
    const WorldShotScene& scene = raw.Scene;
    const E2EPagerFrame& frame = raw.Frame;
    const TypedArray<Dictionary> meshes = conv.finalMeshes;
    const int64_t surfaceCount = conv.surfaceCount;
    const Dictionary collisionLineage = conv.collisionLineage;
    const double msTotal = conv.msTotal;
    const double msMax = conv.msMax;
    const int64_t frames = conv.frames;
    const int sectorsLoaded = raw.Counters[0];
    const int sectorsEvicted = raw.Counters[1];
    const int modelsPeak = raw.Counters[2];
    const int trisPeak = raw.Counters[3];
    Dictionary stats;
    stats["instances"] = frame.instances;
    stats["models_unique"] = frame.modelsUnique;
    stats["triangles"] = frame.tris;
    stats["vertices"] = frame.verts;
    stats["meshes"] = meshes.size();
    stats["surfaces"] = surfaceCount;
    stats["images"] = static_cast<int64_t>(scene.images.size());
    stats["active_cells"] = frame.activeCells;
    stats["loaded_cells"] = frame.loadedCells;
    stats["evicted_cells"] = frame.evictedCells;
    stats["cache_models"] = frame.cacheModels;
    stats["texture_dictionaries"] = frame.texDicts;
    stats["fallback_window"] = frame.fallback != 0;
    stats["sectors_loaded_total"] = sectorsLoaded;
    stats["sectors_evicted_total"] = sectorsEvicted;
    stats["models_peak"] = modelsPeak;
    stats["triangles_peak"] = trisPeak;
    stats["coordinate_basis"] = "SA XYZ -> Godot X,Z,-Y; source triangle order retained";
    stats["lod_status"] = "source pager representation; no Godot runtime LOD selection";
    stats["raw_parse_ms"] = raw.ParseMs;
    stats["request_id"] = static_cast<int64_t>(raw.Request.RequestId);
    stats["session_epoch"] = static_cast<int64_t>(raw.Request.SessionEpoch);
    stats["conversion_ms_total"] = msTotal;
    stats["conversion_ms_max_item"] = msMax;
    stats["conversion_frames"] = frames;
    Dictionary result = Result(true);
    result["meshes"] = meshes;
    result["stats"] = stats;
    result["collision_lineage"] = collisionLineage;
    ++m_PublicationRevision;
    result["publication_revision"] = m_PublicationRevision;
    if (m_Worker) {
        m_Worker->Retire(std::move(conv.raw));
    }
    m_Conversion.reset();
    return result;
}

void SALegacyBridge::_bind_methods() {
    ClassDB::bind_method(D_METHOD("open_game", "game_dir", "radius", "cap", "budget_items"),
                         &SALegacyBridge::OpenGame, DEFVAL(64));
    ClassDB::bind_method(D_METHOD("load_region", "SA_position"), &SALegacyBridge::LoadRegion);
    ClassDB::bind_method(D_METHOD("submit_region", "SA_position"), &SALegacyBridge::SubmitRegion);
    ClassDB::bind_method(D_METHOD("poll_region"), &SALegacyBridge::PollRegion);
    ClassDB::bind_method(D_METHOD("cancel_region", "request_id"), &SALegacyBridge::CancelRegion);
    ClassDB::bind_method(D_METHOD("environment", "weather", "hour"), &SALegacyBridge::Environment);
    ClassDB::bind_method(D_METHOD("close_game"), &SALegacyBridge::CloseGame);
}

SALegacyBridge::SALegacyBridge() = default;

SALegacyBridge::~SALegacyBridge() {
    CloseGame();
}

Dictionary SALegacyBridge::OpenGame(const String& gameDir, float radius, int32_t cap,
                                     int64_t budgetItems) {
    if (!IsMainThread()) {
        return Result(false, "open_game must run on Godot's main thread");
    }
    if (!std::isfinite(radius) || radius < kMinRadius || radius > kMaxRadius) {
        return Result(false, "radius must be finite and in [1,2000]");
    }
    if (cap <= 0 || cap > kMaxInstances) {
        return Result(false, "cap must be in [1,4096]");
    }
    if (budgetItems < kMinBudgetItems || budgetItems > kMaxBudgetItems) {
        return Result(false, "budget_items must be in [1,4096]");
    }
    const std::string path = Utf8(gameDir);
    if (path.empty() || std::strlen(path.c_str()) != path.size()) {
        return Result(false, "game_dir must be a nonempty path without NUL bytes");
    }
    std::error_code pathError;
    if (!std::filesystem::is_directory(std::filesystem::path(path), pathError) || pathError) {
        return Result(false, "game_dir is not a readable directory");
    }

    std::lock_guard lock(s_PagerMutex);
    if (m_Ready) {
        return Result(false, "this bridge already owns an open pager");
    }
    if (s_PagerOwner) {
        return Result(false, "another SALegacyBridge owns the process-global pager");
    }

    E2ELoadInfo info;
    char error[256]{};
    const StreamPagerOptions options{
        .includeStreamed = true,
        .radius = radius,
        .maxInstances = cap,
    };
    if (!StreamPager_Init(path.c_str(), info, error, sizeof(error), options)) {
        StreamPager_Shutdown();
        return Result(false, ErrorString(error));
    }
    if (info.ideModels <= 0 || info.iplTotal <= 0 || info.iplKept <= 0) {
        StreamPager_Shutdown();
        return Result(false, "pager initialized with invalid source counters");
    }

    // P1-A04 single-chain setup after Init, before any Update. Every failure
    // shuts the pager down directly: never call CloseGame() here (mutex is
    // already held, CloseGame would deadlock). Revision stays untouched.
    NativeCollisionPopulation fullPopulation;
    {
        std::string popError;
        if (!StreamPager_CollisionPopulation(fullPopulation, popError)) {
            StreamPager_Shutdown();
            const String detail = String::utf8(popError.c_str());
            return Result(false, detail.is_empty() ? "collision population unavailable"
                                                   : String("collision population unavailable: ") + detail);
        }
    }
    if (!fullPopulation.IncludesStreamed || fullPopulation.Instances.empty() ||
        fullPopulation.Models.empty()) {
        StreamPager_Shutdown();
        return Result(false, "collision population lacks streamed source provenance");
    }

    std::shared_ptr<const NativeLodCatalog> catalog;
    {
        std::string catalogError;
        catalog = NativeLodCatalog::LoadBeforeWorker(path.c_str(), fullPopulation, catalogError);
        if (!catalog || !catalog->DiskValidated()) {
            StreamPager_Shutdown();
            const String detail = String::utf8(catalogError.c_str());
            return Result(false,
                          detail.is_empty() ? "LOD catalog disk validation failed" : detail);
        }
    }

    NativeCollisionAssets collisionAssets;
    {
        std::string colError;
        if (!collisionAssets.Load(path.c_str(), fullPopulation, colError)) {
            StreamPager_Shutdown();
            const String detail = String::utf8(colError.c_str());
            return Result(false, detail.is_empty() ? "collision assets load failed" : detail);
        }
    }

    // EXPLICIT bounded real profile via the actual catalog: LAn text
    // record0/model3991 GSFreeway7_LAn -> record24/model4043 LODGSFreeway7_LAn.
    const NativeLodNode* childNode = nullptr;
    const NativeLodNode* parentNode = nullptr;
    size_t childCount = 0;
    size_t parentCount = 0;
    for (const auto& node : catalog->Nodes()) {
        if (node.Identity.ModelId == kFrozenChildModel) {
            ++childCount;
            childNode = &node;
        }
        if (node.Identity.ModelId == kFrozenParentModel) {
            ++parentCount;
            parentNode = &node;
        }
    }
    if (childCount != 1 || parentCount != 1 || !childNode || !parentNode) {
        StreamPager_Shutdown();
        return Result(false, "frozen LOD pair models 3991/4043 not uniquely present");
    }
    {
        bool profileOk = true;
        if (LowerAscii(childNode->Identity.Model) != "gsfreeway7_lan") {
            profileOk = false;
        }
        if (LowerAscii(parentNode->Identity.Model) != "lodgsfreeway7_lan") {
            profileOk = false;
        }
        if (NormalizeIplKey(childNode->Identity.Ipl) != "data\\maps\\la\\lan.ipl") {
            profileOk = false;
        }
        if (NormalizeIplKey(parentNode->Identity.Ipl) != "data\\maps\\la\\lan.ipl") {
            profileOk = false;
        }
        if (childNode->Identity.Record != kFrozenChildRecord ||
            parentNode->Identity.Record != kFrozenParentRecord) {
            profileOk = false;
        }
        if (childNode->Identity.Binary || parentNode->Identity.Binary) {
            profileOk = false;
        }
        if (childNode->Source != parentNode->Source) {
            profileOk = false;
        }
        if (childNode->LocalIndex != kFrozenChildLocal ||
            parentNode->LocalIndex != kFrozenParentLocal) {
            profileOk = false;
        }
        if (childNode->Placement.Lod != static_cast<int>(parentNode->LocalIndex)) {
            profileOk = false;
        }
        if (parentNode->Placement.Lod != -1) {
            profileOk = false;
        }
        if (childNode->Link != NativeLodLinkStatus::Bound) {
            profileOk = false;
        }
        if (!FinitePlacement(childNode->Placement) || !FinitePlacement(parentNode->Placement)) {
            profileOk = false;
        }
        const size_t childIdx = static_cast<size_t>(childNode - catalog->Nodes().data());
        const size_t parentIdx = static_cast<size_t>(parentNode - catalog->Nodes().data());
        if (!(childNode->Parent.has_value() && *childNode->Parent == parentIdx)) {
            profileOk = false;
        }
        if (!childNode->Children.empty()) {
            profileOk = false;
        }
        if (parentNode->Parent.has_value()) {
            profileOk = false;
        }
        if (parentNode->Children.size() != 1 || parentNode->Children.front() != childIdx) {
            profileOk = false;
        }
        if (!profileOk) {
            StreamPager_Shutdown();
            return Result(false, "frozen LOD pair profile mismatch (LAn record0/3991->record24/4043)");
        }
    }

    NativeLodChainDecision decision;
    {
        std::string evalError;
        const NativeLinkLodsInputs inputs(false, 1.0f);
        if (!catalog->EvaluateLinkLodsChain(childNode->Identity, collisionAssets, inputs, decision,
                                            evalError)) {
            StreamPager_Shutdown();
            const String detail = String::utf8(evalError.c_str());
            return Result(false, detail.is_empty() ? "frozen LOD chain closure rejected" : detail);
        }
    }
    {
        bool closureOk = true;
        if (!(decision.Child == childNode->Identity)) {
            closureOk = false;
        }
        if (!(decision.Parent == parentNode->Identity)) {
            closureOk = false;
        }
        if (decision.ChildModelId != kFrozenChildModel ||
            decision.ParentModelId != kFrozenParentModel) {
            closureOk = false;
        }
        if (decision.Link != NativeLodLinkStatus::Bound || !decision.EdgeKept) {
            closureOk = false;
        }
        if (!decision.CollisionTransferred || !decision.EffectiveCol) {
            closureOk = false;
        }
        if (decision.EffectiveColFaces == 0) {
            closureOk = false;
        }
        if (decision.EffectiveCol &&
            decision.EffectiveColFaces != decision.EffectiveCol->Faces.size()) {
            closureOk = false;
        }
        if (decision.EffectiveColLibrary.empty()) {
            closureOk = false;
        }
        if (decision.EffectiveCol &&
            decision.EffectiveColLibrary != decision.EffectiveCol->Library) {
            closureOk = false;
        }
        if (decision.ChildBigBuilding != NativeWorldKnownBool::False ||
            decision.ChildUsesCollision != NativeWorldKnownBool::True ||
            decision.ChildIsLod != NativeWorldKnownBool::True) {
            closureOk = false;
        }
        if (decision.ParentBigBuilding != NativeWorldKnownBool::True ||
            decision.ParentUsesCollision != NativeWorldKnownBool::False ||
            decision.ParentIsLod != NativeWorldKnownBool::False) {
            closureOk = false;
        }
        if (!decision.DrawUnchanged) {
            closureOk = false;
        }
        if (decision.Underwater || decision.UnderwaterPropagated) {
            closureOk = false;
        }
        if (decision.ParentChildren != 1 || decision.ChildChildren != 0) {
            closureOk = false;
        }
        if (decision.EffectiveCol) {
            String colError;
            if (!ValidateEffectiveCol(*decision.EffectiveCol, decision.EffectiveColFaces, colError)) {
                closureOk = false;
            }
        } else {
            closureOk = false;
        }
        if (!closureOk) {
            StreamPager_Shutdown();
            return Result(false, "frozen LOD chain closure incomplete");
        }
    }

    {
        std::string cfgError;
        if (!StreamPager_ConfigureLodSupplement(decision.Child, decision.Parent, cfgError)) {
            StreamPager_Shutdown();
            const String detail = String::utf8(cfgError.c_str());
            return Result(false, detail.is_empty() ? "LOD supplement configuration rejected"
                                                   : detail);
        }
    }

    // Retain catalog + decision/effective COL owned data. The whole asset map
    // is released here; the shared EffectiveCol keeps the packet alive.
    m_Catalog = catalog;
    m_Decision = decision;
    m_ChildPlacement = childNode->Placement;
    m_ParentPlacement = parentNode->Placement;
    m_EffectiveCol = decision.EffectiveCol;
    m_EffectiveColLibrary = decision.EffectiveColLibrary;
    m_HasLodPair = true;

    // P1-A05: reserve the process-global owner for the whole worker lifetime
    // before the parser thread starts. All native config above ran on main.
    s_PagerOwner = this;

    // Session epoch: never reset across close/reopen, bound to int64 max for
    // Godot exposure. Only a successful Open advances it.
    constexpr uint64_t kMaxGodotInt = static_cast<uint64_t>(std::numeric_limits<int64_t>::max());
    if (m_SessionEpoch >= kMaxGodotInt) {
        s_PagerOwner = nullptr;
        StreamPager_Shutdown();
        m_Catalog.reset();
        m_Decision = NativeLodChainDecision{};
        m_ChildPlacement = NativeCollisionPlacement{};
        m_ParentPlacement = NativeCollisionPlacement{};
        m_EffectiveCol.reset();
        m_EffectiveColLibrary.clear();
        m_HasLodPair = false;
        return Result(false, "session epoch exhausted");
    }
    const uint64_t proposedEpoch = m_SessionEpoch + 1;

    // Sole-owner parse: pure StreamPager_Update + Rendered + Frame + Counters
    // plus BuildRegionPlan at parse end (worker parse+plan timing in ParseMs).
    // Captures no this/Godot state; no Godot API on the worker.
    ParseFn parse = [](RawRegionPacket& packet) {
        const std::shared_ptr<const NativePlacementOverrides> noOverrides;
        char err[256]{};
        if (!StreamPager_Update(packet.Request.X, packet.Request.Y, packet.Request.Z,
                                packet.Scene, packet.Frame, err, sizeof(err),
                                noOverrides, &packet.Rendered)) {
            packet.Error.assign(err[0] != '\0' ? err : "unknown pager update failure");
            return;
        }
        int loaded = 0;
        int evicted = 0;
        int peakModels = 0;
        int peakTris = 0;
        StreamPager_Counters(loaded, evicted, peakModels, peakTris);
        packet.Counters[0] = loaded;
        packet.Counters[1] = evicted;
        packet.Counters[2] = peakModels;
        packet.Counters[3] = peakTris;
        // Pure worker planning reuses exact validation/alpha/group ordering
        // and prepacks surface data; main only copies buffers. Fake unit
        // parsers need not invent a plan except plan tests.
        packet.PlanReady = true;
        packet.PlanOk = BuildRegionPlan(packet.Scene, packet.Plan, packet.PlanFailure);
    };
    std::string workerError;
    std::unique_ptr<RegionWorker> worker =
        RegionWorker::Create(parse, proposedEpoch, workerError);
    if (!worker) {
        // Factory failure cleans Init without deadlock (mutex already held,
        // CloseGame not called here) and without fake Ready.
        s_PagerOwner = nullptr;
        StreamPager_Shutdown();
        m_Catalog.reset();
        m_Decision = NativeLodChainDecision{};
        m_ChildPlacement = NativeCollisionPlacement{};
        m_ParentPlacement = NativeCollisionPlacement{};
        m_EffectiveCol.reset();
        m_EffectiveColLibrary.clear();
        m_HasLodPair = false;
        const String detail = String::utf8(workerError.c_str());
        return Result(false, detail.is_empty() ? "region worker creation failed" : detail);
    }

    m_SessionEpoch = proposedEpoch;
    m_Worker = std::move(worker);
    m_BudgetItems = budgetItems;
    m_ExposedActive = false;
    m_ExposedRequestId = 0;
    m_ExposedEpoch = 0;
    m_ExposedCancelled = false;
    // m_NextRequestId, m_PublicationRevision, m_DiscardedStale, m_StagedDiscards
    // intentionally preserved across close/reopen; only a published region
    // advances revision. m_Conversion/m_Retiring are empty here (Open fails
    // while ready, Close flushes unbudgeted).

    m_GameDir = path;
    m_Ready = true;
    Dictionary result = Result(true);
    result["radius"] = radius;
    result["cap"] = cap;
    result["ide_models"] = info.ideModels;
    result["ide_files"] = info.ideFiles;
    result["ipl_files"] = info.iplFiles;
    result["ipl_total"] = info.iplTotal;
    result["ipl_kept"] = info.iplKept;
    result["binary_ipl_files"] = info.binaryIplFiles;
    result["binary_instances"] = info.binaryInstances;
    result["asset_source"] = "external game directory; no executable read";
    result["publication_revision"] = m_PublicationRevision;
    result["session_epoch"] = static_cast<int64_t>(m_SessionEpoch);
    return result;
}

// P1-A06: atomic PreparePublication removed; Init/Advance/BuildReady stepper owns all conversion.

namespace {

constexpr uint64_t kMaxGodotIntU64 = static_cast<uint64_t>(std::numeric_limits<int64_t>::max());
constexpr float kCoordLimit = 1'000'000.0f;

bool ValidRegionCoords(const Vector3& pos) {
    return Finite(pos.x) && Finite(pos.y) && Finite(pos.z) &&
        std::abs(pos.x) <= kCoordLimit && std::abs(pos.y) <= kCoordLimit &&
        std::abs(pos.z) <= kCoordLimit;
}

} // namespace

Dictionary SALegacyBridge::LoadRegion(const Vector3& saPosition) {
    if (!IsMainThread()) {
        std::lock_guard lock(s_PagerMutex);
        Dictionary result = Result(false, "load_region must run on Godot's main thread");
        result["publication_revision"] = m_PublicationRevision;
        return result;
    }

    std::lock_guard lock(s_PagerMutex);
    const auto failureResult = [this](const String& error, const String& errorCode = String(),
                                      const Dictionary& errorContext = Dictionary()) {
        Dictionary result = Result(false, error);
        if (!errorCode.is_empty()) {
            result["error_code"] = errorCode;
            result["error_context"] = errorContext;
        }
        result["publication_revision"] = m_PublicationRevision;
        return result;
    };
    if (!ValidRegionCoords(saPosition)) {
        return failureResult("SA_position must be finite and within the supported coordinate range");
    }
    if (!m_Ready || s_PagerOwner != this || !m_Worker) {
        return failureResult("load_region requires an open pager owned by this bridge");
    }
    // Sync and async never share the worker: an unpolled async request (even
    // a cancel ack) rejects sync with revision unchanged.
    if (m_ExposedActive) {
        Dictionary context;
        context["pending_request_id"] = static_cast<int64_t>(m_ExposedRequestId);
        context["pending_session_epoch"] = static_cast<int64_t>(m_ExposedEpoch);
        Dictionary result = failureResult(
            "an async region request is pending; poll or cancel it before sync load",
            "async_request_pending", context);
        return result;
    }
    if (m_NextRequestId >= kMaxGodotIntU64) {
        return failureResult("request sequence exhausted");
    }
    if (m_SessionEpoch == 0 || m_SessionEpoch > kMaxGodotIntU64) {
        return failureResult("invalid session epoch");
    }
    const uint64_t requestId = m_NextRequestId + 1;
    const uint64_t epoch = m_SessionEpoch;
    const RegionRequest req{saPosition.x, saPosition.y, saPosition.z, requestId, epoch};
    if (!m_Worker->Submit(req)) {
        // ID consumed (never reused). No exposed update, revision unchanged.
        m_NextRequestId = requestId;
        return failureResult("region worker rejected the sync request");
    }
    m_NextRequestId = requestId;

    // Sync diagnostics use the SAME conversion stepper run-to-completion with
    // explicit unbudgeted flush (no quota). Retiring is flushed first so no
    // mixed generations; conversion must be null because async overlap was
    // rejected above (defensive discard+flush if somehow present).
    FlushRetiringUnbudgetedLocked();
    if (m_Conversion) {
        DiscardConversionToRetiringLocked();
        FlushRetiringUnbudgetedLocked();
    }

    std::unique_ptr<RawRegionPacket> packet;
    const RegionWait waitState = m_Worker->Wait(requestId, packet);
    if (waitState == RegionWait::Stopped) {
        Dictionary result = failureResult("region worker stopped", "worker_stopped", Dictionary());
        result["request_id"] = static_cast<int64_t>(requestId);
        result["session_epoch"] = static_cast<int64_t>(epoch);
        return result;
    }
    if (waitState == RegionWait::Superseded) {
        Dictionary result =
            failureResult("region request superseded", "superseded", Dictionary());
        result["request_id"] = static_cast<int64_t>(requestId);
        result["session_epoch"] = static_cast<int64_t>(epoch);
        return result;
    }
    if (waitState == RegionWait::Cancelled) {
        Dictionary result = failureResult("region request cancelled", "cancelled", Dictionary());
        result["request_id"] = static_cast<int64_t>(requestId);
        result["session_epoch"] = static_cast<int64_t>(epoch);
        return result;
    }
    if (waitState != RegionWait::Ready || !packet) {
        Dictionary result =
            failureResult("region worker returned no packet", "worker_stopped", Dictionary());
        result["request_id"] = static_cast<int64_t>(requestId);
        result["session_epoch"] = static_cast<int64_t>(epoch);
        return result;
    }
    // Raw header check before any GPU work.
    if (packet->Request.RequestId != requestId || packet->Request.SessionEpoch != epoch) {
        m_Worker->Retire(std::move(packet));
        Dictionary result = failureResult("stale region packet", "stale_packet", Dictionary());
        result["request_id"] = static_cast<int64_t>(requestId);
        result["session_epoch"] = static_cast<int64_t>(epoch);
        return result;
    }
    // SAME stepper run-to-completion, explicit unbudgeted (diagnostic path).
    {
        String convError;
        String convCode;
        Dictionary convContext;
        if (!InitConversionLocked(std::move(packet), convError, convCode, convContext)) {
            Dictionary result = failureResult(convError, convCode, convContext);
            result["request_id"] = static_cast<int64_t>(requestId);
            result["session_epoch"] = static_cast<int64_t>(epoch);
            return result;
        }
        String stepError;
        AdvanceOutcome outcome =
            AdvanceConversionLocked(std::numeric_limits<int64_t>::max(), stepError);
        while (outcome == AdvanceOutcome::NeedMore) {
            outcome = AdvanceConversionLocked(std::numeric_limits<int64_t>::max(), stepError);
        }
        if (outcome == AdvanceOutcome::Error) {
            DiscardConversionToRetiringLocked();
            FlushRetiringUnbudgetedLocked();
            Dictionary result = failureResult(stepError);
            result["request_id"] = static_cast<int64_t>(requestId);
            result["session_epoch"] = static_cast<int64_t>(epoch);
            return result;
        }
        Dictionary prepared = BuildReadyPayloadLocked();
        prepared["request_id"] = static_cast<int64_t>(requestId);
        prepared["session_epoch"] = static_cast<int64_t>(epoch);
        return prepared;
    }
}

Dictionary SALegacyBridge::SubmitRegion(const Vector3& saPosition) {
    if (!IsMainThread()) {
        std::lock_guard lock(s_PagerMutex);
        Dictionary result = Result(false, "submit_region must run on Godot's main thread");
        result["request_id"] = int64_t{0};
        result["session_epoch"] = static_cast<int64_t>(m_SessionEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        return result;
    }
    std::lock_guard lock(s_PagerMutex);
    const auto failure = [this](const String& error) {
        Dictionary result = Result(false, error);
        result["request_id"] = int64_t{0};
        result["session_epoch"] = static_cast<int64_t>(m_SessionEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        return result;
    };
    if (!ValidRegionCoords(saPosition)) {
        return failure("SA_position must be finite and within the supported coordinate range");
    }
    if (!m_Ready || s_PagerOwner != this || !m_Worker) {
        return failure("submit_region requires an open pager owned by this bridge");
    }
    if (m_NextRequestId >= kMaxGodotIntU64) {
        return failure("request sequence exhausted");
    }
    if (m_SessionEpoch == 0 || m_SessionEpoch > kMaxGodotIntU64) {
        return failure("invalid session epoch");
    }
    const uint64_t requestId = m_NextRequestId + 1;
    const uint64_t epoch = m_SessionEpoch;
    const RegionRequest req{saPosition.x, saPosition.y, saPosition.z, requestId, epoch};
    if (!m_Worker->Submit(req)) {
        // Consume the ID (never reuse), keep the old exposed request intact.
        m_NextRequestId = requestId;
        return failure("region worker rejected the async request");
    }
    m_NextRequestId = requestId;
    // Latest-only: a superseded unpolled request counts as discarded stale.
    if (m_ExposedActive) {
        if (m_DiscardedStale < std::numeric_limits<int64_t>::max()) {
            ++m_DiscardedStale;
        }
    }
    m_ExposedActive = true;
    m_ExposedRequestId = requestId;
    m_ExposedEpoch = epoch;
    // A new submit wins over any pending cancel ack.
    m_ExposedCancelled = false;

    Dictionary result = Result(true);
    result["request_id"] = static_cast<int64_t>(requestId);
    result["session_epoch"] = static_cast<int64_t>(epoch);
    result["discarded_stale"] = m_DiscardedStale;
    result["publication_revision"] = m_PublicationRevision;
    return result;
}

Dictionary SALegacyBridge::PollRegion() {
    if (!IsMainThread()) {
        std::lock_guard lock(s_PagerMutex);
        Dictionary result = Result(false, "poll_region must run on Godot's main thread");
        result["status"] = "error";
        result["request_id"] = int64_t{0};
        result["session_epoch"] = static_cast<int64_t>(m_SessionEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        result["progress"] = BuildProgressLocked("idle", 0, 0);
        return result;
    }
    std::lock_guard lock(s_PagerMutex);
    int64_t budget = m_BudgetItems;
    if (budget < kMinBudgetItems || budget > kMaxBudgetItems) {
        budget = kDefaultBudgetItems;
    }
    // One shared quota per call: retire first, then convert with remainder.
    int64_t quota = budget;
    const int64_t retireBefore = RetirePendingLocked();
    const int64_t drainFirst = retireBefore < quota ? retireBefore : quota;
    if (drainFirst > 0) {
        DrainRetiringLocked(drainFirst);
        quota -= drainFirst;
    }
    int64_t retireAfterDrain = RetirePendingLocked();

    const auto idleWithProgress = [this](const String& phase) {
        Dictionary result = Result(false, "");
        result["status"] = "idle";
        result["request_id"] = int64_t{0};
        result["session_epoch"] = static_cast<int64_t>(m_SessionEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        result["progress"] = BuildProgressLocked(phase, 0, 0);
        return result;
    };
    if (!m_Ready || s_PagerOwner != this || !m_Worker) {
        // Even idle drains retiring above so the lab can pump to empty.
        return idleWithProgress(retireAfterDrain > 0 ? "retiring" : "idle");
    }

    // --- Current conversion (preparing) takes precedence over worker queue.
    if (m_Conversion) {
        const uint64_t convId = m_Conversion->requestId;
        const uint64_t convEpoch = m_Conversion->epoch;
        const bool superseded =
            !m_ExposedActive || m_ExposedRequestId != convId || m_ExposedEpoch != convEpoch;
        if (superseded) {
            if (m_Worker && convId != 0) {
                (void)m_Worker->Cancel(convId);
            }
            DiscardConversionToRetiringLocked();
            if (m_ExposedActive) {
                const uint64_t newId = m_ExposedRequestId;
                const uint64_t newEpoch = m_ExposedEpoch;
                Dictionary result = Result(false, "");
                result["status"] = "pending";
                result["request_id"] = static_cast<int64_t>(newId);
                result["session_epoch"] = static_cast<int64_t>(newEpoch);
                result["discarded_stale"] = m_DiscardedStale;
                result["publication_revision"] = m_PublicationRevision;
                result["progress"] = BuildProgressLocked("retiring", 0, 0);
                return result;
            }
            return idleWithProgress("retiring");
        }
        if (m_ExposedActive && m_ExposedCancelled && m_ExposedRequestId == convId) {
            if (m_Worker) {
                (void)m_Worker->Cancel(convId);
            }
            DiscardConversionToRetiringLocked();
            m_ExposedActive = false;
            m_ExposedRequestId = 0;
            m_ExposedEpoch = 0;
            m_ExposedCancelled = false;
            Dictionary result = Result(false, "region request cancelled");
            result["error_code"] = "cancelled";
            result["error_context"] = Dictionary();
            result["status"] = "cancelled";
            result["request_id"] = static_cast<int64_t>(convId);
            result["session_epoch"] = static_cast<int64_t>(convEpoch);
            result["discarded_stale"] = m_DiscardedStale;
            result["publication_revision"] = m_PublicationRevision;
            result["progress"] = BuildProgressLocked("retiring", 0, 0);
            return result;
        }
        if (retireAfterDrain > 0) {
            Dictionary result = Result(false, "");
            result["status"] = "preparing";
            result["request_id"] = static_cast<int64_t>(convId);
            result["session_epoch"] = static_cast<int64_t>(convEpoch);
            result["discarded_stale"] = m_DiscardedStale;
            result["publication_revision"] = m_PublicationRevision;
            result["progress"] = BuildProgressLocked(
                "retiring", ConversionDoneLocked(), ConversionTotalLocked());
            return result;
        }
        if (!ConversionMatchesExposedLocked()) {
            Dictionary result = Result(false, "");
            result["status"] = "preparing";
            result["request_id"] = static_cast<int64_t>(convId);
            result["session_epoch"] = static_cast<int64_t>(convEpoch);
            result["discarded_stale"] = m_DiscardedStale;
            result["publication_revision"] = m_PublicationRevision;
            result["progress"] = BuildProgressLocked(
                ConversionPhaseLocked(), ConversionDoneLocked(), ConversionTotalLocked());
            return result;
        }
        String stepError;
        const AdvanceOutcome outcome = AdvanceConversionLocked(quota, stepError);
        if (outcome == AdvanceOutcome::NeedMore) {
            Dictionary result = Result(false, "");
            result["status"] = "preparing";
            result["request_id"] = static_cast<int64_t>(convId);
            result["session_epoch"] = static_cast<int64_t>(convEpoch);
            result["discarded_stale"] = m_DiscardedStale;
            result["publication_revision"] = m_PublicationRevision;
            result["progress"] = BuildProgressLocked(
                ConversionPhaseLocked(), ConversionDoneLocked(), ConversionTotalLocked());
            return result;
        }
        if (outcome == AdvanceOutcome::Error) {
            const String errPhase = ConversionPhaseLocked();
            const int64_t errDone = ConversionDoneLocked();
            const int64_t errTotal = ConversionTotalLocked();
            DiscardConversionToRetiringLocked();
            m_ExposedActive = false;
            m_ExposedRequestId = 0;
            m_ExposedEpoch = 0;
            m_ExposedCancelled = false;
            Dictionary result = Result(false, stepError);
            result["status"] = "error";
            result["request_id"] = static_cast<int64_t>(convId);
            result["session_epoch"] = static_cast<int64_t>(convEpoch);
            result["discarded_stale"] = m_DiscardedStale;
            result["publication_revision"] = m_PublicationRevision;
            result["progress"] = BuildProgressLocked(errPhase, errDone, errTotal);
            return result;
        }
        const int64_t readyTotal = ConversionTotalLocked();
        Dictionary prepared = BuildReadyPayloadLocked();
        m_ExposedActive = false;
        m_ExposedRequestId = 0;
        m_ExposedEpoch = 0;
        m_ExposedCancelled = false;
        prepared["status"] = "ready";
        prepared["request_id"] = static_cast<int64_t>(convId);
        prepared["session_epoch"] = static_cast<int64_t>(convEpoch);
        prepared["discarded_stale"] = m_DiscardedStale;
        prepared["progress"] = BuildProgressLocked("paired", readyTotal, readyTotal);
        return prepared;
    }

    // --- No conversion: idle or worker-driven exposed request.
    if (!m_ExposedActive) {
        return idleWithProgress(retireAfterDrain > 0 ? "retiring" : "idle");
    }
    const uint64_t exposedId = m_ExposedRequestId;
    const uint64_t exposedEpoch = m_ExposedEpoch;
    const bool exposedWasCancelled = m_ExposedCancelled;
    if (exposedWasCancelled) {
        // Cancellation acknowledgement does not wait for an older generation's
        // GPU frees. Idle polls keep draining that generation after this terminal.
        m_ExposedActive = false;
        m_ExposedRequestId = 0;
        m_ExposedEpoch = 0;
        m_ExposedCancelled = false;
        Dictionary result = Result(false, "region request cancelled");
        result["status"] = "cancelled";
        result["error_code"] = "cancelled";
        result["request_id"] = static_cast<int64_t>(exposedId);
        result["session_epoch"] = static_cast<int64_t>(exposedEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        result["progress"] = BuildProgressLocked(retireAfterDrain > 0 ? "retiring" : "queued", 0, 0);
        return result;
    }
    if (retireAfterDrain > 0) {
        Dictionary result = Result(false, "");
        result["status"] = "pending";
        result["request_id"] = static_cast<int64_t>(exposedId);
        result["session_epoch"] = static_cast<int64_t>(exposedEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        result["progress"] = BuildProgressLocked("retiring", 0, 0);
        return result;
    }
    std::unique_ptr<RawRegionPacket> packet;
    const RegionWait state = m_Worker->TryPoll(exposedId, packet);

    if (state == RegionWait::Pending) {
        Dictionary result = Result(false, "");
        result["status"] = "pending";
        result["request_id"] = static_cast<int64_t>(exposedId);
        result["session_epoch"] = static_cast<int64_t>(exposedEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        result["progress"] = BuildProgressLocked("queued", 0, 0);
        return result;
    }
    if (state == RegionWait::Cancelled) {
        m_ExposedActive = false;
        m_ExposedRequestId = 0;
        m_ExposedEpoch = 0;
        m_ExposedCancelled = false;
        Dictionary result = Result(false, "region request cancelled");
        result["error_code"] = "cancelled";
        result["error_context"] = Dictionary();
        result["status"] = "cancelled";
        result["request_id"] = static_cast<int64_t>(exposedId);
        result["session_epoch"] = static_cast<int64_t>(exposedEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        result["progress"] = BuildProgressLocked("queued", 0, 0);
        return result;
    }
    if (state == RegionWait::Stopped) {
        m_ExposedActive = false;
        m_ExposedRequestId = 0;
        m_ExposedEpoch = 0;
        m_ExposedCancelled = false;
        Dictionary result = Result(false, "region worker stopped");
        result["error_code"] = "worker_stopped";
        result["error_context"] = Dictionary();
        result["status"] = "error";
        result["request_id"] = static_cast<int64_t>(exposedId);
        result["session_epoch"] = static_cast<int64_t>(exposedEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        result["progress"] = BuildProgressLocked("queued", 0, 0);
        return result;
    }
    if (state == RegionWait::Superseded) {
        m_ExposedActive = false;
        m_ExposedRequestId = 0;
        m_ExposedEpoch = 0;
        m_ExposedCancelled = false;
        Dictionary result = Result(false, "region request superseded");
        result["error_code"] = "superseded";
        result["error_context"] = Dictionary();
        result["status"] = "error";
        result["request_id"] = static_cast<int64_t>(exposedId);
        result["session_epoch"] = static_cast<int64_t>(exposedEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        result["progress"] = BuildProgressLocked("queued", 0, 0);
        return result;
    }
    if (state != RegionWait::Ready || !packet) {
        m_ExposedActive = false;
        m_ExposedRequestId = 0;
        m_ExposedEpoch = 0;
        m_ExposedCancelled = false;
        Dictionary result = Result(false, "region worker returned no packet");
        result["error_code"] = "worker_stopped";
        result["error_context"] = Dictionary();
        result["status"] = "error";
        result["request_id"] = static_cast<int64_t>(exposedId);
        result["session_epoch"] = static_cast<int64_t>(exposedEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        result["progress"] = BuildProgressLocked("queued", 0, 0);
        return result;
    }
    if (packet->Request.RequestId != exposedId || packet->Request.SessionEpoch != exposedEpoch ||
        exposedEpoch != m_SessionEpoch) {
        m_Worker->Retire(std::move(packet));
        m_ExposedActive = false;
        m_ExposedRequestId = 0;
        m_ExposedEpoch = 0;
        m_ExposedCancelled = false;
        Dictionary result = Result(false, "stale region packet");
        result["error_code"] = "stale_packet";
        result["error_context"] = Dictionary();
        result["status"] = "error";
        result["request_id"] = static_cast<int64_t>(exposedId);
        result["session_epoch"] = static_cast<int64_t>(exposedEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        result["progress"] = BuildProgressLocked("queued", 0, 0);
        return result;
    }
    if (exposedWasCancelled) {
        m_Worker->Retire(std::move(packet));
        m_ExposedActive = false;
        m_ExposedRequestId = 0;
        m_ExposedEpoch = 0;
        m_ExposedCancelled = false;
        Dictionary result = Result(false, "region request cancelled");
        result["error_code"] = "cancelled";
        result["error_context"] = Dictionary();
        result["status"] = "cancelled";
        result["request_id"] = static_cast<int64_t>(exposedId);
        result["session_epoch"] = static_cast<int64_t>(exposedEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        result["progress"] = BuildProgressLocked("queued", 0, 0);
        return result;
    }
    String initError;
    String initCode;
    Dictionary initContext;
    if (!InitConversionLocked(std::move(packet), initError, initCode, initContext)) {
        m_ExposedActive = false;
        m_ExposedRequestId = 0;
        m_ExposedEpoch = 0;
        m_ExposedCancelled = false;
        Dictionary result = Result(false, initError);
        if (!initCode.is_empty()) {
            result["error_code"] = initCode;
            result["error_context"] = initContext;
        }
        result["status"] = "error";
        result["request_id"] = static_cast<int64_t>(exposedId);
        result["session_epoch"] = static_cast<int64_t>(exposedEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        result["progress"] = BuildProgressLocked("planning", 0, 0);
        return result;
    }
    String stepError;
    const AdvanceOutcome outcome = AdvanceConversionLocked(quota, stepError);
    if (outcome == AdvanceOutcome::NeedMore) {
        Dictionary result = Result(false, "");
        result["status"] = "preparing";
        result["request_id"] = static_cast<int64_t>(exposedId);
        result["session_epoch"] = static_cast<int64_t>(exposedEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        result["progress"] = BuildProgressLocked(
            ConversionPhaseLocked(), ConversionDoneLocked(), ConversionTotalLocked());
        return result;
    }
    if (outcome == AdvanceOutcome::Error) {
        const String errPhase = ConversionPhaseLocked();
        const int64_t errDone = ConversionDoneLocked();
        const int64_t errTotal = ConversionTotalLocked();
        DiscardConversionToRetiringLocked();
        m_ExposedActive = false;
        m_ExposedRequestId = 0;
        m_ExposedEpoch = 0;
        m_ExposedCancelled = false;
        Dictionary result = Result(false, stepError);
        result["status"] = "error";
        result["request_id"] = static_cast<int64_t>(exposedId);
        result["session_epoch"] = static_cast<int64_t>(exposedEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        result["progress"] = BuildProgressLocked(errPhase, errDone, errTotal);
        return result;
    }
    const int64_t readyTotal = ConversionTotalLocked();
    Dictionary prepared = BuildReadyPayloadLocked();
    m_ExposedActive = false;
    m_ExposedRequestId = 0;
    m_ExposedEpoch = 0;
    m_ExposedCancelled = false;
    prepared["status"] = "ready";
    prepared["request_id"] = static_cast<int64_t>(exposedId);
    prepared["session_epoch"] = static_cast<int64_t>(exposedEpoch);
    prepared["discarded_stale"] = m_DiscardedStale;
    prepared["progress"] = BuildProgressLocked("paired", readyTotal, readyTotal);
    return prepared;
}

Dictionary SALegacyBridge::CancelRegion(int64_t requestId) {
    if (!IsMainThread()) {
        Dictionary result = Result(false, "cancel_region must run on Godot's main thread");
        result["request_id"] = requestId;
        return result;
    }
    std::lock_guard lock(s_PagerMutex);
    const auto failure = [&](const String& error) {
        Dictionary result = Result(false, error);
        result["request_id"] = requestId;
        result["session_epoch"] = static_cast<int64_t>(m_SessionEpoch);
        result["discarded_stale"] = m_DiscardedStale;
        result["publication_revision"] = m_PublicationRevision;
        return result;
    };
    if (requestId <= 0) {
        return failure("unknown region request");
    }
    if (!m_Ready || s_PagerOwner != this || !m_Worker) {
        return failure("cancel_region requires an open pager owned by this bridge");
    }
    // Only the latest exposed pending ID cancels; old/cancelled fail.
    // Taken (already moved into the single current conversion) is locally
    // cancellable: Worker.Cancel may return false because Taken, not an error.
    if (!m_ExposedActive || m_ExposedCancelled ||
        static_cast<uint64_t>(requestId) != m_ExposedRequestId) {
        return failure("unknown region request");
    }
    const bool workerCancelled = m_Worker->Cancel(static_cast<uint64_t>(requestId));
    if (!workerCancelled) {
        const bool takenLocally = m_Conversion && m_Conversion->requestId ==
            static_cast<uint64_t>(requestId);
        if (!takenLocally) {
            return failure("unknown region request");
        }
    }
    // Cancel ack stays one-shot until poll; a superseding Submit clears it.
    m_ExposedCancelled = true;
    Dictionary result = Result(true);
    result["request_id"] = requestId;
    result["session_epoch"] = static_cast<int64_t>(m_ExposedEpoch);
    result["discarded_stale"] = m_DiscardedStale;
    result["publication_revision"] = m_PublicationRevision;
    return result;
}

Dictionary SALegacyBridge::Environment(const String& weather, int32_t hour) {
    if (!IsMainThread()) {
        return Result(false, "environment must run on Godot's main thread");
    }
    if (hour < 0 || hour >= 24) {
        return Result(false, "hour must be in [0,23]");
    }
    const std::string weatherName = Utf8(weather);
    if (weatherName.empty() || std::strlen(weatherName.c_str()) != weatherName.size()) {
        return Result(false, "weather must be a nonempty ASCII section name");
    }

    std::lock_guard lock(s_PagerMutex);
    if (!m_Ready || s_PagerOwner != this) {
        return Result(false, "environment requires an open pager owned by this bridge");
    }

    size_t sample = 0;
    while (sample + 1 < 8 && hour >= kSampleHours[sample + 1]) {
        ++sample;
    }
    const int firstHour = kSampleHours[sample];
    const int secondHour = kSampleHours[sample + 1] == 24 ? 0 : kSampleHours[sample + 1];
    TimeCycleParams first{};
    TimeCycleParams second{};
    char error[256]{};
    if (!TimeCycle_LoadWeatherHour(m_GameDir.c_str(), weatherName.c_str(), firstHour,
                                   first, error, sizeof(error)) ||
        !TimeCycle_LoadWeatherHour(m_GameDir.c_str(), weatherName.c_str(), secondHour,
                                   second, error, sizeof(error))) {
        return Result(false, ErrorString(error));
    }
    if (first.sampleIdx != static_cast<int>(sample) ||
        second.sampleIdx != static_cast<int>((sample + 1) % 8)) {
        return Result(false, "weather section does not contain the required eight timecycle samples");
    }
    if (!Finite(first.farClp) || !Finite(second.farClp) || !Finite(first.fogSt) ||
        !Finite(second.fogSt)) {
        return Result(false, "timecycle rows lack finite environment fields");
    }
    const float weight = static_cast<float>(hour - kSampleHours[sample]) /
        static_cast<float>(kSampleHours[sample + 1] - kSampleHours[sample]);
    const float directional = std::lerp(first.directionalMult, second.directionalMult, weight)
        * 0.99609375f;
    const float fogStart = std::lerp(first.fogSt, second.fogSt, weight);
    const float farClip = std::lerp(first.farClp, second.farClp, weight);
    if (!Finite(directional) || directional < 0.0f || directional > 16.0f ||
        !Finite(fogStart) || !Finite(farClip) || farClip <= 0.0f || farClip <= fogStart) {
        return Result(false, "interpolated timecycle environment is out of range");
    }

    const float nightBlend = hour < 6 ? 1.0f : hour < 7 ? 7.0f - hour :
        hour < 20 ? 0.0f : hour < 21 ? hour - 20.0f : 1.0f;
    Dictionary result = Result(true);
    result["ambient"] = InterpolateRgb(first.amb, second.amb, weight);
    result["ambient_objects"] = InterpolateRgb(first.ambObjects, second.ambObjects, weight);
    result["directional"] = Color(directional, directional, directional, 1.0f);
    // The owned PC file has 51 columns, without optional DirMult. Match the
    // native environment's explicitly disabled missing-row directional term;
    // never substitute an invented sun strength or the unrelated Dir RGB.
    result["directional_available"] = first.hasDirectionalMult && second.hasDirectionalMult;
    if (!first.hasPostFx || !second.hasPostFx) {
        return Result(false, "missing or invalid PC timecycle post columns");
    }
    for (int pass = 0; pass < 2; ++pass) {
        Color color = InterpolateRgb(first.postFx[pass], second.postFx[pass], weight);
        color.a = (first.postFx[pass][3] * (1.0f - weight) + second.postFx[pass][3] * weight) / 255.0f;
        result[pass == 0 ? "post_pass1" : "post_pass2"] = color;
    }
    result["sky_top"] = InterpolateRgb(first.skyTop, second.skyTop, weight);
    result["sky_bottom"] = InterpolateRgb(first.skyBot, second.skyBot, weight);
    result["fog_start"] = fogStart;
    result["far_clip"] = farClip;
    result["night_blend"] = nightBlend;
    result["hour"] = hour;
    result["weather"] = weather;
    return result;
}

void SALegacyBridge::CloseGame() {
    std::unique_ptr<RegionWorker> worker;
    std::unique_ptr<RawRegionPacket> ownedRaw;
    uint64_t cancelId = 0;
    bool hadExposed = false;
    {
        std::unique_lock<std::mutex> lock(s_PagerMutex);
        if (!m_Ready) {
            if (m_Worker) {
                // Explicit unbudgeted teardown flush: staged Godot holds are
                // destroyed here on main, owned partial raw returns to the
                // worker BEFORE Stop/join (never inline heavy destroy).
                if (m_Conversion) {
                    ownedRaw = std::move(m_Conversion->raw);
                    m_Conversion.reset();
                }
                worker = std::move(m_Worker);
                if (ownedRaw) {
                    worker->Retire(std::move(ownedRaw));
                }
                FlushRetiringUnbudgetedLocked();
                m_ExposedActive = false;
                m_ExposedRequestId = 0;
                m_ExposedEpoch = 0;
                m_ExposedCancelled = false;
            } else {
                m_GameDir.clear();
                m_Catalog.reset();
                m_Decision = NativeLodChainDecision{};
                m_ChildPlacement = NativeCollisionPlacement{};
                m_ParentPlacement = NativeCollisionPlacement{};
                m_EffectiveCol.reset();
                m_EffectiveColLibrary.clear();
                m_HasLodPair = false;
                return;
            }
        } else {
            // Capture the sole-owner worker; keep m_Ready/owner set across the
            // unlock window so a concurrent Open fails instead of racing Init.
            // Explicit unbudgeted flush first: retire owned partial raw on the
            // worker BEFORE Stop, destroy staged/retiring Godot holds on main.
            if (m_Conversion) {
                ownedRaw = std::move(m_Conversion->raw);
                m_Conversion.reset();
            }
            worker = std::move(m_Worker);
            if (ownedRaw) {
                worker->Retire(std::move(ownedRaw));
            }
            FlushRetiringUnbudgetedLocked();
            hadExposed = m_ExposedActive;
            cancelId = m_ExposedRequestId;
            m_ExposedActive = false;
            m_ExposedRequestId = 0;
            m_ExposedEpoch = 0;
            m_ExposedCancelled = false;
        }
        // JOIN without holding s_PagerMutex: the parser thread never needs it
        // (pure StreamPager_Update/Counters/BuildPlan on the worker), so no
        // deadlock. Stop JOIN stays outside the global mutex, before RW shutdown.
        lock.unlock();
        if (worker) {
            if (hadExposed && cancelId != 0) {
                (void)worker->Cancel(cancelId);
            }
            // Stop joins the parser (in-flight parse finishes, result
            // discarded) before any StreamPager_Shutdown below.
            worker->Stop();
        }
        lock.lock();
        if (s_PagerOwner == this) {
            StreamPager_Shutdown();
            s_PagerOwner = nullptr;
        }
        m_GameDir.clear();
        m_Ready = false;
        // Clear pair owners; returned Godot packed arrays already own their bytes.
        // m_PublicationRevision, m_SessionEpoch, m_NextRequestId,
        // m_DiscardedStale, m_StagedDiscards and m_BudgetItems are intentionally
        // preserved across close/reopen. m_Conversion/m_Retiring are empty here
        // (explicit unbudgeted flush above).
        m_Catalog.reset();
        m_Decision = NativeLodChainDecision{};
        m_ChildPlacement = NativeCollisionPlacement{};
        m_ParentPlacement = NativeCollisionPlacement{};
        m_EffectiveCol.reset();
        m_EffectiveColLibrary.clear();
        m_HasLodPair = false;
    }
}

} // namespace godot
