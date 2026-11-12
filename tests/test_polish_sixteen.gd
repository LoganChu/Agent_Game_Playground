extends TestCase
## Day 100 — polish pass sixteen. The Lamp is named "Wynn Sallow" over its head and in the dialogue box once the
## player has told it its name (and stays "The Lamp" if it chose to leave it in the Book); someone seated is framed a
## touch lower in conversation; a small interior can shorten the camera's reach (region `camera_distance`); and the
## camera rises over something low at the Wakebearer's back (the lantern room's cradle) instead of snapping in.

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


func _ease(player: Player, steps: int = 40) -> void:
	for i in steps:
		player._update_framing(0.1)


func test_the_lamp_is_wynn_once_told() -> void:
	var db := load_content()
	var state := fresh_state(db)
	var lamp := db.get_npc("lamp")
	assert_eq(ContentDatabase.npc_display_name(lamp, state), "The Lamp", "before the Book")
	state.set_flag("thornwold_lamp_name", "left")
	assert_eq(ContentDatabase.npc_display_name(lamp, state), "The Lamp", "left in the Book: still the Lamp")
	state.set_flag("thornwold_lamp_name", "told")
	assert_eq(ContentDatabase.npc_display_name(lamp, state), "Wynn Sallow", "told: its own name")
	var runner := DialogueRunner.new(db, state)
	assert_eq(runner.speaker_name("lamp"), "Wynn Sallow", "the dialogue box names it too")


func test_seated_styles() -> void:
	for style: String in ["sit", "bottle", "mend"]:
		assert_true(CharacterRig.is_seated_style(style), style)
	for style: String in ["breathe", "rake", "chisel", "scrape", "still"]:
		assert_false(CharacterRig.is_seated_style(style), style)
	var db := load_content()
	var aldous := NpcActor.new()
	var bench: Dictionary = {}
	for entry: Dictionary in db.get_region("saltmarrow").get("npcs", []):
		if entry.get("npc") == "aldous":
			bench = entry
	aldous.setup("aldous", Region.placed_npc_data(db.get_npc("aldous"), bench))
	assert_true(aldous.is_seated(), "Aldous on his bench sits")
	var mara := NpcActor.new()
	mara.setup("mara", db.get_npc("mara"))
	assert_false(mara.is_seated(), "Mara stands")
	aldous.free()
	mara.free()


func test_someone_seated_is_framed_lower() -> void:
	var player := _player()
	var yaw_node := player.find_child("CameraYaw", true, false) as Node3D
	var pitch_node := player.find_child("CameraPitch", true, false) as Node3D
	GameState.input_locked = true
	player.frame_towards(Vector3(2.0, 0.0, -1.5))
	_ease(player)
	var standing_y := yaw_node.position.y
	var standing_pitch := pitch_node.rotation.x
	assert_true(is_equal_approx(standing_y, Player.CAMERA_PIVOT.y), "standing: the pivot at its height")
	assert_true(is_equal_approx(standing_pitch, deg_to_rad(Player.DIALOGUE_PITCH)), "standing: the usual pitch")
	GameState.input_locked = false
	_ease(player)
	GameState.input_locked = true
	player.frame_towards(Vector3(2.0, 0.0, -1.5), true)
	_ease(player)
	assert_eq(player.framed_low(), 1.0)
	assert_true(absf(yaw_node.position.y - (Player.CAMERA_PIVOT.y - Player.DIALOGUE_LOW_DROP)) < 0.01,
			"seated: the pivot drops (%.2f)" % yaw_node.position.y)
	assert_true(pitch_node.rotation.x > standing_pitch + 0.05, "seated: looking across, not down")
	# A standing second speaker joins: the shot goes halfway back up.
	assert_true(player.frame_also(Vector3(-1.5, 0.0, -3.0), false))
	assert_eq(player.framed_low(), 0.5)
	_ease(player)
	var half := Player.CAMERA_PIVOT.y - Player.DIALOGUE_LOW_DROP * 0.5
	assert_true(absf(yaw_node.position.y - half) < 0.02, "one of two sits: half the drop (%.2f)" % yaw_node.position.y)
	GameState.input_locked = false
	_ease(player)
	assert_true(yaw_node.position.is_equal_approx(Player.CAMERA_PIVOT), "pivot home once the box closes")
	assert_eq(player.framed_low(), 0.0)
	_done(player)


