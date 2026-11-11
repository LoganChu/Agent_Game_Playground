extends TestCase
## Day 98 — the epilogues, part two: Saltmarrow. After the lane out the Mercy puts in at the first harbor (arrival event
## `saltmarrow_homecoming`): the green lantern still on the dock-post, Mara sees what the ending made of the night,
## coloured by the Gull's burning. Aldous hears the Long Book's shut (once): Oriel's name, the seventh novice, the
## brazier laid for whoever comes down the stair (lit from the ember in the dark ending) and the door-warden's answer to
## the Provost. Lit, Saltmarrow goes gold with the far Spire over the lofts.

const ENDINGS: Array[String] = ["lit", "released", "dark"]
const SHUT := "The Long Book's shut, Brother."
const BYE := "Rest easy, Brother."
const LIGHT_IT := "Hold the ember to it."

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


## Rung home on Kindleby after `ending`, then sailed round to Saltmarrow (the Mercy at its dock).
func _home(ending: String, burned := "pebble") -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_homecoming"))
	state.set_flag("cindermoor_cradle_choice", ending)
	state.set_flag("kindleby_midwinter", "ring" if ending == "dark" else "")
	state.set_flag("saltmarrow_beacon_burned", burned)
	state.set_flag("lanes_ferry_at", "saltmarrow")
	state.set_flag("cindermoor_oriel_choice", "")
	state.set_flag("cindermoor_oriel_knows", false)
	return state


func _event(state: WorldState) -> Dictionary:
	return RegionEvents.arrival(_content().regions["saltmarrow"], state)


func test_no_homecoming_before_the_lane_out() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_spire_lit"))
	state.set_flag("lanes_ferry_at", "saltmarrow")
	assert_true(_event(state).is_empty(), "the Long Book's not shut yet")
	var home := _home("lit")
	home.set_flag("lanes_ferry_at", "kindleby")
	assert_true(_event(home).is_empty(), "only when the Mercy's put in here")
	var offered: Array[String] = []
	_lines(_home("lit"), "aldous", [BYE], offered)
	assert_true(offered.has(SHUT), "Aldous can be told once the lane's out: %s" % [offered])


func test_the_homecoming_per_ending() -> void:
	var marks := {
		"lit": "the Hearthspire burns",
		"released": "The step was warm.",
		"dark": "Nobody chooses for Saltmarrow but Saltmarrow.",
	}
	for ending in ENDINGS:
		var state := _home(ending, "knot")
		var event := _event(state)
		assert_eq(str(event.get("id", "")), "saltmarrow_homecoming", ending)
		var said := _lines(state, RegionEvents.fire(event, state))
		assert_true(said.contains("one long note, then two short"), "%s: the horn's signal (canon, Day 13)" % ending)
		assert_true(said.contains("green lantern"), ending)
		assert_true(said.contains(marks[ending]), "%s: %s" % [ending, said])
		for other in ENDINGS:
			if other != ending:
				assert_false(said.contains(marks[other]), "%s: not %s's" % [ending, other])
		assert_true(said.contains("Aldous has set his bottle down"), "%s: sends you on to Aldous" % ending)
		assert_true(bool(state.get_flag("saltmarrow_homecoming_seen")), ending)
		assert_true(_event(state).is_empty(), "%s: once" % ending)


func test_the_burning_colours_it() -> void:
	var lit := {"pebble": "no song I can find the end of", "knot": "begin in the middle", "gull": "two cups"}
	var dark := {"pebble": "A song nobody can finish.", "knot": "where a net doesn't begin", "gull": "That's what it costs."}
	for burned: String in lit:
		var said := _lines(_home("lit", burned), "saltmarrow_homecoming", ["No. It doesn't give anything back."])
		assert_true(said.contains(lit[burned]), "lit / %s: %s" % [burned, said])
		said = _lines(_home("dark", burned), "saltmarrow_homecoming")
		assert_true(said.contains(dark[burned]), "dark / %s: %s" % [burned, said])
	# Released and the lullaby burned: the Gull hums a tune nobody on the island knows; Oda knows it and won't give it back.
	var pebble := _lines(_home("released", "pebble"), "saltmarrow_homecoming")
	assert_true(pebble.contains("tune with no end") and pebble.contains("rain off a coat"), pebble)
	var knot := _lines(_home("released", "knot"), "saltmarrow_homecoming")
	assert_false(knot.contains("rain off a coat"), "only the lullaby is Oda's to know")
	assert_true(knot.contains("keeping time"), knot)


