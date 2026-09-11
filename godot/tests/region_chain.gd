extends SceneTree

const GROVE_CENTER_SA := Vector3(2490.0, -1665.0, 14.0)
const ROADS_CENTER_SA := Vector3(1532.054688, -1662.289063, 12.460938)
const SF_NAN_CENTER_SA := Vector3(-1687.414063, -623.023438, 18.148438)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	if not bool(options.get("ok", false)):
		printerr("region-chain-fail: ", str(options.get("error", "bad options")))
		quit(2)
		return
	if bool(options.get("expect_open", false)) or bool(options.get("expect_region", false)) or bool(options.get("synthetic_baseline", false)):
		await _run_negative(options)
		return
	await _run_normal(options)


func _run_negative(options: Dictionary) -> void:
	# Exercise the actual resource boundary directly. Instantiating the lab here
	# could fail on intentionally absent timecyc before ever testing the DFF/COL.
	if not GDExtensionManager.is_extension_loaded("res://sa_legacy.gdextension"):
		if not _check(GDExtensionManager.load_extension("res://sa_legacy.gdextension") == GDExtensionManager.LOAD_STATUS_OK, "extension loads"):
			return
	var bridge: Object = ClassDB.instantiate("SALegacyBridge")
	var opened: Dictionary = bridge.call("open_game", options.game_dir, 350.0, 256)
	if options.expect_open:
		if not _check(not opened.ok, "missing COL rejects first open: " + str(opened.get("error", "unexpected success"))):
			return
		var unavailable: Dictionary = bridge.call("load_region", ROADS_CENTER_SA)
		if not _check(not unavailable.ok and unavailable.publication_revision == 0 and not unavailable.has("meshes"), "failed open cannot prepare either lineage"):
			return
	else:
		if not _check(opened.ok and opened.publication_revision == 0, "synthetic baseline metadata/COL opens: " + str(opened.get("error", "unexpected sequence"))):
			return
		var packet: Dictionary = bridge.call("load_region", ROADS_CENTER_SA)
		if options.synthetic_baseline:
			if not _check(packet.ok and packet.publication_revision == 1, "synthetic baseline publishes actual pair: " + str(packet.get("error", ""))):
				return
			var payload: Dictionary = packet.collision_lineage.duplicate(true)
			if not _check(payload.generation == 1 and payload.col.faces == 1 and payload.col.face_indices.size() == 3 and payload.col.face_surfaces.size() == 4, "synthetic one-face owned COL"):
				return
			for role in [payload.child, payload.parent]:
				var mesh: ArrayMesh = packet.meshes[int(role.mesh_index)].mesh
				if not _check(mesh.get_surface_count() == 1, "synthetic child/parent real DFF"):
					return
				var authored: Quaternion = role.placement.quaternion_sa
				if not _check(absf(authored.z) > 0.5 and absf(authored.w) > 0.5, "fixture rotation discriminates conjugation"):
					return
				var rendered: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var vertices: PackedFloat32Array = payload.col.vertices
				for v in range(int(payload.col.vertex_count)):
					var local := Vector3(vertices[v * 3], vertices[v * 3 + 1], vertices[v * 3 + 2])
					var world_sa: Vector3 = authored.inverse() * local + role.placement.position_sa
					var expected := Vector3(world_sa.x, world_sa.z, -world_sa.y)
					var found := false
					for vertex in rendered:
						found = found or vertex.distance_to(expected) < 0.001
					if not _check(found, "DFF and COL placement agree with authored inverse quaternion"):
						return
			bridge.call("close_game")
			if not _check(_deep_equal(payload, packet.collision_lineage), "held collision bytes survive bridge close"):
				return
			opened = bridge.call("open_game", options.game_dir, 350.0, 256)
			if not _check(opened.ok and opened.publication_revision == 1, "close/reopen retains prepared sequence"):
				return
			var again: Dictionary = bridge.call("load_region", ROADS_CENTER_SA)
			if not _check(again.ok and again.publication_revision == 2 and again.collision_lineage.generation == 2, "reopened pair advances together"):
				return
			bridge.call("close_game")
			opened = bridge.call("open_game", options.game_dir, 350.0, 2)
			if not _check(opened.ok, "two-slot cap opens"):
				return
			var capped: Dictionary = bridge.call("load_region", ROADS_CENTER_SA)
			if not _check(capped.ok and capped.meshes.size() == 2 and capped.collision_lineage.child.model_id == 3991 and capped.collision_lineage.parent.model_id == 4043, "cap-edge child retained instead of nearer unrelated filler"):
				return
			bridge.call("close_game")
			opened = bridge.call("open_game", options.game_dir, 350.0, 1)
			if not _check(opened.ok, "one-slot cap can open without half-pair"):
				return
			var too_small: Dictionary = bridge.call("load_region", Vector3(1608.195313, -1721.804688, 26.0))
			if not _check(not too_small.ok and too_small.publication_revision == capped.publication_revision and not too_small.has("meshes"), "selected pair cannot fit cap1: neither published"):
				return
		else:
			if not _check(not packet.ok and packet.publication_revision == 0 and not packet.has("meshes") and not packet.has("collision_lineage"), "missing parent rejects first region without either payload: " + str(packet.get("error", "unexpected success"))):
				return
	bridge.call("close_game")
	print("region-chain-synthetic-ok" if options.synthetic_baseline else "region-chain-negative-ok synthetic-first-failure revision=0")
	quit(0)


