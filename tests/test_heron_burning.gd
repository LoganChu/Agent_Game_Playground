extends TestCase
## Day 35 — The Heron Light, part two: back from the legs, Hesper tells of a small light that goes
## up the Heron's ladder some nights (the reason); Corran holds the foot on a dry day and the
## Wakebearer climbs to the cradle — cold put-down things in it, a whittled gull on its rim, the
## keeper's coat folded on the boards; it won't burn what nobody holds. Glasswater's burning:
## Hesper's name or Corran's channels. The lit Heron, the fog leaning back, the lantern lit out in
## the fog, the bell ringing, and Hesper and Corran after.

const FEN := "glasswater_fen"
const MERE := "heron_mere"
const QUEST := "a_light_for_glasswater"
const DIR := "res://assets/models/dressing/"
const HERON := "Tell me about the Heron Light."
const ASK := "Will you take me out to the Heron now?"
const TRAP := "I lifted your far trap."
const POLE := "Pole me out to the Heron."
const POLE_AGAIN := "Pole me out to the Heron again."
const BACK := "Take me back."
const TOLD := "I've been out to the Heron."
const HOLDS := "The Heron wants something somebody here still holds."
const GIVE_NAME := "Give it, Hesper. For the light."
const GIVE_CORD := "Give it, Corran. For the light."
const BURN_NAME := ["Set Hesper's name in the cradle.", "Burn Hesper's name."]
const BURN_CORD := ["Set Corran's knot-cord in the cradle.", "Burn Corran's channels."]

var _db: ContentDatabase


## Out at the Heron's legs for the first time (part one done): the bell hung or kept, the big man
## glimpsed (`glimpse`), the ladder looked at.
func _out(bell: String = "hung", glimpse: String = "watched") -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "thornwold_landed", "fen_landed", "fen_met_hesper",
			"fen_met_corran", "fen_heard_of_dunstan", "saltmarrow_mara_told_of_dunstan"]:
		state.set_flag(flag, true)
	state.set_flag("lanes_ferry_at", "fen")
	state.set_flag("fen_ember", "bare")
	state.complete_quest("a_light_for_thornwold")
	_lines(state, "corran", [HERON])
	_lines(state, "corran", [ASK])
	state.add_item("corrans_trap")
	_lines(state, "corran", [TRAP])
	_lines(state, "corran", [POLE])
	if bell == "hung":
		_lines(state, "heron_skiff", ["Tie the bell back on her bow."])
	elif bell == "kept":
		_lines(state, "heron_skiff", ["Keep the bell."])
	state.set_flag("fen_dunstan_glimpsed", glimpse)
	_lines(state, "heron_ladder")
	return state


## Back at the landing, Hesper told about the trip, out again with a reason.
func _with_a_reason(bell: String = "hung", glimpse: String = "watched") -> WorldState:
	var state := _out(bell, glimpse)
	_lines(state, "corran", [BACK])
	_lines(state, "hesper", [TOLD])
	_lines(state, "corran", [POLE_AGAIN])
	return state


## Up the ladder: the cradle found.
func _climbed(bell: String = "hung") -> WorldState:
	var state := _with_a_reason(bell)
	_lines(state, "heron_ladder", ["Climb."])
	return state


## Climbed, and both Remnants given (Corran's at the legs, Hesper's back at the staithe), out again.
func _both_given() -> WorldState:
	var state := _climbed()
	_lines(state, "corran", [HOLDS, GIVE_CORD])
	_lines(state, "corran", [BACK])
	_lines(state, "hesper", [HOLDS, GIVE_NAME])
	_lines(state, "corran", [POLE_AGAIN])
	return state


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_db, state, dialogue, typed, offered)


func _offered(state: WorldState, dialogue: String) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [], offered)
	return offered


func _shown(region_id: String, model: String, state: WorldState) -> int:
	return (_db.get_region(region_id)["props"] as Array).filter(func(p: Dictionary) -> bool:
		return str(p.get("model", "")) == DIR + model + ".glb" and Conditions.evaluate(p.get("if"), state)).size()


func test_hesper_tells_of_the_light_on_the_ladder() -> void:
	var state := _out("hung", "called")
	_lines(state, "corran", [BACK])
	var text := _lines(state, "hesper", [TOLD])
	assert_true(text.contains("Small. It goes up the legs"), "a small light goes up the ladder some nights")
	assert_true(text.contains("bell back on her bow"), "she knows the bell was hung")
	assert_true(text.contains("not finished"), "...and that he stopped when called")
	assert_true(text.contains("somebody climbs the ladder"), "...and the ladder was looked at")
	assert_eq(state.quest_stage(QUEST), "up_the_ladder", "a reason to climb")
	assert_true(state.get_flag("fen_hesper_heard_heron"))
	assert_false(_offered(state, "hesper").has(TOLD), "told once")
	var kept := _out("kept", "nameless")
	_lines(kept, "corran", [BACK])
	var kept_text := _lines(kept, "hesper", [TOLD])
	assert_true(kept_text.contains("Don't ring it on my staithe"), "kept: don't ring it")
	assert_true(kept_text.contains("couldn't hold his name"), "nameless: she could; she won't")
	var before := fresh_state(load_content())
	before.set_flag("fen_met_hesper", true)
	assert_false(_offered(before, "hesper").has(TOLD), "not before the trip out")


