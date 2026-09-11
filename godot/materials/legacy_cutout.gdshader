shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded, shadows_disabled, fog_disabled;

#include "res://materials/legacy_surface_common.gdshaderinc"

void fragment() {
	vec4 color = legacy_surface_color(UV);
	// Native world state is GL_GREATER 0.5 with blending disabled.
	if (color.a <= 0.5) {
		discard;
	}
	ALBEDO = color.rgb;
}
