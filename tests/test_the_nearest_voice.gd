extends TestCase
## Day 90 — the Choir at the Spire (Act III step 7, mystery #4). Once the woman on the ring path has been answered,
## singing comes down the east stair and the nearest voice gets two words out: "Not Hushed." The Provost takes the
## Wakebearer back down to read the middle of the Spire's book, where the one line that says so has its name scraped
## off and kept on the story: Isolde Vane. At the door: say her name, write her in the Long Book, or let her sing
## (`cindermoor_choir_answered`).

const FOOT := "cindermoor_spire_foot"
const LOWER := "cindermoor_lower_rooms"
const QUEST := "the_nearest_voice"
const HEARD := "cindermoor_choir_heard"
const DOWN := "cindermoor_choir_down"
const READ := "cindermoor_choir_line_read"
const ANSWERED := "cindermoor_choir_answered"
const TELL_HER := "One of them got two words out. \"Not Hushed.\""

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


## Up on the crown with Oriel answered (`told` unless said otherwise).
func _answered(how: String = "told") -> WorldState:
	var state := _at("the_eighth_boat")
	state.set_flag("cindermoor_eighth_met", true)
	state.set_flag("cindermoor_eighth_told", how)
	return state


func _region(id: String) -> Dictionary:
	return _content().regions[id]


func _placements(region_id: String, npc: String, state: WorldState) -> Array:
	return (_region(region_id)["npcs"] as Array).filter(func(n: Dictionary) -> bool:
		return str(n["npc"]) == npc and Conditions.evaluate(n.get("if", []), state))


func _last_step(dialogue: String, knot: String) -> Dictionary:
	var steps: Array = _content().dialogues[dialogue]["knots"][knot]
	return steps[steps.size() - 1]


## The door, the Provost, and the line below: everything up to the answer.
func _to_the_name(state: WorldState) -> String:
	var said := _lines(state, "cindermoor_stair_door", ["Listen."])
	said += _lines(state, "provost", [TELL_HER])
	var event := RegionEvents.arrival(_region(LOWER), state)
	assert_eq(str(event.get("id", "")), "cindermoor_isolde_line")
	return said + _lines(state, RegionEvents.fire(event, state))


func test_the_door_stays_shut_until_she_s_answered() -> void:
	var state := _at("the_eighth_boat")
	var said := _lines(state, "cindermoor_stair_door")
	assert_true(said.contains("can't think what comes after one"), said)
	assert_false(said.contains("Singing"), "no Choir yet: she's still walking unanswered")
	assert_false(bool(state.get_flag(HEARD)))


func test_singing_comes_down_the_stair() -> void:
	for how: String in ["told", "asked", "kept"]:
		var state := _answered(how)
		var said := _lines(state, "cindermoor_stair_door", ["Listen."])
		assert_true(said.contains("Singing.") and said.contains("'Not Hushed.'"), said)
		assert_eq(said.contains("With Oriel sat still"), how == "told", "%s: whether her feet go by" % how)
		assert_eq(said.contains("Her feet go by"), how != "told", how)
		assert_true(bool(state.get_flag(HEARD)))
		assert_eq(state.quest_stage(QUEST), "listen")
		# Again: she doesn't get it out twice.
		said = _lines(state, "cindermoor_stair_door")
		assert_true(said.contains("She doesn't get it out again"), said)
		assert_eq(state.quest_stage(QUEST), "listen")


func test_iver_knows_when_she_ll_breathe() -> void:
	var state := _answered()
	state.set_flag("lowsong_iver_home", true)
	state.set_flag("lowsong_beacon_burned", "lamp")
	var said := _lines(state, "cindermoor_stair_door", ["Listen."])
	assert_true(said.contains("I know when she'll breathe") and said.contains("He doesn't know he did"), said)
	assert_true(_lines(state, "iver").contains("just when I knew she would"))
	var kept := _answered()
	kept.set_flag("lowsong_beacon_burned", "key")
	said = _lines(kept, "cindermoor_stair_door", ["Listen."])
	assert_true(said.contains("Iver said that, on his rock") and not said.contains("breathe"), said)


func test_her_own_things_stop_her() -> void:
	var state := _answered()
	for item: String in ["stair_taper", "hood_pin"]:
		state.remove_item(item, state.item_count(item))
	var offered: Array[String] = []
	_lines(state, "cindermoor_stair_door", ["Listen."], offered)
	assert_false(offered.has("Take out the Stair-Taper.") or offered.has("Take out the hood-pin."), "nothing to take out")
	for item: String in ["stair_taper", "hood_pin"]:
		var carrying := _answered()
		assert_eq(carrying.item_count(item), 1, "Act III carries both")
		offered.clear()
		var pick := "Take out the Stair-Taper." if item == "stair_taper" else "Take out the hood-pin."
		var said := _lines(carrying, "cindermoor_stair_door", [pick], offered)
		assert_true(offered.has(pick), item)
		assert_true(said.contains("very like being looked at") and said.contains("'Not Hushed.'"), said)
		assert_eq(carrying.item_count(item), 1, "put away again, not given up")


