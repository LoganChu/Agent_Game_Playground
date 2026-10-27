extends TestCase
## Day 66 — *The Skiff North* and *A Boat for Aldous*. Kindleby's skiff, sent while the chapter sat, comes in
## to the Northing's boat-stage where the colliers wait (Sister Hild Garrow and Sister Pim, oil, meal and a
## lantern). Wenna wants telling: home up the steps (The Far Shore's `up` homecoming follows) or south with
## the sisters to keep candles on Kindleby; if they'd already gone up, the sisters find the stage empty.
## Aldous's answer to the Provost's boat: a letter carried to Kindleby (the page for what was seen), or no.

const SHORE := "thornwold_far_shore"
const WOODS := "thornwold_woods"
const BY := "kindleby"
const DOWN := "Go down the Keepers' steps."
const WAIT := "Wait for it, then. I'll tell the Spire you're here."
const UP := "Come up. Somebody came down for you: me."
const WHAT := "What's on Kindleby?"
const HOME := "Take the meal and go home, Wenna. Up the steps. The road's lit."
const SOUTH := "Go with the sisters. Kindleby keeps a fire that's never out."
const NOT_YET := "Not yet."
const BOAT := "The Provost of Kindleby says she'd send a boat for you."
const WRITE := "Then write it down. I'll carry it to her."
const DONT := "Then don't go."
const TOLD_ALDOUS := "Aldous told me the High Keeper put the flame out."
const LETTER := "Aldous Wren wrote to you."
const BYE := "Goodbye."
const KIT := "res://assets/models/dressing/"

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


func _offered(state: WorldState, dialogue: String) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [NOT_YET], offered)
	return offered


## Thornwold lit, The Northing done (`northing`), the colliers told to wait on the stage (Hob with them if
## `hob`), then Kindleby lit with the Provost told of the stage: the skiff has gone north.
func _waiting(northing: String = "carried", hob: bool = true) -> WorldState:
	var state := fresh_state(_content())
	for flag: String in ["intro_seen", "thornwold_landed", "thornwold_met_bram", "thornwold_met_hob", "thornwold_hob_paid",
			"thornwold_met_lamp", "thornwold_ladder_stood", "thornwold_ridge_reached", "thornwold_lamp_ladder_told",
			"thornwold_lamp_saw_light", "thornwold_hob_came_in", "thornwold_old_road_reached", "thornwold_met_ottie",
			"thornwold_salt_row_away", "kindleby_landed", "kindleby_met_provost"]:
		state.set_flag(flag, true)
	state.set_flag("thornwold_beacon_burned", "salt_row")
	state.set_flag("thornwold_northing", northing)
	if hob:
		state.set_flag("thornwold_hob_ladder", "gone")
	for quest: String in ["a_light_for_thornwold", "the_northing"]:
		state.complete_quest(quest)
	_lines(state, "keepers_steps", [DOWN])
	_lines(state, RegionEvents.fire(RegionEvents.arrival(_content().get_region(SHORE), state), state))
	_lines(state, "wenna_coll", [WAIT])
	assert_eq(str(state.get_flag("thornwold_far_shore")), "waiting")
	state.set_flag("kindleby_told_of_stage", true)
	state.set_flag("kindleby_rite", "bowed")
	state.set_flag("kindleby_beacon_burned", "boats")
	state.complete_quest("a_light_for_kindleby")
	state.set_flag("kindleby_skiff_north", true)
	state.start_quest("the_skiff_north", "rowing_north")
	return state


## As `_waiting`, gone back down to the shore and seen the skiff come in.
func _landed(northing: String = "carried", hob: bool = true) -> WorldState:
	var state := _waiting(northing, hob)
	var event := RegionEvents.arrival(_content().get_region(SHORE), state)
	assert_eq(str(event.get("id", "")), "skiff_landing")
	_lines(state, RegionEvents.fire(event, state))
	return state


