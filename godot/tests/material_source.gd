extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var game := ""
	for i in args.size():
		if args[i] == "--game-dir": game = args[i + 1]
	if game.is_empty():
		push_error("usage: --game-dir PATH")
		quit(2)
		return
	if not GDExtensionManager.is_extension_loaded("res://sa_legacy.gdextension"):
		assert(GDExtensionManager.load_extension("res://sa_legacy.gdextension") == GDExtensionManager.LOAD_STATUS_OK)
	var bridge = ClassDB.instantiate("SALegacyBridge")
	var opened: Dictionary = bridge.open_game(game, 140.0, 16, 64, true)
	assert(opened.ok)
	var packet: Dictionary = bridge.diagnostic_actors(1.0, true)
	assert(packet.ok)
	var env_triangles := 0
	var alpha_triangles := 0
	var env_names := {}
	for mesh: Dictionary in packet.meshes:
		assert(mesh.matfx_types.size() == mesh.triangles)
		assert(mesh.env_images.size() == mesh.triangles)
		assert(mesh.env_coefficients.size() == mesh.triangles)
		for triangle in mesh.triangles:
			if mesh.matfx_types[triangle] == 2 and mesh.env_coefficients[triangle] > 0.0:
				env_triangles += 1
				var env_image: int = mesh.env_images[triangle]
				assert(env_image >= 0 and env_image < packet.images.size())
				env_names[String(packet.images[env_image].name).to_lower()] = true
			if mesh.vehicle_alpha[triangle] != 0:
				alpha_triangles += 1
	assert(env_triangles > 0 and alpha_triangles > 0)
	assert(env_names.has("xvehicleenv128"))
	for image: Dictionary in packet.images:
		assert(int(image.mipmaps) >= 1)
	bridge.close_game()
	print("material-source-godot-ok env-triangles=", env_triangles,
		" alpha-triangles=", alpha_triangles, " env=xvehicleenv128 mip-chain=owned families=", env_names.size())
	quit(0)
