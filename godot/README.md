# SA Legacy Look Lab

Asset-free Godot 4.6.1 visual lab for inspecting a bounded Grove Street region from
a legally owned classic PC GTA: San Andreas installation. The game directory is
opened read-only by the GDExtension at runtime; it is never copied into this
project or a package. The original executable and Wine are not runtime inputs.

This is a visual test lab, not a visual-parity result. The adapter and actual
Forward+ rendering run on the build server's software Vulkan/Wayland backend.
Fedora 44 / Mesa / RX 780M and original-reference acceptance remain not-run. See
[`docs/visual_contract.md`](../docs/visual_contract.md) for the evidence rules and
known visual limitations.

### Source startup movies and splash (P7-A10)

```bash
./build/godot-native/sa_movie_runtime_probe /game
./build/mad-sa-linux --smoke-movies --game-dir /game
./build/godot-native/sa_script_texture_probe /game
```

The native reference decodes the owned `Logo.mpg` and `GTAtitles.mpg` MPEG1
video/MP2 audio through dynamically linked system FFmpeg, then the independent
texture path verifies `loadsc0`. Media and codec libraries are not bundled in
the asset-free Godot package. See [`docs/FFMPEG-RUNTIME.md`](../docs/FFMPEG-RUNTIME.md)
for the dependency and LGPL redistribution boundary.

### Target closure runner

The remaining acceptance evidence is target-only:

```bash
./tools/target-closure.sh "/path/to/owned/GTA San Andreas" artifacts/target-closure
```

It fail-closes unless it is running in the Fedora44/Wayland/Radeon780M session,
requires a real non-Dummy Godot audio backend, runs the packaged Forward+ family
and native first-mission routes, and preserves timing/log artifacts. Server
llvmpipe and Dummy audio are not accepted substitutes.

### Complete shipped script ledger and radio state (P7-A07 / P8-A01)

```bash
./build/godot-native/sa_core_radio_runtime_probe
./build/godot-native/sa_core_script_content_probe /game
```

The radio gate owns all12 source station programming queues, interruption/resume and canonical restart state. The corpus gate binds exact `main.scm` and `script.img` identities to416669 classified main/mission/streamed sites (`unknown-reachable=0`, fingerprint `54B67C3B1B6BD9E5`). Its69764 strict sites remain explicitly unsupported; the ledger never converts them to NOPs. P4 also owns mission3 `LD_NONE`/24-sprite residency through the sole parser worker; P7-A06 target audio remains open.

The P4 closure probe `sa_first_mission_save_probe /game PRE POST` performs first-mission skip/fail/cleanup/retry/complete/cleanup and verifies matching progression through two fresh `exec` readers. It complements the normal boot/owner gates; it does not claim every mission or target audiovisual parity.

### Representative story lifecycle matrix (P8-A02)

```bash
./build/godot-native/sa_core_story_lifecycle_probe /game
```

The mission2 fixture composes actual PROLOG1 and mission speech43200 through normal start, skip, failure cleanup, retry, authored cutscene/audio completion and final cleanup. It publishes immutable value state with `presentation-feedback=0`; this is lifecycle ownership, not a claim that every strict script site or final cutscene presentation is complete.

### Activity-family lifecycle matrix (P8-A03)

```bash
./build/godot-native/sa_core_activity_lifecycle_probe /game
```

The gate covers17 discovered service, race, school, minigame and other families with normal start/result/cleanup, exact shipped identities where the activity is streamed, and one failure/retry route. Family scripts/tasks remain gameplay-result authority; the lifecycle owner does not replace their rules.

### Restarted-process progression ownership (P8-A04)

```bash
./build/godot-native/sa_core_progression_runtime_probe
```

The canonical port-native envelope preserves and reapplies purchases, integer/float stats, rewards, unlocks and interiors in a fresh owner. It rejects checksum corruption atomically. Original-PC save block compatibility is a separate P8-A06/A07 milestone.

### Cheats, replay and special-state inventory (P8-A05)

```bash
./build/godot-native/sa_core_special_state_probe
```

The manifest covers all92 source cheats,20 replay packet types and9 script special-state families. Each row has a tested value route or an explicit Pending status; pending rows are not silently treated as implemented behavior.

### Original-PC save block envelope (P8-A06)

```bash
./build/godot-native/sa_core_pc_save_codec_probe
```

The codec preserves all28 ordered `BLOCK` payload families inside the fixed202752-byte PC file, validates the original additive checksum and canonical padding, and repairs explicit int32 references atomically. Payload semantics and full progression import/export remain P8-A07; this structural gate alone is not an original-save compatibility claim.

### Weather region/cloud/water transition ownership (P7-A08)

```bash
./build/godot-native/sa_environment_lifecycle_probe /game
```

The value owner follows the source region rectangles and shipped timecycle rows through a controlled Los Santos→San Fierro→desert route. It retains cloud colours, weather factors, water colour/waviness and source UV-flow state; frustum, cloud/water geometry and presentation feedback remain separate renderer authorities.

### Explicit PC effect families (P7-A09)

```bash
./build/godot-native/sa_effect_families_probe
```

The pointer-free profile isolates the discovered ONE/ONE particle, DEFAULT alpha shadow, MatFX ENVMAP reflection and PC two-pass colour-filter formulas. Direct11 verifies exact pixel and blend/depth transitions; existing clean material/cloud gates provide actual asset-render evidence. Generic FX scheduling, projected/permanent/realtime shadow geometry, water reflection/refraction and PS2-only effects remain explicit differences rather than silent fallback.

### Original-PC representative semantic import/export (P8-A07)

```bash
./build/godot-native/sa_core_pc_save_semantics_probe artifacts/build-runs/p8-a07-pc-semantics.bin
```

The probe writes the full202752-byte/28-block PC envelope, then `exec`s a fresh reader. The reader imports exact `CPathFind` switch records, applies a source path-state change, exports and semantically reimports it. Direct12 and strict ASan/UBSan pass. This proves the representative Paths adapter; other source blocks remain opaque until separately adapted.

### SFX, speech and environmental audio families (P7-A06 target-open)

`SALegacyAudio` exposes copied source payloads for door SFX event80/bank138/sound40, mission speech43200 and rain bank105/sound0. Godot constructs WAV/Ogg streams and starts all three players; Dummy is structural CI only:

```sh
./build/godot-native/sa_core_audio_families_probe /game
./artifacts/godot/package/runtime/godot --headless \
  --path artifacts/godot/package/godot --audio-driver Dummy \
  --script /workspace/godot/tests/audio_families.gd -- --game-dir /game
# Target hardware only; must not use --audio-driver Dummy:
./artifacts/godot/package/runtime/godot --headless \
  --path artifacts/godot/package/godot \
  --script /workspace/godot/tests/audio_families.gd -- \
  --game-dir /path/to/owned/game --require-real-audio
```

Require native `sfx=80/138/40 speech=43200 environment=105/0`; CI reports `structural=1 target=0`. P7-A06 is not verified until the same route reports a non-Dummy driver (`target=1`) on the target audio host. Current extension/package SHA256 is `980cb6a251fd0a7fc3500a9249873088e501fd521a25966f7dddccad3a29bad6`.

### Keyboard, mouse, controller, hotplug and feedback (P7-A05)

`NativeInputLifecycle` owns generation-qualified devices and34 source-default keyboard/mouse/gamepad bindings, then commits complete samples through `NativeSourcePad`. The native Realtime loop forwards SDL key, mouse, wheel, gamepad button/axis and hotplug events. The direct lifecycle and actual SDL3 virtual-rumble gates are:

```sh
./build/godot-native/sa_core_input_lifecycle_probe
SDL_VIDEODRIVER=dummy ./artifacts/graphics/NativePadFeedbackProbe
./artifacts/godot/package/runtime/godot --headless \
  --path artifacts/godot/package/godot --audio-driver Dummy \
  --script /workspace/godot/tests/input_trace.gd -- \
  --reference-trace /workspace/artifacts/build-runs/p7-a05-pad-trace.txt
```

