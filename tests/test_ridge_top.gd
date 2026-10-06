extends TestCase
## Day 25 — into the woods, part two: standing the Keepers' ladder, the ridge as its own region,
## the Lamp (what is in the iron box, the ladder, Aldous's confession), the stair lantern (shifting
## paths: a new sliver, or the fourth mark's lantern moved) and Ottie's cap back to Hob.

const THORNWOLD := "a_light_for_thornwold"
const STAIR := "a_lantern_for_the_stair"
const WOODS := "thornwold_woods"
const RIDGE := "thornwold_ridge"
const DIR := "res://assets/models/dressing/"
const ASK_STAIR := "The stair up the bank is deep in the fog."
const ASK_ALDOUS := "A Keeper in Saltmarrow told me how the Spire went dark."

var _db: ContentDatabase


## In the woods, Hob met (the quest names the ridge), the ladder not yet touched.
func _in_the_woods(confessed: String = "") -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "thornwold_landed", "thornwold_met_bram"]:
		state.set_flag(flag, true)
	state.set_flag("lanes_ferry_at", "thornwold")
	state.set_flag("saltmarrow_aldous_confessed", confessed)
	if confessed == "full":
		state.add_item("keepers_sleeve_ember")
	state.start_quest(THORNWOLD, "the_bramble_wall")
	play_dialogue(_db, state, "thornwold_bramble", ["Hold the ember to the thorns.", "Go through."])
	play_dialogue(_db, state, "hob", ["Who hangs the lanterns?"])
	return state


## Up the ladder and the Lamp met.
func _met_lamp(confessed: String = "") -> WorldState:
	var state := _in_the_woods(confessed)
	_climb(state)
	play_dialogue(_db, state, "lamp", [])
	return state


## Runs the ladder's dialogue (standing it if needed) and returns where it travels.
func _climb(state: WorldState) -> Array:
	var runner := DialogueRunner.new(_db, state)
	var ev := runner.start("keeper_ladder")
	while ev["type"] != "end":
		if ev["type"] == "line":
			ev = runner.next()
			continue
		var texts: Array[String] = []
		for option: Dictionary in ev["options"]:
			texts.append(str(option["text"]))
		var pick := texts.find("Stand the ladder against the pitch.")
		ev = runner.choose(pick if pick >= 0 else texts.find("Climb to the ridge."))
	return runner.pending_travel


func _lines(state: WorldState, dialogue: String, picks: Array[String] = [], offered: Array[String] = []) -> String:
	return play_dialogue(_db, state, dialogue, picks, offered)


func _props(region_id: String, model: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop: Dictionary in _db.get_region(region_id)["props"]:
		if str(prop.get("model", "")) == DIR + model + ".glb":
			out.append(prop)
	return out


func _xz(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[2]))


func _depth(region_id: String, state: WorldState, p: Array) -> float:
	return Greying.depth_at(Greying.active_areas(_db.get_region(region_id), state), _xz(p))


func test_the_ladder_stands_and_climbs_to_the_ridge() -> void:
	var state := _in_the_woods()
	var offered: Array[String] = []
	var look := _lines(state, "keeper_ladder", ["Leave it lying."], offered)
	assert_true(look.contains("cut, clean"), "the top cords were cut, not frayed")
	assert_true(offered.has("Stand the ladder against the pitch.") and not offered.has("Climb to the ridge."), "stand it before climbing")
	assert_false(bool(state.get_flag("thornwold_ladder_stood")), "leaving it lying changes nothing")
	assert_eq(_climb(state), [RIDGE, "from_ladder"], "stood and climbed: up to the ridge")
	assert_true(bool(state.get_flag("thornwold_ladder_stood")), "the ladder stands")
	offered.clear()
	var again := _lines(state, "keeper_ladder", ["Not yet."], offered)
	assert_true(again.contains("where you stood it") and not offered.has("Stand the ladder against the pitch."), "it stays stood")
	assert_eq(_climb(state), [RIDGE, "from_ladder"], "and climbs again")


