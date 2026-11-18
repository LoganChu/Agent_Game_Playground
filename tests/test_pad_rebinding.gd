extends TestCase
## Day 112: gamepad rebinding and button-prompt families. Each pad-rebindable action has one
## button (swaps like keys; Start, B and Guide reserved; an action with no button can't take
## one that's in use); the buttons and the prompt family round-trip through settings.cfg and a
## bad file is tolerated; prompts name the button in the pad's family (Auto reads the pad's
## name); the Controls page lists both bindings and captures a pad button.

const SCRATCH := "user://test_pad_rebinding.cfg"


func _fresh() -> GameSettings:
	var settings := GameSettings.new()
	settings.path = SCRATCH
	DirAccess.remove_absolute(SCRATCH)
	return settings


func _restore() -> void:
	DirAccess.remove_absolute(SCRATCH)
	GameSettings.new().apply_all()
	GameSettings.set_current(null)
	InputSetup.pad_last = false
	InputSetup.pad_name = ""
	InputSetup.prompt_style = "auto"


func _press(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


func test_defaults() -> void:
	var settings := _fresh()
	assert_eq(settings.button_for("interact"), JOY_BUTTON_A, "A interacts")
	assert_eq(settings.button_for("lanes"), JOY_BUTTON_X, "X opens the chart")
	assert_eq(settings.button_for("quick_save"), JOY_BUTTON_INVALID, "quicksave has no button")
	assert_eq(settings.prompt_style, "auto", "prompts follow the pad")
	settings.apply_all()
	assert_true(InputMap.event_is_action(_press(JOY_BUTTON_X), "lanes"), "X is bound to Lanes")
	assert_eq(InputSetup.bound_button("quick_load"), JOY_BUTTON_INVALID, "quickload unbound")
	var seen := {}
	for action in InputSetup.PAD_REBINDABLE:
		var button := settings.button_for(action)
		if button == JOY_BUTTON_INVALID:
			continue
		assert_false(seen.has(button), "%s's default button is its own" % action)
		assert_false(InputSetup.RESERVED_BUTTONS.has(button), "%s's default isn't reserved" % action)
		seen[button] = true
	_restore()


func test_rebinding_swaps_and_refuses() -> void:
	var settings := _fresh()
	settings.apply_all()
	assert_eq(settings.rebind_button("interact", JOY_BUTTON_X), "", "interact onto X")
	assert_eq(settings.button_for("interact"), JOY_BUTTON_X)
	assert_eq(settings.button_for("lanes"), JOY_BUTTON_A, "Lanes takes interact's old A")
	assert_true(InputMap.event_is_action(_press(JOY_BUTTON_X), "interact"), "the InputMap follows")
	assert_false(InputMap.event_is_action(_press(JOY_BUTTON_X), "lanes"), "and X is interact's alone")
	assert_true(InputMap.event_is_action(_press(JOY_BUTTON_A), "lanes"))
	assert_false(settings.rebind_button("journal", JOY_BUTTON_START).is_empty(), "Start is reserved")
	assert_false(settings.rebind_button("journal", JOY_BUTTON_B).is_empty(), "B backs out of menus")
	assert_false(settings.rebind_button("move_forward", JOY_BUTTON_DPAD_UP).is_empty(), "movement is on the stick")
	var why := settings.rebind_button("quick_save", JOY_BUTTON_Y)
	assert_true(why.contains("Satchel"), "an unbound action can't take a used button (it'd leave Satchel with none): " + why)
	assert_eq(settings.button_for("inventory"), JOY_BUTTON_Y, "Satchel kept Y")
	assert_eq(settings.rebind_button("quick_save", JOY_BUTTON_DPAD_DOWN), "", "a free button is fine")
	assert_true(InputMap.event_is_action(_press(JOY_BUTTON_DPAD_DOWN), "quick_save"), "quicksave on the d-pad")
	assert_true(InputMap.event_is_action(_press(JOY_BUTTON_START), "pause"), "Start still pauses")
	assert_eq(settings.rebind_button("interact", JOY_BUTTON_A), "", "back again")
	assert_false(settings.pad_buttons.has("interact") or settings.pad_buttons.has("lanes"), "defaults aren't stored")
	settings.reset()
	assert_true(settings.pad_buttons.is_empty(), "reset clears the buttons")
	assert_eq(InputSetup.bound_button("quick_save"), JOY_BUTTON_INVALID, "and the InputMap")
	_restore()


func test_round_trip_and_bad_files() -> void:
	var settings := _fresh()
	settings.rebind_button("journal", JOY_BUTTON_DPAD_LEFT)
	settings.rebind_button("quick_load", JOY_BUTTON_RIGHT_STICK)
	settings.set_prompt_style("playstation")
	assert_true(settings.save(), "saved")
	var back := GameSettings.new()
	back.path = SCRATCH
	assert_true(back.load_file(), "loaded")
	assert_eq(back.button_for("journal"), JOY_BUTTON_DPAD_LEFT, "journal round-trips")
	assert_eq(back.button_for("quick_load"), JOY_BUTTON_RIGHT_STICK, "quickload round-trips")
	assert_eq(back.prompt_style, "playstation", "the prompt family round-trips")
	var cfg := ConfigFile.new()
	cfg.set_value("pad", "prompts", "gamecube")
	cfg.set_value("pad_buttons", "interact", JOY_BUTTON_START)
	cfg.set_value("pad_buttons", "journal", "banana")
	cfg.set_value("pad_buttons", "move_forward", JOY_BUTTON_X)
	cfg.set_value("pad_buttons", "inventory", JOY_BUTTON_X)
	cfg.set_value("pad_buttons", "lanes", JOY_BUTTON_X)
	cfg.set_value("pad_buttons", "tab_left", 999)
	cfg.save(SCRATCH)
	back.load_file()
	assert_eq(back.prompt_style, "auto", "an unknown family falls back to Auto")
	assert_eq(back.button_for("interact"), JOY_BUTTON_A, "a reserved button is ignored")
	assert_eq(back.button_for("journal"), JOY_BUTTON_BACK, "a non-number is ignored")
	assert_eq(back.button_for("tab_left"), JOY_BUTTON_LEFT_SHOULDER, "an out-of-range button is ignored")
	assert_false(back.pad_buttons.has("move_forward"), "a stick action is ignored")
	var seen := {}
	for action in InputSetup.PAD_REBINDABLE:
		var button := back.button_for(action)
		if button != JOY_BUTTON_INVALID:
			assert_false(seen.has(button), "no two actions share %s after a clash" % InputSetup.button_label(button))
			seen[button] = true
	_restore()


func test_prompt_families() -> void:
	assert_eq(InputSetup.style_for_name("Xbox Series Controller"), "xbox")
	assert_eq(InputSetup.style_for_name("PS5 Controller"), "playstation")
	assert_eq(InputSetup.style_for_name("Sony DualSense"), "playstation")
	assert_eq(InputSetup.style_for_name("Nintendo Switch Pro Controller"), "nintendo")
	assert_eq(InputSetup.style_for_name(""), "xbox", "an unknown pad reads as Xbox")
	assert_eq(InputSetup.button_label(JOY_BUTTON_A, "playstation"), "Cross")
	assert_eq(InputSetup.button_label(JOY_BUTTON_A, "nintendo"), "B", "Nintendo's bottom button is B")
	assert_eq(InputSetup.button_label(JOY_BUTTON_LEFT_SHOULDER, "playstation"), "L1")
	assert_eq(InputSetup.button_label(JOY_BUTTON_DPAD_UP, "nintendo"), "D-pad up", "the d-pad is shared")
	assert_eq(InputSetup.button_label(JOY_BUTTON_INVALID), "—")
	for style: String in InputSetup.PAD_STYLES:
		for button in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_BACK, JOY_BUTTON_START,
				JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			assert_true((InputSetup.PAD_STYLES[style] as Dictionary).has(button), "%s names button %d" % [style, button])
	var settings := _fresh()
	GameSettings.set_current(settings)
	settings.apply_all()
	InputSetup.pad_last = true
	assert_eq(InputSetup.hint("interact"), "[A]", "Auto with no pad name: Xbox")
	InputSetup.pad_name = "PS4 Controller"
	assert_eq(InputSetup.hint("interact"), "[Cross]", "Auto follows a Sony pad")
	assert_eq(InputSetup.back_hint(), "[Circle]", "and its back button")
	settings.set_prompt_style("nintendo")
	assert_eq(InputSetup.hint("inventory"), "[X]", "a chosen family wins over the pad's name")
	assert_eq(settings.prompt_style_label(), "Nintendo")
	settings.cycle_prompt_style()
	assert_eq(settings.prompt_style, "auto", "the button steps round to Auto")
	settings.rebind_button("journal", JOY_BUTTON_DPAD_UP)
	assert_eq(InputSetup.hint("journal"), "[D-pad up]", "hints follow a rebound button")
	assert_eq(InputSetup.hint("quick_save"), "[F5]", "an action with no button keeps its key on the pad")
	_restore()


func test_controls_page_captures_a_pad_button() -> void:
	var settings := _fresh()
	GameSettings.set_current(settings)
	settings.apply_all()
	var menu := PauseMenu.new()
	menu._build()
	menu._show_page(MenuScreen.Page.CONTROLS)
	assert_true(menu.press("Interact / talk — E · A"), "a row shows both bindings")
	assert_eq(menu.capturing, "interact", "capturing")
	assert_true(menu.buttons().any(func(b: Button) -> bool: return b.text == "Interact / talk — press a key or button…"), "it asks for either")
	menu.capture_button(JOY_BUTTON_Y)
	assert_eq(settings.button_for("interact"), JOY_BUTTON_Y, "a pad press rebinds")
	assert_eq(settings.button_for("inventory"), JOY_BUTTON_A, "the Satchel swaps to A")
	assert_eq(menu.note(), "Interact / talk: Y.")
	var on_disk := GameSettings.new()
	on_disk.path = SCRATCH
	on_disk.load_file()
	assert_eq(on_disk.button_for("interact"), JOY_BUTTON_Y, "saved at once")
	assert_true(menu.press("Move forward — W · Left stick"), "movement shows its stick")
	menu.capture_button(JOY_BUTTON_X)
	assert_true(menu.note().contains("left stick"), "a stick action says so: " + menu.note())
	assert_eq(settings.button_for("lanes"), JOY_BUTTON_X, "and nothing changed")
	assert_true(menu.press("Previous journal tab — LB"), "the pad-only tab shoulders are listed")
	assert_true(menu.buttons().any(func(b: Button) -> bool: return b.text.ends_with("press a pad button…")), "they ask for a button")
	menu.capture_key(KEY_K)
	assert_true(menu.note().contains("no key"), "a key for a pad-only action is refused: " + menu.note())
	assert_true(menu.press("Previous journal tab"), "again")
	menu.capture_button(JOY_BUTTON_B)
	assert_true(menu.note().begins_with("Kept"), "B cancels: " + menu.note())
	assert_eq(settings.button_for("tab_left"), JOY_BUTTON_LEFT_SHOULDER)
	assert_true(menu.press("Quicksave — F5"), "quicksave has no button yet")
	menu.capture_button(JOY_BUTTON_RIGHT_STICK)
	assert_true(menu.press("Quicksave — F5 · RS"), "now it does")
	menu.capture_key(KEY_ESCAPE)
	menu._show_page(MenuScreen.Page.SETTINGS)
	assert_true(menu.press("Button prompts: Auto"), "Settings offers the prompt family")
	assert_eq(settings.prompt_style, "xbox", "the next one")
	assert_true(menu.press("Button prompts: Xbox"), "it shows the new value")
	menu.free()
	_restore()
