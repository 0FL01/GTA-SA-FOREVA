# Live-test journal

Updated: 2026-09-11. [Readiness roadmap](PORT-READINESS.md) · [full chronology](goals/2026-09-08-linux-native-opengl-port.md)

## Entry contract

Each executed test records:

```text
ID / date / tester:
Commit SHA (both repos), dirty changes and binary/source identity:
Host / GPU / driver / compositor / resolution / input device:
Command, spawn/route, hour/weather, exact reproduction steps:
Expected source/original behavior:
Observed behavior:
Result: not-run | agent-image-reviewed | user-live-passed | failed
Automatic gates (separate from live result):
Evidence paths (application-only captures/logs/CSV):
Defect and fix commit / retest evidence / remaining limits:
```

No desktop-wide screenshots of unrelated applications. A software-rendered VDS result does not certify physical input, display latency, GPU performance or original-game visual parity. Keep private game assets and captures out of commits.

## Historical observations — accurately labelled, not retroactive user acceptance

| ID | Scenario and evidence | Observed result | Status / remaining retest |
|---|---|---|---|
| LIVE-001 | User reported missing world surfaces; streamed binary IPL + rotation fixes, baseline57b43fe4. `resized-world.png`, historical goal P3 | Detailed roads/buildings restored; actual Wayland/MangoHud window | Agent image review recorded; full-city / distance / LOD manual comparison still not-run |
| LIVE-002 | User reported curb/slope stopping and broken animations. Fixes02834a1e/8a099264; later source COL1015fd8f. Latest `./play.sh --demo-curb --seconds 12`, `radar-ipl-live-curb-host.log` | Source rise12.3828125→12.546875, grounded, blocked0; latest714 swaps/12.006s | Automatic replay passed; free-form user walking/sprinting/diagonal/landing retest not recorded |
| LIVE-003 | `./play.sh --player-cj --demo --seconds 28`, `radar-ipl-live-cj-host-2.log` and app-owned frames | Intact CJ white vest/jeans, enter/drive/brake/exit/walk;1645 swaps/28.017s;5 GL0/restored1 captures | Agent-image-reviewed; not a full manual gameplay/IK/vehicle parity pass |
| LIVE-004 | Source vehicle glass/material probes and actual app captures;9c585bee | Cabin/steering/seats visible through authored glass | Agent-image-reviewed; reflections, damage, mixed transparency and moving-camera comparison not-run |
| LIVE-005 | Fixed water/pier view, source scan and low-cloud probes/captures;1df5ce02/f7cb8383 | Real water texture/waves and low clouds presented; cloud pass differs from clear sky | Agent-image-reviewed; storm/underwater/wakes/reflections and original matched views not-run |
| LIVE-006 | `--play --new-game`; committed `radar-ipl-boundary-boot.log` | Five black08:00 frames honor source fade; main53, mission1219, strict016C@212309, runtimeexit1/fullboot0 | Historical bounded diagnostic, **not successful game boot**. Fresh remote1234/0814 evidence is CI-HL-01 below |

## Pending manual campaign

| ID | Required scenario | Platform / acceptance surface | State |
|---|---|---|---|
| MAN-01 | Free walking/sprint across curbs, ramps, diagonal walls, gaps; jump/fall/land and rapid input transitions | GPU host + real keyboard; pose continuity, foot placement, no penetration/sticking | not-run for final port |
| MAN-02 | Vehicle enter/exit at boundaries, acceleration/braking/reverse/turning, slopes/contact | GPU host; compare original handling/animations/physics, not just transmission arithmetic | not-run |
| MAN-03 | Long routes across LS/SF/LV, rapid camera turns and streaming boundaries | GPU host + CSV; missing surfaces/textures, LOD transitions, retained collision, tail stalls/memory | not-run |
| MAN-04 | Matched day/night/weather, glass/alpha layering, cloud/shore/ocean/underwater views | GPU host + legally owned original reference; same location/camera/time/weather | not-run |
| MAN-05 | Radar edges/rotation/resize, help text, prices, all HUD states and frontend navigation | GPU host + keyboard; geometry/text/readability and original behavior | partial automated coverage; manual not-run |
| MAN-06 | Original new-game → live world → missions → death/arrest/interiors → save/cancel/load | Requires systems not yet complete; no harness teleports or unknown-op no-ops | blocked by missing implementation |
| MAN-07 | Physical controller rumble, audio output and input/display latency | Local hardware; virtual/null devices do not close this scenario | not-run |
| CI-HL-01 | Remote fresh build, CPU/surfaceless gates, Weston headless/Wayland/MangoHud/app captures | nc-lab; software renderer/version and exclusions below, no GPU-FPS equivalence | agent-image-reviewed; final combined revalidation recorded below, no user-live acceptance |

