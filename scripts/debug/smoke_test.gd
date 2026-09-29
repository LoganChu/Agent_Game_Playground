class_name SmokeTest
extends Node
## Automated end-to-end playthrough of the loaded region, run with:
##   godot --headless --path . -- --smoke-test
## Talks to every NPC (walking menus option by option), collects every pickup, then
## quicksaves, resets and quickloads, checking state survives. Exits 0 on success.

const MAX_DIALOGUE_STEPS := 200
const PASSES := 3

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
	await _check_ground(main)
	await _check_greying(main)
	await _check_gates(main, false)
	# Several passes over every region so quests started on one pass can advance on the next
	# (pass 3 reaches Aldous's confession and Mara's ferry lantern).
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
	await _check_act_one_close(main)
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


## Sculpted ground: the player lands on it at every region's spawn, NPCs stand on it, the
## Gull's Head ramp can be walked up with real input and physics, the shore wall stops
## the player wading out to sea, and the Saltmarrow dock can be walked out onto.
func _check_ground(main: Node) -> void:
	var player: Player = get_tree().get_first_node_in_group(SaveSystem.PLAYER_GROUP)
	for region_id: String in Content.db.regions:
		GameState.travel(region_id)
		for i in 30:
			await get_tree().physics_frame
		var region: Region = main.get("region")
		if region.field == null:
			continue
		var p := player.global_position
		_check(player.is_on_floor() and absf(p.y - region.ground_y(p.x, p.z)) < 0.25, "player stands on the ground at %s spawn" % region_id)
		for node in get_tree().get_nodes_in_group("npcs"):
			var npc := node as NpcActor
			_check(absf(npc.position.y - region.ground_y(npc.position.x, npc.position.z)) < 0.01, "npc %s stands on the ground" % npc.npc_id)
	GameState.travel("gulls_head")
	for i in 3:
		await get_tree().physics_frame
	var region: Region = main.get("region")
	var camera_yaw: Node3D = player.get("_camera_yaw")
	camera_yaw.rotation.y = 0.0  # move_forward = -Z: from the lofts up the ramp to the beacon
	player.place_at(Vector3(0, region.ground_y(0, 0) + 0.2, 0))
	await _hold("move_forward", 150)
	var top := player.global_position
	print("Smoke: ramp walk reached ", top)
	_check(top.z < -8.0 and top.y > 2.3, "player walks up the Gull's Head ramp (reached %s)" % top)
	player.place_at(Vector3(0, region.ground_y(0, 15) + 0.2, 15))
	await _hold("move_back", 120)  # +Z: straight out to sea
	var shore := player.global_position
	print("Smoke: sea walk reached ", shore)
	_check(shore.y > region.ground_y(0, 15) - 0.6 and shore.z < 22.0, "shore wall stops the player wading out (reached %s)" % shore)
	# The Saltmarrow dock is a pier: walkable out over the harbor, walled at its sides.
	GameState.travel("saltmarrow")
	for i in 3:
		await get_tree().physics_frame
	region = main.get("region")
	player.place_at(Vector3(6, region.ground_y(6, 8) + 0.2, 8))
	await _hold("move_back", 150)  # +Z: down the walkway and out along the dock
	var dock := player.global_position
	print("Smoke: dock walk reached ", dock)
	_check(dock.z > 16.5 and absf(dock.y - region.ground_y(dock.x, dock.z)) < 0.2, "player walks out along the Saltmarrow dock (reached %s)" % dock)
	await _hold("move_right", 90)  # +X: off the side of the dock
	var side := player.global_position
	print("Smoke: dock side walk reached ", side)
	_check(side.x < 7.6 and side.y > 0.0, "the dock's sides are walled (reached %s)" % side)
	camera_yaw.rotation.y = 0.0


## The Greying before the burn: walking up into the Gull's Head fog drains the ember and
## shows the meter; when it runs out the player is turned back to clear ground, refilled.
func _check_greying(main: Node) -> void:
	var player: Player = get_tree().get_first_node_in_group(SaveSystem.PLAYER_GROUP)
	var walker: GreyingWalker = main.get("greying")
	var hud: Hud = main.get("hud")
	GameState.travel("gulls_head")
	for i in 3:
		await get_tree().physics_frame
	var region: Region = main.get("region")
	_check(region.shown_greying() > 0, "Gull's Head shows Greying fog before the burn")
	var camera_yaw: Node3D = player.get("_camera_yaw")
	camera_yaw.rotation.y = 0.0
	player.place_at(Vector3(0, region.ground_y(0, 6) + 0.2, 6))
	for i in 10:
		await get_tree().physics_frame
	walker.meter.refill()
	await _hold("move_forward", 240)
	print("Smoke: walked into the Greying to ", player.global_position, " depth ", walker.depth, " ember ", walker.meter.ember)
	_check(walker.depth > 0.5, "the headland lies deep in the Greying (depth %s)" % walker.depth)
	_check(walker.meter.ember < 0.95, "the Greying drains the ember (%s)" % walker.meter.ember)
	_check(hud.is_meter_shown(), "ember meter shows in the Greying")
	walker.meter.drain_scale = 60.0
	var guard := 0
	while not walker.turning_back and guard < 300:
		guard += 1
		await get_tree().physics_frame
	_check(walker.turning_back and GameState.input_locked, "an empty ember turns the player back")
	await walker.turned_back
	walker.meter.drain_scale = 1.0
	for i in 5:
		await get_tree().physics_frame
	var p := player.global_position
	print("Smoke: turned back to ", p)
	_check(region.greying_depth(p.x, p.z) < Greying.CLEAR_DEPTH and p.z > 3.0, "turned back to clear ground (%s)" % p)
	_check(walker.meter.ember > 0.99 and not GameState.input_locked, "ember refilled and input returned")


