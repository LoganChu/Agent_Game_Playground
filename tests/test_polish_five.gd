extends TestCase
## Day 44 — Polish/debt pass five: string flags list their `values` (a typo in a `set`, a
## condition or a scenario is caught, and joint_witness is exact); prop variants on one spot are
## proved exclusive; Wenna's cord hangs bare once her answer is given; the Gannet's board shows
## its chalk once read; the Teeth's slabs stand in surf and gullies cross the reef road.

const WRACKHOLM := "wrackholm"
const TEETH := "wrack_teeth"
const DRESSING := "res://assets/models/dressing/"
const CHARACTERS := "res://assets/models/characters/"


func test_every_string_flag_lists_its_values() -> void:
	var db := load_content()
	var missing: Array[String] = []
	for id: String in db.flags:
		var default: Variant = db.flag_default(id)
		if default is String:
			if db.flag_values(id).is_empty():
				missing.append(id)
			else:
				assert_true(db.flag_values(id).has(default), "%s: the default is a value" % id)
		else:
			assert_true(db.flag_values(id).is_empty(), "%s: a true/false flag lists none" % id)
	assert_empty(missing, "string flags without values")
	assert_eq(db.flag_values("wrackholm_beacon_burned"), ["", "answer", "board", "white"])
	assert_eq(db.flag_value_error("wrackholm_tide", "low"), "")
	assert_true(db.flag_value_error("wrackholm_tide", "high").contains("never takes \"high\""))
	assert_true(not db.flag_value_error("wrackholm_tide", true).is_empty(), "a string flag never takes true")
	assert_eq(db.flag_value_error("intro_seen", true), "", "flags without a list aren't checked")


func test_validator_catches_a_value_a_flag_never_takes() -> void:
	# In a dialogue `set`.
	var db := load_content()
	var hit := _first_set(db.dialogues["wrack_light"], "wrackholm_beacon_burned")
	assert_true(not hit.is_empty(), "found the burn's set")
	hit["set"]["wrackholm_beacon_burned"] = "answr"
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "a misspelt set fails")
	assert_true(validator.report().contains("sets flag 'wrackholm_beacon_burned' never takes \"answr\""), validator.report())
	# In a condition.
	db = load_content()
	(db.regions[WRACKHOLM]["npcs"] as Array).append({"npc": "wenna", "position": [0, 0, 0], "if": ["flag:wrackholm_tide=high", "flag:wrackholm_tide=low"]})
	validator = ContentValidator.new(db)
	assert_false(validator.validate())
	assert_true(validator.report().contains("reads flag 'wrackholm_tide' never takes \"high\""), validator.report())
	# In flags.json itself.
	db = load_content()
	db.flags["wrackholm_tide"].erase("values")
	db.flags["fen_ember"]["values"] = ["bare", "cupped"]
	validator = ContentValidator.new(db)
	assert_false(validator.validate())
	assert_true(validator.report().contains("string flag 'wrackholm_tide' needs a 'values' list"), validator.report())
	assert_true(validator.report().contains("flag 'fen_ember' default \"\" is not among its values"), validator.report())


func test_scenarios_use_only_listed_values() -> void:
	var db := load_content()
	assert_empty(Scenarios.validate(db, Scenarios.all()), "the real checkpoints")
	var broken: Array = Scenarios.all().duplicate(true)
	for scenario: Dictionary in broken:
		if scenario["id"] == "the_teeth":
			scenario["flags"]["wrackholm_tide"] = "lo"
	var errors := Scenarios.validate(db, broken)
	assert_true(errors.any(func(e: String) -> bool: return e.contains("never takes \"lo\"")), str(errors))


func test_joint_witness_is_exact_with_value_lists() -> void:
	var defaults := {"word": ""}
	# Without a list, a value nobody named is tried (and here makes both hold)...
	assert_false(Conditions.joint_witness([["!flag:word="], ["!flag:word=mara"]], defaults).is_empty())
	# ...with one, only the listed values are.
	assert_eq(Conditions.joint_witness([["!flag:word="], ["!flag:word=mara"]], defaults, {"word": ["", "mara"]}), {})
	assert_false(Conditions.joint_witness([["!flag:word="], ["!flag:word=mara"]], defaults, {"word": ["", "mara", "own"]}).is_empty())


func test_prop_variants_on_one_spot_are_exclusive() -> void:
	var db := load_content()
	var validator := ContentValidator.new(db)
	assert_true(validator.validate(), validator.report())
	# Let the named Gannet show whenever the board's been read, taken or not: both on the hard.
	for prop: Dictionary in db.regions[WRACKHOLM]["props"]:
		if str(prop.get("model", "")).ends_with("gannet_hulk_named.glb"):
			prop["if"] = "flag:wrackholm_board_read"
	validator = ContentValidator.new(db)
	assert_false(validator.validate(), "two Gannets at once fails")
	assert_true(validator.report().contains("prop variants 'gannet_hulk_bare.glb' and 'gannet_hulk_named.glb'")
			or validator.report().contains("prop variants 'gannet_hulk_named.glb' and 'gannet_hulk_bare.glb'"), validator.report())
	# An overlay of another family on the same spot (the gold streak on the lit Heron) is fine.
	db = load_content()
	(db.regions[WRACKHOLM]["props"] as Array).append({"model": DRESSING + "float_pile.glb", "position": [-5.5, 0, -1.0]})
	validator = ContentValidator.new(db)
	assert_true(validator.validate(), validator.report())


