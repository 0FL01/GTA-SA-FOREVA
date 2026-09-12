extends SceneTree

# P2-A03 Godot input seam trace. Synthetic (not physical) device proof:
# instantiates the registered SALegacyInput Node, drives it ONLY through
# Input.parse_input_event with InputEventJoypadButton/Motion, flushes plus
# awaits frames so the actual virtual _input() runs, then samples at fixed
# caller timestamps. No direct _input() calls and no sample-payload RPC that
# could fake event proof (sample takes only sequence/tick; moves/buttons come
# from persistent device-0 callback state).
#
# Shared table (11 rows including duplicate2, matching core probe kTrace):
#   (1,1000,0,0,0), (2,1010,64,-128,1), duplicate (2,1010,64,-128,1),
#   (3,1010,64,-128,1), (4,1030,64,-128,3), (5,1040,0,0,2),
#   (6,1050,-128,38,0), (7,1060,-128,38,0), (8,1070,-128,38,4),
#   (9,1080,-128,38,0), (10,1080,0,0,0)
# Full expected canonicals (11 lines):
#   1,1000,0,0,0,0,0 / 2,1010,64,-128,1,1,0 / 2,1010,64,-128,1,1,0 /
#   3,1010,64,-128,1,0,0 / 4,1030,64,-128,3,2,0 / 5,1040,0,0,2,0,1 /
#   6,1050,-128,38,0,0,2 / 7,1060,-128,38,0,0,0 / 8,1070,-128,38,4,4,0 /
#   9,1080,-128,38,0,0,4 / 10,1080,0,0,0,0,0
# Godot drive:
#   row1 baseline; row2 axes 0.5/-1.0 + X pressed; duplicate sample 2 no event
#   (appended to the trace); row3 no events held (pressed expires); row4 A
#   press; row5 X release + axes 0,0; row6 A release + axes -1.0/0.304
#   (0.304*128 trunc 38; 0.31 would give 39 and is not used); row7 Y press AND
#   release between samples (lost tap, unobserved); row8 Y press; row9 Y
#   release; row10 axes 0.3/0.0 => 0 (deadzone abs <= 0.3). Named JOY_*
#   constants only. Core status strings are lower_snake (ok,
#   duplicate_idempotent, invalid_sequence, duplicate_conflict, backward_tick,
#   non_finite_axis, axis_out_of_range, invalid_buttons); ignored is the owned
#   literal "ignored".
# Reference: `native-source-pad-trace-v1\n` then the 11 canonicals each plus
# newline, printed to stdout by the headless core probe `sa_core_input_probe
# --trace` (no path arg, no game assets) from C++ literal oracles. This script
# compares FULL versioned text, plus independent GDScript mask asserts,
# repeated-snapshot nonconsuming, no-event freeze, negative/conflicting/
# backward atomicity, invalid-axis reject-vs-clamp, and ignored device-1
# isolation. Requires received_events > 0 (real callback). No assets, no game
# dir. Reads ONLY the explicit --reference-trace fixture; writes nothing and
# reads no protected config.

const HEADER := "native-source-pad-trace-v1\n"
# Explicit fixture floats: 0.304*128 trunc 38.
const AXIS_ROW2_X := 0.5
const AXIS_ROW2_Y := -1.0
const AXIS_ZERO := 0.0
const AXIS_ROW6_X := -1.0
const AXIS_ROW6_Y := 0.304
const AXIS_ROW10_X := 0.3
const AXIS_ROW10_Y := 0.0

var _node: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var options := _parse_options(OS.get_cmdline_user_args())
	if not bool(options.get("ok", false)):
		printerr("input-trace-fail: ", str(options.get("error", "bad options")))
		quit(2)
		return
	await _run_trace(str(options.get("reference_trace", "")))


