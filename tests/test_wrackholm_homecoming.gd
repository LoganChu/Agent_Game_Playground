extends TestCase
## Day 102 — the epilogues, part five: Wrackholm. After the lane out the Mercy puts in at the yard's jetty (arrival event
## `wrackholm_homecoming`): the answering horn answers a boat for the first time since the Gannet, and Wenna comes down
## to the jetty's foot. Per ending, coloured by the Wrack's burning (answer / board / white) and Jory gone up or not.
## Then the Book's last line, shown again (`wrackholm_last_line`): the Wakebearer's own hand, "I can count.", and
## "Came in." or left. Lit, Wrackholm goes gold with the far Spire in the south-west. Wenna and Jory have after-lines.

const ENDINGS: Array[String] = ["lit", "released", "dark"]
const BYE := "Goodbye."
const LAST := "Show me the last line."

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed)


## Rung home on Kindleby after `ending`, then sailed round to Wrackholm (the Mercy at the yard's jetty).
func _home(ending: String, burned := "answer", jory_up := true) -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_homecoming"))
	state.set_flag("cindermoor_cradle_choice", ending)
	state.set_flag("kindleby_midwinter", "ring" if ending == "dark" else "")
	state.set_flag("wrackholm_beacon_burned", burned)
	state.set_flag("wrackholm_jory_up", jory_up)
	state.set_flag("wrackholm_horn_sounded", true)
	state.set_flag("wrackholm_book_opened", true)
	state.set_flag("lanes_ferry_at", "wrackholm")
	return state


## The choices Wenna offers when greeted (then goodbye).
func _offered(state: WorldState) -> Array[String]:
	var offered: Array[String] = []
	var picks: Array[String] = [BYE]
	play_dialogue(_content(), state, "wenna", picks, offered)
	return offered


func _event(state: WorldState) -> Dictionary:
	return RegionEvents.arrival(_content().regions["wrackholm"], state)


func _homecoming_next(state: WorldState) -> bool:
	return str(_event(state).get("id", "")) == "wrackholm_homecoming"


## Seen the homecoming (its own `set`), then asks Wenna for the last line and answers `pick`.
func _last_line(state: WorldState, pick: String) -> String:
	state.set_flag("wrackholm_homecoming_seen", true)
	return _lines(state, "wenna", [LAST, pick, BYE])


func test_no_homecoming_before_the_lane_out() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_spire_lit"))
	state.set_flag("lanes_ferry_at", "wrackholm")
	assert_false(_homecoming_next(state), "the Long Book's not shut yet")
	var home := _home("lit")
	home.set_flag("lanes_ferry_at", "fen")
	assert_false(_homecoming_next(home), "only when the Mercy's put in here")


func test_the_homecoming_per_ending() -> void:
	var marks := {
		"lit": "I find I want to know whose hands",
		"released": "the lantern room's warm",
		"dark": "to see what it weighs",
	}
	for ending in ENDINGS:
		var state := _home(ending)
		var event := _event(state)
		assert_eq(str(event.get("id", "")), "wrackholm_homecoming", ending)
		var said := _lines(state, RegionEvents.fire(event, state))
		assert_true(said.contains("one long note, then two short"), "%s: the horn's signal (canon, Day 13)" % ending)
		assert_true(said.contains("the answering horn on the shingle answers her"), "%s: Wrackholm answers" % ending)
		assert_true(said.contains("A horn answered is a lane promised."), "%s: Wenna at the jetty's foot" % ending)
		assert_true(said.contains(marks[ending]), "%s: %s" % [ending, said])
		for other in ENDINGS:
			if other != ending:
				assert_false(said.contains(marks[other]), "%s: not %s's" % [ending, other])
		assert_true(bool(state.get_flag("wrackholm_homecoming_seen")), ending)
		assert_false(_homecoming_next(state), "%s: once" % ending)


func test_a_horn_never_sounded_is_unlashed_now() -> void:
	var state := _home("lit")
	state.set_flag("wrackholm_horn_sounded", false)
	var said := _lines(state, "wrackholm_homecoming")
	assert_true(said.contains("takes a knife to the lashing"), said)
	assert_true(bool(state.get_flag("wrackholm_horn_sounded")), "the horn's open now (the open model shows)")


func test_the_burning_colours_it() -> void:
	var answer := _lines(_home("lit", "answer", true), "wrackholm_homecoming")
	assert_true(answer.contains("she thinks it's her first"), "answer: Oda keeps it")
	assert_true(answer.contains("beaten copper"), "answer + Jory up: a mouthpiece off the Gannet")
	assert_true(_lines(_home("lit", "answer", false), "wrackholm_homecoming").contains("Nobody's made her a mouthpiece"))
	var board := _lines(_home("released", "board", false), "wrackholm_homecoming")
	assert_true(board.contains("Hale Corbet. Annis Corbet. Ruan Pask."), "board: Oda says the names")
	assert_false(board.contains("she thinks it's her first"))
	var white := _lines(_home("dark", "white"), "wrackholm_homecoming")
	assert_true(white.contains("as far as the eleventh"), "white: Jory's marks")
	assert_false(white.contains("Hale Corbet. Annis"))


