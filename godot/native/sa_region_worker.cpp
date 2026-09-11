// sa_region_worker implementation: latest-only sole parser, bounded slots,
// worker-side heavy destruction. See sa_region_worker.h for the coordinator
// protocol. No Godot/GL/gameplay linkage here; only owned StreamPager value
// types plus the C++ standard library.

#include "sa_region_worker.h"

#include <cassert>
#include <chrono>
#include <cmath>
#include <exception>
#include <utility>

namespace {

double NowMs() {
    return std::chrono::duration<double, std::milli>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}

} // namespace

RawRegionPacket::RawRegionPacket(const RegionRequest &request)
    : Request(request) {
}

RegionWorker::RegionWorker(ParseFn parse, uint64_t sessionEpoch)
    : m_Parse(std::move(parse))
    , m_SessionEpoch(sessionEpoch)
    , m_Thread([this] { ThreadMain(); }) {
}

std::unique_ptr<RegionWorker> RegionWorker::Create(ParseFn parse, uint64_t sessionEpoch, std::string &error) {
    if (!parse) {
        error = "region worker requires a parser";
        return nullptr;
    }
    if (sessionEpoch == 0) {
        error = "region worker requires a nonzero session epoch";
        return nullptr;
    }
    try {
        std::unique_ptr<RegionWorker> worker(new RegionWorker(std::move(parse), sessionEpoch));
        error.clear();
        return worker;
    } catch (const std::exception &failure) {
        error = failure.what();
        return nullptr;
    } catch (...) {
        error = "unknown region worker spawn failure";
        return nullptr;
    }
}

RegionWorker::~RegionWorker() {
    Stop();
}

bool RegionWorker::Submit(const RegionRequest &request) {
    std::unique_lock<std::mutex> lock(m_Mutex);
    if (m_StopRequested) {
        return false;
    }
    if (request.RequestId == 0) {
        return false;
    }
    if (request.SessionEpoch != m_SessionEpoch) {
        return false;
    }
    if (request.RequestId <= m_LatestId) {
        return false;
    }
    if (!std::isfinite(request.X) || !std::isfinite(request.Y) || !std::isfinite(request.Z)) {
        return false;
    }
    m_LatestId = request.RequestId;
    m_LatestCancelled = false;
    m_LatestTaken = false;
    // Latest-only coalescing: overwrite any queued request. A previous
    // in-flight parse keeps running but its result becomes stale and is
    // discarded; a previous ready packet becomes stale and is destroyed by
    // the worker off mutex. Nothing heavy is destroyed under this lock.
    m_Queued = request;
    lock.unlock();
    m_Cv.notify_all();
    return true;
}

bool RegionWorker::Cancel(uint64_t requestId) {
    std::unique_lock<std::mutex> lock(m_Mutex);
    if (m_StopRequested) {
        return false;
    }
    if (requestId == 0 || requestId != m_LatestId) {
        return false;
    }
    if (m_LatestCancelled || m_LatestTaken) {
        return false;
    }
    // Mark the latest cancelled and drop queued work so it is never parsed.
    // In-flight work is not interrupted; its result is discarded on
    // completion. Ready-but-untaken work becomes stale for worker cleanup.
    m_LatestCancelled = true;
    m_Queued.reset();
    lock.unlock();
    m_Cv.notify_all();
    return true;
}

