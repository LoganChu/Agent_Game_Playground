class_name Scenarios
extends RefCounted
## Story checkpoints for developers (data/scenarios.json): named points in the story you can
## jump straight to — `--scenario=<id>` on the command line, the pause menu's "Chapter select"
## page in debug builds, or `tools/checkpoints.sh` for a screenshot gallery of every one.
##
## A scenario: {id, act, title, description, region, spawn?, inherits?, flags?, quests?,
## items?, collected?, shot?}. `inherits` names an earlier checkpoint whose state it starts from, so
## each one only lists what changed. `quests` maps id → stage id or "done"; `items` maps id →
## count (0 removes an inherited item); `collected` lists pickup ids already picked up;
## `shot` = extra screenshot args for the gallery (tools/checkpoints.sh).
## Applying one resets the world to a new game first. Validated with the rest of the content.

const PATH := "res://data/scenarios.json"
const KEYS: Array[String] = ["id", "act", "title", "description", "region", "spawn", "inherits",
		"flags", "quests", "items", "collected", "shot", "note"]


## Every scenario in file order (empty if the file is missing or malformed).
static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var errors: Array[String] = []
	var data: Variant = JsonUtil.load_file(PATH, errors)
	if data is Dictionary and (data as Dictionary).get("scenarios") is Array:
		for entry: Variant in data["scenarios"]:
			if entry is Dictionary:
				out.append(entry)
	return out


static func find(id: String, list: Array[Dictionary] = []) -> Dictionary:
	for scenario in (list if not list.is_empty() else all()):
		if str(scenario.get("id", "")) == id:
			return scenario
	return {}


## The scenario with everything it inherits folded in (earliest first, later wins).
static func resolve(id: String, list: Array[Dictionary] = []) -> Dictionary:
	if list.is_empty():
		list = all()
	var chain: Array[Dictionary] = []
	var seen := {}
	var current := find(id, list)
	while not current.is_empty() and not seen.has(current["id"]):
		seen[current["id"]] = true
		chain.push_front(current)
		current = find(str(current.get("inherits", "")), list) if current.has("inherits") else {}
	if chain.is_empty():
		return {}
	var out := {"flags": {}, "quests": {}, "items": {}, "collected": []}
	for link in chain:
		for key: String in ["flags", "quests", "items"]:
			(out[key] as Dictionary).merge(link.get(key, {}), true)
		(out["collected"] as Array).append_array(link.get("collected", []))
	var leaf := chain[-1]
	for key: String in ["id", "act", "title", "description", "region", "spawn"]:
		if leaf.has(key):
			out[key] = leaf[key]
	return out


## Resets `world` to a new game, then applies the resolved scenario's state.
static func apply(db: ContentDatabase, world: WorldState, scenario: Dictionary) -> void:
	world.load_dict({})
	for flag_id: String in db.flags:
		world.flags[flag_id] = db.flag_default(flag_id)
	var flags: Dictionary = scenario.get("flags", {})
	for flag_id: String in flags:
		world.set_flag(flag_id, flags[flag_id])
	var quests: Dictionary = scenario.get("quests", {})
	for quest_id: String in quests:
		var stages: Array = db.get_quest(quest_id).get("stages", [])
		var stage := str(quests[quest_id])
		world.start_quest(quest_id, stage if stage != "done" else str((stages[0] as Dictionary)["id"]))
		if stage == "done":
			world.complete_quest(quest_id)
	var items: Dictionary = scenario.get("items", {})
	for item_id: String in items:
		if int(items[item_id]) > 0:
			world.add_item(item_id, int(items[item_id]))
	for pickup_id: Variant in scenario.get("collected", []):
		world.mark_collected(str(pickup_id))


## Problems with the scenario file, as validator messages.
static func validate(db: ContentDatabase, list: Array[Dictionary]) -> Array[String]:
	var errors: Array[String] = []
	var pickups := {}
	for region: Dictionary in db.regions.values():
		for pickup: Dictionary in region.get("pickups", []):
			pickups[str(pickup.get("id", ""))] = true
	var ids := {}
	for scenario in list:
		var id := str(scenario.get("id", ""))
		var where := "scenario '%s'" % id
		if id.is_empty() or ids.has(id):
			errors.append("scenario id missing or duplicated: '%s'" % id)
		ids[id] = true
		for key: String in scenario:
			if key not in KEYS:
				errors.append("%s: unknown key '%s'" % [where, key])
		for key: String in ["act", "title", "description", "region"]:
			if str(scenario.get(key, "")).is_empty():
				errors.append("%s: needs '%s'" % [where, key])
		var region := str(scenario.get("region", ""))
		if not db.regions.has(region):
			errors.append("%s: unknown region '%s'" % [where, region])
		elif not (db.get_region(region).get("spawn_points", {}) as Dictionary).has(str(scenario.get("spawn", "default"))):
			errors.append("%s: spawn '%s' not in region '%s'" % [where, scenario.get("spawn"), region])
		if scenario.has("inherits") and not ids.has(str(scenario["inherits"])):
			errors.append("%s: inherits '%s', which must be an earlier scenario" % [where, scenario["inherits"]])
		for flag_id: String in scenario.get("flags", {}):
			if not db.flags.has(flag_id):
				errors.append("%s: undeclared flag '%s'" % [where, flag_id])
		var quests: Dictionary = scenario.get("quests", {})
		for quest_id: String in quests:
			var stage := str(quests[quest_id])
			var stage_ids: Array = db.get_quest(quest_id).get("stages", []).map(func(s: Dictionary) -> String: return str(s["id"]))
			if not db.quests.has(quest_id):
				errors.append("%s: unknown quest '%s'" % [where, quest_id])
			elif stage != "done" and stage not in stage_ids:
				errors.append("%s: quest '%s' has no stage '%s'" % [where, quest_id, stage])
		for item_id: String in scenario.get("items", {}):
			if not db.items.has(item_id):
				errors.append("%s: unknown item '%s'" % [where, item_id])
		for pickup_id: Variant in scenario.get("collected", []):
			if not pickups.has(str(pickup_id)):
				errors.append("%s: unknown pickup '%s'" % [where, pickup_id])
	return errors
