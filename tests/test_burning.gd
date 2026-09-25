extends TestCase
## The Act I burn choice at the Gull's Beacon, driven through the real story content.

const QUEST := "a_light_for_saltmarrow"

var _db: ContentDatabase


func _state_at_beacon() -> WorldState:
	if _db == null:
		_db = load_content()
	var state := WorldState.new()
	for flag_id: String in _db.flags:
		state.flags[flag_id] = _db.flag_default(flag_id)
	state.start_quest(QUEST, "speak_to_aldous")
	state.set_quest_stage(QUEST, "feed_the_beacon")
	return state


## Runs `dialogue` choosing options by exact text, in order; lines are skipped.
## Returns every option text that was offered along the way.
func _play(state: WorldState, dialogue: String, picks: Array[String]) -> Array[String]:
	var offered: Array[String] = []
	var runner := DialogueRunner.new(_db, state)
	var ev := runner.start(dialogue)
	var guard := 0
	while ev["type"] != "end" and guard < 200:
		guard += 1
		if ev["type"] != "choices":
			ev = runner.next()
			continue
		var texts: Array[String] = []
		for option: Dictionary in ev["options"]:
			texts.append(str(option["text"]))
		offered.append_array(texts)
		var want: String = picks.pop_front() if not picks.is_empty() else ""
		var index := texts.find(want)
		if index < 0:
			# Leave via the last option (every menu's way out).
			index = texts.size() - 1
		ev = runner.choose(index)
	return offered


func _lines(state: WorldState, dialogue: String, picks: Array[String]) -> String:
	var out: PackedStringArray = []
	var runner := DialogueRunner.new(_db, state)
	var ev := runner.start(dialogue)
	var guard := 0
	while ev["type"] != "end" and guard < 200:
		guard += 1
		if ev["type"] == "line":
			out.append(str(ev["text"]))
			ev = runner.next()
		else:
			var texts: Array = (ev["options"] as Array).map(func(o: Dictionary) -> String: return str(o["text"]))
			var want: String = picks.pop_front() if not picks.is_empty() else ""
			var index := texts.find(want)
			ev = runner.choose(index if index >= 0 else texts.size() - 1)
	return "\n".join(out)


func test_empty_handed_beacon_only_offers_not_yet() -> void:
	var state := _state_at_beacon()
	var offered := _play(state, "gulls_beacon", [])
	assert_eq(offered, ["Not yet."] as Array[String])
	assert_eq(state.quest_state(QUEST), "active")


func test_burning_the_knot_completes_the_quest() -> void:
	var state := _state_at_beacon()
	state.add_item("remembering_knot")
	state.add_item("humming_pebble")
	# Backing out of the confirmation burns nothing.
	_play(state, "gulls_beacon", ["Set the Remembering Knot in the cradle.", "No. Not this.", "Not yet."])
	assert_eq(state.quest_state(QUEST), "active")
	assert_eq(state.item_count("remembering_knot"), 1)
	_play(state, "gulls_beacon", ["Set the Remembering Knot in the cradle.", "Burn the founding knot."])
	assert_eq(state.quest_state(QUEST), "done")
	assert_eq(state.get_flag("saltmarrow_beacon_burned"), "knot")
	assert_eq(state.item_count("remembering_knot"), 0)
	assert_eq(state.item_count("humming_pebble"), 1, "only the chosen Remnant burns")
	assert_true(_lines(state, "hesk", []).contains("forgotten what I was mending"), "Hesk loses the knot")


func test_pell_must_agree_before_a_given_pebble_can_burn() -> void:
	var state := _state_at_beacon()
	state.set_flag("saltmarrow_pebble_fate", "given")
	assert_false(_play(state, "gulls_beacon", []).has("Set the humming pebble in the cradle."))
	var ask := "The beacon needs a Remnant. Could it be the pebble?"
	# Refusing on Pell's behalf leaves the pebble with them.
	_play(state, "pell", [ask, "Keep it, Pell. I'll find another way."])
	assert_eq(state.item_count("humming_pebble"), 0)
	_play(state, "pell", [ask, "Yes. Gone for good. I'm sorry."])
	assert_eq(state.item_count("humming_pebble"), 1)
	assert_eq(state.get_flag("saltmarrow_pell_lent_pebble"), true)
	assert_false(_play(state, "pell", []).has(ask), "Pell is only asked once")
	_play(state, "gulls_beacon", ["Set the humming pebble in the cradle.", "Burn the lullaby."])
	assert_eq(state.get_flag("saltmarrow_beacon_burned"), "pebble")
	assert_eq(state.quest_state(QUEST), "done")
	assert_true(_lines(state, "pell", ["The beacon's lit."]).contains("just… pocket"), "Pell misses the pebble")


func test_mara_can_give_her_memory_of_dunstan() -> void:
	var state := _state_at_beacon()
	state.set_flag("saltmarrow_met_mara", true)
	var offer := "The beacon needs a memory. It could be yours — of Dunstan."
	assert_false(_play(state, "mara", []).has(offer), "not before she has told you of Dunstan")
	state.set_flag("saltmarrow_mara_told_of_dunstan", true)
	_play(state, "mara", [offer, "Only if you're willing. It has to be your choice."])
	assert_eq(state.item_count("dunstans_gull"), 1)
	_play(state, "gulls_beacon", ["Set Dunstan's whittled gull in the cradle.", "Burn Mara's memory of Dunstan."])
	assert_eq(state.get_flag("saltmarrow_beacon_burned"), "gull")
	var after := _lines(state, "mara", [])
	assert_true(after.contains("Tollens end with me"), "Mara no longer remembers a brother")
	assert_eq(state.get_flag("saltmarrow_mara_saw_beacon_lit"), true)
	assert_false(_play(state, "mara", []).has("\"What isn't\" — who's missing?"), "she can't tell of Dunstan now")


func test_unburned_remnants_can_be_returned() -> void:
	var state := _state_at_beacon()
	state.set_flag("saltmarrow_met_mara", true)
	state.set_flag("saltmarrow_mara_told_of_dunstan", true)
	state.set_flag("saltmarrow_pebble_fate", "given")
	_play(state, "mara", ["The beacon needs a memory. It could be yours — of Dunstan.", "Only if you're willing. It has to be your choice."])
	_play(state, "pell", ["The beacon needs a Remnant. Could it be the pebble?", "Yes. Gone for good. I'm sorry."])
	state.add_item("remembering_knot")
	_play(state, "gulls_beacon", ["Set the Remembering Knot in the cradle.", "Burn the founding knot."])
	_play(state, "mara", ["Your gull. The beacon didn't need it."])
	_play(state, "pell", ["Here. Your pebble back. The beacon didn't need it."])
	assert_eq(state.item_count("dunstans_gull"), 0)
	assert_eq(state.item_count("humming_pebble"), 0)


func test_relit_beacon_thins_the_fog() -> void:
	var state := _state_at_beacon()
	var region := load_content().get_region("gulls_head")
	var before := float(RegionMood.fog(region, state)["density"])
	state.complete_quest(QUEST)
	var after := float(RegionMood.fog(region, state)["density"])
	assert_true(after < before, "fog density drops once the beacon is lit (%s -> %s)" % [before, after])
	assert_eq(RegionMood.fog({}, state)["density"], RegionMood.DEFAULT_DENSITY)
