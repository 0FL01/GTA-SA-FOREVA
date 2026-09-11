# Godot standalone reader audit

Status: initial source audit complete; parent integration corrections below supersede provisional choices. Final evidence is recorded in the [current goal](goals/2026-09-11-godot-legacy-look-lab.md).

This audit is scoped to the asset-free Godot Legacy Look Lab. It does not approve a
full gameplay port, replace the native backend, or certify visual parity. The game
installation remains external and read-only.

## Integration corrections (2026-09-11)

- Actual closure is `StreamPager.cpp + TexSample.cpp + TimeCycle.cpp + godot/native/os_file_posix.cpp + librw(NULL)` with PIC, not the SDL/OpenAL OS wrapper. Built extension dependency audit has no SDL/GL/EGL/OpenAL/Wine or original-executable dependency. A read-only trace loads real assets without opening an `.exe`.
- Actual engine is pinned Godot4.6.1 (`14d19694e`), retaining the4.5 binding ABI below. The initial4.5 engine had a reproduced Wayland initialization race fixed upstream in4.6; Forward+ and Compatibility pixel tests pass on4.6.1. `project.godot`'s feature version is not an engine pin.
- Native optional metadata additions preserve model-local geometry/material-slot identity through flattening and the eight timecycle post columns. Adapter grouping no longer merges distinct equal-valued source slots. No source material family/MatFX/second UV/mip-chain/runtime LOD implementation is implied.
- The lab's separate framebuffer shader implements the PC `ColourFilter` two additive passes from source timecycle bytes. Surface materials still have no in-surface post. PS2 filtering, radiosity and heat haze remain unavailable. Known-grey/day-night/sky/post/alpha pixel tests validate actual shader output, not just shader text.
- The owned51-column PC timecycle lacks optional DirMult, so the directional term is explicitly disabled, matching the native policy. Negative cloudy fog-start is valid source data, not an import error. No art-tuned replacement was added.

## Initial audited snapshot (historical findings below)

- Workspace commit: `155b42f5b9fcec00d23887df5cac8baac79c326c`.
- Native fork commit: `22dee69e52564a52a54a948d463bdf47cfb3c4d0`.
- Vendored librw submodule: `18532c2e13efbc1aa43f0b00b4459831f9414de0`.
- Intended engine line: Godot `4.5-stable`, Forward+.
- Intended bindings: `godotengine/godot-cpp` release `godot-4.5-stable`, commit
  `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77`. The upstream release page identifies
  `e83fd09` as that release, but the audited worktree contains no bindings checkout,
  dependency lock, GDExtension descriptor, or native adapter build file yet. The pin
  is therefore externally confirmed but not yet locally enforced.
- Existing `godot/project.godot` declares feature `4.5` and Forward+, but that feature
  string is not an exact editor-binary pin. Delivery still needs an exact engine
  artifact identity and checksum in its build/run tooling.
- No build, Godot run, Docker run, GL run, or game-asset read was performed in this
  lane. Findings below marked **confirmed** are source facts, not runtime results.

## Boundary verdict

**Confirmed:** the native reader slice can run as ordinary Linux x86-64 code without
opening or mapping `gta-sa.exe`, without Wine, and without the native SDL/EGL window.
The selected reader files contain no `StaticRef`, hook registration, `plugin::Call`,
or absolute game-memory dereference. They parse external `DAT`, `IDE`, `IPL`, `IMG`,
`DFF`, `TXD`, and `IFP` bytes through stdio/`OS_File*` and librw's NULL platform.

**Not standalone-safe:** `source/game_sa/**` is the upstream hooked implementation.
For example:

- `source/game_sa/TimeCycle.h` binds all `CTimeCycle` tables and current state to
  Compact 1.0 US addresses through `StaticRef`, including `m_nAmbientRed` at
  `0xB7C3C8`, `m_CurrentColours` at `0xB7C4A0`, and `m_vecDirnLightToSun` at
  `0xB7CB14`.
- `source/game_sa/TimeCycle.cpp::CTimeCycle::InjectHooks` installs functions at fixed
  addresses such as `Initialise` `0x5BBAC0` and `CalcColoursForPoint` `0x5603D0`.
  `CalcColoursForPoint` also consumes live `CClock`, `CWeather`, camera, corona,
  tunnel, underwater, extra-colour, and timecycle-box state.
