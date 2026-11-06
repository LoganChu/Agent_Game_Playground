extends TestCase
## Day 88, polish pass thirteen: a spawn can face somewhere (`spawn_facing`) so stair feet and
## interiors open on the room, not the north wall; the screenshot helper's `--at` yaw turns the
## Wakebearer with the camera; a scenario lint (a choice made with its quest left behind, and
## quests carried open across an act without being restated); paint paths that drift off an axis
## warn; Hild steps out from behind the Provost at the lectern.

const LOWER := "cindermoor_lower_rooms"

var _saved_db: ContentDatabase


func _player() -> Player:
	_saved_db = Content.db
	if Content.db.game.is_empty():
		Content.db = load_content()
	var player := Player.new()
	player._ready()
	return player


func _done(player: Player) -> void:
	player.free()
	Content.db = _saved_db
	GameState.input_locked = false


func _xz(v: Variant) -> Vector2:
	var a: Array = v
	return Vector2(float(a[0]), float(a[1]) if a.size() == 2 else float(a[2]))


func test_face_towards_turns_the_body_and_puts_the_camera_behind() -> void:
	var player := _player()
	for dir: Vector3 in [Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(3, 0, -4)]:
		player.face_towards(dir)
		var want := dir.normalized()
		var body := Basis(Vector3.UP, player.heading()) * Vector3(0, 0, 1)
		var view := Basis(Vector3.UP, player.view_yaw()) * Vector3(0, 0, -1)
		assert_true(body.dot(want) > 0.999, "the body faces %s (got %s)" % [dir, body])
		assert_true(view.dot(want) > 0.999, "the camera looks along %s (got %s)" % [dir, view])
	var before := player.heading()
	player.face_towards(Vector3.ZERO)
	assert_eq(player.heading(), before, "no direction: nothing turns")
	_done(player)


func test_a_spawn_faces_its_point_and_others_keep_their_heading() -> void:
	var region := Region.new()
	region.data = {
		"spawn_points": {"default": [0, 0, 0], "door": [4, 0, 0]},
		"spawn_facing": {"door": [0, 0]},
	}
	assert_eq(region.spawn_facing("door"), Vector3(0, 0, 0))
	assert_eq(region.spawn_facing("default"), null, "no facing given: keep the heading")
	region.data["spawn_facing"]["default"] = [0, -5]
	assert_eq(region.spawn_facing("nowhere"), Vector3(0, 0, -5), "an unknown spawn falls back to default's")
	region.free()


func test_the_lower_rooms_open_on_the_room() -> void:
	var data: Dictionary = load_content().get_region(LOWER)
	var root := Vector2.ZERO
	for prop: Dictionary in data["props"]:
		if str(prop.get("model", "")).ends_with("flame_root.glb"):
			root = _xz(prop["position"])
	for spawn: String in data["spawn_points"]:
		var at := _xz(data["spawn_points"][spawn])
		assert_true(data["spawn_facing"].has(spawn), "spawn %s has a facing" % spawn)
		var look := (_xz(data["spawn_facing"][spawn]) - at).normalized()
		assert_true(look.dot((root - at).normalized()) > 0.95, "spawn %s looks toward the flame's root" % spawn)
	# Coming back up, the Wakebearer looks out at the ring, not into the Spire's wall.
	var foot: Dictionary = load_content().get_region("cindermoor_spire_foot")
	var up := _xz(foot["spawn_points"]["from_lower"])
	var out := (_xz(foot["spawn_facing"]["from_lower"]) - up).normalized()
	assert_true(out.dot((up - Vector2(0, -6)).normalized()) > 0.3, "up the stair: facing away from the Spire")


func test_hild_and_the_provost_both_show_from_the_stair() -> void:
	var data: Dictionary = load_content().get_region(LOWER)
	var at := _xz(data["spawn_points"]["from_stair"])
	var bearing := {}
	for n: Dictionary in data["npcs"]:
		var to := _xz(n["position"]) - at
		bearing[str(n["npc"])] = atan2(to.y, -to.x)
	var apart := absf(angle_difference(float(bearing["hild"]), float(bearing["provost"])))
	assert_true(apart > deg_to_rad(10.0), "from the stair foot Hild isn't hidden behind the Provost (%.0f°)" % rad_to_deg(apart))


func test_the_validator_checks_spawn_facing() -> void:
	var db := load_content()
	var region: Dictionary = db.regions[LOWER]
	var saved: Variant = region["spawn_facing"].duplicate(true)
	for bad: Dictionary in [{"nowhere": [0, 0]}, {"default": [1]}, {"default": [4.4, 0.6]}]:
		region["spawn_facing"] = bad
		var v := ContentValidator.new(db)
		v.validate()
		assert_true(v.errors.any(func(e: String) -> bool: return e.contains("spawn_facing")), "caught %s" % bad)
	region["spawn_facing"] = saved


func test_a_choice_made_with_its_quest_left_behind_is_caught() -> void:
	var db := load_content()
	# Wenna's walk to her hearth sets the bend `walked` and moves her quest to `her_hearth`.
	var half: Array[Dictionary] = [{"id": "x", "act": "II", "region": "thornwold_colls_hearth",
			"flags": {"thornwold_bend": "walked"}, "quests": {"the_bend_in_the_road": "the_bend"}}]
	var found := Scenarios.half_made(db, half)
	assert_true(found.any(func(e: String) -> bool: return e.contains("the_bend_in_the_road") and e.contains("her_hearth")), str(found))
	half[0]["quests"]["the_bend_in_the_road"] = "her_hearth"
	assert_true(Scenarios.half_made(db, half).is_empty(), "moved on with the choice: fine")
	assert_true(Scenarios.half_made(db, Scenarios.all()).is_empty(), str(Scenarios.half_made(db, Scenarios.all())))


func test_a_quest_carried_open_into_a_new_act_must_be_restated() -> void:
	var db := load_content()
	var list: Array[Dictionary] = [
		{"id": "a", "act": "I", "region": "saltmarrow", "quests": {"lost_things": "find_pebble"}},
		{"id": "b", "act": "II", "region": "saltmarrow", "inherits": "a"},
		{"id": "c", "act": "II", "region": "saltmarrow", "inherits": "b"},
	]
	var found := Scenarios.half_made(db, list)
	assert_eq(found.size(), 1, "only the checkpoint that crosses the act: %s" % [found])
	assert_true(found[0].contains("'b'") and found[0].contains("lost_things"))
	list[1]["quests"] = {"lost_things": "find_pebble"}
	assert_true(Scenarios.half_made(db, list).is_empty(), "restated: a decision written down")
	list[1]["quests"] = {"lost_things": "done"}
	assert_true(Scenarios.half_made(db, list).is_empty(), "closed at the act: nothing carried")


func test_paths_that_drift_off_an_axis_warn() -> void:
	assert_eq(ContentValidator.sawing_legs([[0, -15], [0, -40], [0, -70]]).size(), 0, "straight along an axis")
	assert_eq(ContentValidator.sawing_legs([[0, 0], [20, 20]]).size(), 0, "a real diagonal")
	assert_eq(ContentValidator.sawing_legs([[0, 0], [4, 0.3]]).size(), 0, "short legs are turns")
	assert_eq(ContentValidator.sawing_legs([[0, 0], [9, -3], [20, -5]]).size(), 0, "a wandering track reads as ragged")
	assert_eq(ContentValidator.sawing_legs([[0, -40], [0.5, -70]]).size(), 1, "a 30 m road off by half a metre")
	assert_eq(ContentValidator.sawing_legs([[0, -1.2], [15, -1.4]]).size(), 1, "Day 84's cresset leg")