Append actual sessions below; do not erase failed runs or replace these pending rows with assumed success.

## CI-HL-01 — 2026-09-11 / parent agent / nc-lab

- **Source identity:** incoming root `3847ab367f62a2989dd936f62b300ab649c31388`, native `3adc8ec02ee7e400c7245e67969adbef243e187d`, plus inherited five-lane WIP and closure fixes. Capture binary SHA256 `c46aa7d0d6bae154dc961fbcec299f442f3001513f74008205d3ed79b3b7a117`; this includes real `Realtime.cpp` with swap-only application readback, not a replacement gameplay implementation. Commit mapping is in the goal's remote-closure entry.
- **Environment:** host opencode UID1003, Debian13, rootless Docker; image `mad-sa:dev`/`91f7df6f5c32`, fresh GCC13.3 and Conan SDL3/3.4.14. Both game mounts read-only. No render-node: Mesa25.2.8 llvmpipe LLVM20.1.2, OpenGL4.5 Compatibility, Weston13 headless/pixman,1280×720, `LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2`. No physical input/audio/rumble tested.
- **Reproduction:** configure/build with shared Wayland+xkbcommon per README, run surfaceless gates first. In the container set `XDG_RUNTIME_DIR=/run/mad-sa-weston` (mode700), `WAYLAND_DISPLAY=wayland-nc-lab`, `SDL_VIDEODRIVER=wayland`, `EGL_PLATFORM=wayland`; launch `weston --backend=headless --renderer=pixman --width=1280 --height=720 --socket=wayland-nc-lab --idle-time=0 --no-config`. Build/run `RealtimeScriptBootProbe.py` and `NativeCarGeneratorPublicationProbe.py` with `--game-dir /game`; build `RealtimeHudCapture.py`, then `--run --player-cj --seconds 28`. MangoHud uses `--dlsym`, `autostart_log=1,log_duration=0,log_interval=100`.
- **Expected/observed diagnostic:** actual `--new-game` consumer reaches main53/mission1234,8 hospitals+7 police, terminal Unsupported0814@212669, previous016D@212645; five black08:00 frames, runtimeexit1/fullboot0. The wrapper passes because this is the expected strict stop; the game has **not completed boot**. CPU-no-HUD539/0570 stays a separate negative.
- **Observed replay:** default real-ground freeway spawn,12:00/EXTRASUNNY_LA; actual input path jump→land→enter Landstal→drive→brake→exit→walk. `play-ok swaps=244 seconds=28.042 sceneUpdates=2`, all four event counters1, drive91.14m. Three application frames (`0001`, `0043`, `0104`) inspected: intact white-vest/jeans CJ, textured freeway/buildings, vehicle, radar and advancing clock; car view then on-foot view. This is bounded image inspection, not original-game comparison. Pre-swap readbacks exclude the overlay.
- **Evidence:** `artifacts/build-runs/nc-lab-wayland-dlsym.log`, `nc-lab-wayland-boot.log`, `nc-lab-wayland-publication.log`, `nc-lab-wayland-capture.log`; `artifacts/graphics/realtime-hud-integrated-{0001,0043,0104}.png`; `RealtimeHudCapture_2026-09-11_13-25-19.csv` has265 positive-FPS samples with frametime data. These are ignored/private artifacts, not committed assets. Low software FPS is not a hardware-performance claim.
- **Failures and fixes, not hidden passes:** initial default Ubuntu archive requests timed out; signed mirror succeeded. Initial Wayland window creation hung inside Mesa→system Wayland mutex while SDL owned a static Conan display; shared Wayland alone exposed missing xkb symbols, both shared fixed init. First unbounded llvmpipe thread run missed the fifth08:00 clock check; two render threads passed unchanged assertions. Low-FPS demo attempted entry during the source landing task, then walked away; retrying ordinary interaction while waiting by the car fixed replay without bypassing landing/speed/collision checks. MangoHud without `--dlsym` produced no CSV; with it continuous logging passed. Initial sweep environment preselected null audio, changing the reported backend label; removing that external override restored33/0 without changing the sweep. Stale standalone runtime link lists were repaired, not their expectations.
- **Automatic checks:** final shared-dependency `artifacts/build-runs/nc-lab-closure.log` passes40/40 serial commands,5451 VM checks and sweep33/0. Final rebuilt Wayland boot also passes (`nc-lab-wayland-boot-final.log`); actual root `./play.sh --seconds 3 --player-cj` exits0 with26swaps/3.075s (`nc-lab-root-launcher.log`). Native source is committed as `22dee69e52564a52a54a948d463bdf47cfb3c4d0`; root companion contains this entry. MangoHud's headless sensor/GPU/X11 diagnostics remain in logs; they did not prevent swap logging. MAN-01–07 remain unresolved; no user-live-passed claim.
