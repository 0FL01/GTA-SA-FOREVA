# nc-lab workspace handover

Prepared: 2026-09-11. Destination: `/home/opencode/ai/mad-sa`.
This is a **workspace/WIP handover**, not a successful remote game run or a completed full port.

Read first: `AGENTS.md`, `docs/PORT-READINESS.md`, `docs/LIVE-TEST-JOURNAL.md`, then the current section and latest entries of `docs/goals/2026-09-08-linux-native-opengl-port.md`.

## Repository and current work

- Two independent Git repositories. Source root base: `6421b01adbc7a6bf11083ed90560ff3f16e1b5c2`; native HEAD: `3adc8ec02ee7e400c7245e67969adbef243e187d`. Any later root documentation-only commit is recorded by Git/transfer metadata.
- Preserve all current unstaged/untracked work. In particular the five new families `NativeRestarts*`, `NativeWorldGround*`, `NativeVehicleAssetQueue*`, `NativeLiveEntityBounds*`, `NativeLodCatalog*`, plus changed Session/Host/VehiclePool/Streaming and parent CMake/probe integration.
- Current WIP child evidence: restart registration/selection1234 commands then0814@212669; same-worker400/476 CPU packets; native live-bound blockage; authored LOD graph. World-ground authority remains Unsupported for missing original bounds/model-wide LOD/order coverage. These are bounded findings, not full spawn/LOD/restart lifecycles.
- Parent added NativeRestarts.cpp to native CMake and updated strict frontier probes to1234/0814 with preceding016D@212645. `artifacts/graphics/round-final-core.log`: coherent product build and **5451 VM checks passed**. The subsequent combined gates were interrupted; final restart host/queue/bounds/ground/LOD/runtime closure and production commit/push remain to do. Do not assert old binaries/probes prove the final dirty tree.
- Last fully verified committed runtime: main53/mission1219/016C, five black08:00 frames, fullboot0; CJ1645 swaps/28.017s, curb714/12.006s, regression33/0. Historical evidence is local AMD780M/Mesa26.1.4, not this server.
- CPU-no-HUD negative539/0570@205876 remains intentional. Unknown commands/services stay terminal and unadvanced; expected exit1 is not full-boot success.
- Existing `.opencode/`, `opencode.jsonc`, root `e2e_W*.tga`, and native `__pycache__` are user/pre-existing state, not files to sweep into a feature commit. Host-specific tool paths may require explicit review before use; do not run copied automation blindly.

## Transfer scope / exclusions

Transfer keeps both `.git` histories (including librw submodule objects), code, dirty/untracked work, docs and permitted local evidence/build caches. Cache paths and binaries are preserved as historical state, **not portable build readiness**.

The game install `Grand-Theft-Auto-San-Andreas/` is **not transferred**, following the current `never edit/commit/copy` instruction. Raw game-format payloads outside that directory, environment/SSH material, local-only external symlinks, known unrelated desktop captures, and the transfer staging directory are excluded. The transfer manifest records the exact selection. Nothing is removed from the local workspace.

Consequently real-asset runtime/probes on nc-lab need a separately permitted legal asset provision first. Never download substitutes, commit game data, bake it into an image, or bypass the copy restriction by reconstructing assets from evidence.

## Observed server state (read-only RECON)

- Debian13.4, kernel6.12.86,6vCPU,11.68GiB RAM/~7.7GiB available,236GiB free disk.
- `opencode` UID/GID1003, home `/home/opencode`, linger enabled.
- Docker29.4.3 **rootless** context, socket `/run/user/1003/docker.sock`, store `/home/opencode/.local/share/docker`; no user containers running at RECON. Leave the17 existing root-daemon containers untouched.
- CPU quota/memory limits supported; cpuset and IO limits unavailable. Start around4CPU/6GiB and `-j2`; heavy GL gates one at a time. Five agents may work on disjoint source lanes, not five concurrent full GPU stress suites.
- QEMU/bochs VGA, no render-node; Mesa25.0.7 present. Use software llvmpipe, not a hardware-FPS claim.
- No `mad-sa:dev`, Weston or MangoHud verified installed. No server package/image changes were made during RECON. Current task only transfers the workspace.
- Read-only HTTPS Git access works. Root remote now exists (`0FL01/GTA-SA-FOREVA`); native is `0FL01/gta-reversed`. Observed remote HEADs6c4681d/0076f901 lag the local histories. Prior HTTPS push lacked authentication; current write authorization is unverified. Do not overwrite local history by resetting to those remote heads, force-push, read credentials, or rewrite remotes without cause.

## Next checkpoint

1. Check user, target path, transfer verification, both HEADs and dirty statuses. Do not start another feature round before closing current WIP.
2. Build the existing Ubuntu24.04 `mad-sa:dev` image under **opencode's rootless Docker**, preserving Conan SDL3/3.4.14, GCC13 and `/workspace`. Container root maps to host opencode; do not blindly carry over host `--user 1000:1000` commands.
3. Generate fresh Conan/CMake build paths rather than trust copied absolute caches. Preserve local evidence before replacing build outputs. Use `/game:ro` and, if a runner requires it, an additional read-only workspace game-path mount, only once assets are legitimately available.
4. Run smoke, the five new probes, actual restart Host/VM gates, affected pickup/feedback/coordinate/generator boundary gates, worker publication/shutdown and `tools/etalon-sweep.sh`. Record command, exit, source snapshot and backend. Source-ground arithmetic requires no-fast-math/FP contraction off. Do not disable tests or change expectations absent source evidence.
5. Validate EGL surfaceless first; then Weston headless + SDL Wayland + MangoHud with continuous `log_duration=0`. Read only app-owned framebuffer captures; overlay is excluded from pre-swap captures but CSV can verify logging. These remote gates have NOT yet been run.
6. Close the round, update readiness/live journal/chronology, commit explicit intended files in the appropriate repo, and push only with available authorized authentication. Nontrivial messages: `type(scope): description`, blank line, indented `Changes:` with2–4 bullets.
7. Continue F1/F2 via **five fresh stateless general children per round**, disjoint files, parent integration and verification. Children do not delegate. Do not call prepared asset/graph/census APIs completed original systems.

## Important next engineering dependencies

- WorldGround: original header/bounds for primitive-empty models and collision-dependent model-wide LinkLods effects; nearest local triangle is not authoritative world ground.
- LOD: current catalog is authored links only; no renderer/fixup completion.
- Queue: one waiting/running/ready vehicle slot on the existing exclusive parser worker; supported400/476 S0 only; CPU readiness is not GPU/world/pool insertion.
- Blockage: vehicles+peds only, source first8 XY candidates before Z; >8 unknown ordering remains Unsupported. Current native producer completeness is not full original traffic coverage.
- Restart:15 owned records and selection, not death/arrest recovery. Next reached SCM service is0814, not a license to bypass stunt-jump ownership.
- Keep a GPU host for manual playtests, real display/input/audio/rumble, vendor-driver behavior and performance. Software GL can check correctness, not certify all original-game parity.
