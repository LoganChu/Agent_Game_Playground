class_name CharacterRig
extends Node
## Procedural idle/walk motion for a Blender-made character (tools/blender/build_characters.py).
## The model is a node hierarchy — Rig > LegL, LegR, Torso > Head, ArmL, ArmR — and this
## node, added as a child of the model, offsets those parts from their rest pose each frame:
## breathing and a slow sway always, hands working in the "mend" style, a slow draw of the
## clamp rake in the "rake" style (Hob Marl), the hammer and chisel in the "chisel" style (the
## Lamp at the lantern bench), a seated rest in the "sit" style (Hob on the camp bench), a swig
## now and then in the "bottle" style (Aldous on his bench), and a leg/arm swing
## while `move_speed` is above zero. No skeletons or animation tracks to maintain.

const PARTS: Array[String] = ["LegL", "LegR", "Torso", "Head", "ArmL", "ArmR"]
const STYLES: Array[String] = ["breathe", "mend", "rake", "chisel", "sit", "still", "bottle"]
## The "chisel" beat: two taps, then a pause (seconds).
const CHISEL_PERIOD := 3.4
## The "sit" doze: once a cycle the head sinks, holds, and comes up with a start (seconds).
const DOZE_PERIOD := 11.0
## The "still" drift: the head goes down to the water and slowly up again (seconds).
const STILL_PERIOD := 16.0
## The "bottle" swig: once a cycle the bottle comes up, he drinks, and it goes back down (seconds).
const BOTTLE_PERIOD := 14.0
## How far the bottle arm comes up and in for the swig, and the head goes back (radians).
const SWIG_LIFT := 1.35
const SWIG_IN := 0.45
const SWIG_HEAD := 0.42
## Looking away (a figure's `averts`): how far the head turns from the player (radians), how
## much of that the shoulders take, how far the chin drops, and how fast it comes on (1/s).
const AVERT_YAW := 1.1
const AVERT_TORSO := 0.25
const AVERT_CHIN := 0.22
const AVERT_RATE := 1.2
const AVERT_RADIUS := 6.0

## "breathe" (default), "mend" (seated hands working over a net) or "rake" (standing, drawing
## a rake across the ground in slow pulls, leaning into each one) or "chisel" (bent over a bench:
## tap, tap with the left hand, a pause, and now and then the head turns as if listening) or
## "sit" (a seated model resting: thumbs working the rake pole, and once in a while the head
## sinks as he dozes off and comes up with a start — Half-Hushed, he loses the thread) or
## "still" (a seated Unmoored by the pools: slow shallow breath, the hands quiet, the head
## drifting down to look into the water and, a long while later, up again) or "bottle" (a
## seated Aldous: the bottle turning in his hand on his thigh, and once a cycle a swig — it comes
## up to his mouth, his head goes back, and down it comes again; the other hand rubs his knee).
var style := "breathe"
## Horizontal speed in m/s; drives the walk swing (0 = standing).
var move_speed := 0.0
## A condition (Conditions) under which this character won't look at the player: while it
## holds and the player comes within `avert_radius`, the head turns away and the chin drops
## (the Unmoored and a bare ember: "they've a right not to look"). null = never.
var avert_if: Variant = null
var avert_radius := AVERT_RADIUS

var _parts: Dictionary = {}   # part name -> Node3D
var _rest: Dictionary = {}    # part name -> Transform3D
var _time := 0.0
var _walk_phase := 0.0
var _walk_blend := 0.0
var _avert := 0.0       # 0..1, eased
var _avert_side := 1.0  # which way the head turns: +1 = toward the model's +X, -1 = -X
var _avert_reach := 1.0 # 0..1: how much turning is needed (none if the player is behind)
var _player: Node3D = null


## Loads a character model scene and returns an instance with a rig attached, or null if
## the path is empty or does not load (callers fall back to primitive bodies).
static func instantiate(path: String, idle_style: String = "breathe") -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	var rig := CharacterRig.new()
	rig.name = "CharacterRig"
	rig.style = idle_style if idle_style in STYLES else "breathe"
	model.add_child(rig)
	return model


## Every rig part found in `model` (for tests: a model missing parts still loads, it just
## animates less).
static func find_parts(model: Node) -> Dictionary:
	var found := {}
	for part in PARTS:
		var node := model.find_child(part, true, false) as Node3D
		if node:
			found[part] = node
	return found