func test_the_ridge_layout() -> void:
	_db = load_content()
	var region := _db.get_region(RIDGE)
	var field := TerrainField.from_data(region["ground"])
	var spawn: Array = region["spawn_points"]["default"]
	var reachable := field.reachable_from(float(spawn[0]), float(spawn[2]))
	var areas := Greying.worst_case_areas(region)
	for name: String in region["spawn_points"]:
		assert_true(Greying.depth_at(areas, _xz(region["spawn_points"][name])) < Greying.CLEAR_DEPTH, "spawn %s is in the lantern's pool" % name)
	assert_true(Greying.depth_at(areas, Vector2(3, -1)) > 0.9, "between the ladder and the lodge the ridge is deep in the fog")
	var lamp: Dictionary = region["npcs"][0]
	assert_eq(str(lamp["npc"]), "lamp", "the Lamp is on the ridge")
	assert_true(Greying.depth_at(areas, _xz(lamp["position"])) < Greying.CLEAR_DEPTH, "the coal holds the fog off the bench")
	var lodge: Array = _props(RIDGE, "keeper_lodge")[0]["position"]
	assert_true(_xz(lamp["position"]).distance_to(_xz(lodge)) < 4.0, "the Lamp is at the lodge")
	assert_eq(_props(RIDGE, "thornwold_beacon").size(), 1, "the Ridge Light stands cold")
	assert_eq(_props(RIDGE, "thornwold_beacon_lit").size(), 0, "the lit tower waits for the burn")
	# The lip: the ladder's top at the edge, the woods far below and out of reach.
	var ladder: Dictionary = _props(RIDGE, "keeper_ladder")[0]
	assert_false(bool(ladder.get("snap", true)), "the ladder stands on the pitch below the lip (absolute y)")
	var foot: Array = ladder["position"]
	var top := float(foot[1]) + 2.95
	assert_true(absf(top - field.height_at(float(foot[0]), float(foot[2]) - 1.2)) < 0.6, "its top meets the lip (%.2f)" % top)
	assert_true(field.height_at(0, 18) < -5.0, "the woods lie far below the lip")
	assert_false(field.near_reachable(reachable, 0, 18, 1.0), "and can't be walked down to")
	var exit: Dictionary = region["exits"][0]
	assert_eq([str(exit["to"]), str(exit["spawn"])], [WOODS, "from_ridge"], "climbing down comes out in the woods")
	var woods := _db.get_region(WOODS)
	assert_true(Greying.depth_at(Greying.worst_case_areas(woods), _xz(woods["spawn_points"]["from_ridge"])) < Greying.CLEAR_DEPTH,
			"at the colliers' clearing, clear of the fog")
	# Arrival scene once.
	var state := fresh_state(_db)
	assert_true(RegionEvents.arrival(region, state).is_empty(), "no arrival scene without the ladder")
	state.set_flag("thornwold_ladder_stood", true)
	assert_eq(RegionEvents.fire(RegionEvents.arrival(region, state), state), "thornwold_ridge_arrival", "the arrival scene plays")
	assert_true(RegionEvents.arrival(region, state).is_empty(), "and only once")


