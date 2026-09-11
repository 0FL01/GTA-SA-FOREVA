shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded, shadows_disabled, fog_disabled;

#include "res://materials/legacy_surface_common.gdshaderinc"

void fragment() {
	// Not writing ALPHA keeps this material in Godot's opaque pipeline.
	ALBEDO = legacy_surface_color(UV).rgb;
}
