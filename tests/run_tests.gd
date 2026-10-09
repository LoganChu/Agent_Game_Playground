extends SceneTree
## Minimal headless test runner (no third-party addon needed).
##
##   godot --headless --path . -s res://tests/run_tests.gd
##
## Loads every tests/test_*.gd (each extends TestCase), runs each method named test_*,
## prints a summary and exits non-zero if anything failed. Each line carries the test's time;
## the slowest few are listed at the end (the pre-push gate has a time limit).

const TEST_DIR := "res://tests"


func _initialize() -> void:
	var total := 0
	var failed := 0
	var started := Time.get_ticks_msec()
	var timings: Array[Array] = []  # [msec, name]
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
			var t0 := Time.get_ticks_msec()
			test.call(method_name)
			var took := Time.get_ticks_msec() - t0
			var label := "%s::%s" % [path.get_file(), method_name]
			timings.append([took, label])
			total += 1
			if test.failures.is_empty():
				print("ok    %s  (%d ms)" % [label, took])
			else:
				failed += 1
				printerr("FAIL  %s  (%d ms)" % [label, took])
				for f in test.failures:
					printerr("        " + f)
	timings.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("\nslowest:")
	for row: Array in timings.slice(0, 8):
		print("  %6d ms  %s" % [row[0], row[1]])
	print("\n%d tests, %d failed in %.1f s" % [total, failed, (Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if failed > 0 or total == 0 else 0)
