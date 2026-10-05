class_name Inspectable
extends Interactable
## A thing in the world that starts a dialogue when examined (a beacon, a shrine, a
## notice board). Region data: `objects: [{id, prompt, dialogue, position, reach?, glint?, if?}]`.
## It has no visuals of its own — place a prop at the same spot — except a faint `Glint` at
## `glint` ([x, y, z] above its spot, default Glint.DEFAULT_OFFSET; `false` for none).

var object_id := ""
var dialogue_id := ""
var glint: Glint = null


func setup(data: Dictionary) -> void:
	object_id = str(data.get("id", ""))
	dialogue_id = str(data.get("dialogue", ""))
	prompt = str(data.get("prompt", "Examine"))
	reach = float(data.get("reach", reach))
	position = JsonUtil.to_vector3(data.get("position"))
	name = "Object_" + object_id
	var spot: Variant = data.get("glint", null)
	if spot != null and not spot is bool:
		glint = Glint.new()
		glint.position = JsonUtil.to_vector3(spot)
	elif spot == null or spot == true:
		glint = Glint.new()
		glint.position = Glint.DEFAULT_OFFSET
	if glint:
		glint.reach = reach
		add_child(glint)


func _ready() -> void:
	super._ready()
	add_to_group("inspectables")


func interact() -> void:
	GameState.dialogue_requested.emit(dialogue_id, "")
