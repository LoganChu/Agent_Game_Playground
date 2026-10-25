extends TestCase
## Day 64 — Kindleby, part two: the chapter sits. It can't while anybody is on the candles, so the
## Wakebearer's ember holds the ring from the crown for an hour; the chapter chooses Kindleby's night of
## the boats and old Brother Anselm carries the Boats' Lantern out into the fog; the skiff goes north if
## the Provost was told of the Northing's stage. Tobin offers his coal-pan instead. Kindleby's burning,
## the rite kept or broken, and the island after.

const BY := "kindleby"
const LIGHT := "What would it take to light the Vigil Light?"
const BOW := "I'll bow to the rite."
const REFUSE := "I'll choose, as I've chosen everywhere."
const STAGE := "There are colliers on the Northing's boat-stage, waiting for the Spire's boat. I promised I'd tell the Spire."
const OFFER := "My ember could hold the ring while the chapter sits."
const WHY := "Why can't the chapter just sit?"
const WEIGHED := "What else did the chapter weigh?"
const SPARE := "What would you spare, if you were choosing?"
const CARRY := "I'll carry it."
const KEEP := "Keep it, Tobin."
const BACK := "Here. Your coal-pan back."
const SET_BOATS := "Set the Boats' Lantern in the cradle."
const SET_PAN := "Set Tobin's coal-pan in the cradle."
const BURN_BOATS := "Burn Kindleby's night of the boats."
const BURN_PAN := "Burn Tobin's calling."
const QUIET := "Who's in the Quiet House?"
const SPIRE := "Have you been to the Spire?"
const KIT := "res://assets/models/dressing/"

var _db: ContentDatabase


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_db, state, dialogue, typed, offered)


func _offered(state: WorldState, dialogue: String) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [], offered)
	return offered


## On Kindleby with the Provost met and the rite answered (`bowed` / `refused`): the chapter will sit.
## `told` kept the far shore's promise first.
func _answered(rite: String, told: bool = false) -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "thornwold_landed", "fen_landed", "wrackholm_landed",
			"wrackholm_oda_lane_asked", "kindleby_landed"]:
		state.set_flag(flag, true)
	state.set_flag("saltmarrow_beacon_burned", "knot")
	state.set_flag("thornwold_beacon_burned", "boots")
	state.set_flag("fen_beacon_burned", "channels")
	state.set_flag("wrackholm_beacon_burned", "board")
	state.set_flag("lanes_ferry_at", BY)
	state.set_flag("thornwold_far_shore", "waiting" if told else "up")
	for quest: String in ["across_the_grey", "a_light_for_thornwold", "a_light_for_glasswater", "a_light_for_wrackholm"]:
		state.complete_quest(quest)
	state.start_quest("a_light_for_kindleby", "the_candles")
	_lines(state, "provost")
	if told:
		_lines(state, "provost", [STAGE])
	_lines(state, "provost", [LIGHT, BOW if rite == "bowed" else REFUSE])
	assert_eq(state.quest_stage("a_light_for_kindleby"), "the_chapter")
	return state


## The ring held and the chapter's choice made: the Wakebearer on the crown with the Boats' Lantern.
func _chosen(rite: String, told: bool = false) -> WorldState:
	var state := _answered(rite, told)
	_lines(state, "provost", [OFFER])
	_lines(state, "vigil_door")
	assert_eq(state.quest_stage("a_light_for_kindleby"), "feed_the_light")
	return state


func _shown(model: String, state: WorldState) -> int:
	var n := 0
	for p: Dictionary in _db.get_region(BY)["props"]:
		if str(p.get("model", "")) == KIT + model + ".glb" and Conditions.evaluate(p.get("if"), state):
			n += 1
	return n


## How deep the fog is just past the north wall (the ring is at z -13.6).
func _fog_past_the_wall(state: WorldState) -> float:
	return Greying.depth_at(Greying.active_areas(_db.get_region(BY), state), Vector2(0, -19))


func test_the_chapter_cannot_sit_till_the_ember_holds_the_ring() -> void:
	var state := _answered("bowed")
	var why := _lines(state, "tobin", [WHY])
	assert_true(why.contains("forty candles to each of us") and why.contains("That's yours."), "Tobin all but says it")
	assert_true(_offered(state, "provost").has(OFFER), "the offer, once the chapter will sit")
	var vigil := _lines(state, "vigil_door")
	assert_true(vigil.contains("locked"), "the door stays locked till the ring's held")
	var text := _lines(state, "provost", [OFFER])
	assert_true(text.contains("...It could. Couldn't it.") and text.contains("stand by the Vigil Light"), text)
	assert_false(text.contains("I don't understand you"), "that's for the refusal")
	assert_eq(state.quest_stage("a_light_for_kindleby"), "hold_the_ring")
	assert_false(_offered(state, "provost").has(OFFER), "offered once")
	assert_false(_offered(state, "tobin").has(WHY), "and Tobin's done wondering")
	assert_true(_lines(state, "provost").contains("The crown, Wakebearer."), "she sends you up")
	assert_true(_lines(state, "tobin").contains("I'll run, when the bell goes."))
	var refused := _answered("refused")
	assert_true(_lines(refused, "provost", [OFFER]).contains("I don't understand you, Wakebearer. Thank you."), "refused, and holds the door anyway")


