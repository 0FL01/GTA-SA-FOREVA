shader_type canvas_item;
render_mode unshaded, blend_disabled;

// PC CPostEffects::ColourFilter: two SRCALPHA/ONE draws of the same
// frontbuffer. Canvas is intentionally SDR; this arithmetic is source RGB.
// D3D's half-texel raster alignment is represented by pixel-centre sampling.
uniform sampler2D front_buffer : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 pass1;
uniform vec4 pass2;
void fragment() {
	vec3 scene = textureLod(front_buffer, SCREEN_UV, 0.0).rgb;
	COLOR = vec4(clamp(scene * (vec3(1.0) + pass1.rgb * pass1.a + pass2.rgb * pass2.a), vec3(0.0), vec3(1.0)), 1.0);
}
