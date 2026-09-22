class_name LegacyMaterials
extends RefCounted

const OPAQUE_SHADER := preload("res://materials/legacy_opaque.gdshader")
const CUTOUT_SHADER := preload("res://materials/legacy_cutout.gdshader")
const BLEND_SHADER := preload("res://materials/legacy_blend.gdshader")
const ENV_SHADER := preload("res://materials/legacy_env.gdshader")
const SKY_SHADER := preload("res://materials/legacy_sky.gdshader")

const POST_AVAILABLE := false
const POST_STATUS := "unavailable: no source-backed post operation installed"

const SURFACE_KEYS := [&"texture", &"color", &"ambient", &"diffuse", &"alpha_mode", &"family", &"filter"]
const ENVIRONMENT_KEYS := [
	&"ambient", &"ambient_objects", &"directional", &"sky_top", &"sky_bottom",
	&"fog_start", &"far_clip", &"night_blend", &"hour", &"weather",
]
const FLAG_KEYS := [&"textures", &"prelight", &"fog", &"post", &"vertex_only"]
const WORLD_FAMILIES := [&"building", &"road", &"vegetation", &"world"]
const OBJECT_FAMILIES := [&"vehicle", &"character", &"object"]


static func _raw_color(value: Color) -> Vector4:
	# Godot converts Color Variant uniforms to linear RGB in Forward+ even
	# without source_color. These uniforms are source-byte arithmetic, not
	# linear lighting colors; Vector4 preserves them in both renderers.
	return Vector4(value.r, value.g, value.b, value.a)


static func make_surface(info: Dictionary) -> ShaderMaterial:
	_require_keys(info, SURFACE_KEYS, "surface info")
	assert(info.texture == null || info.texture is Texture2D, "surface texture must be Texture2D or null")
	assert(info.color is Color, "surface color must be Color")
	assert(info.alpha_mode is String || info.alpha_mode is StringName, "surface alpha_mode must be a string")
	assert(info.family is String || info.family is StringName, "surface family must be a string")
	assert(info.ambient is float || info.ambient is int, "surface ambient must be numeric")
	assert(info.diffuse is float || info.diffuse is int, "surface diffuse must be numeric")
	assert(info.filter is int, "surface filter must be the RenderWare filterAddressing integer")

	var alpha_mode := StringName(info.alpha_mode)
	var matfx_type := int(info.get("matfx_type", 0))
	var env_texture := info.get("env_texture", null) as Texture2D
	var env_coefficient := float(info.get("env_coefficient", 0.0))
	var env_framebuffer_alpha := bool(info.get("env_framebuffer_alpha", false))
	assert(matfx_type == 0 || matfx_type == 2, "only discovered none/env MatFX families are supported")
	assert(env_coefficient >= 0.0 and is_finite(env_coefficient), "MatFX env coefficient must be finite and nonnegative")
	var shader: Shader
	if matfx_type == 2 and env_texture != null and env_coefficient > 0.0:
		shader = ENV_SHADER
	else:
		match alpha_mode:
			&"opaque":
				shader = OPAQUE_SHADER
			&"cutout":
				shader = CUTOUT_SHADER
			&"blend":
				shader = BLEND_SHADER
			_:
				assert(false, "unsupported alpha_mode: %s" % alpha_mode)
				shader = OPAQUE_SHADER

	var material := ShaderMaterial.new()
	material.shader = shader
	material.resource_name = "legacy_%s_%s" % [info.family, alpha_mode]
	material.set_shader_parameter(&"material_color", _raw_color(info.color))
	material.set_shader_parameter(&"surface_ambient", float(info.ambient))
	material.set_shader_parameter(&"surface_diffuse", float(info.diffuse))
	material.set_shader_parameter(&"legacy_env_texture", env_texture)
	material.set_shader_parameter(&"matfx_env_enabled", matfx_type == 2 and env_texture != null and env_coefficient > 0.0)
	material.set_shader_parameter(&"matfx_env_coefficient", env_coefficient)
	material.set_shader_parameter(&"matfx_env_framebuffer_alpha", env_framebuffer_alpha)

	var source_texture := info.texture as Texture2D
	for parameter in [
		&"legacy_texture_nearest_clamp", &"legacy_texture_linear_clamp",
		&"legacy_texture_nearest_mipmap_clamp", &"legacy_texture_linear_mipmap_clamp",
		&"legacy_texture_nearest_repeat", &"legacy_texture_linear_repeat",
		&"legacy_texture_nearest_mipmap_repeat", &"legacy_texture_linear_mipmap_repeat",
	]:
		material.set_shader_parameter(parameter, source_texture)

	var filter_addressing := int(info.filter)
	var filter_mode := filter_addressing & 0xff
	var diagnostics := PackedStringArray()
	material.set_shader_parameter(&"sampler_mode", _sampler_mode(filter_mode, diagnostics))
	var address_u := _address_mode((filter_addressing >> 8) & 0x0f, "U", diagnostics)
	var address_v := _address_mode((filter_addressing >> 12) & 0x0f, "V", diagnostics)
	material.set_shader_parameter(&"address_u", address_u)
	material.set_shader_parameter(&"address_v", address_v)
	if address_u == 2 || address_v == 2:
		diagnostics.append("RW mirror addressing is shader-emulated; filtered edge taps can differ")
	if address_u == 4 || address_v == 4:
		diagnostics.append("RW border addressing uses native-reference transparent black; filtered border taps can differ")
	if address_u != address_v && (address_u == 1 || address_v == 1):
		diagnostics.append("mixed-axis RW wrap is shader-emulated; filtered seam taps can differ")

	var family := StringName(info.family)
	var object_lighting := 0.0
	var family_status := "exact"
	if family in OBJECT_FAMILIES:
		object_lighting = 1.0
	elif family not in WORLD_FAMILIES:
		family_status = "unsupported; world-lighting fallback"
	material.set_shader_parameter(&"object_lighting", object_lighting)

	material.set_meta(&"legacy_role", &"surface")
	material.set_meta(&"legacy_alpha_mode", alpha_mode)
	material.set_meta(&"legacy_family", family)
	material.set_meta(&"legacy_family_status", family_status)
	material.set_meta(&"legacy_filter_addressing", filter_addressing)
	material.set_meta(&"legacy_sampler_diagnostics", diagnostics)
	material.set_meta(&"legacy_has_texture", source_texture != null)
	material.set_meta(&"legacy_matfx_type", matfx_type)
	material.set_meta(&"legacy_env_coefficient", env_coefficient)
	material.set_meta(&"legacy_post_available", POST_AVAILABLE)
	return material


