extends TestCase
## Settings (GameSettings): volumes on audio buses, text size, camera sensitivity/invert,
## key rebinding (swaps, secondaries, reserved keys), user://settings.cfg round trip and
## tolerance of bad files; the pause menu's Settings and Controls pages.

const SCRATCH := "user://test_settings.cfg"


func _fresh() -> GameSettings:
	var settings := GameSettings.new()
	settings.path = SCRATCH
	DirAccess.remove_absolute(SCRATCH)
	return settings


## Puts the shared state (InputMap, theme) back the way the other tests expect it.
func _restore() -> void:
	DirAccess.remove_absolute(SCRATCH)
	var defaults := GameSettings.new()
	defaults.apply_all()
	GameSettings.set_current(null)


func _keys_of(action: String) -> Array[Key]:
	var out: Array[Key] = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			out.append((ev as InputEventKey).physical_keycode)
	return out


## Moves a settings slider as the player would. (Outside the scene tree — the test runner's
## root isn't in it yet — Range doesn't emit value_changed, so emit it by hand.)
func _slide(menu: PauseMenu, label: String, value: float) -> void:
	var slider := menu.slider(label)
	assert_true(slider != null, "%s slider" % label)
	if slider:
		slider.set_value_no_signal(value)
		slider.value_changed.emit(slider.value)


func test_defaults() -> void:
	var settings := _fresh()
	for bus in GameSettings.BUSES:
		assert_eq(settings.volume(bus), GameSettings.DEFAULT_VOLUME, "%s at the default volume" % bus)
	assert_eq(settings.text_scale, 1.0, "normal text")
	assert_eq(settings.text_size_label(), "Normal", "text size label")
	assert_eq(settings.camera_sensitivity, 1.0, "camera at 100%")
	assert_false(settings.invert_x or settings.invert_y, "nothing inverted")
	assert_eq(settings.key_for("interact"), KEY_E, "E interacts")
	assert_false(settings.load_file(), "a missing file is fine (defaults)")
	_restore()


func test_volume_drives_the_bus() -> void:
	var settings := _fresh()
	settings.set_volume("Effects", 0.5)
	var index := AudioServer.get_bus_index("Effects")
	assert_true(index > 0, "the Effects bus exists")
	assert_true(is_equal_approx(AudioServer.get_bus_volume_db(index), linear_to_db(0.5)), "half volume on the bus")
	assert_false(AudioServer.is_bus_mute(index), "not muted")
	settings.set_volume("Effects", -1.0)
	assert_eq(settings.volume("Effects"), 0.0, "clamped at zero")
	assert_true(AudioServer.is_bus_mute(index), "zero mutes the bus")
	for bus in GameSettings.BUSES:
		var i := AudioServer.get_bus_index(bus)
		assert_true(i >= 0, "%s bus exists" % bus)
		if i > 0:
			assert_eq(AudioServer.get_bus_send(i), &"Master", "%s goes to Master" % bus)
	_restore()


func test_text_size_cycles_and_scales_the_theme() -> void:
	var settings := _fresh()
	settings.cycle_text_size()
	assert_eq(settings.text_size_label(), "Large", "Normal → Large")
	assert_eq(UiTheme.text_scale(), 1.25, "the theme scales")
	settings.cycle_text_size()
	settings.cycle_text_size()
	assert_eq(settings.text_size_label(), "Small", "wraps round to Small")
	settings.set_text_scale(1.1)
	assert_eq(settings.text_size_label(), "Normal", "an odd scale reads as the nearest preset")
	_restore()
	assert_eq(UiTheme.text_scale(), 1.0, "restored")


func test_camera_sensitivity_and_invert() -> void:
	var settings := _fresh()
	assert_true(settings.mouse_turn(Vector2(10, 4), 0.01).is_equal_approx(Vector2(0.1, 0.04)), "plain turn")
	settings.set_camera_sensitivity(2.0)
	settings.set_invert_y(true)
	assert_true(settings.mouse_turn(Vector2(10, 4), 0.01).is_equal_approx(Vector2(0.2, -0.08)), "doubled, up/down inverted")
	settings.set_invert_x(true)
	assert_eq(settings.yaw_factor(), -2.0, "stick yaw doubled and inverted")
	settings.set_camera_sensitivity(99.0)
	assert_eq(settings.camera_sensitivity, GameSettings.SENSITIVITY_MAX, "clamped")
	_restore()


func test_rebinding_swaps_and_updates_the_input_map() -> void:
	var settings := _fresh()
	assert_eq(settings.rebind("interact", KEY_F), "", "E → F")
	assert_eq(_keys_of("interact")[0], KEY_F, "InputMap: F interacts")
	assert_true(_keys_of("interact").has(KEY_ENTER), "Enter still interacts")
	assert_false(_keys_of("interact").has(KEY_E), "E no longer does")
	assert_eq(InputSetup.hint("interact"), "[F]", "HUD hint follows")
	assert_eq(settings.rebind("journal", KEY_F), "", "journal takes F")
	assert_eq(settings.key_for("journal"), KEY_F, "J → F")
	assert_eq(settings.key_for("interact"), KEY_J, "interact got the journal's old key (swap)")
	assert_eq(settings.rebind("inventory", KEY_UP), "", "Satchel on the up arrow")
	assert_false(_keys_of("move_forward").has(KEY_UP), "Up arrow no longer moves forward")
	assert_eq(_keys_of("move_forward"), [KEY_W] as Array[Key], "W still does")
	assert_true(settings.rebind("move_left", KEY_ESCAPE) != "", "Esc is reserved")
	assert_true(settings.rebind("move_left", KEY_P) != "", "P is the menu key")
	assert_true(settings.rebind("pause", KEY_M) != "", "the menu isn't rebindable")
	assert_eq(settings.key_for("move_left"), KEY_A, "refused rebinds change nothing")
	assert_eq(settings.rebind("interact", KEY_E), "", "back to E")
	assert_false(settings.keys.has("interact"), "a default binding isn't stored")
	_restore()
	assert_eq(_keys_of("interact"), [KEY_E, KEY_ENTER] as Array[Key], "restored")
	assert_eq(_keys_of("move_forward"), [KEY_W, KEY_UP] as Array[Key], "restored")


