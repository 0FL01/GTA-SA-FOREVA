extends SceneTree

# P1-A06 region budget gate: decisive actual bridge + lab fixture with quota 1.
# Proves budgeted C++ conversion/preparing + lab hidden staging/retirement:
# - Direct bridge: cancel/supersede AFTER preparing begins (not just raw
#   queue), sync-during-preparing reject, no old Ready/no rev on cancel,
#   admission while C++ retirement held shows progress then drains.
# - Actual lab (set_process(false), manual _pump_region_budget): old active
#   IDs/COL unchanged through multiple partial frames, one flip only when
#   complete, cancel-after-stage retains old, one retiring generation bounds
#   and drains zero, Grove->Roads->Grove cycles bounded (diagnostic, not
#   impossible absolute equality due to held external refs).
# No timestamp/sleep ordering; bounded frames/deadlines. Source assets
# read-only, no file copies, capture dirs outside game as existing tests.
const GROVE_CENTER_SA := Vector3(2490.0, -1665.0, 14.0)
# Center the actual 3991/4043 authored chain so a small real-data working set
# proves all budget phases without thousands of deliberately one-item frames.
const ROADS_CENTER_SA := Vector3(1608.195313, -1721.804688, 26.0)
const FIXTURE_CAP := 16
const INVALID_RADAR_CENTER_SA := Vector3(-1687.414063, -623.023438, 18.148438)
const MAX_POLL_FRAMES := 3600
const POLL_DEADLINE_MSEC := 120000
const BUDGET_ITEMS := 1

var _bridge: Object
var _bridge_open := false


func _unstaged_resource_weakrefs(lab: Node) -> Array:
	# Return weak refs only; locals die on return so the fixture cannot pin
	# the objects whose cancel-time lifetime it is checking.
	for index in range(lab._lab_candidate_meshes.size() - 1, lab._lab_candidate_next_mesh, -1):
		var info: Dictionary = lab._lab_candidate_meshes[index]
		for surface in info.surface_materials:
			if surface.get("texture") is ImageTexture:
				return [weakref(info.mesh), weakref(surface.texture)]
	return []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	if not bool(options.get("ok", false)):
		printerr("region-budget-fail: ", str(options.get("error", "bad options")))
		quit(2)
		return
	if not GDExtensionManager.is_extension_loaded("res://sa_legacy.gdextension"):
		if GDExtensionManager.load_extension("res://sa_legacy.gdextension") != GDExtensionManager.LOAD_STATUS_OK:
			printerr("region-budget-fail: extension load failed")
			quit(3)
			return
	if not ClassDB.class_exists("SALegacyBridge"):
		printerr("region-budget-fail: SALegacyBridge not registered")
		quit(3)
		return
	_bridge = ClassDB.instantiate("SALegacyBridge")
	if _bridge == null:
		printerr("region-budget-fail: cannot instantiate bridge")
		quit(3)
		return
	for method in ["open_game", "load_region", "submit_region", "poll_region", "cancel_region", "environment", "close_game"]:
		if not _bridge.has_method(method):
			printerr("region-budget-fail: missing bridge method ", method)
			quit(3)
			return
	if not await _run_bridge_direct(options.game_dir):
		return
	_close_bridge()
	_bridge = null
	if not await _run_lab_fixture():
		return
	print("region-budget-ok budget1 preparing-cancel-supersede sync-reject no-old-ready retire-progress-drain lab-staged-commit cancel-retain retire-bounded cycles-diagnostic")
	quit(0)


