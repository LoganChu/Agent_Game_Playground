extends Node3D
## Art-review scene: every character model side by side (player first), animated by their
## rigs, lit like the game
## (`Atmosphere` in a region's mood: `--mood=<region>`, default Saltmarrow). Saves a
## screenshot and quits when given one:
##   xvfb-run -a godot --rendering-driver opengl3 --path . res://scenes/debug/character_lineup.tscn \
##       -- --screenshot=/abs/out.png [--closeup] [--only=hob,lamp] [--pose=1.2] [--turn=90]
## Models a region placement poses an NPC in (e.g. `hob_seated`) follow the NPCs; character
## figure props (character models as dressing) after them, and models nothing uses yet are
## added last, labelled "(unplaced)".
## `--closeup` frames the heads and hands instead of the full bodies. `--pose=<seconds>` freezes
## every rig at that moment of its idle (to compare beats of an idle, e.g. a chisel tap);
## `--turn=<degrees>` turns every model (90 = seen from its left side).

const SPACING := 1.3
const UNPLACED_DIR := "res://assets/models/characters/"


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
	# Poses a region placement gives an NPC there (Hob seated at the camp), after the NPCs.
	for region_id: String in Content.db.regions:
		for placement: Dictionary in Content.db.regions[region_id].get("npcs", []):
			var placed_model := str(placement.get("model", ""))
			if placed_model.is_empty() or placed_model in paths:
				continue
			paths.append(placed_model)
			styles.append(str(placement.get("idle", "breathe")))
			names.append("%s (%s)" % [Content.db.npcs.get(str(placement.get("npc", "")), {}).get("name", "?"), placed_model.get_file().get_basename()])
	# Figures: character models stood in a region as set dressing with an idle (the Unmoored).
	for region_id: String in Content.db.regions:
		for prop: Dictionary in Content.db.regions[region_id].get("props", []):
			var figure := str(prop.get("model", ""))
			if not prop.has("idle") or figure in paths:
				continue
			paths.append(figure)
			styles.append(str(prop["idle"]))
			names.append(figure.get_file().get_basename().capitalize() + " (figure)")
	# Character models no NPC wears yet (built ahead of their content), by file name.
	for file in DirAccess.get_files_at(UNPLACED_DIR):
		var path := UNPLACED_DIR + file
		if file.ends_with(".glb") and path not in paths:
			paths.append(path)
			styles.append("breathe")
			names.append(file.get_basename().capitalize() + " (unplaced)")
	var only := PackedStringArray()
	var pose_at := -1.0
	var turn := 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--pose="):
			pose_at = float(arg.get_slice("=", 1))
		elif arg.begins_with("--turn="):
			turn = float(arg.get_slice("=", 1))
	if not only.is_empty():  # keep the listed models (file names without .glb), in that order
		var keep: Array[int] = []
		for stem in only:
			for i in paths.size():
				if paths[i].get_file().get_basename() == stem:
					keep.append(i)
		paths.assign(keep.map(func(i: int) -> String: return paths[i]))
		styles.assign(keep.map(func(i: int) -> String: return styles[i]))
		names.assign(keep.map(func(i: int) -> String: return names[i]))
	var x0 := -SPACING * (paths.size() - 1) * 0.5
	for i in paths.size():
		var model := CharacterRig.instantiate(paths[i], styles[i])
		if model == null:
			push_warning("no model for " + names[i])
			continue
		model.position = Vector3(x0 + SPACING * i, 0, 0)
		model.rotation_degrees.y = 12.0 - 4.0 * i + turn
		add_child(model)
		if pose_at >= 0.0:
			var rig := model.get_node("CharacterRig") as CharacterRig
			rig.set_process(false)
			rig.pose(pose_at)
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
