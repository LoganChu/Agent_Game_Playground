extends TestCase
## Day 122 — Brenner's tally. The bank off the harbor mouth (Days 119–120) gets the man Mara named: Brenner, on a fish
## box at the end of Saltmarrow's breakwater (pipe before the burn; none after — he dropped it when the Gull caught).
## Before the burn: the cod grounds (once Mara's mentioned them) and the Low Water past them, where Dunstan rowed to the
## singing edge every spring and Brenner kept the tally (after the gull burn: twenty-two notches for nobody). After the
## burn: go or wait (`saltmarrow_brenner_cod`), the cork float in Pell's crate is his (`saltmarrow_brenner_float`). Tam
## tells how he paced it. After the homecoming: released/dark on his box, per go/wait; lit, out on the cod grounds.

const ENDINGS: Array[String] = ["lit", "released", "dark"]
const BURNS: Array[String] = ["pebble", "knot", "gull"]
const COD := "Mara says you went out to the cod grounds."
const CHOIR := "What's out past the cod grounds?"
const LEANED := "The grey's drawn back off the mouth."
const GO := "Go. The Gull's lit. It'll see you home."
const WAIT := "Wait. Mara knows that light better than anyone."
const FLOAT := "Pell found a cork float with a mark burned in it."
const TAM_BANK := "Mara says you paced the bank with an oar."
const TAM_OUT := "Where's Brenner?"
const BRENNER := "res://assets/models/characters/brenner.glb"
const NOPIPE := "res://assets/models/characters/brenner_nopipe.glb"

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


func _after(burned: String) -> WorldState:
	var state := _at("aftermath_%s" % burned)
	state.set_flag("saltmarrow_mara_saw_beacon_lit", true)
	return state


func _home(ending: String, cod: String = "") -> WorldState:
	var state := _at("the_homecoming")
	state.set_flag("cindermoor_cradle_choice", ending)
	state.set_flag("saltmarrow_beacon_burned", "knot")
	state.set_flag("lanes_ferry_at", "saltmarrow")
	state.set_flag("saltmarrow_homecoming_seen", true)
	state.set_flag("saltmarrow_brenner_cod", cod)
	return state


## Which Brenner shows on Saltmarrow (his model), or "" when he's not there; and the lit ending's boat.
func _brenner_shown(state: WorldState) -> Array[String]:
	var shown: Array[String] = []
	for placement: Dictionary in _content().regions["saltmarrow"].get("npcs", []):
		if str(placement["npc"]) == "brenner" and Conditions.evaluate(placement.get("if", []), state):
			shown.append(str(placement.get("model", BRENNER)))
	return shown


func _boat_out(state: WorldState) -> bool:
	for prop: Dictionary in _content().regions["saltmarrow"].get("props", []):
		if str(prop["model"]).ends_with("rowboat_out.glb") and Conditions.evaluate(prop.get("if", []), state):
			return true
	return false


func test_on_his_box_pipe_before_none_after() -> void:
	var before := _at("saltmarrow")
	assert_eq(_brenner_shown(before), [BRENNER] as Array[String], "the pipe before the burn")
	assert_false(_boat_out(before))
	for burned: String in BURNS:
		assert_eq(_brenner_shown(_after(burned)), [NOPIPE] as Array[String], "%s: no pipe after" % burned)
	for ending: String in ENDINGS:
		var home := _home(ending)
		if ending == "lit":
			assert_eq(_brenner_shown(home).size(), 0, "lit: out on the cod grounds")
			assert_true(_boat_out(home), "lit: his boat past the post")
		else:
			assert_eq(_brenner_shown(home), [NOPIPE] as Array[String], ending)
			assert_false(_boat_out(home), ending)
	assert_eq(str(_content().npcs["brenner"]["model"]), BRENNER)
	assert_true(ResourceLoader.exists(BRENNER) and ResourceLoader.exists(NOPIPE))
	# The breakwater end is walkable ground, out of the bank, facing out to sea.
	for placement: Dictionary in _content().regions["saltmarrow"]["npcs"]:
		if str(placement["npc"]) == "brenner":
			var at: Array = placement["position"]
			assert_true(float(at[2]) > 18.0 and float(at[0]) > 15.0, "at the breakwater's end: %s" % [at])


func test_before_the_burn() -> void:
	var state := _at("saltmarrow")
	var offered: Array[String] = []
	var said := _lines(state, "brenner", [CHOIR], offered)
	assert_true(said.contains("Don't stand in my light"), said)
	assert_true(bool(state.get_flag("saltmarrow_met_brenner")))
	assert_false(COD in offered, "not till Mara's mentioned the cod grounds")
	assert_false(LEANED in offered, "nothing's leaned back yet")
	assert_true(said.contains("fog on it that sings"), said)
	assert_true(said.contains("Dunstan Tollen used to row out"), said)
	assert_true(bool(state.get_flag("saltmarrow_brenner_choir")))
	state.set_flag("saltmarrow_mara_bank", true)
	var asked: Array[String] = []
	var cod := _lines(state, "brenner", [COD], asked)
	assert_true(COD in asked)
	assert_false(CHOIR in asked, "told once")
	assert_true(cod.contains("What's dinner?"), cod)
	assert_true(cod.contains("Still here"), "met before: %s" % cod)


