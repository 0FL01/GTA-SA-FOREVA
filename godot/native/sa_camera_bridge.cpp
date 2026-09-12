#include "sa_camera_bridge.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <cstdint>
#include <limits>

namespace godot {
namespace {
const char* StatusName(NativeSourceCameraStatus status) {
    switch (status) {
    case NativeSourceCameraStatus::Ok: return "ok";
    case NativeSourceCameraStatus::NotLoaded: return "not_loaded";
    case NativeSourceCameraStatus::InvalidInput: return "invalid_input";
    case NativeSourceCameraStatus::BackwardTime: return "backward_time";
    case NativeSourceCameraStatus::TransitionOutstanding: return "transition_outstanding";
    case NativeSourceCameraStatus::Overflow: return "overflow";
    }
    return "invalid_input";
}
bool HostUnsigned(int64_t value) { return value >= 0; }
std::array<float, 3> SourceVector(const Vector3& value) {
    return {static_cast<float>(value.x), static_cast<float>(value.y), static_cast<float>(value.z)};
}
Dictionary Target(const NativeSourceCameraTarget& target) {
    Dictionary out;
    out["kind"] = static_cast<int64_t>(target.Kind);
    out["identity"] = static_cast<int64_t>(target.Identity);
    return out;
}
Dictionary Event(const NativeSourceCameraEvent& event) {
    Dictionary out;
    out["sequence"] = static_cast<int64_t>(event.Sequence);
    out["kind"] = static_cast<int64_t>(event.Kind);
    out["from"] = static_cast<int64_t>(event.From);
    out["to"] = static_cast<int64_t>(event.To);
    out["target"] = Target(event.Target);
    out["switch"] = static_cast<int64_t>(event.Switch);
    out["time_ms"] = static_cast<int64_t>(event.TimeMs);
    out["duration_ms"] = static_cast<int64_t>(event.DurationMs);
    out["target_duration_ms"] = static_cast<int64_t>(event.TargetDurationMs);
    out["stop_moving"] = event.StopMoving;
    out["stop_catch_up"] = event.StopCatchUp;
    out["transition_beta"] = event.TransitionBeta;
    out["input_sequence"] = static_cast<int64_t>(event.InputSequence);
    return out;
}
}

Dictionary SALegacyCamera::Result(NativeSourceCameraStatus status) const {
    Dictionary out = Snapshot();
    out["ok"] = status == NativeSourceCameraStatus::Ok;
    out["status"] = String::utf8(StatusName(status));
    return out;
}

Dictionary SALegacyCamera::Initialize(int64_t epoch, int64_t pedIdentity, int64_t timeMs) {
    if (!HostUnsigned(epoch) || !HostUnsigned(pedIdentity) || !HostUnsigned(timeMs) ||
        static_cast<std::uint64_t>(timeMs) > std::numeric_limits<std::uint32_t>::max())
        return Result(NativeSourceCameraStatus::InvalidInput);
    return Result(m_Camera.Initialize(static_cast<std::uint64_t>(epoch),
        static_cast<std::uint64_t>(pedIdentity), static_cast<std::uint32_t>(timeMs)));
}

Dictionary SALegacyCamera::SetDirectlyBehind(int64_t timeMs, const Vector3& pedForward) {
    if (!HostUnsigned(timeMs) || static_cast<std::uint64_t>(timeMs) > std::numeric_limits<std::uint32_t>::max())
        return Result(NativeSourceCameraStatus::InvalidInput);
    return Result(m_Camera.SetDirectlyBehind(static_cast<std::uint32_t>(timeMs), SourceVector(pedForward)));
}

Dictionary SALegacyCamera::Restore(int64_t timeMs, int64_t playerState, int64_t pedIdentity,
    int64_t vehicleIdentity, bool vehiclePresent, bool playerWasOnBike,
    const Vector3& activeSourceFront, bool jumpCut, int64_t inputSequence) {
    if (!HostUnsigned(timeMs) || !HostUnsigned(playerState) || !HostUnsigned(pedIdentity) ||
        !HostUnsigned(vehicleIdentity) || !HostUnsigned(inputSequence) ||
        static_cast<std::uint64_t>(timeMs) > std::numeric_limits<std::uint32_t>::max() || playerState > 6)
        return Result(NativeSourceCameraStatus::InvalidInput);
    NativeSourceCameraPlayer player;
    player.State = static_cast<NativeSourceCameraPlayerState>(playerState);
    player.PedIdentity = static_cast<std::uint64_t>(pedIdentity);
    player.VehicleIdentity = static_cast<std::uint64_t>(vehicleIdentity);
    player.VehiclePresent = vehiclePresent;
    player.PlayerWasOnBike = playerWasOnBike;
    return Result(m_Camera.Restore(static_cast<std::uint32_t>(timeMs), player,
        SourceVector(activeSourceFront), jumpCut ? NativeSourceCameraSwitch::JumpCut :
        NativeSourceCameraSwitch::Interpolation, static_cast<std::uint64_t>(inputSequence)));
}

Dictionary SALegacyCamera::Advance(int64_t timeMs) {
    if (!HostUnsigned(timeMs) || static_cast<std::uint64_t>(timeMs) > std::numeric_limits<std::uint32_t>::max())
        return Result(NativeSourceCameraStatus::InvalidInput);
    return Result(m_Camera.Advance(static_cast<std::uint32_t>(timeMs)));
}

Dictionary SALegacyCamera::Snapshot() const {
    Dictionary out;
    const auto snapshot = m_Camera.LastCommitted();
    out["valid"] = bool(snapshot);
    out["view_status"] = "unsupported";
    out["presentation_feedback"] = false;
    if (!snapshot) return out;
    out["epoch"] = static_cast<int64_t>(snapshot->Epoch);
    out["generation"] = static_cast<int64_t>(snapshot->Generation);
    out["time_ms"] = static_cast<int64_t>(snapshot->TimeMs);
    out["mode"] = static_cast<int64_t>(snapshot->Mode);
    out["target"] = Target(snapshot->Target);
    out["input_sequence"] = static_cast<int64_t>(snapshot->InputSequence);
    out["directly_behind"] = snapshot->DirectlyBehind;
    out["directly_in_front"] = snapshot->DirectlyInFront;
    out["ped_orientation"] = snapshot->PedOrientationForBehindOrInFront;
    Dictionary transition;
    transition["active"] = snapshot->Transition.Active;
    transition["just_started"] = snapshot->Transition.JustStarted;
    transition["use_beta"] = snapshot->Transition.UseTransitionBeta;
    transition["start_ms"] = static_cast<int64_t>(snapshot->Transition.StartMs);
    transition["duration_ms"] = static_cast<int64_t>(snapshot->Transition.DurationMs);
    transition["target_duration_ms"] = static_cast<int64_t>(snapshot->Transition.TargetDurationMs);
    transition["stop_moving"] = snapshot->Transition.StopMoving;
    transition["stop_catch_up"] = snapshot->Transition.StopCatchUp;
    transition["target_stop_moving"] = snapshot->Transition.TargetStopMoving;
    transition["target_stop_catch_up"] = snapshot->Transition.TargetStopCatchUp;
    transition["beta"] = snapshot->Transition.TransitionBeta;
    out["transition"] = transition;
    Array events;
    for (const auto& event : snapshot->Events) events.push_back(Event(event));
    out["events"] = events;
    return out;
}

void SALegacyCamera::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize", "epoch", "ped_identity", "time_ms"), &SALegacyCamera::Initialize);
    ClassDB::bind_method(D_METHOD("set_directly_behind", "time_ms", "ped_forward"), &SALegacyCamera::SetDirectlyBehind);
    ClassDB::bind_method(D_METHOD("restore", "time_ms", "player_state", "ped_identity", "vehicle_identity",
        "vehicle_present", "player_was_on_bike", "active_source_front", "jump_cut", "input_sequence"),
        &SALegacyCamera::Restore, DEFVAL(false), DEFVAL(int64_t{0}));
    ClassDB::bind_method(D_METHOD("advance", "time_ms"), &SALegacyCamera::Advance);
    ClassDB::bind_method(D_METHOD("snapshot"), &SALegacyCamera::Snapshot);
}

} // namespace godot
