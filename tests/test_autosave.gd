extends TestCase
## Day 106 — autosave. An "Autosave" slot written quietly (no toast) by the game, listed first on the Load page and
## counted by Continue; `Autosaver` writes it at the next quiet moment after a request (an arrival at once, story
## progress no more than every MIN_INTERVAL_MSEC); never in a developer jump or with the setting off; leaving for the
## title or the desktop says progress will be autosaved.

const SCRATCH := "user://test_autosave_saves"
const SETTINGS_SCRATCH := "user://test_autosave.cfg"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


## Runs `body` with the saves in a scratch dir, a fresh settings instance (autosave on), and a
## playable region set; restores everything afterwards.
func _sandboxed(body: Callable) -> void:
	var saved_dir := SaveSystem.save_dir
	var saved_region := GameState.region_id
	var saved_dev := GameState.dev_session
	var settings := GameSettings.new()
	settings.path = SETTINGS_SCRATCH
	GameSettings.set_current(settings)
	SaveSystem.save_dir = SCRATCH
	_clear()
	GameState.region_id = "saltmarrow"
	GameState.dev_session = false
	body.call(settings)
	_clear()
	SaveSystem.save_dir = saved_dir
	GameState.region_id = saved_region
	GameState.dev_session = saved_dev
	DirAccess.remove_absolute(SETTINGS_SCRATCH)
	GameSettings.set_current(null)


func _clear() -> void:
	for slot: String in SaveSystem.LOADABLE:
		DirAccess.remove_absolute(SCRATCH.path_join(slot + ".json"))
	DirAccess.remove_absolute(SCRATCH)


func test_the_autosave_slot() -> void:
	assert_eq(SaveSystem.slot_label(SaveSystem.AUTO_SLOT), "Autosave", "its name in menus")
	assert_eq(SaveSystem.LOADABLE[0], SaveSystem.AUTO_SLOT, "listed first for loading")
	assert_true(SaveSystem.LOADABLE.has(SaveSystem.QUICK_SLOT), "the quicksave still listed")
	for slot in SaveSystem.SLOTS:
		assert_true(SaveSystem.LOADABLE.has(slot), "%s loadable" % slot)
	assert_false(SaveSystem.SLOTS.has(SaveSystem.AUTO_SLOT), "never offered on the Save page")


func test_autosave_is_quiet_and_counts_for_continue() -> void:
	_sandboxed(func(_settings: GameSettings) -> void:
		var heard: Array[String] = []
		var listen := func(text: String) -> void: heard.append(text)
		GameState.toast.connect(listen)
		assert_true(SaveSystem.autosave(), "writes the slot")
		GameState.toast.disconnect(listen)
		assert_true(SaveSystem.has_save(SaveSystem.AUTO_SLOT), "the autosave file exists")
		assert_eq(heard.size(), 0, "no toast for an autosave: %s" % [heard])
		assert_eq(SaveSystem.latest_slot(), SaveSystem.AUTO_SLOT, "Continue picks it up")
		assert_eq(str(SaveSystem.slot_info(SaveSystem.AUTO_SLOT).get("region")), "saltmarrow", "with its region")
		assert_true(SaveSystem.slot_summary(SaveSystem.AUTO_SLOT).begins_with("Autosave — "), "summarised for the Load page"))


func test_no_autosave_in_a_developer_jump_or_when_off() -> void:
	_sandboxed(func(settings: GameSettings) -> void:
		assert_true(SaveSystem.autosave_allowed(), "on by default")
		GameState.dev_session = true
		assert_false(SaveSystem.autosave_allowed(), "not after a checkpoint or debug state")
		assert_false(SaveSystem.autosave(), "...and nothing written")
		assert_false(SaveSystem.has_save(SaveSystem.AUTO_SLOT), "no file")
		GameState.dev_session = false
		settings.set_autosave(false)
		assert_false(SaveSystem.autosave(), "not with the setting off")
		assert_false(SaveSystem.has_save(SaveSystem.AUTO_SLOT), "still no file")
		settings.set_autosave(true)
		GameState.region_id = ""
		assert_false(SaveSystem.autosave(), "not before any region is loaded"))


func test_a_scenario_or_a_new_game_or_a_load_sets_the_dev_flag() -> void:
	var saved_db := Content.db
	var saved := GameState.world.to_dict()
	var saved_dev := GameState.dev_session
	Content.db = load_content()
	GameState.dev_session = false
	GameState.apply_scenario(Scenarios.resolve("the_homecoming"))
	assert_true(GameState.dev_session, "a checkpoint is a developer jump")
	GameState.new_game()
	assert_false(GameState.dev_session, "a new game is real play")
	GameState.dev_session = saved_dev
	GameState.world.load_dict(saved)
	Content.db = saved_db


