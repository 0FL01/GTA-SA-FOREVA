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

Preset `4` uses the source `CLOUDY_LA` overcast state. `RAINY_LA` does not exist;
it is not aliased to an invented rainy-LA environment.

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
separate. `sa_core` is not linked into `libsa_legacy.so` yet.

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
