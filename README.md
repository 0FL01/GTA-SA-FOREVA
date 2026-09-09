# mad-sa — GTA: San Andreas reverse-engineering research workspace

Personal research project built around [gta-reversed](https://github.com/gta-reversed/gta-reversed)
— a community effort to reverse and rewrite every GTA: San Andreas function. This
workspace keeps a fork of it and develops a **native Linux port**: a faithful,
source-level reconstruction of GTA:SA 1.0 US whose logic can be studied, modified
and rebuilt from source instead of binary patches.

## Legal scope (read first)

- A legally obtained copy of GTA: San Andreas is **required** to run anything here.
  Nothing in this repository helps obtain the game, its executable or its assets.
- The game installation is used strictly **read-only** (mounted at `/game:ro`).
  Game binaries and assets are never committed, never copied into build images,
  never redistributed.
- Not affiliated with Rockstar Games or Take-Two; all trademarks belong to their
  owners. Same research/interoperability model as the upstream gta-reversed project.
- Produced executables are useless without your own game assets — by design.

## Repository map

| Path | What it is |
|---|---|
| `gta-reversed/` | Fork of gta-reversed (independent git repo with its own remote). Upstream = MSVC/Win32 DLL injected via ASI loader; this fork adds the **native Linux track**: `source/app/platform/linux/` (standalone `main` + subsystem harnesses), `oswrapper_linux.cpp`, `vendor/librw`. |
| `Grand-Theft-Auto-San-Andreas/` | Local, legally owned game installation. Read-only; git-ignored. |
| `Dockerfile` | Dev image `mad-sa:dev` (Ubuntu 24.04: GCC13/Clang, CMake/Ninja, Conan2, OpenAL/GL, SDL3 build deps). |
| `docs/goals/` | Frozen objective contract + per-round evidence log for the active goal. |
| `tools/` | Verification scripts. `etalon-sweep.sh` runs every gate in one container pass. |
| `artifacts/` | Git-ignored run outputs: build logs, `.tga` screenshots, one-off probes. Keep repo root free of loose run files. |
| `AGENTS.md` | Working conventions and verify commands for AI coding agents. |

## Build & run

### Native Linux standalone (active track)

Development happens in the `mad-sa:dev` container; `/workspace` is this repo,
`/game` is the read-only game install.

```bash
docker build -t mad-sa:dev .            # after any Dockerfile change
docker run --rm -it \
  -v "$PWD":/workspace \
  -v "$PWD/Grand-Theft-Auto-San-Andreas":/game:ro \
  -v mad-sa-conan:/opt/conan \
  mad-sa:dev bash
```

In-container build (SDL3 via Conan, then CMake):

```bash
conan install --requires=sdl/3.4.14 -o 'sdl/*:pulseaudio=False' \
      -of build-conan -g CMakeDeps -g CMakeToolchain --build=missing
cmake -S gta-reversed -B build -DGTASA_BUILD_LEGACY=OFF \
      -DCMAKE_TOOLCHAIN_FILE=/workspace/build-conan/conan_toolchain.cmake \
      -DCMAKE_BUILD_TYPE=Release
cmake --build build --target mad-sa-linux
file build/mad-sa-linux                 # ELF 64-bit, x86-64
./build/mad-sa-linux --smoke            # first gate
```

Result: `build/mad-sa-linux`, an x86_64 ELF that links **no Wine / Win libraries**
(check with `ldd`). The native track reads game assets directly (`IMG/DFF/TXD/
GXT/dat` via `OS_File*`) and never touches `gta-sa.exe`.

### Interactive OpenGL + Wayland + MangoHud

After building in the container, run **on the host Wayland desktop**:

```bash
./play.sh                       # on-foot / nearby Landstal, until Esc / close
./play.sh --demo --seconds 35   # jump, enter, drive, brake, exit, walk
./play.sh --demo-curb --seconds 12 # real 17 cm street curb, walk/sprint up/down
./play.sh --freecam              # original flying world viewer
./play.sh --freecam --hour 22 --weather CLOUDY_LA --freeze-time
```

Requires host Mesa/OpenGL, OpenAL, Vorbis runtime libraries and `mangohud`.
The launcher forces SDL's **Wayland** driver (no XWayland fallback). The ELF
creates an SDL3 OpenGL window and EGL context, draws DFF triangles with TXD
textures on the GPU, and calls `SDL_GL_SwapWindow` every frame. Vsync plus a
60 Hz timer prevents an unpaced batch loop. It logs the actual video driver,
GL renderer, drawable size, completed swaps and measured frame rate.

**Controls:** WASD walk/drive, arrows orbit, left Shift sprint, Space jump or
handbrake, left Ctrl brake, F enter/exit a nearby stationary vehicle, Tab toggle
free camera (Q/E down/up, Shift fast), Esc exit. Resize is supported.
`--cam x,y,z` selects the initial location (in gameplay, z is the ground-ray
ceiling). `--hour` accepts fractional hours in [0,24); the timecycle advances
one game minute per real second unless `--freeze-time` is supplied.

This is an **interactive gameplay slice, not full San Andreas parity**. A real
skinned `andre` with four IFP clips and a real Landstal persist across ticks;
movement, jumping/landing, collision blocking, entering/driving/exiting and a
collision-aware third-person camera operate in the same loop as rendering.
The on-foot controller sweeps five overlapping spheres against actual triangles:
curbs up to 26 cm and supported descents up to 30 cm retain ground contact;
larger ledges, steep walls and inadequate headroom remain blocking. Walk/run
keep a distance-driven animation phase and blend to idle/fall without resetting
the foot cycle. The targeted terrain probe also checks ramps, gaps and ceilings.
Collision uses a BVH of loaded render triangles, not the original COL flags;
the transmission now uses source-derived handling conversion, gears and inertia
at the original default 30 Hz simulation cadence. Tire adhesion, suspension and
per-wheel braking remain simplified, and entering has no door/seat animation.
The live radar uses all 144 original map tiles, camera-relative player/north
markers and original HUD disc; the clock uses the authored Pricedown atlas and
game time. Modular CJ, mission boot, traffic, combat, remaining HUD/menu/save
systems and other gameplay integration remain unfinished.
`--drive`, `--walk` and screenshot modes remain deterministic offline harnesses.

Unlike those small fixtures, `--play` indexes both text IPL and the binary
streamed IPL inside IMG: the latter contain most of the detailed buildings and
ground. Its resident window is bounded to 900 m / 4096 nearest instances. No
synthetic ground fills missing assets. Distant LOD rendering is not yet present.
Pager/BVH rebuilding now runs on one exclusive worker; texture/list upload and
retirement are spread across main-thread frames. Render and collision snapshots
publish together before physics. The 4 ms GPU budget is soft: measured live
streaming runs at 45–56 FPS versus ~60 steady, with scene publication taking
several seconds; this is not a hard latency guarantee or full-map residency.
The renderer now carries authored day/night prelight, material coefficients
and car paint colors into a GLSL 1.20 pipeline, interpolates `timecyc.dat`
sky/lighting/fog and draws real `water.dat` triangles. Shared `vehicle.txd`
textures now resolve in the original common-before-model order. Vehicle damage
transitions/specular/reflections, water textures/waves/reflections, shadows and full original effects are still
missing; sky and water are not a claim of complete visual equivalence.
Vehicle glass now uses authored material/texture alpha: opaque components render
first, translucent triangles render back-to-front with depth testing/writing.
Triangle sorting is a native substitute for the original atomic/component
heuristic, not full vehicle-material parity.
The starting car now selects intact near-detail components instead of drawing
damaged parts and VLO on top of them. On-foot diagonal contacts slide along
the actual contact plane; animation follows total accepted Tick displacement,
including curb/ramp traversal and downhill guardrail contact.

MangoHud is a runtime overlay, not a build dependency. The launcher records CSV
under `artifacts/graphics/`. It uses continuous logging (`log_duration=0`): the
host's MangoHud package crashes in its post-log benchmark panel with a finite
log duration. Do not stop logging manually on that version. Override
`MANGOHUD_CONFIG` to customize the HUD. See [MangoHud's configuration docs](https://github.com/flightlessmango/MangoHud).

Without MangoHud, the same graphics path can be run directly:

```bash
SDL_VIDEODRIVER=wayland ./build/mad-sa-linux --play \
  --game-dir "$PWD/Grand-Theft-Auto-San-Andreas"
```

Keep the Conan volume between container builds: generated CMake files refer to
absolute paths inside `/opt/conan`. If using a new cache, rerun `conan install`
and the CMake configure step before building.

### Upstream Windows DLL (reference track)

MSVC + Conan, exactly per `gta-reversed/README.md` (`python setup.py`,
`cmake --build build`). That track requires the **compact 1.0 US exe**
(5,189,632 bytes); this machine's local copy is the retail US 1.0 exe
(5,971,456 bytes) — see the exe note in `AGENTS.md`.

## Verification gates

The standalone binary self-verifies each subsystem: every gate exits 0 and prints
its `*-ok` marker (failures print `*-fail` and exit 1, no synthetic success).

| Command | Gate |
|---|---|
| `--smoke` | process boots, logic ticks |
| `SDL_VIDEODRIVER=dummy … --smoke-video` | SDL3 video + event loop |
| `--headless --ticks 600` | loads `data/*.dat` from `/game`, ticks N frames |
| `--smoke-audio` | OpenAL init (null-sink fallback allowed) |
| `--smoke-audio-real --bank GENRL --samples 16` | real SFX bank decode |
| `--shot out.tga --frames 120` | single-model textured render from real DFF/TXD |
| `--shot-scene scene.tga` | multi-instance scene from IDE/IPL |
| `--shot-menu menu.tga --lang english` | GXT text + font rendering, menu frame |
| `--menu-nav down,enter --out nav.tga` | input → state → frame closed loop |
| `--e2e --path X --waypoints N` | streaming pager walk through live world |
| `tools/etalon-sweep.sh` | all gates in one run (inside container, `/workspace` paths) |

## Documentation index

- `AGENTS.md` — repo conventions, exe-size scoping, verify commands.
- `docs/goals/2026-09-08-linux-native-opengl-port.md` — active objective: frozen
  contract R1–R6, status, evidence per round.
- `gta-reversed/README.md` — upstream build + ASI-loader model, plus the native
  Linux track section for this fork.
- `gta-reversed/docs/CodingGuidelines.md` — mandatory style for RE contributions.
- `gta-reversed/docs/ReversedClasses.md` — reverse-engineering progress.
