extends TestCase
## Day 81 — Act III opens. After the act2 card Oda casts off down the lane in on the morning ebb (Tobin's one stroke,
## the Provost by the rite, the six lights astern, Cindermoor out of the fog) to the Boat Stair, a new region: the
## Keepers' quay, the boathouse's eight slips (one boat never launched), Brother Merrit the Hushed boat-warden, and the
## cinder road that forgets where it goes. The Mercy lies at a chart landmark, not a port: nothing sails from it.

const CAST_OFF := "Cast off down the lane in."
const REGION := "cindermoor_boat_stair"

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


func _at(scenario: String) -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve(scenario))
	return state


## At the lane in with Oda's yes given (the act2 card shown).
func _passage() -> WorldState:
	var state := _at("the_lane_in")
	state.set_flag("cindermoor_passage", true)
	return state


func _region() -> Dictionary:
	return _content().regions[REGION]


func test_cast_off_only_once_the_passage_is_agreed() -> void:
	var state := _at("the_lane_in")
	var offered: Array[String] = []
	_lines(state, "oda", ["Not yet."], offered)
	assert_false(CAST_OFF in offered, "not before Oda's yes")
	state.set_flag("cindermoor_passage", true)
	offered.clear()
	var told := _lines(state, "oda", [CAST_OFF], offered)
	assert_true(CAST_OFF in offered)
	assert_true(told.contains("strokes it once") and told.contains("You only ever hear the one."), told)
	assert_true(told.contains("A ring's got a middle.") and told.contains("Thicker in than out."), told)
	assert_true(told.contains("Dark at the top.") and told.contains("smaller than I thought"), told)
	assert_true(bool(state.get_flag("cindermoor_crossed")))
	assert_eq(str(state.get_flag("lanes_ferry_at")), "cindermoor")


func test_who_sees_the_mercy_off() -> void:
	var state := _passage()
	state.set_flag("kindleby_rite", "bowed")
	state.set_flag("lowsong_iver_home", false)
	state.set_flag("thornwold_skiff", "")
	var told := _lines(state, "oda", [CAST_OFF])
	assert_true(told.contains("she lifts her hand"), told)
	assert_false(told.contains("Brother Iver is on the wall"), "Iver keeps the rock")
	assert_false(told.contains("Wenna Coll lifts her rake"), "the colliers aren't on Kindleby")
	state = _passage()
	state.set_flag("kindleby_rite", "refused")
	state.set_flag("lowsong_iver_home", true)
	state.set_flag("thornwold_skiff", "kindleby")
	told = _lines(state, "oda", [CAST_OFF])
	assert_true(told.contains("turns and goes up") and not told.contains("lifts her hand"), told)
	assert_true(told.contains("Brother Iver is on the wall") and told.contains("Wenna Coll lifts her rake"), told)


func test_the_landing_fires_once_and_starts_the_way_up() -> void:
	var state := _passage()
	_lines(state, "oda", [CAST_OFF])
	var event := RegionEvents.arrival(_region(), state)
	assert_eq(str(event.get("id", "")), "cindermoor_arrival")
	var told := _lines(state, RegionEvents.fire(event, state))
	assert_true(told.contains("Nobody takes her lines") and told.contains("And not all of them came."), told)
	assert_eq(state.quest_stage("the_way_up"), "the_road")
	assert_true(RegionEvents.arrival(_region(), state).is_empty(), "once")


