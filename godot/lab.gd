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
var _region_collision: Dictionary = {}
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
# P1-A05 async region state: latest-only pending request. The old complete
# world and paired COL stay active while pending; raw parse runs off main.
var _pending_region_active := false
var _pending_region_request_id := 0
var _pending_region_session_epoch := 0
var _pending_region_center_sa := Vector3.ZERO
var _pending_region_discarded_stale := 0
var _last_region_raw_parse_ms := 0.0
var _last_region_request_id := 0
var _last_region_session_epoch := 0
var _async_submit_count := 0
var _async_ready_count := 0
var _async_error_count := 0
var _async_cancel_count := 0
var _f6_ignored_while_pending := 0
# P1-A06 budgeted publication/retirement: logical work quota per pump, not a
# hard wall-time/FPS promise. One Godot texture/surface/metadata creation or
# one retirement free counts as one quota work item; nonpreemptible Godot
# calls (single texture upload, single surface add, root visibility flips)
# are measured atomic units and may honestly overshoot the quota.
var _budget_items := 64
var _region_root_a: Node3D
var _region_root_b: Node3D
var _region_active_is_a := true
var _lab_staging_active := false
var _lab_candidate_center_sa := Vector3.ZERO
var _lab_candidate_revision := 0
var _lab_candidate_request_id := 0
var _lab_candidate_session_epoch := 0
var _lab_candidate_meshes: Array = []
var _lab_candidate_stats: Dictionary = {}
var _lab_candidate_stats_csv := ""
var _lab_candidate_collision: Dictionary = {}
var _lab_candidate_pair_child := -1
var _lab_candidate_pair_parent := -1
var _lab_candidate_next_mesh := 0
var _lab_candidate_next_surface := 0
var _lab_candidate_current_instance: MeshInstance3D
var _lab_candidate_staged_instances: Array = []
var _lab_candidate_staged_materials: Array = []
var _lab_candidate_mesh_holds: Array = []
var _lab_candidate_texture_holds: Array = []
var _lab_candidate_discarded_stale := 0
var _lab_retire_active := false
var _lab_retire_material_holds: Array = []
var _lab_retire_mesh_holds: Array = []
var _lab_retire_texture_holds: Array = []
var _lab_retire_metadata_holds: Array = []
var _active_metadata_holds: Array = []
var _lab_deferred_discard_pending := false
var _lab_staged_discards := 0
var _last_region_conversion_ms_total := 0.0
var _last_region_conversion_ms_max_item := 0.0
var _last_region_conversion_frames := 0
var _last_region_commit_ms := 0.0
var _last_region_staging_ms_total := 0.0
var _last_region_publication_elapsed_ms := 0.0
var _last_region_retire_ms_max_item := 0.0
var _last_bridge_retire_pending := 0
var _last_bridge_staged_discards := 0
var _last_bridge_progress: Dictionary = {}
var _active_mesh_holds: Array = []
var _active_texture_holds: Array = []
var _lab_deferred_ready: Dictionary = {}
var _lab_deferred_center_sa := Vector3.ZERO
var _lab_deferred_started_usec := 0
var _lab_candidate_started_usec := 0
var _lab_candidate_staging_ms_total := 0.0
var _lab_candidate_sync_prefix_ms := 0.0


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
	for method in ["open_game", "load_region", "submit_region", "poll_region", "cancel_region", "environment", "close_game"]:
		if not _bridge.has_method(method):
			_fatal("SALegacyBridge is missing method %s" % method, 3)
			return

	var open_started := Time.get_ticks_usec()
	# P1-A06: pass logical budget quota at Open (1..4096). Old 3-arg bridges
	# stay compatible (introspect arg count first so no invalid-call error is
	# pushed on old binaries); new bridges enforce the range with DEFVAL(64).
	if _budget_items < 1 or _budget_items > 4096:
		_fatal("budget_items must be in [1,4096]", 2)
		return
	var open_uses_budget := false
	for info in ClassDB.class_get_method_list("SALegacyBridge", true):
		if info is Dictionary and str(info.get("name", "")) == "open_game":
			var arg_list: Array = info.get("args", [])
			if arg_list.size() >= 4:
				open_uses_budget = true
	var opened: Variant
	if open_uses_budget:
		opened = _bridge.call("open_game", _game_dir, _radius, _cap, _budget_items)
	else:
		opened = _bridge.call("open_game", _game_dir, _radius, _cap)
	_open_game_stall_ms = float(Time.get_ticks_usec() - open_started) / 1000.0
	if not _bridge_result_ok(opened, "open_game"):
		return
	_bridge_open = true
	_ensure_region_roots()
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

	# P1-A06: single nonblocking bridge poll per frame (idle polls still pump
	# C++ retirement; idle is never fake Ready) plus one budgeted lab pump
	# that advances hidden staging and hidden retirement together under the
	# per-frame quota. Never blocks on raw parse or whole-scene commit.
	_poll_pending_region()
	_pump_region_budget()
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
				# P1-A05/A06: explicit retry uses async submit, never a blocking wait.
				# F6 while an async request is pending or the budget retiring
				# generation drains is ignored and documented in the overlay
				# (existing counter); the pending request keeps the old world.
				# Camera intent is naturally retried on later frames.
				if _region_candidate_unavailable and not _capture_hold:
					if _pending_region_active or _region_budget_busy():
						_f6_ignored_while_pending += 1
					elif _loading:
						pass
					else:
						_region_retry_suppressed = false
						_submit_region_async(_failed_region_center_sa)
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


func _ensure_region_roots() -> void:
	# P1-A06: two persistent attached roots under mesh_root. Active holds the
	# visible complete generation; inactive (staging) holds hidden staging
	# candidate or hidden retiring generation, never both. No per-frame
	# creation/destruction; commit flips two visibilities plus swaps.
	if mesh_root == null:
		return
	if is_instance_valid(_region_root_a) and is_instance_valid(_region_root_b):
		return
	_region_root_a = Node3D.new()
	_region_root_a.name = "RegionA"
	_region_root_b = Node3D.new()
	_region_root_b.name = "RegionB"
	mesh_root.add_child(_region_root_a)
	mesh_root.add_child(_region_root_b)
	_region_active_is_a = true
	_region_root_a.visible = true
	_region_root_b.visible = false


func _active_region_root() -> Node3D:
	return _region_root_a if _region_active_is_a else _region_root_b


func _staging_region_root() -> Node3D:
	return _region_root_b if _region_active_is_a else _region_root_a


func _lab_retire_pending_count() -> int:
	var count := _lab_retire_material_holds.size() + _lab_retire_mesh_holds.size() + _lab_retire_texture_holds.size() + _lab_retire_metadata_holds.size()
	if _lab_retire_active and is_instance_valid(_staging_region_root()):
		count += _staging_region_root().get_child_count()
	if not _lab_deferred_ready.is_empty():
		var deferred_meshes: Variant = _lab_deferred_ready.get("meshes", [])
		if deferred_meshes is Array:
			count += (deferred_meshes as Array).size()
			# Deferred complete generation will retire metadata + mesh + bound
			# texture holds; count bound textures now so pending reflects the
			# future retiring queue (materials are empty for deferred).
			for mesh_info in (deferred_meshes as Array):
				if mesh_info is Dictionary:
					var sms: Variant = (mesh_info as Dictionary).get("surface_materials", [])
					if sms is Array:
						for surface_info in (sms as Array):
							if surface_info is Dictionary and (surface_info as Dictionary).get("texture", null) is Texture2D:
								count += 1
			# Mesh holds mirror metadata count (one per mesh); count them too.
			count += (deferred_meshes as Array).size()
	return count


func _region_budget_busy() -> bool:
	# Public test helper: true while hidden lab staging or hidden lab
	# retirement still holds work. Bridge preparing is covered by
	# _has_pending_region(); C++ retire_pending is in _last_bridge_retire_pending.
	# Tests with set_process(false) manually pump via _pump_region_budget().
	# Deferred ready (complete GPU generation) also gates admission while held,
	# including discard-pending marked for budgeted retirement.
	if not _lab_deferred_ready.is_empty():
		return true
	return _lab_staging_active or _lab_retire_active


func _update_bridge_progress_diagnostics(polled: Dictionary) -> void:
	var progress_value: Variant = polled.get("progress", {})
	if progress_value is Dictionary:
		_last_bridge_progress = (progress_value as Dictionary).duplicate(true)
		var retire_value: Variant = _last_bridge_progress.get("retire_pending", 0)
		_last_bridge_retire_pending = int(retire_value) if retire_value is int else 0
		var discard_value: Variant = _last_bridge_progress.get("staged_discards", 0)
		_last_bridge_staged_discards = int(discard_value) if discard_value is int else 0
	else:
		# Old A05 bridge has no progress dict: no C++ budget/retire to drain.
		_last_bridge_progress = {}
		_last_bridge_retire_pending = 0
		# Keep last known staged_discards? Old bridge never discards via budget.
		_last_bridge_staged_discards = 0


func _lab_gpu_holds_from_meshes(meshes: Array) -> Dictionary:
	# Local-only collector for deferred discard-pending retirement. Validation
	# path collects inline in its existing full pass; this helper shares the
	# same bound-texture rule (Texture2D only) for deferred payloads that were
	# never staged. No resource cache/authority change.
	var mesh_holds: Array = []
	var texture_holds: Array = []
	for mesh_info in meshes:
		if not mesh_info is Dictionary:
			continue
		var mesh_value: Variant = (mesh_info as Dictionary).get("mesh", null)
		if mesh_value is ArrayMesh:
			mesh_holds.append(mesh_value)
		var sms_value: Variant = (mesh_info as Dictionary).get("surface_materials", [])
		if sms_value is Array:
			for surface_info in (sms_value as Array):
				if surface_info is Dictionary:
					var texture_value: Variant = (surface_info as Dictionary).get("texture", null)
					if texture_value is Texture2D:
						texture_holds.append(texture_value)
	return {"mesh_holds": mesh_holds, "texture_holds": texture_holds}


