extends TestCase
## Day 27 — Thornwold's burning: the Ridge Light fed with Hob's memory of the four colliers
## (Ottie's boots) or the camp's memory of the colliers (Bram's salt row); the lit tower, the fog
## leaning back, Hob coming in by daylight, and Bram, Pell, Oda and the Lamp after.

const THORNWOLD := "a_light_for_thornwold"
const WOODS := "thornwold_woods"
const RIDGE := "thornwold_ridge"
const LANDING := "thornwold_landing"
const DIR := "res://assets/models/dressing/"
const ASK_BEACON := "The Ridge Light is cold."
const ASK_SPARE := "What does the Ridge Light want? What could Thornwold spare?"
const HOB_LIGHT := "The Ridge Light wants something remembered. Something Thornwold can spare."
const BRAM_LIGHT := "The Ridge Light wants something remembered. Something the camp could spare."
const BURN_BOOTS := ["Set Ottie's boots in the cradle.", "Burn Hob's memory of the four."]
const BURN_ROW := ["Set Bram's salt row in the cradle.", "Burn the camp's memory of the colliers."]

var _db: ContentDatabase


## On the ridge with the Lamp met, Hob met and (by default) paid, Pell on Thornwold.
func _on_the_ridge(paid: bool = true) -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "thornwold_landed", "thornwold_met_bram",
			"thornwold_pell_landed", "thornwold_bramble_parted", "thornwold_woods_entered", "thornwold_met_hob",
			"thornwold_ladder_stood", "thornwold_ridge_reached"]:
		state.set_flag(flag, true)
	state.set_flag("lanes_ferry_at", "thornwold")
	state.start_quest(THORNWOLD, "the_ridge")
	if paid:
		state.set_flag("thornwold_hob_paid", true)
		state.start_quest("salt_for_the_collier", "carry_the_salt")
		state.complete_quest("salt_for_the_collier")
	_lines(state, "lamp", [])
	return state


## The Lamp asked about the cold beacon: the quest wants feeding.
func _asked(paid: bool = true) -> WorldState:
	var state := _on_the_ridge(paid)
	_lines(state, "lamp", [ASK_BEACON])
	return state


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_db, state, dialogue, typed, offered)


func _offered(state: WorldState, dialogue: String) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [], offered)
	return offered


func _boots(state: WorldState) -> void:
	_lines(state, "hob", [HOB_LIGHT, "Hold them in the fog, Hob. For the light."])


func _row(state: WorldState) -> void:
	_lines(state, "bram", [BRAM_LIGHT, "Give it, Bram. For the light."])


