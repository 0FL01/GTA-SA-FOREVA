# Goal: Godot SA Legacy Look Lab — Linux test demo

Status: complete — bounded runnable-lab delivery; original/target-GPU acceptance remains separate and unverified
Source: user instruction 2026-09-11, preserved verbatim in [chat request](2026-09-11-godot-legacy-look-lab-request.md).
Last updated: 2026-09-11
Predecessor: [native OpenGL goal](2026-09-08-linux-native-opengl-port.md).

## Objective

Deliver a runnable, asset-free Linux Godot lab for testing on the user's separate Fedora 44 / Wayland / Mesa / RX 780M host. Preserve San Andreas' visual language, not a PBR reinterpretation. Godot is the new project direction; this first milestone is a bounded visual lab, not full-game migration or original-game parity certification. Keep the working native backend as a regression reference. Full F1/F2 ambitions are retained beyond this milestone; the old unresolved R6 is not declared complete.

## Execution Directive

Complete the frozen Required Outcomes using the listed Change Envelope and Primary Evidence. Work on the smallest unresolved outcome. Do not add requirements from reviews, tests, tools, speculative risks, or optional source text. Finish when every required outcome is resolved and affected constraints remain satisfied. Parent owns integration and tests; five fresh stateless general children work in disjoint files and do not delegate. Do not replace missing behavior with no-op/Ready. Record external visual-reference/target-hardware evidence separately from locally verifiable delivery.

## Frozen Contract

### Required Outcomes

- G1: Durable new direction and visual contract.
  - Source: user opening instruction and quoted §§2,5–6.
  - Acceptance: verbatim chat archive, predecessor link, `docs/visual_contract.md` separating actual asset/reference provenance from artistic hypotheses and intentional differences.
  - Primary evidence: document/link and source-text review.
  - Status: verified
  - Evidence: current files; no original reference captures supplied in this request.
- G2: Verified standalone adapter, pinned Godot/C++ bindings.
  - Source: quoted §4 and assignment §6.
  - Acceptance: minimal GDExtension reads existing legal assets via native readers without original executable, Wine, absolute game addresses or dependency on the native GL window. Audit distinguishes standalone native slice from upstream hooked C++ code. Engine/bindings fixed to compatible release identities.
  - Primary evidence: fresh build, runtime load/no-exe trace, source dependency audit.
  - Status: verified
  - Evidence: fresh GCC13 PIC GDExtension build; explicit clean-project extension load; read-only no-exe trace; pinned4.6.1 engine/4.5 bindings actually render on Wayland.
- G3: Working Grove Street visual lab.
  - Source: user «жду демку рабочую для тестов», quoted §§3,5–6.
  - Acceptance: GPU-rendered district and distant context from source assets; texture/normal/UV/material/day-night color retention; distinct alpha handling; coherent data-driven environment at clear day/evening/night/overcast or rainy states. Fixed cameras and independently switchable texture/prelight/fog/post components. Import diagnostics precede artistic corrections. No requirement to implement traffic, missions or new physics in this milestone.
  - Primary evidence: attribute/data probes and reproducible rendered captures with camera, FOV, clock, weather, renderer and toggles recorded; known missing original effects explicit.
  - Status: verified
  - Evidence: final clean-package Wayland Forward+ captures in `artifacts/godot/delivery-final/`,4 source environments and9 component views; rendered Forward+/Compatibility grey/day-night/sky/alpha/post tests. Source material slots retained; remaining LOD/foliage/MatFX/mip differences explicitly documented, not certified original parity.
- G4: Motion and measurement harness.
  - Source: quoted §5 step4 and assignment acceptance.
  - Acceptance: repeatable camera route and environment transition, frame-time/memory/loading measurements over repeated passes, explicit residency/LOD differences; no screenshot-only parity claim. Comparable capture manifests and discrepancy list ready for original-reference comparison.
  - Primary evidence: route log/CSV, captures/manifests, bounded-residency checks. Target-GPU numbers must identify actual hardware and cannot be inferred from software rendering.
  - Status: verified
  - Evidence:794 frames/95.05 engine seconds/179.400331 wall seconds,3 completed passes,24 publications, cap256, source sectors21loaded/12evicted. Later-pass engine memory56.44–59.61MiB and non-growing pass ends. `godot-delivery-report-final.log` and GODOT-LAB-01 record monotonic intervals/stalls, actual software device and limits.
