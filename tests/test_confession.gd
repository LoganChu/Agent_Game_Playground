extends TestCase
## Aldous's Act I confession and the Act II ferry hook, driven through the real story content.

const FERRY := "across_the_grey"

var _db: ContentDatabase


func _state(approach: String, beacon_lit: bool = true) -> WorldState:
	if _db == null:
		_db = load_content()
	var state := WorldState.new()
	for flag_id: String in _db.flags:
		state.flags[flag_id] = _db.flag_default(flag_id)
	state.set_flag("saltmarrow_met_aldous", true)
	state.set_flag("saltmarrow_aldous_approach", approach)
	state.start_quest("a_light_for_saltmarrow", "speak_to_aldous")
	state.set_quest_stage("a_light_for_saltmarrow", "feed_the_beacon")
	if beacon_lit:
		state.set_flag("saltmarrow_beacon_burned", "knot")
		state.complete_quest("a_light_for_saltmarrow")
	return state


## Runs `dialogue`, picking options by exact text in order (else the last option, every
## menu's way out). Returns all spoken lines joined, and every offered option via `offered`.
func _run(state: WorldState, dialogue: String, picks: Array[String], offered: Array[String] = []) -> String:
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
		offered.append_array(texts)
		var want: String = picks.pop_front() if not picks.is_empty() else ""
		var index := texts.find(want)
		ev = runner.choose(index if index >= 0 else texts.size() - 1)
	return "\n".join(out)


func test_no_confession_before_the_beacon_is_lit() -> void:
	for approach: String in ["", "gentle", "pressed"]:
		var state := _state(approach, false)
		var offered: Array[String] = []
		_run(state, "aldous", [], offered)
		assert_false(offered.has("I'm ready for the rest of your story."), "gentle option hidden (%s)" % approach)
		assert_false(offered.has("You said I'd make you talk. So talk."), "pressed option hidden (%s)" % approach)
		assert_eq(state.quest_state(FERRY), "inactive")


func test_gentle_confession_is_full_and_gives_the_sleeve_ember() -> void:
	var state := _state("gentle")
	var text := _run(state, "aldous", ["The Gull's Beacon is lit.", "Sit with him.", "Whose hand?", "Say the name.", "I don't know."])
	assert_eq(state.get_flag("saltmarrow_aldous_confessed"), "full")
	assert_eq(state.item_count("keepers_sleeve_ember"), 1)
	assert_eq(state.quest_state(FERRY), "active")
	assert_eq(state.quest_stage(FERRY), "ask_mara")
	assert_true(text.contains("The High Keeper's"), "names the High Keeper as the culprit")
	assert_true(text.contains("cupped in someone's hands"), "the light going down the stair")
	assert_false(text.contains("Oriel"), "never names the High Keeper")
	# Once told, the spire question gets the short answer and no re-confession is offered.
	var offered: Array[String] = []
	text = _run(state, "aldous", ["What happened at the Hearthspire?"], offered)
	assert_true(text.contains("I held the door"))
	assert_false(offered.has("I'm ready for the rest of your story."))


func test_gentle_player_can_defer_and_ask_later() -> void:
	var state := _state("gentle")
	_run(state, "aldous", ["The Gull's Beacon is lit.", "Later, Brother."])
	assert_eq(state.get_flag("saltmarrow_aldous_confessed"), "")
	_run(state, "aldous", ["I'm ready for the rest of your story.", "Whose hand?", "Why would the High Keeper do that?"])
	assert_eq(state.get_flag("saltmarrow_aldous_confessed"), "full")


func test_pressed_confession_needs_a_second_visit_and_is_grudging() -> void:
	for approach: String in ["pressed", ""]:
		var state := _state(approach)
		_run(state, "aldous", ["You said I'd make you talk. So talk."])
		assert_true(state.get_flag("saltmarrow_aldous_balked"), "balks first (%s)" % approach)
		assert_eq(state.get_flag("saltmarrow_aldous_confessed"), "")
		var text := _run(state, "aldous", ["Hold out your ember. \"Look at it, Brother. Then tell me.\"", "That's all?"])
		assert_eq(state.get_flag("saltmarrow_aldous_confessed"), "grudging")
		assert_eq(state.item_count("keepers_sleeve_ember"), 0, "no sleeve-ember when pressed")
		assert_eq(state.quest_stage(FERRY), "ask_mara")
		assert_true(text.contains("By the High Keeper"))
		assert_false(text.contains("cupped in someone's hands"), "grudging version holds back the stair light")


func test_mara_hangs_the_ferry_lantern() -> void:
	var state := _state("gentle")
	_run(state, "aldous", ["I'm ready for the rest of your story.", "Whose hand?", "Why would the High Keeper do that?"])
	var offered: Array[String] = []
	_run(state, "mara", ["Aldous says the ferry might run again."], offered)
	assert_true(offered.has("Aldous says the ferry might run again."))
	assert_true(state.get_flag("saltmarrow_ferry_lantern_hung"))
	assert_eq(state.quest_stage(FERRY), "await_the_ferry")
	offered.clear()
	_run(state, "mara", [], offered)
	assert_false(offered.has("Aldous says the ferry might run again."), "asked once")


func test_ferry_lantern_prop_shape_builds_with_light() -> void:
	var node := PropFactory.build("signal_lantern")
	assert_true(node.find_children("*", "OmniLight3D", true, false).size() == 1)
	node.free()
