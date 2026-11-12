class_name Player
extends CharacterBody3D
## Third-person Wakebearer controller: camera-relative movement, orbit camera, and
## interaction with the nearest Interactable in reach.

signal focus_changed(target: Interactable)
## A footfall on the ground (in step with the walk; not while airborne).
signal stepped

const SPEED := 5.0
const ACCEL := 12.0
const TURN_SPEED := 10.0
const CAMERA_TURN_SPEED := 2.2
const MOUSE_SENSITIVITY := 0.005
const GRAVITY := 20.0
## Where the ember sits in the Wakebearer model's right hand (model space, rest pose).
const EMBER_HAND := Vector3(-0.3, 0.85, 0.3)
const EMBER_LIGHT_ENERGY := 0.6
## Orbit camera: full distance, the radius of the sphere swept ahead of it (keeps the near
## plane out of walls and cliffs), and how fast it eases back out after being pushed in.
const CAMERA_DISTANCE := 7.0
## Day 100: a small interior may shorten the arm's reach (region `camera_distance`, CAMERA_REACH_MIN..CAMERA_DISTANCE),
## so a wall at the Wakebearer's back doesn't snap a 7 m arm in to a step behind them in every corner.
const CAMERA_REACH_MIN := 3.0
## Day 100: when the arm at the player's own pitch is blocked short of CAMERA_LIFT_CLEAR of its reach (the lantern
## room's cradle, a knee wall, a hut at the Wakebearer's back), the camera rises over it: each CAMERA_LIFT_PITCHES
## (degrees, shallowest first) steeper than the player's own is probed with the arm's sphere, and the first that clears
## is eased to at CAMERA_LIFT_SPEED (1/s). The probe never reads the arm, so the lift can't feed back on itself.
const CAMERA_LIFT_PITCHES: Array[float] = [-38.0, -48.0, -58.0]
const CAMERA_LIFT_CLEAR := 0.6
const CAMERA_LIFT_SPEED := 2.5
const CAMERA_PROBE_RADIUS := 0.3
const CAMERA_RETURN_SPEED := 4.0
## Pushed in closer than this (a wall at the player's back), the camera would sit inside the
## Wakebearer: the body is hidden (the ember's light stays) until it pulls back out. Between
## CAMERA_HIDE_BODY and CAMERA_FADE_BODY it fades rather than popping.
const CAMERA_HIDE_BODY := 0.9
const CAMERA_FADE_BODY := 1.6
const CAMERA_PITCH := -28.0
const CAMERA_PIVOT := Vector3(0, 1.2, 0)
## Talking to an NPC (GameSettings.dialogue_camera), the camera eases round to look past the
## Wakebearer's shoulder at them: DIALOGUE_SIDE off the line between the two, a little lower
## and closer, with the pivot slid DIALOGUE_PIVOT_SHARE of the way towards them (at most
## DIALOGUE_PIVOT_MAX). It eases back to where the player left it once the dialogue closes.
const DIALOGUE_DISTANCE := 4.4
const DIALOGUE_PITCH := -14.0
const DIALOGUE_SIDE := 0.8
const DIALOGUE_PIVOT_SHARE := 0.4
const DIALOGUE_PIVOT_MAX := 1.2
const DIALOGUE_EASE_SECONDS := 0.7
## Day 94: a second NPC who speaks in the conversation (the Provost with Hild) joins the shot if they stand within
## FRAME_JOIN_MAX of the Wakebearer. The camera looks at the middle of everyone framed, swung FRAME_GROUP_SIDE off
## the line, and backs off by FRAME_GROUP_BACK of their spread (at most FRAME_GROUP_BACK_MAX); it eases there at
## FRAME_RETARGET_SPEED (1/s) rather than cutting.
const FRAME_JOIN_MAX := 8.0
const FRAME_GROUP_SIDE := 0.5
const FRAME_GROUP_BACK := 0.6
const FRAME_GROUP_BACK_MAX := 2.2
const FRAME_RETARGET_SPEED := 3.0
## Day 100: someone seated (CharacterRig.SEATED_STYLES: Aldous on his bench, Hesk at her net) is framed a touch lower:
## the pivot drops DIALOGUE_LOW_DROP and the camera looks across at DIALOGUE_LOW_PITCH rather than down, so the seated
## figure clears the dialogue box. A group shot drops by the share of those framed who sit.
const DIALOGUE_LOW_DROP := 0.4
const DIALOGUE_LOW_PITCH := -9.0

