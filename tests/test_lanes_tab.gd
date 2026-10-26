extends TestCase
## Day 65: the journal's Lanes tab — Oda's chart to look at without finding her. It shows once
## the first crossing is made (data/lanes.json `chart`); it is read-only (pressing a port tells
## of it, nothing sails); L opens it, the pad's shoulders step between tabs, and the tab labels
## follow the bindings.

var _saved_world: WorldState
var _saved_db: ContentDatabase


## A JournalUI (and its chart) built outside the tree, over `state` as the playthrough.
func _journal(state: WorldState) -> JournalUI:
	_use(state)
	GameState.input_locked = false
	var journal := JournalUI.new()
	journal._ready()  # built outside the tree, as the runner's tree isn't processing yet
	journal.lane_chart()._ready()
	return journal


func _done(journal: JournalUI) -> void:
	journal.free()
	_restore()


## The autoloads aren't readied under the test runner: give them this playthrough's content.
func _use(state: WorldState) -> void:
	_saved_world = GameState.world
	_saved_db = Content.db
	GameState.world = state
	if Content.db.lanes.is_empty():
		Content.db = load_content()


func _restore() -> void:
	GameState.world = _saved_world
	Content.db = _saved_db
	GameState.input_locked = false


## After the first crossing, at Thornwold with the Ridge Light lit (the fen lane open, unsailed).
func _crossed(db: ContentDatabase) -> WorldState:
	var state := fresh_state(db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "saltmarrow_ferry_arrived", "thornwold_landed"]:
		state.set_flag(flag, true)
	state.set_flag("saltmarrow_beacon_burned", "knot")
	state.set_flag("lanes_ferry_at", "thornwold")
	state.complete_quest("across_the_grey")
	state.set_flag("thornwold_beacon_burned", "boots")
	state.complete_quest("a_light_for_thornwold")
	return state


func test_the_chart_is_known_after_the_first_crossing() -> void:
	var db := load_content()
	var state := fresh_state(db)
	assert_false(Lanes.chart_known(db, state), "no chart at the waking")
	state.set_flag("saltmarrow_ferry_arrived", true)
	state.start_quest("across_the_grey", "take_passage")
	assert_false(Lanes.chart_known(db, state), "nor with the ferry in, before sailing")
	state.complete_quest("across_the_grey")
	assert_true(Lanes.chart_known(db, state), "the first crossing made")


func test_the_validator_checks_the_chart_condition() -> void:
	var db := load_content()
	db.lanes["chart"] = "quest:across_the_grye=done"
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "a misspelt chart condition fails")
	assert_true(validator.report().contains("chart"), validator.report())


func test_no_chart_before_the_crossing() -> void:
	var journal := _journal(fresh_state(load_content()))
	journal.open(JournalUI.Tab.LANES)
	assert_true(journal.is_open() and journal.tab == JournalUI.Tab.LANES, "the tab opens")
	assert_false(journal.chart_shown(), "but shows no chart")
	assert_true((journal.get("_no_chart") as Label).visible, "it says there's none yet")
	assert_false((journal.get("_split") as Control).visible, "the list and page are hidden")
	journal.open(JournalUI.Tab.JOURNAL)
	assert_true((journal.get("_split") as Control).visible and not (journal.get("_no_chart") as Label).visible, "back on the journal")
	_done(journal)


func test_the_chart_in_the_journal_is_read_only() -> void:
	var db := load_content()
	var state := _crossed(db)
	var journal := _journal(state)
	var chart := journal.lane_chart()
	var sailed: Array[String] = []
	chart.chosen.connect(func(id: String) -> void: sailed.append(id))
	journal.open(JournalUI.Tab.LANES)
	assert_true(journal.chart_shown(), "the chart shows")
	var ports := chart.port_ids()
	ports.sort()
	assert_eq(ports, ["fen", "saltmarrow", "thornwold"], "every known port")
	assert_true(chart.info_text().begins_with("Thornwold"), "focus starts where the Slow Mercy lies: " + chart.info_text())
	assert_false((chart.get("_cancel") as Button).visible, "no 'Not yet.' — there's nothing to turn back from")
	assert_eq(chart.chart_size, JournalUI.CHART_SIZE, "the journal's smaller chart")
	chart.press_port("saltmarrow")
	assert_empty(sailed, "pressing a port sails nowhere")
	assert_eq(state.get_flag("lanes_ferry_at"), "thornwold", "the ferry hasn't moved")
	assert_true(chart.info_text().contains("Oda can sail you there.") and not chart.info_text().contains("Press to sail"),
			"it tells of the lane: " + chart.info_text())
	state.set_flag("fen_oda_lane_asked", true)
	journal.open(JournalUI.Tab.LANES)
	assert_true(chart.port_ids().has("wrackholm"), "the chart is redrawn each time it opens")
	chart.press_port("wrackholm")
	assert_true(chart.info_text().begins_with("Wrackholm") and not chart.info_text().contains("Oda can sail"),
			"a voyage she won't make yet says why not: " + chart.info_text())
	assert_true((chart.get("_legend") as Label).text.ends_with("close"), "the legend closes rather than goes back")
	journal.close()
	assert_false(journal.is_open())
	_done(journal)


func test_odas_chart_still_sails() -> void:
	var db := load_content()
	var state := _crossed(db)
	_use(state)
	var chart := LaneMap.new()
	chart._ready()
	var sailed: Array[String] = []
	chart.chosen.connect(func(id: String) -> void: sailed.append(id))
	chart.open()
	assert_true((chart.get("_cancel") as Button).visible, "Oda's chart keeps 'Not yet.'")
	chart.press_port("saltmarrow")
	assert_eq(sailed, ["saltmarrow"] as Array[String], "and sails")
	chart.free()
	_restore()


func test_the_tab_labels_follow_the_bindings() -> void:
	InputSetup.pad_last = false
	var journal := _journal(fresh_state(load_content()))
	var buttons: Array = journal.get("_tab_buttons")
	assert_eq(buttons.map(func(b: Button) -> String: return b.text), ["Journal  [J]", "Satchel  [I]", "Lanes  [L]"], "keys")
	InputSetup.pad_last = true
	journal._label_hint()
	assert_eq(buttons.map(func(b: Button) -> String: return b.text), ["Journal", "Satchel", "Lanes"], "no key names on a pad")
	assert_true((journal.get("_hint") as Label).text.begins_with("[LB] [RB] tabs"), "the shoulders step tabs")
	InputSetup.pad_last = false
	_done(journal)


func test_the_lanes_key_is_rebindable_and_the_shoulders_fixed() -> void:
	assert_true(InputSetup.REBINDABLE.has("lanes"), "L can be rebound in Controls")
	assert_eq(InputSetup.default_key("lanes"), KEY_L)
	assert_eq(InputSetup.PAD_BUTTONS["tab_left"], JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(InputSetup.PAD_BUTTONS["tab_right"], JOY_BUTTON_RIGHT_SHOULDER)
	assert_false(InputSetup.REBINDABLE.has("tab_left") or InputSetup.REBINDABLE.has("tab_right"), "the shoulders aren't keys")
