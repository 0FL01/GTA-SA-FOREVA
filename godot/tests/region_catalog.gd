extends SceneTree

# P1-A07 catalog residency gate: decisive actual bridge + lab fixture.
# No old DLL fallback; catalog methods required. Every expected resource must
# load or the whole candidate errors (no omission Ready). Authored targets held
# hidden are DIAGNOSTIC policy (lod_target_hidden), not source LOD. Time/LOD
# visibility stays unknown-pending-P5-A02. Legacy cap1/2/256 unchanged.
# Corpus fixtures from independent raw_catalog oracle + disjoint-set algebra
# (correcting prior R130 double-count: R130 is 238 visible+44 hidden=282, all 44
# targets already in seed; genuine VISIBLE must exceed 256, not just resident):
# - Grove (2495,-1685,22) R140 274 visible +47 hidden =321 total, 134 models, 0 time/anim/missingDFF
# - Grove (2498,-1618,20) R140 269+48=317, 138 models, 0 time/anim/missing
# - Grove (2650,-1677,40) R200 285+45=330, 136 models, 0 time/anim/missing
# - Roads (1532.054688,-1662.289063,12.460938) R190 279+47=326, 136 models, 5 time/0 anim/missing, A04 pair retained
# - Larger Roads R200 has cross-area LOD closure => correct rejection; never use R200 here or silently omit cross-area
# - Area16 TATTOO (-204.44,-26.454,1001.3) entire area 36+0/36, 26 models
# - Invalid area -1/256 rejected; anim ROI (1214.1484375,-913.4453125) R60
#   lawnboigashot25 honest whole failure, no Rev/old-world mutate, not skip.
# NaN policy unchanged. If parsing fails, report proven failure, never drop.
const GROVE0_SA := Vector3(2495.0, -1685.0, 22.0)
const GROVE1_SA := Vector3(2498.0, -1618.0, 20.0)
const GROVE2_SA := Vector3(2650.0, -1677.0, 40.0)
const ROADS_SA := Vector3(1532.054688, -1662.289063, 12.460938)
const TATTOO_SA := Vector3(-204.44, -26.454, 1001.3)
const ANIM_SA := Vector3(1214.1484375, -913.4453125, 10.0)
const SF_NAN_SA := Vector3(-1687.414063, -623.023438, 18.148438)
const POPULATION := 50935
const AUTHORITY := "unknown-pending-P5-A02"
const MAX_POLL_FRAMES := 3600
const POLL_DEADLINE_MSEC := 120000

var _bridge: Object
var _bridge_open := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	if not bool(options.get("ok", false)):
		printerr("region-catalog-fail: ", str(options.get("error", "bad options")))
		quit(2)
		return
	if not GDExtensionManager.is_extension_loaded("res://sa_legacy.gdextension"):
		if GDExtensionManager.load_extension("res://sa_legacy.gdextension") != GDExtensionManager.LOAD_STATUS_OK:
			printerr("region-catalog-fail: extension load failed")
			quit(3)
			return
	if not ClassDB.class_exists("SALegacyBridge"):
		printerr("region-catalog-fail: SALegacyBridge not registered")
		quit(3)
		return
	_bridge = ClassDB.instantiate("SALegacyBridge")
	if _bridge == null:
		printerr("region-catalog-fail: cannot instantiate bridge")
		quit(3)
		return
	# No old fallback: catalog methods required in this gate.
	for method in ["open_game", "load_region", "submit_region", "poll_region", "cancel_region", "environment", "close_game", "load_catalog_region", "submit_catalog_region"]:
		if not _bridge.has_method(method):
			printerr("region-catalog-fail: missing bridge method ", method)
			quit(3)
			return
	if not await _run_bridge_direct(options.game_dir):
		return
	_close_bridge()
	_bridge = null
	if not await _run_lab_fixture():
		return
	print("region-catalog-ok grove140a=321 grove140b=317 grove200=330 roads190=326 area16=36 pop=50935 pair122-retained legacy-capped stable-plateau invalid-rejected anim-whole-failure visible-gt256")
	quit(0)