func _lab_move_deferred_to_retiring() -> bool:
	# Move a held deferred complete GPU generation to the single retiring
	# queue (metadata + complete mesh/texture holds) for budgeted drain. Caller
	# ensures no staging and no active retiring (single retiring generation);
	# if retiring exists, retain deferred marked discard-pending instead.
	if _lab_deferred_ready.is_empty():
		return false
	if _lab_staging_active or _lab_retire_active:
		_lab_deferred_discard_pending = true
		return false
	var meshes_value: Variant = _lab_deferred_ready.get("meshes", [])
	if not meshes_value is Array:
		_lab_deferred_ready = {}
		_lab_deferred_discard_pending = false
		_lab_staged_discards += 1
		return true
	var meshes: Array = meshes_value
	var holds := _lab_gpu_holds_from_meshes(meshes)
	_lab_retire_metadata_holds = meshes
	_lab_retire_mesh_holds = holds.get("mesh_holds", [])
	_lab_retire_texture_holds = holds.get("texture_holds", [])
	_lab_retire_material_holds = []
	_lab_retire_active = true
	_lab_deferred_ready = {}
	_lab_deferred_discard_pending = false
	_lab_staged_discards += 1
	return true


func _lab_try_consume_deferred_budgeted() -> bool:
	# Budgeted deferred consumer for poll/pump idle: when retire drains and no
	# staging, either stage a normal deferred or retire a discard-pending one.
	# Never overwrites/appends a second retiring generation; retains marked
	# payload while old retire exists. Returns true if it made progress.
	if _lab_deferred_ready.is_empty():
		return false
	if _pending_region_active or _lab_staging_active or _lab_retire_active:
		return false
	if _lab_deferred_discard_pending:
		return _lab_move_deferred_to_retiring()
	return false


func _pump_region_budget() -> void:
	# One budgeted lab pump: hidden staging creation and hidden retirement
	# share the single per-frame quota (_budget_items total, 1..4096).
	# Each staged node or ShaderMaterial counts as one work item; each
	# retired node free or flat ref-hold drop counts as one. Whole-scene
	# commit is never counted as one unit. Nonpreemptible Godot calls
	# (single texture/surface/metadata creation, single free, two root
	# flips) are measured atomic units that may honestly overshoot quota.
	if _shutdown_started or not _bridge_open:
		return
	_ensure_region_roots()
	var budget := _budget_items
	if budget < 1:
		budget = 1
	if budget > 4096:
		budget = 4096
	var used := 0
	while used < budget and _lab_staging_active:
		_lab_stage_one_item()
		used += 1
		if _lab_candidate_next_mesh >= _lab_candidate_meshes.size():
			_lab_commit_staged_candidate()
			break
	while used < budget and _lab_retire_active and not _lab_staging_active:
		_lab_retire_one_item()
		used += 1
	# Manual-pump tests (set_process(false)) never call _poll: convert an idle
	# deferred here too. Discard-pending moves to retiring budgetedly; normal
	# deferred staging is left to _poll to preserve pending identity semantics.
	if used < budget and _lab_try_consume_deferred_budgeted():
		used += 1
		while used < budget and _lab_retire_active:
			_lab_retire_one_item()
			used += 1


func _flush_region_budget_unbudgeted() -> void:
	# Explicit unbudgeted flush reusing the same stepper: used only by sync
	# diagnostics, capture preempt, release and teardown. Not a per-frame quota.
	var guard := 0
	while (_lab_staging_active or _lab_retire_active or not _lab_deferred_ready.is_empty()) and guard < 100000:
		if _lab_staging_active:
			_lab_stage_one_item()
			if _lab_candidate_next_mesh >= _lab_candidate_meshes.size():
				_lab_commit_staged_candidate()
				# Sync flush retires the just-created retiring generation
				# immediately below instead of leaving it budgeted.
				if not _lab_staging_active and not _lab_retire_active and _lab_deferred_ready.is_empty():
					break
		elif _lab_retire_active:
			_lab_retire_one_item()
		elif not _lab_deferred_ready.is_empty():
			# Explicit flush may drain deferred unbudgeted per contract: normal
			# deferred would need validation+staging, but flush context always
			# discards (sync-preempt/teardown/release), so retire directly.
			_lab_deferred_discard_pending = true
			if not _lab_move_deferred_to_retiring():
				break
		else:
			break
		guard += 1


func _lab_stage_one_item() -> void:
	# One quota work item: either one hidden node add or one hidden
	# ShaderMaterial creation+override. Caller ensures staging active and
	# budget remains. No await; staging root stays hidden until commit.
	# Measured into _lab_candidate_staging_ms_total (per-unit CPU only, no
	# free-frame intervals); published to _last_region_staging_ms_total on
	# commit, discarded on cancel/reject without touching active stats.
	if not _lab_staging_active:
		return
	if _lab_candidate_next_mesh >= _lab_candidate_meshes.size():
		return
	var item_started := Time.get_ticks_usec()
	var staging_root := _staging_region_root()
	var mesh_info: Dictionary = _lab_candidate_meshes[_lab_candidate_next_mesh]
	var mesh: ArrayMesh = mesh_info.mesh
	var surface_materials: Array = mesh_info.surface_materials
	if _lab_candidate_current_instance == null or not is_instance_valid(_lab_candidate_current_instance):
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		if _lab_candidate_next_mesh == _lab_candidate_pair_parent:
			instance.visible = false
		instance.set_meta("lod_chain_alternate", _lab_candidate_next_mesh == _lab_candidate_pair_parent)
		instance.set_meta("source_model_id", int(mesh_info.get("source_model_id", -1)))
		instance.set_meta("source_model", str(mesh_info.get("source_model", "")))
		staging_root.add_child(instance)
		_lab_candidate_current_instance = instance
		_lab_candidate_staged_instances.append(instance)
		# A06: candidate mesh/texture holds already contain ALL validated GPU
		# refs from setup (local collection); no per-stage append here so
		# unstaged last refs survive cancel until budgeted retirement.
		_lab_candidate_next_surface = 0
		# New hidden node starts with current environment on its (still zero)
		# materials; each material below is created then immediately given the
		# current environment so the first visible frame is not stale.
		_lab_candidate_staging_ms_total += float(Time.get_ticks_usec() - item_started) / 1000.0
		return
	if _lab_candidate_next_surface < surface_materials.size():
		var material := LegacyMaterials.make_surface(surface_materials[_lab_candidate_next_surface])
		_lab_candidate_current_instance.set_surface_override_material(_lab_candidate_next_surface, material)
		_lab_candidate_staged_materials.append(material)
		# A06: bound textures already held fully from setup; no per-stage
		# texture append (would duplicate and leave unstaged refs unheld).
		if not _environment_data.is_empty():
			LegacyMaterials.set_environment([material], _environment_data, _flags)
		_lab_candidate_next_surface += 1
		if _lab_candidate_next_surface >= surface_materials.size():
			_lab_candidate_current_instance = null
			_lab_candidate_next_mesh += 1
		_lab_candidate_staging_ms_total += float(Time.get_ticks_usec() - item_started) / 1000.0
		return
	# Defensive: surface count mismatch should have failed validation; advance.
	_lab_candidate_current_instance = null
	_lab_candidate_next_mesh += 1
	_lab_candidate_staging_ms_total += float(Time.get_ticks_usec() - item_started) / 1000.0


