extends TestCase
## Sculpted ground: TerrainField heights/walkability/reachability, the mesh + collider it
## builds, region placement on the ground, and the validator's ground checks.


func _island() -> Dictionary:
	# A flat 0.5 m plateau, a 3 m tableland reached by one ramp, sea all around.
	return {
		"bounds": [-20, -30, 20, 20], "base": -2.0, "roughness": 0.0, "ragged": 0.0,
		"land": [
			{"rect": [-8, -2, 8, 10], "height": 0.5, "falloff": 3},
			{"ellipse": [0, -16, 6, 6], "height": 3.0, "falloff": 0.8},
			{"path": [[0, -1, 0.5], [0, -10.5, 3.0]], "width": 3, "falloff": 1},
		],
	}


func test_heights_follow_features() -> void:
	var field := TerrainField.from_data(_island(), -0.25)
	assert_true(absf(field.height_at(0, 5) - 0.5) < 0.001, "plateau at 0.5")
	assert_true(absf(field.height_at(0, -16) - 3.0) < 0.001, "tableland at 3.0")
	assert_true(absf(field.height_at(15, 15) - -2.0) < 0.001, "open sea at base")
	var mid := field.height_at(0, -6)
	assert_true(mid > 0.8 and mid < 2.8, "ramp climbs between them (%s)" % mid)


func test_height_at_matches_mesh_vertices_and_triangles() -> void:
	var data := _island()
	data["roughness"] = 0.3
	var field := TerrainField.from_data(data, -0.25)
	for iz in [0, 7, 20]:
		for ix in [0, 5, 13]:
			var p := field.vertex_xz(ix, iz)
			assert_true(absf(field.height_at(p.x, p.y) - field.vertex_height(ix, iz)) < 0.0001, "vertex %s,%s" % [ix, iz])
	# Mid-diagonal of a cell is the average of the two diagonal corners (00-11 split).
	var p00 := field.vertex_xz(4, 4)
	var expected := (field.vertex_height(4, 4) + field.vertex_height(5, 5)) * 0.5
	assert_true(absf(field.height_at(p00.x + 0.5, p00.y + 0.5) - expected) < 0.0001, "diagonal split")


func test_reachability_ramp_cliffs_and_sea() -> void:
	var field := TerrainField.from_data(_island(), -0.25)
	var reach := field.reachable_from(0, 5)
	assert_true(field.near_reachable(reach, 0, -16, 0.5), "tableland reachable up the ramp")
	assert_false(field.near_reachable(reach, 15, 15, 1.0), "open sea not reachable")
	assert_true(field.is_wet(field.vertex_height(field.cell_of(15, 15).x, field.cell_of(15, 15).y)), "sea is behind the wall")
	var no_ramp := _island()
	(no_ramp["land"] as Array).pop_back()
	var cut := TerrainField.from_data(no_ramp, -0.25)
	assert_false(cut.near_reachable(cut.reachable_from(0, 5), 0, -16, 0.5), "cliffs block the tableland without the ramp")


func test_colors_paint_cliff_shore_ground() -> void:
	var data := _island()
	data["colors"] = {"ground": "moss", "shore": "driftwood", "cliff": "slate", "seabed": "abyss"}
	data["paint"] = [{"rect": [-1, 2, 1, 4], "color": "coal"}]
	var field := TerrainField.from_data(data, -0.25)
	assert_eq(field.color_name(0, 3, 0.5, 0.0), "coal", "paint wins")
	assert_eq(field.color_name(5, 5, 0.5, 2.0), "slate", "steep = cliff")
	assert_eq(field.color_name(5, 5, 0.5, 0.0), "moss", "flat high = ground")
	assert_eq(field.color_name(5, 5, -0.1, 0.0), "driftwood", "just above water = shore")
	assert_eq(field.color_name(5, 5, -1.5, 0.0), "abyss", "underwater = seabed")


func test_builder_mesh_faces_up_and_collider_walls_the_sea() -> void:
	var field := TerrainField.from_data(_island(), -0.25)
	var body := TerrainBuilder.build(field)
	var mesh: ArrayMesh = (body.get_node("GroundMesh") as MeshInstance3D).mesh
	var normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var up := 0
	for n in normals:
		if n.y > 0.0:
			up += 1
	assert_eq(up, normals.size(), "every ground triangle faces up (front face visible from above)")
	var shape := (body.get_child(body.get_child_count() - 1) as CollisionShape3D).shape as ConcavePolygonShape3D
	var faces := shape.get_faces()
	assert_eq(faces.size(), (field.cols - 1) * (field.rows - 1) * 6, "collider covers the grid")
	var wall := 0
	for v in faces:
		if absf(v.y - (-0.25 + TerrainField.WALL_HEIGHT)) < 0.001:
			wall += 1
	assert_true(wall > faces.size() / 2, "sea vertices raised into the shore wall (%d of %d)" % [wall, faces.size()])
	body.free()


