extends TestCase
## Day 69 — Act II's close begins: *What the Ember Keeps*. As the Vigil Light (the fifth light) catches, its
## smoke closes round the Wakebearer's hand and leaves the Stair-Taper in it: the first of the Wakebearer's
## own Remnants (item kind `own`). The Provost, Brother Tobin and Brother Aldous know what it is.

const BY := "kindleby"
const OFFER := "My ember could hold the ring while the chapter sits."
const LIGHT := "What would it take to light the Vigil Light?"
const BOW := "I'll bow to the rite."
const SPARE := "What would you spare, if you were choosing?"
const CARRY := "I'll carry it."
const SET_BOATS := "Set the Boats' Lantern in the cradle."
const SET_PAN := "Set Tobin's coal-pan in the cradle."
const BURN_BOATS := "Burn Kindleby's night of the boats."
const BURN_PAN := "Burn Tobin's calling."
const SHOW_PROVOST := "This came out of the Vigil Light's smoke, into my hand."
const SHOW_TOBIN := "Do you know what this is? It came out of the Vigil Light's smoke."
const SHOW_ALDOUS := "Look at this, Brother. It came out of the smoke on Kindleby, into my hand."
const BYE := "Goodbye."
const REST := "Rest easy, Brother."

var _db: ContentDatabase


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_db, state, dialogue, typed, offered)


func _offered(state: WorldState, dialogue: String, leave: String) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [leave], offered)
	return offered


## Four lights lit, on Kindleby with the rite bowed to and the ring held: the Boats' Lantern in hand.
func _on_the_crown() -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "thornwold_landed", "fen_landed", "wrackholm_landed",
			"wrackholm_oda_lane_asked", "kindleby_landed", "saltmarrow_met_aldous"]:
		state.set_flag(flag, true)
	state.set_flag("saltmarrow_beacon_burned", "knot")
	state.set_flag("thornwold_beacon_burned", "boots")
	state.set_flag("fen_beacon_burned", "channels")
	state.set_flag("wrackholm_beacon_burned", "board")
	state.set_flag("lanes_ferry_at", BY)
	state.set_flag("thornwold_far_shore", "up")
	for quest: String in ["across_the_grey", "a_light_for_saltmarrow", "a_light_for_thornwold", "a_light_for_glasswater",
			"a_light_for_wrackholm"]:
		state.complete_quest(quest)
	state.start_quest("a_light_for_kindleby", "the_candles")
	_lines(state, "provost")
	_lines(state, "provost", [LIGHT, BOW])
	_lines(state, "provost", [OFFER])
	_lines(state, "vigil_door")
	assert_eq(state.quest_stage("a_light_for_kindleby"), "feed_the_light")
	return state


## Kindleby lit on `burn` (boats / pan).
func _lit(burn: String) -> WorldState:
	var state := _on_the_crown()
	if burn == "pan":
		_lines(state, "tobin", [SPARE, CARRY])
	_lines(state, "vigil_door", [SET_BOATS if burn == "boats" else SET_PAN, BURN_BOATS if burn == "boats" else BURN_PAN])
	assert_eq(state.get_flag("kindleby_beacon_burned"), burn)
	return state


func test_the_ember_gives_something_back_as_the_fifth_light_catches() -> void:
	for burn: String in ["boats", "pan"]:
		var state := _on_the_crown()
		if burn == "pan":
			_lines(state, "tobin", [SPARE, CARRY])
		assert_eq(state.item_count("stair_taper"), 0, "nothing before the burning")
		var lit := _lines(state, "vigil_door", [SET_BOATS if burn == "boats" else SET_PAN, BURN_BOATS if burn == "boats" else BURN_PAN])
		assert_true(lit.contains("The Vigil Light catches.") and lit.contains("This one hums with yours."), burn)
		assert_true(lit.contains("a name, and you know the name is yours, and it doesn't come"), burn)
		assert_eq(state.item_count("stair_taper"), 1, burn)
		assert_true(bool(state.get_flag("kindleby_stair_taper")), burn)
		assert_eq(state.quest_stage("what_the_ember_keeps"), "the_taper", burn)
		var again := _lines(state, "vigil_door")
		assert_true(again.contains("burns gold") and not again.contains("This one hums with yours."), "%s: given once" % burn)
		assert_eq(state.item_count("stair_taper"), 1, burn)