func _lab_commit_staged_candidate() -> void:
	# Atomic no-await commit: two root visibility flips plus O(1) state/list
	# swaps. Does NOT loop detach/add all children. Old active root becomes
	# hidden retiring; staging root becomes visible active. Old holds move via
	# reference swap (no whole-generation dictionary clear avalanche).
	# Measurement: _last_load_stall_ms/_total_load_stall_ms are aggregated
	# measured main-thread work only, never multi-frame elapsed. Sync stall =
	# sync blocking bridge prefix (_lab_candidate_sync_prefix_ms, worker wait
	# plus conversion inside load_region) + lab staging (_lab_candidate
	# _staging_ms_total: validation/setup plus node/material items, no free
	# intervals) + atomic commit. Async stall = C++ conversion_ms_total +
	# staging + commit (ready-poll call itself excluded to avoid
	# double-counting conversion). _last_region_publication_elapsed_ms is wall
	# from candidate start to commit end, diagnostic only, never added.
	if not _lab_staging_active:
		return
	_ensure_region_roots()
	var commit_started := Time.get_ticks_usec()
	var staging_root := _staging_region_root()
	var active_root := _active_region_root()
	staging_root.visible = true
	active_root.visible = false
	var old_materials := _materials
	var old_mesh_holds := _active_mesh_holds
	var old_texture_holds := _active_texture_holds
	var old_metadata := _active_metadata_holds
	_materials = _lab_candidate_staged_materials
	_active_mesh_holds = _lab_candidate_mesh_holds
	_active_texture_holds = _lab_candidate_texture_holds
	_active_metadata_holds = _lab_candidate_meshes
	_lab_retire_material_holds = old_materials
	_lab_retire_mesh_holds = old_mesh_holds
	_lab_retire_texture_holds = old_texture_holds
	_lab_retire_metadata_holds = old_metadata
	_region_active_is_a = not _region_active_is_a
	_lab_retire_active = _has_published_region and (active_root.get_child_count() > 0 or not _lab_retire_material_holds.is_empty() or not _lab_retire_mesh_holds.is_empty() or not _lab_retire_texture_holds.is_empty() or not _lab_retire_metadata_holds.is_empty())
	# Deep copies/serialization already completed before hidden staging. Commit
	# only adopts their owned references; do not allocate a new COL after flips.
	_region_stats = _lab_candidate_stats
	_region_collision = _lab_candidate_collision
	_region_stats_csv = _lab_candidate_stats_csv
	_resident_meshes = _lab_candidate_staged_instances.size()
	_resident_surfaces = _lab_candidate_staged_materials.size()
	_loaded_center_sa = _lab_candidate_center_sa
	_has_published_region = true
	_publication_revision = _lab_candidate_revision
	_region_candidate_unavailable = false
	_region_retry_suppressed = false
	_remember_accepted_camera()
	# Stats are scalar only: worker parse+plan plus C++ conversion plus lab
	# staging plus lab commit. Failed/cancelled candidates never reach here,
	# so their partial staging accumulator is discarded without touching
	# active stats (existing invariant).
	var stats_raw: Variant = _region_stats.get("raw_parse_ms", 0.0)
	_last_region_raw_parse_ms = float(stats_raw) if (stats_raw is float or stats_raw is int) and is_finite(float(stats_raw)) else 0.0
	var conv_total: Variant = _region_stats.get("conversion_ms_total", 0.0)
	_last_region_conversion_ms_total = float(conv_total) if (conv_total is float or conv_total is int) and is_finite(float(conv_total)) else 0.0
	var conv_max: Variant = _region_stats.get("conversion_ms_max_item", 0.0)
	_last_region_conversion_ms_max_item = float(conv_max) if (conv_max is float or conv_max is int) and is_finite(float(conv_max)) else 0.0
	var conv_frames: Variant = _region_stats.get("conversion_frames", 0)
	_last_region_conversion_frames = int(conv_frames) if conv_frames is int else 0
	_last_region_request_id = _lab_candidate_request_id
	_last_region_session_epoch = _lab_candidate_session_epoch
	_pending_region_discarded_stale = _lab_candidate_discarded_stale
	# Ready counts only async staged commits (pending was true); sync
	# diagnostics use _load_count, preserving A05 semantics.
	if _pending_region_active:
		_async_ready_count += 1
	_pending_region_active = false
	_pending_region_request_id = 0
	_pending_region_session_epoch = 0
	_lab_staging_active = false
	_lab_candidate_meshes = []
	_lab_candidate_stats = {}
	_lab_candidate_collision = {}
	_lab_candidate_staged_instances = []
	_lab_candidate_staged_materials = []
	_lab_candidate_mesh_holds = []
	_lab_candidate_texture_holds = []
	_lab_candidate_current_instance = null
	_lab_candidate_next_mesh = 0
	_lab_candidate_next_surface = 0
	_last_region_commit_ms = float(Time.get_ticks_usec() - commit_started) / 1000.0
	_last_region_staging_ms_total = _lab_candidate_staging_ms_total
	if _lab_candidate_started_usec != 0:
		_last_region_publication_elapsed_ms = float(Time.get_ticks_usec() - _lab_candidate_started_usec) / 1000.0
	else:
		_last_region_publication_elapsed_ms = 0.0
	if _lab_candidate_sync_prefix_ms > 0.0:
		_last_load_stall_ms = _lab_candidate_sync_prefix_ms + _last_region_staging_ms_total + _last_region_commit_ms
	else:
		_last_load_stall_ms = _last_region_conversion_ms_total + _last_region_staging_ms_total + _last_region_commit_ms
	_total_load_stall_ms += _last_load_stall_ms
	_lab_candidate_staging_ms_total = 0.0
	_lab_candidate_sync_prefix_ms = 0.0
	_lab_candidate_started_usec = 0
	_update_overlay()


func _lab_retire_one_item() -> void:
	# One quota work item of hidden retirement: single metadata dict drop,
	# single node free, or single flat hold drop. Metadata pops first so the
	# full candidate metadata retires budgetedly; mesh/texture last refs free
	# only when their hold pops (nodes still hold refs until freed). Measured;
	# single free may overshoot quota honestly.
	if not _lab_retire_active:
		return
	var started := Time.get_ticks_usec()
	var retire_root := _staging_region_root()
	if not _lab_retire_metadata_holds.is_empty():
		_lab_retire_metadata_holds.pop_back()
		var elapsed_meta := float(Time.get_ticks_usec() - started) / 1000.0
		if elapsed_meta > _last_region_retire_ms_max_item:
			_last_region_retire_ms_max_item = elapsed_meta
		if retire_root.get_child_count() == 0 and _lab_retire_material_holds.is_empty() and _lab_retire_mesh_holds.is_empty() and _lab_retire_texture_holds.is_empty() and _lab_retire_metadata_holds.is_empty():
			_lab_retire_active = false
		return
	if retire_root.get_child_count() > 0:
		var node := retire_root.get_child(0)
		retire_root.remove_child(node)
		node.free()
		var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
		if elapsed > _last_region_retire_ms_max_item:
			_last_region_retire_ms_max_item = elapsed
		if retire_root.get_child_count() == 0 and _lab_retire_material_holds.is_empty() and _lab_retire_mesh_holds.is_empty() and _lab_retire_texture_holds.is_empty() and _lab_retire_metadata_holds.is_empty():
			_lab_retire_active = false
		return
	if not _lab_retire_material_holds.is_empty():
		_lab_retire_material_holds.pop_back()
	elif not _lab_retire_mesh_holds.is_empty():
		_lab_retire_mesh_holds.pop_back()
	elif not _lab_retire_texture_holds.is_empty():
		_lab_retire_texture_holds.pop_back()
	else:
		_lab_retire_active = false
		return
	var elapsed_hold := float(Time.get_ticks_usec() - started) / 1000.0
	if elapsed_hold > _last_region_retire_ms_max_item:
		_last_region_retire_ms_max_item = elapsed_hold
	if retire_root.get_child_count() == 0 and _lab_retire_material_holds.is_empty() and _lab_retire_mesh_holds.is_empty() and _lab_retire_texture_holds.is_empty() and _lab_retire_metadata_holds.is_empty():
		_lab_retire_active = false


func _discard_staging_to_retiring(reason: String) -> void:
	# Cancel/supersede during lab staging retains old active, moves FULL
	# candidate (metadata + ALL GPU mesh/texture holds pre-collected in setup)
	# to the one retiring generation. Bridge prepared counter may already be
	# consumed but active stays unchanged; monotonic seq stays valid.
	# Discarded partial staging CPU is dropped without touching published
	# active stats (existing invariant). Reference assignment only; candidate
	# rebinding below never clears the shared array object, so unstaged last
	# refs survive until budgeted retirement pops them.
	if not _lab_staging_active:
		return
	# Staging root already holds the partial nodes; convert its role to
	# retiring without moving children. Staged holds become retiring holds
	# via O(1) move (no avalanche clear).
	_lab_retire_metadata_holds = _lab_candidate_meshes
	_lab_retire_material_holds = _lab_candidate_staged_materials
	_lab_retire_mesh_holds = _lab_candidate_mesh_holds
	_lab_retire_texture_holds = _lab_candidate_texture_holds
	_lab_retire_active = true
	_lab_staging_active = false
	_lab_candidate_meshes = []
	_lab_candidate_stats = {}
	_lab_candidate_collision = {}
	_lab_candidate_staged_instances = []
	_lab_candidate_staged_materials = []
	_lab_candidate_mesh_holds = []
	_lab_candidate_texture_holds = []
	_lab_candidate_current_instance = null
	_lab_candidate_next_mesh = 0
	_lab_candidate_next_surface = 0
	_lab_candidate_staging_ms_total = 0.0
	_lab_candidate_sync_prefix_ms = 0.0
	_lab_candidate_started_usec = 0
	_lab_staged_discards += 1


func _load_region(center_sa: Vector3) -> bool:
	# Synchronous diagnostic path (explicit unbudgeted flush reusing the same
	# stepper): initial load and fixed captures only. Normal movement and F6
	# use _submit_region_async plus _poll_pending_region/_pump_region_budget.
	# Fixed captures must never see a stale async commit: cancel/consume+flush
	# before holding immutable frames. Keeps the blocking contract.
	if _loading or _shutdown_started:
		return false
	_ensure_region_roots()
	if _has_pending_region() or _region_budget_busy():
		_drain_pending_for_sync("sync-preempt")
		if _shutdown_started:
			return false
		if _has_pending_region() or _lab_staging_active:
			return false
		# Sync flush must start from a drained retiring generation so the
		# staging root is free; drain flushes retiring unbudgeted above.
		if _lab_retire_active:
			_flush_region_budget_unbudgeted()
			if _lab_retire_active:
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
	_update_bridge_progress_diagnostics(result)
	if not _validate_and_begin_staging(result, center_sa, started):
		# Validation/rejection already handled; sync failures retain old.
		# _validate returns false for both reject (ok=false, retains old) and
		# fatal malformed (terminal). Distinguish via shutdown flag? Reject
		# returns false without fatal; report accordingly.
		return false
	# Sync stall keeps its blocking worker wait: the bridge call above already
	# contains worker wait plus conversion, so commit uses this prefix instead
	# of adding conversion_ms_total again (no double count).
	if _lab_staging_active:
		_lab_candidate_sync_prefix_ms = _last_bridge_load_call_ms
	# Explicit flush: stage all + commit + retire old immediately (blocking).
	_flush_region_budget_unbudgeted()
	# Flush also drains the retiring generation created by this sync commit
	# so fixed captures hold a settled world (old freed now, not budgeted).
	_flush_region_budget_unbudgeted()
	if _lab_staging_active:
		return false
	return _has_published_region and _publication_revision > 0