func _run_normal(_options: Dictionary) -> void:
	var lab: Node = load("res://lab.tscn").instantiate()
	root.add_child(lab)
	lab.set_process(false)
	if not _check(lab._has_published_region and not lab._shutdown_started, "initial real Grove region"):
		return
	if not _check(lab._region_collision.is_empty(), "initial Grove has empty COL dict"):
		return
	if not _check(_no_parent_alternate(lab), "initial Grove has no 4043 alternate"):
		return
	var grove_revision: int = lab._publication_revision
	# Move to the real Roads window that selects the frozen 3991 child.
	lab.camera.position = Vector3(ROADS_CENTER_SA.x, ROADS_CENTER_SA.z + 20.0, -ROADS_CENTER_SA.y + 20.0)
	lab._camera_target_world = Vector3(ROADS_CENTER_SA.x, ROADS_CENTER_SA.z, -ROADS_CENTER_SA.y)
	lab.camera.look_at(lab._camera_target_world)
	if not _check(lab._load_region(ROADS_CENTER_SA), "finite Roads replacement with pair"):
		return
	if not _check(lab._publication_revision == grove_revision + 1, "Roads success commits next revision"):
		return
	if not _validate_pair(lab, "Roads pair"):
		return
	var roads_revision: int = lab._publication_revision
	var held_collision: Dictionary = lab._region_collision.duplicate(true)
	var held_stats: Dictionary = lab._region_stats.duplicate(true)
	var held_nodes: Array = lab.mesh_root.get_children().map(func(node: Node) -> int: return node.get_instance_id())
	var held_meshes: Array = lab.mesh_root.get_children().map(func(node: Node) -> int: return (node as MeshInstance3D).mesh.get_instance_id())
	# Rendered evidence while the pair is retained: summary only, never source arrays.
	await lab._capture_current("paired-retained")
	if not _check(_validate_capture_summary_only(lab, "paired-retained"), "paired capture summary only"):
		return
	if not _check(lab._publication_revision == roads_revision, "capture must not advance revision"):
		return
	if not _check(_deep_equal(lab._region_collision, held_collision), "capture must not mutate COL payload"):
		return
	# Failed bridge candidate must preserve old nodes, COL, and revision.
	if not _check(not lab._load_region(SF_NAN_CENTER_SA), "SF NaN must reject"):
		return
	if not _check(not lab._shutdown_started and lab._last_region_error.error_code == "nonfinite_uv", "live classified NaN rejection"):
		return
	if not _check(lab._publication_revision == roads_revision and lab._loaded_center_sa == ROADS_CENTER_SA, "rejection retains revision and center"):
		return
	if not _check(lab._region_stats.size() == held_stats.size() and _deep_equal(lab._region_stats, held_stats), "rejection retains stats"):
		return
	if not _check(_deep_equal(lab._region_collision, held_collision), "rejection retains COL deep-equal"):
		return
	if not _check(lab.mesh_root.get_children().map(func(node: Node) -> int: return node.get_instance_id()) == held_nodes, "rejection retains node identities"):
		return
	var retained_mesh_ids: Array = lab.mesh_root.get_children().map(func(node: Node) -> int: return (node as MeshInstance3D).mesh.get_instance_id())
	if not _check(retained_mesh_ids == held_meshes, "rejection retains mesh resources"):
		return
	if not _validate_pair(lab, "retained pair after NaN"):
		return
	# P0 suppression: repeated near-center attempts must not reload.
	var load_count: int = lab._load_count
	for _attempt in range(3):
		lab.camera.position = Vector3(SF_NAN_CENTER_SA.x, SF_NAN_CENTER_SA.z, -SF_NAN_CENTER_SA.y)
		lab._maybe_reload_region()
	if not _check(lab._load_count == load_count, "rejected center retry suppression"):
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
	if not _check(not lab._has_pending_region() and lab._async_submit_count == async_count + 1 and lab._load_count == load_count and lab._publication_revision == roads_revision, "explicit async F6 without publication"):
		return
	if not _check(_deep_equal(lab._region_collision, held_collision), "F6 retains COL deep-equal"):
		return
	# Recovery at the next revision still carries the pair; held copy stays readable.
	lab.camera.position = Vector3(ROADS_CENTER_SA.x, ROADS_CENTER_SA.z + 20.0, -ROADS_CENTER_SA.y + 20.0)
	lab._camera_target_world = Vector3(ROADS_CENTER_SA.x, ROADS_CENTER_SA.z, -ROADS_CENTER_SA.y)
	lab.camera.look_at(lab._camera_target_world)
	if not _check(lab._load_region(ROADS_CENTER_SA), "recovery after rejection"):
		return
	if not _check(lab._publication_revision == roads_revision + 1, "recovery commits next revision"):
		return
	if not _validate_pair(lab, "recovered pair"):
		return
	if not _check(_deep_equal(held_collision, held_collision.duplicate(true)), "held payload self-consistent"):
		return
	if not _check(int(held_collision.col.faces) == 122, "held payload still readable after recovery"):
		return
	var recovered_revision: int = lab._publication_revision
	# Move far to Grove: bounded pair absent, current payload cleared, held still readable.
	lab.camera.position = Vector3(GROVE_CENTER_SA.x, GROVE_CENTER_SA.z + 20.0, -GROVE_CENTER_SA.y + 20.0)
	lab._camera_target_world = Vector3(GROVE_CENTER_SA.x, GROVE_CENTER_SA.z, -GROVE_CENTER_SA.y)
	lab.camera.look_at(lab._camera_target_world)
	if not _check(lab._load_region(GROVE_CENTER_SA), "far Grove replacement clears pair"):
		return
	if not _check(lab._publication_revision == recovered_revision + 1, "far move commits next revision"):
		return
	if not _check(lab._region_collision.is_empty(), "far Grove has empty COL dict"):
		return
	if not _check(_no_parent_alternate(lab), "far Grove has no 4043 alternate"):
		return
	if not _check(int(held_collision.col.faces) == 122 and int(held_collision.child.model_id) == 3991, "held old payload readable after far move"):
		return
	# Explicit release clears the current payload.
	var pre_release_revision: int = lab._publication_revision
	lab._release_region()
	if not _check(lab._region_collision.is_empty(), "release clears COL payload"):
		return
	if not _check(lab.mesh_root.get_children().is_empty(), "release clears nodes"):
		return
	if not _check(lab._publication_revision == pre_release_revision, "release preserves revision sequence"):
		return
	if not _check(int(held_collision.col.faces) == 122, "held payload readable across release"):
		return
	# Re-publish Grove after release; bridge sequence keeps advancing, never resets.
	lab.camera.position = Vector3(GROVE_CENTER_SA.x, GROVE_CENTER_SA.z + 20.0, -GROVE_CENTER_SA.y + 20.0)
	lab._camera_target_world = Vector3(GROVE_CENTER_SA.x, GROVE_CENTER_SA.z, -GROVE_CENTER_SA.y)
	lab.camera.look_at(lab._camera_target_world)
	if not _check(lab._load_region(GROVE_CENTER_SA), "recovery after release"):
		return
	if not _check(lab._publication_revision == pre_release_revision + 1, "post-release success advances revision"):
		return
	if not _check(lab._region_collision.is_empty(), "post-release Grove still empty"):
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
	if not _check(int(held_collision.col.faces) == 122, "held payload readable across teardown"):
		return
	print("region-chain-ok roads_rev=%d recovered_rev=%d grove_empty_ok held_faces=122" % [roads_revision, recovered_revision])
	quit(0)