func test_merrit_counts_the_slips_and_stops_for_what_is_yours() -> void:
	var state := _at("the_boat_stair")
	var offered: Array[String] = []
	var told := _lines(state, "merrit", ["Who didn't come down?"], offered)
	assert_true(told.contains("Eight slips. Seven out. One in.") and told.contains("Somebody's still up the stair."), told)
	assert_true(bool(state.get_flag("cindermoor_merrit_met")))
	# The scenario carries the Hood-Pin (Lowsong's) but not the Stair-Taper unless Kindleby gave it back.
	assert_true("Show him the Hood-Pin." in offered)
	told = _lines(state, "merrit", ["Show him the Hood-Pin."])
	assert_true(told.contains("Pin's straight. Good. Nobody's to see."), told)
	offered.clear()
	_lines(state, "merrit", [], offered)
	assert_false("Show him the Hood-Pin." in offered, "once")
	state.add_item("stair_taper")
	told = _lines(state, "merrit", ["Show him the Stair-Taper."])
	assert_true(told.contains("Past the third.") and told.contains("You went higher than you were told."), told)
	told = _lines(state, "merrit", ["Come aboard the Mercy. You can't sit here."])
	assert_true(told.contains("Then who'd be on the stair?"), told)


func test_the_road_forgets_and_the_slips_keep_a_boat() -> void:
	var state := _at("the_boat_stair")
	var told := _lines(state, "cindermoor_road")
	assert_true(told.contains("It doesn't remember the road."), told)
	assert_eq(state.quest_stage("the_way_up"), "the_cressets")
	told = _lines(state, "cindermoor_road")
	assert_true(told.contains("you can't remember it for it"), "the second try")
	told = _lines(state, "cindermoor_slips")
	assert_true(told.contains("She has never been in the water."), told)
	var offered: Array[String] = []
	told = _lines(state, "oda", ["The eighth slip has a boat in it."], offered)
	assert_true(told.contains("I never thought to count what didn't come."), told)


func test_no_lane_off_this_water() -> void:
	var state := _at("the_boat_stair")
	var offered: Array[String] = []
	var told := _lines(state, "oda", ["Take me back to Kindleby."], offered)
	assert_true(told.contains("I'll be here.") and told.contains("Off this water? There's no lane."), told)
	assert_false("Where can you take me?" in offered, "no chart to sail from here")
	assert_eq(Lanes.ferry_place_name(_content(), state), "Cindermoor")
	var voyage := Lanes.voyage(_content(), state, "kindleby")
	assert_false(bool(voyage["ok"]))
	assert_true(str(voyage["reason"]).contains("no lane off this water"), str(voyage))
	# Oda and the Mercy are on the Boat Stair, nowhere else.
	for region_id: String in _content().regions:
		for npc: Dictionary in (_content().regions[region_id] as Dictionary).get("npcs", []):
			if str(npc["npc"]) == "oda" and Conditions.evaluate(npc.get("if"), state):
				assert_eq(region_id, REGION, "Oda shows on %s" % region_id)


func test_the_validator_on_a_landmark_the_ferry_lies_at() -> void:
	var db := load_content()
	var mark: Dictionary = db.lanes["landmarks"][0]
	mark["ferry"] = "kindleby"
	mark.erase("moored")
	var v := ContentValidator.new(db)
	v._validate_lanes()
	var report := "\n".join(v.errors)
	assert_true(report.contains("'ferry' must be a declared lanes_ferry_at value that isn't a port"), report)
	assert_true(report.contains("needs 'moored'"), report)


func test_the_quay_is_the_pier() -> void:
	var ground: Dictionary = _region()["ground"]
	var pier: Dictionary = ground["piers"][0]
	assert_eq(float(pier["deck"]), 0.9, "build_cindermoor.QUAY_TOP")
	var quay: Dictionary = _region()["props"][0]
	assert_true(str(quay["model"]).ends_with("boat_stair.glb"))
	var r: Array = pier["rect"]
	var at: Array = quay["position"]
	assert_eq([float(r[0]) + float(r[2]), float(r[1]) + float(r[3])], [float(at[0]) * 2.0, float(at[2]) * 2.0], "centred on the quay")
	for path: String in ["boat_stair", "boathouse_slips", "hearthspire_far", "cinder_cresset"]:
		assert_true(ResourceLoader.exists("res://assets/models/dressing/%s.glb" % path), path)
	assert_true(ResourceLoader.exists("res://assets/models/characters/merrit.glb"))