func test_the_provost_goes_down_to_read_the_middle() -> void:
	var state := _answered()
	_lines(state, "cindermoor_stair_door", ["Listen."])
	assert_eq(_placements(FOOT, "provost", state).size(), 1, "on the niche step")
	var said := _lines(state, "provost", ["It's nothing. The wind."])
	assert_true(said.contains("Iver said that for thirty-one years") and not bool(state.get_flag(DOWN)), said)
	said = _lines(state, "provost", [TELL_HER])
	assert_true(said.contains("Nobody reads the middle of a book like that"), said)
	assert_true(bool(state.get_flag(DOWN)))
	assert_eq(state.quest_stage(QUEST), "the_line")
	assert_eq(_last_step("provost", "not_hushed")["travel"], [LOWER, "from_stair"])
	assert_eq(_placements(FOOT, "provost", state).size(), 0, "gone down")
	assert_eq(_placements(LOWER, "provost", state).size(), 1, "at the lectern")
	assert_true(_lines(state, "provost").contains("She's waiting"), "below, she sends you to the door")


func test_the_line_and_the_name_last() -> void:
	var state := _answered()
	var said := _to_the_name(state)
	assert_true(bool(state.get_flag(READ)))
	assert_eq(state.quest_stage(QUEST), "the_name")
	var awake := said.find("Given to the flame awake")
	var scraped := said.find("little scraped place")
	var name := said.find("Isolde Vane")
	assert_true(awake >= 0 and scraped > awake and name > scraped, "the name comes late, off the story")
	assert_true(said.contains("walked her out of the grey every time"), "the line every novice learns")
	assert_true(RegionEvents.arrival(_region(LOWER), state).is_empty(), "once")
	assert_eq(_last_step("cindermoor_isolde_line", "start")["travel"], [FOOT, "from_lower"])
	# She stays below with the book until the door's answered, then she's up on the step again.
	assert_eq(_placements(LOWER, "provost", state).size(), 1)
	assert_eq(_placements(FOOT, "provost", state).size(), 0)


func test_three_answers_at_the_door() -> void:
	var picks := {
		"named": ["Say her name up the stair. \"Isolde Vane.\"", "'Yes.'"],
		"written": ["Write her in the Long Book, Provost. Not with the Hushed. As she was.", "Struck, not scraped."],
		"left": ["Let her sing. She's nearly got it out herself.", "It's hers to get out."],
	}
	for how: String in picks:
		var state := _at("the_nearest_voice")
		var said := _lines(state, "cindermoor_stair_door", [picks[how][0]])
		assert_true(said.contains("comes up out of the dark under the warden's seat"), said)
		assert_true(said.contains(picks[how][1]), "%s: %s" % [how, said])
		assert_eq(state.get_flag(ANSWERED), how)
		assert_eq(state.quest_state(QUEST), WorldState.QUEST_DONE)
		assert_eq(_placements(FOOT, "provost", state).size(), 1, "%s: the Provost back up" % how)
		assert_eq(_placements(LOWER, "provost", state).size(), 0, how)
		var after := _lines(state, "cindermoor_stair_door")
		assert_true(after.contains("One. And nothing after one"), after)
		assert_false(after.contains("The Provost comes up"), "once")
		assert_true(_lines(state, "provost").length() > 0)


func test_the_crown_hears_her_after() -> void:
	var state := _answered()
	var layers := func() -> Array:
		return (_region(FOOT)["ambience"] as Array).filter(func(a: Dictionary) -> bool:
			return str(a["sound"]) == "choir_near" and Conditions.evaluate(a.get("if", []), state))
	assert_eq(layers.call().size(), 0, "not before the door")
	state.set_flag(HEARD, true)
	assert_eq(layers.call().size(), 1)
	assert_eq(float(layers.call()[0]["volume"]), 0.3)
	state.set_flag(ANSWERED, "named")
	assert_eq(layers.call().size(), 1)
	assert_true(float(layers.call()[0]["volume"]) < 0.3, "thinner, with a gap in it")


func test_who_says_what_after() -> void:
	var state := _at("the_nearest_voice")
	assert_true(_lines(state, "hild").contains("My mother sang that over the cradle"))
	assert_true(_lines(state, "oriel").contains("She's been singing since I sat down"))
	var walking := _answered("asked")
	walking.set_flag(HEARD, true)
	assert_true(_lines(walking, "oriel").contains("I walk past it"))
	_lines(state, "cindermoor_stair_door", ["Write her in the Long Book, Provost. Not with the Hushed. As she was."])
	assert_true(_lines(state, "hild").contains("struck it straight"))
	assert_true(_lines(state, "provost").contains("striking a line was the worst thing"))


func test_the_checkpoint() -> void:
	var state := _at("the_nearest_voice")
	assert_eq(state.quest_stage(QUEST), "the_name")
	assert_eq(state.quest_state("the_eighth_boat"), WorldState.QUEST_DONE)
	assert_eq(state.get_flag(ANSWERED), "")
	assert_true(RegionEvents.arrival(_region(FOOT), state).is_empty(), "nothing fires on the crown")
	assert_true(RegionEvents.arrival(_region(LOWER), state).is_empty(), "nor below")
