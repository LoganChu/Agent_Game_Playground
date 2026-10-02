extends TestCase
## Developer story checkpoints (data/scenarios.json, Scenarios): they validate, inherit,
## reset the world before applying, and leave the story where each one says it is.

var _db: ContentDatabase


func _at(id: String) -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	state.set_flag("saltmarrow_beacon_burned", "pebble")  # stale state the checkpoint must clear
	state.add_item("pells_pouch")
	Scenarios.apply(_db, state, Scenarios.resolve(id))
	return state


func test_checkpoints_validate() -> void:
	var db := load_content()
	assert_empty(Scenarios.validate(db, Scenarios.all()), "scenario errors")
	assert_true(Scenarios.all().size() >= 10, "checkpoints cover the story so far")


func test_inheritance_folds_in_earlier_state() -> void:
	var resolved := Scenarios.resolve("thornwold")
	assert_eq(resolved["region"], "thornwold_landing")
	assert_eq((resolved["flags"] as Dictionary).get("saltmarrow_beacon_burned"), "knot", "inherited from aftermath_knot")
	assert_eq((resolved["quests"] as Dictionary).get("across_the_grey"), "done", "later checkpoints override earlier ones")
	assert_true((resolved["collected"] as Array).has("shingle_humming_pebble"), "collected pickups accumulate")
	assert_true(Scenarios.resolve("no_such_checkpoint").is_empty())


func test_applying_resets_then_sets_the_story() -> void:
	var state := _at("new_game")
	assert_eq(state.get_flag("saltmarrow_beacon_burned"), "", "a checkpoint starts from a new game")
	assert_eq(state.item_count("pells_pouch"), 0)
	assert_eq(state.get_flag("intro_seen"), false, "new_game replays the waking")
	state = _at("the_burning")
	assert_eq(state.quest_stage("a_light_for_saltmarrow"), "feed_the_beacon")
	assert_true(state.item_count("humming_pebble") == 1 and state.item_count("remembering_knot") == 1, "both Remnants in hand")
	assert_true(state.is_collected("gulls_head_knot"), "the knot isn't lying in the lofts twice")
	assert_eq(state.quest_state("lost_things"), WorldState.QUEST_DONE)


func test_each_burn_checkpoint_has_burned_its_remnant() -> void:
	var cases := {"aftermath_pebble": ["pebble", "humming_pebble"], "aftermath_knot": ["knot", "remembering_knot"], "aftermath_gull": ["gull", "dunstans_gull"]}
	for id: String in cases:
		var state := _at(id)
		assert_eq(state.get_flag("saltmarrow_beacon_burned"), cases[id][0], id)
		assert_eq(state.item_count(cases[id][1]), 0, "%s: the burned Remnant is gone" % id)
		assert_eq(state.quest_state("a_light_for_saltmarrow"), WorldState.QUEST_DONE, id)


func test_story_continues_from_the_late_checkpoints() -> void:
	# The ferry checkpoint: Oda weighs the deed and gives passage, ending Act I.
	var state := _at("ferry_arrived")
	play_dialogue(_db, state, "pell", [])
	play_dialogue(_db, state, "mara", [])
	assert_true(ActRecap.reached(_db, state).is_empty(), "Act I not over at the ferry's arrival")
	# The evening tide: Act I is over and Oda casts off.
	state = _at("act_one_end")
	assert_true(ActRecap.reached(_db, state).has("act1"))
	play_dialogue(_db, state, "oda", ["Cast off for Thornwold."])
	assert_eq(state.quest_state("across_the_grey"), WorldState.QUEST_DONE, "the crossing works from the checkpoint")
	# Thornwold: no second landing scene, Bram gives his quest.
	state = _at("thornwold")
	assert_true(RegionEvents.arrival(_db.get_region("thornwold_landing"), state).is_empty(), "landing scene already seen")
	play_dialogue(_db, state, "bram", [])
	assert_eq(state.quest_stage("a_light_for_thornwold"), "the_bramble_wall")


func test_every_checkpoint_region_conversation_finishes() -> void:
	for scenario in Scenarios.all():
		var id := str(scenario["id"])
		var state := _at(id)
		for placement: Dictionary in _db.get_region(str(scenario["region"])).get("npcs", []):
			if not Conditions.evaluate(placement.get("if"), state):
				continue
			var npc := _db.get_npc(str(placement["npc"]))
			var runner := DialogueRunner.new(_db, state)
			var ev := runner.start(str(npc["dialogue"]))
			var steps := 0
			while ev["type"] != "end" and steps < 300:
				steps += 1
				ev = runner.choose((ev["options"] as Array).size() - 1) if ev["type"] == "choices" else runner.next()
			assert_true(ev["type"] == "end", "%s: talking to %s ends" % [id, placement["npc"]])


func test_validator_reports_bad_checkpoints() -> void:
	var db := load_content()
	var errors := Scenarios.validate(db, [
		{"id": "a", "act": "A", "title": "T", "description": "D", "region": "nowhere"},
		{"id": "b", "act": "A", "title": "T", "description": "D", "region": "saltmarrow", "spawn": "nope",
			"inherits": "later", "flags": {"no_flag": true}, "quests": {"lost_things": "no_stage"},
			"items": {"no_item": 1}, "collected": ["no_pickup"], "colour": 1},
		{"id": "later", "region": "saltmarrow"},
	] as Array[Dictionary])
	var text := "\n".join(errors)
	for expected: String in ["unknown region 'nowhere'", "spawn 'nope' not in region 'saltmarrow'",
			"inherits 'later', which must be an earlier scenario", "undeclared flag 'no_flag'",
			"quest 'lost_things' has no stage 'no_stage'", "unknown item 'no_item'",
			"unknown pickup 'no_pickup'", "unknown key 'colour'", "scenario 'later': needs 'title'"]:
		assert_true(text.contains(expected), "reports: " + expected)
