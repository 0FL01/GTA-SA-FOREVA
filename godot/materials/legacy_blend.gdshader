shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, unshaded, shadows_disabled, fog_disabled;

#include "res://materials/legacy_surface_common.gdshaderinc"

void fragment() {
	vec4 color = legacy_surface_color(UV);
	// RenderAlphaAtomics uses a strict greater-than-zero alpha test.
	if (color.a <= 0.0) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
