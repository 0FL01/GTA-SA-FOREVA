extends SceneTree

const Factory := preload("res://materials/legacy_materials.gd")
const ROADS_CENTER_SA := Vector3(1532.054688, -1662.289063, 12.460938)
const LARGE_SOURCE_U := 27062702.0
const VIEWPORT_SIZE := Vector2i(96, 96)

var _bridge: Object
var _bridge_open := false
var _viewport: SubViewport


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("requires a rendering display", 2)
		return
	var options := _parse_options(OS.get_cmdline_user_args())
	if not options.ok:
		_fail(options.error, 2)
		return
	if not GDExtensionManager.is_extension_loaded("res://sa_legacy.gdextension"):
		var load_status := GDExtensionManager.load_extension("res://sa_legacy.gdextension")
		if load_status != GDExtensionManager.LOAD_STATUS_OK:
			_fail("cannot load standalone bridge (status %d)" % load_status, 3)
			return
	if not ClassDB.class_exists("SALegacyBridge"):
		_fail("SALegacyBridge is not registered", 3)
		return
	_bridge = ClassDB.instantiate("SALegacyBridge")
	if _bridge == null:
		_fail("SALegacyBridge could not be instantiated", 3)
		return
	for method in [&"open_game", &"load_region", &"environment", &"close_game"]:
		if not _bridge.has_method(method):
			_fail("SALegacyBridge is missing method %s" % method, 3)
			return
	var opened: Variant = _bridge.call("open_game", options.game_dir, 350.0, 256)
	if not _result_ok(opened):
		_fail("open_game failed: %s" % _result_error(opened), 4)
		return
	_bridge_open = true
	var region: Variant = _bridge.call("load_region", ROADS_CENTER_SA)
	if not _result_ok(region):
		_fail("roads14_lan load failed: %s" % _result_error(region), 4)
		return
	if not region.get("publication_revision") is int:
		_fail("roads14_lan result has no publication_revision", 4)
		return
	if not region.get("meshes") is Array or region.meshes.is_empty():
		_fail("roads14_lan result has no real meshes", 4)
		return
	var triangle := _extract_large_uv_triangle(region.meshes)
	if not triangle.ok:
		_fail(triangle.error, 4)
		return
	var environment: Variant = _bridge.call("environment", "EXTRASUNNY_LA", 12)
	if not _result_ok(environment):
		_fail("source environment failed: %s" % _result_error(environment), 4)
		return
	if not _valid_environment(environment):
		_fail("source environment result is malformed", 4)
		return
	var source_environment: Dictionary = environment

	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var world := Node3D.new()
	_viewport.add_child(world)
	var world_environment := WorldEnvironment.new()
	world_environment.environment = Environment.new()
	world_environment.environment.background_mode = Environment.BG_COLOR
	world_environment.environment.background_color = Color(0.9375, 0.0625, 0.8125, 1.0)
	world_environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_environment.environment.tonemap_exposure = 1.0
	world_environment.environment.glow_enabled = false
	world_environment.environment.fog_enabled = false
	world.add_child(world_environment)

	var material := Factory.make_surface(triangle.surface_info)
	Factory.set_environment(
		[material],
		source_environment,
		{"textures": true, "prelight": true, "fog": false, "post": false, "vertex_only": false},
	)
	var instance := MeshInstance3D.new()
	instance.mesh = triangle.mesh
	instance.set_surface_override_material(0, material)
	world.add_child(instance)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	var vertices: PackedVector3Array = triangle.vertices
	var center := (vertices[0] + vertices[1] + vertices[2]) / 3.0
	var normal := (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0])
	if not is_finite(normal.length()) or normal.length_squared() <= 0.00000001:
		_fail("large-UV source triangle is degenerate", 4)
		return
	normal = normal.normalized()
	var span := maxf(
		(vertices[1] - vertices[0]).length(),
		maxf((vertices[2] - vertices[1]).length(), (vertices[0] - vertices[2]).length()),
	)
	if not is_finite(span) or span <= 0.0:
		_fail("large-UV source triangle has invalid extent", 4)
		return
	var distance := maxf(span * 2.0, 1.0)
	camera.size = maxf(span * 1.5, 1.0)
	camera.near = maxf(distance / 1000.0, 0.001)
	camera.far = distance * 4.0
	camera.position = center + normal * distance
	world.add_child(camera)
	var camera_up := Vector3.UP
	if absf(normal.dot(camera_up)) > 0.9:
		camera_up = Vector3.FORWARD
	camera.look_at(center, camera_up)

	for frame in range(6):
		await process_frame
		await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != VIEWPORT_SIZE:
		_fail("SubViewport CPU readback is empty", 5)
		return
	var background := image.get_pixel(0, 0)
	var foreground_pixels := 0
	var finite_pixels := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if not _finite_color(pixel):
				_fail("SubViewport CPU readback contains a nonfinite pixel", 5)
				return
			finite_pixels += 1
			if _color_distance(pixel, background) > 2.0 / 255.0:
				foreground_pixels += 1
	if foreground_pixels <= 0:
		_fail("actual roads14_lan triangle produced no non-background pixels", 5)
		return
	var uploaded_arrays := (triangle.mesh as ArrayMesh).surface_get_arrays(0)
	var uploaded_uvs: PackedVector2Array = uploaded_arrays[Mesh.ARRAY_TEX_UV]
	var exact_u_seen := false
	for uv in uploaded_uvs:
		if not is_finite(uv.x) or not is_finite(uv.y):
			_fail("rendered surface contains a nonfinite UV", 5)
			return
		if uv.x == LARGE_SOURCE_U:
			exact_u_seen = true
	if not exact_u_seen:
		_fail("rendered surface did not retain exact U=27062702", 5)
		return

	var revision := int(region.publication_revision)
	_close_bridge()
	_viewport.free()
	_viewport = null
	print(
		"region-render-ok revision=%d finite_pixels=%d foreground_pixels=%d renderer=%s evidence=tiny-world-not-source-parity"
		% [revision, finite_pixels, foreground_pixels, RenderingServer.get_current_rendering_method()]
	)
	quit(0)


