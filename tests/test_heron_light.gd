extends TestCase
## Day 33 — The Heron Light, part one: Corran sends the Wakebearer for his far trap at the end of
## the long walk; in it, the keeper's skiff bell; he decides, and poles them out through the
## channels to the Heron's legs (a new region, `heron_mere`): the Foot, the keeper's skiff (hang the
## bell or keep it), the scraped ladder, a big man with an unlit lantern at the fog's edge.

const FEN := "glasswater_fen"
const MERE := "heron_mere"
const QUEST := "a_light_for_glasswater"
const HERON := "Tell me about the Heron Light."
const ASK := "Will you take me out to the Heron now?"
const TRAP := "I lifted your far trap."
const POLE := "Pole me out to the Heron."
const POLE_AGAIN := "Pole me out to the Heron again."
const BACK := "Take me back."
const CHARS := "res://assets/models/characters/"

var _db: ContentDatabase


## Landed at the fen, Corran met (the ember `ember`, "" for never asked), the Heron asked about.
func _at_corran(ember: String = "bare") -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "thornwold_landed", "fen_landed", "fen_met_hesper",
			"saltmarrow_mara_told_of_dunstan"]:
		state.set_flag(flag, true)
	state.set_flag("lanes_ferry_at", "fen")
	state.set_flag("fen_ember", ember)
	state.complete_quest("a_light_for_thornwold")
	_lines(state, "corran", [HERON])
	return state


## Corran has decided and given over the bell.
func _decided(ember: String = "bare") -> WorldState:
	var state := _at_corran(ember)
	_lines(state, "corran", [ASK])
	state.add_item("corrans_trap")
	_lines(state, "corran", [TRAP])
	return state


## Out at the Heron's legs.
func _out(ember: String = "bare") -> WorldState:
	var state := _decided(ember)
	_lines(state, "corran", [POLE])
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


func _travels(knot: String) -> Array:
	for step: Dictionary in _db.dialogues["corran"]["knots"][knot]:
		if step.has("travel"):
			return step["travel"]
	return []


func _shown(region_id: String, list: String, match_fn: Callable, state: WorldState) -> int:
	return (_db.get_region(region_id)[list] as Array).filter(func(e: Dictionary) -> bool:
		return match_fn.call(e) and Conditions.evaluate(e.get("if"), state)).size()


func test_corran_sends_you_for_his_far_trap() -> void:
	var state := _at_corran()
	assert_eq(state.quest_stage(QUEST), "the_heron_light", "the Heron told of")
	assert_true(_offered(state, "corran").has(ASK), "you can ask him again whether he'll take you")
	assert_false(_offered(state, "corran").has(POLE), "...but he hasn't decided")
	var pickup := func(p: Dictionary) -> bool: return str(p.get("item", "")) == "corrans_trap"
	assert_eq(_shown(FEN, "pickups", pickup, state), 0, "no trap at the end of the long walk before he asks")
	var text := _lines(state, "corran", [ASK])
	assert_true(text.contains("I don't walk where they walk"), "he won't walk the long walk")
	assert_true(text.contains("You'll want to see the boards"), "bare ember: keep it bare")
	assert_true(state.get_flag("fen_corran_trap_asked"), "asked")
	assert_eq(state.quest_stage(QUEST), "the_far_trap", "the quest says where the trap is")
	assert_false(_offered(state, "corran").has(ASK), "he's said what he wants")
	assert_true(_lines(state, "corran").contains("Still there, is it?"), "and reminds you")
	assert_eq(_shown(FEN, "pickups", pickup, state), 1, "the trap lies at the end of the long walk")
	var cupped := _at_corran("cupped")
	assert_true(_lines(cupped, "corran", [ASK]).contains("Cup the thing if you like"), "cupped: his own line")


func test_the_far_trap_lies_in_the_deeps_at_the_end_of_the_long_walk() -> void:
	_db = load_content()
	var region := _db.get_region(FEN)
	var trap: Dictionary = (region["pickups"] as Array).filter(func(p: Dictionary) -> bool: return p["item"] == "corrans_trap")[0]
	var field := TerrainField.from_data(region["ground"], float(region["water_level"]))
	var spawn: Array = region["spawn_points"]["from_ferry"]
	var reachable := field.reachable_from(float(spawn[0]), float(spawn[2]))
	assert_true(field.near_reachable(reachable, float(trap["position"][0]), float(trap["position"][2]), 1.0), "the trap can be walked to")
	assert_true(Greying.depth_at(Greying.worst_case_areas(region), _xz(trap["position"])) > 0.9, "...deep in the Deeps' fog")
	assert_true(float(trap["position"][2]) < -27.0, "at the end of the long walk")


