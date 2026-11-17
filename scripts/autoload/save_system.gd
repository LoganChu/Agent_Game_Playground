extends Node
## Autoload "SaveSystem": JSON save files in user://saves/.
##
## A quicksave slot (F5/F9), three manual slots (pause menu) and an autosave slot (Day 106:
## written quietly by `Autosaver` on travel and story progress, and before Return to title or
## Quit).
##
## Day 109: saves carry the play time and the story's id (GameState.play_seconds/playthrough);
## older saves are upgraded on read by SaveMigrations; the autosave keeps one slot per story
## (another story's autosave is moved to PREV_AUTO_SLOT rather than overwritten); and each save
## has a small thumbnail (`<slot>.png`) shown on the Load page.

signal saved(slot: String)
signal loaded(slot: String)

const SAVE_VERSION := 2
const SAVE_DIR := "user://saves"

## Manual slots offered by the pause menu, in order (the quicksave is "quick").
const SLOTS: Array[String] = ["slot1", "slot2", "slot3"]
const QUICK_SLOT := "quick"
## Written only by the game (Autosaver, leaving for the title or the desktop), never offered on the Save page.
const AUTO_SLOT := "auto"
## The autosave of the story before this one (Day 109): a New game's first autosave moves the
## old story's autosave here instead of overwriting it. Only ever written by that move.
const PREV_AUTO_SLOT := "auto_prev"
## Every slot the Load page and the title's Continue look at, in the order they are listed.
const LOADABLE: Array[String] = ["auto", "auto_prev", "quick", "slot1", "slot2", "slot3"]
## The thumbnail's size in pixels (16:9), and how wide the Load page shows it.
const THUMB_SIZE := Vector2i(320, 180)
const THUMB_SHOWN_WIDTH := 128

## Nodes in this group provide the player's position: `get_save_position() -> Vector3`.
const PLAYER_GROUP := "player"

## Where saves go; the smoke test points this elsewhere so it never touches real saves.
var save_dir := SAVE_DIR
## A frame grabbed when a menu or card opened over the world (snap_thumbnail), used by saves
## made from it so the thumbnail shows the world, not the menu.
var _snap: Image = null


func slot_path(slot: String) -> String:
	return save_dir.path_join(slot + ".json")


func thumb_path(slot: String) -> String:
	return save_dir.path_join(slot + ".png")


func has_save(slot: String = QUICK_SLOT) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Player-facing slot name: "Quicksave" or "Slot 1".
static func slot_label(slot: String) -> String:
	if slot == QUICK_SLOT:
		return "Quicksave"
	if slot == AUTO_SLOT:
		return "Autosave"
	if slot == PREV_AUTO_SLOT:
		return "Autosave (earlier story)"
	if slot.begins_with("slot"):
		return "Slot " + slot.substr(4)
	return slot.capitalize()


## Reads a slot and upgrades it to SAVE_VERSION: SaveMigrations.migrate's result, or
## {ok: false, error} if the file is missing or isn't a save.
func read_slot(slot: String) -> Dictionary:
	if not has_save(slot):
		return {"ok": false, "data": {}, "from": 0, "error": "empty"}
	var errs: Array[String] = []
	var data: Variant = JsonUtil.load_file(slot_path(slot), errs)
	if not data is Dictionary:
		return {"ok": false, "data": {}, "from": 0, "error": "unreadable"}
	return SaveMigrations.migrate(data, SAVE_VERSION)


## What a slot holds, for menus: {} if empty or unreadable; {refused: why} for a save this
## build can't load (a newer version); else {region, region_name, saved_at ("2026-10-01 09:12",
## UTC), saved_at_full (with seconds), saved_unix (sub-second; 0 for saves before Day 110), play_seconds,
## playthrough}.
func slot_info(slot: String) -> Dictionary:
	var read := read_slot(slot)
	if not read["ok"]:
		return {"refused": read["error"]} if int(read["from"]) > SAVE_VERSION else {}
	var data: Dictionary = read["data"]
	var region := str(data.get("region", ""))
	var stamp := str(data.get("saved_at", "")).replace("T", " ")
	return {
		"region": region,
		"region_name": str(Content.db.regions.get(region, {}).get("name", region)),
		"saved_at": stamp.substr(0, 16),
		"saved_at_full": stamp,
		"saved_unix": float(data.get("saved_unix", 0.0)),
		"play_seconds": float(data.get("play_seconds", 0.0)),
		"playthrough": str(data.get("playthrough", "")),
	}


## Play time for menus: "3h 12m", "47m", "under a minute"; "" when not known (0 — a save from
## before Day 109 counted nothing).
static func format_play_time(seconds: float) -> String:
	if seconds <= 0.0:
		return ""
	var minutes := int(seconds / 60.0)
	if minutes < 1:
		return "under a minute"
	if minutes < 60:
		return "%dm" % minutes
	return "%dh %02dm" % [minutes / 60, minutes % 60]


## One line describing a slot for the pause menu: "Slot 1 — Saltmarrow · 3h 12m · 2026-10-01 09:12"
## (no play time on a save from before Day 109).
func slot_summary(slot: String) -> String:
	var info := slot_info(slot)
	if info.is_empty():
		return "%s — empty" % slot_label(slot)
	if info.has("refused"):
		return "%s — %s" % [slot_label(slot), info["refused"]]
	var parts: Array[String] = [str(info["region_name"])]
	var played := format_play_time(float(info["play_seconds"]))
	if not played.is_empty():
		parts.append(played)
	parts.append(str(info["saved_at"]))
	return "%s — %s" % [slot_label(slot), " · ".join(parts)]


## The slot's thumbnail, or null if it has none (saved headless, or before Day 109).
func slot_thumbnail(slot: String) -> Texture2D:
	if not has_save(slot) or not FileAccess.file_exists(thumb_path(slot)):
		return null
	var image := Image.load_from_file(thumb_path(slot))
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


