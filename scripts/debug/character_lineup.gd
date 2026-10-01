extends Node3D
## Art-review scene: every character model side by side (player first), animated by their
## rigs, lit like the game
## (`Atmosphere` in a region's mood: `--mood=<region>`, default Saltmarrow). Saves a
## screenshot and quits when given one:
##   xvfb-run -a godot --rendering-driver opengl3 --path . res://scenes/debug/character_lineup.tscn \
##       -- --screenshot=/abs/out.png [--closeup]
## `--closeup` frames the heads and hands instead of the full bodies.

const SPACING := 1.3


func _ready() -> void:
	LineupLight.add_to(self)
	add_child(PropFactory.mesh_instance(PropFactory.box(Vector3(14, 0.2, 5)), PropFactory.color("driftwood"), Vector3(0, -0.1, 0)))

	var paths: Array[String] = [str(Content.db.game.get("player_model", ""))]
	var styles: Array[String] = ["breathe"]
	var names: Array[String] = ["Wakebearer"]
	for id: String in Content.db.npcs:
		var npc: Dictionary = Content.db.npcs[id]
		paths.append(str(npc.get("model", "")))
		styles.append(str(npc.get("idle", "breathe")))
		names.append(str(npc.get("name", id)))
	var x0 := -SPACING * (paths.size() - 1) * 0.5
	for i in paths.size():
		var model := CharacterRig.instantiate(paths[i], styles[i])
		if model == null:
			push_warning("no model for " + names[i])
			continue
		model.position = Vector3(x0 + SPACING * i, 0, 0)
		model.rotation_degrees.y = 12.0 - 4.0 * i
		add_child(model)
		var label := Label3D.new()
		label.text = names[i]
		label.font_size = 28
		label.outline_size = 6
		label.position = Vector3(x0 + SPACING * i, 0.08, 0.9)
		label.rotation_degrees.x = -60
		add_child(label)

	var closeup := "--closeup" in OS.get_cmdline_user_args()
	var camera := Camera3D.new()
	camera.fov = 40
	camera.position = Vector3(0, 1.4, 3.2) if closeup else Vector3(0, 1.6, 7.6)
	add_child(camera)
	camera.look_at(Vector3(0, 1.1 if closeup else 0.8, 0))
	if closeup:
		camera.fov = 58
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			var shot := Screenshot.new()
			shot.path = arg.get_slice("=", 1)
			add_child(shot)