func test_holding_the_ring() -> void:
	for told: bool in [false, true]:
		for rite: String in ["bowed", "refused"]:
			var state := _answered(rite, told)
			_lines(state, "provost", [OFFER])
			var held := _lines(state, "vigil_door")
			assert_true(held.contains("The fog doesn't come.") and held.contains("cold and silver"), "the hour on the crown")
			assert_true(held.contains("Kindleby can spare a night.") and held.contains("Brother Anselm rowed that boat."), "the chapter's choice")
			assert_eq(held.contains("Carry it up."), rite == "bowed", "%s: carry it up" % rite)
			assert_eq(held.contains("look at it while you're deciding"), rite == "refused", "%s: or don't" % rite)
			assert_true(state.get_flag("kindleby_ring_held") == true)
			assert_true((state.item_count("boats_lantern") > 0), "the Boats' Lantern in hand")
			assert_eq(state.quest_stage("a_light_for_kindleby"), "feed_the_light")
			assert_eq(held.contains("row north into the fog"), told, "the skiff goes north only if she was told (%s)" % told)
			assert_eq(state.get_flag("kindleby_skiff_north") == true, told)
			assert_eq(_shown("keeper_skiff", state), 0 if told else 1, "the skiff gone from the shingle (%s)" % told)
			assert_eq(_lines(state, "tobin").contains("The skiff's gone north"), told)
			var cradle := _lines(state, "vigil_door", ["Not yet."])
			assert_true(cradle.contains("The chapter's choice.") and not cradle.contains("Tobin's coal-pan"), "up the stair")
			assert_eq(state.quest_stage("a_light_for_kindleby"), "feed_the_light", "not yet leaves it waiting")


func test_what_the_chapter_weighed() -> void:
	var state := _chosen("bowed")
	assert_true(_lines(state, "provost").contains("nothing to add to what the chapter said"))
	var weighed := _lines(state, "provost", [WEIGHED, "It's the only night anybody here saw what happened at the Spire."])
	assert_true(weighed.contains("the Long Book, and wouldn't") and weighed.contains("the candles"), "what else they weighed")
	assert_true(weighed.contains("Is it? They've never said.") and weighed.contains("I never asked them"), "and what she never asked")


func test_tobins_coal_pan() -> void:
	var state := _chosen("refused")
	assert_true(_lines(state, "tobin").contains("Brother Anselm's been crying."))
	var kept := _lines(state, "tobin", [SPARE, KEEP])
	assert_true(kept.contains("Mine's only mine.") and kept.contains("It'll keep."), kept)
	assert_false((state.item_count("tobins_pan") > 0), "kept")
	_lines(state, "tobin", [SPARE, CARRY])
	assert_true((state.item_count("tobins_pan") > 0), "carried")
	assert_false(_offered(state, "tobin").has(SPARE), "asked while he still has it")
	var offered: Array[String] = []
	var cradle := _lines(state, "vigil_door", ["Not yet."], offered)
	assert_true(cradle.contains("his name scratched in the lid"))
	assert_true(offered.has(SET_BOATS) and offered.has(SET_PAN), "two things to set in the cradle")
	var weighed := _lines(state, "vigil_door", [SET_PAN, "No. Not this.", "Not yet."])
	assert_true(weighed.contains("Tobin Ashe will never have been called"), weighed)
	assert_false(weighed.contains("You bowed to the rite."), "refused: no reminder")
	var bowed := _chosen("bowed")
	_lines(bowed, "tobin", [SPARE, CARRY])
	assert_true(_lines(bowed, "vigil_door", [SET_PAN, "No. Not this.", "Not yet."]).contains("The chapter's choice is still in your other hand. You bowed"))
	assert_true(_lines(bowed, "vigil_door", [SET_BOATS, "No. Not this.", "Not yet."]).contains("The chapter chose it. You bowed."))


