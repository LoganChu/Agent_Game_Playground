extends TestCase
## The Greying v1: fog depth, story-driven areas, the ember meter, the ember-budget map,
## the fog layer mesh and the validator's Greying checks.


func _near(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) < eps


func test_depth_inside_falloff_outside() -> void:
	var rect := {"rect": [0, 0, 10, 10], "strength": 0.8, "falloff": 2}
	assert_true(_near(Greying.area_depth(rect, Vector2(5, 5)), 0.8), "full strength inside")
	var edge := Greying.area_depth(rect, Vector2(11, 5))
	assert_true(edge > 0.1 and edge < 0.7, "fades across the falloff (%s)" % edge)
	assert_eq(Greying.area_depth(rect, Vector2(12.5, 5)), 0.0, "clear past the falloff")
	var ellipse := {"ellipse": [0, 0, 4, 2]}
	assert_true(_near(Greying.area_depth(ellipse, Vector2(3.9, 0)), 1.0), "strength defaults to 1")
	var both: Array[Dictionary] = [rect, ellipse]
	assert_true(_near(Greying.depth_at(both, Vector2(1, 1)), 1.0), "overlap takes the deepest")
	assert_eq(Greying.depth_at([] as Array[Dictionary], Vector2.ZERO), 0.0, "no areas, no fog")


func test_gulls_head_fog_leans_back_after_the_burn() -> void:
	var db := load_content()
	var region: Dictionary = db.regions["gulls_head"]
	var state := fresh_state(db)
	var before := Greying.active_areas(region, state)
	assert_true(Greying.depth_at(before, Vector2(0, -13)) > 0.9, "the beacon stands in thick fog before the burn")
	assert_true(Greying.depth_at(before, Vector2(0, 15)) < Greying.CLEAR_DEPTH, "the boardwalk end is clear")
	state.start_quest("a_light_for_saltmarrow", "feed_the_beacon")
	state.complete_quest("a_light_for_saltmarrow")
	var after := Greying.active_areas(region, state)
	assert_true(after.size() > 0, "pockets linger after the burn")
	assert_true(Greying.depth_at(after, Vector2(0, -13)) < Greying.CLEAR_DEPTH, "the beacon is clear once lit")
	assert_true(Greying.depth_at(after, Vector2(0, -3)) < Greying.CLEAR_DEPTH, "the ramp is clear once lit")


func test_ember_meter_drains_empties_once_and_refills() -> void:
	var meter := EmberMeter.new()
	var emptied := [0]
	meter.emptied.connect(func() -> void: emptied[0] += 1)
	meter.step(Greying.DRAIN_SECONDS * 0.5, 1.0)
	assert_true(_near(meter.ember, 0.5), "half drained at depth 1 (%s)" % meter.ember)
	meter.step(Greying.DRAIN_SECONDS, 0.5)
	assert_true(_near(meter.ember, 0.0), "shallow fog drains slower but still empties")
	meter.step(1.0, 1.0)
	assert_eq(emptied[0], 1, "emptied fires once")
	meter.refill()
	meter.step(1.0, 0.0)
	assert_true(meter.is_full(), "refill caps at full")
	meter.ember = 0.0
	meter.step(Greying.REFILL_SECONDS * 0.5, 0.0)
	assert_true(_near(meter.ember, 0.5), "refills in the clear")
	var fast := EmberMeter.new()
	fast.drain_scale = 4.0
	fast.step(Greying.DRAIN_SECONDS * 0.125, 1.0)
	assert_true(_near(fast.ember, 0.5), "drain_scale speeds it up")


func _long_shore() -> Dictionary:
	# An 80 m flat strip; spawn at the west end.
	return {"bounds": [-6, -8, 90, 8], "base": -2.0, "roughness": 0.0, "ragged": 0.0,
		"land": [{"rect": [0, -2, 80, 2], "height": 0.5, "falloff": 2}]}