func _run_trace(reference_path: String) -> void:
	if not GDExtensionManager.is_extension_loaded("res://sa_legacy.gdextension"):
		if GDExtensionManager.load_extension("res://sa_legacy.gdextension") != GDExtensionManager.LOAD_STATUS_OK:
			_fail("cannot load GDExtension res://sa_legacy.gdextension")
			return
	if not ClassDB.class_exists("SALegacyInput"):
		_fail("SALegacyInput is not registered (SCENE Node expected)")
		return
	_node = ClassDB.instantiate("SALegacyInput")
	if _node == null or not (_node is Node):
		_fail("SALegacyInput could not be instantiated as Node")
		return
	if not _node.has_method("sample") or not _node.has_method("snapshot"):
		_fail("SALegacyInput is missing sample/snapshot")
		return
	root.add_child(_node)
	await process_frame
	await process_frame
	if not _node.is_processing_input():
		_fail("_ready() did not enable input via set_process_input(true)")
		return

	var canonicals: Array[String] = []

	# Row 1 baseline: no events.
	var r1: Dictionary = _sample(1, 1000)
	if not _expect_frame(r1, true, "ok", true, 1, 1000, 0, 0, 0, 0, 0, "1,1000,0,0,0,0,0"):
		return
	canonicals.append(str(r1["canonical"]))
	if not _expect_snapshot_equals(r1, "row1 snapshot matches sample"):
		return
	if not _snapshot_nonconsuming("row1"):
		return

	# Row 2: axes 0.5/-1.0 + X pressed.
	_inject_axis(JOY_AXIS_LEFT_X, AXIS_ROW2_X)
	_inject_axis(JOY_AXIS_LEFT_Y, AXIS_ROW2_Y)
	_inject_button(JOY_BUTTON_X, true)
	await _flush()
	var r2: Dictionary = _sample(2, 1010)
	if not _expect_frame(r2, true, "ok", true, 2, 1010, 64, -128, 1, 1, 0, "2,1010,64,-128,1,1,0"):
		return
	canonicals.append(str(r2["canonical"]))

	# Duplicate sample 2: no event, idempotent ok true, same canonical.
	# The core probe prints this duplicate row to stdout, so it is appended.
	var dup: Dictionary = _sample(2, 1010)
	if not _expect_frame(dup, true, "duplicate_idempotent", true, 2, 1010, 64, -128, 1, 1, 0, "2,1010,64,-128,1,1,0"):
		return
	canonicals.append(str(dup["canonical"]))

	# Row 3: no events held; pressed expires, down freezes.
	var r3: Dictionary = _sample(3, 1010)
	if not _expect_frame(r3, true, "ok", true, 3, 1010, 64, -128, 1, 0, 0, "3,1010,64,-128,1,0,0"):
		return
	canonicals.append(str(r3["canonical"]))

	# Row 4: A press (X still held).
	_inject_button(JOY_BUTTON_A, true)
	await _flush()
	var r4: Dictionary = _sample(4, 1030)
	if not _expect_frame(r4, true, "ok", true, 4, 1030, 64, -128, 3, 2, 0, "4,1030,64,-128,3,2,0"):
		return
	canonicals.append(str(r4["canonical"]))

	# Row 5: X release + axes 0,0 (A still held).
	_inject_button(JOY_BUTTON_X, false)
	_inject_axis(JOY_AXIS_LEFT_X, AXIS_ZERO)
	_inject_axis(JOY_AXIS_LEFT_Y, AXIS_ZERO)
	await _flush()
	var r5: Dictionary = _sample(5, 1040)
	if not _expect_frame(r5, true, "ok", true, 5, 1040, 0, 0, 2, 0, 1, "5,1040,0,0,2,0,1"):
		return
	canonicals.append(str(r5["canonical"]))

	# Row 6: A release + axes -1.0/0.304.
	_inject_button(JOY_BUTTON_A, false)
	_inject_axis(JOY_AXIS_LEFT_X, AXIS_ROW6_X)
	_inject_axis(JOY_AXIS_LEFT_Y, AXIS_ROW6_Y)
	await _flush()
	var r6: Dictionary = _sample(6, 1050)
	if not _expect_frame(r6, true, "ok", true, 6, 1050, -128, 38, 0, 0, 2, "6,1050,-128,38,0,0,2"):
		return
	canonicals.append(str(r6["canonical"]))

	# Row 7: Y press AND release between samples (lost tap, unobserved).
	_inject_button(JOY_BUTTON_Y, true)
	_inject_button(JOY_BUTTON_Y, false)
	await _flush()
	var r7: Dictionary = _sample(7, 1060)
	if not _expect_frame(r7, true, "ok", true, 7, 1060, -128, 38, 0, 0, 0, "7,1060,-128,38,0,0,0"):
		return
	canonicals.append(str(r7["canonical"]))

	# Row 8: Y press.
	_inject_button(JOY_BUTTON_Y, true)
	await _flush()
	var r8: Dictionary = _sample(8, 1070)
	if not _expect_frame(r8, true, "ok", true, 8, 1070, -128, 38, 4, 4, 0, "8,1070,-128,38,4,4,0"):
		return
	canonicals.append(str(r8["canonical"]))

	# Row 9: Y release.
	_inject_button(JOY_BUTTON_Y, false)
	await _flush()
	var r9: Dictionary = _sample(9, 1080)
	if not _expect_frame(r9, true, "ok", true, 9, 1080, -128, 38, 0, 0, 4, "9,1080,-128,38,0,0,4"):
		return
	canonicals.append(str(r9["canonical"]))

	# Row 10: axes 0.3/0.0 => 0 (deadzone).
	_inject_axis(JOY_AXIS_LEFT_X, AXIS_ROW10_X)
	_inject_axis(JOY_AXIS_LEFT_Y, AXIS_ROW10_Y)
	await _flush()
	var r10: Dictionary = _sample(10, 1080)
	if not _expect_frame(r10, true, "ok", true, 10, 1080, 0, 0, 0, 0, 0, "10,1080,0,0,0,0,0"):
		return
	canonicals.append(str(r10["canonical"]))

	# FULL versioned reference comparison (core C++ literal oracles, 11 rows).
	var expected_text := HEADER
	for line in canonicals:
		expected_text += line + "\n"
	var actual_text := _read_text_file(reference_path)
	if actual_text.is_empty() and expected_text != HEADER:
		_fail("cannot read --reference-trace: %s" % reference_path)
		return
	if actual_text != expected_text:
		printerr("input-trace-fail: reference FULL-text mismatch")
		printerr("--- expected ---\n%s--- actual ---\n%s--- end ---" % [expected_text, actual_text])
		quit(1)
		return

	# Independent post-trace checks (do not affect the 11-line reference).
	if not _snapshot_nonconsuming("post-trace"):
		return
	if not _check_atomic_failures():
		return
	if not await _check_invalid_axes():
		return
	if not await _check_ignored_inputs():
		return

	var snap: Dictionary = _node.call("snapshot")
	if not (int(snap.get("received_events", 0)) > 0):
		_fail("received_events is 0; virtual _input() never ran (event proof missing)")
		return

	_node.queue_free()
	print("input-trace-ok synthetic-not-physical frames=11 reference=FULL-match masks=independent received=%d" % int(snap.get("received_events", 0)))
	quit(0)


