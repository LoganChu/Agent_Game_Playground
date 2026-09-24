class_name ContentDatabase
extends RefCounted
## Loads all data-driven content (regions, NPCs, items, quests, flags, dialogues) into
## dictionaries keyed by id. Pure data: no nodes, so it is usable from tests and tools.

const KINDS: Array[String] = ["regions", "npcs", "items", "quests"]

var regions: Dictionary = {}
var npcs: Dictionary = {}
var items: Dictionary = {}
var quests: Dictionary = {}
var dialogues: Dictionary = {}
## flag id -> {"description": String, "default": Variant}
var flags: Dictionary = {}
## Game config (start region, etc.) from data/game.json.
var game: Dictionary = {}
## Where each record came from (id -> file path), for error messages.
var sources: Dictionary = {}
var errors: Array[String] = []


func load_all(data_root: String = "res://data", story_root: String = "res://story") -> bool:
	errors.clear()
	for kind in KINDS:
		_load_kind(kind, data_root.path_join(kind))
	_load_flags(data_root.path_join("flags.json"))
	var game_data: Variant = JsonUtil.load_file(data_root.path_join("game.json"), errors)
	if game_data is Dictionary:
		game = game_data
	for path in JsonUtil.list_files(story_root, "json"):
		_load_record(dialogues, "dialogue", path)
	return errors.is_empty()


func table(kind: String) -> Dictionary:
	match kind:
		"regions": return regions
		"npcs": return npcs
		"items": return items
		"quests": return quests
		"dialogues": return dialogues
	return {}


func get_region(id: String) -> Dictionary:
	return regions.get(id, {})


func get_npc(id: String) -> Dictionary:
	return npcs.get(id, {})


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func get_quest(id: String) -> Dictionary:
	return quests.get(id, {})


func get_dialogue(id: String) -> Dictionary:
	return dialogues.get(id, {})


func flag_default(id: String) -> Variant:
	var entry: Dictionary = flags.get(id, {})
	return entry.get("default", false)


func _load_kind(kind: String, dir_path: String) -> void:
	for path in JsonUtil.list_files(dir_path, "json"):
		_load_record(table(kind), kind, path)


func _load_record(target: Dictionary, kind: String, path: String) -> void:
	var data: Variant = JsonUtil.load_file(path, errors)
	if data == null:
		return
	if not data is Dictionary:
		errors.append("%s: top level must be an object" % path)
		return
	var record: Dictionary = data
	var id := str(record.get("id", ""))
	if id.is_empty():
		errors.append("%s: missing 'id'" % path)
		return
	if id != path.get_file().get_basename():
		errors.append("%s: id '%s' must match file name" % [path, id])
	if target.has(id):
		errors.append("%s: duplicate %s id '%s' (also in %s)" % [path, kind, id, sources.get(kind + ":" + id, "?")])
		return
	target[id] = record
	sources[kind + ":" + id] = path


func _load_flags(path: String) -> void:
	var data: Variant = JsonUtil.load_file(path, errors)
	if not data is Dictionary:
		if data != null:
			errors.append("%s: top level must be an object" % path)
		return
	var root: Dictionary = data
	var entries: Variant = root.get("flags", {})
	if not entries is Dictionary:
		errors.append("%s: 'flags' must be an object" % path)
		return
	flags = entries
