extends SceneTree

# P1-A05 async region gate: decisive actual bridge + lab fixture.
# Real IO timing never proves queued vs in-flight; the C++ worker unit with
# synthetic CV barriers proves queued/in-flight deterministically. This script
# only proves latest-only publication, cancel/error semantics, epoch/ID
# monotonicity, and that the lab moves/F6 via async submit plus nonblocking
# poll through the shared validate/commit helper. No CPU image parity is
# claimed here.
const GROVE_CENTER_SA := Vector3(2490.0, -1665.0, 14.0)
const ROADS_CENTER_SA := Vector3(1532.054688, -1662.289063, 12.460938)
const INVALID_RADAR_CENTER_SA := Vector3(-1687.414063, -623.023438, 18.148438)
const MAX_POLL_FRAMES := 1800
const POLL_DEADLINE_MSEC := 90000

var _bridge: Object
var _bridge_open := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	if not bool(options.get("ok", false)):
		printerr("region-async-fail: ", str(options.get("error", "bad options")))
		quit(2)
		return
	if not GDExtensionManager.is_extension_loaded("res://sa_legacy.gdextension"):
		if GDExtensionManager.load_extension("res://sa_legacy.gdextension") != GDExtensionManager.LOAD_STATUS_OK:
			printerr("region-async-fail: extension load failed")
			quit(3)
			return
	if not ClassDB.class_exists("SALegacyBridge"):
		printerr("region-async-fail: SALegacyBridge not registered")
		quit(3)
		return
	_bridge = ClassDB.instantiate("SALegacyBridge")
	if _bridge == null:
		printerr("region-async-fail: cannot instantiate bridge")
		quit(3)
		return
	for method in ["open_game", "load_region", "submit_region", "poll_region", "cancel_region", "environment", "close_game"]:
		if not _bridge.has_method(method):
			printerr("region-async-fail: missing bridge method ", method)
			quit(3)
			return
	if not await _run_bridge_direct(options.game_dir):
		return
	# Resource handover: close the direct owner before instantiating the lab
	# owner. The process-global pager allows exactly one owner.
	_close_bridge()
	_bridge = null
	if not await _run_lab_fixture():
		return
	print("region-async-ok latest-only cancel sync-reject pair-122 retained reopen-epoch lab-async evidence=none(no-image-parity)")
	quit(0)


