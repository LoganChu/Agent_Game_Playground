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
## Saved world flag: the Greying has turned the Wakebearer back at least once (NPCs remark on it).
const TURNED_BACK_FLAG := "greying_turned_back"

var meter := EmberMeter.new()
## Fog depth under the player on the last physics frame.
var depth := 0.0
var turning_back := false
var player: Player
var region: Region
var hud: Hud

var _last_clear := Vector3.INF
var _pool_time := 0.0


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
	_open_pool(p, delta)
	ember_changed.emit(meter.ember, depth)


## The ember's light holds a pool of clear round the Wakebearer, guttering as the ember wanes
## and breathing with the hand's flicker.
func _open_pool(p: Vector3, delta: float) -> void:
	_pool_time += delta
	var breath := 1.0 + 0.04 * sin(_pool_time * 2.3) + 0.025 * sin(_pool_time * 5.7 + 1.3)
	region.set_ember_pool(p + Vector3.UP, pool_radius() * breath, Greying.EMBER_POOL_PUSH)


## The pool's radius for the ember right now (before the breathing).
func pool_radius() -> float:
	return Greying.ember_pool_radius(meter.ember)


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
	GameState.world.set_flag(TURNED_BACK_FLAG, true)
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
