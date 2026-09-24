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
