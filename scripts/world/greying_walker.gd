class_name GreyingWalker
extends Node
## Walks the Wakebearer through the Greying: each physics frame samples the fog depth under
## the player, runs the EmberMeter (paused while a modal UI holds input), remembers the last
## clear ground stood on and, when the ember runs out, gently turns the player back there.
## There is no fail state — only "You forget why you came."

signal ember_changed(ember: float, depth: float)
signal turned_back
signal road_forgot

const TURN_BACK_TEXT := "You forget why you came."
## The road that forgets (Day 82): lost past a lit cresset's pool, the Wakebearer is brought back
## to where they could last see the way.
const FORGET_TEXT := "The road forgets where it goes. You find it again where the light was."
const FADE_SECONDS := 0.9
## The road-forgetting cue's strength while the way is unsure but not yet lost (lost_cue).
const LOST_HINT := 0.3
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
## Last ground stood on where the way could still be seen (forgetting under half FORGET_DEPTH).
var _last_remembered := Vector3.INF
## Seconds spent lost on a forgetting road (eases back off when the way is found again).
var forget_time := 0.0
## How lost the way is under the player on the last physics frame (Greying.forgetting_at).
var forgetting := 0.0
var _pool_time := 0.0


func _ready() -> void:
	name = "GreyingWalker"
	meter.emptied.connect(_turn_back)


## Called by main after a region loads: forget the previous region's clear spot.
func enter_region(p_region: Region) -> void:
	region = p_region
	_last_clear = Vector3.INF
	_last_remembered = Vector3.INF
	forget_time = 0.0
	if hud:
		hud.set_lost(0.0)


func _physics_process(delta: float) -> void:
	if player == null or region == null or not is_instance_valid(region) or turning_back:
		return
	var p := player.global_position
	depth = region.greying_depth(p.x, p.z)
	if not GameState.input_locked:
		meter.step(delta, depth)
	if depth < Greying.CLEAR_DEPTH and player.is_on_floor():
		_last_clear = p
	forgetting = region.forgetting(p.x, p.z)
	if forgetting < Greying.FORGET_DEPTH * 0.5 and player.is_on_floor():
		_last_remembered = p
	if not GameState.input_locked:
		if forgetting >= Greying.FORGET_DEPTH:
			forget_time += delta
		else:
			forget_time = maxf(0.0, forget_time - delta * 2.0)
		if forget_time >= Greying.FORGET_SECONDS:
			_lose_the_road()
			return
	if hud:
		# Hidden under a modal (a cresset lit mid-road); the fade covers it when the road forgets.
		hud.set_lost(0.0 if GameState.input_locked else lost_cue(forgetting, forget_time))
	player.set_ember(meter.ember)
	_open_pool(p, delta)
	ember_changed.emit(meter.ember, depth)


## The HUD's road-forgetting cue (Day 84; Hud.set_lost): a faint hint (up to LOST_HINT) as the way
## grows unsure, from half FORGET_DEPTH (where it stops being remembered) to FORGET_DEPTH, then
## rising with the time spent lost to 1 as FORGET_SECONDS runs out and the fade takes over.
static func lost_cue(p_forgetting: float, p_forget_time: float) -> float:
	var half := Greying.FORGET_DEPTH * 0.5
	var unsure := clampf((p_forgetting - half) / half, 0.0, 1.0) * LOST_HINT
	var lost := clampf(p_forget_time / Greying.FORGET_SECONDS, 0.0, 1.0)
	if lost <= 0.0:
		return unsure
	return maxf(unsure, lerpf(LOST_HINT, 1.0, lost))


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


## Where the player is brought back to when the road forgets: the last ground where the way could
## be seen, else the last clear ground.
func remembered_point() -> Vector3:
	return _last_remembered if _last_remembered.is_finite() else turn_back_point()


func _turn_back() -> void:
	if turning_back:
		return
	await _bring_back(turn_back_point(), TURN_BACK_TEXT, true)
	turned_back.emit()


func _lose_the_road() -> void:
	if turning_back:
		return
	await _bring_back(remembered_point(), FORGET_TEXT, false)
	road_forgot.emit()


## Fades out, puts the player at `target`, and fades back in with `text`. The ember out (`refill`)
## also refills it and remembers the first turn-back; losing the road leaves the ember as it was.
func _bring_back(target: Vector3, text: String, refill: bool) -> void:
	turning_back = true
	GameState.input_locked = true
	if hud:
		await hud.fade_screen(1.0, FADE_SECONDS)
	player.place_at(target)
	forget_time = 0.0
	forgetting = 0.0
	if hud:
		hud.set_lost(0.0)
	if refill:
		GameState.world.set_flag(TURNED_BACK_FLAG, true)
		meter.refill()
		depth = 0.0
	player.set_ember(meter.ember)
	ember_changed.emit(meter.ember, depth)
	GameState.toast.emit(text)
	if hud:
		await hud.fade_screen(0.0, FADE_SECONDS)
	GameState.input_locked = false
	turning_back = false
