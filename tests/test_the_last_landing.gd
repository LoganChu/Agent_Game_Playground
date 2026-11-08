extends TestCase
## Day 92 — the east stair (Act III step 8, mystery #2). With Isolde Vane answered, the Stair-Taper is lit from the
## ember for the stair it was cut for and the count goes past one: seven landings, the Provost counting the hand up
## from the foot, Isolde at the second turn as she was answered. On the last landing, under the lantern room, the
## night of the Snuffing comes back: a novice who asked the High Keeper for the last coal and fed it everything on
## the way down. Back down, the Provost counts the hand down and sees the face; then the seventh place on the roll
## (`cindermoor_seventh_answered`: written / struck / left).

const FOOT := "cindermoor_spire_foot"
const LANDING := "cindermoor_last_landing"
const QUEST := "the_last_landing"
const CLIMB := "Light the Stair-Taper from the ember, and go up."
const IN_THE_DARK := "Go up in the dark, counting."
const TELL := "It was me. The coal kept back. I asked to carry it."
const QUIET := "Say nothing. Go to the niche."
const ROLL := {
	"written": "Write my name back in the seventh place.",
	"struck": "Write it, and strike it through. The novice is finished.",
	"left": "Leave it scraped. She did it so nobody could write me down.",
}

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


## At the door with Isolde answered `how`.
func _answered(how: String = "named") -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_nearest_voice"))
	state.set_flag("cindermoor_choir_answered", how)
	state.complete_quest("the_nearest_voice")
	return state


func _region(id: String) -> Dictionary:
	return _content().regions[id]


func _last_step(dialogue: String, knot: String) -> Dictionary:
	var steps: Array = _content().dialogues[dialogue]["knots"][knot]
	return steps[steps.size() - 1]


## Up the stair and the landing's arrival: everything up to coming down.
func _up(state: WorldState) -> String:
	var said := _lines(state, "cindermoor_stair_door", [CLIMB])
	var event := RegionEvents.arrival(_region(LANDING), state)
	assert_eq(str(event.get("id", "")), "cindermoor_last_landing")
	return said + "\n" + _lines(state, RegionEvents.fire(event, state))


## Back down: the foot's arrival event, with `picks`.
func _down(state: WorldState, picks: Array) -> String:
	var event := RegionEvents.arrival(_region(FOOT), state)
	assert_eq(str(event.get("id", "")), "cindermoor_stair_down")
	return _lines(state, RegionEvents.fire(event, state), picks)


func test_the_door_offers_the_stair_once_she_s_answered() -> void:
	var before := fresh_state(_content())
	Scenarios.apply(_content(), before, Scenarios.resolve("the_nearest_voice"))
	var offered: Array[String] = []
	_lines(before, "cindermoor_stair_door", [], offered)
	assert_false(offered.has(CLIMB), "not while she's still waiting to be answered")
	var state := _answered()
	offered.clear()
	var said := _lines(state, "cindermoor_stair_door", ["Not yet."], offered)
	assert_true(offered.has(CLIMB) and offered.has("Not yet.") and not offered.has(IN_THE_DARK), str(offered))
	assert_true(said.contains("One. And nothing after one"), said)
	assert_false(bool(state.get_flag("cindermoor_stair_climbed")), "not yet means not yet")
	state.remove_item("stair_taper", state.item_count("stair_taper"))
	offered.clear()
	said = _lines(state, "cindermoor_stair_door", [IN_THE_DARK], offered)
	assert_true(offered.has(IN_THE_DARK) and not offered.has(CLIMB), str(offered))
	assert_true(said.contains("The ember shows you a step at a time") and not said.contains("taper leans"), said)


func test_the_climb_counts_past_one() -> void:
	var state := _answered()
	var said := _lines(state, "cindermoor_stair_door", [CLIMB])
	assert_true(bool(state.get_flag("cindermoor_stair_climbed")))
	assert_eq(state.quest_stage(QUEST), "climb")
	var one := said.find("\nOne.\n")
	var two := said.find("easy as breathing out: two")
	var third := said.find("past the third notch")
	var six := said.find("Six.")
	assert_true(one >= 0 and two > one and third > two and six > third, said)
	assert_true(said.contains("I'll count you"), "the Provost counts the hand up")
	assert_eq(_last_step("cindermoor_stair_door", "climb")["travel"], [LANDING, "from_stair"])
	assert_eq(state.item_count("stair_taper"), 1, "lit and burned down, but kept")


func test_isolde_at_the_second_turn() -> void:
	var expect := {"named": "Nobody's singing in it", "written": "She doesn't know.", "left": "I asked them."}
	for how: String in expect:
		var state := _answered(how)
		var said := _lines(state, "cindermoor_stair_door", [CLIMB])
		assert_true(said.contains(expect[how]), "%s: %s" % [how, said])
		assert_eq(bool(state.get_flag("cindermoor_isolde_spoke")), how == "left", how)
		assert_eq(said.contains("Counting. With a coal."), how == "left", "only the one left to sing tells of it")


