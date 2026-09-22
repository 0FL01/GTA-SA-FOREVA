extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> bool:
	if value:
		return true
	printerr("frontend-lifecycle-godot-fail: ", message)
	quit(1)
	return false

func _run() -> void:
	if not GDExtensionManager.is_extension_loaded("res://sa_legacy.gdextension"):
		if not _check(GDExtensionManager.load_extension("res://sa_legacy.gdextension") == GDExtensionManager.LOAD_STATUS_OK, "extension load"):
			return
	var owner = ClassDB.instantiate("SALegacyFrontend")
	if not _check(owner != null, "registered frontend owner"):
		return
	var state: Dictionary = owner.initialize(7, 1001, 10)
	if not _check(state.ok and state.screen == 34 and state.frontend_active and state.display.brightness == 256, "source main menu defaults"):
		return
	state = owner.start_game(20, Vector2(2495, -1685), 1)
	if not _check(state.ok and state.in_game and not state.frontend_active, "frontend to game"):
		return
	state = owner.set_camera_directly_behind(21, Vector3.RIGHT)
	var game_camera := {"mode": state.camera_mode, "kind": state.camera_target_kind,
		"identity": state.camera_target_identity, "behind": state.camera_directly_behind}
	if not _check(state.ok and game_camera.behind, "source camera ownership"):
		return
	if not _check(owner.pause(30, 2).ok and owner.open_map(31, 3).ok and
		owner.pan_map(32, Vector2(64, -32), 4).ok and owner.zoom_map(33, 2.0, 5).ok,
		"game to map"):
		return
	var map_state: Dictionary = owner.snapshot().duplicate(true)
	if not _check(map_state.screen == 5 and map_state.map_center == Vector2(2559, -1717) and map_state.map_zoom == 2.0, "map authority"):
		return
	if not _check(owner.back(34, 6).ok and owner.open_options(35, 7).ok and owner.open_display(36, 8).ok, "map to settings"):
		return
	var settings: Dictionary = owner.snapshot().display.duplicate(true)
	settings.brightness = 300
	settings.hud = false
	settings.radar_mode = 1
	settings.subtitles = false
	if not _check(owner.set_display(37, settings, 9).ok and owner.back(38, 10).ok and
		owner.back(39, 11).ok and owner.resume(40, 12).ok, "settings to game"):
		return
	var restored: Dictionary = owner.snapshot()
	if not _check(restored.in_game and not restored.paused and not restored.frontend_active and
		restored.display == settings and restored.map_center == map_state.map_center and
		restored.map_zoom == map_state.map_zoom and restored.camera_mode == game_camera.mode and
		restored.camera_target_kind == game_camera.kind and restored.camera_target_identity == game_camera.identity and
		restored.camera_directly_behind and restored.events.size() == 13,
		"authoritative state restored"):
		return
	var frozen := restored.duplicate(true)
	var rejected: Dictionary = owner.resume(41, 13)
	if not _check(not rejected.ok and rejected.status == "invalid_state" and owner.snapshot() == frozen,
		"invalid transition atomic"):
		return
	if not _check(not restored.presentation_feedback and restored.camera_view == "unsupported",
		"no presentation feedback"):
		return
	print("frontend-lifecycle-godot-ok route=frontend,game,map,settings,game events=", restored.events.size(),
		" brightness=", restored.display.brightness, " hud=", int(restored.display.hud),
		" radar=", restored.display.radar_mode, " camera=", restored.camera_mode, " feedback=0")
	quit(0)