var focus: Interactable = null

var _camera_yaw: Node3D
var _camera_pitch: Node3D
var _camera: Camera3D
var _camera_arm: SpringArm3D
## Current camera distance: snaps in when something blocks, eases back out (no popping).
var _camera_distance := CAMERA_DISTANCE
## The arm's full reach here (CAMERA_DISTANCE, or a region's shorter `camera_distance`).
var _camera_reach := CAMERA_DISTANCE
## The lift's target pitch and the pitch shown (radians; 0 = no lift: the player's own).
var _lift_target := 0.0
var _shown_lift := 0.0
var _visual: Node3D
var _sensor: Area3D
var _rig: CharacterRig
var _ember_light: OmniLight3D
## Ember strength (1 = full; the Greying drains it) and the flicker clock.
var _ember := 1.0
var _flicker_time := 0.0
## After the ending (Day 97, Greying.ember_gone): the hand holds no ember — the light out, the glow dark.
var _ember_gone := false
## Where the NPC we're talking to stands (the Wakebearer turns to it while input is locked).
var _talk_to: Variant = null
## The player's own camera pitch (the mouse sets it; dialogue framing blends away from it).
var _pitch := deg_to_rad(CAMERA_PITCH)
## Conversation framing: how far in (0..1), the view yaw it frames to, and the pivot's slide.
var _framing := 0.0
var _framing_on := false
var _frame_yaw := 0.0
var _frame_pivot := Vector3.ZERO
var _frame_distance := DIALOGUE_DISTANCE
## Where everyone framed stands (world space), and the framing actually shown, easing to the targets above.
var _framed: Array[Vector3] = []
## Whether each one framed sits, the share of them who do (the target) and the share shown, easing to it.
var _framed_low: Array[bool] = []
var _frame_low := 0.0
var _shown_low := 0.0
var _shown_yaw := 0.0
var _shown_pivot := Vector3.ZERO
var _shown_distance := DIALOGUE_DISTANCE
## The model's meshes and their current fade (1 = opaque), for the close-camera fade.
var _body_meshes: Array[GeometryInstance3D] = []
var _body_opacity := 1.0


func _ready() -> void:
	name = "Player"
	add_to_group(SaveSystem.PLAYER_GROUP)
	collision_layer = 0
	set_collision_layer_value(Layers.PLAYER, true)
	collision_mask = 0
	set_collision_mask_value(Layers.WORLD, true)
	_build_body()
	_build_camera()
	_build_sensor()


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not GameState.input_locked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		_camera_yaw.rotation.y += Input.get_axis("camera_right", "camera_left") * CAMERA_TURN_SPEED * GameSettings.current().yaw_factor() * delta
	var basis_y := Basis(Vector3.UP, view_yaw())
	var direction := basis_y * Vector3(input.x, 0, input.y)
	var target := direction * SPEED
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta * SPEED)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta * SPEED)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if _rig:
		_rig.move_speed = Vector2(velocity.x, velocity.z).length()
	if direction.length_squared() > 0.01:
		var yaw := atan2(direction.x, direction.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, yaw, TURN_SPEED * delta)
	elif _talk_to != null:
		_face_talk_target(delta)
	# Safety net: never fall forever through a gap in the terrain.
	if global_position.y < -30.0:
		global_position = _respawn_point()
		velocity = Vector3.ZERO
	_update_focus()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.input_locked:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var turn := GameSettings.current().mouse_turn((event as InputEventMouseMotion).relative, MOUSE_SENSITIVITY)
		_camera_yaw.rotation.y -= turn.x
		_pitch = clampf(_pitch - turn.y, deg_to_rad(-60), deg_to_rad(-5))
	elif event.is_action_pressed("interact") and focus and is_instance_valid(focus):
		get_viewport().set_input_as_handled()
		if focus is NpcActor:
			talk_to(focus as NpcActor)
		else:
			focus.interact()


## Opens a conversation with `npc`: the Wakebearer turns to them and (by the setting) the
## camera frames the two.
func talk_to(npc: NpcActor) -> void:
	_talk_to = npc.global_position
	if GameSettings.current().dialogue_camera:
		frame_towards(npc.global_position - global_position, npc.is_seated())
	npc.interact()


func place_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO


## Turns the Wakebearer to face along `direction` (horizontal) with the camera behind them
## (a region's `spawn_facing`).
func face_towards(direction: Vector3) -> void:
	var to := Vector3(direction.x, 0.0, direction.z)
	if to.length() < 0.01:
		return
	_visual.rotation.y = atan2(to.x, to.z)
	_camera_yaw.rotation.y = atan2(-to.x, -to.z)
	_camera_pitch.rotation.y = 0.0


## The way the Wakebearer's body faces (for tests).
func heading() -> float:
	return _visual.rotation.y


## Dims the ember-hand light as the Greying drains the ember (1 = full).
func set_ember(value: float) -> void:
	_ember = clampf(value, 0.0, 1.0)
	_update_ember_light()


## After the lit or released ending the hand holds no ember (Greying.ember_gone): its light goes out and the
## glowing surfaces in the hand go to a cold coal (the released ending's "black coal the size of a hazelnut").
func set_ember_gone(gone: bool) -> void:
	if gone == _ember_gone:
		return
	_ember_gone = gone
	var coal: StandardMaterial3D = null
	if gone:
		coal = StandardMaterial3D.new()
		coal.albedo_color = PropFactory.color("coal")
		coal.roughness = 0.9
	for node in _body_meshes:
		var mesh_node := node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		for i in mesh_node.mesh.get_surface_count():
			var material := mesh_node.mesh.surface_get_material(i)
			if material and material.resource_name.ends_with("_glow"):
				mesh_node.set_surface_override_material(i, coal)
	_update_ember_light()


## True while the hand holds no ember (after the lit or released ending).
func is_ember_gone() -> bool:
	return _ember_gone


## The ember breathes: a slow, uneven flicker on top of its strength.
func _process(delta: float) -> void:
	_flicker_time += delta
	_update_ember_light()
	_update_lift(delta)
	_update_framing(delta)
	_update_camera_distance(delta)


## Swings the orbit camera round the player (the title screen's slow drift).
func turn_camera(radians: float) -> void:
	_camera_yaw.rotation.y = wrapf(_camera_yaw.rotation.y + radians, -PI, PI)


## The orbit camera's yaw as the player set it (for tests).
func camera_yaw() -> float:
	return _camera_yaw.rotation.y


## The yaw the camera actually looks along: the player's plus any conversation framing.
func view_yaw() -> float:
	return _camera_yaw.rotation.y + _camera_pitch.rotation.y


## How far the conversation framing has eased in (0 = the player's own camera, 1 = framed).
func framing() -> float:
	return _framing


## Starts framing a conversation with someone standing `offset` away (while input stays locked); `low` if they sit.
func frame_towards(offset: Vector3, low: bool = false) -> void:
	var to := Vector3(offset.x, 0.0, offset.z)
	if to.length() < 0.3:
		return
	_frame_yaw = dialogue_yaw(view_yaw(), to)
	_frame_pivot = (to * DIALOGUE_PIVOT_SHARE).limit_length(DIALOGUE_PIVOT_MAX)
	_frame_distance = DIALOGUE_DISTANCE
	_framed = [_here() + to]
	_framed_low = [low]
	_frame_low = 1.0 if low else 0.0
	if _framing <= 0.0:
		_shown_yaw = _frame_yaw
		_shown_pivot = _frame_pivot
		_shown_distance = _frame_distance
		_shown_low = _frame_low
	_framing_on = true


## Brings someone else standing at `point` (world space) into the conversation's shot: a second speaker (`low` if they
## sit). Returns whether the shot changed (not framing, already framed, or too far away: no).
func frame_also(point: Vector3, low: bool = false) -> bool:
	if not _framing_on or _framed.is_empty():
		return false
	for framed: Vector3 in _framed:
		if Vector2(framed.x - point.x, framed.z - point.z).length() < 0.5:
			return false
	var here := _here()
	if Vector2(point.x - here.x, point.z - here.z).length() > FRAME_JOIN_MAX:
		return false
	_framed.append(point)
	_framed_low.append(low)
	_frame_low = float(_framed_low.count(true)) / _framed_low.size()
	var centre := Vector3.ZERO
	for framed: Vector3 in _framed:
		centre += framed
	centre /= _framed.size()
	var spread := 0.0
	for a: Vector3 in _framed:
		for b: Vector3 in _framed:
			spread = maxf(spread, Vector2(a.x - b.x, a.z - b.z).length())
	var to := Vector3(centre.x - here.x, 0.0, centre.z - here.z)
	if to.length() < 0.3:
		to = Vector3(sin(_frame_yaw + PI), 0.0, cos(_frame_yaw + PI)) * 0.3
	_frame_yaw = dialogue_yaw(_shown_yaw, to, FRAME_GROUP_SIDE)
	_frame_pivot = (to * DIALOGUE_PIVOT_SHARE).limit_length(DIALOGUE_PIVOT_MAX)
	_frame_distance = DIALOGUE_DISTANCE + minf(spread * FRAME_GROUP_BACK, FRAME_GROUP_BACK_MAX)
	return true