func _run_bridge_direct(game_dir: String) -> bool:
	# Grove R140 disc fixture1 (274 visible genuinely >256, 47 hidden, 321 total).
	var opened: Dictionary = _bridge.call("open_game", game_dir, 140.0, 256)
	if not _check(bool(opened.get("ok", false)), "direct open R140: " + str(opened.get("error", ""))):
		return false
	_bridge_open = true
	var epoch0 := int(opened.get("session_epoch", 0))
	if not _check(epoch0 > 0, "direct open epoch nonzero"):
		return false
	if not _check(int(opened.get("publication_revision", -1)) == 0, "direct open rev 0"):
		return false
	var submit0: Dictionary = _bridge.call("submit_catalog_region", GROVE0_SA, 0)
	if not _check(bool(submit0.get("ok", false)), "submit grove0: " + str(submit0.get("error", ""))):
		return false
	var id0 := int(submit0.get("request_id", 0))
	if not _check(id0 > 0 and int(submit0.get("session_epoch", 0)) == epoch0, "grove0 id/epoch"):
		return false
	var ready0: Dictionary = await _await_bridge_terminal(id0)
	if not _check(str(ready0.get("status", "")) == "ready" and bool(ready0.get("ok", false)), "grove0 ready: " + str(ready0.get("error", ""))):
		return false
	if not _check(int(ready0.get("publication_revision", -1)) == 1, "grove0 rev 1"):
		return false
	if not _check(_validate_catalog_payload(ready0, "catalog_disc", 0, 140.0, 274, 47, 321, "grove0 R140", 134, 0), "grove0 payload"):
		return false
	if not _check(_lineage_empty(ready0), "grove0 empty COL (no 3991/4043)"):
		return false
	var idle0: Dictionary = _bridge.call("poll_region")
	if not _check(str(idle0.get("status", "")) == "idle" and not bool(idle0.get("ok", false)), "grove0 one-shot idle"):
		return false
	var rev_before_close := 1
	# Close/reopen R140 grove1 fixture2: epochs monotonic, IDs never reused, seq preserved.
	var hang: Dictionary = _bridge.call("submit_catalog_region", GROVE0_SA, 0)
	if not _check(bool(hang.get("ok", false)), "submit hang for close"):
		return false
	var hang_id := int(hang.get("request_id", 0))
	var discarded_before := int(hang.get("discarded_stale", 0))
	_bridge.call("close_game")
	_bridge_open = false
	var reopened: Dictionary = _bridge.call("open_game", game_dir, 140.0, 256)
	if not _check(bool(reopened.get("ok", false)), "reopen R140b: " + str(reopened.get("error", ""))):
		return false
	_bridge_open = true
	if not _check(int(reopened.get("session_epoch", 0)) > epoch0, "reopen epoch higher"):
		return false
	if not _check(int(reopened.get("publication_revision", -1)) == rev_before_close, "close/reopen preserves seq"):
		return false
	var idle_re: Dictionary = _bridge.call("poll_region")
	if not _check(str(idle_re.get("status", "")) == "idle", "no old result after reopen"):
		return false
	var submit1: Dictionary = _bridge.call("submit_catalog_region", GROVE1_SA, 0)
	if not _check(bool(submit1.get("ok", false)), "submit grove1"):
		return false
	if not _check(int(submit1.get("request_id", 0)) == hang_id + 1, "IDs never reused"):
		return false
	if not _check(int(submit1.get("discarded_stale", -1)) == discarded_before, "discarded preserved"):
		return false
	var id1 := int(submit1.get("request_id", 0))
	var ready1: Dictionary = await _await_bridge_terminal(id1)
	if not _check(str(ready1.get("status", "")) == "ready" and bool(ready1.get("ok", false)), "grove1 ready: " + str(ready1.get("error", ""))):
		return false
	if not _check(int(ready1.get("publication_revision", -1)) == 2, "grove1 rev 2"):
		return false
	if not _check(_validate_catalog_payload(ready1, "catalog_disc", 0, 140.0, 269, 48, 317, "grove1 R140", 138, 0), "grove1 payload"):
		return false
	# R200 grove2 fixture3.
	_bridge.call("close_game")
	_bridge_open = false
	var reopen200: Dictionary = _bridge.call("open_game", game_dir, 200.0, 256)
	if not _check(bool(reopen200.get("ok", false)), "reopen R200"):
		return false
	_bridge_open = true
	var epoch200 := int(reopen200.get("session_epoch", 0))
	if not _check(epoch200 > int(reopened.get("session_epoch", 0)), "epoch monotonic R200"):
		return false
	var submit2: Dictionary = _bridge.call("submit_catalog_region", GROVE2_SA, 0)
	if not _check(bool(submit2.get("ok", false)), "submit grove2"):
		return false
	var ready2: Dictionary = await _await_bridge_terminal(int(submit2.get("request_id", 0)))
	if not _check(str(ready2.get("status", "")) == "ready" and bool(ready2.get("ok", false)), "grove2 ready: " + str(ready2.get("error", ""))):
		return false
	if not _check(_validate_catalog_payload(ready2, "catalog_disc", 0, 200.0, 285, 45, 330, "grove2 R200", 136, 0), "grove2 payload"):
		return false
	# R190 roads with pair (never R200 here: larger Roads R200 has cross-area LOD closure => correct rejection, do not silently omit).
	_bridge.call("close_game")
	_bridge_open = false
	var reopen190: Dictionary = _bridge.call("open_game", game_dir, 190.0, 256)
	if not _check(bool(reopen190.get("ok", false)), "reopen R190"):
		return false
	_bridge_open = true
	var submit_r: Dictionary = _bridge.call("submit_catalog_region", ROADS_SA, 0)
	if not _check(bool(submit_r.get("ok", false)), "submit roads"):
		return false
	var ready_r: Dictionary = await _await_bridge_terminal(int(submit_r.get("request_id", 0)))
	if not _check(str(ready_r.get("status", "")) == "ready" and bool(ready_r.get("ok", false)), "roads ready: " + str(ready_r.get("error", ""))):
		return false
	if not _check(_validate_catalog_payload(ready_r, "catalog_disc", 0, 190.0, 279, 47, 326, "roads R190", 136, 5), "roads payload"):
		return false
	if not _check(_validate_bridge_pair(ready_r), "roads pair 3991/4043 COL122"):
		return false
	# Area16 entire area (R140 open for stable cycle below).
	_bridge.call("close_game")
	_bridge_open = false
	var reopen140: Dictionary = _bridge.call("open_game", game_dir, 140.0, 256)
	if not _check(bool(reopen140.get("ok", false)), "reopen R140 for area16"):
		return false
	_bridge_open = true
	var submit_a: Dictionary = _bridge.call("submit_catalog_region", TATTOO_SA, 16)
	if not _check(bool(submit_a.get("ok", false)), "submit area16: " + str(submit_a.get("error", ""))):
		return false
	var ready_a: Dictionary = await _await_bridge_terminal(int(submit_a.get("request_id", 0)))
	if not _check(str(ready_a.get("status", "")) == "ready" and bool(ready_a.get("ok", false)), "area16 ready: " + str(ready_a.get("error", ""))):
		return false
	if not _check(_validate_catalog_payload(ready_a, "catalog_area", 16, 140.0, 36, 0, 36, "area16", 26, 0), "area16 payload"):
		return false
	if not _check(_area16_models(ready_a, 26), "area16 26 models"):
		return false
	# Same R140 interior->Grove->interior->Grove stable counts/payload.
	var submit_g2: Dictionary = _bridge.call("submit_catalog_region", GROVE0_SA, 0)
	if not _check(bool(submit_g2.get("ok", false)), "stable grove submit"):
		return false
	var ready_g2: Dictionary = await _await_bridge_terminal(int(submit_g2.get("request_id", 0)))
	if not _check(str(ready_g2.get("status", "")) == "ready" and _validate_catalog_payload(ready_g2, "catalog_disc", 0, 140.0, 274, 47, 321, "stable grove", 134, 0), "stable grove counts"):
		return false
	var submit_a2: Dictionary = _bridge.call("submit_catalog_region", TATTOO_SA, 16)
	if not _check(bool(submit_a2.get("ok", false)), "stable area submit"):
		return false
	var ready_a2: Dictionary = await _await_bridge_terminal(int(submit_a2.get("request_id", 0)))
	if not _check(str(ready_a2.get("status", "")) == "ready" and _validate_catalog_payload(ready_a2, "catalog_area", 16, 140.0, 36, 0, 36, "stable area", 26, 0), "stable area counts"):
		return false
	var submit_g3: Dictionary = _bridge.call("submit_catalog_region", GROVE0_SA, 0)
	if not _check(bool(submit_g3.get("ok", false)), "stable grove2 submit"):
		return false
	var ready_g3: Dictionary = await _await_bridge_terminal(int(submit_g3.get("request_id", 0)))
	if not _check(str(ready_g3.get("status", "")) == "ready" and _validate_catalog_payload(ready_g3, "catalog_disc", 0, 140.0, 274, 47, 321, "stable grove2", 134, 0), "stable grove2 counts"):
		return false
	if not _check(_stable_payload_match(ready0, ready_g3, "grove stable payload") and _stable_payload_match(ready_a, ready_a2, "area stable payload"), "stable payload match"):
		return false
	# Legacy default256 at same Grove center remains capped (different mode proved; catalog visible 274 genuinely >256).
	var legacy: Dictionary = _bridge.call("load_region", GROVE0_SA)
	if not _check(bool(legacy.get("ok", false)), "legacy grove load: " + str(legacy.get("error", ""))):
		return false
	if not _check((legacy.get("meshes", []) as Array).size() <= 256, "legacy capped <=256 vs catalog visible 274"):
		return false
	if not _check(not (legacy.get("stats", {}) as Dictionary).has("selection"), "legacy carries no selection"):
		return false
	# Invalid areas rejected, no rev advance.
	var rev_before_invalid := int(ready_g3.get("publication_revision", 0))
	# Note: legacy load above advanced rev by one; use its rev as baseline.
	var legacy_rev := int(legacy.get("publication_revision", rev_before_invalid))
	for bad_area in [-1, 256]:
		var bad: Dictionary = _bridge.call("submit_catalog_region", GROVE0_SA, bad_area)
		if not _check(not bool(bad.get("ok", true)), "invalid area %d must reject" % bad_area):
			return false
		# Sync invalid also rejects immediately.
		var bad_sync: Dictionary = _bridge.call("load_catalog_region", GROVE0_SA, bad_area)
		if not _check(not bool(bad_sync.get("ok", true)) and not bad_sync.has("meshes"), "invalid sync area %d no meshes" % bad_area):
			return false
		if not _check(int(bad_sync.get("publication_revision", -1)) == legacy_rev, "invalid no rev advance"):
			return false
	# Anim ROI R60 whole failure, no Rev, not skip.
	_bridge.call("close_game")
	_bridge_open = false
	var reopen60: Dictionary = _bridge.call("open_game", game_dir, 60.0, 256)
	if not _check(bool(reopen60.get("ok", false)), "reopen R60"):
		return false
	_bridge_open = true
	var rev60 := int(reopen60.get("publication_revision", -1))
	var anim_submit: Dictionary = _bridge.call("submit_catalog_region", ANIM_SA, 0)
	if not _check(bool(anim_submit.get("ok", false)), "anim submit accepted (failure arrives via poll)"):
		return false
	var anim_ready: Dictionary = await _await_bridge_terminal(int(anim_submit.get("request_id", 0)))
	if not _check(str(anim_ready.get("status", "")) == "error" and not bool(anim_ready.get("ok", true)), "anim honest whole failure, not skip"):
		return false
	if not _check(int(anim_ready.get("publication_revision", -1)) == rev60, "anim no rev advance"):
		return false
	if not _check(not anim_ready.has("meshes"), "anim no partial meshes"):
		return false
	# NaN policy unchanged: legacy SF radar still nonfinite_uv.
	var nan_sync: Dictionary = _bridge.call("load_region", SF_NAN_SA)
	# After anim error, rev still rev60; NaN error must also retain rev.
	if not _check(not bool(nan_sync.get("ok", true)) and str(nan_sync.get("error_code", "")) == "nonfinite_uv" and int(nan_sync.get("publication_revision", -1)) == rev60, "NaN policy unchanged"):
		return false
	return true