RegionWait RegionWorker::Wait(uint64_t requestId, std::unique_ptr<RawRegionPacket> &out) {
    assert(!out && "Wait out must be null on entry");
    // Defensive: never destroy a caller-violating packet under the worker
    // mutex. Moving is cheap (noexcept); the stray (if any) is destroyed on
    // scope exit after the worker lock is released (declared before lock).
    std::unique_ptr<RawRegionPacket> stray = std::move(out);
    std::unique_lock<std::mutex> lock(m_Mutex);
    for (;;) {
        if (m_StopRequested) {
            out.reset();
            return RegionWait::Stopped;
        }
        if (requestId == 0 || requestId > m_LatestId) {
            out.reset();
            return RegionWait::Stopped;
        }
        if (requestId < m_LatestId) {
            out.reset();
            return RegionWait::Superseded;
        }
        if (m_LatestTaken) {
            out.reset();
            return RegionWait::Stopped;
        }
        if (m_LatestCancelled) {
            out.reset();
            return RegionWait::Cancelled;
        }
        if (m_Ready && m_Ready->Request.RequestId == requestId) {
            out = std::move(m_Ready);
            m_LatestTaken = true;
            lock.unlock();
            m_Cv.notify_all();
            return RegionWait::Ready;
        }
        // Still queued or in-flight: wait for supersession, cancel, publish,
        // take by a competing waiter, or stop. Every terminal path notifies.
        m_Cv.wait(lock);
    }
}

RegionWait RegionWorker::TryPoll(uint64_t requestId, std::unique_ptr<RawRegionPacket> &out) {
    assert(!out && "TryPoll out must be null on entry");
    // Same stray rule as Wait: no heavy caller destroy under worker mutex.
    std::unique_ptr<RawRegionPacket> stray = std::move(out);
    std::unique_lock<std::mutex> lock(m_Mutex);
    if (m_StopRequested) {
        out.reset();
        return RegionWait::Stopped;
    }
    if (requestId == 0 || requestId > m_LatestId) {
        out.reset();
        return RegionWait::Stopped;
    }
    if (requestId < m_LatestId) {
        out.reset();
        return RegionWait::Superseded;
    }
    if (m_LatestTaken) {
        out.reset();
        return RegionWait::Stopped;
    }
    if (m_LatestCancelled) {
        out.reset();
        return RegionWait::Cancelled;
    }
    if (m_Ready && m_Ready->Request.RequestId == requestId) {
        out = std::move(m_Ready);
        m_LatestTaken = true;
        lock.unlock();
        m_Cv.notify_all();
        return RegionWait::Ready;
    }
    out.reset();
    return RegionWait::Pending;
}

void RegionWorker::Retire(std::unique_ptr<RawRegionPacket> packet) {
    if (!packet) {
        return;
    }
    std::unique_lock<std::mutex> lock(m_Mutex);
    if (m_StopRequested) {
        lock.unlock();
        packet.reset();
        return;
    }
    // One-slot retire: bound memory while the worker destroys heavy payloads
    // off mutex. The normal bridge holds at most one taken packet, so this
    // wait does not trigger in practice.
    m_Cv.wait(lock, [this] { return !m_Retire || m_StopRequested; });
    if (m_StopRequested) {
        lock.unlock();
        packet.reset();
        return;
    }
    m_Retire = std::move(packet);
    lock.unlock();
    m_Cv.notify_all();
}

void RegionWorker::Stop() {
    std::thread joining;
    {
        std::unique_lock<std::mutex> lock(m_Mutex);
        if (!m_Thread.joinable()) {
            return;
        }
        if (m_Thread.get_id() == std::this_thread::get_id()) {
            // Sequential coordinator-only: never join self; flag exit and let
            // the outer sequential Stop join.
            m_StopRequested = true;
            lock.unlock();
            m_Cv.notify_all();
            return;
        }
        m_StopRequested = true;
        lock.unlock();
        m_Cv.notify_all();
        lock.lock();
        // Sequential use only: move the handle out so a later sequential Stop
        // observes non-joinable and returns. Concurrent callers must not rely
        // on both waiting for join.
        joining = std::move(m_Thread);
    }
    if (joining.joinable()) {
        // An in-flight parse is not interrupted: join waits for it to finish
        // and discard its result before pager Shutdown.
        joining.join();
    }
    std::unique_ptr<RawRegionPacket> ready;
    std::unique_ptr<RawRegionPacket> retire;
    {
        std::unique_lock<std::mutex> lock(m_Mutex);
        ready = std::move(m_Ready);
        retire = std::move(m_Retire);
        m_Queued.reset();
        m_InflightId = 0;
    }
    ready.reset();
    retire.reset();
    m_Cv.notify_all();
}

