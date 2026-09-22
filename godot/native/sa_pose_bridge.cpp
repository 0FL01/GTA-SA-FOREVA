#include "sa_pose_bridge.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

#include <cstring>

namespace godot {
namespace {
String SourceString(const std::string& value) {
    return String::utf8(value.c_str(), static_cast<int64_t>(value.size()));
}

Dictionary SceneValue(const WorldShotScene& scene) {
    Dictionary out;
    Array meshes;
    for (const auto& source : scene.meshes) {
        Dictionary mesh;
        PackedVector3Array positions, normals;
        PackedVector2Array uv;
        PackedInt32Array images;
        PackedColorArray colors;
        for (std::size_t i = 0; i < source.pos.size(); i += 3)
            positions.push_back(Vector3(source.pos[i], source.pos[i + 2], -source.pos[i + 1]));
        for (std::size_t i = 0; i < source.nrm.size(); i += 3)
            normals.push_back(Vector3(source.nrm[i], source.nrm[i + 2], -source.nrm[i + 1]));
        for (std::size_t i = 0; i < source.uv.size(); i += 2)
            uv.push_back(Vector2(source.uv[i], source.uv[i + 1]));
        for (const auto image : source.triImg) images.push_back(image);
        for (int triangle = 0; triangle < source.tris; ++triangle) {
            const auto index = static_cast<std::size_t>(triangle);
            const float alpha = source.surfaces.empty() ? 1.0f : source.surfaces[index].color[3];
            const Color color = !source.surfaces.empty()
                ? Color(source.surfaces[index].color[0], source.surfaces[index].color[1],
                    source.surfaces[index].color[2], alpha)
                : source.triCol.empty()
                    ? Color(source.color[0], source.color[1], source.color[2], alpha)
                    : Color(source.triCol[index * 3], source.triCol[index * 3 + 1],
                        source.triCol[index * 3 + 2], alpha);
            colors.push_back(color);
        }
        mesh["positions"] = positions;
        mesh["normals"] = normals;
        mesh["uv"] = uv;
        mesh["images"] = images;
        mesh["colors"] = colors;
        mesh["triangles"] = source.tris;
        meshes.push_back(mesh);
    }
    Array images;
    for (const auto& source : scene.images) {
        Dictionary image;
        PackedByteArray bytes;
        bytes.resize(static_cast<int64_t>(source.rgba.size()));
        if (!source.rgba.empty()) std::memcpy(bytes.ptrw(), source.rgba.data(), source.rgba.size());
        image["width"] = source.w;
        image["height"] = source.h;
        image["mipmaps"] = source.mipmaps;
        image["filter"] = static_cast<int64_t>(source.filter);
        image["rgba"] = bytes;
        image["filter"] = static_cast<int64_t>(source.filter);
        images.push_back(image);
    }
    out["meshes"] = meshes;
    out["images"] = images;
    out["triangles"] = scene.stats.triangles;
    return out;
}
}

Dictionary SALegacyPose::Result(bool ok, const String& error) const {
    Dictionary out = Snapshot();
    out["ok"] = ok;
    out["error"] = error;
    return out;
}

Dictionary SALegacyPose::CapturePed(const String& gameDir, const String& model,
    const String& clip, double fraction) {
    std::string error;
    const auto directory = gameDir.utf8();
    const auto modelName = model.utf8();
    const auto clipName = clip.utf8();
    const bool ok = m_Poses.CapturePed(directory.get_data(), modelName.get_data(),
        clipName.get_data(), fraction, error);
    return Result(ok, ok ? String() : SourceString(error));
}

Dictionary SALegacyPose::CaptureCutscene(const String& gameDir, const String& model,
    const String& bank, const String& clip, double fraction) {
    std::string error;
    const auto directory = gameDir.utf8();
    const auto modelName = model.utf8();
    const auto bankName = bank.utf8();
    const auto clipName = clip.utf8();
    const bool ok = m_Poses.CaptureCutscene(directory.get_data(), modelName.get_data(),
        bankName.get_data(), clipName.get_data(), fraction, error);
    return Result(ok, ok ? String() : SourceString(error));
}

Dictionary SALegacyPose::Snapshot() const {
    Dictionary out;
    const auto frame = m_Poses.LastFrame();
    out["valid"] = bool(frame);
    out["presentation_feedback"] = false;
    out["exclusive_parser"] = true;
    if (!frame) return out;
    out.merge(SceneValue(frame->Scene));
    out["generation"] = static_cast<int64_t>(frame->Generation);
    out["family"] = frame->Family == NativePoseFamily::Ped ? "ped" : "cutscene";
    out["model"] = SourceString(frame->Model);
    out["bank"] = SourceString(frame->Bank);
    out["clip"] = SourceString(frame->Clip);
    out["fraction"] = frame->Fraction;
    out["bones"] = frame->Family == NativePoseFamily::Ped
        ? frame->PedStats.bones : frame->CutsceneStats.bones;
    out["mapped"] = frame->Family == NativePoseFamily::Ped
        ? frame->PedStats.mapped : frame->CutsceneStats.mapped;
    return out;
}

void SALegacyPose::_bind_methods() {
    ClassDB::bind_method(D_METHOD("capture_ped", "game_dir", "model", "clip", "fraction"),
        &SALegacyPose::CapturePed);
    ClassDB::bind_method(D_METHOD("capture_cutscene", "game_dir", "model", "bank", "clip", "fraction"),
        &SALegacyPose::CaptureCutscene);
    ClassDB::bind_method(D_METHOD("snapshot"), &SALegacyPose::Snapshot);
}

} // namespace godot
