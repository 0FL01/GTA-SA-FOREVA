#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(dirname "$(realpath "$0")")"
readonly PROJECT_DIR="$ROOT/godot"
readonly REPO_RUNTIME="$ROOT/build/godot-deps/godot-4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64"
readonly PACKAGE_RUNTIME="$ROOT/runtime/godot"

usage() {
    cat <<'EOF'
Usage: ./play-godot.sh [--compatibility|--x11|--x11-compatibility|--headless] -- --game-dir PATH [LAB OPTIONS]

The default is native Wayland with Vulkan Forward+. Alternative display/rendering
profiles must be selected explicitly; the launcher never silently falls back.

Lab options: --seconds N --route --capture-dir PATH --radius N --cap N
EOF
}

fail() {
    printf 'play-godot: %s\n' "$*" >&2
    exit 2
}

mode="wayland-forward-plus"
profile_selected=false
separator_seen=false
while (($#)); do
    case "$1" in
        --compatibility)
            [[ "$profile_selected" == false ]] || fail "select only one backend profile"
            mode="wayland-compatibility"
            profile_selected=true
            ;;
        --x11)
            [[ "$profile_selected" == false ]] || fail "select only one backend profile"
            mode="x11-forward-plus"
            profile_selected=true
            ;;
        --x11-compatibility)
            [[ "$profile_selected" == false ]] || fail "select only one backend profile"
            mode="x11-compatibility"
            profile_selected=true
            ;;
        --headless)
            [[ "$profile_selected" == false ]] || fail "select only one backend profile"
            mode="headless"
            profile_selected=true
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --)
            separator_seen=true
            shift
            break
            ;;
        *)
            fail "launcher option '$1' must be a documented backend flag; put lab options after --"
            ;;
    esac
    shift
done
[[ "$separator_seen" == true ]] || fail "missing -- separator before lab options"

lab_args=("$@")
game_dir=""
for ((i = 0; i < ${#lab_args[@]}; i++)); do
    case "${lab_args[i]}" in
        --game-dir)
            ((i + 1 < ${#lab_args[@]})) || fail "--game-dir requires a path"
            [[ -z "$game_dir" ]] || fail "--game-dir may be specified only once"
            game_dir="${lab_args[i + 1]}"
            ((i += 1))
            ;;
    esac
done
[[ -n "$game_dir" ]] || fail "external --game-dir PATH is required after --"
[[ -d "$game_dir" ]] || fail "game directory does not exist: $game_dir"
game_real="$(realpath -e -- "$game_dir")"
for ((i = 0; i < ${#lab_args[@]}; i++)); do
    if [[ "${lab_args[i]}" == --capture-dir ]]; then
        ((i + 1 < ${#lab_args[@]})) || fail "--capture-dir requires a path"
        capture_real="$(realpath -m -- "${lab_args[i + 1]}")"
        [[ "$capture_real" != "$game_real" && "$capture_real" != "$game_real/"* ]] \
            || fail "capture directory resolves inside the read-only game installation"
    fi
done

if [[ -n "${GODOT_BIN:-}" ]]; then
    godot_bin="$GODOT_BIN"
elif [[ -x "$PACKAGE_RUNTIME" ]]; then
    godot_bin="$PACKAGE_RUNTIME"
else
    godot_bin="$REPO_RUNTIME"
fi
[[ -x "$godot_bin" ]] \
    || fail "Godot executable not found; set GODOT_BIN or run tools/godot-fetch.sh"
[[ -f "$PROJECT_DIR/project.godot" ]] || fail "Godot project not found: $PROJECT_DIR"

engine_args=()
case "$mode" in
    wayland-forward-plus)
        [[ -n "${XDG_RUNTIME_DIR:-}" && -n "${WAYLAND_DISPLAY:-}" ]] \
            || fail "Wayland default requires XDG_RUNTIME_DIR and WAYLAND_DISPLAY"
        engine_args=(--display-driver wayland --rendering-method forward_plus --rendering-driver vulkan)
        ;;
    wayland-compatibility)
        [[ -n "${XDG_RUNTIME_DIR:-}" && -n "${WAYLAND_DISPLAY:-}" ]] \
            || fail "Wayland Compatibility requires XDG_RUNTIME_DIR and WAYLAND_DISPLAY"
        engine_args=(--display-driver wayland --rendering-method gl_compatibility --rendering-driver opengl3)
        ;;
    x11-forward-plus)
        [[ -n "${DISPLAY:-}" ]] || fail "--x11 requires DISPLAY"
        engine_args=(--display-driver x11 --rendering-method forward_plus --rendering-driver vulkan)
        ;;
    x11-compatibility)
        [[ -n "${DISPLAY:-}" ]] || fail "--x11-compatibility requires DISPLAY"
        engine_args=(--display-driver x11 --rendering-method gl_compatibility --rendering-driver opengl3)
        ;;
    headless)
        engine_args=(--headless)
        ;;
esac

exec "$godot_bin" --path "$PROJECT_DIR" --audio-driver Dummy "${engine_args[@]}" -- "${lab_args[@]}"