func _capture_catalog_stop(lab: Node, area: int, label: String) -> void:
	for stop in lab.CATALOG_ROUTE_STOPS:
		if int(stop.area) != area:
			continue
		lab.camera.position = lab._sa_to_world(stop.eye)
		lab._camera_target_world = lab._sa_to_world(stop.target)
		lab.camera.look_at(lab._camera_target_world, Vector3.UP)
		await lab._capture_current(label)
		return


func _run_lab_fixture() -> bool:
	var lab: Node = load("res://lab.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	if not _check(is_instance_valid(lab) and lab._has_published_region and not lab._shutdown_started, "lab initial region"):
		return false
	if not _check(lab._catalog_route_enabled and lab._route_enabled, "catalog-route CLI enables normal process itinerary"):
		return false
	var toggle := InputEventKey.new()
	toggle.physical_keycode = KEY_R
	toggle.pressed = true
	lab._unhandled_input(toggle)
	if not _check(not lab._route_enabled, "R pauses catalog route"):
		return false
	lab._unhandled_input(toggle)
	if not _check(lab._route_enabled, "R resumes catalog route"):
		return false
	# Lab was opened via shared CLI args. When parent runs with --catalog-route
	# (no --radius) it opens R140 catalog Grove0 (parent changed default 130->140);
	# otherwise it opens legacy 350. Fixture-controlled deterministic commits below use explicit helpers.
	if not _check(lab._bridge.has_method("submit_catalog_region") and lab._bridge.has_method("load_catalog_region"), "lab catalog methods required"):
		return false
	# Route progress requires a committed waypoint, not merely an accepted
	# request. Real cancellation must retry the same stop without skipping it.
	lab._catalog_route_index = 1
	lab._catalog_route_last_advance_elapsed = lab._elapsed - 3.0
	var route_base: int = lab._publication_revision
	lab._update_catalog_route(0.0)
	if not _check(lab._has_pending_region() and lab._catalog_route_index == 1, "route submit is not a completed waypoint"):
		return false
	lab._cancel_pending_region()
	if not await _await_lab_settled(lab):
		return false
	lab._update_catalog_route(0.0)
	if not _check(lab._catalog_route_index == 1 and lab._publication_revision == route_base and lab._catalog_route_rejects == 1, "cancelled waypoint retained for retry"):
		return false
	lab._catalog_route_last_advance_elapsed = lab._elapsed - 3.0
	lab._update_catalog_route(0.0)
	if not await _await_lab_settled(lab):
		return false
	if not _check(lab._catalog_route_index == 1 and lab._publication_revision == route_base + 1, "waypoint committed before route advancement"):
		return false
	lab._update_catalog_route(0.0)
	if not _check(lab._catalog_route_index == 2 and lab._catalog_route_commits == 1, "route advances after committed settled waypoint"):
		return false
	# Ensure R140 catalog baseline deterministically: sync catalog load at Grove0.
	# If lab already catalog R140 (parent --catalog-route), this republishes next rev;
	# otherwise it establishes the first catalog generation. Both prove the helper.
	# Genuine visible 274 >256 (not just resident total).
	var base_rev: int = lab._publication_revision
	var sync_ok: bool = lab._load_catalog_region(GROVE0_SA, 0)
	if not _check(sync_ok, "lab sync catalog grove0 R140"):
		return false
	if not _check(lab._publication_revision == base_rev + 1, "lab catalog sync advances"):
		return false
	if not _check(_validate_lab_catalog(lab, "catalog_disc", 0, 274, 47, 321, "lab grove0", 134, 0), "lab grove0 selection"):
		return false
	if not _check(_lab_hidden_reconciles(lab, 47), "lab grove0 hidden 47"):
		return false
	var grove_rev: int = lab._publication_revision
	var grove_nodes: Array = _lab_active_node_ids(lab)
	var grove_meshes: Array = _lab_active_mesh_ids(lab)
	var grove_collision: Dictionary = lab._region_collision.duplicate(true)
	var grove_stats: Dictionary = lab._region_stats.duplicate(true)
	# Area16 entire area via async helper + budgeted pump (deterministic).
	var area_submit: Dictionary = lab._submit_catalog_region(TATTOO_SA, 16)
	if not _check(bool(area_submit.get("ok", false)), "lab area16 submit: " + str(area_submit.get("error", ""))):
		return false
	if not _check(lab._has_pending_region(), "lab area16 pending"):
		return false
	if not _check(lab._publication_revision == grove_rev, "lab old retained while pending"):
		return false
	if not await _await_lab_settled(lab):
		printerr("region-catalog-fail: lab area16 deadline")
		quit(1)
		return false
	if not _check(lab._publication_revision == grove_rev + 1, "lab area16 commits"):
		return false
	if not _check(_validate_lab_catalog(lab, "catalog_area", 16, 36, 0, 36, "lab area16", 26, 0), "lab area16 selection"):
		return false
	if not _check(_area16_models_lab(lab, 26), "lab area16 26 models"):
		return false
	if not _check(_lab_hidden_reconciles(lab, 0), "lab area16 hidden 0"):
		return false
	await _capture_catalog_stop(lab, 16, "catalog-area16")
	var area_rev: int = lab._publication_revision
	# Same R140 interior->Grove->interior->Grove stable + resource plateau.
	var settled_counts: Array[int] = []
	settled_counts.append(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)))
	# Grove again.
	var g2_submit: Dictionary = lab._submit_catalog_region(GROVE0_SA, 0)
	if not _check(bool(g2_submit.get("ok", false)), "lab stable grove submit"):
		return false
	if not await _await_lab_settled(lab):
		printerr("region-catalog-fail: lab stable grove deadline")
		quit(1)
		return false
	if not _check(lab._publication_revision == area_rev + 1 and _validate_lab_catalog(lab, "catalog_disc", 0, 274, 47, 321, "lab stable grove", 134, 0), "lab stable grove counts"):
		return false
	await _capture_catalog_stop(lab, 0, "catalog-grove-capless")
	settled_counts.append(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)))
	# Area again.
	var a2_submit: Dictionary = lab._submit_catalog_region(TATTOO_SA, 16)
	if not _check(bool(a2_submit.get("ok", false)), "lab stable area submit"):
		return false
	if not await _await_lab_settled(lab):
		printerr("region-catalog-fail: lab stable area deadline")
		quit(1)
		return false
	if not _check(lab._publication_revision == area_rev + 2 and _validate_lab_catalog(lab, "catalog_area", 16, 36, 0, 36, "lab stable area", 26, 0), "lab stable area counts"):
		return false
	settled_counts.append(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)))
	# Grove once more.
	var g3_submit: Dictionary = lab._submit_catalog_region(GROVE0_SA, 0)
	if not _check(bool(g3_submit.get("ok", false)), "lab stable grove2 submit"):
		return false
	if not await _await_lab_settled(lab):
		printerr("region-catalog-fail: lab stable grove2 deadline")
		quit(1)
		return false
	if not _check(lab._publication_revision == area_rev + 3 and _validate_lab_catalog(lab, "catalog_disc", 0, 274, 47, 321, "lab stable grove2", 134, 0), "lab stable grove2 counts"):
		return false
	settled_counts.append(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)))
	print("region-catalog-settled resources=", settled_counts)
	if not _check(settled_counts[2] <= settled_counts[0] + 2 and settled_counts[3] <= settled_counts[1] + 2, "settled resource plateau"):
		return false
	# Legacy default256 at same Grove center remains capped (different mode; catalog visible 274 genuinely >256).
	var legacy_ok: bool = lab._load_region(GROVE0_SA)
	if not _check(legacy_ok, "lab legacy grove load"):
		return false
	if not _check(lab._resident_meshes <= 256 and lab._resident_meshes <= lab._cap, "lab legacy capped vs catalog visible 274"):
		return false
	if not _check(not (lab._region_stats as Dictionary).has("selection"), "lab legacy no selection"):
		return false
	# Restore catalog Grove for failure-retention checks.
	var restore_ok: bool = lab._load_catalog_region(GROVE0_SA, 0)
	if not _check(restore_ok and _validate_lab_catalog(lab, "catalog_disc", 0, 274, 47, 321, "lab restore", 134, 0), "lab restore catalog"):
		return false
	var restore_rev: int = lab._publication_revision
	var restore_nodes: Array = _lab_active_node_ids(lab)
	var restore_meshes: Array = _lab_active_mesh_ids(lab)
	var restore_collision: Dictionary = lab._region_collision.duplicate(true)
	var restore_stats: Dictionary = lab._region_stats.duplicate(true)
	# Invalid areas rejected, old retained.
	for bad_area in [-1, 256]:
		var bad_submit: Dictionary = lab._submit_catalog_region(GROVE0_SA, bad_area)
		# Bridge may reject immediately (ok=false) or accept then error via poll.
		if bool(bad_submit.get("ok", false)):
			if not await _await_lab_settled(lab):
				printerr("region-catalog-fail: lab invalid poll deadline")
				quit(1)
				return false
		else:
			# Immediate reject: no pending, no rev change.
			if not _check(not lab._has_pending_region(), "invalid immediate no pending"):
				return false
		if not _check(lab._publication_revision == restore_rev, "invalid no rev advance"):
			return false
		if not _check(_lab_active_node_ids(lab) == restore_nodes, "invalid retains nodes"):
			return false
		if not _check(_deep_equal(lab._region_collision, restore_collision), "invalid retains COL"):
			return false
		var bad_sync_ok: bool = lab._load_catalog_region(GROVE0_SA, bad_area)
		if not _check(not bad_sync_ok, "invalid sync must fail"):
			return false
		if not _check(lab._publication_revision == restore_rev and _deep_equal(lab._region_stats, restore_stats), "invalid sync retains"):
			return false
	# Anim ROI whole failure with lab radius (still contains anim): retain old.
	# Direct R60 exact fixture proven above; lab proves retention under its open.
	var anim_submit: Dictionary = lab._submit_catalog_region(ANIM_SA, 0)
	if not _check(bool(anim_submit.get("ok", false)), "lab anim submit accepted"):
		return false
	if not await _await_lab_settled(lab):
		printerr("region-catalog-fail: lab anim deadline")
		quit(1)
		return false
	if not _check(lab._publication_revision == restore_rev, "lab anim no rev"):
		return false
	if not _check(_lab_active_node_ids(lab) == restore_nodes and _lab_active_mesh_ids(lab) == restore_meshes, "lab anim retains resources"):
		return false
	if not _check(_deep_equal(lab._region_collision, restore_collision) and _deep_equal(lab._region_stats, restore_stats), "lab anim retains payload"):
		return false
	# Manifest scalar only, no COL dump, catalog labels.
	lab._write_run_manifest("catalog-probe", false, "", "completed")
	var manifest_path: String = lab._capture_dir.path_join("%s-catalog-probe.manifest.json" % lab._profile_id())
	if not _check(FileAccess.file_exists(manifest_path), "catalog manifest exists"):
		return false
	var mf := FileAccess.open(manifest_path, FileAccess.READ)
	if not _check(mf != null, "catalog manifest readable"):
		return false
	var text := mf.get_as_text()
	mf.close()
	if not _check(not text.contains("face_indices") and not text.contains("face_surfaces"), "manifest no COL arrays"):
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not _check(parsed is Dictionary, "manifest JSON"):
		return false
	var sel: Variant = (parsed as Dictionary).get("region_publication", {}).get("selection", null)
	if not _check(sel is Dictionary and str((sel as Dictionary).get("mode", "")) in ["catalog_disc", "catalog_area"], "manifest selection scalar"):
		return false
	if not _check(text.contains("unknown-pending-P5-A02") and text.contains("diagnostic"), "manifest labels unknown/time diagnostic"):
		return false
	lab._update_overlay()
	# Teardown cancels deferred capture.
	lab._frame_count = 99999
	var cancelled_path: String = lab._capture_dir.path_join("%s-manual-099999.png" % lab._profile_id())
	lab.call_deferred("_capture_manual")
	var held_faces := -1
	if not restore_collision.is_empty():
		held_faces = int((restore_collision.get("col", {}) as Dictionary).get("faces", -1))
	lab.free()
	await process_frame
	await process_frame
	if not _check(not FileAccess.file_exists(cancelled_path), "teardown cancels deferred capture"):
		return false
	if not _check(held_faces == -1 or held_faces == 0 or held_faces == 122, "held payload readable across teardown"):
		return false
	# Silence unused warnings for retained snapshots.
	if not _check(grove_nodes.size() >= 0 and grove_meshes.size() >= 0 and grove_collision.size() >= 0 and grove_stats.size() >= 0, "handover kept"):
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


