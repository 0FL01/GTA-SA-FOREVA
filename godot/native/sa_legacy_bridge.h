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
#include "sa_region_plan.h"
#include "sa_region_worker.h"
#include "app/platform/linux/NativeDiagnosticActors.h"

namespace godot {

class SALegacyBridge : public RefCounted {
    GDCLASS(SALegacyBridge, RefCounted)

public:
    SALegacyBridge();
    ~SALegacyBridge() override;

    Dictionary OpenGame(const String& gameDir, float radius, int32_t cap, int64_t budgetItems = 64, bool diagnosticActors = false);
    Dictionary DiagnosticActors(double alpha, bool includeTopology = false);
    Dictionary TickDiagnosticActors(double seconds, double forward, double side, bool sprint,
        bool jump, bool interact, bool brake = false, bool handbrake = false);
    Dictionary LoadRegion(const Vector3& saPosition);
    Dictionary SubmitRegion(const Vector3& saPosition);
    // P1-A07 opt-in catalog residency lane (area_id 0 = area0 XY disc with the
    // Open radius, positive = whole area). Existing Window signatures/behavior
    // incl cap are unchanged. Main validates coords/area range; in-range empty
    // selections may fail on the worker (no main-thread catalog scans).
    Dictionary LoadCatalogRegion(const Vector3& saPosition, int areaId = 0);
    Dictionary SubmitCatalogRegion(const Vector3& saPosition, int areaId = 0);
    Dictionary PollRegion();
    Dictionary CancelRegion(int64_t requestId);
    Dictionary Environment(const String& weather, int32_t hour);
    void CloseGame();

protected:
    static void _bind_methods();

private:
    // P1-A06 incremental conversion + single retiring slot. Exactly one
    // current conversion plus ONE retiring generation; admission of the next
    // worker Ready is gated until retiring is empty. Raw requests still
    // coalesce in the worker queue. Definitions live in sa_legacy_bridge.cpp
    // so Godot Ref destruction stays on main with honest per-unit timing.
    struct StagedConversion;
    struct RetiringGeneration;

    Dictionary BuildProgressLocked(const String& phase, int64_t done, int64_t total) const;
    int64_t RetirePendingLocked() const;
    void DrainRetiringLocked(int64_t quota);
    void FlushRetiringUnbudgetedLocked();
    void DiscardConversionToRetiringLocked();
    bool ConversionMatchesExposedLocked() const;
    // Returns false plus error/code/context for immediate terminals (parse
    // failure, plan failure, revision exhausted) without creating a staged
    // conversion. Returns true when m_Conversion is initialized for budgeted
    // stepping (plan ok, revision ok).
    bool InitConversionLocked(std::unique_ptr<RawRegionPacket> packet, String& error,
                              String& errorCode, Dictionary& errorContext);
    enum class AdvanceOutcome { NeedMore, Ready, Error };
    // Advances m_Conversion by up to quota units (textures/surfaces/metadata/
    // paired, one shared quota). Increments frames once per call that does
    // work. Measures each atomic Godot unit honestly into msTotal/msMax.
    AdvanceOutcome AdvanceConversionLocked(int64_t quota, String& error);
    int64_t ConversionTotalLocked() const;
    int64_t ConversionDoneLocked() const;
    String ConversionPhaseLocked() const;
    // Builds the exact former ready payload (meshes/stats/lineage) from a
    // completed conversion, increments revision, retires raw on the worker,
    // and clears m_Conversion. Only call when Advance returned Ready.
    Dictionary BuildReadyPayloadLocked();
    // P1-A07 shared submit/load state machines (single implementation for
    // Window + catalog lanes; no duplicated hundreds-of-lines protocol).
    // Selection/AreaId ride the RegionRequest; Window uses AreaId 0.
    Dictionary SubmitRegionInternal(const Vector3& saPosition, RegionSelection selection,
                                    int areaId);
    Dictionary LoadRegionInternal(const Vector3& saPosition, RegionSelection selection,
                                  int areaId);

    std::string m_GameDir;
    bool m_Ready = false;
    std::unique_ptr<NativeDiagnosticActors> m_DiagnosticActors;
    // Object-lifetime sequence: close/reopen preserves it; only a published region advances it.
    int64_t m_PublicationRevision = 0;
    // P1-A04 single-chain LOD supplement: actual paired render + COL packet only.
    // No gameplay physics, no general LOD. Retained across LoadRegion
    // calls; cleared on CloseGame without resetting m_PublicationRevision.
    std::shared_ptr<const NativeLodCatalog> m_Catalog;
    // P1-A07 Open radius captured for catalog-disc selection (area0 XY disc).
    // Set on successful Open, cleared on Close. ParseFn captures it by value
    // alongside the shared catalog; positive areas ignore it (whole area).
    float m_OpenRadius = 0.0f;
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
    // cancelled/preparing stays active), by superseding Submit (old counted
    // as discarded), or Close.
    bool m_ExposedActive = false;
    uint64_t m_ExposedRequestId = 0;
    uint64_t m_ExposedEpoch = 0;
    // Cancel ack pending one-shot poll. A superseding Submit clears it and
    // the latest request wins.
    bool m_ExposedCancelled = false;
    // P1-A06 budget: logical conversion/staging/retirement work quota per
    // PollRegion call (shared single quota, not N times quota). 1..4096,
    // default 64. Set on successful Open, preserved across Close.
    int64_t m_BudgetItems = 64;
    // Cumulative staged discards: increments when a taken (preparing)
    // conversion is locally cancelled/superseded into the single retire
    // slot. Never reset across close/reopen. Repeated cancel cannot append
    // because admission is closed (one-shot cancel ack).
    int64_t m_StagedDiscards = 0;
    double m_RetireMsTotal = 0.0;
    double m_RetireMsMaxItem = 0.0;
    std::unique_ptr<StagedConversion> m_Conversion;
    std::unique_ptr<RetiringGeneration> m_Retiring;
};

} // namespace godot
