extends TestCase
## WorldState mutations and save round-trip.


func test_quest_lifecycle() -> void:
	var s := WorldState.new()
	assert_eq(s.quest_state("q"), "inactive")
	s.set_quest_stage("q", "x")
	assert_eq(s.quest_state("q"), "inactive", "stage change ignored for inactive quest")
	s.start_quest("q", "a")
	s.set_quest_stage("q", "b")
	assert_eq(s.quest_stage("q"), "b")
	s.complete_quest("q")
	assert_eq(s.quest_state("q"), "done")
	s.start_quest("q", "a")
	assert_eq(s.quest_state("q"), "done", "completed quest cannot restart")


func test_inventory() -> void:
	var s := WorldState.new()
	s.add_item("a", 2)
	assert_false(s.remove_item("a", 3))
	assert_eq(s.item_count("a"), 2)
	assert_true(s.remove_item("a", 2))
	assert_false(s.inventory.has("a"), "empty stacks are removed")


func test_round_trip_through_json() -> void:
	var s := WorldState.new()
	s.set_flag("f", true)
	s.set_flag("g", "kept")
	s.start_quest("q", "a")
	s.add_item("a", 3)
	s.mark_collected("p1")
	var json := JSON.stringify(s.to_dict())
	var t := WorldState.new()
	t.load_dict(JSON.parse_string(json))
	assert_eq(t.get_flag("g"), "kept")
	assert_eq(t.quest_stage("q"), "a")
	assert_eq(t.item_count("a"), 3)
	assert_true(t.is_collected("p1"))
	assert_eq(JSON.stringify(t.to_dict()), json)
