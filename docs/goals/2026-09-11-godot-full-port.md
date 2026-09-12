# Active goal: full standalone GTA:SA port hosted by Godot

Status: ACTIVE
Execution: ACTIVE, resumed 2026-09-12. Latest user instruction selects DIRECT execution: parent performs RECON, implementation and verification without subagents. P2-A01–A06 verified; P3-A01 is next. No compress unless context becomes critical, per latest user instruction.
Activated: 2026-09-11
Last updated: 2026-09-12
Approval-time snapshots: root `d147577`; native independent repository `8c62697b`
Predecessor: [delivered Legacy Look Lab](2026-09-11-godot-legacy-look-lab.md)
RECON evidence: [completed full-port RECON](../GODOT-FULL-PORT-RECON.md)
Navigation roadmap: [PORT-READINESS.md](../PORT-READINESS.md)

## Authority and operating rules

This file is the durable execution contract and evidence checkpoint for the approved P0-P9 plan. `docs/PORT-READINESS.md` remains the single navigation roadmap; do not create or maintain a competing roadmap. The immutable approval-time proposal is archived verbatim at the end of this file so its scope and decisions cannot drift.

- Preserve every required behavior below. Missing/reversed-later work remains pending; an agent suggestion, implementation difficulty, unavailable test or `Unsupported` classification cannot waive scope.
- Scope is the user's owned classic-PC content and functionality on Linux x86-64, initially Fedora 44/Wayland/Mesa/Radeon 780M. Additional platforms, mod ecosystems and PS2-only content are not invented; PS2 visual intent remains a separately reviewed reference profile.
- Any eventual incompatibility requires the exact missing behavior, source evidence, attempted alternatives and explicit user disposition. `Unsupported` is an honest intermediate state, never completion. Do not promise dates while required code bodies and owner gaps remain unknown.
- Select one small, testable atom at a time. Keep stable atom IDs and update only factual states: `in_progress` means the currently selected implementation atom; `pending` means no completion claim. Record completion and evidence only after its direct gate passes.
- Apply Pareto testing: run one decisive direct gate per atom and reuse existing coverage. Run broader gates only when a shared ABI, ownership, shader or runtime boundary changed. Never weaken semantics, fixtures or validation merely to make a gate green.
- The parent maintains automatic todos; worker count matches genuinely independent atoms with disjoint file ownership — `@cheap-worker` is default for well-specified/verifiable implementation/test/docs, `@costly-worker` only for ambiguous semantic/architectural/RE/debug decisions. Children do not delegate. After each round the parent integrates and reviews the combined diff. After each substantial verified round, commit and push only intended files and record the resulting hashes/evidence here.
- Work as `opencode` in the existing rootless environment using `/workspace` and `/workspace/build`, with `-j2` and at most one heavy GL/rendered job at a time. Existing SSH-origin push is proven; never read private keys.
- Keep legally owned external game data read-only. Never copy assets into delivery, write the install, alter/probe protected user configuration, saves or caches, or run migration/index-restoration/reset/clean operations. Package/runtime remain native Linux and must not call Wine or the original EXE.
- Reuse or narrowly extract existing C++ readers, catalogs, ownership/generation machinery and implemented source algorithms. Replace only where evidence requires it; do not duplicate authorities or create parallel frameworks.
- Preserve source geometry, materials, scheduler/timestep behavior and physics intent. Godot is presentation/hosting, not a PBR, generic-physics or preview-controller substitute. Preserve Windows/native isolation and the native backend as a regression reference.
- Introduce a versioned portable save early, but keep classic-PC import/export as a separate required codec milestone. Make no original-save compatibility claim before complete source-format codecs and semantic restart tests.
- Stage dependencies and parallelism remain exactly those in the archived approved plan. Pull only genuinely required P6/P7 owners into P4; do not fake services or turn dependency ordering into a scope waiver.

## Frozen finish line

These approved outcomes are unchanged. All six must close before a full-port declaration.

| ID | Required outcome | Completion evidence |
|---|---|---|
| F-WORLD | All owned exterior/interior content, source visibility/LOD/time-object behavior and collision/path residency | Catalog-derived placement/area itinerary; no silent cap/fallback omissions; matching render/collision generation and source-selection reasons |
| F-MECHANICS | General player/peds, all shipped vehicle/weapon behavior classes, objects, collision/physics, tasks/AI/population/traffic/wanted, death/arrest and interactions | Model/type and state-transition coverage manifests plus normal-play E2E; no original-process dependency or preview-controller substitution |
| F-SCRIPTS | Unmodified main SCM, missions, streamed/brain scripts, story and side activities/minigames/progression/cutscenes | Site-level schema/semantics/owner coverage; genuine new-game boot; start/fail/retry/complete/cleanup routes; no unknown NOP or fake Ready |
| F-PERSIST | Saves/load/restart retaining progression and every persistent owner; classic-PC save compatibility tracked separately | Restarted-process semantic round trips, fault/truncation/mismatch tests; complete source-format codecs before original-compatible claims |
| F-PRESENT | Source geometry/material/skin/mip/alpha behavior, weather/sky/water/effects, camera/HUD/frontend/localization, SFX/speech/radio/video/input/feedback | Source data/algorithm oracles, controlled rendered/audio/input routes, documented original PC/PS2 profile and approved differences |
| F-DELIVERY | Standalone Godot Linux package with external read-only assets, preserved native regression and usable target performance | Clean package dependency/no-exe/no-write gates; repeated target routes with frame-time/memory/loading evidence; reproducible input/settings/device lifecycle |

Performance thresholds remain evidence-driven and require review after measured Fedora target routes; no FPS or VRAM threshold is invented by this activation.

## Atomic execution ledger

Atom gates name the smallest decisive proof, not every regression command. Stage gates in the archived plan still apply at stage closure.

### P0 - Make real-data flights diagnostic and safe (`ACTIVE`)

| Atom | State | Small deliverable | Decisive direct gate |
|---|---|---|---|
| P0-A01 | verified | Preserve arbitrary finite source UV including `roads14_lan` value `27062702` through packet/upload without clamp/wrap/zero. Keep finite/size/index validation; no triangle removal or fake Ready. | `region-contract-ok`: exact source U retained; `region-render-ok`: actual roads triangle,9216 finite pixels/176 foreground pixels on Wayland Forward+. |
| P0-A02 | verified | Carry source model/triangle provenance and explicit failure classification through reader, bridge and lab reporting without changing accepted geometry. | CPU corpus rejects all3 NaN regions with archive/model/placement/geometry/triangle/material/component context; no numeric NaN in serialized diagnostic. |
| P0-A03 | verified | Make failed replacements and deferred capture teardown safe while preserving prior complete presentation identity. Current lab has no gameplay collision consumer: keep it explicitly unavailable rather than fabricate paired collision authority; actual render/COL coupling remains P1. | Real lab fixture retains node IDs/center/stats/revision, suppresses repeated loads, handles F6, recovers at next revision and cancels deferred capture on teardown. Same fixture passes from clean rendered package. |
| P0-A04 | blocked_external_target | Reflight Grove controls plus `roads14_lan`, radar and bridge routes in the asset-free target package, with unavailable gameplay coverage still explicit. | Server CPU/rendered package evidence passes. Fedora44/Radeon780M reflight needs the user's separate host/session; its address/access is not available here. Prior user launch predates this fix and is not substituted. |

P0 implementation and available server gates are verified; target reflight stays explicitly open. Independent P1 catalog/identity work can advance without pretending the external target gate passed. Synchronous calls have no in-flight worker cancellation: teardown/deferred capture cancellation is tested here, while asynchronous parser cancellation and render/COL coupling belong to P1.

### P1 - World/catalog and publication foundation (`verified`)

| Atom | State | Small deliverable | Decisive direct gate |
|---|---|---|---|
| P1-A01 | verified | Define TXD-lineage-aware model, texture, material and geometry identities in reusable immutable packets. | Native key fixtures; real Grove/roads gate retains52 same-name/different-lineage pairs, including model646128×128 and4172256×256 `planta256`; clean Wayland package upload/readback passes. |
| P1-A02 | verified | Complete IDE/IPL metadata and parser bounds needed by the catalog without silent caps or fallback omissions. | Native2d121583: atomic metadata fixtures, synthetic actual disk-reader bounds/budget rejections and all50935placements/242sources match independent oracle; ground109500checks retained. Catalog remains prepared, not a runtime visibility consumer. |
| P1-A03 | verified | Reproduce source `LinkLods` child/parent decisions for one authored chain. | Real LAn0/24 (3991/4043), COL122 faces, class/threshold/underwater/conditional renderer relation and unchanged-output gates pass; global runtime fields remain Unknown. |
| P1-A04 | verified | Couple that chain's COL relationship and generation to world publication. | Real3991/4043 DFFs and122-face COL commit/retain/release together; rotated/cap-edge, missing-resource and clean Vulkan package gates pass. Data-only, no gameplay collision/automatic LOD claim. |
| P1-A05 | verified | Adapt the sole-owner parser worker/mailbox for asynchronous raw parsing with request and generation identity. | CPU barrier unit, real async CPU/clean Wayland package and normal route pass: latest-only, queued/in-flight cancellation, join, nonreused IDs/epochs, retained paired data and immutable captures. |
| P1-A06 | verified | Budget Godot main-thread publication and retirement while retaining old complete state until commit. | Upload/retire interruption test shows bounded work and no mixed old/new generation. |
| P1-A07 | verified | Expand catalog-backed residency from the authored chain to the approved exterior itinerary and one interior, removing the lab's final `256`-instance visibility cap. | Catalog itinerary accounts for all expected placements with bounded memory after repeated region/interior transitions; see current checkpoint evidence. |

### P2 - Minimal portable authority hosted by Godot (`ACTIVE`)

