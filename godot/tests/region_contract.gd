extends SceneTree

const GROVE_CENTER_SA := Vector3(2490.0, -1665.0, 14.0)
const ROADS_CENTER_SA := Vector3(1532.054688, -1662.289063, 12.460938)
const LARGE_SOURCE_U := 27062702.0
const NAN_CASES := [
	{
		"label": "SF radar",
		"center": Vector3(-1687.414063, -623.023438, 18.148438),
		"models": [&"ap_smallradar1_sfse"],
	},
	{
		"label": "LV radar",
		"center": Vector3(1292.039063, 1502.687500, 14.710938),
		"models": [&"smallradar02_lvs"],
	},
	{
		"label": "countryside bridge",
		"center": Vector3(2766.757813, 364.953125, -4.492188),
		"models": [&"cunterb01", &"cunterb03"],
	},
]

var _bridge: Object
var _bridge_open := false


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
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
	for method in [&"open_game", &"load_region", &"close_game"]:
		if not _bridge.has_method(method):
			_fail("SALegacyBridge is missing method %s" % method, 3)
			return

	if not _open_game(options.game_dir):
		return
	var grove: Variant = _bridge.call("load_region", GROVE_CENTER_SA)
	if not _validate_region(grove, "initial Grove"):
		return
	var grove_revision := int(grove.publication_revision)
	var grove_identities := _mesh_identities(grove.meshes)
	if grove_identities.is_empty():
		_fail("initial Grove has no source model identities", 4)
		return

	var roads: Variant = _bridge.call("load_region", ROADS_CENTER_SA)
	if not _validate_region(roads, "roads14_lan"):
		return
	var roads_revision := int(roads.publication_revision)
	if not _validate_unbound_bus_material(roads.meshes):
		return
	if roads_revision != grove_revision + 1:
		_fail("roads success did not increment publication_revision exactly once", 4)
		return
	var roads_probe := _find_large_roads_uv(roads.meshes)
	if not roads_probe.ok:
		_fail(roads_probe.error, 4)
		return
	var retained_meshes: Array = roads.meshes
	var retained_ids := _mesh_instance_ids(retained_meshes)
	var retained_large_count := int(roads_probe.large_count)

	for nan_case in NAN_CASES:
		var rejected: Variant = _bridge.call("load_region", nan_case.center)
		if not _validate_nonfinite_rejection(rejected, nan_case, roads_revision):
			return
		if not _validate_retained_meshes(retained_meshes, retained_ids, retained_large_count):
			return

	var grove_after_failure: Variant = _bridge.call("load_region", GROVE_CENTER_SA)
	if not _validate_region(grove_after_failure, "Grove after rejected replacements"):
		return
	if int(grove_after_failure.publication_revision) != roads_revision + 1:
		_fail("failed replacements changed the next successful publication revision", 4)
		return
	if not _validate_retained_meshes(retained_meshes, retained_ids, retained_large_count):
		return

	_close_bridge()
	if not _open_game(options.game_dir):
		return
	var reopened_grove: Variant = _bridge.call("load_region", GROVE_CENTER_SA)
	if not _validate_region(reopened_grove, "Grove after close/reopen"):
		return
	var reopened_identities := _mesh_identities(reopened_grove.meshes)
	if reopened_identities != grove_identities:
		_fail("source model identities changed across close/reopen", 4)
		return
	# publication_revision is a bridge publication sequence, not a globally unique identity.
	_close_bridge()
	print(
		"region-contract-ok grove_revision=%d roads_revision=%d retained_meshes=%d large_u_count=%d nan_cases=%d"
		% [grove_revision, roads_revision, retained_meshes.size(), retained_large_count, NAN_CASES.size()]
	)
	quit(0)


func _validate_unbound_bus_material(meshes: Array) -> bool:
	for info in meshes:
		if String(info.source_model).to_lower() != "bussign1":
			continue
		var counts := {0: 0, 1: 0, 2: 0, 3: 0}
		var source_colour_seen := false
		for i in range(info.mesh.get_surface_count()):
			var material: Dictionary = info.surface_materials[i]
			var slot: int = material.source_material_slot
			var arrays: Array = info.mesh.surface_get_arrays(i)
			if not counts.has(slot) or ((material.texture == null) != (slot == 0)):
				_fail("bussign1 source-null versus real texture binding changed", 4)
				return false
			counts[slot] += arrays[Mesh.ARRAY_VERTEX].size() / 3
			if slot == 0:
				for color in arrays[Mesh.ARRAY_COLOR]:
					if color.r > 0.1 and color.r < 0.5:
						source_colour_seen = true
		if counts != {0: 8, 1: 4, 2: 4, 3: 4} or not source_colour_seen:
			_fail("bussign1 lost authored triangles or prelight", 4)
			return false
		return true
	_fail("roads route did not exercise bussign1 source-null material", 4)
	return false


func _open_game(game_dir: String) -> bool:
	var opened: Variant = _bridge.call("open_game", game_dir, 350.0, 256)
	if not _result_ok(opened):
		_fail("open_game failed: %s" % _result_error(opened), 4)
		return false
	_bridge_open = true
	return true


