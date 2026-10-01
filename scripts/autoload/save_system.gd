extends Node
## Autoload "SaveSystem": JSON save files in user://saves/.
##
## A quicksave slot (F5/F9) plus three manual slots (pause menu). No thumbnails, no
## migration beyond a version check. See ROADMAP for the full save system.

signal saved(slot: String)
signal loaded(slot: String)

const SAVE_VERSION := 1
const SAVE_DIR := "user://saves"

## Manual slots offered by the pause menu, in order (the quicksave is "quick").
const SLOTS: Array[String] = ["slot1", "slot2", "slot3"]
const QUICK_SLOT := "quick"

## Nodes in this group provide the player's position: `get_save_position() -> Vector3`.
const PLAYER_GROUP := "player"

## Where saves go; the smoke test points this elsewhere so it never touches real saves.
var save_dir := SAVE_DIR


func slot_path(slot: String) -> String:
	return save_dir.path_join(slot + ".json")


func has_save(slot: String = QUICK_SLOT) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Player-facing slot name: "Quicksave" or "Slot 1".
static func slot_label(slot: String) -> String:
	if slot == QUICK_SLOT:
		return "Quicksave"
	if slot.begins_with("slot"):
		return "Slot " + slot.substr(4)
	return slot.capitalize()


## What a slot holds, for menus: {} if empty or unreadable, else {region, region_name,
## saved_at ("2026-10-01 09:12", UTC)}.
func slot_info(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var errs: Array[String] = []
	var data: Variant = JsonUtil.load_file(slot_path(slot), errs)
	if not data is Dictionary:
		return {}
	var region := str((data as Dictionary).get("region", ""))
	var stamp := str((data as Dictionary).get("saved_at", "")).replace("T", " ")
	return {
		"region": region,
		"region_name": str(Content.db.regions.get(region, {}).get("name", region)),
		"saved_at": stamp.substr(0, 16),
	}


## One line describing a slot for the pause menu: "Slot 1 — Saltmarrow · 2026-10-01 09:12".
func slot_summary(slot: String) -> String:
	var info := slot_info(slot)
	if info.is_empty():
		return "%s — empty" % slot_label(slot)
	return "%s — %s · %s" % [slot_label(slot), info["region_name"], info["saved_at"]]


func build_save_data() -> Dictionary:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"region": GameState.region_id,
		"spawn": GameState.spawn_point,
		"world": GameState.world.to_dict(),
	}
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) if is_inside_tree() else null
	if player is Node3D:
		data["player_position"] = JsonUtil.from_vector3((player as Node3D).global_position)
	return data


func save_game(slot: String = QUICK_SLOT) -> bool:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Could not write save '%s': %s" % [slot, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(build_save_data(), "\t"))
	file.close()
	saved.emit(slot)
	GameState.toast.emit("Game saved" if slot == QUICK_SLOT else "Saved to " + slot_label(slot))
	return true


func load_game(slot: String = QUICK_SLOT) -> bool:
	var errs: Array[String] = []
	var data: Variant = JsonUtil.load_file(slot_path(slot), errs)
	if not data is Dictionary:
		push_warning("No valid save in slot '%s' %s" % [slot, errs])
		return false
	var save: Dictionary = data
	if int(save.get("version", 0)) != SAVE_VERSION:
		push_warning("Save '%s' has unsupported version %s" % [slot, save.get("version")])
		return false
	var region := str(save.get("region", ""))
	if not Content.db.regions.has(region):
		push_warning("Save '%s' references unknown region '%s'" % [slot, region])
		return false
	GameState.world.load_dict(save.get("world", {}))
	GameState.region_id = region
	GameState.spawn_point = str(save.get("spawn", "default"))
	GameState.pending_player_position = JsonUtil.to_vector3(save["player_position"]) if save.has("player_position") else null
	GameState.region_change_requested.emit(region, GameState.spawn_point)
	loaded.emit(slot)
	GameState.toast.emit("Game loaded")
	return true