func test_region_places_content_on_the_ground() -> void:
	# Region.build needs the Content autoload; placement only needs data + field.
	var db := load_content()
	var region := Region.new()
	region.data = db.get_region("gulls_head")
	region.field = TerrainField.from_data(region.data["ground"], float(region.data["water_level"]))
	var spawn := region.spawn_position("default")
	var raw := JsonUtil.to_vector3(region.data["spawn_points"]["default"])
	assert_true(absf(spawn.y - (region.ground_y(spawn.x, spawn.z) + raw.y)) < 0.001, "spawn y is an offset above ground")
	for object: Dictionary in region.data["objects"]:
		if object["id"] == "gulls_beacon":
			assert_true(region.place(object["position"]).y > 2.0, "beacon object sits up on the headland")
	assert_eq(region.place([1, -0.4, 2], false), Vector3(1, -0.4, 2), "snap:false keeps absolute y")
	region.free()


func test_validator_checks_ground() -> void:
	var db := load_content()
	var region: Dictionary = db.regions["gulls_head"]
	var ground: Dictionary = region["ground"]
	(ground["land"] as Array).remove_at(2)  # no ramp: the beacon is stranded on the headland
	(ground["land"] as Array).append({"rect": [0, 0, 1, 1], "ellipse": [0, 0, 1, 1]})
	(ground["paint"] as Array).append({"path": [[0, 0]], "color": "no_such_colour"})
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["object 'gulls_beacon'", "can't be reached on foot", "exactly one of rect/ellipse/path",
			"malformed 'path'", "no_such_colour"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)
	var edge := load_content()
	edge.regions["saltmarrow"]["ground"]["bounds"] = [-10, -10, 10, 10]
	var edge_validator := ContentValidator.new(edge)
	assert_false(edge_validator.validate(), "tiny bounds should fail")
	assert_true(edge_validator.report().contains("reaches the edge of ground.bounds"), "edge check")


func test_pier_decks_the_sea() -> void:
	var data := _island()
	# The plateau's south shore is around z=12; a pier runs out from it to z=18.
	data["piers"] = [{"rect": [-1, 9, 1, 18], "deck": 0.4}]
	var field := TerrainField.from_data(data, -0.25)
	var reach := field.reachable_from(0, 5)
	assert_true(field.near_reachable(reach, 0, 17.5, 0.1), "pier end reachable on foot")
	assert_false(field.near_reachable(reach, 3, 17.5, 0.5), "sea beside the pier still walled")
	assert_eq(field.surface_at(0, 16), 0.4, "surface over the pier is the deck")
	assert_true(field.height_at(0, 16) < -0.25, "rendered ground under the pier stays seabed")
	var c := field.cell_of(0, 16)
	assert_eq(field.collision_height(c.x, c.y), 0.4, "collider raised to the deck, not the wall")
	var side := field.cell_of(3, 16)
	assert_eq(field.collision_height(side.x, side.y), -0.25 + TerrainField.WALL_HEIGHT, "wall beside the pier")


func test_validator_checks_piers() -> void:
	var db := load_content()
	var ground: Dictionary = db.regions["saltmarrow"]["ground"]
	ground["piers"] = [
		{"rect": [5.5, 12, 7, 18], "deck": 0.3},  # off-grid
		{"rect": [-20, 20, -18, 22], "deck": 0.3},  # out at sea, touches no land
		{"rect": [0, 0, 1, 1], "deck": -1.0},  # under water
		{"rect": [0, 0], "deck": 0.3},
	]
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["must lie on the ground grid", "not above the water", "need a 'rect'"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)
	var sea := load_content()
	sea.regions["saltmarrow"]["ground"]["piers"] = [{"rect": [-20, 20, -18, 22], "deck": 0.3}]
	var sea_validator := ContentValidator.new(sea)
	assert_false(sea_validator.validate(), "a pier out at sea should fail")
	assert_true(sea_validator.report().contains("can't be walked onto"), "unreachable pier reported")
