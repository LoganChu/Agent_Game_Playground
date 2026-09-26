class_name CharacterRig
extends Node
## Procedural idle/walk motion for a Blender-made character (tools/blender/build_characters.py).
## The model is a node hierarchy — Rig > LegL, LegR, Torso > Head, ArmL, ArmR — and this
## node, added as a child of the model, offsets those parts from their rest pose each frame:
## breathing and a slow sway always, hands working in the "mend" style, and a leg/arm swing
## while `move_speed` is above zero. No skeletons or animation tracks to maintain.

const PARTS: Array[String] = ["LegL", "LegR", "Torso", "Head", "ArmL", "ArmR"]
const STYLES: Array[String] = ["breathe", "mend"]

## "breathe" (default) or "mend" (seated hands working over a net).
var style := "breathe"
## Horizontal speed in m/s; drives the walk swing (0 = standing).
var move_speed := 0.0

var _parts: Dictionary = {}   # part name -> Node3D
var _rest: Dictionary = {}    # part name -> Transform3D
var _time := 0.0
var _walk_phase := 0.0
var _walk_blend := 0.0


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
	pose(_time, _walk_phase, _walk_blend)


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
	if style == "mend":
		# Small alternating pulls of the needle through the mesh.
		_offset("ArmL", Vector3.ZERO, Vector3(0.12 * sin(t * 3.1), 0.08 * sin(t * 1.55), 0))
		_offset("ArmR", Vector3.ZERO, Vector3(0.12 * sin(t * 3.1 + PI), -0.08 * sin(t * 1.55 + 0.8), 0))
	else:
		_offset("ArmL", Vector3.ZERO, Vector3(-0.45 * swing + 0.02 * breath, 0, 0.03 * breath))
		_offset("ArmR", Vector3.ZERO, Vector3(0.45 * swing + 0.02 * breath, 0, -0.03 * breath))


func _offset(part: String, move: Vector3, euler: Vector3, scale: Vector3 = Vector3.ONE) -> void:
	var node: Node3D = _parts.get(part)
	if node == null:
		return
	var rest: Transform3D = _rest[part]
	node.transform = Transform3D(rest.basis * Basis.from_euler(euler).scaled(scale), rest.origin + move)