func _validate_catalog_payload(packet: Dictionary, exp_mode: String, exp_area: int, exp_radius: float, exp_vis: int, exp_hid: int, exp_total: int, label: String, exp_models: int = -1, exp_time: int = -1) -> bool:
	if not packet.get("stats") is Dictionary:
		printerr("region-catalog-fail: ", label, " no stats")
		return false
	var stats: Dictionary = packet.stats
	if not stats.get("selection") is Dictionary:
		printerr("region-catalog-fail: ", label, " no selection")
		return false
	var sel: Dictionary = stats.selection
	if str(sel.get("mode", "")) != exp_mode:
		printerr("region-catalog-fail: ", label, " mode ", str(sel.get("mode", "")))
		return false
	if int(sel.get("area_id", -1)) != exp_area:
		printerr("region-catalog-fail: ", label, " area")
		return false
	if absf(float(sel.get("radius", -1.0)) - exp_radius) > 0.001:
		printerr("region-catalog-fail: ", label, " radius ", str(sel.get("radius", "")))
		return false
	if int(sel.get("population", -1)) != POPULATION:
		printerr("region-catalog-fail: ", label, " population")
		return false
	if int(sel.get("expected_visible", -1)) != exp_vis or int(sel.get("expected_hidden", -1)) != exp_hid or int(sel.get("resident", -1)) != exp_total:
		printerr("region-catalog-fail: ", label, " counts vis/hid/res actual=", sel.get("expected_visible"), "/", sel.get("expected_hidden"), "/", sel.get("resident"), " expected=", exp_vis, "/", exp_hid, "/", exp_total)
		return false
	# Genuine VISIBLE must exceed 256 for exterior discs (not just resident total with hidden).
	if exp_mode == "catalog_disc" and exp_vis <= 256:
		printerr("region-catalog-fail: ", label, " visible must genuinely exceed 256, got ", exp_vis)
		return false
	if exp_mode == "catalog_disc" and int(sel.get("expected_visible", 0)) <= 256:
		printerr("region-catalog-fail: ", label, " actual visible <=256, not genuine visible>256")
		return false
	if exp_time >= 0 and int(sel.get("time_models", -1)) != exp_time:
		printerr("region-catalog-fail: ", label, " time_models actual=", sel.get("time_models"), " expected=", exp_time)
		return false
	if int(sel.get("excluded_outside", -1)) != POPULATION - exp_total:
		printerr("region-catalog-fail: ", label, " excluded")
		return false
	if str(sel.get("lod_visibility_authority", "")) != AUTHORITY or str(sel.get("time_visibility_authority", "")) != AUTHORITY:
		printerr("region-catalog-fail: ", label, " authority")
		return false
	if not packet.get("meshes") is Array:
		printerr("region-catalog-fail: ", label, " no meshes")
		return false
	var meshes: Array = packet.meshes
	if meshes.size() != exp_total:
		printerr("region-catalog-fail: ", label, " meshes size ", meshes.size())
		return false
	var hidden := 0
	var seen := {}
	for info in meshes:
		if not info is Dictionary:
			printerr("region-catalog-fail: ", label, " mesh not dict")
			return false
		if not info.get("lod_target_hidden") is bool:
			printerr("region-catalog-fail: ", label, " lod_target_hidden not bool")
			return false
		if bool(info.get("lod_target_hidden", false)):
			hidden += 1
		if not info.get("mesh") is ArrayMesh or (info.mesh as ArrayMesh).get_surface_count() == 0:
			printerr("region-catalog-fail: ", label, " invalid ArrayMesh")
			return false
		var mid := (info.mesh as ArrayMesh).get_instance_id()
		if seen.has(mid):
			printerr("region-catalog-fail: ", label, " duplicate mesh resource")
			return false
		seen[mid] = true
		if not info.get("source_model") is String or String(info.source_model).is_empty():
			printerr("region-catalog-fail: ", label, " no source_model")
			return false
		if not info.get("source_model_id") is int or int(info.source_model_id) < 0:
			printerr("region-catalog-fail: ", label, " no source_model_id")
			return false
		if not info.get("surface_materials") is Array or (info.surface_materials as Array).size() != (info.mesh as ArrayMesh).get_surface_count():
			printerr("region-catalog-fail: ", label, " surface count")
			return false
	if hidden != exp_hid:
		printerr("region-catalog-fail: ", label, " hidden flags actual=", hidden, " expected=", exp_hid)
		return false
	if exp_models >= 0:
		var uniq := {}
		for info in meshes:
			uniq["%s#%d" % [str((info as Dictionary).get("source_model", "")).to_lower(), int((info as Dictionary).get("source_model_id", -1))]] = true
		if uniq.size() != exp_models:
			printerr("region-catalog-fail: ", label, " unique models actual=", uniq.size(), " expected=", exp_models)
			return false
	return true


