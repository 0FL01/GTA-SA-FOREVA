uniform sampler2D legacy_texture_nearest_clamp : source_color, filter_nearest, repeat_disable, hint_default_white;
uniform sampler2D legacy_texture_linear_clamp : source_color, filter_linear, repeat_disable, hint_default_white;
uniform sampler2D legacy_texture_nearest_mipmap_clamp : source_color, filter_nearest_mipmap, repeat_disable, hint_default_white;
uniform sampler2D legacy_texture_linear_mipmap_clamp : source_color, filter_linear_mipmap, repeat_disable, hint_default_white;
uniform sampler2D legacy_texture_nearest_repeat : source_color, filter_nearest, repeat_enable, hint_default_white;
uniform sampler2D legacy_texture_linear_repeat : source_color, filter_linear, repeat_enable, hint_default_white;
uniform sampler2D legacy_texture_nearest_mipmap_repeat : source_color, filter_nearest_mipmap, repeat_enable, hint_default_white;
uniform sampler2D legacy_texture_linear_mipmap_repeat : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D legacy_env_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_black;

uniform vec4 material_color = vec4(1.0);
uniform float surface_ambient = 1.0;
uniform float surface_diffuse = 1.0;
uniform float object_lighting = 0.0;

// Values are normalized source bytes, deliberately not source_color uniforms.
uniform vec4 ambient = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 ambient_objects = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 directional = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 sky_bottom = vec4(0.0, 0.0, 0.0, 1.0);
uniform float night_blend = 0.0;
uniform float fog_start = 0.0;
uniform float far_clip = 1000.0;

uniform int sampler_mode = 1;
uniform int address_u = 1;
uniform int address_v = 1;
uniform bool texture_enabled = true;
uniform bool prelight_enabled = true;
uniform bool fog_enabled = true;
uniform bool vertex_only = false;
uniform bool matfx_env_enabled = false;
uniform float matfx_env_coefficient = 0.0;
uniform bool matfx_env_framebuffer_alpha = false;

varying vec4 legacy_vertex_color;
varying float legacy_eye_depth;
varying vec2 legacy_env_uv;

// RealtimeEnvironment uses the fixed SA direction {-0.5,-0.5,sqrt(0.5)}.
// The adapter's SA -> Godot basis (X,Z,-Y) produces this world-space vector.
const vec3 LEGACY_DIRECTION_TO_SUN = vec3(-0.5, 0.70710678118, 0.5);

float legacy_address(float coordinate, int mode) {
	if (mode == 1) {
		return fract(coordinate);
	}
	if (mode == 2) {
		float phase = mod(coordinate, 2.0);
		return 1.0 - abs(phase - 1.0);
	}
	return clamp(coordinate, 0.0, 1.0);
}

bool legacy_border_outside(vec2 uv) {
	return (address_u == 4 && (uv.x < 0.0 || uv.x > 1.0))
		|| (address_v == 4 && (uv.y < 0.0 || uv.y > 1.0));
}

vec4 legacy_sample(vec2 source_uv) {
	if (!texture_enabled || vertex_only) {
		return vec4(1.0);
	}
	if (legacy_border_outside(source_uv)) {
		// Matches the native reference's default GL_CLAMP_TO_BORDER color.
		return vec4(0.0);
	}
	bool repeat_both = address_u == 1 && address_v == 1;
	vec2 addressed_uv = vec2(
		legacy_address(source_uv.x, address_u),
		legacy_address(source_uv.y, address_v)
	);
	if (sampler_mode == 0) {
		return repeat_both
			? texture(legacy_texture_nearest_repeat, source_uv)
			: texture(legacy_texture_nearest_clamp, addressed_uv);
	}
	if (sampler_mode == 2) {
		return repeat_both
			? texture(legacy_texture_nearest_mipmap_repeat, source_uv)
			: texture(legacy_texture_nearest_mipmap_clamp, addressed_uv);
	}
	if (sampler_mode == 3) {
		return repeat_both
			? texture(legacy_texture_linear_mipmap_repeat, source_uv)
			: texture(legacy_texture_linear_mipmap_clamp, addressed_uv);
	}
	return repeat_both
		? texture(legacy_texture_linear_repeat, source_uv)
		: texture(legacy_texture_linear_clamp, addressed_uv);
}

