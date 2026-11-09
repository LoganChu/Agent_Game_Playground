extends TestCase
## Day 93 — what she was to you (Act III step 8's close). Down from the last landing, Oriel heard the count from the
## ring path and doesn't know whose it was. The Wakebearer tells her it was them she gave the last coal to: told,
## she already has her name; asked, she's asked again and takes it; kept, she works out who she was and asks for
## the novice first, then her name. Then she asks what they want of her (`cindermoor_oriel_choice`): climb / boat / own.

const FOOT := "cindermoor_spire_foot"
const BOATS := "cindermoor_boat_stair"
const QUEST := "what_she_was"
const OFFER := {
	"told": "It was me you gave it to. On the last landing.",
	"asked": "You said to ask you again when I came down. I'm asking.",
	"kept": "Somebody asked to carry one of those, you said. You gave it them.",
}
const ANSWER := {
	"climb": "Come up with me. You were the last one in that room.",
	"boat": "Your boat's still in the eighth slip. Merrit's kept her greased.",
	"own": "Nothing. I'm not going to choose for you.",
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


## Down from the last landing, the roll written, with Oriel answered `told` on Day 89.
func _down(told: String = "told") -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_last_landing"))
	state.set_flag("cindermoor_eighth_told", told)
	state.set_flag("cindermoor_stair_down", true)
	state.set_flag("cindermoor_provost_knows", true)
	state.set_flag("cindermoor_seventh_answered", "written")
	state.complete_quest("the_last_landing")
	return state


## The Region placements of `npc` in `region` that stand under `state`.
func _placed(region: String, npc: String, state: WorldState) -> Array:
	var out: Array = []
	for entry: Dictionary in _content().regions[region]["npcs"]:
		if str(entry["npc"]) == npc and Conditions.evaluate(entry.get("if"), state):
			out.append(entry)
	return out


func test_not_before_the_stair() -> void:
	var state := _down()
	state.set_flag("cindermoor_stair_down", false)
	var offered: Array[String] = []
	_lines(state, "oriel", [], offered)
	assert_false(offered.has(OFFER["told"]), "she can't be told before the Wakebearer remembers")
	assert_eq(state.quest_state(QUEST), WorldState.QUEST_INACTIVE)


func test_she_hears_the_count_and_the_quest_opens() -> void:
	for told: String in OFFER:
		var state := _down(told)
		var offered: Array[String] = []
		_lines(state, "oriel", [], offered)
		assert_true(offered.has(OFFER[told]), "%s: %s" % [told, offered])
		assert_eq(state.quest_stage(QUEST), "heard", told)
		assert_false(bool(state.get_flag("cindermoor_oriel_knows")), "%s: 'not today' leaves her not knowing" % told)


func test_telling_her() -> void:
	for told: String in OFFER:
		var state := _down(told)
		var said := _lines(state, "oriel", [OFFER[told], ANSWER["climb"]])
		assert_true(said.contains("They asked you for the last coal. It was me."), "%s: %s" % [told, said])
		assert_true(said.contains("I didn't think I'd be one of the nobody"), "the hood, pinned (Day 77/92)")
		assert_true(said.contains("Aldous's knife"), "the roll scraped with the warden's knife (Day 83)")
		assert_true(said.contains("You've written it back"), "the seventh place, written")
		assert_eq(said.contains("She tries it like a key"), told == "asked", "%s: asked again, she takes her name" % told)
		assert_eq(said.contains("Tell me who I gave it to. I'd like them in that order"), told == "kept", told)
		assert_eq(said.contains("That's the right weight"), told == "kept", "kept: her name last")
		assert_true(said.contains("They told me at the foot of the stair"), "the Provost already knew")
		assert_true(bool(state.get_flag("cindermoor_oriel_knows")), told)
		assert_eq(state.get_flag("cindermoor_eighth_told"), told, "the Day 89 answer is kept as it was")
		assert_eq(state.quest_state(QUEST), WorldState.QUEST_DONE, told)
		assert_eq(ContentDatabase.npc_display_name(_content().npcs["oriel"], state), "Oriel Sayre", "%s: named now" % told)


func test_the_roll_colours_it() -> void:
	var expect := {"struck": "Struck can still be read", "left": "the one thing I did that night I'm sure of"}
	for how: String in expect:
		var state := _down()
		state.set_flag("cindermoor_seventh_answered", how)
		var said := _lines(state, "oriel", [OFFER["told"], ANSWER["own"]])
		assert_true(said.contains(expect[how]), "%s: %s" % [how, said])
		assert_false(said.contains("You've written it back"), how)


func test_three_answers_and_where_she_goes() -> void:
	var lines := {"climb": "carry nothing and touch nothing", "boat": "I'll go down and sit in her", "own": "The hand goes up. The chapter stays at the foot."}
	for how: String in ANSWER:
		var state := _down()
		state.set_flag("cindermoor_morning", true)
		state.set_flag("cindermoor_eighth_sought", true)
		var said := _lines(state, "oriel", [OFFER["told"], ANSWER[how]])
		assert_eq(state.get_flag("cindermoor_oriel_choice"), how)
		assert_true(said.contains(lines[how]), "%s: %s" % [how, said])
		var crown := _placed(FOOT, "oriel", state)
		var quay := _placed(BOATS, "oriel", state)
		assert_eq(crown.size(), 0 if how == "boat" else 1, "%s: one Oriel on the crown, and not walking" % how)
		assert_eq(quay.size(), 1 if how == "boat" else 0, how)
		for entry: Dictionary in crown:
			assert_false(entry.has("circuit"), "%s: she's stopped walking" % how)
		assert_eq(_placed(FOOT, "hild", state).size(), 0 if how == "boat" else 1, "%s: Hild goes down with her" % how)
		assert_eq(_placed(BOATS, "hild", state).size(), 1 if how == "boat" else 0, how)


func test_who_says_what_after() -> void:
	var expect := {
		"climb": ["hand not quite on the frame", "up the east stair, and nobody to say she mayn't", "waiting on somebody"],
		"boat": ["oars across her knees", "Gone down to the water", ""],
		"own": ["a pace behind the Provost", "best hour I've had of her", "The Provost moved over"],
	}
	for how: String in expect:
		var state := _down()
		state.set_flag("cindermoor_morning", true)
		state.set_flag("cindermoor_eighth_sought", true)
		_lines(state, "oriel", [OFFER["told"], ANSWER[how]])
		var oriel := _lines(state, "oriel")
		assert_true(oriel.contains(expect[how][0]), "%s: %s" % [how, oriel])
		assert_false(oriel.contains("Somebody came down that stair counting"), "%s: past that now" % how)
		assert_true(_lines(state, "provost").contains(expect[how][1]), how)
		var hild := _lines(state, "hild")
		if how == "boat":
			assert_true(hild.contains("Turns out there was a case"), "Hild greases the eighth's rollers (Day 89's promise)")
			assert_true(_lines(state, "merrit").contains("Come down, then. Not gone out."), "Merrit sees her in the eighth")
		else:
			assert_true(hild.contains(expect[how][2]), "%s: %s" % [how, hild])
			assert_true(hild.contains("never once looked under one"), "Hild on the stair climbed (1b)")


func test_the_name_is_never_said() -> void:
	# The Wakebearer's name stays the player's: Oriel's new knots never spell one out.
	for knot: String in ["novice", "asked_again", "kept_told", "climb", "boat_down", "own", "after_knows", "after_boat"]:
		for step: Dictionary in _content().dialogues["oriel"]["knots"][knot]:
			var text := str(step.get("text", ""))
			assert_false(text.contains("your name") and not text.contains("Oriel"), "%s: %s" % [knot, text])


func test_the_checkpoint() -> void:
	var state := fresh_state(_content())
	var scenario := Scenarios.resolve(QUEST)
	assert_eq(str(scenario.get("region", "")), FOOT)
	Scenarios.apply(_content(), state, scenario)
	assert_eq(state.quest_state(QUEST), WorldState.QUEST_DONE)
	assert_eq(state.get_flag("cindermoor_oriel_choice"), "climb")
	assert_true(RegionEvents.arrival(_content().regions[FOOT], state).is_empty(), "nothing left to arrive to")
	assert_eq(_placed(FOOT, "oriel", state).size(), 1)
