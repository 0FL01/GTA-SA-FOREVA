extends SceneTree

const View = preload("res://diagnostic_actor_view.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var game := ""
    var reference := ""
    var screenshot := ""
    for i in args.size():
        if args[i] == "--game-dir": game = args[i + 1]
        if args[i] == "--reference-trace": reference = args[i + 1]
        if args[i] == "--screenshot": screenshot = args[i + 1]
    if game.is_empty() or reference.is_empty():
        push_error("usage: --game-dir PATH --reference-trace PATH [--screenshot PNG]")
        quit(2)
        return
    if not GDExtensionManager.is_extension_loaded("res://sa_legacy.gdextension"):
        assert(GDExtensionManager.load_extension("res://sa_legacy.gdextension") == GDExtensionManager.LOAD_STATUS_OK)
    var bridge = ClassDB.instantiate("SALegacyBridge")
    var opened: Dictionary = bridge.open_game(game, 140.0, 16, 64, true)
    if not opened.ok:
        push_error(opened.error)
        quit(1)
        return
    var packet: Dictionary = bridge.diagnostic_actors(1.0, true)
    var view := View.new()
    root.add_child(view)
    view.configure(packet)
    var camera := Camera3D.new()
    root.add_child(camera)
    camera.position = Vector3(6, 4, 9)
    camera.look_at(Vector3(0, 1, 1.5))
    camera.current = true
    root.size = Vector2i(960, 640)
    var label := Label.new()
    label.text = "DIAGNOSTIC APPROXIMATION — CJ + vehicle\nSynthetic floor; native controller; no source gameplay/parity claim"
    label.position = Vector2(16, 16)
    root.add_child(label)
    var trace: String = packet.trace + "\n"
    var retained: Dictionary = packet.duplicate(true)
    var submitted: Dictionary = bridge.submit_region(Vector3(2490, -1665, 14))
    assert(submitted.ok)
    var region: Dictionary = {}
    for i in 26:
        var step: Dictionary = bridge.tick_diagnostic_actors(1.0 / 30.0, 1.0 if i < 8 or i > 12 else 0.0, 0.25 if i > 12 else 0.0, i >= 4 and i < 8, false, i == 12)
        assert(step.ok)
        trace += step.trace + "\n"
        var current: Dictionary = bridge.diagnostic_actors(1.0)
        var half: Dictionary = bridge.diagnostic_actors(0.5)
        assert(current.trace == half.trace and current.trace == step.trace)
        assert(not bridge.diagnostic_actors(NAN).ok)
        assert(not bridge.tick_diagnostic_actors(-1, 0, 0, false, false, false).ok)
        assert(bridge.diagnostic_actors(1.0).trace == current.trace)
        if i == 0:
            var before_vertex: Vector3 = current.meshes[0].positions[0]
            var changed: PackedVector3Array = current.meshes[0].positions
            changed[0] += Vector3(100, 100, 100)
            current.meshes[0].positions = changed
            assert(bridge.diagnostic_actors(1.0).meshes[0].positions[0] == before_vertex, "presentation mutation reached native owner")
        if region.get("status", "") != "ready":
            region = bridge.poll_region()
            assert(region.status in ["pending", "preparing", "ready"])
        view.present(half)
        await process_frame
        if i == 11 and not screenshot.is_empty():
            await RenderingServer.frame_post_draw
            assert(root.get_texture().get_image().save_png(screenshot + "-walking.png") == OK)
    trace += "diagnostic-actors-ok synthetic-floor=true source-gameplay=false teardown=owned\n"
    assert(trace == FileAccess.get_file_as_string(reference), "headless/Godot full trace mismatch")
    while region.get("status", "") != "ready":
        await process_frame
        region = bridge.poll_region()
        assert(region.status in ["pending", "preparing", "ready"])
    assert(region.ok and region.request_id == submitted.request_id)
    if not screenshot.is_empty():
        await process_frame
        await RenderingServer.frame_post_draw
        var image := root.get_texture().get_image()
        assert(image.save_png(screenshot) == OK)
        # Actual actor pixels below the label, not merely import/trace success.
        var visible_pixels := 0
        var background := image.get_pixel(0, 100)
        for y in range(100, image.get_height(), 2):
            for x in range(0, image.get_width(), 2):
                var c := image.get_pixel(x, y)
                if maxf(absf(c.r - background.r), maxf(absf(c.g - background.g), absf(c.b - background.b))) > 0.05:
                    visible_pixels += 1
        assert(visible_pixels > 500, "actor render missing")
        print("diagnostic-actor-pixels=", visible_pixels)
    var weak_mesh: WeakRef = weakref(view.get_child(0).mesh)
    var weak_view: WeakRef = weakref(view)
    view.queue_free()
    await process_frame
    await process_frame
    assert(weak_view.get_ref() == null, "scene teardown retained view")
    assert(weak_mesh.get_ref() == null, "scene teardown retained mesh")
    bridge.close_game()
    assert(not bridge.diagnostic_actors(1.0).ok)
    assert(retained.trace == packet.trace and retained.meshes[0].positions == packet.meshes[0].positions)
    # A fresh scene can consume already-owned data after native teardown.
    var replay := View.new()
    root.add_child(replay)
    replay.configure(retained)
    replay.queue_free()
    camera.queue_free()
    label.queue_free()
    bridge = null
    await process_frame
    print("diagnostic-actors-godot-ok trace=27 teardown=owned source-gameplay=false")
    quit(0)
