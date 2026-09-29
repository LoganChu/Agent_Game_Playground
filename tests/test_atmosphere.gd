extends TestCase
## Atmosphere & lighting: region light moods (and their story overrides), the validator's
## light checks, the water's baked shore depth, and the Atmosphere node applying a mood.


func _near(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) < eps


func test_light_defaults_and_types() -> void:
	var light := RegionMood.light({}, WorldState.new())
	for key: String in RegionMood.LIGHT_DEFAULTS:
		assert_true(light.has(key), "default light has %s" % key)
	assert_true(light["sun_energy"] is float and light["sun_color"] is String, "values are typed")
	var partial := RegionMood.light({"light": {"sun_energy": 2}}, WorldState.new())
	assert_true(partial["sun_energy"] is float and _near(partial["sun_energy"], 2.0), "ints become floats")
	assert_eq(partial["sky_top"], RegionMood.LIGHT_DEFAULTS["sky_top"], "unset keys keep defaults")


func test_relit_beacon_warms_every_act_one_region() -> void:
	var db := load_content()
	for region_id: String in ["shingle_point", "saltmarrow", "gulls_head"]:
		var region: Dictionary = db.regions[region_id]
		var state := fresh_state(db)
		var before := RegionMood.light(region, state)
		state.start_quest("a_light_for_saltmarrow", "feed_the_beacon")
		state.complete_quest("a_light_for_saltmarrow")
		var after := RegionMood.light(region, state)
		assert_true(float(after["sun_energy"]) > float(before["sun_energy"]), "%s: the sun is stronger once the beacon burns" % region_id)
		for key: String in RegionMood.LIGHT_COLOR_KEYS:
			assert_true(Color.html_is_valid(str(after[key])) or PropFactory.PALETTE.has(after[key]), "%s: %s resolves" % [region_id, key])
	var gulls: Dictionary = db.regions["gulls_head"]
	var dark := RegionMood.light(gulls, fresh_state(db))
	assert_eq(dark["sky_top"], "slate", "Gull's Head's sky is drained before the burn")


func test_validator_checks_light() -> void:
	var db := load_content()
	var light: Dictionary = db.regions["saltmarrow"]["light"]
	light["sun_colour"] = "kindle"
	light["sky_top"] = "hotpink"
	light["sun_energy"] = "bright"
	(light["overrides"] as Array).append({"sun_energy": 2.0})
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["light has unknown key 'sun_colour'", "sky_top has unknown color 'hotpink'",
			"sun_energy must be a number", "light override needs an 'if'"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)


func _saltmarrow_field(db: ContentDatabase) -> TerrainField:
	var region: Dictionary = db.regions["saltmarrow"]
	return TerrainField.from_data(region["ground"], float(region["water_level"]))


func test_water_depth_is_baked_from_the_ground() -> void:
	var db := load_content()
	var field := _saltmarrow_field(db)
	var level := field.water_level
	var spawn: Array = db.regions["saltmarrow"]["spawn_points"]["default"]
	assert_eq(WaterBuilder.depth_at(field, level, spawn[0], spawn[2]), 0.0, "dry land has no depth")
	var corner := field.bounds.position + Vector2(0.5, 0.5)
	assert_eq(WaterBuilder.depth_at(field, level, corner.x, corner.y), 1.0, "the open sea at the bounds is deep")
	assert_eq(WaterBuilder.depth_at(field, level, 500, 500), 1.0, "beyond the grid is deep")
	assert_eq(WaterBuilder.depth_at(null, level, 0, 0), 1.0, "no field: deep everywhere")
	# Somewhere between the spawn and the sea there is a shallow band for the foam line.
	var shallow := 0
	for i in 200:
		var x := lerpf(field.bounds.position.x, field.bounds.end.x, i / 199.0)
		var d := WaterBuilder.depth_at(field, level, x, 0.0)
		if d > 0.0 and d < 0.25:
			shallow += 1
	assert_true(shallow > 0, "a shore has shallows")


func test_water_mesh_has_shore_and_skirt() -> void:
	var db := load_content()
	var field := _saltmarrow_field(db)
	var mesh := WaterBuilder.build_mesh(field, field.water_level)
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	assert_eq(verts.size(), colors.size(), "one depth per vertex")
	assert_true(indices.size() % 3 == 0 and indices.size() > 0, "triangles")
	var far := 0.0
	var foam := 0
	for i in verts.size():
		far = maxf(far, absf(verts[i].x))
		assert_true(is_zero_approx(verts[i].y), "flat at the water level (waves are in the shader)")
		if colors[i].r > 0.0 and colors[i].r < 0.15:
			foam += 1
	assert_true(far > WaterBuilder.SKIRT * 0.9, "the skirt reaches the horizon (%s)" % far)
	assert_true(foam > 20, "vertices along the shoreline carry foam depth (%s)" % foam)
	var dry := int(field.bounds.size.x * field.bounds.size.y * WaterBuilder.SUBDIVIDE * WaterBuilder.SUBDIVIDE)
	assert_true(indices.size() / 6 < dry, "cells well inland are skipped")


func test_atmosphere_applies_mood_and_greying() -> void:
	var db := load_content()
	var atmosphere := Atmosphere.new()
	atmosphere._ready()
	var region: Dictionary = db.regions["gulls_head"]
	var state := fresh_state(db)
	var fog := RegionMood.fog(region, state)
	var light := RegionMood.light(region, state)
	atmosphere.apply_mood(fog, light, false)
	assert_true(_near(atmosphere.sun.light_energy, float(light["sun_energy"])), "sun energy applied")
	assert_true(atmosphere.sun.light_color.is_equal_approx(PropFactory.color(str(light["sun_color"]))), "sun colour applied")
	assert_true(_near(atmosphere.environment.fog_density, float(fog["density"])), "fog applied")
	assert_true(_near(atmosphere.sun.rotation_degrees.x, float(light["sun_pitch"])), "sun angle applied")
	var sky_top: Color = atmosphere.sky_material.get_shader_parameter("sky_top")
	assert_true(sky_top.is_equal_approx(PropFactory.color("slate")), "sky colours applied")
	assert_true(_near(float(atmosphere.target_mood()["sun_energy"]), float(light["sun_energy"])), "target mood reported")
	var saturation := atmosphere.environment.adjustment_saturation
	atmosphere.follow_greying(1.0, 10.0)
	assert_true(atmosphere.environment.adjustment_saturation < saturation, "the Greying drains colour")
	assert_true(atmosphere.environment.fog_density > float(fog["density"]), "the Greying thickens the fog")
	atmosphere.free()
