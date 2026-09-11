# Godot full-port RECON — 2026-09-11

Status: research complete; implementation **not started**. [Draft plan for review](goals/2026-09-11-godot-full-port.md).
Snapshot: root `52877f01d422728f93ee009b3e01680cf6cb1de5`, native `8c62697b46f25f4a2d49d7e2d0bfcb46bb2719a7`.

## Method and evidence limits

Five fresh stateless general lanes examined disjoint subjects: UV/readers, world graphics, mechanics, SCM/persistence, and platform/UI/audio. Children did not delegate or change files. Parent verified critical source anchors and reproduced the UV failure using the existing binary. Only ignored diagnostic scripts/logs and repository documentation were written. No assets were copied, no runtime validation was changed, and no new feature build was performed.

The user reports the Godot demo looks good, with a failure outside Grove. Their supplied startup log identifies Godot4.6.1, Vulkan1.4.354, AMD Radeon780M/RADV PHOENIX. This is user-reported target launch and qualitative feedback, **not** a complete route/performance/original-parity pass. Earlier software measurements remain software-only.

## 1. UV failure: reproduced, not a GPU diagnosis

`godot/native/sa_legacy_bridge.cpp:138–143` combines two conditions into the same error: nonfinite UV, or absolute UV greater than1,000,000. It gives no model/material/triangle provenance.

UV0 originates in `geo->texCoords[0]`, is copied by `StreamPager.cpp:694,812–818`, then into placed meshes at `:1452,1505–1510`. An absent channel is explicitly zero-filled; null UV pointers are initialized by librw (`vendor/librw/src/geometry.cpp:38–47`). Missing UV alone does not explain this failure.

### Parent runtime reproduction

Existing extension, `open_game("/game",350.0,256)` followed by `load_region(center)`, headless Godot4.6.1, without changing any validator:

| Probe center, SA XYZ | Result |
|---|---|
| Grove `(2490,-1665,14)` | success |
| roads14_lan `(1532.054688,-1662.289063,12.460938)` | `pager UV is nonfinite or out of range` |
| SF radar `(-1687.414063,-623.023438,18.148438)` | same failure |
| LV radar `(1292.039063,1502.687500,14.710938)` | same failure |
| Countryside bridge `(2766.757813,364.953125,-4.492188)` | same failure |

Command, in the existing rootless container at `/workspace`:

```sh
build/godot-deps/godot-4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64 \
  --headless --path godot --script /workspace/artifacts/build-runs/godot-uv-recon.gd
```

Evidence: `artifacts/build-runs/godot-uv-recon.log` contains the five results and `uv-recon-complete (diagnostic only; validation unchanged)`. This reproduces the failure class without GPU rendering; the user's exact camera position was not supplied.

### Two distinct source cases

- The reader lane inspected15,008 DFF entries across the three archives. `roads14_lan.dff` contains four finite U values of26,906,820 or27,062,702 on referenced, nondegenerate textured triangles. Parent independently located its IMG directory entry and verified the original four bytes at `gta3.img` offset501036459: `0x4bce78d7`, float **27,062,702**. Evidence: `godot-uv-source-recon.py`/`.log` under ignored build-runs. No runtime uninitialized-memory hypothesis is needed to explain this model's finite value.
- The source scan also found referenced `0xffffffff` NaN UV pairs in `ap_smallradar1_sfse`, `smallradar02_lvs`, `cunterb01` and `cunterb03`. Runtime calls at their placements fail too. These are not equivalent to a missing UV channel or ordinary tiling. Exact original-renderer handling of these source defects was not established.

### Proposed fix boundary, not applied

1. Split error kinds and carry archive/model/geometry/material/triangle/value provenance from the producer. A failure must identify its source, not merely terminate the whole flight anonymously.
2. Remove the unsupported *magnitude* assumption for finite UVs only after a regression proves unchanged float32 publication/sampling. Keep finite checks, bounds, sizes, indices and allocation validation. Do not clamp to `[0,1]`, wrap coordinates on CPU, or replace them with zero.
3. Nonfinite UV needs a separately reviewed compatibility policy. Default recommendation: diagnose and reject the affected candidate publication while retaining the last complete world; do not crash the viewer or falsely publish Ready. A gameplay world must pause/block entry into unavailable collision coverage rather than let actors continue through missing terrain.
4. Per-primitive quarantine is a possible explicitly reported source-defect policy, **not an approved silent fix**. Before adopting it, preserve synchronized attributes, quantify affected content, examine original/reference behavior, and record the visual difference. Do not call skipped triangles faithful data retention.
5. Extend regression coverage beyond Grove: these four failure regions, absent UV, legitimate tiled/large UV, missing texture, malformed geometry and region replacement/close. Whole-map coverage comes from the placement catalog, not a few attractive screenshots.

