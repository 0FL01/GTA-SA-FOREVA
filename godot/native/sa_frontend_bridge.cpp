#include "sa_frontend_bridge.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>

#include <cstdint>
#include <limits>

namespace godot {
namespace {
const char* StatusName(NativeFrontendStatus status) {
    switch (status) {
    case NativeFrontendStatus::Ok: return "ok";
    case NativeFrontendStatus::NotInitialized: return "not_initialized";
    case NativeFrontendStatus::InvalidState: return "invalid_state";
    case NativeFrontendStatus::InvalidInput: return "invalid_input";
    case NativeFrontendStatus::CameraError: return "camera_error";
    case NativeFrontendStatus::Overflow: return "overflow";
    }
    return "invalid_input";
}
bool HostTime(int64_t value) {
    return value >= 0 && static_cast<std::uint64_t>(value) <= std::numeric_limits<std::uint32_t>::max();
}
Dictionary Display(const NativeFrontendDisplaySettings& value) {
    Dictionary out;
    out["brightness"] = value.Brightness;
    out["draw_distance"] = value.DrawDistance;
    out["frame_limiter"] = value.FrameLimiter;
    out["hud"] = value.Hud;
    out["save_photos"] = value.SavePhotos;
    out["mip_mapping"] = value.MipMapping;
    out["antialiasing"] = value.Antialiasing;
    out["widescreen"] = value.Widescreen;
    out["map_legend"] = value.MapLegend;
    out["radar_mode"] = value.RadarMode;
    out["location_blips"] = value.LocationBlips;
    out["contact_blips"] = value.ContactBlips;
    out["mission_blips"] = value.MissionBlips;
    out["other_blips"] = value.OtherBlips;
    out["gang_area_blips"] = value.GangAreaBlips;
    out["subtitles"] = value.Subtitles;
    return out;
}
}

Dictionary SALegacyFrontend::Result(NativeFrontendStatus status) const {
    auto out = Snapshot();
    out["ok"] = status == NativeFrontendStatus::Ok;
    out["status"] = StatusName(status);
    return out;
}
Dictionary SALegacyFrontend::Initialize(int64_t epoch, int64_t ped, int64_t time) {
    if (epoch <= 0 || ped <= 0 || !HostTime(time)) return Result(NativeFrontendStatus::InvalidInput);
    return Result(m_Frontend.Initialize(epoch, ped, time));
}
Dictionary SALegacyFrontend::StartGame(int64_t time, const Vector2& player, int64_t seq) {
    if (!HostTime(time) || seq < 0) return Result(NativeFrontendStatus::InvalidInput);
    return Result(m_Frontend.StartGame(time, player.x, player.y, seq));
}
Dictionary SALegacyFrontend::Pause(int64_t time, int64_t seq) {
    return !HostTime(time) || seq < 0 ? Result(NativeFrontendStatus::InvalidInput) : Result(m_Frontend.Pause(time, seq));
}
Dictionary SALegacyFrontend::OpenMap(int64_t time, int64_t seq) {
    return !HostTime(time) || seq < 0 ? Result(NativeFrontendStatus::InvalidInput) : Result(m_Frontend.OpenMap(time, seq));
}
Dictionary SALegacyFrontend::PanMap(int64_t time, const Vector2& delta, int64_t seq) {
    return !HostTime(time) || seq < 0 ? Result(NativeFrontendStatus::InvalidInput) : Result(m_Frontend.PanMap(time, delta.x, delta.y, seq));
}
Dictionary SALegacyFrontend::ZoomMap(int64_t time, double zoom, int64_t seq) {
    return !HostTime(time) || seq < 0 ? Result(NativeFrontendStatus::InvalidInput) : Result(m_Frontend.ZoomMap(time, zoom, seq));
}
Dictionary SALegacyFrontend::Back(int64_t time, int64_t seq) {
    return !HostTime(time) || seq < 0 ? Result(NativeFrontendStatus::InvalidInput) : Result(m_Frontend.Back(time, seq));
}
Dictionary SALegacyFrontend::OpenOptions(int64_t time, int64_t seq) {
    return !HostTime(time) || seq < 0 ? Result(NativeFrontendStatus::InvalidInput) : Result(m_Frontend.OpenOptions(time, seq));
}
Dictionary SALegacyFrontend::OpenDisplay(int64_t time, int64_t seq) {
    return !HostTime(time) || seq < 0 ? Result(NativeFrontendStatus::InvalidInput) : Result(m_Frontend.OpenDisplay(time, seq));
}
Dictionary SALegacyFrontend::SetDisplay(int64_t time, const Dictionary& d, int64_t seq) {
    if (!HostTime(time) || seq < 0) return Result(NativeFrontendStatus::InvalidInput);
    NativeFrontendDisplaySettings s;
    s.Brightness = d.get("brightness", 256);
    s.DrawDistance = d.get("draw_distance", 1.2);
    s.FrameLimiter = d.get("frame_limiter", true);
    s.Hud = d.get("hud", true);
    s.SavePhotos = d.get("save_photos", true);
    s.MipMapping = d.get("mip_mapping", true);
    s.Antialiasing = static_cast<std::uint8_t>(static_cast<int64_t>(d.get("antialiasing", 1)));
    s.Widescreen = d.get("widescreen", false);
    s.MapLegend = d.get("map_legend", false);
    s.RadarMode = static_cast<std::uint8_t>(static_cast<int64_t>(d.get("radar_mode", 0)));
    s.LocationBlips = d.get("location_blips", true);
    s.ContactBlips = d.get("contact_blips", true);
    s.MissionBlips = d.get("mission_blips", true);
    s.OtherBlips = d.get("other_blips", true);
    s.GangAreaBlips = d.get("gang_area_blips", true);
    s.Subtitles = d.get("subtitles", true);
    return Result(m_Frontend.SetDisplay(time, s, seq));
}
Dictionary SALegacyFrontend::Resume(int64_t time, int64_t seq) {
    return !HostTime(time) || seq < 0 ? Result(NativeFrontendStatus::InvalidInput) : Result(m_Frontend.Resume(time, seq));
}
Dictionary SALegacyFrontend::SetCameraDirectlyBehind(int64_t time, const Vector3& forward) {
    if (!HostTime(time)) return Result(NativeFrontendStatus::InvalidInput);
    return Result(m_Frontend.SetCameraDirectlyBehind(time, {float(forward.x), float(forward.y), float(forward.z)}));
}
Dictionary SALegacyFrontend::Snapshot() const {
    Dictionary out;
    const auto s = m_Frontend.LastCommitted();
    out["valid"] = bool(s);
    out["presentation_feedback"] = false;
    out["camera_view"] = "unsupported";
    if (!s) return out;
    out["epoch"] = static_cast<int64_t>(s->Epoch);
    out["generation"] = static_cast<int64_t>(s->Generation);
    out["time_ms"] = s->TimeMs;
    out["screen"] = static_cast<int64_t>(s->Screen);
    out["frontend_active"] = s->FrontendActive;
    out["in_game"] = s->InGame;
    out["paused"] = s->Paused;
    out["display"] = Display(s->Display);
    out["map_center"] = Vector2(s->Map.CenterX, s->Map.CenterY);
    out["map_zoom"] = s->Map.Zoom;
    out["camera_mode"] = static_cast<int64_t>(s->Camera.Mode);
    out["camera_target_kind"] = static_cast<int64_t>(s->Camera.Target.Kind);
    out["camera_target_identity"] = static_cast<int64_t>(s->Camera.Target.Identity);
    out["camera_directly_behind"] = s->Camera.DirectlyBehind;
    Array events;
    for (const auto& e : s->Events) {
        Dictionary event;
        event["sequence"] = static_cast<int64_t>(e.Sequence);
        event["kind"] = static_cast<int64_t>(e.Kind);
        event["from"] = static_cast<int64_t>(e.From);
        event["to"] = static_cast<int64_t>(e.To);
        event["time_ms"] = e.TimeMs;
        event["input_sequence"] = static_cast<int64_t>(e.InputSequence);
        events.push_back(event);
    }
    out["events"] = events;
    return out;
}
void SALegacyFrontend::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize", "epoch", "ped_identity", "time_ms"), &SALegacyFrontend::Initialize);
    ClassDB::bind_method(D_METHOD("start_game", "time_ms", "player", "input_sequence"), &SALegacyFrontend::StartGame, DEFVAL(int64_t{0}));
    ClassDB::bind_method(D_METHOD("pause", "time_ms", "input_sequence"), &SALegacyFrontend::Pause, DEFVAL(int64_t{0}));
    ClassDB::bind_method(D_METHOD("open_map", "time_ms", "input_sequence"), &SALegacyFrontend::OpenMap, DEFVAL(int64_t{0}));
    ClassDB::bind_method(D_METHOD("pan_map", "time_ms", "delta", "input_sequence"), &SALegacyFrontend::PanMap, DEFVAL(int64_t{0}));
    ClassDB::bind_method(D_METHOD("zoom_map", "time_ms", "zoom", "input_sequence"), &SALegacyFrontend::ZoomMap, DEFVAL(int64_t{0}));
    ClassDB::bind_method(D_METHOD("back", "time_ms", "input_sequence"), &SALegacyFrontend::Back, DEFVAL(int64_t{0}));
    ClassDB::bind_method(D_METHOD("open_options", "time_ms", "input_sequence"), &SALegacyFrontend::OpenOptions, DEFVAL(int64_t{0}));
    ClassDB::bind_method(D_METHOD("open_display", "time_ms", "input_sequence"), &SALegacyFrontend::OpenDisplay, DEFVAL(int64_t{0}));
    ClassDB::bind_method(D_METHOD("set_display", "time_ms", "settings", "input_sequence"), &SALegacyFrontend::SetDisplay, DEFVAL(int64_t{0}));
    ClassDB::bind_method(D_METHOD("resume", "time_ms", "input_sequence"), &SALegacyFrontend::Resume, DEFVAL(int64_t{0}));
    ClassDB::bind_method(D_METHOD("set_camera_directly_behind", "time_ms", "forward"), &SALegacyFrontend::SetCameraDirectlyBehind);
    ClassDB::bind_method(D_METHOD("snapshot"), &SALegacyFrontend::Snapshot);
}

} // namespace godot
