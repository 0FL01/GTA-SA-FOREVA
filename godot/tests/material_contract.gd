extends SceneTree

const LegacyMaterialFactory := preload("res://materials/legacy_materials.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_mesh_contract()
	_test_factory_contract()
	_test_source_color_oracle()
	_test_shader_contract()
	if _failures.is_empty():
		print("material-contract-ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_mesh_contract() -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		Vector3(0.0, 0.0, -1.0),
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray([
		Color(0.25, 0.25, 0.25, 0.5),
		Color(0.5, 0.5, 0.5, 0.75),
		Color(0.75, 0.75, 0.75, 1.0),
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.UP])
	arrays[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array([
		0.75, 0.75, 0.75, 0.25,
		0.5, 0.5, 0.5, 0.5,
		0.25, 0.25, 0.25, 0.75,
	])
	var custom_flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, custom_flags)
	var recovered := mesh.surface_get_arrays(0)
	_check(recovered[Mesh.ARRAY_COLOR] is PackedColorArray, "day prelight uses ArrayMesh COLOR")
	_check(recovered[Mesh.ARRAY_CUSTOM0] is PackedFloat32Array, "night prelight uses ArrayMesh CUSTOM0 float")
	var recovered_night: PackedFloat32Array = recovered[Mesh.ARRAY_CUSTOM0]
	_check(recovered_night.size() == 12, "night prelight retains RGBA per vertex")
	var mapped_normal := (Vector3(1.0, 0.0, 0.0) - Vector3.ZERO).cross(Vector3(0.0, 0.0, -1.0) - Vector3.ZERO)
	_check(mapped_normal == Vector3.UP, "SA (X,Z,-Y) basis preserves triangle winding and mapped normal")
	var recovered_uv: PackedVector2Array = recovered[Mesh.ARRAY_TEX_UV]
	_check(recovered_uv[2] == Vector2.UP, "UVs remain unchanged")


func _test_factory_contract() -> void:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(0.5, 0.5, 0.5, 0.4))
	var texture := ImageTexture.create_from_image(image)
	var base_info := {
		"texture": texture,
		"color": Color(0.8, 0.8, 0.8, 0.6),
		"ambient": 0.5,
		"diffuse": 0.75,
		"alpha_mode": "opaque",
		"family": "building",
		"filter": 0x1102, # Bilinear, U/V wrap.
	}
	var opaque := LegacyMaterialFactory.make_surface(base_info)
	var cutout_info := base_info.duplicate()
	cutout_info.alpha_mode = "cutout"
	var cutout := LegacyMaterialFactory.make_surface(cutout_info)
	var blend_info := base_info.duplicate()
	blend_info.alpha_mode = "blend"
	blend_info.family = "vehicle"
	blend_info.filter = 0x3206 # Trilinear, U mirror, V clamp.
	var blend := LegacyMaterialFactory.make_surface(blend_info)
	_check(opaque.shader != cutout.shader && cutout.shader != blend.shader, "alpha modes must use distinct shaders")
	_check(opaque.get_shader_parameter(&"sampler_mode") == 1, "RW bilinear sampler mapping")
	_check(blend.get_shader_parameter(&"sampler_mode") == 3, "RW trilinear sampler mapping")
	_check(blend.get_shader_parameter(&"address_u") == 2, "RW mirror U mapping")
	_check(blend.get_shader_parameter(&"address_v") == 3, "RW clamp V mapping")
	_check(opaque.get_shader_parameter(&"object_lighting") == 0.0, "building world lighting family")
	_check(blend.get_shader_parameter(&"object_lighting") == 1.0, "vehicle object lighting family")
	var blend_diagnostics: PackedStringArray = blend.get_meta(&"legacy_sampler_diagnostics")
	_check(!blend_diagnostics.is_empty(), "shader-emulated mirror addressing is reported")

	var approximate_info := base_info.duplicate()
	approximate_info.filter = 0x1103
	var approximate := LegacyMaterialFactory.make_surface(approximate_info)
	var approximate_diagnostics: PackedStringArray = approximate.get_meta(&"legacy_sampler_diagnostics")
	_check(!approximate_diagnostics.is_empty(), "mip approximation is reported")

	var environment := {
		"ambient": Color(0.1, 0.1, 0.1, 1.0),
		"ambient_objects": Color(0.2, 0.2, 0.2, 1.0),
		"directional": Color(0.3, 0.3, 0.3, 1.0),
		"sky_top": Color(0.4, 0.5, 0.7, 1.0),
		"sky_bottom": Color(0.7, 0.6, 0.5, 1.0),
		"fog_start": 100.0,
		"far_clip": 800.0,
		"night_blend": 0.25,
		"hour": 20.5,
		"weather": "EXTRASUNNY_LA",
	}
	var flags := {"textures": true, "prelight": true, "fog": true, "post": true, "vertex_only": false}
	var sky := LegacyMaterialFactory.make_sky()
	LegacyMaterialFactory.set_environment([opaque, cutout, blend, sky], environment, flags)
	_check(opaque.get_shader_parameter(&"night_blend") == 0.25, "night blend publication")
	_check(opaque.get_shader_parameter(&"sky_bottom") == Vector4(0.7, 0.6, 0.5, 1.0), "raw fog color publication without Color uniform linearization")
	_check(sky.get_shader_parameter(&"sky_top") == Vector4(0.4, 0.5, 0.7, 1.0), "raw sky color publication without Color uniform linearization")
	_check(bool(opaque.get_shader_parameter(&"texture_enabled")), "texture flag publication")
	_check(bool(opaque.get_shader_parameter(&"prelight_enabled")), "prelight flag publication")
	_check(bool(opaque.get_shader_parameter(&"fog_enabled")), "fog flag publication")
	_check(!bool(opaque.get_shader_parameter(&"vertex_only")), "vertex-only flag publication")
	_check(opaque.get_meta(&"legacy_hour") == 20.5, "hour manifest metadata")
	_check(opaque.get_meta(&"legacy_weather") == "EXTRASUNNY_LA", "weather manifest metadata")
	_check(!LegacyMaterialFactory.POST_AVAILABLE, "public post capability is disabled")
	_check(!bool(opaque.get_meta(&"legacy_post_available")), "post remains unavailable")
	_check(bool(opaque.get_meta(&"legacy_post_requested")), "post request is diagnosed")
	_check(!bool(opaque.get_meta(&"legacy_post_enabled")), "post request is not a fake enabled operation")
	_check(String(opaque.get_meta(&"legacy_post_status")).begins_with("unavailable"), "post unavailability is labelled")


func _test_source_color_oracle() -> void:
	# Synthetic normalized source colors exercise day/night, material, texture, and alpha order.
	var day := Color(0.25, 0.25, 0.25, 0.5)
	var night := Color(0.75, 0.75, 0.75, 0.25)
	var prelight := day.lerp(night, 0.5)
	var light := Color(0.1, 0.1, 0.1) * 0.5
	var material := Color(0.8, 0.8, 0.8, 0.6)
	var texel := Color(0.5, 0.5, 0.5, 0.4)
	var rgb := (
		(Vector3(prelight.r, prelight.g, prelight.b) + Vector3(light.r, light.g, light.b))
		* Vector3(material.r, material.g, material.b)
		* Vector3(texel.r, texel.g, texel.b)
	)
	var alpha := prelight.a * material.a * texel.a
	_check(rgb.is_equal_approx(Vector3(0.22, 0.22, 0.22)), "legacy source RGB order oracle")
	_check(is_equal_approx(alpha, 0.09), "prelight/material/texture alpha oracle")


func _test_shader_contract() -> void:
	var common := _read_text("res://materials/legacy_surface_common.gdshaderinc")
	var opaque := _read_text("res://materials/legacy_opaque.gdshader")
	var cutout := _read_text("res://materials/legacy_cutout.gdshader")
	var blend := _read_text("res://materials/legacy_blend.gdshader")
	_check("mix(COLOR, CUSTOM0" in common, "shader consumes day COLOR and night CUSTOM0")
	_check("OUTPUT_IS_SRGB" in common, "Forward+/Compatibility conversion is explicit")
	_check("far_clip - legacy_eye_depth" in common, "fog uses linear eye depth")
	_check("* material_color" in common && "legacy_sample(uv)" in common, "material and texture modulation are retained")
	_check("ALPHA =" not in opaque, "opaque shader does not enter transparent pipeline")
	_check("depth_draw_opaque" in cutout && "color.a <= 0.5" in cutout, "cutout uses native strict alpha test and opaque depth writes")
	_check("ALPHA =" not in cutout && "depth_prepass_alpha" not in cutout, "cutout does not enter Godot's blended transparent pipeline")
	_check("depth_draw_always" in blend && "color.a <= 0.0" in blend, "blend writes depth and rejects only nonpositive alpha")
	_check("ALPHA_SCISSOR_THRESHOLD" not in blend, "blend retains every positive source-alpha product")


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "read shader source %s" % path)
	return file.get_as_text() if file != null else ""


func _check(condition: bool, message: String) -> void:
	if !condition:
		_failures.append(message)
