extends TestCase
## Day 80 — polish pass eleven. Every quest belongs to an act (`act`, an act_ends id; quests that run across acts are
## `future` instead), and an act's end card closes on a line naming that act's quests still in progress: Oda's "Is
## there anybody left you owe a word?" made concrete, without a checklist before the choice. A long recap shows a
## faint "more below" cue while its end is out of view.

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _start(state: WorldState, id: String) -> void:
	state.start_quest(id, str(_content().get_quest(id)["stages"][0]["id"]))


func _act(id: String) -> Dictionary:
	for act in ActRecap.acts(_content()):
		if str(act["id"]) == id:
			return act
	return {}


func test_every_quest_has_an_act_or_runs_across_acts() -> void:
	var act1: Array[String] = []
	for id: String in _content().quests:
		var quest: Dictionary = _content().quests[id]
		if quest.get("future", false):
			assert_false(quest.has("act"), "%s runs across acts" % id)
			continue
		assert_true(str(quest.get("act", "")) in ["act1", "act2"], "%s has an act" % id)
		if str(quest["act"]) == "act1":
			act1.append(id)
	act1.sort()
	assert_eq(act1, ["a_light_for_saltmarrow", "across_the_grey", "lost_things"] as Array[String], "Act I's three")
	assert_false(_content().quests["what_the_ember_keeps"].has("act"), "the ember's own past runs on")


func test_unfinished_titles_are_the_acts_own_in_progress_in_start_order() -> void:
	var state := fresh_state(_content())
	_start(state, "the_gannets_crew")
	_start(state, "lost_things")
	_start(state, "the_walk_back")
	_start(state, "salt_for_the_collier")
	state.complete_quest("salt_for_the_collier")
	_start(state, "what_the_ember_keeps")
	assert_eq(ActRecap.unfinished_titles(_content(), state, "act2"),
			PackedStringArray(["The Gannet's Crew", "The Walk Back"]), "act2: in progress, in order, not done ones")
	assert_eq(ActRecap.unfinished_titles(_content(), state, "act1"), PackedStringArray(["Lost Things"]), "act1")


func test_the_card_ends_on_what_is_still_owed() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_lane_in"))
	state.set_flag("cindermoor_passage", true)
	var act2 := _act("act2")
	for id: String in state.quests.keys():
		if state.quest_state(id) == WorldState.QUEST_ACTIVE and str(_content().get_quest(id).get("act", "")) == "act2":
			state.complete_quest(id)
	var clean := ActRecap.card_lines(_content(), act2, state)
	assert_eq(clean, ActRecap.lines(act2, state), "nothing owed: no extra line")
	state.quests["the_gannets_crew"] = {"state": WorldState.QUEST_ACTIVE, "stage": "say_the_names"}
	var owed := ActRecap.card_lines(_content(), act2, state)
	assert_eq(owed.size(), clean.size() + 1, "one line more")
	assert_eq(owed[owed.size() - 1], "Still undone on the islands, with a night before the ebb: The Gannet's Crew.")
	state.quests["lost_things"] = {"state": WorldState.QUEST_ACTIVE, "stage": "return_to_pell"}
	owed = ActRecap.card_lines(_content(), act2, state)
	assert_false(owed[owed.size() - 1].contains("Lost Things"), "Act I's errand isn't Act II's")
	var act1_lines := ActRecap.card_lines(_content(), _act("act1"), state)
	assert_true(act1_lines[act1_lines.size() - 1].begins_with("Left undone on Saltmarrow for now: Lost Things."),
			"Act I's card names its own")


func test_the_lane_in_checkpoint_owes_nobody() -> void:
	# The Kindleby checkpoints inherited The Bend in the Road with Wenna's light still in her hand until Day 80.
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_lane_in"))
	assert_eq(ActRecap.unfinished_titles(_content(), state, "act2"), PackedStringArray(), "the canonical path is clean")
	assert_eq(str(state.get_flag("thornwold_bend")), "road", "Wenna's light went on the bend's waymark")


func test_the_far_shore_closes_either_way() -> void:
	# Polish pass eleven's note that the Far Shore stayed at `the_boat` was stale: telling Wenna to wait closes it too.
	var wenna: Dictionary = _content().dialogues["wenna_coll"]
	for knot: String in ["wait", "up"]:
		var closes := false
		for step: Dictionary in wenna["knots"].get(knot, []):
			if str(step.get("quest_complete", "")) == "the_far_shore":
				closes = true
		assert_true(closes, "Wenna's '%s' completes The Far Shore" % knot)


func test_validator_checks_quest_acts_and_the_unfinished_line() -> void:
	var db := load_content()
	var report := ContentValidator.new(db)
	report.validate()
	assert_empty(report.errors, "clean")
	db.quests["lost_things"].erase("act")
	db.quests["the_walk_back"]["act"] = "act9"
	for act: Dictionary in db.game["act_ends"]:
		act["unfinished"] = "Nothing to fill in."
	report = ContentValidator.new(db)
	report.validate()
	var has := func(text: String) -> bool: return report.errors.any(func(e: String) -> bool: return e.contains(text))
	assert_true(has.call("quest lost_things: needs an 'act'"), "missing act")
	assert_true(has.call("act 'act9' is not an act_ends id"), "unknown act")
	assert_true(has.call("unfinished needs exactly one %s"), "template")


func test_the_more_cue_only_while_the_recap_hides_lines() -> void:
	var card := ActEndCard.new()
	card._ready()
	var more: Label = card.get("_more")
	assert_eq(more.text, ActEndCard.MORE_TEXT, "the cue")
	var recap: RichTextLabel = card.get("_recap")
	recap.text = "One short line."
	card.call("_fit_recap")
	assert_false(card.more_cue_visible(), "a short recap has no cue")
	assert_true(more.visible, "the cue keeps its space (alpha only), so the card doesn't jump")
	# A recap long enough to scroll needs a laid-out label: the cue on Act II's card is checked in the --act-end=act2
	# screenshot.
	card.free()
