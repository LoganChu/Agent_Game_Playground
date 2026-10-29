extends TestCase
## Day 70: looking at a Remnant from the satchel. An item may carry a `memory` dialogue; on the
## satchel's "Remember" (interact, Enter / pad A on the list, or the button) the panel steps aside,
## the memory plays in the dialogue box, and the satchel comes back on the same entry. The
## Stair-Taper replays its stair; carried Remnants hum the edges of whoever's memory they hold.
## Remembering can be done any number of times, so a memory changes nothing.

var _saved_world: WorldState
var _saved_db: ContentDatabase


func _journal(state: WorldState) -> JournalUI:
	_saved_world = GameState.world
	_saved_db = Content.db
	GameState.world = state
	Content.db = load_content()
	GameState.input_locked = false
	var journal := JournalUI.new()
	journal._ready()  # built outside the tree, as in test_lanes_tab
	journal.lane_chart()._ready()
	return journal


func _done(journal: JournalUI) -> void:
	journal.free()
	GameState.world = _saved_world
	Content.db = _saved_db
	GameState.input_locked = false


func _select(journal: JournalUI, item: String) -> void:
	var list := journal.get("_list") as ItemList
	var entries: Array[Dictionary] = journal.get("_entries")
	for i in entries.size():
		if entries[i]["id"] == item:
			list.select(i)
			journal.call("_show_entry", i)
			return
	assert_true(false, "%s is not in the satchel" % item)


func test_every_remnant_has_a_memory() -> void:
	var db := load_content()
	var validator := ContentValidator.new(db)
	assert_true(validator.validate(), validator.report())
	for id: String in db.items:
		var item := db.get_item(id)
		if str(item["kind"]) in ["remnant", "own"]:
			assert_true(db.dialogues.has(str(item.get("memory", ""))), "%s holds a memory to remember" % id)
		else:
			assert_false(item.has("memory"), "%s is only a thing" % id)


func test_memories_change_nothing() -> void:
	var db := load_content()
	for id: String in db.items:
		var memory := str(db.get_item(id).get("memory", ""))
		if memory.is_empty():
			continue
		var state := fresh_state(db)
		state.add_item(id)
		var before := JSON.stringify(state.to_dict())
		var lines := play_dialogue(db, state, memory, [])
		assert_false(lines.is_empty(), "%s plays" % memory)
		assert_eq(JSON.stringify(state.to_dict()), before, "remembering %s leaves the world as it was" % id)
		assert_eq(play_dialogue(db, state, memory, []), lines, "and plays the same again")


func test_the_stair_taper_replays_its_stair() -> void:
	var db := load_content()
	var state := fresh_state(db)
	state.add_item("stair_taper")
	var lines := play_dialogue(db, state, "memory_stair_taper", [])
	for needle: String in ["what it hums is yours", "turning always to the left", "the name is yours", "cold at the wick"]:
		assert_true(lines.contains(needle), "the stair: " + needle)
	assert_false(lines.contains("counted"), "nobody's counting yet")
	assert_false(lines.contains("third landing"), "nor has Aldous read the burn")
	state.set_flag("saltmarrow_aldous_saw_taper", true)
	lines = play_dialogue(db, state, "memory_stair_taper", [])
	assert_true(lines.contains("burned down past the third landing") and not lines.contains("cold at the wick"),
			"after Aldous, you see what he saw: " + lines)
	assert_false(lines.contains("counted"), "he only told of the counting after a full confession")
	state.set_flag("saltmarrow_aldous_confessed", "full")
	lines = play_dialogue(db, state, "memory_stair_taper", [])
	assert_true(lines.contains("the landings are being counted") and lines.contains("whose breath"),
			"what Aldous heard is on the stair now: " + lines)


func test_the_validator_keeps_memories_still() -> void:
	var db := load_content()
	db.items["stair_taper"]["memory"] = "no_such_memory"
	db.items["humming_pebble"]["memory"] = 7
	db.dialogues["memory_salt_row"]["knots"]["start"].insert(0, {"set": {"kindleby_stair_taper": true}})
	db.dialogues["memory_tobins_pan"]["knots"]["start"].insert(0,
			{"choice": [{"text": "Keep it.", "give_item": "tobins_pan", "goto": "start"}]})
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "broken memories fail")
	var report := validator.report()
	for needle: String in ["no_such_memory", "item humming_pebble: 'memory' must be a dialogue id",
			"memory 'memory_salt_row' knot 'start' has 'set'", "memory 'memory_tobins_pan' knot 'start' has 'give_item'",
			"dialogue memory_stair_taper: is orphaned"]:
		assert_true(report.contains(needle), "report should mention '%s'\n%s" % [needle, report])


func test_the_satchel_entry_carries_its_memory() -> void:
	var db := load_content()
	var state := fresh_state(db)
	state.add_item("stair_taper")
	state.add_item("harbor_token")
	var entries := JournalModel.item_entries(db, state)
	assert_eq(entries[0]["memory"], "memory_stair_taper", "the taper first, with its memory")
	assert_eq(entries[1]["memory"], "", "a token is only a token")


func test_remembering_from_the_satchel() -> void:
	var db := load_content()
	var state := fresh_state(db)
	for item: String in ["stair_taper", "humming_pebble", "harbor_token"]:
		state.add_item(item)
	var journal := _journal(state)
	var button := journal.get("_remember") as Button
	var heard: Array = []
	journal.remembering.connect(func(item: String, memory: String) -> void: heard.append([item, memory]))

	journal.open(JournalUI.Tab.JOURNAL)
	assert_eq(journal.veil_amount(), 0.0, "no veil just for opening the book")
	assert_eq(journal.selected_memory(), "", "the quest journal has nothing to remember")
	journal.remember()
	assert_true(journal.is_open() and heard.is_empty(), "and Remember does nothing there")

	journal.open(JournalUI.Tab.SATCHEL)
	_select(journal, "harbor_token")
	assert_false(button.visible, "no Remember on the Harbormaster's Token")
	journal.remember()
	assert_true(journal.is_open() and heard.is_empty(), "nothing to remember")

	_select(journal, "humming_pebble")
	assert_true(button.visible and button.text.ends_with("Remember"), "a carried Remnant can be remembered: " + button.text)
	assert_true(button.text.begins_with(InputSetup.hint("interact")), "the hint follows the interact binding")
	journal.remember()
	assert_eq(heard, [["humming_pebble", "memory_humming_pebble"]], "its memory plays")
	assert_false(journal.is_open(), "the panel steps aside for the dialogue box")
	assert_true(journal.is_remembering() and GameState.input_locked, "input stays locked while remembering")
	assert_true(journal.veil_amount() > 0.99, "the world behind goes soft (a memory's own look)")
	journal.remember()
	assert_eq(heard.size(), 1, "a second press while remembering is ignored")
	journal.end_remembering()
	assert_true(journal.is_open() and journal.tab == JournalUI.Tab.SATCHEL, "the satchel comes back")
	assert_false(journal.is_remembering(), "done remembering")
	assert_eq(journal.veil_amount(), 0.0, "the veil lifts with the satchel back")
	assert_eq(journal.selected_memory(), "memory_humming_pebble", "on the same entry")
	assert_true(journal.detail_text().contains("lullaby"), "showing it")
	_done(journal)