func _shown(state: WorldState, region: String) -> Array[String]:
	var out: Array[String] = []
	for placement: Dictionary in _content().get_region(region)["npcs"]:
		if Conditions.evaluate(placement.get("if"), state):
			out.append(str(placement["npc"]))
	out.sort()
	return out


func _props(state: WorldState, region: String, model: String) -> int:
	var n := 0
	for p: Dictionary in _content().get_region(region)["props"]:
		if str(p.get("model", "")).get_file().get_basename() == model and Conditions.evaluate(p.get("if"), state):
			n += 1
	return n


func test_the_skiff_goes_north_with_a_quest() -> void:
	var sets_out := false
	for knot: Array in (_content().get_dialogue("vigil_door")["knots"] as Dictionary).values():
		for step: Dictionary in knot:
			if (step.get("set", {}) as Dictionary).has("kindleby_skiff_north"):
				sets_out = str(step.get("quest_start", "")) == "the_skiff_north"
	assert_true(sets_out, "the skiff's quest starts as it rows off")
	# A save from before Day 66: the Provost starts it.
	var state := _waiting()
	state.quests.erase("the_skiff_north")
	var text := _lines(state, "provost", [BYE])
	assert_true(text.contains("The skiff's gone north"))
	assert_eq(state.quest_stage("the_skiff_north"), "rowing_north")
	assert_eq(_props(state, BY, "kindleby_skiff"), 0, "gone from Kindleby's shingle")


func test_the_skiff_comes_in() -> void:
	var state := _waiting()
	var shore := _content().get_region(SHORE)
	var event := RegionEvents.arrival(shore, state)
	assert_eq(str(event.get("id", "")), "skiff_landing")
	var text := _lines(state, RegionEvents.fire(event, state))
	assert_true(text.contains("Kindleby skiff. Sister Hild Garrow"))
	assert_true(text.contains("...He did say a boat."), "the Drays agree")
	assert_true(text.contains("There. A boat."), "Ottie, who carried the lantern down")
	assert_true(text.contains("Two Keepers and the four."), "Hob counts them separate")
	assert_true(RegionEvents.arrival(shore, state).is_empty(), "once")
	assert_eq(state.quest_stage("the_skiff_north"), "the_word")
	assert_eq(_props(state, SHORE, "kindleby_skiff_stage"), 1, "alongside the stage")
	assert_eq(_props(state, SHORE, "keeper_pim"), 1, "Sister Pim at the line")
	assert_true(_shown(state, SHORE).has("hild"))
	assert_true(_lines(state, "boat_stage").contains("Kindleby's skiff lies alongside"))
	var offered := _offered(state, "wenna_coll")
	for option: String in [WHAT, HOME, SOUTH, NOT_YET]:
		assert_true(offered.has(option), option)
	text = _lines(state, "wenna_coll", [WHAT, NOT_YET])
	assert_true(text.contains("The Quiet House. That's for the Hushed."))
	assert_true(text.contains("the Vigil Light lit"))
	assert_eq(str(state.get_flag("thornwold_skiff")), "", "not yet")
	assert_true(_lines(state, "hild", [BYE]).contains("I'm not to argue and I'm not to hurry them."))
	assert_true(_lines(state, "abe").contains("Came, didn't it."))
	assert_true(_lines(state, "tolly").contains("He's going to be like this for a year."))
	assert_true(_lines(state, "ottie").contains("Boat came. Not the one."))


