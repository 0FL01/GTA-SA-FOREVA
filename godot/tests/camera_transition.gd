extends SceneTree

var _failed := false

func _initialize() -> void:
	call_deferred("_run")

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	printerr("camera-transition-fail: ", message)
	_failed = true
	return false

func _run() -> void:
	if not GDExtensionManager.is_extension_loaded("res://sa_legacy.gdextension"):
		if GDExtensionManager.load_extension("res://sa_legacy.gdextension") != GDExtensionManager.LOAD_STATUS_OK:
			printerr("camera-transition-fail: extension load")
			quit(2)
			return
	if not _expect(ClassDB.class_exists("SALegacyCamera"), "camera class registration"):
		quit(1)
		return
	var camera: RefCounted = ClassDB.instantiate("SALegacyCamera")
	_expect(camera != null, "camera instantiate")
	_expect(not bool(camera.call("snapshot").get("valid", true)), "fresh snapshot invalid")
	var spawn: Dictionary = camera.call("initialize", 7, 11, 100)
	_expect(bool(spawn.get("ok", false)) and int(spawn.get("mode", -1)) == 4, "spawn follow-ped")
	_expect(str(spawn.get("view_status", "")) == "unsupported", "view solver explicit unsupported")
	_expect(not bool(spawn.get("presentation_feedback", true)), "no presentation feedback")
	_expect(int((spawn.get("target", {}) as Dictionary).get("identity", -1)) == 11, "spawn ped identity")
	var held_spawn := spawn.duplicate(true)
	var behind: Dictionary = camera.call("set_directly_behind", 101, Vector3(0, 1, 0))
	_expect(bool(behind.get("ok", false)) and bool(behind.get("directly_behind", false)), "direct behind")
	_expect(is_equal_approx(float(behind.get("ped_orientation", 0)), PI * 0.5), "source orientation")
	var enter: Dictionary = camera.call("restore", 102, 1, 11, 22, true, false, Vector3(1, 0, 0), false, 17)
	_expect(bool(enter.get("ok", false)) and int(enter.get("mode", -1)) == 18, "enter vehicle mode")
	_expect(int((enter.get("target", {}) as Dictionary).get("identity", -1)) == 22, "vehicle identity")
	var transition := enter.get("transition", {}) as Dictionary
	_expect(bool(transition.get("active", false)) and int(transition.get("duration_ms", -1)) == 1350, "enter transition")
	var blocked: Dictionary = camera.call("restore", 103, 5, 11, 22, true, false, Vector3(1, 0, 0), false, 18)
	_expect(not bool(blocked.get("ok", true)) and str(blocked.get("status", "")) == "transition_outstanding", "overlap reject")
	_expect(int(blocked.get("mode", -1)) == 18 and int(blocked.get("input_sequence", -1)) == 17, "overlap atomic")
	var complete: Dictionary = camera.call("advance", 1452)
	_expect(bool(complete.get("ok", false)) and not bool((complete.get("transition", {}) as Dictionary).get("active", true)), "enter complete")
	var exit: Dictionary = camera.call("restore", 1453, 5, 11, 22, true, true, Vector3(1, 0, 0), false, 18)
	_expect(bool(exit.get("ok", false)) and int(exit.get("mode", -1)) == 4, "exit follow-ped")
	transition = exit.get("transition", {}) as Dictionary
	_expect(int(transition.get("duration_ms", -1)) == 800, "bike exit profile")
	var bad: Dictionary = camera.call("restore", 1454, 0, 11, 0, false, false, Vector3(1, 0, 0), false, 16)
	_expect(not bool(bad.get("ok", true)) and str(bad.get("status", "")) == "invalid_input", "backward input reject")
	_expect(int(bad.get("input_sequence", -1)) == 18, "bad input retains state")
	_expect(held_spawn == spawn, "returned dictionary independent")
	var events := exit.get("events", []) as Array
	_expect(events.size() == 5, "ordered committed journal size")
	for i in events.size():
		_expect(int((events[i] as Dictionary).get("sequence", -1)) == i + 1, "journal sequence %d" % i)
	_expect(int((events[2] as Dictionary).get("input_sequence", -1)) == 17, "input sequence carried by transition")
	if _failed:
		quit(1)
		return
	print("camera-transition-ok modes=4,18 events=5 pointer-feedback=0 view=unsupported")
	quit(0)
