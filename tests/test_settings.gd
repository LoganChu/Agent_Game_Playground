extends TestCase
## Settings (GameSettings): volumes on audio buses, text size and speed (the dialogue
## typewriter), camera sensitivity/invert, stick deadzone, window mode and vsync, key rebinding (swaps, secondaries, reserved keys), user://settings.cfg round trip and
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


## What's on disk at SCRATCH right now.
func _saved() -> GameSettings:
	var saved := GameSettings.new()
	saved.path = SCRATCH
	saved.load_file()
	return saved


func test_defaults() -> void:
	var settings := _fresh()
	for bus in GameSettings.BUSES:
		assert_eq(settings.volume(bus), GameSettings.DEFAULT_VOLUME, "%s at the default volume" % bus)
	assert_eq(settings.text_scale, 1.0, "normal text")
	assert_eq(settings.text_size_label(), "Normal", "text size label")
	assert_eq(settings.camera_sensitivity, 1.0, "camera at 100%")
	assert_false(settings.invert_x or settings.invert_y, "nothing inverted")
	assert_eq(settings.key_for("interact"), KEY_E, "E interacts")
	assert_eq(settings.text_speed_label(), "Normal", "normal text speed")
	assert_eq(settings.stick_deadzone, GameSettings.DEFAULT_DEADZONE, "default deadzone")
	assert_eq(settings.window_mode_label(), "Windowed", "windowed")
	assert_true(settings.vsync, "vsync on")
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


func test_text_speed_cycles() -> void:
	var settings := _fresh()
	settings.cycle_text_speed()
	assert_eq(settings.text_speed_label(), "Fast", "Normal → Fast")
	settings.cycle_text_speed()
	assert_eq(settings.text_speed_label(), "Instant", "Fast → Instant")
	assert_eq(settings.text_speed, 0.0, "instant is speed 0")
	settings.cycle_text_speed()
	assert_eq(settings.text_speed_label(), "Slow", "wraps round to Slow")
	settings.set_text_speed(3.0)
	assert_eq(settings.text_speed_label(), "Slow", "a slow odd speed reads as Slow, not Instant")
	settings.set_text_speed(9999.0)
	assert_eq(settings.text_speed, GameSettings.TEXT_SPEED_MAX, "clamped")
	_restore()


## A line types out at the text speed; a press mid-line shows the rest (it doesn't skip the
## line); at Instant the line shows whole. Choices and closing never leave text half-typed.
func test_dialogue_types_out_at_the_text_speed() -> void:
	var settings := _fresh()
	GameSettings.set_current(settings)
	var ui := DialogueUI.new()
	ui._build()
	ui._panel.show()
	var line := "The fog came in under the door like a cat."
	ui._show({"type": "line", "speaker": "narrator", "text": line})
	assert_true(ui.is_revealing(), "a new line starts typing")
	assert_eq(ui._text_label.text, line, "the whole line is set (only its reveal is partial)")
	ui._process(0.2)
	assert_eq(ui._text_label.visible_characters, 10, "50 chars/s × 0.2 s = 10 shown")
	ui.press_continue()
	assert_false(ui.is_revealing(), "interact mid-line shows the rest")
	assert_eq(ui.current_event.get("text"), line, "...without moving on to the next line")
	ui._show({"type": "line", "speaker": "narrator", "text": line})
	ui._process(5.0)
	assert_false(ui.is_revealing(), "it finishes on its own")
	ui._show({"type": "line", "speaker": "narrator", "text": line})
	ui._show({"type": "choices", "options": [{"text": "Go on."}]})
	assert_false(ui.is_revealing(), "choices show the line above them whole")
	settings.set_text_speed(0.0)
	ui._show({"type": "line", "speaker": "narrator", "text": line})
	assert_false(ui.is_revealing(), "Instant shows the line whole at once")
	ui.free()
	_restore()