func test_kindlebys_burning() -> void:
	for rite: String in ["bowed", "refused"]:
		for burn: String in ["boats", "pan"]:
			var state := _chosen(rite)
			var dark_fog := _fog_past_the_wall(state)
			assert_true(dark_fog > 0.0, "the fog a cable's width off")
			assert_false(Lanes.port_lit(_db, state, BY), "dark on the chart")
			_lines(state, "tobin", [SPARE, CARRY])
			var lit := _lines(state, "vigil_door", [SET_BOATS if burn == "boats" else SET_PAN, BURN_BOATS if burn == "boats" else BURN_PAN])
			var case := "%s/%s" % [rite, burn]
			assert_eq(state.get_flag("kindleby_beacon_burned"), burn, case)
			assert_eq(state.quest_state("a_light_for_kindleby"), WorldState.QUEST_DONE, case)
			assert_true(lit.contains("The Vigil Light catches.") and lit.contains("the Taper's channel"), case)
			assert_eq(lit.contains("A face turned up the steps toward you that you almost know."), burn == "boats", case)
			assert_eq(lit.contains("wiping his face"), burn == "pan", case)
			assert_eq((state.item_count("boats_lantern") > 0), burn == "pan", "%s: the other Remnant stays in hand" % case)
			assert_false((state.item_count("tobins_pan") > 0) and burn == "pan", case)
			# The island after: the light lit, the fog leaned back, the chart.
			assert_true(Lanes.port_lit(_db, state, BY), "%s: lit on the chart" % case)
			assert_eq(_shown("vigil_light", state), 0, case)
			assert_eq(_shown("vigil_light_lit", state), 1, case)
			assert_true(_fog_past_the_wall(state) < dark_fog, "%s: the fog leans back (%.2f < %.2f)" % [case, _fog_past_the_wall(state), dark_fog])
			assert_true(RegionMood.light(_db.get_region(BY), state)["sun_energy"] > 0.6, "%s: the light warms" % case)
			assert_true(_lines(state, "vigil_door").contains("burns gold"), "%s: the lit lantern room" % case)
			var provost := _lines(state, "provost")
			assert_eq(provost.contains("Done properly. Once."), rite == "bowed" and burn == "boats", case)
			assert_eq(provost.contains("You chose as the chapter chose."), rite == "refused" and burn == "boats", case)
			assert_eq(provost.contains("kept, and broken, the same night"), rite == "bowed" and burn == "pan", case)
			assert_eq(provost.contains("asked why he'd been crying"), rite == "refused" and burn == "pan", case)
			assert_true(provost.contains("Five lights, Wakebearer."), case)
			assert_false(provost.contains("The chapter will sit. I've said so") or provost.contains("Still choosing"), "%s: the rite's greeting is past" % case)
			var quiet := _lines(state, "provost", [QUIET])
			assert_eq(quiet.contains("How the old ones came to us, I couldn't tell you."), burn == "boats", case)
			assert_eq(quiet.contains("came over in the boats Hushed"), burn == "pan", case)
			var tobin := _lines(state, "tobin", [SPIRE])
			assert_eq(tobin.contains("I was to be called up"), burn == "boats", "%s: Tobin's calling" % case)
			assert_eq(tobin.contains("I've always kept candles."), burn == "pan", case)
			assert_eq(tobin.contains("asked Brother Anselm what for"), burn == "boats", case)
			var oda := _lines(state, "oda", ["Not yet."])
			assert_true(oda.contains("Five lights. Every one of them yours"), "%s: Oda counts five" % case)
			assert_false(oda.contains("one of them tallow") or oda.contains("You bowed to their rite") or oda.contains("You told Lorn no"), case)
			assert_eq(oda.contains("They've forgotten the boats."), burn == "boats", "%s: an off-islander keeps it" % case)
			assert_eq(oda.contains("doesn't remember he was ever going anywhere"), burn == "pan", case)


func test_the_pan_handed_back() -> void:
	var state := _chosen("bowed")
	_lines(state, "tobin", [SPARE, CARRY])
	assert_false(_offered(state, "tobin").has(BACK), "not while the light's dark")
	_lines(state, "vigil_door", [SET_BOATS, BURN_BOATS])
	var back := _lines(state, "tobin", [BACK])
	assert_true(back.contains("I'll stop holding it out."), back)
	assert_false((state.item_count("tobins_pan") > 0), "handed back")
	assert_false(_offered(state, "tobin").has(BACK))


func test_the_lit_vigil_light_model() -> void:
	if _db == null:
		_db = load_content()
	var prop: Dictionary = (_db.get_region(BY)["props"] as Array).filter(func(p: Dictionary) -> bool:
		return str(p.get("model", "")).ends_with("vigil_light_lit.glb"))[0]
	assert_true(prop.has("light") and prop.has("halo"), "it lights the crown")
	var node := (load(KIT + "vigil_light_lit.glb") as PackedScene).instantiate() as Node3D
	var glowing := 0
	var top := -INF
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for s in mesh.mesh.get_surface_count():
			var m := mesh.mesh.surface_get_material(s) as StandardMaterial3D
			if m != null and m.emission_enabled:
				glowing += 1
		top = maxf(top, mesh.get_aabb().end.y)
	assert_true(glowing >= 3, "candles, the fire and the horn glow (%d)" % glowing)
	var halo_y := float(prop["halo"][1])
	assert_true(halo_y > 4.5 and halo_y < 5.7, "the halo in the lantern room (%.1f)" % halo_y)
	node.free()
