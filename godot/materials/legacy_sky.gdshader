shader_type sky;
render_mode disable_fog;

uniform vec4 sky_top = vec4(0.38, 0.55, 0.72, 1.0);
uniform vec4 sky_bottom = vec4(0.38, 0.55, 0.72, 1.0);
uniform bool linear_output = true;

void sky() {
	// RealtimeEnvironment grades only the upper hemisphere; the lower shell is SkyBot.
	vec3 rgb = mix(sky_bottom.rgb, sky_top.rgb, max(EYEDIR.y, 0.0));
	COLOR = linear_output ? mix(rgb / 12.92, pow((rgb + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), rgb)) : rgb;
}
