extends TestCase
## Day 118 — Ness comes back. After the count down Ness Garrow is back, alone, at the Unmoored's shelter on the long
## steps (she went off along the shoulder when the doused cresset was relit). Asked why (once, `cindermoor_ness_back`)
## she answers per ending; she hears where the one who was here first went (once, `cindermoor_ness_heard_oriel`);
## in the dark ending she asks to be asked at midwinter (`cindermoor_ness_midwinter`); after the Keepers relit her
## cresset she's asked if Hild Garrow is kin (`cindermoor_ness_garrow`: no — her man's name, a common one).

const WHY := "You came back."
const ORIEL := "The one who was here first. She came down."
const MIDWINTER := "At midwinter the ember goes round the ring. Shall I ask you?"
const GARROW := "Hild Garrow dug out the cresset. Any kin of yours?"

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, "ness", typed, offered)


## The homecoming checkpoint (lit, the cresset relit by the Wakebearer, Ness met with the ember cupped).
func _after(ending := "lit") -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_homecoming"))
	state.set_flag("cindermoor_cradle_choice", ending)
	return state


func _ness_here(state: WorldState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for placement: Dictionary in _content().regions["cindermoor_long_steps"].get("npcs", []):
		if str(placement["npc"]) == "ness" and Conditions.evaluate(placement.get("if", []), state):
			out.append(placement)
	return out


func _object_here(state: WorldState, id: String) -> bool:
	for object: Dictionary in _content().regions["cindermoor_long_steps"].get("objects", []):
		if str(object["id"]) == id:
			return Conditions.evaluate(object.get("if", []), state)
	return false


func test_where_she_stands() -> void:
	var before := _after()
	before.set_flag("cindermoor_counted_down", false)
	assert_eq(_ness_here(before).size(), 0, "gone along the shoulder before the ending")
	assert_true(_object_here(before, "steps_unmoored_gone"), "the empty place")
	var after := _after()
	var here := _ness_here(after)
	assert_eq(here.size(), 1, "back after the count down, one placement")
	assert_true(absf(float(here[0]["position"][2]) + 32.4) < 0.01, "at the shelter's mouth")
	assert_false(_object_here(after, "steps_unmoored_gone"), "nobody's place isn't empty now")
	var early := fresh_state(_content())
	Scenarios.apply(_content(), early, Scenarios.resolve("the_unmoored"))
	assert_eq(_ness_here(early).size(), 1, "the first placement still stands before the relighting")
	assert_true(absf(float(_ness_here(early)[0]["position"][2]) + 29.2) < 0.01)


func test_why_she_came_back_per_ending() -> void:
	var expect := {
		"lit": ["thin as breath", "hollow there", "never asked for it"],
		"released": ["Out, not in", "who'd let them out", "as thick as ever"],
		"dark": ["Still lit", "every island chooses", "carried it down again"],
	}
	for ending: String in expect:
		var state := _after(ending)
		var offered: Array[String] = []
		var said := _lines(state, [WHY], offered)
		assert_true(WHY in offered, "asked, %s" % ending)
		for bit: String in expect[ending]:
			assert_true(said.contains(bit), "%s: %s" % [ending, bit])
		assert_true(said.contains("I left my rake"), "the rake left on the shelter")
		assert_true(said.contains("worn pale"), "met before: her rake in her hand again")
		assert_true(bool(state.get_flag("cindermoor_ness_back")))
		offered.clear()
		_lines(state, [], offered)
		assert_false(WHY in offered, "once")
	# Led up in the dark, and the lit ending took the counting.
	var led := _after("lit")
	led.set_flag("cindermoor_way_on", "led")
	led.set_flag("cindermoor_keepers_relit", true)
	var said := _lines(led, [WHY])
	assert_true(said.contains("You're not counting now"))
	assert_false(said.contains("never asked for it"))
	assert_true(said.contains("took my rake this time"))
	assert_true(said.contains("across her knees"))


func test_never_met_before() -> void:
	var state := _after()
	state.set_flag("cindermoor_ness_met", false)
	var said := _lines(state)
	assert_true(said.contains("I'm Ness"))
	assert_true(bool(state.get_flag("cindermoor_ness_met")))
	assert_false(_lines(state).contains("I'm Ness"), "only the first time")


func test_where_the_first_one_went() -> void:
	var expect := {
		"boat": "boat I'd not take out",
		"climb": "I'll miss her feet",
		"own": "Behind somebody who's going to ask you things",
	}
	for choice: String in expect:
		var state := _after()
		state.set_flag("cindermoor_oriel_choice", choice)
		var said := _lines(state, [ORIEL])
		assert_true(said.contains(expect[choice]), choice)
		assert_true(said.contains("She was here first"))
		assert_true(bool(state.get_flag("cindermoor_ness_heard_oriel")))
		var offered: Array[String] = []
		_lines(state, [], offered)
		assert_false(ORIEL in offered, "once")
	var unmet := _after()
	unmet.set_flag("cindermoor_eighth_met", false)
	var offered: Array[String] = []
	_lines(unmet, [], offered)
	assert_false(ORIEL in offered, "not if the Wakebearer never met her")


func test_midwinter_in_the_dark() -> void:
	var offered: Array[String] = []
	_lines(_after("lit"), [], offered)
	assert_false(MIDWINTER in offered, "only in the dark ending")
	var ask := _after("dark")
	var said := _lines(ask, [MIDWINTER, "I'll ask you. You can say no."])
	assert_true(said.contains("The fen won't"))
	assert_true(said.contains("a thing I can say no to"))
	assert_eq(str(ask.get_flag("cindermoor_ness_midwinter")), "ask")
	offered.clear()
	_lines(ask, [], offered)
	assert_false(MIDWINTER in offered, "said once")
	var leave := _after("dark")
	said = _lines(leave, [MIDWINTER, "No. I'll leave you be."])
	assert_true(said.contains("That's what we came for"))
	assert_eq(str(leave.get_flag("cindermoor_ness_midwinter")), "leave")


func test_garrow_is_her_mans_name() -> void:
	var offered: Array[String] = []
	_lines(_after(), [], offered)
	assert_false(GARROW in offered, "the Wakebearer relit it: no Hild to ask about")
	var state := _after()
	state.set_flag("cindermoor_keepers_relit", true)
	var said := _lines(state, [GARROW])
	assert_true(said.contains("Half the lanes are Garrows"))
	assert_true(said.contains("my man's name"))
	assert_true(bool(state.get_flag("cindermoor_ness_garrow")))
	offered.clear()
	_lines(state, [], offered)
	assert_false(GARROW in offered, "once")


func test_the_checkpoint() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("ness_comes_back"))
	assert_eq(_ness_here(state).size(), 1, "Ness at the shelter")
	assert_eq(str(state.get_flag("cindermoor_cradle_choice")), "lit")
	assert_eq(str(state.get_flag("lanes_ferry_at")), "cindermoor")
	var offered: Array[String] = []
	_lines(state, [], offered)
	assert_false(WHY in offered, "already asked in the checkpoint")
	assert_true(ORIEL in offered)
