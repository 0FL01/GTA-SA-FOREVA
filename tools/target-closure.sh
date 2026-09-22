#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
GAME=${1:-}
OUT=${2:-"$ROOT/artifacts/target-closure"}
RUNTIME="$ROOT/artifacts/godot/package/runtime/godot"
PROJECT="$ROOT/artifacts/godot/package/godot"

fail() { printf 'target-closure-fail %s\n' "$*" >&2; exit 1; }
[[ -d "$GAME" ]] || fail "usage: $0 /path/to/owned/game [output-dir]"
[[ -x "$RUNTIME" ]] || fail "clean package runtime is missing"
[[ -n "${WAYLAND_DISPLAY:-}" ]] || fail "WAYLAND_DISPLAY is required"

source /etc/os-release
[[ "${ID:-}" == fedora && "${VERSION_ID:-}" == 44 ]] ||
    fail "requires Fedora 44, got ${ID:-unknown} ${VERSION_ID:-unknown}"
command -v lspci >/dev/null || fail "lspci is required"
GPU=$(lspci | grep -Ei 'VGA|Display' || true)
grep -qiE 'Radeon.*780M|780M.*Radeon' <<<"$GPU" ||
    fail "requires the Radeon 780M target, got: $GPU"

mkdir -p "$OUT"
printf '%s\n' "$GPU" >"$OUT/gpu.txt"
printf 'os=%s %s\nwayland=%s\n' "$ID" "$VERSION_ID" "$WAYLAND_DISPLAY" >"$OUT/host.txt"
python3 "$ROOT/tools/godot-package-audit.py" | tee "$OUT/package-audit.log"

run_godot() {
    local name=$1 script=$2; shift 2
    /usr/bin/time -v -o "$OUT/$name.time" \
        "$RUNTIME" --path "$PROJECT" --display-driver wayland \
        --rendering-method forward_plus --script "$ROOT/$script" -- \
        --game-dir "$GAME" "$@" >"$OUT/$name.log" 2>&1
}

run_godot audio godot/tests/audio_families.gd --require-real-audio
grep -q 'audio-families-godot-ok' "$OUT/audio.log" || fail "real-audio marker missing"
grep -q 'target=1' "$OUT/audio.log" || fail "audio route used a Dummy/non-target driver"
run_godot materials godot/tests/material_render.gd
run_godot source-materials godot/tests/material_source.gd
run_godot frontend godot/tests/frontend_lifecycle.gd
run_godot poses godot/tests/pose_families.gd
run_godot catalog godot/tests/region_catalog.gd

/usr/bin/time -v -o "$OUT/mission.time" \
    "$ROOT/build/mad-sa-linux" --play --new-game --first-mission-gate \
    --game-dir "$GAME" --seconds 700 >"$OUT/mission.log" 2>&1
grep -q 'play-first-mission-gate-ok' "$OUT/mission.log" || fail "first-mission marker missing"

ZOMBIES=$(ps -eo stat= | awk '$1 ~ /^Z/ {n++} END {print n+0}')
[[ "$ZOMBIES" == 0 ]] || fail "zombies=$ZOMBIES"
printf 'target-closure-ok os=fedora44 gpu=radeon780m display=wayland audio=real mission=first package=asset-free zombies=0\n' |
    tee "$OUT/summary.log"