func test_the_last_landing_remembers() -> void:
	var state := _answered()
	var said := _up(state)
	assert_true(bool(state.get_flag("cindermoor_stair_remembered")))
	assert_eq(state.quest_stage(QUEST), "remembered")
	var asked := said.find("give it to me. I'll carry it down")
	var hood := said.find("Nobody's to see your face on this stair tonight")
	var name := said.find("Your name comes back last")
	assert_true(asked >= 0 and hood > asked and name > hood, "the coal asked for, the hood pinned, the name last")
	assert_true(said.contains("It's made of you."), "the ember holds the Wakebearer's past")
	assert_true(said.contains("the hood-pin is humming"), "Act III carries the pin")
	assert_true(RegionEvents.arrival(_region(LANDING), state).is_empty(), "once")
	# The Hearthspire's door stays shut: step 9.
	said = _lines(state, "cindermoor_landing_up")
	assert_true(said.contains("Not yet") and said.contains("The hand, the Provost said"), said)


func test_the_name_is_never_said() -> void:
	# The Wakebearer's name comes back but is never shown: no dialogue line spells one out.
	for id: String in ["cindermoor_landing_remember", "cindermoor_stair_down", "cindermoor_niche"]:
		for knot: String in _content().dialogues[id]["knots"]:
			for step: Dictionary in _content().dialogues[id]["knots"][knot]:
				var text := str(step.get("text", ""))
				assert_false(text.contains("your name is") or text.contains("Your name is"), "%s/%s: %s" % [id, knot, text])


func test_counted_down_and_told() -> void:
	var state := _answered()
	_up(state)
	var said := _down(state, [TELL, ROLL["written"]])
	assert_true(said.contains("...Two. One.") and said.contains("That's the second stroke"), said)
	assert_true(said.contains("same face under the hood"), "she'd not have known a novice's face (Day 69)")
	assert_true(said.contains("figure of speech"), "Oriel's last page, read again")
	assert_true(bool(state.get_flag("cindermoor_provost_knows")))
	assert_true(RegionEvents.arrival(_region(FOOT), state).is_empty(), "once")
	var quiet := _answered()
	_up(quiet)
	said = _down(quiet, [QUIET, ROLL["left"]])
	assert_false(bool(quiet.get_flag("cindermoor_provost_knows")))
	assert_true(said.contains("I don't know why I said that"), said)


func test_three_answers_at_the_roll() -> void:
	var expect := {
		"written": ["upright, every one finished", "in upright Keeper's letters"],
		"struck": ["Struck, not scraped", "one straight line through it"],
		"left": ["she wrote it with a knife", "You left it as she left it"],
	}
	for how: String in expect:
		var state := _answered()
		_up(state)
		var said := _down(state, [TELL, ROLL[how]])
		assert_eq(state.get_flag("cindermoor_seventh_answered"), how)
		assert_true(said.contains(expect[how][0]), "%s: %s" % [how, said])
		assert_eq(state.quest_state(QUEST), WorldState.QUEST_DONE, how)
		assert_eq(state.quest_state("the_seventh_name"), WorldState.QUEST_DONE, how)
		assert_eq(state.quest_stage("the_seventh_name"), "yours", how)
		var roll := _lines(state, "cindermoor_niche", ["Read the roll."])
		assert_true(roll.contains(expect[how][1]), "%s: the roll after: %s" % [how, roll])
		assert_eq(roll.contains("scraped the name off down to the skin"), how == "left", how)


func test_the_door_after() -> void:
	var state := _answered()
	_up(state)
	_down(state, [TELL, ROLL["struck"]])
	var offered: Array[String] = []
	var said := _lines(state, "cindermoor_stair_door", ["Not now."], offered)
	assert_true(said.contains("all the way to seven") and offered.has("Go up to the last landing."), said)
	assert_eq(_last_step("cindermoor_stair_door", "up_again")["travel"], [LANDING, "from_stair"])
	assert_true(_lines(state, "cindermoor_landing_window").contains("every midwinter"), "the slit, remembered")


func test_who_says_what_after() -> void:
	var state := _answered()
	_up(state)
	_down(state, [TELL, ROLL["struck"]])
	var provost := _lines(state, "provost")
	assert_true(provost.contains("Seven up and seven down") and provost.contains("The Long Book hasn't one"), provost)
	assert_true(_lines(state, "merrit").contains("Up, and then down"))
	assert_false(_lines(state, "merrit").contains("Still somebody up the stair"))
	assert_true(_lines(state, "oriel").contains("Somebody came down that stair counting"))
	var asked := _answered()
	asked.set_flag("cindermoor_eighth_told", "asked")
	_up(asked)
	_down(asked, [QUIET, ROLL["left"]])
	assert_true(_lines(asked, "oriel").contains("Ask me again"), "asked: she isn't ready yet")


func test_the_checkpoint() -> void:
	var state := fresh_state(_content())
	var scenario := Scenarios.resolve("the_last_landing")
	assert_eq(str(scenario.get("region", "")), LANDING)
	Scenarios.apply(_content(), state, scenario)
	assert_eq(state.quest_stage(QUEST), "remembered")
	assert_true(RegionEvents.arrival(_region(LANDING), state).is_empty(), "already remembered")
	assert_eq(str(RegionEvents.arrival(_region(FOOT), state).get("id", "")), "cindermoor_stair_down", "down next")
