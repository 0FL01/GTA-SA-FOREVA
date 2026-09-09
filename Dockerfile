# mad-sa dev image: RE + Linux-native build.
# Base: Ubuntu 24.04 (GCC 13+, C++23, CMake 3.28, Conan 2 via pip).
# What this image IS for:
#   - native Linux iteration (oswrapper_linux, standalone main, librw/SDL/OpenAL track)
#   - RE analysis of the original x86 PE (binutils/lief/capstone/pefile) + Wine reference runs
# What it is NOT: the legacy `gta_reversed` DLL track stays Windows/MSVC-only
#   (Win libs behind `if(WIN32)`, default `GTASA_BUILD_LEGACY=ON`); Linux work
#   happens in the `mad-sa-linux` native track (`-DGTASA_BUILD_LEGACY=OFF`).
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    CMAKE_GENERATOR=Ninja \
    CONAN_HOME=/opt/conan \
    CCACHE_DIR=/opt/ccache \
    LANG=C.UTF-8

# - toolchain + CMake/Ninja + Python (Conan 2)
# - Linux GL/audio/windowing dev libs (SDL3-from-Conan + OpenAL native needs these)
# - MinGW for x86/x64 cross-checks; wine64 loader present (/usr/lib/wine/wine64,
#   no PATH frontend). 32-bit game-exe reference runs stay on host (needs i386 Wine).
# - RE CLI: binutils (objdump), file; GUI (Ghidra/Cutter) stays on host.
#   Python RE libs (lief/capstone) come via pip below - rizin is NOT in
#   Ubuntu noble repos, so it is intentionally not an apt dependency.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc-multilib g++-multilib clang lld \
    cmake ninja-build pkg-config ccache git curl unzip zip \
    python3 python3-pip python3-venv \
    libopenal-dev libgl1-mesa-dev libegl1-mesa-dev libglu1-mesa-dev \
    libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxss-dev \
    libx11-xcb-dev libfontenc-dev libice-dev libsm-dev libxau-dev libxaw7-dev \
    libxcomposite-dev libxdamage-dev libxinerama-dev libxkbfile-dev libxmu-dev libxmuu-dev \
    libxpm-dev libxres-dev libxt-dev libxtst-dev libxv-dev libxxf86vm-dev \
    libxcb-glx0-dev libxcb-render0-dev libxcb-render-util0-dev libxcb-xkb-dev \
    libxcb-icccm4-dev libxcb-image0-dev libxcb-keysyms1-dev libxcb-randr0-dev \
    libxcb-shape0-dev libxcb-sync-dev libxcb-xfixes0-dev libxcb-xinerama0-dev \
    libxcb-dri3-dev libxcb-cursor-dev libxcb-dri2-0-dev libxcb-present-dev \
    libxcb-composite0-dev libxcb-ewmh-dev libxcb-res0-dev libxcb-util-dev \
    libwayland-dev libudev-dev libdbus-1-dev libibus-1.0-dev \
    libjpeg-turbo8-dev libogg-dev libvorbis-dev \
    wine64 mingw-w64 binutils file \
    && rm -rf /var/lib/apt/lists/*

# Conan 2 (Ubuntu 24.04 pip is externally-managed -> break-system-packages is intended here)
# + Python RE libs for PE analysis (lief/capstone) - GUI disassemblers stay on host.
RUN pip3 install --break-system-packages "conan>=2" lief capstone pefile \
    && mkdir -p /opt/conan /opt/ccache \
    && conan profile detect --force \
    && conan --version && cmake --version && gcc --version | head -n 1

WORKDIR /workspace

# Mounts (run example):
#   docker run --rm -it -v .:/workspace \
#     -v ./Grand-Theft-Auto-San-Andreas:/game:ro \
#     mad-sa:dev
# Inside: game assets are at /game (read-only), never copy them into the image.

CMD ["/bin/bash"]