func test_the_trap_holds_the_keepers_bell_and_corran_decides() -> void:
	var state := _at_corran()
	_lines(state, "corran", [ASK])
	assert_false(_offered(state, "corran").has(TRAP), "nothing to bring back yet")
	state.add_item("corrans_trap")
	assert_true(_offered(state, "corran").has(TRAP), "bring the trap back")
	var text := _lines(state, "corran", [TRAP])
	assert_true(text.contains("brass bell") and text.contains("off her skiff"), "the keeper's skiff bell was in it")
	assert_true(text.contains("doesn't move"), "come half a mile through still water")
	assert_true(text.contains("walked back out again. Good."), "bare: he likes that")
	assert_false(text.contains("Huh."), "...not the cupped line")
	assert_eq(state.item_count("corrans_trap"), 0, "he keeps his trap")
	assert_eq(state.item_count("heron_skiff_bell"), 1, "and gives you her bell")
	assert_true(state.get_flag("fen_corran_decided"), "he's decided")
	assert_eq(state.quest_stage(QUEST), "out_to_the_heron", "the quest moves on")
	assert_true(_offered(state, "corran").has(POLE), "he'll pole you out")
	assert_false(_offered(state, "corran").has(POLE_AGAIN), "...for the first time")
	assert_true(_lines(state, "corran").contains("Punt's off the landing"), "his greeting changes")
	var cupped := _at_corran("cupped")
	_lines(cupped, "corran", [ASK])
	cupped.add_item("corrans_trap")
	assert_true(_lines(cupped, "corran", [TRAP]).contains("the way she asked you"), "cupped: his own line")
	var never := _at_corran("")
	_lines(never, "corran", [ASK])
	never.add_item("corrans_trap")
	var plain := _lines(never, "corran", [TRAP])
	assert_false(plain.contains("walked back out again. Good.") or plain.contains("the way she asked you"), "no ember answer: neither line")
	assert_true(never.get_flag("fen_corran_decided"), "...and he decides all the same")


func test_corran_poles_you_out_to_the_heron_and_back() -> void:
	var state := _decided()
	var text := _lines(state, "corran", [POLE])
	assert_true(text.contains("Don't talk. I'm counting.") and text.contains("knot"), "the first trip is the full scene")
	assert_true(text.contains("It turns away"), "bare: an Unmoored face turns from the ember")
	assert_true(state.get_flag("fen_heron_reached") and state.get_flag("fen_punt_out"), "out in the punt")
	assert_eq(state.quest_stage(QUEST), "at_the_legs", "at the legs")
	assert_eq(_travels("pole_out"), [MERE, "from_punt"], "the punt travels to the Heron's legs")
	assert_true(_db.get_region(MERE)["spawn_points"].has("from_punt"), "...landing at the Foot")
	# Out there Corran waits by the punt and talks of the mere.
	var offered := _offered(state, "corran")
	assert_true(offered.has(BACK) and offered.has("Why does the fog stand off the legs?"), "the mere talk")
	assert_false(offered.has(POLE_AGAIN), "no poling out from out here")
	_lines(state, "corran", [BACK])
	assert_false(state.get_flag("fen_punt_out"), "poled back")
	assert_eq(_travels("pole_back"), [FEN, "from_punt"], "...to his landing")
	assert_true(_db.get_region(FEN)["spawn_points"].has("from_punt"), "...which has a spawn")
	assert_true(_offered(state, "corran").has(POLE_AGAIN), "and he'll go again")
	var again := _lines(state, "corran", [POLE_AGAIN])
	assert_false(again.contains("I'm counting"), "the second trip is one line")
	assert_true(state.get_flag("fen_punt_out"), "out again")
	assert_eq(_travels("pole_again"), [MERE, "from_punt"], "...to the legs")
	var cupped := _decided("cupped")
	assert_false(_lines(cupped, "corran", [POLE]).contains("It turns away"), "cupped: nobody turns")


func test_corran_and_his_punt_are_where_the_punt_is() -> void:
	var state := _decided()
	var corran := func(n: Dictionary) -> bool: return n["npc"] == "corran"
	var punt := func(p: Dictionary) -> bool: return str(p.get("model", "")).ends_with("/punt.glb")
	assert_eq(_shown(FEN, "npcs", corran, state), 1, "Corran at his landing")
	assert_eq(_shown(MERE, "npcs", corran, state), 0, "...not out at the legs")
	assert_eq(_shown(FEN, "props", punt, state), 1, "his punt off the landing")
	assert_eq(_shown(MERE, "props", punt, state), 0, "...not at the Foot")
	_lines(state, "corran", [POLE])
	assert_eq(_shown(FEN, "npcs", corran, state), 0, "out: not at his landing")
	assert_eq(_shown(MERE, "npcs", corran, state), 1, "...but by the Foot")
	assert_eq(_shown(FEN, "props", punt, state), 0, "the punt gone from the landing")
	assert_eq(_shown(MERE, "props", punt, state), 1, "...run in at the Foot")


