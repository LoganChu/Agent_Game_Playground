extends TestCase
## Day 124 — the tally stick. Brenner (Day 122) kept the tally of Dunstan's springtime dare to the Low Water's edge, one
## notch per spring the boat came back inside the outer post. After the burn he gives the stick to the player to carry
## (`saltmarrow_brenner_tally_given`, item `brenners_tally`); Dunstan takes it on the fen, at home or turning the boards
## (`fen_dunstan_tally`); walked home, Brenner cuts the twenty-third (`saltmarrow_brenner_tally_home`). Mara is told
## where the dare went (`saltmarrow_mara_dare`): she knew; after the gull burn, the boat she remembers is in the right water.

const BURNS: Array[String] = ["pebble", "knot", "gull"]
const CHOIR := "What's out past the cod grounds?"
const CARRY := "Could I carry that tally stick to Dunstan? In case I find him."
const CARRY_GULL := "Could I carry that stick? In case I find who it was for."
const GIVE := "Brenner kept this for you. Your tally."
const MARA := "Brenner kept a tally of Dunstan's dare. To the Low Water's edge."
const MARA_GULL := "Brenner says the dare went to the Low Water's edge. Not the bank."
const ITEM := "brenners_tally"

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


## After the burn, the dare told, the stick in hand.
func _carrying(burned: String) -> WorldState:
	var state := _after(burned)
	_lines(state, "brenner", [CHOIR])
	_lines(state, "brenner", [CARRY_GULL if burned == "gull" else CARRY])
	return state


func test_brenner_gives_the_stick() -> void:
	for burned: String in BURNS:
		var state := _after(burned)
		var pick := CARRY_GULL if burned == "gull" else CARRY
		var other := CARRY if burned == "gull" else CARRY_GULL
		var before: Array[String] = []
		_lines(state, "brenner", [], before)
		assert_false(pick in before, "%s: not till he's told the dare" % burned)
		var offered: Array[String] = []
		_lines(state, "brenner", [CHOIR], offered)
		var asked: Array[String] = []
		var said := _lines(state, "brenner", [pick], asked)
		assert_true(pick in asked, burned)
		assert_false(other in asked, "%s: one wording per burn" % burned)
		assert_true(said.contains("You don't count a man till he's home"), said)
		assert_eq(said.contains("The twenty-third's his to bring me"), burned != "gull", burned)
		assert_eq(said.contains("counting for nobody"), burned == "gull", burned)
		assert_true((state.item_count(ITEM) > 0), burned)
		assert_true(bool(state.get_flag("saltmarrow_brenner_tally_given")))
		var again: Array[String] = []
		_lines(state, "brenner", [], again)
		assert_false(pick in again, "%s: given once" % burned)
	# Not before the burn: the dare's told, but there's no ferry to carry it on.
	var early := _at("saltmarrow")
	var early_offered: Array[String] = []
	_lines(early, "brenner", [CHOIR])
	_lines(early, "brenner", [], early_offered)
	assert_false(CARRY in early_offered)
	assert_true(_content().items.has(ITEM))


func test_dunstan_counts_it_on_the_fen() -> void:
	var state := _at("the_tally_stick")
	assert_true((state.item_count(ITEM) > 0))
	state.set_flag("fen_dunstan_met", true)
	var offered: Array[String] = []
	var said := _lines(state, "dunstan", [GIVE], offered)
	assert_true(GIVE in offered)
	assert_true(said.contains("Twenty-two. Old Brenner."), said)
	assert_true(said.contains("It was always the turning round"), said)
	assert_true(said.contains("This time I went in"), said)
	assert_false((state.item_count(ITEM) > 0))
	assert_true(bool(state.get_flag("fen_dunstan_tally")))
	var again: Array[String] = []
	_lines(state, "dunstan", [], again)
	assert_false(GIVE in again, "given once")
	var gull := _at("the_tally_stick")
	gull.set_flag("saltmarrow_beacon_burned", "gull")
	gull.set_flag("fen_dunstan_met", true)
	var gull_said := _lines(gull, "dunstan", [GIVE])
	assert_true(gull_said.contains("the only one left who knows you turned round"), gull_said)
	assert_false(gull_said.contains("Mara thought"), gull_said)
	var without := _at("dunstan_found")
	without.set_flag("fen_dunstan_met", true)
	var none: Array[String] = []
	_lines(without, "dunstan", [], none)
	assert_false(GIVE in none, "only with the stick")


