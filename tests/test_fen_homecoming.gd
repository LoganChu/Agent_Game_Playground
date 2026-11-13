extends TestCase
## Day 101 — the epilogues, part four: Glasswater Fen. After the lane out the Mercy puts in at Stillhithe's staithe
## (arrival event `fen_homecoming`): Hesper meets it with a lantern on a pole and tells what the ending made of the fen,
## coloured by the Heron's burning (name / channels) and the ember she asked to be cupped. Dunstan, if he stayed, waves
## a board at the Mercy. Lit, the fen goes gold with the far Spire in the south. Hesper, Corran and Dunstan have
## after-lines per ending.

const ENDINGS: Array[String] = ["lit", "released", "dark"]
const BYE := "Goodbye."

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed)


## Rung home on Kindleby after `ending`, then sailed round to the fen (the Mercy at the staithe).
func _home(ending: String, burned := "name") -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_homecoming"))
	state.set_flag("cindermoor_cradle_choice", ending)
	state.set_flag("kindleby_midwinter", "ring" if ending == "dark" else "")
	state.set_flag("fen_beacon_burned", burned)
	state.set_flag("lanes_ferry_at", "fen")
	return state


func _event(state: WorldState) -> Dictionary:
	return RegionEvents.arrival(_content().regions["glasswater_fen"], state)


## True when the next arrival on the fen would be the homecoming (other fen events, such as Dunstan's walk back if it
## never happened, may still come after it).
func _homecoming_next(state: WorldState) -> bool:
	return str(_event(state).get("id", "")) == "fen_homecoming"


func test_no_homecoming_before_the_lane_out() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_spire_lit"))
	state.set_flag("lanes_ferry_at", "fen")
	assert_false(_homecoming_next(state), "the Long Book's not shut yet")
	var home := _home("lit")
	home.set_flag("lanes_ferry_at", "wrackholm")
	assert_false(_homecoming_next(home), "only when the Mercy's put in here")


func test_the_homecoming_per_ending() -> void:
	var marks := {
		"lit": "a shallower place to put them",
		"released": "a second light on the Heron",
		"dark": "now there's to be a list",
	}
	for ending in ENDINGS:
		var state := _home(ending)
		var event := _event(state)
		assert_eq(str(event.get("id", "")), "fen_homecoming", ending)
		var said := _lines(state, RegionEvents.fire(event, state))
		assert_true(said.contains("one long note, then two short"), "%s: the horn's signal (canon, Day 13)" % ending)
		assert_true(said.contains("a lantern on a pole"), "%s: Hesper meets the boat" % ending)
		assert_true(said.contains(marks[ending]), "%s: %s" % [ending, said])
		for other in ENDINGS:
			if other != ending:
				assert_false(said.contains(marks[other]), "%s: not %s's" % [ending, other])
		assert_true(bool(state.get_flag("fen_homecoming_seen")), ending)
		assert_false(_homecoming_next(state), "%s: once" % ending)


func test_the_burning_colours_it() -> void:
	for ending in ENDINGS:
		var named := _lines(_home(ending, "name"), "fen_homecoming")
		assert_true(named.contains("looks over her shoulder"), "%s / name: Hesper's name's gone — %s" % [ending, named])
		var channels := _lines(_home(ending, "channels"), "fen_homecoming")
		assert_false(channels.contains("looks over her shoulder"), "%s / channels: Hesper kept her name" % ending)
	assert_true(_lines(_home("lit", "channels"), "fen_homecoming").contains("which one goes"), "lit: the eel-man's channels")
	assert_true(_lines(_home("dark", "name"), "fen_homecoming").contains("I can't sign it."), "dark: no name to sign with")
	assert_true(_lines(_home("dark", "channels"), "fen_homecoming").contains("he's cross about it"), "dark: Corran")


func test_it_took_me_first_gives_a_tussock() -> void:
	var state := _home("lit")
	var said := _lines(state, "fen_homecoming", ["It took me first."])
	assert_true(said.contains("Only nobody let you choose."), said)
	assert_true(bool(state.get_flag("fen_hesper_tussock")))
	state.set_flag("fen_homecoming_seen", true)  # the event's own `set`
	assert_true(_lines(state, "hesper", [BYE]).contains("Your tussock's still there"), "her after-line")
	var other := _home("lit")
	said = _lines(other, "fen_homecoming", ["They'll come back to it, in time."])
	assert_true(said.contains("your light didn't burn it"), said)
	assert_false(bool(other.get_flag("fen_hesper_tussock")))


