extends TestCase
## Day 78, the Greying v2: the ember's light holds a pool of clear round the Wakebearer in the
## fog (look only — the drain is unchanged), guttering as the ember wanes; the first turn-back
## is remembered (`greying_turned_back`) and Aldous has something to say about it.

const AREA := {"rect": [-10, -10, 10, 10], "strength": 1.0, "falloff": 2}


func _region_with_fog(state: WorldState) -> Region:
	var region := Region.new()
	region.data = {"greying": [AREA]}
	region._refresh_greying(state, false)
	return region


func _fog(region: Region) -> GreyingFog:
	for child in region.get_children():
		if child is GreyingFog:
			return child
	return null


func test_pool_gutters_as_the_ember_wanes() -> void:
	assert_true(is_equal_approx(Greying.ember_pool_radius(1.0), Greying.EMBER_POOL_RADIUS), "a full ember holds the widest pool")
	assert_true(is_equal_approx(Greying.ember_pool_radius(0.0), Greying.EMBER_POOL_RADIUS_SPENT), "a spent ember still holds a little")
	var half := Greying.ember_pool_radius(0.5)
	assert_true(half < Greying.EMBER_POOL_RADIUS and half > Greying.EMBER_POOL_RADIUS_SPENT, "it shrinks in between (%.2f)" % half)
	assert_true(Greying.EMBER_POOL_RADIUS <= 4.0, "a boat's length, not a clearing — the fog must still press in (%.1f m)" % Greying.EMBER_POOL_RADIUS)
	assert_true(Greying.ember_pool_radius(2.0) == Greying.EMBER_POOL_RADIUS and Greying.ember_pool_radius(-1.0) == Greying.EMBER_POOL_RADIUS_SPENT, "clamped")


func test_pool_thins_the_fog_most_at_the_hand() -> void:
	var c := Vector2(3, 4)
	var r := 3.0
	assert_true(is_equal_approx(Greying.ember_pool_push(c, r, c), Greying.EMBER_POOL_PUSH), "full push at the centre")
	assert_true(Greying.EMBER_POOL_PUSH < 1.0, "never a hole: some fog always shows round the hand")
	assert_true(is_equal_approx(Greying.ember_pool_push(c, r, c + Vector2(r * Greying.EMBER_POOL_CORE * 0.9, 0)), Greying.EMBER_POOL_PUSH), "held through the core")
	var mid := Greying.ember_pool_push(c, r, c + Vector2(r * 0.7, 0))
	assert_true(mid > 0.0 and mid < Greying.EMBER_POOL_PUSH, "eases across the edge (%.2f)" % mid)
	assert_eq(Greying.ember_pool_push(c, r, c + Vector2(r, 0)), 0.0, "nothing at the radius")
	assert_eq(Greying.ember_pool_push(c, r, c + Vector2(0, r + 5)), 0.0, "nothing beyond")
	assert_eq(Greying.ember_pool_push(c, 0.0, c), 0.0, "no radius, no pool")


func test_the_fog_shader_knows_the_pool() -> void:
	var code := GreyingFog.SHADER.code
	assert_true(code.contains("uniform vec4 ember_pool"), "the fog shader takes the pool")
	assert_true(code.contains("uniform float ember_push"), "and its push")
	assert_true(code.contains("%.2f" % Greying.EMBER_POOL_CORE), "the shader's core fraction matches Greying.EMBER_POOL_CORE")


func test_region_hands_the_pool_to_shown_and_later_fog() -> void:
	var db := load_content()
	var state := fresh_state(db)
	var region := _region_with_fog(state)
	var fog := _fog(region)
	assert_true(fog != null, "the area's fog is shown")
	if fog == null:
		region.free()
		return
	assert_eq(fog.pool().w, 0.0, "no pool before the walker gives one")
	region.set_ember_pool(Vector3(1, 2, 3), 2.5, 0.85)
	assert_eq(fog.pool(), Vector4(1, 2, 3, 2.5), "shown fog takes the pool")
	assert_true(is_equal_approx(float(fog._material.get_shader_parameter("ember_push")), 0.85), "and the push")
	# An area the story brings in later opens round the hand at once.
	region._greying_fog.clear()
	fog.free()
	region._refresh_greying(state, false)
	var later := _fog(region)
	for child in region.get_children():
		if child is GreyingFog and child != later:
			later = child
	assert_true(later != null and later.pool() == Vector4(1, 2, 3, 2.5), "fog built later starts with the pool")
	region.free()


