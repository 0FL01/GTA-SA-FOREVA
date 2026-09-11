extends Node3D

const LegacyMaterials = preload("res://materials/legacy_materials.gd")

const FIXED_CAMERA_SA := Vector3(2495.0, -1685.0, 22.0)
const FIXED_TARGET_SA := Vector3(2490.0, -1665.0, 14.0)
const MOVE_SPEED := 22.0
const FAST_MULTIPLIER := 4.0
const MOUSE_SENSITIVITY := 0.0022
const ROUTE_SEGMENT_SECONDS := 6.0
const SURFACE_INFO_KEYS := [&"texture", &"color", &"ambient", &"diffuse", &"alpha_mode", &"family", &"filter"]
const REGION_ERROR_CONTEXT_KEYS := [&"archive", &"model", &"model_id", &"txd", &"placement_id", &"geometry", &"triangle", &"material_slot", &"uv_component", &"value"]

const ENVIRONMENT_STATES := [
	{"id": "EXTRASUNNY_LA12", "label": "Clear noon", "weather": "EXTRASUNNY_LA", "hour": 12},
	{"id": "EXTRASUNNY_LA19", "label": "Evening", "weather": "EXTRASUNNY_LA", "hour": 19},
	{"id": "EXTRASUNNY_LA0", "label": "Night", "weather": "EXTRASUNNY_LA", "hour": 0},
	{"id": "CLOUDY_LA12", "label": "Overcast noon", "weather": "CLOUDY_LA", "hour": 12},
]

const ROUTE_POINTS_SA := [
	{"eye": Vector3(2495.0, -1685.0, 22.0), "target": Vector3(2490.0, -1665.0, 14.0)},
	{"eye": Vector3(2320.0, -1662.0, 40.0), "target": Vector3(2490.0, -1660.0, 13.0)},
	{"eye": Vector3(2498.0, -1618.0, 20.0), "target": Vector3(2510.0, -1655.0, 13.0)},
	{"eye": Vector3(2650.0, -1677.0, 40.0), "target": Vector3(2500.0, -1680.0, 13.0)},
]

const CAPTURE_SCENARIOS := [
	{"id": "01_clear_day", "state": 0},
	{"id": "02_evening", "state": 1},
	{"id": "03_night", "state": 2},
	{"id": "04_overcast", "state": 3},
	{"id": "05_textures_off", "state": 0, "flag": "textures"},
	{"id": "06_prelight_off", "state": 0, "flag": "prelight"},
	{"id": "07_vertex_only", "state": 0, "enable": "vertex_only"},
	{"id": "08_fog_off", "state": 0, "flag": "fog"},
	{"id": "09_pc_colour_filter", "state": 0, "enable": "post"},
]

@onready var camera: Camera3D = $Camera3D
@onready var mesh_root: Node3D = $MeshRoot
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var status_label: Label = $Overlay/Status

var _bridge: Object
var _game_dir := ""
var _capture_dir := ""
var _radius := 350.0
var _cap := 256
var _seconds := -1.0
var _route_enabled := false
var _route_time := 0.0
var _route_segment := -1
var _route_environment_blend := -1.0
var _capture_index := 0
var _capture_pending := false
var _capture_hold := false
var _can_capture_images := false
var _elapsed := 0.0
var _previous_frame_usec := 0
var _wall_seconds := 0.0
var _frame_count := 0
var _yaw := 0.0
var _pitch := 0.0
var _mouse_look := false
var _loading := false
var _shutdown_started := false
var _bridge_open := false
var _last_overlay_update := -1.0
var _last_capture_at := -1.0
var _loaded_center_sa := Vector3.ZERO
var _has_published_region := false
var _publication_revision := 0
var _rejected_load_count := 0
var _last_region_error: Dictionary = {}
var _region_candidate_unavailable := false
var _region_retry_suppressed := false
var _failed_region_center_sa := Vector3.ZERO
var _accepted_camera_valid := false
var _accepted_camera_transform := Transform3D.IDENTITY
var _accepted_camera_target_world := Vector3.ZERO
var _accepted_camera_pitch := 0.0
var _accepted_camera_yaw := 0.0
var _camera_target_world := Vector3.ZERO
var _environment_index := 0
var _environment_data: Dictionary = {}
var _environment_cache: Array[Dictionary] = []
var _region_stats: Dictionary = {}
var _region_stats_csv := "{}"
var _open_metadata: Dictionary = {}
var _data_hashes: Dictionary = {}
var _bridge_binary_sha256 := "missing"
var _materials: Array = []
var _load_count := 0
var _open_game_stall_ms := 0.0
var _environment_cache_stall_ms := 0.0
var _last_bridge_load_call_ms := 0.0
var _total_load_stall_ms := 0.0
var _last_load_stall_ms := 0.0
var _resident_meshes := 0
var _resident_surfaces := 0
var _csv_file: FileAccess
var _sky_material: ShaderMaterial
var _post_rect: ColorRect
var _flags := {
	"textures": true,
	"prelight": true,
	"fog": true,
	"post": false,
	"vertex_only": false,
}


