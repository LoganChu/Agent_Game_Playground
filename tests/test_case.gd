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