Require `native-input-lifecycle-ok checks=17 ... bindings=34`, feedback `failures=0`, and `input-trace-ok`. Feedback maps source shake100 to both motors25700 for120ms; unsupported/no-device outcomes remain explicit. Extension/package remains byte-identical SHA256 `afe27781b7e8161e0656c05a82581817b6da11d18891917bb503979adb1592da`.

### Multilingual MAIN/mission text and source fonts (P7-A04)

The value-only `NativeTextFamilies` owner validates all127 tables in each shipped GXT language and resolves every keyed TDAT string by source CRC32-uppercase hash. It also applies the source number/string/control-key substitution order without inventing fallback strings. The decisive direct route includes actual font1/font2 TXD atlases and `fonts.dat` metrics:

```sh
./build/godot-native/sa_core_text_families_probe /game
SDL_VIDEODRIVER=dummy ./build/mad-sa-linux --menu-nav down,enter \
  --out artifacts/build-runs/p7-a04-menu-english.tga --lang english --game-dir /game
```

Require `native-text-families-ok checks=83025 ... keys=82997 ... fonts=font1,font2 feedback=0`; repeat MenuNav for french/german/italian/spanish and require the translated Options selection. The extension/package remains byte-identical SHA256 `afe27781b7e8161e0656c05a82581817b6da11d18891917bb503979adb1592da`.

### Frontend, map, HUD and settings lifecycle (P7-A03)

`SALegacyFrontend` is a value-only adapter around source screen IDs, CMenuManager display defaults, map center/zoom and the existing source camera transition owner. The decisive route is frontend → game → map → settings → game; it restores map/camera state while retaining changed HUD/radar/subtitle preferences and never samples Godot node transforms.

```sh
./build/godot-native/sa_core_frontend_probe
./artifacts/godot/package/runtime/godot --headless \
  --path artifacts/godot/package/godot --audio-driver Dummy \
  --script /workspace/godot/tests/frontend_lifecycle.gd
```

Require `native-frontend-lifecycle-ok ... events=13 ... feedback=0` and `frontend-lifecycle-godot-ok`. Camera modes4/18 remain independently pinned by `sa_core_camera_probe`; `RealtimeHudProbe.py` and native `--menu-nav` retain actual radar tiles, source fonts and GXT text. The source eye/collision solver is still explicit `unsupported`, not replaced by a Godot camera. Current extension/package SHA256 is `afe27781b7e8161e0656c05a82581817b6da11d18891917bb503979adb1592da`.

### Source material, MatFX, mip and alpha families (P7-A02)

Native scenes retain complete decoded source mip chains and discovered MatFX environment metadata. Actual Landstal evidence is20 no-effect/97 environment materials,930 env-mapped triangles using `xvehicleenv128`, and authored vehicle alpha. Unsupported MatFX types are rejected rather than hidden behind PBR or a generic fallback.

Direct/source gates:

```sh
bash gta-reversed/source/app/platform/linux/VehicleMaterialProbe.sh /game
./artifacts/godot/package/runtime/godot --headless --path artifacts/godot/package/godot \
  --script res://tests/material_contract.gd
python3 artifacts/build-runs/godot-wayland.py \
  ./artifacts/godot/package/runtime/godot --path artifacts/godot/package/godot \
  --display-driver wayland --audio-driver Dummy --rendering-method forward_plus \
  --script /workspace/godot/tests/material_render.gd -- --game-dir /game
```

The rendered gate isolates the source env formula, authored trilinear lower-mip selection versus point/no-mip level0, and existing opaque/cutout/blend behavior. `material_source.gd` separately checks actual environment and vehicle-alpha families. Current extension/package SHA256 is `a6ddb65bf2b34558f8be5955e0b7b4cb28d50345603be23ae895cd9290ef27c9`.

### Source pose families (P7-A01)

`SALegacyPose` is a standalone, value-only adapter for authoritative CPU pose readers. It captures normal ped DFF/TXD + ped.ifp poses and hi-poly cutscene DFF/TXD + cuts.img ANPK poses, then releases parser-global RW state before publishing copied arrays. It must not be used while `SALegacyBridge` owns an open pager.

Direct gate: `./build/godot-native/sa_pose_families_probe /game` → `native-pose-families-ok checks=12 ... ped=IDLE_stance jump-mapped=26 blend=5 morph=0.937500 cutscene=cssmokevest/csplay bones=61 mapped=56 ... feedback=0`.

Clean packaged rendered gate:

```sh
python3 artifacts/build-runs/godot-wayland.py \
  ./artifacts/godot/package/runtime/godot --path artifacts/godot/package/godot \
  --display-driver wayland --audio-driver Dummy --rendering-method forward_plus \
  --script /workspace/godot/tests/pose_families.gd -- \
  --game-dir /game --screenshot /workspace/artifacts/godot/p7-a01-pose-families.png
```

The view is intentionally unshaded diagnostic presentation; no Skeleton3D, physics or node transform feeds back into source ownership. Material/MatFX/mip/alpha parity belongs to P7-A02.

Preset `4` uses the source `CLOUDY_LA` overcast state. `RAINY_LA` does not exist;
it is not aliased to an invented rainy-LA environment.

## Core and diagnostic hosts

### Generation-qualified world residency (P5-A01)

`sa_world_residency_probe /game` validates the complete64-file source path-area corpus and an actual catalog itinerary from Grove R140 (`321` placements) to interior16 (`36`). `NativeWorldResidency` requires exact ordered render identities and source-COL subsets, publishes immutable generations, retains a stable dynamic reference across the area switch and rejects stale/altered candidates. It deliberately exposes `PathSearchAuthority=false`; route search remains P6-A01.

The clean packaged `region_catalog.gd --catalog-route` gate compares full ordered `IPL/model/record/model-id/binary` placement identity and stable collision/path payloads, not only model sets. Direct19, strict ASan/UBSan, core-world79, native sweep33/0 and Forward+ catalog/chain/async gates pass. Extension/package SHA256: `9891d1b8a422c98b813266b5251fbfcc3e8867c1e039fcb546e0463fc412298c`.

### Source world visibility (P5-A02)

`sa_world_visibility_probe /game` evaluates all326 real roads residents at hour12 and23 from authored area/time metadata, source draw distance, exact loaded model bounds and LOD relations. The route records168 versus173 presented identities while preserving the P5-A01 residency/COL/path set. Every catalog mesh carries `source_runtime_visible` and a source reason; the lab applies that immutable value. Frustum and occlusion remain explicitly external.

Direct14 plus strict ASan/UBSan and clean packaged Forward+ catalog/chain/async routes pass. Extension/package SHA256: `ae2f240583d582d00ce3390780e02ae2bee55655474a1c27451a8098dea5beac`.

### Shipped vehicle constructor families (P5-A03)

`sa_vehicle_families_probe /game` reads the actual212 `vehicles.ide` definitions and constructs an immutable source-family value for every one. Ten model families and ten constructor branches are present; the two recognized fake-aircraft types are absent from this shipped corpus and their source default branch is tested separately. Exact model/TXD/handling identities are retained, with no model400/476 fallback.

Direct1300 and strict ASan/UBSan pass; full builds, smoke, native sweep33/0 and clean packaged Forward+ catalog/chain/async remain green. Extension/package SHA256: `55bf329e32a775111b06c7055e15e8e2c9f0a04a32c586bb7fa8c49858bbbf47`.

### Vehicle-family control dependencies (P5-A04)

`sa_vehicle_family_control_probe` runs one direct source transition for ordinary road input, Boat controls, Train follower/free-carriage state, Trailer support and Quad delegation. It also pins the reversed common Abandoned-status transition used by Helicopter/Plane without claiming their address-backed flight bodies. Direct10 plus strict ASan/UBSan and native sweep33/0 pass; the marker explicitly reports `complete-flight=0 complete-bike=0`.

### Cross-family vehicle lifecycle (P5-A05)

`sa_vehicle_family_lifecycle_probe /game` runs the twelve recognized source families through exact constructor/collision binding, driver/passenger ownership, resolved collision damage, destruction and epoch reload. Direct91 and strict ASan/UBSan pass; held immutable history survives current-owner cleanup. The coordinator consumes source-resolved damage and does not invent family damage formulas or presentation effects.