func test_walker_opens_the_pool_round_the_player_and_it_shrinks() -> void:
	var db := load_content()
	var state := fresh_state(db)
	var region := _region_with_fog(state)
	var walker := GreyingWalker.new()
	walker.region = region
	var at := Vector3(2, 0, -1)
	walker._open_pool(at, 0.1)
	var fog := _fog(region)
	var full := fog.pool() if fog else Vector4.ZERO
	assert_true(Vector2(full.x, full.z).distance_to(Vector2(2, -1)) < 0.01, "centred on the Wakebearer (%s)" % full)
	assert_true(full.y > at.y, "at the hand, not the boots")
	assert_true(absf(full.w - Greying.EMBER_POOL_RADIUS) < Greying.EMBER_POOL_RADIUS * 0.1, "wide while the ember burns (%.2f)" % full.w)
	walker.meter.step(Greying.DRAIN_SECONDS * 0.6, region.greying_depth(at.x, at.z))
	walker._open_pool(at, 0.1)
	var low := fog.pool() if fog else Vector4.ZERO
	assert_true(walker.meter.ember < 0.5, "the ember drained in the fog (%.2f)" % walker.meter.ember)
	assert_true(low.w < full.w * 0.75, "the ring closes as the ember goes (%.2f → %.2f)" % [full.w, low.w])
	assert_true(absf(low.w - walker.pool_radius()) < walker.pool_radius() * 0.1, "the radius follows the ember")
	var source := (load("res://scripts/world/greying_walker.gd") as GDScript).source_code
	assert_true(source.contains("_open_pool(p, delta)"), "every physics frame opens the pool where the player stands")
	walker.free()
	region.free()


func test_the_pool_is_look_only() -> void:
	var db := load_content()
	var state := fresh_state(db)
	var region := _region_with_fog(state)
	var before := region.greying_depth(0, 0)
	region.set_ember_pool(Vector3.ZERO, Greying.EMBER_POOL_RADIUS, Greying.EMBER_POOL_PUSH)
	assert_eq(region.greying_depth(0, 0), before, "the drain still reads the fog that presses in")
	region.free()


func test_first_turn_back_is_remembered() -> void:
	var db := load_content()
	assert_true(db.flags.has(GreyingWalker.TURNED_BACK_FLAG), "the flag is declared")
	assert_true(bool(db.flags[GreyingWalker.TURNED_BACK_FLAG].get("set_by_code", false)), "and marked as set by code")
	var source := (load("res://scripts/world/greying_walker.gd") as GDScript).source_code
	assert_true(source.contains("set_flag(TURNED_BACK_FLAG, true)"), "GreyingWalker sets it on turning back")
	var report := ContentValidator.new(db)
	report.validate()
	for line: String in report.errors:
		assert_false(line.contains(GreyingWalker.TURNED_BACK_FLAG), "no validator error for a code-set flag: " + line)


func test_validator_still_catches_flags_nobody_sets() -> void:
	var db := load_content()
	db.flags["nobody_sets_this"] = {"description": "test", "default": false}
	var report := ContentValidator.new(db)
	report.validate()
	assert_true(report.errors.any(func(e: String) -> bool: return e.contains("nobody_sets_this")), "an unset flag without set_by_code is still an error")


func test_aldous_on_being_turned_back() -> void:
	var db := load_content()
	var state := fresh_state(db)
	state.set_flag("saltmarrow_met_aldous", true)
	var ask := "I went into the fog and came out again not knowing why I'd gone."
	var offered: Array[String] = []
	play_dialogue(db, state, "aldous", ["Rest easy, Brother."], offered)
	assert_false(offered.has(ask), "nothing to tell before the fog has turned you back")
	state.set_flag("greying_turned_back", true)
	offered.clear()
	var text := play_dialogue(db, state, "aldous", [ask, "Rest easy, Brother."], offered)
	assert_true(offered.has(ask), "offered once turned back")
	assert_true(text.contains("A boat's length"), "he tells of the ring of clear round a lit ember")
	assert_true(text.contains("Isolde Vane"), "and of Isolde's ember walking her out")
	assert_true(text.contains("newest thing first"), "the fog takes the errand")
	assert_true(bool(state.get_flag("saltmarrow_aldous_heard_turned_back")), "he's been told")
	offered.clear()
	play_dialogue(db, state, "aldous", ["Rest easy, Brother."], offered)
	assert_false(offered.has(ask), "told once")
	var confessed := fresh_state(db)
	confessed.set_flag("saltmarrow_met_aldous", true)
	confessed.set_flag("greying_turned_back", true)
	confessed.set_flag("saltmarrow_aldous_confessed", "full")
	var full := play_dialogue(db, confessed, "aldous", [ask, "Rest easy, Brother."])
	assert_true(full.contains("the opposite to men"), "after the full confession he says more")
	assert_false(full.contains("long before he forgets the stair"), "and not the plainer line")
