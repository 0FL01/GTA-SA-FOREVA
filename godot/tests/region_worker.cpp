// region_worker unit: deterministic sole-parser checks with CV barriers.
// No game data, no Godot/GL, no new framework: fake ParseFn providers only.
// Every barrier uses wait_for with a bounded timeout; no sleep ordering.
// Plus small synthetic RegionPlan fixtures (exact prepack/basis/day-night/
// material alpha/order, invalid finite/index/provenance). Existing barrier
// semantics unchanged. Prints region-worker-ok on full success.

#include "../native/sa_region_plan.h"
#include "../native/sa_region_worker.h"

#include <chrono>
#include <cmath>
#include <condition_variable>
#include <cstdio>
#include <cstring>
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

// --- P1-A06 synthetic RegionPlan fixtures (pure, no game data/Godot/GL). ---

namespace plan_fixture {

WorldShotImage MakeImage(int w, int h, uint8_t alpha, uint32_t filter) {
    WorldShotImage image{};
    std::snprintf(image.name, sizeof(image.name), "testtex");
    image.w = w;
    image.h = h;
    image.filter = filter;
    image.rgba.assign(static_cast<size_t>(w) * static_cast<size_t>(h) * 4, 200);
    for (size_t i = 3; i < image.rgba.size(); i += 4) {
        image.rgba[i] = alpha;
    }
    NativeAssetIdentity::ArchiveMember member{"models.img", "test.txd"};
    image.sourceIdentity.lineage = {member};
    image.sourceIdentity.owner = member;
    image.sourceIdentity.name = "testtex";
    image.sourceIdentity.filter = filter;
    image.hasSourceIdentity = true;
    return image;
}

WorldShotMesh MakeMesh(int tris, int imageIndex) {
    WorldShotMesh mesh{};
    mesh.tris = tris;
    const size_t t = static_cast<size_t>(tris);
    mesh.pos.assign(t * 9, 10.0f);
    mesh.nrm.assign(t * 9, 0.0f);
    for (size_t i = 2; i < mesh.nrm.size(); i += 3) {
        mesh.nrm[i] = 1.0f;
    }
    mesh.uv.assign(t * 6, 0.5f);
    mesh.triImg.assign(t, imageIndex);
    mesh.triCol.assign(t * 3, 0.5f);
    mesh.color[0] = mesh.color[1] = mesh.color[2] = 0.5f;
    mesh.dayColors.assign(t * 12, 255);
    mesh.nightColors.assign(t * 12, 255);
    mesh.surfaces.resize(t);
    for (size_t i = 0; i < t; ++i) {
        mesh.surfaces[i].color = {1.0f, 1.0f, 1.0f, 1.0f};
        mesh.surfaces[i].ambient = 1.0f;
        mesh.surfaces[i].diffuse = 1.0f;
        mesh.surfaces[i].vehicleAlpha = false;
        mesh.surfaces[i].sourceMaterial = 0;
        mesh.surfaces[i].sourceGeometry = 0;
        mesh.surfaces[i].sourceTriangle = static_cast<int>(i);
    }
    mesh.sourceModelId = 1;
    mesh.sourceModelName = "testmodel";
    mesh.sourceTxdName = "testtxd";
    mesh.sourceArchiveName = "testarchive";
    mesh.sourcePlacementId = 7;
    return mesh;
}

bool FloatNear(float a, float b) {
    return std::fabs(a - b) < 1e-6f;
}

} // namespace plan_fixture