func _check_atomic_failures() -> bool:
	# Last committed is seq 10 (10,1080,0,0,0,0,0). Every failure must expose
	# it unchanged (no partial mutation) with ok false. Negative host
	# sequence/tick map to owned invalid_sequence: the GDScript int64 domain
	# is bounded before the core uint64 cast.
	var before: Dictionary = _node.call("snapshot")
	var cases: Array = [
		[-1, 2000, "invalid_sequence", "negative sequence"],
		[11, -1, "invalid_sequence", "negative tick"],
		[0, 2000, "invalid_sequence", "zero sequence (core)"],
		[10, 1081, "duplicate_conflict", "same seq different tick"],
		[5, 2000, "invalid_sequence", "backward sequence"],
		[11, 1070, "backward_tick", "forward seq backward tick"],
	]
	for entry in cases:
		var seq: int = entry[0]
		var tick: int = entry[1]
		var want_status: String = entry[2]
		var label: String = entry[3]
		var res: Dictionary = _sample(seq, tick)
		if not _check(not bool(res.get("ok", true)), label + " must fail"):
			return false
		if not _check(str(res.get("status", "")) == want_status, label + " status want %s got %s" % [want_status, str(res.get("status", ""))]):
			return false
		if not _check(bool(res.get("valid", false)), label + " failed sample keeps valid committed frame"):
			return false
		for key in ["sequence", "tick", "move_x", "move_y", "down", "pressed", "released", "canonical"]:
			if not _check(str(res.get(key, "A")) == str(before.get(key, "B")), label + " atomic field %s" % key):
				return false
		var after: Dictionary = _node.call("snapshot")
		if not _check(_frames_equal(after, before), label + " snapshot unchanged (atomic)"):
			return false
	return true