- `source/Base.h::StaticRef` normally returns `*reinterpret_cast<T*>(addr)`.
  `VALIDATE_SIZE` and `VALIDATE_OFFSET` enforce original binary layouts throughout
  the game model.
- `gta-reversed/CMakeLists.txt` selects `Win32` for MSVC and
  `gta-reversed/conanprofile.txt` fixes `arch=x86`, `compiler=msvc`, `os=Windows`.
  Pointer-bearing RenderWare/game classes and hook calling conventions consequently
  belong to the 32-bit executable ABI.
- `source/game_sa/FileObjectInstance.h` and `tBinaryIplFile.h` validate `0x28` and
  `0x4c` layouts and cast binary records into game classes. The native pager instead
  decodes the same little-endian fields explicitly in
  `StreamPager.cpp::ParseBinaryIpl`, so unaligned bytes and host pointer size do not
  enter the adapter ABI.

No file under `source/game_sa/` should be compiled into the GDExtension. It remains
read-only algorithm/reference evidence.

## Exact native source closure

All paths in this section are relative to `gta-reversed/source/` unless stated
otherwise. The existing monolithic `mad-sa-linux` target is not the closure for the
extension: it also links SDL3, OpenAL, OpenGL/EGL, Vorbis, and many gameplay units
that the lab does not need.

| Capability | Compile units | Direct non-system dependency | Result |
|---|---|---|---|
| `WorldShot_Init` fixture | `app/platform/linux/WorldShot.cpp`, `app/platform/linux/TexSample.cpp`, `oswrapper/oswrapper_linux.cpp` | `vendor/librw` as `librw::librw`, configured `LIBRW_PLATFORM=NULL` | Parse-only and no GL, but it chooses one hard-coded “richest” DFF candidate. It is a smoke fixture, not a district reader. |
| `StreamPager_Init/Update/Shutdown` | `app/platform/linux/StreamPager.cpp`, `app/platform/linux/TexSample.cpp`, `oswrapper/oswrapper_linux.cpp` | `librw::librw` with NULL platform | Correct starting point for the bounded district adapter. `WorldShot.h` supplies owned output structs; `WorldShot.cpp` is not a link dependency. `NativeCollisionAssets.h` supplies value types; `NativeCollisionAssets.cpp` is not needed unless collision loading is requested. |
| `TimeCycle_LoadWeatherHour` / `TimeCycle_LoadHour` | `app/platform/linux/TimeCycle.cpp`, `oswrapper/oswrapper_linux.cpp` | none | CPU/file-only. No librw or GL dependency. |
| Complete `RealtimeEnvironment` class | `app/platform/linux/RealtimeEnvironment.cpp`, `app/platform/linux/TimeCycle.cpp`, `app/platform/linux/WaterLevel.cpp`, `app/platform/linux/TexSample.cpp`, `oswrapper/oswrapper_linux.cpp` | `librw::librw`, OpenGL | **Reject for the Godot adapter as-is.** Its one implementation unit mixes useful interpolation/data code with `<GL/gl.h>`, GLSL 1.20 compilation, compatibility-state calls, and direct water/sky drawing. |
| Frozen `CarPose_Init` fixture | `app/platform/linux/CarPose.cpp`, `app/platform/linux/TexSample.cpp`, `oswrapper/oswrapper_linux.cpp` | `librw::librw` with NULL platform | Executable-independent and parse-only, but not required by the first district lab. `WorldShot.cpp` is not required. |
| Frozen `IfpAnim_Init` fixture | `app/platform/linux/IfpAnim.cpp`, `app/platform/linux/TexSample.cpp`, `oswrapper/oswrapper_linux.cpp` | `librw::librw` with NULL platform | Executable-independent and parse-only. Build with `REALTIME_GAMEPLAY_POSE_AUDIT` undefined; otherwise its optional audit coupling expands the closure. `NativePlayerAssets.cpp` is not required for the legacy fixture symbols. |

Required include roots are `gta-reversed/source` and `gta-reversed/vendor/librw`.
Use the repository's C++23 setting because `StreamPager.cpp` uses C++20 library
features such as `std::string::ends_with`; do not lower the standard just for the
extension.

