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
scene; it does not claim gameplay collision coverage. F6 explicitly retries the
rejected candidate. Ordinary retries near that center are suppressed.

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

Godot may create a local `.godot/` import cache after launch; it is runtime state,
not an input to republish. Re-run the package script to recreate a clean transfer
tree.

## Known differences, not hidden fixes

Only the bounded outdoor district is presented: no CJ/vehicle simulation, missions,
interiors or new physics. Source positions/normals/UV0/day-night colors and material
coefficients and model-local source material-slot boundaries reach ArrayMesh; secondary UV/MatFX, original
mip chains and renderer-specific flags are not yet carried by the reader boundary.
Source authored LOD selection is not implemented in Godot; overlapping detail/LOD
objects and vegetation sorting/edge aliasing remain visible discrepancies. Loading
and publication are synchronous and measured, not advertised as hitch-free streaming.
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
