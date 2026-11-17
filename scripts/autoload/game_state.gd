extends Node
## Autoload "GameState": the current playthrough (world state + where the player is).

## Emitted when the world should (re)build the current region, e.g. after load or an exit.
signal region_change_requested(region_id: String, spawn: String)
## Emitted for player-facing notifications ("Quest started: ...").
signal toast(text: String)
## Emitted by NPCs/triggers; the dialogue UI listens and runs the conversation.
signal dialogue_requested(dialogue_id: String, npc_id: String)
## Emitted when the player swaps between keyboard/mouse and a pad (InputSetup.pad_last), so
## every prompt can re-label itself.
signal input_device_changed

## True while a modal UI (dialogue, menus) owns input; the player stops moving.
var input_locked := false

var world := WorldState.new()
var region_id := ""
var spawn_point := "default"
## Set by SaveSystem on load so the world can restore an exact position.
var pending_player_position: Variant = null
## True while a checkpoint is being applied: its quests start and finish silently (Day 104 — the toast stack used to
## fill the screen with "Quest started/complete" for every quest a late checkpoint set).
var _quiet := false
## True after a developer jump (a checkpoint, Chapter select, --flags/--quest/--region): the
## world is a test state, so it is never autosaved (Day 106). A new game or a loaded save clears it.
var dev_session := false
## Seconds of play in this story (Day 109): counted by main while a region is up, the title is
## closed and the tree isn't paused (menus pause it). Saved and restored with the game.
var play_seconds := 0.0
## Names the story a New game began (Day 109), so the autosave keeps one slot per story
## (SaveSystem.autosave moves another story's autosave aside). "" = unknown (a legacy save).
var playthrough := ""


func _ready() -> void:
	InputSetup.ensure_actions()
	# Loads user://settings.cfg and applies it (volumes, text size, rebound keys).
	GameSettings.current()
	world.quest_changed.connect(_on_quest_changed)
	world.inventory_changed.connect(_on_inventory_changed)
	# Before any node's _input, so a modal that handles the event still sees the swap.
	get_tree().root.window_input.connect(note_input)


## Notes which device an input event came from (InputSetup.note_device), announcing a swap.
func note_input(event: InputEvent) -> void:
	if InputSetup.note_device(event):
		input_device_changed.emit()


func new_game() -> void:
	dev_session = false
	play_seconds = 0.0
	playthrough = new_playthrough_id()
	world.load_dict({})
	for flag_id: String in Content.db.flags:
		world.flags[flag_id] = Content.db.flag_default(flag_id)
	region_id = str(Content.db.game.get("start_region", ""))
	spawn_point = str(Content.db.game.get("start_spawn", "default"))
	pending_player_position = null


## A fresh story id: the start time and a random tail, as hex ("19a2c3f4e5-7b2e91").
static func new_playthrough_id() -> String:
	return "%x-%06x" % [int(Time.get_unix_time_from_system()), randi() % 0x1000000]


## Developer checkpoint (data/scenarios.json): resets the world to that point in the story
## and loads its region. A checkpoint before the waking narration replays it.
func start_scenario(id: String) -> bool:
	var scenario := Scenarios.resolve(id)
	if scenario.is_empty():
		push_warning("Unknown scenario '%s'" % id)
		return false
	apply_scenario(scenario)
	travel(str(scenario["region"]), str(scenario.get("spawn", "default")))
	var intro := str(Content.db.game.get("intro_dialogue", ""))
	if not world.get_flag("intro_seen") and not intro.is_empty():
		dialogue_requested.emit.call_deferred(intro, "")
	toast.emit("Checkpoint: " + str(scenario["title"]))
	return true


## Applies a resolved checkpoint to the world without a toast per quest or item.
func apply_scenario(scenario: Dictionary) -> void:
	dev_session = true
	_quiet = true
	Scenarios.apply(Content.db, world, scenario)
	_quiet = false


func travel(to_region: String, spawn: String = "default") -> void:
	region_id = to_region
	spawn_point = spawn
	pending_player_position = null
	region_change_requested.emit(region_id, spawn_point)


func _on_quest_changed(id: String, state: String, _stage: String) -> void:
	if _quiet:
		return
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
	if _quiet:
		return
	var item_name := str(Content.db.get_item(item_id).get("name", item_id))
	toast.emit("%s (%d)" % [item_name, count])


func _first_stage(quest_id: String) -> String:
	var stages: Array = Content.db.get_quest(quest_id).get("stages", [])
	return str((stages[0] as Dictionary).get("id", "")) if not stages.is_empty() else ""