func _run_bridge_direct(game_dir: String) -> bool:
	# This gate must reject a stale bridge: three-argument compatibility
	# belongs to clients, not to proof that budget1 is being enforced.
	var open_uses_budget := false
	for info in ClassDB.class_get_method_list("SALegacyBridge", true):
		if info is Dictionary and str(info.get("name", "")) == "open_game":
			var arg_list: Array = info.get("args", [])
			if arg_list.size() >= 4:
				open_uses_budget = true
	if not _check(open_uses_budget, "A06 bridge budget argument is required"):
		return false
	var opened: Variant = _bridge.call("open_game", game_dir, 350.0, FIXTURE_CAP, BUDGET_ITEMS)
	if not _check(bool(opened.get("ok", false)), "direct open budget1: " + str(opened.get("error", ""))):
		return false
	_bridge_open = true
	var epoch0 := int(opened.get("session_epoch", 0))
	if not _check(epoch0 > 0, "direct open epoch nonzero"):
		return false
	if not _check(int(opened.get("publication_revision", -1)) == 0, "direct open rev 0"):
		return false
	# Submit Roads, then prove sync-during-preparing/pending rejects.
	var submit_roads: Dictionary = _bridge.call("submit_region", ROADS_CENTER_SA)
	if not _check(bool(submit_roads.get("ok", false)), "submit roads: " + str(submit_roads.get("error", ""))):
		return false
	var roads_id := int(submit_roads.get("request_id", 0))
	var roads_epoch := int(submit_roads.get("session_epoch", 0))
	if not _check(roads_id > 0 and roads_epoch == epoch0, "roads id/epoch"):
		return false
	# Poll until preparing (new) or at least pending (old) proves work began
	# beyond raw queue; then sync must reject while exposed.
	var saw_preparing := false
	var start_msec := Time.get_ticks_msec()
	var polled: Dictionary = {}
	for _frame in range(MAX_POLL_FRAMES):
		await process_frame
		if Time.get_ticks_msec() - start_msec > POLL_DEADLINE_MSEC:
			break
		var p: Variant = _bridge.call("poll_region")
		if not p is Dictionary:
			return _check(false, "non-Dictionary poll")
		polled = p
		var st := str(polled.get("status", ""))
		if st == "preparing":
			if int(polled.get("progress", {}).get("items_done", 0)) >= 4:
				saw_preparing = true
				break
		if st == "pending":
			continue
		if st in ["ready", "error", "cancelled"]:
			break
	if not _check(saw_preparing, "four GPU preparation units completed before supersede"):
		return false
	# Sync while async pending/preparing must reject, revision unchanged.
	var sync_while: Dictionary = _bridge.call("load_region", GROVE_CENTER_SA)
	if not _check(not bool(sync_while.get("ok", true)), "sync during preparing/pending must reject"):
		return false
	if not _check(str(sync_while.get("error_code", "")) == "async_request_pending", "sync reject code async_request_pending"):
		return false
	if not _check(int(sync_while.get("publication_revision", -1)) == 0, "sync reject no rev advance"):
		return false
	# Supersede AFTER preparing/pending began: submit Grove, only latest publishes.
	var submit_grove: Dictionary = _bridge.call("submit_region", GROVE_CENTER_SA)
	if not _check(bool(submit_grove.get("ok", false)), "submit grove supersede after preparing: " + str(submit_grove.get("error", ""))):
		return false
	var grove_id := int(submit_grove.get("request_id", 0))
	if not _check(grove_id == roads_id + 1, "monotonic IDs"):
		return false
	if not _check(int(submit_grove.get("discarded_stale", 0)) == int(submit_roads.get("discarded_stale", 0)) + 1, "supersede counts discarded stale"):
		return false
	var gated: Dictionary = _bridge.call("poll_region")
	if not _check(str(gated.get("status", "")) == "pending" and _progress_retire_pending(gated) > 0 and int(gated.get("publication_revision", -1)) == 0, "new conversion gated while old partial GPU resources retire"):
		return false
	var gated_cancel: Dictionary = _bridge.call("cancel_region", grove_id)
	if not _check(bool(gated_cancel.get("ok", false)), "cancel coalesced request during old GPU retirement"):
		return false
	var gated_ack: Dictionary = _bridge.call("poll_region")
	if not _check(str(gated_ack.get("status", "")) == "cancelled" and _progress_retire_pending(gated_ack) > 0, "cancel terminal does not wait for GPU retirement"):
		return false
	var replacement: Dictionary = _bridge.call("submit_region", GROVE_CENTER_SA)
	if not _check(bool(replacement.get("ok", false)) and int(replacement.get("request_id", 0)) > grove_id, "new request stays monotonic during retire admission gate"):
		return false
	grove_id = int(replacement.request_id)
	var first: Dictionary = await _await_bridge_terminal(grove_id)
	if not _check(str(first.get("status", "")) == "ready" and bool(first.get("ok", false)), "grove latest ready, roads never published"):
		return false
	if not _check(int(first.get("request_id", 0)) == grove_id, "ready is grove id, not roads"):
		return false
	if not _check(int(first.get("publication_revision", -1)) == 1, "first publication rev 1"):
		return false
	_check_progress_shape(first, "ready progress")
	_check_conversion_stats(first, "ready conversion stats")
	var idle: Dictionary = _bridge.call("poll_region")
	if not _check(str(idle.get("status", "")) == "idle" and not bool(idle.get("ok", false)), "ready one-shot, next idle (idle ok=false not failure)"):
		return false
	# Cancel AFTER preparing/pending begins: submit, wait for pending/preparing,
	# cancel, poll cancelled, no old Ready, no rev advance.
	var submit_cancel: Dictionary = _bridge.call("submit_region", ROADS_CENTER_SA)
	if not _check(bool(submit_cancel.get("ok", false)), "submit for cancel"):
		return false
	var cancel_id := int(submit_cancel.get("request_id", 0))
	# Prove GPU resources exist; raw pending alone does not test cancellation
	# of an already-taken conversion or subsequent GPU retirement.
	var began := false
	start_msec = Time.get_ticks_msec()
	for _frame in range(MAX_POLL_FRAMES):
		await process_frame
		if Time.get_ticks_msec() - start_msec > POLL_DEADLINE_MSEC:
			break
		var q: Variant = _bridge.call("poll_region")
		if q is Dictionary and str(q.get("status", "")) == "preparing" and int(q.get("progress", {}).get("items_done", 0)) >= 4:
			began = true
			break
		if q is Dictionary and str(q.get("status", "")) in ["ready", "error", "cancelled"]:
			break
	if not _check(began, "four GPU preparation units completed before cancellation"):
		return false
	var cancelled_ack: Dictionary = _bridge.call("cancel_region", cancel_id)
	if not _check(bool(cancelled_ack.get("ok", false)), "cancel after preparing ack"):
		return false
	var cancelled: Dictionary = await _await_bridge_terminal(cancel_id)
	if not _check(str(cancelled.get("status", "")) == "cancelled" and not bool(cancelled.get("ok", false)), "cancel confirmation once via poll"):
		return false
	if not _check(str(cancelled.get("error_code", "")) == "cancelled", "cancelled code"):
		return false
	if not _check(int(cancelled.get("publication_revision", -1)) == 1, "cancel causes no revision advance (no old Ready/no Rev)"):
		return false
	var remaining := _progress_retire_pending(cancelled)
	if not _check(remaining > 0, "cancel leaves a real budgeted retirement window"):
		return false
	while remaining > 0:
		var draining: Dictionary = _bridge.call("poll_region")
		var next := _progress_retire_pending(draining)
		if not _check(str(draining.get("status", "")) == "idle" and next < remaining and remaining - next <= BUDGET_ITEMS and int(draining.get("publication_revision", -1)) == 1, "idle quota drains retirement without publishing"):
			return false
		remaining = next
		await process_frame
	var idle2: Dictionary = _bridge.call("poll_region")
	if not _check(str(idle2.get("status", "")) == "idle", "cancel one-shot, next idle"):
		return false
	# A fully handed-off successful packet is not a cancelled conversion:
	# it must not invent a C++ retirement backlog.
	var submit_roads2: Dictionary = _bridge.call("submit_region", ROADS_CENTER_SA)
	if not _check(bool(submit_roads2.get("ok", false)), "submit roads2"):
		return false
	var roads2_id := int(submit_roads2.get("request_id", 0))
	var roads2: Dictionary = await _await_bridge_terminal(roads2_id)
	if not _check(str(roads2.get("status", "")) == "ready" and bool(roads2.get("ok", false)), "roads2 ready: " + str(roads2.get("error", ""))):
		return false
	if not _check(int(roads2.get("publication_revision", -1)) == 2, "roads2 rev 2"):
		return false
	if not _check(_validate_bridge_pair(roads2), "roads2 pair 3991/4043 122"):
		return false
	_check_progress_shape(roads2, "roads2 progress")
	_check_conversion_stats(roads2, "roads2 conversion stats")
	# Eventual drain: idle shows zero retire, next submit succeeds.
	var idle3: Dictionary = _bridge.call("poll_region")
	if not _check(_progress_retire_pending(idle3) == 0, "eventual C++ retire zero"):
		return false
	return true


