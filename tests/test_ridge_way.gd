extends TestCase
## Day 24 art pass: the way up the woods' north bank (tools/blender/build_ridge.py) — the Keepers'
## log stair in two flights on the region's stair path, the landing under the last pitch with the
## ladder lying fallen, the colliers' traces (a cap on a waymark, a dropped sack) — and the Lamp,
## built ahead of the ridge content.

const DIR := "res://assets/models/dressing/"
const WOODS := "thornwold_woods"
const MAX_BYTES := 5 * 1024 * 1024
## Mirrors STAIR_FLIGHTS in build_ridge.py: each flight climbs `rise` over `length` along its +X.
const FLIGHTS := {"ridge_steps_lower": [7.5, 1.85], "ridge_steps_upper": [6.0, 1.6]}
const KIT: Array[String] = ["ridge_steps_lower", "ridge_steps_upper", "keeper_ladder", "keeper_ladder_fallen",
		"waymark_cap", "sack_dropped"]


func _props(model: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop: Dictionary in load_content().get_region(WOODS)["props"]:
		if str(prop.get("model", "")) == DIR + model + ".glb":
			out.append(prop)
	return out


func _field() -> TerrainField:
	return TerrainField.from_data(load_content().get_region(WOODS)["ground"])


func _bounds(model: String) -> AABB:
	var node := (load(DIR + model + ".glb") as PackedScene).instantiate() as Node3D
	var bounds := Region.mesh_bounds(node)
	node.free()
	return bounds


func test_kit_models_exist_and_are_small() -> void:
	for name in KIT:
		var path := DIR + name + ".glb"
		assert_true(ResourceLoader.exists(path), "%s.glb exists" % name)
		if ResourceLoader.exists(path):
			assert_true(FileAccess.open(path, FileAccess.READ).get_length() < MAX_BYTES, "%s.glb is under 5 MB" % name)


## Each flight model climbs exactly as far as the ground under it: from its origin (the low end,
## snapped to the ground) to `length` along its rotated +X, the ground rises by `rise`.
func test_each_flight_climbs_the_ground_it_stands_on() -> void:
	var field := _field()
	for name: String in FLIGHTS:
		var length: float = FLIGHTS[name][0]
		var rise: float = FLIGHTS[name][1]
		var placed := _props(name)
		assert_eq(placed.size(), 1, "one %s, in the woods" % name)
		var size := _bounds(name).size
		assert_true(absf(size.x - length) < 0.4, "%s is %.1f m long (%.2f)" % [name, length, size.x])
		assert_true(size.y > rise + 0.8 and size.y < rise + 1.4, "%s rises %.2f plus its rail (%.2f)" % [name, rise, size.y])
		for prop in placed:
			var p: Array = prop["position"]
			var along := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(float(prop.get("rotation_y", 0.0))))
			var low := field.height_at(float(p[0]), float(p[2]))
			var high := field.height_at(float(p[0]) + along.x * length, float(p[2]) + along.z * length)
			assert_true(absf(high - low - rise) < 0.2,
					"%s: the ground under it rises %.2f (model %.2f)" % [name, high - low, rise])
			# Every step sits on the ramp, not on the bank above it or over the drop below.
			for i in 5:
				var t := (i + 0.5) / 5.0
				var x := float(p[0]) + along.x * length * t
				var z := float(p[2]) + along.z * length * t
				assert_true(absf(field.height_at(x, z) - (low + rise * t)) < 0.2,
						"%s: step %d on the ramp (ground %.2f, step %.2f)" % [name, i, field.height_at(x, z), low + rise * t])


