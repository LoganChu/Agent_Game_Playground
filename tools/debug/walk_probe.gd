extends SceneTree
## Lists every pair of one NPC's placements per region and what a move between them does mid-visit (WalkSurvey):
##   godot --headless --path . -s res://tools/debug/walk_probe.gd [-- <region_id> ... [--flags=a,b] [--walks]]
## Each region is built in the tree with the given flags set (none by default), so the props shown then and the other
## NPCs block the way as they would in the game. `--walks` leaves out the swaps and the seated/circuit fades.
## The scripts that use the autoloads are loaded at run time (as the test runner does): a `-s` script that names them
## outright fails to compile before the autoloads exist.


func _initialize() -> void:
	var only: Array[String] = []
	var walks_only := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--flags="):
			for flag: String in arg.trim_prefix("--flags=").split(",", false):
				root.get_node("GameState").world.flags[flag] = true
		elif arg == "--walks":
			walks_only = true
		else:
			only.append(arg)
	_run(only, walks_only)


func _run(only: Array[String], walks_only: bool) -> void:
	await process_frame  # the Content autoload loads the data in its _ready
	var ids: Array = root.get_node("Content").db.regions.keys()
	ids.sort()
	var survey: GDScript = load("res://scripts/world/walk_survey.gd")
	var totals := {}
	for id: String in ids:
		if not only.is_empty() and id not in only:
			continue
		var region: Node3D = load("res://scripts/world/region.gd").new()
		root.add_child(region)
		region.call("build", id)
		for i in 3:
			await physics_frame
		var rows: Array = survey.survey(region)
		if not rows.is_empty():
			print("== %s" % id)
		for row: Dictionary in rows:
			if walks_only and (row["kind"] == survey.SWAP or str(row["reason"]) in ["seated", "circuit"]):
				continue
			print("  " + survey.describe(row))
		var tally: Dictionary = survey.tally(rows)
		for kind: String in tally:
			totals[kind] = int(totals.get(kind, 0)) + int(tally[kind])
		region.queue_free()
		await process_frame
	print("== total  %s" % totals)
	quit(0)
