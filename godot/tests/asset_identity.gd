extends SceneTree

const GROVE_CENTER_SA := Vector3(2490.0, -1665.0, 14.0)
const ROADS_CENTER_SA := Vector3(1532.054688, -1662.289063, 12.460938)

var _bridge: Object
var _bridge_open := false
var _publication_texture_ids := {}
var _texture_payloads := {}
var _publication_decoded_instances := {}
var _publication_textures_by_name := {}
var _model_keys := {}
var _geometry_keys := {}
var _material_keys := {}
var _texture_keys := {}
var _mesh_count := 0
var _surface_count := 0
var _texture_reference_count := 0
var _source_null_count := 0
var _shared_identity_reference_count := 0
var _decoded_instance_count := 0
var _same_name_identity_pairs := 0
var _same_name_source_pairs := 0
var _planta_models := {}


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

	print("asset-identity-start probes=2 radius=%s cap=%d" % [options.radius, options.cap])
	var opened: Variant = _bridge.call("open_game", options.game_dir, options.radius, options.cap)
	if not _result_ok(opened):
		_fail("open_game failed: %s" % _result_error(opened), 4)
		return
	_bridge_open = true

	for probe in [
		{"label": "Grove", "center": GROVE_CENTER_SA},
		{"label": "roads", "center": ROADS_CENTER_SA},
	]:
		var region: Variant = _bridge.call("load_region", probe.center)
		if not _result_ok(region):
			_fail(
				"unexpected %s candidate failure: %s" % [probe.label, _result_error(region)],
				4,
			)
			return
		_publication_texture_ids = {}
		_publication_textures_by_name = {}
		_publication_decoded_instances = {}
		if not _validate_publication(region, String(probe.label)):
			return

	if _same_name_source_pairs <= 0:
		_finding(
			(
				"actual Grove/roads regions contain no same-name textures with differing TXD lineage/owner; "
				+ "same_name_identity_pairs=%d (parent must select a source-backed fixture)"
			)
			% _same_name_identity_pairs
		)
		return

	if _planta_models.size() != 2:
		_fail("source planta256 fixture requires models646 and4172 (radius120/cap1200)", 4)
		return
	_close_bridge()
	print(
		(
			"asset-identity-ok publications=2 meshes=%d surfaces=%d model_keys=%d geometry_keys=%d "
			+ "material_keys=%d texture_keys=%d texture_refs=%d shared_refs=%d source_null=%d "
			+ "decoded_keys=%d decoded_instances=%d same_name_identity_pairs=%d same_name_source_pairs=%d"
		)
		% [
			_mesh_count,
			_surface_count,
			_model_keys.size(),
			_geometry_keys.size(),
			_material_keys.size(),
			_texture_keys.size(),
			_texture_reference_count,
			_shared_identity_reference_count,
			_source_null_count,
			_texture_payloads.size(),
			_decoded_instance_count,
			_same_name_identity_pairs,
			_same_name_source_pairs,
		]
	)
	quit(0)


func _validate_publication(value: Variant, label: String) -> bool:
	if not value is Dictionary:
		_fail("%s publication is not a Dictionary" % label, 4)
		return false
	var result: Dictionary = value
	if not result.get("publication_revision") is int or int(result.publication_revision) < 0:
		_fail("%s publication has no valid publication_revision" % label, 4)
		return false
	if not result.get("meshes") is Array or result.meshes.is_empty():
		_fail("%s publication has no real meshes" % label, 4)
		return false
	for mesh_index in range(result.meshes.size()):
		if not _validate_mesh(result.meshes[mesh_index], label, mesh_index):
			return false
	return true