## Grabs the frame on screen now for the next saves' thumbnails. Menus and cards call it as
## they open, before they draw over the world.
func snap_thumbnail() -> void:
	_snap = capture_thumbnail()


## The current frame scaled to THUMB_SIZE, or null where nothing is rendered (headless runs).
func capture_thumbnail() -> Image:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return null
	var texture := get_viewport().get_texture()
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null or image.is_empty():
		return null
	image.resize(THUMB_SIZE.x, THUMB_SIZE.y, Image.INTERPOLATE_BILINEAR)
	return image


## The slot saved most recently (quicksave and autosave included), or "" if there are no
## saves. For the title screen's Continue.
func latest_slot() -> String:
	var best := ""
	var best_stamp := ""
	for slot: String in LOADABLE:
		var info := slot_info(slot)
		if info.is_empty() or info.has("refused"):
			continue
		# ISO stamps sort as strings. Two saves in the same second (the smoke walk, a save then Return to title)
		# are told apart by the sub-second Unix time (Day 110); the file's modified time, whole seconds too, is
		# the last resort for older saves.
		var stamp := "%s|%020.4f|%012d" % [info["saved_at_full"], float(info["saved_unix"]),
				FileAccess.get_modified_time(slot_path(slot))]
		if stamp > best_stamp:
			best = slot
			best_stamp = stamp
	return best


func build_save_data() -> Dictionary:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"saved_unix": Time.get_unix_time_from_system(),
		"region": GameState.region_id,
		"spawn": GameState.spawn_point,
		"world": GameState.world.to_dict(),
		"play_seconds": snappedf(GameState.play_seconds, 0.1),
		"playthrough": GameState.playthrough,
	}
	var player := get_tree().get_first_node_in_group(PLAYER_GROUP) if is_inside_tree() else null
	if player is Node3D:
		data["player_position"] = JsonUtil.from_vector3((player as Node3D).global_position)
	return data


## Whether the game may write the autosave: the setting is on and this isn't a developer jump
## (a checkpoint or debug state — GameState.dev_session), which would overwrite the player's
## real progress with a test state.
func autosave_allowed() -> bool:
	return GameSettings.current().autosave and not GameState.dev_session


## Writes the autosave slot without a toast (the HUD shows a small "Saving…" cue from `saved`).
## Does nothing (false) when autosave isn't allowed. An autosave from another story (or a
## legacy one) is first moved to PREV_AUTO_SLOT, so a New game never eats the old story's
## progress (Day 109). `fresh_thumbnail` grabs the frame now (the Autosaver at a quiet moment);
## otherwise the frame snapped when the open menu or card appeared is used.
func autosave(fresh_thumbnail: bool = false) -> bool:
	if not autosave_allowed() or GameState.region_id.is_empty():
		return false
	_keep_other_story_autosave()
	return save_game(AUTO_SLOT, fresh_thumbnail)


func _keep_other_story_autosave() -> void:
	var info := slot_info(AUTO_SLOT)
	if info.is_empty() or info.has("refused"):
		return
	var theirs := str(info["playthrough"])
	if not theirs.is_empty() and theirs == GameState.playthrough:
		return
	_move_slot(AUTO_SLOT, PREV_AUTO_SLOT)


func _move_slot(from_slot: String, to_slot: String) -> void:
	DirAccess.remove_absolute(slot_path(to_slot))
	DirAccess.remove_absolute(thumb_path(to_slot))
	DirAccess.rename_absolute(slot_path(from_slot), slot_path(to_slot))
	if FileAccess.file_exists(thumb_path(from_slot)):
		DirAccess.rename_absolute(thumb_path(from_slot), thumb_path(to_slot))


## Writes a slot (and its thumbnail: the frame snapped when a menu opened, or the frame now
## with `fresh_thumbnail` or when nothing was snapped).
func save_game(slot: String = QUICK_SLOT, fresh_thumbnail: bool = false) -> bool:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Could not write save '%s': %s" % [slot, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(build_save_data(), "\t"))
	file.close()
	var thumb := capture_thumbnail() if fresh_thumbnail or _snap == null else _snap
	if thumb == null or thumb.save_png(thumb_path(slot)) != OK:
		# Never leave an older save's picture beside a newer save.
		DirAccess.remove_absolute(thumb_path(slot))
	saved.emit(slot)
	if slot != AUTO_SLOT:
		GameState.toast.emit("Game saved" if slot == QUICK_SLOT else "Saved to " + slot_label(slot))
	return true


func load_game(slot: String = QUICK_SLOT) -> bool:
	var read := read_slot(slot)
	if not read["ok"]:
		push_warning("Can't load save '%s': %s" % [slot, read["error"]])
		return false
	var save: Dictionary = read["data"]
	var region := str(save.get("region", ""))
	if not Content.db.regions.has(region):
		push_warning("Save '%s' references unknown region '%s'" % [slot, region])
		return false
	GameState.dev_session = false
	GameState.world.load_dict(save.get("world", {}))
	GameState.play_seconds = float(save.get("play_seconds", 0.0))
	GameState.playthrough = str(save.get("playthrough", ""))
	if GameState.playthrough.is_empty():
		# A save from before Day 109: its story gets an id now, so its autosaves stay one slot.
		GameState.playthrough = GameState.new_playthrough_id()
	GameState.region_id = region
	GameState.spawn_point = str(save.get("spawn", "default"))
	GameState.pending_player_position = JsonUtil.to_vector3(save["player_position"]) if save.has("player_position") else null
	GameState.region_change_requested.emit(region, GameState.spawn_point)
	loaded.emit(slot)
	GameState.toast.emit("Game loaded")
	return true