- G5: Linux test delivery and factual chronology.
  - Source: user Fedora44/Wayland/Mesa/RX780M test host instruction; retained milestone docs/commit/push instruction.
  - Acceptance: runnable asset-free demo package or reproducible build plus launcher, controls, diagnostics, required dependencies and external game-directory selection; tested local launch/error paths and explicit target-host test procedure. Update roadmap/journal, commit intended files, attempt push if authorized access available. Remote user acceptance remains not-run until supplied, not fabricated.
  - Primary evidence: clean staging-package launch with external read-only assets, no-exe/dependency check, docs and git identities.
  - Status: verified
  - Evidence: asset-free `artifacts/godot/package/`, pinned runtime/bindings, read-only no-exe trace and dependency audits; clean-package route/normal exit, launcher negative paths and target procedure. Native8c62697b plus root containing commit; HTTPS write authentication unavailable, native push failed explicitly. No target-host live pass claimed.

### Constraints and non-goals

- Original game directory is read-only, never copied/exported into the project, package or Docker image; no assets/executables/captures/cache/user `.opencode` configuration in Git. The lab reads the user's existing PC installation at runtime.
- Keep native root155b42f / native22dee69e control baseline intact; no migration helpers, index restore, hard reset, broad clean, SSH or root-daemon operations. Work as opencode; rootless `mad-sa:dev`, `/workspace` and existing `/workspace/build`; -j2, one heavy graphics run at a time.
- Preserve source geometry/normals/textures, no upscale/generated normal/roughness maps, no automatic PBR conversion or invented saturation/contrast compensation. Families retain separate meaning; diagnostic fixtures must be marked synthetic and never used as world substitutes.
- Godot owns presentation; native code owns authoritative game/data state. Do not replace SA vehicle behavior with VehicleBody3D or change simulation timing. Interactive existing mechanics follow visual validation, not new mechanics in this lab.
- Choose Forward+ as the initial target renderer; validate software Vulkan where available. Compatibility is explicitly separate evidence, not a visually interchangeable fallback. No full-state world node preload; preserve bounded publications and main-thread GPU ownership.
- PS2-oriented restoration is a working hypothesis, not a claim that PC bytes equal PS2 reference. Missing exact original capture/configuration is not permission to fabricate parity; complete independent runnable-lab work first. SkyGfx is reference only, not a hook library linked into runtime; respect licenses for any algorithm/code reuse.

## Change Envelope

- New root `godot/` project: pinned GDExtension build, minimal adapter over native reader sources, shaders, visual-lab scene/controller and tests. `tools/godot-*.sh` / `play-godot.sh` for reproducible delivery. Godot and godot-cpp downloaded into ignored dependency/build directories, never game-data conversions.
- Root docs: this goal and verbatim request, visual contract, standalone audit, lab README, readiness/handover/live journal and predecessor cross-link. Minimal native-reader additions only when a required preserved attribute cannot be obtained from existing APIs; retain legacy target isolation and numerical contracts.
- Build under `/workspace/build/godot-*` or ignored artifacts; logs/captures/packages under `artifacts/godot/`. Existing `/workspace/build/mad-sa-linux` remains available for regression.

## Current Checkpoint

- Closed: G1–G5 bounded district demo and delivery. Do not start a new feature round as part of this closure.
- User-host next evidence: run the packaged route on Fedora44/Wayland/Mesa/RX780M per `godot/README.md`; retain PNG/JSON/CSV and compare against controlled original captures when available. Those observations inform the next separately scoped migration decision.

## Current State

- Native baseline verified: 5451 VM checks,40 serial commands,sweep33/0, llvmpipe Wayland demo. Strict SCM frontier main53/mission1234,8 hospitals/7 police,Unsupported0814@212669; no full boot.
- New Godot runtime:4.6.1 Wayland/Vulkan Forward+ district delivery verified. Final long route exits0; nine held-frame captures agree with their manifests/UI. Forward+/Compatibility pixel oracles and real-data smoke pass; native additive reader rebuild and sweep33/0 pass. Fedora44 GPU host and exact original visual captures are not accessible from this server; they remain external acceptance, not invented results.
- Publication: previous HTTPS pushes failed missing username/write authentication; no credentials or SSH read. Preserve local commits.