func _validate_mesh(value: Variant, publication: String, mesh_index: int) -> bool:
	var label := "%s mesh %d" % [publication, mesh_index]
	if not value is Dictionary:
		_fail("%s metadata is not a Dictionary" % label, 4)
		return false
	var mesh_info: Dictionary = value
	if not mesh_info.get("source_model") is String or String(mesh_info.source_model).is_empty():
		_fail("%s has no source_model provenance" % label, 4)
		return false
	if not mesh_info.get("source_model_id") is int or int(mesh_info.source_model_id) < 0:
		_fail("%s has no source_model_id provenance" % label, 4)
		return false
	if not mesh_info.get("source_archive") is String or String(mesh_info.source_archive).is_empty():
		_fail("%s has no source_archive provenance" % label, 4)
		return false
	if not mesh_info.get("source_txd") is String or String(mesh_info.source_txd).is_empty():
		_fail("%s has no source_txd provenance" % label, 4)
		return false

	if not mesh_info.get("mesh") is ArrayMesh:
		_fail("%s has no ArrayMesh" % label, 4)
		return false
	var mesh: ArrayMesh = mesh_info.mesh
	if mesh.get_surface_count() <= 0:
		_fail("%s has no surfaces" % label, 4)
		return false
	if not mesh_info.get("surface_materials") is Array:
		_fail("%s has invalid surface_materials" % label, 4)
		return false
	var materials: Array = mesh_info.surface_materials
	if materials.size() != mesh.get_surface_count():
		_fail("%s surface material count disagrees with ArrayMesh" % label, 4)
		return false

	_mesh_count += 1
	for surface_index in range(materials.size()):
		if not _validate_surface(
			materials[surface_index],
			label,
			surface_index,
			String(mesh_info.source_model),
			int(mesh_info.source_model_id),
			String(mesh_info.source_archive),
			String(mesh_info.source_txd),
		):
			return false
	return true