### Destructible object lifecycle (P5-A06)

`sa_object_lifecycle_probe` runs source effects0/1/20/21/200/202 through health/multiplier damage, changed-model, smash and breakable value states, then rejects stale reload and clears epoch2 owners while held history survives. Direct29, existing real-object10 and strict ASan/UBSan pass. Particle/render replacement remains a separate P7 consumer.

### Deterministic source path graph (P6-A01)

`sa_path_graph_probe /game` parses all64 shipped node/link payloads and adopts the exact Grove path-area identity set. It pins the actual17-node vehicle route area14 node0→node1 at source distance313, repeats it after generation replacement and rejects stale/altered residency. Direct15 and strict ASan+UBSan pass; route following remains an AI consumer.

### Deterministic task/event/group flow (P6-A02)

`sa_source_event_flow_probe` runs a three-producer group route twice and compares all seven task transitions. It preserves source capacity16 event queues, group fan-out order, script-command first-tie and ordinary-event last-tie priority behavior. Direct25 and strict ASan+UBSan pass; perception remains an external typed event producer.

### Moving source population and pool pressure (P6-A03)

`sa_population_runtime_probe /game` moves model400 traffic and model7 peds along current Grove source graph routes, fills pools to the source free-space threshold and applies exact frame-gated closest cleanup. Direct248 and strict ASan+UBSan pass with vehicle103→102 and ped133→132; parked definitions alone are not counted.

### Source combat transitions (P6-A04)

`sa_combat_runtime_probe /game` parses71 shipped weapon rows and runs ped/vehicle/object instant-hit, projectile, area-fire, armour, health and death transitions. Direct15 and strict ASan+UBSan pass. Camera/use remain non-damage classes and melee combo damage stays with its separate source owner; visual/audio effects are not fabricated.

### Wanted pursuit and escape (P6-A05)

`sa_wanted_runtime_probe` runs offense600 through source level3, four-cop pursuit and roadblock threshold12, then applies police-presence/elusive-vehicle rules and timed escape decay to clean. The306-event scenario repeats identically; direct927 and strict ASan+UBSan pass.

### Death and arrest return-to-play (P6-A06)

`sa_restart_lifecycle_probe /game` runs separate death→Hospital and arrest→Police recoveries and applies all63 source restart effects: actor, wanted/tasks, world/area, streaming, camera/control and gameplay reset. Direct11 and strict ASan+UBSan pass; registration alone is not counted.

### Persistent normal-play interactions (P6-A07)

`sa_interaction_runtime_probe` buys and uses a property, garage and shop, saves money/ownership/use/purchase progression in a versioned checksum envelope, restores into a fresh owner and continues after restart. Direct11 and strict ASan+UBSan pass; truncated/corrupt saves retain current state.

### Source boot/first-mission checkpoint (P4-A06/A07 dependency)

`./build/mad-sa-linux --play --new-game --boot-gate --game-dir /game --seconds 700` follows the unchanged source route through mission0 and mission2 and exits0 only after the real mission2 thread terminates with control enabled and fade alpha0. Native `6dd454b7` owns exact world/model/COL handoff, mission actors, source car-recording interpolation, GXT and source-duration mission-audio clocks. Marker: `play-boot-gate-ok ... no-fault=1`. This verifies bounded P4-A06 boot, not cutscene/NPC/audio presentation or broad story progression. Focused peds9/audio/carrec7/beat8/trains5 and Session5482/scheduling106/frame104/transaction71/portable111 pass; extension SHA256 remains `acf7d35b3f433e1d4323fc8c1357062408a0c67292223764654a33c9b30bdb0c`.

`./build/mad-sa-linux --play --new-game --first-mission-gate --game-dir /game --seconds 700` uses the same normal schedule and additionally requires first-mission camera/text/audio/cutscene/train owner cleanup. The marker records camera9, text revision936, cleared cutscene, completed audio clock, stopped beat and trains0 with `presentation-feedback=0`. Native `3befe10a` closes P4-A07 ownership, not final audiovisual presentation or broad story progression.

### Committed core frames (P2-A05)

`sa_core_frame_probe [owned-game-dir]` exercises `NativeScriptFrame`, which
publishes `shared_ptr<const NativeScriptFrameSnapshot>` only after the existing
SCM `RunPass` completes. Owned clock/pad samples, VM state/globals/threads and
ordered post-commit clock/fade/output observations and value-only streamed
registry state contain no Godot/RW pointers or script payload bytes.
Pending and quota continuation freeze the pass sample; no new scheduler, clock,
service implementation or gameplay is introduced. Failed passes retain the
previous presentation without rolling back already committed VM/host effects.
Successful reload invalidates the current epoch, not previously retained values.

```sh
docker --context rootless exec -w /workspace mad-sa-graphics-build cmake --build build/godot-native --parallel 2
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_frame_probe /game
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_session_probe /game
```

The 104-check frame test and existing 5467-check session regression pass. Real
startup still commits14 instructions then reports Unsupported `04E4@56022`:
fixture success is not completed boot. Evidence: `artifacts/build-runs/p2-a05-*`.
The frame TU is core-only; A05 kept the extension byte-identical to P2-A04.

### Shipped SCM corpus/schema (P4-A01)

`NativeScriptSchema` separates the pinned bytecode form from implemented VM
semantics; a known form is never executed by the default switch as a NOP.
`NativeScriptCorpusManifest` records exact raw tags/array metadata and owned
main/mission/streamed thread forms without copying SCM bytes.

```sh
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_session_probe /game
docker --context rootless exec -w /workspace mad-sa-graphics-build python3 gta-reversed/source/app/platform/linux/NativePickupScriptProbe.py --run --game-dir /game
```

Require `checks=5472` and the current `script-corpus` marker with `sites=1359`,
`opcodes=44`, `forms=49`, `frontier=029B@218276`, `next=218298`,
`fingerprint=F2F1C258210742AD`, `nop-substitution=0`. The complementary CPU route
is593 sites/32 opcodes/36 forms and stops at host-unready `0570@205876`. This
classifies the encountered startup path only; 0814 registration is now owned by
P4-A05, while 029B object construction, broader mission/streamed corpora and
genuine boot remain later P4 work.

### Deterministic script scheduling (P4-A02)

`NativeScriptSession` remains the only scheduler. It owns the source depth-8
GOSUB/RETURN stack, tag-zero main/streamed child parameters, next-pass head
insertion, mission/streamed BaseIP and generation-qualified streamed payload
users. `script.img` bytes stay private and can unload only at zero users.

```sh
docker --context rootless exec -w /workspace mad-sa-graphics-build cmake --build build/godot-native --parallel 2 --target sa_core_scheduling_probe
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_scheduling_probe /game
```

Require `sa-core-scheduling-ok checks=106 commits=31`,
`passes=18,9,1,1,1,1`, `stack=8`, `streamed=79`, and
`deterministic=twice`. The fixture covers all source numeric vararg tags and
mission/streamed base-relative returns; the real read-only registry verifies all
79 metadata↔VER2 names plus exact unpadded sizes. It does not claim every
streamed body, entity-attached brain behavior, genuine boot or save semantics.
Evidence: `artifacts/build-runs/p4-a02-*`.

### Asynchronous script-service transactions (P4-A03)

`NativeScriptServiceTransaction` gives one exact SCM service identity a
pointer-free owner/attempt ticket. Repeated Pending polls retain that ticket;
cancel notifies once and must be acknowledged before the same instruction can
retry with a newer attempt. A worker can report only Pending, Prepared or Error:
Prepared is internal and is never script Ready before the host's actual effect
and journal commit. The current realtime consumers are `04E4` and `03CB`; this
does not create another scheduler, worker or generic fake service implementation.

```sh
docker --context rootless exec -w /workspace mad-sa-graphics-build cmake --build build/godot-native --parallel 2 --target sa_core_service_transactions_probe
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_service_transactions_probe
docker --context rootless exec -w /workspace mad-sa-graphics-build python3 gta-reversed/source/app/platform/linux/RealtimeScriptHostProbe.py --run --game-dir /game
```

