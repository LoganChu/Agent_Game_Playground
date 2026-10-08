extends TestCase
## Day 29 — the fen lane: Oda sails north-about from the lit Ridge Light to Glasswater Fen; the
## staithe, Stillhithe and the Deeps; Hesper Vail of the Unmoored (the ember cupped or bare, the
## big man's rowboat, the letting post) and Corran Teal (the Heron Light).

const FEN := "glasswater_fen"
const SAIL := "Sail north-about to Glasswater Fen."
const ROWBOAT := "Whose rowboat is that, tied at the staithe?"
const MARA_WORD := "Tie on Mara's word: the stool's still by the door."
const OWN_WORD := "Tie on word of your own: someone from Saltmarrow came looking."
const NO_WORD := "Leave nothing. He came here to put things down."
const DIR := "res://assets/models/dressing/"

var _db: ContentDatabase


## At Thornwold landing with the ferry in and (by default) the Ridge Light lit.
func _at_thornwold(lit: bool = true) -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "thornwold_landed", "saltmarrow_mara_told_of_dunstan"]:
		state.set_flag(flag, true)
	state.set_flag("lanes_ferry_at", "thornwold")
	state.start_quest("a_light_for_thornwold", "feed_the_light")
	if lit:
		state.complete_quest("a_light_for_thornwold")
		state.set_flag("thornwold_beacon_burned", "boots")
	return state


## Landed at the fen (the first sailing played).
func _at_the_fen() -> WorldState:
	var state := _at_thornwold()
	_lines(state, "oda", [SAIL])
	return state


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_db, state, dialogue, typed, offered)


func _offered(state: WorldState, dialogue: String) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [], offered)
	return offered


func _xz(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[2]))


