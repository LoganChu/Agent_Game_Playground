extends TestCase
## Content validation: every data file parses and every cross-reference resolves.


func test_content_loads_without_errors() -> void:
	var db := load_content()
	assert_empty(db.errors, "content load errors:")
	assert_true(db.regions.size() > 0, "no regions loaded")
	assert_true(db.npcs.size() > 0, "no NPCs loaded")
	assert_true(db.dialogues.size() > 0, "no dialogues loaded")


func test_all_references_valid() -> void:
	var validator := ContentValidator.new(load_content())
	var ok := validator.validate()
	if not validator.warnings.is_empty():
		print("        content warnings:\n        " + "\n        ".join(validator.warnings))
	assert_true(ok, "validation failed")
	assert_empty(validator.errors, "content errors:")


func test_every_dialogue_terminates_on_every_path() -> void:
	# Explore each dialogue from a fresh state by always taking each option once per menu,
	# and make sure the runner never gets stuck in a loop without output.
	var db := load_content()
	for id: String in db.dialogues:
		var state := WorldState.new()
		var runner := DialogueRunner.new(db, state)
		var ev := runner.start(id)
		var seen: Dictionary = {}
		var steps := 0
		while ev["type"] != "end" and steps < 500:
			if ev["type"] == "choices":
				var key := JSON.stringify(ev["options"])
				var visits: int = seen.get(key, 0)
				seen[key] = visits + 1
				ev = runner.choose(mini(visits, (ev["options"] as Array).size() - 1))
			else:
				ev = runner.next()
			steps += 1
		assert_eq(ev["type"], "end", "dialogue %s never ended" % id)


func test_validator_catches_broken_links() -> void:
	var db := load_content()
	# Break a few links on purpose and make sure each is reported.
	db.npcs["pell"]["dialogue"] = "no_such_dialogue"
	db.dialogues["mara"]["knots"]["hub"].append({"goto": "missing_knot"})
	db.dialogues["aldous"]["knots"]["start"].insert(0, {"set": {"undeclared_flag": true}})
	db.regions["saltmarrow"]["npcs"].append({"npc": "ghost", "position": [0, 0, 0]})
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["no_such_dialogue", "missing_knot", "undeclared_flag", "ghost", "dialogue pell: is orphaned"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)


func test_validator_checks_objects_and_gated_exits() -> void:
	var db := load_content()
	db.regions["gulls_head"]["objects"].append({"id": "gulls_beacon", "prompt": "Again", "dialogue": "no_such_talk"})
	db.regions["gulls_head"]["objects"].append({"id": "shrine", "dialogue": "gulls_beacon", "if": "item:no_such_item"})
	db.regions["gulls_head"]["exits"].append({"to": "saltmarrow", "position": [0, 0, 0], "requires": "flag:no_such_flag"})
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["duplicate object id 'gulls_beacon'", "no_such_talk", "object 'shrine' needs a 'prompt'",
			"no_such_item", "no_such_flag", "needs a 'locked_text'"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)


func test_validator_checks_fog_overrides_and_conditional_props() -> void:
	var db := load_content()
	var fog: Dictionary = db.regions["saltmarrow"]["fog"]
	fog["overrides"] = [{"density": 0.001}, {"if": "flag:fog_flag_missing", "density": "thick", "color": "no_such_color"}]
	db.regions["saltmarrow"]["props"].append({"shape": "crate", "position": [0, 0, 0], "if": "quest:no_such_quest=done"})
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["fog override needs an 'if'", "fog_flag_missing", "density must be a number",
			"no_such_color", "no_such_quest"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)
