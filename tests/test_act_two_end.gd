extends TestCase
## Day 79 — Act II's end. Back on Kindleby after Lowsong's light burns, Oda has seen the sixth light from the rail:
## she counts "the lights between" and inks the lane in, Kindleby to Cindermoor, on her chart (drawn, not sailed).
## Asked to take the Wakebearer in, she weighs it once more and asks if anyone is owed a word; "take me in" sets
## `cindermoor_passage` and the `act2` end card recaps every burning and who went where.

const TAKE_ME_IN := "Take me in to Cindermoor."
const GO := "Nobody I can't owe it to from there. Take me in."
const WAIT := "Not yet. There's somebody I've to see first."
const COUNTED := "The lights between."

var _db: ContentDatabase
var _saved_world: WorldState
var _saved_db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


## At a checkpoint, rowed back to Kindleby if it is out on Lowsong.
func _at(scenario: String) -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve(scenario))
	state.set_flag("lowsong_out", false)
	return state


func _act2() -> Dictionary:
	for act in ActRecap.acts(_content()):
		if str(act["id"]) == "act2":
			return act
	return {}


func _recap(state: WorldState) -> String:
	return "\n".join(ActRecap.lines(_act2(), state))


func _cindermoor() -> Dictionary:
	for mark: Dictionary in _content().lanes["landmarks"]:
		if str(mark["name"]) == "Cindermoor":
			return mark
	return {}


func test_oda_counts_six_lights_and_inks_the_lane_in() -> void:
	var state := _at("lowsong_lit")
	var offered: Array[String] = []
	var told := _lines(state, "oda", ["Not yet."], offered)
	assert_true(told.contains("There's a light on the Low Water.") and told.contains(COUNTED), told)
	assert_true(told.contains("Somebody's keeping it, too."), "the key burned: someone keeps the rock")
	assert_false(told.contains("Lorn's been at him"), "Iver didn't row home")
	assert_true(told.contains("The lane in."), told)
	assert_true(bool(state.get_flag("kindleby_oda_lane_in")))
	assert_true(TAKE_ME_IN in offered, "she offers to take you in at once")
	assert_true(told.contains("Six lights, and a line on my chart"), "the quay greeting counts six now")
	assert_false(told.contains("Five lights. Every one"), "not five any more")
	told = _lines(state, "oda", ["Not yet."])
	assert_false(told.contains(COUNTED), "she counts them once")


func test_iver_home_is_seen_from_the_rail() -> void:
	var state := _at("lowsong_lit")
	state.set_flag("lowsong_beacon_burned", "lamp")
	state.set_flag("lowsong_iver_home", true)
	var told := _lines(state, "oda", ["Not yet."])
	assert_true(told.contains("Lorn's been at him in front of everybody"), told)
	assert_false(told.contains("Somebody's keeping it"), told)


func test_nothing_before_the_sixth_light() -> void:
	var state := _at("lowsong")
	state.set_flag("lanes_ferry_at", "kindleby")
	var offered: Array[String] = []
	var told := _lines(state, "oda", ["Not yet."], offered)
	assert_false(told.contains(COUNTED), "Lowsong still cold")
	assert_false(TAKE_ME_IN in offered)
	assert_true(told.contains("Five lights. Every one"), told)
	assert_false(bool(state.get_flag("kindleby_oda_lane_in")))
	assert_true(ActRecap.reached(_content(), state).has("act1"))
	assert_false(ActRecap.reached(_content(), state).has("act2"))


func test_waiting_keeps_act_two_open_and_going_ends_it() -> void:
	var state := _at("the_lane_in")
	var told := _lines(state, "oda", [TAKE_ME_IN, WAIT])
	assert_true(told.contains("Is there anybody left you owe a word?") and told.contains("That's rather the point."), told)
	assert_false(bool(state.get_flag("cindermoor_passage")), "not yet")
	assert_false(ActRecap.reached(_content(), state).has("act2"))
	var offered: Array[String] = []
	told = _lines(state, "oda", [TAKE_ME_IN, GO], offered)
	assert_true(told.contains("The morning ebb, then.") and told.contains("nothing to see at all"), told)
	assert_true(bool(state.get_flag("cindermoor_passage")))
	assert_true(ActRecap.reached(_content(), state).has("act2"), "Act II ends")
	offered.clear()
	told = _lines(state, "oda", ["Not yet."], offered)
	assert_false(TAKE_ME_IN in offered, "asked once")
	assert_true(told.contains("I've not changed my mind"), told)


func test_oda_weighs_it_by_the_sleeve_ember_and_the_colliers() -> void:
	var state := _at("the_lane_in")
	state.set_flag("saltmarrow_oda_saw_sleeve_ember", true)
	var told := _lines(state, "oda", [TAKE_ME_IN, WAIT])
	assert_true(told.contains("I'd say this is the other one."), told)
	assert_false(told.contains("I'll not weigh you again"), told)
	state.set_flag("saltmarrow_oda_saw_sleeve_ember", false)
	state.set_flag("thornwold_far_shore", "waiting")
	state.set_flag("thornwold_skiff", "")
	told = _lines(state, "oda", [TAKE_ME_IN, WAIT])
	assert_true(told.contains("you've paid it six times over") and told.contains("Now you can."), told)
	state.set_flag("thornwold_skiff", "kindleby")
	told = _lines(state, "oda", [TAKE_ME_IN, WAIT])
	assert_false(told.contains("Now you can."), "the colliers came to Kindleby: nobody's waiting on the stage")


