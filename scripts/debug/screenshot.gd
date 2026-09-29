class_name Screenshot
extends Node
## Saves a screenshot after the scene settles, then quits. Debug/marketing helper:
##   godot --path . -- --screenshot=/abs/path.png [--dialogue=<id>]
##       [--camera=x,y,z:tx,ty,tz]   fixed camera at x,y,z looking at tx,ty,tz (overviews)
##       [--at=x,z[,yaw_deg]]        put the player on the ground at x,z, camera facing yaw
##       [--settle=frames]           frames to wait before capturing (default 30)
## Needs a real renderer (e.g. xvfb-run + --rendering-driver opengl3); not for --headless.

const SETTLE_FRAMES := 30

var path := ""


func _ready() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var settle := SETTLE_FRAMES
	# Let a --region= travel finish before placing anything.
	for i in 3:
		await get_tree().physics_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera="):
			_place_camera(arg.substr(9))
		elif arg.begins_with("--at="):
			_place_player(arg.substr(5))
		elif arg.begins_with("--settle="):
			settle = int(arg.substr(9))
	for i in settle:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("Screenshot saved to %s (%s)" % [path, error_string(err)])
	get_tree().quit(0 if err == OK else 1)


func _place_camera(spec: String) -> void:
	var parts := spec.split(":")
	var eye := _vec(parts[0])
	var target := _vec(parts[1]) if parts.size() > 1 else Vector3.ZERO
	var camera := Camera3D.new()
	camera.far = 400.0
	add_child(camera)
	camera.look_at_from_position(eye, target)
	camera.make_current()


func _place_player(spec: String) -> void:
	var n := spec.split_floats(",")
	var player := get_tree().get_first_node_in_group(SaveSystem.PLAYER_GROUP) as Player
	var region := get_tree().get_first_node_in_group("region") as Region
	if player == null or region == null or n.size() < 2:
		return
	player.place_at(Vector3(n[0], region.ground_y(n[0], n[1]) + 0.2, n[1]))
	if n.size() > 2:
		(player.get("_camera_yaw") as Node3D).rotation_degrees.y = n[2]


static func _vec(csv: String) -> Vector3:
	var n := csv.split_floats(",")
	return Vector3(n[0], n[1], n[2]) if n.size() == 3 else Vector3.ZERO
