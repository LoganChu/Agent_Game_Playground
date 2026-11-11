extends TestCase
## Day 97 — the epilogues, part one. After the count down Oda finds a lane off Cindermoor's water in every ending
## (by the lit Spire astern, by the six lights ahead, by the ember held up in the bow) and brings the Wakebearer to
## Kindleby, where Tobin rings the quay bell's second stroke. After `lit` or `released` the hand holds no ember (the
## fog takes nothing); after `lit` the grey goes back everywhere (game.json `after_the_ember`). The chart's Cindermoor
## says what the ending made of it (lanes.json landmark `after`).

const ENDINGS: Array[String] = ["lit", "released", "dark"]
const OUT := "Take me out to Kindleby."
const BACK_IN := "Take me back in to Cindermoor."

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


## Where a dialogue run sends the player when it closes ([] = nowhere): picks as in play_dialogue.
func _travel(state: WorldState, dialogue: String, picks: Array) -> Array:
	var runner := DialogueRunner.new(_content(), state)
	var ev := runner.start(dialogue)
	var guard := 0
	while ev["type"] != "end" and guard < 200:
		guard += 1
		if ev["type"] != "line":
			var texts: Array = (ev["options"] as Array).map(func(o: Dictionary) -> String: return str(o["text"]))
			var want: String = picks.pop_front() if not picks.is_empty() else ""
			var index := texts.find(want)
			ev = runner.choose(index if index >= 0 else texts.size() - 1)
		else:
			ev = runner.next()
	return runner.pending_travel


## Counted down at the spire's foot after choosing `ending`, the Mercy still at the Boat Stair.
func _after(ending: String) -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_spire_lit"))
	state.set_flag("cindermoor_cradle_choice", ending)
	state.set_flag("cindermoor_counted_down", true)
	state.quests["the_lantern_room"] = {"status": "done", "stage": ""}
	return state


func _sail_out(state: WorldState) -> String:
	return _lines(state, "oda", [OUT])


func test_no_lane_before_the_count_down() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_spire_lit"))
	var offered: Array[String] = []
	var said := _lines(state, "oda", ["Take me back to Kindleby."], offered)
	assert_false(offered.has(OUT), "no lane out before the Long Book's shut: %s" % [offered])
	assert_true(said.contains("There's no lane"), said)
	assert_eq(str(state.get_flag("lanes_ferry_at")), "cindermoor")


func test_oda_finds_a_lane_in_every_ending() -> void:
	var marks := {"lit": "Well. It's lit.", "released": "I didn't say I'd be the one to find it.", "dark": "Hold it up."}
	var first := {"lit": "opened a door in the sky", "released": "Something went past the Mercy", "dark": "Still dark up there."}
	for ending in ENDINGS:
		var state := _after(ending)
		var said := _lines(state, "oda", ["Not yet."])
		assert_true(said.contains(first[ending]), "%s: Oda's night: %s" % [ending, said])
		assert_true(bool(state.get_flag("cindermoor_oda_after_seen")), ending)
		for other in ENDINGS:
			if other != ending:
				assert_false(said.contains(first[other]), "%s: not %s's line" % [ending, other])
		var again := _lines(state, "oda", ["Not yet."])
		assert_true(again.contains("Still here.") and not again.contains(first[ending]), "%s: told once: %s" % [ending, again])
		var travel := _travel(state, "oda", [OUT])
		assert_eq(travel, ["kindleby", "from_ferry"], ending)
		assert_eq(str(state.get_flag("lanes_ferry_at")), "kindleby", ending)
		assert_true(bool(state.get_flag("cindermoor_lane_out")), ending)
		var voyage := _sail_out(_after(ending))
		assert_true(voyage.contains(marks[ending]), "%s: the lane out: %s" % [ending, voyage])
		assert_true(voyage.contains("candles of Kindleby's wall"), ending)


func test_the_lit_lane_counts_for_the_wakebearer() -> void:
	# Day 96: after the lit ending the Wakebearer can't count; Oda counts the six lights for them.
	var said := _sail_out(_after("lit"))
	assert_true(said.contains("lose your place at two") and said.contains("Oda counts them for you"), said)
	for light: String in ["the Gull", "the Ridge", "the Heron", "the Wrack", "the Vigil Light", "Lowsong"]:
		assert_true(said.contains(light), light)


