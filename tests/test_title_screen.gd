extends TestCase
## The title screen (Day 41): when a launch opens on it, Continue picks the latest save, its
## pages (shared with the pause menu through MenuScreen), and "Return to title" on the pause
## menu and the act-end card asking twice.

const SCRATCH := "user://test_title_saves"
const MAIN := preload("res://scripts/main.gd")


func _write_save(dir: String, slot: String, saved_at: String, region: String = "saltmarrow") -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(dir.path_join(slot + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": SaveSystem.SAVE_VERSION, "saved_at": saved_at, "region": region, "world": {}}))
	file.close()


func _clear(dir: String) -> void:
	for slot: String in [SaveSystem.QUICK_SLOT] + SaveSystem.SLOTS:
		DirAccess.remove_absolute(dir.path_join(slot + ".json"))
	DirAccess.remove_absolute(dir)


func test_which_launches_open_on_the_title() -> void:
	assert_true(MAIN.wants_title(PackedStringArray()), "a plain launch")
	assert_true(MAIN.wants_title(PackedStringArray(["--smoke-test"])), "the smoke run starts from it")
	for arg in ["--scenario=heron_lit", "--region=saltmarrow", "--flags=intro_seen", "--quest=lost_things", "--act-end=act1", "--pause-menu=save", "--screenshot=/tmp/x.png"]:
		assert_false(MAIN.wants_title(PackedStringArray([arg])), "%s goes straight to play" % arg)
	assert_true(MAIN.wants_title(PackedStringArray(["--screenshot=/tmp/x.png", "--title"])), "--title forces it")


func test_continue_is_the_latest_save() -> void:
	var saves: Node = load("res://scripts/autoload/save_system.gd").new()
	saves.save_dir = SCRATCH
	_clear(SCRATCH)
	assert_eq(saves.latest_slot(), "", "no saves, nothing to continue")
	_write_save(SCRATCH, "slot1", "2026-10-14T09:10:00")
	_write_save(SCRATCH, "quick", "2026-10-14T09:30:05")
	_write_save(SCRATCH, "slot3", "2026-10-13T21:40:00")
	assert_eq(saves.latest_slot(), "quick", "the quicksave counts")
	_write_save(SCRATCH, "slot2", "2026-10-14T09:31:00")
	assert_eq(saves.latest_slot(), "slot2", "the newest stamp wins, not the slot order")
	var bad := FileAccess.open(SCRATCH.path_join("slot3.json"), FileAccess.WRITE)
	bad.store_string("{ not json")
	bad.close()
	assert_eq(saves.latest_slot(), "slot2", "an unreadable save is skipped")
	_clear(SCRATCH)
	saves.free()


func test_title_pages() -> void:
	var real_dir := SaveSystem.save_dir
	SaveSystem.save_dir = SCRATCH
	_clear(SCRATCH)
	var title := TitleScreen.new()
	title._build()
	title._show_page(MenuScreen.Page.MAIN)
	var texts := title.buttons().map(func(b: Button) -> String: return b.text)
	assert_eq(texts[0], "New game", "no saves: New game first (%s)" % [texts])
	assert_true(title.buttons()[1].text == "Load game" and title.buttons()[1].disabled, "Load greyed without saves")
	assert_true(texts.has("Settings") and texts[-1] == "Quit", "Settings, and Quit last")
	assert_true(title.heading().begins_with("Emberwake"), "the game's name heads it")
	assert_true(title._game_title.visible and not title._title.visible and not title._hint.visible, "name shown, no page title or Esc hint on the main page")
	title.back()
	assert_eq(title.page, MenuScreen.Page.MAIN, "Esc on the main page stays on the title")
	assert_true(title.press("Settings"), "Settings")
	assert_eq(title.page, MenuScreen.Page.SETTINGS, "the shared Settings page")
	assert_true(title.slider("Master volume") != null, "with its sliders")
	assert_true(not title._game_title.visible and title._title.visible and title._hint.visible, "the page's own title and a way back")
	assert_true(title.press("Controls") and title.page == MenuScreen.Page.CONTROLS, "and Controls")
	title.back()
	title.back()
	assert_eq(title.page, MenuScreen.Page.MAIN, "Esc backs out page by page")
	_write_save(SCRATCH, "slot2", "2026-10-14T09:31:00", "nowhere_known")
	title._show_page(MenuScreen.Page.MAIN)
	assert_true(title.buttons()[0].text.begins_with("Continue") and title.buttons()[0].text.contains("Slot 2"), "Continue first, naming the slot (%s)" % title.buttons()[0].text)
	assert_false(title.buttons()[2].disabled, "Load open with a save")
	assert_true(title.press("Load game") and title.page == MenuScreen.Page.LOAD, "the shared Load page")
	assert_true(title.buttons()[0].disabled and not title.buttons()[2].disabled, "empty quicksave greyed, slot 2 loadable")
	title.free()
	_clear(SCRATCH)
	SaveSystem.save_dir = real_dir


func test_return_to_title_asks_twice() -> void:
	var menu := PauseMenu.new()
	menu._build()
	menu._root.hide()  # built but never opened (out of the tree, closing can't unpause)
	menu._show_page(MenuScreen.Page.MAIN)
	var asked := [0]
	menu.title_requested.connect(func() -> void: asked[0] += 1)
	var texts := menu.buttons().map(func(b: Button) -> String: return b.text)
	assert_true(texts.find("Return to title") == texts.size() - 2, "Return to title just above Quit (%s)" % [texts])
	assert_true(menu.press("Return to title"), "first press")
	assert_true(asked[0] == 0 and menu.note().contains("Press again"), "only warns")
	menu.press("Save game")
	menu.press("Back")
	menu.press("Return to title")
	assert_eq(asked[0], 0, "a page change disarms it")
	menu.press("Return to title")
	assert_eq(asked[0], 1, "the second press asks for the title")
	menu.free()
	var card := ActEndCard.new()
	card._build()
	var card_asked := [0]
	card.title_requested.connect(func() -> void: card_asked[0] += 1)
	card.return_to_title()
	assert_true(card_asked[0] == 0 and card._title_button.text.contains("Press again"), "the act card warns first")
	card.return_to_title()
	assert_eq(card_asked[0], 1, "then asks for the title")
	card.free()
