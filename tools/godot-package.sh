#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
readonly PROJECT_DIR="$REPO_ROOT/godot"
readonly DEPS_DIR="$REPO_ROOT/build/godot-deps"
readonly RUNTIME_DIR="$DEPS_DIR/godot-4.6.1-stable"
readonly RUNTIME_BIN="$RUNTIME_DIR/Godot_v4.6.1-stable_linux.x86_64"
readonly RUNTIME_ARCHIVE="$DEPS_DIR/downloads/Godot_v4.6.1-stable_linux.x86_64.zip"
readonly RUNTIME_SHA512="a76fd0fe1d44a2dd6c065b6f7b434ad75f5593c07bda3d3017f8304f2d069acbcf0f39cb5d0976f0434b56e9ea852032ddbcbdb7e0ce1c75a47e1dacb6794bd7"
readonly GODOT_CPP_LICENSE="$DEPS_DIR/godot-cpp/LICENSE.md"
readonly LIBRW_LICENSE="$REPO_ROOT/gta-reversed/vendor/librw/LICENSE"
readonly PACKAGE_DIR="$REPO_ROOT/artifacts/godot/package"
readonly STAGING_DIR="$REPO_ROOT/artifacts/godot/.package.$$"
readonly EXTENSION_DESCRIPTOR="$PROJECT_DIR/sa_legacy.gdextension"
readonly EXTENSION_LIBRARY="$PROJECT_DIR/bin/libsa_legacy.so"

fail() {
    printf 'godot-package: %s\n' "$*" >&2
    exit 1
}

copy_file() {
    local source="$1"
    local relative_destination="$2"
    [[ -f "$source" ]] || fail "required package input missing: $source"
    install -D -m 0644 "$source" "$STAGING_DIR/$relative_destination"
}

audit_elf() {
    local binary="$1"
    local dynamic_info
    local runtime_links

    dynamic_info="$(readelf -d "$binary")"
    runtime_links="$(ldd "$binary")"
    [[ "$runtime_links" != *"not found"* ]] || fail "$binary has unresolved runtime libraries"
    for forbidden in "$REPO_ROOT" /workspace /opt/conan /.conan-cache; do
        [[ "$dynamic_info" != *"$forbidden"* && "$runtime_links" != *"$forbidden"* ]] \
            || fail "$binary contains a build-tree or Conan runtime path: $forbidden"
    done
}

audit_extension_boundary() {
    local dependencies
    local exports

    dependencies="$(readelf -d "$EXTENSION_LIBRARY") $(ldd "$EXTENSION_LIBRARY")"
    for forbidden in libSDL libopenal libOpenAL libGL.so libOpenGL libGLX libGLES libEGL libwine librw; do
        [[ "$dependencies" != *"$forbidden"* ]] \
            || fail "GDExtension unexpectedly depends on native presentation/runtime library: $forbidden"
    done
    exports="$(nm --dynamic --defined-only --format=just-symbols "$EXTENSION_LIBRARY")"
    [[ "$exports" == "sa_legacy_library_init" ]] \
        || fail "extension must export only its GDExtension C entry point; private C++ symbols can collide with the GPU driver runtime"
}

for command in file install ldd nm readelf sha512sum unzip; do
    command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done
[[ -x "$RUNTIME_BIN" ]] || fail "run tools/godot-fetch.sh first"
[[ -f "$RUNTIME_ARCHIVE" ]] || fail "verified Godot archive is missing: $RUNTIME_ARCHIVE"
printf '%s  %s\n' "$RUNTIME_SHA512" "$RUNTIME_ARCHIVE" | sha512sum --check --status - \
    || fail "Godot runtime archive checksum mismatch"

archive_runtime_hash="$(unzip -p "$RUNTIME_ARCHIVE" Godot_v4.6.1-stable_linux.x86_64 | sha512sum | cut -d ' ' -f 1)"
installed_runtime_hash="$(sha512sum "$RUNTIME_BIN" | cut -d ' ' -f 1)"
[[ "$archive_runtime_hash" == "$installed_runtime_hash" ]] \
    || fail "installed Godot runtime differs from the verified archive"