func test_after_the_burn_per_burn() -> void:
	var marks := {"pebble": "hum something round the stem", "knot": "Started it in the middle", "gull": ""}
	for burned: String in BURNS:
		var state := _after(burned)
		var offered: Array[String] = []
		var said := _lines(state, "brenner", [CHOIR], offered)
		assert_true(said.contains("Dropped my pipe in the harbor"), said)
		assert_true(LEANED in offered, burned)
		assert_false(COD in offered, "%s: the before line's gone" % burned)
		for other: String in marks:
			if marks[other] != "":
				assert_eq(said.contains(marks[other]), other == burned, "%s: %s" % [burned, other])
		if burned == "gull":
			assert_true(said.contains("Twenty-two notches"), said)
			assert_false(said.contains("Dunstan"), "the gull burn: nobody says his name")
		else:
			assert_true(said.contains("Dunstan Tollen used to row out"), said)
	var home := _after("knot")
	home.set_flag("fen_dunstan_walk", "home")
	assert_true(_lines(home, "brenner").contains("Backward, I've no doubt"))
	var home_gull := _after("gull")
	home_gull.set_flag("fen_dunstan_walk", "home")
	var gull_said := _lines(home_gull, "brenner", [CHOIR])
	assert_true(gull_said.contains("Big fellow rowed in"), gull_said)
	assert_false(gull_said.contains("Dunstan"), gull_said)


func test_go_or_wait_and_the_float() -> void:
	for pick: String in [GO, WAIT]:
		var state := _after("knot")
		var said := _lines(state, "brenner", [LEANED, pick])
		assert_true(said.contains("Four boat-lengths"), said)
		assert_eq(str(state.get_flag("saltmarrow_brenner_cod")), "go" if pick == GO else "wait")
		var again: Array[String] = []
		_lines(state, "brenner", [], again)
		assert_false(LEANED in again, "asked once")
	var crate := _after("knot")
	assert_false(_lines(crate, "pells_lost_things").contains("BRENNERS"))
	assert_true(_lines(crate, "pells_lost_things").contains("SOMBODYS"))
	var offered: Array[String] = []
	_lines(crate, "brenner", [], offered)
	assert_false(FLOAT in offered, "not till Pell's said so")
	crate.set_flag("shingle_pell_bank_back", true)
	var said := _lines(crate, "brenner", [FLOAT])
	assert_true(said.contains("That's my mark"), said)
	assert_true(bool(crate.get_flag("saltmarrow_brenner_float")))
	var now := _lines(crate, "pells_lost_things")
	assert_true(now.contains("BRENNERS. HE SAYS KEEP IT."), now)
	# Before the burn the cork hasn't washed in; and it's on the crate as a prop after.
	assert_false(_lines(_at("saltmarrow"), "pells_lost_things").contains("round of cork"))
	var shown := 0
	for prop: Dictionary in _content().regions["shingle_point"]["props"]:
		if str(prop["model"]).ends_with("cork_float.glb"):
			assert_false(Conditions.evaluate(prop.get("if", []), _at("saltmarrow")))
			assert_true(Conditions.evaluate(prop.get("if", []), crate))
			shown += 1
	assert_eq(shown, 1)


func test_after_the_homecoming() -> void:
	var marks := {
		"released": {"go": "I went the once", "wait": "Still waiting"},
		"dark": {"go": "know what he's putting his name to", "wait": "Never did go out"},
	}
	for ending: String in marks:
		for cod: String in ["go", "wait"]:
			var said := _lines(_home(ending, cod), "brenner")
			assert_true(said.contains(marks[ending][cod]), "%s/%s: %s" % [ending, cod, said])
			var other := "wait" if cod == "go" else "go"
			assert_false(said.contains(marks[ending][other]), "%s/%s" % [ending, cod])
	assert_true(_lines(_home("dark"), "brenner").contains("Put my name on Mara's list"))
	assert_true(_lines(_home("released"), "brenner").contains("Sat just where the Gull put it"))
	# Lit: Tam points him out, per go/wait.
	for cod: String in ["go", "wait", ""]:
		var state := _home("lit", cod)
		var offered: Array[String] = []
		var said := _lines(state, "tam", [TAM_OUT], offered)
		assert_true(TAM_OUT in offered)
		assert_true(said.contains("a speck with a cap on"), said)
		assert_eq(said.contains("Tells everyone you told him to go"), cod == "go", cod)
		assert_eq(said.contains("like it was his own idea"), cod == "wait", cod)
	var released: Array[String] = []
	_lines(_home("released"), "tam", [], released)
	assert_false(TAM_OUT in released, "only when he's out")


func test_tam_paced_it() -> void:
	var marks := {"pebble": "Rowed back singing", "knot": "a net with nobody hauling", "gull": "another boat behind us"}
	var before: Array[String] = []
	_lines(_at("saltmarrow"), "tam", [], before)
	assert_false(TAM_BANK in before, "not before the burn")
	for burned: String in BURNS:
		var state := _after(burned)
		var said := _lines(state, "tam", [TAM_BANK])
		assert_true(said.contains("I sat on his oars"), said)
		for other: String in marks:
			assert_eq(said.contains(marks[other]), other == burned, "%s: %s" % [burned, other])
		var again: Array[String] = []
		_lines(state, "tam", [], again)
		assert_false(TAM_BANK in again, "once")


func test_checkpoint() -> void:
	var state := _at("brenners_tally")
	assert_eq(str(state.get_flag("saltmarrow_beacon_burned")), "gull")
	assert_eq(_brenner_shown(state), [NOPIPE] as Array[String])
	assert_true(_lines(state, "brenner", [CHOIR]).contains("Twenty-two notches"))