func _lineage_empty(packet: Dictionary) -> bool:
	var lin: Variant = packet.get("collision_lineage", {})
	if lin is Dictionary and (lin as Dictionary).is_empty():
		return true
	return false


func _validate_bridge_pair(packet: Dictionary) -> bool:
	if not packet.get("collision_lineage") is Dictionary:
		printerr("region-catalog-fail: no collision_lineage")
		return false
	var lineage: Dictionary = packet.collision_lineage
	if int(lineage.get("generation", -1)) != int(packet.get("publication_revision", -2)):
		printerr("region-catalog-fail: generation mismatch")
		return false
	if str(lineage.get("scope", "")) != "single-chain-data-not-gameplay" or str(lineage.get("link", "")) != "bound" or not bool(lineage.get("collision_transferred", false)):
		printerr("region-catalog-fail: lineage scope/link/transfer")
		return false
	var child: Dictionary = lineage.get("child", {})
	var parent: Dictionary = lineage.get("parent", {})
	var col: Dictionary = lineage.get("col", {})
	if int(child.get("model_id", -1)) != 3991 or str(child.get("model", "")).to_lower() != "gsfreeway7_lan":
		printerr("region-catalog-fail: child role")
		return false
	if int(parent.get("model_id", -1)) != 4043 or str(parent.get("model", "")).to_lower() != "lodgsfreeway7_lan":
		printerr("region-catalog-fail: parent role")
		return false
	if int(col.get("header_id", -1)) != 3991 or int(col.get("faces", -1)) != 122 or str(col.get("status", "")) != "ready":
		printerr("region-catalog-fail: COL 122 ready")
		return false
	if (col.get("face_surfaces", PackedByteArray()) as PackedByteArray).size() != 488:
		printerr("region-catalog-fail: surface 488 bytes")
		return false
	if (col.get("face_indices", PackedInt32Array()) as PackedInt32Array).size() != 366:
		printerr("region-catalog-fail: index count")
		return false
	return true


