extends TestCase
## Day 89 — the eighth boat's owner (Act III step 6). After the Spire's own book the Provost reckons the High Keeper
## never left Cindermoor, and the chapter comes back up from the lower rooms with the Wakebearer. A woman walks the
## worn path round the Spire's foot (a walking NPC: placement `circuit`). Whether the Wakebearer tells her who she is,
## asks her first, or lets her walk (`cindermoor_eighth_told`).

const FOOT := "cindermoor_spire_foot"
const LOWER := "cindermoor_lower_rooms"
const SOUGHT := "cindermoor_eighth_sought"
const TOLD := "cindermoor_eighth_told"
const CHAPTER: Array[String] = ["provost", "hild", "iver", "wenna_coll"]

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


## Everyone aboard: Iver home with his lamp burned, Wenna come to Kindleby.
func _everyone(state: WorldState) -> WorldState:
	state.set_flag("lowsong_iver_home", true)
	state.set_flag("lowsong_beacon_burned", "lamp")
	state.set_flag("thornwold_skiff", "kindleby")
	state.set_flag("thornwold_far_shore", "")
	return state


func _region(id: String) -> Dictionary:
	return _content().regions[id]


func _placements(region_id: String, npc: String, state: WorldState) -> Array:
	return (_region(region_id)["npcs"] as Array).filter(func(n: Dictionary) -> bool:
		return str(n["npc"]) == npc and Conditions.evaluate(n.get("if", []), state))


## Up from the lower rooms and the arrival on the crown; returns everything said.
func _go_up(state: WorldState, pick: String = "I saw her. At the sitting, walking the path outside the candles.") -> String:
	var told := _lines(state, "provost", [pick])
	var event := RegionEvents.arrival(_region(FOOT), state)
	assert_eq(str(event.get("id", "")), "cindermoor_eighth_walks")
	return told + _lines(state, RegionEvents.fire(event, state))


func test_the_provost_goes_up_to_look() -> void:
	var state := _everyone(_at("the_lower_rooms"))
	for npc in CHAPTER:
		assert_eq(_placements(LOWER, npc, state).size(), 1, "%s below with the book" % npc)
	var offered: Array[String] = []
	var told := _lines(state, "provost", ["Not yet. Read your lines."], offered)
	assert_true(told.contains("And there's the eighth boat.") and told.contains("Oriel never could abide"), told)
	assert_false(bool(state.get_flag(SOUGHT)), "not yet: the chapter stays below")
	told = _lines(state, "provost", ["I saw her. At the sitting, walking the path outside the candles."])
	assert_true(told.contains("into the fog like a hare") and told.contains("We'll go up. Quietly."), told)
	assert_true(bool(state.get_flag(SOUGHT)))
	assert_eq(state.quest_stage("the_eighth_boat"), "go_up")
	for npc in CHAPTER:
		assert_eq(_placements(LOWER, npc, state).size(), 0, "%s has gone up" % npc)
		assert_eq(_placements(FOOT, npc, state).size(), 1, "%s on the crown" % npc)
	var ring: Array = (_region(FOOT)["props"] as Array).filter(func(p: Dictionary) -> bool:
		return str(p.get("model", "")).ends_with("chapter_ring.glb"))
	assert_false(Conditions.evaluate(ring[0]["if"], state), "the candle ring is gathered up")
	# The way up is a travel on the closing line, to the crown's stair head.
	var go: Array = (_content().dialogues["provost"]["knots"]["eighth_go"] as Array)
	assert_eq(go[go.size() - 1]["travel"], [FOOT, "from_lower"])


func test_ness_s_word_is_another_way_to_say_it() -> void:
	var state := _at("the_lower_rooms")
	var offered: Array[String] = []
	_lines(state, "provost", ["Not yet. Read your lines."], offered)
	var ness := "Ness said a woman goes about up there on her own. Was there before any of the Unmoored."
	assert_eq(offered.has(ness), bool(state.get_flag("cindermoor_ness_met")), "offered only if Ness was met")
	state.set_flag("cindermoor_ness_met", true)
	var told := _lines(state, "provost", [ness])
	assert_true(told.contains("always first up the stair") and bool(state.get_flag(SOUGHT)), told)


