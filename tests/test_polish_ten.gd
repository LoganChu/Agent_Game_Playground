extends TestCase
## Day 73, polish pass ten: conversations are framed (the camera eases round past the
## Wakebearer's shoulder to the NPC, and back to where the player left it), with a setting to
## turn it off, and the speaker's floating name hidden meanwhile; and the close-camera body fades
## out rather than vanishing at 0.9 m.

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


func test_the_body_fades_between_hide_and_fade_distances() -> void:
	assert_eq(Player.body_opacity(0.3), 0.0, "gone with the camera inside it")
	assert_eq(Player.body_opacity(Player.CAMERA_HIDE_BODY - 0.01), 0.0, "gone just inside the hide distance")
	var mid := Player.body_opacity((Player.CAMERA_HIDE_BODY + Player.CAMERA_FADE_BODY) * 0.5)
	assert_true(mid > 0.2 and mid < 0.8, "half faded between (%.2f)" % mid)
	assert_eq(Player.body_opacity(Player.CAMERA_FADE_BODY), 1.0, "solid from the fade distance")
	assert_eq(Player.body_opacity(Player.CAMERA_DISTANCE), 1.0, "solid at the full distance")
	assert_true(Player.body_opacity(1.1) < Player.body_opacity(1.3), "fading in as the camera pulls out")


func test_the_body_meshes_fade_and_the_ember_light_stays() -> void:
	var player := _player()
	var meshes := player.get("_body_meshes") as Array
	assert_true(meshes.size() >= 1, "the Wakebearer's meshes are collected (%d)" % meshes.size())
	player._apply_body_opacity(0.5)
	for mesh: GeometryInstance3D in meshes:
		assert_true(mesh.visible and is_equal_approx(mesh.transparency, 0.5), "%s half faded" % mesh.name)
	player._apply_body_opacity(0.0)
	for mesh: GeometryInstance3D in meshes:
		assert_false(mesh.visible, "%s hidden at 0" % mesh.name)
	player._apply_body_opacity(1.0)
	for mesh: GeometryInstance3D in meshes:
		assert_true(mesh.visible and mesh.transparency == 0.0, "%s solid again (no alpha pass)" % mesh.name)
	var light := player.find_child("EmberLight", true, false) as OmniLight3D
	assert_true(light != null and light.visible, "the ember's light is never faded")
	_done(player)


func test_dialogue_yaw_looks_past_the_shoulder() -> void:
	# Someone 5 m to the north (-Z): looking along the line is yaw 0, swung DIALOGUE_SIDE either way.
	var north := Vector3(0, 0, -5)
	assert_true(is_equal_approx(Player.dialogue_yaw(0.4, north), Player.DIALOGUE_SIDE), "swings to the nearer side (left)")
	assert_true(is_equal_approx(Player.dialogue_yaw(-0.4, north), -Player.DIALOGUE_SIDE), "or the right")
	# Someone to the east (+X): the camera sits west of the player looking east (yaw -PI/2).
	var yaw := Player.dialogue_yaw(-PI * 0.5, Vector3(3, 0, 0))
	var forward := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)
	assert_true(forward.dot(Vector3(1, 0, 0)) > cos(Player.DIALOGUE_SIDE) - 0.01, "looking towards them")
	# Across the ±PI seam: the nearer candidate is picked by angle, not by raw value.
	var seam := Player.dialogue_yaw(PI - 0.1, Vector3(0, 0, 4))
	assert_true(absf(angle_difference(PI - 0.1, seam)) <= Player.DIALOGUE_SIDE + 0.11, "nearer across the seam (%.2f)" % seam)


func test_framing_eases_in_while_talking_and_back_after() -> void:
	var player := _player()
	var arm := player.find_child("CameraArm", true, false) as SpringArm3D
	var start_yaw := player.view_yaw()
	GameState.input_locked = true
	player.frame_towards(Vector3(2.5, 0.4, -1.0))
	player._update_framing(0.1)
	assert_true(player.framing() > 0.0 and player.framing() < 1.0, "easing in (%.2f)" % player.framing())
	for i in 20:
		player._update_framing(0.1)
	assert_eq(player.framing(), 1.0, "framed")
	assert_true(is_equal_approx(arm.spring_length, Player.DIALOGUE_DISTANCE), "closer while talking")
	var yaw_node := player.find_child("CameraYaw", true, false) as Node3D
	var slide := yaw_node.position - Player.CAMERA_PIVOT
	assert_true(slide.x > 0.5 and slide.length() <= Player.DIALOGUE_PIVOT_MAX + 0.001, "the pivot slides towards them (%s)" % slide)
	var forward := Basis(Vector3.UP, player.view_yaw()) * Vector3(0, 0, -1)
	assert_true(forward.dot(Vector3(2.5, 0, -1.0).normalized()) > cos(Player.DIALOGUE_SIDE) - 0.01, "looking towards them, past the shoulder")
	assert_true(is_equal_approx(player.camera_yaw(), start_yaw), "the player's own yaw is kept underneath")
	GameState.input_locked = false
	for i in 20:
		player._update_framing(0.1)
	assert_eq(player.framing(), 0.0, "eased back out once the dialogue closed")
	assert_true(is_equal_approx(player.view_yaw(), start_yaw), "back where the player left it")
	assert_true(is_equal_approx(arm.spring_length, Player.CAMERA_DISTANCE), "full distance again")
	assert_true(yaw_node.position.is_equal_approx(Player.CAMERA_PIVOT), "pivot home")
	_done(player)


func test_framing_ignores_someone_standing_on_top() -> void:
	var player := _player()
	GameState.input_locked = true
	player.frame_towards(Vector3(0.1, 0, 0.1))
	player._update_framing(0.5)
	assert_eq(player.framing(), 0.0, "no direction to frame")
	_done(player)


func test_the_setting_round_trips_and_defaults_on() -> void:
	var settings := GameSettings.new()
	settings.path = "user://test_polish_ten.cfg"
	assert_true(settings.dialogue_camera, "on by default")
	settings.set_dialogue_camera(false)
	assert_true(settings.save(), "saved")
	var again := GameSettings.new()
	again.path = settings.path
	again.load_file()
	assert_false(again.dialogue_camera, "off survives a reload")
	again.reset_values()
	assert_true(again.dialogue_camera, "reset turns it back on")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.path))


func test_the_speaker_s_name_hides_while_talking() -> void:
	var db := load_content()
	var actor := NpcActor.new()
	actor.setup("mara", db.get_npc("mara"))
	actor._build_body()
	var label := actor._label
	assert_true(label != null and label.visible, "the name shows over the head")
	var was := GameState.input_locked
	actor._talking = true  # as face() sets it when the player starts the conversation (needs the tree)
	GameState.input_locked = true
	actor._process(0.05)
	assert_false(label.visible, "talking: the dialogue box names her instead")
	GameState.input_locked = false
	actor._process(0.05)
	assert_true(label.visible, "the dialogue closed: the name is back")
	GameState.input_locked = was
	actor.free()