func test_stick_deadzone_reaches_the_pad_axes() -> void:
	var settings := _fresh()
	settings.set_stick_deadzone(0.35)
	for action: String in InputSetup.PAD_AXES:
		assert_true(is_equal_approx(InputMap.action_get_deadzone(action), 0.35), "%s deadzone" % action)
	var lean := InputEventJoypadMotion.new()
	lean.axis = JOY_AXIS_LEFT_X
	lean.axis_value = 0.3
	assert_false(lean.is_action_pressed("move_right"), "a 0.3 lean is inside a 0.35 deadzone")
	settings.set_stick_deadzone(0.25)
	assert_true(lean.is_action_pressed("move_right"), "and outside a 0.25 one")
	settings.set_stick_deadzone(0.0)
	assert_eq(settings.stick_deadzone, GameSettings.DEADZONE_MIN, "clamped")
	_restore()
	assert_true(is_equal_approx(InputMap.action_get_deadzone("move_right"), GameSettings.DEFAULT_DEADZONE), "restored")


## Prompts show pad buttons once a pad is used, and keys again after a key press; a light
## stick touch (drift) doesn't flip them. The HUD re-labels its key hint on the swap.
func test_prompts_follow_the_device_used_last() -> void:
	InputSetup.pad_last = false
	assert_eq(InputSetup.hint("interact"), "[E]", "keyboard first")
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.2
	assert_false(InputSetup.note_device(drift), "stick drift isn't the pad being used")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	button.pressed = true
	assert_true(InputSetup.note_device(button), "a pad button swaps the prompts")
	assert_eq(InputSetup.hint("interact"), "[A]", "interact on A")
	assert_eq(InputSetup.hint("journal"), "[Back]", "journal on Back")
	assert_eq(InputSetup.hint("move_forward"), "[W]", "an action with no pad button keeps its key")
	assert_false(InputSetup.note_device(button), "no change on a second pad press")
	var hud := Hud.new()
	hud._ready()
	assert_true((hud.get("_keys") as Label).text.begins_with("[Back] Journal   [Y] Satchel   [Start] Menu"), "the HUD hint shows pad buttons")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	GameState.note_input(key)
	assert_false(InputSetup.pad_last, "a key press swaps back")
	assert_true((hud.get("_keys") as Label).text.begins_with("[J] Journal   [I] Satchel   [Esc] Menu"), "and the HUD hint follows")
	hud.free()
	InputSetup.pad_last = false


func test_window_mode_and_vsync() -> void:
	var settings := _fresh()
	settings.cycle_window_mode()
	assert_eq(settings.window_mode, "fullscreen", "Windowed → Fullscreen")
	assert_eq(settings.window_mode_label(), "Fullscreen", "label")
	settings.cycle_window_mode()
	assert_eq(settings.window_mode, "windowed", "wraps back")
	settings.set_window_mode("cinema")
	assert_eq(settings.window_mode, "windowed", "an unknown mode is refused")
	settings.set_vsync(false)
	assert_false(settings.vsync, "vsync off")
	_restore()


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
	settings.set_text_speed(0.0)
	settings.set_stick_deadzone(0.3)
	settings.set_window_mode("fullscreen")
	settings.set_vsync(false)
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
	assert_eq(again.text_speed_label(), "Instant", "text speed")
	assert_true(is_equal_approx(again.stick_deadzone, 0.3), "deadzone")
	assert_eq(again.window_mode, "fullscreen", "window mode")
	assert_false(again.vsync, "vsync")
	_restore()