func _has_pending_region() -> bool:
	# True through GPU preparing + lab staging until commit/cancel (including
	# deferred ready held while the retiring generation drains).
	if _lab_staging_active:
		return true
	if not _lab_deferred_ready.is_empty():
		return true
	return _pending_region_active and _pending_region_request_id != 0


func _submit_region_async(center_sa: Vector3) -> Dictionary:
	# Latest-only async submit via the shared worker. Never blocks on raw
	# parse; the old complete world and paired COL stay active until budgeted
	# commit. Duplicate requests near the same pending center are ignored so
	# per-frame movement does not resubmit identical work. While the one
	# retiring lab generation drains (or C++ retire_pending>0), new admission
	# is blocked as busy (camera intent naturally retried next frame; F6 busy
	# uses the existing ignored counter). No unbounded queue by repeated
	# supersede: at most one retiring generation plus one bridge pending.
	if _shutdown_started or not _bridge_open or _bridge == null:
		return {"ok": false, "error": "bridge not open", "request_id": 0, "session_epoch": _last_region_session_epoch, "discarded_stale": _pending_region_discarded_stale, "publication_revision": _publication_revision}
	if not _bridge.has_method("submit_region"):
		_fatal("SALegacyBridge is missing method submit_region", 3)
		return {"ok": false, "error": "missing submit_region", "request_id": 0, "session_epoch": 0, "discarded_stale": 0, "publication_revision": _publication_revision}
	if _loading:
		return {"ok": false, "error": "sync load in progress", "request_id": 0, "session_epoch": _last_region_session_epoch, "discarded_stale": _pending_region_discarded_stale, "publication_revision": _publication_revision}
	_ensure_region_roots()
	if _lab_retire_active or not _lab_deferred_ready.is_empty() or _last_bridge_retire_pending > 0:
		return {"ok": false, "error": "retiring_busy", "request_id": 0, "session_epoch": _last_region_session_epoch, "discarded_stale": _pending_region_discarded_stale, "publication_revision": _publication_revision}
	if _pending_region_active:
		if _planar_region_distance(center_sa, _pending_region_center_sa) < 1.0:
			return {"ok": false, "error": "duplicate_pending", "request_id": _pending_region_request_id, "session_epoch": _pending_region_session_epoch, "discarded_stale": _pending_region_discarded_stale, "publication_revision": _publication_revision}
		if _planar_region_distance(center_sa, _pending_region_center_sa) < _region_reload_threshold():
			return {"ok": false, "error": "duplicate_pending", "request_id": _pending_region_request_id, "session_epoch": _pending_region_session_epoch, "discarded_stale": _pending_region_discarded_stale, "publication_revision": _publication_revision}
		if _lab_staging_active:
			# Supersede during lab staging retains old active, moves partial
			# candidate to the one retiring root. Prepared bridge counter may
			# already be consumed but active stays unchanged; monotonic seq
			# stays valid. New admission blocks as busy until the retiring
			# generation drains (camera intent naturally retried after);
			# no unbounded queue by repeated supersede.
			_discard_staging_to_retiring("supersede")
			_pending_region_active = false
			_pending_region_request_id = 0
			_pending_region_session_epoch = 0
			_async_cancel_count += 1
			_update_overlay()
			return {"ok": false, "error": "retiring_busy", "request_id": 0, "session_epoch": _last_region_session_epoch, "discarded_stale": _pending_region_discarded_stale, "publication_revision": _publication_revision}
	var submitted: Variant = _bridge.call("submit_region", center_sa)
	if not submitted is Dictionary:
		_fatal("submit_region returned a non-Dictionary result", 4)
		return {"ok": false, "error": "non-Dictionary submit result", "request_id": 0, "session_epoch": 0, "discarded_stale": 0, "publication_revision": _publication_revision}
	if not bool(submitted.get("ok", false)):
		return submitted
	var rid: Variant = submitted.get("request_id")
	var epoch: Variant = submitted.get("session_epoch")
	if not rid is int or not epoch is int or int(rid) <= 0 or int(epoch) <= 0:
		_fatal("submit_region returned invalid request identity", 4)
		return submitted
	_pending_region_active = true
	_pending_region_request_id = int(rid)
	_pending_region_session_epoch = int(epoch)
	_pending_region_center_sa = center_sa
	_pending_region_discarded_stale = int(submitted.get("discarded_stale", 0))
	_async_submit_count += 1
	_update_overlay()
	return submitted


func _poll_pending_region() -> void:
	# Single nonblocking bridge poll per frame. Idle polls still pump C++
	# retirement (idle is never fake Ready). Pending/preparing/idle with
	# ok=false are not failures; old world stays active. Preparing is
	# nonterminal budgeted C++ conversion: keep pending, update progress.
	# Ready/error/cancelled are one-shot and only applied when request_id and
	# session_epoch match the pending request; foreign id/epoch is terminal
	# protocol error before any mutation. Ready starts hidden lab staging
	# (budgeted) and keeps pending true through lab staging until commit.
	if _shutdown_started or not _bridge_open or _bridge == null:
		return
	if not _bridge.has_method("poll_region"):
		return
	# Deferred ready (bridge ready arrived while retiring drained): begin
	# staging now that the staging root is free. Discard-pending deferred is
	# never adopted for staging; it retires budgetedly when free. CANCEL marks
	# discard-pending so a later poll cannot stage it.
	if not _pending_region_active and not _lab_deferred_ready.is_empty() and not _lab_staging_active and not _lab_retire_active:
		if _lab_deferred_discard_pending:
			_lab_move_deferred_to_retiring()
			return
		var deferred := _lab_deferred_ready
		var deferred_center := _lab_deferred_center_sa
		var deferred_started := _lab_deferred_started_usec
		_lab_deferred_ready = {}
		_lab_deferred_discard_pending = false
		_pending_region_active = true
		_pending_region_request_id = int(deferred.get("request_id", 0))
		_pending_region_session_epoch = int(deferred.get("session_epoch", 0))
		_pending_region_center_sa = deferred_center
		_validate_and_begin_staging(deferred, deferred_center, deferred_started)
		return
	var convert_started := Time.get_ticks_usec()
	var polled: Variant = _bridge.call("poll_region")
	if not polled is Dictionary:
		_fatal("poll_region returned a non-Dictionary result", 4)
		return
	_update_bridge_progress_diagnostics(polled)
	var status := str(polled.get("status", ""))
	if not _pending_region_active:
		# Idle pump drains C++ retirement; never treat idle as Ready.
		# If a terminal arrived with no lab pending (e.g., stale after cancel),
		# ignore it: no fake Ready, no revision advance.
		return
	if status == "pending" or status == "idle":
		return
	if status == "preparing":
		# Nonterminal: validate identity when present, keep pending and old.
		var prepar_rid: Variant = polled.get("request_id", _pending_region_request_id)
		var prepar_epoch: Variant = polled.get("session_epoch", _pending_region_session_epoch)
		if prepar_rid is int and prepar_epoch is int:
			if int(prepar_rid) != _pending_region_request_id or int(prepar_epoch) != _pending_region_session_epoch:
				_pending_region_active = false
				_pending_region_request_id = 0
				_pending_region_session_epoch = 0
				_fatal("async region protocol mismatch: foreign request_id/session_epoch in preparing", 4)
				return
		return
	var rid: Variant = polled.get("request_id")
	var epoch: Variant = polled.get("session_epoch")
	if not rid is int or not epoch is int or int(rid) != _pending_region_request_id or int(epoch) != _pending_region_session_epoch:
		_pending_region_active = false
		_pending_region_request_id = 0
		_pending_region_session_epoch = 0
		if _lab_staging_active:
			_discard_staging_to_retiring("protocol-mismatch")
		_fatal("async region protocol mismatch: foreign request_id/session_epoch", 4)
		return
	if status == "cancelled":
		if _lab_staging_active:
			_discard_staging_to_retiring("cancelled")
		_pending_region_active = false
		_pending_region_request_id = 0
		_pending_region_session_epoch = 0
		_async_cancel_count += 1
		_update_overlay()
		return
	if status == "ready":
		var center := _pending_region_center_sa
		# If retiring/staging/deferred blocks admission, hold the ready payload
		# deferred until drain instead of losing the one-shot packet or mixing
		# generations. Never overwrite an existing deferred (single deferred +
		# single retiring bound); retain the old and keep pending cleared.
		if _lab_retire_active or _lab_staging_active or not _lab_deferred_ready.is_empty():
			if not _lab_deferred_ready.is_empty():
				_pending_region_active = false
				_pending_region_request_id = 0
				_pending_region_session_epoch = 0
				return
			_lab_deferred_ready = (polled as Dictionary).duplicate(true)
			_lab_deferred_center_sa = center
			_lab_deferred_started_usec = convert_started
			_lab_deferred_discard_pending = false
			_pending_region_active = false
			_pending_region_request_id = 0
			_pending_region_session_epoch = 0
			return
		# Keep pending true through lab staging; ready count increments only
		# on staged commit (cancelled staged work never becomes ready).
		_validate_and_begin_staging(polled, center, convert_started)
		return
	if status == "error":
		var failed_center := _pending_region_center_sa
		if _lab_staging_active:
			_discard_staging_to_retiring("error")
		_pending_region_active = false
		_pending_region_request_id = 0
		_pending_region_session_epoch = 0
		_async_error_count += 1
		_reject_region_candidate(failed_center, polled)
		return
	_pending_region_active = false
	_pending_region_request_id = 0
	_pending_region_session_epoch = 0
	if _lab_staging_active:
		_discard_staging_to_retiring("unknown-status")
	_fatal("poll_region returned unknown status %s" % status, 4)