static func set_environment(materials: Array, environment: Dictionary, flags: Dictionary) -> void:
	_require_keys(environment, ENVIRONMENT_KEYS, "environment")
	_require_keys(flags, FLAG_KEYS, "flags")
	for color_key in [&"ambient", &"ambient_objects", &"directional", &"sky_top", &"sky_bottom"]:
		assert(environment[color_key] is Color, "environment %s must be Color" % color_key)
	for number_key in [&"fog_start", &"far_clip", &"night_blend", &"hour"]:
		assert(environment[number_key] is float || environment[number_key] is int, "environment %s must be numeric" % number_key)
	assert(environment.weather is String || environment.weather is StringName, "environment weather must be a string")
	assert(float(environment.night_blend) >= 0.0 && float(environment.night_blend) <= 1.0, "environment night_blend must be in [0, 1]")
	assert(float(environment.hour) >= 0.0 && float(environment.hour) < 24.0, "environment hour must be in [0, 24)")
	for flag_key in FLAG_KEYS:
		assert(flags[flag_key] is bool, "flag %s must be bool" % flag_key)

	for candidate in materials:
		assert(candidate is ShaderMaterial, "materials must contain only ShaderMaterial values")
		var material := candidate as ShaderMaterial
		var role: StringName = material.get_meta(&"legacy_role", &"")
		assert(role == &"surface" || role == &"sky", "material was not made by LegacyMaterials")
		material.set_meta(&"legacy_hour", float(environment.hour))
		material.set_meta(&"legacy_weather", String(environment.weather))
		material.set_meta(&"legacy_post_requested", bool(flags.post))
		material.set_meta(&"legacy_post_enabled", false)
		material.set_meta(&"legacy_post_status", POST_STATUS)

		material.set_shader_parameter(&"sky_bottom", _raw_color(environment.sky_bottom))
		if role == &"sky":
			material.set_shader_parameter(&"sky_top", _raw_color(environment.sky_top))
			continue

		material.set_shader_parameter(&"ambient", _raw_color(environment.ambient))
		material.set_shader_parameter(&"ambient_objects", _raw_color(environment.ambient_objects))
		material.set_shader_parameter(&"directional", _raw_color(environment.directional))
		material.set_shader_parameter(&"fog_start", float(environment.fog_start))
		material.set_shader_parameter(&"far_clip", float(environment.far_clip))
		material.set_shader_parameter(&"night_blend", float(environment.night_blend))
		material.set_shader_parameter(&"texture_enabled", bool(flags.textures) && bool(material.get_meta(&"legacy_has_texture")))
		material.set_shader_parameter(&"prelight_enabled", bool(flags.prelight))
		material.set_shader_parameter(&"fog_enabled", bool(flags.fog))
		material.set_shader_parameter(&"vertex_only", bool(flags.vertex_only))


static func make_sky() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("linear_output", RenderingServer.get_current_rendering_method() != "gl_compatibility")
	material.resource_name = "legacy_timecycle_sky"
	material.set_meta(&"legacy_role", &"sky")
	material.set_meta(&"legacy_post_available", POST_AVAILABLE)
	material.set_meta(&"legacy_post_status", POST_STATUS)
	return material


static func _sampler_mode(filter_mode: int, diagnostics: PackedStringArray) -> int:
	match filter_mode:
		1:
			return 0 # RW point sampling.
		2:
			return 1 # RW bilinear.
		3:
			diagnostics.append("RW nearest/nearest mip selection approximated by Godot nearest_mipmap")
			return 2
		4:
			diagnostics.append("RW linear/nearest mip selection approximated by Godot linear_mipmap")
			return 3
		5:
			diagnostics.append("RW nearest/linear mip selection uses Godot nearest_mipmap")
			return 2
		6:
			return 3 # RW trilinear.
		_:
			diagnostics.append("unsupported RW filter mode %d; explicit bilinear fallback" % filter_mode)
			return 1


static func _address_mode(mode: int, axis: String, diagnostics: PackedStringArray) -> int:
	if mode >= 1 && mode <= 4:
		return mode # wrap, mirror, clamp, transparent-black border.
	diagnostics.append("unsupported RW %s address mode %d; explicit clamp fallback" % [axis, mode])
	return 3


static func _require_keys(values: Dictionary, keys: Array, label: String) -> void:
	for key in keys:
		assert(values.has(key), "%s missing required key '%s'" % [label, key])
