// sa_region_worker: sole-owner asynchronous raw-region parser for P1-A05.
// Pure C++ coordinator: one parser thread owns ParseFn (production wires
// StreamPager_Update plus StreamPager_Counters capture). No Godot, no GL,
// no gameplay monolith, no escaped RenderWare pointers: packets carry only
// owned StreamPager value types (WorldShotScene, NativePlacementIdentity,
// E2EPagerFrame). Init/configuration precede thread startup; Shutdown
// follows Stop join.
//
// Coordinator protocol (main thread drives, worker parses):
// - Bridge assigns never-reused RequestIds and a session epoch. Worker
//   rejects RequestId 0, wrong epoch, nonincreasing IDs, nonfinite X/Y/Z,
//   and anything after Stop.
// - Latest-only mailbox, not a queue: Submit overwrites any queued request.
//   An in-flight parse is never interrupted (no force IO kill); its result
//   is discarded when stale. A ready packet that is stale is never taken;
//   the worker destroys it off mutex.
// - Terminal states wake every Waiter: Ready (take exactly once), Cancelled
//   (latest cancelled before take), Superseded (older than latest), Stopped
//   (worker stopped, or consumed/unknown/future ID). TryPoll never blocks.
// - No historical maps: only the latest ID plus one ready, one in-flight
//   (thread-local while parsing), one queued, and one retire slot are kept.
//   Older IDs report Superseded; future/unknown/consumed report Stopped.
// - Ownership: main holds at most one taken packet, converts it (GPU upload
//   in production) atomically, then Retires it for worker-side destruction
//   off mutex. Ready/build/main-retire are each one slot; no batched vector.
//   Retire waits only for the one retire slot to free (normal bridge holds
//   one packet, so no wait in practice). Stop is idempotent and joins the
//   parser before pager Shutdown. There is no ReleaseBusy API.
// - Parse exceptions never escape the thread: the worker stores them in
//   packet.Error and still publishes Ready (unless superseded/cancelled or
//   stopped). Factory spawn failure returns nullptr plus error.
// - NOTE for parent CMake: this TU throws/catches (parser exceptions) and
//   needs per-source -fexceptions like NATIVE_LOD_SOURCES. Parent wires that
//   later; this file must not change CMake here.
#pragma once

#include "app/platform/linux/StreamPager.h"

#include <array>
#include <condition_variable>
#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <vector>

struct RegionRequest {
    float X{};
    float Y{};
    float Z{};
    uint64_t RequestId{};
    uint64_t SessionEpoch{};
};

struct RawRegionPacket {
    explicit RawRegionPacket(const RegionRequest &request);
    const RegionRequest Request;
    WorldShotScene Scene;
    std::vector<NativePlacementIdentity> Rendered;
    E2EPagerFrame Frame{};
    std::array<int, 4> Counters{};
    std::string Error;
    double ParseMs{};
};

enum class RegionWait { Pending, Ready, Superseded, Cancelled, Stopped };

using ParseFn = std::function<void(RawRegionPacket &)>;

class RegionWorker {
public:
    // Creates and starts the single parser thread. Returns nullptr plus a
    // human-readable error when the parser is empty, the epoch is 0, or the
    // thread fails to spawn. Clears error on success.
    static std::unique_ptr<RegionWorker> Create(ParseFn parse, uint64_t sessionEpoch, std::string &error);

    ~RegionWorker();

    RegionWorker(const RegionWorker &) = delete;
    RegionWorker &operator=(const RegionWorker &) = delete;

    // Accepts only a fresh latest request: nonzero ID strictly greater than
    // every previously accepted ID, matching session epoch, finite XYZ, and
    // not stopped. Overwrites any queued (not yet started) request so only
    // the latest is ever parsed. Never destroys heavy packets under the
    // caller mutex; stale in-flight/ready results are discarded by the
    // worker off mutex. Returns true when accepted, false when rejected.
    bool Submit(const RegionRequest &request);

    // Cancels only the latest accepted ID when it is still untaken and not
    // already cancelled: queued work is dropped without parsing, in-flight
    // work finishes without interruption and is then discarded, ready-but-
    // untaken work is discarded without delivery. One-shot: repeat, older,
    // future/unknown, consumed, or stopped cancels return false. Wakes all
    // Waiters (Cancelled, or Stopped once Stop is requested).
    bool Cancel(uint64_t requestId);

    // Blocks until the ID reaches a terminal state, then returns it. Caller
    // must pass a null/empty out (debug builds assert this). Ready moves the
    // owned packet into out exactly once (one-shot take); every other
    // terminal leaves out null. Older than latest returns Superseded
    // immediately (even while the stale parse still runs); latest cancelled
    // returns Cancelled immediately (without waiting for the in-flight parse
    // to finish); consumed latest, unknown/future/zero IDs, and anything
    // after Stop return Stopped. A second waiter for the same Ready loses
    // and observes Stopped. Woken by every terminal transition.
    RegionWait Wait(uint64_t requestId, std::unique_ptr<RawRegionPacket> &out);

    // Nonblocking form of Wait: caller must pass a null/empty out (debug
    // builds assert this). Returns Pending when the latest ID is still queued
    // or in-flight, otherwise the same terminal mapping as Wait (including
    // one-shot Ready take). Never waits.
    RegionWait TryPoll(uint64_t requestId, std::unique_ptr<RawRegionPacket> &out);

    // Hands a previously taken packet back for worker-side destruction off
    // mutex. Null is a no-op. Waits only for the one retire slot to free;
    // the normal bridge retires its single held packet, so no wait occurs
    // in practice. After Stop the worker is gone and the packet is destroyed
    // inline. Never calls Godot.
    void Retire(std::unique_ptr<RawRegionPacket> packet);

    // Sequential coordinator-only termination (main thread): requests exit,
    // joins the parser thread, then releases any leftover ready/retire
    // payloads. Lets an in-flight parse finish and discards its result (no
    // force IO kill). Wakes all Waiters with Stopped. Idempotent for
    // sequential calls; safe in the destructor. Concurrent Stop callers must
    // not rely on both waiting for join. Call after the held packet is
    // retired and before pager Shutdown.
    void Stop();

private:
    explicit RegionWorker(ParseFn parse, uint64_t sessionEpoch);

    void ThreadMain();

    ParseFn m_Parse;
    uint64_t m_SessionEpoch;
    std::mutex m_Mutex;
    std::condition_variable m_Cv;
    uint64_t m_LatestId = 0;
    bool m_LatestCancelled = false;
    bool m_LatestTaken = false;
    std::optional<RegionRequest> m_Queued;
    uint64_t m_InflightId = 0;
    std::unique_ptr<RawRegionPacket> m_Ready;
    std::unique_ptr<RawRegionPacket> m_Retire;
    bool m_StopRequested = false;
    // Last: every field above is initialized before the thread can observe it.
    std::thread m_Thread;
};
