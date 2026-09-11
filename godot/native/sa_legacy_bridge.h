#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <cstdint>
#include <memory>
#include <string>

#include "app/platform/linux/NativeCollisionAssets.h"
#include "app/platform/linux/NativeLodCatalog.h"
#include "sa_region_worker.h"

namespace godot {

class SALegacyBridge : public RefCounted {
    GDCLASS(SALegacyBridge, RefCounted)

public:
    SALegacyBridge() = default;
    ~SALegacyBridge() override;

    Dictionary OpenGame(const String& gameDir, float radius, int32_t cap);
    Dictionary LoadRegion(const Vector3& saPosition);
    Dictionary SubmitRegion(const Vector3& saPosition);
    Dictionary PollRegion();
    Dictionary CancelRegion(int64_t requestId);
    Dictionary Environment(const String& weather, int32_t hour);
    void CloseGame();

protected:
    static void _bind_methods();

private:
    // P1-A05: converts one taken raw packet to Godot world without holding
    // raw state. Uses packet Frame/Counters, never StreamPager on main.
    // Increments m_PublicationRevision only after full successful conversion.
    Dictionary PreparePublication(const RawRegionPacket& raw);

    std::string m_GameDir;
    bool m_Ready = false;
    // Object-lifetime sequence: close/reopen preserves it; only a published region advances it.
    int64_t m_PublicationRevision = 0;
    // P1-A04 single-chain LOD supplement: actual paired render + COL packet only.
    // No gameplay physics, no general LOD, no A06. Retained across LoadRegion
    // calls; cleared on CloseGame without resetting m_PublicationRevision.
    std::shared_ptr<const NativeLodCatalog> m_Catalog;
    NativeLodChainDecision m_Decision;
    NativeCollisionPlacement m_ChildPlacement;
    NativeCollisionPlacement m_ParentPlacement;
    std::shared_ptr<const NativeCollisionModel> m_EffectiveCol;
    std::string m_EffectiveColLibrary;
    bool m_HasLodPair = false;
    // P1-A05 sole-owner async parser: created after all native config in
    // OpenGame, joined before Shutdown in CloseGame. Never reset across
    // close/reopen except for the worker handle itself.
    std::unique_ptr<RegionWorker> m_Worker;
    // Session epoch: increments on each successful Open, never reset, bound
    // to int64 max for Godot exposure. Zero means no session yet.
    uint64_t m_SessionEpoch = 0;
    // Monotonic request sequence: never reset across close/reopen, bound to
    // int64 max for Godot exposure. Next ID is m_NextRequestId + 1.
    uint64_t m_NextRequestId = 0;
    // Cumulative supersede diagnostic: increments when Submit replaces an
    // unpolled exposed request. Never reset across close/reopen.
    int64_t m_DiscardedStale = 0;
    // Latest exposed async request awaiting one-shot poll. Sync LoadRegion
    // rejects while this is set. Cleared one-shot by poll (ready/error/
    // cancelled), by superseding Submit (old counted as discarded), or Close.
    bool m_ExposedActive = false;
    uint64_t m_ExposedRequestId = 0;
    uint64_t m_ExposedEpoch = 0;
    // Cancel ack pending one-shot poll. A superseding Submit clears it and
    // the latest request wins.
    bool m_ExposedCancelled = false;
};

} // namespace godot
