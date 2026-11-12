extends TestCase
## Day 99 — the epilogues, part three: Thornwold. After the lane out the Mercy puts in at the lumber camp (arrival event
## `thornwold_homecoming`): Bram sees what the ending made of the night, coloured by the Ridge Light's burning; Pell, if
## landed, per ending. If Aldous kept the door-warden's answer (`saltmarrow_aldous_crossing=now`) and knows Wynn lives, he
## comes ashore and goes up the ridge, and on the ridge (`thornwold_two_keepers`) says his sorry in person: "a door-warden
## isn't the door", the day the lanes run with nobody counting. Lit, the cove and the ridge go gold with the far Spire.

const ENDINGS: Array[String] = ["lit", "released", "dark"]
const BYE := "Goodbye."

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


## Rung home on Kindleby after `ending`, then sailed round to Thornwold (the Mercy at its jetty).
func _home(ending: String, burned := "salt_row") -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_homecoming"))
	state.set_flag("cindermoor_cradle_choice", ending)
	state.set_flag("kindleby_midwinter", "ring" if ending == "dark" else "")
	state.set_flag("thornwold_beacon_burned", burned)
	state.set_flag("lanes_ferry_at", "thornwold")
	state.set_flag("thornwold_lamp_saw_light", true)  # the Lamp's one-time "it's burning" said long since
	return state


## As `_home`, with Aldous crossing (lit/released: he wrote to the Provost, and was told on the east stair).
func _crossing(ending: String) -> WorldState:
	var state := _home(ending)
	state.set_flag("saltmarrow_aldous_boat", "letter")
	state.set_flag("saltmarrow_aldous_crossing", "now")
	state.set_flag("saltmarrow_aldous_novice", "lamp")
	return state


func _event(state: WorldState, region := "thornwold_landing") -> Dictionary:
	return RegionEvents.arrival(_content().regions[region], state)


func _placed(state: WorldState, npc: String) -> Array[String]:
	var where: Array[String] = []
	for region_id: String in _content().regions:
		for placement: Dictionary in _content().regions[region_id].get("npcs", []):
			if str(placement["npc"]) == npc and Conditions.evaluate(placement.get("if", []), state):
				where.append(region_id)
	return where


func test_no_homecoming_before_the_lane_out() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_spire_lit"))
	state.set_flag("lanes_ferry_at", "thornwold")
	assert_true(_event(state).is_empty(), "the Long Book's not shut yet")
	var home := _home("lit")
	home.set_flag("lanes_ferry_at", "saltmarrow")
	assert_true(_event(home).is_empty(), "only when the Mercy's put in here")


func test_the_homecoming_per_ending() -> void:
	var marks := {
		"lit": "You don't count a thing that stays.",
		"released": "the other end of the bench warm",
		"dark": "WINTER",
	}
	for ending in ENDINGS:
		var state := _home(ending)
		var event := _event(state)
		assert_eq(str(event.get("id", "")), "thornwold_homecoming", ending)
		var said := _lines(state, RegionEvents.fire(event, state))
		assert_true(said.contains("one long note, then two short"), "%s: the horn's signal (canon, Day 13)" % ending)
		assert_true(said.contains(marks[ending]), "%s: %s" % [ending, said])
		for other in ENDINGS:
			if other != ending:
				assert_false(said.contains(marks[other]), "%s: not %s's" % [ending, other])
		assert_true(bool(state.get_flag("thornwold_homecoming_seen")), ending)
		assert_false(bool(state.get_flag("thornwold_aldous_landed")), "%s: no Aldous unless he's crossing" % ending)
		assert_true(_event(state).is_empty(), "%s: once" % ending)


func test_the_burning_colours_it() -> void:
	for ending in ENDINGS:
		var row := _lines(_home(ending, "salt_row"), "thornwold_homecoming")
		assert_true(row.contains("pegs"), "%s / salt_row: the bare pegs — %s" % [ending, row])
		var boots := _home(ending, "boots")
		boots.set_flag("thornwold_hob_ladder", "")
		var said := _lines(boots, "thornwold_homecoming")
		assert_false(said.contains("pegs"), "%s / boots: the salt row's still on the board" % ending)
		assert_true(said.contains("Hob"), "%s / boots: Hob on the step — %s" % [ending, said])


func test_it_took_me_first_cuts_a_row() -> void:
	var state := _home("lit")
	var said := _lines(state, "thornwold_homecoming", ["It took me first."])
	assert_true(said.contains("a place on the board that's yours"), said)
	assert_true(bool(state.get_flag("thornwold_bram_cut_row")))
	state.set_flag("thornwold_homecoming_seen", true)  # the event's own `set`
	var after := _lines(state, "bram", [BYE])
	assert_true(after.contains("Your row's on the board"), after)
	var counting := _home("lit")
	said = _lines(counting, "thornwold_homecoming", ["Nobody's counting, then."])
	assert_true(said.contains("By name, and asked first."), said)
	assert_false(bool(counting.get_flag("thornwold_bram_cut_row")))