func _cancel_pending_region() -> Dictionary:
	# Direct bridge cancel/supersede after preparing begins (not just raw
	# queue) plus lab staging cancel: retains old active, moves partial
	# candidate to the one retiring root. No old Ready, no revision advance
	# on cancel.
	if not _has_pending_region() and _lab_deferred_ready.is_empty():
		return {"ok": false, "error": "no pending region", "request_id": 0}
	if not _lab_deferred_ready.is_empty():
		# Midrun cancel of a deferred complete GPU generation: never clear the
		# dict (would free unstaged last refs unbudgeted) and never create a
		# second retiring generation. Mark discard-pending, gate admission
		# while held; move to the single retiring queue budgetedly when free
		# (immediately if already free). CANCEL-marked payload is never staged.
		if _lab_staging_active:
			_discard_staging_to_retiring("cancel-deferred")
			_pending_region_active = false
			_pending_region_request_id = 0
			_pending_region_session_epoch = 0
			_async_cancel_count += 1
		_lab_deferred_discard_pending = true
		_pending_region_active = false
		_pending_region_request_id = 0
		_pending_region_session_epoch = 0
		_async_cancel_count += 1
		if not _lab_staging_active and not _lab_retire_active:
			_lab_move_deferred_to_retiring()
		_update_overlay()
		return {"ok": true, "request_id": 0, "session_epoch": _last_region_session_epoch, "discarded_stale": _pending_region_discarded_stale, "publication_revision": _publication_revision}
	var rid := _pending_region_request_id
	var result: Variant = _bridge.call("cancel_region", rid)
	if not result is Dictionary:
		_fatal("cancel_region returned a non-Dictionary result", 4)
		return {"ok": false, "error": "non-Dictionary cancel result", "request_id": rid}
	if bool(result.get("ok", false)):
		_poll_pending_region()
		# Cancel during lab staging (bridge already ready, no exposed to
		# cancel): bridge ack fails as unknown, but lab staging must still be
		# discarded to retiring with old retained.
		if _has_pending_region() and _lab_staging_active:
			_discard_staging_to_retiring("cancel")
			_pending_region_active = false
			_pending_region_request_id = 0
			_pending_region_session_epoch = 0
			_async_cancel_count += 1
			_update_overlay()
	else:
		# Bridge has no exposed request (already ready/consumed) but lab
		# staging exists: explicit cancel discards staging to retiring.
		if _has_pending_region() and _lab_staging_active:
			_discard_staging_to_retiring("cancel")
			_pending_region_active = false
			_pending_region_request_id = 0
			_pending_region_session_epoch = 0
			_async_cancel_count += 1
			_update_overlay()
			return {"ok": true, "request_id": rid, "session_epoch": _last_region_session_epoch, "discarded_stale": _pending_region_discarded_stale, "publication_revision": _publication_revision}
	return result


func _drain_pending_for_sync(reason: String) -> void:
	# Fixed captures and sync diagnostics must never see a stale async commit
	# over the fixed frame: cancel/consume+flush before holding immutable
	# frames. Cancel-before-poll discards even a ready-but-untaken packet, so
	# no stale world is committed. Explicit unbudgeted flush reusing the same
	# stepper drains lab staging/retiring and C++ retirement (bounded).
	if not _has_pending_region() and _lab_deferred_ready.is_empty() and not _region_budget_busy() and _last_bridge_retire_pending == 0:
		return
	if _bridge != null and _bridge_open and _bridge.has_method("cancel_region") and _has_pending_region():
		var rid := _pending_region_request_id
		var _cancelled: Variant = _bridge.call("cancel_region", rid)
	if _bridge != null and _bridge_open and _bridge.has_method("poll_region") and not _shutdown_started:
		_poll_pending_region()
	# Lab staging partial (if any) becomes the one retiring generation with
	# old retained; deferred ready is marked discard-pending (never staged)
	# and retired via the single retiring queue. Explicit unbudgeted flush
	# below drains it per sync contract.
	if not _lab_deferred_ready.is_empty():
		_lab_deferred_discard_pending = true
		_pending_region_active = false
		_pending_region_request_id = 0
		_pending_region_session_epoch = 0
	if _lab_staging_active:
		_discard_staging_to_retiring("sync-preempt")
		_pending_region_active = false
		_pending_region_request_id = 0
		_pending_region_session_epoch = 0
	# Unbudgeted flush of lab retiring plus bounded C++ retire pump.
	_flush_region_budget_unbudgeted()
	if _bridge != null and _bridge_open and _bridge.has_method("poll_region") and not _shutdown_started:
		var guard := 0
		while guard < 100:
			var polled: Variant = _bridge.call("poll_region")
			if not polled is Dictionary:
				break
			_update_bridge_progress_diagnostics(polled)
			if _last_bridge_retire_pending == 0:
				break
			guard += 1
	# If the worker already retired the packet without a cancel ack (should not
	# happen after cancel), a single poll above still consumes it exactly once.
	if _has_pending_region() and reason == "sync-preempt":
		# Force-clear a stuck pending only after cancel+consume+flush above;
		# never publish partial or stale resources.
		if _lab_staging_active:
			_discard_staging_to_retiring("sync-preempt-force")
		_pending_region_active = false
		_pending_region_request_id = 0
		_pending_region_session_epoch = 0


func _validate_and_begin_staging(result: Dictionary, center_sa: Vector3, started_usec: int) -> bool:
	# Shared validation for sync and async ready payloads (P0/chain/async
	# typed payload validation/rejection/context/recovery and COL bytes
	# preserved). Old complete nodes/stats/paired COL stay unchanged until
	# all candidate validated + nodes/materials ready. On success begins
	# hidden budgeted staging under the staging root and keeps pending true;
	# commit happens later via _pump (budgeted) or flush (sync). Never
	# publishes partial or stale resources. Validation/setup CPU is measured
	# into the per-candidate staging accumulator; failures discard without
	# touching published active stats.
	var setup_started := Time.get_ticks_usec()
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
	# A06: collect ALL candidate GPU refs in locals during this same full
	# validation pass (no second geometry pass). Assigned to candidate holds
	# in setup below; per-stage appends removed so unstaged last refs survive
	# cancel until budgeted retirement.
	var all_mesh_holds: Array = []
	var all_texture_holds: Array = []
	for mesh_info in meshes:
		if not mesh_info is Dictionary:
			_fatal("load_region returned malformed mesh metadata", 4)
			return false
		if mesh_info.has("lod_chain_alternate") and not mesh_info.get("lod_chain_alternate") is bool:
			_fatal("load_region lod_chain_alternate is not boolean", 4)
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
		all_mesh_holds.append(mesh_value)
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
			if surface_info.texture is Texture2D:
				all_texture_holds.append(surface_info.texture)

	var collision_out := _prepare_region_collision(result, meshes, int(revision_value))
	if not bool(collision_out.get("ok", false)):
		return false
	var prepared_collision: Dictionary = collision_out.get("prepared", {})
	var pair_child_index: int = int(collision_out.get("child_index", -1))
	var pair_parent_index: int = int(collision_out.get("parent_index", -1))

	var candidate_stats: Dictionary = result.stats.duplicate(true)
	# Begin hidden budgeted staging: clear any prior partial in the staging
	# root (should be empty; if retiring blocks, caller defers instead).
	_ensure_region_roots()
	var staging_root := _staging_region_root()
	# Staging root must be empty when beginning (no retiring/deferred coexists
	# with new staging by admission gate). Defensive: if retiring or deferred
	# still holds a generation, do not mix generations.
	if _lab_retire_active or not _lab_deferred_ready.is_empty():
		# Caller should have deferred; do not start staging over retiring.
		return false
	for child in staging_root.get_children():
		# Defensive flush of a stale empty staging remnant (no active mix).
		# Measured as setup work below with the rest of validation.
		staging_root.remove_child(child)
		child.free()
	_lab_staging_active = true
	_lab_candidate_center_sa = center_sa
	_lab_candidate_revision = int(revision_value)
	var top_rid_begin: Variant = result.get("request_id", candidate_stats.get("request_id", 0))
	_lab_candidate_request_id = int(top_rid_begin) if top_rid_begin is int else _pending_region_request_id
	var top_epoch_begin: Variant = result.get("session_epoch", candidate_stats.get("session_epoch", 0))
	_lab_candidate_session_epoch = int(top_epoch_begin) if top_epoch_begin is int else _pending_region_session_epoch
	_lab_candidate_meshes = meshes
	_lab_candidate_stats = candidate_stats
	_lab_candidate_stats_csv = JSON.stringify(candidate_stats)
	_lab_candidate_collision = prepared_collision
	_lab_candidate_pair_child = pair_child_index
	_lab_candidate_pair_parent = pair_parent_index
	_lab_candidate_next_mesh = 0
	_lab_candidate_next_surface = 0
	_lab_candidate_current_instance = null
	_lab_candidate_staged_instances = []
	_lab_candidate_staged_materials = []
	_lab_candidate_mesh_holds = all_mesh_holds
	_lab_candidate_texture_holds = all_texture_holds
	_lab_candidate_staging_ms_total = float(Time.get_ticks_usec() - setup_started) / 1000.0
	_lab_candidate_sync_prefix_ms = 0.0
	_lab_candidate_started_usec = started_usec
	_lab_candidate_discarded_stale = int(result.get("discarded_stale", _pending_region_discarded_stale)) if result.get("discarded_stale") is int else _pending_region_discarded_stale
	_update_bridge_progress_diagnostics(result)
	return true


