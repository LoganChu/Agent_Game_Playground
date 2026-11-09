class_name NpcActor
extends Interactable
## An NPC placed in a region. Visuals are the NPC's Blender-made character model (`model`,
## animated by a CharacterRig in its `idle` style), or a primitive figure tinted by the NPC's
## signature color when it has none; talking starts the NPC's dialogue. While talking the
## NPC turns to face the player (unless its data says `"faces_player": false`, e.g. Hesk at
## her net), and turns back to its placed facing when the dialogue closes. A working idle
## ("scrape") puts the work down while talking, and the name over the head is hidden then.
## A working idle with a sound in data/audio.json `work` is heard from the NPC on every stroke.
## An NPC carrying a lit lantern can say `"halo": {"part": "ArmR"}` (optional `size`,
## `strength`): a LanternHalo hangs on that part's glowing surface and moves with the arm, so
## the lantern reads through the fog (Brother Iver's lamp on Lowsong).
## A placement's `circuit` (Day 89: `{"center": [x, z], "radius": r, "speed": m/s, "clockwise"?: bool}`) walks
## the NPC round and round a circle on the ground from where it was placed (the woman on Cindermoor's ring path);
## it stops while talking, while a modal holds input, and while the Wakebearer stands in its way. How far round it has
## got is kept in the world state (`WorldState.walkers`, saved), so a reload or a return finds it there.
## Day 94: an NPC who comes or goes mid-visit (Region.refresh_conditional, animated) fades in or out over
## FADE_SECONDS instead of cutting. One leaving is out of the "npcs" group and can't be talked to from the start.

## How quickly the NPC turns towards the player and back (1/s, exponential ease).
const TURN_SPEED := 6.0
## A walking NPC holds while the Wakebearer is this close (m), so it never walks into them.
const CIRCUIT_HOLD := 1.6
## How long an NPC takes to fade in on arriving, or out on leaving, mid-visit (s).
const FADE_SECONDS := 0.8

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
## The placement's circuit (empty = stands where placed), its angle round the centre, and the region's ground height.
var _circuit: Dictionary = {}
var _circuit_angle := 0.0
var _ground := Callable()
## Fade: current opacity (1 = solid), where it's heading, and whether the actor frees itself at 0.
var _opacity := 1.0
var _opacity_target := 1.0
var _leaving := false


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


## Starts invisible and fades in (an NPC arriving mid-visit). Call before it enters the tree or after.
func fade_in() -> void:
	_opacity = 0.0
	_opacity_target = 1.0
	_apply_opacity()


## Fades out and frees itself (an NPC leaving mid-visit). It leaves the "npcs" group and stops being something to
## talk to or bump into at once, so nothing finds it while it fades.
func fade_out() -> void:
	_leaving = true
	_opacity_target = 0.0
	remove_from_group("npcs")
	collision_layer = 0
	prompt = ""
	if _body is CollisionObject3D:
		(_body as CollisionObject3D).collision_layer = 0
	if _label:
		_label.visible = false


## True while fading out (tests).
func is_leaving() -> bool:
	return _leaving


## The NPC's current opacity (1 = solid; tests).
func opacity() -> float:
	return _opacity


func can_interact() -> bool:
	return not _leaving


func _apply_opacity() -> void:
	if _body == null:
		return
	for node in _body.find_children("*", "GeometryInstance3D", true, false):
		var mesh := node as GeometryInstance3D
		mesh.transparency = 1.0 - _opacity
		mesh.visible = _opacity > 0.0
	if _label:
		_label.modulate.a = _opacity


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


## True while the floating name is on screen (for tests).
func is_nameplate_shown() -> bool:
	return _label != null and _label.visible


## The body's current yaw relative to the placed facing (for tests).
func body_yaw() -> float:
	return _body.rotation.y if _body else 0.0


## Sets the NPC walking round `circuit` (a validated placement `circuit`), from its current position, at the
## heights `ground` (x, z) -> y gives. Call once it has been positioned.
func walk_circuit(circuit: Dictionary, ground: Callable) -> void:
	_circuit = circuit
	_ground = ground
	var c := circuit_centre()
	_circuit_angle = atan2(position.z - c.y, position.x - c.x)
	# Day 91: pick the walk up where it was (a reload, or coming back), if it's the same circle.
	var seen: Variant = GameState.world.walker_angle(npc_id, circuit)
	if seen != null:
		_circuit_angle = float(seen)
	_place_on_circuit()


