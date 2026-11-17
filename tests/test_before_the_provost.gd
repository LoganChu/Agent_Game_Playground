extends TestCase
## Day 110 — after the final card: the Provost comes home, and Aldous before the Provost.
## Back in at Cindermoor after the lane out, the Wakebearer tells the Provost that Tobin asks when she's coming home; she
## goes down to the Boat Stair (`kindleby_provost_going`), Oda's lane out carries her, and Kindleby's arrival event
## `kindleby_provost_home` puts the Long Book on a shelf. Then Aldous (lit/released, the door-warden's answer kept), told the
## candles are lit, goes aboard (`kindleby_aldous_coming`); the next Kindleby arrival, `kindleby_aldous_before_provost`,
## is the meeting: the witnesses' page signed (twice, if both he and she know the Wakebearer was the light), and the
## Wakebearer tells him to keep the chapter-house door or go home (`kindleby_aldous_door`).

const ASK := "Tobin asks when you're coming home."
const CAND := "The Provost's home. She says the candles are lit."
const KEEP := "Keep the door. This time, ask who's going by."
const HOME := "Go home. You've kept enough doors."
const BYE := "Goodbye."
const ENDINGS: Array[String] = ["lit", "released", "dark"]

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


func _event(state: WorldState, region := "kindleby") -> Dictionary:
	return RegionEvents.arrival(_content().regions[region], state)


func _placed(state: WorldState, npc: String) -> Array[String]:
	var where: Array[String] = []
	for region_id: String in _content().regions:
		for placement: Dictionary in _content().regions[region_id].get("npcs", []):
			if str(placement["npc"]) == npc and Conditions.evaluate(placement.get("if", []), state):
				where.append(region_id)
	return where


## Every homecoming seen (the_quiet_water), re-coloured by `ending`, and run back in to the Boat Stair.
func _back_in(ending := "lit") -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_quiet_water"))
	state.set_flag("cindermoor_cradle_choice", ending)
	state.set_flag("kindleby_midwinter", "ring" if ending == "dark" else "")
	state.set_flag("lanes_ferry_at", "cindermoor")
	return state


## `_back_in`, the Provost asked home and carried out to Kindleby by Oda, the arrival not yet played.
func _sailed_home(ending := "lit") -> WorldState:
	var state := _back_in(ending)
	_lines(state, "provost", [ASK])
	_lines(state, "oda", ["Take me out to Kindleby."])
	return state


## `_sailed_home` with the homecoming played; Aldous crossing (lit/released), on the ridge if `ridge`.
func _provost_home(ending := "lit", ridge := true) -> WorldState:
	var state := _sailed_home(ending)
	_lines(state, RegionEvents.fire(_event(state), state))
	state.set_flag("saltmarrow_aldous_boat", "letter")
	state.set_flag("kindleby_provost_read_letter", true)
	state.set_flag("saltmarrow_aldous_after_seen", true)
	state.set_flag("saltmarrow_aldous_crossing", "now")
	state.set_flag("saltmarrow_aldous_novice", "lamp" if ridge else "")
	state.set_flag("thornwold_aldous_landed", ridge)
	state.set_flag("thornwold_aldous_met_wynn", ridge)
	return state


func test_the_provost_is_asked_home_only_once_back_in() -> void:
	var before := fresh_state(_content())
	Scenarios.apply(_content(), before, Scenarios.resolve("the_spire_lit"))
	var offered: Array[String] = []
	_lines(before, "provost", [], offered)
	assert_false(offered.has(ASK), "not before the lane out: %s" % [offered])
	for ending: String in ENDINGS:
		var state := _back_in(ending)
		assert_eq(_placed(state, "provost"), ["cindermoor_spire_foot"] as Array[String], ending)
		var said := _lines(state, "provost", [ASK])
		assert_true(said.contains("when the Long Book's put away"), "%s: %s" % [ending, said])
		assert_true(bool(state.get_flag("kindleby_provost_going")), ending)
		assert_eq(_placed(state, "provost"), ["cindermoor_boat_stair"] as Array[String], "%s: waiting on the Mercy" % ending)
		assert_true(_lines(state, "provost").contains("wait for a tide"), ending)
		var again: Array[String] = []
		_lines(state, "provost", [], again)
		assert_false(again.has(ASK), "%s: asked once" % ending)


