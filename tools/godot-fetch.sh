#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
readonly DEPS_DIR="$REPO_ROOT/build/godot-deps"
readonly DOWNLOAD_DIR="$DEPS_DIR/downloads"

readonly GODOT_VERSION="4.6.1-stable"
readonly GODOT_COMMIT="14d19694e0c88a3f9e82d899a0400f27a24c176e"
readonly GODOT_ARCHIVE="Godot_v4.6.1-stable_linux.x86_64.zip"
readonly GODOT_ARCHIVE_SHA512="a76fd0fe1d44a2dd6c065b6f7b434ad75f5593c07bda3d3017f8304f2d069acbcf0f39cb5d0976f0434b56e9ea852032ddbcbdb7e0ce1c75a47e1dacb6794bd7"
readonly GODOT_RELEASE_URL="https://github.com/godotengine/godot-builds/releases/download/$GODOT_VERSION"
readonly GODOT_RUNTIME_DIR="$DEPS_DIR/godot-$GODOT_VERSION"
readonly GODOT_EXECUTABLE="Godot_v4.6.1-stable_linux.x86_64"

readonly GODOT_CPP_TAG="godot-4.5-stable"
readonly GODOT_CPP_COMMIT="e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77"
readonly GODOT_CPP_URL="https://github.com/godotengine/godot-cpp.git"
readonly GODOT_CPP_DIR="$DEPS_DIR/godot-cpp"

fail() {
    printf 'godot-fetch: %s\n' "$*" >&2
    exit 1
}

fetch() {
    local url="$1"
    local destination="$2"
    local temporary="${destination}.part.$$"

    rm -f "$temporary"
    if ! curl --proto '=https' --tlsv1.2 --fail --location --retry 3 \
        --output "$temporary" "$url"; then
        rm -f "$temporary"
        fail "download failed: $url"
    fi
    mv "$temporary" "$destination"
}

for command in curl git sha512sum unzip; do
    command -v "$command" >/dev/null 2>&1 || fail "required command not found: $command"
done
[[ "$(uname -m)" == "x86_64" ]] || fail "the pinned official runtime is Linux x86_64 only"

mkdir -p "$DOWNLOAD_DIR"
archive_path="$DOWNLOAD_DIR/$GODOT_ARCHIVE"
sums_path="$DOWNLOAD_DIR/Godot_v${GODOT_VERSION}_SHA512-SUMS.txt"

if [[ ! -f "$archive_path" ]]; then
    fetch "$GODOT_RELEASE_URL/$GODOT_ARCHIVE" "$archive_path"
fi
printf '%s  %s\n' "$GODOT_ARCHIVE_SHA512" "$archive_path" | sha512sum --check --status - \
    || fail "archive checksum mismatch; remove $archive_path and retry"

if [[ ! -f "$sums_path" ]]; then
    fetch "$GODOT_RELEASE_URL/SHA512-SUMS.txt" "$sums_path"
fi
official_digest=""
while read -r digest filename; do
    if [[ "$filename" == "$GODOT_ARCHIVE" ]]; then
        official_digest="$digest"
        break
    fi
done < "$sums_path"
[[ "$official_digest" == "$GODOT_ARCHIVE_SHA512" ]] \
    || fail "official checksum list does not contain the pinned runtime digest"

runtime_tmp="$DEPS_DIR/.godot-runtime.$$"
rm -rf "$runtime_tmp"
mkdir -p "$runtime_tmp"
trap 'rm -rf "$runtime_tmp" "$DEPS_DIR/.godot-cpp.$$"' EXIT
unzip -q "$archive_path" -d "$runtime_tmp"
[[ -f "$runtime_tmp/$GODOT_EXECUTABLE" ]] \
    || fail "runtime archive does not contain $GODOT_EXECUTABLE"
chmod 0755 "$runtime_tmp/$GODOT_EXECUTABLE"

fetch "https://raw.githubusercontent.com/godotengine/godot/$GODOT_COMMIT/LICENSE.txt" \
    "$runtime_tmp/LICENSE.txt"
fetch "https://raw.githubusercontent.com/godotengine/godot/$GODOT_COMMIT/COPYRIGHT.txt" \
    "$runtime_tmp/COPYRIGHT.txt"
rm -rf "$GODOT_RUNTIME_DIR"
mv "$runtime_tmp" "$GODOT_RUNTIME_DIR"

if [[ -e "$GODOT_CPP_DIR" ]]; then
    [[ -d "$GODOT_CPP_DIR/.git" ]] || fail "$GODOT_CPP_DIR exists but is not a Git checkout"
    origin_url="$(git -C "$GODOT_CPP_DIR" remote get-url origin)"
    [[ "$origin_url" == "$GODOT_CPP_URL" ]] \
        || fail "$GODOT_CPP_DIR origin is $origin_url, expected $GODOT_CPP_URL"
    [[ -z "$(git -C "$GODOT_CPP_DIR" status --porcelain)" ]] \
        || fail "$GODOT_CPP_DIR has local changes; refusing a non-reproducible dependency"
    actual_commit="$(git -C "$GODOT_CPP_DIR" rev-parse HEAD)"
    [[ "$actual_commit" == "$GODOT_CPP_COMMIT" ]] \
        || fail "$GODOT_CPP_DIR is $actual_commit, expected $GODOT_CPP_COMMIT"
else
    cpp_tmp="$DEPS_DIR/.godot-cpp.$$"
    rm -rf "$cpp_tmp"
    git clone --depth 1 --branch "$GODOT_CPP_TAG" "$GODOT_CPP_URL" "$cpp_tmp"
    actual_commit="$(git -C "$cpp_tmp" rev-parse HEAD)"
    [[ "$actual_commit" == "$GODOT_CPP_COMMIT" ]] \
        || fail "$GODOT_CPP_TAG resolved to $actual_commit, expected $GODOT_CPP_COMMIT"
    mv "$cpp_tmp" "$GODOT_CPP_DIR"
fi

printf 'Godot runtime: %s (%s)\n' "$GODOT_RUNTIME_DIR/$GODOT_EXECUTABLE" "$GODOT_COMMIT"
printf 'Godot archive SHA-512: %s\n' "$GODOT_ARCHIVE_SHA512"
printf 'godot-cpp: %s (%s)\n' "$GODOT_CPP_DIR" "$GODOT_CPP_COMMIT"
