class_name TitleScreen
extends MenuScreen
## The title screen, over the live start region (the beach at the Wakebearer's waking, the
## camera drifting round): the game's name and tagline (data/game.json `title`, `tagline`),
## then Continue (the latest save, quicksave included — SaveSystem.latest_slot), New game,
## Load game, Settings and Quit. Debug builds add "Chapter select (dev)". The Load,
## Settings and Controls pages are the pause menu's (MenuScreen). Modal: holds
## `GameState.input_locked` while open; never pauses the tree, so the sea keeps moving.

## "New game" was pressed; main resets the world to the start and plays the waking.
signal new_game_requested

var _game_title: Label
var _tagline: Label


func _ready() -> void:
	layer = 20
	super()


func open() -> void:
	if is_open():
		return
	GameState.input_locked = true
	_root.show()
	_show_page(Page.MAIN)
	opened.emit()


func close() -> void:
	if not is_open():
		return
	_leave_settings(Page.MAIN)
	_root.hide()
	# Deferred like the other modals, so the pressing key doesn't reach the world.
	(func() -> void: GameState.input_locked = false).call_deferred()
	closed.emit()


func _show_page(which: Page) -> void:
	super(which)
	# The game's name heads the main page; the other pages have their own title and a way back.
	var main := which == Page.MAIN
	_game_title.visible = main
	_tagline.visible = main and not _tagline.text.is_empty()
	_title.visible = not main
	_hint.visible = not main
	_fit_scroll()


func _build_main() -> void:
	_title.text = ""
	var latest := SaveSystem.latest_slot()
	if not latest.is_empty():
		var info := SaveSystem.slot_info(latest)
		_add("Continue — %s (%s)" % [info["region_name"], SaveSystem.slot_label(latest)], _load.bind(latest))
	_add("New game", _new_game)
	var load := _add("Load game", _show_page.bind(Page.LOAD))
	load.disabled = latest.is_empty()
	if OS.is_debug_build():
		_add("Chapter select (dev)", _show_page.bind(Page.CHAPTERS))
	_add("Settings", _show_page.bind(Page.SETTINGS))
	_add("Quit", func() -> void: AudioDirector.quit_game(get_tree()))


func _leave_for_play() -> void:
	close()


## A save that won't load keeps the title up and says so (the world behind is still the start).
func _load(slot: String) -> void:
	if not SaveSystem.load_game(slot):
		_note.text = "Couldn't load %s." % SaveSystem.slot_label(slot)
		return
	close()


func _new_game() -> void:
	close()
	new_game_requested.emit()


## The game's name and tagline as shown (for tests).
func heading() -> String:
	return "%s\n%s" % [_game_title.text, _tagline.text]


func _build() -> void:
	super()
	# Lighter than the pause menu's shade: the beach behind is the title art.
	_shade.color = Color(PropFactory.color("ink"), 0.3)
	_game_title = Label.new()
	_game_title.text = str(Content.db.game.get("title", "Emberwake"))
	_game_title.theme_type_variation = UiTheme.GAME_TITLE
	_game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_game_title)
	_box.move_child(_game_title, 0)
	_tagline = Label.new()
	_tagline.text = str(Content.db.game.get("tagline", ""))
	_tagline.theme_type_variation = UiTheme.SUBHEADING
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_tagline)
	_box.move_child(_tagline, 1)