func test_meeting_the_lamp() -> void:
	var state := _in_the_woods()
	_climb(state)
	assert_eq(state.quest_stage(THORNWOLD), "the_ridge", "the ridge, before the Lamp")
	var first := _lines(state, "lamp", [])
	assert_true(first.contains("Proper light") and first.contains("You stood the ladder"), "the Lamp sees the ember")
	assert_true(bool(state.get_flag("thornwold_met_lamp")), "met the Lamp")
	assert_eq(state.quest_stage(THORNWOLD), "the_lamp", "the quest names the Lamp")
	assert_eq(state.quest_state(THORNWOLD), WorldState.QUEST_ACTIVE, "Thornwold's burning is not written yet")
	assert_true(_lines(state, "lamp", ["Who are you?"]).contains("I had another one. A name."), "the Lamp lost its name")
	assert_true(bool(state.get_flag("thornwold_lamp_name_lost")))
	var box := _lines(state, "lamp", ["What's in the iron box?"])
	assert_true(box.contains("Saved it") and box.contains("the lanterns go out"), "the last coal of the midwinter fire")
	assert_true(bool(state.get_flag("thornwold_lamp_coal_told")))
	var ladder := _lines(state, "lamp", ["The ladder was lying on the landing."])
	assert_true(ladder.contains("I put it down") and ladder.contains("no fifth"), "the Lamp put the ladder down")
	var offered: Array[String] = []
	_lines(state, "lamp", [], offered)
	assert_false(offered.has("The ladder was lying on the landing."), "told once")
	assert_false(offered.has(ASK_ALDOUS), "nothing to tell of Aldous without his confession")
	var beacon := _lines(state, "lamp", ["The Ridge Light is cold."])
	assert_true(beacon.contains("something somebody remembers") and beacon.contains("Don't ask me"), "the Ridge Light wants a memory, not the Lamp's")


func test_the_lamp_hears_of_aldous() -> void:
	var full := _met_lamp("full")
	var told := _lines(full, "lamp", [ASK_ALDOUS])
	assert_true(told.contains("Spire stitch") and told.contains("Door-warden"), "the sleeve-ember's stitch is Wren's stair")
	assert_true(told.contains("cupped in someone's hands") and told.contains("went cold down one side"), "the full story, and the coal")
	assert_eq(full.item_count("keepers_sleeve_ember"), 1, "the ember is handed back")
	assert_true(bool(full.get_flag("thornwold_lamp_heard_of_aldous")))
	var grudging := _met_lamp("grudging")
	var bare := _lines(grudging, "lamp", [ASK_ALDOUS])
	assert_true(bare.contains("Put out. Not went out.") and bare.contains("Leave him the rest"), "the bare fact is enough to know")
	assert_false(bare.contains("Spire stitch") or bare.contains("cupped"), "no sleeve, no light on the stair")


func test_a_sliver_for_the_stair() -> void:
	var state := _met_lamp()
	var woods := _db.get_region(WOODS)
	var stair_turn := [6.5, 0, -62.6]
	assert_true(_depth(WOODS, state, stair_turn) > 0.9, "the stair is deep in the fog")
	assert_false(_lines(state, "woods_cap_waymark", []).contains("hook takes the weight"), "nothing to hang yet")
	var given := _lines(state, "lamp", [ASK_STAIR, "Break a sliver for the stair."])
	assert_true(given.contains("a little smaller"), "the coal is a little smaller")
	assert_eq(str(state.get_flag("thornwold_stair_light")), "sliver")
	assert_eq(state.item_count("keepers_lantern"), 1, "a lit lantern to carry")
	assert_eq(state.quest_stage(STAIR), "hang", "straight to hanging it")
	assert_true(_lines(state, "ridge_light", []).contains("one more from the bench"), "the rack's count knows")
	var offered: Array[String] = []
	_lines(state, "lamp", [], offered)
	assert_false(offered.has(ASK_STAIR), "asked once")
	var hung := _lines(state, "woods_cap_waymark", ["Take down the cap and hang the lantern."])
	assert_true(hung.contains("Light goes up the stair"), "the stair is lit")
	assert_true(bool(state.get_flag("thornwold_stair_lantern_hung")))
	assert_eq(state.item_count("keepers_lantern"), 0)
	assert_eq(state.item_count("colliers_cap"), 1, "the cap comes down")
	assert_eq(state.quest_state(STAIR), WorldState.QUEST_DONE)
	assert_true(_depth(WOODS, state, stair_turn) < Greying.CLEAR_DEPTH, "the stair stands in clear light")
	assert_true(_depth(WOODS, state, [-13.0, 0, -47.0]) < Greying.CLEAR_DEPTH, "and the fourth mark keeps its light")
	var shown := _db.get_region(WOODS)["props"].filter(func(p: Dictionary) -> bool:
		return str(p["model"]).ends_with("waymark_lit.glb") and Conditions.evaluate(p.get("if"), state)) as Array
	assert_eq(shown.size(), 6, "five lanterns as before, and the stair's")
	assert_true(woods.has("objects"))
	assert_true(_lines(state, "woods_cap_waymark", []).contains("The lantern you hung"), "the waymark reads lit after")


