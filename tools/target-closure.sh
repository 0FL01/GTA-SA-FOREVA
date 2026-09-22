#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
GAME=${1:-}
OUT=${2:-"$ROOT/artifacts/target-closure"}
PACKAGE="$ROOT/artifacts/godot/package"
RUNTIME="$ROOT/artifacts/godot/package/runtime/godot"
PROJECT="$ROOT/artifacts/godot/package/godot"
NATIVE="$ROOT/build/mad-sa-linux"

fail() { printf 'target-closure-fail %s\n' "$*" >&2; exit 1; }
[[ -d "$GAME" ]] || fail "usage: $0 /path/to/owned/game [output-dir]"
[[ -x "$RUNTIME" ]] || fail "clean package runtime is missing"
[[ -x "$NATIVE" ]] || fail "target-built native binary is missing"
[[ -n "${WAYLAND_DISPLAY:-}" ]] || fail "WAYLAND_DISPLAY is required"
[[ -S "${XDG_RUNTIME_DIR:-}/$WAYLAND_DISPLAY" ]] || fail "Wayland socket is missing"

source /etc/os-release
[[ "${ID:-}" == fedora && "${VERSION_ID:-}" == 44 ]] ||
    fail "requires Fedora 44, got ${ID:-unknown} ${VERSION_ID:-unknown}"
command -v lspci >/dev/null || fail "lspci is required"
command -v vulkaninfo >/dev/null || fail "vulkaninfo is required to identify RADV"
GPU=$(lspci | grep -Ei 'VGA|Display' || true)
grep -qiE 'Phoenix1|Radeon.*780M|780M.*Radeon' <<<"$GPU" ||
    fail "requires AMD Phoenix1/Radeon 780M PCI hardware, got: $GPU"
VULKAN=$(vulkaninfo --summary 2>&1) || fail "vulkaninfo cannot enumerate target GPU"
grep -qiE 'Radeon.*780M|780M.*Radeon' <<<"$VULKAN" ||
    fail "Vulkan did not identify Radeon 780M"
grep -qi 'radv' <<<"$VULKAN" || fail "Vulkan did not identify RADV"

# A native binary built in Ubuntu links libavformat/libavcodec.so.60 and is
# not a Fedora executable. Never bless extracted compat libraries via an
# environment override; build the native reference on Fedora against its own
# system FFmpeg and use the package separately for Godot.
[[ -z "${LD_LIBRARY_PATH:-}" ]] || fail "unset LD_LIBRARY_PATH; native target ABI must use system libraries"
NATIVE_LINKS=$(ldd "$NATIVE") || fail "native ELF dependencies could not be resolved"
! grep -qiE 'not found|wine' <<<"$NATIVE_LINKS" || fail "unresolved/Wine native dependency"
grep -q 'libavformat.so.62 => /\(usr/\)\?lib64/' <<<"$NATIVE_LINKS" ||
    fail "native reference requires Fedora FFmpeg libavformat.so.62; rebuild it on target"
grep -q 'libavcodec.so.62 => /\(usr/\)\?lib64/' <<<"$NATIVE_LINKS" ||
    fail "native reference requires Fedora FFmpeg libavcodec.so.62; rebuild it on target"

mkdir -p "$OUT"
printf '%s\n' "$GPU" >"$OUT/gpu.txt"
printf '%s\n' "$VULKAN" >"$OUT/vulkan.txt"
printf '%s\n' "$NATIVE_LINKS" >"$OUT/native-dependencies.txt"
printf 'os=%s %s\nwayland=%s\n' "$ID" "$VERSION_ID" "$WAYLAND_DISPLAY" >"$OUT/host.txt"
python3 "$ROOT/tools/godot-package-audit.py" "$PACKAGE" | tee "$OUT/package-audit.log"

run_godot() {
    local name=$1 script=$2 marker=$3; shift 3
    local status=0
    /usr/bin/time -v -o "$OUT/$name.time" timeout --signal=TERM --kill-after=10s 900s \
        "$RUNTIME" --path "$PROJECT" --display-driver wayland \
        --rendering-method forward_plus --script "$ROOT/$script" -- \
        --game-dir "$GAME" "$@" >"$OUT/$name.log" 2>&1 || status=$?
    printf '%d\n' "$status" >"$OUT/$name.exit"
    [[ "$status" == 0 ]] || fail "$name exited $status (even if a marker was printed); see $OUT/$name.log"
    grep -qF "$marker" "$OUT/$name.log" || fail "$name success marker is missing"
}

run_godot audio godot/tests/audio_families.gd audio-families-godot-ok --require-real-audio
grep -q 'target=1' "$OUT/audio.log" || fail "audio route used a Dummy/non-target driver"
run_godot materials godot/tests/material_render.gd material-render-ok
run_godot source-materials godot/tests/material_source.gd material-source-godot-ok
run_godot frontend godot/tests/frontend_lifecycle.gd frontend-lifecycle-godot-ok
run_godot poses godot/tests/pose_families.gd pose-families-godot-ok
run_godot catalog godot/tests/region_catalog.gd region-catalog-ok --catalog-route
grep -qF 'visible-gt256' "$OUT/catalog.log" || fail "catalog capless route missing"
# A successful marker followed by a Wayland/Futex teardown hang is not an exit0.
# Repeat the small route independently; keep every exit status and timing log.
for attempt in 1 2 3; do
    run_godot "wayland-exit-$attempt" godot/tests/frontend_lifecycle.gd frontend-lifecycle-godot-ok
done

status=0
/usr/bin/time -v -o "$OUT/mission.time" timeout --signal=TERM --kill-after=10s 1300s \
    "$NATIVE" --play --new-game --first-mission-gate --probe-source-cj-pixels \
    --profile-frame-stages --game-dir "$GAME" --seconds 700 >"$OUT/mission.log" 2>&1 || status=$?
printf '%d\n' "$status" >"$OUT/mission.exit"
[[ "$status" == 0 ]] || fail "mission exited $status; see $OUT/mission.log"
grep -q 'play-first-mission-gate-ok' "$OUT/mission.log" || fail "first-mission marker missing"
grep -q 'play-source-cj-pixels changed=' "$OUT/mission.log" || fail "source player pixel evidence missing"
grep -q 'play-stage-ms' "$OUT/mission.log" || fail "frame-stage timing evidence missing"

ZOMBIES=$(ps -eo stat= | awk '$1 ~ /^Z/ {n++} END {print n+0}')
[[ "$ZOMBIES" == 0 ]] || fail "zombies=$ZOMBIES"
printf 'target-closure-ok os=fedora44 gpu=radeon780m display=wayland audio=real mission=first package=asset-free zombies=0\n' |
    tee "$OUT/summary.log"
