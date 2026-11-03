extends TestCase
## Day 82 — the way up (Act III step 2). The cinder road forgets where it goes: `forgets` fog turns the Wakebearer
## back unless a lit cresset's pool holds the way. Region `cressets` expand into cold/lit props, a "Light the
## cresset" object, clear pools and the road's paint; the validator checks each can be lit in order. Two cressets up
## the Boat Stair's notch, four up Cindermoor's long steps, and Ness Garrow of the Unmoored at the edge of the last.

const STAIR := "cindermoor_boat_stair"
const STEPS := "cindermoor_long_steps"

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


func _region(id: String) -> Dictionary:
	return _content().regions[id]


func _forgetting(region_id: String, state: WorldState, x: float, z: float) -> float:
	return Greying.forgetting_at(Greying.active_areas(_region(region_id), state), Vector2(x, z))


func test_cressets_expand_into_ordinary_content() -> void:
	for region_id: String in [STAIR, STEPS]:
		var region := _region(region_id)
		var list := Cressets.of(region)
		assert_eq(list.size(), 2 if region_id == STAIR else 4, region_id)
		for c: Dictionary in list:
			var id := str(c["id"])
			var flag := "flag:" + str(c["flag"])
			var props: Array = region["props"].filter(func(p: Dictionary) -> bool: return str(p.get("cresset", "")) == id)
			assert_eq(props.size(), 2, "a cold and a lit prop for " + id)
			assert_true(props.any(func(p: Dictionary) -> bool: return p["if"] == "!" + flag and str(p["model"]) == Cressets.MODEL_COLD), id)
			assert_true(props.any(func(p: Dictionary) -> bool: return p["if"] == flag and str(p["model"]) == Cressets.MODEL_LIT and p.has("halo")), id)
			var objects: Array = region["objects"].filter(func(o: Dictionary) -> bool: return str(o.get("cresset", "")) == id)
			assert_eq(objects.size(), 1, id)
			assert_eq(str(objects[0]["prompt"]), Cressets.PROMPT)
			var pools := Cressets.pools_of(region, id)
			assert_true(not pools.is_empty() and pools.all(func(a: Dictionary) -> bool: return Greying.is_clear(a) and a["if"] == flag), id)
			var paint: Array = region["ground"]["paint"].filter(func(z: Dictionary) -> bool: return str(z.get("cresset", "")) == id)
			assert_eq(paint.size(), 1, "the road's leg for " + id)
		# Expanding again changes nothing (generated entries are replaced, not doubled).
		var before := JSON.stringify(region)
		Cressets.expand(region)
		assert_eq(JSON.stringify(region), before, "idempotent")
	for model: String in [Cressets.MODEL_COLD, Cressets.MODEL_LIT, "res://assets/models/dressing/cinder_cresset_doused.glb"]:
		assert_true(ResourceLoader.exists(model), model)


func test_the_road_forgets_until_the_cressets_remember_it() -> void:
	var state := _at("the_boat_stair")
	# Halfway up the notch, and the band below the lip.
	assert_true(_forgetting(STAIR, state, 12.4, -11.5) >= Greying.FORGET_DEPTH, "up the notch, unlit")
	assert_true(_forgetting(STAIR, state, 11.8, -8.4) < Greying.FORGET_DEPTH, "the road's foot, where it's tried")
	state.set_flag("cindermoor_cresset_stair_1", true)
	assert_true(_forgetting(STAIR, state, 12.4, -11.5) < Greying.FORGET_DEPTH, "the first remembers as far as the second")
	assert_true(_forgetting(STAIR, state, 12.3, -14.4) >= Greying.FORGET_DEPTH, "and no further")
	state.set_flag("cindermoor_cresset_stair_2", true)
	assert_true(_forgetting(STAIR, state, 12.3, -14.4) < Greying.FORGET_DEPTH, "the second remembers over the lip")
	# Nothing forgets anywhere a region has no forgetting fog.
	assert_eq(Greying.forgetting_at(Greying.all_areas(_region("lowsong")), Vector2.ZERO), 0.0)


func test_each_cresset_needs_the_one_before() -> void:
	var v := ContentValidator.new(_content())
	for region_id: String in [STAIR, STEPS]:
		var region := _region(region_id)
		var field := TerrainField.from_data(region["ground"], float(region.get("water_level", -INF)))
		var spawn := JsonUtil.to_vector3(region["spawn_points"]["default"])
		var reachable := field.reachable_from(spawn.x, spawn.z)
		var list := Cressets.of(region)
		var lit: Array[Dictionary] = []
		for k in list.size():
			var pos := JsonUtil.to_vector3(list[k]["position"])
			var base := Greying.worst_case_areas(region)
			var with_before := v._remembered_cells(field, reachable, base + lit, spawn)
			assert_true(field.near_reachable(with_before, pos.x, pos.z, 2.0), "%s: %s with the ones before it" % [region_id, list[k]["id"]])
			if k > 0:
				var short: Array[Dictionary] = base + lit.slice(0, lit.size() - Cressets.pools_of(region, str(list[k - 1]["id"])).size())
				var without := v._remembered_cells(field, reachable, short, spawn)
				assert_false(field.near_reachable(without, pos.x, pos.z, 2.0), "%s: %s not without %s" % [region_id, list[k]["id"], list[k - 1]["id"]])
			lit.append_array(Cressets.pools_of(region, str(list[k]["id"])))