func _validate_surface(
	value: Variant,
	mesh_label: String,
	surface_index: int,
	source_model: String,
	source_model_id: int,
	source_archive: String,
	source_txd: String,
) -> bool:
	var label := "%s surface %d" % [mesh_label, surface_index]
	if not value is Dictionary:
		_fail("%s metadata is not a Dictionary" % label, 4)
		return false
	var surface: Dictionary = value
	if not surface.get("source_model") is String or String(surface.source_model) != source_model:
		_fail("%s source_model disagrees with its mesh" % label, 4)
		return false
	if not surface.get("source_geometry") is int or int(surface.source_geometry) < 0:
		_fail("%s has no source_geometry provenance" % label, 4)
		return false
	if not surface.get("source_material_slot") is int or int(surface.source_material_slot) < 0:
		_fail("%s has no source_material_slot provenance" % label, 4)
		return false
	if not surface.get("filter") is int or int(surface.filter) < 0:
		_fail("%s has no authored non-negative integer filter" % label, 4)
		return false

	var model_result := _model_identity(surface.get("model_identity"), "%s model_identity" % label)
	if not model_result.ok:
		_fail(model_result.error, 4)
		return false
	if int(model_result.model_id) != source_model_id:
		_fail("%s model_identity model_id disagrees with source_model_id" % label, 4)
		return false
	if not _archive_matches(String(model_result.archive), source_archive):
		_fail("%s model_identity DFF archive disagrees with source_archive" % label, 4)
		return false
	if not _member_matches(String(model_result.member), source_model, ".dff"):
		_fail("%s model_identity DFF member disagrees with source_model" % label, 4)
		return false
	var model_key := String(model_result.key)

	var geometry_result := _geometry_identity(surface.get("geometry_identity"), "%s geometry_identity" % label)
	if not geometry_result.ok:
		_fail(geometry_result.error, 4)
		return false
	if String(geometry_result.model_key) != model_key:
		_fail("%s geometry_identity refers to a different model" % label, 4)
		return false
	if int(geometry_result.index) != int(surface.source_geometry):
		_fail("%s geometry_identity disagrees with source_geometry" % label, 4)
		return false
	var geometry_key := String(geometry_result.key)

	var material_result := _material_identity(surface.get("material_identity"), "%s material_identity" % label)
	if not material_result.ok:
		_fail(material_result.error, 4)
		return false
	if String(material_result.model_key) != model_key:
		_fail("%s material hierarchy refers to a different model" % label, 4)
		return false
	if String(material_result.geometry_key) != geometry_key:
		_fail("%s material_identity refers to a different geometry_identity" % label, 4)
		return false
	if int(material_result.slot) != int(surface.source_material_slot):
		_fail("%s material identity disagrees with source_material_slot" % label, 4)
		return false
	_model_keys[model_key] = true
	_geometry_keys[geometry_key] = true
	_material_keys[String(material_result.key)] = true
	_surface_count += 1

	var texture: Variant = surface.get("texture")
	var texture_identity: Variant = surface.get("texture_identity")
	if texture == null:
		if not texture_identity is Dictionary or not texture_identity.is_empty():
			_fail("%s source-null texture must publish an empty texture_identity Dictionary" % label, 4)
			return false
		_source_null_count += 1
		return true
	if not texture is Texture2D:
		_fail("%s texture is not a Texture2D" % label, 4)
		return false
	if not texture is ImageTexture:
		_fail("%s identity-bearing texture is not an ImageTexture" % label, 4)
		return false

	var texture_result := _texture_identity(texture_identity, "%s texture_identity" % label)
	if not texture_result.ok:
		_fail(texture_result.error, 4)
		return false
	if int(texture_result.filter) != int(surface.filter):
		_fail("%s texture_identity filter disagrees with surface filter" % label, 4)
		return false
	var source_txd_seen := false
	for member in texture_result.members:
		if _member_matches(String(member), source_txd, ".txd"):
			source_txd_seen = true
			break
	if not source_txd_seen:
		_fail("%s texture lineage does not contain the source_txd" % label, 4)
		return false

	_texture_reference_count += 1
	var key := String(texture_result.key)
	var texture_id: int = texture.get_instance_id()
	if _publication_texture_ids.has(key):
		_shared_identity_reference_count += 1
		if int(_publication_texture_ids[key]) != texture_id:
			_fail("%s same texture identity uses different ImageTexture instances within one publication" % label, 4)
			return false
	else:
		_publication_texture_ids[key] = texture_id
	_texture_keys[key] = true

	if not _record_texture_variant(texture_result, texture_id, label):
		return false
	var image_texture := texture as ImageTexture
	if String(texture_result.name).to_lower() == "planta256" and source_model_id in [646, 4172]:
		var expected_side := 128 if source_model_id == 646 else 256
		var expected_txd := "gta_potplants.txd" if source_model_id == 646 else "cityhall_tr_lan.txd"
		# DFF 0x11102 includes the separate mip-generation flag; RW stores
		# filterAddressing low16 (texture.cpp:416), unlike TXD's 0x1101.
		var expected_filter := 0x1102 if source_model_id == 646 else 0x1106
		if image_texture.get_width() != expected_side or image_texture.get_height() != expected_side or String(texture_identity.owner.member).to_lower() != expected_txd or int(surface.filter) != expected_filter:
			_fail("source planta256 model%d dimensions=%dx%d owner=%s filter=%x expected=%s/%x" % [source_model_id, image_texture.get_width(), image_texture.get_height(), texture_identity.owner.member, int(surface.filter), expected_txd, expected_filter], 4)
			return false
		_planta_models[source_model_id] = true
	if not _record_texture_payload(key, image_texture, texture_id, label):
		return false
	return true


func _record_texture_variant(identity: Dictionary, texture_id: int, label: String) -> bool:
	var name := String(identity.name)
	var variants: Dictionary = _publication_textures_by_name.get(name, {})
	for other_key in variants:
		if String(other_key) == String(identity.key):
			continue
		var other: Dictionary = variants[other_key]
		var other_ids: Dictionary = other.ids
		if other_ids.has(texture_id):
			_fail("%s same-name differing texture identities alias one ImageTexture" % label, 4)
			return false
	if variants.has(identity.key):
		var existing: Dictionary = variants[identity.key]
		var ids: Dictionary = existing.ids
		ids[texture_id] = true
		existing.ids = ids
		variants[identity.key] = existing
	else:
		for other_key in variants:
			var other: Dictionary = variants[other_key]
			_same_name_identity_pairs += 1
			if String(other.lineage_key) != String(identity.lineage_key) or String(other.owner_key) != String(identity.owner_key):
				_same_name_source_pairs += 1
		var ids := {}
		ids[texture_id] = true
		variants[identity.key] = {
			"lineage_key": identity.lineage_key,
			"owner_key": identity.owner_key,
			"filter": identity.filter,
			"ids": ids,
		}
	_publication_textures_by_name[name] = variants
	return true