func test_the_recap_tells_every_light_once() -> void:
	var state := _at("the_lane_in")
	_lines(state, "oda", [TAKE_ME_IN, GO])
	var islands := {
		"thornwold_beacon_burned": "The Ridge Light burns",
		"fen_beacon_burned": "The Heron Light burns",
		"wrackholm_beacon_burned": "The Wrack Light burns",
		"kindleby_beacon_burned": "The Vigil Light burns",
		"lowsong_beacon_burned": "Lowsong's light burns",
	}
	for flag: String in islands:
		var keep: Variant = state.get_flag(flag)
		for value: Variant in _content().flags[flag]["values"]:
			if str(value).is_empty():
				continue
			state.set_flag(flag, value)
			var lines := ActRecap.lines(_act2(), state)
			var hits := Array(lines).filter(func(l: String) -> bool: return l.begins_with(str(islands[flag])))
			assert_eq(hits.size(), 1, "%s=%s tells its light once" % [flag, value])
		state.set_flag(flag, keep)
	var recap := _recap(state)
	assert_true(recap.contains("Iver Lusk's Kindleby") and not recap.contains("Iver Lusk's listening"), recap)
	assert_true(recap.contains("a bone hood-pin") and recap.contains("It was you."), recap)


func test_dunstan_is_told_by_what_the_wakebearer_remembers() -> void:
	var state := _at("the_lane_in")
	state.set_flag("cindermoor_passage", true)
	state.set_flag("fen_dunstan_walk", "home")
	state.set_flag("saltmarrow_beacon_burned", "knot")
	assert_true(_recap(state).contains("Dunstan Tollen walked back for his name and rowed home"), _recap(state))
	state.set_flag("saltmarrow_beacon_burned", "gull")
	var recap := _recap(state)
	assert_false(recap.contains("Dunstan"), "the gull burned: his name won't stay with you")
	assert_true(recap.contains("She doesn't know him. The second cup is his."), recap)
	state.set_flag("fen_dunstan_walk", "stayed")
	assert_true(_recap(state).contains("stayed on the fen to turn the long walk's boards"), _recap(state))


func test_the_chart_draws_the_lane_in_and_lowsong_lit() -> void:
	var state := _at("lowsong")
	var low_water: Dictionary = {}
	for mark: Dictionary in _content().lanes["landmarks"]:
		if str(mark["name"]) == "the Low Water":
			low_water = mark
	assert_false(Lanes.landmark_lit(low_water, state), "cold")
	assert_true(Lanes.landmark_lane(_cindermoor(), state).is_empty(), "no lane in yet")
	state = _at("the_lane_in")
	assert_true(Lanes.landmark_lit(low_water, state), "Lowsong lit shows on the chart")
	var lane := Lanes.landmark_lane(_cindermoor(), state)
	assert_eq(str(lane.get("from", "")), "kindleby")
	assert_eq(Lanes.landmark_lanes_from(_content(), state, "kindleby").size(), 1)
	assert_empty(Lanes.landmark_lanes_from(_content(), state, "wrackholm"))
	assert_eq(str(Lanes.voyage(_content(), state, "kindleby").get("reason", "")), "The Slow Mercy is moored here.",
			"the lane in is drawn, never sailed from the chart")
	_saved_world = GameState.world
	_saved_db = Content.db
	GameState.world = state
	Content.db = _content()
	var chart := LaneMap.new()
	chart._ready()
	chart.open()
	chart.call("_focus_port", "kindleby")
	assert_true(chart.info_text().contains("The lane in runs from here to Cindermoor: ask Oda."), chart.info_text())
	chart.free()
	GameState.world = _saved_world
	Content.db = _saved_db
	GameState.input_locked = false


func test_validator_checks_landmark_lanes() -> void:
	var db := load_content()
	var report := ContentValidator.new(db)
	report.validate()
	assert_empty(report.errors, "clean")
	for mark: Dictionary in db.lanes["landmarks"]:
		if str(mark["name"]) == "Cindermoor":
			mark["lane"] = {"from": "the_spire", "name": "the lane in", "known": "flag:no_such_flag"}
	report = ContentValidator.new(db)
	report.validate()
	assert_true(report.errors.any(func(e: String) -> bool: return e.contains("lane 'from' must be a port")), "bad port")
	assert_true(report.errors.any(func(e: String) -> bool: return e.contains("no_such_flag")), "bad condition")


func test_a_long_recap_scrolls_on_the_card() -> void:
	var card := ActEndCard.new()
	card._ready()
	var recap: RichTextLabel = card.get("_recap")
	var scroll: ScrollContainer = card.get("_recap_scroll")
	assert_true(scroll.is_ancestor_of(recap), "the recap sits in a scroll box")
	recap.text = "One short line."
	card.call("_fit_recap")
	assert_false(card.recap_scrolls(), "a short recap doesn't scroll")
	var lines: PackedStringArray = []
	for i in 40:
		lines.append("•  A line of the recap, long enough to wrap now and then on a narrow screen: %d." % i)
	recap.text = "\n".join(lines)
	card.call("_fit_recap")
	assert_true(scroll.custom_minimum_size.y <= 720.0 * 0.55 + 1.0, "no taller than about half the screen")
	# Whether forty lines actually scroll needs a laid-out label: checked in the screenshot run (--act-end=act2).
	card.free()
