#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include "app/platform/linux/NativeSourceCamera.h"

namespace godot {

// Value-only adapter for NativeSourceCamera. It accepts explicit caller-owned
// identities/time/input sequence and source camera front vectors. It never
// reads or writes a Godot Camera3D/Node transform, and exposes no view pose.
class SALegacyCamera final : public RefCounted {
    GDCLASS(SALegacyCamera, RefCounted)

public:
    Dictionary Initialize(int64_t epoch, int64_t pedIdentity, int64_t timeMs);
    Dictionary SetDirectlyBehind(int64_t timeMs, const Vector3& pedForward);
    Dictionary Restore(int64_t timeMs, int64_t playerState, int64_t pedIdentity,
        int64_t vehicleIdentity, bool vehiclePresent, bool playerWasOnBike,
        const Vector3& activeSourceFront, bool jumpCut = false, int64_t inputSequence = 0);
    Dictionary Advance(int64_t timeMs);
    Dictionary Snapshot() const;

protected:
    static void _bind_methods();

private:
    Dictionary Result(NativeSourceCameraStatus) const;
    NativeSourceCamera m_Camera;
};

} // namespace godot
