extends TestCase
## Day 109 — save follow-ups. Saves are version 2: a save-version migration path (SaveMigrations) upgrades version 1
## saves on read and refuses saves from a newer build; saves carry the play time and the story's id; the autosave keeps
## one slot per story (another story's autosave moves to "Autosave (earlier story)"); each save has a thumbnail, shown on
## the Load and Save pages.

const SCRATCH := "user://test_save_follow_ups"
const SETTINGS_SCRATCH := "user://test_save_follow_ups.cfg"


func _sandboxed(body: Callable) -> void:
	# Tests run before the autoloads' _ready; loading a save needs the regions, so lend Content a
	# loaded database (its own still loads, untouched, when the tree starts).
	var real_db := Content.db
	if real_db.regions.is_empty():
		Content.db = ContentDatabase.new()
		Content.db.load_all()
	var saved_dir := SaveSystem.save_dir
	var saved_region := GameState.region_id
	var saved_dev := GameState.dev_session
	var saved_story := GameState.playthrough
	var saved_play := GameState.play_seconds
	var settings := GameSettings.new()
	settings.path = SETTINGS_SCRATCH
	GameSettings.set_current(settings)
	SaveSystem.save_dir = SCRATCH
	_clear()
	GameState.region_id = "saltmarrow"
	GameState.dev_session = false
	GameState.playthrough = "story-a"
	GameState.play_seconds = 0.0
	body.call()
	_clear()
	SaveSystem.save_dir = saved_dir
	GameState.region_id = saved_region
	GameState.dev_session = saved_dev
	GameState.playthrough = saved_story
	GameState.play_seconds = saved_play
	DirAccess.remove_absolute(SETTINGS_SCRATCH)
	GameSettings.set_current(null)
	Content.db = real_db


func _clear() -> void:
	for slot: String in SaveSystem.LOADABLE + ["old"]:
		DirAccess.remove_absolute(SCRATCH.path_join(slot + ".json"))
		DirAccess.remove_absolute(SCRATCH.path_join(slot + ".png"))
	DirAccess.remove_absolute(SCRATCH)