func test_the_fourth_lantern_moves_to_the_stair() -> void:
	var state := _met_lamp()
	var fourth := [-13.0, 0, -47.0]
	var object: Dictionary = _db.get_region(WOODS)["objects"].filter(func(o: Dictionary) -> bool:
		return o["id"] == "woods_fourth_waymark")[0]
	assert_false(Conditions.evaluate(object["if"], state), "the fourth mark's lantern isn't for taking unasked")
	_lines(state, "lamp", [ASK_STAIR, "I'll move the fourth mark's lantern."])
	assert_eq(str(state.get_flag("thornwold_stair_light")), "moved")
	assert_eq(state.item_count("keepers_lantern"), 0, "nothing given: fetch it")
	assert_eq(state.quest_stage(STAIR), "fetch")
	assert_true(Conditions.evaluate(object["if"], state), "now it can be unhooked")
	assert_true(_depth(WOODS, state, fourth) < Greying.CLEAR_DEPTH, "still lit")
	var took := _lines(state, "woods_fourth_waymark", ["Unhook the lantern."])
	assert_true(took.contains("begins, without hurry, to close in"), "the fog closes in")
	assert_false(Conditions.evaluate(object["if"], state), "gone from the hook")
	assert_true(_depth(WOODS, state, fourth) > 0.9, "the fourth mark's pool closes up")
	assert_eq(state.item_count("keepers_lantern"), 1)
	assert_eq(state.quest_stage(STAIR), "hang")
	assert_true(_lines(state, "hob", ["Goodbye."]).contains("Fourth mark's dark"), "Hob notices")
	_lines(state, "woods_cap_waymark", ["Take down the cap and hang the lantern."])
	assert_eq(state.quest_state(STAIR), WorldState.QUEST_DONE)
	assert_true(_lines(state, "hob", ["Goodbye."]).contains("Lamp's moved it"), "Hob sees where it went")
	assert_true(_lines(state, "lamp", ["Goodbye."]).contains("light on the stair"), "the Lamp saw it from the gallery")


func test_refusing_leaves_the_stair_dark() -> void:
	var state := _met_lamp()
	var said := _lines(state, "lamp", [ASK_STAIR, "Keep your coal. I'll climb in the fog."])
	assert_true(said.contains("few left who'd say it"), "the Lamp is grateful")
	assert_eq(str(state.get_flag("thornwold_stair_light")), "refused")
	assert_eq(state.quest_state(STAIR), WorldState.QUEST_INACTIVE, "no lantern to carry")
	assert_true(_depth(WOODS, state, [6.5, 0, -62.6]) > 0.9, "the stair stays in the fog")
	var offered: Array[String] = []
	_lines(state, "lamp", [], offered)
	assert_false(offered.has(ASK_STAIR), "the choice stands")


func test_ottie_swales_cap_goes_to_hob() -> void:
	var state := _met_lamp()
	_lines(state, "lamp", [ASK_STAIR, "Break a sliver for the stair."])
	var offered: Array[String] = []
	_lines(state, "hob", [], offered)
	assert_false(offered.has("This cap hung on the waymark at the foot of the stair."), "no cap yet")
	assert_true(offered.has("I've been up on the ridge. I met the Lamp."), "Hob hears of the ridge")
	_lines(state, "woods_cap_waymark", ["Take down the cap and hang the lantern."])
	var cap := _lines(state, "hob", ["This cap hung on the waymark at the foot of the stair."])
	assert_true(cap.contains("Ottie Swale") and cap.contains("beside the boots"), "Ottie's cap, set by his boots")
	assert_eq(state.item_count("colliers_cap"), 0)
	assert_true(bool(state.get_flag("thornwold_hob_has_cap")))
