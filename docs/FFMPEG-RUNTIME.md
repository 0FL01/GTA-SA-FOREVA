# FFmpeg runtime boundary

The native Linux reference executable decodes the legally owned startup MPEG
files through the system FFmpeg shared libraries. FFmpeg is **not** copied into
the Godot transfer package and no game movie is redistributed.

## Build and runtime

The development image installs the Ubuntu 24.04 development packages for
`libavformat`, `libavcodec`, `libavutil`, `libswscale`, and `libswresample`.
CMake resolves them with `pkg-config`; the resulting ELF dynamically links the
system libraries. The direct gate is:

```sh
./build/mad-sa-linux --smoke-movies --game-dir /game
```

It decodes video and audio from `Logo.mpg` followed by `GTAtitles.mpg`, then
checks the independently decoded `loadsc0` splash through the texture probe.
All source media stays external and read-only.

## Licensing

Ubuntu's FFmpeg packages used by this workspace are distributed under the
LGPL/GPL terms recorded by the installed package in
`/usr/share/doc/ffmpeg/copyright`; the linked libraries in this build report
LGPL-compatible system configurations. This project uses dynamic linking and
does not redistribute those shared libraries. A distributor of a native binary
must provide the corresponding FFmpeg license notices and satisfy the license
terms of the exact FFmpeg build it ships. The asset-free Godot package does not
contain FFmpeg or MPEG files.

This is a dependency and redistribution boundary, not legal advice.

## Fedora 44 target policy

The Ubuntu 24.04 development build links FFmpeg `libavformat.so.60` and
`libavcodec.so.60`. Fedora 44 provides `.so.62`, so the Ubuntu native binary is
**not** a portable Fedora release artifact. Reconfigure and rebuild
`build/mad-sa-linux` from these sources on the Fedora target using its own
FFmpeg development packages and system shared libraries (the native Conan/SDL3
and CMake steps are in the root README). `tools/target-closure.sh` checks that
the native ELF resolves Fedora's system `.so.62` libraries, rejects an injected
`LD_LIBRARY_PATH`, and does not accept private extracted compat libraries.

The asset-free Godot package has a separate extension/runtime dependency audit:
it never carries MPEG files or FFmpeg libraries. Any future redistribution of
the Fedora-built native binary requires notices/license review for that exact
host FFmpeg configuration, independently of the Godot transfer package.
