extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_dir := ""
	var require_real := false
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] == "--game-dir" and i + 1 < args.size():
			game_dir = args[i + 1]
			i += 2
		elif args[i] == "--require-real-audio":
			require_real = true
			i += 1
		else:
			_fail("unknown option %s" % args[i])
			return
	if game_dir.is_empty():
		_fail("--game-dir is required")
		return
	if not GDExtensionManager.is_extension_loaded("res://sa_legacy.gdextension"):
		if GDExtensionManager.load_extension("res://sa_legacy.gdextension") != GDExtensionManager.LOAD_STATUS_OK:
			_fail("cannot load extension")
			return
	if not ClassDB.class_exists("SALegacyAudio"):
		_fail("SALegacyAudio is not registered")
		return
	var owner = ClassDB.instantiate("SALegacyAudio")
	var loaded: Dictionary = owner.call("load", game_dir)
	if not bool(loaded.get("ok", false)) or not bool(loaded.get("loaded", false)):
		_fail("native audio load failed: %s" % str(loaded.get("error", "unknown")))
		return
	var assets: Array = loaded.get("assets", [])
	if assets.size() != 3:
		_fail("want three audio families")
		return
	var families := {}
	var lengths := {}
	for value in assets:
		var asset: Dictionary = value
		var family := str(asset.get("family", ""))
		var payload: PackedByteArray = asset.get("payload", PackedByteArray())
		if payload.is_empty():
			_fail("empty payload for %s" % family)
			return
		var stream: AudioStream
		if str(asset.get("encoding", "")) == "pcm16_mono":
			var wav := AudioStreamWAV.new()
			wav.format = AudioStreamWAV.FORMAT_16_BITS
			wav.mix_rate = int(asset.get("rate", 0))
			wav.stereo = false
			wav.data = payload
			stream = wav
		else:
			stream = AudioStreamOggVorbis.load_from_buffer(payload)
		if stream == null or stream.get_length() <= 0.0:
			_fail("invalid stream for %s" % family)
			return
		var player := AudioStreamPlayer.new()
		root.add_child(player)
		player.stream = stream
		player.play()
		await process_frame
		if not player.playing:
			_fail("Godot did not start %s" % family)
			return
		families[family] = true
		lengths[family] = stream.get_length()
		player.stop()
		player.queue_free()
	if not (families.has("sfx") and families.has("speech") and families.has("environment")):
		_fail("missing audio family")
		return
	var driver := AudioServer.get_driver_name()
	if require_real and driver.to_lower() == "dummy":
		_fail("target route requires a non-Dummy Godot audio driver")
		return
	owner = null
	await process_frame
	print("audio-families-godot-ok driver=%s sfx=%.3f speech=%.3f environment=%.3f structural=%d target=%d feedback=0" % [
		driver, float(lengths["sfx"]), float(lengths["speech"]), float(lengths["environment"]),
		1 if driver.to_lower() == "dummy" else 0, 1 if driver.to_lower() != "dummy" else 0])
	quit(0)


func _fail(message: String) -> void:
	printerr("audio-families-godot-fail: ", message)
	quit(1)
