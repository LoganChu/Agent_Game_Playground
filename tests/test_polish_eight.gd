extends TestCase
## Day 61 polish pass eight: a flag condition may name several values (`flag:x=a|b`), which
## lets one placement stand for Wenna at her clamp on either bend outcome; the validator flags
## dialogue steps that can never play (after an unconditional goto/end/choice); joint_witness
## searches key by key instead of every combination (faster, and no "too many states" give-up
## that answered "exclusive"); the back key's hint ([Esc] / [B]) follows the device used last
## in the journal, the menus and the lane map.

const HEARTH := "thornwold_colls_hearth"


func test_a_flag_condition_can_name_several_values() -> void:
	var p := Conditions.parse("flag:thornwold_bend=road|hearth")
	assert_eq(p["values"], ["road", "hearth"], "the values split on |")
	assert_eq(Conditions.parse("flag:word=")["values"], [""], "an empty value is still one value")
	var state := WorldState.new()
	for value: String in ["road", "hearth"]:
		state.set_flag("thornwold_bend", value)
		assert_true(Conditions.evaluate("flag:thornwold_bend=road|hearth", state), value)
		assert_false(Conditions.evaluate("!flag:thornwold_bend=road|hearth", state), "negated: " + value)
	state.set_flag("thornwold_bend", "walked")
	assert_false(Conditions.evaluate("flag:thornwold_bend=road|hearth", state), "walked is neither")
	var values := {"bend": ["", "walked", "road", "hearth"]}
	assert_eq(Conditions.joint_witness(["flag:bend=road|hearth", "flag:bend=walked"], {}, values), {}, "exclusive")
	assert_eq(Conditions.joint_witness(["flag:bend=road|hearth", "flag:bend=hearth"], {}, values), {"flag:bend": "hearth"})
	# Without a values list, every named alternative is tried.
	assert_false(Conditions.joint_witness(["flag:w=a|b", "flag:w=b"], {"w": ""}).is_empty())


func test_the_validator_checks_every_alternative() -> void:
	var db := load_content()
	for placement: Dictionary in db.regions[HEARTH]["npcs"]:
		if str(placement.get("model", "")).ends_with("wenna_coll_rake.glb"):
			placement["if"] = ["flag:thornwold_far_shore=up", "flag:thornwold_bend=road|hearh", "flag:thornwold_bend_breaking_out"]
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "a misspelt alternative fails")
	assert_true(validator.report().contains("flag 'thornwold_bend' never takes \"hearh\""), validator.report())


func test_wenna_needs_one_placement_per_spot_now() -> void:
	var db := load_content()
	var placements: Array = (db.get_region(HEARTH)["npcs"] as Array).filter(func(p: Dictionary) -> bool:
		return p["npc"] == "wenna_coll")
	var rake := placements.filter(func(p: Dictionary) -> bool: return str(p.get("model", "")).ends_with("wenna_coll_rake.glb"))
	assert_eq(rake.size(), 1, "one rake placement for both outcomes (Day 58 needed two)")
	var state := fresh_state(db)
	state.set_flag("thornwold_far_shore", "up")
	state.set_flag("thornwold_bend_breaking_out", true)
	for value: String in ["road", "hearth"]:
		state.set_flag("thornwold_bend", value)
		var shown := placements.filter(func(p: Dictionary) -> bool: return Conditions.evaluate(p.get("if"), state))
		assert_eq(shown.size(), 1, "one Wenna (%s)" % value)
		assert_true(str(shown[0].get("model", "")).ends_with("wenna_coll_rake.glb"), "at her clamp with the rake (%s)" % value)
		state.set_flag("thornwold_bend_breaking_out", false)
		shown = placements.filter(func(p: Dictionary) -> bool: return Conditions.evaluate(p.get("if"), state))
		assert_eq(shown.size(), 1, "one Wenna before she breaks it out (%s)" % value)
		assert_eq(str(shown[0].get("model", "")), "", "on her seat (%s)" % value)
		state.set_flag("thornwold_bend_breaking_out", true)


func test_joint_witness_has_no_state_limit() -> void:
	# Twenty independent flags were 4^20 combinations: the old search gave up and answered {}.
	var conditions: Array = []
	for i in 20:
		conditions.append("flag:f%d" % i)
	var witness := Conditions.joint_witness(conditions, {})
	assert_eq(witness.size(), 20, "found at once")
	conditions.append("!flag:f19")
	assert_eq(Conditions.joint_witness(conditions, {}), {}, "and still proves a contradiction")


func _dead_step_errors(knots: Dictionary) -> String:
	var validator := ContentValidator.new(load_content())
	validator.errors = []
	validator._validate_dialogue("probe", {"knots": knots})
	return "\n".join(validator.errors)


func test_the_validator_flags_steps_that_never_play() -> void:
	var line := {"say": "mara", "text": "Hello."}
	var errors := _dead_step_errors({"start": [{"goto": "hub"}, line], "hub": [line]})
	assert_true(errors.contains("probe/start: step 1 never plays: step 0 always leaves"), errors)
	errors = _dead_step_errors({"start": [line, {"end": true}, line, line]})
	assert_eq(errors.count("never plays"), 1, "one error per knot: " + errors)
	errors = _dead_step_errors({"start": [{"choice": [{"text": "A", "goto": "hub"}, {"text": "B", "end": true}]}, line], "hub": [line]})
	assert_true(errors.contains("step 1 never plays"), "a choice whose every option leaves: " + errors)
	# Steps that may fall through are fine.
	for knots: Dictionary in [
		{"start": [{"goto": "hub", "if": "flag:intro_seen"}, line], "hub": [line]},
		{"start": [{"choice": [{"text": "A", "goto": "hub"}, {"text": "B"}]}, line], "hub": [line]},
		{"start": [{"choice": [{"text": "A", "goto": "hub", "if": "flag:intro_seen"}]}, line], "hub": [line]},
		{"start": [line, {"goto": "hub"}], "hub": [line]},
	]:
		errors = _dead_step_errors(knots)
		assert_false(errors.contains("never plays"), "%s: %s" % [JSON.stringify(knots), errors])


func test_the_back_hint_follows_the_device() -> void:
	InputSetup.pad_last = false
	var journal := JournalUI.new()
	var title := TitleScreen.new()
	var chart := LaneMap.new()
	for node: Node in [journal, title, chart]:
		node._ready()  # built outside the tree, as the runner's tree isn't processing yet
	var hints := func() -> Array:
		return [(journal.get("_hint") as Label).text, (title.get("_hint") as Label).text,
				(chart.get("_legend") as Label).text.get_slice("·", 3).strip_edges()]
	assert_eq(hints.call(), ["[Esc] close", "[Esc] back", "[Esc] back"], "keys")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_B
	button.pressed = true
	GameState.note_input(button)
	assert_eq(hints.call(), ["[LB] [RB] tabs   [B] close", "[B] back", "[B] back"], "a pad (the journal's tabs on the shoulders since Day 65)")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	key.pressed = true
	GameState.note_input(key)
	assert_eq(hints.call(), ["[Esc] close", "[Esc] back", "[Esc] back"], "keys again")
	for node: Node in [journal, title, chart]:
		node.free()
	InputSetup.pad_last = false