func test_the_dry_day_and_the_climb() -> void:
	var state := _with_a_reason()
	var waiting := _lines(state, "heron_ladder", ["Not yet."])
	assert_true(waiting.contains("Dry as it'll get") and waiting.contains("hold the foot"), "Corran holds the foot")
	assert_eq(state.quest_stage(QUEST), "up_the_ladder", "not yet: still at the foot")
	var text := _lines(state, "heron_ladder", ["Climb."])
	for bit: String in ["child's shoe", "whittled gull", "Dunstan's", "keeper's coat", "nobody remembers", "Hesper's name, or my channels"]:
		assert_true(text.contains(bit), "up the ladder: " + bit)
	assert_false(text.contains("red cord"), "no red cord when Mara's word wasn't left")
	assert_true(state.get_flag("fen_heron_climbed"))
	assert_eq(state.quest_stage(QUEST), "feed_the_heron", "the Heron wants something held")
	assert_true(_lines(state, "heron_ladder").contains("You have nothing to set in it"), "nothing to set in it yet")


func test_the_gull_in_the_cradle_honours_earlier_choices() -> void:
	var mara := _with_a_reason()
	mara.set_flag("fen_dunstan_word", "mara")
	assert_true(_lines(mara, "heron_ladder", ["Climb."]).contains("a bit of red cord"), "Mara's word round the gull's neck")
	var gull := _with_a_reason()
	gull.set_flag("saltmarrow_beacon_burned", "gull")
	var text := _lines(gull, "heron_ladder", ["Climb."])
	assert_false(text.contains("Dunstan"), "after the gull burn his name isn't held")
	assert_true(text.contains("rain off a coat"), "...it goes past")


func test_hesper_gives_her_name_and_corran_his_channels() -> void:
	var state := _climbed()
	var offered := _offered(state, "corran")
	assert_true(offered.has(HOLDS) and offered.has(BACK), "Corran asked at the legs, with the way back still on offer")
	var cord := _lines(state, "corran", [HOLDS, GIVE_CORD], offered)
	assert_true(cord.contains("heavier than a cord"), "the cord goes silver in the fog")
	assert_eq(state.item_count("corrans_knot_cord"), 1)
	assert_true(state.get_flag("fen_corran_cord_away"))
	assert_true(state.get_flag("fen_punt_out"), "still out at the legs")
	assert_false(_offered(state, "corran").has(HOLDS), "given once")
	_lines(state, "corran", [BACK])
	var kept := _lines(state, "hesper", [HOLDS, "No. Keep it."])
	assert_true(kept.contains("That much I kept"), "her name is the last thing she kept")
	assert_eq(state.item_count("hespers_name"), 0, "kept")
	var given := _lines(state, "hesper", [HOLDS, GIVE_NAME])
	assert_true(given.contains("doesn't come back off the water"), "she says it out over the pool until it's gone")
	assert_eq(state.item_count("hespers_name"), 1)
	assert_true(state.get_flag("fen_hesper_name_away"))
	assert_false(_offered(_out(), "hesper").has(HOLDS), "not asked before the climb")


func test_burning_hespers_name() -> void:
	var state := _both_given()
	var text := _lines(state, "heron_ladder", BURN_NAME)
	assert_eq(state.quest_state(QUEST), WorldState.QUEST_DONE, "the Heron is lit")
	assert_eq(state.get_flag("fen_beacon_burned"), "name")
	assert_eq(state.item_count("hespers_name"), 0, "burned")
	for bit: String in ["aren't yours to burn", "The Heron Light catches", "bell on her bow rings once",
			"a light comes on", "For after", "meeting nobody"]:
		assert_true(text.contains(bit) or text.contains(bit.replace("For after", "for after")), "the burn: " + bit)
	assert_false(text.contains("In your satchel the keeper's bell"), "the bell was hung, not kept")
	assert_true(_lines(state, "heron_ladder").contains("a lettered reed"), "lit, after")
	assert_true(_lines(state, "hesper").contains("looks over her shoulder"), "she has no name now")
	var offered := _offered(state, "corran")
	assert_true(offered.has("Your knot-cord. I didn't burn it."), "the unburned cord can go back")
	_lines(state, "corran", ["Your knot-cord. I didn't burn it."])
	assert_eq(state.item_count("corrans_knot_cord"), 0, "given back")
	assert_false(state.get_flag("fen_corran_cord_away"))
	_lines(state, "corran", [BACK])
	assert_true(_offered(state, "corran").has(POLE_AGAIN), "he can still pole you out")
	assert_true(_lines(state, "corran", [POLE_AGAIN]).contains("hole in the fog"), "...and does")


