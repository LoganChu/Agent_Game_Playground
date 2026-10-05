class_name PauseMenu
extends CanvasLayer
## Esc / Start: pauses the world and offers Resume, Save, Load and Quit. Save and Load list
## the manual slots (SaveSystem.SLOTS; Load also the F5 quicksave) with region and time.
## Overwriting a used slot and quitting each ask for a second press. Debug builds add
## "Chapter select (dev)": jump to any story checkpoint in data/scenarios.json. Settings
## (GameSettings) edit volumes, text size and the camera; Controls rebinds keys (press the
## action, then the new key; Esc cancels). Settings are saved to user://settings.cfg as they
## change (a dragged slider once, when it is let go) and again when their pages are left. Modal: holds `GameState.input_locked`, and only opens when nothing
## else does.

signal opened
signal closed

enum Page { MAIN, SAVE, LOAD, CHAPTERS, SETTINGS, CONTROLS }

var page: Page = Page.MAIN

var _root: Control
var _title: Label
var _buttons: VBoxContainer
var _scroll: ScrollContainer
var _hint: Label
var _note: Label
## The button waiting for a confirming second press ("" = none).
var _armed := ""
## The action waiting for a new key on the Controls page ("" = none).
var capturing := ""
## The frame the capture started on: the Enter/click that started it isn't the new key.
var _capture_frame := -1


func _ready() -> void:
	layer = 15
	# Keeps running while the tree is paused (that's the point of it).
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _root == null:  # tests may build it before it enters the tree
		_build()
	_root.hide()


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if is_open() or GameState.input_locked:
		return
	GameState.input_locked = true
	get_tree().paused = true
	_root.show()
	_show_page(Page.MAIN)
	opened.emit()


func close() -> void:
	if not is_open():
		return
	_leave_settings(Page.MAIN)
	_root.hide()
	get_tree().paused = false
	# Deferred like the other modals, so the closing key press doesn't reach the world.
	(func() -> void: GameState.input_locked = false).call_deferred()
	closed.emit()


## The buttons on the current page, top to bottom (for tests and the smoke run).
func buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child in _buttons.get_children():
		if child is Button and not child.is_queued_for_deletion():
			out.append(child)
	return out


## Presses the first button on the page whose text starts with `prefix`; false if none
## (or it is disabled).
func press(prefix: String) -> bool:
	for button in buttons():
		if button.text.begins_with(prefix) and not button.disabled:
			button.pressed.emit()
			return true
	return false


## While waiting for a key on the Controls page, the next key press is the new binding
## (Esc cancels); it never reaches the menu or the world.
func _input(event: InputEvent) -> void:
	if capturing.is_empty() or not is_open():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or Engine.get_process_frames() == _capture_frame:
		return
	get_viewport().set_input_as_handled()
	var keycode := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	capture_key(keycode)


## Finishes a key capture with `keycode` (Esc cancels). Public for tests and the smoke run.
func capture_key(keycode: Key) -> void:
	var action := capturing
	capturing = ""
	if action.is_empty():
		return
	if keycode == KEY_ESCAPE:
		_show_page(Page.CONTROLS)
		_note.text = "Kept %s." % InputSetup.key_label(GameSettings.current().key_for(action))
		return
	var why := GameSettings.current().rebind(action, keycode)
	if why.is_empty():
		_commit_settings()
	_show_page(Page.CONTROLS)
	_note.text = why if not why.is_empty() else "%s: %s." % [InputSetup.action_label(action), InputSetup.key_label(keycode)]


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") and not (is_open() and event.is_action_pressed("ui_cancel")):
		return
	if is_open():
		get_viewport().set_input_as_handled()
		if page == Page.MAIN:
			close()
		elif page == Page.CONTROLS:
			_show_page(Page.SETTINGS)
		else:
			_show_page(Page.MAIN)
	elif event.is_action_pressed("pause") and not GameState.input_locked:
		get_viewport().set_input_as_handled()
		open()