func test_home_and_stayed() -> void:
	for burned: String in BURNS:
		# Carried home in the player's pocket: Dunstan on his stool takes it; Brenner cuts the twenty-third.
		var state := _carrying(burned)
		state.set_flag("fen_dunstan_walk", "home")
		var reminder := _lines(state, "brenner")
		assert_true(reminder.contains("still my stick" if burned != "gull" else "I'd given it you"), reminder)
		var said := _lines(state, "dunstan", [GIVE])
		assert_true(said.contains("cut the twenty-third himself"), said)
		var brenner := _lines(state, "brenner")
		assert_true(brenner.contains("twenty-third"), brenner)
		assert_true(brenner.contains("Keep counting"), brenner)
		assert_eq(brenner.contains("my hands were shaking"), burned == "gull", burned)
		assert_true(bool(state.get_flag("saltmarrow_brenner_tally_home")))
		assert_false(_lines(state, "brenner").contains("twenty-third"), "%s: told once" % burned)
		var dunstan := _lines(state, "dunstan")
		assert_true(dunstan.contains("He cut the notch anyway" if burned == "gull" else "He will, too"), dunstan)
		# The told-already dare line no longer says Brenner handed it over himself.
		var choir := _carrying(burned)
		choir.set_flag("fen_dunstan_walk", "home")
		assert_false(_lines(choir, "brenner").contains("I gave him the stick"), burned)
	# After the homecoming, Brenner tells it the first time he's spoken to.
	var home := _carrying("knot")
	home.set_flag("fen_dunstan_walk", "home")
	_lines(home, "dunstan", [GIVE])
	home.set_flag("saltmarrow_homecoming_seen", true)
	home.set_flag("cindermoor_cradle_choice", "released")
	var told := _lines(home, "brenner")
	assert_true(told.contains("Took me four goes"), told)
	assert_true(told.contains("Sat just where the Gull put it"), told)
	# Stayed: a notch for every board.
	var stayed := _carrying("pebble")
	stayed.set_flag("fen_dunstan_walk", "stayed")
	var notched := _lines(stayed, "dunstan", [GIVE])
	assert_true(notched.contains("one for every board I turn"), notched)
	assert_true(_lines(stayed, "dunstan").contains("one for each board"))


func test_mara_told_where_the_dare_went() -> void:
	var before: Array[String] = []
	_lines(_after("knot"), "mara", [], before)
	assert_false(MARA in before, "not till Brenner's told it")
	for burned: String in BURNS:
		var state := _after(burned)
		_lines(state, "brenner", [CHOIR])
		var offered: Array[String] = []
		var pick := MARA_GULL if burned == "gull" else MARA
		var said := _lines(state, "mara", [pick], offered)
		assert_true(pick in offered, burned)
		assert_false((MARA if burned == "gull" else MARA_GULL) in offered, burned)
		assert_true(bool(state.get_flag("saltmarrow_mara_dare")))
		if burned == "gull":
			assert_true(said.contains("They always turned round"), said)
			assert_true(said.contains("Brenner showed me his stick"), said)
			assert_false(said.contains("Dunstan"), "the gull burn: no name in her mouth")
		else:
			assert_true(said.contains("I knew."), said)
			assert_false(said.contains("in your pocket"), said)
		var again: Array[String] = []
		_lines(state, "mara", [], again)
		assert_false(pick in again, "%s: once" % burned)
	var pocket := _carrying("pebble")
	assert_true(_lines(pocket, "mara", [MARA]).contains("in your pocket"))
	var gull_pocket := _carrying("gull")
	var gull_said := _lines(gull_pocket, "mara", [MARA_GULL])
	assert_true(gull_said.contains("you've his stick now"), gull_said)
	assert_false(gull_said.contains("Brenner showed me"), gull_said)


func test_checkpoint() -> void:
	var state := _at("the_tally_stick")
	assert_true((state.item_count(ITEM) > 0))
	assert_true(bool(state.get_flag("saltmarrow_brenner_tally_given")))
	assert_true(bool(state.get_flag("saltmarrow_mara_message_for_dunstan")))
	var offered: Array[String] = []
	var said := _lines(state, "dunstan", [GIVE], offered)
	assert_true(said.contains("Dunstan Tollen, of Saltmarrow"), "the first meeting runs first: %s" % said)
	assert_true(GIVE in offered, "then the stick: %s" % [offered])
