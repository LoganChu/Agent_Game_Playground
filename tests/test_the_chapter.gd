extends TestCase
## Day 85 — the chapter comes in (Act III step 4). Back down off the moor once the crown has been reached, the first
## of the seven Spire boats comes in to the Boat Stair under oars with the Provost and what of the chapter she could
## put in a boat (Hild always; Iver if he rowed home; Wenna if the colliers went to keep candles). Merrit holds the
## bow. The Provost lays the chapter's claim on the Wakebearer, asks to weigh the own Remnants, hears of the scraped
## roll, and — if Ness led the Wakebearer up in the dark — has Hild relight the doused cresset.

const STAIR := "cindermoor_boat_stair"
const STEPS := "cindermoor_long_steps"
const CAME := "cindermoor_chapter_came"

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


## The Spire's foot reached the way Ness walks it: led up in the dark, the doused cresset left doused.
func _led_up() -> WorldState:
	var state := _at("the_spire_foot")
	state.set_flag("cindermoor_cresset_steps_5", false)
	state.set_flag("cindermoor_way_on", "led")
	return state


## Fires the Boat Stair's arrival (the chapter's boat) and returns what it said.
func _come_in(state: WorldState) -> String:
	var event := RegionEvents.arrival(_region(STAIR), state)
	assert_eq(str(event.get("id", "")), "cindermoor_chapter_in")
	return _lines(state, RegionEvents.fire(event, state))


func _placed(region_id: String, npc: String) -> Array:
	return (_region(region_id)["npcs"] as Array).filter(func(n: Dictionary) -> bool: return str(n["npc"]) == npc)


func test_the_boat_comes_in_once_after_the_crown() -> void:
	var state := _at("the_unmoored")
	assert_true(RegionEvents.arrival(_region(STAIR), state).is_empty(), "not before the crown")
	state = _at("the_spire_foot")
	var boat: Array = (_region(STAIR)["props"] as Array).filter(func(p: Dictionary) -> bool: return str(p.get("model", "")).ends_with("chapter_boat.glb"))
	assert_eq(boat.size(), 1)
	assert_false(Conditions.evaluate(boat[0]["if"], state), "no boat at the quay before it comes in")
	var told := _come_in(state)
	assert_true(told.contains("I scarfed that stem.") and told.contains("You hold the bow"), told)
	assert_true(told.contains("Novice.") and told.contains("She doesn't correct him."), told)
	assert_true(told.contains("ring it anyway") and told.contains("do it properly"), told)
	assert_true(bool(state.get_flag(CAME)))
	assert_eq(state.quest_stage("the_chapter"), "come_in")
	assert_true(Conditions.evaluate(boat[0]["if"], state), "the boat lies alongside")
	assert_true(RegionEvents.arrival(_region(STAIR), state).is_empty(), "once")


func test_who_comes_in_the_boat() -> void:
	var state := _at("the_spire_foot")
	var told := _come_in(state)
	var iver_home := bool(state.get_flag("lowsong_iver_home"))
	var wenna_came := str(state.get_flag("thornwold_skiff")) == "kindleby" and str(state.get_flag("thornwold_far_shore")) != "up"
	assert_eq(told.contains("Brother Iver comes up after her"), iver_home, told)
	assert_eq(told.contains("Wenna Coll comes last"), wenna_came, told)
	# Iver home, the colliers keeping candles on Kindleby, the boats burned: all three show.
	state = _at("the_spire_foot")
	state.set_flag("lowsong_iver_home", true)
	state.set_flag("lowsong_beacon_burned", "lamp")
	state.set_flag("thornwold_skiff", "kindleby")
	state.set_flag("thornwold_far_shore", "")
	state.set_flag("kindleby_beacon_burned", "boats")
	state.set_flag("cindermoor_merrit_seven_lit", true)
	told = _come_in(state)
	assert_true(told.contains("Brother Iver comes up after her") and told.contains("Wenna Coll comes last"), told)
	assert_true(told.contains("nobody could tell me whose she was") and not told.contains("Brother Anselm rowed her"), told)
	assert_true(told.contains("Somebody has come in."), "Merrit's seven, paid: " + told)
	for npc: String in ["provost", "hild", "iver", "wenna_coll"]:
		var here := _placed(STAIR, npc).filter(func(e: Dictionary) -> bool: return Conditions.evaluate(e.get("if", []), state))
		assert_eq(here.size(), 1, npc)
		assert_true(Conditions.evaluate(here[0]["if"], state), npc + " on the quay")
		for k: Dictionary in _placed("kindleby", npc):
			assert_false(Conditions.evaluate(k.get("if", []), state), npc + " no longer on Kindleby")
	assert_true(_lines(state, "iver").contains("I can't stop."))
	assert_true(_lines(state, "wenna_coll").contains("Usually it's will you."))
	# The pan burned: Kindleby remembers the night of the boats, and Anselm.
	state = _at("the_spire_foot")
	state.set_flag("kindleby_beacon_burned", "pan")
	told = _come_in(state)
	assert_true(told.contains("Brother Anselm rowed her over") and not told.contains("Somebody has come in."), told)


