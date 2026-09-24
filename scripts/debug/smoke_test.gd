class_name SmokeTest
extends Node
## Automated end-to-end playthrough of the loaded region, run with:
##   godot --headless --path . -- --smoke-test
## Talks to every NPC (walking menus option by option), collects every pickup, then
## quicksaves, resets and quickloads, checking state survives. Exits 0 on success.

const MAX_DIALOGUE_STEPS := 200
const PASSES := 2

var _failures: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Let the main scene finish building (deferred region load, intro dialogue, physics).
	for i in 5:
		await get_tree().physics_frame
	var main := get_parent()
	var ui: DialogueUI = main.get("dialogue_ui")
	_check(ui.is_open(), "intro dialogue plays on new game")
	_finish_dialogue(ui, "intro")
	# Two passes over every region so quests started on pass 1 can be finished on pass 2.
	for pass_index in PASSES:
		for region_id: String in Content.db.regions:
			GameState.travel(region_id)
			for i in 3:
				await get_tree().physics_frame
			var region: Region = main.get("region")
			_check(region != null and region.region_id == region_id, "region %s loaded" % region_id)
			for node in get_tree().get_nodes_in_group("npcs"):
				var npc := node as NpcActor
				if npc.is_queued_for_deletion():
					continue
				npc.interact()
				_check(ui.is_open(), "dialogue opens for " + npc.npc_id)
				_finish_dialogue(ui, npc.npc_id)
				await get_tree().process_frame
			for node in get_tree().get_nodes_in_group("pickups"):
				if not node.is_queued_for_deletion():
					(node as Pickup).interact()
			await get_tree().process_frame
	print("Smoke test end state: ", JSON.stringify(GameState.world.to_dict()))
	var before := GameState.world.to_dict()
	_check(SaveSystem.save_game("smoke_test"), "save succeeds")
	GameState.world.load_dict({})
	_check(SaveSystem.load_game("smoke_test"), "load succeeds")
	_check(JSON.stringify(GameState.world.to_dict()) == JSON.stringify(before), "state round-trips through save")
	DirAccess.remove_absolute(SaveSystem.slot_path("smoke_test"))
	for i in 3:
		await get_tree().process_frame
	_check(main.get("region") != null, "region rebuilt after load")
	if _failures.is_empty():
		print("SMOKE TEST PASSED")
		get_tree().quit(0)
	else:
		printerr("SMOKE TEST FAILED:\n  " + "\n  ".join(_failures))
		get_tree().quit(1)


## Clicks through an open dialogue. Picks option 0 the first time a menu is seen, then 1,
## and so on, so hub menus that loop back eventually reach their last ("goodbye") option.
func _finish_dialogue(ui: DialogueUI, who: String) -> void:
	var steps := 0
	var seen: Dictionary = {}
	while ui.is_open() and steps < MAX_DIALOGUE_STEPS:
		if ui.current_event.get("type") == "choices":
			var options: Array = ui.current_event["options"]
			var key := JSON.stringify(options)
			var visits: int = seen.get(key, 0)
			seen[key] = visits + 1
			ui.select(mini(visits, options.size() - 1))
		else:
			ui.advance()
		steps += 1
	_check(not ui.is_open(), "dialogue with %s finishes" % who)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