Adjacent full-world issues are independent: native `triImg=-2` means missing/undecodable texture (`WorldShot.h:42–44`), but the bridge rejects `<-1`; librw count/chunk/short-read handling needs bounded structural checks before expanding corpus trust (`geometry.cpp:28–69,134–180`, `base.cpp:970–981`). No validation weakening is proposed.

## 2. What exists versus what still needs engineering

| Domain | Current portable or Godot foundation | Remaining substantive work |
|---|---|---|
| Godot integration | Four bridge calls, `StreamPager/TexSample/TimeCycle`, world alpha variants and PC filter | No gameplay/SCM/audio/frontend host in Godot; CMake closure is explicit at `godot/native/CMakeLists.txt:47–62` |
| World data/render | Source meshes, UV0, day/night, model-local material slots, level0 texture decode | Whole-map metadata, interiors, time objects, reusable model instances, source mip chains/UV sets/MatFX; current flattening and synchronous replacements are not final architecture |
| Streaming | Native sole parser worker, latest-request mailbox, active/pending/retiring ownership | Godot conversion/publication budget, cancellation and stale generations, TXD-qualified cache identity; no GL uploader reuse |
| LOD/collision | Authored `NativeLodCatalog`, COL readers, static queries, prepared source ground/live bounds | Runtime `LinkLods`, collision transfer, normal/big-building sectors, dynamic producers and ordering. Prepared graph/query fixtures are not consumed world authority |
| Player/mechanics | Bounded preview controller and CPU pose/collision helpers | General ped/player/tasks/events/physics. `CPed::ProcessControl` still calls the original address (`game_sa/Entity/Ped/Ped.cpp:3692–3694`) |
| Vehicles | Pool identities/lifecycle bookkeeping, car pose,400/476 CPU packets | General vehicle construction/world insertion, Automobile physics extraction, remaining bikes/flight/boats/trains/trailers/types, occupants, damage and cleanup |
| AI/population/combat | Reversed fragments, source tables, task/wanted structures | Owned path search, ped control, population/traffic, weapons/damage/police. Central upstream methods are still address-backed |
| SCM/missions | Native typed subset, instruction transactions, stable Pending/replay IDs, strict fault frontier | Complete operand schemas/thread lifecycle, source tick scheduler, real service owners, complete unmodified mission/streamed-script routes |
| Saves/progression | Source original save block layout and bounded native fixtures | Complete owner snapshots/reference relocation, durable clocks/RNG/thread state, atomic port saves and separately verified classic-PC compatibility |
| UI/input | Godot lab input/overlay; native GXT/font/menu/HUD references | Full frontend/HUD/map/settings, mission text/substitution, action remap/gamepad/hotplug/rumble; no parallel SDL platform owner |
| Audio/radio/video | Native PCM/Vorbis/source-container readers and some source scheduling tables | Real Godot output, spatial/event/loop lifetimes, speech/radio programming, streaming cursors, cutscene timing and source movie decoder. Lab launcher currently forces Dummy audio |
| Effects/environment | Timecycle subset, water/low-cloud CPU helpers, source PC filter | Complete weather regions/transitions, sky/clouds/water/particles/shadows/reflections/post; some algorithms remain unreversed |

Source anchors for the major world gaps: `StreamPager.cpp:240–291,665–839,1098–1144,1154–1289,1422–1543`; name-only image deduplication at `:1427,1463–1472`; `NativeLodCatalog.h:1–61`; source `FileLoader.cpp:1954–2024` and `Renderer.cpp:180–272,920–1066`. `RealtimeStreaming.h:23–103,131–271` is a CPU ownership design to adapt, not a Godot-ready uploader.

## 3. Authority and time: do not promote a preview into the full simulation

- Current `RealtimeGameplay::Tick` caps elapsed dt at0.1 and records dropped seconds (`RealtimeGameplay.cpp:1201–1225`). Its simplified controller cannot silently become source physics merely by hosting it in Godot.
- Preserve source subsystem cadence and ordering, not an arbitrary60Hz rewrite. Upstream order is observable at `Game.cpp:719–845`, `World.cpp:2166–2351`, `PedIntelligence.cpp:950–961`. Choose a tested portable timing contract based on source behavior; do not assume every original floating-point physics algorithm is independent of step partitioning.
- Godot owns input collection and presentation; the C++ core owns entities, timing, collision, tasks, SCM, progression and requested audio/camera effects. Renderer node deletion or animation interpolation must not mutate gameplay authority.
- Reuse existing generation-qualified pool references, request IDs and prepared transactions where their contract fits. Do not introduce a replacement ECS, universal plugin framework or broad public API before a real vertical slice requires it.
- Worker completion arrival order must not silently choose source simulation order. Record input, core tick schedule, RNG and resource adoption order. Replay claims apply to that defined schedule and numerical profile, not cross-platform bitwise physics by assumption.

## 4. SCM and the real boot boundary

Current native strict regression: main53/mission1234,8 hospitals/7 police, previous016D@212645, Unsupported0814@212669, exit1/fullboot0. CPU-no-HUD539/0570 is deliberately separate. See `RealtimeScriptBootProbe.py:60–87` and `RealtimeScriptHostProbe.py:74–85`.