func test_ember_cost_grows_with_distance_into_fog() -> void:
	var field := TerrainField.from_data(_long_shore(), -0.25)
	var reach := field.reachable_from(1, 0)
	var areas: Array[Dictionary] = [{"rect": [20, -10, 100, 10], "falloff": 0}]
	var cost := Greying.ember_cost_map(field, reach, areas)
	assert_eq(float(cost[field.cell_of(5, 0)]), 0.0, "clear ground costs nothing")
	var near := float(cost[field.cell_of(30, 0)])
	var far := float(cost[field.cell_of(60, 0)])
	var expected := 30.0 / Greying.WALK_SPEED / Greying.DRAIN_SECONDS
	assert_true(near > 0.0 and far > near, "deeper in costs more (%s, %s)" % [near, far])
	assert_true(absf(far - near - expected) < 0.01, "cost = time in fog / drain time (%s vs %s)" % [far - near, expected])


func test_fog_mesh_follows_the_area() -> void:
	var area := {"ellipse": [0, 0, 3, 3], "falloff": 1, "height": 2.0}
	var mesh := GreyingFog.build_mesh(area, func(_x: float, _z: float) -> float: return 1.0)
	assert_eq(mesh.get_surface_count(), 1, "one surface")
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_true(verts.size() > 0, "has layers")
	var ok := true
	for i in verts.size():
		ok = ok and verts[i].y > 1.0 and verts[i].y < 3.0
		ok = ok and Vector2(verts[i].x, verts[i].z).length() < 3 + 1 + 1.5
		ok = ok and colors[i].a >= 0.0 and colors[i].a <= GreyingFog.BASE_ALPHA + 0.0001
	assert_true(ok, "layers sit above the surface, inside the area, alpha within bounds")
	var clear := GreyingFog.build_mesh({"rect": [0, 0, 1, 1], "strength": 0.0}, func(_x: float, _z: float) -> float: return 0.0)
	assert_eq(clear.get_surface_count(), 0, "an area with no depth builds nothing")


func test_validator_checks_greying() -> void:
	var db := load_content()
	var areas: Array = db.regions["gulls_head"]["greying"]
	areas.append({"rect": [0, 0, 1, 1], "ellipse": [0, 0, 1, 1]})
	areas.append({"rect": [0, 0, 1], "strength": 2, "colour": "grey"})
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["exactly one of rect/ellipse", "malformed 'rect'",
			"strength must be a number", "unknown key 'colour'"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)
	var spawn_db := load_content()
	(spawn_db.regions["gulls_head"]["greying"] as Array).append({"ellipse": [0, 15, 3, 3]})
	var spawn_validator := ContentValidator.new(spawn_db)
	assert_false(spawn_validator.validate(), "fog over a spawn should fail")
	assert_true(spawn_validator.report().contains("spawn 'default' lies in the Greying"), "spawn check")


func test_validator_checks_ember_budget() -> void:
	var db := load_content()
	# A 120 m strip drowned from 20 m on: its far end is out of a Wakebearer's reach.
	var strip := {"bounds": [-6, -8, 130, 8], "base": -2.0, "roughness": 0.0, "ragged": 0.0,
		"land": [{"rect": [0, -2, 120, 2], "height": 0.5, "falloff": 2}]}
	db.regions["test_strip"] = {"id": "test_strip", "name": "Strip", "description": "test",
		"water_level": -0.25, "spawn_points": {"default": [1, 0, 0]}, "ground": strip,
		"greying": [{"rect": [20, -10, 140, 10], "falloff": 0}],
		"objects": [{"id": "far_end", "prompt": "Examine", "dialogue": "gulls_beacon", "position": [115, 0, 0]},
			{"id": "near", "prompt": "Examine", "dialogue": "gulls_beacon", "position": [40, 0, 0]}]}
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	assert_true(report.contains("object 'far_end'") and report.contains("ember to reach through the Greying"), "budget reported:\n" + report)
	assert_false(report.contains("object 'near'"), "content a short way in is fine")


func test_ember_cost_heap_pops_cheapest_first() -> void:
	# Day 31: ember_cost_map is Dijkstra over a binary heap (it was a LIFO search, 8.6 s on the woods).
	var heap: Array = []
	var values := [0.7, 0.1, 0.9, 0.3, 0.3, 0.0, 0.5, 2.0, 0.05]
	for i in values.size():
		Greying._heap_push(heap, [values[i], i])
	var out: Array = []
	while not heap.is_empty():
		out.append(float(Greying._heap_pop(heap)[0]))
	var sorted := values.duplicate()
	sorted.sort()
	assert_eq(out, sorted, "the heap gives costs back cheapest first")