| Atom | State | Small deliverable | Decisive direct gate |
|---|---|---|---|
| P2-A01 | verified | Extract the smallest portable C++ core composition target without SDL/GL/OpenAL monolith or address-backed `game_sa` linkage. | Dependency inspection and a headless startup fixture show no forbidden runtime authority. |
| P2-A02 | verified | Established source Timer/Clock profile, pause/scale/snapshot domains and RNG/tick separation in `sa_core`. | Repeated defined schedule produces the same clock/RNG trace without silent dt dropping or universal `60Hz` conversion. |
| P2-A03 | verified | Translated device input into deterministic semantic commands with correct edge handling. | One press/hold/release trace matches between headless and Godot hosts. |
| P2-A04 | verified | Adopted world resources through existing generation refs and world-query boundaries. | Stale resource completion cannot mutate or satisfy a newer generation query. |
| P2-A05 | verified | Added immutable owned snapshots and ordered post-commit clock/fade/output observations over the sole existing RunPass; no Godot/RW pointers. | 104-check frame fixture, ASan/UBSan and 5451-check existing session regression pass; Pending/quota, pause, exact final WAIT, mission order, failure retention/reload epochs, const consumer and real Unsupported frontier. |
| P2-A06 | verified | Rehosted existing native CJ/car presentation as a labelled studio approximation; no replacement source gameplay authority. | Full27-row headless/Godot trace with concurrent region parsing, interpolation/mutation isolation, retained-buffer replay and scene/resource teardown; clean Vulkan actor3772-pixel +region/async gates, wrapper ASan/UBSan and native33/0 pass. |

### P3 - First real playable vertical slice (`pending`)

| Atom | State | Small deliverable | Decisive direct gate |
|---|---|---|---|
| P3-A01 | pending | Port source-informed ped task state, interruption and animation-marker flow, using focused RE where bodies are missing. | Walk/run/jump/interruption fixture matches expected task and marker transitions. |
| P3-A02 | pending | Port authoritative ped/world collision and dynamic pair/contact behavior. | Controlled curb/wall/dynamic-contact route crosses loaded world without lost collision. |
| P3-A03 | pending | Port gameplay camera ownership and transitions for the slice. | Spawn/on-foot/vehicle camera transition trace has no Godot-node authority feedback. |
| P3-A04 | pending | Construct a common Automobile from real model and handling identities with occupants. | One common source model constructs with exact handling/model/occupant identities, not `400/476` fallback. |
| P3-A05 | pending | Port common Automobile control and applicable implemented `CPhysical`/Automobile algorithms. | Accelerate/brake/steer/contact fixture follows source state transitions. |
| P3-A06 | pending | Complete spawn -> enter -> drive -> exit -> destroy lifetime across pools and streaming eviction. | Normal input E2E completes the lifecycle with coherent generation/pool cleanup. |
| P3-A07 | pending | Connect action input, required HUD state and basic SFX to the real slice. | One normal-input route produces authoritative HUD/action/audio events; posed CJ or CPU Landstal alone cannot pass. |

### P4 - True SCM boot, first mission and persistence loop (`pending`)

| Atom | State | Small deliverable | Decisive direct gate |
|---|---|---|---|
| P4-A01 | pending | Build the shipped corpus/schema manifest with complete required operand and thread forms, preserving strict main53/mission1234/0814 and CPU539/0570 history. | Corpus gate classifies every encountered startup form without unknown NOP substitution. |
| P4-A02 | pending | Port wait, stack, mission and streamed/brain scheduling needed by startup. | Deterministic scheduler fixture reaches the same wait/resume/thread ordering twice. |
| P4-A03 | pending | Give asynchronous script services stable prepare/pending/commit/cancel semantics. | Cancel/retry fixture commits exactly once and never exposes fake readiness. |
| P4-A04 | pending | Define owner serialization contracts and an early versioned portable save envelope outside original settings/saves. | Restarted-process envelope round trip preserves one owned graph and rejects truncation/version mismatch. |
| P4-A05 | pending | Implement the real owner/service subset demanded by unmodified startup, including `0814` registration and separate runtime coverage. | Unmodified startup crosses each implemented site through a real owner; registration is not credited as update/reward/reset/save coverage. |
| P4-A06 | pending | Reach mission0's real wait/termination, continue main scheduling, clear fade and return live player control. | Genuine new-game boot reaches controllable play with no startup-incomplete/unsupported fault or runtime exit `1`. |
| P4-A07 | pending | Add the camera, text, audio, cutscene and cleanup owners required by the first source-reachable story mission. | Normal game-state launch reaches mission play without debug launch or dummy owner. |
| P4-A08 | pending | Complete first-mission start/fail/retry/complete plus pre/post save, process restart and load semantics. | One E2E performs all four mission routes and matching pre/post restarted-process progression. |

### P5 - Whole-world entities and all vehicle classes (`pending`)

| Atom | State | Small deliverable | Decisive direct gate |
|---|---|---|---|
| P5-A01 | pending | Complete exterior/interior/path residency and dynamic-world service from P1 catalog authority. | Area-switch itinerary preserves entity identity and paired render/physics generation. |
| P5-A02 | pending | Replace radius/cap fallback with source runtime LOD, time-object and interior visibility behavior. | Controlled time/area/LOD route records source-selection reasons with no silent omission. |
| P5-A03 | pending | Map every shipped vehicle model to its real family and constructor. | Catalog matrix has no generic `400/476` representation and constructs one fixture per family. |
| P5-A04 | pending | Port family control dependencies for road, water, rail, flight, towing and special vehicles. | One direct state-transition fixture passes for each family dependency. |
| P5-A05 | pending | Complete vehicle collision, occupants, damage, destruction and reload across classes. | Per-class lifecycle matrix preserves identities and cleans all owners on reload. |
| P5-A06 | pending | Port general objects plus destructible/damage state into the dynamic world. | Object damage/destroy/reload fixture preserves source state and generation ownership. |

### P6 - Population, AI, combat, police and recovery (`pending`)

| Atom | State | Small deliverable | Decisive direct gate |
|---|---|---|---|
| P6-A01 | pending | Port owned path graph loading/search and deterministic path ownership. | Known source route returns the expected graph path and survives area residency changes. |
| P6-A02 | pending | Port task, event, scanner and group producer/consumer flow. | Repeated producer/event fixture yields the same ordered task transitions. |
| P6-A03 | pending | Port traffic/population spawn, removal and pool-pressure rules; parked definitions alone do not count. | Bounded route creates moving traffic/peds and cleans them under forced pool pressure. |
| P6-A04 | pending | Port weapons, projectiles, fire and damage across source model/weapon classes. | Representative class matrix records authoritative hit/damage/death transitions. |
| P6-A05 | pending | Port wanted escalation, pursuit, roadblocks and escape. | Controlled offense -> pursuit -> roadblock -> escape scenario is reproducible. |
| P6-A06 | pending | Complete death/arrest, restart selection and return-to-play lifecycle. | Separate death and arrest E2Es recover world, control and camera; registration alone cannot pass. |
| P6-A07 | pending | Port garages, properties, shops and related interactions required by normal play. | Buy/use/save/reload interaction route preserves ownership and progression. |

### P7 - Complete presentation and platform families (`pending`, may begin beside P3/P4)

| Atom | State | Small deliverable | Decisive direct gate |
|---|---|---|---|
| P7-A01 | pending | Port source skins, animation families and cutscene poses. | Controlled skinned animation/cutscene capture matches source data and pose transitions. |
| P7-A02 | pending | Port material families, MatFX, mip selection and alpha behavior without PBR gap-covering. | Renderer pixel gate isolates each discovered material family and expected alpha/mip result. |
| P7-A03 | pending | Complete camera modes, HUD, radar, map, frontend and settings lifecycle. | One frontend -> game -> map -> settings -> game route restores authoritative state. |
| P7-A04 | pending | Complete MAIN/mission GXT, source fonts and substitutions. | Multilingual mission/UI fixture resolves all strings and expected glyph substitutions. |
| P7-A05 | pending | Complete keyboard, mouse, controller, hotplug and rumble/feedback behavior. | Device lifecycle route covers bind/input/disconnect/reconnect/feedback deterministically. |
| P7-A06 | pending | Port SFX, speech and environmental audio with real target Godot audio; Dummy remains CI-only. | Target audio route emits and audibly/structurally validates one event from each family. |
| P7-A07 | pending | Port radio programming and playback state. | Station/program/interrupt/save-resume fixture preserves source sequencing state. |
| P7-A08 | pending | Port weather regions/transitions, clouds, water and their time-dependent behavior. | Controlled time/region capture sequence matches source-backed transition oracles. |
| P7-A09 | pending | Port particles, shadows, reflections and post effects under the explicit original visual profile. | Isolated rendered gate covers each discovered effect family and records approved differences. |
| P7-A10 | pending | Support source startup movies only after codec, dependency and license evidence is established. | Clean-package playback gate uses the proven in-memory source route and records dependency/license status. |

### P8 - Complete progression/content and save compatibility (`pending`)

| Atom | State | Small deliverable | Decisive direct gate |
|---|---|---|---|
| P8-A01 | pending | Expand site-level semantics and owner coverage across all main, mission, streamed and brain scripts. | Corpus report classifies every shipped command site with no reachable unknown behavior. |
| P8-A02 | pending | Complete story mission and cutscene start/fail/retry/skip/complete/cleanup routes. | Representative lifecycle matrix passes through normal progression entry points. |
| P8-A03 | pending | Complete side jobs, races, schools, minigames and other activities. | Each discovered activity family has one normal start/result/cleanup E2E. |
| P8-A04 | pending | Complete purchases, stats, rewards/unlocks, interiors and their persistent owners. | Restarted-process progression route preserves and reapplies each owner family. |
| P8-A05 | pending | Inventory and implement cheats, replay and special script-driven states rather than silently omitting them. | Manifest has a tested semantic route or explicit still-pending row for every discovered feature. |
| P8-A06 | pending | Complete original-PC save block codecs, checksum and reference repair separately from port-native saves. | Source-format fixtures round-trip every block and reject corrupted checksum/references. |
| P8-A07 | pending | Validate original-PC import/export against full progression semantics before compatibility is claimed. | Fresh-process import -> play/change -> export -> import route preserves semantic state. |

### P9 - Full-port closure and target release candidate (`pending`)

