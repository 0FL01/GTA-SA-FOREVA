#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
readonly PROJECT_DIR="$ROOT/godot"
readonly LOG_DIR="$ROOT/artifacts/godot"
readonly REPO_RUNTIME="$ROOT/build/godot-deps/godot-4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64"
readonly PACKAGE_RUNTIME="$ROOT/runtime/godot"

usage() {
    printf 'Usage: %s {cpu|render} --game-dir PATH\n' "$0"
}

fail() {
    printf 'godot-region-test: %s\n' "$*" >&2
    exit 2
}

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
    usage
    exit 0
fi
[[ $# -eq 3 && "$2" == --game-dir ]] || { usage >&2; exit 2; }

readonly profile="$1"
readonly game_dir="$3"
[[ -d "$game_dir" ]] || fail "game directory does not exist: $game_dir"
readonly game_real="$(realpath -e -- "$game_dir")"
log_real="$(realpath -m -- "$LOG_DIR")"
[[ "$log_real" != "$game_real" && "$log_real" != "$game_real/"* ]] \
    || fail "test logs must stay outside the read-only game installation"

if [[ -n "${GODOT_BIN:-}" ]]; then
    godot_bin="$GODOT_BIN"
elif [[ -x "$PACKAGE_RUNTIME" ]]; then
    godot_bin="$PACKAGE_RUNTIME"
else
    godot_bin="$REPO_RUNTIME"
fi
[[ -x "$godot_bin" ]] \
    || fail "Godot executable not found; set GODOT_BIN or run tools/godot-fetch.sh"

case "$profile" in
    cpu)
        script="res://tests/region_contract.gd"
        marker="region-contract-ok"
        log="$LOG_DIR/region-contract.log"
        engine_args=(--headless)
        ;;
    render)
        [[ -n "${XDG_RUNTIME_DIR:-}" && -n "${WAYLAND_DISPLAY:-}" ]] \
            || fail "render requires XDG_RUNTIME_DIR and WAYLAND_DISPLAY"
        script="res://tests/region_render.gd"
        marker="region-render-ok"
        log="$LOG_DIR/region-render.log"
        engine_args=(--display-driver wayland --rendering-method forward_plus \
            --rendering-driver vulkan --audio-driver Dummy)
        ;;
    *)
        fail "profile must be 'cpu' or 'render'"
        ;;
esac
[[ -f "$PROJECT_DIR/${script#res://}" ]] || fail "test script not found: $script"
mkdir -p "$LOG_DIR"

set +e
"$godot_bin" --path "$PROJECT_DIR" "${engine_args[@]}" --script "$script" \
    -- --game-dir "$game_real" 2>&1 | tee "$log"
statuses=("${PIPESTATUS[@]}")
set -e
((statuses[0] == 0)) || exit "${statuses[0]}"
((statuses[1] == 0)) || fail "could not capture test log: $log"

if grep -Fq 'ERROR:' "$log"; then
    fail "Godot reported a script or shader error; inspect $log"
fi
grep -Eq "^${marker}( |$)" "$log" || fail "missing success marker '$marker'; inspect $log"
printf 'godot-region-test: %s passed; log: %s\n' "$profile" "$log"