func _ready() -> void:
	# A clean asset-free package has no editor-generated extension_list.cfg.
	# Explicitly load its descriptor rather than shipping a build/import cache.
	if not GDExtensionManager.is_extension_loaded("res://sa_legacy.gdextension"):
		var load_status := GDExtensionManager.load_extension("res://sa_legacy.gdextension")
		if load_status != GDExtensionManager.LOAD_STATUS_OK:
			_fatal("GDExtension load failed (%d)" % load_status, 3)
			return
	if not _parse_cli():
		return
	if not _validate_renderer_profile():
		return
	if not _prepare_capture_directory():
		return
	_setup_environment()
	var post_layer := CanvasLayer.new()
	post_layer.layer = -1 # below diagnostic UI, above the 3D viewport
	add_child(post_layer)
	_post_rect = ColorRect.new()
	_post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_rect.material = ShaderMaterial.new()
	_post_rect.material.shader = preload("res://materials/legacy_post.gdshader")
	_post_rect.visible = false
	post_layer.add_child(_post_rect)
	_set_fixed_camera()
	if not _open_frame_csv():
		return

	if not ClassDB.class_exists("SALegacyBridge"):
		_fatal("SALegacyBridge is not registered; the GDExtension failed to load", 3)
		return
	_bridge = ClassDB.instantiate("SALegacyBridge")
	if _bridge == null:
		_fatal("ClassDB could not instantiate SALegacyBridge", 3)
		return
	for method in ["open_game", "load_region", "environment", "close_game"]:
		if not _bridge.has_method(method):
			_fatal("SALegacyBridge is missing method %s" % method, 3)
			return

	var open_started := Time.get_ticks_usec()
	var opened: Variant = _bridge.call("open_game", _game_dir, _radius, _cap)
	_open_game_stall_ms = float(Time.get_ticks_usec() - open_started) / 1000.0
	if not _bridge_result_ok(opened, "open_game"):
		return
	_bridge_open = true
	_open_metadata = opened.duplicate(true)
	_open_metadata.erase("ok")
	_data_hashes = _collect_data_hashes()

	var environment_started := Time.get_ticks_usec()
	var environments_cached := _cache_environments()
	_environment_cache_stall_ms = float(Time.get_ticks_usec() - environment_started) / 1000.0
	if not environments_cached:
		return
	if not _load_region(FIXED_TARGET_SA):
		return
	_apply_environment(_environment_cache[0], 0)
	_can_capture_images = DisplayServer.get_name().to_lower() != "headless"
	if FileAccess.file_exists("res://bin/libsa_legacy.so"):
		_bridge_binary_sha256 = FileAccess.get_sha256("res://bin/libsa_legacy.so")
	_write_run_manifest("run-start", false, "")
	_update_overlay()