The current VM allowlist has63 IDs; this is not a completion percentage. Executed instruction counts are not unique opcode coverage, and an enum's numeric range includes holes/aliases/unused commands. Track every shipped source command site by schema, semantics, owner, transaction, cleanup, persistence and executed-route coverage. The legal SCM's135 mission and79 streamed-script records are inventory entries, not135 completed story missions.

Upstream cannot simply be linked: `RunningScript.cpp:882–907` falls back to an original handler table; `TheScripts.h:351–465` contains address-backed state. Native instruction transactions are useful, but complete thread stacks, mission/streamed lifetimes, source waits and durable owner state remain missing. Native256-command-per-presented-frame behavior (`Realtime.cpp:923–930`) must not advance source-visible time halfway through one source scheduler pass; compare `TheScripts.cpp:1393–1448`.

**Parent correction to one lane recommendation:** `0814` is ADD_STUNT_JUMP. Source `StuntJumpManager.cpp:70–86` registers a record; runtime detection/reward is a separate `Update` at `:88+`. Correct registration into a real owned registry can complete the registration command without pretending the entire jump gameplay is done. Keep separate coverage states for registry, update/reward/camera/reset and save/load. Requiring all future consumers before acknowledging *every* registration command would invent a dependency; claiming a whole feature complete after registration would be equally wrong. Unknown semantics or discarded effects must never return fake Ready.

Persistence source has28 blocks (`GenericGameStorage.h:3–49`) and ABI/raw-pointer assumptions (`SimpleVariablesSaveStructure.h:9–72`, `TheScripts.cpp:1110–1368`). A portable versioned save envelope and original-PC import/export are distinct contracts; the latter stays on the full-port inventory, not silently dropped. Technical load failure should leave the current session intact; source mission failure commits its normal cleanup/retry, not a rollback of all gameplay history.

## 5. Platform and effects constraints

- `GxtText.cpp:77–243` offers MAIN-table parsing, not complete mission localization; formatting/control substitutions need source-aware tokenization (`Messages.cpp:433–529`). Source menus/HUD are references, not a framebuffer to permanently embed into Godot.
- `SfxDecode.h:1–58`, `RadioDecode.cpp:170–433` are decode foundations. A first-track OpenAL probe is not radio programming; `AERadioTrackManager.cpp:11–60,197–269` retains unreversed behavior. Audio sequencing stays authoritative; Godot provides output and device integration.
- `VideoPlayer.cpp:1–26,99–176` is DirectShow/COM, not Linux playback. Inventory source movie container/codecs read-only before selecting an in-memory decoder. Godot4.6 core video supports Ogg Theora, with extensions for other formats [2]; this is a dependency/codec task, not evidence that GTA movies are inherently unportable. No transcoded assets in the package.
- Godot's active SceneTree is not thread-safe; server threading has explicit configuration/ownership requirements and GPU calls can stall [1]. Initial port design keeps raw parser work off-thread and all Godot resource/tree publication on the main thread. Broader server threading is an optimization to prove, not a prerequisite.
- Unreversed examples remain actual RE work: `Ped.cpp:3692–3694`, `PathFind.cpp:29–78`, `Population.cpp:66–70`, `Fx/FxEmitterBP.cpp:109–176`, portions of shadows/mirrors/vehicle control. **Missing today does not mean impossible to port.** Runtime must never depend on the original executable; any future legal reference/reversal work stays development-only under repository constraints.
- The existing package is a private test handoff. Godot/librw notices do not automatically grant redistribution rights to all RE reader/adapter code; public distribution licensing is a separate unresolved item, not a reason to skip local functional work.

## 6. Review conclusions

1. Start with the reproduced source-data/world-publication failure, not new shader cosmetics.
2. Build a minimal portable core seam and world publication ownership, then put a small **real** player/vehicle/SCM interaction into Godot early. Do not wait for a perfect renderer to begin mechanics, and do not claim the preview controller is finished source mechanics.
3. Expand rendering, simulation and mission owners in connected vertical slices. Audio/UI/save lifecycle must accompany those slices, not be postponed until every mission already works.
4. Whole-map, full free-roam, complete progression, source visual behavior and packaging are separate acceptance axes. No one screenshot, opcode count or smoke test closes all of them.
5. No defensible full-port completion date or percentage follows from this reconnaissance. Extraction work and missing-algorithm RE have different uncertainty; estimate bounded stages only after their acceptance tests and source gaps are enumerated.

## Sources

Repository anchors above are pinned to the stated revisions. Parent diagnostic outputs remain ignored/private numeric evidence, not redistributed assets.

1. [Godot4.6 thread-safe APIs](https://docs.godotengine.org/en/4.6/tutorials/performance/thread_safe_apis.html).
2. [Godot4.6 video formats and extension boundary](https://docs.godotengine.org/en/4.6/tutorials/animation/playing_videos.html).