func _record_texture_payload(key: String, texture: ImageTexture, texture_id: int, label: String) -> bool:
	var decoded_for_key: Dictionary = _publication_decoded_instances.get(key, {})
	if decoded_for_key.has(texture_id):
		return true
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_fail("%s ImageTexture.get_image returned no decoded pixel payload" % label, 4)
		return false
	var bytes := image.get_data()
	if bytes.is_empty():
		_fail("%s decoded ImageTexture pixel payload is empty" % label, 4)
		return false
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK or hashing.update(bytes) != OK:
		_fail("cannot hash decoded texture payload", 4)
		return false
	var digest := hashing.finish().hex_encode()
	var payload_key := "payload{%s%s%s%s%s}" % [
		_int_atom(image.get_width()),
		_int_atom(image.get_height()),
		_int_atom(image.get_format()),
		_int_atom(image.get_mipmap_count()),
		_string_atom(digest),
	]
	if _texture_payloads.has(key) and String(_texture_payloads[key]) != payload_key:
		_fail("%s same texture identity decoded to different pixel bytes" % label, 4)
		return false
	_texture_payloads[key] = payload_key
	decoded_for_key[texture_id] = true
	_publication_decoded_instances[key] = decoded_for_key
	_decoded_instance_count += 1
	return true


func _texture_identity(value: Variant, label: String) -> Dictionary:
	if not value is Dictionary or value.is_empty():
		return _identity_error("%s is not a non-empty Dictionary" % label)
	if not value.get("lineage") is Array or value.lineage.is_empty():
		return _identity_error("%s lineage is not a non-empty Array" % label)
	var lineage_keys := PackedStringArray()
	var members := PackedStringArray()
	var lineage_set := {}
	for index in range(value.lineage.size()):
		var reference := _archive_member(value.lineage[index], "%s lineage %d" % [label, index])
		if not reference.ok:
			return reference
		lineage_keys.append(reference.key)
		members.append(reference.member)
		lineage_set[reference.key] = true
	var owner := _archive_member(value.get("owner"), "%s owner" % label)
	if not owner.ok:
		return owner
	if not lineage_set.has(owner.key):
		return _identity_error("%s owner is not present in its ordered lineage" % label)
	if not value.get("name") is String or String(value.name).is_empty():
		return _identity_error("%s name is not a non-empty String" % label)
	if not value.get("filter") is int or int(value.filter) < 0:
		return _identity_error("%s filter is not a non-negative int" % label)
	var lineage_key := "lineage{%s%s}" % [_int_atom(lineage_keys.size()), "".join(lineage_keys)]
	var key := "texture{%s%s%s%s}" % [
		lineage_key,
		"owner{%s}" % owner.key,
		"name{%s}" % _string_atom(String(value.name)),
		"filter{%s}" % _int_atom(int(value.filter)),
	]
	return {
		"ok": true,
		"key": key,
		"lineage_key": lineage_key,
		"owner_key": owner.key,
		"name": value.name,
		"filter": value.filter,
		"members": members,
	}


func _material_identity(value: Variant, label: String) -> Dictionary:
	if not value is Dictionary:
		return _identity_error("%s is not a Dictionary" % label)
	var geometry := _geometry_identity(value.get("geometry"), "%s geometry" % label)
	if not geometry.ok:
		return geometry
	if not value.get("slot") is int or int(value.slot) < 0:
		return _identity_error("%s slot is not a non-negative int" % label)
	return {
		"ok": true,
		"key": "material{%s%s}" % [geometry.key, "slot{%s}" % _int_atom(int(value.slot))],
		"geometry_key": geometry.key,
		"geometry_index": geometry.index,
		"model_key": geometry.model_key,
		"slot": value.slot,
	}