`oswrapper_linux.cpp` itself has no SDL, OpenAL, Wine, or GL include. It uses libc,
POSIX threads and semaphores. Linking `Threads::Threads` is the portable closure. The
reader calls only its file/path functions, so a later small file-only abstraction is
possible, but it is not required to prove this milestone and should not fork reader
behavior prematurely.

The librw CMake target sets public `RW_NULL` and links only `m` on GCC/Clang when
`LIBRW_PLATFORM=NULL`; its OpenGL branch is conditional on `LIBRW_PLATFORM_GL3`.
Although its source list names GL and D3D implementation files, the NULL build does
not make the adapter a GL/D3D runtime. Configure `LIBRW_TOOLS=OFF`,
`LIBRW_EXAMPLES=OFF`, and `LIBRW_INSTALL=OFF`, as the native target does.

**Build blocker:** librw defaults to a static library and its CMake file does not set
`POSITION_INDEPENDENT_CODE`. Any static librw/godot-cpp objects linked into the
x86-64 GDExtension `.so` must be compiled with PIC (for example, set
`CMAKE_POSITION_INDEPENDENT_CODE=ON` before adding those subdirectories). This is a
source-confirmed configuration gap; whether the current toolchain would emit a
relocation error is not run in this lane.

## Ownership and concurrency

- `StreamPager.cpp`, `CarPose.cpp`, and `IfpAnim.cpp` each keep process-global caches;
  librw has one global engine/current texture dictionary; `oswrapper_linux.cpp` has
  one global base path. These APIs are not re-entrant.
- `StreamPager_Init` parses the world catalogs and IMG directories, and
  `StreamPager_Update` performs model/TXD reads and mutates residency. Calls must be
  serialized under one adapter owner. Godot `ArrayMesh`, `ImageTexture`, and other
  engine objects must be created on Godot's owning thread after CPU publication.
- `StreamPager_Shutdown` releases pager dictionaries/caches but intentionally does
  not stop librw. The extension owner must call it exactly once for each opened
  pager lifecycle and must not let Godot resources retain librw pointers. The
  `WorldShotScene` output owns vectors and RGBA bytes, so copying/moving it across
  the publication boundary is safe after parsing completes.
- `StreamPagerOptions::maxInstances` bounds a frame's placed instances, not total
  initialization memory. Initialization still retains all parsed placement rows and
  IMG directories. This satisfies “no full world node preload,” but it is not proof
  of a fixed total-memory bound.

## World and texture fidelity

The following describes the actual `StreamPager` output with
`StreamPagerOptions::includeStreamed=true`. Leaving the default `false` is a hard
adapter error: it omits binary IPLs and does not populate `dayColors`, `nightColors`,
or `surfaces`.

| Source feature | What survives | Loss or uncertainty |
|---|---|---|
| Placement | Text and binary IPL position, conjugated quaternion basis, source order, model ID, flags/interior/LOD provenance | Render output exposes world-space soup, not each authored local transform. Only interior 0 is rendered. |
| Geometry | Morph target 0 positions and triangle order | Index topology, atomic/frame identity, additional morph targets, and source material IDs are lost. Skinned and IDE `anim` models are skipped. Invalid triangles are silently omitted from the soup. |
| Normals | Source morph-target-0 normals when `rw::Geometry::NORMALS` is set | Every normal is normalized. Missing/degenerate normals are generated from the face and are indistinguishable from authored normals in the API. This does not meet strict “preserve normals” diagnostics without added provenance/counters. |
| UV | UV set 0 | UV sets 1-7 are lost. Missing UV is replaced by `(0,0)` and cannot be distinguished from authored zero UV. |
| Day prelight | Geometry RGBA copied per emitted vertex | Missing prelight becomes RW-semantic black for lit geometry or white for unlit geometry, but the API has no “missing” bit. |
| Night prelight | Raw Rockstar extension `0x253F2F9` is parsed by `ReadNightColors` and copied per vertex | If absent, night is filled with day, so “no night stream” is not observable. The parser assumes the audited clump/geometry/atomic chunk ordering; unsupported layout rejects the whole model. |
| Material | Per-triangle texture index, RGB `triCol`; with streamed mode, ambient, diffuse, and conditional RGBA in `WorldShotSurface` | Material identity/name, specular, pipeline identity, MatFX/env map, UV animation, 2dfx and family are absent. `surface.color` uses authored material RGBA only when `rw::Geometry::MODULATE` is set; otherwise it remains white. |
| Texture | Mip-0 RGBA8, name, dimensions, and DFF `filterAddressing` | Mip levels and mask name are not exported. Decoder accepts D3D8/9 native DXT1, DXT3, A8R8G8B8 and X8R8G8B8 only; DXT2/4/5, paletted, 16-bit and unknown formats become `triImg=-2`. No source color-space tag is exported. |
| Sampler | Packed RW filter plus independent U/V address fields (`VVVVUUUU FFFFFFFF`) | Preservation ends at metadata. Godot's mapping and filtered seam behavior require renderer tests; `WorldShotImage::filter` alone is not visual proof. |
| Alpha class | Vertex alpha, texture alpha bytes, and conditional material alpha are available | There is no world `opaque`/`cutout`/`blend` classification. `WorldShotSurface::vehicleAlpha` is vehicle-only and remains false for pager meshes. The native world baseline applies one global `GL_GREATER, 0.5` cutout test, not a source-backed world-family classifier. |