| Atom | State | Small deliverable | Decisive direct gate |
|---|---|---|---|
| P9-A01 | pending | Close every remaining required row across F-WORLD, F-MECHANICS, F-SCRIPTS, F-PERSIST, F-PRESENT and F-DELIVERY. | Finish-line audit contains no unresolved required behavior, fake readiness or original-runtime dependency. |
| P9-A02 | pending | Run long normal-play, route, reload, device, mission and save sessions on the Fedora target. | Reviewed endurance itinerary completes with preserved artifacts and no unbounded resource growth. |
| P9-A03 | pending | Measure CPU/GPU/IO/frame-time/memory/loading behavior and propose target thresholds for review. | Repeatable target measurements support explicitly approved thresholds. |
| P9-A04 | pending | Optimize only measured stalls without changing source behavior. | Before/after trace improves the selected stall while semantic and presentation gates remain unchanged. |
| P9-A05 | pending | Prove asset-free reproducible clean packaging with external read-only data and private-test/public-distribution licensing separated. | Clean environment gate verifies dependencies, no EXE/Wine, no asset/config writes and documented licensing status. |
| P9-A06 | pending | Execute final catalog, route, mission, save, effects, device and native-regression closure. | Cross-axis release-candidate sweep and reviewed reference differences pass before any full-game declaration. |

Atom count: **68** (`P0-A01` through `P9-A06`, scoped per stage; IDs are never renumbered or reused).

## Current checkpoint and evidence

### 2026-09-12 — DIRECT; P2-A06 verified

- **Current result/versions:** native `6bbebc48` pushed; root companion is the containing commit (base `f513b0f`). Extension SHA256 `2c9dfb65f8179439c73966c9efcb3d8abed45ff9235bec28de424c62570be959`. P0 3/4 +P1 7/7 +P2 6/6 =16/68 verified atoms (23.5%, not workload or game readiness). All six full-port axes and target-GPU reflight remain open.
- **A06 evidence:** `artifacts/build-runs/p2-a06-final-gates.log` ends `p2-a06-final-gates-ok`; native27-row trace, wrapper-ASan/UBSan, IO read-only/no-EXE, frame104/session5451, package studio launch, actual actor3772 pixels, retained/mutation-safe buffers and concurrent region parse, clean packaged region_chain/region_async. `p2-a06-native-sweep.log`33/0 after shared texture-linkage fix. PNGs `artifacts/godot/p2-a06-actors.png` (driving) and `p2-a06-actors.png-walking.png` (CJ+car) reviewed; server llvmpipe is not RX780M/source parity. Commands and controls are in `godot/README.md`.
- **A06 resolved experiments:** Godot API has no exposed ARRAY_FLAG_FORMAT_VERSION_2, use the established flags0 path; source resolved vehicle paint comes from surface.color, not legacy marker triCol. Pixel presence compares against the background rather than assuming saturated paint. ASan found48 orphaned zero-size rasters (13824B) in old TexSample_LinkedParse's NULL-driver dummy path; a name-only read callback retains the same texture-reference semantics without allocating rasters. Final sanitizer and RW allocation-count checks pass, no suppressions; all native raster hashes remain unchanged.

- **P2-A06 frozen boundary (verified):** reuse `RealtimeGameplay` unchanged, including existing CJ startup outfit/IFP skinning and car pose, in a separate `sa_diagnostic` archive (not pure `sa_core`). Opt-in `open_game(..., diagnostic_actors=true)` parses before worker startup; ticks are owned CPU-only. Studio uses an explicitly synthetic flat collision fixture, unlit preview materials and a labelled approximation; it is NOT whole-world collision/source gameplay. Transfer owned numeric topology/pose buffers only; interpolate vertices on presentation copies without feeding them back. Default region API stays compatible; native parser concurrency/teardown order unchanged.

- **New evidence:** `p2-a05-frame.log` and `p2-a05-sanitized.log` both `sa-core-frame-ok checks=104`; unchanged existing VM probe `p2-a05-session.log`5451 checks; startup, clock509412, input497, world79, native build+smoke pass. Logs under `artifacts/build-runs/`. Rebuilt extension SHA256 is still exactly `0e2e1115ba6f2838daf29dc46dd4882f7b53118447ba816fc0a4931090d9d598`, so prior clean rendered-package evidence remains applicable; this atom does not host the VM in Godot. Core now10 TUs. Synthetic fixture initially forgot the six executable SCM header jumps and used integer operands for a float service schema: corrected test encoding/counts, no product semantics changed to pass them.

- **Current boundary:** one completed existing `RunPass` publishes an owned immutable snapshot. Quota/Pending continuation holds the same sampled clock/input and advances Session time only once. This bounded frame policy does not change the bare Session API or native host. Caller retains clock/pad authority; no combined tick API with partial rejection, no second scheduler. A commit observer records ordered value-only instruction/clock/fade/output observations after VM commit, not Pending attempts or fabricated world effects. Failed passes retain the previous presentation snapshot without pretending to roll back host effects. Successful reload changes epoch; retained snapshots remain readable. Direct fixture covers order, pause, continuation, faults and reload plus real unsupported startup frontier.

- **Result:** `sa_core` reuses generation-qualified world publication and real COL ownership; stale generation/metadata/changed-owner commits retain the previous publication. The 79-check fixture uses synthetic isolated metadata plus real3991 COL/122 faces, not whole-world physics or Godot world authority.
- **Versions:** verified code root `875916f`, native `2457d32b` (both pushed); Godot4.6.1 / godot-cpp4.5, GCC13/rootless `mad-sa-graphics-build`. Extension SHA256 `0e2e1115ba6f2838daf29dc46dd4882f7b53118447ba816fc0a4931090d9d598`.
- **Evidence:** `artifacts/build-runs/p2-a04-gates.log` → `p2-a04-gates-ok`; `p2-a04-world.log`, `p2-a04-collision.log`, `p2-a04-package-runtime.log` cover core adoption, native collision and clean Wayland/Vulkan paired-data regression. Core startup/input/clock and read-only trace pass. Core archive has9 TUs; extension extracts only Pad; single ELF entry export. Startup remains14 commits then Unsupported04E4@56022 (next56034), not completed boot. Full six axes and target-GPU reflight remain open.
- **Build/core test:** `docker --context rootless exec -w /workspace mad-sa-graphics-build cmake --build build/godot-native --parallel 2`, then `docker --context rootless exec -w /workspace mad-sa-graphics-build ./build/godot-native/sa_core_world_probe /game`.
- **Demo:** `./play-godot.sh -- --game-dir "/path/to/owned/GTA San Andreas" --catalog-route --seconds 80`; clean delivery is `artifacts/godot/package/`, assets external/read-only. Package procedure: `godot/README.md`.
- **Next:** P3-A01 source-informed ped task/interruption/animation-marker flow; do not promote the A06 diagnostic controller into source gameplay. No source gameplay/boot/save closure is implied by P2.

### Preserved boundary notes

- **P2-A04 frozen seam:** reuse `NativeWorldGround`'s existing immutable publication, source-COL owner and generation-qualified query matrix in `sa_core`; no new resource broker, clocks, commit API or physics substitute. A pure core link requires moving the unchanged `NativeCollisionContext::LoadBeforeWorker` pager-composition definition from `NativeCollisionAssets.cpp` to existing `StreamPager.cpp` (public API unchanged), because otherwise pulling Assets.o also pulls its unresolved pager reference. Add the existing Assets/WorldEntityInfo/SourceGround/WorldGround TUs with strict FP/exception flags. The decisive fixture binds real3991 COL bytes to an explicitly synthetic isolated population, tests stale generation/metadata/same-generation-changed-owner rejection with prior publication retained, and preserves Unsupported for missing general-world authority. It does not claim whole-world ground, async epoch/cancel or Godot gameplay adoption; those consumers remain later atoms. Rehome may change extension layout/hash, so inspect actual output before deciding rendered regression scope.

- **P2-A03 frozen seam (verified):** pure `NativeSourcePad` consumes complete caller-stamped samples (nonzero Seq, nondecreasing Tick, axes [-128,128], three digital Mode0 buttons). Old/New masks derive non-consuming Down/Pressed/Released; identical Seq replay idempotent, conflict/bad-Seq/backwards/unknown-bits/range fail atomically; no-submit freezes, subframe tap lost by sampled source, equal Tick valid. Source 0.3 deadzone then float*128 trunc, no invert/swap, owned finite/range checks explicit; fixed 128-char allocation-free canonical format. C++ literal 497 checks + 11 canonical frames (incl duplicate Seq2), pure headless no assets. Registered Godot `SALegacyInput` Node actual `Input.parse_input_event` -> `_input` (device0 left XY + X/A/Y) -> explicit Sample timestamps; persistent held state; negative host int args `invalid_sequence`; invalid axis events rejected with counters, other devices/types ignored. Synthetic test only, NOT physical; Node available but NOT attached to demo/CJ/freecamera/physics, no full controls/remap/hotplug/P7. Core CMake 5 TUs (Session, Clock, Rng, Pad, POSIX); actual ELF linkmap proves ONLY `NativeSourcePad.cpp.o` into `sa_legacy`, no Session/Clock VM in Godot; hidden exports map sole entry; hash NEW `bf3b7a019a5f90aa4d6c14523a5366e28f615b41f5674afb73c1d835d9c1b735`. Pad strict float flags, no device/OS-clock/RW/global-data authority.

- **P2-A02 frozen seam:** one owned source Timer/Clock profile in `sa_core`, caller-supplied nondecreasing ticks/divider and explicit pause/scale/snapshot/clock flags; reuse `NativeSourceRng` as a separate existing owner, with no clock-owned draws or default seed. Preserve source float operation order, separate nonclipped/pause/clipped milliseconds,300ms game-ms cap versus3.0 normalized timestep cap, fractional truncation, strict clock-minute threshold and source calendar quirks; expose their trace instead of silently dropping elapsed time. Equal timestamps are valid (zero delta); backwards/out-of-range samples fail atomically. Suspend/resume uses rebased source start time: Tick200→Suspend200→Resume1200→Tick1250 gives50ms, not250. Fresh unassigned source nonclipped-step is an explicit owned0 before first tick; reinitialise retains that field as source Initialise does. Game-ms wrap is rejected before violating existing Session horizon; unsigned other-domain wrap stays explicit. No OS clock reads, serialization, Godot/physics or scheduler rewrite; no universal frame-partition-invariance claim.