## Where the Wakebearer stands (world space; the local position outside the tree, for tests).
func _here() -> Vector3:
	return global_position if is_inside_tree() else position


## How many people the conversation's shot frames (0 when not framing; tests).
func framed_count() -> int:
	return _framed.size() if _framing_on else 0


## The share of those framed who sit (0..1; the shot's target, tests).
func framed_low() -> float:
	return _frame_low if _framing_on else 0.0


## The view yaw that frames someone `to` away (horizontal): looking along the line from the
## Wakebearer to them, swung `side` (DIALOGUE_SIDE) to whichever side is nearer the `current` yaw.
static func dialogue_yaw(current: float, to: Vector3, side: float = DIALOGUE_SIDE) -> float:
	var behind := atan2(-to.x, -to.z)
	var left := wrapf(behind + side, -PI, PI)
	var right := wrapf(behind - side, -PI, PI)
	return left if absf(angle_difference(current, left)) <= absf(angle_difference(current, right)) else right


## Eases the framing in while a framed conversation holds input, and back out after; the
## offset rides on the pitch node, so the player's own yaw and pitch are kept underneath.
func _update_framing(delta: float) -> void:
	if _framing_on and not GameState.input_locked and _framing > 0.0:
		_framing_on = false
		_framed.clear()
		_framed_low.clear()
	var target := 1.0 if _framing_on else 0.0
	_framing = move_toward(_framing, target, delta / DIALOGUE_EASE_SECONDS)
	# A second speaker joining moves the shot: ease there.
	var k := 1.0 - exp(-FRAME_RETARGET_SPEED * delta)
	_shown_yaw = lerp_angle(_shown_yaw, _frame_yaw, k)
	_shown_pivot = _shown_pivot.lerp(_frame_pivot, k)
	_shown_distance = lerpf(_shown_distance, _frame_distance, k)
	_shown_low = lerpf(_shown_low, _frame_low, k)
	var w := smoothstep(0.0, 1.0, _framing)
	_camera_pitch.rotation.y = angle_difference(_camera_yaw.rotation.y, _shown_yaw) * w
	_camera_pitch.rotation.x = lerpf(own_pitch(), deg_to_rad(lerpf(DIALOGUE_PITCH, DIALOGUE_LOW_PITCH, _shown_low)), w)
	_camera_yaw.position = CAMERA_PIVOT + (_shown_pivot + Vector3.DOWN * DIALOGUE_LOW_DROP * _shown_low) * w
	if _camera_arm:
		_camera_arm.spring_length = lerpf(_camera_reach, minf(_shown_distance, maxf(_camera_reach, DIALOGUE_DISTANCE)), w)


## The pitch the camera looks down at outside a conversation: the player's own, or steeper while lifted.
func own_pitch() -> float:
	return minf(_pitch, _shown_lift) if _shown_lift < 0.0 else _pitch


## Which pitch the lift wants (radians, 0 = none), from how far the arm clears at the player's own pitch
## (`base_clear`) and at each of CAMERA_LIFT_PITCHES (`clears`, same order), out of `reach`. Only pitches steeper than
## `base` count; the shallowest that clears CAMERA_LIFT_CLEAR of the reach wins; none clearing = no lift.
static func choose_lift(base: float, base_clear: float, clears: Array[float], reach: float) -> float:
	var need := reach * CAMERA_LIFT_CLEAR
	if base_clear >= need:
		return 0.0
	for i in mini(clears.size(), CAMERA_LIFT_PITCHES.size()):
		var pitch := deg_to_rad(CAMERA_LIFT_PITCHES[i])
		if pitch < base - 0.01 and clears[i] >= need:
			return pitch
	return 0.0