func test_the_going_home_per_ending() -> void:
	var marks := {"lit": "asked twice", "released": "calling it a vigil", "dark": "put himself on it twice"}
	for ending: String in marks:
		var said := _lines(_back_in(ending), "provost", [ASK])
		for other: String in marks:
			assert_eq(said.contains(marks[other]), other == ending, "%s shows %s" % [ending, other])


func test_oda_carries_her_home() -> void:
	var state := _sailed_home("released")
	assert_eq(str(state.get_flag("lanes_ferry_at")), "kindleby")
	var event := _event(state)
	assert_eq(str(event.get("id", "")), "kindleby_provost_home")
	var said := _lines(state, RegionEvents.fire(event, state))
	assert_true(said.contains("You may also walk on the steps."), said)
	assert_true(said.contains("Not yet."), "the Book's not to be dusted")
	assert_true(bool(state.get_flag("kindleby_provost_home")))
	assert_eq(_placed(state, "provost"), ["kindleby"] as Array[String], "at the chapter-house steps")
	assert_true(_event(state).is_empty(), "once")
	assert_true(_lines(state, "tobin", [BYE]).contains("I may walk on the steps"), "Tobin after")
	# Oda's lane out says who's in the stern only while she's going.
	var plain := _back_in("lit")
	assert_false(_lines(plain, "oda", ["Take me out to Kindleby."]).contains("The Provost sits in the stern"))


func test_the_shelf_per_ending() -> void:
	var marks := {"lit": "for one page", "released": "The writing's done", "dark": "I'll hold the lamp"}
	for ending: String in marks:
		var state := _sailed_home(ending)
		var said := _lines(state, RegionEvents.fire(_event(state), state))
		for other: String in marks:
			assert_eq(said.contains(marks[other]), other == ending, "%s shows %s" % [ending, other])
		assert_false(said.contains("door-warden owes me"), "%s: no Aldous hook without his letter" % ending)
		assert_true(_lines(state, "provost").contains("spine out"), ending)


func test_aldous_is_told_the_candles_are_lit() -> void:
	# On the ridge (Thornwold first): "not yet" until she's home, then the choice.
	var ridge := _provost_home("lit", true)
	assert_true(_lines(ridge, "provost").contains("tell him so"), "the Provost's hook")
	var said := _lines(ridge, "aldous", [CAND])
	assert_false(said.contains("Not yet, though."), "the next leg's come: %s" % said)
	assert_true(said.contains("Mind the ladder"), said)
	assert_true(bool(ridge.get_flag("kindleby_aldous_coming")))
	assert_eq(_placed(ridge, "aldous"), [] as Array[String], "below on the Mercy")
	# On his bench (crossing, but never heard Wynn lives).
	var bench := _provost_home("released", false)
	assert_eq(_placed(bench, "aldous"), ["saltmarrow"] as Array[String])
	said = _lines(bench, "aldous", [CAND])
	assert_true(said.contains("Is Oda going?"), said)
	assert_false(said.contains("Mind the ladder"), "no Lamp on Saltmarrow")
	assert_true(bool(bench.get_flag("kindleby_aldous_coming")))
	assert_eq(_placed(bench, "aldous"), [] as Array[String])
	# Not before she's home; not in the dark ending (he comes at midwinter).
	var early := _back_in("lit")
	early.set_flag("saltmarrow_aldous_crossing", "now")
	early.set_flag("thornwold_aldous_landed", true)
	assert_true(_lines(early, "aldous").contains("Not yet, though."), "still not yet")
	var dark := _provost_home("dark", false)
	dark.set_flag("saltmarrow_aldous_crossing", "midwinter")
	var offered: Array[String] = []
	_lines(dark, "aldous", [], offered)
	assert_false(offered.has(CAND), "dark: %s" % [offered])


