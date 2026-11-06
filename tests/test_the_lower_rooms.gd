extends TestCase
## Day 87 — what the Firstflame ate (Act III step 5). After the sitting the night passes by the chapter's candles
## (the story clock's first rest: `cindermoor_morning`); in the morning the chapter goes down the stair under the
## warden's seat to the lower rooms (a new region) and reads the Spire's own book: the Hushed of nine hundred
## midwinters "given" with what was in them, the fog as what was burned coming home, and the last page in the High
## Keeper's hand — Oriel Sayre, named here and not before. Who writes the Spire's line into the Long Book.

const FOOT := "cindermoor_spire_foot"
const LOWER := "cindermoor_lower_rooms"
const MORNING := "cindermoor_morning"
const READ := "cindermoor_spire_book_read"
const CHAPTER: Array[String] = ["provost", "hild", "iver", "wenna_coll"]

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


func _region(id: String) -> Dictionary:
	return _content().regions[id]


func _shown(region_id: String, npc: String, state: WorldState) -> bool:
	return (_region(region_id)["npcs"] as Array).any(func(n: Dictionary) -> bool:
		return str(n["npc"]) == npc and Conditions.evaluate(n.get("if", []), state))


func _object(region_id: String, id: String) -> Dictionary:
	for o: Dictionary in _region(region_id)["objects"]:
		if str(o["id"]) == id:
			return o
	return {}


## The checkpoint after the sitting with everyone aboard: Iver home (his lamp burned) and Wenna come to Kindleby.
func _sat(everyone: bool = true) -> WorldState:
	var state := _at("the_sitting")
	if everyone:
		state.set_flag("lowsong_iver_home", true)
		state.set_flag("lowsong_beacon_burned", "lamp")
		state.set_flag("thornwold_skiff", "kindleby")
		state.set_flag("thornwold_far_shore", "")
	return state


## Lies down by the candles, goes down the niche's stair and fires the reading; returns everything said.
func _read(state: WorldState, pick: String = "Write it in, Provost. In your own hand.") -> String:
	var told := _lines(state, "cindermoor_night")
	told += _lines(state, "cindermoor_niche", ["Go down the stair."])
	var event := RegionEvents.arrival(_region(LOWER), state)
	assert_eq(str(event.get("id", "")), "cindermoor_spire_book")
	return told + _lines(state, RegionEvents.fire(event, state), [pick])


func test_the_night_passes() -> void:
	var state := _sat()
	var rest := _object(FOOT, "foot_rest")
	assert_false(rest.is_empty())
	assert_true(Conditions.evaluate(rest["if"], state), "the rest is offered after the sitting")
	assert_false(Conditions.evaluate(rest["if"], _at("the_chapter")), "not before")
	var night := RegionMood.light(_region(FOOT), state)
	var told := _lines(state, "cindermoor_night")
	assert_true(told.contains("fourteen she kept back") and told.contains("Round, and round.") and told.contains("You stop at twelve."), told)
	assert_true(bool(state.get_flag(MORNING)))
	assert_false(Conditions.evaluate(rest["if"], state), "slept once")
	var morning := RegionMood.light(_region(FOOT), state)
	assert_true(morning["sun_energy"] > night["sun_energy"] and morning["sun_yaw"] > 0.0, "morning, the sun in the east")
	for id: String in ["cindermoor_boat_stair", "cindermoor_long_steps", FOOT]:
		assert_eq(RegionMood.light(_region(id), state)["sun_energy"], morning["sun_energy"], id + " in the morning too")
	state = _sat(false)
	assert_true(_lines(state, "cindermoor_night").contains("nobody lights them again"), "no Wenna, no relighting")


func test_the_chapter_goes_down_in_the_morning() -> void:
	var state := _sat()
	for npc: String in CHAPTER:
		assert_true(_shown(FOOT, npc, state) and not _shown(LOWER, npc, state), npc + " on the crown at night")
	var offered: Array[String] = []
	_lines(state, "cindermoor_niche", ["Leave the niche as it is."], offered)
	assert_false(offered.has("Go down the stair."), "nobody goes down before")
	assert_true(RegionEvents.arrival(_region(LOWER), state).is_empty(), "no reading at night (or on a debug jump)")
	_lines(state, "cindermoor_night")
	for npc: String in CHAPTER:
		assert_true(_shown(LOWER, npc, state) and not _shown(FOOT, npc, state), npc + " below in the morning")
	offered.clear()
	_lines(state, "cindermoor_niche", ["Leave the niche as it is."], offered)
	assert_true(offered.has("Go down the stair.") and not offered.has("Look down the stair under the seat."), str(offered))
	var runner := DialogueRunner.new(_content(), state)
	var ev := runner.start("cindermoor_niche")
	for i in 40:
		if ev["type"] == "end":
			break
		if ev["type"] == "choices":
			var texts: Array = (ev["options"] as Array).map(func(o: Dictionary) -> String: return str(o["text"]))
			ev = runner.choose(texts.find("Go down the stair."))
		else:
			ev = runner.next()
	var travel: Array = runner.pending_travel
	assert_eq(travel, [LOWER, "from_stair"])