func _props(region_id: String, model: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop: Dictionary in _db.get_region(region_id)["props"]:
		if str(prop.get("model", "")) == DIR + model + ".glb":
			out.append(prop)
	return out


func _shown(region_id: String, model: String, state: WorldState) -> int:
	var count := 0
	for prop in _props(region_id, model):
		if Conditions.evaluate(prop.get("if"), state):
			count += 1
	return count


func _hob_at(state: WorldState) -> Array[String]:
	var out: Array[String] = []
	for region_id: String in [WOODS, LANDING]:
		for npc: Dictionary in _db.get_region(region_id)["npcs"]:
			if str(npc["npc"]) == "hob" and Conditions.evaluate(npc.get("if"), state):
				out.append(region_id)
	return out


func test_the_lamp_sends_you_to_thornwold() -> void:
	var state := _on_the_ridge()
	assert_eq(state.quest_stage(THORNWOLD), "the_lamp", "met the Lamp")
	assert_false(_offered(state, "hob").has(HOB_LIGHT), "Hob isn't asked before the Lamp says what the light wants")
	var look := _lines(state, "ridge_light")
	assert_true(look.contains("the Lamp will know"), "the tower sends you to the Lamp")
	var said := _lines(state, "lamp", [ASK_BEACON])
	assert_true(said.contains("something somebody remembers"), "the Lamp says what it wants")
	assert_eq(state.quest_stage(THORNWOLD), "feed_the_light", "the quest wants feeding")
	var spare := _lines(state, "lamp", [ASK_SPARE])
	assert_true(spare.contains("Hob remembers the four") and spare.contains("salt row"), "the Lamp names Hob and the camp")
	assert_true(spare.contains("Don't bring me the woods"), "and keeps the woods' liking out of it")
	var empty := _lines(state, "ridge_light")
	assert_true(empty.contains("nothing to set in it"), "nothing to burn yet")


func test_hob_gives_the_boots() -> void:
	var state := _asked()
	var kept := _lines(state, "hob", [HOB_LIGHT, "No. Keep them. They might come back."])
	assert_true(kept.contains("Wenna Coll") and kept.contains("Dray"), "Hob names the four")
	assert_eq(state.item_count("otties_boots"), 0, "kept")
	assert_eq(_shown(WOODS, "collier_hut_cold", state), 1, "the boots stay on the seat")
	_boots(state)
	assert_eq(state.item_count("otties_boots"), 1, "Ottie's boots, a Remnant")
	assert_eq(str(_db.items["otties_boots"]["kind"]), "remnant")
	assert_true(bool(state.get_flag("thornwold_boots_away")))
	assert_false(_offered(state, "hob").has(HOB_LIGHT), "asked once")
	for model: String in ["collier_hut_cold", "collier_hut_cold_cap"]:
		assert_eq(_shown(WOODS, model, state), 0, "%s gone: the seat is bare" % model)
	assert_eq(_shown(WOODS, "collier_hut_cold_empty", state), 1, "the empty hut")
	state.set_flag("thornwold_hob_has_cap", true)
	assert_eq(_shown(WOODS, "collier_hut_cold_empty", state), 1, "the cap goes with the boots")
	assert_eq(_shown(WOODS, "collier_hut_cold_cap", state), 0)


func test_bram_gives_the_salt_row_once_hob_is_paid() -> void:
	var unpaid := _asked(false)
	assert_false(_offered(unpaid, "bram").has(BRAM_LIGHT), "an unpaid camp has nothing it'd miss")
	var why := _lines(unpaid, "bram", ["The Ridge Light wants something remembered."])
	assert_true(why.contains("owed something first"), "Bram says so")
	var state := _asked()
	var board := _lines(state, "bram_tally_board")
	assert_true(board.contains("a fourth, fresh and pale"), "the salt row hangs")
	var kept := _lines(state, "bram", [BRAM_LIGHT, "No. Keep your row."])
	assert_true(kept.contains("forgot him once already"), "Bram weighs it")
	assert_eq(state.item_count("salt_row"), 0)
	_row(state)
	assert_eq(state.item_count("salt_row"), 1, "the salt row, a Remnant")
	assert_eq(str(_db.items["salt_row"]["kind"]), "remnant")
	board = _lines(state, "bram_tally_board")
	assert_true(board.contains("bare pegs") and not board.contains("fresh and pale"), "the board's bottom pegs are bare")


func test_burning_the_boots() -> void:
	var state := _asked()
	state.add_item("colliers_cap")
	_boots(state)
	_row(state)
	var offered: Array[String] = []
	var climb := _lines(state, "ridge_light", ["Not yet."], offered)
	assert_true(climb.contains("lantern cage") and climb.contains("Ottie's boots") and climb.contains("salt row"), "both Remnants up the tower")
	assert_true(offered.has(BURN_BOOTS[0]) and offered.has(BURN_ROW[0]), "either can go in the cradle")
	_lines(state, "ridge_light", [BURN_BOOTS[0], "No. Not this.", "Not yet."])
	assert_eq(state.item_count("otties_boots"), 1, "weighed and not burned")
	var burn := _lines(state, "ridge_light", BURN_BOOTS)
	assert_true(burn.contains("The Ridge Light catches"), "it catches")
	assert_true(burn.contains("old man has stopped"), "Hob, below, forgets")
	assert_eq(state.quest_state(THORNWOLD), WorldState.QUEST_DONE, "A Light for Thornwold is done")
	assert_eq(str(state.get_flag("thornwold_beacon_burned")), "boots")
	assert_eq(state.item_count("otties_boots"), 0)
	assert_eq(_shown(WOODS, "collier_hut_cold_empty", state), 1, "the hut is nobody's for good")
	# Hob forgets the four.
	var hob := _lines(state, "hob", ["Where are the other charcoal folk?", "Who lived in the cold hut?"])
	assert_true(hob.contains("Always just me") and hob.contains("Nobody's"), "Hob never had neighbours")
	assert_false(hob.contains("Five hearths"), "no five hearths")
	var cap := _lines(state, "hob", ["This cap hung on the waymark at the foot of the stair."])
	assert_true(cap.contains("Somebody's") and not cap.contains("Ottie"), "a stranger's cap")
	assert_eq(_shown(WOODS, "collier_hut_cold_cap", state), 0, "and it doesn't go on the seat")
	# The salt row wasn't burned: it goes back to the board.
	var bram := _lines(state, "bram", ["Your salt row. I didn't burn it. Here."])
	assert_true(bram.contains("hangs it back"), "Bram hangs his row back")
	assert_false(bool(state.get_flag("thornwold_salt_row_away")))
	assert_true(_lines(state, "bram_tally_board").contains("fresh and pale"), "the row is on the board")
	var lit := _lines(state, "ridge_light")
	assert_true(lit.contains("burns gold") and lit.contains("crooked cord"), "the lit tower remembers the burn")


func test_burning_the_salt_row() -> void:
	var state := _asked()
	_boots(state)
	_row(state)
	_lines(state, "ridge_light", BURN_ROW)
	assert_eq(str(state.get_flag("thornwold_beacon_burned")), "salt_row")
	assert_eq(state.item_count("salt_row"), 0)
	assert_true(_lines(state, "bram_tally_board").contains("You know something hung there"), "the board's gap, for good")
	assert_false(_offered(state, "bram").has("About Hob Marl."), "Bram no longer knows Hob")
	# The boots go back to the seat.
	var back := _lines(state, "hob", ["Ottie's boots. I didn't burn them. Here."])
	assert_true(back.contains("Four places"), "Hob sets them back out")
	assert_eq(_shown(WOODS, "collier_hut_cold_cap", state) + _shown(WOODS, "collier_hut_cold", state), 1, "boots on the seat")
	assert_eq(_shown(WOODS, "collier_hut_cold_empty", state), 0)
	var others := _lines(state, "hob", ["Where are the other charcoal folk?"])
	assert_true(others.contains("Five hearths"), "Hob still remembers the four")


func test_the_light_changes_the_island() -> void:
	var state := _asked()
	var before_fog: float = RegionMood.fog(_db.get_region(WOODS), state)["density"]
	var before_sun: float = RegionMood.light(_db.get_region(RIDGE), state)["sun_energy"]
	var deep := Vector2(8, -45)  # off the lantern road, under the trees
	var before_depth := Greying.depth_at(Greying.active_areas(_db.get_region(WOODS), state), deep)
	assert_eq(_shown(RIDGE, "thornwold_beacon", state), 1, "cold on the ridge")
	assert_eq(_shown(WOODS, "thornwold_beacon_lit", state), 0)
	_boots(state)
	_lines(state, "ridge_light", BURN_BOOTS)
	for region_id: String in [WOODS, RIDGE]:
		assert_eq(_shown(region_id, "thornwold_beacon", state), 0, "no cold tower (%s)" % region_id)
		assert_eq(_shown(region_id, "thornwold_beacon_lit", state), 1, "the lit tower (%s)" % region_id)
	var ridge_lit: Dictionary = _props(RIDGE, "thornwold_beacon_lit")[0]
	assert_true(ridge_lit.has("light"), "the beacon's light on the ridge (the light budget's beacon)")
	assert_true(_props(WOODS, "thornwold_beacon_lit")[0].has("halo"), "the woods see it as a halo, not a light")
	for region_id: String in [WOODS, RIDGE, LANDING]:
		var region := _db.get_region(region_id)
		assert_true(float(RegionMood.fog(region, state)["density"]) < float(RegionMood.fog(region, fresh_state(_db))["density"]), "the fog thins (%s)" % region_id)
		assert_true(float(RegionMood.light(region, state)["sun_energy"]) > float(RegionMood.light(region, fresh_state(_db))["sun_energy"]), "the light warms (%s)" % region_id)
	assert_true(float(RegionMood.fog(_db.get_region(WOODS), state)["density"]) < float(before_fog))
	assert_true(float(RegionMood.light(_db.get_region(RIDGE), state)["sun_energy"]) > float(before_sun))
	var after_depth := Greying.depth_at(Greying.active_areas(_db.get_region(WOODS), state), deep)
	assert_true(before_depth > 0.9 and after_depth < 0.5 and after_depth > 0.0, "the woods' fog leans back but stays (%.2f → %.2f)" % [before_depth, after_depth])
	var ridge := _db.get_region(RIDGE)
	assert_true(Greying.depth_at(Greying.active_areas(ridge, state), Vector2(3, -1)) < 0.5, "the ridge top thins too")


func test_hob_comes_in_by_daylight() -> void:
	var state := _asked(false)
	_boots(state)
	_lines(state, "ridge_light", BURN_BOOTS)
	var landing := _db.get_region(LANDING)
	assert_true(RegionEvents.arrival(landing, state).is_empty(), "an unpaid Hob stays in the clearing")
	assert_eq(_hob_at(state), [WOODS])
	state.set_flag("thornwold_hob_paid", true)  # paid after the burn
	assert_eq(RegionEvents.fire(RegionEvents.arrival(landing, state), state), "hob_comes_in", "he comes in")
	assert_true(RegionEvents.arrival(landing, state).is_empty(), "once")
	assert_eq(_hob_at(state), [LANDING], "Hob sits on the tally-house step")
	var scene := _lines(state, "hob_comes_in")
	assert_true(scene.contains("Kettle's on") and scene.contains("doesn't look back"), "Bram knows him; Hob doesn't wait")
	var bram := _lines(state, "bram", ["Thornwold's beacon is lit."])
	assert_true(bram.contains("Didn't look back up at the ridge"), "Bram on Hob, after the boots")
	var hob := _lines(state, "hob", [])
	assert_true(hob.contains("Proper daylight"), "Hob at the camp")
	var hob_menu := _offered(state, "hob")
	assert_false(hob_menu.has("The fog stays out of your clearing."), "no clearing talk at the camp")


func test_the_camp_forgets_hob() -> void:
	var state := _asked()
	_row(state)
	_lines(state, "ridge_light", BURN_ROW)
	var scene := _lines(state, "hob_comes_in")
	assert_true(scene.contains("Can I help you") and scene.contains("You don't know me"), "Bram doesn't know Hob")
	assert_true(scene.contains("counts something"), "Hob still counts the four")
	state.set_flag("thornwold_hob_came_in", true)
	var bram := _lines(state, "bram", ["Thornwold's beacon is lit."])
	assert_true(bram.contains("Can't think why it was owed"), "the salt is a mystery to Bram")
	var pell := _lines(state, "pell", [])
	assert_true(pell.contains("asked me again at supper") and pell.contains("sticks to me"), "Pell, an off-islander, remembers")


func test_the_lamp_and_oda_after() -> void:
	var state := _asked()
	state.set_flag("thornwold_stair_light", "sliver")
	_boots(state)
	_lines(state, "ridge_light", BURN_BOOTS)
	var lamp := _lines(state, "lamp", [])
	assert_true(lamp.contains("No fifth"), "the Lamp on the boots")
	assert_true(lamp.contains("stop breaking the coal"), "the lanterns can go out now")
	assert_true(lamp.contains("A night less"), "the stair's sliver shows")
	assert_true(lamp.contains("For the four"), "the coal kept for the four (open)")
	assert_true(bool(state.get_flag("thornwold_lamp_saw_light")))
	assert_true(_lines(state, "lamp", []).contains("A new habit"), "once")
	var other := _asked()
	_row(other)
	_lines(other, "ridge_light", BURN_ROW)
	var lamp_row := _lines(other, "lamp", [])
	assert_true(lamp_row.contains("I'll not put it down again") and lamp_row.contains("More than I thought"), "the Lamp on the salt row, no sliver taken")
	var oda := _lines(state, "oda", [])
	assert_true(oda.contains("Glasswater Fen"), "the lane on opens")
	var pell := _lines(state, "pell", [])
	assert_true(pell.contains("LIGHT on the ridge"), "Pell saw it")


func test_the_burn_checkpoint() -> void:
	_db = load_content()
	var state := fresh_state(_db)
	Scenarios.apply(_db, state, Scenarios.resolve("thornwold_lit"))
	assert_eq(state.quest_state(THORNWOLD), WorldState.QUEST_DONE, "a checkpoint after the burn")
	assert_eq(str(state.get_flag("thornwold_beacon_burned")), "boots")
	assert_eq(_shown(RIDGE, "thornwold_beacon_lit", state), 1, "the tower lit")