func test_a_save_lit_before_day_69_gets_it_at_the_door() -> void:
	var state := _lit("boats")
	state.remove_item("stair_taper")
	state.set_flag("kindleby_stair_taper", false)
	state.quests.erase("what_the_ember_keeps")
	var door := _lines(state, "vigil_door")
	assert_true(door.contains("You put your hand to the open door") and door.contains("This one hums with yours."), door)
	assert_eq(state.item_count("stair_taper"), 1)
	assert_eq(state.quest_stage("what_the_ember_keeps"), "the_taper")
	assert_true(_lines(state, "vigil_door").contains("burns gold"))


func test_it_is_the_wakebearers_own() -> void:
	var state := _lit("boats")
	assert_eq(str(_db.get_item("stair_taper")["kind"]), "own")
	var entries := JournalModel.item_entries(_db, state)
	assert_eq(str(entries[0]["id"]), "stair_taper", "your own first")
	assert_true(entries[0]["own"] and entries[0]["remnant"])
	assert_eq(str(entries[0]["kind_label"]), "Remnant · your own")
	state.add_item("humming_pebble")
	entries = JournalModel.item_entries(_db, state)
	assert_eq(str(entries[0]["id"]), "stair_taper", "before other Remnants")
	assert_eq(str(entries[1]["id"]), "humming_pebble")
	assert_false(entries[1]["own"])


func test_the_provost_knows_a_novices_light() -> void:
	for letter: bool in [false, true]:
		var state := _lit("boats")
		state.set_flag("kindleby_provost_read_letter", letter)
		assert_true(_offered(state, "provost", BYE).has(SHOW_PROVOST))
		var said := _lines(state, "provost", [SHOW_PROVOST, BYE])
		assert_true(said.contains("A stair-taper.") and said.contains("A notch for every landing"), said)
		assert_true(said.contains("they all had the same face under the hood"))
		assert_eq(said.contains("Going down. Not going out."), letter, "the letter remembered")
		assert_true(said.contains("They'd want to weigh it."))
		assert_true(bool(state.get_flag("kindleby_provost_saw_taper")))
		assert_eq(state.quest_stage("what_the_ember_keeps"), "a_novices_light")
		assert_false(_offered(state, "provost", BYE).has(SHOW_PROVOST), "asked once")


func test_tobin_knows_it_unless_his_calling_burned() -> void:
	for burn: String in ["boats", "pan"]:
		var state := _lit(burn)
		var said := _lines(state, "tobin", [SHOW_TOBIN, BYE])
		assert_eq(said.contains("The letter in my pan said they'd give me one"), burn == "boats", burn)
		assert_eq(said.contains("I feel like I ought to know that."), burn == "pan", burn)
		assert_eq(state.quest_stage("what_the_ember_keeps"), "the_taper", "%s: Tobin's never seen the stair" % burn)
		assert_false(_offered(state, "tobin", BYE).has(SHOW_TOBIN), burn)


func test_aldous_cut_it() -> void:
	for confessed: String in ["full", "grudging"]:
		for novice: String in ["", "self", "lamp"]:
			var state := _lit("boats")
			state.set_flag("saltmarrow_aldous_confessed", confessed)
			state.set_flag("saltmarrow_aldous_novice", novice)
			var case := "%s/%s" % [confessed, novice]
			assert_true(_offered(state, "aldous", REST).has(SHOW_ALDOUS), case)
			var said := _lines(state, "aldous", [SHOW_ALDOUS, REST])
			assert_true(said.contains("That's one of mine.") and said.contains("You'll know which stair."), case)
			assert_eq(said.contains("I heard them counting."), confessed == "full", case)
			assert_eq(said.contains("I still don't know. I like it less."), novice == "self", case)
			assert_eq(said.contains("Seven lights up and seven down"), not novice.is_empty(), case)
			assert_eq(state.quest_stage("what_the_ember_keeps"), "a_novices_light", case)
			assert_false(_offered(state, "aldous", REST).has(SHOW_ALDOUS), case)


func test_no_ones_own_remnant_lies_about() -> void:
	var db := load_content()
	var shingle: Dictionary = db.get_region("shingle_point")
	(shingle["pickups"] as Array).append({"id": "a_taper_on_the_beach", "item": "stair_taper", "position": [0, 0, 0]})
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "an own Remnant as a pickup fails")
	assert_true(validator.report().contains("only the ember gives those up"), validator.report())


func test_the_checkpoint() -> void:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	Scenarios.apply(_db, state, Scenarios.resolve("the_stair_taper"))
	assert_eq(state.item_count("stair_taper"), 1)
	assert_eq(state.quest_stage("what_the_ember_keeps"), "the_taper")
	assert_true(_lines(state, "vigil_door").contains("burns gold"), "no second taper at the door")
	assert_eq(state.item_count("stair_taper"), 1)
