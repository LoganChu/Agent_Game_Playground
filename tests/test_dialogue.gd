extends TestCase
## DialogueRunner and Conditions behaviour, on a small hand-built fixture.


func _fixture() -> ContentDatabase:
	var db := ContentDatabase.new()
	db.npcs = {"ann": {"id": "ann", "name": "Ann"}}
	db.items = {"key": {"id": "key", "name": "Key"}}
	db.quests = {"q": {"id": "q", "stages": [{"id": "one", "text": "1"}, {"id": "two", "text": "2"}]}}
	db.flags = {"met": {"description": "d"}, "mood": {"description": "d", "default": ""}}
	db.dialogues = {"d": {"id": "d", "knots": {
		"start": [
			{"if": "flag:met", "goto": "again"},
			{"set": {"met": true}},
			{"say": "ann", "text": "Hello."},
			{"choice": [
				{"text": "Take key", "give_item": "key", "quest_start": "q", "goto": "took"},
				{"text": "Hidden", "if": "item:key", "goto": "took"},
				{"text": "Bye", "end": true}]}],
		"took": [
			{"say": "player", "text": "Thanks."},
			{"quest_stage": ["q", "two"]},
			{"set": {"mood": "happy"}}],
		"again": [
			{"if": "flag:mood=happy", "say": "ann", "text": "Still happy?"},
			{"if": "!flag:mood=happy", "say": "ann", "text": "Hmph."}]}}}
	return db


func test_line_choice_and_effects() -> void:
	var db := _fixture()
	var state := WorldState.new()
	var runner := DialogueRunner.new(db, state)
	var ev := runner.start("d")
	assert_eq(ev["type"], "line")
	assert_eq(ev["name"], "Ann")
	assert_eq(ev["text"], "Hello.")
	assert_eq(state.get_flag("met"), true)
	ev = runner.next()
	assert_eq(ev["type"], "choices")
	assert_eq((ev["options"] as Array).size(), 2, "hidden option filtered")
	ev = runner.choose(0)
	assert_eq(ev["name"], "You")
	assert_eq(state.item_count("key"), 1)
	assert_eq(state.quest_state("q"), "active")
	ev = runner.next()
	assert_eq(ev["type"], "end")
	assert_eq(state.quest_stage("q"), "two")
	assert_eq(state.get_flag("mood"), "happy")
	assert_false(runner.is_running())


func test_flag_branches_on_revisit() -> void:
	var db := _fixture()
	var state := WorldState.new()
	state.set_flag("met", true)
	var runner := DialogueRunner.new(db, state)
	assert_eq(runner.start("d")["text"], "Hmph.")
	state.set_flag("mood", "happy")
	assert_eq(runner.start("d")["text"], "Still happy?")


func test_end_option() -> void:
	var runner := DialogueRunner.new(_fixture(), WorldState.new())
	runner.start("d")
	runner.next()
	assert_eq(runner.choose(1)["type"], "end")


func test_condition_parsing() -> void:
	assert_true(Conditions.parse("bogus").has("error"))
	assert_true(Conditions.parse("quest:q=started").has("error"))
	assert_true(Conditions.parse("item:x=3").has("error"))
	var p := Conditions.parse("!item:key>=2")
	assert_eq(p["negate"], true)
	assert_eq(p["kind"], "item")
	assert_eq(p["value"], "2")
	var state := WorldState.new()
	state.add_item("key", 2)
	assert_true(Conditions.evaluate("item:key>=2", state))
	assert_false(Conditions.evaluate(["item:key>=2", "flag:nope"], state))
	assert_true(Conditions.evaluate(null, state), "empty condition is true")
