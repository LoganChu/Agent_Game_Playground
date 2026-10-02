extends TestCase
## The crossing (Act I → II, Day 17): casting off from Saltmarrow on the evening tide, the
## `travel` dialogue effect, the Slow Mercy and Oda following `lanes_ferry_at`, Pell crossing
## when aboard, the landing arrival scene, Bram Kettle and the bramble wall, the trip back,
## and the validator's travel checks.

const FERRY := "across_the_grey"
const THORNWOLD := "a_light_for_thornwold"

var _db: ContentDatabase


## Act I ended: beacon burned with `burn`, Aldous confessed in full, the ferry in, Oda has
## weighed the deed (`deed`) and given passage; Pell's crossing settled as `pell`.
func _passage(burn: String = "knot", pell: String = "stayed", deed: String = "claimed") -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "shingle_met_pell", "saltmarrow_met_mara", "saltmarrow_met_aldous",
			"saltmarrow_ferry_lantern_hung", "saltmarrow_ferry_arrived", "saltmarrow_ferry_passage"]:
		state.set_flag(flag, true)
	state.set_flag("saltmarrow_beacon_burned", burn)
	state.set_flag("saltmarrow_aldous_confessed", "full")
	state.set_flag("saltmarrow_ferry_deed", deed)
	state.set_flag("saltmarrow_pell_crossing", pell)
	if pell != "":
		state.set_flag("saltmarrow_pell_ferry_ask", "promised")
	state.start_quest("a_light_for_saltmarrow", "speak_to_aldous")
	state.complete_quest("a_light_for_saltmarrow")
	state.start_quest(FERRY, "ask_mara")
	state.set_quest_stage(FERRY, "evening_tide")
	return state


## Runs a dialogue picking options by text (like TestCase.play_dialogue) and returns
## {text, travel} — where a `travel` effect would take the player when it closes.
func _run(state: WorldState, dialogue: String, picks: Array[String]) -> Dictionary:
	var out: PackedStringArray = []
	var runner := DialogueRunner.new(_db, state)
	var ev := runner.start(dialogue)
	var guard := 0
	while ev["type"] != "end" and guard < 200:
		guard += 1
		if ev["type"] == "line":
			out.append(str(ev["text"]))
			ev = runner.next()
			continue
		var texts: Array[String] = []
		for option: Dictionary in ev["options"]:
			texts.append(str(option["text"]))
		var want: String = picks.pop_front() if not picks.is_empty() else ""
		var index := texts.find(want)
		ev = runner.choose(index if index >= 0 else texts.size() - 1)
	return {"text": "\n".join(out), "travel": runner.pending_travel}


func _placed(region_id: String, npc: String, state: WorldState) -> bool:
	for entry: Dictionary in _db.get_region(region_id).get("npcs", []):
		if str(entry.get("npc", "")) == npc and Conditions.evaluate(entry.get("if"), state):
			return true
	return false


func _ferry_shown(region_id: String, state: WorldState) -> bool:
	for prop: Dictionary in _db.get_region(region_id).get("props", []):
		if str(prop.get("model", "")).get_file() == "ferry.glb" and Conditions.evaluate(prop.get("if"), state):
			return true
	return false


func test_casting_off_completes_the_crossing_and_travels() -> void:
	var state := _passage()
	var result := _run(state, "oda", ["Cast off for Thornwold."])
	assert_eq(state.quest_state(FERRY), WorldState.QUEST_DONE, "the crossing completes Across the Grey")
	assert_eq(state.get_flag("lanes_ferry_at"), "thornwold")
	assert_eq(result["travel"], ["thornwold_landing", "from_ferry"], "the dialogue carries the player to Thornwold")
	var text: String = result["text"]
	assert_true(text.contains("evening tide") and text.contains("Listen for the trees"), "the crossing is narrated")
	assert_true(text.contains("green lantern"), "Mara sees them off with the green lantern")


func test_crossing_remembers_the_burn_and_pell() -> void:
	var cases := {
		"pebble": "lullaby", "knot": "a knot you almost know", "gull": "an old crewmate's",
	}
	for burn: String in cases:
		var text: String = _run(_passage(burn), "oda", ["Cast off for Thornwold."])["text"]
		assert_true(text.contains(cases[burn]), "the crossing echoes the %s burn" % burn)
		for other: String in cases:
			if other != burn:
				assert_false(text.contains(cases[other]), "no %s echo after the %s burn" % [other, burn])
	var pells := {"aboard": "coil of rope", "stayed": "something GOOD", "let_down": "packed bundle", "": "both arms"}
	for pell: String in pells:
		var state := _passage("knot", pell)
		var text: String = _run(state, "oda", ["Cast off for Thornwold."])["text"]
		assert_true(text.contains(pells[pell]), "Pell's farewell when crossing='%s'" % pell)
		assert_eq(state.get_flag("thornwold_pell_landed"), pell == "aboard", "Pell lands only when aboard ('%s')" % pell)
	assert_true(_run(_passage("gull"), "oda", ["Cast off for Thornwold."])["text"].contains("two cups"), "the gull burn's two cups on the dock")