func test_the_homecoming_on_kindleby() -> void:
	var lines := {
		"lit": "It took me first.",
		"released": "Your hand's gone out.",
		"dark": "Will you come here first?",
	}
	for ending in ENDINGS:
		var state := _after(ending)
		_sail_out(state)
		var event := RegionEvents.arrival(_content().regions["kindleby"], state)
		assert_eq(str(event.get("id", "")), "kindleby_homecoming", ending)
		var offered: Array[String] = []
		var said := _lines(state, RegionEvents.fire(event, state), [], offered)
		assert_true(said.contains("strikes it, once") and said.contains("The second stroke"), "%s: the second stroke" % ending)
		assert_true(said.contains(lines[ending]) or offered.has(lines[ending]), "%s: %s / %s" % [ending, said, offered])
		assert_true(said.contains("Is the Provost coming back?"), "%s: the chapter came, so Tobin asks" % ending)
		assert_true(bool(state.get_flag("kindleby_homecoming_seen")), ending)
		assert_true(RegionEvents.arrival(_content().regions["kindleby"], state).is_empty(), "%s: once" % ending)
		var tobin := _lines(state, "tobin", ["Goodbye."])
		assert_true(tobin.contains("I go up the crown") if ending == "lit" else true, tobin)
		assert_true(tobin.contains("warm steps") if ending == "released" else true, tobin)
		assert_true(tobin.contains("Six weeks to midwinter") if ending == "dark" else true, tobin)


func test_the_dark_ending_is_asked_to_carry_it_round() -> void:
	for pick: Array in [["Kindleby first. You've waited longest.", "first", "I'll be on the bell."],
			["Round the way the light goes. From the Gull, and here last.", "ring", "Somebody's always last."]]:
		var state := _after("dark")
		_sail_out(state)
		var said := _lines(state, "kindleby_homecoming", [pick[0]])
		assert_eq(str(state.get_flag("kindleby_midwinter")), pick[1])
		assert_true(said.contains(pick[2]), said)
	var lit := _after("lit")
	_sail_out(lit)
	_lines(lit, "kindleby_homecoming", ["It's lit."])
	assert_eq(str(lit.get_flag("kindleby_midwinter")), "", "only the dark ending asks")


func test_the_lane_runs_both_ways_after() -> void:
	for ending in ENDINGS:
		var state := _after(ending)
		_sail_out(state)
		state.set_flag("kindleby_homecoming_seen", true)
		var offered: Array[String] = []
		_lines(state, "oda", ["Not yet."], offered)
		assert_true(offered.has(BACK_IN), "%s: %s" % [ending, offered])
		assert_true(offered.has("Where can you take me?"), "the ring's lanes as before")
		assert_eq(_travel(state, "oda", [BACK_IN]), ["cindermoor_boat_stair", "from_ferry"], ending)
		assert_eq(str(state.get_flag("lanes_ferry_at")), "cindermoor")
		var again := _lines(state, "oda", [OUT])
		assert_true(again.contains("The lane out again") and not again.contains("candles of Kindleby's wall"), again)
		assert_eq(str(state.get_flag("lanes_ferry_at")), "kindleby")
	var before := fresh_state(_content())
	Scenarios.apply(_content(), before, Scenarios.resolve("the_lantern_room"))
	before.set_flag("lanes_ferry_at", "kindleby")
	var offered_before: Array[String] = []
	_lines(before, "oda", ["Not yet."], offered_before)
	assert_false(offered_before.has(BACK_IN), "not before the lane out")


func test_after_the_ember() -> void:
	var db := _content()
	var expect := {"": [false, 1.0], "lit": [true, 0.35], "released": [true, 1.0], "dark": [false, 1.0]}
	for ending: String in expect:
		var state := fresh_state(db)
		state.set_flag("cindermoor_cradle_choice", ending)
		assert_eq(Greying.ember_gone(db, state), expect[ending][0], "ember gone after '%s'" % ending)
		assert_true(is_equal_approx(Greying.after_scale(db, state), expect[ending][1]), "grey scale after '%s'" % ending)
	# The validator reads the block.
	var bad := load_content()
	bad.game["after_the_ember"] = {"ember_gone": "flag:no_such_flag", "greying_scale": [{"if": "flag:cindermoor_counted_down", "scale": 2}], "oops": 1}
	var report := ContentValidator.new(bad)
	report.validate()
	var errors := "\n".join(report.errors)
	assert_true(errors.contains("no_such_flag"), errors)
	assert_true(errors.contains("'scale' must be a number in 0..1"), errors)
	assert_true(errors.contains("unknown key 'oops'"), errors)


