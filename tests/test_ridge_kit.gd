extends TestCase
## Day 22 art pass: the ridge kit (tools/blender/build_ridge.py) — Thornwold's beacon, the Ridge
## Light (cold and lit), and the keeper's lodge beside it — plus the cold collier hut
## (build_woods.py) and Hob Marl's raking idle.

const DIR := "res://assets/models/dressing/"
const KIT: Array[String] = ["thornwold_beacon", "thornwold_beacon_lit", "keeper_lodge", "collier_hut_cold"]
const WOODS := "thornwold_woods"
const MAX_BYTES := 5 * 1024 * 1024


func _props(model: String, region: String = WOODS) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop: Dictionary in load_content().get_region(region)["props"]:
		if str(prop.get("model", "")) == DIR + model + ".glb":
			out.append(prop)
	return out


func _placed_anywhere(model: String) -> int:
	var count := 0
	for id: String in load_content().regions:
		count += _props(model, id).size()
	return count


func _emissive_surfaces(node: Node) -> int:
	var count := 0
	for mesh_instance: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(i) as StandardMaterial3D
			if material and material.emission_enabled:
				count += 1
	return count


func test_kit_models_exist_small_and_stand_on_their_origin() -> void:
	for name in KIT:
		var path := DIR + name + ".glb"
		assert_true(ResourceLoader.exists(path), "%s.glb exists" % name)
		if not ResourceLoader.exists(path):
			continue
		assert_true(FileAccess.open(path, FileAccess.READ).get_length() < MAX_BYTES, "%s.glb is under 5 MB" % name)
		var node := (load(path) as PackedScene).instantiate() as Node3D
		var bounds := Region.mesh_bounds(node)
		assert_true(bounds.position.y > -0.15, "%s sits on its origin (bottom %.2f)" % [name, bounds.position.y])
		assert_true(absf(bounds.get_center().x) < 1.0 and absf(bounds.get_center().z) < 1.2,
				"%s is centred on its origin (%s)" % [name, bounds.get_center()])
		node.free()


## The beacon is a landmark: taller than anything else in the kit, the Gull's Beacon included.
func test_the_ridge_light_is_a_landmark() -> void:
	var tower := (load(DIR + "thornwold_beacon.glb") as PackedScene).instantiate() as Node3D
	var gull := (load("res://assets/models/gull_beacon.glb") as PackedScene).instantiate() as Node3D
	var height := Region.mesh_bounds(tower).size.y
	assert_true(height > 8.5 and height < 11.0, "the Ridge Light stands ~10 m (%.2f)" % height)
	assert_true(height > Region.mesh_bounds(gull).size.y, "taller than the Gull's stub of stone")
	tower.free()
	gull.free()


## Seen from the woods but out of reach on the ridge until part two builds the road; the lit
## tower is held for the burn.
func test_beacon_and_lodge_stand_on_the_ridge_out_of_reach() -> void:
	var region := load_content().get_region(WOODS)
	var field := TerrainField.from_data(region["ground"])
	var spawn: Array = region["spawn_points"]["default"]
	var reachable := field.reachable_from(float(spawn[0]), float(spawn[2]))
	for name: String in ["thornwold_beacon", "keeper_lodge"]:
		var placed := _props(name)
		assert_eq(placed.size(), 1, "one %s, in the woods" % name)
		assert_eq(_placed_anywhere(name), 1, "%s stands nowhere else" % name)
		for prop in placed:
			var p: Array = prop["position"]
			assert_true(float(p[2]) < -70.0, "%s is on the ridge (z %.1f)" % [name, float(p[2])])
			assert_true(field.height_at(float(p[0]), float(p[2])) > 4.0, "%s stands up on the ridge top" % name)
			assert_false(field.near_reachable(reachable, float(p[0]), float(p[2]), 2.5), "%s is out of reach" % name)
			assert_false(prop.has("if"), "%s stands unconditionally (the beacon is cold until the burn)" % name)
	assert_eq(_placed_anywhere("thornwold_beacon_lit"), 0, "the lit Ridge Light waits for Thornwold's burn")


func test_lit_beacon_glows_and_the_cold_one_does_not() -> void:
	var lit := (load(DIR + "thornwold_beacon_lit.glb") as PackedScene).instantiate()
	var cold := (load(DIR + "thornwold_beacon.glb") as PackedScene).instantiate()
	var lodge := (load(DIR + "keeper_lodge.glb") as PackedScene).instantiate()
	assert_true(_emissive_surfaces(lit) >= 1, "the lit horn panes glow")
	assert_eq(_emissive_surfaces(cold), 0, "the cold lantern cage is dark")
	assert_eq(_emissive_surfaces(lodge), 0, "the lodge's lanterns are all cold (the coal is the Lamp's)")
	lit.free()
	cold.free()
	lodge.free()


## The colliers' clearing: Hob's hut has a fire in it (smoke), the second hut is the cold one.
func test_the_clearing_has_a_warm_hut_and_a_cold_one() -> void:
	var warm := _props("collier_hut")
	var cold := _props("collier_hut_cold")
	assert_eq(warm.size(), 1, "Hob's hut")
	assert_eq(cold.size(), 1, "the cold hut of a collier who went up the ridge")
	assert_true(warm[0].get("smoke") is Array and (warm[0]["smoke"] as Array).size() >= 1, "Hob's hut smokes")
	assert_false(cold[0].has("smoke"), "the cold hut doesn't")
	var a: Array = warm[0]["position"]
	var b: Array = cold[0]["position"]
	assert_true(Vector2(float(a[0]), float(a[2])).distance_to(Vector2(float(b[0]), float(b[2]))) < 14.0,
			"both huts stand in the clearing")


func test_hob_rakes() -> void:
	var hob: Dictionary = load_content().npcs["hob"]
	assert_eq(str(hob.get("idle", "")), "rake", "Hob works his rake while he talks")
	var model := CharacterRig.instantiate(str(hob["model"]), "rake")
	var rig := model.get_node("CharacterRig") as CharacterRig
	assert_eq(rig.style, "rake")
	rig._ready()
	var arm := model.find_child("ArmL", true, false) as Node3D
	var torso := model.find_child("Torso", true, false) as Node3D
	var rest_arm := arm.transform
	var rest_torso := torso.transform
	rig.pose(PI / 4.2)  # the far end of a pull
	var reach := arm.transform
	assert_false(reach.is_equal_approx(rest_arm), "the arms reach with the rake")
	assert_true((torso.transform.basis.y - rest_torso.basis.y).z > 0.05, "he leans forward into the pull")
	rig.pose(PI / 4.2 + PI / 2.1)  # half a cycle later: drawn back
	assert_false(arm.transform.is_equal_approx(reach), "and draws it back")
	model.free()