func test_the_heron_mere_layout() -> void:
	_db = load_content()
	var region := _db.get_region(MERE)
	var field := TerrainField.from_data(region["ground"], float(region["water_level"]))
	var spawn: Array = region["spawn_points"]["from_punt"]
	var reachable := field.reachable_from(float(spawn[0]), float(spawn[2]))
	var areas := Greying.worst_case_areas(region)
	assert_true(Greying.depth_at(areas, _xz(spawn)) < Greying.CLEAR_DEPTH, "the Foot is clear: the fog stands off the legs")
	assert_eq(region["exits"].size(), 0, "no way off but the punt")
	for object: Dictionary in region["objects"]:
		assert_true(field.near_reachable(reachable, float(object["position"][0]), float(object["position"][2]), 1.5), "%s can be walked to" % object["id"])
		assert_true(Greying.depth_at(areas, _xz(object["position"])) < Greying.CLEAR_DEPTH, "%s is in the clear" % object["id"])
	for who: Dictionary in region["npcs"]:
		assert_true(field.near_reachable(reachable, float(who["position"][0]), float(who["position"][2]), 1.5), "%s can be walked to" % who["npc"])
	# The Heron up close: the stage runs out to the ladder leg; the skiff is by the mud bar's end.
	var heron: Dictionary = (region["props"] as Array).filter(func(p: Dictionary) -> bool: return str(p["model"]).ends_with("/heron_light.glb"))[0]
	var at := _xz(heron["position"])
	assert_eq(float(heron["rotation_y"]), 0.0, "the ladder faces the Foot")
	var ladder_foot := at + Vector2(-1.6, 1.85)  # the model's front-left leg, ladder side
	var skiff := at + Vector2(2.6, -1.2)
	assert_true(field.near_reachable(reachable, ladder_foot.x, ladder_foot.y, 1.0), "the stage reaches the ladder")
	assert_false(field.near_reachable(reachable, at.x, at.y, 1.2), "...but not in among the legs")
	var objects := {}
	for object: Dictionary in region["objects"]:
		objects[object["id"]] = object
	assert_true(_xz(objects["heron_ladder"]["position"]).distance_to(ladder_foot) < 1.0, "the ladder's look-at is at its foot")
	var skiff_spot := _xz(objects["heron_skiff"]["position"])
	assert_true(skiff_spot.distance_to(skiff) < 3.0, "the skiff's look-at is by the skiff (%.1f m)" % skiff_spot.distance_to(skiff))
	# Further in: the Unmoored in the fog, out of reach; the big man at the fog's foot.
	var figures := (region["props"] as Array).filter(func(p: Dictionary) -> bool: return p.has("idle"))
	var unmoored := figures.filter(func(p: Dictionary) -> bool: return str(p["model"]).contains("unmoored_"))
	assert_true(unmoored.size() >= 2, "Unmoored further in")
	for figure: Dictionary in figures:
		assert_false(field.near_reachable(reachable, float(figure["position"][0]), float(figure["position"][2]), 1.5), "%s is out of reach" % figure["model"])
	for figure: Dictionary in unmoored:
		assert_true(Greying.depth_at(areas, _xz(figure["position"])) > 0.7, "the Unmoored sit inside the fog")
	var big: Array = figures.filter(func(p: Dictionary) -> bool: return str(p["model"]) == CHARS + "dunstan.glb")
	assert_eq(big.size(), 1, "the big man stands out there")
	var edge := Greying.depth_at(areas, _xz(big[0]["position"]))
	assert_true(edge > Greying.CLEAR_DEPTH and edge < 0.6, "...at the foot of the fog, not in it (%.2f)" % edge)
	assert_true(_xz(objects["heron_glimpse"]["position"]).distance_to(_xz(big[0]["position"])) < 20.0, "seen from the Foot's edge")
	assert_eq(big[0]["if"], "!flag:fen_dunstan_glimpsed", "he goes once glimpsed")
	assert_eq(objects["heron_glimpse"]["if"], "!flag:fen_dunstan_glimpsed", "...and there is nothing more to look at")