[[ -f "$EXTENSION_DESCRIPTOR" ]] \
    || fail "missing $EXTENSION_DESCRIPTOR; integrate the native adapter descriptor first"
[[ -f "$EXTENSION_LIBRARY" ]] || fail "run tools/godot-build.sh first"
file "$EXTENSION_LIBRARY" | while read -r identity; do
    [[ "$identity" == *"ELF 64-bit"* && "$identity" == *"x86-64"* ]] \
        || fail "GDExtension is not an ELF x86_64 library: $identity"
done

descriptor_contents="$(<"$EXTENSION_DESCRIPTOR")"
for forbidden in "$REPO_ROOT" /workspace /opt/conan /.conan-cache; do
    [[ "$descriptor_contents" != *"$forbidden"* ]] \
        || fail "GDExtension descriptor contains a build-tree or Conan path: $forbidden"
done
audit_elf "$RUNTIME_BIN"
audit_elf "$EXTENSION_LIBRARY"
audit_extension_boundary

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
trap 'rm -rf "$STAGING_DIR"' EXIT

copy_file "$PROJECT_DIR/project.godot" godot/project.godot
copy_file "$PROJECT_DIR/lab.tscn" godot/lab.tscn
copy_file "$PROJECT_DIR/lab.gd" godot/lab.gd
copy_file "$PROJECT_DIR/actor_lab.tscn" godot/actor_lab.tscn
copy_file "$PROJECT_DIR/actor_lab.gd" godot/actor_lab.gd
copy_file "$PROJECT_DIR/diagnostic_actor_view.gd" godot/diagnostic_actor_view.gd
copy_file "$PROJECT_DIR/pose_family_view.gd" godot/pose_family_view.gd
copy_file "$PROJECT_DIR/materials/API.md" godot/materials/API.md
copy_file "$PROJECT_DIR/materials/legacy_materials.gd" godot/materials/legacy_materials.gd
copy_file "$PROJECT_DIR/materials/legacy_surface_common.gdshaderinc" godot/materials/legacy_surface_common.gdshaderinc
copy_file "$PROJECT_DIR/materials/legacy_opaque.gdshader" godot/materials/legacy_opaque.gdshader
copy_file "$PROJECT_DIR/materials/legacy_cutout.gdshader" godot/materials/legacy_cutout.gdshader
copy_file "$PROJECT_DIR/materials/legacy_blend.gdshader" godot/materials/legacy_blend.gdshader
copy_file "$PROJECT_DIR/materials/legacy_env.gdshader" godot/materials/legacy_env.gdshader
copy_file "$PROJECT_DIR/materials/legacy_sky.gdshader" godot/materials/legacy_sky.gdshader
copy_file "$PROJECT_DIR/materials/legacy_post.gdshader" godot/materials/legacy_post.gdshader
copy_file "$EXTENSION_DESCRIPTOR" godot/sa_legacy.gdextension
copy_file "$EXTENSION_LIBRARY" godot/bin/libsa_legacy.so
copy_file "$REPO_ROOT/play-godot.sh" play-godot.sh
copy_file "$PROJECT_DIR/README.md" README.md
copy_file "$PROJECT_DIR/DEPENDENCIES.md" DEPENDENCIES.md
copy_file "$RUNTIME_DIR/LICENSE.txt" licenses/GODOT_LICENSE.txt
copy_file "$RUNTIME_DIR/COPYRIGHT.txt" licenses/GODOT_COPYRIGHT.txt
copy_file "$GODOT_CPP_LICENSE" licenses/GODOT_CPP_LICENSE.md
copy_file "$LIBRW_LICENSE" licenses/LIBRW_LICENSE.txt
install -D -m 0755 "$RUNTIME_BIN" "$STAGING_DIR/runtime/godot"
chmod 0755 "$STAGING_DIR/play-godot.sh"

rm -rf "$PACKAGE_DIR"
mkdir -p "$(dirname "$PACKAGE_DIR")"
mv "$STAGING_DIR" "$PACKAGE_DIR"
trap - EXIT
printf 'Package staged at %s\n' "$PACKAGE_DIR"
printf 'It contains no game assets; pass an external --game-dir after the launcher separator.\n'
