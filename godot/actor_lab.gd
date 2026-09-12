extends Node3D

const View = preload("res://diagnostic_actor_view.gd")
const STEP := 1.0 / 30.0
var _bridge: RefCounted
var _view: Node3D
var _accumulator := 0.0
var _jump := false
var _interact := false
var _last_jump := false
var _last_interact := false

func _ready() -> void:
    var args := OS.get_cmdline_user_args()
    var game := ""
    for i in args.size() - 1:
        if args[i] == "--game-dir": game = args[i + 1]
    if not GDExtensionManager.is_extension_loaded("res://sa_legacy.gdextension"):
        if GDExtensionManager.load_extension("res://sa_legacy.gdextension") != GDExtensionManager.LOAD_STATUS_OK:
            push_error("cannot load native diagnostic extension")
            get_tree().quit(1)
            return
    _bridge = ClassDB.instantiate("SALegacyBridge")
    var result: Dictionary = _bridge.open_game(game, 140.0, 16, 64, true)
    if not result.ok:
        push_error(result.error)
        get_tree().quit(1)
        return
    _view = View.new()
    add_child(_view)
    _view.configure(_bridge.diagnostic_actors(1.0, true))
    var camera := Camera3D.new()
    add_child(camera)
    camera.position = Vector3(6, 4, 9)
    camera.look_at(Vector3(0, 1, 1.5))
    camera.current = true
    var label := Label.new()
    label.position = Vector2(16, 16)
    label.text = "DIAGNOSTIC APPROXIMATION — synthetic flat floor, NOT source gameplay\nWASD move/steer • Shift sprint • Space jump • E enter/exit • B brake • Esc quit\nNative controller/CPU poses; unlit preview materials, no visual parity claim"
    add_child(label)

func _process(delta: float) -> void:
    if _view == null:
        return
    if Input.is_physical_key_pressed(KEY_ESCAPE):
        get_tree().quit()
        return
    # Explicit studio policy: a stall pauses this approximation rather than
    # accumulating an unbounded catch-up queue. Not a source clock contract.
    if delta > 0.25:
        return
    var jump := Input.is_physical_key_pressed(KEY_SPACE)
    var interact := Input.is_physical_key_pressed(KEY_E)
    _jump = _jump or (jump and not _last_jump)
    _interact = _interact or (interact and not _last_interact)
    _last_jump = jump
    _last_interact = interact
    _accumulator += delta
    while _accumulator >= STEP:
        var forward := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
        var side := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
        var result: Dictionary = _bridge.tick_diagnostic_actors(STEP, forward, side, Input.is_physical_key_pressed(KEY_SHIFT), _jump, _interact, Input.is_physical_key_pressed(KEY_B))
        assert(result.ok)
        _jump = false
        _interact = false
        _accumulator -= STEP
    _view.present(_bridge.diagnostic_actors(_accumulator / STEP))

func _exit_tree() -> void:
    if _bridge != null:
        _bridge.close_game()
        _bridge = null
