# Native port readiness roadmap

Updated: 2026-09-11. **Full F1/F2/R6 remains active; the original game is not yet fully playable.**

Authority: [frozen goal and chronological evidence](goals/2026-09-08-linux-native-opengl-port.md).
Manual evidence: [live-test journal](LIVE-TEST-JOURNAL.md).
Current machine/worktree handoff: [remote handover](REMOTE-HANDOVER.md).

## Status rules

- **Integrated slice**: an actual native runtime consumer exists and the listed bounded checks passed. This does NOT mean full subsystem parity.
- **Prepared**: source/data/API/probes exist, but a required production consumer or authority is missing.
- **WIP**: local changes exist; the current combined build/runtime closure is incomplete.
- **Missing**: the original behavior is not implemented in native runtime.
- Keep automatic correctness, agent image inspection, user live testing, and original-game comparison separate. A green probe is not a manual playtest.
- Percentages are not acceptance criteria. Do not count opcodes, files, or passed smoke gates as percent of the full game.

## Snapshot by subsystem

| F1/F2 area | Current bounded readiness | Missing finish-line behavior / next evidence |
|---|---|---|
| Native platform / presentation | Fresh nc-lab GCC13/SDL3.4.14 build; surfaceless EGL and Weston13/Wayland/llvmpipe presentation, app captures and continuous MangoHud CSV verified | Shared Wayland+xkbcommon and MangoHud dlsym required on this stack; physical device/display and GPU-driver gates stay on a GPU host |
| World assets / streaming | Integrated IMG/DFF/TXD/text+binary IPL; corrected full instance flags; staged GPU upload and joined parser worker | Complete original residency, throughput/tail latency, transitions and model ownership |
| World collision | Integrated source COL triangles/spheres/boxes and paired render/query publications; source curb rise 0.1640625 m | Full original surface responses, dynamic entities, interiors and complete original-world query authority |
| LOD | **Prepared** `NativeLodCatalog`: 50,935 placements, 6,103 authored links; invalid catalogs cannot claim disk validation | Collision-dependent LinkLods fixups, model-wide effects and actual renderer consumption; unlinked binary runtime state remains Unknown, graph is not runtime LOD |
| Materials / lighting | Integrated prelight/day-night, source material coefficients, vehicle paint/shared textures and glass | Full original pipelines, reflections/specular, shadowing, transparency ordering, dynamic lights/damage |
| Weather / sky / water | Integrated fixed-weather low clouds, source water waves/flow, ocean floor and ordered sector scan | Weather evolution/boxes, remaining cloud/sun layers, reflections/refraction, foam/wakes and underwater effects |
| Player / animation | Integrated Andre/CJ preview, walking/running/jump/landing, wall sliding, source activity projection | Full TaskManager/events, combat, weapons, swimming, climbing, IK and original player lifecycle |
| Vehicles | Integrated preview Landstal controls/transmission; prepared immutable 400/476 S0 packets | Actual generated vehicle construction/world insertion, dynamic physics, suspension/adhesion, damage, aircraft/boat/bike behavior |
| Model jobs / blockage / ground | **Prepared** same-worker model mailbox (empty Ready rejected) and native live-bound census; source vertical primitives verified | Optional mailbox is not enabled by the production worker constructor. Wire retained demands to genuine model/ground/blockage/population/spawn/cleanup consumers. WorldGround stays Unsupported where header/LOD/order/coverage authority is missing |
| Generators / garages / ENEX | Integrated definitions, strict residency, paired door overrides, bounded update/access consumers | Actual spawning/destruction, original producer coverage, interior transitions, garage camera/movement/maintenance actions |
| HUD / interface | Integrated radar, clock, 62 source texture sprites, coordinate/contact rules, help and property prices | Full health/armour/weapon/wanted/money HUD, textureless traces, contact 3D markers, original font rasterization and frontend lifecycle |
| Pickups / save | Integrated save-token collection, generation-bearing ring and virtual pad feedback | Original PSAVE1 reachability, frontend, persistence serializer/load and other pickup/inventory effects |
| SCM / startup | Fresh integrated main53 / mission1234 / strict0814@212669, previous016D@212645; five black08:00 frames, runtimeexit1/fullboot0 | Real owner/consumer for the next operation, not opcode skipping. CPU-no-HUD539/0570 remains intentional; Unsupported is not successful boot |
| Restarts | **Integrated slice** 8 hospitals / 7 police and owned source selection; ordinary selection does not mutate one-shot revision | Actual death/arrest/resurrection/world/control/camera lifecycle remains missing |
| Population / missions / audio | Missing or isolated subsystem probes | Ped/traffic/police AI, ordinary missions, integrated game audio and a sustained original new-game boot |

## Ordered checkpoints — not a promise to batch unrelated changes

1. **Inherited WIP closure — verified.** Native `22dee69e` preserves the rsynced work and closes fresh build/read-only assets/five-lane/combined runtime checks:40/40 serial commands,5451 VM checks,33/0 sweep, headless Wayland/MangoHud and inspected app frames. No migration resumed; rootless only. Publication requires unavailable HTTPS authentication, not additional root permissions.
2. **Restart integration — verified bounded slice.** Actual main53 + mission1234,15 registrations, unadvanced0814@212669, preceding016D@212645; independent selection probes and CPU-negative539/0570 pass. Death/arrest remains missing. This stage is closed before another feature round.
3. **Finish generator demand consumers.** Owned model jobs → authoritative ground/live blockage/visibility/population → actual render/COL/physics/pool insertion and cleanup. CPU packet readiness is not a spawned vehicle.
4. **Continue genuine SCM boot.** Implement the next reached operation and its real owner/consumer; repeat until original startup runs rather than stopping at a strict frontier. Do not weaken the frontier checks merely to obtain exit0.
5. **Close remaining graphics and gameplay categories.** Use the subsystem table and source evidence; wire LOD and remaining effects, original actions, world AI, frontend/audio/save and mission systems.
6. **Manual parity campaign.** Run the journal scenarios on GPU hardware and compare against the legally owned original at matched location/time/weather/camera. Regressions found during live testing return to the relevant checkpoint.

## Evidence and update discipline

After each major stage update this table, append the factual result to the existing goal chronology, and add/update a journal entry. Record exact commit or **dirty/WIP**, backend/driver, command/route, observed behavior, artifacts, failures and next unresolved cause.

For manual observations distinguish `agent-image-reviewed`, `user-live-passed`, `failed`, and `not-run`. Never mark a pending manual scenario passed because a numeric oracle passed. Preserve failed evidence and source-proven reasons for any fixture changes.

Current coherent remote evidence: `artifacts/build-runs/nc-lab-closure.log` **40/40**, `nc-lab-sweep.log` **33/0**, `nc-lab-wayland-boot-final.log`, `nc-lab-wayland-dlsym.log`, `nc-lab-root-launcher.log`; native `22dee69e`. CI-HL-01 records source/binary identity and failures/fixes. Earlier `radar-ipl-*` logs remain local AMD history, not nc-lab performance.