func _extract_large_uv_triangle(meshes: Array) -> Dictionary:
	for mesh_info_value in meshes:
		if not mesh_info_value is Dictionary:
			return {"ok": false, "error": "region returned malformed mesh metadata"}
		var mesh_info: Dictionary = mesh_info_value
		if not mesh_info.get("source_model") is String:
			return {"ok": false, "error": "region mesh is missing source_model identity"}
		if String(mesh_info.source_model).to_lower() != "roads14_lan":
			continue
		if not mesh_info.get("source_model_id") is int or not mesh_info.get("mesh") is ArrayMesh:
			return {"ok": false, "error": "roads14_lan identity or ArrayMesh is malformed"}
		if not mesh_info.get("surface_materials") is Array:
			return {"ok": false, "error": "roads14_lan surface material metadata is malformed"}
		var source_mesh: ArrayMesh = mesh_info.mesh
		var surface_materials: Array = mesh_info.surface_materials
		if surface_materials.size() != source_mesh.get_surface_count():
			return {"ok": false, "error": "roads14_lan surface material count mismatch"}
		for surface_index in range(source_mesh.get_surface_count()):
			if source_mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
				return {"ok": false, "error": "roads14_lan has a non-triangle surface"}
			var surface_info: Variant = surface_materials[surface_index]
			if not _valid_surface_info(surface_info):
				return {"ok": false, "error": "roads14_lan has malformed legacy surface metadata"}
			var arrays := source_mesh.surface_get_arrays(surface_index)
			if arrays.size() != Mesh.ARRAY_MAX:
				return {"ok": false, "error": "roads14_lan has malformed surface arrays"}
			var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
			var normals: Variant = arrays[Mesh.ARRAY_NORMAL]
			var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
			var colors: Variant = arrays[Mesh.ARRAY_COLOR]
			var night: Variant = arrays[Mesh.ARRAY_CUSTOM0]
			if not vertices is PackedVector3Array or vertices.size() % 3 != 0:
				return {"ok": false, "error": "roads14_lan vertices are malformed"}
			if not normals is PackedVector3Array or normals.size() != vertices.size():
				return {"ok": false, "error": "roads14_lan normals are malformed"}
			if not uvs is PackedVector2Array or uvs.size() != vertices.size():
				return {"ok": false, "error": "roads14_lan UVs are malformed"}
			if not colors is PackedColorArray or colors.size() != vertices.size():
				return {"ok": false, "error": "roads14_lan day colors are malformed"}
			if not night is PackedFloat32Array or night.size() != vertices.size() * 4:
				return {"ok": false, "error": "roads14_lan night colors are malformed"}
			for vertex_index in range(uvs.size()):
				var uv: Vector2 = uvs[vertex_index]
				if not is_finite(uv.x) or not is_finite(uv.y):
					return {"ok": false, "error": "roads14_lan published a nonfinite UV"}
				if uv.x != LARGE_SOURCE_U:
					continue
				var triangle_start := vertex_index - vertex_index % 3
				var extracted_arrays := []
				extracted_arrays.resize(Mesh.ARRAY_MAX)
				var extracted_vertices := PackedVector3Array()
				var extracted_normals := PackedVector3Array()
				var extracted_uvs := PackedVector2Array()
				var extracted_colors := PackedColorArray()
				var extracted_night := PackedFloat32Array()
				for source_vertex in range(triangle_start, triangle_start + 3):
					extracted_vertices.append(vertices[source_vertex])
					extracted_normals.append(normals[source_vertex])
					extracted_uvs.append(uvs[source_vertex])
					extracted_colors.append(colors[source_vertex])
					for channel in range(4):
						extracted_night.append(night[source_vertex * 4 + channel])
				extracted_arrays[Mesh.ARRAY_VERTEX] = extracted_vertices
				extracted_arrays[Mesh.ARRAY_NORMAL] = extracted_normals
				extracted_arrays[Mesh.ARRAY_TEX_UV] = extracted_uvs
				extracted_arrays[Mesh.ARRAY_COLOR] = extracted_colors
				extracted_arrays[Mesh.ARRAY_CUSTOM0] = extracted_night
				var extracted_mesh := ArrayMesh.new()
				var custom_flags := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
				extracted_mesh.add_surface_from_arrays(
					Mesh.PRIMITIVE_TRIANGLES,
					extracted_arrays,
					[],
					{},
					custom_flags,
				)
				if extracted_mesh.get_surface_count() != 1:
					return {"ok": false, "error": "Godot rejected the extracted source triangle"}
				return {
					"ok": true,
					"mesh": extracted_mesh,
					"vertices": extracted_vertices,
					"surface_info": surface_info,
				}
	return {"ok": false, "error": "no roads14_lan triangle retained exact finite U=27062702"}