func _geometry_identity(value: Variant, label: String) -> Dictionary:
	if not value is Dictionary:
		return _identity_error("%s is not a Dictionary" % label)
	var model := _model_identity(value.get("model"), "%s model" % label)
	if not model.ok:
		return model
	if not value.get("index") is int or int(value.index) < 0:
		return _identity_error("%s index is not a non-negative int" % label)
	return {
		"ok": true,
		"key": "geometry{%s%s}" % [model.key, "index{%s}" % _int_atom(int(value.index))],
		"model_key": model.key,
		"index": value.index,
	}


func _model_identity(value: Variant, label: String) -> Dictionary:
	if not value is Dictionary:
		return _identity_error("%s is not a Dictionary" % label)
	var dff := _archive_member(value.get("dff"), "%s dff" % label)
	if not dff.ok:
		return dff
	if not value.get("model_id") is int or int(value.model_id) < 0:
		return _identity_error("%s model_id is not a non-negative int" % label)
	return {
		"ok": true,
		"key": "model{%s%s}" % ["dff{%s}" % dff.key, "model_id{%s}" % _int_atom(int(value.model_id))],
		"archive": dff.archive,
		"member": dff.member,
		"model_id": value.model_id,
	}


func _archive_member(value: Variant, label: String) -> Dictionary:
	if not value is Dictionary:
		return _identity_error("%s is not a Dictionary" % label)
	if not value.get("archive") is String or String(value.archive).is_empty():
		return _identity_error("%s archive is not a non-empty String" % label)
	if not value.get("member") is String or String(value.member).is_empty():
		return _identity_error("%s member is not a non-empty String" % label)
	return {
		"ok": true,
		"key": "archive_member{%s%s}" % [
			_string_atom(String(value.archive)),
			_string_atom(String(value.member)),
		],
		"archive": value.archive,
		"member": value.member,
	}


func _identity_error(message: String) -> Dictionary:
	return {"ok": false, "error": message}


func _string_atom(value: String) -> String:
	return "s%d:%s" % [value.to_utf8_buffer().size(), value]


func _int_atom(value: int) -> String:
	return "i%d;" % value


func _archive_matches(identity_archive: String, source_archive: String) -> bool:
	return identity_archive.get_file().to_lower() == source_archive.get_file().to_lower()


func _member_matches(identity_member: String, source_name: String, extension: String) -> bool:
	var expected := source_name.get_file()
	if not expected.to_lower().ends_with(extension):
		expected += extension
	return identity_member.get_file().to_lower() == expected.to_lower()


func _parse_options(args: PackedStringArray) -> Dictionary:
	var result := {"ok": false, "error": "", "game_dir": "/game", "radius": 120.0, "cap": 1200}
	var index := 0
	while index < args.size():
		var option := args[index]
		if option not in ["--game-dir", "--radius", "--cap"]:
			result.error = "unknown asset identity option: %s" % option
			return result
		if index + 1 >= args.size() or args[index + 1].is_empty():
			result.error = "%s requires a value" % option
			return result
		var value := args[index + 1]
		match option:
			"--game-dir":
				result.game_dir = _absolute_path(value)
			"--radius":
				if not value.is_valid_float() or not is_finite(value.to_float()) or value.to_float() <= 0.0:
					result.error = "--radius must be a positive finite number"
					return result
				result.radius = value.to_float()
			"--cap":
				if not value.is_valid_int() or value.to_int() <= 0:
					result.error = "--cap must be positive"
					return result
				result.cap = value.to_int()
		index += 2
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


func _result_ok(result: Variant) -> bool:
	return result is Dictionary and bool(result.get("ok", false))


func _result_error(result: Variant) -> String:
	return str(result.get("error", "invalid result")) if result is Dictionary else "non-Dictionary result"


func _finding(message: String) -> void:
	_close_bridge()
	printerr("asset-identity-finding: %s" % message)
	quit(5)


func _fail(message: String, code: int) -> void:
	_close_bridge()
	printerr("asset-identity-fail: %s" % message)
	quit(code)


func _close_bridge() -> void:
	if _bridge_open and _bridge != null:
		_bridge.call("close_game")
	_bridge_open = false
