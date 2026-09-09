#!/usr/bin/env bash
set -euo pipefail
root="$(dirname "$(realpath "$0")")"
exec "$root/tools/play-wayland.sh" "$@"
