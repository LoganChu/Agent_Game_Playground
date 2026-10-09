extends TestCase
## Day 14 art pass: village house variants and gate posts replace the last procedural
## stand-ins, extra prop `colliders`, floating boats with foam rings, and NPCs that turn to
## face the player while talking.

const DIR := "res://assets/models/dressing/"


func test_no_procedural_stand_ins_left_in_act_one() -> void:
	var db := load_content()
	for id: String in ["shingle_point", "saltmarrow", "gulls_head"]:
		for prop: Dictionary in db.get_region(id)["props"]:
			assert_true(prop.has("model"), "%s prop %s at %s is a Blender model" % [id, prop.get("shape"), prop.get("position")])


func test_village_has_house_variants() -> void:
	var db := load_content()
	var models := {}
	for prop: Dictionary in db.get_region("saltmarrow")["props"]:
		if str(prop.get("shape", "")) == "house":
			models[str(prop["model"]).get_file()] = true
	for name: String in ["house_stilt.glb", "house_wren.glb", "house_tall.glb", "house_porch.glb", "net_loft_broken.glb",
			"net_loft_mended.glb"]:
		assert_true(models.has(name), "Saltmarrow uses %s" % name)


func test_houses_share_the_stilt_house_deck() -> void:
	# Deck at 1.0 m (so the stilt house's collider fits every variant); the porch reaches out
	# in front (+Z in Godot) and its steps come down to the ground.
	for name: String in ["house_stilt", "house_wren", "house_tall", "house_porch"]:
		var node := (load(DIR + name + ".glb") as PackedScene).instantiate() as Node3D
		var found := false
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var box := mi.transform * mi.get_aabb()
			if box.position.y < 0.05:
				found = true  # stilts / steps reach the ground
		assert_true(found, "%s stands on the ground" % name)
		node.free()


func test_porch_gets_its_extra_colliders() -> void:
	var db := load_content()
	var region := Region.new()
	var porch: Dictionary = {}
	for prop: Dictionary in db.get_region("saltmarrow")["props"]:
		if str(prop.get("model", "")).ends_with("house_porch.glb"):
			porch = prop
	assert_true(not porch.is_empty(), "Mara's porch house is placed")
	var node := region._build_prop(porch)
	# Walk colliders only (the camera blocker over the roof is on its own layer).
	var shapes := node.find_children("*", "CollisionShape3D", true, false).filter(
		func(s: Node) -> bool: return (s.get_parent() as CollisionObject3D).get_collision_layer_value(Layers.WORLD))
	assert_eq(shapes.size(), 1 + (porch["colliders"] as Array).size(), "house + porch + steps colliders")
	var furthest := 0.0
	for shape: CollisionShape3D in shapes:
		furthest = maxf(furthest, shape.position.z)
	assert_true(furthest > 2.5, "the steps' collider sits in front of the porch (z %.2f)" % furthest)
	node.free()
	region.free()


func test_validator_checks_colliders_and_float() -> void:
	var db := load_content()
	var props: Array = db.regions["saltmarrow"]["props"]
	props.append({"shape": "crate", "position": [0, 0, 0], "colliders": [{"size": [1, 1, 1]}], "float": {"bob": 0.1}})
	props.append({"model": DIR + "rowboat.glb", "position": [0, 0, 0], "colliders": [{"size": [1, 1]}],
			"float": {"bob": "lots", "wobble": 1, "foam": [1, -2]}})
	db.npcs["tam"]["faces_player"] = "sometimes"
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["'colliders' needs a 'model'", "'float' needs a 'model'", "collider must be {size",
			"float bob must be a number", "unknown key 'wobble'", "foam must be [rx, rz]", "faces_player must be true or false"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)


func test_boats_float_with_foam() -> void:
	var db := load_content()
	var region := Region.new()
	var floating := 0
	for prop: Dictionary in db.get_region("saltmarrow")["props"]:
		if not prop.has("float"):
			continue
		floating += 1
		assert_false(bool(prop.get("snap", true)), "%s floats at an absolute water height" % prop["model"])
		var node := region._build_prop(prop)
		assert_true(node is FloatingProp, "%s is wrapped in a FloatingProp" % prop["model"])
		var fp := node as FloatingProp
		assert_true(fp.find_child("Foam", false, false) != null, "%s has a foam ring" % prop["model"])
		fp._apply(0.0)
		var a := fp.model_offset()
		fp._apply(fp.period * 0.25)
		assert_true(absf(fp.model_offset() - a) > 0.01, "%s bobs over a swell" % prop["model"])
		assert_true(absf(fp.model_offset()) <= fp.bob + 0.001, "bob stays within its amplitude")
		node.free()
	assert_true(floating >= 3, "the ferry, fishing boat and rowboat float (%d)" % floating)
	region.free()


func test_foam_ring_fades_outward() -> void:
	var mesh := FloatingProp.foam_mesh(1.0, 2.0)
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_true(verts.size() >= FloatingProp.FOAM_SEGMENTS * 12, "two bands of quads")
	var inner_alpha := 0.0
	var outer_alpha := 1.0
	for i in verts.size():
		var r := Vector2(verts[i].x / 1.0, verts[i].z / 2.0).length()
		assert_true(absf(verts[i].y) < 0.001, "the ring is flat")
		if r < 0.9:
			inner_alpha = maxf(inner_alpha, colors[i].a)
		elif r > 1.3:
			outer_alpha = minf(outer_alpha, colors[i].a)
	assert_true(inner_alpha > 0.7, "foam is dense at the hull")
	assert_true(outer_alpha < 0.05, "foam fades to nothing outside")


func test_npc_turns_to_face_the_player() -> void:
	# An NPC placed facing +Z (rotation 0) with the player due east turns +90°.
	var at := Transform3D(Basis.IDENTITY, Vector3(5, 0, 5))
	assert_true(is_equal_approx(float(NpcActor.facing_yaw(at, Vector3(8, 0, 5))), PI / 2), "turns towards +X")
	# Placed turned 180° (facing -Z), a player behind it (+Z) is straight behind: ±180°.
	var turned := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	assert_true(is_equal_approx(absf(float(NpcActor.facing_yaw(turned, Vector3(0, 0, 3)))), PI), "turns right round")
	assert_eq(NpcActor.facing_yaw(at, Vector3(5, 1, 5)), null, "no turn for a point right on top")
	# The turn eases in and settles.
	var yaw := 0.0
	for i in 60:
		yaw = NpcActor.turn_step(yaw, PI / 2, 1.0 / 30.0)
	assert_true(absf(yaw - PI / 2) < 0.01, "settles facing the player after 2 s (%.3f)" % yaw)


func test_hesk_keeps_mending() -> void:
	var db := load_content()
	assert_eq(db.get_npc("hesk").get("faces_player"), false, "Hushed Hesk doesn't look up from her net")
	var actor := NpcActor.new()
	actor.setup("hesk", db.get_npc("hesk"))
	actor.face(Vector3(3, 0, 0))
	assert_eq(actor._talking, false, "Hesk doesn't turn")
	actor.free()