func test_it_took_me_first() -> void:
	var said := _lines(_home("lit"), "saltmarrow_homecoming", ["It took me first."])
	assert_true(said.contains("Then you're Saltmarrow's."), said)


func test_the_dark_round_starts_here_if_from_the_gull() -> void:
	var ring := _lines(_home("dark"), "saltmarrow_homecoming")
	assert_true(ring.contains("That's here. That's first."), ring)
	var first := _home("dark")
	first.set_flag("kindleby_midwinter", "first")
	var said := _lines(first, "saltmarrow_homecoming")
	assert_true(said.contains("Kindleby asked first") and not said.contains("That's first."), said)


func test_aldous_hears_the_book_shut_once() -> void:
	var marks := {"lit": "It always starts with the hand.", "released": "It isn't lit.", "dark": "Still lit."}
	for ending in ENDINGS:
		var state := _home(ending)
		var said := _lines(state, "aldous", [SHUT, "Say nothing of the High Keeper.", "Let the stair be.",
				"Leave it laid, Brother. For midwinter.", BYE])
		assert_true(said.contains(marks[ending]), "%s: %s" % [ending, said])
		assert_true(said.contains("A door-warden keeps a hearth laid"), ending)
		assert_true(bool(state.get_flag("saltmarrow_aldous_after_seen")), ending)
		var offered: Array[String] = []
		var again := _lines(state, "aldous", [BYE], offered)
		assert_false(offered.has(SHUT), "%s: told once" % ending)
		assert_false(again.contains(marks[ending]), ending)
		assert_false(bool(state.get_flag("saltmarrow_brazier_lit")), "%s: left laid" % ending)


func test_oriel_s_name() -> void:
	var state := _home("released")
	state.set_flag("cindermoor_oriel_choice", "climb")
	var said := _lines(state, "aldous", [SHUT, "She signed the Long Book. \"Oriel Sayre, High Keeper, who put it out.\"",
			"Let the stair be.", BYE])
	assert_true(said.contains("Oriel.") and said.contains("Let it carry, then."), said)
	assert_true(bool(state.get_flag("saltmarrow_aldous_heard_oriel")))
	var boat := _home("dark")
	boat.set_flag("cindermoor_oriel_choice", "boat")
	var offered: Array[String] = []
	said = _lines(boat, "aldous", [SHUT, "The High Keeper's alive. She's sitting in a boat at the slips that never went out."], offered)
	assert_true(said.contains("wait for the tide"), said)
	assert_false(offered.has("She signed the Long Book. \"Oriel Sayre, High Keeper, who put it out.\""), "she didn't sign")


func test_the_seventh_novice() -> void:
	const TOLD := "The seventh novice on the east landing, with the light in their hands. It was me."
	for ending in ENDINGS:
		var state := _home(ending)
		state.set_flag("cindermoor_oriel_choice", "")
		state.set_flag("cindermoor_oriel_knows", true)
		var offered: Array[String] = []
		var said := _lines(state, "aldous", [SHUT, TOLD, "Leave it laid, Brother. For midwinter.", BYE], offered)
		if ending == "lit":
			assert_false(offered.has(TOLD), "lit: the stair burned first; the Wakebearer can't tell it")
		else:
			assert_true(said.contains("I'll take your word over my eyes."), "%s: %s" % [ending, said])
			assert_true(bool(state.get_flag("saltmarrow_aldous_knows_novice")), ending)