func test_aldous_before_the_provost() -> void:
	var marks := {"lit": "We only ever saw it from underneath.", "released": "I came for the second one."}
	for ending: String in marks:
		for ridge: bool in [true, false]:
			var state := _provost_home(ending, ridge)
			_lines(state, "aldous", [CAND])
			var event := _event(state)
			assert_eq(str(event.get("id", "")), "kindleby_aldous_before_provost", ending)
			var said := _lines(state, RegionEvents.fire(event, state), [KEEP])
			var tag := "%s/%s" % [ending, "ridge" if ridge else "bench"]
			assert_true(said.contains(marks[ending]), "%s: %s" % [tag, said])
			assert_eq(said.contains("Thornwold's ridge"), ending == "lit" and ridge, tag)
			assert_true(said.contains("Sign it, and it's a record."), tag)
			assert_true(said.contains("It's a start"), "%s: one witness" % tag)
			assert_true(said.contains("Do I keep a door again?"), tag)
			assert_eq(str(state.get_flag("kindleby_aldous_door")), "kept", tag)
			assert_eq(_placed(state, "aldous"), ["kindleby"] as Array[String], "%s: at the chapter-house door" % tag)
			assert_true(_lines(state, "aldous").contains("put me on report yet"), tag)
			assert_true(_lines(state, "provost").contains("I've not corrected it"), tag)
			assert_true(_event(state).is_empty(), "%s: once" % tag)


func test_the_second_witness() -> void:
	var state := _provost_home("released", true)
	state.set_flag("cindermoor_provost_knows", true)
	state.set_flag("saltmarrow_aldous_knows_novice", true)
	_lines(state, "aldous", [CAND])
	var said := _lines(state, RegionEvents.fire(_event(state), state), [KEEP])
	assert_true(said.contains("The light I let by."), said)
	assert_true(said.contains("I was on the stair"), said)
	assert_true(said.contains("Two. The door-warden, and the light."), said)
	assert_false(said.contains("It's a start"), "two, not one")
	# Only one of them knows: one witness.
	var half := _provost_home("released", true)
	half.set_flag("cindermoor_provost_knows", true)
	_lines(half, "aldous", [CAND])
	assert_false(_lines(half, RegionEvents.fire(_event(half), half), [KEEP]).contains("I was on the stair"))


func test_aldous_goes_home_with_her_leave() -> void:
	for ridge: bool in [true, false]:
		var state := _provost_home("lit", ridge)
		_lines(state, "aldous", [CAND])
		var said := _lines(state, RegionEvents.fire(_event(state), state), [HOME])
		assert_true(said.contains("Then go with my leave."), said)
		assert_eq(said.contains("Wynn'll have the bench swept"), ridge, said)
		assert_eq(said.contains("Mara will say"), not ridge, said)
		assert_eq(str(state.get_flag("kindleby_aldous_door")), "home")
		assert_false(bool(state.get_flag("kindleby_aldous_coming")))
		var home: Array[String] = ["thornwold_ridge" if ridge else "saltmarrow"]
		assert_eq(_placed(state, "aldous"), home, "back where he was")
		assert_true(_lines(state, "aldous", [BYE]).contains("leave"), "home-again line")
		assert_true(_lines(state, "provost").contains("I find I miss being disobeyed."))
		var offered: Array[String] = []
		_lines(state, "aldous", [BYE], offered)
		assert_false(offered.has(CAND), "not offered again")


func test_the_checkpoint() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("before_the_provost"))
	assert_eq(_placed(state, "aldous"), ["kindleby"] as Array[String])
	assert_eq(_placed(state, "provost"), ["kindleby"] as Array[String])
	assert_true(_event(state).is_empty(), "everything on Kindleby's been seen")
