class_name GreyingWalker
extends Node
## Walks the Wakebearer through the Greying: each physics frame samples the fog depth under
## the player, runs the EmberMeter (paused while a modal UI holds input), remembers the last
## clear ground stood on and, when the ember runs out, gently turns the player back there.
## There is no fail state — only "You forget why you came."

signal ember_changed(ember: float, depth: float)
signal turned_back

const TURN_BACK_TEXT := "You forget why you came."
const FADE_SECONDS := 0.9

var meter := EmberMeter.new()
## Fog depth under the player on the last physics frame.
var depth := 0.0
var turning_back := false
var player: Player
var region: Region
var hud: Hud

var _last_clear := Vector3.INF


func _ready() -> void:
	name = "GreyingWalker"
	meter.emptied.connect(_turn_back)


## Called by main after a region loads: forget the previous region's clear spot.
func enter_region(p_region: Region) -> void:
	region = p_region
	_last_clear = Vector3.INF


func _physics_process(delta: float) -> void:
	if player == null or region == null or not is_instance_valid(region) or turning_back:
		return
	var p := player.global_position
	depth = region.greying_depth(p.x, p.z)
	if not GameState.input_locked:
		meter.step(delta, depth)
	if depth < Greying.CLEAR_DEPTH and player.is_on_floor():
		_last_clear = p
	player.set_ember(meter.ember)
	ember_changed.emit(meter.ember, depth)


## Where the player is returned when the ember runs out.
func turn_back_point() -> Vector3:
	return _last_clear if _last_clear.is_finite() else region.spawn_position("default")


func _turn_back() -> void:
	if turning_back:
		return
	turning_back = true
	GameState.input_locked = true
	var target := turn_back_point()
	if hud:
		await hud.fade_screen(1.0, FADE_SECONDS)
	player.place_at(target)
	meter.refill()
	depth = 0.0
	player.set_ember(meter.ember)
	ember_changed.emit(meter.ember, depth)
	GameState.toast.emit(TURN_BACK_TEXT)
	if hud:
		await hud.fade_screen(0.0, FADE_SECONDS)
	GameState.input_locked = false
	turning_back = false
	turned_back.emit()