func _process(delta: float) -> void:
	if _shutdown_started or not _bridge_open:
		return
	var now_usec := Time.get_ticks_usec()
	var wall_delta := 0.0 if _previous_frame_usec == 0 else float(now_usec - _previous_frame_usec) / 1000000.0
	_previous_frame_usec = now_usec
	_wall_seconds += wall_delta
	_frame_count += 1
	_elapsed += delta

	if not _capture_hold:
		if _route_enabled:
			_update_route(delta)
		else:
			_update_free_camera(delta)

	if not _capture_hold:
		_maybe_reload_region()
	_record_frame(wall_delta)

	if _route_enabled and not _capture_pending and _capture_index < CAPTURE_SCENARIOS.size():
		if _elapsed >= float(_capture_index + 1):
			_capture_pending = true
			call_deferred("_capture_scenario", _capture_index)

	if _last_overlay_update < 0.0 or _elapsed - _last_overlay_update >= 0.25:
		_update_overlay()
		_last_overlay_update = _elapsed

	if _seconds > 0.0 and _elapsed >= _seconds and _frame_count > 0 and not _capture_pending:
		_shutdown(0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_look = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_look else Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse_look and not _route_enabled:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clamp(_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
		camera.rotation = Vector3(_pitch, _yaw, 0.0)
		_camera_target_world = camera.global_position - camera.global_basis.z * 20.0
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if _mouse_look:
					_mouse_look = false
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				else:
					_shutdown(0)
			KEY_1, KEY_2, KEY_3, KEY_4:
				_route_enabled = false
				_apply_environment(_environment_cache[int(event.physical_keycode - KEY_1)], int(event.physical_keycode - KEY_1))
			KEY_F1:
				_toggle_flag("textures")
			KEY_F2:
				_toggle_flag("prelight")
			KEY_F3:
				_toggle_flag("vertex_only")
			KEY_F4:
				_toggle_flag("fog")
			KEY_F5:
				_toggle_flag("post")
			KEY_F6:
				if _region_candidate_unavailable and not _loading and not _capture_hold:
					_region_retry_suppressed = false
					_load_region(_failed_region_center_sa)
					_update_overlay()
			KEY_F12:
				if not _capture_pending:
					_capture_pending = true
					call_deferred("_capture_manual")
			KEY_R:
				if _route_enabled:
					_route_enabled = false
				else:
					_start_route()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_shutdown(0)


func _exit_tree() -> void:
	_shutdown_started = true
	_close_bridge()
	if _csv_file != null:
		_csv_file.flush()
		_csv_file.close()


func _parse_cli() -> bool:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var arg: String = args[i]
		match arg:
			"--route":
				_route_enabled = true
			"--game-dir", "--seconds", "--capture-dir", "--radius", "--cap":
				if i + 1 >= args.size():
					_fatal("%s requires a value" % arg, 2)
					return false
				i += 1
				var value: String = args[i]
				match arg:
					"--game-dir":
						if value.is_empty():
							_fatal("--game-dir requires a non-empty path", 2)
							return false
						_game_dir = _absolute_path(value)
					"--capture-dir":
						if value.is_empty():
							_fatal("--capture-dir requires a non-empty path", 2)
							return false
						_capture_dir = _absolute_path(value)
					"--seconds":
						if not value.is_valid_float():
							_fatal("--seconds must be a positive number", 2)
							return false
						var parsed_seconds := value.to_float()
						if not is_finite(parsed_seconds) or parsed_seconds <= 0.0:
							_fatal("--seconds must be a positive finite number", 2)
							return false
						_seconds = parsed_seconds
					"--radius":
						if not value.is_valid_float():
							_fatal("--radius must be a positive number", 2)
							return false
						var parsed_radius := value.to_float()
						if not is_finite(parsed_radius) or parsed_radius <= 0.0:
							_fatal("--radius must be a positive finite number", 2)
							return false
						_radius = parsed_radius
					"--cap":
						if not value.is_valid_int() or value.to_int() <= 0:
							_fatal("--cap must be a positive integer", 2)
							return false
						_cap = value.to_int()
			_:
				_fatal("unknown user option: %s" % arg, 2)
				return false
		i += 1

	if _game_dir.is_empty():
		_fatal("--game-dir PATH is required", 2)
		return false
	if not DirAccess.dir_exists_absolute(_game_dir):
		_fatal("game directory does not exist: %s" % _game_dir, 2)
		return false
	if _capture_dir.is_empty():
		_capture_dir = ProjectSettings.globalize_path("user://legacy-look-lab")
	var game_directory_prefix := _game_dir.trim_suffix("/") + "/"
	if _capture_dir == _game_dir or _capture_dir.begins_with(game_directory_prefix):
		_fatal("--capture-dir must not be the read-only game directory or one of its children", 2)
		return false
	return true


func _absolute_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path).simplify_path()
	if path.is_absolute_path():
		return path.simplify_path()
	return OS.get_environment("PWD").path_join(path).simplify_path()


func _validate_renderer_profile() -> bool:
	var engine_args := OS.get_cmdline_args()
	for i in range(engine_args.size() - 1):
		if engine_args[i] == "--display-driver" and engine_args[i + 1].to_lower() != DisplayServer.get_name().to_lower():
			_fatal("engine display fallback is not an accepted lab profile", 2)
			return false
	if DisplayServer.get_name().to_lower() == "headless":
		return true
	var active_method := RenderingServer.get_current_rendering_method()
	if active_method == "forward_plus":
		return true
	if active_method != "gl_compatibility":
		_fatal("unsupported rendering method %s; this lab defaults to Forward+" % active_method, 2)
		return false
	var args := OS.get_cmdline_args()
	for i in range(args.size()):
		if args[i] == "--rendering-method" and i + 1 < args.size() and args[i + 1] == "gl_compatibility":
			return true
		if args[i] == "--rendering-driver" and i + 1 < args.size() and args[i + 1] == "opengl3":
			return true
		if args[i] in ["--rendering-method=gl_compatibility", "--rendering-driver=opengl3"]:
			return true
	_fatal("Compatibility is a separate profile and must be selected explicitly", 2)
	return false


func _prepare_capture_directory() -> bool:
	var error := DirAccess.make_dir_recursive_absolute(_capture_dir)
	if error != OK and not DirAccess.dir_exists_absolute(_capture_dir):
		_fatal("cannot create capture directory %s (error %d)" % [_capture_dir, error], 2)
		return false
	var probe_path := _capture_dir.path_join(".write-probe")
	var probe := FileAccess.open(probe_path, FileAccess.WRITE)
	if probe == null:
		_fatal("capture directory is not writable: %s" % _capture_dir, 2)
		return false
	probe.store_string("application-owned capture directory\n")
	probe.close()
	DirAccess.remove_absolute(probe_path)
	return true


func _setup_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = 1.0
	environment.ambient_light_sky_contribution = 0.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.adjustment_enabled = false
	environment.glow_enabled = false
	environment.fog_enabled = false

	_sky_material = LegacyMaterials.make_sky()
	var sky := Sky.new()
	sky.sky_material = _sky_material
	environment.sky = sky
	world_environment.environment = environment


func _set_fixed_camera() -> void:
	camera.position = _sa_to_world(FIXED_CAMERA_SA)
	_camera_target_world = _sa_to_world(FIXED_TARGET_SA)
	camera.look_at(_camera_target_world, Vector3.UP)
	_pitch = camera.rotation.x
	_yaw = camera.rotation.y


func _cache_environments() -> bool:
	_environment_cache.clear()
	for state in ENVIRONMENT_STATES:
		var result: Variant = _bridge.call("environment", state.weather, state.hour)
		if not _bridge_result_ok(result, "environment(%s,%d)" % [state.weather, state.hour]):
			return false
		for key in ["ambient", "ambient_objects", "directional", "sky_top", "sky_bottom"]:
			if not result.get(key) is Color:
				_fatal("environment(%s,%d) returned invalid %s" % [state.weather, state.hour, key], 4)
				return false
		for key in ["fog_start", "far_clip", "night_blend", "hour"]:
			var value: Variant = result.get(key)
			if not (value is float or value is int) or not is_finite(float(value)):
				_fatal("environment(%s,%d) returned invalid %s" % [state.weather, state.hour, key], 4)
				return false
		if float(result.night_blend) < 0.0 or float(result.night_blend) > 1.0:
			_fatal("environment(%s,%d) returned night_blend outside [0, 1]" % [state.weather, state.hour], 4)
			return false
		if float(result.hour) < 0.0 or float(result.hour) >= 24.0:
			_fatal("environment(%s,%d) returned hour outside [0, 24)" % [state.weather, state.hour], 4)
			return false
		if not (result.get("weather") is String or result.get("weather") is StringName) or str(result.weather).is_empty():
			_fatal("environment(%s,%d) returned no weather identity" % [state.weather, state.hour], 4)
			return false
		_environment_cache.append(result.duplicate(true))
	return true


func _load_region(center_sa: Vector3) -> bool:
	if _loading or _shutdown_started:
		return false
	_loading = true
	var started := Time.get_ticks_usec()
	var result: Variant = _bridge.call("load_region", center_sa)
	_last_bridge_load_call_ms = float(Time.get_ticks_usec() - started) / 1000.0
	_load_count += 1
	_loading = false
	if not result is Dictionary:
		_fatal("load_region returned a non-Dictionary result", 4)
		return false
	var ok_value: Variant = result.get("ok")
	if not ok_value is bool:
		_fatal("load_region returned an invalid ok value", 4)
		return false
	if not ok_value:
		return _reject_region_candidate(center_sa, result)

	var revision_value: Variant = result.get("publication_revision")
	if not revision_value is int or int(revision_value) <= _publication_revision:
		_fatal("load_region returned a non-monotonic publication_revision", 4)
		return false

	var meshes_value: Variant = result.get("meshes")
	if not meshes_value is Array:
		_fatal("load_region returned a non-Array meshes value", 4)
		return false
	var meshes: Array = meshes_value
	if meshes.is_empty():
		_fatal("load_region returned no meshes; dummy/empty scenes are not success", 4)
		return false
	if not result.get("stats") is Dictionary:
		_fatal("load_region returned invalid stats", 4)
		return false
	for mesh_info in meshes:
		if not mesh_info is Dictionary:
			_fatal("load_region returned malformed mesh metadata", 4)
			return false
		var mesh_value: Variant = mesh_info.get("mesh")
		if not mesh_value is ArrayMesh or mesh_value.get_surface_count() == 0:
			_fatal("load_region returned an empty or invalid ArrayMesh", 4)
			return false
		var surface_materials_value: Variant = mesh_info.get("surface_materials")
		if not surface_materials_value is Array:
			_fatal("load_region returned non-Array surface material metadata", 4)
			return false
		var surface_materials: Array = surface_materials_value
		if surface_materials.size() != mesh_value.get_surface_count():
			_fatal("load_region surface material count does not match ArrayMesh surfaces", 4)
			return false
		for surface_info in surface_materials:
			if not surface_info is Dictionary:
				_fatal("load_region returned malformed surface material metadata", 4)
				return false
			for key in SURFACE_INFO_KEYS:
				if not surface_info.has(key):
					_fatal("load_region surface material is missing %s" % key, 4)
					return false
			if (
				(surface_info.texture != null and not surface_info.texture is Texture2D)
				or not surface_info.color is Color
				or not (surface_info.ambient is float or surface_info.ambient is int)
				or not (surface_info.diffuse is float or surface_info.diffuse is int)
				or not is_finite(float(surface_info.ambient))
				or not is_finite(float(surface_info.diffuse))
				or not _color_is_finite(surface_info.color)
				or not (surface_info.alpha_mode is String or surface_info.alpha_mode is StringName)
				or StringName(surface_info.alpha_mode) not in [&"opaque", &"cutout", &"blend"]
				or not (surface_info.family is String or surface_info.family is StringName)
				or not surface_info.filter is int
			):
				_fatal("load_region returned invalid surface material values", 4)
				return false

	var candidate_stats: Dictionary = result.stats.duplicate(true)
	var candidate_instances: Array[MeshInstance3D] = []
	var candidate_materials: Array = []
	var candidate_surfaces := 0
	for mesh_info in meshes:
		var mesh: ArrayMesh = mesh_info.mesh
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		var surface_materials: Array = mesh_info.surface_materials
		for surface_index in range(mesh.get_surface_count()):
			var material := LegacyMaterials.make_surface(surface_materials[surface_index])
			instance.set_surface_override_material(surface_index, material)
			candidate_materials.append(material)
			candidate_surfaces += 1
		candidate_instances.append(instance)

	_release_region()
	_region_stats = candidate_stats
	_region_stats_csv = JSON.stringify(_region_stats)
	_materials = candidate_materials
	_resident_meshes = candidate_instances.size()
	_resident_surfaces = candidate_surfaces
	for instance in candidate_instances:
		mesh_root.add_child(instance)
	_loaded_center_sa = center_sa
	_has_published_region = true
	_publication_revision = int(revision_value)
	_region_candidate_unavailable = false
	_region_retry_suppressed = false
	_remember_accepted_camera()
	if not _environment_data.is_empty():
		LegacyMaterials.set_environment(_environment_materials(), _environment_data, _flags)
	_last_load_stall_ms = float(Time.get_ticks_usec() - started) / 1000.0
	_total_load_stall_ms += _last_load_stall_ms
	return true


func _reject_region_candidate(center_sa: Vector3, result: Dictionary) -> bool:
	var revision_value: Variant = result.get("publication_revision")
	if not revision_value is int or int(revision_value) != _publication_revision:
		_fatal("failed load_region returned an invalid publication_revision", 4)
		return false

	_rejected_load_count += 1
	_last_region_error = _region_error_status(result, center_sa)
	_region_candidate_unavailable = true
	_failed_region_center_sa = center_sa
	_region_retry_suppressed = _has_published_region
	var human_error := str(_last_region_error.get("error", "unspecified bridge error"))
	if not _has_published_region:
		_fatal("load_region failed before the first publication: %s" % human_error, 4)
		return false

	_restore_accepted_camera()
	var code := str(_last_region_error.get("error_code", "uncoded"))
	printerr("legacy-look-lab: region candidate unavailable at %s; retaining publication %d: %s (%s)" % [center_sa, _publication_revision, human_error, code])
	_update_overlay()
	return false


func _region_error_status(result: Dictionary, center_sa: Vector3) -> Dictionary:
	var status := {
		"error": _bounded_status_string(result.get("error", "unspecified bridge error"), 320),
		"requested_center_sa": _status_vector_to_array(center_sa),
		"publication_revision": int(result.get("publication_revision", _publication_revision)),
	}
	var error_code: Variant = result.get("error_code")
	if error_code is String or error_code is StringName:
		status["error_code"] = _bounded_status_string(error_code, 80)
	var context_value: Variant = result.get("error_context")
	if context_value is Dictionary:
		var context := {}
		for key in REGION_ERROR_CONTEXT_KEYS:
			if not context_value.has(key):
				continue
			var value: Variant = context_value[key]
			if value is String or value is StringName:
				context[key] = _bounded_status_string(value, 160)
			elif value is float:
				context[key] = value if is_finite(value) else str(value)
			elif value is int or value is bool:
				context[key] = value
			else:
				context[key] = _bounded_status_string(value, 160)
		status["error_context"] = context
	return status


func _release_region() -> void:
	for child in mesh_root.get_children():
		mesh_root.remove_child(child)
		child.free()
	_materials.clear()
	_resident_meshes = 0
	_resident_surfaces = 0
	_region_stats.clear()
	_region_stats_csv = "{}"


func _bridge_result_ok(result: Variant, operation: String) -> bool:
	if not result is Dictionary:
		_fatal("%s returned a non-Dictionary result" % operation, 4)
		return false
	if not result.get("ok") is bool:
		_fatal("%s returned an invalid ok value" % operation, 4)
		return false
	if not result.ok:
		_fatal("%s failed: %s" % [operation, result.get("error", "unspecified bridge error")], 4)
		return false
	return true


func _apply_environment(data: Dictionary, state_index: int) -> void:
	_environment_data = data.duplicate(true)
	_environment_index = state_index
	var environment := world_environment.environment
	var sky_top: Color = _environment_data.get("sky_top", Color.BLACK)
	var sky_bottom: Color = _environment_data.get("sky_bottom", Color.BLACK)
	var ambient: Color = _environment_data.get("ambient", Color.BLACK)
	_sky_material.set_shader_parameter("sky_top", sky_top)
	_sky_material.set_shader_parameter("sky_bottom", sky_bottom)
	environment.ambient_light_color = ambient
	camera.far = max(1.0, float(_environment_data.get("far_clip", 800.0)))
	LegacyMaterials.set_environment(_environment_materials(), _environment_data, _flags)
	_update_post()


func _blended_environment(from_data: Dictionary, to_data: Dictionary, weight: float) -> Dictionary:
	var result := from_data.duplicate(true)
	for key in ["ambient", "ambient_objects", "directional", "sky_top", "sky_bottom", "post_pass1", "post_pass2"]:
		var from_color: Color = from_data.get(key, Color.BLACK)
		var to_color: Color = to_data.get(key, from_color)
		result[key] = from_color.lerp(to_color, weight)
	for key in ["fog_start", "far_clip", "night_blend"]:
		var from_value := float(from_data.get(key, 0.0))
		var to_value := float(to_data.get(key, from_value))
		result[key] = lerpf(from_value, to_value, weight)
	var from_hour := float(from_data.get("hour", 0.0))
	var hour_delta := fposmod(float(to_data.get("hour", from_hour)) - from_hour, 24.0)
	result["hour"] = fmod(from_hour + hour_delta * weight, 24.0)
	if weight <= 0.0:
		result["weather"] = from_data.get("weather", "unknown")
	elif weight >= 1.0:
		result["weather"] = to_data.get("weather", "unknown")
	else:
		result["weather"] = "%s -> %s" % [from_data.get("weather", "unknown"), to_data.get("weather", "unknown")]
	result["transition"] = weight
	return result


func _update_route(delta: float) -> void:
	_route_time += delta
	var segment := int(floor(_route_time / ROUTE_SEGMENT_SECONDS)) % ROUTE_POINTS_SA.size()
	var next_segment := (segment + 1) % ROUTE_POINTS_SA.size()
	var local_time := fmod(_route_time, ROUTE_SEGMENT_SECONDS) / ROUTE_SEGMENT_SECONDS
	var eased := smoothstep(0.0, 1.0, local_time)
	var from_point: Dictionary = ROUTE_POINTS_SA[segment]
	var to_point: Dictionary = ROUTE_POINTS_SA[next_segment]
	var eye_sa: Vector3 = from_point.eye.lerp(to_point.eye, eased)
	var target_sa: Vector3 = from_point.target.lerp(to_point.target, eased)
	camera.position = _sa_to_world(eye_sa)
	_camera_target_world = _sa_to_world(target_sa)
	camera.look_at(_camera_target_world, Vector3.UP)
	_pitch = camera.rotation.x
	_yaw = camera.rotation.y

	var transition := smoothstep(0.65, 1.0, local_time)
	if segment != _route_segment or absf(transition - _route_environment_blend) >= 0.025:
		var state := segment % ENVIRONMENT_STATES.size()
		var next_state := (state + 1) % ENVIRONMENT_STATES.size()
		_apply_environment(_blended_environment(_environment_cache[state], _environment_cache[next_state], transition), state)
		_route_segment = segment
		_route_environment_blend = transition


func _start_route() -> void:
	_route_enabled = true
	_route_time = 0.0
	_route_segment = -1
	_route_environment_blend = -1.0
	var first_point: Dictionary = ROUTE_POINTS_SA[0]
	camera.position = _sa_to_world(first_point.eye)
	_camera_target_world = _sa_to_world(first_point.target)
	camera.look_at(_camera_target_world, Vector3.UP)
	_pitch = camera.rotation.x
	_yaw = camera.rotation.y
	_apply_environment(_environment_cache[0], 0)


func _update_free_camera(delta: float) -> void:
	var movement := Vector3.ZERO
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	if Input.is_physical_key_pressed(KEY_W):
		movement += forward
	if Input.is_physical_key_pressed(KEY_S):
		movement -= forward
	if Input.is_physical_key_pressed(KEY_D):
		movement += right
	if Input.is_physical_key_pressed(KEY_A):
		movement -= right
	if Input.is_physical_key_pressed(KEY_E):
		movement += Vector3.UP
	if Input.is_physical_key_pressed(KEY_Q):
		movement -= Vector3.UP
	if not movement.is_zero_approx():
		var speed := MOVE_SPEED * (FAST_MULTIPLIER if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
		camera.global_position += movement.normalized() * speed * delta
		_camera_target_world = camera.global_position - camera.global_basis.z * 20.0


func _maybe_reload_region() -> void:
	var camera_sa := _world_to_sa(camera.global_position)
	var planar_delta := Vector2(camera_sa.x - _loaded_center_sa.x, camera_sa.y - _loaded_center_sa.y)
	var reload_threshold := _region_reload_threshold()
	if planar_delta.length() < reload_threshold:
		_remember_accepted_camera()
		if _region_retry_suppressed and _planar_region_distance(camera_sa, _failed_region_center_sa) >= reload_threshold:
			_region_retry_suppressed = false
		return
	if _region_retry_suppressed and _planar_region_distance(camera_sa, _failed_region_center_sa) < reload_threshold:
		_restore_accepted_camera()
		return
	_region_retry_suppressed = false
	_load_region(camera_sa)


func _region_reload_threshold() -> float:
	return maxf(50.0, _radius * 0.35)


func _planar_region_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x - second.x, first.y - second.y).length()


func _remember_accepted_camera() -> void:
	if not _has_published_region:
		return
	_accepted_camera_transform = camera.global_transform
	_accepted_camera_target_world = _camera_target_world
	_accepted_camera_pitch = _pitch
	_accepted_camera_yaw = _yaw
	_accepted_camera_valid = true


func _restore_accepted_camera() -> void:
	if not _accepted_camera_valid:
		return
	camera.global_transform = _accepted_camera_transform
	_camera_target_world = _accepted_camera_target_world
	_pitch = _accepted_camera_pitch
	_yaw = _accepted_camera_yaw


func _toggle_flag(flag: String) -> void:
	_flags[flag] = not bool(_flags[flag])
	LegacyMaterials.set_environment(_environment_materials(), _environment_data, _flags)
	_update_post()
	_update_overlay()


func _update_post() -> void:
	assert(_environment_data.has("post_pass1") and _environment_data.has("post_pass2"))
	_post_rect.visible = _flags.post
	for pass_index in [1, 2]:
		var color: Color = _environment_data["post_pass%d" % pass_index]
		_post_rect.material.set_shader_parameter("pass%d" % pass_index, Vector4(color.r, color.g, color.b, color.a))


func _capture_scenario(index: int) -> void:
	if index < 0 or index >= CAPTURE_SCENARIOS.size() or _shutdown_started:
		_capture_pending = false
		return
	_capture_hold = true
	var scenario: Dictionary = CAPTURE_SCENARIOS[index]
	var saved_flags := _flags.duplicate(true)
	var saved_environment := _environment_data.duplicate(true)
	var saved_environment_index := _environment_index
	var saved_camera_transform := camera.global_transform
	var saved_camera_target := _camera_target_world
	var saved_pitch := _pitch
	var saved_yaw := _yaw
	_flags = {"textures": true, "prelight": true, "fog": true, "post": false, "vertex_only": false}
	if scenario.has("flag"):
		_flags[scenario.flag] = false
	if scenario.has("enable"):
		_flags[scenario.enable] = true
	var state_index := int(scenario.state)
	_set_fixed_camera()
	_apply_environment(_environment_cache[state_index], state_index)
	if _loaded_center_sa.distance_to(FIXED_TARGET_SA) > 1.0:
		if not _load_region(FIXED_TARGET_SA):
			if _shutdown_started:
				return
			_flags = saved_flags
			_apply_environment(saved_environment, saved_environment_index)
			camera.global_transform = saved_camera_transform
			_camera_target_world = saved_camera_target
			_pitch = saved_pitch
			_yaw = saved_yaw
			_remember_accepted_camera()
			_capture_index = index + 1
			_capture_pending = false
			_capture_hold = false
			_update_overlay()
			_write_run_manifest(scenario.id, false, "", "skipped_region_unavailable", str(_last_region_error.get("error", "region candidate unavailable")))
			return
	await _capture_current(scenario.id)
	if _shutdown_started:
		return
	_last_capture_at = _elapsed
	_flags = saved_flags
	_apply_environment(saved_environment, saved_environment_index)
	camera.global_transform = saved_camera_transform
	_camera_target_world = saved_camera_target
	_pitch = saved_pitch
	_yaw = saved_yaw
	_capture_index = index + 1
	_capture_pending = false
	_capture_hold = false


func _capture_manual() -> void:
	if _shutdown_started:
		_capture_pending = false
		return
	_capture_hold = true
	await _capture_current("manual-%06d" % _frame_count)
	if _shutdown_started:
		return
	_capture_pending = false
	_capture_hold = false


func _capture_current(capture_id: String) -> void:
	_update_overlay()
	# Hold one immutable scene state through complete rendered frames. A single
	# process tick can still read the preceding queued framebuffer on Vulkan.
	for frame in range(3):
		await get_tree().process_frame
		if _can_capture_images:
			await RenderingServer.frame_post_draw
		if _shutdown_started:
			return
	var image_written := false
	var image_path := ""
	if _can_capture_images:
		image_path = _capture_dir.path_join("%s-%s.png" % [_profile_id(), capture_id])
		var image := get_viewport().get_texture().get_image()
		var save_error := image.save_png(image_path)
		if save_error != OK:
			_fatal("failed to save application framebuffer %s (error %d)" % [image_path, save_error], 5)
			return
		image_written = true
	_write_run_manifest(capture_id, image_written, image_path, "completed")


func _open_frame_csv() -> bool:
	var path := _capture_dir.path_join("%s-frame-times.csv" % _profile_id())
	_csv_file = FileAccess.open(path, FileAccess.WRITE)
	if _csv_file == null:
		_fatal("cannot open frame CSV: %s" % path, 5)
		return false
	_csv_file.store_line("frame,runtime_seconds,cpu_frame_interval_ms,cpu_process_ms,cpu_physics_ms,engine_static_memory_bytes,engine_static_memory_peak_bytes,resource_count,render_objects,render_primitives,render_draw_calls,route_enabled,capture_hold,route_clock_seconds,route_pass,route_pass_seconds,route_segment,environment_transition,open_game_sync_stall_ms,environment_cache_sync_stall_ms,load_count,last_bridge_load_call_ms,last_region_publication_stall_ms,total_region_publication_stall_ms,resident_meshes,resident_surfaces,bridge_region_stats_json,wall_seconds")
	return true


func _record_frame(delta: float) -> void:
	if _csv_file == null:
		return
	var route_duration := ROUTE_SEGMENT_SECONDS * ROUTE_POINTS_SA.size()
	var values := [
		_frame_count,
		"%.6f" % _elapsed,
		"%.4f" % (delta * 1000.0),
		"%.4f" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0),
		"%.4f" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0),
		int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		_route_enabled,
		_capture_hold,
		"%.6f" % _route_time,
		int(floor(_route_time / route_duration)),
		"%.6f" % fmod(_route_time, route_duration),
		_route_segment,
		"%.4f" % maxf(_route_environment_blend, 0.0),
		"%.4f" % _open_game_stall_ms,
		"%.4f" % _environment_cache_stall_ms,
		_load_count,
		"%.4f" % _last_bridge_load_call_ms,
		"%.4f" % _last_load_stall_ms,
		"%.4f" % _total_load_stall_ms,
		_resident_meshes,
		_resident_surfaces,
		_region_stats_csv,
		"%.6f" % _wall_seconds,
	]
	_csv_file.store_csv_line(PackedStringArray(values.map(func(value): return str(value))))
	if _frame_count % 60 == 0:
		_csv_file.flush()