bool TestPlanPrepackBasisDayNight() {
    bool ok = true;
    const auto fail = [&](const char* message) {
        std::printf("plan-prepack: %s\n", message);
        ok = false;
    };
    WorldShotScene scene;
    scene.images.push_back(plan_fixture::MakeImage(1, 1, 255, 0x1102));
    WorldShotMesh mesh = plan_fixture::MakeMesh(1, 0);
    mesh.pos = {1, 2, 3, 4, 5, 6, 7, 8, 9};
    mesh.nrm = {0, 1, 0, 0, 0, 1, 1, 0, 0};
    mesh.uv = {0.1f, 0.2f, 0.3f, 0.4f, 0.5f, 0.6f};
    mesh.dayColors = {255, 0, 0, 255, 0, 255, 0, 128, 0, 0, 255, 0};
    mesh.nightColors = mesh.dayColors;
    scene.meshes.push_back(mesh);
    RegionPlan plan;
    RegionPlanFailure failure;
    if (!BuildRegionPlan(scene, plan, failure)) {
        fail("valid prepack scene rejected");
        return false;
    }
    if (plan.imageModes.size() != 1 || plan.imageModes[0] != RegionPlanAlpha::Opaque) {
        fail("image mode not opaque");
    }
    if (plan.meshes.size() != 1 || plan.meshes[0].surfaces.size() != 1) {
        fail("expected one mesh with one surface");
        return ok;
    }
    const auto& surf = plan.meshes[0].surfaces[0];
    const float exPos[9] = {1, 3, -2, 4, 6, -5, 7, 9, -8};
    const float exNrm[9] = {0, 0, -1, 0, 1, 0, 1, 0, 0};
    const float exUv[6] = {0.1f, 0.2f, 0.3f, 0.4f, 0.5f, 0.6f};
    for (int i = 0; i < 9; ++i) {
        if (!plan_fixture::FloatNear(surf.positions[static_cast<size_t>(i)], exPos[i])) {
            fail("basis position mismatch");
            break;
        }
        if (!plan_fixture::FloatNear(surf.normals[static_cast<size_t>(i)], exNrm[i])) {
            fail("basis normal mismatch");
            break;
        }
    }
    for (int i = 0; i < 6; ++i) {
        if (!plan_fixture::FloatNear(surf.uvs[static_cast<size_t>(i)], exUv[i])) {
            fail("uv mismatch");
            break;
        }
    }
    const float exDay[12] = {1, 0, 0, 1, 0, 1, 0, 128.0f / 255.0f, 0, 0, 1, 0};
    for (int i = 0; i < 12; ++i) {
        if (!plan_fixture::FloatNear(surf.day[static_cast<size_t>(i)], exDay[i])) {
            fail("day rgba mismatch");
            break;
        }
        if (!plan_fixture::FloatNear(surf.night[static_cast<size_t>(i)], exDay[i])) {
            fail("night rgba mismatch");
            break;
        }
    }
    if (surf.imageIndex != 0) {
        fail("surface image index mismatch");
    }
    // The prepack fixture deliberately includes vertex alpha 128: source
    // classification is blended even though its texture is opaque.
    if (std::strcmp(RegionPlanAlphaName(surf.alpha), "blend") != 0) {
        fail("surface alpha name not blend");
    }
    if (RegionPlanTotalSurfaces(plan) != 1 || RegionPlanTotalUnits(plan) != 1 + 1 + 1 + 1) {
        fail("total units mismatch (images+surfaces+meshes+paired)");
    }
    return ok;
}

