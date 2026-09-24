extends TestCase
## JournalModel: quest journal and satchel ordering/text rules, on a hand-built fixture.


func _fixture() -> ContentDatabase:
	var db := ContentDatabase.new()
	db.quests = {
		"a": {"id": "a", "title": "Alpha", "description": "About alpha.",
			"stages": [{"id": "one", "text": "Do one."}, {"id": "two", "text": "Do two."},
				{"id": "three", "text": "Do three."}]},
		"b": {"id": "b", "title": "Beta", "stages": [{"id": "x", "text": "Do x."}]},
		"c": {"id": "c", "title": "Gamma", "stages": [{"id": "y", "text": "Do y."}]},
		"unstarted": {"id": "unstarted", "title": "Never", "stages": [{"id": "z", "text": "z"}]},
	}
	db.items = {
		"rope": {"id": "rope", "name": "rope", "kind": "misc", "description": "Frayed."},
		"key": {"id": "key", "name": "Brass Key", "kind": "key"},
		"shell": {"id": "shell", "name": "Singing Shell", "kind": "remnant"},
		"bead": {"id": "bead", "name": "Amber Bead", "kind": "remnant"},
	}
	return db


func test_quest_order_and_stage_text() -> void:
	var world := WorldState.new()
	world.start_quest("b", "x")
	world.complete_quest("b")
	world.start_quest("a", "one")
	world.set_quest_stage("a", "two")
	world.start_quest("c", "y")
	var entries := JournalModel.quest_entries(_fixture(), world)
	var ids: Array = entries.map(func(e: Dictionary) -> String: return e["id"])
	assert_eq(ids, ["c", "a", "b"], "active newest-first, then done; unstarted hidden")
	var alpha: Dictionary = entries[1]
	assert_eq(alpha["title"], "Alpha")
	assert_eq(alpha["current"], "Do two.")
	assert_eq(alpha["completed"], ["Do one."] as Array[String])
	assert_false(alpha["done"])
	var beta: Dictionary = entries[2]
	assert_true(beta["done"])
	assert_eq(beta["current"], "", "done quests have no current objective")
	assert_eq(beta["completed"], ["Do x."] as Array[String], "done quests list every reached stage")


func test_quest_order_survives_save_round_trip() -> void:
	var world := WorldState.new()
	world.start_quest("a", "one")
	world.start_quest("c", "y")
	var loaded := WorldState.new()
	loaded.load_dict(JSON.parse_string(JSON.stringify(world.to_dict())))
	var ids: Array = JournalModel.quest_entries(_fixture(), loaded).map(
			func(e: Dictionary) -> String: return e["id"])
	assert_eq(ids, ["c", "a"])


func test_item_order_and_labels() -> void:
	var world := WorldState.new()
	world.add_item("rope", 3)
	world.add_item("key")
	world.add_item("shell")
	world.add_item("bead")
	world.add_item("gone")
	world.remove_item("gone")
	var entries := JournalModel.item_entries(_fixture(), world)
	var ids: Array = entries.map(func(e: Dictionary) -> String: return e["id"])
	assert_eq(ids, ["bead", "shell", "key", "rope"], "remnants, keys, misc; by name within kind")
	assert_true(entries[0]["remnant"])
	assert_false(entries[2]["remnant"])
	assert_eq(entries[3]["count"], 3)
	assert_eq(entries[3]["kind_label"], "Oddment")


func test_empty_world() -> void:
	var world := WorldState.new()
	assert_empty(JournalModel.quest_entries(_fixture(), world), "no quests")
	assert_empty(JournalModel.item_entries(_fixture(), world), "no items")