- **P2-A01 frozen seam:** introduce a static `sa_core` session-seed target from the existing `NativeScriptSession.cpp` plus the existing read-only POSIX file adapter, with a separate `sa_core_startup` headless fixture. Reuse its public C++ types and failure-atomic load semantics; no new wrapper/service framework and no `RealtimeScriptHost`, RW/Godot/platform-monolith linkage. Fixture loads real SCM and observes an explicit unavailable-owner frontier without fake Ready; its exit0 is test success, not completed boot. Existing deeper native frontier remains separate. Do not change extension linkage/output or implement clocks/input/world adoption before their P2 atoms. Direct gates: target/link closure, exact real metadata/frontier, retained session after malformed/missing reload; extension byte identity avoids an unrelated pixel rerun.

- **A07 frozen seam:** add an explicit catalog-residency mode beside unchanged capped diagnostic APIs. The existing immutable catalog selects area0 XY discs or an entire positive interior area on the sole worker; all selected static resources and authored-parent closure must load and reconcile one-to-one, otherwise reject the whole candidate and retain old state. No LOD-name/failed/animated omission bucket can produce Ready. Authored targets may be retained hidden as an explicitly labelled lab policy, not source runtime LOD; time-object visibility stays unknown until P5-A02. Keep A04 paired data, A05 identities/cancel/join and A06 quotas. Reuse StreamPager's existing TXD/DFF/emission/eviction stages, no second loader/catalog. Actual consumer is opt-in catalog route; legacy cap1/cap2/256 behavior stays compatible. Corrected corpus fixtures (visible and hidden DISJOINT): Grove2495,-1685 R140=274+47=321; Grove2498,-1618 R140=269+48=317; Grove2650,-1677 R200=285+45=330; roads R190=279+47=326 (including3991/4043,5 time models); whole interior16=36+0,26 models. Prior R130282+44 doubled targets already inside the282 seed; no product selection was changed to fit that erroneous count. Genuine visible>256 is now independently asserted. Presence is not decoding proof: unsupported selected content is a required rejection/fix, never silently removed to make a test pass. Out-of-range area rejects immediately; empty selection may reject on worker, avoiding whole-catalog main-thread scans.

- **A05 frozen seam:** one pure-C++ parser worker owns `StreamPager_Update` and counter capture while running; Init/configuration precede thread startup and Shutdown follows join. Owned raw packets carry request/session identity, scene, rendered placement identities, frame/counters and parse error/timing; no Godot or escaped RW pointers. Main-thread bridge assigns never-reused request IDs/session epochs, creates GPU resources, and advances prepared revision only for a current successful result. Existing sync `load_region` uses the same worker/CV and rejects overlap with an exposed async request. New submit/poll/cancel exposes explicit pending/ready/error/cancelled/idle outcomes. Cancellation/supersession discards results, not unsafe interruption of file I/O. Lab keeps paired active data until no-await commit; normal reload/F6 use async, initial/diagnostic load stays sync. Main-thread publication remains unbudgeted until A06. No reset of publication sequence on close/reopen.
- **A06 frozen seam:** optional fourth `open_game` argument `budget_items:int=64` (1..4096, old3-arg calls unchanged) controls logical conversion/staging/retirement work quotas, not a hard wall-time/FPS promise. Pure worker planning reuses existing validation/alpha/group ordering and pre-packs surface data without Godot calls; main creates one texture/surface/metadata unit at a time and reports `preparing` until complete. One retiring conversion slot gates admission of another; raw requests still coalesce. Lab stages under an attached hidden root, budgetedly creates nodes/materials and retires hidden old nodes, and flips two roots plus paired state in one measured no-await commit. No new candidate admission while its retiring generation remains. Hold references to prevent a whole-generation last-reference avalanche. Sync diagnostics/teardown explicitly flush unbudgeted; cancellation cannot publish partial or stale resources. Nonpreemptible Godot uploads/frees/root flips are measured atomic units with honest overshoot, never disguised as a whole-scene single unit. Idle main polls continue retirement; no generic jobs/second graph authority or new commit API. Bridge-prepared and lab-active revisions stay distinct; a fully prepared but later lab-cancelled candidate may consume a prepared sequence without becoming active. Exact surfaces/material/alpha/paired-COL behavior and existing P0/A04/A05 rejection semantics remain mandatory.
- **A04 contract:** reuse StreamPager model loading/placed-mesh emission to add the real4043 parent only when its selected3991 child needs the pair; preserve the cap by reserving room, never silently publish half a pair. Parent is a retained, explicitly hidden prepared alternate, not a claim of source runtime LOD selection. Bridge returns real owned COL vertices/indices/surfaces/spheres/boxes/bounds, source placement and alias metadata, not just counters. Lab validates/copies the candidate COL payload before releasing old state, then commits nodes + COL + active generation together on the existing synchronous main-thread boundary; rejection retains both old owners, teardown releases both. COL data is memory-only; manifests contain summaries/hashes, never exported source arrays. General gameplay collision remains unsupported.
- **A04 revision clarification:** preserve existing bridge sequence across close/reopen (new object starts0); the research suggestion to reset it was contradicted by source and is not adopted. Bridge increments only after complete render+COL preparation; lab advances its active generation only in its no-await commit. Post-prepare malformed lab payload remains a terminal error with no partial commit, not a retry with mismatched revisions. A05/A06 will separately own worker cancellation and budgeted publication. No new commit API or generic packet framework is needed for this main-thread slice.
- **A04 rendered blocker resolved:** `LD_DEBUG=bindings` proved GNU-unique numeric locale IDs crossed from the extension's static libstdc++ to Mesa's dynamic runtime. `exports.map` now exposes only `sa_legacy_library_init`, enforced by packaging. The unchanged parsers pass real/synthetic CPU and final clean Vulkan package gates; no parser workaround or exception suppression.
- P0 material-boundary finding resolved: `bussign1` material0 requests `chrome`, absent from valid `signs.txd` with no authored parent. Source TxdStore lookup returns null. Streamed presentation preserves its unbound material/prelight/UV, not manufactured texels or dropped triangles; the20-triangle source fixture passes. Legacy offline fallback is unchanged. Undecodable real rasters, missing primary TXDs and unresolved parent semantics stay rejected. Implementation/server gates pass; only the separate target reflight remains open.
- Conservative ambiguity resolution: nonfinite data fails the candidate region replacement with exact provenance while the last committed world remains live. Per-triangle quarantine is not approved. Finite-large values are valid and must be preserved exactly through the relevant numeric path, subject only to existing finite/size/index safety validation.
- Available P0 evidence: fresh coherent extension/native builds; `artifacts/godot/region-contract.log`, `region-render.log`; real `region_lab.gd` in CPU and clean rendered package; `artifacts/build-runs/p0-native-sweep.log`33/0 because shared mesh ABI changed. Package image `artifacts/godot/p0-lab-package/forward_plus-p0-retained-rejection.png` shows intact previous roads scene and explicit rejected radar status. Remaining external gate is P0-A04, not a claim that the full port is blocked from independent development.

## Checkpoint history

### P2-A04 world-adoption seam — 2026-09-12 UTC

- Native `2457d32b` pushed; root companion is the commit containing this checkpoint, based on `98e839a`. P2-A04 verified; P2-A05 selected `in_progress` SEMANTIC RESEARCH ONLY (no implementation). Six axes + P0 target reflight remain open; 68 atoms unchanged.
- Seam: reused existing `NativeCollisionAssets`/`WorldEntityInfo`/`SourceGround`/`WorldGround` into `sa_core`, now 9 exact TUs (Session, Rng, Clock, Pad, Assets, EntityInfo, SourceGround, WorldGround, POSIX); no StreamPager/RW/Godot/SDL/OpenAL/GL core. `NativeCollisionContext::LoadBeforeWorker` SAME body moved `Assets.cpp` -> `StreamPager.cpp`; public API unchanged, removes archive UNDEF pager trap without weak stubs/new query framework. New `sa_core_world_probe` argv/game Release-safe 79 checks: actual `gsfreeway7_lan` COL Ready header3991 validated 122 faces, parent lod KnownAbsent; isolated SYNTHETIC single-building population + IDE/Object.dat metadata with FULL REAL COL (no asset copy/borrowed triangle), worldMetadata7/mult1; real currentHit; rollback/older or mismatch meta/same-gen changed `SourceCollision` OWNER reject old Snapshot ptr + SourceCollision ptr + target/model122 bytes retained; next gen11 adopts copied owner, old10 pub still queryable10, wrong gen returns StaleWorld stamped actual; invalid radius/mult/null/far commit retain; outside coverage/incomplete population typed Unsupported. NOT whole-original world QueryReady/async/reopen epoch/Godot gameplay adoption; existing general Unknown authority not waived.
- Gates: `artifacts/build-runs/p2-a04-build.log` world.log (`sa-core-world-ok`79), startup.log (same 14 commits 04E4 IP56022 next56034 unavailable NOT boot), input.log497, clock.log509412; native build + `--smoke` native-build/native-smoke; `NativeCollisionWorldProbe` --build/run collision-build/collision.log real source COL indexed/exhaustive/generation/join PASS (not full physics). `readelf` core world NEEDED ONLY libstdc++/libm/libgcc_s/libc; `ninja` query archive 9 objects; `nm` Assets.o NO StreamPager UNDEF (only 5 OSFile and C++/POSIX/sqrtf). DLL DID CHANGE from `bf3b7a0` to `0e2e1115ba6f2838daf29dc46dd4882f7b53118447ba816fc0a4931090d9d598` due rehome layout; actual clean packaged Wayland/Vulkan Forward+ `region_chain.gd` PASS p2-a04-package-runtime.log (3991/4043 pair 122 faces, retention/F6/recovery/far grove empty), known nonfatal NaN diagnostics. p2-a04-gates.log p2-a04-gates-ok; identical-binary linkmap audit p2-a04-extension.map core archive extraction ONLY `NativeSourcePad.cpp.o`, single ELF export `sa_legacy_library_init`; extension not world-hosted yet. Fresh strace p2-a04-io.trace/log no file.exe/game writes. Package cache-free regenerated, no new tar. Source C++ verbatim rehome no arithmetic change; affected native COL gate instead of redundant full sweep. Target software Weston13 pixman/Mesa Vulkan1.4.318 llvmpipe LLVM20.1.2, not Radeon/original parity. No user files/keys/config/caches/assets touched. Immutable approval fence preserved byte-for-byte; see journal GODOT-P2-15.

