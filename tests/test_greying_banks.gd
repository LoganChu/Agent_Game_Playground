extends TestCase
## Day 119 (systems): the Greying v2's offshore banks on Saltmarrow and Shingle Point (thick off the harbor mouth
## and past the spit before the Gull burns, leaning back thinner and lower after it, over water only), and the
## exclusive fullscreen mode beside borderless.

const SCRATCH := "user://test_greying_banks.cfg"
const BANKED: Array[String] = ["saltmarrow", "shingle_point"]


func _burned(db: ContentDatabase) -> WorldState:
	var state := fresh_state(db)
	state.start_quest("a_light_for_saltmarrow", "feed_the_beacon")
	state.complete_quest("a_light_for_saltmarrow")
	return state


func _deepest_reachable(region: Dictionary, areas: Array[Dictionary]) -> float:
	var field := TerrainField.from_data(region["ground"], float(region.get("water_level", -INF)))
	var spawn := JsonUtil.to_vector3(region["spawn_points"]["default"])
	var deepest := 0.0
	for cell: Vector2i in field.reachable_from(spawn.x, spawn.z):
		var centre := field.vertex_xz(cell.x, cell.y) + Vector2(field.cell, field.cell) * 0.5
		deepest = maxf(deepest, Greying.depth_at(areas, centre))
	return deepest


func test_a_bank_offshore_before_the_burn() -> void:
	var db := load_content()
	var state := fresh_state(db)
	for id in BANKED:
		var region: Dictionary = db.regions[id]
		var areas := Greying.active_areas(region, state)
		assert_eq(areas.size(), 1, "%s: one bank before the burn" % id)
		assert_true(Greying.depth_at(areas, Vector2(0, 32)) > 0.8, "%s: thick out to sea" % id)
		assert_true(Greying.depth_at(areas, Vector2(0, 24)) > 0.0, "%s: its edge reaches in toward the shore" % id)
		assert_true(_deepest_reachable(region, areas) < Greying.CLEAR_DEPTH, "%s: nothing walkable is in it" % id)
		for spawn: String in region["spawn_points"]:
			var p := JsonUtil.to_vector3(region["spawn_points"][spawn])
			assert_true(Greying.depth_at(areas, Vector2(p.x, p.z)) < Greying.CLEAR_DEPTH, "%s: spawn %s clear" % [id, spawn])
	# The dock's end and the ferry's berth stay clear: the Mercy comes in out of clear water.
	var salt := Greying.active_areas(db.regions["saltmarrow"], state)
	assert_true(Greying.depth_at(salt, Vector2(6, 18)) < Greying.CLEAR_DEPTH, "the dock's end is clear")
	assert_true(Greying.depth_at(salt, Vector2(8.9, 16.5)) < Greying.CLEAR_DEPTH, "the ferry's berth is clear")


func test_the_bank_leans_back_after_the_burn() -> void:
	var db := load_content()
	var before := fresh_state(db)
	var after := _burned(db)
	for id in BANKED:
		var region: Dictionary = db.regions[id]
		var then := Greying.active_areas(region, before)
		var now := Greying.active_areas(region, after)
		assert_eq(now.size(), 1, "%s: the bank stays, leaned back" % id)
		assert_true(Greying.depth_at(now, Vector2(0, 27)) < Greying.depth_at(then, Vector2(0, 27)), "%s: thinner near in" % id)
		assert_true(Greying.depth_at(now, Vector2(0, 26)) < Greying.CLEAR_DEPTH, "%s: its edge has drawn off" % id)
		assert_true(Greying.depth_at(now, Vector2(0, 38)) <= 0.5 + 0.001, "%s: at most half strength" % id)
		assert_true(float(now[0]["height"]) < float(then[0]["height"]), "%s: and lower" % id)
	# The lit ending thins it again with every other area.
	after.set_flag("cindermoor_cradle_choice", "lit")
	assert_true(Greying.after_scale(db, after) < 0.5, "lit: the bank goes back further still")


func test_the_banks_build_over_water() -> void:
	var db := load_content()
	for id in BANKED:
		var region: Dictionary = db.regions[id]
		var water := float(region["water_level"])
		var surface := func(_x: float, _z: float) -> float: return water
		for area: Dictionary in Greying.all_areas(region):
			var mesh := GreyingFog.build_mesh(area, surface)
			assert_true(mesh.get_surface_count() == 1, "%s: a bank draws" % id)
			var aabb := mesh.get_aabb()
			assert_true(aabb.position.y >= water, "%s: it lies on the water" % id)
			assert_true(aabb.position.z >= 20.0, "%s: and only offshore" % id)


func test_exclusive_fullscreen() -> void:
	assert_eq(GameSettings.display_mode_for("windowed"), DisplayServer.WINDOW_MODE_WINDOWED, "windowed")
	assert_eq(GameSettings.display_mode_for("fullscreen"), DisplayServer.WINDOW_MODE_FULLSCREEN, "borderless")
	assert_eq(GameSettings.display_mode_for("exclusive"), DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, "exclusive")
	assert_eq(GameSettings.display_mode_for("cinema"), DisplayServer.WINDOW_MODE_WINDOWED, "unknown: windowed")
	assert_true(GameSettings.is_fullscreen_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN), "both count as fullscreen")
	assert_false(GameSettings.is_fullscreen_mode(DisplayServer.WINDOW_MODE_MAXIMIZED), "a maximized window doesn't")
	DirAccess.remove_absolute(SCRATCH)
	var settings := GameSettings.new()
	settings.path = SCRATCH
	settings.set_window_mode("exclusive")
	assert_true(settings.save(), "saves")
	var again := GameSettings.new()
	again.path = SCRATCH
	assert_true(again.load_file(), "loads")
	assert_eq(again.window_mode, "exclusive", "exclusive round-trips")
	GameSettings.set_current(again)
	var menu := PauseMenu.new()
	menu._build()
	menu._show_page(MenuScreen.Page.SETTINGS)
	var size_row: Button = null
	for b in menu.buttons():
		if b.text.begins_with("Window size"):
			size_row = b
	assert_true(size_row != null and size_row.disabled, "the size is off in exclusive fullscreen too")
	assert_true(menu.buttons().any(func(b: Button) -> bool: return b.text == "Display: Exclusive fullscreen"), "the menu names it")
	menu.free()
	DirAccess.remove_absolute(SCRATCH)
	GameSettings.new().apply_all()
	GameSettings.set_current(null)
