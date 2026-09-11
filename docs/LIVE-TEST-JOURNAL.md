# Live-test journal

Updated: 2026-09-11. [Readiness roadmap](PORT-READINESS.md) · [full chronology](goals/2026-09-08-linux-native-opengl-port.md)

## Entry contract

Each executed test records:

```text
ID / date / tester:
Commit SHA (both repos), dirty changes or snapshot manifest:
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
| LIVE-006 | `--play --new-game`; committed `radar-ipl-boundary-boot.log` | Five black08:00 frames honor source fade; main53, mission1219, strict016C@212309, runtimeexit1/fullboot0 | Expected bounded diagnostic, **not successful game boot**. Restart-WIP1234/0814 has no final live closure yet |

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
| CI-HL-01 | Remote fresh build, CPU/surfaceless gates, Weston headless/Wayland/MangoHud/app captures | nc-lab; record software renderer/version and exclusions, no GPU-FPS equivalence | not-run; image/assets not prepared |

Append actual sessions below; do not erase failed runs or replace these pending rows with assumed success.