func test_bad_file_is_tolerated() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "Master", 7.0)
	cfg.set_value("display", "text_scale", 0.1)
	cfg.set_value("camera", "sensitivity", -3)
	cfg.set_value("display", "text_speed", -20)
	cfg.set_value("display", "window_mode", "cinema")
	cfg.set_value("pad", "stick_deadzone", 4.0)
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
	assert_eq(settings.text_speed, 0.0, "text speed clamped")
	assert_eq(settings.window_mode, "windowed", "unknown window mode ignored")
	assert_eq(settings.stick_deadzone, GameSettings.DEADZONE_MAX, "deadzone clamped")
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
	menu._show_page(MenuScreen.Page.MAIN)
	assert_true(menu.press("Settings"), "the main page offers Settings")
	assert_eq(menu.page, MenuScreen.Page.SETTINGS, "Settings page")
	for label in GameSettings.BUS_LABELS:
		assert_true(menu.slider(label + " volume") != null, "%s volume slider" % label)
	_slide(menu, "Music volume", 40.0)
	assert_true(is_equal_approx(settings.volume("Music"), 0.4), "the slider sets the volume")
	assert_true(is_equal_approx(_saved().volume("Music"), 0.4), "a slider step saves at once")
	var music := menu.slider("Music volume")
	music.drag_started.emit()
	_slide(menu, "Music volume", 20.0)
	assert_true(is_equal_approx(_saved().volume("Music"), 0.4), "not saved on every tick of a drag")
	music.drag_ended.emit(true)
	assert_true(is_equal_approx(_saved().volume("Music"), 0.2), "saved when the drag is let go")
	_slide(menu, "Camera sensitivity", 150.0)
	assert_eq(settings.camera_sensitivity, 1.5, "the slider sets sensitivity")
	assert_true(menu.press("Text size: Normal"), "text size button")
	assert_true(menu.press("Text size: Large"), "it shows the new size")
	assert_true(menu.press("Invert camera up/down: Off"), "invert button")
	assert_true(settings.invert_y, "inverted")
	assert_true(menu.press("Invert camera up/down: On"), "it shows On")
	assert_true(menu.press("Frame conversations: On"), "conversation framing button (Day 73)")
	assert_false(settings.dialogue_camera, "framing off")
	assert_false(_saved().dialogue_camera, "saved at once")
	assert_true(menu.press("Frame conversations: Off"), "it shows Off")
	assert_true(menu.press("Text speed: Normal"), "text speed button")
	assert_true(menu.press("Text speed: Fast"), "it shows the new speed")
	assert_eq(settings.text_speed_label(), "Instant", "pressed twice: Instant")
	_slide(menu, "Stick deadzone", 30.0)
	assert_true(is_equal_approx(settings.stick_deadzone, 0.3), "the slider sets the deadzone")
	assert_true(menu.press("Display: Windowed"), "display button")
	assert_eq(settings.window_mode, "fullscreen", "fullscreen")
	assert_true(menu.press("Display: Fullscreen"), "it shows Fullscreen")
	assert_true(menu.press("VSync: On"), "vsync button")
	assert_false(settings.vsync, "vsync off")
	assert_false(_saved().vsync, "saved at once")
	assert_true(menu.press("VSync: Off"), "it shows Off")
	assert_true(menu.press("Controls"), "Controls page")
	assert_eq(menu.page, MenuScreen.Page.CONTROLS, "on Controls")
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
	assert_eq(_saved().key_for("interact"), KEY_G, "a rebind saves at once")
	assert_eq(_saved().text_scale, settings.text_scale, "so does a toggle")
	assert_false(_saved().invert_y, "and toggling back")
	menu.press("Back")
	assert_eq(menu.page, MenuScreen.Page.SETTINGS, "Back from Controls goes to Settings")
	menu.press("Reset to defaults")
	assert_eq(settings.key_for("interact"), KEY_G, "reset asks twice")
	menu.press("Reset to defaults")
	assert_eq(settings.key_for("interact"), KEY_E, "reset puts keys back")
	assert_eq(settings.text_scale, 1.0, "and text size")
	assert_eq(settings.text_speed_label(), "Normal", "and text speed")
	_slide(menu, "Master volume", 55.0)
	menu.press("Back")
	assert_eq(menu.page, MenuScreen.Page.MAIN, "back to the main page")
	var saved := GameSettings.new()
	saved.path = SCRATCH
	assert_true(saved.load_file(), "leaving the settings pages saved the file")
	assert_true(is_equal_approx(saved.volume("Master"), 0.55), "with the new master volume")
	menu.free()
	_restore()