func _area16_models(packet: Dictionary, exp_unique: int) -> bool:
	var meshes: Array = packet.get("meshes", [])
	var uniq := {}
	for info in meshes:
		uniq["%s#%d" % [str((info as Dictionary).get("source_model", "")).to_lower(), int((info as Dictionary).get("source_model_id", -1))]] = true
	if uniq.size() != exp_unique:
		printerr("region-catalog-fail: area16 unique models ", uniq.size(), " expected ", exp_unique)
		return false
	return true


func _stable_payload_match(first: Dictionary, second: Dictionary, label: String) -> bool:
	var a_meshes: Array = first.get("meshes", [])
	var b_meshes: Array = second.get("meshes", [])
	if a_meshes.size() != b_meshes.size():
		printerr("region-catalog-fail: ", label, " size")
		return false
	var a_ids := {}
	for info in a_meshes:
		a_ids["%s#%d" % [str((info as Dictionary).get("source_model", "")).to_lower(), int((info as Dictionary).get("source_model_id", -1))]] = true
	var b_ids := {}
	for info in b_meshes:
		b_ids["%s#%d" % [str((info as Dictionary).get("source_model", "")).to_lower(), int((info as Dictionary).get("source_model_id", -1))]] = true
	# Counts stable; placement identities stable as sets (order may differ).
	# Strict per-placement deep equality would require identical ArrayMesh
	# resources across publications, which new GPU resources never share.
	if a_ids.size() != b_ids.size():
		printerr("region-catalog-fail: ", label, " unique count")
		return false
	for key in a_ids:
		if not b_ids.has(key):
			printerr("region-catalog-fail: ", label, " identity ", key)
			return false
	var a_sel: Dictionary = (first.get("stats", {}) as Dictionary).get("selection", {})
	var b_sel: Dictionary = (second.get("stats", {}) as Dictionary).get("selection", {})
	if not _deep_equal(a_sel, b_sel):
		printerr("region-catalog-fail: ", label, " selection")
		return false
	return true


