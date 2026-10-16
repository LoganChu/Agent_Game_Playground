extends TestCase
## Day 45 — the Lamp's name carried home (*Paid Twice*). Read in Wrackholm's lane-house Book
## (WYNN SALLOW, keeper, for the Ridge Light. Paid twice.), carried back west by the fen to the ridge:
## said outright (the hood put back, the sentence finished, the novice on the east stair who said
## "Keep one back this year, Keeper Sallow") or asked first (the Lamp leaves it paid in the Book, for
## the four). Oda weighs it once at Thornwold landing, differently for a sworn friend of the lanes.

const RIDGE := "thornwold_ridge"
const TELL := "I read your name. In the Tidewrights' Book, on Wrackholm."
const SAY := "Your name is Wynn Sallow."
const ASK := "Do you want it back?"
const LATER := "Not now."
const WHO := "Who are you?"
const BYE := "Goodbye."

var _db: ContentDatabase


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_db, state, dialogue, typed, offered)


func _offered(state: WorldState, dialogue: String) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [BYE], offered)
	return offered


## Back on the ridge after the Wrack: the Ridge Light lit and seen, the Lamp met; the name read in
## the Book unless `read` is false; `sworn` is the friend-of-the-lanes answer.
func _home(read: bool = true, sworn: String = "") -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "thornwold_landed", "thornwold_met_lamp",
			"thornwold_lamp_name_lost", "thornwold_lamp_saw_light", "fen_landed", "wrackholm_landed",
			"wrackholm_book_told", "wrackholm_book_opened", "wrackholm_horn_sounded"]:
		state.set_flag(flag, true)
	state.set_flag("thornwold_beacon_burned", "salt_row")
	state.set_flag("wrackholm_sworn", sworn)
	state.set_flag("lanes_ferry_at", "thornwold")
	state.complete_quest("a_light_for_thornwold")
	if read:
		state.set_flag("wrackholm_lamp_name_read", true)
		state.start_quest("paid_twice", "carry_it_home")
	return state


func _lamp_model(state: WorldState) -> String:
	var placements: Array = (_db.get_region(RIDGE)["npcs"] as Array).filter(func(p: Dictionary) -> bool: return p["npc"] == "lamp")
	var shown := placements.filter(func(p: Dictionary) -> bool: return Conditions.evaluate(p.get("if"), state))
	assert_eq(shown.size(), 1, "one Lamp at the bench")
	for p: Dictionary in placements:
		assert_eq(p["position"], placements[0]["position"], "at the bench every time")
	return str(shown[0].get("model", "lamp")).get_file().get_basename() if not shown.is_empty() else "?"


func test_only_once_the_name_was_read() -> void:
	var unread := _home(false)
	assert_false(_offered(unread, "lamp").has(TELL), "nothing to carry")
	var state := _home()
	assert_true(_offered(state, "lamp").has(TELL))
	var text := _lines(state, "lamp", [TELL, LATER, BYE])
	assert_true(text.contains("went out of my head and stayed on the page"))
	assert_eq(state.get_flag("thornwold_lamp_name"), "", "not now: still to say")
	assert_eq(state.quest_state("paid_twice"), WorldState.QUEST_ACTIVE)
	assert_true(_offered(state, "lamp").has(TELL), "asked again")


func test_said_outright() -> void:
	var state := _home()
	assert_eq(_lamp_model(state), "lamp", "hood up")
	var text := _lines(state, "lamp", [TELL, SAY, BYE])
	assert_true(text.contains("put it back") and text.contains("White hair cropped close"), "the hood back")
	assert_true(text.contains("that one had an end"), "a sentence finished")
	assert_true(text.contains("Keep one back this year, Keeper Sallow"), "the novice on the east stair")
	assert_true(text.contains("door-warden on the east stair"), "a thread to the Wren")
	assert_eq(state.get_flag("thornwold_lamp_name"), "told")
	assert_eq(state.quest_state("paid_twice"), WorldState.QUEST_DONE)
	assert_false(_offered(state, "lamp").has(TELL), "said once")
	assert_eq(_lamp_model(state), "lamp_named", "the hood put back")
	assert_true(ResourceLoader.exists("res://assets/models/characters/lamp_named.glb"))
	var again := _lines(state, "lamp", [WHO, BYE])
	assert_true(again.contains("I say it in the mornings"), "greets you as Wynn")
	assert_true(again.contains("I answer to both now"))
	assert_false(again.contains("I keep meaning to look"), "not lost any more")


func test_asked_first() -> void:
	var state := _home()
	var text := _lines(state, "lamp", [TELL, ASK, BYE])
	assert_true(text.contains("doesn't go round after for the change"))
	assert_true(text.contains("Not some stranger with a name they never heard"), "for the four")
	assert_false(text.contains("Keeper Sallow"), "the stair stays shut")
	assert_eq(state.get_flag("thornwold_lamp_name"), "left")
	assert_eq(state.quest_state("paid_twice"), WorldState.QUEST_DONE)
	assert_false(_offered(state, "lamp").has(TELL), "its choice stands")
	assert_eq(_lamp_model(state), "lamp", "the hood stays up")
	var again := _lines(state, "lamp", [WHO, BYE])
	assert_true(again.contains("The Book's keeping it") and again.contains("that's where it lives"))


func test_a_friend_of_the_lanes_hears_it_noticed() -> void:
	var sworn := _home(true, "sworn")
	assert_true(_lines(sworn, "lamp", [TELL, LATER, BYE]).contains("A friend of the lanes"))
	assert_false(_lines(_home(true, "declined"), "lamp", [TELL, LATER, BYE]).contains("A friend of the lanes"))


func test_oda_weighs_it_once() -> void:
	var cases := {"sworn told": "It minds being emptied", "declined told": "She'd mind if you were sworn",
			" told": "She'd mind if you were sworn", "sworn left": "Tidewright manners", " left": "Tidewright manners"}
	for key: String in cases:
		var parts := key.split(" ")
		var state := _home(true, parts[0])
		assert_false(_lines(state, "oda", ["Not yet."]).contains("Lamp's name"), "nothing before the ridge")
		_lines(state, "lamp", [TELL, SAY if parts[1] == "told" else ASK, BYE])
		var text := _lines(state, "oda", ["Not yet."])
		assert_true(text.contains(cases[key]), key)
		for other: String in cases.values():
			if other != cases[key]:
				assert_false(text.contains(other), key + " not: " + other)
		assert_true(state.get_flag("lanes_oda_weighed_name") == true)
		assert_false(_lines(state, "oda", ["Not yet."]).contains(cases[key]), "once")


func test_old_saves_complete_it_without_the_quest() -> void:
	# A save from Day 43-44 read the name before Paid Twice existed.
	var state := _home()
	state.quests.erase("paid_twice")
	_lines(state, "lamp", [TELL, SAY, BYE])
	assert_eq(state.quest_state("paid_twice"), WorldState.QUEST_DONE)