Require `sa-core-service-transactions-ok checks=71`, `attempts=2`,
`session-stable-id=1`, `session-effect=once`, `ready-before-commit=0` and
`deterministic=twice`. The real host fixture additionally validates the resident
source-COL world, two-phase cancellation, attempt+1 retry, exactly one world
revision/event, invalid Prepared retirement and worker exception handling. The
actual parser-worker placement gate passes with explicit generator cleanup for
the exact privately held packet. Original-save compatibility and genuine boot
remain later P4 work.

### Portable script owner envelope (P4-A04)

`NativeScriptPortableSave` encodes one quiescent `NativeScriptSession` graph as
canonical little-endian value fields under a strict v1 header, source/schema
fingerprints and checksum. A restarted process must independently load the exact
SCM and resident streamed payloads before restore. The envelope contains no
pointers, raw C++ structs, script asset bytes, pending service transaction or
process `SessionId`, and it is not the original PC save/settings format.

```sh
docker --context rootless exec -w /workspace mad-sa-graphics-build cmake --build build/godot-native --parallel 2 --target sa_core_portable_save_probe
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_portable_save_probe /workspace/artifacts/build-runs/p4-a04-portable-envelope.bin
```

Require writer/reader success and `sa-core-portable-save-ok restart=exec
envelope=v1 owner=script-session asset-bytes=external`. The6863-byte fixture
preserves main/mission/streamed stacks, globals and streamed users, re-encodes
byte-identically and matches continuation passes `3,3,3,1`. Truncation, version,
checksum and source/payload mismatches retain the destination graph. Evidence:
`artifacts/build-runs/p4-a04-*`. Complete gameplay persistence and classic-PC
save import/export remain later P4/P8 work.

### Source stunt-jump registration (P4-A05)

`NativeStuntJumps` owns the source capacity-256 registration pool used by `0814`.
The complete fifteen-float-plus-integer form is decoded by the sole script session
and committed through the real host service; each entry retains exact start/end
boxes, camera and reward values with source initial flags. Runtime stunt detection,
camera activation, reward/stat/audio/money effects, reset and save/load are not
claimed by this atom.

```sh
docker --context rootless exec -w /workspace mad-sa-graphics-build cmake --build build/godot-native --parallel 2 --target sa_core_stunt_jumps_probe
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_stunt_jumps_probe
docker --context rootless exec -w /workspace mad-sa-graphics-build python3 artifacts/build-runs/godot-wayland.py python3 gta-reversed/source/app/platform/linux/RealtimeScriptBootProbe.py --run --game-dir /game
```

Require `native-stunt-jumps-ok checks=261` and the boot marker with six captures,
mission quanta `0/256/512/768/1024/1280`, `029B@218276`, `executed=25`,
`stuntJumps=70` and `fullboot=0`. The route proves exact registration and strict
frontier behavior, not genuine controllable play. Evidence:
`artifacts/graphics/radar-ipl-boundary-boot-runtime.log` and
`artifacts/build-runs/p4-a05-stunt-sanitized.log`.

### Mission object/generator continuation (P4-A06 checkpoint)

`NativeScriptObjects` owns the bounded source object identity/lifetime state used by
the observed mission slice: generation-safe references, no-offset/regular creation,
heading, cleanup, collision effect, freeze/dynamic, velocity, proofs, relative
rotation, area, coordinates, heading and LOD links. `0400` uses the owned heading-only
world transform; full 3D matrix input remains `Unsupported`. The existing generator
owner now also accepts source `0A17` player-owned updates. Garage type19/type22 records
outside the source interaction range are no-transition; near garage state remains
strict. Nothing here creates render nodes, world object cleanup, plate-generator
construction or vehicle-pool fulfillment.

```sh
docker --context rootless exec -w /workspace mad-sa-graphics-build cmake --build build/godot-native --parallel 2 --target sa_core_objects_probe
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_objects_probe /game
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_session_probe /game
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_scheduling_probe /game
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_frame_probe /game
docker --context rootless exec -w /workspace mad-sa-graphics-build bash tools/etalon-sweep.sh
```

Current markers are `native-script-objects-ok checks=10`, session5472,
scheduling106, frame104 and native sweep33/0. The real production continuation
reaches `09E2@221414` after `014C@221407` with mission commands1612 and exits1 at
the strict frontier. This is not genuine boot or controllable play; pause here and
resume P4-A06 only after user direction.

### Source camera transitions (P3-A03 bounded owner)

`NativeSourceCamera` owns the source `FollowPed` (`4`) / `CamOnAString` (`18`)
target identities, direct-behind orientation, ordinary1350ms and bike-exit800ms
transitions and an ordered immutable journal. The source active-camera front and
sampled input sequence are explicit inputs; no Godot node transform can feed the
owner. `ResolveView` remains `Unsupported` because the source `CCam` FollowPed/
FollowCar eye solvers and camera-world collision are still unreversed; the
diagnostic actor orbit is not promoted to gameplay authority.

```sh
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_camera_probe
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-deps/godot-4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64 --headless --path godot --script res://tests/camera_transition.gd
```

Require `sa-core-camera-ok checks=72` and `camera-transition-ok`. The registered
`SALegacyCamera` adapter exposes only value dictionaries and explicitly reports
`presentation_feedback=false`, `view_status=unsupported`. This verifies P3-A03's
ownership/transition gate. The full view solver and camera mode family remain the
explicit P7-A03 work, not a diagnostic-orbit substitute. Evidence:
`artifacts/build-runs/p3-camera-*`.
Current extension SHA256 after the adapter is
`de50c7832e75943827f00a97b2554fe0f561ec20ac749434ba17c1caf2b4e568`.

### Exact common Automobile construction and control (P3-A04/A05)

```sh
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_source_automobile_probe /game
```

Require `sa-core-automobile-ok checks=111` and `sa_core_model_contact_probe`
`checks=11`. The read-only fixture binds actual
model400 `landstal`, DFF/TXD/embedded COL and the `LANDSTAL` handling row into
immutable constructor/occupant state, then exercises ordinary keyboard control,
the existing source transmission/air-resistance owner, suspension lines from
actual wheel dummies, grounded wheel traction/velocity and source-ordered model
contacts. Actual `landstal_col`18 spheres/10 faces collide with qualified
isolated floor/wall fixtures and drive bounded static-building response. The
general query preserves two-sided sphere/box/triangle/line provenance and source
128/64/600/31 limits. It deliberately does not claim vehicle pool/world
discovery, dynamic vehicle/object response, damage/effects, all vehicle families
or Godot driving. Evidence: `artifacts/build-runs/p3-a05-final-*`.

### Source vehicle lifecycle and feedback (P3-A06/A07)

```sh
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_source_vehicle_lifecycle_probe /game
```

Require `source-vehicle-lifecycle-ok checks=115` and
`source-slice-feedback-ok actions=14 audio=4`. The fixture requests actual
model400 from the existing sole parser worker, then feeds Mode0 Triangle/Cross/
Square/left-X through phased source camera/task handoffs, Automobile control,
real3991/122-face source COL, vehicle-pool updates and destruction. Exit consumes an explicit
task-resolved nearby `SetPedOut` position, never a Godot transform. World eviction
is blocked until the pool/resource owner is released; generation11 migration and
ref1-to-ref2 stale-reference rejection are verified. The lifecycle observer publishes
source-initial HUD and ordered action values, and task-reported Landstal door crossings
retain exact PCM for events80/86, bank138/slot19, sounds40/33. This is the bounded
P3 gate, not full door animation, mutable HUD, mixer/spatialization, vehicle discovery,
general world/vehicle support or a Godot gameplay scene. Evidence:
`artifacts/build-runs/p3-a07-final-*`.

Current extension SHA256 after this fresh closure build is
`6d00c0bef914a5d805c0ab6189b3036f3ea13e1342a17715a02a3f08d8f0c1ca`.
The fresh package passes camera, labelled diagnostic actor, region-chain and
region-async routes under Wayland/software Vulkan with PID1 reaping and no
zombie growth.

### Source ped tasks (P3-A01 bounded fixture verified)