func _run_bridge_direct(game_dir: String) -> bool:
	var opened: Dictionary = _bridge.call("open_game", game_dir, 350.0, 256)
	if not _check(bool(opened.get("ok", false)), "direct open: " + str(opened.get("error", ""))):
		return false
	_bridge_open = true
	var epoch0 := int(opened.get("session_epoch", 0))
	if not _check(epoch0 > 0, "direct open epoch nonzero"):
		return false
	if not _check(int(opened.get("publication_revision", -1)) == 0, "direct open rev 0"):
		return false
	# Submit Roads then Grove before any poll: only the latest may publish.
	var submit_roads: Dictionary = _bridge.call("submit_region", ROADS_CENTER_SA)
	if not _check(bool(submit_roads.get("ok", false)), "submit roads: " + str(submit_roads.get("error", ""))):
		return false
	var roads_id := int(submit_roads.get("request_id", 0))
	var roads_epoch := int(submit_roads.get("session_epoch", 0))
	if not _check(roads_id > 0 and roads_epoch == epoch0, "roads id/epoch"):
		return false
	var submit_grove: Dictionary = _bridge.call("submit_region", GROVE_CENTER_SA)
	if not _check(bool(submit_grove.get("ok", false)), "submit grove supersede: " + str(submit_grove.get("error", ""))):
		return false
	var grove_id := int(submit_grove.get("request_id", 0))
	if not _check(grove_id == roads_id + 1, "monotonic IDs per bridge"):
		return false
	if not _check(int(submit_grove.get("session_epoch", 0)) == epoch0, "epoch per open"):
		return false
	if not _check(int(submit_grove.get("discarded_stale", 0)) == int(submit_roads.get("discarded_stale", 0)) + 1, "supersede counts discarded stale"):
		return false
	# Sync while async pending must reject, revision unchanged.
	var sync_while_pending: Dictionary = _bridge.call("load_region", GROVE_CENTER_SA)
	if not _check(not bool(sync_while_pending.get("ok", true)), "sync while pending must reject"):
		return false
	if not _check(str(sync_while_pending.get("error_code", "")) == "async_request_pending", "sync reject code async_request_pending"):
		return false
	# Only the latest publishes; one-shot poll then idle.
	var first: Dictionary = await _await_bridge_terminal(grove_id)
	if not _check(str(first.get("status", "")) == "ready" and bool(first.get("ok", false)), "grove latest ready, roads never published"):
		return false
	if not _check(int(first.get("request_id", 0)) == grove_id, "ready is grove id, not roads"):
		return false
	if not _check(int(first.get("publication_revision", -1)) == 1, "first publication rev 1"):
		return false
	var idle: Dictionary = _bridge.call("poll_region")
	if not _check(str(idle.get("status", "")) == "idle" and not bool(idle.get("ok", false)), "ready is one-shot, next poll idle (idle ok=false not failure)"):
		return false
	# Cancel before poll returns cancelled with no revision advance.
	var submit_cancel: Dictionary = _bridge.call("submit_region", ROADS_CENTER_SA)
	if not _check(bool(submit_cancel.get("ok", false)), "submit for cancel"):
		return false
	var cancel_id := int(submit_cancel.get("request_id", 0))
	var cancelled_ack: Dictionary = _bridge.call("cancel_region", cancel_id)
	if not _check(bool(cancelled_ack.get("ok", false)), "cancel before poll ack"):
		return false
	var cancelled: Dictionary = await _await_bridge_terminal(cancel_id)
	if not _check(str(cancelled.get("status", "")) == "cancelled" and not bool(cancelled.get("ok", false)), "cancel confirmation once via poll"):
		return false
	if not _check(str(cancelled.get("error_code", "")) == "cancelled", "cancelled code"):
		return false
	if not _check(int(cancelled.get("publication_revision", -1)) == 1, "cancel causes no revision advance"):
		return false
	var idle2: Dictionary = _bridge.call("poll_region")
	if not _check(str(idle2.get("status", "")) == "idle", "cancel is one-shot, next idle"):
		return false
	# Clear the earlier sync-reject pending? Already consumed grove; now submit
	# a fresh pending to re-test sync reject then drain it.
	var submit_block: Dictionary = _bridge.call("submit_region", ROADS_CENTER_SA)
	if not _check(bool(submit_block.get("ok", false)), "submit block for sync reject"):
		return false
	var block_id := int(submit_block.get("request_id", 0))
	var sync_reject: Dictionary = _bridge.call("load_region", GROVE_CENTER_SA)
	if not _check(not bool(sync_reject.get("ok", true)) and str(sync_reject.get("error_code", "")) == "async_request_pending", "sync while pending rejects"):
		return false
	var unblock: Dictionary = _bridge.call("cancel_region", block_id)
	if not _check(bool(unblock.get("ok", false)), "unblock cancel"):
		return false
	var unblocked: Dictionary = await _await_bridge_terminal(block_id)
	if not _check(str(unblocked.get("status", "")) == "cancelled", "unblock poll cancelled"):
		return false
	# Actual Roads ready carries the A04 pair: 122 COL faces plus two real roles.
	var submit_roads2: Dictionary = _bridge.call("submit_region", ROADS_CENTER_SA)
	if not _check(bool(submit_roads2.get("ok", false)), "submit roads2"):
		return false
	var roads2_id := int(submit_roads2.get("request_id", 0))
	var roads2: Dictionary = await _await_bridge_terminal(roads2_id)
	if not _check(str(roads2.get("status", "")) == "ready" and bool(roads2.get("ok", false)), "roads2 ready: " + str(roads2.get("error", ""))):
		return false
	if not _check(int(roads2.get("publication_revision", -1)) == 2, "roads2 rev 2"):
		return false
	if not _check(_validate_bridge_pair(roads2), "roads2 pair validation"):
		return false
	if not _check(roads2.get("stats") is Dictionary and (roads2.stats.get("raw_parse_ms") is float or roads2.stats.get("raw_parse_ms") is int), "roads2 stats carry raw_parse_ms"):
		return false
	# Hold the returned payload across close: packed bytes must stay readable.
	var held_lineage: Dictionary = (roads2.get("collision_lineage", {}) as Dictionary).duplicate(true)
	var held_meshes: Array = roads2.get("meshes", [])
	var held_ids := PackedInt64Array()
	for info in held_meshes:
		held_ids.append((info.mesh as ArrayMesh).get_instance_id())
	var rev_before_close := int(roads2.get("publication_revision", 0))
	# Close with pending outstanding, then reopen: epoch higher, IDs nonreused,
	# sequence preserved, no old result.
	var submit_hang: Dictionary = _bridge.call("submit_region", GROVE_CENTER_SA)
	if not _check(bool(submit_hang.get("ok", false)), "submit hang for close"):
		return false
	var hang_id := int(submit_hang.get("request_id", 0))
	var discarded_before := int(submit_hang.get("discarded_stale", 0))
	_bridge.call("close_game")
	_bridge_open = false
	if not _check(_deep_equal(held_lineage, held_lineage.duplicate(true)), "held lineage self-consistent across close"):
		return false
	if not _check(int(held_lineage.col.faces) == 122, "held 122 faces readable across close"):
		return false
	for i in range(held_meshes.size()):
		var mesh: ArrayMesh = (held_meshes[i] as Dictionary).mesh
		if not _check(is_instance_valid(mesh) and mesh.get_instance_id() == held_ids[i] and mesh.get_surface_count() > 0, "held mesh readable across close"):
			return false
	var reopened: Dictionary = _bridge.call("open_game", game_dir, 350.0, 256)
	if not _check(bool(reopened.get("ok", false)), "reopen: " + str(reopened.get("error", ""))):
		return false
	_bridge_open = true
	if not _check(int(reopened.get("session_epoch", 0)) > epoch0, "reopen epoch higher"):
		return false
	if not _check(int(reopened.get("publication_revision", -1)) == rev_before_close, "close/reopen preserves publication sequence"):
		return false
	var idle_after_reopen: Dictionary = _bridge.call("poll_region")
	if not _check(str(idle_after_reopen.get("status", "")) == "idle", "no old result after reopen"):
		return false
	var submit_after: Dictionary = _bridge.call("submit_region", GROVE_CENTER_SA)
	if not _check(bool(submit_after.get("ok", false)), "submit after reopen"):
		return false
	if not _check(int(submit_after.get("request_id", 0)) == hang_id + 1, "request IDs never reused"):
		return false
	if not _check(int(submit_after.get("discarded_stale", -1)) == discarded_before, "discarded counter preserved across reopen"):
		return false
	var after_id := int(submit_after.get("request_id", 0))
	var after_ready: Dictionary = await _await_bridge_terminal(after_id)
	if not _check(str(after_ready.get("status", "")) == "ready" and int(after_ready.get("publication_revision", -1)) == rev_before_close + 1, "post-reopen publish advances"):
		return false
	return true


