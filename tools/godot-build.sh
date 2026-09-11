#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
readonly SOURCE_DIR="$REPO_ROOT/godot/native"
readonly BUILD_DIR="$REPO_ROOT/build/godot-native"
readonly GODOT_CPP_DIR="$REPO_ROOT/build/godot-deps/godot-cpp"
readonly GODOT_CPP_COMMIT="e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77"
readonly OUTPUT_LIBRARY="$REPO_ROOT/godot/bin/libsa_legacy.so"

fail() {
    printf 'godot-build: %s\n' "$*" >&2
    exit 1
}

for command in cmake file git ninja; do
    command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done
[[ -f "$SOURCE_DIR/CMakeLists.txt" ]] \
    || fail "missing $SOURCE_DIR/CMakeLists.txt; integrate the native adapter lane first"
[[ -d "$GODOT_CPP_DIR/.git" ]] || fail "run tools/godot-fetch.sh first"
actual_commit="$(git -C "$GODOT_CPP_DIR" rev-parse HEAD)"
[[ "$actual_commit" == "$GODOT_CPP_COMMIT" ]] \
    || fail "godot-cpp is $actual_commit, expected $GODOT_CPP_COMMIT"
[[ -z "$(git -C "$GODOT_CPP_DIR" status --porcelain)" ]] \
    || fail "godot-cpp checkout has local changes"

cmake --fresh -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja \
    -DREPO_ROOT="$REPO_ROOT" \
    -DGODOT_CPP_DIR="$GODOT_CPP_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
cmake --build "$BUILD_DIR" --config Release -j2

[[ -f "$OUTPUT_LIBRARY" ]] \
    || fail "build completed without expected output $OUTPUT_LIBRARY"
file "$OUTPUT_LIBRARY"
printf 'Built %s\n' "$OUTPUT_LIBRARY"