### P2-A03 device-input edge seam — 2026-09-12 UTC

- Native `47c5c109` pushed (3 new Pad files); root companion is the commit containing this checkpoint, based on `5d9ac72` (adapter/test/CMake/register/README). P2-A03 verified; P2-A04 selected `in_progress` semantic research ONLY (no implementation). Six axes + P0 target reflight remain open; 68 atoms unchanged.
- Seam: pure `NativeSourcePad` full samples Seq/Tick/axes[-128,128]/3 digital Mode0 buttons; Down/Pressed/Released non-consuming, identical Seq replay idempotent/conflict bad-Seq/backwards/unknown-bits/ranges fail atomically; no-submit freezes, subframe tap lost by sampled source, equal Tick valid. Source 0.3 deadzone then float*128 trunc, no invert/swap, owned finite/range checks explicit. Fixed 128-char allocation-free canonical format. C++ literal fixture 497 checks + 11 canonical frames (including duplicate Seq2), pure headless no assets. Registered Godot `SALegacyInput` Node actual `Input.parse_input_event` -> `_input` (device0 left XY + X/A/Y) -> explicit Sample timestamps; persistent held state; negative host int args `invalid_sequence`; invalid axis events rejected with counters, other devices/types ignored. Synthetic test NOT physical; Node capability available but NOT attached to demo/CJ/freecamera/physics, no promotion to full controls/remap/hotplug/P7. Core CMake 5 TUs (Session, Clock, Rng, Pad, POSIX); actual ELF linkmap proves ONLY `NativeSourcePad.cpp.o` extracted into `sa_legacy`, no Session/Clock VM linked into Godot; hidden exports map still sole entry; hash NEW `bf3b7a019a5f90aa4d6c14523a5366e28f615b41f5674afb73c1d835d9c1b735`. Pad object strict float flags, no device/OS-clock/RW/global-data authority.
- Gates: fresh GCC13 `-j2` build `p2-a03-build.log`, core `p2-a03-core.log` `native-source-pad-ok`; `p2-a03-reference.trace` (12 lines header + 11 frames), Godot headless `p2-a03-godot-cpu-final.log` FULL-match + independent mask/status asserts received 23 callbacks. Clean packaged Wayland/Vulkan Forward+ same input trace pass `p2-a03-input-runtime.log`; software Weston13 pixman/llvmpipe LLVM20.1.2, not Fedora Radeon. Existing startup regression `p2-a03-startup.log` same 14 commits 04E4 IP56022 next56034 unavailable NOT boot; Clock probe `p2-a03-clock.log` 509412 same profile. Link audit `p2-a03-extension.map` + hash identical audit ELF proves only Pad from core; `nm` exact `sa_legacy_library_init`. Normal clean packaged 3s world launch exit0/run-end manifest `p2-a03-world-runtime.log`, `p2-a03-short` artifacts; final cache-free package audit. Master `p2-a03-gates.log` `p2-a03-gates-ok`. All logs in `artifacts/build-runs`. Existing native product unchanged / no full sweep rerun.
- Parent fixed cross-lane status enum-vs-lower_snake / duplicate 11 trace / 0.31 typo (use 0.304*128=>38) / GDScript await coroutine errors; no semantic expectation weakened. Native 3 new files + root adapter/test/CMake/register/README; protected `.opencode`/TGA/caches not staged. See journal GODOT-P2-14.

### P2-A02 source Timer/Clock profile — 2026-09-12 UTC

- Native `7d8e7b44` pushed (new `NativeSourceClock.h/.cpp/Probe.cpp`); root companion containing this checkpoint based on `ff3b4f7` adds core CMake/README plus these docs. P2-A02 verified; P2-A03 selected `in_progress` semantic research ONLY (no implementation). Six axes + P0 target reflight remain open; 68 atoms unchanged.
- Seam: static `sa_core` is now exactly `NativeScriptSession.cpp` + existing `NativeSourceRng.cpp` + new Clock cpp + `os_file_posix.cpp`; `sa_core_clock_probe` links ONLY core; no GDExtension link change.
- Gates: fresh GCC13 CMake core targets `-j2` PASS `p2-a02-final-build.log`; real `sa_core_clock_probe /game` `p2-a02-clock-final.log` prints `native-source-clock-ok` with 509412 checks (quantity, NOT game completeness). Regression `sa_core_startup /game` `p2-a02-startup-final.log` keeps same 14 pure commits to `04E4` IP56022 next56034 unavailable-collision then `sa-core-startup-ok` (fixture success, NOT boot/deeper native Host 0814 frontier).
- Exact source profile: raw caller `uint64` ticks/divider; source frame float order/truncation; separate pause/nonclipped/clipped domains with 300ms game cap vs Step 3.0 cap, no arbitrary 60Hz; source 1000 strict-boundary seconds 60→1001 minute with weekday/month `>=` quirks; equal Tick valid zero; paused Game/NCCalendar frozen while PauseMs raw; Stop/nested-suspend rebase (Tick200→Suspend200→Resume1200→Tick1250 = 50ms); finite-cast bounds plus backwards/game-prewrap fail atomically, other NC/Pause unsigned wrap explicit. Fresh source-unassigned NC Step owned 0 / reinit retains value (labelled NOT x87 parity); Calendar Revision owned-lifecycle observation only. RNG separate unchanged SeedOnce 1 canonical 41/18467/6334/26500/19169; ticks never mutate full Inspect. EVERY-frame State/LastFrame/RNG provenance with repeated trace and real Session pause feed; horizon 14316557×300ms loop then atomic Overflow; explicit NC/Pause wrap fixture. No OS-clock/Godot/RW/Stats/physics/scheduler/serialization new authority.
- Link closure: `readelf` clock probe NEEDED only `libstdc++.so.6`/`libgcc_s.so.1`/`libc.so.6`; `nm` core clock object NO UNDEFINED symbols, RNG only `pthread_self`; `ninja -t query` core archive 4 TU proven. Extension SHA256 `p2-a02-extension-final.log` `b409d17720bbcdd340bf54e26928f4b0880cb89e7c2cd211b61a3f663340208e` IDENTICAL A07/A01, so no GPU/package/full native-sweep rerun (root touched only core target/new native files, not product CMake). Parent costly review: no blockers; initial RE example corrections needed (equal-timestamp/first-FPS/hitch-minute/suspend-50) with no runtime algorithm patched to match incorrect expectation. No original EXE/asset writes. All logs under `artifacts/build-runs/`. P2-A01 entry's then-current 2-TU label is preserved history. See journal GODOT-P2-13.

### P2-A01 LOAD-only portable core seam — 2026-09-12 UTC

- Native `dca0185b`; root companion containing this checkpoint based on `d2390f0` adds core CMake/new `sa_core_startup.cpp`+Godot README. P2-A01 verified; P2-A02 selected `in_progress` semantic research ONLY (no implementation). Six axes + P0 target reflight remain open; 68 atoms unchanged.
- Seam: static `sa_core` from exact `NativeScriptSession.cpp` + existing `os_file_posix.cpp` only; public existing NativeScript types, no new framework/no GodotVM/no service integration; new `sa_core_startup` takes argc1 game dir. No `RealtimeScriptHost`, RW/Godot/SDL/OpenAL/GL/EXE/Wine authority.
- Gates: fresh GCC13 `tools/godot-build.sh` PASS `p2-a01-build.log`; real `/game` startup `p2-a01-startup.log` prints `sa-core-frontier unavailable opcode=04E4 ip=56022 next=56034 reason=collision-unavailable` then `sa-core-startup-ok`, exit 0. Exit0 is fixture success, not completed boot.
- Exact behavior: 14 pure commits; owner stub ONLY Unsupported; sticky exact fault; real metadata 194125 main / 55976 code / 43800 globals / 135 missions / 79 streamed / build 569; error reload size/GOTO/mission-offset/non-directory preserves Loaded/State/Threads/ALL metadata/10950 global cells. Missing path reuses existing SCMFILE as game DIR yielding ENOTDIR, not `/tmp`. All asset bytes read-only into RAM, never copied to disk.
- Link closure: `readelf` exe NEEDED only `libstdc++.so.6`/`libgcc_s.so.1`/`libc.so.6`; `nm` archive only std/POSIX + 4 `OS_File` resolved inside core; `ninja -t query` archive exact 2 objects. `strace` `p2-a01-io.trace/log` shows no exe open, no `O_WRONLY`/`RDWR`, no game write, startup-marker pass.
- No unrelated rerun: extension SHA256 UNCHANGED `b409d17720bbcdd340bf54e26928f4b0880cb89e7c2cd211b61a3f663340208e` so no extra GL/package/native full-sweep rerun; readers/native unchanged.
- Frontier distinction: existing native Host deeper main53/mission1234/0814 vs new LOAD-only core-profile collision frontier — neither is full boot. Next P2-A02 researches source clock/pause/timestep/RNG; no new semantics decided yet. See journal GODOT-P2-12.

### P1-A07 catalog-backed residency — 2026-09-12 UTC

- Native `dca0185b` pushed; root companion containing this checkpoint, based on `82c67e7`. P1-A07 verified; P2-A01 selected `in_progress` RESEARCH ONLY (no implementation yet). Six axes + P0 target reflight stay open.
- Gates: coherent 13-TU GCC13 `-j2` build `p1-a07-native-build.log`, full sweep `p1-a07-native-sweep.log` 33/0, `p1-a07-unit.log` `region-worker-ok`; final driver `artifacts/build-runs/p1-a07-gates-catalog-captures.log` (13 lines, `p1-a07-gates-ok`) for latest headless catalog, package, GPU catalog 320x180, actual normal 80s 1280x720 catalog route, cache-free package. Unchanged P0/A04/A05 CPU + A06 GPU-budget passed earlier in `p1-a07-gates.log`.
- Catalog: DISJOINT Grove R140 274+47=321/134 models, 269+48=317/138 models; Grove R200 285+45=330/136 models; roads R190 279+47=326/136 models (5 time + COL122); area16 36+0/26 models. Prior hidden-double-count corrected in expectations only; population 50935 catalog-derived; selected failure = whole-candidate reject; `--catalog-route` capless selected mode, default R140, sole worker/quotas/paired generation.
- Route: 80.027092 engine / 83.236731 wall, 11 settled `catalog_commits`, 0 rejects, 12/12/0 async, active 13, last commit settling at shutdown; CSV areas 0+16, visible max >256, visible+hidden==resident; controlled [10,10,10,10]. Six NEW `catalog-*-area-*` PNGs are final (`a07-route-package/` incl. 1280x720 `forward_plus-catalog-04-area-16.png` + `a07-catalog-package/` Grove/area16 read); old `01..09` files are failed-run history. Wayland Weston13 pixman / Vulkan 1.4.318 llvmpipe LLVM20.1.2; no Fedora/parity. DLL `b409d17720bbcdd340bf54e26928f4b0880cb89e7c2cd211b61a3f663340208e`, lab `79f637720b2e357819cb330ccd03e1014422549cc7c629b8f421885e459b39e6`; cache-free `artifacts/godot/package` passes, no new tar. See journal GODOT-P1-11.
- Fixes: accepted submit no longer advances a stop before commit/cancel proof; `--catalog-route` now enables `_route_enabled` (previously 0 progress); catalog captures only completed settled stops after legacy fixed-Grove automatic captures cancelled 3 real transitions (old component captures were ordinary `--route` only); camera moved inside area16 and roads collinear `look_at` corrected.