func _run_lab_fixture() -> bool:
	var lab: Node = load("res://lab.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	if not _check(is_instance_valid(lab) and lab._has_published_region and not lab._shutdown_started, "lab initial sync diagnostic region"):
		return false
	var initial_rev: int = lab._publication_revision
	var initial_loads: int = lab._load_count
	# Roads via lab async: move camera, submit, old world retained until poll.
	lab.camera.position = Vector3(ROADS_CENTER_SA.x, ROADS_CENTER_SA.z + 20.0, -ROADS_CENTER_SA.y + 20.0)
	lab._camera_target_world = Vector3(ROADS_CENTER_SA.x, ROADS_CENTER_SA.z, -ROADS_CENTER_SA.y)
	lab.camera.look_at(lab._camera_target_world)
	var held_nodes: Array = _lab_active_node_ids(lab)
	var held_mesh_ids: Array = _lab_active_mesh_ids(lab)
	var held_collision: Dictionary = lab._region_collision.duplicate(true)
	lab._maybe_reload_region()
	if not _check(lab._has_pending_region(), "lab normal movement uses async submit"):
		return false
	if not _check(lab._load_count == initial_loads, "async submit causes no sync load (polls commit, not sync)"):
		return false
	if not _check(lab._publication_revision == initial_rev, "old world retained while pending"):
		return false
	if not _check(_lab_active_node_ids(lab) == held_nodes, "old nodes retained while pending"):
		return false
	# Duplicate near the same pending center must not resubmit every frame.
	var submits_before: int = lab._async_submit_count
	lab._maybe_reload_region()
	if not _check(lab._async_submit_count == submits_before, "no identical resubmit every frame"):
		return false
	if not await _await_lab_settled(lab):
		printerr("region-async-fail: lab roads async deadline")
		quit(1)
		return false
	if not _check(lab._publication_revision == initial_rev + 1, "lab async poll commits next revision"):
		return false
	if not _check(lab._load_count == initial_loads, "lab async commit did not use sync path"):
		return false
	if not _check(_validate_lab_pair(lab, "lab roads pair"), "lab roads pair"):
		return false
	if not _check((lab._region_stats.get("raw_parse_ms") is float or lab._region_stats.get("raw_parse_ms") is int), "lab stats carry raw_parse_ms scalar"):
		return false
	var roads_rev: int = lab._publication_revision
	var roads_nodes: Array = _lab_active_node_ids(lab)
	var roads_meshes: Array = _lab_active_mesh_ids(lab)
	var roads_collision: Dictionary = lab._region_collision.duplicate(true)
	var roads_stats: Dictionary = lab._region_stats.duplicate(true)
	# Invalid radar via async errors but retains active mesh IDs, COL packed
	# bytes, and revision.
	var bad_submit: Dictionary = lab._submit_region_async(INVALID_RADAR_CENTER_SA)
	if not _check(bool(bad_submit.get("ok", false)), "invalid radar async submit accepted"):
		return false
	if not _check(lab._has_pending_region(), "invalid pending active"):
		return false
	if not _check(lab._publication_revision == roads_rev and _lab_active_node_ids(lab) == roads_nodes, "old world retained before error poll"):
		return false
	if not await _await_lab_settled(lab):
		printerr("region-async-fail: lab invalid async deadline")
		quit(1)
		return false
	if not _check(not lab._shutdown_started and str(lab._last_region_error.get("error_code", "")) == "nonfinite_uv", "invalid async classified error"):
		return false
	if not _check(lab._publication_revision == roads_rev, "async error retains revision"):
		return false
	if not _check(_lab_active_node_ids(lab) == roads_nodes, "async error retains node IDs"):
		return false
	if not _check(_lab_active_mesh_ids(lab) == roads_meshes, "async error retains mesh resources"):
		return false
	if not _check(_deep_equal(lab._region_collision, roads_collision), "async error retains COL packed bytes"):
		return false
	if not _check(_deep_equal(lab._region_stats, roads_stats), "async error retains stats"):
		return false
	# P0 suppression: repeated near-center attempts must not resubmit.
	var err_submits: int = lab._async_submit_count
	for _attempt in range(3):
		lab.camera.position = Vector3(INVALID_RADAR_CENTER_SA.x, INVALID_RADAR_CENTER_SA.z, -INVALID_RADAR_CENTER_SA.y)
		lab._maybe_reload_region()
	if not _check(lab._async_submit_count == err_submits, "failed-center suppression holds for async"):
		return false
	# Explicit F6 retry uses async, not sync.
	var loads_before_f6: int = lab._load_count
	lab._maybe_reload_region()
	var retry_key := InputEventKey.new()
	retry_key.physical_keycode = KEY_F6
	retry_key.pressed = true
	lab._unhandled_input(retry_key)
	if not _check(lab._has_pending_region(), "F6 uses async submit"):
		return false
	if not _check(lab._load_count == loads_before_f6, "F6 async causes no sync load"):
		return false
	# F6 while pending is ignored and documented, pending unchanged.
	var pending_id: int = lab._pending_region_request_id
	var f6_ignored_before: int = lab._f6_ignored_while_pending
	lab._unhandled_input(retry_key)
	if not _check(lab._has_pending_region() and lab._pending_region_request_id == pending_id, "F6 while pending keeps pending"):
		return false
	if not _check(lab._f6_ignored_while_pending == f6_ignored_before + 1, "F6 while pending documented"):
		return false
	if not await _await_lab_settled(lab):
		printerr("region-async-fail: lab F6 async deadline")
		quit(1)
		return false
	if not _check(lab._publication_revision == roads_rev, "F6 error advances no revision"):
		return false
	if not _check(_deep_equal(lab._region_collision, roads_collision), "F6 error retains COL"):
		return false
	# A manual capture must cancel outstanding work before its held frames;
	# even a ready-but-unpolled packet cannot swap the world during the hold.
	var manual_submit: Dictionary = lab._submit_region_async(GROVE_CENTER_SA)
	if not _check(bool(manual_submit.get("ok", false)), "manual capture has pending request"):
		return false
	await lab._capture_manual()
	if not _check(not lab._has_pending_region() and lab._publication_revision == roads_rev and _deep_equal(lab._region_collision, roads_collision), "manual capture retains immutable paired generation"):
		return false
	# Fixed capture path: sync diagnostic must cancel and consume outstanding
	# async before issuing sync, so no stale commit lands over the fixed frame.
	var cap_submit: Dictionary = lab._submit_region_async(ROADS_CENTER_SA)
	# After the F6 error the failed center is INVALID; ROADS is far, so this
	# submit must succeed (or be a fresh pending). If suppressed state blocks
	# it, clear via explicit far move: the call itself proves submit path.
	if bool(cap_submit.get("ok", false)):
		if not _check(lab._has_pending_region(), "capture preempt pending active"):
			return false
		var sync_ok: bool = lab._load_region(GROVE_CENTER_SA)
		if not _check(sync_ok, "sync diagnostic after cancel+consume"):
			return false
		if not _check(not lab._has_pending_region(), "sync preempt consumed pending"):
			return false
		if not _check(lab._loaded_center_sa == GROVE_CENTER_SA, "fixed capture center not mislabeled"):
			return false
	else:
		lab._drain_pending_for_sync("capture-fixed")
	# Manifest carries scalar pending/raw_parse_ms and no COL array dump.
	lab._write_run_manifest("async-probe", false, "", "completed")
	var manifest_path: String = lab._capture_dir.path_join("%s-async-probe.manifest.json" % lab._profile_id())
	if not _check(FileAccess.file_exists(manifest_path), "async probe manifest exists"):
		return false
	var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
	if not _check(manifest_file != null, "async probe manifest readable"):
		return false
	var manifest_text := manifest_file.get_as_text()
	manifest_file.close()
	if not _check(not manifest_text.contains("face_indices") and not manifest_text.contains("face_surfaces"), "manifest must not dump COL arrays"):
		return false
	var parsed: Variant = JSON.parse_string(manifest_text)
	if not _check(parsed is Dictionary, "manifest JSON"):
		return false
	var pub: Variant = (parsed as Dictionary).get("region_publication", {})
	if not _check(pub is Dictionary and (pub as Dictionary).has("pending_request") and (pub as Dictionary).has("last_async"), "manifest scalar pending/async"):
		return false
	var meas: Variant = (parsed as Dictionary).get("measurements", {})
	if not _check(meas is Dictionary and meas.has("last_region_raw_parse_ms"), "manifest raw_parse_ms scalar"):
		return false
	lab._update_overlay()
	if not _check(true, "overlay update runs with pending scalar"):
		return false
	# Teardown cancels deferred capture and holds no freed callbacks.
	lab._frame_count = 99999
	var cancelled_path: String = lab._capture_dir.path_join("%s-manual-099999.png" % lab._profile_id())
	lab.call_deferred("_capture_manual")
	var teardown_collision: Dictionary = lab._region_collision.duplicate(true)
	lab.free()
	await process_frame
	await process_frame
	if not _check(not FileAccess.file_exists(cancelled_path), "teardown cancels deferred capture"):
		return false
	if not _check(int((teardown_collision.get("col", {}) as Dictionary).get("faces", 0)) == 0 or int((teardown_collision.get("col", {}) as Dictionary).get("faces", 122)) == 122, "held payload readable across teardown"):
		return false
	# Silence unused warnings for retained pre-pending snapshot.
	if not _check(held_collision.size() >= 0 and held_mesh_ids.size() >= 0 and held_nodes.size() >= 0, "handover snapshot kept"):
		return false
	return true


func _await_bridge_terminal(expect_id: int) -> Dictionary:
	var start_msec := Time.get_ticks_msec()
	for _frame in range(MAX_POLL_FRAMES):
		await process_frame
		if Time.get_ticks_msec() - start_msec > POLL_DEADLINE_MSEC:
			break
		var polled: Variant = _bridge.call("poll_region")
		if not polled is Dictionary:
			return {"ok": false, "status": "error", "error": "non-Dictionary poll"}
		var status := str(polled.get("status", ""))
		if status == "pending" or status == "idle" or status == "preparing":
			if not _check(not bool(polled.get("ok", false)), "pending/idle/preparing ok=false is not failure"):
				return {"ok": false, "status": "error", "error": "pending marked ok"}
			continue
		return polled
	return {"ok": false, "status": "error", "error": "async poll deadline", "request_id": expect_id}


func _await_lab_settled(lab: Node) -> bool:
	# A06: await bridge preparing + hidden lab staging + hidden retirement.
	# Idle polls still pump C++ retirement; budgeted staging/retirement share
	# the per-frame quota via _pump_region_budget. Settled means no pending
	# (preparing/staging/deferred) and no lab budget busy and no C++ retire.
	var start_msec := Time.get_ticks_msec()
	for _frame in range(MAX_POLL_FRAMES):
		await process_frame
		if not is_instance_valid(lab):
			return false
		if Time.get_ticks_msec() - start_msec > POLL_DEADLINE_MSEC:
			return false
		lab._poll_pending_region()
		lab._pump_region_budget()
		if not lab._has_pending_region() and not lab._region_budget_busy() and int(lab._last_bridge_retire_pending) == 0:
			return true
	return false


func _lab_active_node_ids(lab: Node) -> Array:
	return lab._active_region_root().get_children().map(func(node: Node) -> int: return node.get_instance_id())


func _lab_active_mesh_ids(lab: Node) -> Array:
	return lab._active_region_root().get_children().map(func(node: Node) -> int: return (node as MeshInstance3D).mesh.get_instance_id())


func _validate_bridge_pair(packet: Dictionary) -> bool:
	if not packet.get("collision_lineage") is Dictionary:
		printerr("region-async-fail: no collision_lineage")
		return false
	var lineage: Dictionary = packet.collision_lineage
	if int(lineage.get("generation", -1)) != int(packet.get("publication_revision", -2)):
		printerr("region-async-fail: generation mismatch")
		return false
	if str(lineage.get("scope", "")) != "single-chain-data-not-gameplay" or str(lineage.get("link", "")) != "bound" or not bool(lineage.get("collision_transferred", false)):
		printerr("region-async-fail: lineage scope/link/transfer")
		return false
	var child: Dictionary = lineage.get("child", {})
	var parent: Dictionary = lineage.get("parent", {})
	var col: Dictionary = lineage.get("col", {})
	if int(child.get("model_id", -1)) != 3991 or str(child.get("model", "")).to_lower() != "gsfreeway7_lan":
		printerr("region-async-fail: child role")
		return false
	if int(parent.get("model_id", -1)) != 4043 or str(parent.get("model", "")).to_lower() != "lodgsfreeway7_lan":
		printerr("region-async-fail: parent role")
		return false
	if int(col.get("header_id", -1)) != 3991 or int(col.get("faces", -1)) != 122 or str(col.get("status", "")) != "ready":
		printerr("region-async-fail: COL 122 ready")
		return false
	if (col.get("face_surfaces", PackedByteArray()) as PackedByteArray).size() != 488:
		printerr("region-async-fail: surface 488 bytes")
		return false
	if (col.get("face_indices", PackedInt32Array()) as PackedInt32Array).size() != 366:
		printerr("region-async-fail: index count")
		return false
	return true


func _validate_lab_pair(lab: Node, label: String) -> bool:
	if not _check(not lab._region_collision.is_empty(), label + " has COL"):
		return false
	var lineage: Dictionary = lab._region_collision
	if not _check(int(lineage.get("generation", -1)) == lab._publication_revision, label + " generation"):
		return false
	var child: Dictionary = lineage.get("child", {})
	var parent: Dictionary = lineage.get("parent", {})
	var col: Dictionary = lineage.get("col", {})
	if not _check(int(child.get("model_id", -1)) == 3991, label + " child 3991"):
		return false
	if not _check(int(parent.get("model_id", -1)) == 4043, label + " parent 4043"):
		return false
	if not _check(int(col.get("faces", -1)) == 122, label + " 122 faces"):
		return false
	# A06: active generation lives under the visible persistent root; the
	# hidden staging/retiring root never mixes into the active set.
	var nodes: Array = lab._active_region_root().get_children()
	var child_index := int(child.get("mesh_index", -1))
	var parent_index := int(parent.get("mesh_index", -1))
	if not _check(child_index >= 0 and child_index < nodes.size() and parent_index >= 0 and parent_index < nodes.size() and child_index != parent_index, label + " distinct slots"):
		return false
	var child_node := nodes[child_index] as MeshInstance3D
	var parent_node := nodes[parent_index] as MeshInstance3D
	if not _check(child_node.visible and not parent_node.visible, label + " visibility"):
		return false
	if not _check(lab._active_region_root().visible and not lab._staging_region_root().visible, label + " two-root flip"):
		return false
	return true


func _deep_equal(first: Variant, second: Variant) -> bool:
	if (first is int or first is float) and (second is int or second is float):
		return first == second
	if (first is String or first is StringName) and (second is String or second is StringName):
		return str(first) == str(second)
	if typeof(first) != typeof(second):
		return false
	if first is Dictionary:
		if first.size() != second.size():
			return false
		for key in first:
			if not second.has(key):
				return false
			if not _deep_equal(first[key], second[key]):
				return false
		return true
	if first is Array:
		if first.size() != second.size():
			return false
		for i in range(first.size()):
			if not _deep_equal(first[i], second[i]):
				return false
		return true
	if first is PackedFloat32Array or first is PackedFloat64Array or first is PackedInt32Array or first is PackedInt64Array or first is PackedByteArray or first is PackedStringArray or first is PackedVector2Array or first is PackedVector3Array or first is PackedColorArray or first is PackedVector4Array:
		if first.size() != second.size():
			return false
		for i in range(first.size()):
			if first[i] != second[i]:
				return false
		return true
	if first is Vector2:
		return first.x == second.x and first.y == second.y
	if first is Vector3:
		return first.x == second.x and first.y == second.y and first.z == second.z
	if first is Vector4:
		return first.x == second.x and first.y == second.y and first.z == second.z and first.w == second.w
	if first is Quaternion:
		return first.x == second.x and first.y == second.y and first.z == second.z and first.w == second.w
	if first is Color:
		return first.r == second.r and first.g == second.g and first.b == second.b and first.a == second.a
	return first == second


func _parse_options(args: PackedStringArray) -> Dictionary:
	var result := {"ok": false, "error": "", "game_dir": "", "capture_dir": ""}
	var i := 0
	while i < args.size():
		var arg := String(args[i])
		if arg == "--route":
			pass
		elif arg in ["--game-dir", "--capture-dir", "--seconds", "--radius", "--cap"]:
			if i + 1 >= args.size():
				result.error = "%s requires a value" % arg
				return result
			i += 1
			var value := String(args[i])
			if arg == "--game-dir":
				if value.is_empty():
					result.error = "--game-dir requires a non-empty path"
					return result
				result.game_dir = _absolute_path(value)
			elif arg == "--capture-dir":
				if value.is_empty():
					result.error = "--capture-dir requires a non-empty path"
					return result
				result.capture_dir = _absolute_path(value)
		else:
			result.error = "unknown region async option: %s" % arg
			return result
		i += 1
	if not result.game_dir.is_empty() and not DirAccess.dir_exists_absolute(result.game_dir):
		result.error = "game directory does not exist: %s" % result.game_dir
		return result
	if result.game_dir.is_empty():
		# Fall back to the lab default probe so a bare run still explains itself.
		result.error = "--game-dir PATH is required"
		return result
	if not result.capture_dir.is_empty() and not result.game_dir.is_empty():
		var prefix: String = result.game_dir.trim_suffix("/") + "/"
		if result.capture_dir == result.game_dir or result.capture_dir.begins_with(prefix):
			result.error = "--capture-dir must not be the read-only game directory or one of its children"
			return result
	result.ok = true
	return result


func _absolute_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path).simplify_path()
	if path.is_absolute_path():
		return path.simplify_path()
	return OS.get_environment("PWD").path_join(path).simplify_path()


func _check(condition: bool, label: String) -> bool:
	if not condition:
		printerr("region-async-fail: ", label)
		_close_bridge()
		quit(1)
	return condition


func _close_bridge() -> void:
	if _bridge_open and _bridge != null:
		_bridge.call("close_game")
	_bridge_open = false
