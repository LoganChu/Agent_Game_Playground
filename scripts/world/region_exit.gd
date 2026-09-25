class_name RegionExit
extends Interactable
## A travel point (ferry, path, gate) to another region. An exit with a `requires`
## condition stays visible but refuses passage (showing `locked_text`) until it holds.

var target_region := ""
var target_spawn := "default"
var requires: Variant = null
var locked_text := ""


func setup(data: Dictionary) -> void:
	target_region = str(data.get("to", ""))
	target_spawn = str(data.get("spawn", "default"))
	requires = data.get("requires")
	locked_text = str(data.get("locked_text", "The way is barred."))
	position = JsonUtil.to_vector3(data.get("position"))
	var region_name := str(Content.db.get_region(target_region).get("name", target_region))
	prompt = str(data.get("prompt", "Travel to " + region_name))
	name = "Exit_" + target_region


func _ready() -> void:
	super._ready()
	add_to_group("exits")
	# A lantern post marks every way out of a region.
	add_child(PropFactory.mesh_instance(PropFactory.cylinder(0.07, 0.09, 1.8, 5), PropFactory.color("driftwood"), Vector3(0, 0.9, 0)))
	add_child(PropFactory.mesh_instance(PropFactory.box(Vector3(0.3, 0.35, 0.3)), PropFactory.color("ember"), Vector3(0, 1.9, 0), true))


func is_locked() -> bool:
	return not Conditions.evaluate(requires, GameState.world)


func interact() -> void:
	if is_locked():
		GameState.toast.emit(locked_text)
		return
	GameState.travel(target_region, target_spawn)
