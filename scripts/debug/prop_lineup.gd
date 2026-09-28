extends Node3D
## Art-review scene: every dressing-kit model (assets/models/dressing/) in a labelled grid,
## lit like the lineup. Saves a screenshot and quits when given one:
##   xvfb-run -a godot --rendering-driver opengl3 --path . res://scenes/debug/prop_lineup.tscn \
##       -- --screenshot=/abs/out.png [--only=dock,wreck] [--camera=x,y,z:tx,ty,tz]

const DIR := "res://assets/models/dressing/"
const COLUMNS := 6
const CELL := Vector2(3.6, 4.2)


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = PropFactory.color("silverfog")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = PropFactory.color("silverfog")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.light_color = PropFactory.color("kindle")
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50, -35, 0)
	add_child(sun)

	var only: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7).split(",")
	var names: Array[String] = []
	for file in DirAccess.get_files_at(DIR):
		if file.ends_with(".glb") and (only.is_empty() or file.get_basename() in only):
			names.append(file.get_basename())
	names.sort()
	var rows := ceili(names.size() / float(COLUMNS))
	var width := CELL.x * mini(names.size(), COLUMNS)
	add_child(PropFactory.mesh_instance(PropFactory.box(Vector3(width + 2, 0.2, CELL.y * rows + 2)), PropFactory.color("driftwood"), Vector3(0, -0.1, -CELL.y * (rows - 1) * 0.5)))
	for i in names.size():
		var scene := load(DIR + names[i] + ".glb") as PackedScene
		var model := scene.instantiate() as Node3D
		var cell := Vector3(-width * 0.5 + CELL.x * (i % COLUMNS + 0.5), 0, -CELL.y * (i / COLUMNS))
		model.position = cell
		model.rotation_degrees.y = 25
		add_child(model)
		var label := Label3D.new()
		label.text = names[i]
		label.font_size = 40
		label.outline_size = 8
		label.position = cell + Vector3(0, 0.05, 1.6)
		label.rotation_degrees.x = -60
		add_child(label)

	var camera := Camera3D.new()
	camera.fov = 45
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 7 + rows * 2.5, 9 + rows * 1.5), Vector3(0, 0.8, -CELL.y * (rows - 1) * 0.5))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--camera="):
			var parts := arg.substr(9).split(":")
			camera.look_at_from_position(JsonUtil.to_vector3(Array(parts[0].split_floats(","))), JsonUtil.to_vector3(Array(parts[1].split_floats(","))))
		elif arg.begins_with("--screenshot="):
			var shot := Screenshot.new()
			shot.path = arg.get_slice("=", 1)
			add_child(shot)