func _ready() -> void:
	_parts = find_parts(get_parent())
	for part: String in _parts:
		_rest[part] = (_parts[part] as Node3D).transform
	# Desynchronise characters standing side by side.
	_time = float(get_instance_id() % 1000) * 0.01


func _process(delta: float) -> void:
	_time += delta
	_walk_blend = move_toward(_walk_blend, 1.0 if move_speed > 0.3 else 0.0, delta * 5.0)
	_walk_phase += delta * clampf(move_speed, 0.0, 6.0) * 2.2
	if avert_if != null:
		_update_avert(delta)
	pose(_time, _walk_phase, _walk_blend)


func _update_avert(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(SaveSystem.PLAYER_GROUP) as Node3D
	var holds := Conditions.evaluate(avert_if, GameState.world)
	step_avert(delta, holds, _player.global_position if _player else null)


## One step of looking away (public so tests can drive it): `holds` = the `avert_if` condition,
## `player` = the player's world position (null = no player).
func step_avert(delta: float, holds: bool, player: Variant) -> void:
	var want := 0.0
	var model := get_parent() as Node3D
	if holds and player is Vector3 and model:
		var xform := model.global_transform if model.is_inside_tree() else model.transform
		var aim := avert_aim(xform.affine_inverse() * (player as Vector3), avert_radius, _avert_side)
		want = aim.x
		if want > 0.0:
			_avert_side = aim.y
			_avert_reach = aim.z
	_avert = move_toward(_avert, want, delta * AVERT_RATE)


## Where a character looks away to, for the player at `local` (model space, +Z = the way the
## character faces): x = how much it wants to look away (1 within `radius`, fading to 0 a
## metre past it), y = the side the head turns to (away from the player; `side` is kept while
## the player is nearly dead ahead, so the head doesn't flick), z = how far it needs to turn
## (1 with the player in front, 0 with them behind — it's already not looking).
static func avert_aim(local: Vector3, radius: float, side: float = 1.0) -> Vector3:
	var flat := Vector2(local.x, local.z)
	var distance := flat.length()
	var want := 1.0 - smoothstep(radius, radius + 1.0, distance)
	if distance < 0.0001:
		return Vector3(want, side, 1.0)
	var angle := atan2(local.x, local.z)
	if absf(angle) > 0.15:
		side = -signf(angle)
	var reach := 1.0 - smoothstep(PI * 0.55, PI * 0.9, absf(angle))
	return Vector3(want, side, reach)


## How far the character is looking away right now (0..1; for tests).
func avert_amount() -> float:
	return _avert


## Applies the pose for time `t` (public so tests can drive it deterministically).
func pose(t: float, walk_phase: float = 0.0, walk: float = 0.0) -> void:
	var breath := sin(t * 1.7)
	var swing := sin(walk_phase) * walk
	_offset("Torso", Vector3(0, abs(swing) * 0.03, 0),
		Vector3(0.02 * breath * (1.0 - walk) + 0.06 * walk, 0.05 * swing, 0.015 * sin(t * 0.6)),
		Vector3(1.0 + 0.012 * breath, 1.0 + 0.02 * breath, 1.0 + 0.012 * breath))
	_offset("Head", Vector3.ZERO, Vector3(-0.015 * breath, 0.04 * sin(t * 0.37), 0.0))
	_offset("LegL", Vector3.ZERO, Vector3(0.55 * swing, 0, 0))
	_offset("LegR", Vector3.ZERO, Vector3(-0.55 * swing, 0, 0))
	if style == "rake":
		# A slow pull every ~3 s: reach out (arms forward, a lean), draw back; eased by walking.
		var pull := sin(t * 2.1) * (1.0 - walk)
		_offset("Torso", Vector3(0, abs(swing) * 0.03, 0),
			Vector3(0.1 + 0.07 * pull + 0.06 * walk, 0.05 * swing, 0.015 * sin(t * 0.6)),
			Vector3(1.0 + 0.012 * breath, 1.0 + 0.02 * breath, 1.0 + 0.012 * breath))
		_offset("ArmL", Vector3.ZERO, Vector3(-0.3 * pull - 0.45 * swing, 0, 0.03 * breath))
		_offset("ArmR", Vector3.ZERO, Vector3(-0.3 * pull + 0.45 * swing, 0, -0.03 * breath))
	elif style == "chisel":
		var still := 1.0 - walk
		var tap := chisel_tap(t) * still
		var listen := chisel_listen(t) * still
		_offset("Torso", Vector3(0, abs(swing) * 0.03, 0),
			Vector3(0.16 * still + 0.02 * tap + 0.06 * walk, 0.05 * swing, 0.015 * sin(t * 0.6)),
			Vector3(1.0 + 0.012 * breath, 1.0 + 0.02 * breath, 1.0 + 0.012 * breath))
		_offset("Head", Vector3.ZERO, Vector3(0.12 * still - 0.015 * breath, 0.5 * listen, 0.0))
		# The hammer hand lifts and strikes; the pole hand steadies the chisel, barely moving.
		_offset("ArmL", Vector3.ZERO, Vector3(-0.55 * still - 0.5 * tap - 0.45 * swing, 0, 0.1 * still))
		_offset("ArmR", Vector3.ZERO, Vector3(-0.3 * still + 0.02 * tap + 0.45 * swing, 0, -0.06 * still))
	elif style == "sit":
		# Seated models carry their own bent legs and seat; nothing here walks.
		var doze := sit_doze(t)
		var start := sit_start(t)
		_offset("LegL", Vector3.ZERO, Vector3.ZERO)
		_offset("LegR", Vector3.ZERO, Vector3.ZERO)
		_offset("Torso", Vector3(0, 0.01 * start, 0),
			Vector3(0.02 * breath + 0.06 * doze - 0.05 * start, 0.0, 0.015 * sin(t * 0.6)),
			Vector3(1.0 + 0.012 * breath, 1.0 + 0.02 * breath, 1.0 + 0.012 * breath))
		_offset("Head", Vector3.ZERO, Vector3(0.38 * doze - 0.12 * start - 0.015 * breath, 0.04 * sin(t * 0.37) * (1.0 - doze), 0.0))
		# Thumbs working along the pole: the hands creep a little, out of step.
		_offset("ArmL", Vector3.ZERO, Vector3(0.04 * sin(t * 0.9) + 0.05 * doze, 0, 0.02 * breath))
		_offset("ArmR", Vector3.ZERO, Vector3(0.04 * sin(t * 0.9 + 2.0) + 0.05 * doze, 0, -0.02 * breath))
	elif style == "still":
		var slow := sin(t * 0.9)
		var drift := still_drift(t)
		_offset("LegL", Vector3.ZERO, Vector3.ZERO)
		_offset("LegR", Vector3.ZERO, Vector3.ZERO)
		_offset("Torso", Vector3.ZERO, Vector3(0.012 * slow + 0.04 * drift, 0.0, 0.01 * sin(t * 0.21)),
			Vector3(1.0 + 0.006 * slow, 1.0 + 0.01 * slow, 1.0 + 0.006 * slow))
		_offset("Head", Vector3.ZERO, Vector3(0.3 * drift - 0.01 * slow, 0.06 * sin(t * 0.13) * (1.0 - drift), 0.0))
		_offset("ArmL", Vector3.ZERO, Vector3(0.01 * slow, 0, 0))
		_offset("ArmR", Vector3.ZERO, Vector3(0.01 * slow, 0, 0))
	elif style == "bottle":
		var swig := bottle_swig(t)
		_offset("LegL", Vector3.ZERO, Vector3.ZERO)
		_offset("LegR", Vector3.ZERO, Vector3.ZERO)
		_offset("Torso", Vector3.ZERO,
			Vector3(0.02 * breath - 0.07 * swig, 0.0, 0.015 * sin(t * 0.6)),
			Vector3(1.0 + 0.012 * breath, 1.0 + 0.02 * breath, 1.0 + 0.012 * breath))
		_offset("Head", Vector3.ZERO, Vector3(-SWIG_HEAD * swig - 0.015 * breath, 0.05 * sin(t * 0.37) * (1.0 - swig), 0.0))
		# The bottle hand: turning it a little on his thigh, then up and in to his mouth.
		_offset("ArmL", Vector3.ZERO, Vector3(-SWIG_LIFT * swig, 0.06 * sin(t * 0.8) * (1.0 - swig), -SWIG_IN * swig))
		_offset("ArmR", Vector3.ZERO, Vector3(0.05 * sin(t * 1.3), 0, -0.02 * breath))
	elif style == "mend":
		# Small alternating pulls of the needle through the mesh.
		_offset("ArmL", Vector3.ZERO, Vector3(0.12 * sin(t * 3.1), 0.08 * sin(t * 1.55), 0))
		_offset("ArmR", Vector3.ZERO, Vector3(0.12 * sin(t * 3.1 + PI), -0.08 * sin(t * 1.55 + 0.8), 0))
	else:
		_offset("ArmL", Vector3.ZERO, Vector3(-0.45 * swing + 0.02 * breath, 0, 0.03 * breath))
		_offset("ArmR", Vector3.ZERO, Vector3(0.45 * swing + 0.02 * breath, 0, -0.03 * breath))
	if _avert > 0.0:
		# On top of the idle: the shoulders and then the head turn away, the chin goes down.
		var turn := smoothstep(0.0, 1.0, _avert) * _avert_side * _avert_reach
		_turn("Torso", AVERT_TORSO * turn, 0.0)
		_turn("Head", AVERT_YAW * turn, AVERT_CHIN * smoothstep(0.0, 1.0, _avert))


## The chisel hand's lift at time `t` (0 = resting on the work, 1 = raised): two quick taps at
## the start of each CHISEL_PERIOD, then a rest.
static func chisel_tap(t: float) -> float:
	var p := fmod(t, CHISEL_PERIOD)
	for start: float in [0.0, 0.42]:
		var x := (p - start) / 0.32
		if x >= 0.0 and x <= 1.0:
			return sin(x * PI) * sin(x * PI)
	return 0.0


## How far the head has turned to listen (0..1): about once in three beats it turns aside,
## holds, and comes back to the work.
static func chisel_listen(t: float) -> float:
	var p := fmod(t, CHISEL_PERIOD * 3.0) - CHISEL_PERIOD * 1.2
	if p < 0.0 or p > 2.8:
		return 0.0
	return smoothstep(0.0, 0.6, p) * (1.0 - smoothstep(2.1, 2.8, p))


## How far a sitter has nodded off at time `t` (0 = awake, 1 = chin down): late in each
## DOZE_PERIOD the head sinks slowly, holds, then snaps back up.
static func sit_doze(t: float) -> float:
	var p := fmod(t, DOZE_PERIOD) - DOZE_PERIOD * 0.55
	if p < 0.0 or p > 4.3:
		return 0.0
	return smoothstep(0.0, 2.4, p) * (1.0 - smoothstep(4.0, 4.3, p))


## How far a "still" sitter's head has drifted down to the water (0..1): a slow swell over
## STILL_PERIOD — no start, nothing calls them back.
static func still_drift(t: float) -> float:
	return 0.5 - 0.5 * cos(t / STILL_PERIOD * TAU)


## How far the bottle is up for a swig at time `t` (0 = on his thigh, 1 = at his mouth): late
## in each BOTTLE_PERIOD it comes up (0.9 s), he drinks (1.4 s), and it goes down slower (1.2 s).
static func bottle_swig(t: float) -> float:
	var p := fmod(t, BOTTLE_PERIOD) - BOTTLE_PERIOD * 0.6
	if p < 0.0 or p > 3.5:
		return 0.0
	return smoothstep(0.0, 0.9, p) * (1.0 - smoothstep(2.3, 3.5, p))


## The little start as the sitter wakes (0..1, peaks just after the head comes up).
static func sit_start(t: float) -> float:
	var p := fmod(t, DOZE_PERIOD) - DOZE_PERIOD * 0.55 - 4.1
	if p < 0.0 or p > 0.8:
		return 0.0
	return sin(p / 0.8 * PI)


## Turns a part (already posed) by `yaw` about its parent's up axis and `pitch` about its own
## X (positive = chin down), pivoting on its origin.
func _turn(part: String, yaw: float, pitch: float) -> void:
	var node: Node3D = _parts.get(part)
	if node == null:
		return
	node.basis = Basis(Vector3.UP, yaw) * node.basis * Basis(Vector3.RIGHT, pitch)


func _offset(part: String, move: Vector3, euler: Vector3, scale: Vector3 = Vector3.ONE) -> void:
	var node: Node3D = _parts.get(part)
	if node == null:
		return
	var rest: Transform3D = _rest[part]
	node.transform = Transform3D(rest.basis * Basis.from_euler(euler).scaled(scale), rest.origin + move)