### P1-A06 budgeted publication/retirement — 2026-09-12 UTC

- Root companion containing this checkpoint, based on `4ea8d9e`; native `95713252` unchanged. Budget1 CPU/package fixture is quota1/cap16 targeting the actual 3991/4043 chain with 16 instances; production defaults are quota64/cap256. Final default256 `region_chain`/`region_lab` CPU plus budget1 quota1/cap16 and default256 package gates all pass. `p1-a06-gates-retain.log` ends `p1-a06-gates-ok`; actual GPU logs are `p1-a06-region_budget-package-runtime.log` / `p1-a06-region_async-package-runtime.log`.
- Decisive weakref proof: hidden-stage cancellation keeps unstaged mesh/texture alive until budgeted retirement, then they disappear; old nodes/meshes/center/COL/revision stay exact and repeated exact-center settled cycles hold `resources[10,10,10,10]`. Work items are counted uploads/surfaces/frees/flips, not ms/FPS; sync/teardown explicitly unbudgeted. Deferred branch reviewed, not separately forced-tested.
- Limit retained: final normal 40s route exits 0 with `ready_count=0/submit=7/cancel=7` (C++ discards 4, lab 2, rev1, Grove retained) — slow-llvmpipe continuous movement outran prepared uploads. Safe lifecycle only, not load progress; uninterrupted fixture proves commits. Reviewed city PNG `artifacts/godot/a06-region_async-package/forward_plus-manual-000000.png`; no parity claim, no A06 tar. Next A07 is research-only: catalog-backed exterior/interior, no final 256 cap.

### P1-A05 sole-owner parser worker — 2026-09-11 UTC

- One exception-contained C++ worker owns region Update/counter capture and off-lock raw-packet retirement. Main thread owns Init/configuration, all Godot conversion and Shutdown after Stop/join. Owned packet request identity is immutable; bridge request IDs/epochs never reuse, publication sequence persists across reopen. Sync diagnostics use the same worker/CV; movement/F6 use explicit submit/poll/cancel. Cancellation discards results without interrupting file I/O. Old complete render/COL remains active on pending/stale/cancel/error.
- Parent review fixed allocation/function-copy exception escape from the thread, a timing-assumption in the Stop barrier test, async stall timestamps excluding bridge GPU conversion, and pending work committing during manual capture hold. Stop's sequential-coordinator contract is explicit; no concurrent-Stop guarantee is invented. Updated F6 regression fixtures await async completion while asserting no sync load and unchanged rejected-world identity.
- Evidence: GCC13/C++20 `region-worker-ok` barrier unit passes; `p1-a05-async-cpu-final.log`, `p1-a05-p0-cpu.log`, `p1-a05-chain-cpu.log`, `p1-a05-lab-cpu.log` pass. Clean package export/dependency audit and actual Wayland/Vulkan `p1-a05-async-package-runtime.log` pass; manual retained-world PNG reviewed, paired122-face data stays immutable after cancellation. `p1-a05-gates.log` ends `p1-a05-gates-ok`.
- Normal packaged route:40.1268 engine seconds/68.117834 wall seconds,10 async submissions/9 ready/1 cancelled/0 async errors, final publication13 and no pending request. This verifies the ordinary process-loop path, not only a manually polled fixture; no FPS improvement/hardware parity is claimed. Initial/fixed-camera loads still block and GPU conversion is not budgeted until A06.
- Last metadata-only correction labels sync stall as including worker wait (async stall includes main conversion/publication). Final clean-package3-second launch verifies that label and source hashes. Extension SHA256 `660916a4871a91c122ba537bd6d56487f27528f9458eea7783f06dc5a2c35558`; final lab script `14da5b03c170061a1ab92ca0c54032a00448fec9546d4574b49c331c5867569f`. The earlier40s route predates only this label/comment correction. Native/shared readers are unchanged, so unchanged native33/0 was not rerun as substitute evidence. Latest package is regenerated cache-free; original game remains external/read-only.

### P1-A04 paired render/COL publication — 2026-09-11 UTC

- Native `95713252` + root companion implement the contract above through existing placement/parser helpers, actual owned packed COL data and one synchronous commit. Parent DFF remains hidden/prepared; source automatic LOD/general physics are not implemented. Pure-Python fixtures contain only synthetic bytes and prove90-degree DFF/COL transforms, cap2 child-at-edge/cap1 rejection, missing parent DFF/missing child COL, and monotonic reopen revisions.
- Fresh native13-unit/extension builds and native sweep33/0; final `artifacts/build-runs/p1-a04-gates-final.log` passes P0,52-pair identities, synthetic cases and clean Wayland/Vulkan package, ending `p1-a04-gates-ok`. Real `region-chain-ok roads_rev=2 recovered_rev=3 grove_empty_ok held_faces=122`; paired-data image in `artifacts/godot/a04-chain-package/` reviewed. Software llvmpipe/Weston13 only, no target/original-parity claim.
- The initial Vulkan crash is retained in `p1-a04-gates.log`; `p1-a04-bindings-diagnostic.log` proves cross-runtime facet redirects. Final defined ELF exports are exactly the C entry point. Extension SHA256 `cfa73c06ca9e959eb03e6f06eddadae2c4dab2c72e0195082a654d909461a300`; lab script `515b7414dcfc2594b595b09d18a5125d39ff64b2ee9f7037a5935d6969bf42e0`. No raw COL arrays/assets shipped or written to manifests. Next A05/A06 remain separate ownership/budget atoms.

### P1-A03 source-closed LinkLods decision — 2026-09-11

- Native `0628fce4` adds read-only owned COL lookup and a pure evaluator in the existing catalog, not another graph. Real text LAn records0/24, model3991/4043, source draws180/450 and child COL3/header3991/122 faces produce the expected retained edge and parent collision alias. Child is normal/uses-COL/`bIsLod=true`; parent big/no-entity-collision/`bIsLod=false`. Model `bIsLod` is distinct from the collision-ownership bit. Explicit cache/multiplier constructor inputs prevent an inferred default boot profile.
- Accepted closure is unique model/name, single-child text, non-time/non-shared, building-mask, child-normal/parent-big, Ready child COL and KnownAbsent parent. Cache, shared/multi-child/unknown closure and threshold-crossing multiplier2 reject without changing output. Underwater uses the exact authored-bit OR `(COL minZ + positionZ < 0)` predicate. Relation gates cover opaque child suppressing parent, translucent child not marking it, alpha255 boundary and visible-parent fallback; no actual camera/residency/near-far rendering claim. Every catalog node's runtime fields remain Unknown.
- Parent/costly source review found and fixed dummy-class collision overclaim, child-big scan-order overclaim, missing COL-derived underwater state and a tautological partner assertion. Parent made cache/multiplier explicit, reused the existing COL diagnosis/link helper, and expanded query names beyond the legacy map (which excludes empty COL) to exercise real `8screen` Empty and `casinoblock2_nt -> casinoblock2_dy` aliasing. Unsupported per-model lookup was not exercised by that name set; pre-load/invalid-input Unsupported was. Retained ownership and failed-load preservation pass.
- Fresh gates: `p1-a03-lod-final.log` + `artifacts/graphics/NativeLodCatalog-probe.log` pass all prior disk/census fixtures (50935/6103), real CHAIN/DECISION/MASK/THRESHOLD/RELATION/FORGED/UNDERWATER/NEGATIVE/RUNTIME and synthetic building-vs-dummy boundary. `p1-a03-lookup-final.log` passes the actual COL diagnosis/lookup gates. `p1-a03-world.log` preserves exhaustive/indexed collision oracles, source ground and worker generations (measured12.02x/10.35x index speedups); these remain native preview-controller regressions, not full gameplay proof. Coherent native/Godot builds and `p1-a03-smoke.log` pass. Logs are under `artifacts/build-runs/` unless stated otherwise.
- Scope: PREPARED CPU authority only. No A04 render/COL publication or A05 async implementation, no new GPU/original/target acceptance. Native shared COL lookup/Snapshot refactor was verified by its affected source collision gates; an unchanged rendering/package sweep was not substituted for those direct checks.

### P1-A02 source metadata and bounds — 2026-09-11

- Reused `NativeWorldEntityInfo` and `NativeLodCatalog`, not a new metadata authority. Authored TXD, anim name and signed tobj hours are retained with existing first draw distance, flags, classification and Object.dat provenance. Static disk-catalog publication now requires complete per-placement metadata and cumulative population bounds before append; pure synthetic Assemble remains explicitly uncertified.
- Parent rejected a proposed validation that treated IPL size fields as authoritative record extents. Owned190binary IPLs contain1140zero size fields,41667inst records and1045car generators. Source tBinaryIplFile spans ignore size and use count; actual storage is validated against member bytes independently of advertised ranges, including nonzero advisory ranges. Synthetic valid baseline then malformed other-section/advertised/actual-inst/actual-cargen/population-budget/cumulative cases prove atomic rejection; no game bytes copied.
- Two decisive oracles pass: complete static IDE namespace14259models; placed namespace12839IDs (these counts are not interchangeable),50935placements=9268text+41667binary,242sources=52text+190binary,6103edges/6086targets,161time placements, classes34759Building/68AnimatedBuilding/16108Dummy/0Unknown. Original incorrect14259 placed-ID assertion was corrected only after independent raw-IPL enumeration proved12839.
- Evidence: `artifacts/build-runs/p1-a02-metadata.log`, `p1-a02-catalog-verified.log`; generated `NativeLodCatalog-probe.log` includes DISKFIXTURE/CENSUS. Affected `p1-a02-ground-regression.log` passes109500checks, preserving Unsupported for unknown original bounds/model-wide LOD/order. `p1-a02-product-check.log`: ninja no work; these prepared catalog units are not in native/Godot product closures, so unchanged production/GL/package suites were not needlessly rerun. Native commit `2d121583`; root companion records the checkpoint. No full runtime LOD/visibility/ground parity claim.

