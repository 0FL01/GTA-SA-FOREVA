# Legacy material API

`LegacyMaterials` is the presentation adapter for Godot 4.5. Runtime code supplies source-normalized values; the factory does not read assets or reinterpret them as PBR inputs.

## Mesh contract

- Convert SA positions and normals with `(X, Y, Z) -> (X, Z, -Y)` before creating the `ArrayMesh`. UVs are unchanged.
- Store source day RGBA in `Mesh.ARRAY_COLOR` and source night RGBA float in `Mesh.ARRAY_CUSTOM0`. Set custom channel 0 to `Mesh.ARRAY_CUSTOM_RGBA_FLOAT` in the surface format flags.
- Preserve one Godot surface per source material/alpha category. Do not merge opaque, cutout, and blend triangles.

## Factory calls

The public API is exactly:

```gdscript
static func make_surface(info: Dictionary) -> ShaderMaterial
static func set_environment(materials: Array, environment: Dictionary, flags: Dictionary) -> void
static func make_sky() -> ShaderMaterial
const POST_AVAILABLE := false
```

```gdscript
var material := LegacyMaterials.make_surface({
	"texture": texture, # Texture2D or null
	"color": source_material_color,
	"ambient": source_surface_ambient,
	"diffuse": source_surface_diffuse,
	"alpha_mode": "opaque", # opaque, cutout, or blend
	"family": "building",
	"filter": filter_addressing,
})

var sky_material := LegacyMaterials.make_sky()
LegacyMaterials.set_environment(surface_materials + [sky_material], environment, flags)
```

`make_surface()` requires all seven shown keys. `texture` is a `Texture2D` or `null`; `color` is a source-normalized `Color`; `ambient` and `diffuse` are numeric source surface coefficients; `alpha_mode` is exactly `opaque`, `cutout`, or `blend`; `family` is a string identity; and `filter` is the RenderWare `filterAddressing` integer. Recognized world-lighting families are `building`, `road`, `vegetation`, and `world`. Recognized object-lighting families are `vehicle`, `character`, and `object`. Other names render with the world formula and are explicitly reported by `legacy_family_status` metadata; water/effect parity is not claimed.

`environment` requires all ten keys: `ambient`, `ambient_objects`, `directional`, `sky_top`, and `sky_bottom` as source-normalized `Color` values; numeric `fog_start` and `far_clip`; `night_blend` in `[0, 1]`; `hour` in `[0, 24)`; and `weather` as a `String` or `StringName` manifest identity. `flags` requires all five boolean keys: `textures`, `prelight`, `fog`, `post`, and `vertex_only`. Pass every material returned by this class, including the optional sky material, on every environment change; foreign materials are rejected. Assign `make_sky()` to `Sky.sky_material`, then assign that `Sky` to the scene `Environment` with background mode `BG_SKY`. `hour` and `weather` are recorded as material metadata; they do not independently derive or modify any color.

`LegacyMaterials.POST_AVAILABLE` / `POST_STATUS` refer only to an in-surface operation, which is unavailable. The integrated lab owns a separate CanvasLayer using `legacy_post.gdshader`: F5 enables the real source PC ColourFilter after the 3D framebuffer and before UI. Lab manifests record that layer's actual visibility and timecycle pass values; there is no PS2/radiosity/heat-haze claim.

`vertex_only` displays the day/night vertex-color mix directly: texture, material modulation, lighting, and fog are bypassed. Otherwise prelight RGB can be disabled independently while its authored alpha remains in the surface alpha product. Texture, prelight, and material alpha multiply for cutout/blend output.

## Source decisions

- The surface equation follows `RealtimeEnvironment.cpp`: mix day/night prelight, add ambient plus object-family directional Lambert at vertices, clamp, multiply source material color, multiply texture, then apply linear eye-depth fog toward `sky_bottom`.
- Arithmetic remains in normalized source-color space. `source_color` texture decoding is reversed for that arithmetic in Forward+, then the final RGB is converted to linear. Compatibility uses `OUTPUT_IS_SRGB` and emits source RGB directly. There is no tonemap, PBR response, grading, or generated material channel.
- RW filter/address bits are `VVVVUUUU FFFFFFFF`. Clamp/repeat variants for each of four Godot filter classes preserve point, bilinear, mipmapped-point, and trilinear behavior where Godot exposes it; the common both-axis wrap case uses a real repeating sampler so filtered seam taps wrap. Mipmapped source textures must retain their source mip levels, and the project must keep `rendering/textures/default_filters/use_nearest_mipmap_filter=false`; otherwise modes 5 and 6 no longer use linear mip interpolation. Independent mirror, clamp, transparent-black border, and mixed-axis addressing is implemented in the shader. RW modes 3-5 cannot all express their distinct mip selection with Godot sampler hints, and Godot has no mirrored-repeat sampler hint; approximations are listed in `legacy_sampler_diagnostics`. Invalid values use an explicit, reported fallback.
- Opaque never writes shader alpha. Cutout explicitly discards `alpha <= 0.5`, stays in the opaque pipeline, and writes depth, matching the native `GL_GREATER` world state without blending. Blend uses source-alpha blending, writes depth like the native alpha-atomic path, and explicitly discards only `alpha <= 0`; it does not use a positive Godot scissor threshold that would lose small positive products.
- Surface `legacy_post_available`/`enabled` remain false because post belongs to the separate framebuffer operation above, not each world material. `legacy_post.gdshader` computes the two additive SRCALPHA/ONE PC passes from one source image. Source RGB arithmetic and its output are covered by rendered pixel tests.

## Known differences

- Godot transparency is surface/object sorted rather than the native reference's stable per-triangle eye-depth ordering, so intersecting blend geometry can differ.
- Godot's custom `Sky` shader interpolates colors in the renderer's color path; the native compatibility sky interpolates already time-interpolated source values. This is a known renderer-path difference, not PS2 parity evidence.
- Godot sampler hints cannot independently select nearest versus linear mip-level interpolation for every RenderWare mode. Shader-emulated mirror/border/mixed wrap can also differ in filtered taps at boundaries. Material metadata records each approximation.
- Godot `Mesh.ARRAY_COLOR` is RGBA8. This is sufficient for source byte prelight, while `CUSTOM0` is explicitly RGBA float as required by the adapter contract.

Godot 4.5 API references: [spatial shaders](https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/spatial_shader.html), [shader uniform hints](https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/shading_language.html#uniforms), [shader includes](https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/shader_preprocessor.html#include), [ArrayMesh](https://docs.godotengine.org/en/4.5/classes/class_arraymesh.html), and [sky shaders](https://docs.godotengine.org/en/4.5/tutorials/shaders/shader_reference/sky_shader.html).
