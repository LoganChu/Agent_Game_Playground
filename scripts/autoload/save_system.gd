extends Node
## Autoload "SaveSystem": JSON save files in user://saves/.
##
## Stub for the vertical slice: one quicksave slot, no thumbnails, no migration beyond a
## version check. See ROADMAP for the full save system.

signal saved(slot: String)
signal loaded(slot: String)

const SAVE_VERSION := 1
const SAVE_DIR := "user://saves"

## Nodes in this group provide the player's position: `get_save_position() -> Vector3`.
const PLAYER_GROUP := "player"


func slot_path(slot: String) -> String:
	return SAVE_DIR.path_join(slot + ".json")


func has_save(slot: String = "quick") -> bool:
	return FileAccess.file_exists(slot_path(slot))


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


func save_game(slot: String = "quick") -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Could not write save '%s': %s" % [slot, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(build_save_data(), "\t"))
	file.close()
	saved.emit(slot)
	GameState.toast.emit("Game saved")
	return true


func load_game(slot: String = "quick") -> bool:
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
