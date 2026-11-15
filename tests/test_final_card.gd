extends TestCase
## Day 105 — the final card. After the lane out, at any port, "That's the ring. Tie her up for the winter." With every
## homecoming seen Oda goes straight on; otherwise she names the islands not yet visited and lets the Wakebearer tie up
## anyway. She asks what they'll do with the winter (stay / crew / walk) and puts the Mercy to bed
## (`epilogue_tied_up`), which ends the story with the `epilogue` card: the ending, one or two lines per island seen
## (coloured by its homecoming's flags), a line for each island missed, the winter, a coda per ending, and "The End".

const TIE := "That's the ring. Tie her up for the winter."
const ANYWAY := "Tie her up anyway."
const NOT_YET := "Not yet, then."
const STAY := "Stay here."
const CREW := "Crew the Mercy, if you'll have me."
const WALK := "Walk the islands. Nobody's counting now."
const BYE := "Not yet."
const ISLANDS: Array[String] = ["saltmarrow", "thornwold", "fen", "wrackholm", "kindleby", "lowsong"]

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, picks: Array = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, "oda", typed)


func _offered(state: WorldState) -> Array[String]:
	var offered: Array[String] = []
	var picks: Array[String] = [BYE]
	play_dialogue(_content(), state, "oda", picks, offered)
	return offered


## Every homecoming seen (the Day 103 checkpoint: lit, Lowsong key, the Mercy at Kindleby), re-coloured by `ending`.
func _all_seen(ending := "lit", port := "kindleby") -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_quiet_water"))
	state.set_flag("cindermoor_cradle_choice", ending)
	state.set_flag("lanes_ferry_at", port)
	return state


func _card() -> Dictionary:
	for act in ActRecap.acts(_content()):
		if str(act["id"]) == "epilogue":
			return act
	return {}


func _card_text(state: WorldState) -> String:
	return "\n".join(ActRecap.card_lines(_content(), _card(), state))


func test_offered_at_every_port_after_the_lane_out_only() -> void:
	var before := fresh_state(_content())
	Scenarios.apply(_content(), before, Scenarios.resolve("the_spire_lit"))
	before.set_flag("lanes_ferry_at", "kindleby")
	assert_false(_offered(before).has(TIE), "not before the lane out")
	for port: String in ["kindleby", "saltmarrow", "thornwold", "fen", "wrackholm"]:
		var state := _all_seen("lit", port)
		assert_true(_offered(state).has(TIE), "offered at " + port)
	var done := _all_seen()
	_lines(done, [TIE, CREW])
	assert_false(_offered(done).has(TIE), "only once")
	assert_true(_offered(done).has("Where can you take me?"), "Oda still ferries after")


func test_all_seen_goes_straight_on() -> void:
	var state := _all_seen()
	var said := _lines(state, [TIE, STAY])
	assert_false(said.contains("You've not been home"), said)
	assert_true(said.contains("What'll you do with the winter?"), said)
	assert_true(bool(state.get_flag("epilogue_tied_up")))
	assert_eq(state.get_flag("epilogue_winter"), "stay")


func test_unseen_islands_named_and_optional() -> void:
	var state := _all_seen()
	state.set_flag("thornwold_homecoming_seen", false)
	state.set_flag("lowsong_homecoming_seen", false)
	var said := _lines(state, [TIE, NOT_YET])
	assert_true(said.contains("Nor Thornwold."), said)
	assert_true(said.contains("nobody's rowed you out to Lowsong"), said)
	assert_false(said.contains("Saltmarrow, mind"), "Saltmarrow was seen")
	assert_false(bool(state.get_flag("epilogue_tied_up")), "not yet keeps the story open")
	_lines(state, [TIE, ANYWAY, WALK])
	assert_true(bool(state.get_flag("epilogue_tied_up")), "tied up anyway")
	var card := _card_text(state)
	assert_true(card.contains("The Mercy never put in at Thornwold after."), card)
	assert_true(card.contains("Nobody rowed you out to Lowsong after."), card)
	assert_false(card.contains("Thornwold: "), "no Thornwold epilogue line when it wasn't seen")
	assert_false(card.contains("never put in at Saltmarrow"), card)


