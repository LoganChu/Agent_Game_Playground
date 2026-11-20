extends TestCase
## Day 116 — word goes round: who has a word for the east stair, for Oriel, and for the Wren on the door.
## Iver and Wenna Coll at the Spire's foot speak to the stair climbed (counted twice; "one of ours" once the Provost
## knows), to where Oriel went (climb / boat / own), and, after the cradle, to the Spire per ending. Oda at the Boat
## Stair hears the High Keeper's alive (`cindermoor_oda_heard_oriel`, once). At Kindleby Oda finds a Wren on the
## Keepers' door who asked her where she was going (`kindleby_oda_saw_warden`, once), and Wenna Garrow at Wrackholm
## hears it from her (`wrackholm_wenna_heard_warden`, once).

const ORIEL_ASK := "The High Keeper's alive. She's up on the crown."

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


## The what_she_was checkpoint with Iver and Wenna Coll along with the chapter.
func _foot(oriel := "climb") -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("what_she_was"))
	state.set_flag("lowsong_iver_home", true)
	state.set_flag("lowsong_beacon_burned", "lamp")
	state.set_flag("thornwold_skiff", "kindleby")
	state.set_flag("thornwold_far_shore", "")
	state.set_flag("cindermoor_oriel_choice", oriel)
	return state


func _here(state: WorldState, region: String, npc: String) -> bool:
	for placement: Dictionary in _content().regions[region].get("npcs", []):
		if str(placement["npc"]) == npc and Conditions.evaluate(placement.get("if", []), state):
			return true
	return false


func test_iver_and_wenna_coll_at_the_foot() -> void:
	var state := _foot()
	assert_true(_here(state, "cindermoor_spire_foot", "iver"), "Iver at the foot")
	assert_true(_here(state, "cindermoor_spire_foot", "wenna_coll"), "Wenna Coll at the foot")
	var iver := _lines(state, "iver")
	assert_true(iver.contains("One of ours"), "the Provost knows: Iver says so")
	assert_false(iver.contains("count anything twice"), "not the unknowing line once she knows")
	assert_true(iver.contains("at the stair door"), "climb")
	var wenna := _lines(state, "wenna_coll")
	assert_true(wenna.contains("One of theirs"))
	assert_true(wenna.contains("clamp door"), "climb")
	# Not told the Provost: counted twice, nothing about whose.
	state.set_flag("cindermoor_provost_knows", false)
	assert_true(_lines(state, "iver").contains("count anything twice"))
	assert_true(_lines(state, "wenna_coll").contains("ran out"))
	# Before the stair: neither.
	state.set_flag("cindermoor_stair_down", false)
	assert_false(_lines(state, "iver").contains("count anything twice"))
	assert_false(_lines(state, "wenna_coll").contains("ran out"))


func test_where_oriel_went() -> void:
	var expect := {
		"": ["put a pack down", "raked out herself"],
		"boat": ["went down to the boat", "sit in her boat"],
		"own": ["behind the Provost", "Nobody told her where to stand"],
	}
	for choice: String in expect:
		var state := _foot(choice)
		assert_true(_lines(state, "iver").contains(expect[choice][0]), "Iver, %s" % choice)
		assert_true(_lines(state, "wenna_coll").contains(expect[choice][1]), "Wenna Coll, %s" % choice)


func test_after_the_cradle() -> void:
	var expect := {
		"lit": ["Burning", "carry them home"],
		"released": ["Properly quiet", "out that window"],
		"dark": ["still singing", "long dark round"],
	}
	for ending: String in expect:
		var state := _foot()
		state.set_flag("cindermoor_cradle_choice", ending)
		var iver := _lines(state, "iver")
		var wenna := _lines(state, "wenna_coll")
		assert_true(iver.contains(expect[ending][0]), "Iver, %s" % ending)
		assert_true(wenna.contains(expect[ending][1]), "Wenna Coll, %s" % ending)
		assert_false(iver.contains("One of ours") or iver.contains("stair door"), "Iver: the ending, not the stair")
		assert_false(wenna.contains("One of theirs") or wenna.contains("clamp door"), "Wenna Coll: the ending")


