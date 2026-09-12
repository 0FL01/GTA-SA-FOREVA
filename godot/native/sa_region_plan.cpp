// sa_region_plan implementation: pure-C++ validation + grouping + prepack.
// See sa_region_plan.h for the frozen contract. No Godot/RW pointers.

#include "sa_region_plan.h"

#include <algorithm>
#include <bit>
#include <cmath>
#include <cstdint>
#include <limits>
#include <map>
#include <tuple>
#include <utility>

namespace {

bool FiniteFloat(float value) {
    return std::isfinite(value);
}

bool ValidUnitFloat(float value) {
    return FiniteFloat(value) && value >= 0.0f && value <= 1.0f;
}

RegionPlanAlpha MergePlanAlpha(RegionPlanAlpha current, uint8_t alpha) {
    if (alpha > 0 && alpha < 255) {
        return RegionPlanAlpha::Blend;
    }
    if (alpha == 0 && current == RegionPlanAlpha::Opaque) {
        return RegionPlanAlpha::Cutout;
    }
    return current;
}

std::vector<RegionPlanAlpha> ClassifyPlanImages(const WorldShotScene &scene) {
    std::vector<RegionPlanAlpha> modes(scene.images.size(), RegionPlanAlpha::Opaque);
    for (size_t index = 0; index < scene.images.size(); ++index) {
        for (size_t byte = 3; byte < scene.images[index].rgba.size(); byte += 4) {
            modes[index] = MergePlanAlpha(modes[index], scene.images[index].rgba[byte]);
            if (modes[index] == RegionPlanAlpha::Blend) {
                break;
            }
        }
    }
    return modes;
}

RegionPlanAlpha ClassifyPlanTriangle(const WorldShotMesh &mesh, size_t triangle,
                                     const std::vector<RegionPlanAlpha> &imageModes) {
    const auto &surface = mesh.surfaces[triangle];
    if (surface.vehicleAlpha || surface.color[3] < 1.0f) {
        return RegionPlanAlpha::Blend;
    }
    RegionPlanAlpha mode = RegionPlanAlpha::Opaque;
    const int image = mesh.triImg[triangle];
    if (image >= 0) {
        mode = imageModes[static_cast<size_t>(image)];
    }
    for (size_t vertex = 0; vertex < 3; ++vertex) {
        const size_t alpha = triangle * 12 + vertex * 4 + 3;
        mode = MergePlanAlpha(mode, mesh.dayColors[alpha]);
        mode = MergePlanAlpha(mode, mesh.nightColors[alpha]);
        if (mesh.dayColors[alpha] != mesh.nightColors[alpha]) {
            mode = RegionPlanAlpha::Blend;
        }
    }
    return mode;
}

using PlanMaterialKey = std::tuple<int, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t,
                                   int32_t, int, int>;

PlanMaterialKey MakePlanMaterialKey(const WorldShotMesh &mesh, size_t triangle,
                                    RegionPlanAlpha alpha) {
    const auto &surface = mesh.surfaces[triangle];
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

struct PlanSurfaceGroup {
    size_t representative = 0;
    RegionPlanAlpha alpha = RegionPlanAlpha::Opaque;
    std::vector<size_t> triangles;
};

bool ValidatePlanTextureIdentity(const WorldShotMesh & /*mesh*/, size_t triangle, int imageIndex,
                                 const WorldShotImage &image, RegionPlanFailure &failure) {
    const auto reject = [&](const char *reason) {
        failure.kind = RegionPlanFailure::Kind::BadTextureIdentity;
        failure.meshIndex = 0; // patched by caller (needs mesh index)
        failure.triangle = triangle;
        failure.imageIndex = imageIndex;
        failure.reason = reason;
        return false;
    };
    if (!image.hasSourceIdentity) {
        return reject("missing_source_identity");
    }
    const auto &identity = image.sourceIdentity;
    if (identity.lineage.empty()) {
        return reject("empty_lineage");
    }
    if (std::any_of(identity.lineage.begin(), identity.lineage.end(), [](const auto &member) {
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

} // namespace

const char *RegionPlanAlphaName(RegionPlanAlpha alpha) {
    switch (alpha) {
    case RegionPlanAlpha::Opaque:
        return "opaque";
    case RegionPlanAlpha::Cutout:
        return "cutout";
    case RegionPlanAlpha::Blend:
        return "blend";
    }
    return "opaque";
}

size_t RegionPlanTotalSurfaces(const RegionPlan &plan) {
    size_t total = 0;
    for (const auto &mesh : plan.meshes) {
        total += mesh.surfaces.size();
    }
    return total;
}

size_t RegionPlanTotalUnits(const RegionPlan &plan) {
    // One ImageTexture per image, one surface add per planned surface, one
    // mesh-metadata finish per planned mesh, one paired payload. No
    // whole-scene single unit.
    return plan.imageModes.size() + RegionPlanTotalSurfaces(plan) + plan.meshes.size() + 1;
}

void ClearRegionPlan(RegionPlan &plan) {
    plan.imageModes.clear();
    plan.meshes.clear();
}

bool BuildRegionPlan(const WorldShotScene &scene, RegionPlan &plan, RegionPlanFailure &failure) {
    ClearRegionPlan(plan);
    failure = RegionPlanFailure{};

    if (scene.meshes.empty()) {
        failure.kind = RegionPlanFailure::Kind::NoMeshes;
        return false;
    }
    if (scene.images.size() > kRegionPlanMaxSceneImages) {
        failure.kind = RegionPlanFailure::Kind::TooManyImages;
        return false;
    }

    size_t imageBytes = 0;
    for (const auto &image : scene.images) {
        if (image.w <= 0 || image.h <= 0 || image.w > 4096 || image.h > 4096) {
            failure.kind = RegionPlanFailure::Kind::BadImageDimensions;
            return false;
        }
        const size_t pixels = static_cast<size_t>(image.w) * static_cast<size_t>(image.h);
        if (pixels > std::numeric_limits<size_t>::max() / 4 || image.rgba.size() != pixels * 4) {
            failure.kind = RegionPlanFailure::Kind::BadImageBytes;
            return false;
        }
        if (imageBytes > kRegionPlanMaxImageBytes - image.rgba.size()) {
            failure.kind = RegionPlanFailure::Kind::ImageBytesLimit;
            return false;
        }
        imageBytes += image.rgba.size();
    }

    size_t sceneTriangles = 0;
    for (size_t meshIndex = 0; meshIndex < scene.meshes.size(); ++meshIndex) {
        const auto &mesh = scene.meshes[meshIndex];
        if (mesh.tris <= 0) {
            failure.kind = RegionPlanFailure::Kind::EmptyMesh;
            failure.meshIndex = meshIndex;
            return false;
        }
        const size_t triangles = static_cast<size_t>(mesh.tris);
        if (triangles > kRegionPlanMaxSceneTriangles ||
            sceneTriangles > kRegionPlanMaxSceneTriangles - triangles) {
            failure.kind = RegionPlanFailure::Kind::TriangleLimit;
            failure.meshIndex = meshIndex;
            return false;
        }
        sceneTriangles += triangles;
        if (mesh.pos.size() != triangles * 9 || mesh.nrm.size() != triangles * 9 ||
            mesh.uv.size() != triangles * 6 || mesh.triImg.size() != triangles ||
            mesh.triCol.size() != triangles * 3 || mesh.dayColors.size() != triangles * 12 ||
            mesh.nightColors.size() != triangles * 12 || mesh.surfaces.size() != triangles) {
            failure.kind = RegionPlanFailure::Kind::AttributeMismatch;
            failure.meshIndex = meshIndex;
            return false;
        }
        for (float value : mesh.pos) {
            if (!FiniteFloat(value) || std::abs(value) > 1'000'000.0f) {
                failure.kind = RegionPlanFailure::Kind::BadPosition;
                failure.meshIndex = meshIndex;
                failure.badValue = value;
                return false;
            }
        }
        for (float value : mesh.nrm) {
            if (!FiniteFloat(value) || std::abs(value) > 1.001f) {
                failure.kind = RegionPlanFailure::Kind::BadNormal;
                failure.meshIndex = meshIndex;
                failure.badValue = value;
                return false;
            }
        }
        for (size_t uvIndex = 0; uvIndex < mesh.uv.size(); ++uvIndex) {
            if (!FiniteFloat(mesh.uv[uvIndex])) {
                failure.kind = RegionPlanFailure::Kind::NonfiniteUv;
                failure.meshIndex = meshIndex;
                failure.triangle = uvIndex / 6;
                failure.uvIndex = uvIndex;
                failure.badValue = mesh.uv[uvIndex];
                return false;
            }
        }
        for (float value : mesh.triCol) {
            if (!ValidUnitFloat(value)) {
                failure.kind = RegionPlanFailure::Kind::BadMaterialColor;
                failure.meshIndex = meshIndex;
                failure.badValue = value;
                return false;
            }
        }
        for (size_t triangle = 0; triangle < triangles; ++triangle) {
            const int image = mesh.triImg[triangle];
            if (image < -1 || image >= static_cast<int>(scene.images.size())) {
                failure.kind = RegionPlanFailure::Kind::BadImageIndex;
                failure.meshIndex = meshIndex;
                failure.triangle = triangle;
                failure.imageIndex = image;
                failure.missingTexture = (image == -2);
                return false;
            }
            if (image >= 0) {
                RegionPlanFailure idFailure;
                if (!ValidatePlanTextureIdentity(
                        mesh, triangle, image, scene.images[static_cast<size_t>(image)],
                        idFailure)) {
                    failure = idFailure;
                    failure.meshIndex = meshIndex;
                    return false;
                }
            }
            const auto &surface = mesh.surfaces[triangle];
            if (!std::all_of(surface.color.begin(), surface.color.end(), ValidUnitFloat) ||
                !FiniteFloat(surface.ambient) || !FiniteFloat(surface.diffuse) ||
                surface.ambient < 0.0f || surface.diffuse < 0.0f || surface.ambient > 16.0f ||
                surface.diffuse > 16.0f) {
                failure.kind = RegionPlanFailure::Kind::BadSurfaceValues;
                failure.meshIndex = meshIndex;
                failure.triangle = triangle;
                return false;
            }
        }
    }

    // Classification + material-group ordering (first-encounter map order).
    plan.imageModes = ClassifyPlanImages(scene);
    plan.meshes.reserve(scene.meshes.size());
    for (size_t meshIndex = 0; meshIndex < scene.meshes.size(); ++meshIndex) {
        const auto &source = scene.meshes[meshIndex];
        std::map<PlanMaterialKey, size_t> groupIndex;
        std::vector<PlanSurfaceGroup> groups;
        for (size_t triangle = 0; triangle < static_cast<size_t>(source.tris); ++triangle) {
            const RegionPlanAlpha alpha = ClassifyPlanTriangle(source, triangle, plan.imageModes);
            const auto key = MakePlanMaterialKey(source, triangle, alpha);
            auto [iterator, inserted] = groupIndex.emplace(key, groups.size());
            if (inserted) {
                groups.push_back({triangle, alpha, {}});
            }
            groups[iterator->second].triangles.push_back(triangle);
        }
        RegionPlanMesh planned;
        planned.sourceMeshIndex = meshIndex;
        planned.surfaces.reserve(groups.size());
        for (const auto &group : groups) {
            RegionPlanSurface surface;
            surface.representativeTriangle = group.representative;
            surface.alpha = group.alpha;
            const auto &rep = source.surfaces[group.representative];
            surface.imageIndex = source.triImg[group.representative];
            surface.color = rep.color;
            surface.ambient = rep.ambient;
            surface.diffuse = rep.diffuse;
            surface.sourceMaterial = rep.sourceMaterial;
            surface.sourceGeometry = rep.sourceGeometry;
            const size_t vertexCount = group.triangles.size() * 3;
            surface.positions.reserve(vertexCount * 3);
            surface.normals.reserve(vertexCount * 3);
            surface.uvs.reserve(vertexCount * 2);
            surface.day.reserve(vertexCount * 4);
            surface.night.reserve(vertexCount * 4);
            for (size_t triangle : group.triangles) {
                for (size_t vertex = 0; vertex < 3; ++vertex) {
                    const size_t xyz = triangle * 9 + vertex * 3;
                    const size_t uv = triangle * 6 + vertex * 2;
                    const size_t rgba = triangle * 12 + vertex * 4;
                    // Exact former AddSurface basis: SA XYZ -> Godot X,Z,-Y.
                    surface.positions.push_back(source.pos[xyz]);
                    surface.positions.push_back(source.pos[xyz + 2]);
                    surface.positions.push_back(-source.pos[xyz + 1]);
                    surface.normals.push_back(source.nrm[xyz]);
                    surface.normals.push_back(source.nrm[xyz + 2]);
                    surface.normals.push_back(-source.nrm[xyz + 1]);
                    surface.uvs.push_back(source.uv[uv]);
                    surface.uvs.push_back(source.uv[uv + 1]);
                    for (size_t channel = 0; channel < 4; ++channel) {
                        surface.day.push_back(
                            static_cast<float>(source.dayColors[rgba + channel]) / 255.0f);
                        surface.night.push_back(
                            static_cast<float>(source.nightColors[rgba + channel]) / 255.0f);
                    }
                }
            }
            planned.surfaces.push_back(std::move(surface));
        }
        plan.meshes.push_back(std::move(planned));
    }
    return true;
}