func _show_page(which: Page) -> void:
	_leave_settings(which)
	page = which
	capturing = ""
	_armed = ""
	_note.text = ""
	_scroll.scroll_vertical = 0
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	match which:
		Page.MAIN:
			_title.text = "Paused"
			_add("Resume", close)
			_add("Save game", _show_page.bind(Page.SAVE))
			_add("Load game", _show_page.bind(Page.LOAD))
			if OS.is_debug_build():
				_add("Chapter select (dev)", _show_page.bind(Page.CHAPTERS))
			_add("Settings", _show_page.bind(Page.SETTINGS))
			_add("Quit to desktop", _quit)
		Page.SAVE:
			_title.text = "Save game"
			for slot in SaveSystem.SLOTS:
				_add(SaveSystem.slot_summary(slot), _save.bind(slot))
			_add("Back", _show_page.bind(Page.MAIN))
		Page.LOAD:
			_title.text = "Load game"
			for slot: String in [SaveSystem.QUICK_SLOT] + SaveSystem.SLOTS:
				var button := _add(SaveSystem.slot_summary(slot), _load.bind(slot))
				button.disabled = not SaveSystem.has_save(slot)
			_add("Back", _show_page.bind(Page.MAIN))
		Page.CHAPTERS:
			_title.text = "Chapter select (dev)"
			_note.text = "Jumps to a story checkpoint. Unsaved progress is lost."
			var act := ""
			for scenario in Scenarios.all():
				if str(scenario["act"]) != act:
					act = str(scenario["act"])
					var heading := Label.new()
					heading.text = act
					heading.theme_type_variation = UiTheme.HINT
					_buttons.add_child(heading)
				var button := _add(str(scenario["title"]), _jump.bind(str(scenario["id"])))
				button.tooltip_text = str(scenario["description"])
			_add("Back", _show_page.bind(Page.MAIN))
		Page.SETTINGS:
			_title.text = "Settings"
			_build_settings()
		Page.CONTROLS:
			_title.text = "Controls"
			_note.text = "Pick an action, then press its new key. Arrow keys and Enter still work unless you take them for something else."
			var settings := GameSettings.current()
			for action in InputSetup.REBINDABLE:
				_add("%s — %s" % [InputSetup.action_label(action), InputSetup.key_label(settings.key_for(action))], _start_capture.bind(action))
			_add("Back", _show_page.bind(Page.SETTINGS))
	for child in _buttons.get_children():
		var control := _first_focusable(child)
		if control:
			_focus.call_deferred(control)
			break


## The list takes its full height up to what the screen leaves free, then scrolls.
func _fit_scroll() -> void:
	if _hint == null:  # still being built
		return
	var room := 720.0
	if is_inside_tree():
		room = get_viewport().get_visible_rect().size.y
	# Everything else in the panel: title, note, hint, three gaps, panel margins, and a
	# screen margin above and below.
	var rest := _title.get_combined_minimum_size().y + _note.get_combined_minimum_size().y \
		+ _hint.get_combined_minimum_size().y + 3 * 14 + 40 + 2 * 24
	_scroll.custom_minimum_size.y = minf(_buttons.get_combined_minimum_size().y, maxf(160.0, room - rest))


func _first_focusable(node: Node) -> Control:
	if node.is_queued_for_deletion():
		return null
	if node is Button and not (node as Button).disabled or node is Slider:
		return node as Control
	for child in node.get_children():
		var found := _first_focusable(child)
		if found:
			return found
	return null


## Deferred focus; the page may have been rebuilt (the button freed) in the meantime.
## Once the new page is laid out, the scroll box is brought round to the focused control
## (focusing scrolls at once, against the old page's layout).
func _focus(button: Control) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree():
		return
	button.grab_focus()
	await get_tree().process_frame
	if is_instance_valid(button) and button.is_inside_tree():
		_scroll.ensure_control_visible(button)