### P1-A01 identity round / user pause — 2026-09-11

- Native `ddc9863d` plus root containing commit carry owned model/geometry/material/texture keys, actual IMG/member TXD lineage and resolved owner, sampler-qualified caches and structured bridge metadata. Streamed lookup is child->authored parent only, no unrelated resident fallback; DEFAULT.DAT IDEs precede GTA.DAT IDEs, later TXDP assignment wins. Incomplete/cyclic/malformed/over-depth lineage rejects the candidate, complete source-null remains distinct from undecodable raster. Offline native path is retained. This is not full catalog/LOD/mip/MatFX/async completion.
- Parent fixed the final review's DAT/duplicate-parent defect, the standalone assert macro's initializer-comma issue and two GDScript API/type errors. Exact fixture exposed `0x11102` versus runtime `0x1102`: librw texture.cpp strips the separate mip-generation flag, so the test pins correct low16 sampler bits rather than a TXD-default sampler. No resource bytes, finite UV or geometry were altered.
- Decisive gate: `NativeAssetIdentityProbe.cpp` built with GCC13/C++20/assertions and exits0. `asset_identity.gd` passes headless and on clean-package Wayland/Vulkan Forward+:2 publications,366 meshes,1056 surfaces,123 model keys,524 material keys,328 texture keys,52 same-name/source-lineage pairs. Models646/4172 retain separate `gta_potplants.txd`/`cityhall_tr_lan.txd` owners,128×128/256×256 images and0x1102/0x1106 DFF samplers. Same full keys reuse one resource within publication; distinct scoped keys cannot alias. Texture bytes are hashed after actual upload/readback.
- Regressions: coherent extension/native35-unit rebuild; P0 CPU exact27062702 +3 NaN-provenance cases pass; native sweep33/0. Real lab retention/F6/recovery/deferred-teardown fixture passes from clean rendered package and its retained-city image was reviewed. Logs: `p1-identity-final.log`, `p1-package-identity-runtime.log`, `p1-p0-regression.log`, `p1-native-sweep.log`, `p1-package-retention-runtime.log`, `p1-close.log` in `artifacts/build-runs/`; final marker `p1-round-gates-ok`. Software server only, no new Fedora GPU acceptance.
- Extension SHA256 `2a6eded80b1becd81acf164abee09a38b8c3625075f404b3a5425906768fe54b`; unchanged lab script `2abc10803e6c9a74060433c96025b1fb9f091573a2e691ba9021c2c338dea518`. Package remains asset-free with external read-only game data. All current child work is finished; the pause is user-directed, not a full-port completion or an implementation blocker.

### P0 implementation checkpoint — 2026-09-11

- Native metadata/source-null change committed and pushed as `4674ce65`; root companion contains the approved activation/68 atoms, viewer fix and focused tests. No source UV was clamped or triangle dropped. Native sweep33/0 remains green after the shared ABI rebuild.
- Decisive checks: CPU `region-contract-ok` (3 retained exact-large U values in selected roads placement, all3 NaN corpus cases); rendered real triangle `region-render-ok` (9216 finite/176 foreground pixels); real lab retained-node/revision, F6, recovery and deferred teardown fixture passes headless and from clean rendered package. `p0-package-final.log` verifies successful process exit, errors absent, matching captured code/binary hashes and cache-free regeneration.
- Personal test archive: `artifacts/godot/sa-legacy-look-lab-p0-linux-x86_64.tar.gz`, SHA256 `2ae06ddb3fe1f8b2ba430d25232006ee7ff2883469740c5069c8542b472259d4`. Extension SHA256 `88ff41149ce29bc78c8f51435cb648dc964353949bbe034d34ac5cfaadfb9279`; lab script `2abc10803e6c9a74060433c96025b1fb9f091573a2e691ba9021c2c338dea518`. No game data/caches/tests included. Target reflight is still required; server evidence uses Godot4.6.1, Wayland/Weston13 and llvmpipe, not Radeon780M.

## Immutable approval-time plan backup

The following is the complete pre-activation file, preserved verbatim as the approval-time scope record. It is archival text, not a second live roadmap or a source of current status.

````markdown
# Goal proposal: full standalone GTA:SA port hosted by Godot

Status: draft
Last updated: 2026-09-11
Predecessor: [delivered Legacy Look Lab](2026-09-11-godot-legacy-look-lab.md)
Evidence: [completed full-port RECON](../GODOT-FULL-PORT-RECON.md)

**Review boundary:** this is the requested plan, not authorization to begin the full migration. RECON and documentation are complete; no product fix or new gameplay implementation is part of this planning round. The current UV failure is reproduced and remains unfixed until the next implementation stage.

## Source — latest request, verbatim

Демка с godot выглядит круто, всё окей за исключением подобного при пролёте за пределы грув стрита

```
legacy-look-lab: load_region failed: pager UV is nonfinite or out of range
ERROR: load_region failed: pager UV is nonfinite or out of range
   at: push_error (core/variant/variant_utility.cpp:1024)
   GDScript backtrace (most recent call first):
       [0] _fatal (res://lab.gd:955)
       [1] _bridge_result_ok (res://lab.gd:531)
       [2] _load_region (res://lab.gd:439)
       [3] _maybe_reload_region (res://lab.gd:643)
       [4] _process (res://lab.gd:184)
➜  mad-sa git:(master) ✗
```

Куда дальше копать будем? Жду план после RECOn для ревью, цель полный порт сделать на godot, под полным я имею ввиду всё что можно портировать

## Proposed objective and interpretation

Deliver the original game's portable functionality through Godot, not merely a map viewer or selected free-roam demo. Working scope is the user's owned classic-PC SA content and behaviors on Linux x86-64, initially Fedora44/Wayland/Mesa/Radeon780M. Preserve the previous visual restoration contract and full F1/F2 ambitions; native R6 is not closed by changing engines.

"Everything that can be ported" includes currently missing/unreversed features. They remain scheduled research or implementation work until proven otherwise; difficulty, missing bodies or unavailable tests cannot silently remove them. Inventory the whole owned source content rather than selecting only easy subsystems. Additional platforms/mod ecosystems/PS2-only content are not implicitly invented; PS2 visual intent remains a separate reference-profile decision.

No feature waiver is granted by this draft. Any eventual incompatibility requires the specific missing behavior, source evidence, tried alternatives and explicit user disposition. A label such as Unsupported is honest intermediate state, not full-port completion.

## Proposed full-port acceptance axes (not yet frozen)

| ID | Required outcome | Completion evidence |
|---|---|---|
| F-WORLD | All owned exterior/interior content, source visibility/LOD/time-object behavior and collision/path residency | Catalog-derived placement/area itinerary; no silent cap/fallback omissions; matching render/collision generation and source-selection reasons |
| F-MECHANICS | General player/peds, all shipped vehicle/weapon behavior classes, objects, collision/physics, tasks/AI/population/traffic/wanted, death/arrest and interactions | Model/type and state-transition coverage manifests plus normal-play E2E; no original-process dependency or preview-controller substitution |
| F-SCRIPTS | Unmodified main SCM, missions, streamed/brain scripts, story and side activities/minigames/progression/cutscenes | Site-level schema/semantics/owner coverage; genuine new-game boot; start/fail/retry/complete/cleanup routes; no unknown NOP or fake Ready |
| F-PERSIST | Saves/load/restart retaining progression and every persistent owner; classic-PC save compatibility tracked separately | Restarted-process semantic round trips, fault/truncation/mismatch tests; complete source-format codecs before original-compatible claims |
| F-PRESENT | Source geometry/material/skin/mip/alpha behavior, weather/sky/water/effects, camera/HUD/frontend/localization, SFX/speech/radio/video/input/feedback | Source data/algorithm oracles, controlled rendered/audio/input routes, documented original PC/PS2 profile and approved differences |
| F-DELIVERY | Standalone Godot Linux package with external read-only assets, preserved native regression and usable target performance | Clean package dependency/no-exe/no-write gates; repeated target routes with frame-time/memory/loading evidence; reproducible input/settings/device lifecycle |

Target performance thresholds will be proposed from measured Fedora routes and reviewed; no invented FPS/VRAM budget is an acceptance requirement yet. User-reported startup on780M is evidence of launch, not all these axes passing.

## Architectural decision proposed for review

```text
read-only source assets
  -> C++ readers/catalogs + sole-owner parser worker
  -> immutable model/world packets and resource completions
  -> portable C++ game authority (world, entities, tasks, clocks/RNG, SCM, progression)
  -> committed snapshots + ordered presentation events
  -> thin GDExtension -> Godot meshes/skeletons/shaders/camera/UI/audio/input devices
                          | semantic input commands back to core
```

- Extract and adapt existing standalone code before writing replacements. Do not link the SDL/GL/OpenAL monolith or address-backed `game_sa` target into the bridge. Source algorithms with completed bodies can be extracted behind owned dependencies; missing bodies get explicit RE tasks.
- Do not move gameplay into GDScript, assign Godot node transforms as game authority, or substitute `VehicleBody3D`/generic Godot physics/PBR. GDScript remains orchestration/UI where appropriate; shaders remain shaders.
- Reuse current pools, generations, pending request identities and source numeric contracts. Introduce only the core boundary needed by the next slice, not a new general ECS/framework.
- Preserve source scheduler phases and relevant timestep domains. Render interpolation, GPU stalls and parser arrival order must not become hidden inputs to gameplay. Numerical replay claims have a declared tick/platform profile.
- Keep runtime LOD selection, residency and visibility separate; keep live collision generation coupled to world publication. Retain old complete state until replacement commits; make unavailable gameplay coverage explicit.
- Keep source registration semantics distinct from full subsystem completion. A real registry may acknowledge ADD_STUNT_JUMP after correct registration; coverage cannot call stunt-jump update/reward/reset/save finished until those paths work.