func test_the_claim() -> void:
	var state := _at("the_chapter")
	var told := _lines(state, "provost", ["The chapter can sit. I'll hear what it says.", "Leave her to the quay."])
	assert_true(told.contains("The hand. Not the choosing.") and told.contains("That's all I ask. Today."), told)
	assert_eq(str(state.get_flag("cindermoor_chapter_claim")), "heard")
	assert_eq(state.quest_stage("the_chapter"), "the_claim")
	told = _lines(state, "provost", ["Leave her to the quay."])
	assert_false(told.contains("The hand."), "said once: " + told)
	state = _at("the_chapter")
	state.set_flag("kindleby_rite", "refused")
	told = _lines(state, "provost", ["I've chosen six times. I'll choose the seventh.", "Leave her to the quay."])
	assert_true(told.contains("I'm not asking this time.") and told.contains("We write everything down."), told)
	assert_eq(str(state.get_flag("cindermoor_chapter_claim")), "refused")


func test_she_asks_to_weigh_what_is_yours() -> void:
	var state := _at("the_chapter")
	assert_true(state.item_count("stair_taper") > 0 and state.item_count("hood_pin") > 0, "both own Remnants carried by now")
	state.set_flag("kindleby_provost_saw_taper", true)
	var told := _lines(state, "provost", ["The chapter can sit. I'll hear what it says.", "Let her hold the Stair-Taper and the Hood-Pin.", "Put the Stair-Taper and the Hood-Pin in her hands.", "Leave her to the quay."])
	assert_true(told.contains("The chapter's come to it.") and told.contains("a bit of bone") and told.contains("Not yet."), told)
	assert_eq(str(state.get_flag("cindermoor_chapter_weigh")), "shown")
	assert_true(state.item_count("stair_taper") > 0 and state.item_count("hood_pin") > 0, "weighing isn't taking")
	var offered: Array[String] = []
	_lines(state, "provost", ["Leave her to the quay."], offered)
	assert_false(offered.has("Let her hold the Stair-Taper and the Hood-Pin."), "asked once")
	assert_true(_lines(state, "hild").contains("Longer than she holds most things."))
	state = _at("the_chapter")
	told = _lines(state, "provost", ["The chapter can sit. I'll hear what it says.", "Let her hold the Stair-Taper and the Hood-Pin.", "No. They're mine.", "Leave her to the quay."])
	assert_true(told.contains("it'll weigh you instead") and not told.contains("The chapter's come to it."), told)
	assert_eq(str(state.get_flag("cindermoor_chapter_weigh")), "kept")
	assert_true(_lines(state, "hild").contains("You told her no."))


