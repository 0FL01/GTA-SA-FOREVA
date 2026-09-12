// P2-A01 owned SCM startup seed. No Godot VM, no boot claim, no world.
// Loads the real main.scm through the existing session, pins the Probe's
// metadata, advances the existing game clock to 123ms, commits 14 pure
// instructions, then proves the first unavailable frontier (04E4 collision)
// with explicit Unsupported services and atomic failure preservation.
#include "app/platform/linux/NativeScriptSession.h"

#include <array>
#include <cstdint>
#include <cstdio>
#include <span>
#include <string>
#include <vector>

namespace {

using Bytes = std::vector<std::uint8_t>;

struct StartupServices final : NativeScriptServices {
    NativeScriptCollisionRequest Collision{};
    NativeScriptSceneRequest Scene{};
    NativeScriptPlayerRequest Player{};
    unsigned CollisionCalls = 0;
    unsigned SceneCalls = 0;
    unsigned PlayerCalls = 0;

    NativeScriptServiceResult RequestCollision(const NativeScriptCollisionRequest& request) override {
        Collision = request;
        ++CollisionCalls;
        return {NativeScriptServiceStatus::Unsupported, "sa-core-startup P2-A01: collision unavailable"};
    }
    NativeScriptServiceResult LoadScene(const NativeScriptSceneRequest& request) override {
        Scene = request;
        ++SceneCalls;
        return {NativeScriptServiceStatus::Unsupported, "sa-core-startup P2-A01: scene unavailable"};
    }
    NativeScriptServiceResult CreatePlayer(const NativeScriptPlayerRequest& request) override {
        Player = request;
        ++PlayerCalls;
        return {NativeScriptServiceStatus::Unsupported, "sa-core-startup P2-A01: player unavailable"};
    }
};

bool SetError(std::string& error, const char* message) {
    error = message;
    std::fprintf(stderr, "sa-core-startup FAIL: %s\n", message);
    return false;
}

bool MetadataEqual(const NativeScriptMetadata& a, const NativeScriptMetadata& b, std::string& error) {
    if (a.MainSize != b.MainSize) return SetError(error, "metadata MainSize changed");
    if (a.CodeStart != b.CodeStart) return SetError(error, "metadata CodeStart changed");
    if (a.GlobalBytes != b.GlobalBytes) return SetError(error, "metadata GlobalBytes changed");
    if (a.LargestMission != b.LargestMission) return SetError(error, "metadata LargestMission changed");
    if (a.MissionLocals != b.MissionLocals) return SetError(error, "metadata MissionLocals changed");
    if (a.StreamedScripts != b.StreamedScripts) return SetError(error, "metadata StreamedScripts changed");
    if (a.LargestStreamed != b.LargestStreamed) return SetError(error, "metadata LargestStreamed changed");
    if (a.Build != b.Build) return SetError(error, "metadata Build changed");
    if (a.MissionOffsets != b.MissionOffsets) return SetError(error, "metadata MissionOffsets changed");
    if (a.UsedObjects.size() != b.UsedObjects.size()) return SetError(error, "metadata UsedObjects size changed");
    for (std::size_t i = 0; i < a.UsedObjects.size(); ++i) {
        if (a.UsedObjects[i] != b.UsedObjects[i]) return SetError(error, "metadata UsedObjects entry changed");
    }
    return true;
}

struct SessionSnapshot {
    bool Loaded = false;
    NativeScriptState State{};
    std::vector<NativeScriptThreadState> Threads;
    NativeScriptMetadata Metadata{};
    std::vector<std::int32_t> Globals;
};

bool TakeSnapshot(const NativeScriptSession& session, SessionSnapshot& snapshot, std::string& error) {
    snapshot.Loaded = session.Loaded();
    snapshot.State = session.State();
    const auto threads = session.Threads();
    snapshot.Threads.assign(threads.begin(), threads.end());
    snapshot.Metadata = session.Metadata();
    snapshot.Globals.clear();
    const std::uint32_t bytes = session.Metadata().GlobalBytes;
    for (std::uint32_t offset = 8; offset + 4 <= 8 + bytes; offset += 4) {
        std::int32_t value = 0;
        if (!session.ReadGlobal(static_cast<std::uint16_t>(offset), value)) {
            return SetError(error, "snapshot ReadGlobal failed");
        }
        snapshot.Globals.push_back(value);
    }
    error.clear();
    return true;
}

bool CheckSnapshot(const NativeScriptSession& session, const SessionSnapshot& snapshot, std::string& error) {
    if (session.Loaded() != snapshot.Loaded) return SetError(error, "atomic failure changed Loaded");
    if (!(session.State() == snapshot.State)) return SetError(error, "atomic failure changed State");
    const auto threads = session.Threads();
    if (threads.size() != snapshot.Threads.size()) return SetError(error, "atomic failure changed thread count");
    for (std::size_t i = 0; i < threads.size(); ++i) {
        if (!(threads[i] == snapshot.Threads[i])) return SetError(error, "atomic failure changed thread");
    }
    if (!MetadataEqual(session.Metadata(), snapshot.Metadata, error)) return false;
    for (std::size_t i = 0; i < snapshot.Globals.size(); ++i) {
        std::int32_t value = 0;
        const auto offset = static_cast<std::uint16_t>(8 + i * 4);
        if (!session.ReadGlobal(offset, value)) return SetError(error, "atomic ReadGlobal failed");
        if (value != snapshot.Globals[i]) return SetError(error, "atomic failure changed global memory");
    }
    error.clear();
    return true;
}

bool CheckMetadataPins(const NativeScriptMetadata& metadata, std::string& error) {
    if (metadata.MainSize != 194125) return SetError(error, "metadata MainSize pin mismatch");
    if (metadata.CodeStart != 55976) return SetError(error, "metadata CodeStart pin mismatch");
    if (metadata.GlobalBytes != 43800) return SetError(error, "metadata GlobalBytes pin mismatch");
    if (metadata.MissionOffsets.size() != 135) return SetError(error, "metadata mission count pin mismatch");
    if (metadata.MissionOffsets.front() != 194125) return SetError(error, "metadata mission front pin mismatch");
    if (metadata.LargestMission != 68439) return SetError(error, "metadata LargestMission pin mismatch");
    if (metadata.MissionLocals != 964) return SetError(error, "metadata MissionLocals pin mismatch");
    if (metadata.StreamedScripts != 79) return SetError(error, "metadata StreamedScripts pin mismatch");
    if (metadata.LargestStreamed != 35122) return SetError(error, "metadata LargestStreamed pin mismatch");
    if (metadata.Build != 569) return SetError(error, "metadata Build pin mismatch");
    error.clear();
    return true;
}

bool LoadFileBytes(const char* gameDir, Bytes& out, std::string& error) {
    if (!gameDir || !*gameDir) return SetError(error, "invalid game directory");
    const std::string path = std::string(gameDir) + "/data/script/main.scm";
    if (path.size() >= 2048) return SetError(error, "SCM path too long");
    FILE* file = std::fopen(path.c_str(), "rb");
    if (!file) return SetError(error, "cannot open main.scm for snapshot copy");
    struct Closer {
        FILE* File;
        ~Closer() { if (File) std::fclose(File); }
    } closer{file};
    if (std::fseek(file, 0, SEEK_END) != 0) return SetError(error, "SCM seek failed");
    const long size = std::ftell(file);
    if (size < 0) return SetError(error, "SCM tell failed");
    if (std::fseek(file, 0, SEEK_SET) != 0) return SetError(error, "SCM rewind failed");
    out.resize(static_cast<std::size_t>(size));
    if (size > 0 && std::fread(out.data(), 1, static_cast<std::size_t>(size), file) != static_cast<std::size_t>(size)) {
        out.clear();
        return SetError(error, "short SCM read for snapshot copy");
    }
    error.clear();
    return true;
}

bool ReadU32LE(const Bytes& bytes, std::size_t pos, std::uint32_t& out, std::string& error) {
    if (pos + 4 > bytes.size()) return SetError(error, "payload offset out of range");
    out = std::uint32_t(bytes[pos]) | (std::uint32_t(bytes[pos + 1]) << 8) |
          (std::uint32_t(bytes[pos + 2]) << 16) | (std::uint32_t(bytes[pos + 3]) << 24);
    error.clear();
    return true;
}

// Minimal source-offset derivation (two header next links to chunk 2), not a
// duplicated SCM parser. Full validation stays inside LoadMainBytes.
bool FindFirstMissionOffsetPos(const Bytes& bytes, std::size_t& outPos, std::string& error) {
    if (bytes.size() < 8) return SetError(error, "payload too small for header chain");
    std::uint32_t next0 = 0, next1 = 0;
    if (!ReadU32LE(bytes, 3, next0, error)) return false;
    if (next0 > bytes.size() || next0 + 8 > bytes.size()) return SetError(error, "bad chunk0 next");
    if (!ReadU32LE(bytes, static_cast<std::size_t>(next0) + 3, next1, error)) return false;
    if (next1 > bytes.size() || bytes.size() - next1 < 28) return SetError(error, "bad chunk2 extent");
    if (bytes[static_cast<std::size_t>(next1) + 7] != 1) return SetError(error, "unexpected chunk2 index");
    outPos = static_cast<std::size_t>(next1) + 24;
    if (outPos + 4 > bytes.size()) return SetError(error, "mission offset out of range");
    error.clear();
    return true;
}

bool CheckAtomicReload(NativeScriptSession& session, const SessionSnapshot& before, bool reloaded,
    const std::string& reloadError, const char* what, std::string& error) {
    if (reloaded) return SetError(error, what);
    if (reloadError.empty()) return SetError(error, "failed load left empty error");
    if (!CheckSnapshot(session, before, error)) return false;
    error.clear();
    return true;
}

bool RunStartup(const char* gameDir, std::string& error) {
    if (!gameDir || !*gameDir) return SetError(error, "missing game directory argument");
    NativeScriptSession session;
    StartupServices services;

    if (!session.LoadMain(gameDir, error)) {
        std::fprintf(stderr, "sa-core-startup FAIL: LoadMain: %s\n", error.c_str());
        return false;
    }
    if (!CheckMetadataPins(session.Metadata(), error)) return false;
    if (!session.AdvanceTime(123, error)) {
        std::fprintf(stderr, "sa-core-startup FAIL: AdvanceTime: %s\n", error.c_str());
        return false;
    }
    if (!session.Loaded()) return SetError(error, "session not loaded after LoadMain");
    if (session.State().IP != 0) return SetError(error, "session did not seed at IP 0");
    if (session.Threads().size() != 1) return SetError(error, "seed thread count is not 1");

    Bytes payload;
    if (!LoadFileBytes(gameDir, payload, error)) return false;
    if (payload.empty()) return SetError(error, "snapshot payload is empty");

    // Failure-atomic cases: every rejected reload must leave the live session
    // (Loaded/State/Threads/all metadata/global memory) semantically identical.
    {
        SessionSnapshot before{};
        if (!TakeSnapshot(session, before, error)) return false;
        std::string reloadError;
        const bool reloaded = session.LoadMainBytes(std::span<const std::uint8_t>(payload.data(), payload.size()),
            static_cast<std::uint64_t>(payload.size()) + 1, reloadError);
        if (!CheckAtomicReload(session, before, reloaded, reloadError, "size-mismatch payload unexpectedly loaded", error)) {
            return false;
        }
    }
    {
        SessionSnapshot before{};
        if (!TakeSnapshot(session, before, error)) return false;
        Bytes corrupt = payload;
        corrupt[0] = static_cast<std::uint8_t>(corrupt[0] ^ 0xFF);
        std::string reloadError;
        const bool reloaded = session.LoadMainBytes(
            std::span<const std::uint8_t>(corrupt.data(), corrupt.size()),
            static_cast<std::uint64_t>(corrupt.size()), reloadError);
        if (!CheckAtomicReload(session, before, reloaded, reloadError, "invalid GOTO marker unexpectedly loaded", error)) {
            return false;
        }
    }
    {
        SessionSnapshot before{};
        if (!TakeSnapshot(session, before, error)) return false;
        std::size_t offsetPos = 0;
        if (!FindFirstMissionOffsetPos(payload, offsetPos, error)) return false;
        Bytes corrupt = payload;
        corrupt[offsetPos] = 8;
        corrupt[offsetPos + 1] = 0;
        corrupt[offsetPos + 2] = 0;
        corrupt[offsetPos + 3] = 0;
        std::string reloadError;
        const bool reloaded = session.LoadMainBytes(
            std::span<const std::uint8_t>(corrupt.data(), corrupt.size()),
            static_cast<std::uint64_t>(corrupt.size()), reloadError);
        if (!CheckAtomicReload(session, before, reloaded, reloadError, "mission offset before main unexpectedly loaded", error)) {
            return false;
        }
    }
    {
        SessionSnapshot before{};
        if (!TakeSnapshot(session, before, error)) return false;
        std::string reloadError;
        // A proven regular source file cannot also be an installation directory.
        const std::string nonDirectory = std::string(gameDir) + "/data/script/main.scm";
        const bool reloaded = session.LoadMain(nonDirectory.c_str(), reloadError);
        if (!CheckAtomicReload(session, before, reloaded, reloadError, "missing game path unexpectedly loaded", error)) {
            return false;
        }
    }

    // Recorded real prefix from NativeScriptSessionProbe.cpp RealAsset:
    // 6 header GOTOs + 8 pure setters = 14 commits, then 04E4 collision.
    constexpr std::uint32_t kIps[] = {0, 43808, 53156, 53720, 55948, 55960, 55976, 55987,
        55993, 55998, 56003, 56008, 56012, 56016, 56022, 56034};
    constexpr std::uint16_t kOpcodes[] = {2, 2, 2, 2, 2, 2, 0x03A4, 0x016A, 0x042C,
        0x030D, 0x0997, 0x01F0, 0x0111, 0x00C0};
    for (unsigned i = 0; i < 14; ++i) {
        const auto result = session.Step(services);
        if (result.Status != NativeScriptStatus::Advanced) return SetError(error, "pure prefix did not advance");
        if (result.Executed != 1) return SetError(error, "pure prefix did not commit once");
        if (result.Opcode != kOpcodes[i]) return SetError(error, "unexpected pure prefix opcode");
        if (result.IP != kIps[i + 1]) return SetError(error, "unexpected pure prefix frontier");
        if (session.State().IP != kIps[i + 1]) return SetError(error, "state IP left the recorded prefix");
        if (session.State().LastOpcode != kOpcodes[i]) return SetError(error, "state opcode left the recorded prefix");
    }
    if (session.State().Commands != 14) return SetError(error, "pure prefix command count is not 14");
    if (services.CollisionCalls != 0 || services.SceneCalls != 0 || services.PlayerCalls != 0) {
        return SetError(error, "pure prefix caused a service call");
    }
    const auto& clocked = session.State().Clock;
    if (clocked.Hours != 8 || clocked.Minutes != 0 || clocked.Seconds != 0 ||
        clocked.LastTickMs != 123 || clocked.Revision != 1) {
        return SetError(error, "clock is not 8:00:00/lastTick123/revision1");
    }

    const auto beforeFrontier = session.State();
    const std::vector<NativeScriptThreadState> threadsBefore(session.Threads().begin(), session.Threads().end());
    const auto frontier = session.Step(services);
    if (frontier.Status != NativeScriptStatus::Unsupported) return SetError(error, "frontier is not unavailable");
    if (frontier.Opcode == 0x0053 || frontier.Opcode == 0x0417 || frontier.Opcode == 0x0814) {
        return SetError(error, "frontier reached player/mission/unknown instead of collision");
    }
    if (frontier.Opcode != 0x04E4) return SetError(error, "unexpected frontier opcode");
    if (frontier.IP != 56022) return SetError(error, "unexpected frontier IP");
    if (frontier.Executed != 0) return SetError(error, "unavailable frontier committed");
    if (frontier.Message.empty()) return SetError(error, "unavailable frontier left empty message");
    if (services.CollisionCalls != 1) return SetError(error, "collision barrier did not record one DTO");
    if (services.SceneCalls != 0 || services.PlayerCalls != 0) {
        return SetError(error, "frontier reached scene/player instead of collision only");
    }
    if (!(services.Collision.X == 2488.562255859375f && services.Collision.Y == -1666.864501953125f)) {
        return SetError(error, "collision DTO coordinates differ from authored values");
    }
    if (!(session.State() == beforeFrontier)) return SetError(error, "unavailable frontier mutated state");
    if (session.Threads().size() != threadsBefore.size()) return SetError(error, "unavailable frontier changed threads");
    for (std::size_t i = 0; i < threadsBefore.size(); ++i) {
        if (!(session.Threads()[i] == threadsBefore[i])) return SetError(error, "unavailable frontier mutated thread");
    }
    const auto sticky = session.Step(services);
    if (sticky.Status != NativeScriptStatus::Unsupported || sticky.Opcode != 0x04E4 ||
        sticky.IP != 56022 || sticky.Executed != 0) {
        return SetError(error, "unavailable fault is not sticky");
    }
    if (!(session.State() == beforeFrontier)) return SetError(error, "sticky fault mutated state");
    if (services.CollisionCalls != 1) return SetError(error, "sticky fault retried the service");

    std::printf("sa-core-frontier unavailable opcode=04E4 ip=56022 next=56034 reason=collision-unavailable\n");
    error.clear();
    return true;
}

} // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        std::fprintf(stderr, "usage: sa_core_startup <owned-game-dir>\n");
        return 1;
    }
    std::string error;
    if (!RunStartup(argv[1], error)) {
        if (!error.empty()) std::fprintf(stderr, "sa-core-startup FAIL: %s\n", error.c_str());
        return 1;
    }
    std::printf("sa-core-startup-ok\n");
    return 0;
}