func _commit_region_result(result: Dictionary, center_sa: Vector3, started_usec: int) -> bool:
	# Legacy blocking wrapper (kept for direct callers): validate + begin
	# staging then explicitly flush unbudgeted reusing the same stepper.
	# Async poll path uses _validate_and_begin_staging directly to keep
	# pending true through budgeted staging.
	if not _validate_and_begin_staging(result, center_sa, started_usec):
		return false
	_flush_region_budget_unbudgeted()
	_flush_region_budget_unbudgeted()
	return not _lab_staging_active and _has_published_region


func _prepare_region_collision(result: Dictionary, meshes: Array, revision: int) -> Dictionary:
	var lineage_value: Variant = result.get("collision_lineage", {})
	if not lineage_value is Dictionary:
		_fatal("load_region returned non-Dictionary collision_lineage", 4)
		return {"ok": false}
	var lineage: Dictionary = lineage_value
	if lineage.is_empty():
		for mesh_index in range(meshes.size()):
			var info: Dictionary = meshes[mesh_index]
			if bool(info.get("lod_chain_alternate", false)):
				_fatal("load_region meshes claim lod_chain_alternate without collision_lineage", 4)
				return {"ok": false}
		return {"ok": true, "prepared": {}, "child_index": -1, "parent_index": -1}
	var generation_value: Variant = lineage.get("generation")
	if not generation_value is int or int(generation_value) != revision:
		_fatal("load_region collision_lineage has invalid generation", 4)
		return {"ok": false}
	if str(lineage.get("scope", "")) != "single-chain-data-not-gameplay":
		_fatal("load_region collision_lineage has invalid scope", 4)
		return {"ok": false}
	if str(lineage.get("link", "")) != "bound":
		_fatal("load_region collision_lineage has invalid link", 4)
		return {"ok": false}
	if not lineage.get("collision_transferred") is bool or not bool(lineage.collision_transferred):
		_fatal("load_region collision_lineage collision_transferred must be true", 4)
		return {"ok": false}
	if not lineage.get("child") is Dictionary or not lineage.get("parent") is Dictionary or not lineage.get("col") is Dictionary:
		_fatal("load_region collision_lineage is missing child/parent/col", 4)
		return {"ok": false}
	var child: Dictionary = lineage.child
	var parent: Dictionary = lineage.parent
	var col: Dictionary = lineage.col
	var child_role := _validate_collision_role(child, meshes, true, "child")
	if not bool(child_role.get("ok", false)):
		return {"ok": false}
	var parent_role := _validate_collision_role(parent, meshes, false, "parent")
	if not bool(parent_role.get("ok", false)):
		return {"ok": false}
	var child_index: int = int(child_role.mesh_index)
	var parent_index: int = int(parent_role.mesh_index)
	if child_index == parent_index:
		_fatal("load_region collision_lineage child and parent share mesh_index", 4)
		return {"ok": false}
	if str(parent.get("effective_alias", "")) != "child":
		_fatal("load_region collision_lineage parent effective_alias must be child", 4)
		return {"ok": false}
	for mesh_index in range(meshes.size()):
		var info: Dictionary = meshes[mesh_index]
		var flag := bool(info.get("lod_chain_alternate", false))
		if mesh_index == parent_index and not flag:
			_fatal("load_region parent mesh must carry lod_chain_alternate=true", 4)
			return {"ok": false}
		if mesh_index == child_index and flag:
			_fatal("load_region child mesh must carry lod_chain_alternate=false", 4)
			return {"ok": false}
		if mesh_index != parent_index and flag:
			_fatal("load_region only the bound parent may carry lod_chain_alternate=true", 4)
			return {"ok": false}
	if not _validate_collision_model(col, child):
		return {"ok": false}
	return {"ok": true, "prepared": lineage.duplicate(true), "child_index": child_index, "parent_index": parent_index}


func _validate_collision_role(role: Dictionary, meshes: Array, expect_uses: bool, label: String) -> Dictionary:
	var model_id_value: Variant = role.get("model_id")
	if not model_id_value is int or int(model_id_value) < 0:
		_fatal("load_region collision_lineage %s has invalid model_id" % label, 4)
		return {"ok": false}
	var model_value: Variant = role.get("model")
	if not (model_value is String or model_value is StringName) or str(model_value).is_empty():
		_fatal("load_region collision_lineage %s has invalid model" % label, 4)
		return {"ok": false}
	var mesh_index_value: Variant = role.get("mesh_index")
	if not mesh_index_value is int or int(mesh_index_value) < 0 or int(mesh_index_value) >= meshes.size():
		_fatal("load_region collision_lineage %s has invalid mesh_index" % label, 4)
		return {"ok": false}
	if not role.get("uses_collision") is bool or bool(role.uses_collision) != expect_uses:
		_fatal("load_region collision_lineage %s has invalid uses_collision" % label, 4)
		return {"ok": false}
	if not role.get("placement") is Dictionary:
		_fatal("load_region collision_lineage %s is missing placement" % label, 4)
		return {"ok": false}
	var placement: Dictionary = role.placement
	var ipl_value: Variant = placement.get("ipl")
	if not (ipl_value is String or ipl_value is StringName) or str(ipl_value).is_empty():
		_fatal("load_region collision_lineage %s placement has invalid ipl" % label, 4)
		return {"ok": false}
	if not placement.get("record") is int or int(placement.record) < 0:
		_fatal("load_region collision_lineage %s placement has invalid record" % label, 4)
		return {"ok": false}
	if not placement.get("binary") is bool:
		_fatal("load_region collision_lineage %s placement has invalid binary" % label, 4)
		return {"ok": false}
	if not _finite_vector3(placement.get("position_sa")):
		_fatal("load_region collision_lineage %s placement has nonfinite position_sa" % label, 4)
		return {"ok": false}
	if not _finite_quaternion(placement.get("quaternion_sa")):
		_fatal("load_region collision_lineage %s placement has nonfinite quaternion_sa" % label, 4)
		return {"ok": false}
	var mesh_index := int(mesh_index_value)
	var mesh_info: Dictionary = meshes[mesh_index]
	if not mesh_info.get("source_model_id") is int or int(mesh_info.source_model_id) != int(model_id_value):
		_fatal("load_region collision_lineage %s model_id does not match source mesh" % label, 4)
		return {"ok": false}
	if str(mesh_info.get("source_model", "")).to_lower() != str(model_value).to_lower():
		_fatal("load_region collision_lineage %s model does not match source mesh" % label, 4)
		return {"ok": false}
	return {"ok": true, "mesh_index": mesh_index}


func _validate_collision_model(col: Dictionary, child: Dictionary) -> bool:
	if str(col.get("status", "")) != "ready":
		_fatal("load_region collision_lineage col status must be ready", 4)
		return false
	var library_value: Variant = col.get("library")
	if not (library_value is String or library_value is StringName) or str(library_value).is_empty():
		_fatal("load_region collision_lineage col has invalid library", 4)
		return false
	if not col.get("header_id") is int or int(col.header_id) < 0:
		_fatal("load_region collision_lineage col has invalid header_id", 4)
		return false
	var header_name_value: Variant = col.get("header_name")
	if not (header_name_value is String or header_name_value is StringName) or str(header_name_value).is_empty():
		_fatal("load_region collision_lineage col has invalid header_name", 4)
		return false
	if not col.get("version") is int:
		_fatal("load_region collision_lineage col has invalid version", 4)
		return false
	for key in ["vertex_count", "faces", "spheres", "boxes"]:
		if not col.get(key) is int or int(col[key]) < 0:
			_fatal("load_region collision_lineage col has invalid %s" % key, 4)
			return false
	var vertex_count := int(col.vertex_count)
	var faces := int(col.faces)
	var spheres := int(col.spheres)
	var boxes := int(col.boxes)
	if vertex_count <= 0 or faces <= 0:
		_fatal("load_region collision_lineage col has no faces/vertices", 4)
		return false
	if int(child.model_id) != int(col.header_id):
		_fatal("load_region collision_lineage col header_id does not match child", 4)
		return false
	if str(child.model).to_lower() != str(header_name_value).to_lower():
		_fatal("load_region collision_lineage col header_name does not match child", 4)
		return false
	if not _finite_vector3(col.get("bounds_min")) or not _finite_vector3(col.get("bounds_max")) or not _finite_vector3(col.get("bound_center")):
		_fatal("load_region collision_lineage col has nonfinite bounds", 4)
		return false
	var radius_value: Variant = col.get("bound_radius")
	if not (radius_value is float or radius_value is int) or not is_finite(float(radius_value)) or float(radius_value) < 0.0:
		_fatal("load_region collision_lineage col has invalid bound_radius", 4)
		return false
	if not col.get("vertices") is PackedFloat32Array:
		_fatal("load_region collision_lineage col has invalid vertices", 4)
		return false
	if not col.get("face_indices") is PackedInt32Array:
		_fatal("load_region collision_lineage col has invalid face_indices", 4)
		return false
	if not col.get("face_surfaces") is PackedByteArray:
		_fatal("load_region collision_lineage col has invalid face_surfaces", 4)
		return false
	if not col.get("sphere_data") is PackedFloat32Array:
		_fatal("load_region collision_lineage col has invalid sphere_data", 4)
		return false
	if not col.get("sphere_surfaces") is PackedByteArray:
		_fatal("load_region collision_lineage col has invalid sphere_surfaces", 4)
		return false
	if not col.get("box_data") is PackedFloat32Array:
		_fatal("load_region collision_lineage col has invalid box_data", 4)
		return false
	if not col.get("box_surfaces") is PackedByteArray:
		_fatal("load_region collision_lineage col has invalid box_surfaces", 4)
		return false
	var vertices: PackedFloat32Array = col.vertices
	var face_indices: PackedInt32Array = col.face_indices
	var face_surfaces: PackedByteArray = col.face_surfaces
	var sphere_data: PackedFloat32Array = col.sphere_data
	var sphere_surfaces: PackedByteArray = col.sphere_surfaces
	var box_data: PackedFloat32Array = col.box_data
	var box_surfaces: PackedByteArray = col.box_surfaces
	if vertices.size() != vertex_count * 3:
		_fatal("load_region collision_lineage col vertex count mismatch", 4)
		return false
	if face_indices.size() != faces * 3 or face_surfaces.size() != faces * 4:
		_fatal("load_region collision_lineage col face count mismatch", 4)
		return false
	if sphere_data.size() != spheres * 4 or sphere_surfaces.size() != spheres * 4:
		_fatal("load_region collision_lineage col sphere count mismatch", 4)
		return false
	if box_data.size() != boxes * 6 or box_surfaces.size() != boxes * 4:
		_fatal("load_region collision_lineage col box count mismatch", 4)
		return false
	for value in vertices:
		if not is_finite(value):
			_fatal("load_region collision_lineage col has nonfinite vertex", 4)
			return false
	for index_value in face_indices:
		if index_value < 0 or index_value >= vertex_count:
			_fatal("load_region collision_lineage col has out-of-range face index", 4)
			return false
	for value in sphere_data:
		if not is_finite(value):
			_fatal("load_region collision_lineage col has nonfinite sphere data", 4)
			return false
	for sphere_index in range(spheres):
		if float(sphere_data[sphere_index * 4 + 3]) < 0.0:
			_fatal("load_region collision_lineage col has negative sphere radius", 4)
			return false
	for value in box_data:
		if not is_finite(value):
			_fatal("load_region collision_lineage col has nonfinite box data", 4)
			return false
	for box_index in range(boxes):
		for axis in range(3):
			if float(box_data[box_index * 6 + axis]) > float(box_data[box_index * 6 + 3 + axis]):
				_fatal("load_region collision_lineage col has inverted box bounds", 4)
				return false
	return true


