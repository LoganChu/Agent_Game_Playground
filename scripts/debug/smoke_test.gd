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
	var player := get_tree().get_first_node_in_group(SaveSystem.PLAYER_GROUP)
	_check(player != null and player.find_child("CharacterRig", true, false) != null, "player shows the Wakebearer model")
	_finish_dialogue(ui, "intro")
	await _check_gates(main, false)
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
				if pass_index == 0 and npc.npc_data.has("model"):
					_check(npc.find_child("CharacterRig", true, false) != null, "npc %s shows its rigged model" % npc.npc_id)
				npc.interact()
				_check(ui.is_open(), "dialogue opens for " + npc.npc_id)
				_finish_dialogue(ui, npc.npc_id)
				await get_tree().process_frame
			for node in get_tree().get_nodes_in_group("inspectables"):
				var object := node as Inspectable
				if object.is_queued_for_deletion():
					continue
				object.interact()
				_check(ui.is_open(), "dialogue opens for object " + object.object_id)
				_finish_dialogue(ui, object.object_id)
				await get_tree().process_frame
			for node in get_tree().get_nodes_in_group("pickups"):
				if not node.is_queued_for_deletion():
					(node as Pickup).interact()
			await get_tree().process_frame
	await _check_gates(main, true)
	await _check_beacon_lit(main)
	await _check_journal(main.get("journal_ui"))
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


## Checks every gated exit in every region: locked exits refuse travel, open ones allow it.
func _check_gates(main: Node, expect_open: bool) -> void:
	for region_id: String in Content.db.regions:
		for exit_data: Dictionary in Content.db.get_region(region_id).get("exits", []):
			if not exit_data.has("requires"):
				continue
			GameState.travel(region_id)
			for i in 3:
				await get_tree().physics_frame
			var exit: RegionExit = null
			for node in get_tree().get_nodes_in_group("exits"):
				var candidate := node as RegionExit
				if not candidate.is_queued_for_deletion() and candidate.target_region == str(exit_data["to"]):
					exit = candidate
			_check(exit != null, "gated exit %s -> %s exists" % [region_id, exit_data["to"]])
			if exit == null:
				continue
			var target := exit.target_region
			_check(exit.is_locked() != expect_open, "exit %s -> %s is %s" % [region_id, target, "open" if expect_open else "locked"])
			exit.interact()
			for i in 3:
				await get_tree().physics_frame
			var now: Region = main.get("region")
			var arrived := now != null and now.region_id == target
			_check(arrived == expect_open, "exit %s -> %s %s travel" % [region_id, target, "allows" if expect_open else "refuses"])


## By the end of pass two the menu walk has fed the Gull's Beacon: check the quest, the
## burn flag, the lantern-room light and that the fog thinned.
func _check_beacon_lit(main: Node) -> void:
	var world := GameState.world
	_check(world.quest_state("a_light_for_saltmarrow") == WorldState.QUEST_DONE, "the Gull's Beacon is relit")
	_check(str(world.get_flag("saltmarrow_beacon_burned")) in ["pebble", "knot", "gull"], "a Remnant was burned")
	GameState.travel("gulls_head")
	for i in 3:
		await get_tree().physics_frame
	var region: Region = main.get("region")
	_check(region.shown_conditional_props() == 1, "beacon light shows once lit")
	var base := float((region.data.get("fog", {}) as Dictionary).get("density", 0.0))
	var target: float = main.call("target_fog_density")
	_check(target < base, "fog override thins Gull's Head")
	var env: Environment = main.get("_environment")
	_check(is_equal_approx(env.fog_density, target), "fog applied on region load")


## Opens both journal tabs via the real input actions and checks they mirror world state.
func _check_journal(journal: JournalUI) -> void:
	# Parsed input is flushed at the start of the next frame; resuming from a physics
	# frame can mean that is two process frames away, so always wait two.
	_press("journal")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(journal.is_open() and journal.tab == JournalUI.Tab.JOURNAL, "J opens the journal")
	_check(GameState.input_locked, "journal locks player input")
	var quests := JournalModel.quest_entries(Content.db, GameState.world)
	_check(journal.entry_count() == quests.size() and quests.size() > 0, "journal lists started quests")
	_press("inventory")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(journal.is_open() and journal.tab == JournalUI.Tab.SATCHEL, "I switches to the satchel")
	var items := JournalModel.item_entries(Content.db, GameState.world)
	_check(journal.entry_count() == items.size(), "satchel lists carried items")
	if not items.is_empty():
		_check(journal.detail_text().contains(str(items[0]["description"])), "satchel shows item description")
	_press("ui_cancel")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not journal.is_open() and not GameState.input_locked, "Esc closes the journal and unlocks input")


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)


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
