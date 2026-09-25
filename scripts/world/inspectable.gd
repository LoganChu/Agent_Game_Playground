class_name Inspectable
extends Interactable
## A thing in the world that starts a dialogue when examined (a beacon, a shrine, a
## notice board). Region data: `objects: [{id, prompt, dialogue, position, reach?, if?}]`.
## It has no visuals of its own — place a prop at the same spot.

var object_id := ""
var dialogue_id := ""


func setup(data: Dictionary) -> void:
	object_id = str(data.get("id", ""))
	dialogue_id = str(data.get("dialogue", ""))
	prompt = str(data.get("prompt", "Examine"))
	reach = float(data.get("reach", reach))
	position = JsonUtil.to_vector3(data.get("position"))
	name = "Object_" + object_id


func _ready() -> void:
	super._ready()
	add_to_group("inspectables")


func interact() -> void:
	GameState.dialogue_requested.emit(dialogue_id, "")