`NativeSourcePedControl` and `NativeSourceJump` add source input smoothing,
retail-mapped normal walk/run weights, animation timing and bounded jump/land/
hit-head/interruption flow to the pure core. The107/52-check probes include
source callback-on-fade deletion, literal foot markers, current launch/landing
observations and failure-atomic unavailable-world/clip/stale guards.

```sh
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_ped_control_probe
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_jump_probe
```

The initial probes use explicit synthetic clips/world predicates, not manufactured
gameplay Ready. Shared `NativeSourceAnimClump` now owns source Add/Blend selection,
three-pass updates and post-task retirement. `NativeSourceJump(clump)` reads real
clip durations and observes each update; its task destructor detaches callbacks,
not clump-owned animations. The standalone fixture API remains available.

```sh
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_clump_probe
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_source_clump_assets_probe /game
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_tasks_probe
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_walk_run_probe
docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_ped_tasks_probe
```

Current counts: control107/jump75/clump38/real-bank107 (13 real clips). The bank
probe reuses `IfpAnimPlayerBank::Describe`, not a new parser. The57-check task
manager probe additionally verifies owned source primary/secondary slots, nested
tree transitions, source scheduling limits, interruption and clump-safe teardown.
The25-check ordinary locomotion probe additionally verifies idle/start/walk/run/
stop, source start lookahead and phase reset. Sprint/exhaustion/turn/adrenaline
remain unsupported here rather than silently becoming normal run. Integrated
ordinary on-foot/jump tasks now pass294 checks, including inactive callback
delivery, typed death, air abort and hit-head. The real-bank fixture also executes
the integrated route with authored timings. Contacts are explicitly synthetic;
no physics or Godot source-ped host is claimed. Clean Vulkan actor/region/async regressions cover the changed
extension; evidence is `artifacts/build-runs/p3-clump-*`.
Task-manager direct/sanitizer evidence is `artifacts/build-runs/p3-tasks-*`;
this later core-only TU leaves the rendered extension byte-identical.
Ordinary locomotion evidence is `artifacts/build-runs/p3-walk-*`, also core-only.
Integrated-task and manager sanitizer evidence is `artifacts/build-runs/p3-ped-final-*`;
the full gate summary is `artifacts/build-runs/p3-ped-tasks-gates.log`. This core-only
integration leaves the extension byte-identical. Call `NotifyAnimations` after
each clump update and before `Manage`, even when the jump slot is inactive.
Static RE used the local owned `Grand-Theft-Auto-San-Andreas/gta-sa.exe` read-only;
neither native nor Godot runtime reads that executable.

P3-A02's bounded normal-sector gate is verified. `sa_core_physical_probe` verifies65 checks:31 force/gravity/
dynamic-ped pair cases,13 retail collision-step cases,17 friction cases and4
translational air-resistance cases. This
preserves source minimum/narrowing and friction accumulation/consumption, including
the unclamped second pair force. `sa_core_surfaces_probe /game` verifies611 checks
for the owned source adhesion/material binding: real179 material rows, generated
matrix/order/parser cases, atomic reload rejection and the physical friction handoff.
The existing canonical name table is shared through a metadata-only source build;
coefficients stay in the external game files. Adhesion plus the soft/steep properties
needed by the bounded response are adopted, not all surface flags/effects.
Direct/ASan/UBSan, read-only IO, pure link closure and Win32 lookup syntax checks
pass (`artifacts/build-runs/p3-surfaces-*.log`);
the extension remains byte-identical to the latest clean rendered delivery.
`sa_core_ped_response_probe /game` verifies58 ordinary support/wall/pair response
checks. `sa_core_ped_world_probe /game` verifies84 ownership/substep/rollback
checks and the decisive route: a controlled loaded snapshot steps onto a0.25
curb, transfers one dynamic-ped contact and stops before a wall; a separate
real3991 target reaches standing through the same owner and real surface data.
The owner requires complete, source-ordered normal-sector authority. This closes
the stated P3-A02 route, not whole-world order/coverage, moving supports, fall/
 head effects or Godot gameplay hosting. Core25 TUs; ASan/UBSan and native33/0 pass.
`sa_core_contact_probe /game` verifies315 upstream-model sphere/line
contact and broadphase checks, including122 real COL triangles and four authored
face groups using the existing reader.
`sa_core_ped_model_probe /game` verifies26 source model-pair checks: ordered groups,
nearest/all contacts, transformed support/head lines, source caps and a real COL
support-line hit. This is still an isolated query, not ped standing or world coverage.
Retail RE resolved box equal-face selection (ties fall through to z). The
controlled route is now composed, while retail sector-pool breadth and full ped
collision families remain open beyond this vertical slice.

### Native actor studio (P2-A06)

The separate `sa_diagnostic` archive reuses the existing native CJ startup
outfit, IFP skinning and car controller. `actor_lab.tscn` is an opt-in **diagnostic
approximation on a synthetic flat floor**, not source ped/Automobile gameplay,
world collision, mission boot or visual parity. The main region lab is unchanged.
The preview uses unlit textured materials, not a PBR/physics replacement.

```sh
# After tools/godot-build.sh and tools/godot-package.sh:
./artifacts/godot/package/runtime/godot --path artifacts/godot/package/godot \
  --display-driver wayland res://actor_lab.tscn -- --game-dir "/path/to/owned/GTA San Andreas"
# Direct CPU fixture; prints 27 canonical state rows and its success marker:
docker --context rootless exec -w /workspace mad-sa-graphics-build \
  ./build/godot-native/sa_diagnostic_actors_probe /game
```

Studio controls: WASD move/steer, Shift sprint, Space jump, E enter/exit, B brake,
Esc quit. This limited keyboard map is not P7 device/control completion. A stall
over250ms pauses the studio approximation; it does not redefine the source clock.

The optional fifth `open_game` argument enables actors before worker startup;
default false preserves existing region callers. `tick_diagnostic_actors` drives
only owned native CPU data; `diagnostic_actors(alpha, include_topology=false)`
returns independent buffers with `diagnostic_approximation=true`,
`synthetic_floor=true`, `source_gameplay=false`. Interpolation affects copied
vertices only. Startup parsing is synchronous; mesh rebuilding is deliberately
unbudgeted diagnostic work, not the P1 region publication performance contract.

`tests/diagnostic_actors.gd` compares the full native trace through walking,
running, car entry and steering, including while a region parses asynchronously.
It checks mutation isolation, native/scene teardown, retained-buffer replay and
actual rendered pixels. Clean Wayland/Vulkan package gates, wrapper ASan/UBSan,
zero remaining RW texture/raster counts, and the native33/0 sweep pass. Logs are
`artifacts/build-runs/p2-a06-*`; captures `artifacts/godot/p2-a06-actors.png` and
`p2-a06-actors.png-walking.png`. RX780M target acceptance remains separate.

## Pinned Inputs

- Godot `4.6.1-stable`, official Linux x86_64 editor/runtime, engine commit
  `14d19694e0c88a3f9e82d899a0400f27a24c176e`.
- Official archive SHA-512:
  `a76fd0fe1d44a2dd6c065b6f7b434ad75f5593c07bda3d3017f8304f2d069acbcf0f39cb5d0976f0434b56e9ea852032ddbcbdb7e0ce1c75a47e1dacb6794bd7`.
- `godot-cpp` tag `godot-4.5-stable`, commit
  `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77`.

`tools/godot-fetch.sh` uses HTTPS only, checks the archive against the pinned
digest and the release's official `SHA512-SUMS.txt`, and puts both dependencies
under ignored `build/godot-deps/`.

