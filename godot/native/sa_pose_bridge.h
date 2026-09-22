#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include "app/platform/linux/NativePoseFamilies.h"

namespace godot {

// Standalone source-pose adapter. It owns copied CPU scenes only and must be
// used without an open pager bridge because both readers own parser-global RW
// state. Godot receives values; it cannot mutate the source pose owner.
class SALegacyPose final : public RefCounted {
    GDCLASS(SALegacyPose, RefCounted)

public:
    Dictionary CapturePed(const String& gameDir, const String& model,
        const String& clip, double fraction);
    Dictionary CaptureCutscene(const String& gameDir, const String& model,
        const String& bank, const String& clip, double fraction);
    Dictionary Snapshot() const;

protected:
    static void _bind_methods();

private:
    Dictionary Result(bool ok, const String& error = String()) const;
    NativePoseFamilies m_Poses;
};

} // namespace godot