func test_it_took_me_first_is_held_for() -> void:
	var state := _home("lit")
	var said := _lines(state, "wrackholm_homecoming", ["It took me first."])
	assert_true(said.contains("a year and a tide for its owner"), said)
	assert_true(bool(state.get_flag("wrackholm_held_for")))
	assert_true(_last_line(state, "Leave it as it is.").contains("Held for. Whatever the Wakebearer was."), "in the Book")
	var other := _home("lit")
	said = _lines(other, "wrackholm_homecoming", ["Steer by it. That's what it's for."])
	assert_true(said.contains("We're good at books."), said)
	assert_false(bool(other.get_flag("wrackholm_held_for")))


func test_the_dark_round_puts_wrackholm_fourth() -> void:
	assert_true(_lines(_home("dark"), "wrackholm_homecoming").contains("That makes us fourth."))
	var first := _home("dark")
	first.set_flag("kindleby_midwinter", "first")
	assert_false(_lines(first, "wrackholm_homecoming").contains("fourth"), "Kindleby asked first: no order told")


func test_the_last_line_per_ending() -> void:
	var marks := {
		"lit": "as if it were somebody else's",
		"released": "Your hand goes along them",
		"dark": "This time you let it.",
	}
	for ending in ENDINGS:
		var before := _home(ending)
		assert_false(_offered(before).has(LAST), "%s: not before the homecoming" % ending)
		var state := _home(ending)
		var said := _last_line(state, "Write under it: Came in.")
		assert_true(said.contains(marks[ending]), "%s: %s" % [ending, said])
		assert_true(said.contains("I can count."), "%s: what was said on the landing" % ending)
		assert_true(said.contains("Nobody came in that night."), ending)
		assert_true(said.contains("only the one place a Keeper ever gave their name"), "%s: Wenna's guess" % ending)
		assert_true(said.contains("not one ever came back to close their own"), "%s: a fare closed" % ending)
		assert_eq(str(state.get_flag("wrackholm_last_line")), "came_in", ending)
		assert_false(_offered(state).has(LAST), "%s: once" % ending)
		assert_true(_lines(state, "wenna", [BYE]).contains("Came in. I read it of a morning"), "%s: after" % ending)
	var left := _home("released")
	assert_true(_last_line(left, "Leave it as it is.").contains("Paid's paid."))
	assert_eq(str(left.get_flag("wrackholm_last_line")), "left")
	assert_false(_lines(left, "wenna", [BYE]).contains("Came in. I read it"))


func test_the_last_line_never_says_the_name() -> void:
	# Canon rule (Day 92): the Wakebearer's name is never written on screen.
	var said := _last_line(_home("dark"), "Write under it: Came in.")
	assert_false(said.contains("{name}"))
	assert_true(said.contains("It's yours."))


func test_the_book_unopened_is_found_now() -> void:
	var state := _home("lit")
	state.set_flag("wrackholm_book_opened", false)
	state.set_flag("wrackholm_homecoming_seen", true)
	var offered := _offered(state)
	assert_false(offered.has("Show me the Book."), "the epilogue's line replaces the old ask")
	assert_true(offered.has(LAST))
	assert_true(_last_line(state, "Leave it as it is.").contains("as thick as a man's arm is long"))
	assert_true(bool(state.get_flag("wrackholm_book_opened")))


func test_after_lines() -> void:
	var wenna := {"lit": "That's how you know a light's home.", "released": "nor the white", "dark": "a knife in the pan"}
	var jory := {"lit": "Every rock of it.", "released": "best company on the island", "dark": "pry bar in the pan"}
	for ending in ENDINGS:
		var state := _home(ending)
		assert_false(_lines(state, "wenna", [BYE]).contains(wenna[ending]), "%s: not before the homecoming" % ending)
		state.set_flag("wrackholm_homecoming_seen", true)
		assert_true(_lines(state, "wenna", [BYE]).contains(wenna[ending]), "wenna / %s" % ending)
		assert_true(_lines(state, "jory", [BYE]).contains(jory[ending]), "jory / %s" % ending)
	var board := _home("dark", "board")
	board.set_flag("wrackholm_homecoming_seen", true)
	assert_true(_lines(board, "jory", [BYE]).contains("my brother's pry bar"), "board: no name for him")


func test_wrackholm_goes_gold_when_lit() -> void:
	var region: Dictionary = _content().regions["wrackholm"]
	for ending in ENDINGS:
		var state := _home(ending)
		var light := RegionMood.light(region, state)
		assert_true((str(light.get("sky_horizon", "")) == "#D9BE96") == (ending == "lit"), ending)
	var far: Array = (region["props"] as Array).filter(
			func(p: Dictionary) -> bool: return str(p.get("model", "")).ends_with("hearthspire_far_lit.glb"))
	assert_eq(far.size(), 1)
	assert_eq(str((far[0] as Dictionary)["if"]), "flag:cindermoor_cradle_choice=lit")
	var at: Array = (far[0] as Dictionary)["position"]
	assert_true(float(at[0]) < -100.0 and float(at[2]) > 100.0, "south-west: Cindermoor on the chart")


func test_the_checkpoint() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_wrack_answers"))
	assert_eq(str(state.get_flag("cindermoor_cradle_choice")), "lit")
	assert_eq(str(state.get_flag("lanes_ferry_at")), "wrackholm")
	assert_false(_homecoming_next(state), "the homecoming's been seen")
	assert_true(_lines(state, "wenna", [BYE]).contains("Came in. I read it of a morning"))
