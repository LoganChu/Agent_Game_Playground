extends TestCase
## Day 115: settings follow-ups. A window size for windowed mode (presets that fit the screen; off in
## fullscreen), a 3D render scale on the root viewport, and Clear for the quick save/load pad buttons (the
## actions the game needs on a pad can only be moved). All of it round-trips through settings.cfg, and a bad
## file falls back to the defaults.

const SCRATCH := "user://test_display_settings.cfg"


func _fresh() -> GameSettings:
	var settings := GameSettings.new()
	settings.path = SCRATCH
	DirAccess.remove_absolute(SCRATCH)
	return settings


func _restore() -> void:
	DirAccess.remove_absolute(SCRATCH)
	GameSettings.new().apply_all()
	GameSettings.set_current(null)


func _press(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


func test_window_size_and_render_scale() -> void:
	var settings := _fresh()
	assert_eq(settings.window_size, GameSettings.DEFAULT_WINDOW_SIZE, "starts at the project's size")
	assert_eq(GameSettings.WINDOW_SIZES[0], Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		int(ProjectSettings.get_setting("display/window/size/viewport_height"))), "the first preset is the project's size")
	assert_eq(settings.window_size_label(), "1280 × 720")
	assert_eq(GameSettings.fitting_window_sizes().size(), GameSettings.WINDOW_SIZES.size(), "headless: every size fits")
	settings.cycle_window_size()
	assert_eq(settings.window_size, Vector2i(1600, 900), "the next size")
	for i in GameSettings.WINDOW_SIZES.size() - 1:
		settings.cycle_window_size()
	assert_eq(settings.window_size, GameSettings.WINDOW_SIZES[0], "it wraps")
	settings.set_window_size(Vector2i(1234, 567))
	assert_eq(settings.window_size, GameSettings.WINDOW_SIZES[0], "an unknown size is ignored")
	settings.set_render_scale(0.2)
	assert_true(absf(settings.render_scale - GameSettings.RENDER_SCALE_MIN) < 0.001, "clamped low")
	settings.set_render_scale(0.75)
	var root := (Engine.get_main_loop() as SceneTree).root
	assert_true(absf(root.scaling_3d_scale - 0.75) < 0.001, "the root viewport follows")
	settings.reset_values()
	settings.apply_all()
	assert_true(absf(root.scaling_3d_scale - 1.0) < 0.001, "defaults draw at full scale")
	_restore()


func test_display_file_round_trip() -> void:
	var settings := _fresh()
	settings.set_window_size(Vector2i(1920, 1080))
	settings.set_render_scale(0.6)
	assert_true(settings.save(), "saved")
	var again := _loaded()
	assert_eq(again.window_size, Vector2i(1920, 1080), "size round-trips")
	assert_true(absf(again.render_scale - 0.6) < 0.001, "scale round-trips")
	assert_eq(GameSettings.parse_size("1600x900"), Vector2i(1600, 900))
	assert_eq(GameSettings.parse_size("wide"), Vector2i.ZERO)
	for bad: Array in [["1234x567", 9.0], ["huge", "half"], ["1600x", -1.0]]:
		var cfg := ConfigFile.new()
		cfg.set_value("display", "window_size", bad[0])
		cfg.set_value("display", "render_scale", bad[1])
		cfg.save(SCRATCH)
		var loaded := _loaded()
		assert_eq(loaded.window_size, GameSettings.DEFAULT_WINDOW_SIZE, "a bad size falls back: %s" % str(bad[0]))
		assert_true(loaded.render_scale >= GameSettings.RENDER_SCALE_MIN and loaded.render_scale <= GameSettings.RENDER_SCALE_MAX,
			"a bad scale stays in range: %s" % str(bad[1]))
	_restore()


func _loaded() -> GameSettings:
	var out := GameSettings.new()
	out.path = SCRATCH
	out.load_file()
	return out