func _finite_vector3(value: Variant) -> bool:
	if not value is Vector3:
		return false
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


func _finite_quaternion(value: Variant) -> bool:
	if not value is Quaternion:
		return false
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z) and is_finite(value.w)


func _paired_data_summary() -> Dictionary:
	if _region_collision.is_empty():
		return {"present": false}
	var child: Dictionary = _region_collision.get("child", {})
	var parent: Dictionary = _region_collision.get("parent", {})
	var col: Dictionary = _region_collision.get("col", {})
	return {
		"present": true,
		"generation": int(_region_collision.get("generation", _publication_revision)),
		"child_model_id": int(child.get("model_id", -1)),
		"child_model": str(child.get("model", "")),
		"child_mesh_index": int(child.get("mesh_index", -1)),
		"parent_model_id": int(parent.get("model_id", -1)),
		"parent_model": str(parent.get("model", "")),
		"parent_mesh_index": int(parent.get("mesh_index", -1)),
		"header_id": int(col.get("header_id", -1)),
		"faces": int(col.get("faces", 0)),
		"vertex_count": int(col.get("vertex_count", 0)),
		"spheres": int(col.get("spheres", 0)),
		"boxes": int(col.get("boxes", 0)),
	}


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
	# Explicit unbudgeted flush path reusing the same stepper: frees hidden
	# staging and hidden retiring immediately (blocking), then active.
	# Persistent roots stay attached (empty); no whole-generation dict clear
	# avalanche in normal budgeted commits (holds moved O(1) there).
	_flush_region_budget_unbudgeted()
	_lab_deferred_ready = {}
	_lab_deferred_discard_pending = false
	_lab_staging_active = false
	_lab_candidate_meshes = []
	_lab_candidate_stats = {}
	_lab_candidate_collision = {}
	_lab_candidate_staged_instances = []
	_lab_candidate_staged_materials = []
	_lab_candidate_mesh_holds = []
	_lab_candidate_texture_holds = []
	_lab_candidate_current_instance = null
	_lab_candidate_next_mesh = 0
	_lab_candidate_next_surface = 0
	_lab_candidate_staging_ms_total = 0.0
	_lab_candidate_sync_prefix_ms = 0.0
	_lab_candidate_started_usec = 0
	_lab_retire_active = false
	_lab_retire_material_holds = []
	_lab_retire_mesh_holds = []
	_lab_retire_texture_holds = []
	_lab_retire_metadata_holds = []
	_lab_staged_discards = 0
	_last_bridge_retire_pending = 0
	_last_bridge_staged_discards = 0
	_last_bridge_progress = {}
	if is_instance_valid(_region_root_a):
		for child in _region_root_a.get_children():
			_region_root_a.remove_child(child)
			child.free()
	if is_instance_valid(_region_root_b):
		for child in _region_root_b.get_children():
			_region_root_b.remove_child(child)
			child.free()
	# Legacy direct children (pre-A06 scenes) flushed as well, but roots stay.
	if mesh_root != null:
		for child in mesh_root.get_children():
			if child != _region_root_a and child != _region_root_b:
				mesh_root.remove_child(child)
				child.free()
	_materials.clear()
	_active_mesh_holds.clear()
	_active_texture_holds.clear()
	_active_metadata_holds.clear()
	_resident_meshes = 0
	_resident_surfaces = 0
	_region_stats.clear()
	_region_collision.clear()
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
	# P1-A05/A06: normal movement submits async, never a blocking wait. The old
	# complete world stays active while pending/staging; no frame stalls on raw
	# parse. While the one retiring generation drains, new admission blocks as
	# busy and camera intent is naturally retried on a later frame.
	if _lab_retire_active or not _lab_deferred_ready.is_empty() or _last_bridge_retire_pending > 0:
		# Do not queue unbounded supersedes while retiring/deferred held; retry after drain.
		return
	var camera_sa := _world_to_sa(camera.global_position)
	var reload_threshold := _region_reload_threshold()
	if _pending_region_active:
		if _region_retry_suppressed and _planar_region_distance(camera_sa, _failed_region_center_sa) < reload_threshold:
			_restore_accepted_camera()
			return
		# Camera returned to the already-active world: discard the stale
		# pending instead of republishing the same center.
		if _has_published_region and _planar_region_distance(camera_sa, _loaded_center_sa) < reload_threshold:
			_cancel_pending_region()
			_remember_accepted_camera()
			return
		# Ignore duplicates near the same pending center; allow the latest to
		# supersede only when the camera moved meaningfully from it. Never
		# submit identical work every frame.
		if _planar_region_distance(camera_sa, _pending_region_center_sa) < reload_threshold:
			return
		if _region_retry_suppressed and _planar_region_distance(camera_sa, _failed_region_center_sa) >= reload_threshold:
			_region_retry_suppressed = false
		_region_retry_suppressed = false
		_submit_region_async(camera_sa)
		return
	var planar_delta := Vector2(camera_sa.x - _loaded_center_sa.x, camera_sa.y - _loaded_center_sa.y)
	if planar_delta.length() < reload_threshold:
		_remember_accepted_camera()
		if _region_retry_suppressed and _planar_region_distance(camera_sa, _failed_region_center_sa) >= reload_threshold:
			_region_retry_suppressed = false
		return
	if _region_retry_suppressed and _planar_region_distance(camera_sa, _failed_region_center_sa) < reload_threshold:
		_restore_accepted_camera()
		return
	_region_retry_suppressed = false
	_submit_region_async(camera_sa)


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
	# Fixed captures must never carry a stale async commit: cancel and consume
	# outstanding async before any sync diagnostic or frame hold.
	_drain_pending_for_sync("capture-fixed")
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
	_drain_pending_for_sync("capture-manual")
	if _shutdown_started or _has_pending_region() or _region_budget_busy():
		_capture_pending = false
		_capture_hold = false
		return
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
	_csv_file.store_line("frame,runtime_seconds,cpu_frame_interval_ms,cpu_process_ms,cpu_physics_ms,engine_static_memory_bytes,engine_static_memory_peak_bytes,resource_count,render_objects,render_primitives,render_draw_calls,route_enabled,capture_hold,route_clock_seconds,route_pass,route_pass_seconds,route_segment,environment_transition,open_game_sync_stall_ms,environment_cache_sync_stall_ms,load_count,last_bridge_load_call_ms,last_region_publication_stall_ms,total_region_publication_stall_ms,resident_meshes,resident_surfaces,bridge_region_stats_json,wall_seconds,pending_request_id,pending_session_epoch,last_raw_parse_ms,async_submit_count,async_ready_count,async_error_count,async_cancel_count,last_request_id,last_session_epoch,f6_ignored_while_pending,budget_items,conversion_ms_total,conversion_ms_max_item,conversion_frames,commit_ms,staging_ms_total,publication_elapsed_ms,retire_ms_max_item,retire_pending,staged_discards,bridge_retire_pending,bridge_staged_discards")
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
		_pending_region_request_id if _pending_region_active else 0,
		_pending_region_session_epoch if _pending_region_active else 0,
		"%.4f" % _last_region_raw_parse_ms,
		_async_submit_count,
		_async_ready_count,
		_async_error_count,
		_async_cancel_count,
		_last_region_request_id,
		_last_region_session_epoch,
		_f6_ignored_while_pending,
		_budget_items,
		"%.4f" % _last_region_conversion_ms_total,
		"%.4f" % _last_region_conversion_ms_max_item,
		_last_region_conversion_frames,
		"%.4f" % _last_region_commit_ms,
		"%.4f" % _last_region_staging_ms_total,
		"%.4f" % _last_region_publication_elapsed_ms,
		"%.4f" % _last_region_retire_ms_max_item,
		_lab_retire_pending_count(),
		_lab_staged_discards,
		_last_bridge_retire_pending,
		_last_bridge_staged_discards,
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
			"paired_data": _paired_data_summary(),
			"pending_request": {
				"active": _pending_region_active,
				"request_id": _pending_region_request_id if _pending_region_active else 0,
				"session_epoch": _pending_region_session_epoch if _pending_region_active else 0,
				"center_sa": _vector_to_array(_pending_region_center_sa) if _pending_region_active else [],
				"discarded_stale": _pending_region_discarded_stale,
			},
			"last_async": {
				"request_id": _last_region_request_id,
				"session_epoch": _last_region_session_epoch,
				"raw_parse_ms": _last_region_raw_parse_ms,
				"conversion_ms_total": _last_region_conversion_ms_total,
				"conversion_ms_max_item": _last_region_conversion_ms_max_item,
				"conversion_frames": _last_region_conversion_frames,
				"staging_ms_total": _last_region_staging_ms_total,
				"commit_ms": _last_region_commit_ms,
				"publication_elapsed_ms": _last_region_publication_elapsed_ms,
				"retire_ms_max_item": _last_region_retire_ms_max_item,
				"retire_pending": _lab_retire_pending_count(),
				"staged_discards": _lab_staged_discards,
				"bridge_retire_pending": _last_bridge_retire_pending,
				"bridge_staged_discards": _last_bridge_staged_discards,
				"bridge_progress": _last_bridge_progress.duplicate(true),
				"budget_items": _budget_items,
				"budget_busy": _region_budget_busy(),
				"lab_staging_active": _lab_staging_active,
				"lab_retire_active": _lab_retire_active,
				"submit_count": _async_submit_count,
				"ready_count": _async_ready_count,
				"error_count": _async_error_count,
				"cancel_count": _async_cancel_count,
				"f6_ignored_while_pending": _f6_ignored_while_pending,
			},
			"budget": {
				"budget_items": _budget_items,
				"quota_label": "quota work items: one hidden node add or one hidden ShaderMaterial creation counts as one staging item; one hidden node free or one flat ref-hold drop counts as one retirement item; whole-scene commit is never one unit",
				"overshoot_note": "nonpreemptible Godot calls (single texture upload, single surface add, single free, two root visibility flips) are measured atomic units: time overshoot remains possible while work-item counts stay bounded; not a hard deadline/FPS claim. Bridge budgeted-free totals/max are in bridge_progress; sync/teardown flushes are explicitly unbudgeted",
				"staging_active": _lab_staging_active,
				"retire_active": _lab_retire_active,
				"retire_pending": _lab_retire_pending_count(),
				"staged_discards": _lab_staged_discards,
				"busy": _region_budget_busy(),
			},
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
			"publication": "bounded replacement; the previous complete publication remains active until a valid candidate is fully staged. Initial and fixed captures use synchronous diagnostics; movement/F6 use async submit plus nonblocking poll",
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
			"last_region_raw_parse_ms": _last_region_raw_parse_ms,
			"conversion_ms_total": _last_region_conversion_ms_total,
			"conversion_ms_max_item": _last_region_conversion_ms_max_item,
			"conversion_frames": _last_region_conversion_frames,
			"staging_ms_total": _last_region_staging_ms_total,
			"commit_ms": _last_region_commit_ms,
			"publication_elapsed_ms": _last_region_publication_elapsed_ms,
			"retire_ms_max_item": _last_region_retire_ms_max_item,
			"retire_pending": _lab_retire_pending_count(),
			"staged_discards": _lab_staged_discards,
			"bridge_retire_pending": _last_bridge_retire_pending,
			"bridge_staged_discards": _last_bridge_staged_discards,
			"budget_items": _budget_items,
			"async_submit_count": _async_submit_count,
			"async_ready_count": _async_ready_count,
			"async_error_count": _async_error_count,
			"async_cancel_count": _async_cancel_count,
			"timing_split": "stall_ms is aggregated measured main-thread work only, never multi-frame elapsed: sync = bridge_load_call_ms (blocking worker wait+conversion) + staging_ms_total + commit_ms; async = conversion_ms_total + staging_ms_total + commit_ms (ready-poll call excluded to avoid double-counting conversion); staging_ms_total is lab validation/setup plus node/material items, excludes commit and free-frame intervals; publication_elapsed_ms is wall candidate-start to commit-end diagnostic only, never added; raw_parse_ms is worker parse+plan off main; retire_ms_max_item is lab single-free max, separate; discarded/cancelled/rejected partial staging never publishes; quota work items may honestly overshoot on nonpreemptible Godot calls, not a hard deadline/FPS claim",
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
			"Async raw parse runs off main; main conversion/publication/retirement is quota-budgeted per frame but single Godot calls and two root flips are measured atomic units that may overshoot. No hitch-free or faster-GPU claim.",
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
	status_label.text += "sync open %.2f ms | env %.2f ms | publish-work last %.2f ms total %.2f ms (elapsed last %.2f ms diag only) | worker parse+plan last %.2f ms\n" % [_open_game_stall_ms, _environment_cache_stall_ms, _last_load_stall_ms, _total_load_stall_ms, _last_region_publication_elapsed_ms, _last_region_raw_parse_ms]
	status_label.text += "budget %d/frame conv total %.2f max_item %.2f frames %d staging %.2f commit %.2f retire_max %.2f retire_pending %d staged_discards %d\n" % [_budget_items, _last_region_conversion_ms_total, _last_region_conversion_ms_max_item, _last_region_conversion_frames, _last_region_staging_ms_total, _last_region_commit_ms, _last_region_retire_ms_max_item, _lab_retire_pending_count(), _lab_staged_discards]
	if _pending_region_active:
		status_label.text += "async pending req %d epoch %d discarded %d\n" % [_pending_region_request_id, _pending_region_session_epoch, _pending_region_discarded_stale]
	else:
		status_label.text += "async idle submits %d ready %d err %d cancel %d last req %d\n" % [_async_submit_count, _async_ready_count, _async_error_count, _async_cancel_count, _last_region_request_id]
	if _lab_staging_active or _lab_retire_active:
		status_label.text += "lab staging=%s retire_active=%s busy=%s bridge_retire=%d\n" % ["yes" if _lab_staging_active else "no", "yes" if _lab_retire_active else "no", "yes" if _region_budget_busy() else "no", _last_bridge_retire_pending]
	if _f6_ignored_while_pending > 0:
		status_label.text += "F6 ignored while pending: %d\n" % _f6_ignored_while_pending
	if _region_candidate_unavailable:
		status_label.text += "REGION CANDIDATE UNAVAILABLE: %s | showing committed revision %d; F6 retry\n" % [_bounded_status_string(_last_region_error.get("error", "unspecified bridge error"), 180), _publication_revision]
	status_label.text += "WASD move  Q/E fall/rise  Shift fast  RMB look  Esc release/quit  R route\n"
	status_label.text += "1 clear  2 evening  3 night  4 overcast | F1-F4 diagnostics | F5 PC filter | F6 retry | F12 capture\n"
	status_label.text += "LOD unavailable | gameplay collision unsupported\n"
	var paired_summary := _paired_data_summary()
	if bool(paired_summary.get("present", false)):
		status_label.text += "paired data: %d->%d COL %df (data only, no gameplay)\n" % [int(paired_summary.get("child_model_id", -1)), int(paired_summary.get("parent_model_id", -1)), int(paired_summary.get("faces", 0))]
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
	# P1-A05/A06: cancel/consume outstanding async before RW shutdown so no
	# stale commit lands during teardown, then prevent deferred callbacks.
	# Explicit unbudgeted flush reusing the same stepper drains hidden staging
	# (to retiring, old retained) and hidden retiring immediately. Active
	# complete generation stays for inspection; scene free releases it.
	if (_pending_region_active or not _lab_deferred_ready.is_empty()) and _bridge != null and _bridge_open:
		if _bridge.has_method("cancel_region") and _pending_region_active:
			var _cancel_id := _pending_region_request_id
			var _cancel_out: Variant = _bridge.call("cancel_region", _cancel_id)
		if _bridge.has_method("poll_region"):
			var _drain_out: Variant = _bridge.call("poll_region")
			_update_bridge_progress_diagnostics(_drain_out if _drain_out is Dictionary else {})
			_pending_region_active = false
			_pending_region_request_id = 0
			_pending_region_session_epoch = 0
			if _drain_out is Dictionary and str(_drain_out.get("status", "")) == "cancelled":
				_async_cancel_count += 1
		else:
			_pending_region_active = false
			_pending_region_request_id = 0
			_pending_region_session_epoch = 0
	if not _lab_deferred_ready.is_empty():
		# Teardown explicit unbudgeted flush per contract: retire deferred via
		# the single queue then flush below (no budgeted drain at shutdown).
		_lab_deferred_discard_pending = true
		_pending_region_active = false
		_pending_region_request_id = 0
		_pending_region_session_epoch = 0
	if _lab_staging_active:
		_discard_staging_to_retiring("teardown")
		_pending_region_active = false
		_pending_region_request_id = 0
		_pending_region_session_epoch = 0
	_flush_region_budget_unbudgeted()
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
	# Current environment changes apply to hidden staged materials as well so
	# the first visible frame is not stale; no artistic changes.
	var result := _materials.duplicate()
	result.append_array(_lab_candidate_staged_materials)
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
