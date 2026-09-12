// sa_region_plan: pure-C++ region validation + material grouping + CPU prepack.
// P1-A06: extracted verbatim from the former Godot bridge so the worker can
// plan without Godot/RW pointers. No Godot, no GL, no RW pointers: only owned
// StreamPager value types (WorldShotScene) plus the C++ standard library.
//
// Ordering and numeric contracts are frozen:
// - validation order/codes match the former ValidateScene (P0 NaN reject with
//   nonfinite_uv provenance, invalid_image_index/missing_texture,
//   invalid_texture_identity + reason, finite/size/index bounds).
// - ClassifyImages/ClassifyTriangle/MakeMaterialKey grouping order matches the
//   former bridge (first-encounter map order, source triangle order retained).
// - prepacked CPU floats match the former AddSurface exactly: SA XYZ ->
//   Godot X,Z,-Y basis (positive determinant, clockwise retained),
//   UV direct, day/night uint8/255.0f. Main only copies buffers into Godot
//   Packed arrays and issues one add_surface_from_arrays per surface unit;
//   it must not rescan pixel/triangle attributes.
#pragma once

#include "app/platform/linux/WorldShot.h"

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

enum class RegionPlanAlpha : int32_t { Opaque = 0, Cutout = 1, Blend = 2 };

constexpr size_t kRegionPlanMaxSceneTriangles = 8'000'000;
constexpr size_t kRegionPlanMaxSceneImages = 4096;
constexpr size_t kRegionPlanMaxImageBytes = 512ull * 1024ull * 1024ull;

struct RegionPlanSurface {
    size_t representativeTriangle = 0;
    RegionPlanAlpha alpha = RegionPlanAlpha::Opaque;
    // Prepacked CPU floats, already in Godot basis (see file comment).
    std::vector<float> positions; // 3 * verts
    std::vector<float> normals;   // 3 * verts
    std::vector<float> uvs;       // 2 * verts
    std::vector<float> day;       // 4 * verts, 0..1
    std::vector<float> night;     // 4 * verts, 0..1
    int imageIndex = -1;
    std::array<float, 4> color{1.0f, 1.0f, 1.0f, 1.0f};
    float ambient = 1.0f;
    float diffuse = 1.0f;
    int sourceMaterial = -1;
    int sourceGeometry = -1;
};

struct RegionPlanMesh {
    size_t sourceMeshIndex = 0;
    std::vector<RegionPlanSurface> surfaces;
};

struct RegionPlan {
    std::vector<RegionPlanAlpha> imageModes;
    std::vector<RegionPlanMesh> meshes;
};

// Strongly typed plan failure: carries indices/reason so the Godot main
// constructs the exact former structured failure (nonfinite_uv etc) without
// parsing human strings.
struct RegionPlanFailure {
    enum class Kind {
        None,
        NoMeshes,
        TooManyImages,
        BadImageDimensions,
        BadImageBytes,
        ImageBytesLimit,
        EmptyMesh,
        TriangleLimit,
        AttributeMismatch,
        BadPosition,
        BadNormal,
        NonfiniteUv,
        BadMaterialColor,
        BadImageIndex,
        BadTextureIdentity,
        BadSurfaceValues,
    };
    Kind kind = Kind::None;
    size_t meshIndex = 0;
    size_t triangle = 0;
    int imageIndex = -1;
    size_t uvIndex = 0;
    float badValue = 0.0f;
    std::string reason;
    bool missingTexture = false;
};

bool BuildRegionPlan(const WorldShotScene &scene, RegionPlan &plan, RegionPlanFailure &failure);

const char *RegionPlanAlphaName(RegionPlanAlpha alpha);
size_t RegionPlanTotalSurfaces(const RegionPlan &plan);
size_t RegionPlanTotalUnits(const RegionPlan &plan);
void ClearRegionPlan(RegionPlan &plan);