func test_oda_per_ending() -> void:
	var expect := {
		"lit": "a gold one in the middle",
		"released": "somebody sitting up with every one",
		"dark": "carrying you round the ring with that coal",
	}
	for ending: String in expect:
		var said := _lines(_all_seen(ending), [TIE, CREW])
		assert_true(said.contains(expect[ending]), ending + ": " + said)
		for other: String in expect:
			if other != ending:
				assert_false(said.contains(expect[other]), ending + " shows " + other)


func test_the_card_reached_once_tied_up() -> void:
	var state := _all_seen()
	assert_false(ActRecap.reached(_content(), state).has("epilogue"))
	_lines(state, [TIE, CREW])
	assert_true(ActRecap.reached(_content(), state).has("epilogue"))
	assert_eq(ActRecap.credits(_card())[0], "The End")


func test_card_reads_every_island_seen() -> void:
	var state := _all_seen("lit")
	state.set_flag("thornwold_bram_cut_row", true)
	state.set_flag("fen_hesper_tussock", true)
	state.set_flag("wrackholm_held_for", true)
	state.set_flag("wrackholm_last_line", "came_in")
	state.set_flag("lowsong_beacon_burned", "key")
	state.set_flag("lowsong_kept_for", true)
	_lines(state, [TIE, CREW])
	var card := _card_text(state)
	for line: String in [
		"The Hearthspire burns gold", "Saltmarrow: Mara counts the boats", "Thornwold: Bram Kettle stopped notching",
		"a row that's yours", "Glasswater Fen: the fog lies on the pools", "a tussock that's yours",
		"Wrackholm: the answering horn", "Held for. Whatever the Wakebearer was.", "Came in.",
		"Kindleby: the old brothers", "Lowsong: the Low Water is quiet", "Iver listens over the Low Water",
		"Slow Mercy's deck"]:
		assert_true(card.contains(line), "missing: " + line)
	assert_false(card.contains("never put in"), card)
	assert_false(card.contains("sitting up with them"), "no released line when lit")
	assert_eq(ActRecap.coda(_card(), state), "The Lanternreach remembers. What it's willing to forget, it will be asked.")


func test_card_per_ending() -> void:
	var expect := {
		"released": ["sitting up with them", "Tam has taken a blanket", "counts two at the Lamp's bench",
			"a second light goes round the Heron's walk", "Gannet's empty bracket", "candles on the wall",
			"Iver shares the step"],
		"dark": ["every island chooses its own burning", "own list hangs on the dock-post", "WINTER row",
			"Hesper's first post", "hand-scale's pan", "Kindleby last", "one name long"],
	}
	for ending: String in expect:
		var state := _all_seen(ending)
		state.set_flag("lowsong_beacon_burned", "key")
		state.set_flag("kindleby_midwinter", "ring" if ending == "dark" else "")
		state.set_flag("lowsong_kept_for", false)
		state.set_flag("wrackholm_held_for", false)
		_lines(state, [TIE, WALK])
		var card := _card_text(state)
		for line: String in expect[ending]:
			assert_true(card.contains(line), ending + " missing: " + line)
		assert_false(card.contains("burns gold"), ending + ": not lit")
		assert_true(card.contains("You winter on foot"), card)
		assert_false(ActRecap.coda(_card(), state).is_empty(), ending + " has a coda")


func test_stay_names_the_port() -> void:
	var expect := {
		"saltmarrow": "where you woke", "thornwold": "black pines", "fen": "by the pools",
		"wrackholm": "sound of the horn", "kindleby": "among the candles",
	}
	for port: String in expect:
		var state := _all_seen("lit", port)
		_lines(state, [TIE, STAY])
		var winters := 0
		for line in ActRecap.card_lines(_content(), _card(), state):
			if line.begins_with("You winter"):
				winters += 1
				assert_true(line.contains(expect[port]), port + ": " + line)
		assert_eq(winters, 1, port + ": one winter line")


func test_card_draws_the_credits() -> void:
	var card := ActEndCard.new()
	card._ready()
	card.call("_show_credits", ActRecap.credits(_card()))
	assert_true(card.credits_text().begins_with("The End\nEmberwake"), card.credits_text())
	card.call("_show_credits", PackedStringArray())
	assert_eq(card.credits_text(), "", "an act with no credits clears them")
	card.free()
