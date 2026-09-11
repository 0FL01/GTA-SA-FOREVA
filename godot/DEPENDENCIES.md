# Godot Lab Dependencies And Licenses

This record covers the standalone Linux test package assembled by
`tools/godot-package.sh`. It is not legal advice.

## Pinned Downloaded Inputs

| Component | Identity | Source | License handling |
|---|---|---|---|
| Godot Engine | `4.6.1-stable`, commit `14d19694e0c88a3f9e82d899a0400f27a24c176e` | `https://github.com/godotengine/godot-builds/releases/download/4.6.1-stable/Godot_v4.6.1-stable_linux.x86_64.zip` | MIT/Expat engine license plus bundled third-party notices; package includes `licenses/GODOT_LICENSE.txt` and `licenses/GODOT_COPYRIGHT.txt` fetched at the exact engine commit. |
| godot-cpp | tag `godot-4.5-stable`, commit `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77` | `https://github.com/godotengine/godot-cpp.git` | MIT; package includes `licenses/GODOT_CPP_LICENSE.md` from the pinned checkout. |
| librw | vendored commit `18532c2e13efbc1aa43f0b00b4459831f9414de0` | `gta-reversed/vendor/librw` | MIT, copyright 2014 aap; statically linked by the intended NULL-platform reader closure and included as `licenses/LIBRW_LICENSE.txt`. |

The Godot archive is checked with SHA-512
`a76fd0fe1d44a2dd6c065b6f7b434ad75f5593c07bda3d3017f8304f2d069acbcf0f39cb5d0976f0434b56e9ea852032ddbcbdb7e0ce1c75a47e1dacb6794bd7`.
The fetch script also requires the same entry in Godot's official release
`SHA512-SUMS.txt`. The package script rechecks the archive and verifies that the
packaged executable bytes match the executable stored in that archive.

## Runtime Boundary

- The package contains the official Godot executable and `libsa_legacy.so`.
- `godot-cpp` and NULL-platform `librw` are compiled into the GDExtension; their
  source checkouts are not shipped.
- Linux, glibc, libstdc++, Wayland, Vulkan loader, and Mesa are host components,
  not copied from the build machine. Exact dynamic requirements are compiler and
  adapter dependent; packaging runs `ldd` and fails on unresolved libraries.
- The package rejects RPATH/RUNPATH or resolved dependency paths under the
repository, `/workspace`, `/opt/conan`, or `/.conan-cache`. Conan is not a
runtime dependency of this delivery.
- The GDExtension audit also rejects linked SDL, OpenAL, OpenGL/EGL, and Wine
  libraries. Godot owns presentation; the adapter's librw configuration is
  parse-only `RW_NULL`.
- A legally owned GTA: San Andreas installation is external, selected with the
  required `--game-dir`, and read at runtime. No Rockstar/Take-Two asset,
  executable, screenshot, or license is included.

## Adapter Source Status

The native adapter consumes reader code from this research workspace. The source
audit and `godot/native/CMakeLists.txt` identify `StreamPager`, `TexSample`, the
read-only `os_file_posix` wrapper, GL-free `TimeCycle` and MIT-licensed
NULL-platform librw as the compiled closure. The workspace root does not
contain a declared redistribution license for its own reader/adapter code.
Therefore the generated package is a personal test handover, not a
redistribution-cleared binary release. Review the final CMake source list and
establish permission/notice obligations before distributing it beyond the
authorized tester. Do not infer that the Godot/godot-cpp/librw MIT licenses cover
the adapter or reverse-engineered reader code.

## Reproducibility Limits

- Engine and bindings source identities are pinned; downloads use HTTPS and the
  engine archive has a fixed digest.
- `mad-sa:dev` currently names an image tag rather than an immutable image digest.
  Compiler, linker, CMake, Ninja, glibc, and system headers are not locked here to
  package hashes, so `libsa_legacy.so` is not claimed bit-for-bit reproducible.
- The native reader source commit and any dirty workspace state are not embedded
  in the package name. Run manifests should record source identities separately.
- Package mtimes and filesystem ordering are not normalized. The output is a
  clean rsync-ready directory, not a reproducible archive format.
- Mesa, Vulkan loader, Wayland compositor, GPU firmware, and RX 780M behavior are
  target-host inputs. Server or headless results cannot substitute for Fedora 44
  GPU evidence.
- Godot can generate `.godot/` import state and per-user logs after first launch.
  Those files are intentionally excluded; rerun packaging for a clean handover.
