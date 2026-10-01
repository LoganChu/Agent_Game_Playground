class_name PauseMenu
extends CanvasLayer
## Esc / Start: pauses the world and offers Resume, Save, Load and Quit. Save and Load list
## the manual slots (SaveSystem.SLOTS; Load also the F5 quicksave) with region and time.
## Overwriting a used slot and quitting each ask for a second press. Modal: holds
## `GameState.input_locked`, and only opens when nothing else does.

signal opened
signal closed

enum Page { MAIN, SAVE, LOAD }

var page: Page = Page.MAIN

var _root: Control
var _title: Label
var _buttons: VBoxContainer
var _note: Label
## The button waiting for a confirming second press ("" = none).
var _armed := ""


func _ready() -> void:
	layer = 15
	# Keeps running while the tree is paused (that's the point of it).
	process_mode = Node.PROCESS_MODE_ALWAYS
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


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") and not (is_open() and event.is_action_pressed("ui_cancel")):
		return
	if is_open():
		get_viewport().set_input_as_handled()
		if page == Page.MAIN:
			close()
		else:
			_show_page(Page.MAIN)
	elif event.is_action_pressed("pause") and not GameState.input_locked:
		get_viewport().set_input_as_handled()
		open()


func _show_page(which: Page) -> void:
	page = which
	_armed = ""
	_note.text = ""
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	match which:
		Page.MAIN:
			_title.text = "Paused"
			_add("Resume", close)
			_add("Save game", _show_page.bind(Page.SAVE))
			_add("Load game", _show_page.bind(Page.LOAD))
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
	for button in buttons():
		if not button.disabled:
			_focus.call_deferred(button)
			break


## Deferred focus; the page may have been rebuilt (the button freed) in the meantime.
func _focus(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()


func _add(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT if page != Page.MAIN else HORIZONTAL_ALIGNMENT_CENTER
	button.pressed.connect(action)
	_buttons.add_child(button)
	return button


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
	_buttons = VBoxContainer.new()
	box.add_child(_buttons)
	_note = Label.new()
	_note.theme_type_variation = UiTheme.HINT
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_note)
	var hint := Label.new()
	hint.text = "[Esc] back"
	hint.theme_type_variation = UiTheme.HINT
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint)
