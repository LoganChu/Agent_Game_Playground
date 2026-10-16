class_name PauseMenu
extends MenuScreen
## Esc / Start: pauses the world and offers Resume, Save, Load, Settings, Return to title
## and Quit. Save lists the manual slots (SaveSystem.SLOTS) with region and time; Load (from
## MenuScreen) also the F5 quicksave. Overwriting a used slot, returning to the title and
## quitting each ask for a second press. Debug builds add "Chapter select (dev)". Modal:
## holds `GameState.input_locked`, and only opens when nothing else does.

## "Return to title" was confirmed; main resets the world and shows the title screen.
signal title_requested


func _ready() -> void:
	layer = 15
	super()


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


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() and event.is_action_pressed("pause") and not GameState.input_locked:
		get_viewport().set_input_as_handled()
		open()
		return
	super(event)


func _back_from_main() -> void:
	close()


func _leave_for_play() -> void:
	close()


func _build_main() -> void:
	_title.text = "Paused"
	_add("Resume", close)
	_add("Save game", _show_page.bind(Page.SAVE))
	_add("Load game", _show_page.bind(Page.LOAD))
	if OS.is_debug_build():
		_add("Chapter select (dev)", _show_page.bind(Page.CHAPTERS))
	_add("Settings", _show_page.bind(Page.SETTINGS))
	_add("Return to title", _return_to_title)
	_add("Quit to desktop", _quit)


func _build_page(which: Page) -> void:
	if which == Page.SAVE:
		_title.text = "Save game"
		for slot in SaveSystem.SLOTS:
			_add(SaveSystem.slot_summary(slot), _save.bind(slot))
		_add("Back", _show_page.bind(Page.MAIN))


## Saving into a used slot needs a second press.
func _save(slot: String) -> void:
	if SaveSystem.has_save(slot) and not _confirm(slot, "%s holds a save. Press again to overwrite it." % SaveSystem.slot_label(slot)):
		return
	if SaveSystem.save_game(slot):
		_show_page(Page.SAVE)
		_note.text = "Saved to %s." % SaveSystem.slot_label(slot)
	else:
		_note.text = "Couldn't save to %s." % SaveSystem.slot_label(slot)


func _return_to_title() -> void:
	if not _confirm("title", "Unsaved progress since your last save will be lost. Press again to return to the title."):
		return
	close()
	title_requested.emit()


func _quit() -> void:
	if not _confirm("quit", "Unsaved progress since your last save will be lost. Press again to quit."):
		return
	AudioDirector.quit_game(get_tree())