func test_a_region_can_shorten_the_reach() -> void:
	var player := _player()
	var arm := player.find_child("CameraArm", true, false) as SpringArm3D
	assert_eq(player.camera_reach(), Player.CAMERA_DISTANCE, "the usual reach")
	player.set_camera_reach(4.5)
	assert_eq(arm.spring_length, 4.5, "a small room: a shorter arm")
	GameState.input_locked = true
	player.frame_towards(Vector3(2.5, 0.0, -1.0))
	_ease(player)
	assert_true(is_equal_approx(arm.spring_length, Player.DIALOGUE_DISTANCE), "a conversation still frames at its distance")
	assert_true(player.frame_also(Vector3(-2.0, 0.0, -3.0)))
	_ease(player)
	assert_true(arm.spring_length <= 4.5 + 0.001, "a group shot never reaches past the room's arm (%.2f)" % arm.spring_length)
	GameState.input_locked = false
	_ease(player)
	assert_true(is_equal_approx(arm.spring_length, 4.5), "back to the room's reach")
	player.set_camera_reach(0.0)
	assert_eq(player.camera_reach(), Player.CAMERA_DISTANCE, "no camera_distance: the usual reach")
	player.set_camera_reach(1.0)
	assert_eq(player.camera_reach(), Player.CAMERA_REACH_MIN, "never shorter than the minimum")
	_done(player)


func test_the_lantern_room_shortens_the_reach_and_the_validator_checks_it() -> void:
	var db := load_content()
	var reach: Variant = db.get_region("cindermoor_lantern_room").get("camera_distance")
	assert_true(reach is float and float(reach) < Player.CAMERA_DISTANCE, "the lantern room has a shorter reach")
	db.regions["saltmarrow"]["camera_distance"] = 1.0
	db.regions["thornwold_landing"]["camera_distance"] = "near"
	var validator := ContentValidator.new(db)
	assert_false(validator.validate())
	var report := validator.report()
	assert_true(report.contains("region saltmarrow: camera_distance must be a number"), report)
	assert_true(report.contains("region thornwold_landing: camera_distance must be a number"), report)


func test_the_lift_picks_the_shallowest_pitch_that_clears() -> void:
	var base := deg_to_rad(Player.CAMERA_PITCH)
	var reach := 7.0
	var clear: Array[float] = [7.0, 7.0, 7.0]
	assert_eq(Player.choose_lift(base, 6.0, clear, reach), 0.0, "clear enough at the player's pitch: no lift")
	assert_eq(Player.choose_lift(base, 1.5, clear, reach), deg_to_rad(Player.CAMERA_LIFT_PITCHES[0]), "blocked: the first lift")
	var low_wall: Array[float] = [2.0, 6.5, 7.0]
	assert_eq(Player.choose_lift(base, 1.5, low_wall, reach), deg_to_rad(Player.CAMERA_LIFT_PITCHES[1]), "a taller thing: higher")
	var roofed: Array[float] = [1.0, 1.0, 1.0]
	assert_eq(Player.choose_lift(base, 1.5, roofed, reach), 0.0, "nothing clears (a ceiling): no lift")
	var steep := deg_to_rad(-50.0)
	assert_eq(Player.choose_lift(steep, 1.5, clear, reach), deg_to_rad(Player.CAMERA_LIFT_PITCHES[2]),
			"only pitches steeper than the player's own")


func test_the_lift_only_steepens_and_conversations_ignore_it() -> void:
	var player := _player()
	var pitch_node := player.find_child("CameraPitch", true, false) as Node3D
	player._shown_lift = deg_to_rad(-48.0)
	assert_true(is_equal_approx(player.own_pitch(), deg_to_rad(-48.0)), "lifted: steeper than the player's own")
	player._update_framing(0.1)
	assert_true(is_equal_approx(pitch_node.rotation.x, deg_to_rad(-48.0)), "the camera looks down at it")
	player._pitch = deg_to_rad(-58.0)
	assert_true(is_equal_approx(player.own_pitch(), deg_to_rad(-58.0)), "never shallower than the player's own")
	player._pitch = deg_to_rad(Player.CAMERA_PITCH)
	GameState.input_locked = true
	player.frame_towards(Vector3(2.5, 0.0, -1.0))
	_ease(player)
	assert_true(is_equal_approx(pitch_node.rotation.x, deg_to_rad(Player.DIALOGUE_PITCH)), "framed: the dialogue pitch")
	_done(player)