Additional confirmed pager differences:

- `ParseIdeText` reads only the leading model/TXD fields for `objs`, `tobj`, and
  `anim`. It discards authored draw distances, object flags, mesh count, and related
  IDE metadata. Time-object models are indexed but not gated by their authored
  hours.
- The render index rejects every model name beginning with `lod`, ignores authored
  `inst.lod` links for selection, and caps nearest instances by distance. Radius,
  the 300 m grid, 100 m hysteresis, 80-instance default, and sparse-window widening
  to 750 m are lab pager policy, not SA's authored streaming/LOD algorithm.
- A Grove Street frame can therefore contain source near geometry, but “distant
  context,” source LOD transitions, or no-pop motion are not confirmed by this API.
- During DFF linking, the IDE-named TXD is primary, then every other currently
  resident TXD is searched as a fallback. A same-named texture in an unrelated TXD
  can satisfy a missing primary reference. Scene-level image deduplication then uses
  only `WorldShotImage::name`, so equal names from different dictionaries can alias
  different bytes or sampler state. Both behaviors must be detected before claiming
  texture retention.

The adapter's coordinate conversion `(X,Y,Z) -> (X,Z,-Y)` is a proper-axis rotation
and preserves winding if applied equally to positions and normals. That mathematical
fact is confirmed; byte-for-byte round-trip, culling, front-face, UV orientation,
and Godot image-row orientation remain runtime tests.

## Material-family and alpha blocker

The current `WorldShotScene` is sufficient to build visible Godot surfaces but not
to assign source-authoritative `building`, `road`, `vegetation`, `cutout`, and
`blend` labels. Neither IPL/IDE family data nor RenderWare pipeline/material identity
survives flattening. Texture-alpha inspection can prove that alpha bytes exist, but
cannot by itself prove whether the original renderer treated a material as cutout or
ordered blend.

For the bounded demo, the adapter must do one of the following before a fidelity
claim:

1. Minimally extend the reader output with source material/atomic identity and the
   exact evidence used to choose family/alpha mode, then test it against known source
   models.
2. Ship a deterministic heuristic only as an explicitly reported approximation,
   include per-category counts/names in diagnostics, and keep G3 material/alpha
   fidelity marked pending.

Silently labelling every pager surface `building` or inferring all non-255 textures
as `cutout` would make the demo runnable but would violate the visual contract.

## Day, night, weather, and environment

`TimeCycle.cpp::TimeCycle_LoadWeatherHour` is standalone and source-backed, but it is
a deliberately reduced parser. It retains timecyc tokens 0-17 (ambient, object
ambient, unused Dir RGB, sky top/bottom, sun core), 27-28 (far/fog), 30-32 (low
cloud), 36-39 (water RGBA), and optional 51 (directional multiplier). It does not
publish source tokens 18-26, 29, 33-35, or 40-50: sun corona, sun/sprite sizes and
brightness, shadow strengths, light-on-ground, fluffy-cloud bottom, both PostFX
colors/alphas, cloud alpha, highlight threshold, and water fog alpha.

`TimeCycle_LoadWeatherHour` selects a floor anchor from
`{0,5,6,7,12,19,20,22,24}`; it does not interpolate. The useful interpolation and
night-balance implementation is in `RealtimeEnvironment::SetHour`:

- fixed-weather anchor interpolation, including 22:00 to midnight;
- world/object ambient and sky/water/fog interpolation;
- directional light from token 51, multiplied by `0.99609375`;
- fixed sun-light direction `(-0.5,-0.5,sqrt(0.5))`;
- building night balance: 1 before 06:00, ramps to 0 by 07:00, stays 0 until 20:00,
  ramps to 1 by 21:00, then stays 1.

That function cannot be linked alone because it shares `RealtimeEnvironment.cpp`
with compatibility OpenGL. The bounded adapter should implement a CPU-only provider
using the eight `TimeCycleParams` anchors and the same formulas, or first extract
those formulas into a GL-free source unit shared by both backends. Linking the whole
realtime implementation and merely avoiding `Upload/Draw` still introduces GL
symbols and is not an acceptable proof that Godot owns presentation.

Even the realtime provider is not full `CTimeCycle::CalcColoursForPoint` parity. It
uses fixed old==new weather and omits weather transitions, timecycle boxes,
extra-colour overrides, camera/corona brightness effects, fog reduction,
underwater/tunnel blends, dynamic sun sprite direction, and most sky/post effects.
Its sky dome is a native presentation approximation. These omissions are confirmed
by `RealtimeEnvironment.h` and by comparison with
`source/game_sa/TimeCycle.cpp::CalcColoursForPoint`.

**Immediate blocker:** `godot/lab.gd` and `godot/tests/lab_smoke.gd` request
`RAINY_LA`. There is no `RAINY_LA` in
`source/game_sa/Enums/eWeatherType.h` or in
`RealtimeEnvironment.cpp::kFixedWeather`. The LA source set has `CLOUDY_LA`; rainy
source sections exist for SF and countryside. Use `CLOUDY_LA` for the contract's
allowed “overcast or rainy” Grove Street state, or deliberately use `RAINY_SF` and
label the cross-region weather. Do not fabricate a `RAINY_LA` alias.

The existing material lane correctly leaves post unavailable. No source-backed
PostFX operation can be produced from `TimeCycleParams`, because its public struct
does not retain tokens 40-47.

## Frozen pose fixtures

`CarPose` and `IfpAnim` are useful regression fixtures, not requirements for the
first world lab and not permission to expand into gameplay.

- `CarPose_Init` reads `<model>.dff/.txd` from `gta3.img`/`gta_int.img`, optional
  `models/generic/vehicle.txd`, and `data/carcols.dat`. It parses frame names from
  extension `0x253F2FE`, poses wheel dummies, and emits owned triangle soup. Its
  realtime vehicle mode carries day prelight and `WorldShotSurface` material/alpha
  metadata, but no night-prelight stream or original car env/specular pipeline.
- `IfpAnim_Init` reads a ped DFF/TXD plus loose `anim/<bank>.ifp` or
  `anim/anim.img:<bank>.ifp`, parses ANP2/ANP3, samples/retargets HAnim, and CPU-skins
  morph target 0. The legacy fixture output at its final flatten path carries
  positions, normalized normals, UV0, texture index and material RGB, but does not
  populate `dayColors`, `nightColors`, or `surfaces`. It must not be fed into the
  district material contract as though those attributes were present.
- Both share librw/OS global state with the pager. If retained as tests, run them in
  isolated processes or under one serialized lifecycle. Do not include them in the
  shipping extension until a lab acceptance check actually needs them.

## Confirmed facts versus assumptions

Confirmed by this source audit:

- the upstream hook/address/x86 boundary and the native compile-unit dependencies;
- the fields each public native output retains, substitutes, or drops;
- the GL calls in `RealtimeEnvironment.cpp`, NULL-platform librw configuration, and
  global ownership constraints;
- the absent world material-family/alpha classification, non-authored pager LOD
  policy, reduced timecycle schema, and invalid `RAINY_LA` enum/mapping;
- the matching upstream godot-cpp release identity for the intended binding commit.

Not confirmed and not to be promoted to fact:

- successful PIC compilation or GDExtension load with the intended toolchain;
- the absence of an unexpected `RAINY_LA` label or unsupported texture encoding in
  a particular user's modified game data; no asset corpus was read in this lane;
- that texture-name fallback selects the intended bytes in Grove Street, or that
  unchanged UV/image rows appear upright in Godot;