func _run_lab_fixture() -> bool:
	var lab: Node = load("res://lab.tscn").instantiate()
	lab._budget_items = BUDGET_ITEMS
	root.add_child(lab)
	lab.set_process(false)
	if not _check(is_instance_valid(lab) and lab._has_published_region and not lab._shutdown_started, "lab initial sync diagnostic region with budget1"):
		return false
	if not _check(lab._budget_items == BUDGET_ITEMS, "lab budget1 passed at Open"):
		return false
	if not _check(lab._cap == FIXTURE_CAP, "bounded fixture requires --cap 16 (normal product cap remains unchanged)"):
		return false
	if not _check(lab.mesh_root.get_child_count() == 2, "two persistent attached roots under mesh_root"):
		return false
	if not _check(is_instance_valid(lab._region_root_a) and is_instance_valid(lab._region_root_b), "both roots valid"):
		return false
	if not _check(lab._active_region_root().visible and not lab._staging_region_root().visible, "active visible, staging hidden"):
		return false
	var initial_rev: int = lab._publication_revision
	var initial_loads: int = lab._load_count
	# Roads via budgeted async: old active must stay byte-identical through
	# multiple partial frames; exactly one flip when complete.
	lab.camera.position = Vector3(ROADS_CENTER_SA.x, ROADS_CENTER_SA.z + 5.0, -ROADS_CENTER_SA.y + 5.0)
	lab._camera_target_world = Vector3(ROADS_CENTER_SA.x, ROADS_CENTER_SA.z, -ROADS_CENTER_SA.y)
	lab.camera.look_at(lab._camera_target_world)
	var held_nodes: Array = _lab_active_node_ids(lab)
	var held_meshes: Array = _lab_active_mesh_ids(lab)
	var held_collision: Dictionary = lab._region_collision.duplicate(true)
	var held_stats: Dictionary = lab._region_stats.duplicate(true)
	var held_center: Vector3 = lab._loaded_center_sa
	var held_retire_units: int = held_nodes.size() + lab._materials.size() + lab._active_mesh_holds.size() + lab._active_texture_holds.size() + lab._active_metadata_holds.size()
	lab._maybe_reload_region()
	if not _check(lab._has_pending_region(), "budget lab submit creates pending"):
		return false
	if not _check(lab._load_count == initial_loads, "budget submit causes no sync load"):
		return false
	# Manually pump with process disabled: prove partial staging keeps old.
	# Phase 1 waits for commit (rev advance, one flip); Phase 2 drains retiring.
	var active_flag_before: bool = lab._region_active_is_a
	var partial_frames := 0
	var saw_partial_staging := false
	var start_msec := Time.get_ticks_msec()
	var committed := false
	for _frame in range(MAX_POLL_FRAMES):
		await process_frame
		if Time.get_ticks_msec() - start_msec > POLL_DEADLINE_MSEC:
			break
		lab._poll_pending_region()
		lab._pump_region_budget()
		# Old must stay unchanged until commit (validating preparing+staging).
		if lab._publication_revision == initial_rev:
			if not _check(_lab_active_mesh_ids(lab) == held_meshes and lab._loaded_center_sa == held_center, "active mesh identities and center retained through partial work"):
				return false
			if _lab_active_node_ids(lab) != held_nodes:
				printerr("region-budget-fail: active nodes changed before commit")
				quit(1)
				return false
			if not _deep_equal(lab._region_collision, held_collision):
				printerr("region-budget-fail: COL changed before commit")
				quit(1)
				return false
			if not _deep_equal(lab._region_stats, held_stats):
				printerr("region-budget-fail: stats changed before commit")
				quit(1)
				return false
			if lab._lab_staging_active and lab._staging_region_root().get_child_count() > 0:
				saw_partial_staging = true
				partial_frames += 1
			# Idle polls are never fake Ready: no rev advance without commit.
			continue
		else:
			committed = true
			break
	if not _check(saw_partial_staging and partial_frames >= 2, "old retained through multiple partial frames (budget1 stages, not whole-scene 1 unit)"):
		return false
	if not _check(committed, "budget lab roads committed"):
		return false
	if not _check(lab._publication_revision == initial_rev + 1, "one active generation advance without an intervening cancelled candidate"):
		return false
	if not _check(lab._region_active_is_a != active_flag_before, "exactly one active root flip when complete (two flips, no detach/add loop)"):
		return false
	if not _check(lab._active_region_root().visible and not lab._staging_region_root().visible, "roots flipped visible/hidden"):
		return false
	if not _check(_lab_active_node_ids(lab) != held_nodes, "new active set differs after commit"):
		return false
	if not _check(_validate_lab_pair(lab, "budget roads pair"), "budget roads pair 3991/4043 122 hidden parent"):
		return false
	var measured_work: float = lab._last_region_conversion_ms_total + lab._last_region_staging_ms_total + lab._last_region_commit_ms
	if not _check(absf(lab._last_load_stall_ms - measured_work) < 0.001 and lab._last_region_staging_ms_total >= 0.0 and lab._last_region_publication_elapsed_ms >= 0.0, "async work sums measured units, not free-frame elapsed"):
		return false
	var retained_roads: Dictionary = lab._region_collision.duplicate(true)
	var retained_face_bytes: PackedByteArray = retained_roads.col.face_indices.to_byte_array()
	# Retire queue bounds and drains zero: immediately after commit retiring
	# must be bounded (one generation), then manual pumps drain to zero.
	var retire_after_commit: int = lab._lab_retire_pending_count()
	if not _check(retire_after_commit > 0 and retire_after_commit <= held_retire_units, "retire queue contains at most the preceding generation's exact held resources"):
		return false
	# Admission while lab retiring drains must block as busy (camera retried
	# after; F6 busy uses existing counter).
	if lab._lab_retire_active or int(lab._last_bridge_retire_pending) > 0:
		var busy_submit: Dictionary = lab._submit_region_async(GROVE_CENTER_SA)
		if not _check(not bool(busy_submit.get("ok", false)) and str(busy_submit.get("error", "")) == "retiring_busy", "admission while retiring held is busy"):
			return false
		var f6_before: int = lab._f6_ignored_while_pending
		var retry_key := InputEventKey.new()
		retry_key.physical_keycode = KEY_F6
		retry_key.pressed = true
		lab._unhandled_input(retry_key)
		# F6 while busy increments existing counter (no new counter).
		if not _check(lab._f6_ignored_while_pending == f6_before or lab._f6_ignored_while_pending == f6_before + 1, "F6 busy ignored via existing counter"):
			return false
		# Drain retiring with bounded manual pumps; each budget1 pump retires
		# at most one node/hold (incremental, no avalanche).
		var last_count := retire_after_commit
		var drain_ok := true
		var drain_start := Time.get_ticks_msec()
		for _frame in range(MAX_POLL_FRAMES):
			await process_frame
			if Time.get_ticks_msec() - drain_start > POLL_DEADLINE_MSEC:
				drain_ok = false
				break
			lab._poll_pending_region()
			lab._pump_region_budget()
			var now_count: int = lab._lab_retire_pending_count()
			if now_count > last_count:
				drain_ok = false
				break
			last_count = now_count
			if not lab._region_budget_busy() and int(lab._last_bridge_retire_pending) == 0:
				break
		if not _check(drain_ok and not lab._region_budget_busy() and lab._lab_retire_pending_count() == 0, "retire drains zero incrementally"):
			return false
	else:
		# No retiring held (initial commit had no old? Should still drain zero).
		if not _check(lab._lab_retire_pending_count() == 0, "retire drains zero"):
			return false
	var roads_rev: int = lab._publication_revision
	var roads_nodes: Array = _lab_active_node_ids(lab)
	var roads_collision: Dictionary = lab._region_collision.duplicate(true)
	# Cancel AFTER lab stage exists retains old: submit Grove, pump until
	# staging has nodes, cancel, verify old retained, no new Ready/Rev.
	var cancel_submit: Dictionary = lab._submit_region_async(GROVE_CENTER_SA)
	if not _check(bool(cancel_submit.get("ok", false)), "cancel-test submit accepted (retiring drained)"):
		return false
	var staged_seen := false
	for _frame in range(MAX_POLL_FRAMES):
		await process_frame
		lab._poll_pending_region()
		lab._pump_region_budget()
		if lab._lab_staging_active and lab._staging_region_root().get_child_count() > 0:
			staged_seen = true
			break
		if not lab._has_pending_region():
			break
	if not _check(staged_seen, "lab stage exists before cancel (hidden staging children budgeted)"):
		return false
	var unstaged_refs := _unstaged_resource_weakrefs(lab)
	if not _check(unstaged_refs.size() == 2, "fixture has an unstaged textured mesh"):
		return false
	var cancel_out: Dictionary = lab._cancel_pending_region()
	if not _check(unstaged_refs[0].get_ref() != null and unstaged_refs[1].get_ref() != null, "cancel retains not-yet-staged GPU resources for budgeted retirement"):
		return false
	# Direct cancel after staging began must retain old (no old Ready/no Rev).
	if not _check(lab._publication_revision == roads_rev, "cancel after stage retains rev (prepared consumed, active unchanged)"):
		return false
	if not _check(_lab_active_node_ids(lab) == roads_nodes, "cancel after stage retains old visible IDs"):
		return false
	if not _check(_deep_equal(lab._region_collision, roads_collision), "cancel after stage retains COL bytes"):
		return false
	if not _check(int(lab._lab_staged_discards) >= 1 or int(lab._async_cancel_count) >= 1, "cancel counts staged_discards/cancel"):
		return false
	# Drain the retiring partial to zero (bounded).
	if not await _await_lab_settled(lab):
		return false
	if not _check(not lab._region_budget_busy() and lab._lab_retire_pending_count() == 0, "cancel retiring drains zero"):
		return false
	if not _check(unstaged_refs[0].get_ref() == null and unstaged_refs[1].get_ref() == null, "unstaged GPU wrappers release only after retirement drain"):
		return false
	# Sync during preparing rejects: submit, prove bridge preparing/pending
	# began (staging not yet, so bridge exposed), sync must reject.
	# Retry once if the worker finished instantly and staging already began.
	var sync_ok_proven := false
	for _attempt in range(2):
		var sync_submit: Dictionary = lab._submit_region_async(GROVE_CENTER_SA)
		if not _check(bool(sync_submit.get("ok", false)), "sync-reject submit accepted"):
			return false
		var began_sync := false
		var staging_early := false
		for _frame in range(120):
			await process_frame
			lab._poll_pending_region()
			if lab._has_pending_region() and not lab._lab_staging_active:
				began_sync = true
				break
			if lab._lab_staging_active:
				staging_early = true
				break
		if staging_early:
			lab._cancel_pending_region()
			if not await _await_lab_settled(lab):
				return false
			continue
		if not _check(began_sync, "sync-reject target began"):
			return false
		var sync_result: Variant = lab._bridge.call("load_region", ROADS_CENTER_SA)
		if not _check(sync_result is Dictionary and not bool(sync_result.get("ok", true)), "sync during preparing rejects"):
			return false
		if not _check(str(sync_result.get("error_code", "")) == "async_request_pending", "sync reject code"):
			return false
		sync_ok_proven = true
		break
	if not _check(sync_ok_proven, "sync during preparing proven"):
		return false
	# Lab sync helper would drain; direct bridge sync reject proves no old Ready.
	lab._cancel_pending_region()
	if not await _await_lab_settled(lab):
		return false
	# Environment applies to hidden staged materials: change env mid-stage,
	# first visible frame must not be stale. Submit, stage partially, change
	# env, settle, verify active materials carry new env (no artistic change).
	var env_submit: Dictionary = lab._submit_region_async(GROVE_CENTER_SA)
	if not _check(bool(env_submit.get("ok", false)), "env-test submit"):
		return false
	var env_partial := false
	for _frame in range(MAX_POLL_FRAMES):
		await process_frame
		lab._poll_pending_region()
		lab._pump_region_budget()
		if lab._lab_staging_active and lab._staging_region_root().get_child_count() > 0:
			env_partial = true
			break
		if not lab._has_pending_region():
			break
	if not _check(env_partial, "env test staged partial"):
		return false
	lab._apply_environment(lab._environment_cache[1], 1)
	if not await _await_lab_settled(lab):
		return false
	var env_ok := true
	for node in lab._active_region_root().get_children():
		var inst := node as MeshInstance3D
		var surface_count := (inst.mesh as ArrayMesh).get_surface_count() if inst != null and inst.mesh is ArrayMesh else 0
		for s in range(surface_count):
			var mat := inst.get_surface_override_material(s) as ShaderMaterial
			if mat != null and str(mat.get_meta(&"legacy_weather", "")) != str(lab._environment_data.get("weather", "")):
				env_ok = false
	if not _check(env_ok, "hidden staged materials got current environment (first frame not stale)"):
		return false
	lab._apply_environment(lab._environment_cache[0], 0)
	# Repeat Grove->Roads->Grove settled cycles: resource counts diagnostic,
	# not impossible absolute equality (held external refs may pin a few).
	var settled_counts: Array[int] = []
	var grove_meshes_first := 0
	var grove_surfaces_first := 0
	var roads_meshes_first := 0
	var roads_surfaces_first := 0
	for cycle in range(4):
		var target := GROVE_CENTER_SA if cycle % 2 == 0 else ROADS_CENTER_SA
		# Move camera far enough to force reload (threshold 122.5 at r350).
		lab.camera.position = Vector3(target.x, target.z + 5.0, -target.y + 5.0)
		lab._camera_target_world = Vector3(target.x, target.z, -target.y)
		lab.camera.look_at(lab._camera_target_world)
		# Identical requested centers, not camera-offset-dependent cap selection.
		var cycle_submit: Dictionary = lab._submit_region_async(target)
		if not _check(bool(cycle_submit.get("ok", false)), "settled-cycle explicit center accepted"):
			return false
		if not await _await_lab_settled(lab):
			printerr("region-budget-fail: cycle deadline ", cycle)
			quit(1)
			return false
		if target == GROVE_CENTER_SA:
			if grove_meshes_first == 0:
				grove_meshes_first = lab._resident_meshes
				grove_surfaces_first = lab._resident_surfaces
			elif not _check(lab._resident_meshes == grove_meshes_first and lab._resident_surfaces == grove_surfaces_first, "grove cycle resident stable"):
				return false
		else:
			if roads_meshes_first == 0:
				roads_meshes_first = lab._resident_meshes
				roads_surfaces_first = lab._resident_surfaces
			elif not _check(lab._resident_meshes == roads_meshes_first and lab._resident_surfaces == roads_surfaces_first, "roads cycle resident stable"):
				return false
		if not _check(not lab._region_budget_busy() and lab._lab_retire_pending_count() == 0, "cycle settled drains zero"):
			return false
		settled_counts.append(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)))
	# Compare the SAME settled centers, with the same externally-held fixture
	# references throughout. Two resources allow tiny global UI/cache variation,
	# not a hidden previous region. Owned retire/staging queues must be empty.
	print("region-budget-settled resources=", settled_counts)
	if not _check(settled_counts[2] <= settled_counts[0] + 2 and settled_counts[3] <= settled_counts[1] + 2, "same-itinerary settled resource plateau"):
		return false
	# Manifest/CSV scalar diagnostics, quota labels, no hard deadline/FPS claim.
	lab._write_run_manifest("budget-probe", false, "", "completed")
	var manifest_path: String = lab._capture_dir.path_join("%s-budget-probe.manifest.json" % lab._profile_id())
	if not _check(FileAccess.file_exists(manifest_path), "budget probe manifest exists"):
		return false
	var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
	if not _check(manifest_file != null, "budget manifest readable"):
		return false
	var manifest_text := manifest_file.get_as_text()
	manifest_file.close()
	if not _check(not manifest_text.contains("face_indices") and not manifest_text.contains("face_surfaces"), "manifest no COL arrays (scalar only)"):
		return false
	var parsed: Variant = JSON.parse_string(manifest_text)
	if not _check(parsed is Dictionary, "manifest JSON"):
		return false
	var meas: Variant = (parsed as Dictionary).get("measurements", {})
	if not _check(meas is Dictionary and meas.has("conversion_ms_total") and meas.has("conversion_ms_max_item") and meas.has("conversion_frames") and meas.has("commit_ms") and meas.has("retire_ms_max_item") and meas.has("retire_pending") and meas.has("staged_discards"), "manifest scalar budget diagnostics"):
		return false
	var budget_section: Variant = (parsed as Dictionary).get("region_publication", {}).get("budget", {})
	if not _check(budget_section is Dictionary and str(budget_section.get("quota_label", "")).contains("quota work items") and str(budget_section.get("overshoot_note", "")).contains("overshoot"), "manifest labels quota work items and overshoot, not hard deadline/FPS"):
		return false
	lab._update_overlay()
	# Teardown flushes retiring unbudgeted; held payload stays readable.
	lab.free()
	await process_frame
	await process_frame
	if not _check(int(retained_roads.col.faces) == 122 and retained_roads.col.face_indices.to_byte_array() == retained_face_bytes, "held actual COL face bytes readable and unchanged across retirement/teardown"):
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
			if not _check(not bool(polled.get("ok", false)), "pending/idle/preparing ok=false not failure"):
				return {"ok": false, "status": "error", "error": "pending marked ok"}
			_check_progress_shape(polled, "poll progress")
			continue
		return polled
	return {"ok": false, "status": "error", "error": "async poll deadline", "request_id": expect_id}


