extends SceneTree

const ROADS := Vector3(1532.054688, -1662.289063, 12.460938)
const RADAR := Vector3(-1687.414063, -623.023438, 18.148438)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var lab: Node = load("res://lab.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	if not _check(lab._has_published_region and not lab._shutdown_started, "initial real region"):
		return
	lab.camera.position = Vector3(ROADS.x, ROADS.z + 20.0, -ROADS.y + 20.0)
	lab._camera_target_world = Vector3(ROADS.x, ROADS.z, -ROADS.y)
	lab.camera.look_at(lab._camera_target_world)
	if not _check(lab._load_region(ROADS), "finite roads replacement"):
		return
	var nodes: Array = lab.mesh_root.get_children().map(func(node: Node) -> int: return node.get_instance_id())
	var stats: Dictionary = lab._region_stats.duplicate(true)
	var revision: int = lab._publication_revision
	if not _check(not lab._load_region(RADAR), "NaN must reject"):
		return
	if not _check(not lab._shutdown_started and lab._last_region_error.error_code == "nonfinite_uv", "live classified rejection"):
		return
	if not _check(lab._publication_revision == revision and lab._loaded_center_sa == ROADS and lab._region_stats == stats, "unchanged committed state"):
		return
	if not _check(nodes == lab.mesh_root.get_children().map(func(node: Node) -> int: return node.get_instance_id()), "retained nodes"):
		return
	var count: int = lab._load_count
	for attempt in range(3):
		lab.camera.position = Vector3(RADAR.x, RADAR.z, -RADAR.y)
		lab._maybe_reload_region()
	if not _check(lab._load_count == count, "rejected center retry suppression"):
		return
	var retry := InputEventKey.new()
	var async_count: int = lab._async_submit_count
	retry.physical_keycode = KEY_F6
	retry.pressed = true
	lab._unhandled_input(retry)
	var deadline := Time.get_ticks_msec() + 30000
	while lab._has_pending_region() and Time.get_ticks_msec() < deadline:
		lab._poll_pending_region()
		await process_frame
	if not _check(not lab._has_pending_region() and lab._async_submit_count == async_count + 1 and lab._load_count == count and lab._publication_revision == revision, "explicit async retry without publication"):
		return
	await lab._capture_current("p0-retained-rejection")
	if not _check(lab._load_region(ROADS), "recovery after rejection"):
		return
	if not _check(lab._publication_revision == revision + 1, "success commits next revision"):
		return
	# Destroy the real host while a capture is deferred; it must not publish later.
	lab._frame_count = 99999
	var cancelled_path: String = lab._capture_dir.path_join("%s-manual-099999.png" % lab._profile_id())
	lab.call_deferred("_capture_manual")
	lab.free()
	await process_frame
	await process_frame
	if not _check(not FileAccess.file_exists(cancelled_path), "teardown cancels deferred capture"):
		return
	print("region-lab-ok real-replacement retained-nan retry recovery teardown")
	quit(0)

func _check(condition: bool, label: String) -> bool:
	if not condition:
		printerr("region-lab-fail: ", label)
		quit(1)
	return condition