func test_she_walks_the_path_and_doesnt_turn() -> void:
	var state := _everyone(_at("the_lower_rooms"))
	var told := _go_up(state)
	assert_true(told.contains("Oriel.") and told.contains("doesn't turn") and told.contains("only one of us she's never seen"), told)
	assert_true(bool(state.get_flag("cindermoor_eighth_seen")))
	assert_eq(state.quest_stage("the_eighth_boat"), "the_path")
	assert_true(told.contains("Wenna goes round it"), "Wenna gathers her stubs when she came")
	assert_true(RegionEvents.arrival(_region(FOOT), state).is_empty(), "once")
	var walking := _placements(FOOT, "oriel", state)
	assert_eq(walking.size(), 1)
	assert_true(walking[0].has("circuit"), "she walks round")
	assert_eq(ContentDatabase.npc_display_name(_content().npcs["oriel"], state, "oriel"), "The woman on the ring path")
	# Without Wenna, Hild picks the stubs up instead (exactly one opening line either way).
	var alone := _at("the_lower_rooms")
	var lines := _go_up(alone)
	assert_true(lines.contains("into her sleeve") and not lines.contains("Wenna"), lines)


func test_the_circuit_is_the_worn_path_and_clear_of_everyone() -> void:
	var placement: Dictionary = (_region(FOOT)["npcs"] as Array).filter(func(n: Dictionary) -> bool:
		return str(n["npc"]) == "oriel" and n.has("circuit"))[0]
	var circuit: Dictionary = placement["circuit"]
	var centre := Vector2(float(circuit["center"][0]), float(circuit["center"][1]))
	var radius := float(circuit["radius"])
	# The worn path is the painted ring round the Spire.
	var ring: Dictionary = (_region(FOOT)["ground"]["paint"] as Array).filter(func(p: Dictionary) -> bool:
		return str(p.get("note", "")).contains("round and round"))[0]
	for point: Array in ring["path"]:
		assert_true(absf(Vector2(float(point[0]), float(point[1])).distance_to(centre) - radius) < 0.1, "on the worn path: %s" % [point])
	# Clear of the Spire's foot (its boxes reach 5 m from the centre, the niche ~6.4) ...
	assert_true(radius > 6.4 + 0.6)
	# ... and of everyone standing on the crown while she walks.
	var state := _everyone(_at("the_eighth_boat"))
	for n: Dictionary in _region(FOOT)["npcs"]:
		if str(n["npc"]) == "oriel" or not Conditions.evaluate(n.get("if", []), state):
			continue
		var at := Vector2(float(n["position"][0]), float(n["position"][2]))
		assert_true(absf(at.distance_to(centre) - radius) > 1.5, "%s stands off her path" % n["npc"])


func test_tell_her() -> void:
	var state := _at("the_eighth_boat")
	var told := _lines(state, "oriel", ["I know who you are.", "Tell her: her name, and what she did, and why."])
	assert_true(told.contains("Somebody asked to carry one of those, once."), "the hook, not the answer")
	assert_true(told.contains("Your name is Oriel Sayre.") and told.contains("It turns.") and told.contains("Then I meant it."), told)
	assert_true(told.contains("Agathe.") and told.contains("You were careful.") and told.contains("That's worse."), told)
	assert_eq(str(state.get_flag(TOLD)), "told")
	assert_eq(state.quest_state("the_eighth_boat"), WorldState.QUEST_DONE)
	assert_eq(ContentDatabase.npc_display_name(_content().npcs["oriel"], state, "oriel"), "Oriel Sayre")
	var sitting := _placements(FOOT, "oriel", state)
	assert_eq(sitting.size(), 1)
	assert_false(sitting[0].has("circuit"), "she has stopped walking")
	assert_true(str(sitting[0]["model"]).ends_with("oriel_seated.glb"))
	assert_true(_lines(state, "oriel").contains("That's somebody else's stair."))
	assert_true(_lines(state, "provost").contains("She's sitting down."))
	assert_true(_lines(state, "merrit").contains("Found, then. Not come down."))
	assert_true(_lines(state, "cindermoor_ring").contains("Nobody's walking it now."))


func test_ask_her_first() -> void:
	var state := _at("the_eighth_boat")
	var told := _lines(state, "oriel", ["I know who you are.", "Ask her first whether she wants it back."])
	assert_true(told.contains("Do you want it back?") and told.contains("Then not yet.") and told.contains("come and ask me again"), told)
	assert_eq(str(state.get_flag(TOLD)), "asked")
	assert_eq(state.quest_state("the_eighth_boat"), WorldState.QUEST_DONE)
	assert_true(_placements(FOOT, "oriel", state)[0].has("circuit"), "still walking")
	assert_eq(ContentDatabase.npc_display_name(_content().npcs["oriel"], state, "oriel"), "The woman on the ring path")
	assert_true(_lines(state, "provost").contains("You asked her."))
	assert_true(_lines(state, "oriel").contains("You said you'd go up first."))