func _validate_pair(lab: Node, label: String) -> bool:
	if not _check(not lab._region_collision.is_empty(), label + " has COL payload"):
		return false
	var lineage: Dictionary = lab._region_collision
	if not _check(int(lineage.get("generation", -1)) == lab._publication_revision, label + " generation matches revision"):
		return false
	if not _check(str(lineage.get("scope", "")) == "single-chain-data-not-gameplay", label + " scope"):
		return false
	if not _check(str(lineage.get("link", "")) == "bound", label + " link"):
		return false
	if not _check(bool(lineage.get("collision_transferred", false)), label + " transferred"):
		return false
	var child: Dictionary = lineage.get("child", {})
	var parent: Dictionary = lineage.get("parent", {})
	var col: Dictionary = lineage.get("col", {})
	if not _check(int(child.get("model_id", -1)) == 3991, label + " child 3991"):
		return false
	if not _check(str(child.get("model", "")).to_lower() == "gsfreeway7_lan", label + " child name"):
		return false
	if not _check(int(parent.get("model_id", -1)) == 4043, label + " parent 4043"):
		return false
	if not _check(str(parent.get("model", "")).to_lower() == "lodgsfreeway7_lan", label + " parent name"):
		return false
	if not _check(bool(child.get("uses_collision", false)) and not bool(parent.get("uses_collision", true)), label + " use flags"):
		return false
	if not _check(str(parent.get("effective_alias", "")) == "child", label + " alias"):
		return false
	if not _check(int(col.get("header_id", -1)) == 3991, label + " header 3991"):
		return false
	if not _check(int(col.get("faces", -1)) == 122, label + " COL 122 faces"):
		return false
	if not _check(str(col.get("status", "")) == "ready", label + " COL ready"):
		return false
	var face_surfaces: PackedByteArray = col.get("face_surfaces", PackedByteArray())
	if not _check(face_surfaces.size() == 488, label + " surface 488 bytes"):
		return false
	var face_indices: PackedInt32Array = col.get("face_indices", PackedInt32Array())
	var vertex_count := int(col.get("vertex_count", 0))
	if not _check(face_indices.size() == 122 * 3, label + " index count"):
		return false
	for index_value in face_indices:
		if index_value < 0 or index_value >= vertex_count:
			printerr("region-chain-fail: ", label + " index bounded")
			quit(1)
			return false
	var child_index := int(child.get("mesh_index", -1))
	var parent_index := int(parent.get("mesh_index", -1))
	var nodes: Array = lab.mesh_root.get_children()
	if not _check(child_index >= 0 and child_index < nodes.size(), label + " child index bounded"):
		return false
	if not _check(parent_index >= 0 and parent_index < nodes.size(), label + " parent index bounded"):
		return false
	if not _check(child_index != parent_index, label + " distinct pair slots"):
		return false
	if not _check(lab._resident_meshes <= lab._cap and lab._resident_meshes == nodes.size(), label + " cap held"):
		return false
	for node in nodes:
		if not (node is MeshInstance3D):
			printerr("region-chain-fail: ", label + " node is MeshInstance3D")
			quit(1)
			return false
		var instance := node as MeshInstance3D
		if instance.mesh == null or instance.mesh.get_surface_count() == 0:
			printerr("region-chain-fail: ", label + " nonempty DFF resource")
			quit(1)
			return false
	var child_node := nodes[child_index] as MeshInstance3D
	var parent_node := nodes[parent_index] as MeshInstance3D
	if not _check(int(child_node.get_meta("source_model_id", -1)) == 3991, label + " child source ID"):
		return false
	if not _check(int(parent_node.get_meta("source_model_id", -1)) == 4043, label + " parent source ID"):
		return false
	if not _check(bool(child_node.get_meta("lod_chain_alternate", true)) == false, label + " child lod flag false"):
		return false
	if not _check(bool(parent_node.get_meta("lod_chain_alternate", false)) == true, label + " parent lod flag true"):
		return false
	if not _check(child_node.visible, label + " child visible"):
		return false
	if not _check(not parent_node.visible, label + " parent hidden prepared"):
		return false
	return true


