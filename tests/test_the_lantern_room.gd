extends TestCase
## Day 95 — the lantern room (Act III step 9, part one; mystery #4's close). Once Oriel has been asked
## (`cindermoor_oriel_choice`), the Provost sits the chapter once more, by daylight, on the one line — whether the
## Hearthspire is lit again — and writes that it does not choose (`cindermoor_chapter_chose`). The stair on up from
## the last landing opens: "Eight." The lantern room: the cold cradle, the soot-black panes, the Hollow Choir, and
## Isolde Vane (as she was answered) telling what lighting it would cost. Nobody asks the Wakebearer for anything.

const FOOT := "cindermoor_spire_foot"
const LANDING := "cindermoor_last_landing"
const ROOM := "cindermoor_lantern_room"
const QUEST := "the_lantern_room"
const ASK := "Ask her what she'd choose."
const WAIT := "Say nothing. Wait with them."
const GO_UP := "Go on up. Past seven."
const HOLD := "Hold the ember out over the cradle."

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


func _region(id: String) -> Dictionary:
	return _content().regions[id]


## Down from the stair, Oriel told and asked `choice`; Isolde answered `how`.
func _asked(choice: String = "climb", how: String = "named") -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("what_she_was"))
	state.set_flag("cindermoor_oriel_choice", choice)
	state.set_flag("cindermoor_choir_answered", how)
	return state


## The sitting, then up into the room (its arrival event played).
func _into_the_room(state: WorldState, sit_pick: String = WAIT) -> String:
	var said := _lines(state, "provost", [sit_pick])
	said += "\n" + _lines(state, "cindermoor_landing_up", [GO_UP])
	var event := RegionEvents.arrival(_region(ROOM), state)
	assert_eq(str(event.get("id", "")), "cindermoor_lantern_room")
	return said + "\n" + _lines(state, RegionEvents.fire(event, state))


func test_not_before_the_chapter_sits() -> void:
	var before := fresh_state(_content())
	Scenarios.apply(_content(), before, Scenarios.resolve("the_last_landing"))
	var said := _lines(before, "cindermoor_landing_up")
	assert_true(said.contains("Not yet") and said.contains("The hand, the Provost said"), said)
	assert_true(RegionEvents.arrival(_region(ROOM), before).is_empty(), "no room before the chapter chooses")
	# Before Oriel's been asked, the Provost doesn't sit them.
	var told := fresh_state(_content())
	Scenarios.apply(_content(), told, Scenarios.resolve("what_she_was"))
	told.set_flag("cindermoor_oriel_choice", "")
	assert_false(_lines(told, "provost").contains("The question's one line"))
	assert_false(bool(told.get_flag("cindermoor_chapter_chose")))


func test_the_chapter_does_not_choose() -> void:
	for pick: String in [ASK, WAIT]:
		var state := _asked()
		var offered: Array[String] = []
		var said := _lines(state, "provost", [pick], offered)
		assert_true(offered.has(ASK) and offered.has(WAIT), str(offered))
		assert_true(said.contains("Whether the Hearthspire's lit again"), said)
		assert_true(said.contains("does not choose") and said.contains("carries it up"), said)
		assert_true(bool(state.get_flag("cindermoor_chapter_chose")), pick)
		assert_eq(state.quest_stage(QUEST), "chosen")
		assert_eq(bool(state.get_flag("cindermoor_provost_would_light")), pick == ASK, pick)
		assert_eq(said.contains("I'd light it. Tonight."), pick == ASK, pick)
		# Once: after it she's back to her after-lines.
		said = _lines(state, "provost")
		assert_false(said.contains("The question's one line"), said)
		assert_true(said.contains("frightened of three words"), said)


func test_the_sitting_follows_oriel() -> void:
	var expect := {
		"climb": "I'll not be it twice.",
		"boat": "Hild's place is empty",
		"own": "in the place a novice takes",
	}
	for choice: String in expect:
		var state := _asked(choice)
		var said := _lines(state, "provost", [WAIT])
		assert_true(said.contains(expect[choice]), "%s: %s" % [choice, said])
		assert_eq(said.contains("Hild sits on the end"), choice != "boat", choice)
	var unknown := _asked()
	unknown.set_flag("cindermoor_provost_knows", false)
	assert_true(_lines(unknown, "provost", [WAIT]).contains("I don't know whose hand"))


func test_up_past_seven() -> void:
	var state := _asked()
	_lines(state, "provost", [WAIT])
	var offered: Array[String] = []
	var said := _lines(state, "cindermoor_landing_up", [GO_UP], offered)
	assert_true(offered.has(GO_UP) and offered.has("Not yet."), str(offered))
	assert_true(said.contains("Eight. There's no notch for it"), said)
	var steps: Array = _content().dialogues["cindermoor_landing_up"]["knots"]["up"]
	assert_eq(steps[steps.size() - 1]["travel"], [ROOM, "from_stair"])
	# Oriel, asked up, comes up the east stair behind them now.
	assert_true(_lines(state, "cindermoor_stair_door", ["Go up to the last landing."]).contains("comes in behind you"))
	var exits: Array = _region(ROOM)["exits"]
	assert_eq(exits[0]["to"], LANDING)
	assert_true(_region(LANDING)["spawn_points"].has(str(exits[0]["spawn"])), "back down to the landing's far side")


