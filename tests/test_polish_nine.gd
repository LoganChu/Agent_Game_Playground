extends TestCase
## Day 68, polish pass nine: the HUD's key hint names the Lanes key once the chart is known;
## the journal's chart keeps its legend to one line; and the validator checks that NPCs stand
## on dry ground or a deck unless their placement says "wading" (Hild stood in Kindleby's sea
## from Day 66 to 67, Ottie at the quay since Day 66).

var _saved_world: WorldState
var _saved_db: ContentDatabase


func _use(state: WorldState) -> void:
	_saved_world = GameState.world
	_saved_db = Content.db
	GameState.world = state
	if Content.db.lanes.is_empty():
		Content.db = load_content()


func _restore() -> void:
	GameState.world = _saved_world
	Content.db = _saved_db
	InputSetup.pad_last = false


func test_the_key_hint_names_lanes_once_the_chart_is_known() -> void:
	var db := load_content()
	var state := fresh_state(db)
	_use(state)
	InputSetup.pad_last = false
	var hud := Hud.new()
	hud._ready()
	var keys := hud.get("_keys") as Label
	assert_false(keys.text.contains("Lanes"), "no Lanes key before the chart: " + keys.text)
	state.complete_quest("across_the_grey")
	assert_true(keys.text.begins_with("[J] Journal   [L] Lanes   [I] Satchel   [Esc] Menu"),
			"the first crossing done, the hint names L: " + keys.text)
	InputSetup.pad_last = true
	GameState.input_device_changed.emit()
	assert_false(keys.text.contains("Lanes"), "a pad has no Lanes button (LB/RB in the journal): " + keys.text)
	hud.free()
	# A load into a playthrough past the crossing re-labels it as the region is rebuilt.
	InputSetup.pad_last = false
	var fresh := fresh_state(db)
	GameState.world = fresh
	var hud2 := Hud.new()
	hud2._ready()
	assert_false((hud2.get("_keys") as Label).text.contains("Lanes"), "before the load")
	fresh.load_dict(state.to_dict())
	GameState.region_change_requested.emit("saltmarrow", "default")
	assert_true((hud2.get("_keys") as Label).text.contains("[L] Lanes"), "after it: " + (hud2.get("_keys") as Label).text)
	hud2.free()
	_restore()


func test_the_journal_chart_legend_fits_one_line() -> void:
	var db := load_content()
	var state := fresh_state(db)
	state.complete_quest("across_the_grey")
	_use(state)
	var journal := JournalUI.new()
	journal._ready()
	var chart := journal.lane_chart()
	chart._ready()
	var legend := chart.get("_legend") as Label
	assert_eq(UiTheme.text_scale(), 1.0, "measured at text scale 1")
	assert_true(legend.text.ends_with("[Esc] close"), "the journal's legend closes")
	assert_true(chart.legend_fits(), "on one line at %s: %s" % [chart.chart_size, legend.text])
	InputSetup.pad_last = true
	GameState.input_device_changed.emit()
	assert_true(chart.legend_fits(), "and with the pad's [B]")
	var short := legend.text
	legend.text = "Solid gold: a lane sailed · dashed gold: not sailed yet · grey: not this tide · [B] close"
	assert_false(chart.legend_fits(), "Oda's long legend would wrap there (the Day 65 look)")
	legend.text = short
	journal.free()
	var odas := LaneMap.new()
	odas._ready()
	assert_true((odas.get("_legend") as Label).text.begins_with("Solid gold: a lane sailed"), "Oda's chart keeps the long legend")
	assert_true(odas.legend_fits(), "which fits her wider chart")
	odas.free()
	_restore()


func test_every_npc_stands_dry_or_says_wading() -> void:
	var db := load_content()
	var validator := ContentValidator.new(db)
	assert_true(validator.validate(), validator.report())
	# Ottie looks north from Kindleby's quay deck now, not from the sea off its side.
	var kindleby: Dictionary = db.get_region("kindleby")
	var field := TerrainField.from_data(kindleby["ground"], float(kindleby["water_level"]))
	for placement: Dictionary in kindleby["npcs"]:
		if placement["npc"] == "ottie":
			var at := JsonUtil.to_vector3(placement["position"])
			assert_true(field.pier_deck(at.x, at.z) > -INF, "Ottie on the quay deck at %s" % at)
	# Dunstan's boots in the mere are meant.
	for placement: Dictionary in db.get_region("glasswater_fen")["npcs"]:
		if placement["npc"] == "dunstan" and JsonUtil.to_vector3(placement["position"]).z < -29.0:
			assert_eq(placement.get("wading"), true, "Dunstan's tussock placement wades")


func test_the_validator_catches_an_npc_in_the_sea() -> void:
	var db := load_content()
	var kindleby: Dictionary = db.get_region("kindleby")
	for placement: Dictionary in kindleby["npcs"]:
		if placement["npc"] == "hild":
			placement["position"] = [-4.0, 0, 9.0]  # out past the shingle
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "an NPC in the sea fails")
	assert_true(validator.report().contains("npc 'hild'") and validator.report().contains("under the water"), validator.report())
	var db2 := load_content()
	for placement: Dictionary in db2.get_region("glasswater_fen")["npcs"]:
		if placement.has("wading"):
			placement["wading"] = "yes"
	var v2 := ContentValidator.new(db2)
	assert_false(v2.validate(), "a non-bool wading fails")
	assert_true(v2.report().contains("'wading' must be true or false"), v2.report())
