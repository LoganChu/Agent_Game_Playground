class_name Player
extends CharacterBody3D
## Third-person Wakebearer controller: camera-relative movement, orbit camera, and
## interaction with the nearest Interactable in reach.

signal focus_changed(target: Interactable)

const SPEED := 5.0
const ACCEL := 12.0
const TURN_SPEED := 10.0
const CAMERA_TURN_SPEED := 2.2
const MOUSE_SENSITIVITY := 0.005
const GRAVITY := 20.0

var focus: Interactable = null

var _camera_yaw: Node3D
var _camera_pitch: Node3D
var _camera: Camera3D
var _visual: Node3D
var _sensor: Area3D


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
		_camera_yaw.rotation.y += Input.get_axis("camera_right", "camera_left") * CAMERA_TURN_SPEED * delta
	var basis_y := Basis(Vector3.UP, _camera_yaw.rotation.y)
	var direction := basis_y * Vector3(input.x, 0, input.y)
	var target := direction * SPEED
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta * SPEED)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta * SPEED)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if direction.length_squared() > 0.01:
		var yaw := atan2(direction.x, direction.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, yaw, TURN_SPEED * delta)
	# Safety net: never fall forever through a gap in the terrain.
	if global_position.y < -30.0:
		global_position = _respawn_point()
		velocity = Vector3.ZERO
	_update_focus()


func _unhandled_input(event: InputEvent) -> void:
	if GameState.input_locked:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion := event as InputEventMouseMotion
		_camera_yaw.rotation.y -= motion.relative.x * MOUSE_SENSITIVITY
		_camera_pitch.rotation.x = clampf(_camera_pitch.rotation.x - motion.relative.y * MOUSE_SENSITIVITY, deg_to_rad(-60), deg_to_rad(-5))
	elif event.is_action_pressed("interact") and focus and is_instance_valid(focus):
		get_viewport().set_input_as_handled()
		focus.interact()


func place_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO


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
	add_child(_visual)
	# Cloak, head and the ember in the right hand — the warmest thing on screen.
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
	light.light_energy = 0.4
	light.omni_range = 3.5
	light.position = Vector3(0.38, 0.9, 0.2)
	_visual.add_child(light)


func _build_camera() -> void:
	_camera_yaw = Node3D.new()
	_camera_yaw.name = "CameraYaw"
	_camera_yaw.top_level = false
	_camera_yaw.position = Vector3(0, 1.2, 0)
	add_child(_camera_yaw)
	_camera_pitch = Node3D.new()
	_camera_pitch.name = "CameraPitch"
	_camera_pitch.rotation.x = deg_to_rad(-28)
	_camera_yaw.add_child(_camera_pitch)
	var arm := SpringArm3D.new()
	arm.spring_length = 7.0
	arm.margin = 0.3
	arm.collision_mask = 1 << (Layers.WORLD - 1)
	arm.add_excluded_object(get_rid())
	_camera_pitch.add_child(arm)
	_camera = Camera3D.new()
	_camera.fov = 55
	_camera.current = true
	arm.add_child(_camera)


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
