extends SceneTree

const LegacyMaterials = preload("res://materials/legacy_materials.gd")
const GROVE_CENTER_SA := Vector3(2490.0, -1665.0, 14.0)
const SURFACE_INFO_KEYS := [&"texture", &"color", &"ambient", &"diffuse", &"alpha_mode", &"family", &"filter"]
const STATES := [
	["EXTRASUNNY_LA", 12],
	["EXTRASUNNY_LA", 19],
	["EXTRASUNNY_LA", 0],
	["CLOUDY_LA", 12],
]

var _bridge: Object
var _bridge_open := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not GDExtensionManager.is_extension_loaded("res://sa_legacy.gdextension"):
		if GDExtensionManager.load_extension("res://sa_legacy.gdextension") != GDExtensionManager.LOAD_STATUS_OK:
			_fail("cannot load standalone bridge", 3)
			return
	var options := _parse_options(OS.get_cmdline_user_args())
	if not options.ok:
		_fail(options.error, 2)
		return
	if not ClassDB.class_exists("SALegacyBridge"):
		_fail("SALegacyBridge is not registered", 3)
		return
	_bridge = ClassDB.instantiate("SALegacyBridge")
	if _bridge == null:
		_fail("SALegacyBridge could not be instantiated", 3)
		return
	for method in ["open_game", "load_region", "environment", "close_game"]:
		if not _bridge.has_method(method):
			_fail("SALegacyBridge is missing method %s" % method, 3)
			return

	var opened = _bridge.call("open_game", options.game_dir, options.radius, options.cap)
	if not _ok(opened):
		_fail("open_game failed: %s" % _error(opened), 4)
		return
	_bridge_open = true
	var region = _bridge.call("load_region", GROVE_CENTER_SA)
	if not _ok(region):
		_fail("load_region failed: %s" % _error(region), 4)
		return
	if not region.get("meshes") is Array or not region.get("stats") is Dictionary:
		_fail("load_region returned invalid meshes or stats", 4)
		return
	var meshes: Array = region.meshes
	if meshes.is_empty():
		_fail("load_region returned no real meshes", 4)
		return
	var surface_count := 0
	var materials: Array = []
	var grove_world := Vector2(GROVE_CENTER_SA.x, -GROVE_CENTER_SA.y)
	var world_coordinate_seen := false
	for mesh_info in meshes:
		if not mesh_info is Dictionary or not mesh_info.get("mesh") is ArrayMesh:
			_fail("load_region returned malformed mesh data", 4)
			return
		var mesh: ArrayMesh = mesh_info.mesh
		if mesh.get_surface_count() == 0:
			_fail("load_region returned an empty ArrayMesh", 4)
			return
		if not mesh_info.get("surface_materials") is Array:
			_fail("load_region returned invalid surface material metadata", 4)
			return
		var surface_materials: Array = mesh_info.surface_materials
		if surface_materials.size() != mesh.get_surface_count():
			_fail("surface material count does not match ArrayMesh surfaces", 4)
			return
		for surface_index in range(mesh.get_surface_count()):
			var surface_info_value: Variant = surface_materials[surface_index]
			if not _valid_surface_info(surface_info_value):
				_fail("load_region returned an invalid surface material", 4)
				return
			var surface_info: Dictionary = surface_info_value
			if int(surface_info.get("source_material_slot", -1)) < 0:
				_fail("source material slot identity was lost", 4)
				return
			if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
				_fail("load_region returned a non-triangle surface", 4)
				return
			var arrays := mesh.surface_get_arrays(surface_index)
			var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
			var normals: Variant = arrays[Mesh.ARRAY_NORMAL]
			var colors: Variant = arrays[Mesh.ARRAY_COLOR]
			var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
			var night: Variant = arrays[Mesh.ARRAY_CUSTOM0]
			if not vertices is PackedVector3Array:
				_fail("surface geometry is not a PackedVector3Array", 4)
				return
			if vertices.is_empty():
				_fail("surface has no source geometry", 4)
				return
			var source_vertices: PackedVector3Array = vertices
			if not normals is PackedVector3Array or normals.size() != source_vertices.size():
				_fail("surface normals were not preserved", 4)
				return
			if not colors is PackedColorArray or colors.size() != source_vertices.size():
				_fail("surface day prelight was not preserved", 4)
				return
			if not night is PackedFloat32Array or night.size() != source_vertices.size() * 4:
				_fail("surface night prelight RGBA was not preserved", 4)
				return
			if not uvs is PackedVector2Array or (not uvs.is_empty() and uvs.size() != source_vertices.size()):
				_fail("surface UV data is malformed", 4)
				return
			if surface_info.texture != null and uvs.size() != source_vertices.size():
				_fail("textured surface has no preserved UVs", 4)
				return
			if not world_coordinate_seen:
				for vertex in source_vertices:
					if Vector2(vertex.x, vertex.z).distance_to(grove_world) <= options.radius + 500.0:
						world_coordinate_seen = true
						break
			materials.append(LegacyMaterials.make_surface(surface_info))
		surface_count += mesh.get_surface_count()
	if not world_coordinate_seen:
		_fail("mesh vertices are not in the expected Grove world-coordinate basis X,Z,-Y", 4)
		return

	for state in STATES:
		var environment = _bridge.call("environment", state[0], state[1])
		if not _ok(environment):
			_fail("environment(%s,%d) failed: %s" % [state[0], state[1], _error(environment)], 4)
			return
		for key in ["ambient", "ambient_objects", "directional", "sky_top", "sky_bottom", "post_pass1", "post_pass2"]:
			if not environment.get(key) is Color:
				_fail("environment result has invalid %s" % key, 4)
				return
		for key in ["fog_start", "far_clip", "night_blend", "hour"]:
			var value: Variant = environment.get(key)
			if not (value is float or value is int) or not is_finite(float(value)):
				_fail("environment result has invalid %s" % key, 4)
				return
		if float(environment.night_blend) < 0.0 or float(environment.night_blend) > 1.0:
			_fail("environment night_blend is outside [0, 1]", 4)
			return
		if float(environment.hour) < 0.0 or float(environment.hour) >= 24.0:
			_fail("environment hour is outside [0, 24)", 4)
			return
		if not (environment.get("weather") is String or environment.get("weather") is StringName) or str(environment.weather).is_empty():
			_fail("environment result has no weather identity", 4)
			return
		var sky := LegacyMaterials.make_sky()
		LegacyMaterials.set_environment(
			materials + [sky],
			environment,
			{"textures": true, "prelight": true, "fog": true, "post": false, "vertex_only": false},
		)

	_close_bridge()
	print("lab-smoke-ok meshes=%d surfaces=%d states=%d render-evidence=none(headless-data-smoke)" % [meshes.size(), surface_count, STATES.size()])
	quit(0)