func _no_parent_alternate(lab: Node) -> bool:
	for node in lab.mesh_root.get_children():
		if bool(node.get_meta("lod_chain_alternate", false)):
			return false
		if int(node.get_meta("source_model_id", -1)) == 4043:
			return false
	return true


func _validate_capture_summary_only(lab: Node, capture_id: String) -> bool:
	var path: String = lab._capture_dir.path_join("%s-%s.manifest.json" % [lab._profile_id(), capture_id])
	if not FileAccess.file_exists(path):
		printerr("region-chain-fail: paired manifest missing: ", path)
		quit(1)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("region-chain-fail: cannot read paired manifest")
		quit(1)
		return false
	var text := file.get_as_text()
	file.close()
	if text.contains("face_indices") or text.contains("face_surfaces") or text.contains("PackedFloat32Array"):
		printerr("region-chain-fail: paired manifest must not dump COL arrays")
		quit(1)
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		printerr("region-chain-fail: paired manifest is not JSON")
		quit(1)
		return false
	var paired: Variant = parsed.get("region_publication", {}).get("paired_data", {})
	if not paired is Dictionary or not bool(paired.get("present", false)):
		printerr("region-chain-fail: paired manifest missing summary")
		quit(1)
		return false
	if int(paired.get("faces", -1)) != 122 or int(paired.get("child_model_id", -1)) != 3991:
		printerr("region-chain-fail: paired manifest summary mismatch")
		quit(1)
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
	var result := {"ok": false, "error": "", "game_dir": "", "capture_dir": "", "expect_open": false, "expect_region": false, "synthetic_baseline": false}
	var i := 0
	while i < args.size():
		var arg := String(args[i])
		if arg == "--expect-open-reject":
			result.expect_open = true
		elif arg == "--expect-region-reject":
			result.expect_region = true
		elif arg == "--synthetic-baseline":
			result.synthetic_baseline = true
		elif arg == "--route":
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
			result.error = "unknown region chain option: %s" % arg
			return result
		i += 1
	if not result.game_dir.is_empty() and not DirAccess.dir_exists_absolute(result.game_dir):
		result.error = "game directory does not exist: %s" % result.game_dir
		return result
	if not result.game_dir.is_empty() and not result.capture_dir.is_empty():
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
		printerr("region-chain-fail: ", label)
		quit(1)
	return condition
