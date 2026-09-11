# Active goal: full standalone GTA:SA port hosted by Godot

Status: ACTIVE
Activated: 2026-09-11
Last updated: 2026-09-11
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
- The parent maintains automatic todos, assigns fresh general children disjoint file ownership, and forbids child delegation. After each parallel round the parent integrates and reviews the combined diff. After each major verified stage, commit and push only intended files and record the resulting hashes/evidence here.
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

### P1 - World/catalog and publication foundation (`pending`)

| Atom | State | Small deliverable | Decisive direct gate |
|---|---|---|---|
| P1-A01 | pending | Define TXD-lineage-aware model, texture, material and geometry identities in reusable immutable packets. | A same-name/different-lineage fixture resolves both textures/materials without collision. |
| P1-A02 | pending | Complete IDE/IPL metadata and parser bounds needed by the catalog without silent caps or fallback omissions. | Catalog fixture rejects malformed bounds and accounts for every expected placement. |
| P1-A03 | pending | Reproduce source `LinkLods` child/parent decisions for one authored chain. | One source-authored chain matches expected links and runtime selection reasons. |
| P1-A04 | pending | Couple that chain's COL relationship and generation to world publication. | A generation switch publishes matching render/collision lineage or publishes neither. |
| P1-A05 | pending | Adapt the sole-owner parser worker/mailbox for asynchronous raw parsing with request and generation identity. | Queue/parse cancellation test proves stale results cannot cross generations. |
| P1-A06 | pending | Budget Godot main-thread publication and retirement while retaining old complete state until commit. | Upload/retire interruption test shows bounded work and no mixed old/new generation. |
| P1-A07 | pending | Expand catalog-backed residency from the authored chain to the approved exterior itinerary and one interior, removing the lab's final `256`-instance visibility cap. | Revisit itinerary accounts for all expected placements and has bounded memory after repeated region/interior transitions. |

### P2 - Minimal portable authority hosted by Godot (`pending`)

| Atom | State | Small deliverable | Decisive direct gate |
|---|---|---|---|
| P2-A01 | pending | Extract the smallest portable C++ core composition target without SDL/GL/OpenAL monolith or address-backed `game_sa` linkage. | Dependency inspection and a headless startup fixture show no forbidden runtime authority. |
| P2-A02 | pending | Establish source-relevant clocks, pause state, timestep domains and RNG/tick profile. | Repeated defined schedule produces the same clock/RNG trace without silent dt dropping or universal `60Hz` conversion. |
| P2-A03 | pending | Translate device input into deterministic semantic commands with correct edge handling. | One press/hold/release trace matches between headless and Godot hosts. |
| P2-A04 | pending | Adopt world resources through existing generation refs and world-query boundaries. | Stale resource completion cannot mutate or satisfy a newer generation query. |
| P2-A05 | pending | Add committed snapshots, ordered presentation events and SCM scheduling seams without leaking Godot/RW pointers. | Boundary test serializes/inspects one tick and rejects presentation-owned pointers or mutation. |
| P2-A06 | pending | Rehost existing player/vehicle presentation only as an explicitly labelled diagnostic approximation with safe teardown/interpolation. | Matching headless/Godot trace survives scene teardown; interpolation changes presentation only and approximation is not reported complete. |

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

- Current stage: **P0 implementation verified, target reflight pending**. Next independent atom: **P1-A01** after the P0 source/evidence commit. Full-port finish line remains active and unresolved.
- P0 material-boundary finding resolved: `bussign1` material0 requests `chrome`, absent from valid `signs.txd` with no authored parent. Source TxdStore lookup returns null. Streamed presentation preserves its unbound material/prelight/UV, not manufactured texels or dropped triangles; the20-triangle source fixture passes. Legacy offline fallback is unchanged. Undecodable real rasters, missing primary TXDs and unresolved parent semantics stay rejected. Implementation/server gates pass; only the separate target reflight remains open.
- Conservative ambiguity resolution: nonfinite data fails the candidate region replacement with exact provenance while the last committed world remains live. Per-triangle quarantine is not approved. Finite-large values are valid and must be preserved exactly through the relevant numeric path, subject only to existing finite/size/index safety validation.
- Available P0 evidence: fresh coherent extension/native builds; `artifacts/godot/region-contract.log`, `region-render.log`; real `region_lab.gd` in CPU and clean rendered package; `artifacts/build-runs/p0-native-sweep.log`33/0 because shared mesh ABI changed. Package image `artifacts/godot/p0-lab-package/forward_plus-p0-retained-rejection.png` shows intact previous roads scene and explicit rejected radar status. Remaining external gate is P0-A04, not a claim that the full port is blocked from independent development.

## Checkpoint history

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