func _write(slot: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	var file := FileAccess.open(SCRATCH.path_join(slot + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


## A version 1 save as Days 1–108 wrote it.
func _v1_save() -> Dictionary:
	return {
		"version": 1, "saved_at": "2026-11-10T09:12:30", "region": "saltmarrow", "spawn": "default",
		"world": {"flags": {"intro_seen": true}, "quests": {}, "inventory": {}, "collected": []},
	}


func test_migration_from_version_one() -> void:
	assert_eq(SaveSystem.SAVE_VERSION, 2, "saves are version 2 since Day 109")
	var old := _v1_save()
	var result := SaveMigrations.migrate(old, SaveSystem.SAVE_VERSION)
	assert_true(result["ok"], "a version 1 save upgrades: %s" % result["error"])
	var data: Dictionary = result["data"]
	assert_eq(int(data["version"]), 2, "to version 2")
	assert_eq(int(result["from"]), 1, "from version 1")
	assert_eq(float(data["play_seconds"]), 0.0, "no play time counted before Day 109")
	assert_eq(str(data["playthrough"]), "", "an unknown story")
	assert_eq(str(data["region"]), "saltmarrow", "the rest kept")
	assert_true((data["world"] as Dictionary)["flags"]["intro_seen"], "the world kept")
	assert_false(old.has("play_seconds"), "the original isn't touched")
	assert_eq(int(old["version"]), 1, "...nor its version")


func test_migration_refuses_what_it_cannot_read() -> void:
	var newer := SaveMigrations.migrate({"version": SaveSystem.SAVE_VERSION + 1}, SaveSystem.SAVE_VERSION)
	assert_false(newer["ok"], "a save from a newer build is refused")
	assert_true(str(newer["error"]).contains("newer"), "and says why: %s" % newer["error"])
	assert_false(SaveMigrations.migrate({}, SaveSystem.SAVE_VERSION)["ok"], "no version: not a save")
	assert_false(SaveMigrations.migrate({"version": 0}, SaveSystem.SAVE_VERSION)["ok"], "version 0 refused")
	var current := {"version": SaveSystem.SAVE_VERSION, "region": "saltmarrow", "play_seconds": 12.0, "playthrough": "x"}
	var same := SaveMigrations.migrate(current, SaveSystem.SAVE_VERSION)
	assert_true(same["ok"], "a current save passes")
	assert_eq(same["data"], current, "unchanged")
	# Every version from OLDEST up has a step, so no save in between is stranded.
	for version in range(SaveMigrations.OLDEST, SaveSystem.SAVE_VERSION):
		assert_true(SaveMigrations.migrate({"version": version}, SaveSystem.SAVE_VERSION)["ok"], "an upgrade from version %d" % version)


func test_a_version_one_save_loads() -> void:
	_sandboxed(func() -> void:
		_write("slot1", _v1_save())
		var info := SaveSystem.slot_info("slot1")
		assert_eq(str(info.get("region")), "saltmarrow", "listed with its region")
		assert_eq(SaveSystem.slot_summary("slot1"), "Slot 1 — %s · 2026-11-10 09:12" % info["region_name"], "no play time shown for it")
		var heard := []
		var listen := func(region: String, _spawn: String) -> void: heard.append(region)
		GameState.region_change_requested.connect(listen)
		var ok := SaveSystem.load_game("slot1")
		GameState.region_change_requested.disconnect(listen)
		assert_true(ok, "loads")
		assert_eq(heard, ["saltmarrow"], "into its region")
		assert_eq(GameState.play_seconds, 0.0, "play time starts at zero")
		assert_false(GameState.playthrough.is_empty(), "its story gets an id on load")
		assert_true(GameState.playthrough != "story-a", "a new one"))


func test_a_newer_save_is_listed_but_not_loaded() -> void:
	_sandboxed(func() -> void:
		_write("slot2", {"version": SaveSystem.SAVE_VERSION + 1, "saved_at": "2030-01-01T00:00:00", "region": "saltmarrow", "world": {}})
		assert_true(SaveSystem.slot_summary("slot2").contains("newer version"), "the Load page says why: %s" % SaveSystem.slot_summary("slot2"))
		assert_eq(SaveSystem.latest_slot(), "", "Continue doesn't offer it")
		assert_false(SaveSystem.load_game("slot2"), "it doesn't load")
		var menu := PauseMenu.new()
		menu._build()
		menu._root.hide()
		menu._show_page(MenuScreen.Page.LOAD)
		for button: Button in menu.buttons():
			if button.text.begins_with("Slot 2"):
				assert_true(button.disabled, "its button is disabled")
		menu.free())


func test_play_time() -> void:
	assert_eq(SaveSystem.format_play_time(0.0), "", "unknown")
	assert_eq(SaveSystem.format_play_time(20.0), "under a minute")
	assert_eq(SaveSystem.format_play_time(47 * 60 + 5), "47m")
	assert_eq(SaveSystem.format_play_time(3 * 3600 + 12 * 60 + 40), "3h 12m")
	assert_eq(SaveSystem.format_play_time(25 * 3600 + 60), "25h 01m")
	_sandboxed(func() -> void:
		GameState.play_seconds = 2 * 3600 + 5 * 60 + 0.04
		assert_true(SaveSystem.save_game("slot3"), "saves")
		var info := SaveSystem.slot_info("slot3")
		assert_true(absf(float(info["play_seconds"]) - 7500.0) <= 0.11, "the play time saved")
		assert_eq(str(info["playthrough"]), "story-a", "with the story's id")
		assert_true(SaveSystem.slot_summary("slot3").contains(" · 2h 05m · "), "shown on the Load page: %s" % SaveSystem.slot_summary("slot3"))
		GameState.play_seconds = 99.0
		GameState.playthrough = "other"
		assert_true(SaveSystem.load_game("slot3"), "loads")
		assert_true(absf(GameState.play_seconds - 7500.0) <= 0.11, "the play time restored")
		assert_eq(GameState.playthrough, "story-a", "and the story"))


func test_a_new_game_starts_a_new_story() -> void:
	var saved_world := GameState.world.to_dict()
	var saved_region := GameState.region_id
	var saved_spawn := GameState.spawn_point
	var saved_story := GameState.playthrough
	var saved_play := GameState.play_seconds
	GameState.play_seconds = 500.0
	GameState.new_game()
	var first := GameState.playthrough
	assert_eq(GameState.play_seconds, 0.0, "the clock reset")
	assert_false(first.is_empty(), "a story id")
	GameState.new_game()
	assert_true(GameState.playthrough != first, "each new game its own")
	GameState.world.load_dict(saved_world)
	GameState.region_id = saved_region
	GameState.spawn_point = saved_spawn
	GameState.playthrough = saved_story
	GameState.play_seconds = saved_play


func test_one_autosave_per_story() -> void:
	_sandboxed(func() -> void:
		assert_true(SaveSystem.autosave(), "story A autosaves")
		assert_true(SaveSystem.autosave(), "...and again")
		assert_false(SaveSystem.has_save(SaveSystem.PREV_AUTO_SLOT), "the same story overwrites its own autosave")
		GameState.playthrough = "story-b"
		GameState.region_id = "gulls_head"
		assert_true(SaveSystem.autosave(), "a new story autosaves")
		assert_eq(str(SaveSystem.slot_info(SaveSystem.AUTO_SLOT)["playthrough"]), "story-b", "the autosave is the new story")
		var prev := SaveSystem.slot_info(SaveSystem.PREV_AUTO_SLOT)
		assert_eq(str(prev.get("playthrough")), "story-a", "the old story's autosave kept aside")
		assert_eq(str(prev.get("region")), "saltmarrow", "where it was")
		assert_eq(SaveSystem.slot_label(SaveSystem.PREV_AUTO_SLOT), "Autosave (earlier story)", "named on the Load page")
		assert_true(SaveSystem.autosave(), "story B again")
		assert_eq(str(SaveSystem.slot_info(SaveSystem.PREV_AUTO_SLOT)["playthrough"]), "story-a", "story A's still kept")
		# Loading story A back and playing on swaps them round.
		assert_true(SaveSystem.load_game(SaveSystem.PREV_AUTO_SLOT), "the earlier story loads")
		assert_true(SaveSystem.autosave(), "and autosaves")
		assert_eq(str(SaveSystem.slot_info(SaveSystem.AUTO_SLOT)["playthrough"]), "story-a", "A is the autosave")
		assert_eq(str(SaveSystem.slot_info(SaveSystem.PREV_AUTO_SLOT)["playthrough"]), "story-b", "B kept aside")
		# A legacy autosave (no story id) is never overwritten by a story.
		_write(SaveSystem.AUTO_SLOT, _v1_save())
		assert_true(SaveSystem.autosave(), "autosaves over a legacy one")
		assert_eq(int(SaveSystem.read_slot(SaveSystem.PREV_AUTO_SLOT)["from"]), 1, "the legacy autosave moved aside"))


func test_the_earlier_story_is_listed_only_once_there_is_one() -> void:
	_sandboxed(func() -> void:
		var menu := PauseMenu.new()
		menu._build()
		menu._root.hide()
		SaveSystem.autosave()
		menu._show_page(MenuScreen.Page.LOAD)
		var texts := menu.buttons().map(func(b: Button) -> String: return b.text)
		assert_false(texts.any(func(t: String) -> bool: return t.begins_with("Autosave (earlier")), "not listed with one story (%s)" % [texts])
		GameState.playthrough = "story-b"
		SaveSystem.autosave()
		menu._show_page(MenuScreen.Page.LOAD)
		texts = menu.buttons().map(func(b: Button) -> String: return b.text)
		assert_true(str(texts[0]).begins_with("Autosave — "), "this story's autosave first (%s)" % [texts])
		assert_true(str(texts[1]).begins_with("Autosave (earlier story) — "), "the earlier story's next")
		assert_false(menu.buttons()[1].disabled, "loadable")
		menu.free())


func test_thumbnails() -> void:
	_sandboxed(func() -> void:
		# Headless runs render nothing: a save has no thumbnail, and never keeps an older one.
		var stale := Image.create(SaveSystem.THUMB_SIZE.x, SaveSystem.THUMB_SIZE.y, false, Image.FORMAT_RGB8)
		stale.fill(Color(0.8, 0.4, 0.1))
		DirAccess.make_dir_recursive_absolute(SCRATCH)
		stale.save_png(SaveSystem.thumb_path("slot1"))
		SaveSystem.save_game("slot1")
		assert_false(FileAccess.file_exists(SaveSystem.thumb_path("slot1")), "an older save's picture is removed")
		assert_true(SaveSystem.slot_thumbnail("slot1") == null, "no thumbnail")
		# A save that has one shows it on the Load and Save pages.
		stale.save_png(SaveSystem.thumb_path("slot1"))
		var thumb := SaveSystem.slot_thumbnail("slot1")
		assert_true(thumb != null, "the thumbnail loads")
		assert_eq(Vector2i(thumb.get_size()), SaveSystem.THUMB_SIZE, "at its size")
		var menu := PauseMenu.new()
		menu._build()
		menu._root.hide()
		for which: MenuScreen.Page in [MenuScreen.Page.LOAD, MenuScreen.Page.SAVE]:
			menu._show_page(which)
			for button: Button in menu.buttons():
				if button.text.begins_with("Slot 1"):
					assert_true(button.icon != null, "shown beside the slot (page %d)" % which)
					assert_eq(button.get_theme_constant(&"icon_max_width"), SaveSystem.THUMB_SHOWN_WIDTH, "small")
				elif button.text.begins_with("Slot 2"):
					assert_true(button.icon == null, "an empty slot has none")
		menu.free()
		# The picture moves with the autosave it belongs to.
		SaveSystem.autosave()
		stale.save_png(SaveSystem.thumb_path(SaveSystem.AUTO_SLOT))
		GameState.playthrough = "story-b"
		SaveSystem.autosave()
		assert_true(FileAccess.file_exists(SaveSystem.thumb_path(SaveSystem.PREV_AUTO_SLOT)), "moved aside with the earlier story")
		assert_false(FileAccess.file_exists(SaveSystem.thumb_path(SaveSystem.AUTO_SLOT)), "the new autosave has none (headless)"))