vec3 legacy_srgb_to_linear(vec3 color) {
	vec3 low = color / 12.92;
	vec3 high = pow((color + vec3(0.055)) / 1.055, vec3(2.4));
	return mix(high, low, lessThanEqual(color, vec3(0.04045)));
}

vec3 legacy_linear_to_srgb(vec3 color) {
	color = clamp(color, vec3(0.0), vec3(1.0));
	vec3 low = color * 12.92;
	vec3 high = 1.055 * pow(color, vec3(1.0 / 2.4)) - vec3(0.055);
	return mix(high, low, lessThanEqual(color, vec3(0.0031308)));
}

vec3 legacy_sample_to_source(vec3 sampled_color) {
	// source_color samplers are decoded by Forward+, but not Compatibility.
	return OUTPUT_IS_SRGB ? sampled_color : legacy_linear_to_srgb(sampled_color);
}

vec3 legacy_source_to_output(vec3 legacy_rgb) {
	return OUTPUT_IS_SRGB ? legacy_rgb : legacy_srgb_to_linear(legacy_rgb);
}

void vertex() {
	vec4 prelight = mix(COLOR, CUSTOM0, clamp(night_blend, 0.0, 1.0));
	legacy_eye_depth = abs((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z);
	vec3 normal_view = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	// librw standard MatFX: camera-space normal through the 0.5/-0.5
	// normal2tex matrix, followed by its fragment-stage V inversion.
	legacy_env_uv = vec2(normal_view.x * 0.5 + 0.5, normal_view.y * 0.5 + 0.5);
	if (vertex_only) {
		legacy_vertex_color = prelight;
	} else {
		vec3 normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
		float lambert = max(dot(normal_world, LEGACY_DIRECTION_TO_SUN), 0.0);
		vec3 selected_ambient = mix(ambient.rgb, ambient_objects.rgb, object_lighting);
		vec3 lighting = selected_ambient * surface_ambient
			+ directional.rgb * surface_diffuse * lambert * object_lighting;
		vec3 prelight_rgb = prelight_enabled ? prelight.rgb : vec3(0.0);
		legacy_vertex_color = vec4(clamp(prelight_rgb + lighting, vec3(0.0), vec3(1.0)), prelight.a)
			* material_color;
	}
}

vec4 legacy_surface_color(vec2 uv) {
	vec4 texel = legacy_sample(uv);
	vec4 legacy_rgba = legacy_vertex_color
		* vec4(legacy_sample_to_source(texel.rgb), texel.a);
	vec3 env_rgb = vec3(0.0);
	if (matfx_env_enabled && matfx_env_coefficient > 0.0) {
		vec4 env_texel = texture(legacy_env_texture, legacy_env_uv);
		env_rgb = legacy_sample_to_source(env_texel.rgb) * matfx_env_coefficient;
	}
	if (fog_enabled && !vertex_only) {
		float fog_span = max(far_clip - fog_start, 0.0001);
		float visibility = clamp((far_clip - legacy_eye_depth) / fog_span, 0.0, 1.0);
		legacy_rgba.rgb = mix(sky_bottom.rgb, legacy_rgba.rgb, visibility);
		env_rgb *= visibility;
	}
	if (matfx_env_enabled) {
		float framebuffer_alpha = max(legacy_rgba.a, matfx_env_framebuffer_alpha ? 0.0 : 1.0);
		legacy_rgba.rgb = legacy_rgba.rgb * legacy_rgba.a + env_rgb * framebuffer_alpha;
	}
	return vec4(legacy_source_to_output(legacy_rgba.rgb), legacy_rgba.a);
}
