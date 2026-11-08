class_name WorldState
extends RefCounted
## All mutable story/world state: flags, quests, inventory, collected pickups.
## Serializable to a plain Dictionary for save files.

signal flag_changed(id: String, value: Variant)
signal quest_changed(id: String, state: String, stage: String)
signal inventory_changed(item_id: String, count: int)

const QUEST_INACTIVE := "inactive"
const QUEST_ACTIVE := "active"
const QUEST_DONE := "done"

var flags: Dictionary = {}
## quest id -> {"state": String, "stage": String}
var quests: Dictionary = {}
## item id -> count
var inventory: Dictionary = {}
## pickup instance ids that have been collected (value is always true)
var collected: Dictionary = {}
## Where each walking NPC (a placement `circuit`) has got to round its circle (Day 91), so a reload or a
## return finds them where they were: npc id -> {"center": [x, z], "radius": r, "angle": radians}.
## Only a walk on the same circle picks the angle up again.
var walkers: Dictionary = {}


func get_flag(id: String, default_value: Variant = false) -> Variant:
	return flags.get(id, default_value)


func set_flag(id: String, value: Variant) -> void:
	if flags.get(id) == value:
		return
	flags[id] = value
	flag_changed.emit(id, value)


func quest_state(id: String) -> String:
	var entry: Dictionary = quests.get(id, {})
	return entry.get("state", QUEST_INACTIVE)


func quest_stage(id: String) -> String:
	var entry: Dictionary = quests.get(id, {})
	return entry.get("stage", "")


func start_quest(id: String, first_stage: String) -> void:
	if quest_state(id) != QUEST_INACTIVE:
		return
	quests[id] = {"state": QUEST_ACTIVE, "stage": first_stage}
	quest_changed.emit(id, QUEST_ACTIVE, first_stage)


func set_quest_stage(id: String, stage: String) -> void:
	if quest_state(id) != QUEST_ACTIVE:
		return
	quests[id]["stage"] = stage
	quest_changed.emit(id, QUEST_ACTIVE, stage)


func complete_quest(id: String) -> void:
	if quest_state(id) == QUEST_DONE:
		return
	quests[id] = {"state": QUEST_DONE, "stage": quest_stage(id)}
	quest_changed.emit(id, QUEST_DONE, quest_stage(id))


func item_count(id: String) -> int:
	return int(inventory.get(id, 0))


func add_item(id: String, count: int = 1) -> void:
	var total := item_count(id) + count
	if total <= 0:
		inventory.erase(id)
		total = 0
	else:
		inventory[id] = total
	inventory_changed.emit(id, total)


## Removes up to `count`; returns false (and removes nothing) if not enough.
func remove_item(id: String, count: int = 1) -> bool:
	if item_count(id) < count:
		return false
	add_item(id, -count)
	return true


func is_collected(pickup_id: String) -> bool:
	return collected.has(pickup_id)


func mark_collected(pickup_id: String) -> void:
	collected[pickup_id] = true


func to_dict() -> Dictionary:
	return {
		"flags": flags.duplicate(true),
		"quests": quests.duplicate(true),
		"inventory": inventory.duplicate(true),
		"collected": collected.keys(),
		"walkers": walkers.duplicate(true),
	}


func load_dict(data: Dictionary) -> void:
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	quests = (data.get("quests", {}) as Dictionary).duplicate(true)
	inventory = {}
	var inv: Dictionary = data.get("inventory", {})
	for key: String in inv:
		inventory[key] = int(inv[key]) # JSON numbers load as float
	walkers = (data.get("walkers", {}) as Dictionary).duplicate(true)
	collected = {}
	for pickup_id: Variant in data.get("collected", []):
		collected[str(pickup_id)] = true


## Remembers how far round its circuit a walking NPC has got (see `walkers`).
func note_walker(npc_id: String, circuit: Dictionary, angle: float) -> void:
	walkers[npc_id] = {"center": circuit.get("center", [0, 0]), "radius": circuit.get("radius", 0), "angle": angle}


## The angle a walker had reached on this same circuit, or null (another circle, or never walked).
func walker_angle(npc_id: String, circuit: Dictionary) -> Variant:
	var seen: Variant = walkers.get(npc_id)
	if not seen is Dictionary:
		return null
	var at: Array = (seen as Dictionary).get("center", [])
	var c: Array = circuit.get("center", [0, 0])
	if at.size() != 2 or absf(float(at[0]) - float(c[0])) > 0.01 or absf(float(at[1]) - float(c[1])) > 0.01:
		return null
	if absf(float((seen as Dictionary).get("radius", 0)) - float(circuit.get("radius", 0))) > 0.01:
		return null
	return float((seen as Dictionary).get("angle", 0.0))
