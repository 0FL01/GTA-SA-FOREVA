# mad-sa
Personal RE research workspace for GTA:SA 1.0 US: upstream-model reverse (gta-reversed fork) + native Linux standalone track. Wine is dev-reference only, never runtime.
Primary direction is the full standalone Godot port, developed from the legacy-look lab; preserve the native backend as a regression reference, not a completed full game.

## Map
- `godot/` — Godot presentation/GDExtension lab; `godot/README.md` has pinned fetch/build/package/test commands. Authoritative readers remain C++; no PBR/physics replacement.
- `Grand-Theft-Auto-San-Andreas/` — legally owned game install, read-only, never edit/commit/copy
- `gta-reversed/` — fork of `gta-reversed/gta-reversed`, independent git repo (own remote), many commits ahead of upstream master
- `gta-reversed/source/game_sa/` — game logic being reversed (upstream DLL-hook model)
- `gta-reversed/source/app/platform/linux/` — native track: standalone `main` (`MainLinux.cpp`) + subsystem harnesses (`--smoke*`, `--headless`, `--shot`, `--shot-scene`, `--shot-menu`, `--menu-nav`, `--e2e`, `--smoke-audio-real`, `--hour`, `--show-zone`, …)
- `gta-reversed/source/oswrapper/oswrapper_linux.cpp` — Linux OS abstraction (SDL3 video/input, OpenAL, `OS_File*` IO); `oswrapper_win.cpp` stays upstream reference
- `gta-reversed/vendor/librw` — RW→GL rendering vendored for the native track
- `Dockerfile` — dev image `mad-sa:dev` (Ubuntu 24.04: GCC13/Clang, CMake/Ninja, Conan2, OpenAL/GL/SDL3-sysdeps, wine64+mingw, lief/capstone/pefile; GUI RE on host)
- `tools/etalon-sweep.sh` — full gate sweep inside container (hardcoded `/workspace` paths)
- `artifacts/` — git-ignored run outputs (build logs, `.tga`, one-off probes); keep root free of loose run files
- `docs/goals/` — active objective contract + per-round evidence log

## Rules
- Upstream is MSVC Win32 x86 only (`gta-reversed/conanprofile.txt`: `msvc/x86/Windows`); Linux native is a separate track (`librw + SDL3 + OpenAL`); shared code behind platform guards, upstream DLL build must stay green.
- Exe scoping: upstream DLL track requires Compact 1.0 US exe `5189632` bytes — mismatch = random crashes. Local `gta-sa.exe` is `5971456` (retail 1.0 US): expected on this machine, not an error. The native Linux track never reads the exe — it parses assets directly (`IMG/DFF/TXD/GXT/dat` via `OS_File*`). Do not "fix" the size mismatch and never document acquisition paths for exes/patches.
- Edits inside `gta-reversed/` follow its `docs/CodingGuidelines.md` (`StaticRef<addr>`, `notsa::bugfixes`, `assert` over silent return).
- Dev env is `Dockerfile` (`mad-sa:dev`); do not add VS/Windows-only steps to Linux build path. Game mounts at `/game:ro`, never copied into image.
- Requires a legally owned game copy: no assets/exes in commits, no redistribution, no piracy instructions (see root `README.md`, Legal scope).

## Execution workers
- `@cheap-worker` is default for well-specified/verifiable implementation/test/docs; `@costly-worker` only for ambiguous semantic/architectural/RE/debug decisions.
- No fixed worker count: number matches genuinely independent atoms with disjoint file ownership; children do not delegate.
- Parent integrates/verifies/records evidence; commit+push after substantial verified rounds.
- Single roadmap: `docs/PORT-READINESS.md`; atom ledger/backup in `docs/goals/2026-09-11-godot-full-port.md`; no competing roadmap.
- Do not read/modify/stage `.opencode/opencode.jsonc`, `*.tga`, or caches (`__pycache__`, etc.).

## Commit style
- Format non-trivial commits as `<type>(<scope>): <description>`, then a blank line and an indented `Changes:` list with 2–4 concrete bullets; use `feat`, `fix`, `chore`, `docs`, `refactor`, or `test`.
- Do not use a bare one-line message for non-trivial changes; the message must explain the change without requiring the diff.

## Verify
- `tools/godot-build.sh` / `tools/godot-package.sh` — asset-free Godot delivery; run rendered pixel tests and clean-package route per `godot/README.md`, not just headless import. Game data stays external/read-only.
- `./build/mad-sa-linux --smoke` — minimal native gate (exit 0 + `smoke-ok`); full sweep: `tools/etalon-sweep.sh` inside container
- `file build/mad-sa-linux` — ELF 64-bit x86-64; `ldd build/mad-sa-linux` — no wine/Win libs
- `git -C gta-reversed log --oneline -5` — confirm RE base before port work
- `docker build -t mad-sa:dev .` — after any `Dockerfile` change
- `stat -c %s Grand-Theft-Auto-San-Andreas/gta-sa.exe` — `5971456` expected locally; `5189632` required only for upstream DLL-track runs
- Windows-only reference build: `python gta-reversed/setup.py`, `cmake --build build`

## Docs
- `docs/goals/2026-09-11-godot-full-port.md` — active goal, immutable plan backup and atom ledger; `docs/PORT-READINESS.md` is the single roadmap. `docs/visual_contract.md` separates restoration intent from unverified original/GPU parity.
- `README.md` — project purpose, legal scope, build/run, gate table
- `docs/goals/2026-09-08-linux-native-opengl-port.md` — frozen contract R1–R6 + evidence
- `gta-reversed/README.md` — upstream build + ASI-loader model + native Linux track section
- `gta-reversed/docs/CodingGuidelines.md` — mandatory style for RE contributions
- `gta-reversed/docs/ReversedClasses.md` — what is already reversed
