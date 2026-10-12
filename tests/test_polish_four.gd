extends TestCase
## Day 38 — Polish/debt pass four: an NPC's placements are proved mutually exclusive by the
## validator (Pell's beach placement now negates the Thornwold one); Dunstan sits off the end of
## the long walk with his boots in the mere; walking past Hesper (no `fen_ember`) still reads.

const FEN := "glasswater_fen"


func test_joint_witness_finds_a_shared_state() -> void:
	var defaults := {"a": false, "word": ""}
	assert_eq(Conditions.joint_witness(["flag:a", "!flag:a"], defaults), {}, "a flag and its negation never hold together")
	assert_true(Conditions.joint_witness(["flag:a", "flag:word=mara"], defaults).has("flag:word"), "independent terms can")
	assert_eq(Conditions.joint_witness(["flag:word=mara", "flag:word=own"], defaults), {}, "one flag can't hold two values")
	assert_eq(Conditions.joint_witness([["flag:word=mara"], ["!flag:word=", "!flag:word=none", "!flag:word=mara"]], defaults), {},
			"...nor a value and its exclusion")
	var w := Conditions.joint_witness(["!flag:word=", "!flag:word=mara"], defaults)
	assert_false(w.is_empty(), "a value nobody named still counts (%s)" % JSON.stringify(w))
	assert_eq(Conditions.joint_witness(["quest:q=done", "stage:q=s1"], defaults), {}, "a done quest is at no stage")
	assert_false(Conditions.joint_witness(["quest:q=active", "!stage:q=s1"], defaults).is_empty(), "active at another stage")
	assert_eq(Conditions.joint_witness(["item:x>=2", "!item:x"], defaults), {}, "two of a thing means having it")


func test_every_placed_npc_shows_in_one_place_at_most() -> void:
	var db := load_content()
	var validator := ContentValidator.new(db)
	assert_true(validator.validate(), validator.report())
	# Pell: the beach until the ferry comes, the dock after — and Thornwold, if they crossed.
	var beach: Dictionary = (db.get_region("shingle_point")["npcs"] as Array).filter(func(p: Dictionary) -> bool: return p["npc"] == "pell")[0]
	assert_true(Conditions.terms(beach["if"]).has("!flag:thornwold_pell_landed"), "the beach Pell gives way to the Thornwold one")


func test_validator_catches_an_npc_in_two_places() -> void:
	var db := load_content()
	var placements: Array = db.regions[FEN]["npcs"]
	for p: Dictionary in placements:
		if p["npc"] == "dunstan" and Conditions.terms(p["if"]).has("flag:fen_dunstan_word=mara"):
			p["if"] = ["quest:a_light_for_glasswater=done"]
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	assert_true(validator.report().contains("npc 'dunstan' can show here and in glasswater_fen at once"), validator.report())


func test_dunstan_sits_with_his_boots_in_the_mere() -> void:
	var db := load_content()
	var region: Dictionary = db.get_region(FEN)
	var water := float(region["water_level"])
	var field := TerrainField.from_data(region["ground"], water)
	for p: Dictionary in region["npcs"]:
		if p["npc"] != "dunstan":
			continue
		var at := JsonUtil.to_vector3(p["position"])
		var seat := at.y + field.surface_at(at.x, at.z)
		assert_true(seat < water and seat > water - 0.3, "his tussock stands in the shallows (%.2f, water %.2f)" % [seat, water])
		var facing := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(float(p["rotation_y"])))
		for reach: float in [0.35, 0.5, 0.65]:
			var boot := at + facing * reach
			assert_true(field.height_at(boot.x, boot.z) < seat, "his boots in the water off the tussock, not on the hummock (%.2f m out)" % reach)
		# Still at the end of the walk: the player can come within talking distance on the boards.
		assert_true(Vector2(at.x, at.z).distance_to(Vector2(1, -29)) < 1.2, "by the end of the long walk")
		var heron := Vector2(-13, -31) - Vector2(at.x, at.z)
		assert_true(Vector2(facing.x, facing.z).angle_to(heron) < deg_to_rad(10) and Vector2(facing.x, facing.z).angle_to(heron) > -deg_to_rad(10),
				"facing the lit Heron")


func test_walking_past_hesper_still_reads() -> void:
	# The player can meet Corran (and later Dunstan) without ever being asked to cup the ember.
	var db := load_content()
	var state := fresh_state(db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "thornwold_landed", "fen_landed"]:
		state.set_flag(flag, true)
	state.set_flag("lanes_ferry_at", "fen")
	assert_eq(str(state.get_flag("fen_ember")), str(db.flag_default("fen_ember")), "Hesper never asked")
	var corran := play_dialogue(db, state, "corran", [])
	assert_true(corran.contains("Corran Teal"), "Corran introduces himself")
	assert_false(corran.contains("Hiding it for her") or corran.contains("Not hiding it"), "...without remarking on a choice never made")
	assert_true(state.get_flag("fen_met_corran") == true, "met Corran")