## Proposed stages and gates

Stages are a dependency plan, not calendar estimates. Branches may advance in parallel only with non-overlapping files and agreed packet/service contracts. Each stage delivers a runnable slice, evidence and an explicit local commit/push, rather than accumulating an unverified feature backlog.

### P0 — Make real-data flights diagnostic and safe

Scope: fix the reproduced large-finite UV rejection, separate true NaN policy, preserve model/triangle provenance, and stop turning every failed replacement into total application exit. No blanket clamping, zeroing, dropped geometry or disabled validation.

Gate: unchanged Grove controls plus roads14_lan/radar/bridge cases; legitimate finite UV preserved through upload/render, nonfinite cases classified with explicit policy; old valid region survives failed/cancelled replacement; no false Ready or out-of-coverage gameplay. Package reflight on target. NaN compatibility behavior is a review decision below.

### P1 — World/catalog and publication foundation

Scope: TXD-lineage-aware identities, reusable model/instance packets, complete IDE/IPL metadata, material/geometry identity, parser bounds; source `LinkLods`/COL relationship for one authored chain. Adapt existing worker/mailbox to asynchronous raw parsing and budgeted main-thread Godot publication/retirement. Then expand to an exterior itinerary and one interior.

Gate: old/new generations never mixed; cancel/close during queue/parse/upload/retire; source LOD child/parent/collision decisions tested; no name-only texture collision; bounded memory on region revisits. No silent256-instance truncation as final world visibility. A full catalog coverage list classifies every expected placement.

### P2 — Minimal portable authority hosted by Godot

Scope: extract the smallest core composition target, clocks/pause/input edges, existing generation refs, world queries, resource adoption and SCM scheduling seams. Rehost existing player/vehicle presentation as a diagnostic baseline, explicitly retaining its current approximation label until replaced.

Gate: the same defined tick/input/resource schedule yields matching core traces headless and Godot-hosted; no Godot/RW pointers escape packet boundaries; scene teardown cancels consumers; presentation interpolation cannot mutate state. No silent dt dropping or invented universal60Hz conversion.

### P3 — First real playable vertical slice

Scope: source-informed ped tasks/collision/animation markers and camera, common vehicle/Automobile construction and handling/occupants, actual spawn→enter→drive→exit→destroy lifecycle, HUD/action input and basic SFX. Extract `CPhysical`/Automobile algorithms where source is implemented; perform focused RE for missing ped behavior.

Gate: normal input route crosses loaded world without losing collision; dynamic pair/contact and task interruption fixtures; source model/handling identities retained; actor pool lifetime and streaming eviction are coherent. A posed CJ or CPU Landstal packet alone does not pass. Do not postpone all mechanics until every visual effect is complete.

### P4 — True SCM boot, first mission and persistence loop

Parallel foundation from P2: corpus/schema manifest, complete necessary operand/thread forms, wait/stack/mission/streamed scheduling, stable prepare/pending/commit/cancel semantics and owner serialization contracts. Preserve current strict main53/mission1234/0814 and CPU539/0570 regression as history, not desired final boot.

Scope: implement real services demanded by the unmodified startup/first playable mission, including0814 ownership with separate registry/runtime coverage. Introduce a versioned portable save envelope early; never overwrite the original install/settings/saves. Include needed camera/text/audio/cutscene/cleanup behavior in this slice.

Gate: mission0 reaches its real wait/termination, main scheduling continues, fade clears and player control is live with no startup-incomplete/unsupported fault. Start the first source-reachable story mission through normal game state, fail/retry/complete it, then save/restart/load pre/post progression with matching semantic state. A debug mission launch or runtime exit1 is not completion.

### P5 — Whole-world entities and all vehicle classes

Scope: complete exterior/interior/path residency and dynamic world service; all source vehicle families and model constructors, water/rail/flight/towing/special control dependencies; general objects and destructible/damage state. Runtime LOD, time objects and interior visibility continue from P1, not the lab's radius/cap fallback.

Gate: catalog maps each shipped model to a real supported behavior/presentation path; construction/control/collision/occupants/damage/destruction/reload matrix for each class; no400/476 fallback representing all vehicles. Area switches preserve entity identity and matching render/physics generation.

### P6 — Population, AI, combat, police and recovery

Scope: owned path graph/search, task/event/scanner/group systems, traffic/population/spawn/removal rules, weapons/projectiles/fire/damage, wanted/pursuit/roadblocks, death/arrest/restarts, garages/properties/shops and related interactions. Bring required pieces forward into P4 when that route needs them rather than faking mission services.

Gate: normal-play scenarios cover source model/weapon/task classes, reproducible producer/event traces under the defined schedule, pool pressure/cleanup, pursuit→escape/death/arrest and subsequent playable recovery. Restart registration alone is not death/arrest recovery; parked-car definitions are not traffic.

### P7 — Complete presentation and platform families

Begins beside P3/P4, not only after P6. Scope: source skins/animation/cutscene poses, material family/MatFX/mips/alpha, camera modes/HUD/radar/map/frontend/settings, MAIN+mission GXT/fonts/substitutions, keyboard/mouse/controller/rumble, SFX/speech/environment audio/radio programming, weather regions/transitions/clouds/water/particles/shadows/reflections/post and source startup movies.

Gate: each discovered data/effect/event family has source-backed semantics and rendered/aural/device tests. Real Godot audio on target, explicit Dummy only for CI. In-memory source movie decoder needs actual codec/dependency/license evidence; extension support is possible, not assumed. No shader cosmetics/PBR/default physics used to cover import or algorithm gaps. Original visual profile and permitted differences remain explicit.

### P8 — Complete progression/content and save compatibility

Scope: expand P4's lifecycle and owner/persistence gates across all source mission/streamed/brain routes, side jobs, races, schools, minigames, activities, purchases, stats, rewards/unlocks, interiors and cutscenes. Inventory features such as cheats/replay/special script-driven states rather than silently omitting them. Complete original-PC save import/export as its own codec milestone; a port-native save is not that compatibility result.

Gate: every shipped command site/feature is classified; required reachable semantics, failure/retry/skip/cleanup and persistence routes run without unknown behavior. Full source save blocks/checksum/reference repair before compatibility claims. No mere enum-count percentage, mission-header count or fixture hash substitutes for progression E2E.

### P9 — Full-port closure and target release candidate

Scope: close outstanding coverage rows from all axes, not an unrelated optimization backlog. Perform long normal-play/route/reload/device/mission/save sessions on target; optimize measured CPU/GPU/IO stalls without changing source behavior. Preserve asset-free reproducible delivery and separate private-test/public-distribution licensing status.

Gate: no unresolved required behavior, fake readiness or original-runtime dependency; catalog/route/mission/save/effects gates green; no unbounded memory/resource growth; target thresholds and controlled reference differences reviewed. Full-game declaration requires this cross-axis closure, not P3 or P4 alone.

## Dependencies and next proposed coding round

```text
P0 -> P1 -> P2 -> P3
             |     +-> required owners for P4
             +-> SCM/schema/save foundation -> P4
P1/P3 -> P5 -> P6 -------> P8
P3/P4 -> P7 (parallel) --> P8
all accepted axes ------> P9
```

P4 and P6 are not a circular wait: identify and implement the minimal real owner subset required by the first mission, then broaden it in P6. The same rule applies to P7 UI/audio/cutscenes.

After approval, the first bounded round should close **P0**, not attempt all stages. Proposed five disjoint lanes: source-data diagnostics/reader policy; bridge publication validation; lab failure/coverage UI; regression fixtures/corpus itinerary; package/target evidence documentation. Parent fixes exact file ownership before launch, integrates, runs fresh gates and packages the result. Children never delegate; -j2 and one heavy rendered run at a time.

## Review decisions and recommended defaults

1. **Full means classic-PC functionality/content first**, including missions/save/audio/UI/side activities, with source-preserving Godot presentation. No difficult subsystem is declared out of scope. PS2 colour/effect parity is a named subsequent reference profile, not inferred from PC data.
2. **Native gameplay authority + Godot presentation**, with incremental extraction rather than a full rewrite or Godot physics substitution.
3. **NaN source-data policy:** initially preserve validation and old complete world, report the exact unavailable region/model; any per-primitive quarantine requires explicit compatibility approval and visible counters. Finite-large UV is a different, directly fixable validator defect.
4. **Early portable save, classic-PC compatibility later but still tracked**; no promise of source-save interoperability before complete codecs.
5. **No calendar promise from missing code bodies.** First estimate P0/P1 from concrete touched units and tests; estimate larger stages after their source-semantic gaps and dependent owners are enumerated.

## Constraints and change envelope

- Preserve legal assets read-only, native reference, source geometry/material/physics intent, exact unsupported/transaction boundaries and existing Windows/native isolation. No migration/index restoration/reset/clean or user configuration/cache commits. Runtime remains Linux native with no Wine/original EXE calls.
- Work as opencode in the existing rootless environment, `/workspace` and `/workspace/build`; no root-daemon interference. Do not read private keys. Both normal SSH origin pushes were successfully authorized and verified after the earlier HTTPS-only failures; do not perpetuate the old blanket publication-blocker claim.
- Current planning diff is docs only plus ignored diagnostic scripts/logs. Future implementation envelope is staged: Godot bridge/presentation, narrowly extracted native core/readers and relevant tests; shared upstream changes remain guarded and reviewed. No new dependency is accepted merely because a lane suggests it.

## Current checkpoint / review record

- RECON completed by five fresh lanes and parent verification. UV case reproduced at four non-Grove regions with Grove success control; source finite float independently verified. No product code changed and no fix is claimed.
- Delivered prior commits are present on both SSH origins: root52877f0, native8c62697b. Target user feedback is positive with a known flight regression; original/full-game parity remains open.
- Next implementation action is **not authorized by this document** until the user reviews the proposed stages/defaults. Keep this goal `draft`; the completed output of this round is the researched plan.
````