bool TestPlanMaterialAlphaOrder() {
    bool ok = true;
    const auto fail = [&](const char* message) {
        std::printf("plan-alpha: %s\n", message);
        ok = false;
    };
    WorldShotScene scene;
    scene.images.push_back(plan_fixture::MakeImage(1, 1, 255, 0x1102));
    WorldShotImage cutout = plan_fixture::MakeImage(2, 1, 255, 0x1102);
    cutout.rgba[3] = 255;
    cutout.rgba[7] = 0;
    scene.images.push_back(cutout);
    scene.images.push_back(plan_fixture::MakeImage(1, 1, 128, 0x1102));
    WorldShotMesh mesh = plan_fixture::MakeMesh(4, 0);
    mesh.triImg = {0, 2, 0, 0};
    mesh.surfaces[3].vehicleAlpha = true;
    scene.meshes.push_back(mesh);
    RegionPlan plan;
    RegionPlanFailure failure;
    if (!BuildRegionPlan(scene, plan, failure)) {
        fail("valid alpha scene rejected");
        return false;
    }
    if (plan.imageModes.size() != 3 || plan.imageModes[0] != RegionPlanAlpha::Opaque ||
        plan.imageModes[1] != RegionPlanAlpha::Cutout ||
        plan.imageModes[2] != RegionPlanAlpha::Blend) {
        fail("image modes opaque/cutout/blend mismatch");
    }
    if (plan.meshes.size() != 1 || plan.meshes[0].surfaces.size() != 3) {
        fail("expected three material groups (opaque pair + blend + vehicle)");
        return ok;
    }
    const auto& g0 = plan.meshes[0].surfaces[0];
    const auto& g1 = plan.meshes[0].surfaces[1];
    const auto& g2 = plan.meshes[0].surfaces[2];
    if (g0.representativeTriangle != 0 || g0.alpha != RegionPlanAlpha::Opaque) {
        fail("group0 must be opaque representative 0 (first-encounter order)");
    }
    if (g0.positions.size() != 2 * 3 * 3) {
        fail("group0 must prepack two triangles (0,2)");
    }
    if (g1.representativeTriangle != 1 || g1.alpha != RegionPlanAlpha::Blend) {
        fail("group1 must be blend representative 1");
    }
    if (g2.representativeTriangle != 3 || g2.alpha != RegionPlanAlpha::Blend) {
        fail("group2 must be vehicle-blend representative 3");
    }
    {
        WorldShotScene nightScene;
        nightScene.images.push_back(plan_fixture::MakeImage(1, 1, 255, 0x1102));
        WorldShotMesh nightMesh = plan_fixture::MakeMesh(1, 0);
        nightMesh.nightColors[3] = 0;
        nightScene.meshes.push_back(nightMesh);
        RegionPlan nightPlan;
        RegionPlanFailure nightFailure;
        if (!BuildRegionPlan(nightScene, nightPlan, nightFailure)) {
            fail("night-mismatch scene rejected");
        } else if (nightPlan.meshes.empty() || nightPlan.meshes[0].surfaces.empty() ||
                   nightPlan.meshes[0].surfaces[0].alpha != RegionPlanAlpha::Blend) {
            fail("day/night alpha mismatch must force blend");
        }
    }
    return ok;
}

