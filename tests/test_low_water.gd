extends TestCase
## Day 72 — Act II's close, step 2 begins: the ring's last gap. Once the Vigil Light is lit, Oda tells of the
## Low Water (south of the ring, between Kindleby and the Gull) and smudges it onto her chart — a landmark,
## never a port: the Slow Mercy won't sail water that sings. A Keeper might row it: Sister Hild, scraping the
## chapter's skiff on Kindleby's shingle, will once the weed is off its bottom (*The Low Water*).

const BY := "kindleby"
const ASK := "Where does the ring go from here?"
const WHY := "Why go round?"
const LIGHT := "Is there a light out there?"
const ROW := "Would you row me out to the Low Water?"
const CLEAN := "Is she clean yet?"
const SCRAPING := "You're scraping her."
const BYE := "Goodbye."

var _db: ContentDatabase


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_db, state, dialogue, typed, offered)


## On Kindleby with the Slow Mercy at the quay; `burn` '' for the Vigil Light still dark. `skiff` is
## thornwold_skiff, or '-' when the skiff never went north.
func _kindleby(burn := "boats", skiff := "home") -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "thornwold_landed", "fen_landed", "wrackholm_landed",
			"wrackholm_oda_lane_asked", "kindleby_landed", "kindleby_met_provost"]:
		state.set_flag(flag, true)
	for quest: String in ["across_the_grey", "a_light_for_saltmarrow", "a_light_for_thornwold", "a_light_for_glasswater",
			"a_light_for_wrackholm"]:
		state.complete_quest(quest)
	state.set_flag("lanes_ferry_at", BY)
	state.set_flag("kindleby_rite", "bowed")
	state.set_flag("kindleby_beacon_burned", burn)
	if skiff != "-":
		state.set_flag("kindleby_told_of_stage", true)
		state.set_flag("kindleby_skiff_north", true)
		state.set_flag("thornwold_skiff", skiff)
	if not burn.is_empty():
		state.complete_quest("a_light_for_kindleby")
	return state


func _odas_offer(state: WorldState) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, "oda", ["Not yet."], offered)
	return offered


func _hilds_placements() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for placed: Dictionary in _content().get_region(BY)["npcs"]:
		if placed["npc"] == "hild":
			out.append(placed)
	return out


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _shown(state: WorldState) -> Array[String]:
	var names: Array[String] = []
	for mark in Lanes.known_landmarks(_db, state):
		names.append(str(mark["name"]))
	return names


func test_oda_tells_of_the_low_water_once_kindleby_is_lit() -> void:
	assert_false(ASK in _odas_offer(_kindleby("")), "not while the Vigil Light is dark")
	for burn: String in ["boats", "pan"]:
		var state := _kindleby(burn)
		assert_true(ASK in _odas_offer(state), burn)
		assert_eq(_shown(state), ["Cindermoor"], "only the dark Spire on the chart before she's asked")
		var ports := Lanes.known_ports(_db, state)
		var told := _lines(state, "oda", [ASK, WHY])
		assert_true(told.contains("The Low Water.") and told.contains("Ferrymen won't sail what they can hear and can't see."), told)
		assert_true(told.contains("The Hollow Choir.") and told.contains("It's not the wind."), "the pilots' word for it")
		assert_true(told.contains("I'll not sail it."), "it's on the chart, not a lane")
		assert_true(bool(state.get_flag("kindleby_oda_low_water_asked")), burn)
		assert_eq(state.quest_stage("the_low_water"), "ask_a_keeper", burn)
		assert_eq(_shown(state), ["Cindermoor", "the Low Water"], "smudged onto the chart")
		assert_eq(Lanes.known_ports(_db, state), ports, "no new port: the Mercy won't sail it")
		# Asking again tells it again without starting anything twice.
		var again := _lines(state, "oda", [ASK, LIGHT])
		assert_true(again.contains("a Keepers' light on the biggest of the rocks"), again)
		assert_eq(state.quest_stage("the_low_water"), "ask_a_keeper")


