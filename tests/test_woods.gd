extends TestCase
## Into the woods, part one (Day 21): lantern light as `clear` Greying areas, the ember
## parting the bramble wall, the woods past it (the straight road lies, the lanterns lead to
## the colliers' clearing), Hob Marl, Bram's tally board and the salt he owes.

const THORNWOLD := "a_light_for_thornwold"
const SALT := "salt_for_the_collier"
const WOODS := "thornwold_woods"
const DIR := "res://assets/models/dressing/"

var _db: ContentDatabase


## Ashore on Thornwold, Bram met and the quest given (the bramble wall not yet looked at).
func _ashore(pell_landed: bool = false) -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "thornwold_landed", "thornwold_met_bram"]:
		state.set_flag(flag, true)
	state.set_flag("lanes_ferry_at", "thornwold")
	state.set_flag("thornwold_pell_landed", pell_landed)
	state.start_quest(THORNWOLD, "the_bramble_wall")
	return state


## Past the wall and Hob met (and asked about the Lamp).
func _met_hob(pell_landed: bool = false) -> WorldState:
	var state := _ashore(pell_landed)
	play_dialogue(_db, state, "thornwold_bramble", ["Hold the ember to the thorns.", "Go through."])
	play_dialogue(_db, state, "hob", ["Who hangs the lanterns?"])
	return state


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


func test_clear_areas_cut_pools_out_of_the_fog() -> void:
	var fog := {"rect": [-10, -10, 10, 10]}
	var lamp := {"ellipse": [0, 0, 3, 3], "falloff": 2.0, "clear": true}
	var areas: Array[Dictionary] = [fog, lamp]
	assert_eq(Greying.depth_at(areas, Vector2(0, 0)), 0.0, "a lantern clears the fog under it")
	assert_eq(Greying.depth_at(areas, Vector2(8, 8)), 1.0, "away from the lantern the fog is whole")
	var edge := Greying.depth_at(areas, Vector2(4, 0))
	assert_true(edge > 0.0 and edge < 1.0, "the pool's edge thins gradually (%.2f)" % edge)
	var light_only: Array[Dictionary] = [lamp]
	assert_eq(Greying.depth_at(light_only, Vector2(0, 0)), 0.0, "light alone is no fog")
	var region := {"greying": [fog, lamp, {"ellipse": [5, 5, 2, 2], "clear": true, "if": "flag:intro_seen"}]}
	var worst := Greying.worst_case_areas(region)
	assert_eq(worst.size(), 2, "the worst case drops lights the story may take away")
	assert_true(worst.has(lamp), "an unconditional lantern always counts")