func test_home_up_the_steps() -> void:
	var state := _landed()
	var text := _lines(state, "wenna_coll", [HOME])
	assert_eq(str(state.get_flag("thornwold_skiff")), "home")
	assert_eq(str(state.get_flag("thornwold_far_shore")), "up", "The Far Shore's homecoming follows")
	assert_eq(state.quest_state("the_skiff_north"), "done")
	assert_true(text.contains("Keep your lantern, sister."))
	assert_true(text.contains("Abe. Tolly. Up."), "the way up, as before")
	assert_true(text.contains("For the skiff, next time."))
	assert_false(text.contains("For the boat. Somebody should be lit for it, if it comes."))
	assert_true(text.contains("Tell your Provost we went home"))
	assert_false(text.contains("Tell the boat we went home."))
	assert_eq(_shown(state, SHORE), [] as Array[String], "the shore's empty; the skiff's gone south")
	assert_eq(_props(state, SHORE, "kindleby_skiff_stage"), 0)
	assert_true(_shown(state, WOODS).has("wenna_coll"), "home in the clearing")
	assert_eq(_props(state, BY, "kindleby_skiff"), 1, "back on Kindleby's shingle")
	assert_true(_shown(state, BY).has("hild"))
	assert_false(_shown(state, BY).has("wenna_coll"))
	assert_true(_lines(state, "hild").contains("They took the meal and went up the steps"))
	assert_true(_lines(state, "provost", [BYE]).contains("went home up the steps. Good. I'd have kept them, gladly."))


func test_south_to_kindleby() -> void:
	var state := _landed()
	var text := _lines(state, "wenna_coll", [SOUTH])
	assert_eq(str(state.get_flag("thornwold_skiff")), "kindleby")
	assert_eq(str(state.get_flag("thornwold_far_shore")), "waiting", "they never went up")
	assert_eq(state.quest_state("the_skiff_north"), "done")
	assert_true(text.contains("draws it back through the whole long count"))
	assert_true(text.contains("...Wenna's going. I'll go."))
	assert_true(text.contains("Four in a boat."))
	assert_true(text.contains("tell them we went to keep candles"))
	assert_eq(_shown(state, SHORE), [] as Array[String], "everybody got in")
	assert_eq(_props(state, SHORE, "drift_fire"), 0)
	assert_eq(_props(state, SHORE, "drift_fire_out"), 1, "raked out")
	assert_eq(_props(state, SHORE, "kindleby_skiff_stage"), 0)
	assert_eq(_shown(state, BY), ["abe", "hild", "hob", "ottie", "provost", "tobin", "tolly", "wenna_coll"] as Array[String])
	assert_false(_shown(state, WOODS).has("wenna_coll"), "not home on Thornwold")
	assert_false(_shown(state, WOODS).has("ottie"))
	assert_true(_lines(state, "wenna_coll", ["Did you find what you wanted here?", "Goodbye, Wenna."]).contains("Wrote it all down"))
	assert_true(_lines(state, "abe").contains("It's always been a thumbnail."))
	assert_true(_lines(state, "tolly").contains("Who bars a door on the outside?"))
	assert_true(_lines(state, "ottie").contains("Somebody should look north."))
	assert_true(_lines(state, "hob").contains("Four colliers by the chapter-house fire"))
	assert_true(_lines(state, "hild").contains("Your colliers keep candles like they were born to it."))
	assert_true(_lines(state, "provost", [BYE]).contains("Your colliers are on my wall."))
	assert_true(_lines(state, "boat_stage").contains("One line is drawn back through the whole count"))
	assert_true(_lines(state, "lamp", [BYE]).contains("Keepers' skiff, the one that brought my meal."))
	assert_false(_lines(state, "lamp", [BYE]).contains("Still on the stage, are they."))


func test_south_with_ottie_home() -> void:
	var state := _landed("lit", true)
	var text := _lines(state, "wenna_coll", [SOUTH])
	assert_false(text.contains("Wenna's going. I'll go."), "Ottie went home from the Northing")
	assert_true(text.contains("Three in a boat, and Ottie home in his boots."))
	assert_eq(_shown(state, BY), ["abe", "hild", "hob", "provost", "tobin", "tolly", "wenna_coll"] as Array[String])
	assert_true(_shown(state, WOODS).has("ottie"), "still on his seat")
	assert_true(_lines(state, "hob").contains("Ottie home on Thornwold in his boots. Four."))
	state = _landed("lit", false)
	_lines(state, "wenna_coll", [SOUTH])
	assert_eq(_shown(state, BY), ["abe", "hild", "provost", "tobin", "tolly", "wenna_coll"] as Array[String])