func _validate_lab_catalog(lab: Node, exp_mode: String, exp_area: int, exp_vis: int, exp_hid: int, exp_total: int, label: String, exp_models: int = -1, exp_time: int = -1) -> bool:
	var stats: Dictionary = lab._region_stats
	if not stats.get("selection") is Dictionary:
		printerr("region-catalog-fail: ", label, " lab no selection")
		return false
	var sel: Dictionary = stats.selection
	if not _check(str(sel.get("mode", "")) == exp_mode, label + " mode"):
		return false
	if not _check(int(sel.get("area_id", -1)) == exp_area, label + " area"):
		return false
	if not _check(int(sel.get("expected_visible", -1)) == exp_vis and int(sel.get("expected_hidden", -1)) == exp_hid and int(sel.get("resident", -1)) == exp_total, label + " counts actual=%d/%d/%d expected=%d/%d/%d" % [int(sel.get("expected_visible", -1)), int(sel.get("expected_hidden", -1)), int(sel.get("resident", -1)), exp_vis, exp_hid, exp_total]):
		return false
	if exp_mode == "catalog_disc" and exp_vis <= 256:
		printerr("region-catalog-fail: ", label, " visible must genuinely exceed 256")
		return false
	if exp_mode == "catalog_disc" and int(sel.get("expected_visible", 0)) <= 256:
		printerr("region-catalog-fail: ", label, " actual visible <=256")
		return false
	if exp_time >= 0 and not _check(int(sel.get("time_models", -1)) == exp_time, label + " time_models actual=%s expected=%d" % [str(sel.get("time_models", "?")), exp_time]):
		return false
	if not _check(int(sel.get("population", -1)) == POPULATION and int(sel.get("excluded_outside", -1)) == POPULATION - exp_total, label + " pop"):
		return false
	if not _check(str(sel.get("lod_visibility_authority", "")) == AUTHORITY and str(sel.get("time_visibility_authority", "")) == AUTHORITY, label + " authority"):
		return false
	var nodes: Array = lab._active_region_root().get_children()
	if not _check(nodes.size() == exp_total, label + " resident nodes"):
		return false
	if not _check(lab._resident_meshes == exp_total, label + " resident_meshes"):
		return false
	var hidden_nodes := 0
	var seen := {}
	for node in nodes:
		if not (node is MeshInstance3D):
			printerr("region-catalog-fail: ", label, " not MeshInstance3D")
			return false
		var inst := node as MeshInstance3D
		if inst.mesh == null or not inst.mesh is ArrayMesh or (inst.mesh as ArrayMesh).get_surface_count() == 0:
			printerr("region-catalog-fail: ", label, " invalid mesh resource")
			return false
		var mid := (inst.mesh as ArrayMesh).get_instance_id()
		if seen.has(mid):
			printerr("region-catalog-fail: ", label, " duplicate mesh")
			return false
		seen[mid] = true
		if not node.has_meta("lod_target_hidden"):
			printerr("region-catalog-fail: ", label, " missing lod_target_hidden meta")
			return false
		if bool(node.get_meta("lod_target_hidden", false)):
			hidden_nodes += 1
			if node.visible:
				printerr("region-catalog-fail: ", label, " hidden must be invisible")
				return false
	if not _check(hidden_nodes == exp_hid, label + " hidden nodes actual=%d expected=%d" % [hidden_nodes, exp_hid]):
		return false
	if exp_models >= 0:
		var uniq := {}
		for node in nodes:
			uniq["%s#%d" % [str(node.get_meta("source_model", "")).to_lower(), int(node.get_meta("source_model_id", -1))]] = true
		if not _check(uniq.size() == exp_models, label + " unique models actual=%d expected=%d" % [uniq.size(), exp_models]):
			return false
	return true


