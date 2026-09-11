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
