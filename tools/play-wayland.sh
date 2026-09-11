#!/usr/bin/env bash
# Run the container-built ELF on the host's native Wayland/Mesa/MangoHud stack.
set -euo pipefail
root="$(dirname "$(dirname "$(realpath "$0")")")"
if [[ -z "${XDG_RUNTIME_DIR:-}" || -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo 'Run from a Wayland desktop session (XDG_RUNTIME_DIR and WAYLAND_DISPLAY required).' >&2
    exit 1
fi
if [[ ! -x "$root/build/mad-sa-linux" ]]; then
    echo 'Build build/mad-sa-linux in mad-sa:dev first; see README.md.' >&2
    exit 1
fi
command -v mangohud >/dev/null
mkdir -p "$root/artifacts/graphics"
export SDL_VIDEODRIVER=wayland
# Conan's xkbcommon otherwise searches its container-only locale path.
if [[ -d /usr/share/X11/locale ]]; then
    export XLOCALEDIR=/usr/share/X11/locale
fi
# Continuous logging avoids the broken post-log benchmark panel in the host's
# MangoHud 0.8.3-rc1 package (reports v0.8.2). CSV rows flush during the run.
export MANGOHUD_CONFIG="${MANGOHUD_CONFIG:-fps,frametime,gpu_name,gpu_stats,cpu_stats,autostart_log=1,log_duration=0,log_interval=100,output_folder=$root/artifacts/graphics}"
# SDL resolves EGL entry points dynamically; older MangoHud packages need this
# hook as well as the ordinary GL preload to observe swaps and write CSV rows.
exec mangohud --dlsym "$root/build/mad-sa-linux" --play \
    --game-dir "$root/Grand-Theft-Auto-San-Andreas" "$@"