func test_ferry_oda_and_pell_follow_the_lane() -> void:
	var state := _passage("knot", "aboard")
	assert_true(_ferry_shown("saltmarrow", state) and not _ferry_shown("thornwold_landing", state), "ferry at Saltmarrow before sailing")
	assert_true(_placed("saltmarrow", "oda", state) and not _placed("thornwold_landing", "oda", state))
	assert_true(_placed("saltmarrow", "pell", state) and not _placed("thornwold_landing", "pell", state))
	_run(state, "oda", ["Cast off for Thornwold."])
	assert_true(_ferry_shown("thornwold_landing", state) and not _ferry_shown("saltmarrow", state), "ferry at Thornwold after the crossing")
	assert_true(_placed("thornwold_landing", "oda", state) and not _placed("saltmarrow", "oda", state), "Oda on the Thornwold jetty")
	assert_true(_placed("thornwold_landing", "pell", state) and not _placed("saltmarrow", "pell", state), "Pell crossed with you")
	assert_false(_placed("shingle_point", "pell", state))
	# Back again: the ferry and Oda go home; Pell stays sorting Bram's nails.
	var back := _run(state, "oda", ["Take me back to Saltmarrow."])
	assert_eq(back["travel"], ["saltmarrow", "from_ferry"], "Oda takes you back")
	assert_eq(state.get_flag("lanes_ferry_at"), "saltmarrow")
	assert_true(_ferry_shown("saltmarrow", state) and _placed("saltmarrow", "oda", state), "ferry back at Saltmarrow")
	assert_true(_placed("thornwold_landing", "pell", state), "Pell stays on Thornwold")
	var again := _run(state, "oda", ["Cast off for Thornwold."])
	assert_eq(again["travel"], ["thornwold_landing", "from_ferry"], "and out again")
	assert_false((again["text"] as String).contains("green lantern"), "the second sailing is short")
	assert_eq(state.get_flag("lanes_ferry_at"), "thornwold")


func test_staying_pell_stays_on_the_dock() -> void:
	var state := _passage("knot", "stayed")
	_run(state, "oda", ["Cast off for Thornwold."])
	assert_true(_placed("saltmarrow", "pell", state) and not _placed("thornwold_landing", "pell", state), "Pell stays on the Saltmarrow dock")


func test_landing_scene_plays_once_after_the_crossing() -> void:
	var state := _passage("knot", "aboard")
	var region := _db.get_region("thornwold_landing")
	assert_true(RegionEvents.arrival(region, state).is_empty(), "no landing scene before the crossing")
	_run(state, "oda", ["Cast off for Thornwold."])
	var event := RegionEvents.arrival(region, state)
	assert_false(event.is_empty(), "landing scene on arrival")
	var text := play_dialogue(_db, state, RegionEvents.fire(event, state), [])
	assert_true(text.contains("wall of thorns"), "the landing points at the brambles")
	assert_true(text.contains("resin pot"), "Pell is along")
	assert_true(RegionEvents.arrival(region, state).is_empty(), "the landing scene plays once")


func test_bram_weighs_the_deed_and_the_burn() -> void:
	var state := _passage("knot", "stayed", "shared")
	_run(state, "oda", ["Cast off for Thornwold."])
	var text := play_dialogue(_db, state, "bram", [])
	assert_true(text.contains("gave the credit round"), "Bram heard how the deed was told")
	assert_true(text.contains("founding knot"), "Bram knows the knot burned")
	assert_eq(state.get_flag("thornwold_bram_knot_grudge"), true, "and holds it against you")
	assert_eq(state.quest_stage(THORNWOLD), "the_bramble_wall", "Bram points you at the bramble wall")
	assert_eq(state.get_flag("thornwold_met_bram"), true)
	for burn: String in ["pebble", "gull"]:
		var other := _passage(burn, "stayed", "brusque")
		var said := play_dialogue(_db, other, "bram", [])
		assert_true(said.contains("like a tally"), "brusque deed")
		assert_true(said.contains("rain off a coat"), "an off-islander's memory slides off you (%s)" % burn)
		assert_eq(other.get_flag("thornwold_bram_knot_grudge"), false, "no grudge after the %s burn" % burn)


func test_the_bramble_wall_advances_the_quest() -> void:
	var state := _passage()
	play_dialogue(_db, state, "bram", [])
	var offered: Array[String] = []
	play_dialogue(_db, state, "bram", [], offered)
	assert_false(offered.has("The cart road runs straight in under the brambles."), "nothing to say about the wall yet")
	var text := play_dialogue(_db, state, "thornwold_bramble", [])
	assert_true(text.contains("this way home"), "the cutter's notch points into the thorns")
	assert_eq(state.quest_stage(THORNWOLD), "past_the_wall")
	offered.clear()
	play_dialogue(_db, state, "bram", [], offered)
	assert_true(offered.has("The cart road runs straight in under the brambles."), "Bram answers once you've looked")
	assert_eq(state.quest_state(THORNWOLD), WorldState.QUEST_ACTIVE, "Thornwold's beacon is still ahead")


func test_pell_on_thornwold() -> void:
	var state := _passage("knot", "aboard")
	_run(state, "oda", ["Cast off for Thornwold."])
	var text := play_dialogue(_db, state, "pell", [])
	assert_true(text.contains("sorting nails"), "Pell talks about the camp")
	var offered: Array[String] = []
	play_dialogue(_db, state, "bram", [], offered)
	assert_true(offered.has("About Pell."), "Bram has a word about Pell")


func test_validator_checks_travel() -> void:
	var db := load_content()
	db.dialogues["bram"]["knots"]["keeper"].append_array([
		{"travel": ["nowhere"]},
		{"travel": ["saltmarrow", "no_such_spawn"]},
		{"travel": "saltmarrow"},
	])
	var v := ContentValidator.new(db)
	assert_false(v.validate())
	var report := v.report()
	assert_true(report.contains("travel to unknown region 'nowhere'"), "unknown region")
	assert_true(report.contains("travel spawn 'no_such_spawn' not in region 'saltmarrow'"), "unknown spawn")
	assert_true(report.contains("travel must be [region_id] or [region_id, spawn]"), "malformed travel")