func _parse_options(args: PackedStringArray) -> Dictionary:
	var result := {"ok": false, "error": "", "game_dir": "", "radius": 350.0, "cap": 256}
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg not in ["--game-dir", "--radius", "--cap"]:
			result.error = "unknown smoke option: %s" % arg
			return result
		if i + 1 >= args.size():
			result.error = "%s requires a value" % arg
			return result
		i += 1
		var value := args[i]
		match arg:
			"--game-dir":
				if value.is_empty():
					result.error = "--game-dir requires a non-empty path"
					return result
				result.game_dir = _absolute_path(value)
			"--radius":
				if not value.is_valid_float():
					result.error = "--radius must be a positive finite number"
					return result
				var radius := value.to_float()
				if not is_finite(radius) or radius <= 0.0:
					result.error = "--radius must be a positive finite number"
					return result
				result.radius = radius
			"--cap":
				if not value.is_valid_int() or value.to_int() <= 0:
					result.error = "--cap must be positive"
					return result
				result.cap = value.to_int()
		i += 1
	if result.game_dir.is_empty():
		result.error = "--game-dir PATH is required"
		return result
	if not DirAccess.dir_exists_absolute(result.game_dir):
		result.error = "game directory does not exist: %s" % result.game_dir
		return result
	result.ok = true
	return result


func _absolute_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path).simplify_path()
	if path.is_absolute_path():
		return path.simplify_path()
	return OS.get_environment("PWD").path_join(path).simplify_path()


func _ok(result: Variant) -> bool:
	return result is Dictionary and result.get("ok", false)


func _valid_surface_info(info: Variant) -> bool:
	if not info is Dictionary:
		return false
	for key in SURFACE_INFO_KEYS:
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
	)


func _error(result: Variant) -> String:
	return str(result.get("error", "invalid result")) if result is Dictionary else "non-Dictionary result"


func _fail(message: String, code: int) -> void:
	_close_bridge()
	printerr("lab-smoke-fail: %s" % message)
	quit(code)


func _close_bridge() -> void:
	if _bridge_open and _bridge != null:
		_bridge.call("close_game")
	_bridge_open = false
