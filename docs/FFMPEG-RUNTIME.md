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