## The stair can be climbed to the landing, but the ridge stays out of reach until part two
## stands the ladder (or makes the ridge its own region).
func test_the_landing_is_reachable_and_the_ridge_is_not() -> void:
	var region := load_content().get_region(WOODS)
	var field := _field()
	var spawn: Array = region["spawn_points"]["default"]
	var reachable := field.reachable_from(float(spawn[0]), float(spawn[2]))
	var ladder := _props("keeper_ladder_fallen")
	assert_eq(ladder.size(), 1, "the ladder lies on the landing")
	var p: Array = ladder[0]["position"]
	assert_true(field.near_reachable(reachable, float(p[0]), float(p[2]), 1.0), "the landing can be reached")
	assert_true(field.height_at(float(p[0]), float(p[2])) > 3.2, "the landing is high on the bank")
	for cell: Vector2i in reachable:
		var xz := field.vertex_xz(cell.x, cell.y)
		assert_true(field.height_at(xz.x + 0.5, xz.y + 0.5) < 4.8,
				"nothing on the ridge top is reachable (cell %s)" % xz)
		if field.height_at(xz.x + 0.5, xz.y + 0.5) >= 4.8:
			break
	# Day 25: standing the ladder swaps the fallen one for the standing one, same landing.
	var stood := _props("keeper_ladder")
	assert_eq(stood.size(), 1, "one standing ladder")
	assert_eq(str(stood[0].get("if", "")), "flag:thornwold_ladder_stood", "it stands once the player stands it")
	assert_eq(str(ladder[0].get("if", "")), "!flag:thornwold_ladder_stood", "and lies until then")


func test_ladders_stand_and_lie() -> void:
	var standing := _bounds("keeper_ladder")
	var fallen := _bounds("keeper_ladder_fallen")
	assert_true(standing.size.y > 2.7 and standing.size.y < 3.2, "the ladder stands ~3 m (%.2f)" % standing.size.y)
	assert_true(standing.position.y > -0.1, "the standing ladder's feet are at its origin")
	assert_true(fallen.size.y < 0.3, "the fallen ladder lies flat (%.2f)" % fallen.size.y)
	assert_true(fallen.size.x > 3.0, "lying along X (%.2f)" % fallen.size.x)


## The colliers' traces: by the stair, unconditional, nowhere else.
func test_the_colliers_traces_are_by_the_stair() -> void:
	var foot: Array = _props("ridge_steps_lower")[0]["position"]
	for name: String in ["waymark_cap", "sack_dropped"]:
		var placed := _props(name)
		assert_eq(placed.size(), 1, "one %s" % name)
		for prop in placed:
			var p: Array = prop["position"]
			assert_true(not prop.has("if") or str(prop["if"]) == "!flag:thornwold_stair_lantern_hung",
					"%s is there from the start (the cap until a lantern is hung in its place)" % name)
			var d := Vector2(float(p[0]) - float(foot[0]), float(p[2]) - float(foot[2])).length()
			assert_true(d < 10.0, "%s is by the stair (%.1f m from its foot)" % [name, d])
	var cap := _bounds("waymark_cap")
	var bare := _bounds("waymark")
	assert_true(cap.size.y > 2.2 and absf(cap.size.y - bare.size.y) < 0.05, "the cap hangs on a waymark-high hook")


## Built ahead of the ridge content: the Lamp carries a lit lantern (the only light it has); the
## rig contract is checked with every character in test_characters.gd.
func test_the_lamp_carries_a_lit_lantern() -> void:
	var path := "res://assets/models/characters/lamp.glb"
	assert_true(ResourceLoader.exists(path), "lamp.glb exists")
	var model := CharacterRig.instantiate(path)
	var parts := CharacterRig.find_parts(model)
	var glowing: Array[String] = []
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(i) as StandardMaterial3D
			if material and material.emission_enabled:
				glowing.append(str(mesh_instance.name))
	assert_eq(glowing.size(), 1, "one glowing surface: the lantern (%s)" % [glowing])
	assert_true(parts.has("ArmR") and str(glowing[0]) == str((parts["ArmR"] as Node).name) if not glowing.is_empty() else false,
			"the lantern is carried in the right hand (on ArmR)")
	var height := Region.mesh_bounds(model).size.y
	assert_true(height > 2.0 and height < 2.6, "the lantern pole stands over the hood (%.2f)" % height)
	model.free()