bool TestPlanInvalidFiniteIndexProvenance() {
    bool ok = true;
    const auto fail = [&](const char* message) {
        std::printf("plan-invalid: %s\n", message);
        ok = false;
    };
    const float nan = std::numeric_limits<float>::quiet_NaN();
    const float inf = std::numeric_limits<float>::infinity();
    {
        WorldShotScene scene;
        scene.images.push_back(plan_fixture::MakeImage(1, 1, 255, 0x1102));
        WorldShotMesh mesh = plan_fixture::MakeMesh(1, 0);
        mesh.uv[2] = nan;
        scene.meshes.push_back(mesh);
        RegionPlan plan;
        RegionPlanFailure failure;
        if (BuildRegionPlan(scene, plan, failure)) {
            fail("nan uv accepted");
        } else if (failure.kind != RegionPlanFailure::Kind::NonfiniteUv ||
                   failure.meshIndex != 0 || failure.triangle != 0 || failure.uvIndex != 2) {
            fail("nan uv failure indices mismatch");
        }
    }
    {
        WorldShotScene scene;
        scene.images.push_back(plan_fixture::MakeImage(1, 1, 255, 0x1102));
        WorldShotMesh mesh = plan_fixture::MakeMesh(1, 0);
        mesh.pos[0] = inf;
        scene.meshes.push_back(mesh);
        RegionPlan plan;
        RegionPlanFailure failure;
        if (BuildRegionPlan(scene, plan, failure) ||
            failure.kind != RegionPlanFailure::Kind::BadPosition) {
            fail("inf position not rejected as BadPosition");
        }
    }
    {
        WorldShotScene scene;
        scene.images.push_back(plan_fixture::MakeImage(1, 1, 255, 0x1102));
        WorldShotMesh mesh = plan_fixture::MakeMesh(1, 0);
        mesh.triCol[0] = 2.0f;
        scene.meshes.push_back(mesh);
        RegionPlan plan;
        RegionPlanFailure failure;
        if (BuildRegionPlan(scene, plan, failure) ||
            failure.kind != RegionPlanFailure::Kind::BadMaterialColor) {
            fail("triCol outside [0,1] not rejected");
        }
    }
    {
        WorldShotScene scene;
        scene.images.push_back(plan_fixture::MakeImage(1, 1, 255, 0x1102));
        WorldShotMesh mesh = plan_fixture::MakeMesh(1, -2);
        scene.meshes.push_back(mesh);
        RegionPlan plan;
        RegionPlanFailure failure;
        if (BuildRegionPlan(scene, plan, failure) ||
            failure.kind != RegionPlanFailure::Kind::BadImageIndex || !failure.missingTexture ||
            failure.imageIndex != -2) {
            fail("-2 must report missing_texture with index");
        }
    }
    {
        WorldShotScene scene;
        scene.images.push_back(plan_fixture::MakeImage(1, 1, 255, 0x1102));
        WorldShotMesh mesh = plan_fixture::MakeMesh(1, 99);
        scene.meshes.push_back(mesh);
        RegionPlan plan;
        RegionPlanFailure failure;
        if (BuildRegionPlan(scene, plan, failure) ||
            failure.kind != RegionPlanFailure::Kind::BadImageIndex || failure.missingTexture) {
            fail("out-of-range index must report invalid_image_index");
        }
    }
    {
        WorldShotScene scene;
        WorldShotImage image = plan_fixture::MakeImage(1, 1, 255, 0x1102);
        image.hasSourceIdentity = false;
        scene.images.push_back(image);
        scene.meshes.push_back(plan_fixture::MakeMesh(1, 0));
        RegionPlan plan;
        RegionPlanFailure failure;
        if (BuildRegionPlan(scene, plan, failure) ||
            failure.kind != RegionPlanFailure::Kind::BadTextureIdentity ||
            failure.reason != "missing_source_identity") {
            fail("missing_source_identity reason mismatch");
        }
    }
    {
        WorldShotScene scene;
        WorldShotImage image = plan_fixture::MakeImage(1, 1, 255, 0x1102);
        image.sourceIdentity.owner = {"other.img", "other.txd"};
        scene.images.push_back(image);
        scene.meshes.push_back(plan_fixture::MakeMesh(1, 0));
        RegionPlan plan;
        RegionPlanFailure failure;
        if (BuildRegionPlan(scene, plan, failure) ||
            failure.kind != RegionPlanFailure::Kind::BadTextureIdentity ||
            failure.reason != "owner_not_in_lineage") {
            fail("owner_not_in_lineage reason mismatch");
        }
    }
    {
        WorldShotScene scene;
        WorldShotImage image = plan_fixture::MakeImage(1, 1, 255, 0x1102);
        image.filter = 0x9999;
        scene.images.push_back(image);
        scene.meshes.push_back(plan_fixture::MakeMesh(1, 0));
        RegionPlan plan;
        RegionPlanFailure failure;
        if (BuildRegionPlan(scene, plan, failure) ||
            failure.kind != RegionPlanFailure::Kind::BadTextureIdentity ||
            failure.reason != "filter_mismatch") {
            fail("filter_mismatch reason mismatch");
        }
    }
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
    if (!TestPlanPrepackBasisDayNight()) {
        ok = false;
    }
    if (!TestPlanMaterialAlphaOrder()) {
        ok = false;
    }
    if (!TestPlanInvalidFiniteIndexProvenance()) {
        ok = false;
    }
    if (ok) {
        std::printf("region-worker-ok\n");
        return 0;
    }
    std::printf("region-worker-fail\n");
    return 1;
}
