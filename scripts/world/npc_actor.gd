class_name NpcActor
extends Interactable
## An NPC placed in a region. Visuals are the NPC's Blender-made character model (`model`,
## animated by a CharacterRig in its `idle` style), or a primitive figure tinted by the NPC's
## signature color when it has none; talking starts the NPC's dialogue. While talking the
## NPC turns to face the player (unless its data says `"faces_player": false`, e.g. Hesk at
## her net), and turns back to its placed facing when the dialogue closes. A working idle
## ("scrape") puts the work down while talking, and the name over the head is hidden then.
## A working idle with a sound in data/audio.json `work` is heard from the NPC on every stroke.

## How quickly the NPC turns towards the player and back (1/s, exponential ease).
const TURN_SPEED := 6.0

var npc_id := ""
var npc_data: Dictionary = {}

## The body's yaw while talking, relative to the placed rotation (0 = placed facing).
var _face_yaw := 0.0
var _talking := false
var _body: Node3D
var _rig: CharacterRig
var _label: Label3D
## Body yaw to start from (set by take_over before the body is built).
var _start_yaw := 0.0
## The work sound's player (a working idle with a `work` sound) and its sound id.
var _work_player: AudioStreamPlayer3D
var _work_id := ""
## Work strokes heard so far (tests).
var work_sounds_played := 0


func setup(id: String, data: Dictionary) -> void:
	npc_id = id
	npc_data = data
	name = "Npc_" + id
	_refresh_prompt()


## "Talk to <name>" and the name over the head, by the NPC's conditional `names`.
func _refresh_prompt() -> void:
	var shown := ContentDatabase.npc_display_name(npc_data, GameState.world, npc_id)
	prompt = "Talk to " + shown
	if _label:
		_label.text = shown


func _ready() -> void:
	super._ready()
	add_to_group("npcs")
	if npc_data.has("names"):
		GameState.world.flag_changed.connect(func(_id: String, _v: Variant) -> void: _refresh_prompt())
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


## Carries on from `before`, the actor this one replaces at the same placement mid-visit (a
## model swap while talking): its turn towards the player and the body's current yaw.
func take_over(before: NpcActor) -> void:
	_face_yaw = before._face_yaw
	_talking = before._talking
	_start_yaw = before.body_yaw()


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
	if _rig:
		_rig.resting = _talking
	# The dialogue box names the speaker; their floating name would only sit over the framing.
	if _label:
		_label.visible = not _talking
	if _body == null:
		return
	var target := _face_yaw if _talking else 0.0
	if absf(angle_difference(_body.rotation.y, target)) > 0.001:
		_body.rotation.y = turn_step(_body.rotation.y, target, delta)


## The idle's work sound (data/audio.json `work`), played from the hands on each stroke.
func _add_work_sound(body: Node3D) -> void:
	var spec: Variant = (Content.db.audio.get("work", {}) as Dictionary).get(_rig.style)
	if not spec is Dictionary or not (spec as Dictionary).has("sound"):
		return
	_work_id = str(spec["sound"])
	SoundBank.warm(Content.db, [_work_id])
	_work_player = AudioStreamPlayer3D.new()
	_work_player.name = "WorkSound"
	_work_player.position = Vector3(0, 0.5, 0.6)
	_work_player.max_distance = float(spec.get("range", SoundEmitter.RANGE))
	_work_player.unit_size = _work_player.max_distance * 0.25
	_work_player.volume_db = linear_to_db(maxf(0.0001, float(spec.get("volume", 1.0))))
	_work_player.bus = SoundBank.bus(Content.db, _work_id)
	body.add_child(_work_player)
	_rig.work_stroke.connect(_on_work_stroke)


func _on_work_stroke() -> void:
	if not SoundBank.is_ready(Content.db, _work_id):
		return
	_work_player.stream = SoundBank.stream(Content.db, _work_id)
	_work_player.pitch_scale = randf_range(0.92, 1.08)
	work_sounds_played += 1
	if _work_player.is_inside_tree():
		_work_player.play()


func _exit_tree() -> void:
	if _work_player:
		_work_player.stop()
		_work_player.stream = null


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
		_rig = model.get_node_or_null("CharacterRig") as CharacterRig
		if _rig:
			_add_work_sound(body)
	else:
		body.add_child(PropFactory.mesh_instance(PropFactory.cylinder(0.25, 0.42, 1.0, 6), tint, Vector3(0, 0.5, 0)))
		var head := SphereMesh.new()
		head.radius = 0.3
		head.height = 0.6
		head.radial_segments = 8
		head.rings = 4
		body.add_child(PropFactory.mesh_instance(head, PropFactory.color("kindle").darkened(0.15), Vector3(0, 1.3, 0)))
	body.rotation.y = _start_yaw
	add_child(body)
	_body = body
	var label := Label3D.new()
	_label = label
	label.text = ContentDatabase.npc_display_name(npc_data, GameState.world, npc_id)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.0, 0)
	label.font_size = 40
	label.outline_size = 8
	label.modulate = PropFactory.color("bone")
	add_child(label)
