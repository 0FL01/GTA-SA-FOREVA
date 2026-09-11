#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cstdint>
#include <string>

namespace godot {

class SALegacyBridge : public RefCounted {
    GDCLASS(SALegacyBridge, RefCounted)

public:
    SALegacyBridge() = default;
    ~SALegacyBridge() override;

    Dictionary OpenGame(const String& gameDir, float radius, int32_t cap);
    Dictionary LoadRegion(const Vector3& saPosition);
    Dictionary Environment(const String& weather, int32_t hour);
    void CloseGame();

protected:
    static void _bind_methods();

private:
    std::string m_GameDir;
    bool m_Ready = false;
    // Object-lifetime sequence: close/reopen preserves it; only a published region advances it.
    int64_t m_PublicationRevision = 0;
};

} // namespace godot
