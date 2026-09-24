extends SceneTree
## Minimal headless test runner (no third-party addon needed).
##
##   godot --headless --path . -s res://tests/run_tests.gd
##
## Loads every tests/test_*.gd (each extends TestCase), runs each method named test_*,
## prints a summary and exits non-zero if anything failed.

const TEST_DIR := "res://tests"


func _initialize() -> void:
	var total := 0
	var failed := 0
	for path in JsonUtil.list_files(TEST_DIR, "gd"):
		if not path.get_file().begins_with("test_"):
			continue
		var script := load(path) as GDScript
		if script == null:
			printerr("FAIL  could not load %s" % path)
			failed += 1
			continue
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var test: TestCase = script.new()
			test.call(method_name)
			total += 1
			if test.failures.is_empty():
				print("ok    %s::%s" % [path.get_file(), method_name])
			else:
				failed += 1
				printerr("FAIL  %s::%s" % [path.get_file(), method_name])
				for f in test.failures:
					printerr("        " + f)
	print("\n%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)