func test_round_trip_through_the_file() -> void:
	var settings := _fresh()
	settings.set_volume("Music", 0.3)
	settings.set_text_scale(1.5)
	settings.set_camera_sensitivity(0.5)
	settings.set_invert_y(true)
	settings.rebind("interact", KEY_SPACE)
	assert_true(settings.save(), "saves")
	var again := GameSettings.new()
	again.path = SCRATCH
	assert_true(again.load_file(), "loads")
	assert_true(is_equal_approx(again.volume("Music"), 0.3), "music volume")
	assert_eq(again.text_scale, 1.5, "text scale")
	assert_eq(again.camera_sensitivity, 0.5, "sensitivity")
	assert_true(again.invert_y and not again.invert_x, "invert")
	assert_eq(again.key_for("interact"), KEY_SPACE, "rebound key")
	assert_eq(again.keys.size(), 1, "only the changed key is stored")
	_restore()


func test_bad_file_is_tolerated() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "Master", 7.0)
	cfg.set_value("display", "text_scale", 0.1)
	cfg.set_value("camera", "sensitivity", -3)
	cfg.set_value("keys", "interact", "Escape")  # reserved
	cfg.set_value("keys", "dance", "K")  # not an action
	cfg.set_value("keys", "journal", "W")  # clashes with move_forward
	cfg.set_value("keys", "inventory", "NotAKey")
	cfg.save(SCRATCH)
	var settings := GameSettings.new()
	settings.path = SCRATCH
	assert_true(settings.load_file(), "loads")
	assert_eq(settings.volume("Master"), 1.0, "volume clamped")
	assert_eq(settings.text_scale, 0.75, "text scale clamped")
	assert_eq(settings.camera_sensitivity, GameSettings.SENSITIVITY_MIN, "sensitivity clamped")
	assert_eq(settings.key_for("interact"), KEY_E, "reserved key ignored")
	assert_eq(settings.key_for("inventory"), KEY_I, "unknown key name ignored")
	var seen := {}
	for action in InputSetup.REBINDABLE:
		assert_false(seen.has(settings.key_for(action)), "%s's key is unique" % action)
		seen[settings.key_for(action)] = true
	_restore()


func test_pause_menu_settings_pages() -> void:
	var settings := _fresh()
	GameSettings.set_current(settings)
	var menu := PauseMenu.new()
	menu._build()
	menu._show_page(PauseMenu.Page.MAIN)
	assert_true(menu.press("Settings"), "the main page offers Settings")
	assert_eq(menu.page, PauseMenu.Page.SETTINGS, "Settings page")
	for label in GameSettings.BUS_LABELS:
		assert_true(menu.slider(label + " volume") != null, "%s volume slider" % label)
	_slide(menu, "Music volume", 40.0)
	assert_true(is_equal_approx(settings.volume("Music"), 0.4), "the slider sets the volume")
	_slide(menu, "Camera sensitivity", 150.0)
	assert_eq(settings.camera_sensitivity, 1.5, "the slider sets sensitivity")
	assert_true(menu.press("Text size: Normal"), "text size button")
	assert_true(menu.press("Text size: Large"), "it shows the new size")
	assert_true(menu.press("Invert camera up/down: Off"), "invert button")
	assert_true(settings.invert_y, "inverted")
	assert_true(menu.press("Invert camera up/down: On"), "it shows On")
	assert_true(menu.press("Controls"), "Controls page")
	assert_eq(menu.page, PauseMenu.Page.CONTROLS, "on Controls")
	assert_eq(menu.buttons().size(), InputSetup.REBINDABLE.size() + 1, "a button per action + Back")
	assert_true(menu.press("Interact / talk — E"), "interact shows E")
	assert_eq(menu.capturing, "interact", "waiting for a key")
	menu.capture_key(KEY_ESCAPE)
	assert_eq(settings.key_for("interact"), KEY_E, "Esc cancels")
	menu.press("Interact / talk")
	menu.capture_key(KEY_G)
	assert_eq(settings.key_for("interact"), KEY_G, "G interacts now")
	assert_true(menu.press("Interact / talk — G"), "the button shows G")
	menu.capture_key(KEY_P)
	assert_eq(settings.key_for("interact"), KEY_G, "P refused")
	assert_true(menu._note.text.contains("Menu"), "and says why (%s)" % menu._note.text)
	assert_false(FileAccess.file_exists(SCRATCH), "not saved while on the settings pages")
	menu.press("Back")
	assert_eq(menu.page, PauseMenu.Page.SETTINGS, "Back from Controls goes to Settings")
	menu.press("Reset to defaults")
	assert_eq(settings.key_for("interact"), KEY_G, "reset asks twice")
	menu.press("Reset to defaults")
	assert_eq(settings.key_for("interact"), KEY_E, "reset puts keys back")
	assert_eq(settings.text_scale, 1.0, "and text size")
	_slide(menu, "Master volume", 55.0)
	menu.press("Back")
	assert_eq(menu.page, PauseMenu.Page.MAIN, "back to the main page")
	var saved := GameSettings.new()
	saved.path = SCRATCH
	assert_true(saved.load_file(), "leaving the settings pages saved the file")
	assert_true(is_equal_approx(saved.volume("Master"), 0.55), "with the new master volume")
	menu.free()
	_restore()