func _write_run_manifest(capture_id: String, image_written: bool, image_path: String, capture_status := "not_requested", capture_note := "") -> void:
	var version := Engine.get_version_info()
	var viewport_size := get_viewport().get_visible_rect().size
	var state: Dictionary = ENVIRONMENT_STATES[_environment_index]
	var combined_hashes := _data_hashes.duplicate(true)
	var region_hashes: Variant = _region_stats.get("data_hashes", {})
	if region_hashes is Dictionary:
		combined_hashes.merge(region_hashes, true)
	var manifest := {
		"capture_id": capture_id,
		"capture_status": capture_status,
		"capture_note": capture_note,
		"evidence_profile": _profile_id(),
		"image_written": image_written,
		"image_source": "application framebuffer" if image_written else "none",
		"desktop_capture": false,
		"image_path": image_path,
		"headless_notice": "Headless execution does not produce rendered image evidence." if DisplayServer.get_name().to_lower() == "headless" else "",
		"comparison_status": "original_reference_missing",
		"parity_result": "not_evaluated",
		"original_parity_acceptance": "pending controlled original captures and discrepancy review",
		"target_gpu_acceptance": "pending user run on Fedora 44 / Wayland / Mesa / RX 780M",
		"engine": {
			"name": "Godot",
			"version": version.get("string", str(version)),
			"hash": version.get("hash", "unknown"),
			"executable": OS.get_executable_path(),
		},
		"renderer": {
			"configured_profile": ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"),
			"active_method": RenderingServer.get_current_rendering_method(),
			"active_driver": RenderingServer.get_current_rendering_driver_name(),
			"display_server": DisplayServer.get_name(),
			"backend_api": RenderingServer.get_video_adapter_api_version(),
			"gpu_name": RenderingServer.get_video_adapter_name(),
			"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
			"driver_info": OS.get_video_adapter_driver_info(),
			"sampling": {
				"msaa_3d": ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0),
				"screen_space_aa": ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa", 0),
				"taa": ProjectSettings.get_setting("rendering/anti_aliasing/quality/use_taa", false),
				"scaling_mode": ProjectSettings.get_setting("rendering/scaling_3d/mode", 0),
				"scaling_factor": ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0),
			},
		},
		"resolution": {"width": int(viewport_size.x), "height": int(viewport_size.y)},
		"camera": {
			"position_godot": _vector_to_array(camera.global_position),
			"position_sa": _vector_to_array(_world_to_sa(camera.global_position)),
			"target_godot": _vector_to_array(_camera_target_world),
			"target_sa": _vector_to_array(_world_to_sa(_camera_target_world)),
			"forward_godot": _vector_to_array(-camera.global_basis.z),
			"fov_degrees": camera.fov,
		},
		"environment": {
			"preset_id": state.id,
			"weather": _environment_data.get("weather", state.weather),
			"hour": _environment_data.get("hour", state.hour),
			"night_blend": _environment_data.get("night_blend", 0.0),
			"fog_start": _environment_data.get("fog_start", 0.0),
			"far_clip": _environment_data.get("far_clip", camera.far),
			"transition": _environment_data.get("transition", 0.0),
			"ambient": _color_to_array(_environment_data.get("ambient", Color.BLACK)),
			"ambient_objects": _color_to_array(_environment_data.get("ambient_objects", Color.BLACK)),
			"directional": _color_to_array(_environment_data.get("directional", Color.BLACK)),
			"sky_top": _color_to_array(_environment_data.get("sky_top", Color.BLACK)),
			"sky_bottom": _color_to_array(_environment_data.get("sky_bottom", Color.BLACK)),
		},
		"toggles": _flags.duplicate(true),
		"region_publication": {
			"active": _has_published_region,
			"active_publication_revision": _publication_revision,
			"active_center_sa": _vector_to_array(_loaded_center_sa) if _has_published_region else [],
			"candidate_status": "unavailable" if _region_candidate_unavailable else "none",
			"retry_suppressed": _region_retry_suppressed,
			"retry_control": "F6",
			"rejected_load_count": _rejected_load_count,
			"last_region_error": _last_region_error.duplicate(true),
			"collision_status": "unsupported; this viewer does not generate gameplay collision",
		},
		"post_effect": {
			"requested": _flags.post,
			"available": true,
			"enabled": _post_rect.visible,
			"status": "PC ColourFilter only; PS2 filter/radiosity/heat haze unavailable",
			"pass1_rgba": _color_to_array(_environment_data.get("post_pass1", Color.BLACK)),
			"pass2_rgba": _color_to_array(_environment_data.get("post_pass2", Color.BLACK)),
		},
		"bounded_residency": {
			"radius_sa_units": _radius,
			"cap": _cap,
			"resident_meshes": _resident_meshes,
			"resident_surfaces": _resident_surfaces,
			"load_count": _load_count,
			"rejected_load_count": _rejected_load_count,
			"active_publication_revision": _publication_revision,
			"publication": "synchronous bounded replacement; the previous complete publication remains active until a valid candidate is fully staged",
			"lod_status": "no Godot runtime LOD selection; source representation is whatever the bridge publishes",
		},
		"route": {
			"enabled": _route_enabled,
			"route_clock_seconds": _route_time,
			"segment_seconds": ROUTE_SEGMENT_SECONDS,
			"segments_per_pass": ROUTE_POINTS_SA.size(),
			"completed_passes": int(floor(_route_time / (ROUTE_SEGMENT_SECONDS * ROUTE_POINTS_SA.size()))),
			"measurement_source": "%s-frame-times.csv" % _profile_id(),
		},
		"measurements": {
			"frame_count": _frame_count,
			"runtime_seconds": _elapsed,
			"wall_seconds": _wall_seconds,
			"timing_label": "Monotonic CPU frame intervals (first=0); runtime/route seconds use engine delta, which may be capped. No GPU frame-time query is claimed",
			"open_game_synchronous_stall_ms": _open_game_stall_ms,
			"environment_cache_synchronous_stall_ms": _environment_cache_stall_ms,
			"last_bridge_load_call_ms": _last_bridge_load_call_ms,
			"last_region_publication_stall_ms": _last_load_stall_ms,
			"total_region_publication_stall_ms": _total_load_stall_ms,
		},
		"data_hashes": combined_hashes,
		"source_identity": {
			"lab_script_sha256": FileAccess.get_sha256("res://lab.gd"),
			"lab_scene_sha256": FileAccess.get_sha256("res://lab.tscn"),
			"project_sha256": FileAccess.get_sha256("res://project.godot"),
			"gdextension_descriptor_sha256": FileAccess.get_sha256("res://sa_legacy.gdextension"),
			"bridge_binary_sha256": _bridge_binary_sha256,
			"material_script_sha256": FileAccess.get_sha256("res://materials/legacy_materials.gd"),
			"surface_shader_sha256": FileAccess.get_sha256("res://materials/legacy_surface_common.gdshaderinc"),
			"sky_shader_sha256": FileAccess.get_sha256("res://materials/legacy_sky.gdshader"),
			"post_shader_sha256": FileAccess.get_sha256("res://materials/legacy_post.gdshader"),
		},
		"data_provenance": {
			"game_directory": _game_dir,
			"access": "external runtime source; assets are not exported by the lab",
			"configuration_hashes": combined_hashes,
		},
		"bridge_open_metadata": _open_metadata,
		"bridge_region_stats": _region_stats,
		"limitations": [
			"Region publication is synchronous and may hitch; no hitch-free streaming claim.",
			"Route frame intervals start after synchronous initialization; measured open/environment/load stalls are reported separately, while manifest hashing and driver discovery are not timed.",
			"Residency, absent Godot runtime LOD selection, and fog visibility are separate facts.",
			"Post toggle implements PC ColourFilter only; PS2 filter/radiosity/heat haze remain unavailable.",
			"Gameplay collision is unsupported; the viewer does not generate collision data.",
			"No controlled original capture was supplied, so discrepancy labels are not parity passes.",
			"Target Fedora 44 / Wayland / Mesa / RX 780M acceptance is pending a run on that hardware.",
		],
	}
	var path := _capture_dir.path_join("%s-%s.manifest.json" % [_profile_id(), capture_id])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fatal("cannot write manifest: %s" % path, 5)
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()