func _await_lab_settled(lab: Node) -> bool:
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


func _check_progress_shape(polled: Variant, label: String) -> bool:
	if not polled is Dictionary:
		return true
	if not polled.has("progress"):
		return true
	var progress: Variant = polled.get("progress", {})
	if not progress is Dictionary:
		printerr("region-budget-fail: ", label, " progress not Dictionary")
		quit(1)
		return false
	for key in ["phase", "items_done", "items_total", "retire_pending", "staged_discards"]:
		if not (progress as Dictionary).has(key):
			printerr("region-budget-fail: ", label, " progress missing ", key)
			quit(1)
			return false
	return true


func _check_conversion_stats(packet: Variant, label: String) -> bool:
	if not packet is Dictionary:
		return true
	if not (packet as Dictionary).has("stats"):
		return true
	var stats: Variant = (packet as Dictionary).get("stats", {})
	if not stats is Dictionary:
		return true
	# Old bridges omit conversion stats (scalar 0 on lab); new must be scalars.
	if not (stats as Dictionary).has("conversion_ms_total"):
		return true
	for key in ["conversion_ms_total", "conversion_ms_max_item", "conversion_frames"]:
		if not (stats as Dictionary).has(key):
			printerr("region-budget-fail: ", label, " stats missing ", key)
			quit(1)
			return false
	return true