void RegionWorker::ThreadMain() {
    std::unique_lock<std::mutex> lock(m_Mutex, std::defer_lock);
    try {
        lock.lock();
        for (;;) {
        m_Cv.wait(lock, [this] {
            return m_StopRequested || m_Retire ||
                (m_Ready && (m_LatestCancelled || m_Ready->Request.RequestId != m_LatestId)) ||
                (m_Queued.has_value() && m_InflightId == 0);
        });
        if (m_StopRequested) {
            std::unique_ptr<RawRegionPacket> ready = std::move(m_Ready);
            std::unique_ptr<RawRegionPacket> retire = std::move(m_Retire);
            m_Queued.reset();
            lock.unlock();
            ready.reset();
            retire.reset();
            lock.lock();
            lock.unlock();
            m_Cv.notify_all();
            return;
        }
        if (m_Retire) {
            std::unique_ptr<RawRegionPacket> doomed = std::move(m_Retire);
            lock.unlock();
            doomed.reset();
            lock.lock();
            lock.unlock();
            m_Cv.notify_all();
            lock.lock();
            continue;
        }
        if (m_Ready && (m_LatestCancelled || m_Ready->Request.RequestId != m_LatestId)) {
            std::unique_ptr<RawRegionPacket> doomed = std::move(m_Ready);
            lock.unlock();
            doomed.reset();
            lock.lock();
            lock.unlock();
            m_Cv.notify_all();
            lock.lock();
            continue;
        }
        if (m_Queued.has_value() && m_InflightId == 0) {
            if (m_LatestCancelled) {
                m_Queued.reset();
                lock.unlock();
                m_Cv.notify_all();
                lock.lock();
                continue;
            }
            RegionRequest request = *m_Queued;
            m_Queued.reset();
            if (request.RequestId != m_LatestId) {
                lock.unlock();
                m_Cv.notify_all();
                lock.lock();
                continue;
            }
            m_InflightId = request.RequestId;
            // No per-parse std::function copy: a copy/allocation failure must
            // not escape the thread. m_Parse is immutable after construction,
            // so a const reference stays valid across unlock (worker lifetime
            // outlives the joined thread).
            const ParseFn &parse = m_Parse;
            lock.unlock();

            std::unique_ptr<RawRegionPacket> packet = std::make_unique<RawRegionPacket>(request);
            const double startMs = NowMs();
            try {
                parse(*packet);
            } catch (const std::exception &failure) {
                packet->Error = failure.what();
            } catch (...) {
                packet->Error = "unknown region parser exception";
            }
            packet->ParseMs = NowMs() - startMs;

            lock.lock();
            m_InflightId = 0;
            bool stale = m_StopRequested || m_LatestCancelled ||
                (packet->Request.RequestId != m_LatestId);
            if (!stale && m_Ready) {
                // Bounded one-slot ready: a ready packet should not already
                // exist for the latest ID. Discard the newcomer rather than
                // growing a queue.
                stale = true;
            }
            if (stale) {
                lock.unlock();
                packet.reset();
                lock.lock();
                lock.unlock();
                m_Cv.notify_all();
                lock.lock();
                continue;
            }
            m_Ready = std::move(packet);
            lock.unlock();
            m_Cv.notify_all();
            lock.lock();
            continue;
        }
        }
    } catch (...) {
        // Unrecoverable thread failure (make_unique, Error-string growth,
        // clock, wait): never escape and terminate. The unique_lock may or
        // may not own the mutex here; never double-lock.
        if (!lock.owns_lock()) {
            lock.lock();
        }
        m_StopRequested = true;
        m_InflightId = 0;
        m_Queued.reset();
        std::unique_ptr<RawRegionPacket> ready = std::move(m_Ready);
        std::unique_ptr<RawRegionPacket> retire = std::move(m_Retire);
        lock.unlock();
        ready.reset();
        retire.reset();
        m_Cv.notify_all();
        return;
    }
}