## Probes the arm at the player's pitch and the lift pitches (outside conversations), and eases the lift.
func _update_lift(delta: float) -> void:
	if _camera_arm == null or not is_inside_tree():
		return
	var target := 0.0
	if not _framing_on and _framing <= 0.0:
		var clears: Array[float] = []
		var base_clear := _arm_clearance(_pitch)
		if base_clear < _camera_reach * CAMERA_LIFT_CLEAR:
			for degrees: float in CAMERA_LIFT_PITCHES:
				clears.append(_arm_clearance(deg_to_rad(degrees)))
		target = choose_lift(_pitch, base_clear, clears, _camera_reach)
	_lift_target = target
	var from := _shown_lift if _shown_lift < 0.0 else _pitch
	var to := target if target < 0.0 else _pitch
	var eased := lerpf(from, to, 1.0 - exp(-CAMERA_LIFT_SPEED * delta))
	_shown_lift = 0.0 if target >= 0.0 and absf(eased - _pitch) < 0.005 else eased


## How far the arm's sphere travels from the pivot at `pitch` (the current view yaw) before it hits something.
func _arm_clearance(pitch: float) -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _camera_arm.shape
	query.collision_mask = _camera_arm.collision_mask
	query.exclude = [get_rid()]
	var origin := _camera_yaw.global_position
	query.transform = Transform3D(Basis.IDENTITY, origin)
	var direction := Basis(Vector3.UP, view_yaw()) * Basis(Vector3.RIGHT, pitch) * Vector3.BACK
	query.motion = direction * _camera_reach
	var hit := space.cast_motion(query)
	return _camera_reach * (hit[0] if hit.size() > 0 else 1.0)


## Whether the camera is lifted over something at the player's back (tests, debug).
func is_lifted() -> bool:
	return _lift_target < 0.0


## Sets the arm's full reach for this region (`camera_distance`; 0 or anything out of range = the usual 7 m).
func set_camera_reach(reach: float) -> void:
	_camera_reach = clampf(reach, CAMERA_REACH_MIN, CAMERA_DISTANCE) if reach > 0.0 else CAMERA_DISTANCE
	if _camera_arm and _framing <= 0.0:
		_camera_arm.spring_length = _camera_reach


## The arm's full reach here (tests).
func camera_reach() -> float:
	return _camera_reach


## How far the camera currently sits behind the pivot (for tests).
func camera_distance() -> float:
	return _camera_distance


## The spring arm sweeps a sphere toward the full distance on the world and camera layers;
## the camera jumps in to the hit at once (never through a wall) and eases back out.
func _update_camera_distance(delta: float) -> void:
	if _camera_arm == null:
		return
	var target := _camera_arm.get_hit_length()
	_camera_distance = next_camera_distance(_camera_distance, target, delta)
	_camera.position = Vector3(0, 0, _camera_distance)
	_apply_body_opacity(body_opacity(_camera_distance))


## Fades every mesh of the body (not the ember's light); hidden outright at 0.
func _apply_body_opacity(opacity: float) -> void:
	if opacity == _body_opacity:
		return
	_body_opacity = opacity
	for mesh in _body_meshes:
		mesh.visible = opacity > 0.0
		mesh.transparency = 1.0 - opacity


## Whether the body is drawn with the camera `distance` behind the pivot.
static func shows_body(distance: float) -> bool:
	return body_opacity(distance) > 0.0


## How opaque the body is drawn with the camera `distance` behind the pivot: gone inside
## CAMERA_HIDE_BODY, fading in up to CAMERA_FADE_BODY, solid beyond.
static func body_opacity(distance: float) -> float:
	if distance < CAMERA_HIDE_BODY:
		return 0.0
	return smoothstep(CAMERA_HIDE_BODY, CAMERA_FADE_BODY, distance)


static func next_camera_distance(current: float, target: float, delta: float) -> float:
	if target <= current:
		return target
	return move_toward(current, target, CAMERA_RETURN_SPEED * delta)


func _update_ember_light() -> void:
	if _ember_light == null:
		return
	var t := _flicker_time
	var flicker := 1.0 + 0.08 * sin(t * 2.3) + 0.05 * sin(t * 5.7 + 1.3) + 0.03 * sin(t * 11.0)
	_ember_light.light_energy = 0.0 if _ember_gone else EMBER_LIGHT_ENERGY * lerpf(0.3, 1.0, _ember) * flicker


## Turns the Wakebearer towards the NPC being talked to; stops once the dialogue has closed.
func _face_talk_target(delta: float) -> void:
	if not GameState.input_locked:
		_talk_to = null
		return
	var to := (_talk_to as Vector3) - global_position
	if Vector2(to.x, to.z).length_squared() > 0.0001:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(to.x, to.z), minf(1.0, TURN_SPEED * 0.6 * delta))


