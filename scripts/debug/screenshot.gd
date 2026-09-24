class_name Screenshot
extends Node
## Saves a screenshot after the scene settles, then quits. Debug/marketing helper:
##   godot --path . -- --screenshot=/abs/path.png [--dialogue=<id>]
## Needs a real renderer (e.g. xvfb-run + --rendering-driver opengl3); not for --headless.

const SETTLE_FRAMES := 30

var path := ""


func _ready() -> void:
	_capture.call_deferred()


func _capture() -> void:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("Screenshot saved to %s (%s)" % [path, error_string(err)])
	get_tree().quit(0 if err == OK else 1)