The adapter targets the pinned4.5 API, supported by the newer4.6.1 runtime.
The initial4.5 engine was rejected after reproducing its Wayland initialization
race;4.6 includes the upstream fix [GH-111493](https://github.com/godotengine/godot/pull/111493).

## Fetch And Build

From the repository root:

```bash
docker --context rootless exec -w /workspace mad-sa-graphics-build ./tools/godot-fetch.sh
docker --context rootless exec -w /workspace mad-sa-graphics-build ./tools/godot-build.sh
```

The build is rootless, configures `godot/native` with CMake in Release mode,
passes `REPO_ROOT=/workspace` and the pinned `GODOT_CPP_DIR`, enables PIC, and
builds in `/workspace/build/godot-native` with `-j2`. Its required output is
`godot/bin/libsa_legacy.so`. It does not use the Conan toolchain or build/open a
graphics context. The adapter supplies
`godot/native/CMakeLists.txt` and `godot/sa_legacy.gdextension`; the scripts
fail instead of creating substitutes if either is absent.

## Run On Fedora 44

The default path is explicitly native Wayland plus Vulkan Forward+. No X11 or
Compatibility fallback is accepted (the lab rejects an engine display fallback):

```bash
./play-godot.sh -- --game-dir "/path/to/owned/GTA San Andreas"
./play-godot.sh -- --game-dir "/path/to/owned/GTA San Andreas" \
  --seconds 95 --route --capture-dir "$PWD/artifacts/godot/rx780m" \
  --radius 350 --cap 256
```

Set `GODOT_BIN=/absolute/path/to/Godot_v4.6.1-stable_linux.x86_64` to use a
separately installed executable. Otherwise the launcher uses the fetched runtime
in the repository or `runtime/godot` in a staged package. All lab arguments,
including the required external `--game-dir`, belong after the `--` separator.

Alternative profiles are deliberately explicit and produce separate evidence:

```bash
./play-godot.sh --compatibility -- --game-dir "/path/to/owned/GTA San Andreas"
./play-godot.sh --x11 -- --game-dir "/path/to/owned/GTA San Andreas"
./play-godot.sh --x11-compatibility -- --game-dir "/path/to/owned/GTA San Andreas"
./play-godot.sh --headless -- --game-dir "/path/to/owned/GTA San Andreas" --seconds 5
```

Headless runs exercise loading and control flow but do not produce rendered-image
evidence. Compatibility output is not interchangeable with Forward+ output.

For a normal Fedora 44 Wayland desktop on an AMD RX 780M, the relevant host
components are the x86_64 runtime, Wayland client libraries, Vulkan loader, and
Mesa RADV driver. Inspect first; if packages are missing, the operator can run:

```bash
rpm -q mesa-vulkan-drivers vulkan-loader wayland-libs libxkbcommon
sudo dnf install mesa-vulkan-drivers vulkan-loader wayland-libs libxkbcommon
```

The scripts never invoke `sudo` or `dnf`. Forward+ requires working Vulkan; use
`vulkaninfo --summary` from Fedora's `vulkan-tools` package for host diagnostics.

## Controls And Evidence

- `W/A/S/D`: horizontal movement; `Q/E`: down/up; left Shift: faster movement.
- Right mouse button: mouse look; `Esc`: release mouse, then quit.
- `1` through `4`: clear day, evening, night, overcast noon.
- `F1`: textures; `F2`: prelight; `F3`: vertex-only; `F4`: fog.
- `F5`: PC SA two-pass additive `ColourFilter`, off by default for diagnosis;
  source `timecyc` coefficients, not an orange LUT. PS2 filter/radiosity/heat haze
  are not implemented. Dummy audio is intentional: this is a visual lab.
- `F12`: application-framebuffer capture; `R`: repeatable camera/environment route.

`--capture-dir` receives PNG captures, JSON manifests, and CPU frame-interval
CSV. Keep it under ignored `artifacts/godot/` or another external path. A run
manifest records the active renderer, display server, GPU/driver where exposed,
camera, environment, component toggles, residency counters, source hashes, and
known limitations. These records do not by themselves establish PS2 or original
PC parity.

`runtime_seconds`/route clocks use Godot's simulation delta (which can be capped
on a slow software renderer). `wall_seconds` and `cpu_frame_interval_ms` use the
monotonic clock; the first interval is0. Thus `--seconds 95` can take longer than
95 wall seconds. Startup parsing/publication costs are recorded separately.

## Region P0 Gate

Run the focused region checks from the repository root against an external game
installation. The runner only reads `--game-dir`; logs are written under the
ignored `artifacts/godot/` directory.

```bash
./tools/godot-region-test.sh cpu --game-dir "/path/to/owned/GTA San Andreas"
./tools/godot-region-test.sh render --game-dir "/path/to/owned/GTA San Andreas"
```

The `cpu` profile is headless. The `render` profile must be requested explicitly
and uses native Wayland with Vulkan Forward+ and Dummy audio, so an unattended
CPU run cannot hang waiting for a display. `GODOT_BIN` overrides the fetched
pinned4.6.1 runtime. The runner preserves a nonzero engine exit and, even after a
zero exit, requires the profile's fixed success marker and rejects Godot error
diagnostics. CPU and rendered checks pass on the build server; hardware reflight
remains a separate target gate.

The P0 contract keeps finite source UV values unchanged. A candidate containing
non-finite data is rejected as a whole, leaving the last complete world active;
it is not repaired by clamping coordinates or dropping individual triangles.
Rejection diagnostics carry structured archive/model/placement/geometry/triangle
context. The viewer restores its last accepted camera and keeps its committed
scene; it does not claim gameplay collision coverage. F6 asynchronously retries the
rejected candidate; another F6 while pending is ignored and counted. Ordinary retries
near that center are suppressed.

The focused real lab integration test covers retained node identity, revision,
retry/recovery and teardown cancellation (use the same pinned executable):

```bash
"$PWD/build/godot-deps/godot-4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64" \
  --headless --path godot --script res://tests/region_lab.gd -- \
  --game-dir "/path/to/owned/GTA San Andreas" --capture-dir "$PWD/artifacts/godot/p0-lab"
```

Expect `region-lab-ok`; repeat with Wayland/Vulkan flags for rendered package
inspection. Authored unbound textures (e.g. valid `signs.txd` without `chrome` and
without an authored parent) retain source material/prelight, not dummy texels.
Missing dictionaries, undecodable real rasters and unresolved parent semantics
remain honest candidate errors; this is not whole-map texture/LOD completion.

## Paired source-chain data gate (P1-A04)

The bounded LAn0/24 chain (models3991/4043) now prepares both real DFF resources
and the child COL arrays in one publication. The lab validates and retains them
together; a rejected replacement preserves both. The parent resource stays hidden
as a prepared alternate, **not automatic source LOD selection**. Packed COL data
is not gameplay collision/physics authority. Leaving this chain's window publishes
an empty paired-data section. Publication remains one main-thread operation; normal
movement parsing now uses the worker below, while initial/fixed-camera loads wait.

```bash
GODOT_BIN="$PWD/build/godot-deps/godot-4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64"
"$GODOT_BIN" --headless --path godot --script res://tests/region_chain.gd -- \
  --game-dir "/path/to/owned/GTA San Andreas" --capture-dir "$PWD/artifacts/godot/chain-cpu"
```

Require `region-chain-ok`; use the explicit Wayland/Vulkan flags below instead
of `--headless` for the rendered gate. The fixture checks122 real faces, retained
packed-array contents, hidden parent resources, retry/recovery and teardown.
`tools/godot-chain-fixture.py --output artifacts/godot/chain-fixture-NEW --case baseline`
creates only synthetic bytes in a new directory; it never reads/copies the game.
Run that directory with the test's `--synthetic-baseline` to verify rotated
DFF/COL transforms, cap-edge pairing and monotonic reopen revisions. Separate
`missing-parent`/`missing-col` fixture cases use `--expect-region-reject` /
`--expect-open-reject`. These are **test-script flags**, not production launcher
options. Missing resources reject the pair; they never produce counters-only Ready.

## Package

After a successful native build:

```bash
./tools/godot-package.sh
./tools/godot-package-audit.py artifacts/godot/package
```

Transfer the ignored `artifacts/godot/package/` directory using the user's approved
file-transfer method into a new destination (do not delete unrelated remote files).
The tree is directly runnable with its own
`play-godot.sh`. Packaging starts from an empty staging directory and copies only
the named project scene/scripts/materials, GDExtension descriptor and library,
verified runtime, README, dependency record, and license notices. It rejects
unresolved libraries, native SDL/OpenAL/GL/Wine coupling, and repository,
`/workspace`, or Conan runtime paths. It does not include game assets, captures,
tests, `.godot`, caches, or user settings.
The extension exports only `sa_legacy_library_init`, enforced by `nm` at packaging.
The independent audit additionally rejects symlinks, proprietary game/save/EXE/DLL
suffixes, unresolved or Wine/build-tree dependencies, missing license records and
an absolute extension descriptor. The package still requires an external owned
`--game-dir`; that data is private runtime input, not distributable content.
This isolates its static C++ runtime from Mesa's separately loaded libstdc++:
exported GNU-unique locale facet IDs previously caused a Vulkan-only parser crash.
The ELF export map fixes that ABI collision without changing parsing/validation.