func test_released_rings_the_keeper_bell() -> void:
	var hung := _home("released")
	hung.set_flag("fen_skiff_bell", "hung")
	assert_true(_lines(hung, "fen_homecoming").contains("the bell on her skiff rang"), "the bell on her bow")
	var kept := _home("released")
	kept.set_flag("fen_skiff_bell", "kept")
	kept.add_item("heron_skiff_bell")
	var said := _lines(kept, "fen_homecoming")
	assert_true(said.contains("In your satchel the keeper's skiff bell"), said)
	assert_false(said.contains("the bell on her skiff rang"), "not on her bow")
	for cupped: String in ["cupped", "bare"]:
		var state := _home("released")
		state.set_flag("fen_ember", cupped)
		var mark := "nothing in it now to mind" if cupped == "cupped" else "nothing in it now to cup"
		assert_true(_lines(state, "fen_homecoming").contains(mark), cupped)


func test_the_dark_round_puts_the_fen_third() -> void:
	assert_true(_lines(_home("dark"), "fen_homecoming").contains("That makes us third."))
	var first := _home("dark")
	first.set_flag("kindleby_midwinter", "first")
	assert_false(_lines(first, "fen_homecoming").contains("third"), "Kindleby asked first: no order told")


func test_dunstan_per_walk() -> void:
	var stayed := _home("lit")
	stayed.set_flag("fen_dunstan_walk", "stayed")
	assert_true(_lines(stayed, "fen_homecoming").contains("lifts the board at her like a hat"), "he waves at the Mercy")
	var home := _home("lit")
	home.set_flag("fen_dunstan_walk", "home")
	var said := _lines(home, "fen_homecoming")
	assert_true(said.contains("boat's still gone off my first post"), said)
	assert_false(said.contains("like a hat"))
	var out := _home("lit")  # the checkpoint chain leaves him at the end of the long walk
	assert_true(_lines(out, "fen_homecoming").contains("lantern is still lit on the boards"), "still out there")
	assert_false(_lines(home, "fen_homecoming").contains("lantern is still lit"), "not once he's home")


func test_after_lines() -> void:
	var hesper := {"lit": "Nobody's counting.", "released": "I didn't watch. I listened.", "dark": "like it's a tree"}
	var corran := {"lit": "Fog's off the water.", "released": "Same pace.", "dark": "I'm on Hesper's list."}
	var dunstan := {"lit": "Bright enough to turn boards by", "released": "The boards were wet", "dark": "Not the name"}
	for ending in ENDINGS:
		var state := _home(ending)
		state.set_flag("fen_dunstan_walk", "stayed")
		assert_false(_lines(state, "hesper", [BYE]).contains(hesper[ending]), "%s: not before the homecoming" % ending)
		state.set_flag("fen_homecoming_seen", true)
		assert_true(_lines(state, "hesper", [BYE]).contains(hesper[ending]), "hesper / %s" % ending)
		assert_true(_lines(state, "corran", [BYE]).contains(corran[ending]), "corran / %s" % ending)
		assert_true(_lines(state, "dunstan", ["I'll leave you to it."]).contains(dunstan[ending]), "dunstan / %s" % ending)
	var channels := _home("lit", "channels")
	channels.set_flag("fen_homecoming_seen", true)
	assert_true(_lines(channels, "corran", [BYE]).contains("which one goes"), "lit / channels: Corran's own line")


func test_the_fen_goes_gold_when_lit() -> void:
	var region: Dictionary = _content().regions["glasswater_fen"]
	for ending in ENDINGS:
		var state := _home(ending)
		state.set_flag("fen_homecoming_seen", true)
		var light := RegionMood.light(region, state)
		assert_true((str(light.get("sky_horizon", "")) == "#DCC29A") == (ending == "lit"), ending)
	var far: Array = (region["props"] as Array).filter(
			func(p: Dictionary) -> bool: return str(p.get("model", "")).ends_with("hearthspire_far_lit.glb"))
	assert_eq(far.size(), 1)
	assert_eq(str((far[0] as Dictionary)["if"]), "flag:cindermoor_cradle_choice=lit")
	assert_true(float(((far[0] as Dictionary)["position"] as Array)[2]) > 100.0, "south of the fen: Cindermoor on the chart")


func test_the_checkpoint() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_staithe_lantern"))
	assert_eq(str(state.get_flag("cindermoor_cradle_choice")), "lit")
	assert_eq(str(state.get_flag("lanes_ferry_at")), "fen")
	assert_false(_homecoming_next(state), "the homecoming's been seen")
	assert_true(_lines(state, "hesper", [BYE]).contains("Your tussock's still there"))