func _check_invalid_axes() -> bool:
	# Supported-axis invalid events reject (never clamp): physical preserved,
	# rejected_events increments, last_event_status diagnoses. Next sample
	# still yields 0,0 (not 127/128-clamped).
	var snap0: Dictionary = _node.call("snapshot")
	var rejected0 := int(snap0.get("rejected_events", -1))
	_inject_axis(JOY_AXIS_LEFT_X, NAN)
	await _flush()
	var snap_nan: Dictionary = _node.call("snapshot")
	if not _check(int(snap_nan.get("rejected_events", -2)) == rejected0 + 1, "NaN axis increments rejected_events"):
		return false
	if not _check(str(snap_nan.get("last_event_status", "")) == "non_finite_axis", "NaN axis status non_finite_axis got %s" % str(snap_nan.get("last_event_status", ""))):
		return false
	_inject_axis(JOY_AXIS_LEFT_Y, 2.0)
	await _flush()
	var snap_range: Dictionary = _node.call("snapshot")
	if not _check(int(snap_range.get("rejected_events", -2)) == rejected0 + 2, "out-of-range axis increments rejected_events"):
		return false
	if not _check(str(snap_range.get("last_event_status", "")) == "axis_out_of_range", "range axis status axis_out_of_range got %s" % str(snap_range.get("last_event_status", ""))):
		return false
	# +inf is non-finite (not out-of-range).
	_inject_axis(JOY_AXIS_LEFT_X, INF)
	await _flush()
	var snap_inf: Dictionary = _node.call("snapshot")
	if not _check(int(snap_inf.get("rejected_events", -2)) == rejected0 + 3, "+inf axis increments rejected_events"):
		return false
	if not _check(str(snap_inf.get("last_event_status", "")) == "non_finite_axis", "+inf axis status non_finite_axis"):
		return false
	# Physical preserved: next fresh sample still 0,0 (would be clamped
	# otherwise), down 0.
	var res: Dictionary = _sample(11, 1090)
	if not _expect_frame(res, true, "ok", true, 11, 1090, 0, 0, 0, 0, 0, "11,1090,0,0,0,0,0"):
		return false
	return true


func _check_ignored_inputs() -> bool:
	# Device-1 supported button cannot mutate device-0 state; unsupported
	# buttons/axes and other event types are ignored (counted, never stored).
	var before: Dictionary = _node.call("snapshot")
	var ignored0 := int(before.get("ignored_events", -1))
	var received0 := int(before.get("received_events", -1))
	_inject_button_device(JOY_BUTTON_X, true, 1)
	await _flush()
	var after_dev1: Dictionary = _node.call("snapshot")
	if not _check(int(after_dev1.get("received_events", -2)) == received0 + 1, "device-1 event still received (callback ran)"):
		return false
	if not _check(int(after_dev1.get("ignored_events", -2)) == ignored0 + 1, "device-1 increments ignored_events"):
		return false
	if not _check(str(after_dev1.get("last_event_status", "")) == "ignored", "device-1 status ignored"):
		return false
	if not _check(_frames_equal(after_dev1, before), "device-1 cannot mutate device-0 frame"):
		return false
	# Unsupported button B on device 0.
	_inject_button(JOY_BUTTON_B, true)
	await _flush()
	var after_b: Dictionary = _node.call("snapshot")
	if not _check(int(after_b.get("ignored_events", -2)) == ignored0 + 2, "unsupported button increments ignored_events"):
		return false
	if not _check(_frames_equal(after_b, before), "unsupported button cannot mutate"):
		return false
	# Unsupported axis (right X) on device 0.
	_inject_axis(JOY_AXIS_RIGHT_X, 0.9)
	await _flush()
	var after_axis: Dictionary = _node.call("snapshot")
	if not _check(int(after_axis.get("ignored_events", -2)) == ignored0 + 3, "unsupported axis increments ignored_events"):
		return false
	# Other event type via the same parse_input_event path (not direct _input).
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	key.device = 0
	Input.parse_input_event(key)
	await _flush()
	var after_key: Dictionary = _node.call("snapshot")
	if not _check(int(after_key.get("ignored_events", -2)) == ignored0 + 4, "other event type increments ignored_events"):
		return false
	if not _check(_frames_equal(after_key, before), "other event type cannot mutate"):
		return false
	# Fresh sample still reflects device-0 physical (0,0,0), not device-1/B.
	var res: Dictionary = _sample(12, 1100)
	if not _expect_frame(res, true, "ok", true, 12, 1100, 0, 0, 0, 0, 0, "12,1100,0,0,0,0,0"):
		return false
	return true


