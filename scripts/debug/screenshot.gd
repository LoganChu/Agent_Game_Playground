class_name Screenshot
extends Node
## Saves a screenshot after the scene settles, then quits. Debug/marketing helper:
##   godot --path . -- --screenshot=/abs/path.png [--dialogue=<id>]
##       [--camera=x,y,z:tx,ty,tz]   fixed camera at x,y,z looking at tx,ty,tz (overviews)
## Needs a real renderer (e.g. xvfb-run + --rendering-driver opengl3); not for --headless.

const SETTLE_FRAMES := 30

var path := ""


func _ready() -> void:
	_capture.call_deferred()


func _capture() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera="):
			_place_camera(arg.substr(9))
	for i in SETTLE_FRAMES:
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


static func _vec(csv: String) -> Vector3:
	var n := csv.split_floats(",")
	return Vector3(n[0], n[1], n[2]) if n.size() == 3 else Vector3.ZERO