func _add(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT if page != Page.MAIN else HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(action)
	_buttons.add_child(button)
	return button


## The Settings page: a slider per audio bus, text size, camera sensitivity and invert,
## Controls, Reset. Buttons show their value ("Text size: Large") and change it when pressed.
func _build_settings() -> void:
	var settings := GameSettings.current()
	for i in GameSettings.BUSES.size():
		var bus := GameSettings.BUSES[i]
		_add_slider("%s volume" % GameSettings.BUS_LABELS[i], settings.volume(bus) * 100.0, 0.0, 100.0, 5.0, "%d%%",
			func(value: float) -> void: settings.set_volume(bus, value / 100.0))
	_add("Text size: " + settings.text_size_label(), func() -> void:
		settings.cycle_text_size()
		_commit_settings()
		_refresh_settings(0))
	_add_slider("Camera sensitivity", settings.camera_sensitivity * 100.0, GameSettings.SENSITIVITY_MIN * 100.0,
		GameSettings.SENSITIVITY_MAX * 100.0, 5.0, "%d%%", func(value: float) -> void: settings.set_camera_sensitivity(value / 100.0))
	_add("Invert camera left/right: " + _on_off(settings.invert_x), func() -> void:
		settings.set_invert_x(not settings.invert_x)
		_commit_settings()
		_refresh_settings(1))
	_add("Invert camera up/down: " + _on_off(settings.invert_y), func() -> void:
		settings.set_invert_y(not settings.invert_y)
		_commit_settings()
		_refresh_settings(2))
	_add("Controls", _show_page.bind(Page.CONTROLS))
	_add("Reset to defaults", _reset_settings)
	_add("Back", _show_page.bind(Page.MAIN))


## Rebuilds the Settings page in place, keeping focus on the `index`-th button pressed.
func _refresh_settings(index: int) -> void:
	page = Page.MAIN  # so _show_page doesn't treat the rebuild as leaving (no save yet)
	_show_page(Page.SETTINGS)
	var list := buttons()
	if index < list.size():
		_focus.call_deferred(list[index])


static func _on_off(value: bool) -> String:
	return "On" if value else "Off"


func _add_slider(text: String, value: float, min_value: float, max_value: float, step: float, format: String, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.name = text.to_pascal_case()
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.x = 200
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.set_meta(&"label", text)
	row.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size.x = 64
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.text = format % value
	row.add_child(readout)
	# Keyboard/pad steps save at once; a mouse drag saves once, when it is let go.
	slider.drag_started.connect(func() -> void: slider.set_meta(&"dragging", true))
	slider.drag_ended.connect(func(value_changed: bool) -> void:
		slider.set_meta(&"dragging", false)
		if value_changed:
			_commit_settings())
	slider.value_changed.connect(func(v: float) -> void:
		readout.text = format % v
		on_change.call(v)
		if not slider.get_meta(&"dragging", false):
			_commit_settings())
	_buttons.add_child(row)
	return slider


## The slider on the current page whose label starts with `prefix` (tests, smoke run).
func slider(prefix: String) -> HSlider:
	for row in _buttons.get_children():
		for child in row.get_children():
			if child is HSlider and str(child.get_meta(&"label", "")).begins_with(prefix) and not row.is_queued_for_deletion():
				return child
	return null


func _start_capture(action: String) -> void:
	capturing = action
	_capture_frame = Engine.get_process_frames()
	for button in buttons():
		if button.text.begins_with(InputSetup.action_label(action) + " —"):
			button.text = "%s — press a key…" % InputSetup.action_label(action)
	_note.text = "Press the new key for %s. Esc cancels." % InputSetup.action_label(action)


func _reset_settings() -> void:
	if _armed != "reset":
		_armed = "reset"
		_note.text = "Press again to put every setting and key back to its default."
		return
	GameSettings.current().reset()
	_commit_settings()
	_refresh_settings(0)
	_note.text = "Settings reset."


## Writes user://settings.cfg after a change on the Settings/Controls pages, so quitting from
## the OS mid-page loses nothing.
func _commit_settings() -> void:
	GameSettings.current().save()


## Leaving the settings pages for anything else (or closing the menu) writes the file too.
func _leave_settings(to: Page) -> void:
	var in_settings := page == Page.SETTINGS or page == Page.CONTROLS
	if in_settings and to != Page.SETTINGS and to != Page.CONTROLS:
		GameSettings.current().save()


## Saving into a used slot needs a second press.
func _save(slot: String) -> void:
	if SaveSystem.has_save(slot) and _armed != slot:
		_armed = slot
		_note.text = "%s holds a save. Press again to overwrite it." % SaveSystem.slot_label(slot)
		return
	if SaveSystem.save_game(slot):
		_show_page(Page.SAVE)
		_note.text = "Saved to %s." % SaveSystem.slot_label(slot)
	else:
		_note.text = "Couldn't save to %s." % SaveSystem.slot_label(slot)


## Loading closes the menu first so the world unpauses into the loaded region.
func _load(slot: String) -> void:
	close()
	if not SaveSystem.load_game(slot):
		GameState.toast.emit("Couldn't load " + SaveSystem.slot_label(slot))


## Jumping closes the menu first so the world unpauses into the checkpoint's region.
func _jump(scenario_id: String) -> void:
	close()
	GameState.start_scenario(scenario_id)


func _quit() -> void:
	if _armed != "quit":
		_armed = "quit"
		_note.text = "Unsaved progress since your last save will be lost. Press again to quit."
		return
	get_tree().quit()


func _build() -> void:
	_root = Control.new()
	_root.name = "PauseRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(PropFactory.color("ink"), 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 520
	box.add_theme_constant_override(&"separation", 14)
	panel.add_child(box)
	_title = Label.new()
	_title.theme_type_variation = UiTheme.HEADING
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	# Long pages (Controls, Chapter select) at large text sizes scroll instead of running off
	# the screen; the scroll box is sized to its page in _fit_scroll.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	box.add_child(_scroll)
	_buttons = VBoxContainer.new()
	_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons.minimum_size_changed.connect(_fit_scroll)
	_scroll.add_child(_buttons)
	_note = Label.new()
	_note.theme_type_variation = UiTheme.HINT
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.minimum_size_changed.connect(_fit_scroll)
	box.add_child(_note)
	var hint := Label.new()
	_hint = hint
	hint.text = "[Esc] back"
	hint.theme_type_variation = UiTheme.HINT
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint)
