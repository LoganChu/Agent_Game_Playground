extends TestCase
## Day 120 — the bank leans back. The offshore Greying banks (Day 119) off Saltmarrow's harbor mouth and Shingle Point
## get their lines. Before the burn Mara tells what lies off the mouth (`saltmarrow_mara_bank`: nobody past the outer
## post, the lanes run through it) and Pell where lost things come from (`shingle_pell_bank`). After it both notice it
## leaned back (`saltmarrow_mara_bank_back` per burn — the gull burn: somebody used to row out to its edge;
## `shingle_pell_bank_back`). After the homecoming Mara says what it is now, per ending (`saltmarrow_mara_bank_after`).

const ENDINGS: Array[String] = ["lit", "released", "dark"]
const MARA_BEFORE := "There's grey lying out past the harbor mouth."
const MARA_BACK := "The grey off the harbor mouth has drawn back."
const MARA_AFTER := "The bank off the harbor mouth."
const PELL_BEFORE := "What's that grey out on the water?"
const PELL_BACK := "The grey out at sea has pulled back."

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


## After the burn, with Mara's beacon scene already seen so the hub comes first.
func _after(burned: String) -> WorldState:
	var state := _at("aftermath_%s" % burned)
	state.set_flag("saltmarrow_mara_saw_beacon_lit", true)
	return state


## Rung home after `ending` and sailed round to Saltmarrow, the homecoming seen.
func _home(ending: String) -> WorldState:
	var state := _at("the_homecoming")
	state.set_flag("cindermoor_cradle_choice", ending)
	state.set_flag("saltmarrow_beacon_burned", "knot")
	state.set_flag("lanes_ferry_at", "saltmarrow")
	state.set_flag("saltmarrow_homecoming_seen", true)
	return state


func test_mara_before_the_burn() -> void:
	var state := _at("saltmarrow")
	var offered: Array[String] = []
	var said := _lines(state, "mara", [MARA_BEFORE], offered)
	assert_true(MARA_BEFORE in offered, "asked before the burn")
	assert_false(MARA_BACK in offered, "nothing's drawn back yet")
	assert_true(said.contains("found a mooring"), said)
	assert_true(said.contains("past the outer post"), said)
	assert_true(said.contains("The lanes run through it"), said)
	assert_true(bool(state.get_flag("saltmarrow_mara_bank")))
	var again: Array[String] = []
	_lines(state, "mara", [], again)
	assert_false(MARA_BEFORE in again, "told once")


func test_mara_after_the_burn_per_burn() -> void:
	var marks := {
		"pebble": "Something ought to be sung about it",
		"knot": "a net with nobody hauling",
		"gull": "Can't see who's in it",
	}
	for burned: String in marks:
		var state := _after(burned)
		var offered: Array[String] = []
		var said := _lines(state, "mara", [MARA_BACK], offered)
		assert_true(MARA_BACK in offered, burned)
		assert_false(MARA_BEFORE in offered, "%s: the before line's gone" % burned)
		assert_true(said.contains("four boat-lengths"), said)
		assert_true(said.contains(marks[burned]), "%s: %s" % [burned, said])
		for other: String in marks:
			if other != burned:
				assert_false(said.contains(marks[other]), "%s not %s" % [burned, other])
		assert_false(said.contains("You asked me about that"), "%s: never asked before" % burned)
		assert_true(bool(state.get_flag("saltmarrow_mara_bank_back")))
		var again: Array[String] = []
		_lines(state, "mara", [], again)
		assert_false(MARA_BACK in again, "%s: once" % burned)
	var asked := _after("knot")
	asked.set_flag("saltmarrow_mara_bank", true)
	assert_true(_lines(asked, "mara", [MARA_BACK]).contains("You asked me about that, before."))


func test_mara_after_the_homecoming_per_ending() -> void:
	var marks := {"lit": "Gone to a haze", "released": "just where the Gull leaned it", "dark": "until midwinter"}
	for ending: String in ENDINGS:
		var state := _home(ending)
		var offered: Array[String] = []
		var said := _lines(state, "mara", [MARA_AFTER], offered)
		assert_true(MARA_AFTER in offered, ending)
		assert_false(MARA_BACK in offered, "%s: the Act I line's not offered at the homecoming" % ending)
		assert_true(said.contains(marks[ending]), "%s: %s" % [ending, said])
		for other: String in marks:
			if other != ending:
				assert_false(said.contains(marks[other]), "%s not %s" % [ending, other])
		var again: Array[String] = []
		_lines(state, "mara", [], again)
		assert_false(MARA_AFTER in again, "%s: once" % ending)
	var before := _home("lit")
	before.set_flag("saltmarrow_homecoming_seen", false)
	var not_yet: Array[String] = []
	_lines(before, "mara", [], not_yet)
	assert_false(MARA_AFTER in not_yet, "not before the homecoming")


func test_pell_before_and_after() -> void:
	var early := _at("new_game")
	early.set_flag("intro_seen", true)
	early.set_flag("shingle_met_pell", true)
	var offered: Array[String] = []
	var said := _lines(early, "pell", [PELL_BEFORE], offered)
	assert_true(PELL_BEFORE in offered, "asked before the burn")
	assert_false(PELL_BACK in offered)
	assert_true(said.contains("where lost things come FROM"), said)
	assert_true(bool(early.get_flag("shingle_pell_bank")))

	var state := _after("knot")
	var after_offered: Array[String] = []
	var back := _lines(state, "pell", [PELL_BACK], after_offered)
	assert_true(PELL_BACK in after_offered)
	assert_false(PELL_BEFORE in after_offered, "the before line's gone")
	assert_true(back.contains("They're just WET"), back)
	assert_true(back.contains("Somebody's mark is somebody's"), "never asked before: %s" % back)
	assert_false(back.contains("It went up"), "only when their pebble burned")
	var again: Array[String] = []
	_lines(state, "pell", [], again)
	assert_false(PELL_BACK in again, "once")

	var lent := _after("pebble")
	lent.set_flag("saltmarrow_pell_lent_pebble", true)
	lent.set_flag("shingle_pell_bank", true)
	var lent_said := _lines(lent, "pell", [PELL_BACK])
	assert_true(lent_said.contains("It went up"), lent_said)
	assert_true(lent_said.contains("You asked me what it was"), lent_said)


func test_the_banks_are_where_they_say() -> void:
	# The lines say the bank lies off the mouth and leaned back thinner: hold the data to it.
	for region_id: String in ["saltmarrow", "shingle_point"]:
		var areas: Array = _content().regions[region_id].get("greying", [])
		var before := _at("saltmarrow")
		var after := _after("knot")
		var thick := 0.0
		var thin := 0.0
		for area: Dictionary in areas:
			if not str(area.get("note", "")).begins_with("Day 119"):
				continue
			if Conditions.evaluate(area.get("if", []), before):
				thick = maxf(thick, float(area["strength"]))
			if Conditions.evaluate(area.get("if", []), after):
				thin = maxf(thin, float(area["strength"]))
		assert_true(thick > 0.0 and thin > 0.0, region_id)
		assert_true(thin < thick, "%s: thinner after the burn" % region_id)


func test_checkpoint() -> void:
	var state := _at("the_bank_leans_back")
	assert_eq(str(state.get_flag("saltmarrow_beacon_burned")), "knot")
	var offered: Array[String] = []
	_lines(state, "pell", [], offered)
	assert_true(PELL_BACK in offered, "Pell's line is waiting at the checkpoint")