func _progress_retire_pending(polled: Variant) -> int:
	if not polled is Dictionary:
		return 0
	var progress: Variant = (polled as Dictionary).get("progress", {})
	if progress is Dictionary and (progress as Dictionary).get("retire_pending") is int:
		return int((progress as Dictionary).get("retire_pending"))
	return 0


func _lab_active_node_ids(lab: Node) -> Array:
	return lab._active_region_root().get_children().map(func(node: Node) -> int: return node.get_instance_id())


func _lab_active_mesh_ids(lab: Node) -> Array:
	return lab._active_region_root().get_children().map(func(node: Node) -> int: return (node as MeshInstance3D).mesh.get_instance_id())


func _validate_bridge_pair(packet: Dictionary) -> bool:
	if not packet.get("collision_lineage") is Dictionary:
		printerr("region-budget-fail: no collision_lineage")
		return false
	var lineage: Dictionary = packet.collision_lineage
	if int(lineage.get("generation", -1)) != int(packet.get("publication_revision", -2)):
		printerr("region-budget-fail: generation mismatch")
		return false
	if str(lineage.get("scope", "")) != "single-chain-data-not-gameplay" or str(lineage.get("link", "")) != "bound" or not bool(lineage.get("collision_transferred", false)):
		printerr("region-budget-fail: lineage scope/link/transfer")
		return false
	var child: Dictionary = lineage.get("child", {})
	var parent: Dictionary = lineage.get("parent", {})
	var col: Dictionary = lineage.get("col", {})
	if int(child.get("model_id", -1)) != 3991 or str(child.get("model", "")).to_lower() != "gsfreeway7_lan":
		printerr("region-budget-fail: child role")
		return false
	if int(parent.get("model_id", -1)) != 4043 or str(parent.get("model", "")).to_lower() != "lodgsfreeway7_lan":
		printerr("region-budget-fail: parent role")
		return false
	if int(col.get("header_id", -1)) != 3991 or int(col.get("faces", -1)) != 122 or str(col.get("status", "")) != "ready":
		printerr("region-budget-fail: COL 122 ready")
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
	var nodes: Array = lab._active_region_root().get_children()
	var child_index := int(child.get("mesh_index", -1))
	var parent_index := int(parent.get("mesh_index", -1))
	if not _check(child_index >= 0 and child_index < nodes.size() and parent_index >= 0 and parent_index < nodes.size() and child_index != parent_index, label + " distinct slots"):
		return false
	var child_node := nodes[child_index] as MeshInstance3D
	var parent_node := nodes[parent_index] as MeshInstance3D
	if not _check(child_node.visible and not parent_node.visible, label + " visibility"):
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
			result.error = "unknown region budget option: %s" % arg
			return result
		i += 1
	if not result.game_dir.is_empty() and not DirAccess.dir_exists_absolute(result.game_dir):
		result.error = "game directory does not exist: %s" % result.game_dir
		return result
	if result.game_dir.is_empty():
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
		printerr("region-budget-fail: ", label)
		_close_bridge()
		quit(1)
	return condition


func _close_bridge() -> void:
	if _bridge_open and _bridge != null:
		_bridge.call("close_game")
	_bridge_open = false