func test_the_scraped_roll_told_to_a_keeper() -> void:
	for ask: String in ["Then it wasn't a Keeper.", "Who kept the roll?"]:
		var state := _at("the_chapter")
		var told := _lines(state, "provost", ["The chapter can sit. I'll hear what it says.", "Tell her about the novices' roll.", "Scraped. Down to the skin, with a blade.", ask, "Leave her to the quay."])
		assert_true(told.contains("Struck through.") and told.contains("it only finishes") and told.contains("I'll want to see it."), told)
		assert_eq(told.contains("could reach the peg"), ask == "Then it wasn't a Keeper.", told)
		assert_eq(told.contains("The door-warden. Aldous."), ask == "Who kept the roll?", told)
		assert_false(told.contains("Oriel") or told.contains("High Keeper"), "never named yet")
		assert_eq(state.quest_stage("the_seventh_name"), "a_keeper_knows")
		assert_true(bool(state.get_flag("cindermoor_provost_heard_roll")))
	# Not read: nothing to tell.
	var unread := _at("the_chapter")
	unread.set_flag("cindermoor_roll_read", false)
	var offered: Array[String] = []
	_lines(unread, "provost", ["The chapter can sit. I'll hear what it says.", "Leave her to the quay."], offered)
	assert_false(offered.has("Tell her about the novices' roll."))


func test_the_road_lit_for_them() -> void:
	var state := _at("the_chapter")
	var told := _lines(state, "provost", ["The chapter can sit. I'll hear what it says.", "The road up forgets where it goes. You'll want the cressets.", "Leave her to the quay."])
	assert_true(told.contains("You've lit the road for us") and not told.contains("Hild takes the bow lantern"), told)
	assert_false(bool(state.get_flag("cindermoor_keepers_relit")))


func test_the_keepers_relight_the_doused_cresset() -> void:
	for spare: bool in [false, true]:
		var state := _led_up()
		_come_in(state)
		var exit: Dictionary = (_region(STEPS)["exits"] as Array).filter(func(e: Dictionary) -> bool: return str(e["to"]) == "cindermoor_spire_foot")[0]
		assert_false(Conditions.evaluate(exit["requires"], state), "doused: the road up forgets")
		var ness: Array = _placed(STEPS, "ness")
		assert_true(Conditions.evaluate(ness[0]["if"], state), "Ness still on the shoulder")
		var pick := "One was put out on purpose. The Unmoored sit under it. Leave it out." if spare else "Say nothing."
		var told := _lines(state, "provost", ["The chapter can sit. I'll hear what it says.", "The road up forgets where it goes. You'll want the cressets.", pick, "Leave her to the quay."])
		assert_true(told.contains("Six. Six up the moor.") and told.contains("Seven lit.") and told.contains("I had it out in ten minutes."), told)
		assert_eq(told.contains("The ones who don't.") and told.contains("It's written down."), spare, told)
		assert_true(bool(state.get_flag("cindermoor_keepers_relit")) and bool(state.get_flag("cindermoor_cresset_steps_5")))
		assert_eq(str(state.get_flag("cindermoor_way_on")), "led", "the Wakebearer still went up in the dark")
		assert_eq(bool(state.get_flag("cindermoor_asked_spare")), spare)
		assert_true(Conditions.evaluate(exit["requires"], state), "the road remembers up to the crown")
		assert_false(Conditions.evaluate(ness[0]["if"], state), "Ness has gone")
		told = _lines(state, "cindermoor_unmoored_gone")
		assert_true(told.contains("her rake's gone with her") and told.contains("You didn't light it."), told)
		assert_false(told.contains("The cresset you lit"), told)
		assert_eq(told.contains("You asked them not to."), spare, told)
		assert_true(_lines(state, "hild").contains("somebody'd woken her"))
	# Relit by the Wakebearer: the old words stand.
	var relit := _at("the_chapter")
	var gone := _lines(relit, "cindermoor_unmoored_gone")
	assert_true(gone.contains("Her cinder-rake leans on the shelter") and gone.contains("The cresset you lit"), gone)


func test_merrit_after_the_boat() -> void:
	var state := _at("the_spire_foot")
	state.set_flag("cindermoor_merrit_seven_lit", false)
	_come_in(state)
	var told := _lines(state, "merrit", ["Leave him to his rope."])
	assert_true(told.contains("First out. First back.") and told.contains("Still somebody up the stair"), told)
	assert_false(told.contains("Somebody's coming down, then."), "the seven are paid by the boat: " + told)


func test_the_scenario_and_the_validator() -> void:
	var state := _at("the_chapter")
	assert_true(bool(state.get_flag(CAME)))
	assert_eq(str(Scenarios.resolve("the_chapter")["region"]), STAIR)
	var v := ContentValidator.new(load_content())
	assert_true(v.validate(), "\n".join(v.errors))