func test_the_autosaver_waits_for_a_quiet_moment() -> void:
	_sandboxed(func(_settings: GameSettings) -> void:
		var saver := Autosaver.new()
		var quiet := [false]
		saver.is_safe = func() -> bool: return quiet[0]
		saver.last_msec = 0
		assert_false(saver.try_now(100000), "nothing asked, nothing written")
		saver.request(true)
		assert_false(saver.try_now(100000), "an arrival waits while the moment isn't quiet")
		assert_true(saver.is_pending(), "...and stays pending")
		quiet[0] = true
		assert_true(saver.try_now(100001), "written once it is")
		assert_false(saver.is_pending(), "the request is spent")
		assert_eq(saver.count, 1, "one save")
		assert_true(SaveSystem.has_save(SaveSystem.AUTO_SLOT), "the file")
		saver.free())


func test_story_autosaves_are_spaced_out() -> void:
	_sandboxed(func(_settings: GameSettings) -> void:
		var saver := Autosaver.new()
		saver.last_msec = 0
		assert_true(saver.try_now(1) == false and not saver.is_pending(), "idle")
		saver.request()
		assert_true(saver.try_now(saver.min_interval_msec + 1), "a quest change after the interval saves")
		saver.request()
		saver.request()
		var at := saver.min_interval_msec + 500
		assert_false(saver.try_now(at), "a second quest change soon after waits")
		assert_true(saver.is_pending(), "...pending")
		assert_true(saver.try_now(2 * saver.min_interval_msec + 2), "and goes through once the interval is up (once)")
		assert_eq(saver.count, 2, "two saves for three requests")
		saver.request(true)
		assert_true(saver.try_now(2 * saver.min_interval_msec + 10), "an arrival doesn't wait for the interval")
		saver.free())


func test_a_request_is_dropped_when_autosave_is_not_allowed() -> void:
	_sandboxed(func(settings: GameSettings) -> void:
		var saver := Autosaver.new()
		settings.set_autosave(false)
		saver.request(true)
		assert_false(saver.try_now(100000), "setting off: nothing written")
		assert_false(saver.is_pending(), "...and the request dropped, not kept for later")
		settings.set_autosave(true)
		saver.request(true)
		saver.cancel()
		assert_false(saver.try_now(100000) or saver.is_pending(), "a cancelled request never saves")
		assert_false(SaveSystem.has_save(SaveSystem.AUTO_SLOT), "no file")
		saver.free())


func test_the_setting_round_trips() -> void:
	var settings := GameSettings.new()
	settings.path = SETTINGS_SCRATCH
	assert_true(settings.autosave, "on by default")
	settings.set_autosave(false)
	assert_true(settings.save(), "saved")
	var again := GameSettings.new()
	again.path = SETTINGS_SCRATCH
	again.load_file()
	assert_false(again.autosave, "off survives a restart")
	again.reset_values()
	assert_true(again.autosave, "reset turns it back on")
	DirAccess.remove_absolute(SETTINGS_SCRATCH)


func test_the_menus() -> void:
	_sandboxed(func(settings: GameSettings) -> void:
		var menu := PauseMenu.new()
		menu._build()
		menu._root.hide()
		menu._show_page(MenuScreen.Page.SETTINGS)
		var texts := menu.buttons().map(func(b: Button) -> String: return b.text)
		assert_true(texts.has("Autosave: On"), "a Settings toggle (%s)" % [texts])
		assert_true(menu.press("Autosave"), "pressing it")
		assert_false(settings.autosave, "turns autosave off")
		assert_true(PauseMenu.leave_warning("quit").contains("Unsaved progress"), "off: leaving warns of lost progress")
		settings.set_autosave(true)
		assert_true(PauseMenu.leave_warning("quit").contains("autosaved"), "on: leaving says it autosaves")
		SaveSystem.autosave()
		menu._show_page(MenuScreen.Page.LOAD)
		assert_true(menu.buttons()[0].text.begins_with("Autosave — ") and not menu.buttons()[0].disabled, "the Load page offers the autosave first (%s)" % menu.buttons()[0].text)
		menu._show_page(MenuScreen.Page.SAVE)
		for button: Button in menu.buttons():
			assert_false(button.text.begins_with("Autosave"), "the Save page doesn't offer the autosave slot")
		menu.free())


func test_the_act_end_card_says_it_autosaves() -> void:
	_sandboxed(func(settings: GameSettings) -> void:
		var card := ActEndCard.new()
		card._build()
		card.return_to_title()
		var button := card.get("_title_button") as Button
		assert_eq(button.text, ActEndCard.TITLE_CONFIRM_AUTOSAVED, "armed: progress will be autosaved")
		card.free()
		settings.set_autosave(false)
		var off := ActEndCard.new()
		off._build()
		off.return_to_title()
		assert_eq((off.get("_title_button") as Button).text, ActEndCard.TITLE_CONFIRM_TEXT, "off: progress is lost")
		off.free())


func test_the_hud_cue() -> void:
	var hud := Hud.new()
	_root().add_child(hud)
	if hud.get("_saving") == null:
		hud._ready()
	assert_false(hud.is_autosave_shown(), "hidden at first")
	hud.show_autosave()
	assert_true(hud.is_autosave_shown(), "shown after an autosave")
	assert_eq((hud.get("_saving") as Label).text, "Saving…", "a small Saving…")
	_root().remove_child(hud)
	hud.free()
