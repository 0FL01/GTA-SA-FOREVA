# SA Legacy Look Lab — visual contract

Status: active implementation contract; original-reference parity **unverified**.
Goal: [Godot Linux lab](goals/2026-09-11-godot-legacy-look-lab.md).
Source: [verbatim user request](goals/2026-09-11-godot-legacy-look-lab-request.md).

## Authority and provenance

- Restore SA's visual language; do not reinterpret it as a modern PBR city.
- Available data: user's legally owned classic PC SA installation, read-only. Record the hashes of actually used configuration files and the source commits in run manifests; do not distribute assets or screenshots in Git.
- PS2-oriented colour is the user's quoted **working hypothesis**, not an approved exact reference profile. No PS2 asset set or controlled original captures are supplied. Do not manufacture them or describe existing PC output as validated PS2.
- SkyGfx is a technical reference, not a drop-in runtime or an unconditional original-image oracle. No hook/address-based code in the standalone adapter.
- Keep original-version/configuration/weather/camera evidence separate from lab presentation improvements. Exact-reference comparison status stays pending until that evidence is available.

## Preserved data and intentional differences

- Preserve geometry, normals, UVs, material boundaries/colors, texture bytes after lossless format decoding, filter/wrap semantics, vertex alpha, and source day/night prelight. Coordinate-basis/winding conversion must be reversible and tested; no geometry repair masquerading as a conversion.
- Building, vehicle, character, cutout/vegetation, water and effect material families are not a universal StandardMaterial3D assignment. The first district need not implement absent water/effect systems, but must not claim parity for them.
- No texture upscale, replacement faces, generated PBR maps, arbitrary saturation/contrast grading, or normal regeneration. Missing data is an error/diagnostic, not an artistic tweak.
- Initial presentation: higher-resolution resizable Linux window and free inspection camera. Tonemapping/exposure and sampling explicitly fixed; no automatic exposure, strong bloom, chromatic aberration or grain to hide errors.
- Prefer Forward+ on the target GPU; record rendering backend and colour path. Compatibility captures are a distinct profile, not comparable by default.
- Check texture/prelight → colour conversion → legacy material → fog/post → display. Synthetic known-colour/alpha fixtures are diagnostic only; they cannot replace missing world assets.

## First district and controls

- Grove Street with surrounding geometry/distant context. Fixed camera/FOV and repeatable inspection route. Four named source-data environment states: clear day, evening, night, overcast/rainy. Weather transition uses one coherent environment state, not separately hand-tuned sky and fog.
- Component toggles: texture, prelight/day-night, fog, available postprocessing; a vertex-colour-only mode. An unavailable original post effect is labelled unavailable, not implemented no-op.
- Separate residency (loaded data), LOD selection (which representation), and fog/visibility (perceived distance). Expose current limitations and load counters. Do not claim authored-link census is working LOD.

## Capture and motion evidence

Each capture/run manifest records source/binary/engine identities, renderer/GPU/driver where observable, resolution, camera position/target/FOV, time/weather/blend, enabled components and relevant data hashes. Application framebuffer only, no unrelated desktop.

Repeat the route and record CPU frame intervals, available GPU metrics explicitly labelled, memory and resource/loading counters. Review long frames and growth across repeated passes; do not invent a target FPS or hide startup costs. Server software results are not RX780M results.

Compare controlled original/lab pairs when available; list known differences before subjective acceptance. Numerical image differences are evidence, not the sole artistic judge. Stills cannot certify motion/LOD/transparency/streaming. Journal labels automated, agent-image-reviewed and user-live-passed separately.

## Initial unresolved differences

- Implemented baseline: source PC district data, day/night channels, source material-slot boundaries, separate opaque/cutout/blend shaders, raw-colour uniform path, timecycle sky/fog and optional two-pass PC ColourFilter. Forward+/Compatibility known-colour and alpha-boundary checks are separate rendered oracles. No exposure/saturation repair was used for import bugs.
- Current reader closure retains the primary UV and decoded base texture level, not source mip chains/secondary UV/MatFX. Runtime LOD selection is absent; near/far representations may overlap, including visible z-fighting. Translucent sorting/blending and foliage sampling remain comparison risks. Original family-specific vehicle/character/water/effect presentation is not validated by this district-only demo.

- No controlled original PS2 or PC comparison set; screenshot from SkyGfx in the request is only a reference illustration.
- Full source material/LOD/post-effect equivalence remains to be established; no transfer of native viewer's partial validation to Godot without fresh tests.
- Fedora44/Wayland/Mesa/RX780M runtime, performance and physical input are not run on this server. A runnable delivery and a target test procedure are required independently.