## True if this NPC walks a circuit.
func walks_circuit() -> bool:
	return not _circuit.is_empty()


## The circuit's centre (x, z).
func circuit_centre() -> Vector2:
	var at: Array = _circuit.get("center", [0, 0])
	return Vector2(float(at[0]), float(at[1]))


## Whether the walker should hold this frame: talking, a modal up, or the Wakebearer within CIRCUIT_HOLD.
func circuit_holds() -> bool:
	if _talking or GameState.input_locked:
		return true
	var player := get_tree().get_first_node_in_group(SaveSystem.PLAYER_GROUP) as Node3D if is_inside_tree() else null
	if player == null:
		return false
	var d := player.global_position - global_position
	return Vector2(d.x, d.z).length() < CIRCUIT_HOLD


## One step along the circuit of `delta` seconds (unless holding); returns the distance walked.
func step_circuit(delta: float) -> float:
	if _circuit.is_empty():
		return 0.0
	var speed := float(_circuit.get("speed", 0.7))
	if circuit_holds():
		speed = 0.0
	if speed > 0.0:
		var turn := circuit_turn()
		_circuit_angle = wrapf(_circuit_angle + turn * speed * delta / float(_circuit["radius"]), -PI, PI)
		_place_on_circuit()
		GameState.world.note_walker(npc_id, _circuit, _circuit_angle)
	if _rig:
		_rig.move_speed = speed
	return speed * delta


## +1 when the walk goes clockwise seen from above with north (-Z) up the map (the angle from +X toward +Z grows),
## -1 for anticlockwise (the default).
func circuit_turn() -> float:
	return 1.0 if bool(_circuit.get("clockwise", false)) else -1.0


func _place_on_circuit() -> void:
	var c := circuit_centre()
	var r := float(_circuit["radius"])
	var x := c.x + r * cos(_circuit_angle)
	var z := c.y + r * sin(_circuit_angle)
	position = Vector3(x, float(_ground.call(x, z)) if _ground.is_valid() else position.y, z)
	# Face along the way round: the tangent, turned for a clockwise walker.
	var turn := circuit_turn()
	var ahead := Vector2(-sin(_circuit_angle), cos(_circuit_angle)) * turn
	rotation.y = atan2(ahead.x, ahead.y)


func _process(delta: float) -> void:
	if _opacity != _opacity_target:
		_opacity = move_toward(_opacity, _opacity_target, delta / FADE_SECONDS)
		_apply_opacity()
	if _leaving and _opacity <= 0.0:
		queue_free()
		return
	step_circuit(delta)
	# The dialogue opens (and locks input) in the same frame as interact(); once it has
	# closed again, turn back to the placed facing.
	if _talking and not GameState.input_locked:
		_talking = false
	if _rig:
		_rig.resting = _talking
	# The dialogue box names the speaker; their floating name would only sit over the framing.
	# Every other nameplate hides too while a modal holds input (dialogue, menus, the act
	# card): they showed through the card's shade.
	if _label:
		_label.visible = not _talking and not GameState.input_locked and not _leaving
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


## Hangs a halo on the glowing (emissive) surface of the model part `halo.part`; false when the
## part or a glowing surface on it isn't there.
static func add_lantern_halo(model: Node, halo: Dictionary) -> bool:
	var part := model.find_child(str(halo.get("part", "ArmR")), true, false) as MeshInstance3D
	if part == null or part.mesh == null:
		return false
	var at: Variant = glow_centre(part.mesh)
	if at == null:
		return false
	part.add_child(LanternHalo.build(at, float(halo.get("size", LanternHalo.SIZE)),
		float(halo.get("strength", LanternHalo.STRENGTH))))
	return true


## The centre of a mesh's first emissive surface (a lantern's lit horn), or null.
static func glow_centre(mesh: Mesh) -> Variant:
	for i in mesh.get_surface_count():
		var material := mesh.surface_get_material(i) as BaseMaterial3D
		if material == null or not material.emission_enabled:
			continue
		var points: PackedVector3Array = mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
		if points.is_empty():
			continue
		var box := AABB(points[0], Vector3.ZERO)
		for point in points:
			box = box.expand(point)
		return box.get_center()
	return null


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
		if npc_data.get("halo") is Dictionary:
			add_lantern_halo(model, npc_data["halo"])
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
	if _opacity < 1.0:
		_apply_opacity()