func test_the_light_and_the_ring_held() -> void:
	var state := _kindleby()
	var told := _lines(state, "oda", [ASK, LIGHT])
	assert_true(told.contains("Keepers' water") and told.contains("it sings"), "the other way round to the same place")
	assert_false(told.contains("I've a deckhand"), "the deckhand's talk only if the ember held Kindleby's ring")
	state = _kindleby()
	state.set_flag("kindleby_ring_held", true)
	assert_true(_lines(state, "oda", [ASK, WHY]).contains("I've a deckhand who talks too much."))


func test_the_fog_sings_when_its_told_of() -> void:
	_content()
	var sounds: Array[String] = []
	for knot in [_db.dialogues["oda"]["knots"]["low_water_sings"], _db.dialogues["oda"]["knots"]["low_water_light"],
			_db.dialogues["hild"]["knots"]["low_water"]]:
		for step: Dictionary in knot:
			if step.has("sound"):
				sounds.append(str(step["sound"]))
	assert_eq(sounds, ["choir_far", "choir_far", "choir_far"], "Oda's and Hild's telling each hear it once")
	assert_true(_db.sounds.has("choir_far"), "a recipe")


func test_hild_will_row_once_the_weed_is_off() -> void:
	for skiff: String in ["home", "kindleby", "empty", "-"]:
		var state := _kindleby("boats", skiff)
		var offered: Array[String] = []
		_lines(state, "hild", [BYE], offered)
		assert_false(ROW in offered, "%s: nothing to ask before Oda's told of it" % skiff)
		_lines(state, "oda", [ASK, WHY])
		offered.clear()
		var told := _lines(state, "hild", [ROW, BYE], offered)
		assert_true(ROW in offered, skiff)
		assert_true(told.contains("Lowsong, the old brothers call the rock") and told.contains("When she's clean, I'll row you."), skiff)
		assert_true(told.contains("Then she sent me north anyway") == (skiff != "-"), "%s: the Provost said yes once already" % skiff)
		assert_eq(state.quest_stage("the_low_water"), "the_skiff", skiff)
		assert_true(bool(state.get_flag("kindleby_hild_low_water")), skiff)
		offered.clear()
		var later := _lines(state, "hild", [CLEAN, BYE], offered)
		assert_false(ROW in offered, "%s: asked once" % skiff)
		assert_true(later.contains("Not yet."), skiff)


func test_hild_talks_about_the_scraping() -> void:
	var state := _kindleby("boats", "kindleby")
	var told := _lines(state, "hild", [SCRAPING, BYE])
	assert_true(told.contains("Weed. The Northing's water grows it"), told)
	assert_true(told.contains("Big one wanted to row."), "the colliers came back in her skiff")
	assert_false(_lines(_kindleby("boats", "home"), "hild", [SCRAPING, BYE]).contains("Big one"), "not if they went home")


func test_hild_on_the_shingle_when_the_skiff_never_went_north() -> void:
	var placements := _hilds_placements()
	assert_eq(placements.size(), 2, "back from the Northing, or never gone")
	var cases := {"dark, never north": [_kindleby("", "-"), 0], "lit, never north": [_kindleby("boats", "-"), 1],
		"lit, back": [_kindleby("boats", "home"), 1], "lit, not landed yet": [_kindleby("boats", ""), 0]}
	for name: String in cases:
		var state: WorldState = cases[name][0]
		var here := 0
		for placed in placements:
			if Conditions.evaluate(placed.get("if"), state):
				here += 1
		assert_eq(here, cases[name][1], name)
	assert_eq(placements[0]["position"], placements[1]["position"], "at the skiff's bow either way (it lies in one place)")
	var met := _lines(_kindleby("boats", "-"), "hild", [BYE])
	assert_true(met.contains("Hild Garrow.") and met.contains("A boat you stop looking after starts forgetting she's a boat."), met)


func test_the_validator_checks_landmarks() -> void:
	var db := load_content()
	var v := ContentValidator.new(db)
	v._validate_lanes()
	assert_empty(v.errors, "the real chart is clean")
	db.lanes["landmarks"][1]["look"] = "whirlpool"
	db.lanes["landmarks"][1]["known"] = "flag:no_such_flag"
	v = ContentValidator.new(db)
	v._validate_lanes()
	var report := "\n".join(v.errors)
	assert_true(report.contains("look must be one of"), report)
	assert_true(report.contains("no_such_flag"), report)