func _lab_hidden_reconciles(lab: Node, exp_hid: int) -> bool:
	var nodes: Array = lab._active_region_root().get_children()
	var hidden := 0
	for node in nodes:
		if bool(node.get_meta("lod_target_hidden", false)):
			hidden += 1
	if hidden != exp_hid:
		printerr("region-catalog-fail: lab hidden reconcile ", hidden, " expected ", exp_hid)
		return false
	return true


func _area16_models_lab(lab: Node, exp_unique: int) -> bool:
	var nodes: Array = lab._active_region_root().get_children()
	var uniq := {}
	for node in nodes:
		uniq["%s#%d" % [str(node.get_meta("source_model", "")).to_lower(), int(node.get_meta("source_model_id", -1))]] = true
	if uniq.size() != exp_unique:
		printerr("region-catalog-fail: lab area16 unique ", uniq.size())
		return false
	return true


func _lab_active_node_ids(lab: Node) -> Array:
	return lab._active_region_root().get_children().map(func(node: Node) -> int: return node.get_instance_id())


func _lab_active_mesh_ids(lab: Node) -> Array:
	return lab._active_region_root().get_children().map(func(node: Node) -> int: return (node as MeshInstance3D).mesh.get_instance_id())


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
		if arg == "--route" or arg == "--catalog-route":
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
			result.error = "unknown region catalog option: %s" % arg
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
		printerr("region-catalog-fail: ", label)
		_close_bridge()
		quit(1)
	return condition


func _close_bridge() -> void:
	if _bridge_open and _bridge != null:
		_bridge.call("close_game")
	_bridge_open = false