func test_the_walker_takes_nothing_without_an_ember() -> void:
	# A region with fog: the drain stops and the hand goes dark once it holds no ember; lit, the grey goes back.
	var saved_db := Content.db
	if Content.db.game.is_empty():
		Content.db = _content()
	var saved := GameState.world
	GameState.world = fresh_state(_content())
	var region := Region.new()
	region.data = {"greying": [{"rect": [-50, -50, 50, 50], "strength": 1.0}]}
	region.refresh_conditional(false)
	var player := Player.new()
	player._ready()
	var walker := GreyingWalker.new()
	walker.player = player
	walker.region = region
	walker.walk(Vector3.ZERO, true, 1.0)
	assert_true(walker.meter.ember < 1.0, "the fog drains the ember (%.2f)" % walker.meter.ember)
	assert_false(player.is_ember_gone())
	GameState.world.set_flag("cindermoor_cradle_choice", "released")
	walker.walk(Vector3.ZERO, true, 1.0)
	assert_true(walker.ember_gone and is_equal_approx(walker.meter.ember, 1.0), "no ember to drain")
	assert_true(player.is_ember_gone(), "the hand's light out")
	walker.walk(Vector3.ZERO, true, Greying.DRAIN_SECONDS * 2.0)
	assert_true(is_equal_approx(walker.meter.ember, 1.0) and not walker.turning_back, "never turned back")
	assert_true(is_equal_approx(region.greying_depth(0, 0), 1.0), "released: the fog stands as it was")
	GameState.world.set_flag("cindermoor_cradle_choice", "lit")
	region.refresh_conditional(false)
	assert_true(is_equal_approx(region.greying_scale, 0.35), "the grey goes back")
	assert_true(is_equal_approx(region.greying_depth(0, 0), 0.35), "and the depth with it (%.2f)" % region.greying_depth(0, 0))
	GameState.world.set_flag("cindermoor_cradle_choice", "dark")
	region.refresh_conditional(false)
	walker.walk(Vector3.ZERO, true, 1.0)
	assert_false(walker.ember_gone or player.is_ember_gone(), "dark: the ember still in the hand")
	GameState.world = saved
	Content.db = saved_db
	walker.free()
	player.free()
	region.free()


func test_the_chart_after() -> void:
	var db := _content()
	var mark: Dictionary = {}
	for m: Dictionary in db.lanes["landmarks"]:
		if m.get("name") == "Cindermoor":
			mark = m
	var state := fresh_state(db)
	state.set_flag("lanes_ferry_at", "cindermoor")
	assert_true(str(Lanes.voyage(db, state, "kindleby")["reason"]).contains("till the Spire's lit"), "before")
	assert_false(Lanes.landmark_lit(mark, state))
	for ending in ENDINGS:
		state.set_flag("cindermoor_cradle_choice", ending)
		var words := Lanes.landmark_words(mark, state)
		assert_true(str(words["moored"]).contains("Ask Oda"), "%s: %s" % [ending, words])
		assert_false(str(words["text"]).contains("Nobody lands"), ending)
		assert_eq(Lanes.landmark_lit(mark, state), ending == "lit", ending)
		assert_eq(Lanes.voyage(db, state, "kindleby")["reason"], words["moored"], "the map says the same")


func test_the_far_spire_lit() -> void:
	var db := _content()
	for region_id: String in ["cindermoor_boat_stair", "cindermoor_long_steps", "kindleby"]:
		for ending: String in ["", "lit", "released", "dark"]:
			var state := fresh_state(db)
			state.set_flag("cindermoor_cradle_choice", ending)
			var dark := 0
			var lit := 0
			for prop: Dictionary in db.regions[region_id]["props"]:
				var model := str(prop.get("model", ""))
				if not Conditions.evaluate(prop.get("if"), state):
					continue
				if model.ends_with("hearthspire_far.glb"):
					dark += 1
				elif model.ends_with("hearthspire_far_lit.glb"):
					lit += 1
			assert_eq(lit, 1 if ending == "lit" else 0, "%s / %s: the lit Spire" % [region_id, ending])
			if region_id != "kindleby":
				assert_eq(dark, 0 if ending == "lit" else 1, "%s / %s: the dark Spire" % [region_id, ending])


func test_the_checkpoint() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_homecoming"))
	assert_eq(str(state.get_flag("lanes_ferry_at")), "kindleby")
	assert_true(Greying.ember_gone(_content(), state))
	var offered: Array[String] = []
	_lines(state, "oda", ["Not yet."], offered)
	assert_true(offered.has(BACK_IN), str(offered))
