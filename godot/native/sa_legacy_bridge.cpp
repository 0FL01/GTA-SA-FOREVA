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
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/variant.hpp>

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

bool ValidateScene(const WorldShotScene& scene, String& error) {
    if (scene.meshes.empty()) {
        error = "pager returned no meshes";
        return false;
    }
    if (scene.images.size() > kMaxSceneImages) {
        error = "pager returned too many images";
        return false;
    }

    size_t imageBytes = 0;
    for (const auto& image : scene.images) {
        if (image.w <= 0 || image.h <= 0 || image.w > 4096 || image.h > 4096) {
            error = "decoded texture dimensions are out of range";
            return false;
        }
        const size_t pixels = static_cast<size_t>(image.w) * static_cast<size_t>(image.h);
        if (pixels > std::numeric_limits<size_t>::max() / 4 || image.rgba.size() != pixels * 4) {
            error = "decoded texture byte size is invalid";
            return false;
        }
        if (imageBytes > kMaxImageBytes - image.rgba.size()) {
            error = "decoded texture publication exceeds the size limit";
            return false;
        }
        imageBytes += image.rgba.size();
    }

    size_t sceneTriangles = 0;
    for (const auto& mesh : scene.meshes) {
        if (mesh.tris <= 0) {
            error = "pager returned a mesh with no triangles";
            return false;
        }
        const size_t triangles = static_cast<size_t>(mesh.tris);
        if (triangles > kMaxSceneTriangles || sceneTriangles > kMaxSceneTriangles - triangles) {
            error = "pager scene exceeds the triangle limit";
            return false;
        }
        sceneTriangles += triangles;
        if (mesh.pos.size() != triangles * 9 || mesh.nrm.size() != triangles * 9 ||
            mesh.uv.size() != triangles * 6 || mesh.triImg.size() != triangles ||
            mesh.triCol.size() != triangles * 3 || mesh.dayColors.size() != triangles * 12 ||
            mesh.nightColors.size() != triangles * 12 || mesh.surfaces.size() != triangles) {
            error = "pager mesh attribute sizes are inconsistent";
            return false;
        }
        for (float value : mesh.pos) {
            if (!Finite(value) || std::abs(value) > 1'000'000.0f) {
                error = "pager position is nonfinite or out of range";
                return false;
            }
        }
        for (float value : mesh.nrm) {
            if (!Finite(value) || std::abs(value) > 1.001f) {
                error = "pager normal is nonfinite or out of range";
                return false;
            }
        }
        for (float value : mesh.uv) {
            if (!Finite(value) || std::abs(value) > 1'000'000.0f) {
                error = "pager UV is nonfinite or out of range";
                return false;
            }
        }
        for (float value : mesh.triCol) {
            if (!ValidUnit(value)) {
                error = "pager material color is outside [0,1]";
                return false;
            }
        }
        for (size_t triangle = 0; triangle < triangles; ++triangle) {
            const int image = mesh.triImg[triangle];
            if (image < -1 || image >= static_cast<int>(scene.images.size())) {
                error = "pager material references an invalid image";
                return false;
            }
            const auto& surface = mesh.surfaces[triangle];
            if (!std::all_of(surface.color.begin(), surface.color.end(), ValidUnit) ||
                !Finite(surface.ambient) || !Finite(surface.diffuse) || surface.ambient < 0.0f ||
                surface.diffuse < 0.0f || surface.ambient > 16.0f || surface.diffuse > 16.0f) {
                error = "pager surface values are nonfinite or out of range";
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

using MaterialKey = std::tuple<int, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, int32_t, int>;

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

    const size_t triangle = group.representative;
    const auto& surface = source.surfaces[triangle];
    const int image = source.triImg[triangle];
    if (image >= 0) {
        material["texture"] = textures[static_cast<size_t>(image)];
        material["filter"] = static_cast<int64_t>(scene.images[static_cast<size_t>(image)].filter);
    } else {
        material["texture"] = Variant();
        material["filter"] = int64_t{0};
    }
    material["color"] = Color(surface.color[0], surface.color[1], surface.color[2], surface.color[3]);
    material["ambient"] = static_cast<double>(surface.ambient);
    material["diffuse"] = static_cast<double>(surface.diffuse);
    material["alpha_mode"] = AlphaName(group.alpha);
    material["family"] = "world";
    material["source_material_slot"] = surface.sourceMaterial;
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
    return result;
}

Dictionary SALegacyBridge::LoadRegion(const Vector3& saPosition) {
    if (!IsMainThread()) {
        return Result(false, "load_region must run on Godot's main thread");
    }
    if (!Finite(saPosition.x) || !Finite(saPosition.y) || !Finite(saPosition.z) ||
        std::abs(saPosition.x) > 1'000'000.0f || std::abs(saPosition.y) > 1'000'000.0f ||
        std::abs(saPosition.z) > 1'000'000.0f) {
        return Result(false, "SA_position must be finite and within the supported coordinate range");
    }

    std::lock_guard lock(s_PagerMutex);
    if (!m_Ready || s_PagerOwner != this) {
        return Result(false, "load_region requires an open pager owned by this bridge");
    }

    WorldShotScene scene{};
    E2EPagerFrame frame{};
    char nativeError[256]{};
    if (!StreamPager_Update(saPosition.x, saPosition.y, saPosition.z, scene, frame,
                            nativeError, sizeof(nativeError))) {
        return Result(false, ErrorString(nativeError));
    }
    String validationError;
    if (!ValidateScene(scene, validationError)) {
        return Result(false, validationError);
    }

    std::vector<Ref<ImageTexture>> textures;
    textures.reserve(scene.images.size());
    for (const auto& image : scene.images) {
        Ref<ImageTexture> texture = MakeTexture(image);
        if (texture.is_null()) {
            return Result(false, "Godot rejected a decoded RGBA texture");
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
            return Result(false, meshError);
        }
        meshes.push_back(mesh);
    }
    if (meshes.is_empty()) {
        return Result(false, "validated scene produced no Godot meshes");
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
        return;
    }
    if (s_PagerOwner == this) {
        StreamPager_Shutdown();
        s_PagerOwner = nullptr;
    }
    m_GameDir.clear();
    m_Ready = false;
}

} // namespace godot
