class_name NpcActor
extends Interactable
## An NPC placed in a region. Visuals are the NPC's Blender-made character model (`model`,
## animated by a CharacterRig in its `idle` style), or a primitive figure tinted by the NPC's
## signature color when it has none; talking starts the NPC's dialogue. While talking the
## NPC turns to face the player (unless its data says `"faces_player": false`, e.g. Hesk at
## her net), and turns back to its placed facing when the dialogue closes.

## How quickly the NPC turns towards the player and back (1/s, exponential ease).
const TURN_SPEED := 6.0

var npc_id := ""
var npc_data: Dictionary = {}

## The body's yaw while talking, relative to the placed rotation (0 = placed facing).
var _face_yaw := 0.0
var _talking := false
var _body: Node3D


func setup(id: String, data: Dictionary) -> void:
	npc_id = id
	npc_data = data
	name = "Npc_" + id
	prompt = "Talk to " + str(data.get("name", id))


func _ready() -> void:
	super._ready()
	add_to_group("npcs")
	_build_body()


func interact() -> void:
	var player := get_tree().get_first_node_in_group(SaveSystem.PLAYER_GROUP) as Node3D
	if player:
		face(player.global_position)
	GameState.dialogue_requested.emit(str(npc_data.get("dialogue", "")), npc_id)


## Starts turning to face `point` (world space) for the conversation about to open.
func face(point: Vector3) -> void:
	if not bool(npc_data.get("faces_player", true)):
		return
	var yaw: Variant = facing_yaw(global_transform, point)
	if yaw != null:
		_face_yaw = yaw
		_talking = true


## Yaw (relative to the actor's own facing, +Z) that faces world `point` from an actor at
## `xform`; null when the point is right on top of it.
static func facing_yaw(xform: Transform3D, point: Vector3) -> Variant:
	var local := xform.affine_inverse() * point
	if Vector2(local.x, local.z).length_squared() < 0.0001:
		return null
	return atan2(local.x, local.z)


## One easing step of the body's yaw towards `target` over `delta` seconds.
static func turn_step(current: float, target: float, delta: float) -> float:
	return lerp_angle(current, target, 1.0 - exp(-TURN_SPEED * delta))


## The body's current yaw relative to the placed facing (for tests).
func body_yaw() -> float:
	return _body.rotation.y if _body else 0.0


func _process(delta: float) -> void:
	# The dialogue opens (and locks input) in the same frame as interact(); once it has
	# closed again, turn back to the placed facing.
	if _talking and not GameState.input_locked:
		_talking = false
	if _body == null:
		return
	var target := _face_yaw if _talking else 0.0
	if absf(angle_difference(_body.rotation.y, target)) > 0.001:
		_body.rotation.y = turn_step(_body.rotation.y, target, delta)


func _build_body() -> void:
	var tint := PropFactory.color(str(npc_data.get("color", "slate")))
	var body := StaticBody3D.new()
	body.name = "Body"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.85, 0)
	body.add_child(shape)
	var model := CharacterRig.instantiate(str(npc_data.get("model", "")), str(npc_data.get("idle", "breathe")))
	if model:
		model.name = "Model"
		body.add_child(model)
	else:
		body.add_child(PropFactory.mesh_instance(PropFactory.cylinder(0.25, 0.42, 1.0, 6), tint, Vector3(0, 0.5, 0)))
		var head := SphereMesh.new()
		head.radius = 0.3
		head.height = 0.6
		head.radial_segments = 8
		head.rings = 4
		body.add_child(PropFactory.mesh_instance(head, PropFactory.color("kindle").darkened(0.15), Vector3(0, 1.3, 0)))
	add_child(body)
	_body = body
	var label := Label3D.new()
	label.text = str(npc_data.get("name", npc_id))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.0, 0)
	label.font_size = 40
	label.outline_size = 8
	label.modulate = PropFactory.color("bone")
	add_child(label)