func _validate_region(result: Variant, label: String) -> bool:
	if not _result_ok(result):
		_fail("%s load failed: %s" % [label, _result_error(result)], 4)
		return false
	if not result.get("publication_revision") is int or int(result.publication_revision) < 0:
		_fail("%s has no valid publication_revision" % label, 4)
		return false
	if not result.get("meshes") is Array or result.meshes.is_empty():
		_fail("%s has no published real meshes" % label, 4)
		return false
	if not result.get("stats") is Dictionary:
		_fail("%s has no stats Dictionary" % label, 4)
		return false
	for mesh_index in range(result.meshes.size()):
		var mesh_info: Variant = result.meshes[mesh_index]
		if not mesh_info is Dictionary:
			_fail("%s mesh %d metadata is not a Dictionary" % [label, mesh_index], 4)
			return false
		if not mesh_info.get("source_model") is String or String(mesh_info.source_model).is_empty():
			_fail("%s mesh %d has no source_model identity" % [label, mesh_index], 4)
			return false
		if not mesh_info.get("source_model_id") is int or int(mesh_info.source_model_id) < 0:
			_fail("%s mesh %d has no source_model_id identity" % [label, mesh_index], 4)
			return false
		if not mesh_info.get("mesh") is ArrayMesh:
			_fail("%s mesh %d is not an ArrayMesh" % [label, mesh_index], 4)
			return false
		var mesh: ArrayMesh = mesh_info.mesh
		if mesh.get_surface_count() <= 0:
			_fail("%s mesh %d has no surfaces" % [label, mesh_index], 4)
			return false
		if not mesh_info.get("surface_materials") is Array:
			_fail("%s mesh %d has invalid surface_materials" % [label, mesh_index], 4)
			return false
		var surface_materials: Array = mesh_info.surface_materials
		if surface_materials.size() != mesh.get_surface_count():
			_fail("%s mesh %d surface metadata count mismatch" % [label, mesh_index], 4)
			return false
		for surface_index in range(mesh.get_surface_count()):
			var surface_info: Variant = surface_materials[surface_index]
			if not surface_info is Dictionary:
				_fail("%s mesh %d surface %d metadata is invalid" % [label, mesh_index, surface_index], 4)
				return false
			if not surface_info.get("source_material_slot") is int or int(surface_info.source_material_slot) < 0:
				_fail("%s mesh %d surface %d lost source material identity" % [label, mesh_index, surface_index], 4)
				return false
			if surface_info.has("source_geometry") and (
				not surface_info.source_geometry is int or int(surface_info.source_geometry) < 0
			):
				_fail("%s mesh %d surface %d has invalid source_geometry" % [label, mesh_index, surface_index], 4)
				return false
			if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
				_fail("%s mesh %d surface %d is not triangles" % [label, mesh_index, surface_index], 4)
				return false
			var arrays := mesh.surface_get_arrays(surface_index)
			if not _validate_surface_arrays(arrays, label, mesh_index, surface_index):
				return false
	return true


func _validate_surface_arrays(arrays: Array, label: String, mesh_index: int, surface_index: int) -> bool:
	if arrays.size() != Mesh.ARRAY_MAX:
		_fail("%s mesh %d surface %d has malformed arrays" % [label, mesh_index, surface_index], 4)
		return false
	var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
	var normals: Variant = arrays[Mesh.ARRAY_NORMAL]
	var colors: Variant = arrays[Mesh.ARRAY_COLOR]
	var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
	var night: Variant = arrays[Mesh.ARRAY_CUSTOM0]
	if not vertices is PackedVector3Array or vertices.is_empty() or vertices.size() % 3 != 0:
		_fail("%s mesh %d surface %d has invalid vertices" % [label, mesh_index, surface_index], 4)
		return false
	var vertex_count: int = vertices.size()
	if not normals is PackedVector3Array or normals.size() != vertex_count:
		_fail("%s mesh %d surface %d has invalid normals" % [label, mesh_index, surface_index], 4)
		return false
	if not colors is PackedColorArray or colors.size() != vertex_count:
		_fail("%s mesh %d surface %d has invalid day colors" % [label, mesh_index, surface_index], 4)
		return false
	if not uvs is PackedVector2Array or uvs.size() != vertex_count:
		_fail("%s mesh %d surface %d has invalid UVs" % [label, mesh_index, surface_index], 4)
		return false
	if not night is PackedFloat32Array or night.size() != vertex_count * 4:
		_fail("%s mesh %d surface %d has invalid night colors" % [label, mesh_index, surface_index], 4)
		return false
	for vertex in vertices:
		if not is_finite(vertex.x) or not is_finite(vertex.y) or not is_finite(vertex.z):
			_fail("%s mesh %d surface %d has nonfinite published position" % [label, mesh_index, surface_index], 4)
			return false
	for uv in uvs:
		if not is_finite(uv.x) or not is_finite(uv.y):
			_fail("%s mesh %d surface %d has nonfinite published UV" % [label, mesh_index, surface_index], 4)
			return false
	return true


