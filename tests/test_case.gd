class_name TestCase
extends RefCounted
## Base class for tests run by tests/run_tests.gd. Assertions record failures instead of
## aborting, so one test reports every problem it finds.

var failures: PackedStringArray = []


func assert_true(value: bool, message: String = "expected true") -> void:
	if not value:
		failures.append(message)


func assert_false(value: bool, message: String = "expected false") -> void:
	if value:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%sexpected %s but got %s" % [message + ": " if message else "", var_to_str(expected), var_to_str(actual)])


func assert_empty(list: Array, message: String = "") -> void:
	if not list.is_empty():
		failures.append("%s\n        %s" % [message, "\n        ".join(PackedStringArray(list))])


## Loads the real game content.
func load_content() -> ContentDatabase:
	var db := ContentDatabase.new()
	db.load_all()
	return db


## A WorldState with every declared flag at its default, as a new game starts.
func fresh_state(db: ContentDatabase) -> WorldState:
	var state := WorldState.new()
	for flag_id: String in db.flags:
		state.flags[flag_id] = db.flag_default(flag_id)
	return state


## Runs `dialogue` to its end, picking options by exact text in order (an unmatched or
## missing pick takes the last option, every menu's way out). Returns the spoken lines
## joined by newlines; every option offered along the way is appended to `offered`.
func play_dialogue(db: ContentDatabase, state: WorldState, dialogue: String, picks: Array[String], offered: Array[String] = []) -> String:
	var out: PackedStringArray = []
	var runner := DialogueRunner.new(db, state)
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