func test_oda_hears_the_high_keepers_alive() -> void:
	var state := _foot("boat")
	state.set_flag("lanes_ferry_at", "cindermoor")
	assert_true(_here(state, "cindermoor_boat_stair", "oriel"), "Oriel in her boat on the Boat Stair")
	var offered: Array[String] = []
	var said := _lines(state, "oda", [ORIEL_ASK], offered)
	assert_true(ORIEL_ASK in offered)
	assert_true(said.contains("Thirty-eight years"))
	assert_true(said.contains("same as Merrit"), "she sees Oriel in the eighth boat")
	assert_true(said.contains("carrying it now"), "told")
	assert_true(bool(state.get_flag("cindermoor_oda_heard_oriel")))
	offered.clear()
	_lines(state, "oda", [], offered)
	assert_false(ORIEL_ASK in offered, "once")
	# Not before she's met; after the count down, from the other hub, with the ending's line.
	var fresh := _foot("climb")
	fresh.set_flag("lanes_ferry_at", "cindermoor")
	fresh.set_flag("cindermoor_eighth_met", false)
	offered.clear()
	_lines(fresh, "oda", [], offered)
	assert_false(ORIEL_ASK in offered, "not before the ring path")
	var after := _foot("climb")
	after.set_flag("lanes_ferry_at", "cindermoor")
	after.set_flag("cindermoor_counted_down", true)
	after.set_flag("cindermoor_oda_after_seen", true)
	after.set_flag("cindermoor_cradle_choice", "lit")
	said = _lines(after, "oda", [ORIEL_ASK, "Not yet."])
	assert_true(said.contains("let you light it"))
	assert_false(said.contains("same as Merrit"), "not in the boat")


func test_oda_and_wenna_on_the_warden() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_door_wardens_stool"))
	var said := _lines(state, "oda")
	assert_true(said.contains("Wren on the Keepers' door"))
	assert_true(said.contains("Tobin's stool"), "sat on the stool")
	assert_true(bool(state.get_flag("kindleby_oda_saw_warden")))
	assert_false(_lines(state, "oda").contains("Wren on the Keepers' door"), "once")
	# Without the stool: no stool line. Home: nothing.
	var standing := fresh_state(_content())
	Scenarios.apply(_content(), standing, Scenarios.resolve("before_the_provost"))
	said = _lines(standing, "oda")
	assert_true(said.contains("Wren on the Keepers' door"))
	assert_false(said.contains("Tobin's stool"))
	var home := fresh_state(_content())
	Scenarios.apply(_content(), home, Scenarios.resolve("before_the_provost"))
	home.set_flag("kindleby_aldous_door", "home")
	assert_false(_lines(home, "oda").contains("Wren on the Keepers' door"))
	# Wenna at Wrackholm, after her homecoming.
	state.set_flag("lanes_ferry_at", "wrackholm")
	state.set_flag("wrackholm_met_wenna", true)
	state.set_flag("wrackholm_homecoming_seen", true)
	said = _lines(state, "wenna")
	assert_true(said.contains("A horn's the same"))
	assert_true(bool(state.get_flag("wrackholm_wenna_heard_warden")))
	assert_false(_lines(state, "wenna").contains("A horn's the same"), "once")
	home.set_flag("wrackholm_met_wenna", true)
	home.set_flag("wrackholm_homecoming_seen", true)
	assert_false(_lines(home, "wenna").contains("A horn's the same"), "not if he went home")


func test_the_checkpoint() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("word_goes_round"))
	assert_true(_here(state, "cindermoor_boat_stair", "oriel"), "Oriel in her boat")
	assert_true(_here(state, "cindermoor_boat_stair", "oda"), "Oda on the quay")
	assert_true(bool(state.get_flag("cindermoor_oda_heard_oriel")))