func test_the_room_and_the_choir() -> void:
	var state := _asked()
	var said := _into_the_room(state)
	assert_true(bool(state.get_flag("cindermoor_lantern_room_entered")))
	assert_eq(state.quest_stage(QUEST), "the_room")
	var stops := said.find("The singing stops.")
	var cradle := said.find("a hollow the size of two hands")
	var woke := said.find("I was the first of them that woke")
	var hungry := said.find("by midwinter it'll be hungry")
	assert_true(stops >= 0 and cradle > stops and woke > cradle and hungry > woke, said)
	assert_true(said.contains("The Hollow Choir. Not the Hushed."), "mystery #4: what the Choir is")
	assert_true(said.contains("We're not asking you for anything"), "nobody asks the Wakebearer")
	assert_true(said.contains("what you'd be choosing with") and said.contains("The Provost said it"), said)
	assert_true(RegionEvents.arrival(_region(ROOM), state).is_empty(), "once")
	# Going back up later skips the arrival.
	var offered: Array[String] = []
	_lines(state, "cindermoor_landing_up", [], offered)
	assert_true(offered.has("Go back up to the lantern room."), str(offered))


func test_isolde_as_answered() -> void:
	var expect := {
		"named": "You said my name",
		"written": "the only one of us who gets to the end of a sentence",
		"left": "Not Hushed,' Isolde Vane says. 'Awake. I asked them.'",
	}
	for how: String in expect:
		var state := _asked("climb", how)
		var said := _into_the_room(state)
		assert_true(said.contains(expect[how]), "%s: %s" % [how, said])
		for other: String in expect:
			if other != how:
				assert_false(said.contains(expect[other]), "%s heard %s's line" % [how, other])


func test_oriel_and_the_roll_colour_it() -> void:
	var where := {
		"climb": "That's where it sat.",
		"boat": "a woman sitting in a boat that hasn't gone out",
		"own": "two voices at the foot, counting",
	}
	for choice: String in where:
		var state := _asked(choice)
		var said := _into_the_room(state)
		assert_true(said.contains(where[choice]), "%s: %s" % [choice, said])
		assert_eq(_placed(ROOM, state), choice == "climb", "only the one asked up is in the room: " + choice)
	var roll := {"left": "your name. They were there", "written": "Written back in", "struck": "You kept your hand"}
	for how: String in roll:
		var state := _asked()
		state.set_flag("cindermoor_seventh_answered", how)
		assert_true(_into_the_room(state).contains(roll[how]), how)


func test_oriel_goes_up() -> void:
	var state := _asked("climb")
	assert_true(_placed(FOOT, state), "waiting at the door before the climb")
	_into_the_room(state)
	assert_false(_placed(FOOT, state), "she went up behind them")
	assert_true(_placed(ROOM, state), "she stands inside the lantern-room door")
	assert_true(_lines(state, "oriel").contains("Thirty-one midwinters"))
	var own := _asked("own")
	_into_the_room(own)
	assert_false(_placed(ROOM, own))
	assert_true(_lines(own, "oriel").contains("I sat with the chapter and didn't choose"))


func _placed(region: String, state: WorldState) -> bool:
	for npc: Dictionary in _region(region)["npcs"]:
		if str(npc.get("npc", "")) != "oriel" or not Conditions.evaluate(npc.get("if", []), state):
			continue
		if region == ROOM or str(npc.get("if", [])).contains("climb"):
			return true
	return false


func test_the_cradle_waits() -> void:
	var state := _asked()
	_into_the_room(state)
	var offered: Array[String] = []
	var said := _lines(state, "cindermoor_cradle", [HOLD], offered)
	assert_true(offered.has(HOLD) and offered.has("Leave it."), str(offered))
	assert_true(said.contains("It would take") and said.contains("You take your hand back"), said)
	assert_true(said.contains("It feels like that every time"), "Oriel, climbed, stood there too")
	assert_true(bool(state.get_flag("cindermoor_cradle_held")))
	assert_eq(state.quest_stage(QUEST), "the_room", "nothing is chosen yet")
	offered.clear()
	_lines(state, "cindermoor_cradle", [], offered)
	assert_true(offered.has("Put the ember in the ash.") and not offered.has(HOLD), str(offered))
	var panes := _lines(state, "cindermoor_lantern_panes")
	assert_true(panes.contains("the ring has nothing in the middle"), panes)
	assert_true(panes.contains("Saltmarrow's, on the Gull"), "the first light, as it was burned")
	assert_true(_lines(state, "cindermoor_lantern_choir").contains("Keeping the time."), "named: she keeps the time")


func test_the_name_is_never_said() -> void:
	for id: String in ["cindermoor_lantern_room", "cindermoor_cradle", "cindermoor_lantern_choir"]:
		for knot: String in _content().dialogues[id]["knots"]:
			for step: Dictionary in _content().dialogues[id]["knots"][knot]:
				var text := str(step.get("text", ""))
				assert_false(text.contains("your name is") or text.contains("Your name is"), "%s/%s: %s" % [id, knot, text])


func test_the_checkpoint() -> void:
	var state := fresh_state(_content())
	var scenario := Scenarios.resolve("the_lantern_room")
	assert_eq(str(scenario.get("region", "")), ROOM)
	Scenarios.apply(_content(), state, scenario)
	assert_eq(state.quest_stage(QUEST), "the_room")
	assert_true(RegionEvents.arrival(_region(ROOM), state).is_empty(), "already in")
	assert_true(_placed(ROOM, state), "Oriel came up (the checkpoint's choice is climb)")
