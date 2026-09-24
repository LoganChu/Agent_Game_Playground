extends Node
## Autoload "GameState": the current playthrough (world state + where the player is).

## Emitted when the world should (re)build the current region, e.g. after load or an exit.
signal region_change_requested(region_id: String, spawn: String)
## Emitted for player-facing notifications ("Quest started: ...").
signal toast(text: String)
## Emitted by NPCs/triggers; the dialogue UI listens and runs the conversation.
signal dialogue_requested(dialogue_id: String, npc_id: String)

## True while a modal UI (dialogue, menus) owns input; the player stops moving.
var input_locked := false

var world := WorldState.new()
var region_id := ""
var spawn_point := "default"
## Set by SaveSystem on load so the world can restore an exact position.
var pending_player_position: Variant = null


func _ready() -> void:
	InputSetup.ensure_actions()
	world.quest_changed.connect(_on_quest_changed)
	world.inventory_changed.connect(_on_inventory_changed)


func new_game() -> void:
	world.load_dict({})
	for flag_id: String in Content.db.flags:
		world.flags[flag_id] = Content.db.flag_default(flag_id)
	region_id = str(Content.db.game.get("start_region", ""))
	spawn_point = str(Content.db.game.get("start_spawn", "default"))
	pending_player_position = null


func travel(to_region: String, spawn: String = "default") -> void:
	region_id = to_region
	spawn_point = spawn
	pending_player_position = null
	region_change_requested.emit(region_id, spawn_point)


func _on_quest_changed(id: String, state: String, _stage: String) -> void:
	var title := str(Content.db.get_quest(id).get("title", id))
	match state:
		WorldState.QUEST_ACTIVE:
			if world.quest_stage(id) == _first_stage(id):
				toast.emit("Quest started: " + title)
			else:
				toast.emit("Quest updated: " + title)
		WorldState.QUEST_DONE:
			toast.emit("Quest complete: " + title)


func _on_inventory_changed(item_id: String, count: int) -> void:
	var item_name := str(Content.db.get_item(item_id).get("name", item_id))
	toast.emit("%s (%d)" % [item_name, count])


func _first_stage(quest_id: String) -> String:
	var stages: Array = Content.db.get_quest(quest_id).get("stages", [])
	return str((stages[0] as Dictionary).get("id", "")) if not stages.is_empty() else ""