func test_the_dark_round_puts_thornwold_second() -> void:
	var ring := _lines(_home("dark"), "thornwold_homecoming")
	assert_true(ring.contains("That puts us second."), ring)
	var first := _home("dark")
	first.set_flag("kindleby_midwinter", "first")
	assert_false(_lines(first, "thornwold_homecoming").contains("second"), "Kindleby asked first: no order told")


func test_pell_per_ending() -> void:
	var marks := {"lit": "I keep those.", "released": "Finders keep FOR.", "dark": "I put myself on."}
	for ending in ENDINGS:
		var said := _lines(_home(ending), "thornwold_homecoming")
		assert_true(said.contains(marks[ending]), "%s: %s" % [ending, said])
		var away := _home(ending)
		away.set_flag("thornwold_pell_landed", false)
		assert_false(_lines(away, "thornwold_homecoming").contains(marks[ending]), "%s: Pell didn't cross" % ending)
	var dunstan := _home("lit")
	dunstan.set_flag("fen_dunstan_walk", "home")
	assert_true(_lines(dunstan, "thornwold_homecoming").contains("Dunstan's home!"), "the Act II follow-up")


func test_aldous_comes_ashore_and_leaves_his_bench() -> void:
	for ending: String in ["lit", "released"]:
		var state := _crossing(ending)
		assert_eq(_placed(state, "aldous"), ["saltmarrow"] as Array[String], "%s: on his bench till he lands" % ending)
		var said := _lines(state, RegionEvents.fire(_event(state), state))
		assert_true(said.contains("Brother Aldous") and said.contains("Is there a ladder"), "%s: %s" % [ending, said])
		assert_true(bool(state.get_flag("thornwold_aldous_landed")), ending)
		assert_eq(_placed(state, "aldous"), ["thornwold_ridge"] as Array[String], "%s: on the ridge" % ending)
		assert_true(_lines(state, "bram", [BYE]).contains("I held the foot."), ending)
	# He doesn't know Wynn lives: no Thornwold first.
	var unknowing := _crossing("lit")
	unknowing.set_flag("saltmarrow_aldous_novice", "")
	_lines(unknowing, "thornwold_homecoming")
	assert_false(bool(unknowing.get_flag("thornwold_aldous_landed")), "he never heard Wynn lives")


func test_aldous_crossing_after_the_homecoming() -> void:
	var state := _home("released")
	_lines(state, RegionEvents.fire(_event(state), state))
	assert_true(_event(state).is_empty(), "nothing left on this arrival")
	state.set_flag("saltmarrow_aldous_boat", "letter")
	state.set_flag("saltmarrow_aldous_crossing", "now")
	state.set_flag("saltmarrow_aldous_novice", "self")
	var event := _event(state)
	assert_eq(str(event.get("id", "")), "thornwold_aldous_ashore")
	var said := _lines(state, RegionEvents.fire(event, state))
	assert_true(said.contains("Door-warden. Was."), said)
	assert_true(_event(state).is_empty(), "once")


func test_aldous_says_thornwold_first_at_saltmarrow() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_homecoming"))
	state.set_flag("lanes_ferry_at", "saltmarrow")
	state.set_flag("saltmarrow_aldous_boat", "letter")
	var said := _lines(state, "aldous", ["The Long Book's shut, Brother.", "Say nothing of the High Keeper.",
			"Let the stair be.", "Rest easy, Brother."])
	assert_eq(str(state.get_flag("saltmarrow_aldous_crossing")), "now")
	assert_true(said.contains("Thornwold first"), said)


func test_the_two_keepers() -> void:
	var marks := {"lit": "Bram Kettle's stopped notching it.", "released": "They came out. It's not the same."}
	for ending: String in marks:
		var state := _crossing(ending)
		assert_true(_event(state, "thornwold_ridge").is_empty(), "%s: not before he's landed" % ending)
		state.set_flag("thornwold_aldous_landed", true)
		var event := _event(state, "thornwold_ridge")
		assert_eq(str(event.get("id", "")), "thornwold_two_keepers", ending)
		var said := _lines(state, RegionEvents.fire(event, state))
		assert_true(said.contains("I'm sorry. For all of it."), ending)
		assert_true(said.contains("A door-warden isn't the door."), "%s: the Day 47 promise kept" % ending)
		assert_true(said.contains("nobody counting"), ending)
		assert_true(said.contains(marks[ending]), "%s: %s" % [ending, said])
		assert_true(said.contains("It's a long bench."), ending)
		assert_true(bool(state.get_flag("thornwold_aldous_met_wynn")), ending)
		assert_true(bool(state.get_flag("thornwold_last_coal_out")), "%s: the last coal let go out" % ending)
		assert_true(_event(state, "thornwold_ridge").is_empty(), "%s: once" % ending)
		assert_true(_lines(state, "lamp", [BYE]).contains("who snores"), ending)
		assert_true(_lines(state, "aldous").contains("Kindleby when Oda's going"), "%s: the next leg" % ending)


