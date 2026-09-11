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

#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <limits>
#include <map>
#include <mutex>
#include <string>
#include <tuple>
#include <vector>

namespace godot {
namespace {

constexpr float kMinRadius = 1.0f;
constexpr float kMaxRadius = 2000.0f;
constexpr int32_t kMaxInstances = 4096;
constexpr size_t kMaxSceneTriangles = 8'000'000;
constexpr size_t kMaxSceneImages = 4096;
constexpr size_t kMaxImageBytes = 512ull * 1024ull * 1024ull;
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

bool ValidUnit(float value) {
    return Finite(value) && value >= 0.0f && value <= 1.0f;
}

struct ValidationFailure {
    String error;
    String errorCode;
    Dictionary errorContext;
};

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

void SetNonfiniteUvFailure(const WorldShotMesh& mesh, size_t uvIndex, float value,
                           ValidationFailure& failure) {
    const size_t triangle = uvIndex / 6;
    const auto& surface = mesh.surfaces[triangle];
    const String model = SourceString(mesh.sourceModelName);
    failure.error = String("pager returned nonfinite UV for model '") + model +
        "' (id " + String::num_int64(mesh.sourceModelId) + ")";
    failure.errorCode = "nonfinite_uv";
    failure.errorContext["archive"] = SourceString(mesh.sourceArchiveName);
    failure.errorContext["model"] = model;
    failure.errorContext["model_id"] = mesh.sourceModelId;
    failure.errorContext["txd"] = SourceString(mesh.sourceTxdName);
    failure.errorContext["placement_id"] = static_cast<int64_t>(mesh.sourcePlacementId);
    failure.errorContext["geometry"] = surface.sourceGeometry;
    failure.errorContext["triangle"] = surface.sourceTriangle;
    failure.errorContext["material_slot"] = surface.sourceMaterial;
    failure.errorContext["uv_component"] = (uvIndex % 2 == 0) ? "u" : "v";
    failure.errorContext["value"] = NonfiniteName(value);
}

void SetTextureIdentityFailure(const WorldShotMesh& mesh, size_t triangle, int imageIndex,
                               const WorldShotImage& image, const char* reason,
                               ValidationFailure& failure) {
    const auto& surface = mesh.surfaces[triangle];
    failure.error = String("pager returned invalid texture identity for model '") +
        SourceString(mesh.sourceModelName) + "' (id " + String::num_int64(mesh.sourceModelId) +
        "), image " + String::num_int64(imageIndex) + ": " + reason;
    failure.errorCode = "invalid_texture_identity";
    failure.errorContext["archive"] = SourceString(mesh.sourceArchiveName);
    failure.errorContext["model"] = SourceString(mesh.sourceModelName);
    failure.errorContext["model_id"] = mesh.sourceModelId;
    failure.errorContext["txd"] = SourceString(mesh.sourceTxdName);
    failure.errorContext["placement_id"] = static_cast<int64_t>(mesh.sourcePlacementId);
    failure.errorContext["geometry"] = surface.sourceGeometry;
    failure.errorContext["triangle"] = surface.sourceTriangle;
    failure.errorContext["material_slot"] = surface.sourceMaterial;
    failure.errorContext["image_index"] = imageIndex;
    failure.errorContext["reason"] = reason;
    if (image.hasSourceIdentity) {
        failure.errorContext["texture_identity"] = TextureIdentity(image);
    }
}

bool ValidateTextureIdentity(const WorldShotMesh& mesh, size_t triangle, int imageIndex,
                             const WorldShotImage& image, ValidationFailure& failure) {
    const auto reject = [&](const char* reason) {
        SetTextureIdentityFailure(mesh, triangle, imageIndex, image, reason, failure);
        return false;
    };
    if (!image.hasSourceIdentity) {
        return reject("missing_source_identity");
    }
    const auto& identity = image.sourceIdentity;
    if (identity.lineage.empty()) {
        return reject("empty_lineage");
    }
    if (std::any_of(identity.lineage.begin(), identity.lineage.end(), [](const auto& member) {
            return member.archive.empty() || member.member.empty();
        })) {
        return reject("incomplete_lineage_member");
    }
    if (identity.owner.archive.empty() || identity.owner.member.empty()) {
        return reject("incomplete_owner");
    }
    if (identity.name.empty()) {
        return reject("empty_name");
    }
    if (std::find(identity.lineage.begin(), identity.lineage.end(), identity.owner) ==
        identity.lineage.end()) {
        return reject("owner_not_in_lineage");
    }
    if (identity.filter != image.filter) {
        return reject("filter_mismatch");
    }
    return true;
}

bool ValidateScene(const WorldShotScene& scene, ValidationFailure& failure) {
    if (scene.meshes.empty()) {
        failure.error = "pager returned no meshes";
        return false;
    }
    if (scene.images.size() > kMaxSceneImages) {
        failure.error = "pager returned too many images";
        return false;
    }

    size_t imageBytes = 0;
    for (const auto& image : scene.images) {
        if (image.w <= 0 || image.h <= 0 || image.w > 4096 || image.h > 4096) {
            failure.error = "decoded texture dimensions are out of range";
            return false;
        }
        const size_t pixels = static_cast<size_t>(image.w) * static_cast<size_t>(image.h);
        if (pixels > std::numeric_limits<size_t>::max() / 4 || image.rgba.size() != pixels * 4) {
            failure.error = "decoded texture byte size is invalid";
            return false;
        }
        if (imageBytes > kMaxImageBytes - image.rgba.size()) {
            failure.error = "decoded texture publication exceeds the size limit";
            return false;
        }
        imageBytes += image.rgba.size();
    }

    size_t sceneTriangles = 0;
    for (const auto& mesh : scene.meshes) {
        if (mesh.tris <= 0) {
            failure.error = "pager returned a mesh with no triangles";
            return false;
        }
        const size_t triangles = static_cast<size_t>(mesh.tris);
        if (triangles > kMaxSceneTriangles || sceneTriangles > kMaxSceneTriangles - triangles) {
            failure.error = "pager scene exceeds the triangle limit";
            return false;
        }
        sceneTriangles += triangles;
        if (mesh.pos.size() != triangles * 9 || mesh.nrm.size() != triangles * 9 ||
            mesh.uv.size() != triangles * 6 || mesh.triImg.size() != triangles ||
            mesh.triCol.size() != triangles * 3 || mesh.dayColors.size() != triangles * 12 ||
            mesh.nightColors.size() != triangles * 12 || mesh.surfaces.size() != triangles) {
            failure.error = "pager mesh attribute sizes are inconsistent";
            return false;
        }
        for (float value : mesh.pos) {
            if (!Finite(value) || std::abs(value) > 1'000'000.0f) {
                failure.error = "pager position is nonfinite or out of range";
                return false;
            }
        }
        for (float value : mesh.nrm) {
            if (!Finite(value) || std::abs(value) > 1.001f) {
                failure.error = "pager normal is nonfinite or out of range";
                return false;
            }
        }
        for (size_t uvIndex = 0; uvIndex < mesh.uv.size(); ++uvIndex) {
            if (!Finite(mesh.uv[uvIndex])) {
                SetNonfiniteUvFailure(mesh, uvIndex, mesh.uv[uvIndex], failure);
                return false;
            }
        }
        for (float value : mesh.triCol) {
            if (!ValidUnit(value)) {
                failure.error = "pager material color is outside [0,1]";
                return false;
            }
        }
        for (size_t triangle = 0; triangle < triangles; ++triangle) {
            const int image = mesh.triImg[triangle];
            if (image < -1 || image >= static_cast<int>(scene.images.size())) {
                failure.errorCode = image == -2 ? "missing_texture" : "invalid_image_index";
                failure.error = String("pager material references an invalid image for model '") +
                    SourceString(mesh.sourceModelName) + "' txd '" + SourceString(mesh.sourceTxdName) +
                    "' triangle " + String::num_int64(mesh.surfaces[triangle].sourceTriangle);
                failure.errorContext["model"] = SourceString(mesh.sourceModelName);
                failure.errorContext["model_id"] = mesh.sourceModelId;
                failure.errorContext["txd"] = SourceString(mesh.sourceTxdName);
                failure.errorContext["archive"] = SourceString(mesh.sourceArchiveName);
                failure.errorContext["geometry"] = mesh.surfaces[triangle].sourceGeometry;
                failure.errorContext["triangle"] = mesh.surfaces[triangle].sourceTriangle;
                failure.errorContext["material_slot"] = mesh.surfaces[triangle].sourceMaterial;
                failure.errorContext["placement_id"] = static_cast<int64_t>(mesh.sourcePlacementId);
                return false;
            }
            if (image >= 0 && !ValidateTextureIdentity(
                    mesh, triangle, image, scene.images[static_cast<size_t>(image)], failure)) {
                return false;
            }
            const auto& surface = mesh.surfaces[triangle];
            if (!std::all_of(surface.color.begin(), surface.color.end(), ValidUnit) ||
                !Finite(surface.ambient) || !Finite(surface.diffuse) || surface.ambient < 0.0f ||
                surface.diffuse < 0.0f || surface.ambient > 16.0f || surface.diffuse > 16.0f) {
                failure.error = "pager surface values are nonfinite or out of range";
                return false;
            }
        }
    }
    return true;
}

enum class AlphaMode : int32_t { Opaque, Cutout, Blend };

AlphaMode MergeAlpha(AlphaMode current, uint8_t alpha) {
    if (alpha > 0 && alpha < 255) {
        return AlphaMode::Blend;
    }
    if (alpha == 0 && current == AlphaMode::Opaque) {
        return AlphaMode::Cutout;
    }
    return current;
}

std::vector<AlphaMode> ClassifyImages(const WorldShotScene& scene) {
    std::vector<AlphaMode> modes(scene.images.size(), AlphaMode::Opaque);
    for (size_t index = 0; index < scene.images.size(); ++index) {
        for (size_t byte = 3; byte < scene.images[index].rgba.size(); byte += 4) {
            modes[index] = MergeAlpha(modes[index], scene.images[index].rgba[byte]);
            if (modes[index] == AlphaMode::Blend) {
                break;
            }
        }
    }
    return modes;
}

AlphaMode ClassifyTriangle(const WorldShotMesh& mesh, size_t triangle,
                           const std::vector<AlphaMode>& imageModes) {
    const auto& surface = mesh.surfaces[triangle];
    if (surface.vehicleAlpha || surface.color[3] < 1.0f) {
        return AlphaMode::Blend;
    }
    AlphaMode mode = AlphaMode::Opaque;
    const int image = mesh.triImg[triangle];
    if (image >= 0) {
        mode = imageModes[static_cast<size_t>(image)];
    }
    for (size_t vertex = 0; vertex < 3; ++vertex) {
        const size_t alpha = triangle * 12 + vertex * 4 + 3;
        mode = MergeAlpha(mode, mesh.dayColors[alpha]);
        mode = MergeAlpha(mode, mesh.nightColors[alpha]);
        if (mesh.dayColors[alpha] != mesh.nightColors[alpha]) {
            mode = AlphaMode::Blend;
        }
    }
    return mode;
}

const char* AlphaName(AlphaMode mode) {
    switch (mode) {
    case AlphaMode::Opaque: return "opaque";
    case AlphaMode::Cutout: return "cutout";
    case AlphaMode::Blend: return "blend";
    }
    return "opaque";
}

using MaterialKey = std::tuple<int, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t,
                               int32_t, int, int>;

MaterialKey MakeMaterialKey(const WorldShotMesh& mesh, size_t triangle, AlphaMode alpha) {
    const auto& surface = mesh.surfaces[triangle];
    return {
        mesh.triImg[triangle],
        std::bit_cast<uint32_t>(surface.color[0]),
        std::bit_cast<uint32_t>(surface.color[1]),
        std::bit_cast<uint32_t>(surface.color[2]),
        std::bit_cast<uint32_t>(surface.color[3]),
        std::bit_cast<uint32_t>(surface.ambient),
        std::bit_cast<uint32_t>(surface.diffuse),
        static_cast<int32_t>(alpha),
        surface.sourceMaterial,
        surface.sourceGeometry,
    };
}

struct SurfaceGroup {
    size_t representative = 0;
    AlphaMode alpha = AlphaMode::Opaque;
    std::vector<size_t> triangles;
};

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

bool AddSurface(const WorldShotMesh& source, const SurfaceGroup& group, Ref<ArrayMesh>& mesh,
                Dictionary& material, const std::vector<Ref<ImageTexture>>& textures,
                const WorldShotScene& scene, String& error) {
    const size_t vertexCount = group.triangles.size() * 3;
    if (vertexCount == 0 || vertexCount > static_cast<size_t>(std::numeric_limits<int32_t>::max())) {
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

    size_t destination = 0;
    for (size_t triangle : group.triangles) {
        for (size_t vertex = 0; vertex < 3; ++vertex, ++destination) {
            const size_t xyz = triangle * 9 + vertex * 3;
            const size_t uv = triangle * 6 + vertex * 2;
            const size_t rgba = triangle * 12 + vertex * 4;
            // This basis has positive determinant, so SA/D3D clockwise order is retained.
            positions.set(static_cast<int64_t>(destination),
                Vector3(source.pos[xyz], source.pos[xyz + 2], -source.pos[xyz + 1]));
            normals.set(static_cast<int64_t>(destination),
                Vector3(source.nrm[xyz], source.nrm[xyz + 2], -source.nrm[xyz + 1]));
            uvs.set(static_cast<int64_t>(destination), Vector2(source.uv[uv], source.uv[uv + 1]));
            dayColors.set(static_cast<int64_t>(destination), Color(
                source.dayColors[rgba] / 255.0f,
                source.dayColors[rgba + 1] / 255.0f,
                source.dayColors[rgba + 2] / 255.0f,
                source.dayColors[rgba + 3] / 255.0f));
            for (size_t channel = 0; channel < 4; ++channel) {
                nightColors.set(static_cast<int64_t>(destination * 4 + channel),
                    source.nightColors[rgba + channel] / 255.0f);
            }
        }
    }

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

    const size_t triangle = group.representative;
    const auto& surface = source.surfaces[triangle];
    const int image = source.triImg[triangle];
    if (image >= 0) {
        material["texture"] = textures[static_cast<size_t>(image)];
        material["filter"] = static_cast<int64_t>(scene.images[static_cast<size_t>(image)].filter);
        material["texture_identity"] = TextureIdentity(scene.images[static_cast<size_t>(image)]);
    } else {
        material["texture"] = Variant();
        material["filter"] = int64_t{0};
        material["texture_identity"] = Dictionary();
    }
    material["color"] = Color(surface.color[0], surface.color[1], surface.color[2], surface.color[3]);
    material["ambient"] = static_cast<double>(surface.ambient);
    material["diffuse"] = static_cast<double>(surface.diffuse);
    material["alpha_mode"] = AlphaName(group.alpha);
    material["family"] = "world";
    material["source_model"] = SourceString(source.sourceModelName);
    material["source_material_slot"] = surface.sourceMaterial;
    material["source_geometry"] = surface.sourceGeometry;
    material["model_identity"] = ModelIdentity(source);
    material["geometry_identity"] = GeometryIdentity(source, surface);
    material["material_identity"] = MaterialIdentity(source, surface);
    return true;
}

bool MakeMesh(const WorldShotMesh& source, const WorldShotScene& scene,
              const std::vector<AlphaMode>& imageModes,
              const std::vector<Ref<ImageTexture>>& textures, Dictionary& output, String& error,
              int64_t& surfaceCount) {
    std::map<MaterialKey, size_t> groupIndex;
    std::vector<SurfaceGroup> groups;
    for (size_t triangle = 0; triangle < static_cast<size_t>(source.tris); ++triangle) {
        const AlphaMode alpha = ClassifyTriangle(source, triangle, imageModes);
        const auto key = MakeMaterialKey(source, triangle, alpha);
        auto [iterator, inserted] = groupIndex.emplace(key, groups.size());
        if (inserted) {
            groups.push_back({triangle, alpha, {}});
        }
        groups[iterator->second].triangles.push_back(triangle);
    }

    Ref<ArrayMesh> mesh;
    mesh.instantiate();
    TypedArray<Dictionary> materials;
    for (const auto& group : groups) {
        Dictionary material;
        if (!AddSurface(source, group, mesh, material, textures, scene, error)) {
            return false;
        }
        materials.push_back(material);
    }
    if (mesh.is_null() || mesh->get_surface_count() <= 0 ||
        mesh->get_surface_count() != materials.size()) {
        error = "ArrayMesh publication is incomplete";
        return false;
    }
    surfaceCount += mesh->get_surface_count();
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

void SALegacyBridge::_bind_methods() {
    ClassDB::bind_method(D_METHOD("open_game", "game_dir", "radius", "cap"), &SALegacyBridge::OpenGame);
    ClassDB::bind_method(D_METHOD("load_region", "SA_position"), &SALegacyBridge::LoadRegion);
    ClassDB::bind_method(D_METHOD("environment", "weather", "hour"), &SALegacyBridge::Environment);
    ClassDB::bind_method(D_METHOD("close_game"), &SALegacyBridge::CloseGame);
}

SALegacyBridge::~SALegacyBridge() {
    CloseGame();
}

Dictionary SALegacyBridge::OpenGame(const String& gameDir, float radius, int32_t cap) {
    if (!IsMainThread()) {
        return Result(false, "open_game must run on Godot's main thread");
    }
    if (!std::isfinite(radius) || radius < kMinRadius || radius > kMaxRadius) {
        return Result(false, "radius must be finite and in [1,2000]");
    }
    if (cap <= 0 || cap > kMaxInstances) {
        return Result(false, "cap must be in [1,4096]");
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

    m_GameDir = path;
    m_Ready = true;
    s_PagerOwner = this;
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
    return result;
}

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
    if (!Finite(saPosition.x) || !Finite(saPosition.y) || !Finite(saPosition.z) ||
        std::abs(saPosition.x) > 1'000'000.0f || std::abs(saPosition.y) > 1'000'000.0f ||
        std::abs(saPosition.z) > 1'000'000.0f) {
        return failureResult("SA_position must be finite and within the supported coordinate range");
    }

    if (!m_Ready || s_PagerOwner != this) {
        return failureResult("load_region requires an open pager owned by this bridge");
    }

    WorldShotScene scene{};
    E2EPagerFrame frame{};
    std::vector<NativePlacementIdentity> rendered;
    char nativeError[256]{};
    const std::shared_ptr<const NativePlacementOverrides> noOverrides;
    if (!StreamPager_Update(saPosition.x, saPosition.y, saPosition.z, scene, frame,
                            nativeError, sizeof(nativeError), noOverrides, &rendered)) {
        return failureResult(ErrorString(nativeError));
    }
    ValidationFailure validationFailure;
    if (!ValidateScene(scene, validationFailure)) {
        return failureResult(validationFailure.error, validationFailure.errorCode,
                             validationFailure.errorContext);
    }
    if (m_PublicationRevision == std::numeric_limits<int64_t>::max()) {
        return failureResult("publication revision exhausted");
    }

    std::vector<Ref<ImageTexture>> textures;
    textures.reserve(scene.images.size());
    for (const auto& image : scene.images) {
        Ref<ImageTexture> texture = MakeTexture(image);
        if (texture.is_null()) {
            return failureResult("Godot rejected a decoded RGBA texture");
        }
        textures.push_back(texture);
    }

    const auto imageModes = ClassifyImages(scene);
    TypedArray<Dictionary> meshes;
    int64_t surfaceCount = 0;
    for (const auto& source : scene.meshes) {
        Dictionary mesh;
        String meshError;
        if (!MakeMesh(source, scene, imageModes, textures, mesh, meshError, surfaceCount)) {
            return failureResult(meshError);
        }
        meshes.push_back(mesh);
    }
    if (meshes.is_empty()) {
        return failureResult("validated scene produced no Godot meshes");
    }

    // P1-A04 single-chain supplement resolution. The parent emits via the
    // existing pipeline only when its selected child is in this window.
    int childMeshIndex = -1;
    int parentMeshIndex = -1;
    bool lodSelected = false;
    if (m_HasLodPair && m_Catalog && m_EffectiveCol) {
        if (rendered.size() != scene.meshes.size()) {
            return failureResult("LOD supplement render identity count mismatch");
        }
        for (size_t i = 0; i < rendered.size(); ++i) {
            if (rendered[i] == m_Decision.Child) {
                if (childMeshIndex >= 0) {
                    return failureResult("LOD supplement duplicate child render");
                }
                childMeshIndex = static_cast<int>(i);
            }
            if (rendered[i] == m_Decision.Parent) {
                if (parentMeshIndex >= 0) {
                    return failureResult("LOD supplement duplicate parent render");
                }
                parentMeshIndex = static_cast<int>(i);
            }
        }
        if (childMeshIndex >= 0 || parentMeshIndex >= 0) {
            // Half pairs never publish: reject with revision unchanged.
            if (childMeshIndex < 0 || parentMeshIndex < 0) {
                return failureResult("LOD supplement half pair present (pair rejected)");
            }
            if (childMeshIndex >= static_cast<int>(scene.meshes.size()) ||
                parentMeshIndex >= static_cast<int>(scene.meshes.size()) ||
                childMeshIndex >= static_cast<int>(meshes.size()) ||
                parentMeshIndex >= static_cast<int>(meshes.size())) {
                return failureResult("LOD supplement mesh index outside publication");
            }
            const auto& childScene = scene.meshes[static_cast<size_t>(childMeshIndex)];
            const auto& parentScene = scene.meshes[static_cast<size_t>(parentMeshIndex)];
            if (childScene.tris <= 0 || childScene.pos.empty() || parentScene.tris <= 0 ||
                parentScene.pos.empty()) {
                return failureResult("LOD supplement pair geometry empty (pair rejected)");
            }
            lodSelected = true;
        }
    }

    Dictionary collisionLineage;
    if (lodSelected) {
        // Fully validated render + COL payload only; any failure leaves the
        // revision unchanged. Local SA data plus the authored placement
        // specifies the transform/conjugation exactly once (binding conjugates
        // the authored inverse rotation a single time).
        if (!FinitePlacement(m_ChildPlacement) || !FinitePlacement(m_ParentPlacement)) {
            return failureResult("LOD supplement authored placement nonfinite");
        }
        String colError;
        if (!m_EffectiveCol ||
            !ValidateEffectiveCol(*m_EffectiveCol, m_Decision.EffectiveColFaces, colError)) {
            return failureResult(colError.is_empty() ? "LOD supplement effective COL invalid"
                                                     : colError);
        }
        if (m_EffectiveColLibrary.empty() || m_EffectiveColLibrary != m_EffectiveCol->Library) {
            return failureResult("LOD supplement effective COL library mismatch");
        }
        const NativeCollisionModel& col = *m_EffectiveCol;
        const int64_t vertexCount = static_cast<int64_t>(col.Vertices.size());
        const int64_t faceCount = static_cast<int64_t>(col.Faces.size());
        const int64_t sphereCount = static_cast<int64_t>(col.Spheres.size());
        const int64_t boxCount = static_cast<int64_t>(col.Boxes.size());
        if (vertexCount <= 0 || faceCount <= 0) {
            return failureResult("LOD supplement effective COL counters invalid");
        }

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
        for (int64_t i = 0; i < faceCount; ++i) {
            const auto& face = col.Faces[static_cast<size_t>(i)];
            for (int k = 0; k < 3; ++k) {
                const uint32_t index = face.Vertices[static_cast<size_t>(k)];
                if (static_cast<uint64_t>(index) >= static_cast<uint64_t>(vertexCount) ||
                    index > static_cast<uint32_t>(std::numeric_limits<int32_t>::max())) {
                    return failureResult("LOD supplement effective COL face index outside array");
                }
                faceIndices.set(i * 3 + k, static_cast<int32_t>(index));
            }
        }
        PackedByteArray faceSurfaces;
        faceSurfaces.resize(faceCount * 4);
        for (int64_t i = 0; i < faceCount; ++i) {
            const auto& surface = col.Faces[static_cast<size_t>(i)].Surface;
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
        childDict["model_id"] = static_cast<int64_t>(m_Decision.Child.ModelId);
        childDict["model"] = SourceString(m_Decision.Child.Model);
        childDict["mesh_index"] = static_cast<int64_t>(childMeshIndex);
        childDict["uses_collision"] = true;
        childDict["placement"] = PlacementDictionary(m_ChildPlacement);

        Dictionary parentDict;
        parentDict["model_id"] = static_cast<int64_t>(m_Decision.Parent.ModelId);
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
        colDict["bounds_min"] = Vector3(col.Min[0], col.Min[1], col.Min[2]);
        colDict["bounds_max"] = Vector3(col.Max[0], col.Max[1], col.Max[2]);
        colDict["bound_center"] = Vector3(col.BoundCenter[0], col.BoundCenter[1], col.BoundCenter[2]);
        colDict["bound_radius"] = col.BoundRadius;
        colDict["vertices"] = vertices;
        colDict["face_indices"] = faceIndices;
        colDict["face_surfaces"] = faceSurfaces;
        colDict["sphere_data"] = sphereData;
        colDict["sphere_surfaces"] = sphereSurfaces;
        colDict["box_data"] = boxData;
        colDict["box_surfaces"] = boxSurfaces;

        collisionLineage["generation"] = m_PublicationRevision + 1;
        collisionLineage["scope"] = "single-chain-data-not-gameplay";
        collisionLineage["link"] = "bound";
        collisionLineage["collision_transferred"] = true;
        collisionLineage["child"] = childDict;
        collisionLineage["parent"] = parentDict;
        collisionLineage["col"] = colDict;
    }

    // Top-level mesh flag: the prepared parent stays retained-but-hidden on the
    // client when selected (child false). This is a client retention hint, not
    // a source visibility claim. Unselected frames flag every mesh false.
    for (int64_t i = 0; i < meshes.size(); ++i) {
        Dictionary entry = meshes[i];
        entry["lod_chain_alternate"] = lodSelected && i == parentMeshIndex;
        meshes[i] = entry;
    }

    int sectorsLoaded = 0;
    int sectorsEvicted = 0;
    int modelsPeak = 0;
    int trisPeak = 0;
    StreamPager_Counters(sectorsLoaded, sectorsEvicted, modelsPeak, trisPeak);
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

    Dictionary result = Result(true);
    result["meshes"] = meshes;
    result["stats"] = stats;
    result["collision_lineage"] = collisionLineage;
    ++m_PublicationRevision;
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
    std::lock_guard lock(s_PagerMutex);
    if (!m_Ready) {
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
    if (s_PagerOwner == this) {
        StreamPager_Shutdown();
        s_PagerOwner = nullptr;
    }
    m_GameDir.clear();
    m_Ready = false;
    // Clear pair owners; returned Godot packed arrays already own their bytes.
    // m_PublicationRevision is intentionally preserved across close/reopen.
    m_Catalog.reset();
    m_Decision = NativeLodChainDecision{};
    m_ChildPlacement = NativeCollisionPlacement{};
    m_ParentPlacement = NativeCollisionPlacement{};
    m_EffectiveCol.reset();
    m_EffectiveColLibrary.clear();
    m_HasLodPair = false;
}

} // namespace godot