func test_the_spire_book() -> void:
	var state := _sat()
	state.set_flag("cindermoor_roll_boats", true)
	var told := _read(state)
	assert_true(told.contains("Twelve steps, and the turn"), told)
	assert_true(told.contains("Said I'd keep some back for a stair."), "Wenna's fourteen: " + told)
	assert_true(told.contains("Given to the flame: Maud, of the Heron. Hushed. And what was in her."), told)
	assert_true(told.contains("The Hushed are not emptied. They are filled.") and told.contains("all it was given comes home"),
			"mystery #3: " + told)
	assert_true(told.contains("Brought up from the Quiet House") and told.contains("To keep them till they were full."), told)
	assert_true(told.contains("It is starved, and I am starving it.") and told.contains("Nobody chose that I should."), told)
	assert_true(told.contains("Oriel Sayre. High Keeper.") and told.contains("It didn't fail."), "named here: " + told)
	assert_true(told.contains("hands that asked to carry it"), "mystery #2 hook (the Hood-Pin's 'tonight'): " + told)
	assert_true(told.contains("not a comma moved") or told.contains("And not a comma moved."), "Iver's commas: " + told)
	assert_true(told.contains("That's what you did with them."), "Wenna's charcoal: " + told)
	assert_true(told.contains("We chose for them. And then we chose them."), told)
	assert_true(told.contains("It was always the eighth.") and told.contains("Kept back, the roll says. Her word."), told)
	assert_true(bool(state.get_flag(READ)))
	assert_eq(state.quest_stage("the_chapter"), "the_spire_book")
	assert_true(RegionEvents.arrival(_region(LOWER), state).is_empty(), "read once")
	assert_false(told.contains("Isolde"), "mystery #4 waits")


func test_the_reading_without_iver_or_wenna() -> void:
	var state := _sat(false)
	state.set_flag("lowsong_iver_home", false)
	var told := _read(state)
	assert_true(told.contains("Aldous's bundle of tapers") and told.contains("Hild reads over the Provost's shoulder"), told)
	assert_false(told.contains("Lorn,") or told.contains("charcoal"), told)
	assert_true(told.contains("It was always the eighth.") and not told.contains("Her word."), "the roll's back unread: " + told)
	assert_true(told.contains("Oriel Sayre. High Keeper."))


func test_the_sitting_colours_the_first_lines() -> void:
	var lines := {
		"offered": "Read this first. Then offer it",
		"asked": "Aldous sat on the lid of it thirty-one years",
		"silent": "Down here you may say what you like.",
	}
	for spoke: String in lines:
		var state := _sat()
		state.set_flag("cindermoor_sitting_spoke", spoke)
		var told := _read(state)
		assert_true(told.contains(lines[spoke]), spoke + ": " + told)
		assert_eq(told.contains("You think about what it's fed on"), spoke == "offered", spoke)


func test_who_writes_the_spires_line() -> void:
	var picks := {
		"Write it in, Provost. In your own hand.": ["provost", "I never asked.", "In my hand. I'd sooner it were anybody's."],
		"Give me the pen. I'll write it.": ["hand", "you didn't know it would", "You didn't have to think about the letters."],
		"Leave it unwritten. Not yet.": ["open", "That's never been done either.", "the only page in the Long Book anybody's ever left open"],
	}
	for pick: String in picks:
		var state := _sat()
		var told := _read(state, pick)
		assert_eq(str(state.get_flag("cindermoor_spire_line")), picks[pick][0])
		assert_true(told.contains(picks[pick][1]), pick + ": " + told)
		assert_true(_lines(state, "provost").contains(picks[pick][2]), pick)


func test_after_the_reading() -> void:
	var state := _at("the_lower_rooms")
	assert_eq(str(Scenarios.resolve("the_lower_rooms")["region"]), LOWER)
	state.set_flag("lowsong_iver_home", true)
	state.set_flag("lowsong_beacon_burned", "lamp")
	state.set_flag("thornwold_skiff", "kindleby")
	assert_true(_lines(state, "hild").contains("Three still in the Quiet House"))
	assert_true(_lines(state, "iver").contains("wind in the skerries"))
	assert_true(_lines(state, "wenna_coll").contains("Fourteen."))
	assert_true(_lines(state, "provost").contains("The chapter will sit again before it chooses."))
	var book := _lines(state, "cindermoor_lectern", ["Read the last line again."])
	assert_true(book.contains("Oriel Sayre") and book.contains("somebody hid their face"), book)
	assert_true(_lines(state, "cindermoor_benches").contains("full, humming"))
	assert_true(_lines(state, "cindermoor_flame_root").contains("No smell of fire."))
	var exits: Array = _region(LOWER)["exits"]
	assert_eq(exits.size(), 1)
	assert_eq([str(exits[0]["to"]), str(exits[0]["spawn"])], [FOOT, "from_lower"])
	assert_true((_region(FOOT)["spawn_points"] as Dictionary).has("from_lower"))
	var v := ContentValidator.new(load_content())
	assert_true(v.validate(), "\n".join(v.errors))


func test_the_lower_rooms_are_under_a_roof() -> void:
	var props: Array = _region(LOWER)["props"]
	var vault: Array = props.filter(func(p: Dictionary) -> bool: return str(p.get("model", "")).ends_with("lower_vault.glb"))
	assert_eq(vault.size(), 1, "the rock overhead keeps the sky out")
	assert_false(vault[0].has("if"))
	var lit: Array = props.filter(func(p: Dictionary) -> bool: return p.has("light"))
	assert_eq(lit.size(), 1, "one small light: the candles on the ledge")
	assert_false(_region(LOWER).has("greying"), "no Greying under the rock")