func test_the_stage_found_empty() -> void:
	var state := _waiting()
	_lines(state, "wenna_coll", ["Come up, Wenna. It's not too late to go home."])
	assert_eq(str(state.get_flag("thornwold_far_shore")), "up")
	var event := RegionEvents.arrival(_content().get_region(SHORE), state)
	assert_eq(str(event.get("id", "")), "skiff_landing")
	var text := _lines(state, RegionEvents.fire(event, state))
	assert_true(text.contains("...Nobody's on the Northing's stage."))
	assert_true(text.contains("Somebody's left a light on the bracket for us."))
	assert_eq(str(state.get_flag("thornwold_skiff")), "empty")
	assert_eq(state.quest_state("the_skiff_north"), "done")
	assert_false(_shown(state, SHORE).has("hild"))
	assert_true(_shown(state, BY).has("hild"))
	assert_true(_lines(state, "hild").contains("Nobody on the stage."))
	assert_true(_lines(state, "provost", [BYE]).contains("The skiff came back with nobody in it."))


## Aldous confessed (`confessed`), the Provost met on Kindleby.
func _aldous(confessed: String) -> WorldState:
	var state := fresh_state(_content())
	for flag: String in ["intro_seen", "saltmarrow_met_aldous", "kindleby_landed", "kindleby_met_provost"]:
		state.set_flag(flag, true)
	state.set_flag("saltmarrow_aldous_confessed", confessed)
	state.complete_quest("a_light_for_saltmarrow")
	return state


func test_a_letter_for_the_provost() -> void:
	var state := _aldous("full")
	assert_false(_offered(state, "aldous").has(BOAT), "not till the Provost says it")
	var text := _lines(state, "provost", [TOLD_ALDOUS, BYE])
	assert_true(text.contains("I'd send a boat for him. Tell him so."))
	assert_eq(state.quest_stage("a_boat_for_aldous"), "tell_aldous")
	text = _lines(state, "aldous", [BOAT, WRITE])
	assert_true(text.contains("put me on report twice in one winter"))
	assert_true(text.contains("with a light going past me"))
	assert_true(text.contains("It's mostly apologising."))
	assert_true(text.contains("It looks smaller, written."))
	assert_eq(str(state.get_flag("saltmarrow_aldous_boat")), "letter")
	assert_true(state.item_count("aldous_letter") > 0)
	assert_eq(state.quest_stage("a_boat_for_aldous"), "the_letter")
	assert_false(_offered(state, "aldous").has(BOAT), "answered once")
	text = _lines(state, "provost", [LETTER, BYE])
	assert_true(text.contains("He spelled my name wrong. He always did."))
	assert_true(text.contains("Going down. Not going out."))
	assert_true(text.contains("a page at the back of the Long Book for what was seen"))
	assert_false(state.item_count("aldous_letter") > 0)
	assert_true(bool(state.get_flag("kindleby_provost_read_letter")))
	assert_eq(state.quest_state("a_boat_for_aldous"), "done")
	assert_false(_offered(state, "provost").has(LETTER))


func test_aldous_wont_go() -> void:
	var state := _aldous("grudging")
	_lines(state, "provost", [TOLD_ALDOUS, BYE])
	var text := _lines(state, "aldous", [BOAT, DONT])
	assert_false(text.contains("with a light going past me"), "only the bare fact was told")
	assert_true(text.contains("Tell her I'm sorry about the reports."))
	assert_eq(str(state.get_flag("saltmarrow_aldous_boat")), "no")
	assert_false(state.item_count("aldous_letter") > 0)
	assert_eq(state.quest_state("a_boat_for_aldous"), "done")
	assert_false(_offered(state, "provost").has(LETTER))
	# A save from before Day 66: the Provost was told, but no quest yet; Aldous starts it.
	state = _aldous("full")
	state.set_flag("kindleby_provost_heard_aldous", true)
	_lines(state, "aldous", [BOAT, WRITE])
	assert_eq(state.quest_stage("a_boat_for_aldous"), "the_letter")