- any source-authoritative family/alpha labels inferred from model or texture names;
- exact original color-space, framebuffer, transparency, fog, sky, postprocessing,
  LOD, or motion equivalence;
- Fedora 44/Wayland/Mesa/RX 780M load, rendering, performance, or input behavior.

Retail-address comments and algorithm comparisons in the native files are repository
reverse-engineering evidence. This lane did not repeat binary disassembly and does
not elevate those comments into new independent executable proof.

## Required gates

These are bounded adapter tests, not new feature requirements.

1. **Pin gate:** record `Godot --version`, exact editor artifact SHA-256,
   godot-cpp commit `e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77`, native commit, and librw
   commit in build/run manifests. Fail configuration on mismatch.
2. **Link gate:** inspect the extension's dynamic dependencies. The reader extension
   may depend on Godot ABI support, libc/libstdc++, `libm`, and pthread support; it
   must not require Wine, SDL3, OpenAL, EGL, or a separate OpenGL context. The
   extension load and `open_game` path must not open `gta-sa.exe`.
3. **Read-only gate:** run against an externally selected read-only game directory,
   trace file opens, and compare hashes/mtimes before and after. No asset, decoded
   texture, cache, or capture may be written under that directory or packaged in the
   project.
4. **Pager contract gate:** initialize with `includeStreamed=true`, requested radius
   and cap. For every emitted mesh require exact cardinalities:
   `pos=nrm=tris*9`, `uv=tris*6`, `triImg=surfaces=tris`,
   `triCol=tris*3`, and `dayColors=nightColors=tris*12`. Require each image to have
   `rgba=w*h*4`; report `-1` and `-2` triangle counts rather than hiding misses.
5. **Determinism/bounds gate:** repeat the same Grove center and compare scene hashes,
   model/texture counts, cell loads/evictions, and triangle counts. Move over the
   route repeatedly and prove instance cap plus retirement; report sparse-window
   fallback and memory growth separately.
6. **Conversion gate:** round-trip representative position/normal values through
   `(X,Y,Z) <-> (X,-Z,Y)`, verify preserved front faces, and compare known UV/image
   orientation against the native reader output. No normal regeneration may occur in
   Godot.
7. **Texture gate:** report source format, filter/address bits, mip loss, unsupported
   decodes, duplicate names across TXDs, and primary-versus-fallback resolution.
   Reject silent same-name image aliasing.
8. **Material gate:** prove triangle conservation while splitting Godot surfaces;
   record the source evidence for every family and alpha category. Exercise opaque,
   cutout and blend with actual source alpha, not only synthetic shader fixtures.
9. **Day/night gate:** use at least one real building with unequal day/night bytes;
   compare exported RGBA before Godot upload and verify anchor values plus the
   06-07/20-21 night ramps. A model whose night bytes equal day does not prove the
   night path.
10. **Weather gate:** test `EXTRASUNNY_LA` and `CLOUDY_LA` exact anchors and one
    fractional-hour interpolation against an independent numeric oracle. Assert that
    `RAINY_LA` fails rather than aliases another section.
11. **Godot data gate:** round-trip ArrayMesh day color, custom night RGBA, normals,
    UV, surface count and texture bytes. Record Forward+/Vulkan and Compatibility
    separately; a headless data pass is not render evidence.
12. **Target gate:** Fedora 44, Wayland, Mesa and RX 780M renderer/driver,
    framebuffer captures, route timings and memory remain user-host evidence. They
    cannot be inferred from this server or from the native GL baseline.

## Integration decision

Proceed with `StreamPager + TexSample + oswrapper_linux + librw(NULL)` and a
GL-free timecycle provider behind the pinned Godot 4.5 GDExtension. Preserve
`mad-sa-linux` unchanged as the regression reference. Keep `WorldShot`, `CarPose`,
and `IfpAnim` as frozen process-isolated fixtures. Before calling the demo visually
faithful, resolve or explicitly diagnose the source material-family/alpha boundary,
same-name TXD aliasing, missing normal/UV provenance, source LOD omission, and the
invalid `RAINY_LA` state.

External identity references:

- <https://github.com/godotengine/godot-cpp/releases/tag/godot-4.5-stable>
- <https://godotengine.org/download/archive/4.5-stable/>