func _props(model: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop: Dictionary in _db.get_region(FEN)["props"]:
		if str(prop.get("model", "")) == DIR + model + ".glb":
			out.append(prop)
	return out


func _shown(model: String, state: WorldState) -> int:
	return _props(model).filter(func(p: Dictionary) -> bool: return Conditions.evaluate(p.get("if"), state)).size()


func test_oda_sails_north_about_once_the_ridge_light_is_lit() -> void:
	var dark := _at_thornwold(false)
	assert_false(_offered(dark, "oda").has(SAIL), "no fen lane while the Ridge Light is dark")
	var state := _at_thornwold()
	assert_true(_offered(state, "oda").has(SAIL), "Oda offers the fen lane once it's lit")
	var text := _lines(state, "oda", [SAIL])
	assert_true(text.contains("listen for") or text.contains("reeds"), "the first sailing is the full scene")
	assert_eq(state.get_flag("lanes_ferry_at"), "fen", "the Slow Mercy lies at the fen")
	assert_true(_db.dialogues["oda"]["knots"]["sail_fen"].any(func(s: Dictionary) -> bool: return s.get("travel", []) == [FEN, "from_ferry"]),
			"and the sailing travels to the fen's staithe")
	# At the fen Oda runs back to Thornwold; from there the lane again is one line.
	assert_true(_offered(state, "oda").has("Take me back to Thornwold."), "Oda will run back to Thornwold")
	assert_false(_offered(state, "oda").has(SAIL), "...and doesn't offer the fen from the fen")
	_lines(state, "oda", ["Take me back to Thornwold."])
	assert_eq(state.get_flag("lanes_ferry_at"), "thornwold")
	state.set_flag("fen_landed", true)
	var again := _lines(state, "oda", [SAIL])
	assert_false(again.contains("Fen folk used to meet every boat"), "later sailings are short")
	assert_eq(state.get_flag("lanes_ferry_at"), "fen")


func test_the_ferry_and_oda_follow_the_lane() -> void:
	var state := _at_the_fen()
	state.set_flag("saltmarrow_ferry_arrived", true)
	for region_id: String in ["saltmarrow", "thornwold_landing", FEN]:
		var region := _db.get_region(region_id)
		var oda := (region["npcs"] as Array).filter(func(n: Dictionary) -> bool:
			return str(n["npc"]) == "oda" and Conditions.evaluate(n.get("if"), state))
		var ferry := (region["props"] as Array).filter(func(p: Dictionary) -> bool:
			return str(p.get("model", "")).ends_with("/ferry.glb") and Conditions.evaluate(p.get("if"), state))
		var here := region_id == FEN
		assert_eq(oda.size(), 1 if here else 0, "Oda in %s only while the ferry is there" % region_id)
		assert_eq(ferry.size(), 1 if here else 0, "the Slow Mercy in %s only while she's there" % region_id)


func test_the_fen_layout() -> void:
	_db = load_content()
	var region := _db.get_region(FEN)
	var field := TerrainField.from_data(region["ground"], float(region["water_level"]))
	var spawn: Array = region["spawn_points"]["from_ferry"]
	var reachable := field.reachable_from(float(spawn[0]), float(spawn[2]))
	var areas := Greying.worst_case_areas(region)
	assert_true(Greying.depth_at(areas, _xz(spawn)) < Greying.CLEAR_DEPTH, "the staithe is clear of the fog")
	var stillhithe := Greying.depth_at(areas, Vector2(0, -11))
	assert_true(stillhithe > 0.2 and stillhithe < 0.5, "Stillhithe lies in a thin Greying (%.2f)" % stillhithe)
	assert_true(Greying.depth_at(areas, Vector2(0, -27)) > 0.9, "the long walk runs into the Deeps")
	assert_true(field.near_reachable(reachable, 0, -24, 1.0), "...and can be walked out along")
	for who: Dictionary in region["npcs"]:
		assert_true(field.near_reachable(reachable, float(who["position"][0]), float(who["position"][2]), 1.5), "%s can be walked to" % who["npc"])
	for object: Dictionary in region["objects"]:
		assert_true(field.near_reachable(reachable, float(object["position"][0]), float(object["position"][2]), 1.5), "%s can be walked to" % object["id"])
	# The letting post's islet is reached over the west walk (a pier), not by wading.
	assert_true(field.near_reachable(reachable, -11, -10, 0.6), "the west walk's boardwalk is walkable")
	var heron: Dictionary = _props("heron_light")[0]
	assert_false(bool(heron.get("snap", true)), "the Heron Light stands in the mere at an absolute height")
	assert_false(heron.has("collider"), "...and is never reached (no collider)")
	assert_false(field.near_reachable(reachable, float(heron["position"][0]), float(heron["position"][2]), 3.0), "it is out of reach")
	assert_true(Greying.depth_at(areas, _xz(heron["position"])) > 0.9, "deep in the Deeps' fog")
	# Arrival scene once, and only off the ferry.
	var state := fresh_state(_db)
	assert_true(RegionEvents.arrival(region, state).is_empty(), "no arrival scene without the ferry")
	state.set_flag("lanes_ferry_at", "fen")
	assert_eq(RegionEvents.fire(RegionEvents.arrival(region, state), state), "fen_arrival", "the arrival scene plays")
	assert_true(RegionEvents.arrival(region, state).is_empty(), "and only once")


func test_hesper_asks_for_the_ember_cupped() -> void:
	var cupped := _at_the_fen()
	var text := _lines(cupped, "hesper", ["Close your hand over the ember."])
	assert_true(text.contains("Hesper Vail") and text.contains("nobody asks what you came to put down"), "she names herself and the rule")
	assert_eq(cupped.get_flag("fen_ember"), "cupped")
	assert_true(cupped.get_flag("fen_met_hesper") == true)
	assert_true(_lines(cupped, "hesper").contains("Your hand's still shut"), "she remembers your manners")
	var bare := _at_the_fen()
	_lines(bare, "hesper", ["It's not mine to hide."])
	assert_eq(bare.get_flag("fen_ember"), "bare")
	assert_true(_lines(bare, "hesper").contains("Stand downwind"), "...or that you didn't have any")
	# Corran has no time for Hesper's manners.
	assert_true(_lines(cupped, "corran").contains("Hiding it for her"), "Corran sees the cupped hand")
	assert_false(_lines(bare, "corran").contains("Hiding it for her"))


func test_the_big_man_and_the_letting_post() -> void:
	var state := _at_the_fen()
	assert_true(_lines(state, "letting_post").contains("wooden gull"), "the post can be looked at before you know of it")
	assert_eq(state.quest_state("the_letting_post"), WorldState.QUEST_INACTIVE)
	_lines(state, "hesper", ["Close your hand over the ember."])
	var text := _lines(state, "hesper", [ROWBOAT])
	assert_true(text.contains("Dunstan Tollen"), "the player knows the name Hesper keeps for him")
	assert_true(text.contains("letting post"), "she tells of the letting post")
	assert_eq(state.quest_stage("the_letting_post"), "leave_word", "The Letting Post begins")
	assert_false(_offered(state, "hesper").has(ROWBOAT), "asked once")
	# Without Mara's message the player can leave word of their own, or nothing.
	var offered := _offered(state, "letting_post")
	assert_true(offered.has(OWN_WORD) and offered.has(NO_WORD) and not offered.has(MARA_WORD))
	assert_eq(_shown("letting_post", state), 1, "the post hangs as it was")
	_lines(state, "letting_post", [OWN_WORD])
	assert_eq(state.get_flag("fen_dunstan_word"), "own")
	assert_eq(state.quest_state("the_letting_post"), WorldState.QUEST_DONE)
	assert_eq([_shown("letting_post", state), _shown("letting_post_word", state)], [0, 1], "your word is knotted on")
	assert_true(_lines(state, "hesper").contains("That's a hook"), "Hesper has a view on it")
	assert_false(_lines(state, "hesper").contains("That's a hook"), "...once")
	assert_true(_lines(state, "letting_post").contains("still knotted"), "the post remembers it")


func test_maras_word_or_nothing() -> void:
	var mara := _at_the_fen()
	mara.set_flag("saltmarrow_mara_message_for_dunstan", true)
	_lines(mara, "hesper", ["Close your hand over the ember.", ROWBOAT])
	var offered := _offered(mara, "letting_post")
	assert_true(offered.has(MARA_WORD) and not offered.has(OWN_WORD), "Mara's word, if she sent one")
	assert_true(_lines(mara, "letting_post", [MARA_WORD]).contains("the stool's still by the door"))
	assert_eq(mara.get_flag("fen_dunstan_word"), "mara")
	assert_eq(_shown("letting_post_word", mara), 1)
	assert_true(_lines(mara, "hesper").contains("red cord"))
	var none := _at_the_fen()
	_lines(none, "hesper", ["Close your hand over the ember.", ROWBOAT])
	_lines(none, "letting_post", [NO_WORD])
	assert_eq(none.get_flag("fen_dunstan_word"), "none")
	assert_eq(none.quest_state("the_letting_post"), WorldState.QUEST_DONE, "leaving nothing is an answer too")
	assert_eq([_shown("letting_post", none), _shown("letting_post_word", none)], [1, 0], "nothing is tied on")
	assert_true(_lines(none, "hesper").contains("kept the rule"))
	# Walking away from the post leaves the choice open.
	var later := _at_the_fen()
	_lines(later, "hesper", ["Close your hand over the ember.", ROWBOAT])
	_lines(later, "letting_post", ["Not yet."])
	assert_eq(later.quest_state("the_letting_post"), WorldState.QUEST_ACTIVE, "'Not yet' keeps the quest open")


func test_after_the_gull_burn_the_name_slides_off() -> void:
	var state := _at_the_fen()
	state.set_flag("saltmarrow_beacon_burned", "gull")
	var text := _lines(state, "hesper", ["Close your hand over the ember.", ROWBOAT])
	assert_false(text.contains("Dunstan"), "the Wakebearer can't hold the name Mara burned")
	assert_true(text.contains("rain off a coat"))
	assert_true(_lines(state, "fen_rowboat").contains("A stool by a door? It won't come."))
	var oda := _lines(state, "oda", ["That rowboat tied at the staithe..."])
	assert_true(oda.contains("Dunstan's, then") and oda.contains("Gull's burn"), "Oda, an off-islander, still says it; it doesn't stay")
	var kept := _at_the_fen()
	_lines(kept, "fen_rowboat")
	assert_true(_lines(kept, "oda", ["That rowboat tied at the staithe..."]).contains("crewed for me two winters"))


func test_corran_and_the_heron_light() -> void:
	var state := _at_the_fen()
	var text := _lines(state, "corran", ["Tell me about the Heron Light."])
	assert_true(text.contains("Corran Teal") and text.contains("skiff"), "Corran tells of the keeper who poled out")
	assert_eq(state.quest_state("a_light_for_glasswater"), WorldState.QUEST_ACTIVE, "A Light for Glasswater begins")
	assert_true(bool(_db.quests["a_light_for_glasswater"].get("future", false)), "its payoff is a later session's")
	assert_false(_offered(state, "corran").has("A big man came here in a rowboat, Hesper says."), "Corran's whittler waits on Hesper")
	_lines(state, "hesper", ["Close your hand over the ember.", ROWBOAT])
	assert_true(_lines(state, "corran", ["A big man came here in a rowboat, Hesper says."]).contains("It's for after"))


func test_the_fen_folk_are_built() -> void:
	_db = load_content()
	for id: String in ["hesper", "corran"]:
		var npc := _db.get_npc(id)
		assert_true(ResourceLoader.exists(str(npc["model"])), "%s has a model" % id)
	assert_eq(str(_db.get_npc("hesper")["faction"]), "unmoored", "Hesper is one of the Unmoored")
	for model: String in ["reed_house", "letting_post", "letting_post_word", "heron_light"]:
		assert_true(ResourceLoader.exists(DIR + model + ".glb"), "%s is built" % model)
	assert_eq(_props("reed_house").size(), 3, "three reed houses on Stillhithe")