func test_the_big_man_at_the_fogs_edge() -> void:
	var state := _out()
	var offered: Array[String] = []
	var text := _lines(state, "heron_glimpse", ["Call out: \"Dunstan!\""], offered)
	assert_true(text.contains("big man") and text.contains("It isn't lit"), "a big man, a dark lantern")
	assert_true(offered.has("Say nothing. Watch him.") and not offered.has("Call out his name."), "his name to call")
	assert_true(text.contains("He doesn't turn") and text.contains("gone"), "he stops, doesn't turn, goes")
	assert_eq(state.get_flag("fen_dunstan_glimpsed"), "called")
	assert_false(text.contains("flicks red"), "no word of Mara's on him")
	assert_true(_offered(state, "corran").has("I saw a man out there. Big, with a lantern that wasn't lit."), "tell Corran")
	assert_true(_lines(state, "corran", ["I saw a man out there. Big, with a lantern that wasn't lit."]).contains("for after"),
			"Corran knows the whittler's lantern")
	# Mara's word on the letting post: a red cord at his belt as he goes.
	var word := _out()
	word.set_flag("fen_dunstan_word", "mara")
	assert_true(_lines(word, "heron_glimpse", ["Say nothing. Watch him."]).contains("flicks red"), "he took Mara's word")
	assert_eq(word.get_flag("fen_dunstan_glimpsed"), "watched")
	# After the gull burn his name won't hold.
	var gull := _out()
	gull.set_flag("saltmarrow_beacon_burned", "gull")
	offered = []
	var nameless := _lines(gull, "heron_glimpse", ["Call out his name."], offered)
	assert_false(offered.has("Call out: \"Dunstan!\""), "no name to call after the gull burn")
	assert_true(nameless.contains("rain off a coat"), "it goes past you")
	assert_false(nameless.contains("Dunstan"), "and isn't said")
	assert_eq(gull.get_flag("fen_dunstan_glimpsed"), "nameless")
	assert_true(_offered(gull, "corran").has("I saw a man out there. I couldn't hold his name."), "Corran hears it")
	# Never told his name: call out to him all the same.
	var untold := _out()
	untold.set_flag("saltmarrow_mara_told_of_dunstan", false)
	assert_true(_offered(untold, "heron_glimpse").has("Call out to him."), "untold: call out to him")


func test_the_keepers_skiff_and_her_bell() -> void:
	var state := _out()
	var text := _lines(state, "heron_skiff", ["Tie the bell back on her bow."])
	assert_true(text.contains("oil") and text.contains("full"), "her lantern is full: she didn't run out")
	assert_true(text.contains("mean to come back"), "tied up to come back to")
	assert_eq(state.get_flag("fen_skiff_bell"), "hung")
	assert_eq(state.item_count("heron_skiff_bell"), 0, "the bell is back on her bow")
	assert_true(_lines(state, "heron_skiff").contains("hangs at her bow again"), "and stays there")
	var kept := _out()
	_lines(kept, "heron_skiff", ["Keep the bell."])
	assert_eq(kept.get_flag("fen_skiff_bell"), "kept")
	assert_eq(kept.item_count("heron_skiff_bell"), 1, "kept")
	assert_true(_lines(kept, "heron_skiff").contains("It's in your satchel"), "the hole where it hung")
	var later := _out()
	_lines(later, "heron_skiff", ["Not yet."])
	assert_eq(later.get_flag("fen_skiff_bell"), "", "not yet: undecided")
	assert_true(_offered(later, "heron_skiff").has("Keep the bell."), "...and asked again")


func test_the_ladder_is_climbed_lately() -> void:
	var state := _out()
	var first := _lines(state, "heron_ladder")
	assert_true(first.contains("scraped pale") and first.contains("Lately"), "somebody climbs it, lately")
	assert_true(first.contains("Not today"), "Corran: not today")
	assert_true(state.get_flag("fen_heron_ladder_seen"))
	assert_false(_lines(state, "heron_ladder").contains("Not today"), "he says it once")


func test_the_heron_mere_checkpoint() -> void:
	_db = load_content()
	var resolved := Scenarios.resolve(MERE)
	assert_false(resolved.is_empty(), "a checkpoint for the Heron's legs")
	var state := fresh_state(_db)
	Scenarios.apply(_db, state, resolved)
	assert_true(state.get_flag("fen_punt_out"), "out in the punt")
	assert_eq(state.quest_stage(QUEST), "at_the_legs")
	assert_eq(state.item_count("heron_skiff_bell"), 1, "with the bell to hang or keep")
