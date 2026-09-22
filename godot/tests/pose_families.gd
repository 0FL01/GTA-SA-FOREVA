extends SceneTree

const PoseView = preload("res://pose_family_view.gd")

func _initialize() -> void:
    call_deferred("_run")


func _visible_pixels(image: Image) -> int:
    var background := image.get_pixel(0, 0)
    var count := 0
    for y in range(0, image.get_height(), 2):
        for x in range(0, image.get_width(), 2):
            var color := image.get_pixel(x, y)
            if maxf(absf(color.r - background.r), maxf(absf(color.g - background.g), absf(color.b - background.b))) > 0.05:
                count += 1
    return count


func _focus(camera: Camera3D, packet: Dictionary) -> void:
    var minimum := Vector3(INF, INF, INF)
    var maximum := Vector3(-INF, -INF, -INF)
    for mesh: Dictionary in packet.meshes:
        for point: Vector3 in mesh.positions:
            minimum = minimum.min(point)
            maximum = maximum.max(point)
    var center := (minimum + maximum) * 0.5
    var extent: float = maxf(1.0, (maximum - minimum).length())
    camera.position = center + Vector3(extent * 0.6, extent * 0.25, extent * 1.4)
    camera.look_at(center)


func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var game := ""
    var screenshot := ""
    for i in args.size():
        if args[i] == "--game-dir": game = args[i + 1]
        if args[i] == "--screenshot": screenshot = args[i + 1]
    if game.is_empty():
        push_error("usage: --game-dir PATH [--screenshot PNG]")
        quit(2)
        return
    if not GDExtensionManager.is_extension_loaded("res://sa_legacy.gdextension"):
        assert(GDExtensionManager.load_extension("res://sa_legacy.gdextension") == GDExtensionManager.LOAD_STATUS_OK)
    var owner = ClassDB.instantiate("SALegacyPose")
    var idle: Dictionary = owner.capture_ped(game, "andre", "IDLE_stance", 0.5)
    assert(idle.ok and idle.family == "ped" and idle.bones == 32 and idle.mapped == 32)
    var retained := idle.duplicate(true)
    var before: Vector3 = idle.meshes[0].positions[0]
    var mutated: PackedVector3Array = idle.meshes[0].positions
    mutated[0] += Vector3(100, 100, 100)
    idle.meshes[0].positions = mutated
    assert(owner.snapshot().meshes[0].positions[0] == before, "Godot mutation reached native pose owner")
    var packet: Dictionary = owner.capture_ped(game, "andre", "WALK_civi", 0.5)
    assert(packet.ok and packet.generation == 2 and packet.triangles > 0)
    var view := PoseView.new()
    root.add_child(view)
    view.configure(packet)
    var camera := Camera3D.new()
    root.add_child(camera)
    _focus(camera, packet)
    camera.current = true
    root.size = Vector2i(960, 640)
    await process_frame
    var jump: Dictionary = owner.capture_ped(game, "andre", "JUMP_glide", 0.5)
    assert(jump.ok and jump.mapped == 26 and jump.generation == 3)
    view.present(jump)
    _focus(camera, jump)
    await process_frame
    await RenderingServer.frame_post_draw
    var ped_pixels := _visible_pixels(root.get_texture().get_image())
    assert(ped_pixels > 500, "source ped pose render missing")
    view.queue_free()
    await process_frame
    var cutscene: Dictionary = owner.capture_cutscene(game, "cssmokevest", "smoke1a", "csplay", 0.5)
    assert(cutscene.ok and cutscene.family == "cutscene" and cutscene.bones == 61 and cutscene.mapped == 56)
    var cs_view := PoseView.new()
    root.add_child(cs_view)
    cs_view.configure(cutscene)
    _focus(camera, cutscene)
    await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    var cs_pixels := _visible_pixels(image)
    assert(cs_pixels > 500, "source cutscene pose render missing")
    if not screenshot.is_empty():
        assert(image.save_png(screenshot) == OK)
    var failed: Dictionary = owner.capture_ped(game, "andre", "missing", 0.5)
    assert(not failed.ok and owner.snapshot().generation == cutscene.generation)
    assert(retained.meshes[0].positions[0] == before)
    cs_view.queue_free()
    camera.queue_free()
    owner = null
    await process_frame
    print("pose-families-godot-ok ped-pixels=", ped_pixels, " cutscene-pixels=", cs_pixels,
        " ped=32/26 cutscene=61/56 feedback=0")
    quit(0)