func test_wennas_cord_hangs_bare_once_her_answer_is_given() -> void:
	var db := load_content()
	var placements: Array = (db.get_region(WRACKHOLM)["npcs"] as Array).filter(func(p: Dictionary) -> bool: return p["npc"] == "wenna")
	assert_eq(placements.size(), 3, "Wenna: brass, given, burned")
	var state := fresh_state(db)
	assert_eq(_wenna_model(db, placements, state), "", "the brass at her neck (her own model)")
	state.add_item("wennas_answer")
	assert_eq(_wenna_model(db, placements, state), "wenna_nobrass", "given: the cord bare")
	state.add_item("wennas_answer", -1)
	state.set_flag("wrackholm_beacon_burned", "answer")
	assert_eq(_wenna_model(db, placements, state), "wenna_nobrass", "burned: the cord bare")
	state.set_flag("wrackholm_beacon_burned", "board")
	assert_eq(_wenna_model(db, placements, state), "", "given back (the board burned instead): the brass again")
	for p: Dictionary in placements:
		assert_eq(p["position"], placements[0]["position"], "on her coil of hawser every time")
	assert_true(ResourceLoader.exists(CHARACTERS + "wenna_nobrass.glb"), "the model")


func test_the_gannets_board_shows_its_chalk_once_read() -> void:
	var db := load_content()
	var state := fresh_state(db)
	assert_eq(_gannet(db, state), "gannet_hulk", "blank as slate")
	state.set_flag("wrackholm_board_read", true)
	assert_eq(_gannet(db, state), "gannet_hulk_named", "the names in chalk")
	state.set_flag("wrackholm_board_taken", true)
	assert_eq(_gannet(db, state), "gannet_hulk_bare", "prised off for the Wrack")
	state.set_flag("wrackholm_board_taken", false)
	assert_eq(_gannet(db, state), "gannet_hulk_named", "back on its nails, still named")
	assert_true(ResourceLoader.exists(DRESSING + "gannet_hulk_named.glb"), "the model")


func test_the_teeth_stand_in_surf_and_the_road_has_gullies() -> void:
	var db := load_content()
	var data: Dictionary = db.get_region(TEETH)
	var region := Region.new()
	region.data = data
	region.field = TerrainField.from_data(data["ground"], float(data["water_level"]))
	var surf := 0
	for prop: Dictionary in data["props"]:
		if not prop.has("wading"):
			continue
		var node := region._build_prop(prop)
		if node.find_child("WadingFoam", false, false) != null:
			surf += 1
		node.free()
	region.free()
	assert_true(surf >= 8, "the dead-end teeth in the water break the surf (%d)" % surf)
	var gullies: Array = (data["ground"]["paint"] as Array).filter(func(z: Dictionary) -> bool: return str(z.get("note", "")).contains("gully"))
	assert_true(gullies.size() >= 5, "gullies across the reef road (%d)" % gullies.size())
	var field := TerrainField.from_data(data["ground"], float(data["water_level"]))
	for zone: Dictionary in gullies:
		var mid := (JsonUtil.to_vector3(zone["path"][0]) + JsonUtil.to_vector3(zone["path"][1])) * 0.5
		assert_true(field.height_at(mid.x, mid.y) > field.water_level, "a gully is wet rock above the water, still walkable (%s)" % mid)


func _wenna_model(db: ContentDatabase, placements: Array, state: WorldState) -> String:
	var shown := placements.filter(func(p: Dictionary) -> bool: return Conditions.evaluate(p.get("if"), state))
	assert_eq(shown.size(), 1, "one Wenna")
	return str(shown[0].get("model", "")).get_file().get_basename() if not shown.is_empty() else "?"


func _gannet(db: ContentDatabase, state: WorldState) -> String:
	var shown := (db.get_region(WRACKHOLM)["props"] as Array).filter(func(p: Dictionary) -> bool:
		return str(p.get("model", "")).get_file().begins_with("gannet_hulk") and Conditions.evaluate(p.get("if"), state))
	assert_eq(shown.size(), 1, "one Gannet on the hard")
	return str(shown[0]["model"]).get_file().get_basename() if not shown.is_empty() else "?"


## The first step or option (depth first) whose `set` names `flag`.
func _first_set(node: Variant, flag: String) -> Dictionary:
	if node is Dictionary:
		if (node as Dictionary).get("set") is Dictionary and (node["set"] as Dictionary).has(flag):
			return node
		for value: Variant in (node as Dictionary).values():
			var hit := _first_set(value, flag)
			if not hit.is_empty():
				return hit
	elif node is Array:
		for value: Variant in node:
			var hit := _first_set(value, flag)
			if not hit.is_empty():
				return hit
	return {}