func _collect_data_hashes() -> Dictionary:
	var hashes := {}
	for relative_path in ["data/timecyc.dat", "data/gta.dat", "data/default.dat", "models/gta3.dir"]:
		var absolute_path := _game_dir.path_join(relative_path)
		if FileAccess.file_exists(absolute_path):
			hashes[relative_path] = FileAccess.get_sha256(absolute_path)
	return hashes


func _update_overlay() -> void:
	if status_label == null:
		return
	var state: Dictionary = ENVIRONMENT_STATES[_environment_index]
	var cpu_frame_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var memory_mib := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var renderer := RenderingServer.get_current_rendering_method()
	status_label.text = "SA LEGACY LOOK LAB | %s\n" % renderer
	status_label.text += "State %d: %s / %s @ %.2fh | route %s\n" % [_environment_index + 1, state.label, _environment_data.get("weather", state.weather), float(_environment_data.get("hour", state.hour)), "ON" if _route_enabled else "off"]
	status_label.text += "textures=%s prelight=%s vertex-only=%s fog=%s PC-filter=%s\n" % [_on_off(_flags.textures), _on_off(_flags.prelight), _on_off(_flags.vertex_only), _on_off(_flags.fog), _on_off(_flags.post)]
	status_label.text += "CPU process %.2f ms | engine static %.1f MiB | resources %d\n" % [cpu_frame_ms, memory_mib, int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))]
	status_label.text += "bounded radius %.0f cap %d | meshes %d surfaces %d | loads %d rejected %d | publication %d\n" % [_radius, _cap, _resident_meshes, _resident_surfaces, _load_count, _rejected_load_count, _publication_revision]
	status_label.text += "sync open %.2f ms | env %.2f ms | load+publish last %.2f ms total %.2f ms\n" % [_open_game_stall_ms, _environment_cache_stall_ms, _last_load_stall_ms, _total_load_stall_ms]
	if _region_candidate_unavailable:
		status_label.text += "REGION CANDIDATE UNAVAILABLE: %s | showing committed revision %d; F6 retry\n" % [_bounded_status_string(_last_region_error.get("error", "unspecified bridge error"), 180), _publication_revision]
	status_label.text += "WASD move  Q/E fall/rise  Shift fast  RMB look  Esc release/quit  R route\n"
	status_label.text += "1 clear  2 evening  3 night  4 overcast | F1-F4 diagnostics | F5 PC filter | F6 retry | F12 capture\n"
	status_label.text += "LOD unavailable | gameplay collision unsupported\n"
	status_label.text += "Original reference missing: discrepancy not measured; no parity pass."