func test_burning_corrans_channels() -> void:
	var state := _both_given()
	_lines(state, "heron_skiff")
	var text := _lines(state, "heron_ladder", BURN_CORD)
	assert_eq(state.get_flag("fen_beacon_burned"), "channels")
	assert_true(text.contains("as if he has never seen it before"), "Corran forgets the channels")
	var back := _lines(state, "corran", [BACK])
	assert_true(back.contains("no cord to count back") and not back.contains("counts the knots back"), "poled back by the light")
	var refused := _lines(state, "corran", [POLE_AGAIN])
	assert_true(refused.contains("can't see the way to it"), "nobody poles out there now")
	assert_false(state.get_flag("fen_punt_out"), "...and he doesn't")
	assert_true(_offered(state, "hesper").has("I didn't burn your name. Here."), "the unburned name can go back")
	assert_true(_lines(state, "hesper", ["I didn't burn your name. Here."]).contains("She can read it"), "given back")
	assert_false(state.get_flag("fen_hesper_name_away"))


func test_a_kept_bell_rings_in_the_satchel() -> void:
	var state := _climbed("kept")
	_lines(state, "hesper", [HOLDS, GIVE_NAME])
	var text := _lines(state, "heron_ladder", BURN_NAME)
	assert_true(text.contains("In your satchel the keeper's bell rings once"), "the kept bell rings")
	assert_false(text.contains("bell on her bow"), "...not on her bow")


func test_the_heron_lit_in_both_regions() -> void:
	_db = load_content()
	var cold := fresh_state(_db)
	var lit := fresh_state(_db)
	lit.complete_quest(QUEST)
	for pair: Array in [[FEN, "heron_light"], [MERE, "heron_light_near"]]:
		assert_true(ResourceLoader.exists(DIR + pair[1] + "_lit.glb"), "%s_lit is built" % pair[1])
		assert_eq(_shown(pair[0], pair[1], cold) + _shown(pair[0], pair[1] + "_lit", cold), 1, "%s: one Heron, cold" % pair[0])
		assert_eq(_shown(pair[0], pair[1], cold), 1, "cold before")
		assert_eq(_shown(pair[0], pair[1] + "_lit", lit), 1, "%s: lit after" % pair[0])
		assert_eq(_shown(pair[0], pair[1], lit), 0, "and the cold one gone")
		assert_true(float(RegionMood.fog(_db.get_region(pair[0]), lit)["density"]) < float(RegionMood.fog(_db.get_region(pair[0]), cold)["density"]),
				"%s: the fog thins" % pair[0])
	var near: Dictionary = (_db.get_region(MERE)["props"] as Array).filter(func(p: Dictionary) -> bool:
		return str(p["model"]).ends_with("heron_light_near_lit.glb"))[0]
	assert_true(near.has("light") and near.has("halo"), "the lit Heron lights the Foot")


func test_the_fog_leans_back_but_not_from_stillhithe() -> void:
	_db = load_content()
	var cold := fresh_state(_db)
	var lit := fresh_state(_db)
	lit.complete_quest(QUEST)
	for region_id: String in [FEN, MERE]:
		var region := _db.get_region(region_id)
		var deep_cold := 0.0
		var deep_lit := 0.0
		for area: Dictionary in region["greying"]:
			if area.has("rect"):
				if Conditions.evaluate(area.get("if"), cold):
					deep_cold = maxf(deep_cold, float(area["strength"]))
				if Conditions.evaluate(area.get("if"), lit):
					deep_lit = maxf(deep_lit, float(area["strength"]))
		assert_eq(deep_cold, 1.0, "%s: deep before" % region_id)
		assert_true(deep_lit > 0.0 and deep_lit <= 0.5, "%s: leaning back after (%.2f)" % [region_id, deep_lit])
	var stillhithe: Array = (_db.get_region(FEN)["greying"] as Array).filter(func(a: Dictionary) -> bool: return a.has("ellipse"))
	assert_eq(stillhithe.size(), 1, "Stillhithe's thin Greying")
	assert_false((stillhithe[0] as Dictionary).has("if"), "...stays, as if it had been asked to")


func test_the_heron_lit_checkpoint() -> void:
	_db = load_content()
	var resolved := Scenarios.resolve("heron_lit")
	assert_false(resolved.is_empty(), "a checkpoint for the lit Heron")
	var state := fresh_state(_db)
	Scenarios.apply(_db, state, resolved)
	assert_eq(state.quest_state(QUEST), WorldState.QUEST_DONE)
	assert_eq(state.get_flag("fen_beacon_burned"), "name")
	assert_eq(state.item_count("heron_skiff_bell"), 0, "the bell is on her bow")
	assert_eq(_shown(MERE, "keeper_skiff_bell", state), 1, "...and shows there")