Godot may create a local `.godot/` import cache after launch; it is runtime state,
not an input to republish. Re-run the package script to recreate a clean transfer
tree.

## Script session seed (P2-A01)

Owned SCM startup seed, not a Godot VM and not a boot. It reuses the existing
session through `LoadMain`, pins the real header facts, advances the existing
clock to123ms, commits14 pure instructions, then stops at the first honest
unavailable frontier (`04E4` collision at `56022`, next `56034`). World, player
and scene stay `Unsupported`; the original native `--headless` frontier stays
separate. Since P2-A03 the extension links the core archive but extracts only the
source-pad object for the input node; the session/clock/world owners are not yet
hosted by the Godot runtime.

```bash
./tools/godot-build.sh
file build/godot-native/sa_core_startup
readelf -d godot/bin/libsa_legacy.so | head -20
nm --dynamic --defined-only --format=just-symbols godot/bin/libsa_legacy.so
build/godot-native/sa_core_startup "/path/to/owned/GTA San Andreas"
```

Require `sa-core-startup-ok` plus the printed unavailable-frontier line. The
fixture only reads the game directory; malformed-load copies stay in memory
and no asset file is written or copied.

## Source clock (P2-A02)

Owned deterministic `CTimer`/`CClock` phase (caller ticks, no OS clock, no
RNG draw, no `CStats`, no serialization, no `Restore`). `sa_core` gains the
new clock plus the unchanged source RNG; `libsa_legacy.so` is untouched and
the probe links only `sa_core`.

```bash
./tools/godot-build.sh
build/godot-native/sa_core_clock_probe "/path/to/owned/GTA San Andreas"
```

Require `native-source-clock-ok`. Named limits: Timer/Clock/Game-unpaused
profile only; fresh `NonClippedStep` is owned `0` (source never assigns it),
retained on reinit; `+inf` FPS on zero prior increment is diagnostic, not
JSON; `GameMs` horizon rejects before `uint32` wrap while `NC`/`Pause` wrap;
strict binary32 (`-fno-fast-math -ffp-contract=off`), no x87 parity; no
frame-partition invariance; missing game data is nonzero exit.

## Source pad input seam (P2-A03)

Pure `NativeSourcePad` consumes caller-stamped samples (nonzero sequence,
nondecreasing tick, signed left axes, three Mode0 buttons); Old/New masks
derive non-consuming Down/Pressed/Released. Identical replay is idempotent;
conflicts/backwards/invalid leave state unchanged. Holding needs persistent
host device state; no-submit freezes, identical resubmit expires pressed, and
a tap between samples is unobserved. Registered SCENE Node `SALegacyInput`
receives actual synthetic `Input.parse_input_event` callbacks for device-0
left axes + X/A/Y, then samples at explicit timestamps. Default axis profile:
no inversion/swap, abs<=0.3 zero else trunc(v*128). `sa_core` gains only the
pad object; `sa_input_bridge.cpp` is the sole extension user and links
`sa_core` privately (Session/Clock/IO stay unreferenced). `exports.map` keeps
its single entry; bind/data/worker/`.so` APIs are unchanged.

```bash
./tools/godot-build.sh
build/godot-native/sa_core_input_probe --trace > "$PWD/artifacts/godot/pad-trace.txt"
GODOT_BIN="$PWD/build/godot-deps/godot-4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64"
"$GODOT_BIN" --headless --path godot --script res://tests/input_trace.gd -- \
  --reference-trace "$PWD/artifacts/godot/pad-trace.txt"
```

Require `input-trace-ok` (synthetic, not physical) plus FULL versioned
`native-source-pad-trace-v1` text match (11 canonical rows including
duplicate2) against the probe's C++ literal oracles. Core statuses are
lower_snake (`ok`, `duplicate_idempotent`, `invalid_sequence`,
`duplicate_conflict`, `backward_tick`, `non_finite_axis`, `axis_out_of_range`,
`invalid_buttons`); ignored is the owned literal `ignored`. Named limits:
device 0 only; X->1/A->2/Y->4, left axes 0/1, other devices/types/buttons/axes
ignored; invalid supported axes reject (never clamp) with
`rejected_events`/`last_event_status`; negative seq/tick reject as owned
`invalid_sequence` before the uint64 cast (bounded host validation), seq 0 is
a core error, duplicate idempotent is ok true; fixture axis 0.304 gives 38 via
trunc(0.304*128); no keyboard/focus/hotplug/remap/pause/clock/auto-latch/
inference/CJ/camera claims; no assets or game dir; the script only reads the
explicit fixture and writes nothing. Full native sweep, rendered package, and
regression gates are parent-run, not part of this lane.

## Isolated world authority (P2-A04)

Existing `NativeWorldGround` publication/generation matrix hosted in `sa_core`.
Pure core link needs the unchanged `NativeCollisionContext::LoadBeforeWorker`
pager composition moved from `NativeCollisionAssets.cpp` to existing
`StreamPager.cpp` (public API unchanged, no callsite change); otherwise the
static archive object keeps an unresolved pager reference. No weak stubs,
`--allow-unresolved`, whole-archive RW or new broker/clock/commit/physics API.
`sa_core` gains the existing Assets/EntityInfo/SourceGround/WorldGround TUs
(strict `-fno-fast-math -ffp-contract=off` plus `-fexceptions`, same full set
as the extension LOD sources) plus the POSIX adapter only; no
StreamPager/GL/SDL/Godot/RW link into core. The extension already compiles
Assets/EntityInfo plus StreamPager, so the moved function stays available.

```bash
./tools/godot-build.sh
build/godot-native/sa_core_world_probe "/path/to/owned/GTA San Andreas"
```

Require `sa-core-world-ok` (bool/error checks, Release-active, no assert side
effects, game dir required, no copies/writes/new parser). The fixture binds
real `GSFreeway7_LAn` COL bytes (Ready, header 3991, validated, 122 faces;
parent `LODGSFreeway7_LAn` KnownAbsent; pre-load/empty/NUL Unsupported) to an
owned synthetic isolated population via `LoadSources` (revision 7, committed
`LodMultiplier` 1.0, query derived from real face geometry, source math
unchanged). It proves the real SourceCollision owner, retained 122-face bytes
and same-owner snapshot across rollback/metadata-older/mismatch/same-gen
owner-copy rejection (full prior Snapshot/SourceCollision/target list
retained), next-gen adoption, StaleWorld with published generation, old
publication still queryable, and invalid/coverage rejections retaining current.
Whole-world Unsupported is not bypassed; no full census, pager dummy, async
epoch (A05 later) or Godot consumer Ready. The rehome may change extension
layout/hash (do not claim unchanged); `nm`/link-map, DLL-hash, native/
extension regressions, docs and commit are parent-run.

## Sole-owner parser worker (P1-A05)

One C++ worker owns region parsing and counter capture, with one latest-request
slot and bounded raw-packet ownership. Movement and F6 submit without waiting for
parsing. Godot object creation stays on the main thread and uses the P1-A06 work
quotas below. Startup/fixed-camera diagnostic loads deliberately remain blocking.
Worker parse time and main-thread conversion/publication stall are separate metrics.

The bridge exposes `submit_region`, `poll_region` and `cancel_region`; sync
`load_region` uses the same worker/CV and rejects overlap with an exposed async
request. Request IDs are never reused; reopening advances session epoch without
resetting publication sequence. Superseded/cancelled work cannot publish. Cancel
discards results rather than interrupting a parser inside file I/O; close joins
before destroying pager/RW state. Both manual and fixed captures drain pending work
before holding an immutable frame. Old render/COL stays live until a valid commit.