func _fatal(message: String, code: int) -> void:
	if _shutdown_started:
		return
	printerr("legacy-look-lab: %s" % message)
	push_error(message)
	if status_label != null:
		status_label.text = "SA Legacy Look Lab failed\n%s" % message
	_shutdown_started = true
	call_deferred("_finish_shutdown", code)


func _shutdown(code: int) -> void:
	if _shutdown_started:
		return
	_shutdown_started = true
	_finish_shutdown(code)


func _finish_shutdown(code: int) -> void:
	if _bridge_open:
		_write_run_manifest("run-end", false, "")
	_close_bridge()
	if _csv_file != null:
		_csv_file.flush()
		_csv_file.close()
		_csv_file = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().quit(code)


func _close_bridge() -> void:
	_shutdown_started = true
	_capture_pending = false
	_capture_hold = false
	_region_retry_suppressed = false
	if _bridge_open and _bridge != null:
		_bridge.call("close_game")
	_bridge_open = false


func _sa_to_world(value: Vector3) -> Vector3:
	return Vector3(value.x, value.z, -value.y)


func _world_to_sa(value: Vector3) -> Vector3:
	return Vector3(value.x, -value.z, value.y)


func _vector_to_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _color_to_array(value: Color) -> Array:
	return [value.r, value.g, value.b, value.a]


func _color_is_finite(value: Color) -> bool:
	return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)


func _status_vector_to_array(value: Vector3) -> Array:
	var result := []
	for component in [value.x, value.y, value.z]:
		result.append(component if is_finite(component) else str(component))
	return result


func _environment_materials() -> Array:
	var result := _materials.duplicate()
	result.append(_sky_material)
	return result


func _profile_id() -> String:
	var profile := RenderingServer.get_current_rendering_method().to_lower().replace(" ", "_")
	if DisplayServer.get_name().to_lower() == "headless":
		return "headless_%s" % (profile if not profile.is_empty() else "none")
	return profile if not profile.is_empty() else "unknown_renderer"


func _on_off(value: bool) -> String:
	return "on" if value else "off"


func _bounded_status_string(value: Variant, maximum_length: int) -> String:
	return str(value).left(maximum_length)