func _find_large_roads_uv(meshes: Array) -> Dictionary:
	var roads_found := false
	var large_count := 0
	for mesh_info in meshes:
		if String(mesh_info.source_model).to_lower() != "roads14_lan":
			continue
		roads_found = true
		var mesh: ArrayMesh = mesh_info.mesh
		for surface_index in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface_index)
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			for uv in uvs:
				if uv.x == LARGE_SOURCE_U:
					large_count += 1
	if not roads_found:
		return {"ok": false, "error": "roads region has no source_model roads14_lan ArrayMesh"}
	if large_count <= 0:
		return {
			"ok": false,
			"error": "roads14_lan did not retain exact finite U=27062702 (clamped, rebased, or absent)",
		}
	return {"ok": true, "large_count": large_count}


func _validate_nonfinite_rejection(result: Variant, nan_case: Dictionary, prior_revision: int) -> bool:
	var label := String(nan_case.label)
	if not result is Dictionary:
		_fail("%s rejection is not a Dictionary" % label, 4)
		return false
	if bool(result.get("ok", true)):
		_fail("%s unexpectedly published source NaN data" % label, 4)
		return false
	if result.get("error_code") != "nonfinite_uv":
		_fail("%s did not return error_code=nonfinite_uv" % label, 4)
		return false
	if not result.get("publication_revision") is int or int(result.publication_revision) != prior_revision:
		_fail("%s rejection changed publication_revision" % label, 4)
		return false
	if not result.get("error_context") is Dictionary:
		_fail("%s has no structured error_context" % label, 4)
		return false
	var context: Dictionary = result.error_context
	for key in [
		&"archive", &"model", &"model_id", &"txd", &"placement_id", &"geometry",
		&"triangle", &"material_slot", &"uv_component", &"value",
	]:
		if not context.has(key):
			_fail("%s error_context is missing %s" % [label, key], 4)
			return false
	for key in [&"archive", &"model", &"txd"]:
		if not context[key] is String or String(context[key]).is_empty():
			_fail("%s error_context has invalid %s identity" % [label, key], 4)
			return false
	if StringName(String(context.model).to_lower()) not in nan_case.models:
		_fail("%s identified unexpected source model %s" % [label, context.model], 4)
		return false
	for key in [&"model_id", &"placement_id", &"geometry", &"triangle", &"material_slot"]:
		if not context[key] is int or int(context[key]) < 0:
			_fail("%s error_context has invalid %s" % [label, key], 4)
			return false
	var component: Variant = context.uv_component
	var valid_component := (
		(component is int and int(component) in [0, 1])
		or ((component is String or component is StringName) and String(component).to_lower() in ["u", "v"])
	)
	if not valid_component:
		_fail("%s error_context has invalid uv_component" % label, 4)
		return false
	if not context.value is String or context.value != "nan":
		_fail("%s error_context must classify this corpus UV as nan" % label, 4)
		return false
	return true


func _validate_retained_meshes(
	meshes: Array,
	instance_ids: PackedInt64Array,
	expected_large_count: int,
) -> bool:
	if meshes.size() != instance_ids.size():
		_fail("previously returned roads mesh list changed after replacement attempt", 4)
		return false
	for index in range(meshes.size()):
		var mesh_info: Variant = meshes[index]
		if not mesh_info is Dictionary or not mesh_info.get("mesh") is ArrayMesh:
			_fail("previously returned roads mesh %d is no longer readable" % index, 4)
			return false
		var mesh: ArrayMesh = mesh_info.mesh
		if not is_instance_valid(mesh) or mesh.get_instance_id() != instance_ids[index]:
			_fail("previously returned roads mesh %d changed identity" % index, 4)
			return false
		if mesh.get_surface_count() <= 0:
			_fail("previously returned roads mesh %d lost its surfaces" % index, 4)
			return false
	var roads_probe := _find_large_roads_uv(meshes)
	if not roads_probe.ok or int(roads_probe.get("large_count", -1)) != expected_large_count:
		_fail("previously returned roads UV data changed after replacement attempt", 4)
		return false
	return true


func _mesh_instance_ids(meshes: Array) -> PackedInt64Array:
	var ids := PackedInt64Array()
	for mesh_info in meshes:
		var mesh: ArrayMesh = mesh_info.mesh
		ids.append(mesh.get_instance_id())
	return ids


func _mesh_identities(meshes: Array) -> Dictionary:
	var identities := {}
	for mesh_info in meshes:
		var key := "%s#%d" % [mesh_info.source_model, int(mesh_info.source_model_id)]
		identities[key] = true
	return identities


func _parse_options(args: PackedStringArray) -> Dictionary:
	var game_dir := "/game"
	var i := 0
	while i < args.size():
		if args[i] != "--game-dir":
			return {"ok": false, "error": "unknown region contract option: %s" % args[i]}
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
	printerr("region-contract-fail: %s" % message)
	quit(code)


func _close_bridge() -> void:
	if _bridge_open and _bridge != null:
		_bridge.call("close_game")
	_bridge_open = false
