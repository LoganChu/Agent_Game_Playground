extends TestCase
## Day 16 art pass: houses planked on all four sides, the Wrens' old house with its ember sign
## that follows Aldous's confession, Gull's Head's broken net-lofts, and foam rings where legs
## and pilings stand in the sea (`wading`).

const DIR := "res://assets/models/dressing/"


func _props(region: String, file: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop: Dictionary in load_content().get_region(region)["props"]:
		if str(prop.get("model", "")).get_file() == file:
			out.append(prop)
	return out


## Distinct positions along the wall (cm) of the vertices on a house's +X or -X face (just
## outside the walls), from the board edges: a flat wall box has only its two ends.
func _side_heights(node: Node3D, side: float) -> Dictionary:
	var heights := {}
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var p := mi.transform * v
				if absf(p.x - side * 1.327) < 0.012 and absf(p.z) < 1.0:
					heights[roundi(p.z * 100)] = true
	return heights


func test_houses_are_planked_on_every_side() -> void:
	for name: String in ["house_stilt", "house_wren", "house_tall", "house_porch"]:
		var node := (load(DIR + name + ".glb") as PackedScene).instantiate() as Node3D
		for side: float in [-1.0, 1.0]:
			var n := _side_heights(node, side).size()
			assert_true(n >= 10, "%s has boards on its %s side (%d board edges)" % [name, "+X" if side > 0 else "-X", n])
		node.free()


func test_old_stilt_house_is_retired() -> void:
	assert_false(ResourceLoader.exists("res://assets/models/stilt_house.glb"), "the flat-walled stilt house is gone")
	for region: String in ["shingle_point", "saltmarrow", "gulls_head"]:
		assert_eq(_props(region, "stilt_house.glb").size(), 0, "%s no longer uses it" % region)
	assert_true(_props("saltmarrow", "house_stilt.glb").size() >= 2, "the plain houses are the planked stilt house")


func test_wrens_house_stands_by_aldous() -> void:
	var db := load_content()
	var wren := _props("saltmarrow", "house_wren.glb")
	assert_eq(wren.size(), 1, "one Wrens' house")
	var house := JsonUtil.to_vector3(wren[0]["position"])
	for npc: Dictionary in db.get_region("saltmarrow")["npcs"]:
		if npc["npc"] == "aldous":
			assert_true(house.distance_to(JsonUtil.to_vector3(npc["position"])) < 4.0, "Aldous sits by his family's house")
	# Both signs hang on the house's hook: same position and turn as the house.
	for file: String in ["ember_sign.glb", "ember_sign_wrapped.glb"]:
		var signs := _props("saltmarrow", file)
		assert_eq(signs.size(), 1, "%s placed once" % file)
		assert_eq(signs[0]["position"], wren[0]["position"], "%s sits on the house's origin" % file)
		assert_eq(signs[0]["rotation_y"], wren[0]["rotation_y"], "%s turns with the house" % file)


func test_ember_sign_follows_the_confession() -> void:
	var db := load_content()
	for told: String in ["", "full", "grudging"]:
		var state := fresh_state(db)
		state.set_flag("saltmarrow_aldous_confessed", told)
		var shown: Array[String] = []
		for prop: Dictionary in db.get_region("saltmarrow")["props"]:
			if str(prop.get("shape", "")) == "ember_sign" and Conditions.evaluate(prop["if"], state):
				shown.append(str(prop["model"]).get_file())
		var expected := "ember_sign_wrapped.glb" if told.is_empty() else "ember_sign.glb"
		assert_eq(shown, [expected] as Array[String], "confessed '%s' shows exactly %s" % [told, expected])


func test_wrens_door_tells_what_aldous_told() -> void:
	var db := load_content()
	var state := fresh_state(db)
	var text := play_dialogue(db, state, "wrens_door", [])
	assert_true(text.contains("wrapped in sailcloth"), "the sign is hidden before the confession")
	assert_false(text.contains("Aldous sits"), "no Aldous before meeting him")
	state.set_flag("saltmarrow_met_aldous", true)
	assert_true(play_dialogue(db, state, "wrens_door", []).contains("Aldous sits with his back"))
	state.set_flag("saltmarrow_aldous_confessed", "grudging")
	text = play_dialogue(db, state, "wrens_door", [])
	assert_true(text.contains("hangs bare") and text.contains("grey all the way down"), "pressed: uncovered, cold")
	state.set_flag("saltmarrow_aldous_confessed", "full")
	text = play_dialogue(db, state, "wrens_door", [])
	assert_true(text.contains("faces the road") and text.contains("Raked"), "gentle: cleaned, the ash raked")
	assert_false(text.contains("Different hands"), "no sleeve-ember line without the ember")
	state.add_item("keepers_sleeve_ember")
	assert_true(play_dialogue(db, state, "wrens_door", []).contains("Different hands"))


func test_gulls_head_lofts_are_falling_down() -> void:
	var broken := _props("gulls_head", "net_loft_broken.glb")
	var whole := _props("gulls_head", "net_loft.glb")
	assert_eq(broken.size(), 2, "two lofts left to ruin")
	assert_eq(whole.size(), 2, "two still standing")
	# The loft nearest Hesk is one she still mends.
	var hesk := Vector3(-2.6, 0, 4.5)
	var nearest := ""
	var best := INF
	for prop: Dictionary in broken + whole:
		var d := JsonUtil.to_vector3(prop["position"]).distance_to(hesk)
		if d < best:
			best = d
			nearest = str(prop["model"]).get_file()
	assert_eq(nearest, "net_loft.glb", "Hesk's own loft is whole")
	for prop: Dictionary in broken:
		assert_eq(prop["collider"], [3.2, 3.8, 2.6], "the broken loft keeps net_loft's collider")


func test_wading_foam_rings_only_in_the_sea() -> void:
	var db := load_content()
	var region := Region.new()
	region.data = db.get_region("saltmarrow")
	region.field = TerrainField.from_data(region.data["ground"], float(region.data["water_level"]))
	var water := float(region.data["water_level"])
	var with_rings := 0
	for prop: Dictionary in db.get_region("saltmarrow")["props"]:
		if not prop.has("wading"):
			continue
		var node := region._build_prop(prop)
		var foam := node.find_child("WadingFoam", false, false) as MeshInstance3D
		assert_true(foam != null, "%s at %s stands in the sea and gets foam" % [prop["model"].get_file(), prop["position"]])
		if foam:
			with_rings += 1
			var world_y := node.position.y + foam.position.y * node.scale.y
			assert_true(absf(world_y - (water + 0.03)) < 0.01, "foam lies on the water (%.2f)" % world_y)
		node.free()
	assert_true(with_rings >= 4, "the dock and the houses in the shallows have foam (%d)" % with_rings)
	# The same legs on dry land get none.
	var dry := {"model": DIR + "house_stilt.glb", "position": [-12, 0, 6], "wading": [[-1.1, -0.9, 0.13], [1.1, 0.9, 0.13]]}
	var node := region._build_prop(dry)
	assert_true(node.find_child("WadingFoam", false, false) == null, "no foam on dry ground")
	node.free()
	region.free()


func test_wading_mesh_has_a_ring_per_leg() -> void:
	var rings: Array[Vector3] = [Vector3(1, 0.13, 1), Vector3(-1, 0.13, 1), Vector3(0, 0.2, -1)]
	var mesh := FloatingProp.wading_mesh(rings)
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(verts.size(), rings.size() * FloatingProp.WADING_SEGMENTS * 12, "two bands of quads per ring")
	for v in verts:
		var near := rings.any(func(r: Vector3) -> bool: return Vector2(v.x - r.x, v.z - r.z).length() < r.y + FloatingProp.WADING_WIDTH * 1.25)
		assert_true(near, "every vertex belongs to a ring round its leg")


func test_validator_checks_wading() -> void:
	var db := load_content()
	var props: Array = db.regions["saltmarrow"]["props"]
	props.append({"shape": "crate", "position": [0, 0, 0], "wading": [[0, 0, 0.1]]})
	props.append({"model": DIR + "rowboat.glb", "position": [0, 0, 0], "float": {"bob": 0.1}, "wading": [[0, 0, -1], [1, 2]]})
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["'wading' needs a 'model'", "can't go with 'float'", "ring must be [x, z, radius]"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)