func _inject_button(button: int, pressed: bool) -> void:
	_inject_button_device(button, pressed, 0)


func _inject_button_device(button: int, pressed: bool, device: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _inject_axis(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _flush() -> void:
	Input.flush_buffered_events()
	await process_frame
	await process_frame


func _sample(sequence: int, tick: int) -> Dictionary:
	return _node.call("sample", sequence, tick)


func _expect_frame(res: Variant, want_ok: bool, want_status: String, want_valid: bool, want_seq: int, want_tick: int, want_mx: int, want_my: int, want_down: int, want_pressed: int, want_released: int, want_canonical: String) -> bool:
	if not (res is Dictionary):
		return _check(false, "sample returned non-Dictionary")
	if not _check(bool(res.get("ok", not want_ok)) == want_ok, "ok want %s got %s (%s)" % [str(want_ok), str(res.get("ok", "?")), str(res.get("status", "?"))]):
		return false
	if not _check(str(res.get("status", "")) == want_status, "status want %s got %s" % [want_status, str(res.get("status", ""))]):
		return false
	if not _check(bool(res.get("valid", not want_valid)) == want_valid, "valid want %s" % str(want_valid)):
		return false
	var fields := {
		"sequence": want_seq, "tick": want_tick, "move_x": want_mx, "move_y": want_my,
		"down": want_down, "pressed": want_pressed, "released": want_released,
	}
	for key in fields:
		if not _check(int(res.get(key, -99999)) == int(fields[key]), "%s want %d got %s" % [key, int(fields[key]), str(res.get(key, "?"))]):
			return false
	if not _check(str(res.get("canonical", "")) == want_canonical, "canonical want %s got %s" % [want_canonical, str(res.get("canonical", ""))]):
		return false
	return true


func _expect_snapshot_equals(sample_res: Dictionary, label: String) -> bool:
	var snap: Dictionary = _node.call("snapshot")
	for key in ["valid", "sequence", "tick", "move_x", "move_y", "down", "pressed", "released", "canonical"]:
		if not _check(str(snap.get(key, "A")) == str(sample_res.get(key, "B")), label + " snapshot field %s" % key):
			return false
	return true


func _snapshot_nonconsuming(label: String) -> bool:
	var first: Dictionary = _node.call("snapshot")
	var second: Dictionary = _node.call("snapshot")
	if not _check(_frames_equal(first, second), label + " repeated snapshot nonconsuming"):
		return false
	return true


func _frames_equal(a: Dictionary, b: Dictionary) -> bool:
	for key in ["valid", "sequence", "tick", "move_x", "move_y", "down", "pressed", "released", "canonical"]:
		if str(a.get(key, "A")) != str(b.get(key, "B")):
			return false
	return true


func _read_text_file(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _parse_options(args: PackedStringArray) -> Dictionary:
	var result := {"ok": false, "error": "", "reference_trace": ""}
	var i := 0
	while i < args.size():
		var arg := String(args[i])
		if arg != "--reference-trace":
			result.error = "unknown input trace option: %s (only --reference-trace PATH is supported; no game dir, no writes)" % arg
			return result
		if i + 1 >= args.size():
			result.error = "--reference-trace requires a value"
			return result
		i += 1
		var value := String(args[i])
		if value.is_empty():
			result.error = "--reference-trace requires a non-empty path"
			return result
		result.reference_trace = _absolute_path(value)
		i += 1
	if str(result.reference_trace).is_empty():
		result.error = "--reference-trace PATH is required (redirected core probe --trace stdout; no game assets)"
		return result
	if not FileAccess.file_exists(str(result.reference_trace)):
		result.error = "reference trace does not exist: %s" % str(result.reference_trace)
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
		printerr("input-trace-fail: ", label)
		quit(1)
	return condition


func _fail(message: String) -> void:
	printerr("input-trace-fail: %s" % message)
	quit(1)