## Material Decisions

- 2026-09-11: G3 material-boundary audit found equal-valued source material slots were merged after flattening. Add an optional model-local source slot identity to `WorldShotSurface`, assign it in `StreamPager`, and include it in adapter grouping. Native render arithmetic remains unchanged; fresh coherent build/sweep required.

- 2026-09-11: Reproduced Godot4.5 Wayland startup race (`wl_display_roundtrip_queue` concurrent dispatch; interleaved registry log). Upstream [GH-111493](https://github.com/godotengine/godot/pull/111493) fixes exactly this in4.6. Replace provisional engine pin with official4.6.1 `14d19694e0c88a3f9e82d899a0400f27a24c176e`; retain pinned4.5 GDExtension API/bindings and verify forward compatibility. No timing/debug-output workaround in delivery.

- 2026-09-11: G3 post toggle requires actual post data absent from the reader API. Minimal envelope expansion: additive optional timecyc tokens40–47 metadata in native `TimeCycle.{h,cpp}`, without changing existing row selection/output; bridge exposes PC byte-converted/interpolated passes. Implement only source PC `ColourFilter` additive two-pass operation, not invented PS2 grading/radiosity/heat haze. Native build/sweep must remain green.

- 2026-09-11: User explicitly changes primary direction to Godot. The quoted recommendation to defer that direction is superseded by the user's opening instruction; its bounded visual-first implementation order is adopted. Full F1/F2 are not silently reduced to a district viewer.
- 2026-09-11: First deliverable is a visual test lab; no automatic promise of complete PS2 parity or RX780M FPS without reference/hardware observations.

## Checkpoint History

- 2026-09-11: Contract opened from the new user request; previous WIP already committed and verified. Implementation not yet certified.
- 2026-09-11: Five fresh stateless lanes integrated by parent. Fixed engine Wayland startup, shader colour-space/alpha semantics, source optional metadata and clean-project extension discovery. `godot-closure-final.log` passes both pixel profiles, data contract/smoke, package route and native33/0. Image review then fixed capture synchronization/UI; final clean-package95s run + report pass. GDExtension SHA256 `ec67c60cc6061c662fa08a879949df8e8982a602c83e837b6318d8044692e98d`; final lab script `eba9df80e45d28633b6d87f225527b8f811a22cd37b7db58bf77209fe9f22e6c`. Journal GODOT-LAB-01 preserves failures, measurements and exclusions. Native metadata commit8c62697b; root delivery/docs in containing commit.

## Completion

- Personal test handoff: `artifacts/godot/sa-legacy-look-lab-linux-x86_64.tar.gz` (73,282,549 bytes), SHA256 `a908e464f0f3c1c02be7cf9efae19d073ab16e6ab3597659b915722aac9ba7dd`. Its21-file asset-free package was regenerated without runtime caches and checked against the final measured script/shader/extension hashes; archive listing contains only those project/runtime/notices files. Game data is not included. Extract into a new directory on the user's host and use its `play-godot.sh` per README.

- G1–G5 verified for the explicitly bounded runnable Linux lab, not full F1/F2/R6 or original graphical equivalence.
- Commands/artifacts: pinned fetch/build/package; `material_contract.gd`, `lab_smoke.gd`, rendered `material_render.gd` on both profiles; clean package95s Wayland route; read-only `strace`; native build/sweep33/0; launcher validation and both Git diff checks. Root whitespace check excludes only the verbatim request's seven original trailing spaces; they are preserved, not code/style regressions. Details/measurements in GODOT-LAB-01 and `godot/README.md`.
- Diff scope: root Godot project/tools/docs plus4 native additive metadata files; original assets remain external/read-only; no PBR/new physics/asset redistribution/user configuration/caches staged. Native backend retained.
- Decision: Godot is viable for continued legacy-shader presentation work with native data authority. Do not migrate gameplay yet on the strength of this district: first resolve measured LOD/foliage/sampling discrepancies and obtain target/reference comparisons in a new goal. Actual time/performance evidence is software-only; no person-week estimate or RX780M FPS is promoted to a result.
- Publication limitation: local commits are preserved; HTTPS push lacks write authentication. User live acceptance and original-reference comparison remain **not-run/unverified**, independently of delivered demo closure.
