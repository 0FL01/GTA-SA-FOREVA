#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include "app/platform/linux/NativeAudioFamilies.h"

namespace godot {

class SALegacyAudio final : public RefCounted {
    GDCLASS(SALegacyAudio, RefCounted)
public:
    Dictionary Load(const String& gameDir);
    Dictionary Snapshot() const;
protected:
    static void _bind_methods();
private:
    NativeAudioFamilies m_Audio;
    String m_Error;
};

} // namespace godot