func test_let_her_walk() -> void:
	var state := _at("the_eighth_boat")
	var told := _lines(state, "oriel", ["I know who you are.", "Say nothing. Step off the path and let her walk."])
	assert_true(told.contains("Kind. Or careful."), told)
	assert_eq(str(state.get_flag(TOLD)), "kept")
	assert_true(_lines(state, "provost").contains("That's what frightens me about it."))
	# "Not now" keeps it open.
	var later := _at("the_eighth_boat")
	_lines(later, "oriel", ["I know who you are.", "Not now."])
	assert_eq(str(later.get_flag(TOLD)), "")
	assert_eq(later.quest_stage("the_eighth_boat"), "the_path")


func test_the_chapter_and_ness_have_a_line_for_each() -> void:
	for value: String in ["", "told", "asked", "kept"]:
		var state := _everyone(_at("the_eighth_boat"))
		state.set_flag(TOLD, value)
		for npc: String in ["hild", "iver", "wenna_coll"]:
			assert_true(_lines(state, npc).length() > 40, "%s speaks (%s)" % [npc, value])
		state.set_flag("cindermoor_ness_met", true)
		var ness := _lines(state, "ness", ["Go carefully."])
		assert_true(ness.contains("You'll have seen her."), ness)


func test_a_walker_goes_round_and_holds() -> void:
	var actor := NpcActor.new()
	actor.setup("oriel", {"dialogue": "oriel"})
	actor.position = Vector3(-7.4, 0, -6)
	actor.walk_circuit({"center": [0, -6], "radius": 7.4, "speed": 0.6, "clockwise": true}, func(_x: float, _z: float) -> float: return 1.0)
	assert_true(actor.walks_circuit())
	assert_eq(actor.position, Vector3(-7.4, 1.0, -6), "starts where placed, on the ground")
	var before := actor.position
	var walked := actor.step_circuit(2.0)
	assert_true(absf(walked - 1.2) < 0.001)
	var centre := Vector2(0, -6)
	assert_true(absf(Vector2(actor.position.x, actor.position.z).distance_to(centre) - 7.4) < 0.001, "stays on the circle")
	assert_true(absf(before.distance_to(actor.position) - 1.2) < 0.02, "1.2 m along it")
	# Clockwise seen from above (+Y up, looking down -Y with +X right and +Z down the page) from the west: north (-Z).
	assert_true(actor.position.z < -6.0, "went north from the west side: %s" % actor.position)
	var ahead := actor.basis * Vector3(0, 0, 1)
	var step := Vector3(actor.position.x - before.x, 0, actor.position.z - before.z).normalized()
	assert_true(ahead.dot(step) > 0.95, "faces the way round")
	GameState.input_locked = true
	assert_eq(actor.step_circuit(1.0), 0.0, "holds while a modal is up")
	GameState.input_locked = false
	actor.free()


func test_the_validator_checks_circuits() -> void:
	var db := load_content()
	var region: Dictionary = db.regions[FOOT]
	var placement: Dictionary = (region["npcs"] as Array).filter(func(n: Dictionary) -> bool:
		return str(n["npc"]) == "oriel" and n.has("circuit"))[0]
	var saved: Dictionary = placement["circuit"].duplicate(true)
	var cases := [
		[{"center": [0, -6.0], "radius": 0.5}, "radius"],
		[{"center": [0], "radius": 7.4}, "center"],
		[{"center": [0, -6.0], "radius": 7.4, "speed": 9}, "speed"],
		[{"center": [0, -6.0], "radius": 7.4, "clockwise": "yes"}, "clockwise"],
		[{"center": [0, -6.0], "radius": 7.4, "pace": 1}, "unknown key"],
		[{"center": [0, -6.0], "radius": 6.0}, "off its circuit"],
		[{"center": [-7.4, -6.0], "radius": 0.0}, "radius"],
	]
	for case: Array in cases:
		placement["circuit"] = case[0]
		var v := ContentValidator.new(db)
		v.validate()
		assert_true(v.errors.any(func(e: String) -> bool: return e.contains(case[1])), "caught %s: %s" % [case[0], v.errors])
	# A circle out past the crown's edge leaves walkable ground.
	placement["circuit"] = {"center": [-7.4 - 25.0, -6.0], "radius": 25.0}
	var walk := ContentValidator.new(db)
	walk.validate()
	assert_true(walk.errors.any(func(e: String) -> bool: return e.contains("circuit leaves walkable ground")), str(walk.errors))
	placement["circuit"] = saved
	var ok := ContentValidator.new(db)
	assert_true(ok.validate(), str(ok.errors))
