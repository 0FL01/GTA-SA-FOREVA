#include "sa_audio_bridge.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include <cstring>
#include <string>

namespace godot {
namespace {
const char* FamilyName(NativeAudioFamily family) {
    switch (family) {
    case NativeAudioFamily::Sfx: return "sfx";
    case NativeAudioFamily::Speech: return "speech";
    case NativeAudioFamily::Environment: return "environment";
    }
    return "unknown";
}

const char* EncodingName(NativeAudioEncoding encoding) {
    return encoding == NativeAudioEncoding::Pcm16Mono ? "pcm16_mono" : "ogg_vorbis";
}

Dictionary Asset(const NativeAudioFamilyAsset& asset) {
    Dictionary out;
    out["family"] = FamilyName(asset.Family);
    out["encoding"] = EncodingName(asset.Encoding);
    out["source_event"] = asset.SourceEvent;
    out["bank"] = asset.Bank;
    out["sound"] = asset.Sound;
    out["rate"] = static_cast<int64_t>(asset.Rate);
    out["duration_ms"] = static_cast<int64_t>(asset.DurationMs);
    out["loop_start"] = asset.LoopStart;
    out["hash"] = static_cast<int64_t>(asset.Hash);
    PackedByteArray payload;
    if (asset.Payload) {
        payload.resize(static_cast<int64_t>(asset.Payload->size()));
        if (!asset.Payload->empty()) std::memcpy(payload.ptrw(), asset.Payload->data(), asset.Payload->size());
    }
    out["payload"] = payload;
    return out;
}
}

Dictionary SALegacyAudio::Load(const String& gameDir) {
    std::string error;
    if (!m_Audio.Load(gameDir.utf8().get_data(), error)) {
        m_Error = String::utf8(error.c_str());
        Dictionary out = Snapshot();
        out["ok"] = false;
        return out;
    }
    m_Error = String();
    Dictionary out = Snapshot();
    out["ok"] = true;
    return out;
}

Dictionary SALegacyAudio::Snapshot() const {
    Dictionary out;
    out["loaded"] = m_Audio.Loaded();
    out["error"] = m_Error;
    out["output_feedback"] = false;
    Array assets;
    if (m_Audio.Loaded()) {
        for (const auto& asset : m_Audio.Assets()) assets.push_back(Asset(asset));
    }
    out["assets"] = assets;
    return out;
}

void SALegacyAudio::_bind_methods() {
    ClassDB::bind_method(D_METHOD("load", "game_dir"), &SALegacyAudio::Load);
    ClassDB::bind_method(D_METHOD("snapshot"), &SALegacyAudio::Snapshot);
}

} // namespace godot