func _valid_surface_info(info: Variant) -> bool:
	if not info is Dictionary:
		return false
	for key in [&"texture", &"color", &"ambient", &"diffuse", &"alpha_mode", &"family", &"filter", &"source_material_slot"]:
		if not info.has(key):
			return false
	return (
		(info.texture == null or info.texture is Texture2D)
		and info.color is Color
		and (info.ambient is float or info.ambient is int)
		and (info.diffuse is float or info.diffuse is int)
		and (info.alpha_mode is String or info.alpha_mode is StringName)
		and StringName(info.alpha_mode) in [&"opaque", &"cutout", &"blend"]
		and (info.family is String or info.family is StringName)
		and info.filter is int
		and info.source_material_slot is int
		and int(info.source_material_slot) >= 0
		and (not info.has("source_geometry") or (info.source_geometry is int and int(info.source_geometry) >= 0))
	)


func _valid_environment(environment: Variant) -> bool:
	if not environment is Dictionary:
		return false
	for key in [&"ambient", &"ambient_objects", &"directional", &"sky_top", &"sky_bottom"]:
		if not environment.get(key) is Color:
			return false
	for key in [&"fog_start", &"far_clip", &"night_blend", &"hour"]:
		var value: Variant = environment.get(key)
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
	return (
		(environment.get("weather") is String or environment.get("weather") is StringName)
		and not String(environment.weather).is_empty()
		and float(environment.night_blend) >= 0.0
		and float(environment.night_blend) <= 1.0
		and float(environment.hour) >= 0.0
		and float(environment.hour) < 24.0
	)


func _finite_color(color: Color) -> bool:
	return is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and is_finite(color.a)


func _color_distance(first: Color, second: Color) -> float:
	return maxf(
		absf(first.r - second.r),
		maxf(absf(first.g - second.g), maxf(absf(first.b - second.b), absf(first.a - second.a))),
	)


func _parse_options(args: PackedStringArray) -> Dictionary:
	var game_dir := "/game"
	var i := 0
	while i < args.size():
		if args[i] != "--game-dir":
			return {"ok": false, "error": "unknown region render option: %s" % args[i]}
		if i + 1 >= args.size() or args[i + 1].is_empty():
			return {"ok": false, "error": "--game-dir requires a non-empty path"}
		game_dir = _absolute_path(args[i + 1])
		i += 2
	if not DirAccess.dir_exists_absolute(game_dir):
		return {"ok": false, "error": "game directory does not exist: %s" % game_dir}
	return {"ok": true, "game_dir": game_dir}


func _absolute_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path).simplify_path()
	if path.is_absolute_path():
		return path.simplify_path()
	return OS.get_environment("PWD").path_join(path).simplify_path()


func _result_ok(result: Variant) -> bool:
	return result is Dictionary and bool(result.get("ok", false))


func _result_error(result: Variant) -> String:
	return str(result.get("error", "invalid result")) if result is Dictionary else "non-Dictionary result"


func _fail(message: String, code: int) -> void:
	_close_bridge()
	if _viewport != null and is_instance_valid(_viewport):
		_viewport.free()
		_viewport = null
	printerr("region-render-fail: %s" % message)
	quit(code)


func _close_bridge() -> void:
	if _bridge_open and _bridge != null:
		_bridge.call("close_game")
	_bridge_open = false