func _respawn_point() -> Vector3:
	var region := get_tree().get_first_node_in_group("region") as Region
	return region.spawn_position("default") if region else Vector3(0, 2, 0)


func _update_focus() -> void:
	var best: Interactable = null
	var best_dist := INF
	if not GameState.input_locked:
		for area in _sensor.get_overlapping_areas():
			var it := area as Interactable
			if it == null or not it.can_interact() or it.is_queued_for_deletion():
				continue
			var d := global_position.distance_squared_to(it.global_position)
			if d < best_dist:
				best_dist = d
				best = it
	if best != focus:
		focus = best
		focus_changed.emit(focus)


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	shape.shape = capsule
	shape.position = Vector3(0, 0.8, 0)
	add_child(shape)
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.rotation.y = PI  # models face +Z; start facing away from the camera
	add_child(_visual)
	# Blender-made Wakebearer (game.json `player_model`); primitive cloak/head/ember fallback.
	var ember_pos := Vector3(0.38, 0.9, 0.2)
	var model := CharacterRig.instantiate(str(Content.db.game.get("player_model", "")))
	if model:
		model.name = "Model"
		_visual.add_child(model)
		_rig = model.get_node("CharacterRig") as CharacterRig
		_rig.footfall.connect(func() -> void:
			if is_on_floor():
				stepped.emit())
		ember_pos = EMBER_HAND
	else:
		_visual.add_child(PropFactory.mesh_instance(PropFactory.cylinder(0.18, 0.45, 1.1, 6), PropFactory.color("abyss"), Vector3(0, 0.55, 0)))
		var head := SphereMesh.new()
		head.radius = 0.27
		head.height = 0.54
		head.radial_segments = 8
		head.rings = 4
		_visual.add_child(PropFactory.mesh_instance(head, PropFactory.color("bone"), Vector3(0, 1.3, 0)))
		var ember := SphereMesh.new()
		ember.radius = 0.09
		ember.height = 0.18
		ember.radial_segments = 6
		ember.rings = 3
		_visual.add_child(PropFactory.mesh_instance(ember, PropFactory.color("ember"), Vector3(0.38, 0.8, 0.2), true))
	var light := OmniLight3D.new()
	light.name = "EmberLight"
	light.light_color = PropFactory.color("ember")
	light.light_energy = EMBER_LIGHT_ENERGY
	light.omni_range = 3.5
	light.position = ember_pos
	_visual.add_child(light)
	_ember_light = light
	_body_meshes.clear()
	for node in _visual.find_children("*", "GeometryInstance3D", true, false):
		_body_meshes.append(node as GeometryInstance3D)


func _build_camera() -> void:
	_camera_yaw = Node3D.new()
	_camera_yaw.name = "CameraYaw"
	_camera_yaw.top_level = false
	_camera_yaw.position = CAMERA_PIVOT
	add_child(_camera_yaw)
	_camera_pitch = Node3D.new()
	_camera_pitch.name = "CameraPitch"
	_camera_pitch.rotation.x = _pitch
	_camera_yaw.add_child(_camera_pitch)
	# The arm only measures (no children); `_update_camera_distance` places the camera.
	var arm := SpringArm3D.new()
	arm.name = "CameraArm"
	arm.spring_length = CAMERA_DISTANCE
	arm.margin = 0.1
	var probe := SphereShape3D.new()
	probe.radius = CAMERA_PROBE_RADIUS
	arm.shape = probe
	arm.collision_mask = (1 << (Layers.WORLD - 1)) | (1 << (Layers.CAMERA - 1))
	arm.add_excluded_object(get_rid())
	_camera_pitch.add_child(arm)
	_camera_arm = arm
	_camera = Camera3D.new()
	_camera.fov = 55
	_camera.current = true
	_camera.position = Vector3(0, 0, CAMERA_DISTANCE)
	_camera_pitch.add_child(_camera)


func _build_sensor() -> void:
	_sensor = Area3D.new()
	_sensor.name = "InteractSensor"
	_sensor.collision_layer = 0
	_sensor.collision_mask = 0
	_sensor.set_collision_mask_value(Layers.INTERACTABLE, true)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	shape.position = Vector3(0, 0.9, 0)
	_sensor.add_child(shape)
	add_child(_sensor)