func test_clearing_quick_buttons() -> void:
	var settings := _fresh()
	settings.apply_all()
	assert_true(GameSettings.can_clear_button("quick_save") and GameSettings.can_clear_button("quick_load"), "the quick ones can go")
	for action in ["interact", "journal", "inventory", "lanes", "tab_left", "tab_right"]:
		assert_false(GameSettings.can_clear_button(action), "%s can only be moved" % action)
	assert_true(settings.clear_button("interact") != "", "interact can't be cleared")
	assert_eq(settings.button_for("interact"), JOY_BUTTON_A, "and keeps A")
	assert_true(settings.clear_button("quick_save") != "", "nothing to clear yet")
	assert_eq(settings.rebind_button("quick_save", JOY_BUTTON_RIGHT_STICK), "", "quicksave on RS")
	assert_true(InputMap.event_is_action(_press(JOY_BUTTON_RIGHT_STICK), "quick_save"), "RS saves")
	assert_true(settings.save(), "saved with RS")
	assert_eq(settings.clear_button("quick_save"), "", "cleared")
	assert_eq(settings.button_for("quick_save"), JOY_BUTTON_INVALID, "no button")
	assert_false(InputMap.event_is_action(_press(JOY_BUTTON_RIGHT_STICK), "quick_save"), "RS no longer saves")
	assert_eq(settings.rebind_button("quick_load", JOY_BUTTON_RIGHT_STICK), "", "RS is free for quickload")
	settings.save()
	var again := _loaded()
	assert_eq(again.button_for("quick_save"), JOY_BUTTON_INVALID, "the clear round-trips")
	assert_eq(again.button_for("quick_load"), JOY_BUTTON_RIGHT_STICK)
	_restore()


func test_menu_offers_size_scale_and_clear() -> void:
	var settings := _fresh()
	GameSettings.set_current(settings)
	settings.apply_all()
	var menu := PauseMenu.new()
	menu._build()
	menu._show_page(MenuScreen.Page.SETTINGS)
	assert_true(menu.press("Window size: 1280 × 720"), "Settings offers the window size")
	assert_eq(settings.window_size, Vector2i(1600, 900), "pressing steps it")
	assert_true(menu.buttons().any(func(b: Button) -> bool: return b.text == "Window size: 1600 × 900"), "it shows the new value")
	assert_eq(_loaded().window_size, Vector2i(1600, 900), "saved at once")
	var scale := menu.slider("3D render scale")
	assert_true(scale != null, "a render scale slider")
	if scale:
		# Outside the scene tree Range doesn't emit value_changed (see test_settings._slide): emit it by hand.
		scale.set_value_no_signal(70.0)
		scale.value_changed.emit(scale.value)
		assert_true(absf(settings.render_scale - 0.7) < 0.001, "the slider sets the scale")
		assert_true(absf(_loaded().render_scale - 0.7) < 0.001, "and saves it")
	assert_true(menu.press("Display: Windowed"), "to fullscreen")
	var size_row: Button = null
	for b in menu.buttons():
		if b.text.begins_with("Window size"):
			size_row = b
	assert_true(size_row != null and size_row.disabled, "the size is off in fullscreen")
	menu._show_page(MenuScreen.Page.CONTROLS)
	assert_true(menu.clear_button("quick_save") == null, "no Clear while quicksave has no button")
	assert_true(menu.clear_button("interact") == null, "never one for interact")
	assert_true(menu.press("Quicksave — F5"), "pick quicksave")
	menu.capture_button(JOY_BUTTON_RIGHT_STICK)
	var clear := menu.clear_button("quick_save")
	assert_true(clear != null, "now a Clear beside it")
	assert_true(menu.buttons().any(func(b: Button) -> bool: return b.text == "Quicksave — F5 · RS"), "the row keeps its text")
	if clear:
		clear.pressed.emit()
	assert_eq(settings.button_for("quick_save"), JOY_BUTTON_INVALID, "Clear takes it off the pad")
	assert_eq(menu.note(), "Quicksave: no pad button.")
	assert_true(menu.clear_button("quick_save") == null, "and the Clear goes")
	assert_eq(_loaded().button_for("quick_save"), JOY_BUTTON_INVALID, "saved at once")
	menu.free()
	_restore()