func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	for i in frames:
		await get_tree().physics_frame
	Input.action_release(action)
	for i in 10:
		await get_tree().physics_frame


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
	_check(region.shown_conditional_props("beacon_light") == 1, "beacon light shows once lit")
	_check(region.greying_depth(0, -13) < Greying.CLEAR_DEPTH and region.shown_greying() > 0, "the Greying leans back off the headland, pockets remain")
	var base := float((region.data.get("fog", {}) as Dictionary).get("density", 0.0))
	var target: float = main.call("target_fog_density")
	_check(target < base, "fog override thins Gull's Head")
	var atmosphere: Atmosphere = main.get("atmosphere")
	_check(is_equal_approx(atmosphere.environment.fog_density, target), "fog applied on region load")
	var light := RegionMood.light(region.data, world)
	_check(is_equal_approx(atmosphere.sun.light_energy, float(light["sun_energy"])), "region light applied on region load")


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


## Act I's close: Aldous has confessed (either way), Mara has hung the ferry signal lantern
## and it shows at the Saltmarrow dock.
func _check_act_one_close(main: Node) -> void:
	var world := GameState.world
	_check(str(world.get_flag("saltmarrow_aldous_confessed")) in ["full", "grudging"], "Aldous confessed")
	_check(world.quest_stage("across_the_grey") == "await_the_ferry", "ferry quest awaits the ferry")
	GameState.travel("saltmarrow")
	for i in 3:
		await get_tree().physics_frame
	var region: Region = main.get("region")
	_check(region.shown_conditional_props("signal_lantern") == 1, "ferry signal lantern shows at the dock")
	# Saltmarrow after the burn: nets are out drying, and the dressing matches the burn.
	var burned := str(world.get_flag("saltmarrow_beacon_burned"))
	_check(region.shown_conditional_props("net_frame") == (2 if burned == "knot" else 0), "net frames only after the knot burn")
	_check(region.shown_conditional_props("net_rack") == (0 if burned == "knot" else 2), "whole nets drying unless the knot burned")
	_check(region.shown_conditional_props("cups") == (1 if burned == "gull" else 0), "two cups only after the gull burn")
	await _check_live_refresh(region)


## Conditional NPCs, pickups and objects appear/disappear live when a flag changes mid-visit
## (via main.gd's world-changed hook). Probes are added with a scratch condition, then
## removed again so the rest of the run is unaffected.
func _check_live_refresh(region: Region) -> void:
	var world := GameState.world
	var flag := "saltmarrow_pell_lent_pebble"
	var before: Variant = world.get_flag(flag)
	world.set_flag(flag, false)
	var probes: Array[Dictionary] = [
		{"kind": "npc", "data": {"npc": "pell", "position": [2, 0, 4], "if": "flag:" + flag}, "node": null},
		{"kind": "pickup", "data": {"id": "smoke_probe", "item": "harbor_token", "position": [3, 0, 4], "if": "flag:" + flag}, "node": null},
		{"kind": "object", "data": {"id": "smoke_probe", "dialogue": "mara", "position": [4, 0, 4], "if": "flag:" + flag}, "node": null},
	]
	region._conditional.append_array(probes)
	var groups := ["npcs", "pickups", "inspectables"]
	var counts := groups.map(func(g: String) -> int: return _live_in_group(g))
	world.set_flag(flag, true)
	await get_tree().process_frame
	for i in groups.size():
		_check(_live_in_group(groups[i]) == counts[i] + 1, "live refresh adds a conditional %s" % groups[i])
	world.set_flag(flag, false)
	await get_tree().process_frame
	for i in groups.size():
		_check(_live_in_group(groups[i]) == counts[i], "live refresh removes a conditional %s" % groups[i])
	for probe in probes:
		region._conditional.erase(probe)
	world.set_flag(flag, before)


func _live_in_group(group: String) -> int:
	return get_tree().get_nodes_in_group(group).filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()


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
