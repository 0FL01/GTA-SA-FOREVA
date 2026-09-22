#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include "app/platform/linux/NativeFrontendLifecycle.h"

namespace godot {

class SALegacyFrontend final : public RefCounted {
    GDCLASS(SALegacyFrontend, RefCounted)
public:
    Dictionary Initialize(int64_t epoch, int64_t pedIdentity, int64_t timeMs);
    Dictionary StartGame(int64_t timeMs, const Vector2& player, int64_t inputSequence = 0);
    Dictionary Pause(int64_t timeMs, int64_t inputSequence = 0);
    Dictionary OpenMap(int64_t timeMs, int64_t inputSequence = 0);
    Dictionary PanMap(int64_t timeMs, const Vector2& delta, int64_t inputSequence = 0);
    Dictionary ZoomMap(int64_t timeMs, double zoom, int64_t inputSequence = 0);
    Dictionary Back(int64_t timeMs, int64_t inputSequence = 0);
    Dictionary OpenOptions(int64_t timeMs, int64_t inputSequence = 0);
    Dictionary OpenDisplay(int64_t timeMs, int64_t inputSequence = 0);
    Dictionary SetDisplay(int64_t timeMs, const Dictionary& settings, int64_t inputSequence = 0);
    Dictionary Resume(int64_t timeMs, int64_t inputSequence = 0);
    Dictionary SetCameraDirectlyBehind(int64_t timeMs, const Vector3& forward);
    Dictionary Snapshot() const;
protected:
    static void _bind_methods();
private:
    Dictionary Result(NativeFrontendStatus) const;
    NativeFrontendLifecycle m_Frontend;
};

} // namespace godot