func test_the_wrens_brazier_lit_from_the_ember() -> void:
	for laid: String in ["self", ""]:
		var state := _home("dark")
		state.set_flag("saltmarrow_aldous_novice", laid)
		var before := _brazier(state)
		assert_eq(before.size(), 1, "one brazier in the bowl (%s)" % laid)
		assert_true(before[0] == "brazier_laid" if laid != "" else before[0] != "brazier_lit", "before (%s): %s" % [laid, before])
		var said := _lines(state, "aldous", [SHUT, LIGHT_IT, BYE])
		assert_true(said.contains("burns for the first time since the Snuffing"), said)
		assert_true(said.contains("He lays it while you watch") == (laid == ""), "lays it if it wasn't laid (%s)" % laid)
		assert_true(bool(state.get_flag("saltmarrow_brazier_lit")))
		assert_eq(_brazier(state), ["brazier_lit"], "one brazier in the bowl, lit (%s)" % laid)
		var after := _lines(state, "aldous", [BYE])
		assert_true(after.contains("Nobody said he had to keep it cold."), after)
	for ending: String in ["lit", "released"]:
		var offered: Array[String] = []
		_lines(_home(ending), "aldous", [SHUT, "Let the stair be.", BYE], offered)
		assert_false(offered.has(LIGHT_IT), "%s: no ember to light it with" % ending)
	var lit: Array = (_content().regions["saltmarrow"]["props"] as Array).filter(
			func(p: Dictionary) -> bool: return str(p.get("model", "")).ends_with("brazier_lit.glb"))
	assert_eq(lit.size(), 1)
	assert_true((lit[0] as Dictionary).has("light") and (lit[0] as Dictionary).has("sound"), "a small fire: light and crackle")


func test_the_door_warden_s_answer() -> void:
	var expect := {"lit": "now", "released": "now", "dark": "midwinter"}
	for ending in ENDINGS:
		var state := _home(ending)
		state.set_flag("saltmarrow_aldous_boat", "letter")
		var said := _lines(state, "aldous", [SHUT, "Let the stair be.", "Leave it laid, Brother. For midwinter.", BYE])
		assert_eq(str(state.get_flag("saltmarrow_aldous_crossing")), expect[ending], "%s: %s" % [ending, said])
		var no := _home(ending)
		no.set_flag("saltmarrow_aldous_boat", "no")
		said = _lines(no, "aldous", [SHUT, "Let the stair be.", "Leave it laid, Brother. For midwinter.", BYE])
		assert_eq(str(no.get_flag("saltmarrow_aldous_crossing")), "", ending)
		assert_true(said.contains("Nobody's weighing, now"), said)


func test_mara_after() -> void:
	var marks := {"lit": "by the Spire's light", "released": "a blanket up to the Gull", "dark": "The list's on the dock-post"}
	for ending in ENDINGS:
		var state := _home(ending)
		var before := _lines(state, "mara", ["I'll be going."])
		assert_false(before.contains(marks[ending]), "%s: not before the homecoming" % ending)
		state.set_flag("saltmarrow_homecoming_seen", true)
		var said := _lines(state, "mara", ["I'll be going."])
		assert_true(said.contains(marks[ending]), "%s: %s" % [ending, said])


func test_saltmarrow_goes_gold_when_lit() -> void:
	var region: Dictionary = _content().regions["saltmarrow"]
	for ending: String in ["", "lit", "released", "dark"]:
		var state := _home(ending) if ending != "" else fresh_state(_content())
		var light := RegionMood.light(region, state)
		var fog := RegionMood.fog(region, state)
		if ending == "lit":
			assert_eq(str(light.get("sky_horizon", "")), "#DCC29A", "lit: the gold low in the north-east")
			assert_true(absf(float(fog["density"]) - 0.005) < 0.0001, "lit: the harbor all but clear")
		else:
			assert_true(str(light.get("sky_horizon", "")) != "#DCC29A", ending)


func test_the_checkpoint() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_wrens_fire"))
	assert_eq(str(state.get_flag("cindermoor_cradle_choice")), "dark")
	assert_false(Greying.ember_gone(_content(), state), "dark: the ember's still in the hand")
	assert_eq(_brazier(state), ["brazier_lit"])
	assert_true(_event(state).is_empty(), "the homecoming's been seen")


## The brazier models whose `if` holds (all sit in the Wrens' bowl).
func _brazier(state: WorldState) -> Array[String]:
	var shown: Array[String] = []
	for prop: Dictionary in _content().regions["saltmarrow"]["props"]:
		if str(prop.get("shape", "")) == "brazier" and Conditions.evaluate(prop["if"], state):
			shown.append(str(prop["model"]).get_file().get_basename())
	return shown
