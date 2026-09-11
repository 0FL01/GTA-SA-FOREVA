// region_worker unit: deterministic sole-parser checks with CV barriers.
// No game data, no Godot/GL, no new framework: fake ParseFn providers only.
// Every barrier uses wait_for with a bounded timeout; no sleep ordering.
// Prints region-worker-ok on full success.

#include "../native/sa_region_worker.h"

#include <chrono>
#include <cmath>
#include <condition_variable>
#include <cstdio>
#include <future>
#include <limits>
#include <mutex>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

namespace {

constexpr std::chrono::seconds kTimeout{5};

struct Gate {
    std::mutex mutex;
    std::condition_variable cv;
    bool entered = false;
    bool release = false;
};

struct ParseLog {
    std::mutex mutex;
    std::vector<uint64_t> ids;
    std::thread::id firstTid;
    bool haveTid = false;
    bool multiTid = false;
    std::thread::id mainTid;

    void Record(uint64_t id) {
        std::lock_guard<std::mutex> lock(mutex);
        ids.push_back(id);
        const std::thread::id self = std::this_thread::get_id();
        if (!haveTid) {
            firstTid = self;
            haveTid = true;
        } else if (firstTid != self) {
            multiTid = true;
        }
    }

    bool Saw(uint64_t id) {
        std::lock_guard<std::mutex> lock(mutex);
        for (uint64_t seen : ids) {
            if (seen == id) {
                return true;
            }
        }
        return false;
    }
};

RegionRequest MakeRequest(float x, float y, float z, uint64_t id, uint64_t epoch) {
    RegionRequest request{};
    request.X = x;
    request.Y = y;
    request.Z = z;
    request.RequestId = id;
    request.SessionEpoch = epoch;
    return request;
}

bool WaitGateEntered(const std::shared_ptr<Gate> &gate) {
    std::unique_lock<std::mutex> lock(gate->mutex);
    return gate->cv.wait_for(lock, kTimeout, [&] { return gate->entered; });
}

void ReleaseGate(const std::shared_ptr<Gate> &gate) {
    {
        std::unique_lock<std::mutex> lock(gate->mutex);
        gate->release = true;
    }
    gate->cv.notify_all();
}

bool TestSupersede(std::thread::id mainTid) {
    auto gate = std::make_shared<Gate>();
    auto log = std::make_shared<ParseLog>();
    log->mainTid = mainTid;
    ParseFn parse = [gate, log](RawRegionPacket &packet) {
        const uint64_t id = packet.Request.RequestId;
        log->Record(id);
        if (id == 1) {
            std::unique_lock<std::mutex> lock(gate->mutex);
            gate->entered = true;
            lock.unlock();
            gate->cv.notify_all();
            lock.lock();
            gate->cv.wait(lock, [&] { return gate->release; });
            packet.Frame.instances = 1;
            packet.Counters = {1, 0, 1, 1};
            return;
        }
        packet.Frame.instances = static_cast<int>(id);
        packet.Counters = {static_cast<int>(id), 0, 1, 1};
    };
    std::string error;
    auto worker = RegionWorker::Create(parse, 101, error);
    if (!worker) {
        std::printf("supersede: create failed: %s\n", error.c_str());
        return false;
    }
    bool ok = true;
    const auto fail = [&](const char *message) {
        std::printf("supersede: %s\n", message);
        ok = false;
    };
    if (!worker->Submit(MakeRequest(1.0f, 2.0f, 3.0f, 1, 101))) {
        fail("submit1 rejected");
    }
    if (!WaitGateEntered(gate)) {
        fail("parser never entered req1");
    }
    {
        std::lock_guard<std::mutex> lock(log->mutex);
        if (!log->haveTid) {
            fail("no parse record for req1");
        } else if (log->firstTid == mainTid) {
            fail("parser ran on main thread");
        }
    }
    if (!worker->Submit(MakeRequest(4.0f, 5.0f, 6.0f, 2, 101))) {
        fail("submit2 rejected");
    }
    if (!worker->Submit(MakeRequest(7.0f, 8.0f, 9.0f, 3, 101))) {
        fail("submit3 rejected");
    }
    {
        std::unique_ptr<RawRegionPacket> tmp;
        if (worker->TryPoll(1, tmp) != RegionWait::Superseded) {
            fail("req1 not superseded (poll)");
        }
        if (tmp) {
            fail("superseded req1 returned a packet");
        }
        if (worker->TryPoll(2, tmp) != RegionWait::Superseded) {
            fail("req2 not superseded (poll)");
        }
        if (tmp) {
            fail("superseded req2 returned a packet");
        }
        if (worker->TryPoll(3, tmp) != RegionWait::Pending) {
            fail("req3 not pending (poll)");
        }
        if (tmp) {
            fail("pending req3 returned a packet");
        }
        if (worker->Wait(1, tmp) != RegionWait::Superseded) {
            fail("req1 not superseded (wait)");
        }
        if (worker->Wait(2, tmp) != RegionWait::Superseded) {
            fail("req2 not superseded (wait)");
        }
    }
    ReleaseGate(gate);
    {
        std::unique_ptr<RawRegionPacket> out;
        if (worker->Wait(3, out) != RegionWait::Ready) {
            fail("req3 not ready");
        } else if (!out) {
            fail("req3 ready without packet");
        } else {
            if (out->Request.RequestId != 3) {
                fail("req3 packet id mismatch");
            }
            if (!out->Error.empty()) {
                fail("req3 unexpected error");
            }
            worker->Retire(std::move(out));
        }
        if (log->Saw(2)) {
            fail("req2 was parsed (must be skipped)");
        }
        if (!log->Saw(1)) {
            fail("req1 never parsed");
        }
        if (!log->Saw(3)) {
            fail("req3 never parsed");
        }
        {
            std::lock_guard<std::mutex> lock(log->mutex);
            if (log->multiTid) {
                fail("multiple parser threads");
            }
            if (log->haveTid && log->firstTid == mainTid) {
                fail("parser thread is main thread");
            }
        }
        std::unique_ptr<RawRegionPacket> tmp;
        if (worker->TryPoll(3, tmp) != RegionWait::Stopped) {
            fail("consumed req3 not stopped (poll)");
        }
        if (worker->Wait(3, tmp) != RegionWait::Stopped) {
            fail("consumed req3 not stopped (wait)");
        }
        if (tmp) {
            fail("consumed req3 returned a packet");
        }
    }
    worker->Stop();
    worker->Stop();
    return ok;
}

bool TestCancelDuringParseAndStop(std::thread::id mainTid) {
    (void)mainTid;
    auto gate = std::make_shared<Gate>();
    auto log = std::make_shared<ParseLog>();
    ParseFn parse = [gate, log](RawRegionPacket &packet) {
        log->Record(packet.Request.RequestId);
        std::unique_lock<std::mutex> lock(gate->mutex);
        gate->entered = true;
        lock.unlock();
        gate->cv.notify_all();
        lock.lock();
        gate->cv.wait(lock, [&] { return gate->release; });
        packet.Frame.instances = 1;
    };
    std::string error;
    auto worker = RegionWorker::Create(parse, 102, error);
    if (!worker) {
        std::printf("cancel-stop: create failed: %s\n", error.c_str());
        return false;
    }
    bool ok = true;
    const auto fail = [&](const char *message) {
        std::printf("cancel-stop: %s\n", message);
        ok = false;
    };
    if (!worker->Submit(MakeRequest(10.0f, 20.0f, 30.0f, 1, 102))) {
        fail("submit1 rejected");
    }
    if (!WaitGateEntered(gate)) {
        fail("parser never entered req1");
        ReleaseGate(gate);
        worker->Stop();
        return false;
    }
    if (!worker->Cancel(1)) {
        fail("cancel during parse rejected");
    }
    if (worker->Cancel(1)) {
        fail("second cancel accepted (must be one-shot)");
    }
    {
        std::unique_ptr<RawRegionPacket> tmp;
        if (worker->Wait(1, tmp) != RegionWait::Cancelled) {
            fail("cancelled req1 did not report Cancelled before stop");
        }
        if (tmp) {
            fail("cancelled req1 returned a packet before stop");
        }
    }
    auto stopFuture = std::async(std::launch::async, [&] { worker->Stop(); });
    bool gateReleased = false;
    const auto releaseOnce = [&] {
        if (!gateReleased) {
            ReleaseGate(gate);
            gateReleased = true;
        }
    };
    // Bounded observable barrier (no scheduling assumption): Stop visibility
    // is TryPoll turning Stopped. Poll with yield until Stopped or deadline.
    {
        const auto deadline = std::chrono::steady_clock::now() + kTimeout;
        bool observedStopped = false;
        while (std::chrono::steady_clock::now() < deadline) {
            std::unique_ptr<RawRegionPacket> probe;
            if (worker->TryPoll(1, probe) == RegionWait::Stopped) {
                observedStopped = true;
                break;
            }
            std::this_thread::yield();
        }
        if (!observedStopped) {
            fail("never observed Stopped after Stop requested");
            releaseOnce();
            stopFuture.wait_for(kTimeout);
            worker->Stop();
            return false;
        }
    }
    // Flag observed while the parser is still blocked: join must still be
    // pending (no force kill). Immediate check, no sleep ordering.
    if (stopFuture.wait_for(std::chrono::milliseconds(0)) != std::future_status::timeout) {
        fail("Stop returned before parser release (must join, no force kill)");
    }
    {
        // While Stop is blocked in join, waiters already observe Stopped.
        std::unique_ptr<RawRegionPacket> tmp;
        if (worker->Wait(1, tmp) != RegionWait::Stopped) {
            fail("req1 not stopped after Stop requested (wait)");
        }
        if (tmp) {
            fail("stopped req1 returned a packet");
        }
    }
    releaseOnce();
    if (stopFuture.wait_for(kTimeout) != std::future_status::ready) {
        fail("Stop never joined after release");
        worker->Stop();
        return false;
    }
    {
        std::unique_ptr<RawRegionPacket> tmp;
        if (worker->Wait(1, tmp) != RegionWait::Stopped) {
            fail("req1 not stopped after join (wait)");
        }
        if (tmp) {
            fail("stopped req1 returned a packet after join");
        }
        if (!log->Saw(1)) {
            fail("in-flight parse never ran (Stop must not kill file IO)");
        }
    }
    worker->Stop();
    return ok;
}

bool TestThrow(std::thread::id mainTid) {
    auto log = std::make_shared<ParseLog>();
    log->mainTid = mainTid;
    ParseFn parse = [log](RawRegionPacket &packet) {
        log->Record(packet.Request.RequestId);
        if (packet.Request.RequestId == 1) {
            throw std::runtime_error("boom-provider");
        }
        packet.Frame.instances = 2;
    };
    std::string error;
    auto worker = RegionWorker::Create(parse, 103, error);
    if (!worker) {
        std::printf("throw: create failed: %s\n", error.c_str());
        return false;
    }
    bool ok = true;
    const auto fail = [&](const char *message) {
        std::printf("throw: %s\n", message);
        ok = false;
    };
    if (!worker->Submit(MakeRequest(1.0f, 1.0f, 1.0f, 1, 103))) {
        fail("submit1 rejected");
    }
    {
        std::unique_ptr<RawRegionPacket> out;
        if (worker->Wait(1, out) != RegionWait::Ready) {
            fail("throwing req1 not ready");
        } else if (!out) {
            fail("throwing req1 ready without packet");
        } else {
            if (out->Error.find("boom-provider") == std::string::npos) {
                fail("throwing req1 error text missing");
            }
            if (out->Request.RequestId != 1) {
                fail("throwing req1 packet id mismatch");
            }
            worker->Retire(std::move(out));
        }
    }
    if (!worker->Submit(MakeRequest(2.0f, 2.0f, 2.0f, 2, 103))) {
        fail("submit2 rejected after throw");
    }
    {
        std::unique_ptr<RawRegionPacket> out;
        if (worker->Wait(2, out) != RegionWait::Ready) {
            fail("req2 not ready after throw");
        } else if (!out) {
            fail("req2 ready without packet");
        } else {
            if (!out->Error.empty()) {
                fail("req2 unexpected error after throw");
            }
            worker->Retire(std::move(out));
        }
    }
    {
        std::lock_guard<std::mutex> lock(log->mutex);
        if (log->multiTid) {
            fail("multiple parser threads across throw");
        }
        if (log->haveTid && log->firstTid == mainTid) {
            fail("parser ran on main thread");
        }
    }
    worker->Stop();
    return ok;
}

bool TestQueuedCancelAndValidation(std::thread::id mainTid) {
    (void)mainTid;
    auto gate = std::make_shared<Gate>();
    auto log = std::make_shared<ParseLog>();
    ParseFn parse = [gate, log](RawRegionPacket &packet) {
        const uint64_t id = packet.Request.RequestId;
        log->Record(id);
        if (id == 1) {
            std::unique_lock<std::mutex> lock(gate->mutex);
            gate->entered = true;
            lock.unlock();
            gate->cv.notify_all();
            lock.lock();
            gate->cv.wait(lock, [&] { return gate->release; });
        }
        packet.Frame.instances = static_cast<int>(id);
    };
    std::string error;
    auto worker = RegionWorker::Create(parse, 104, error);
    if (!worker) {
        std::printf("queued: create failed: %s\n", error.c_str());
        return false;
    }
    bool ok = true;
    const auto fail = [&](const char *message) {
        std::printf("queued: %s\n", message);
        ok = false;
    };
    if (!worker->Submit(MakeRequest(0.0f, 0.0f, 0.0f, 1, 104))) {
        fail("submit1 rejected");
    }
    if (!WaitGateEntered(gate)) {
        fail("parser never entered req1");
        ReleaseGate(gate);
        worker->Stop();
        return false;
    }
    if (!worker->Submit(MakeRequest(1.0f, 1.0f, 1.0f, 2, 104))) {
        fail("submit2 (queued) rejected");
    }
    if (!worker->Cancel(2)) {
        fail("queued cancel rejected");
    }
    if (worker->Cancel(2)) {
        fail("second queued cancel accepted (must be one-shot)");
    }
    {
        std::unique_ptr<RawRegionPacket> tmp;
        if (worker->TryPoll(2, tmp) != RegionWait::Cancelled) {
            fail("queued req2 not cancelled (poll)");
        }
        if (worker->Wait(2, tmp) != RegionWait::Cancelled) {
            fail("queued req2 not cancelled (wait)");
        }
        if (tmp) {
            fail("cancelled queued req2 returned a packet");
        }
    }
    ReleaseGate(gate);
    {
        std::unique_ptr<RawRegionPacket> tmp;
        if (worker->Wait(1, tmp) != RegionWait::Superseded) {
            fail("stale req1 not superseded after queued cancel");
        }
        if (tmp) {
            fail("superseded req1 returned a packet");
        }
        if (worker->Wait(2, tmp) != RegionWait::Cancelled) {
            fail("queued req2 not cancelled after release");
        }
    }
    if (log->Saw(2)) {
        fail("queued req2 was parsed (must be skipped)");
    }
    // Validation negatives: zero, wrong epoch, nonincreasing, nonfinite.
    {
        if (worker->Submit(MakeRequest(0.0f, 0.0f, 0.0f, 0, 104))) {
            fail("zero id accepted");
        }
        if (worker->Submit(MakeRequest(0.0f, 0.0f, 0.0f, 3, 999))) {
            fail("wrong epoch accepted");
        }
        if (worker->Submit(MakeRequest(0.0f, 0.0f, 0.0f, 2, 104))) {
            fail("nonincreasing id accepted");
        }
        if (worker->Submit(MakeRequest(0.0f, 0.0f, 0.0f, 1, 104))) {
            fail("older id accepted");
        }
        const float nan = std::numeric_limits<float>::quiet_NaN();
        const float inf = std::numeric_limits<float>::infinity();
        if (worker->Submit(MakeRequest(nan, 0.0f, 0.0f, 3, 104))) {
            fail("nan x accepted");
        }
        if (worker->Submit(MakeRequest(0.0f, inf, 0.0f, 3, 104))) {
            fail("inf y accepted");
        }
        if (worker->Submit(MakeRequest(0.0f, 0.0f, nan, 3, 104))) {
            fail("nan z accepted");
        }
        std::unique_ptr<RawRegionPacket> tmp;
        if (worker->Cancel(999)) {
            fail("future cancel accepted");
        }
        if (worker->Cancel(1)) {
            fail("older cancel accepted");
        }
        if (worker->Wait(999, tmp) != RegionWait::Stopped) {
            fail("future wait not stopped");
        }
        if (worker->Wait(0, tmp) != RegionWait::Stopped) {
            fail("zero wait not stopped");
        }
        if (tmp) {
            fail("unknown wait returned a packet");
        }
    }
    // One-shot take: submit fresh latest, take once, second observes Stopped.
    if (!worker->Submit(MakeRequest(5.0f, 5.0f, 5.0f, 3, 104))) {
        fail("submit3 rejected");
    }
    {
        std::unique_ptr<RawRegionPacket> out;
        if (worker->Wait(3, out) != RegionWait::Ready) {
            fail("req3 not ready");
        } else if (!out) {
            fail("req3 ready without packet");
        } else {
            worker->Retire(std::move(out));
        }
        std::unique_ptr<RawRegionPacket> tmp;
        if (worker->TryPoll(3, tmp) != RegionWait::Stopped) {
            fail("consumed req3 not stopped (poll)");
        }
        if (worker->Wait(3, tmp) != RegionWait::Stopped) {
            fail("consumed req3 not stopped (wait)");
        }
        if (worker->Cancel(3)) {
            fail("cancel after take accepted (must be one-shot)");
        }
        worker->Retire(std::move(tmp));
    }
    worker->Stop();
    {
        if (worker->Submit(MakeRequest(0.0f, 0.0f, 0.0f, 4, 104))) {
            fail("submit after stop accepted");
        }
        if (worker->Cancel(3)) {
            fail("cancel after stop accepted");
        }
        std::unique_ptr<RawRegionPacket> tmp;
        if (worker->Wait(3, tmp) != RegionWait::Stopped) {
            fail("wait after stop not stopped");
        }
    }
    worker->Stop();
    return ok;
}

bool TestSingleThread(std::thread::id mainTid) {
    auto log = std::make_shared<ParseLog>();
    log->mainTid = mainTid;
    ParseFn parse = [log](RawRegionPacket &packet) {
        log->Record(packet.Request.RequestId);
        packet.Frame.instances = static_cast<int>(packet.Request.RequestId);
    };
    std::string error;
    auto worker = RegionWorker::Create(parse, 105, error);
    if (!worker) {
        std::printf("thread: create failed: %s\n", error.c_str());
        return false;
    }
    bool ok = true;
    const auto fail = [&](const char *message) {
        std::printf("thread: %s\n", message);
        ok = false;
    };
    for (uint64_t id = 1; id <= 3; ++id) {
        if (!worker->Submit(MakeRequest(static_cast<float>(id), 0.0f, 0.0f, id, 105))) {
            fail("sequential submit rejected");
            break;
        }
        std::unique_ptr<RawRegionPacket> out;
        if (worker->Wait(id, out) != RegionWait::Ready) {
            fail("sequential wait not ready");
            break;
        }
        if (!out || out->Request.RequestId != id) {
            fail("sequential packet id mismatch");
        }
        worker->Retire(std::move(out));
    }
    {
        std::lock_guard<std::mutex> lock(log->mutex);
        if (!log->haveTid) {
            fail("no parser thread observed");
        } else {
            if (log->firstTid == mainTid) {
                fail("parser ran on main thread");
            }
            if (log->multiTid) {
                fail("more than one parser thread observed");
            }
            if (log->ids.size() != 3) {
                fail("expected exactly three sequential parses");
            }
        }
    }
    worker->Stop();
    return ok;
}

} // namespace

int main() {
    const std::thread::id mainTid = std::this_thread::get_id();
    bool ok = true;
    if (!TestSupersede(mainTid)) {
        ok = false;
    }
    if (!TestCancelDuringParseAndStop(mainTid)) {
        ok = false;
    }
    if (!TestThrow(mainTid)) {
        ok = false;
    }
    if (!TestQueuedCancelAndValidation(mainTid)) {
        ok = false;
    }
    if (!TestSingleThread(mainTid)) {
        ok = false;
    }
    if (ok) {
        std::printf("region-worker-ok\n");
        return 0;
    }
    std::printf("region-worker-fail\n");
    return 1;
}