func test_fog_layers_are_cut_around_lantern_pools() -> void:
	var fog := {"rect": [-6, -6, 6, 6], "falloff": 1.0}
	var lamp: Array[Dictionary] = [{"ellipse": [0, 0, 3, 3], "falloff": 1.0, "clear": true}]
	var flat := func(_x: float, _z: float) -> float: return 0.0
	var whole := GreyingFog.build_mesh(fog, flat)
	var cut := GreyingFog.build_mesh(fog, flat, lamp)
	var whole_verts: int = (whole.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var cut_verts: int = (cut.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	assert_true(cut_verts < whole_verts, "the pool's triangles are dropped (%d < %d)" % [cut_verts, whole_verts])


func test_validator_checks_clear() -> void:
	var db := load_content()
	(db.regions[WOODS]["greying"] as Array).append({"ellipse": [0, -30, 2, 2], "clear": "yes"})
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	assert_true(validator.report().contains("greying clear must be true or false"), validator.report())


func test_the_ember_parts_the_bramble_wall() -> void:
	_db = load_content()
	var before := fresh_state(_db)
	var offered: Array[String] = []
	_lines(before, "thornwold_bramble", [], offered)
	assert_false(offered.has("Hold the ember to the thorns."), "no parting before Bram has sent you")
	var state := _ashore()
	var runner := DialogueRunner.new(_db, state)
	var ev := runner.start("thornwold_bramble")
	var picks: Array[String] = ["Hold the ember to the thorns.", "Go through."]
	var text := ""
	while ev["type"] != "end":
		if ev["type"] == "line":
			text += str(ev["text"]) + "\n"
			ev = runner.next()
		else:
			var texts: Array[String] = []
			for option: Dictionary in ev["options"]:
				texts.append(str(option["text"]))
			ev = runner.choose(texts.find(picks.pop_front()))
	assert_true(text.contains("draw back from the ember"), "the canes draw back")
	assert_eq(runner.pending_travel, ["thornwold_woods", "from_bramble"], "through the gap into the woods")
	assert_true(bool(state.get_flag("thornwold_bramble_parted")), "the wall has parted")
	assert_eq(state.quest_stage(THORNWOLD), "the_lantern_road", "follow the lanterns")
	var again := _lines(state, "thornwold_bramble", ["Not yet."])
	assert_true(again.contains("opens again") and again.contains("settle back"), "it parts again on a later visit")


func test_the_woods_road_lies_and_the_lanterns_lead() -> void:
	_db = load_content()
	var region := _db.get_region(WOODS)
	var areas := Greying.worst_case_areas(region)
	for spawn: String in region["spawn_points"]:
		assert_true(Greying.depth_at(areas, _xz(region["spawn_points"][spawn])) < Greying.CLEAR_DEPTH, "spawn %s is clear" % spawn)
	var lit := _props(WOODS, "waymark_lit")
	assert_true(lit.size() >= 5, "lanterns on the waymarks, and one on the ridge")
	# Lanterns the story can move (Day 25: the fourth mark's, the stair's) have conditional pools,
	# which the worst case leaves out; test_ridge_top.gd covers those.
	var lit_always := lit.filter(func(p: Dictionary) -> bool: return not p.has("if"))
	var pools := 0
	for prop in lit_always:
		if Greying.depth_at(areas, _xz(prop["position"])) < Greying.CLEAR_DEPTH:
			pools += 1
	assert_eq(pools, lit_always.size() - 1, "every reachable lit waymark stands in its own clear pool")
	for prop in _props(WOODS, "waymark"):
		assert_true(Greying.depth_at(areas, _xz(prop["position"])) > 0.9, "a bare waymark stands in deep fog")
	assert_true(Greying.depth_at(areas, Vector2(0, -45)) > 0.9, "the straight road runs on into deep fog")
	var hob: Dictionary = region["npcs"][0]
	assert_eq(str(hob["npc"]), "hob")
	assert_true(Greying.depth_at(areas, _xz(hob["position"])) < Greying.CLEAR_DEPTH, "the colliers' clearing is clear")
	assert_eq(_props(WOODS, "collier_hut").size() + _props(WOODS, "collier_hut_cold").size(), 2,
			"two huts in the clearing (Hob's, and a cold one)")
	# The ridge lantern is seen, not reached.
	var field := TerrainField.from_data(region["ground"])
	var spawn: Array = region["spawn_points"]["default"]
	var reachable := field.reachable_from(float(spawn[0]), float(spawn[2]))
	var ridge := lit.filter(func(p: Dictionary) -> bool: return float(p["position"][2]) < -65.0)
	assert_eq(ridge.size(), 1, "one lantern on the ridge")
	var rp: Array = ridge[0]["position"]
	assert_false(field.near_reachable(reachable, float(rp[0]), float(rp[2]), 2.0), "the ridge lantern is out of reach")
	# The arrival scene only plays for someone who came through the wall, once.
	var state := _ashore()
	assert_true(RegionEvents.arrival(region, state).is_empty(), "no arrival scene without the parting")
	state.set_flag("thornwold_bramble_parted", true)
	var event := RegionEvents.arrival(region, state)
	assert_eq(RegionEvents.fire(event, state), "thornwold_woods_arrival", "the arrival scene plays")
	assert_true(RegionEvents.arrival(region, state).is_empty(), "and only once")


func test_hob_marl_and_the_lamp() -> void:
	var state := _ashore()
	play_dialogue(_db, state, "thornwold_bramble", ["Hold the ember to the thorns.", "Go through."])
	var first := _lines(state, "hob", [])
	assert_true(first.contains("You're not the Lamp") and first.contains("Hob Marl"), "Hob introduces himself")
	assert_true(bool(state.get_flag("thornwold_met_hob")), "met Hob")
	assert_eq(state.quest_stage(THORNWOLD), "the_lantern_road", "the ridge isn't named yet")
	var lamp := _lines(state, "hob", ["Who hangs the lanterns?"])
	assert_true(lamp.contains("along the ridge") and lamp.contains("Beacon's up there"), "the Lamp, the ridge, the beacon")
	assert_eq(state.quest_stage(THORNWOLD), "the_ridge", "the quest points up the ridge")
	var sacks := _lines(state, "hob", ["Do you bring the sacks down to the jetty?"])
	assert_true(sacks.contains("Did I take the salt?"), "he forgot his pay")


func test_the_tally_board_and_the_salt() -> void:
	var state := _ashore()
	var board := _lines(state, "bram_tally_board")
	assert_true(board.contains("three notches, then bare wood"), "the salt row stops at three")
	assert_true(board.contains("for nothing"), "somebody brings charcoal for nothing")
	var offered: Array[String] = []
	_lines(state, "bram", [], offered)
	assert_false(offered.has("I found who brings your sacks: an old collier, Hob Marl."), "nothing to tell Bram yet")
	state = _met_hob()
	assert_true(_lines(state, "bram_tally_board").contains("without his salt"), "the board reads differently once you know")
	var told := _lines(state, "bram", ["I found who brings your sacks: an old collier, Hob Marl."])
	assert_true(told.contains("I haven't thought of him since the Snuffing"), "Bram had forgotten Hob too")
	assert_eq(state.item_count("salt_crock"), 1, "Bram gives a crock of salt")
	assert_eq(state.quest_state(SALT), WorldState.QUEST_ACTIVE, "Salt for the Collier")
	var paid := _lines(state, "hob", ["Bram Kettle sends your salt."])
	assert_true(paid.contains("Hob Marl had his salt"), "Hob takes his pay")
	assert_eq(state.item_count("salt_crock"), 0, "the crock is handed over")
	assert_true(bool(state.get_flag("thornwold_hob_paid")), "Hob is paid")
	assert_eq(state.quest_state(SALT), WorldState.QUEST_DONE, "quest done")
	assert_true(_lines(state, "bram_tally_board").contains("a fourth, fresh and pale"), "a fourth notch on the salt row")
	assert_true(_lines(state, "bram", ["About Hob Marl."]).contains("fourth notch"), "Bram cut it himself")
	assert_true(_lines(state, "hob", ["Do you bring the sacks down to the jetty?"]).contains("Bram Kettle's salt"), "Hob remembers")


func test_the_tally_stick_is_hobs() -> void:
	var offered: Array[String] = []
	var alone := _met_hob(false)
	_lines(alone, "hob", [], offered)
	assert_false(offered.has("A kid at the camp found a tally stick by your sacks."), "no stick without Pell")
	var state := _met_hob(true)
	var stick := _lines(state, "hob", ["A kid at the camp found a tally stick by your sacks."])
	assert_true(stick.contains("the night I forgot what I was counting"), "Hob knows his stick")
	assert_true(bool(state.get_flag("thornwold_hob_stick")), "flag set")
	var pell := _lines(state, "pell", ["The tally stick is Hob Marl's. A collier, past the wall."])
	assert_true(pell.contains("keeping it FOR him"), "Pell keeps it for him")


func test_salt_is_a_valid_item_and_hob_has_his_model() -> void:
	_db = load_content()
	assert_false(_db.get_item("salt_crock").is_empty(), "salt crock item exists")
	var npc := _db.get_npc("hob")
	assert_true(ResourceLoader.exists(str(npc["model"])), "hob.glb exists")