func test_the_name_is_kept_as_it_was_left() -> void:
	var told := _crossing("lit")
	told.set_flag("thornwold_aldous_landed", true)
	var said := _lines(told, "thornwold_two_keepers")
	assert_true(said.contains("Wynn.\nAldous Wren. You've got old."), said)
	for left: String in ["left", ""]:
		var state := _crossing("lit")
		state.set_flag("thornwold_lamp_name", left)
		state.set_flag("thornwold_aldous_landed", true)
		said = _lines(state, "thornwold_two_keepers")
		assert_false(said.contains("You've got old."), "%s: the name isn't said" % left)
		assert_true(said.contains("Lamp, then."), "%s: %s" % [left, said])
		assert_eq(str(state.get_flag("thornwold_lamp_name")), left, "the name stays where it was put")


func test_the_seventh_novice_thanked() -> void:
	var state := _crossing("released")
	state.set_flag("thornwold_aldous_landed", true)
	state.set_flag("saltmarrow_aldous_knows_novice", true)
	var said := _lines(state, "thornwold_two_keepers")
	assert_true(said.contains("Keep one back this year, Keeper Sallow.") and said.contains("Thank you."), said)
	var unnamed := _crossing("released")
	unnamed.set_flag("thornwold_lamp_name", "left")
	unnamed.set_flag("thornwold_aldous_landed", true)
	unnamed.set_flag("saltmarrow_aldous_knows_novice", true)
	said = _lines(unnamed, "thornwold_two_keepers")
	assert_false(said.contains("Keeper Sallow"), "the novice's line came back with the name")
	var not_told := _crossing("released")
	not_told.set_flag("thornwold_aldous_landed", true)
	assert_false(_lines(not_told, "thornwold_two_keepers").contains("Keep one back"), "only once Aldous knows")


func test_after_lines() -> void:
	var bram := {"lit": "Still there of an evening", "released": "a second cup up the ladder", "dark": "Two sticks on the WINTER row"}
	var lamp := {"lit": "I can see it from the bench.", "released": "far end of the bench of a night", "dark": "Midwinter, then."}
	for ending in ENDINGS:
		var state := _home(ending)
		assert_false(_lines(state, "bram", [BYE]).contains(bram[ending]), "%s: not before the homecoming" % ending)
		state.set_flag("thornwold_homecoming_seen", true)
		assert_true(_lines(state, "bram", [BYE]).contains(bram[ending]), ending)
		assert_true(_lines(state, "lamp", [BYE]).contains(lamp[ending]), ending)
	var midwinter := _home("dark")
	midwinter.set_flag("thornwold_homecoming_seen", true)
	midwinter.set_flag("saltmarrow_aldous_crossing", "midwinter")
	assert_true(_lines(midwinter, "lamp", [BYE]).contains("I'll have the bench swept."), "the Wren comes at midwinter")


func test_thornwold_goes_gold_when_lit() -> void:
	for region_id: String in ["thornwold_landing", "thornwold_ridge"]:
		var region: Dictionary = _content().regions[region_id]
		for ending: String in ["lit", "released", "dark"]:
			var light := RegionMood.light(region, _home(ending))
			assert_true((str(light.get("sky_horizon", "")) == "#DCC29A") == (ending == "lit"), "%s / %s" % [region_id, ending])
		var far: Array = (region["props"] as Array).filter(
				func(p: Dictionary) -> bool: return str(p.get("model", "")).ends_with("hearthspire_far_lit.glb"))
		assert_eq(far.size(), 1, region_id)
		assert_eq(str((far[0] as Dictionary)["if"]), "flag:cindermoor_cradle_choice=lit", region_id)


func test_the_checkpoint() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_two_keepers"))
	assert_eq(str(state.get_flag("cindermoor_cradle_choice")), "lit")
	assert_eq(_placed(state, "aldous"), ["thornwold_ridge"] as Array[String])
	assert_true(_event(state, "thornwold_ridge").is_empty(), "the meeting's been seen")
	assert_true(_event(state).is_empty(), "the homecoming's been seen")