```bash
g++ -std=c++20 -Wall -Wextra -Wpedantic -Werror \
  -I gta-reversed/source -I godot/native godot/native/sa_region_worker.cpp \
  godot/native/sa_region_plan.cpp godot/tests/region_worker.cpp -pthread -o artifacts/graphics/region-worker-test
timeout 30s artifacts/graphics/region-worker-test

build/godot-deps/godot-4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64 \
  --headless --path godot --script res://tests/region_async.gd -- \
  --game-dir /game --capture-dir /workspace/artifacts/godot/async-cpu
```

Run inside the documented GCC13 container. Require `region-worker-ok` and
`region-async-ok`, not exit0 alone. CPU barriers prove queued/in-flight cancellation,
supersession and join ordering; the real-data script tests bridge/lab ownership,
reopen epochs, paired122-face retention and capture cancellation. Repeat the latter
from the clean package with explicit Wayland/Vulkan flags for integration evidence.
This does not claim automatic source LOD, gameplay collision, hardware performance
or original-image parity.

## Publication and retirement work quotas (P1-A06)

`open_game(game_dir, radius, cap, budget_items=64)` accepts1..4096 work items, not
milliseconds. Existing3-argument calls keep64. Worker planning validates and
prepacks source arrays without Godot calls; main-thread `poll_region` may return
nonterminal `preparing` across frames. Each texture upload, surface, mesh metadata
or paired-COL packet is an indivisible measured unit. Lab node/material creation
and retirement share a separate per-frame quota. Two persistent roots keep the
candidate hidden; commit flips visibility and adopts already-prepared state.

Cancelled/old generations retain **all** mesh/texture references, including not-yet-
staged resources, until metadata/node/resource holds drain incrementally. Deferred
discard is retained behind the single retiring slot, with admission backpressure.
Sync diagnostics and teardown are explicitly unbudgeted flushes. A single driver
call or root flip may exceed a desired frame time: this is not a hard deadline,
FPS guarantee or hitch-free streaming. Motion that continually supersedes requests
may defer commits until a candidate gets enough uninterrupted publication work.

```bash
build/godot-deps/godot-4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64 \
  --headless --path godot --script res://tests/region_budget.gd -- \
  --game-dir /game --cap 16 --capture-dir /workspace/artifacts/godot/budget-cpu
```

This decisive fixture forces budget1 and a small **real-data**16-instance set,
including the3991/4043 chain and122 COL faces. Require `region-budget-ok`; it tests
partial cancellation/supersession, old-generation identity and COL retention,
weak-reference lifetime of unstaged resources, drain-to-zero and repeated identical
settled centers. Repeat on explicit Wayland/Vulkan; a320×180 test window is sufficient
for ownership/upload evidence, not image-parity evidence. Default-cap256 regressions
remain separate. CPU `conversion_ms_total + staging_ms_total + commit_ms` excludes
inter-frame waiting; `publication_elapsed_ms` is wall-time diagnostic only. Sync
stall also includes the blocking worker wait. Retirement maxima are separately
reported; no GPU-only timing is inferred.

## Known differences, not hidden fixes

### Catalog residency route (P1-A07)

```bash
./play-godot.sh -- --game-dir "/path/to/owned/GTA San Andreas" \
  --catalog-route --seconds 80 --capture-dir "$PWD/catalog-captures"
```

This explicit mode defaults to radius140 when `--radius` is not supplied. It
loads every selected exterior placement plus its authored-parent closure, or the
entire selected positive area. It does **not** truncate the final set to256.
Hidden authored targets and visible instances are disjoint; malformed, missing,
skinned/animated or unresolved selected content rejects the whole candidate
instead of silently disappearing. Existing capped diagnostic APIs remain unchanged.

The held-waypoint route visits Grove/roads and all36 records of interior16,
then returns outside. Each stop advances only after its request commits and
retirement settles; cancellation/error retries the same stop. `R` pauses/resumes
the route. `route.catalog_commits/rejects` and per-frame `stats.selection` record
actual progress and area residency, not just accepted requests.
The first six completed stops receive `catalog-*-area-*.png` captures and matching
manifests after settling. The older fixed-Grove component screenshots run only
under the ordinary `--route`; they must not cancel catalog/interior transitions.

This is resource residency, **not ENEX gameplay or source runtime LOD/time
visibility**. Authored targets are retained hidden as a labelled diagnostic policy;
time-object visibility remains unknown. Ordinary free-camera mode retains the
legacy cap. Shared worker, epoch/cancellation, paired-chain data and GPU quotas
remain in force; individual calls still have no millisecond deadline guarantee.

Direct gate (inside the configured development environment):

```bash
build/godot-deps/godot-4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64 \
  --headless --path godot --script res://tests/region_catalog.gd -- \
  --game-dir /game --catalog-route --capture-dir /workspace/artifacts/godot/catalog-test
```

Require `region-catalog-ok` and no Godot errors. Real fixture counts are
Grove R140:274+47=321 and269+48=317; Grove R200:285+45=330;
roads R190:279+47=326 (five time objects, paired COL122); interior16:36+0.
The first number is genuinely visible>256, not a resident total that includes
hidden LOD targets. The test also checks repeated same-world residency, rejected
selected animation, legacy cap compatibility and committed-versus-cancelled route
progress. Repeat from a clean explicit Wayland/Vulkan package for rendered proof;
software results do not certify target GPU performance or original parity.

### TXD-qualified identity gate (P1-A01)

Streamed texture resolution now searches only the complete authored child-to-parent
TXD chain. Image keys own the resolved IMG/member lineage, owner, texture name and
runtime RW filter/address bits. Same-name textures from different TXDs do not alias;
source-null stays distinct from missing/undecodable lineage. Model, geometry and
material identities are exposed as structured surface metadata. This is not full
catalog, mip/MatFX, LOD or asynchronous-streaming completion.

```bash
build/godot-deps/godot-4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64 \
  --headless --path godot --script res://tests/asset_identity.gd -- --game-dir /game
```

Require `asset-identity-ok` and no script errors. The source-backed fixture uses
radius120/cap1200 around Grove and roads: model646's128×128 and model4172's256×256
`planta256` have distinct owners, resources and DFF-authored samplers (`0x1102`
versus `0x1106`; DFF's separate `0x10000` mip-generation flag is not part of RW's
stored filter/address word). Run the same script with the documented explicit
Wayland/Vulkan/Forward+ flags for real GPU upload/readback verification.

Only the bounded outdoor district is presented: no CJ/vehicle simulation, missions,
interiors or new physics. Source positions/normals/UV0/day-night colors and material
coefficients and model-local source material-slot boundaries reach ArrayMesh; secondary UV/MatFX, original
mip chains and renderer-specific flags are not yet carried by the reader boundary.
Source authored LOD selection is not implemented in Godot; overlapping detail/LOD
objects and vegetation sorting/edge aliasing remain visible discrepancies. Loading
is asynchronous for movement/F6; main-thread GPU publication/retirement uses work
quotas, while initial loads and indivisible driver calls remain blocking and measured.
This is not advertised as hitch-free streaming.
The route crosses the bounded region's reload threshold; compare repeated cycles,
not just the first frame. GPU VRAM and GPU-only timing are not inferred from CPU CSV.

## Reproduce data and pixel checks

Use the pinned executable (`GODOT_BIN` below), from the repository root:

```bash
GODOT_BIN="$PWD/build/godot-deps/godot-4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64"
"$GODOT_BIN" --headless --path godot --editor --import --quit
"$GODOT_BIN" --headless --path godot --script res://tests/material_contract.gd
"$GODOT_BIN" --headless --path godot --script res://tests/lab_smoke.gd -- --game-dir "/path/to/owned/GTA San Andreas"
"$GODOT_BIN" --path godot --display-driver wayland --rendering-method forward_plus --rendering-driver vulkan --audio-driver Dummy --script res://tests/material_render.gd
```

Require `material-contract-ok`, `lab-smoke-ok`, `material-render-ok` and **no shader/
script errors**; Godot's exit code alone does not establish that a script compiled.
The rendered oracle checks source grey modulation, day/night channels, sky colour
space, alpha cutoff/blend boundaries and actual PC filter output. Original-reference parity is a separate task.
