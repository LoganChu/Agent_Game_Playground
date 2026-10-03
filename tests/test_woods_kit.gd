extends TestCase
## Day 20 art pass: the first kit for Thornwold's woods past the bramble wall
## (tools/blender/build_woods.py) — the charcoal folk's hut and sack cart, the Keepers'
## waymarks (bare and lit), a cutter's trail stake, Greyed undergrowth and Greyed pines.

const DIR := "res://assets/models/dressing/"
const KIT: Array[String] = ["collier_hut", "sack_cart", "waymark", "waymark_lit", "trail_stake", "greyed_brush",
		"pine_grey"]
## Built now, placed by *Into the woods*: everything else must already stand in Thornwold.
const NOT_PLACED_YET: Array[String] = ["collier_hut", "waymark_lit"]
const MAX_BYTES := 5 * 1024 * 1024


func _thornwold_props(model: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop: Dictionary in load_content().get_region("thornwold_landing")["props"]:
		if str(prop.get("model", "")) == DIR + model + ".glb":
			out.append(prop)
	return out


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
		var file := FileAccess.open(path, FileAccess.READ)
		assert_true(file.get_length() < MAX_BYTES, "%s.glb is under 5 MB" % name)
		var node := (load(path) as PackedScene).instantiate() as Node3D
		var bounds := Region.mesh_bounds(node)
		assert_true(bounds.position.y > -0.15, "%s sits on its origin (bottom %.2f)" % [name, bounds.position.y])
		assert_true(absf(bounds.get_center().x) < 1.0 and absf(bounds.get_center().z) < 1.2,
				"%s is centred on its origin (%s)" % [name, bounds.get_center()])
		node.free()


func test_kit_placed_past_the_wall() -> void:
	for name in KIT:
		var placed := _thornwold_props(name).size()
		if name in NOT_PLACED_YET:
			assert_eq(placed, 0, "%s waits for Into the woods" % name)
		else:
			assert_true(placed >= 1, "Thornwold uses %s" % name)
	assert_true(_thornwold_props("pine_grey").size() >= 6, "the deep woods are Greyed pines")
	assert_true(_thornwold_props("greyed_brush").size() >= 4, "Greyed undergrowth under them")


## The Greyed pines and brush grow where the Greying is (the woods going grey from the inside),
## never in the camp's clear ground; the trail stake stands on the camp side, in the clear.
func test_greyed_growth_stands_in_the_fog() -> void:
	var region := load_content().get_region("thornwold_landing")
	var areas := Greying.all_areas(region)
	for name: String in ["pine_grey", "greyed_brush", "sack_cart", "waymark"]:
		for prop in _thornwold_props(name):
			var p: Array = prop["position"]
			var depth := Greying.depth_at(areas, Vector2(float(p[0]), float(p[2])))
			assert_true(depth > 0.5, "%s at %s stands in the Greying (depth %.2f)" % [name, p, depth])
	for prop in _thornwold_props("trail_stake"):
		var p: Array = prop["position"]
		assert_true(Greying.depth_at(areas, Vector2(float(p[0]), float(p[2]))) == 0.0, "the trail stake is on clear ground")
		assert_true(float(p[2]) > -16.0, "the trail stake is on the camp side of the wall")


## The lit waymark's lantern glows (emissive glass, so it blooms by day without a light);
## the bare one has nothing lit.
func test_waymark_lantern_glows() -> void:
	var lit := (load(DIR + "waymark_lit.glb") as PackedScene).instantiate()
	var bare := (load(DIR + "waymark.glb") as PackedScene).instantiate()
	assert_true(_emissive_surfaces(lit) >= 1, "the hung lantern's glass is emissive")
	assert_eq(_emissive_surfaces(bare), 0, "the bare waymark's hook is empty")
	lit.free()
	bare.free()