func test_lighting_the_way_up() -> void:
	var state := _at("the_boat_stair")
	var lighting: Dictionary = (_region(STAIR)["objects"] as Array).filter(func(o: Dictionary) -> bool: return str(o["id"]) == "cresset_stair_1")[0]
	assert_false(Conditions.evaluate(lighting["if"], state), "not before the road's been tried")
	var told := _lines(state, "cindermoor_road")
	assert_true(told.contains("The ember stirs in your hand"), told)
	assert_true(Conditions.evaluate(lighting["if"], state), "then it can be lit")
	told = _lines(state, "cindermoor_cresset_stair_1")
	assert_true(told.contains("You don't remember learning that.") and told.contains("The road remembers."), told)
	assert_true(told.contains("Mercy's deck"), "the Mercy's below")
	assert_false(Conditions.evaluate(lighting["if"], state), "lit once")
	told = _lines(state, "cindermoor_road")
	assert_true(told.contains("The road is a road again") or told.contains("the road is a road again"), told)
	assert_true(told.contains("the second cresset stands cold"), told)
	_lines(state, "cindermoor_cresset_stair_2")
	var exit: Dictionary = _region(STAIR)["exits"][0]
	assert_eq(str(exit["to"]), STEPS)
	assert_true(Conditions.evaluate(exit["requires"], state), "the exit opens")
	# Over the lip: the arrival fires once and moves the quest on.
	var event := RegionEvents.arrival(_region(STEPS), state)
	told = _lines(state, RegionEvents.fire(event, state))
	assert_true(told.contains("long steps") and told.contains("It's the lantern room. Nothing in it."), told)
	assert_eq(state.quest_stage("the_way_up"), "up_the_steps")
	assert_true(RegionEvents.arrival(_region(STEPS), state).is_empty(), "once")
	for k in range(1, 5):
		_lines(state, "cindermoor_cresset_steps_%d" % k)
		assert_true(bool(state.get_flag("cindermoor_cresset_steps_%d" % k)), str(k))
	assert_true(_lines(_at("the_long_steps"), "cindermoor_cresset_steps_3").contains("count the landings on a stair"), "the third turn")


func test_ness_at_the_edge_of_the_light() -> void:
	var state := _at("the_unmoored")
	state.set_flag("fen_met_hesper", true)
	state.set_flag("fen_ember", "cupped")
	var told := _lines(state, "ness", ["Close your hand over the ember.", "Who are you?", "Why come here, of all places?",
			"Did you put out the cresset up the road?", "Leave her to the fog."])
	assert_true(told.contains("That's far enough with that.") and told.contains("Keepers never did."), told)
	assert_true(told.contains("For Hesper, I'd guess.") and told.contains("You'll have met Hesper."), told)
	assert_true(told.contains("Like water to a drain.") and told.contains("Doesn't sit at all."), told)
	assert_true(told.contains("Took three days to get it cold."), told)
	assert_eq(str(state.get_flag("cindermoor_ness_ember")), "cupped")
	assert_eq(state.quest_stage("the_way_up"), "the_doused")
	told = _lines(state, "ness", ["Leave her to the fog."])
	assert_true(told.contains("she nods, once"), "covered again")
	state = _at("the_unmoored")
	state.set_flag("fen_dunstan_walk", "home")
	told = _lines(state, "ness", ["Let it burn.", "Why come here, of all places?", "Leave her to the fog."])
	assert_true(told.contains("the two others turn theirs") and told.contains("rowed home"), told)
	assert_false(told.contains("For Hesper"), told)
	assert_eq(str(state.get_flag("cindermoor_ness_ember")), "bare")
	# The two in the fog turn from a bare ember.
	var figures: Array = (_region(STEPS)["props"] as Array).filter(func(p: Dictionary) -> bool: return p.has("averts"))
	assert_eq(figures.size(), 2)
	assert_true(figures.all(func(p: Dictionary) -> bool: return Conditions.evaluate(p["averts"]["if"], state)))


func test_the_doused_cresset() -> void:
	var state := _at("the_unmoored")
	var told := _lines(state, "cindermoor_doused")
	assert_true(told.contains("put it out on purpose") and told.contains("somebody stands up"), told)
	assert_false(told.contains("Three days"), "only once Ness has said so")
	assert_true(bool(state.get_flag("cindermoor_doused_seen")))
	assert_eq(state.quest_stage("the_way_up"), "the_doused")
	assert_true(bool(_content().get_quest("the_way_up").get("future", false)), "the way on up isn't written yet")


func test_the_validator_on_cressets_and_forgetting() -> void:
	var db := load_content()
	var region: Dictionary = db.regions[STEPS]
	region["cressets"][1]["flag"] = "no_such_flag"
	region["cressets"][2]["dialogue"] = "cindermoor_cresset_steps_1"
	region["cressets"][3]["colour"] = "gold"
	region["greying"][0]["forgets"] = "yes"
	var v := ContentValidator.new(db)
	v._validate_region(STEPS, region)
	var report := "\n".join(v.errors)
	assert_true(report.contains("flag 'no_such_flag' is not declared"), report)
	assert_true(report.contains("never sets cindermoor_cresset_steps_3"), report)
	assert_true(report.contains("unknown key 'colour'"), report)
	assert_true(report.contains("greying forgets must be true or false"), report)
	# Swap two cressets: the later one can't be reached with only the earlier ones lit.
	db = load_content()
	region = db.regions[STEPS]
	var list: Array = region["cressets"]
	var swap: Variant = list[1]
	list[1] = list[2]
	list[2] = swap
	v = ContentValidator.new(db)
	v._validate_region(STEPS, region)
	report = "\n".join(v.errors)
	assert_true(report.contains("cresset 'steps_3'") and report.contains("can't be reached with only the cressets before it lit"), report)
	# Ness put out of every light's reach.
	db = load_content()
	region = db.regions[STEPS]
	region["npcs"][0]["position"] = [0, 0, -40]
	v = ContentValidator.new(db)
	v._validate_region(STEPS, region)
	report = "\n".join(v.errors)
	assert_true(report.contains("npc 'ness'") and report.contains("where the road forgets"), report)
