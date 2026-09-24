class_name RegionExit
extends Interactable
## A travel point (ferry, path, gate) to another region.

var target_region := ""
var target_spawn := "default"


func setup(data: Dictionary) -> void:
	target_region = str(data.get("to", ""))
	target_spawn = str(data.get("spawn", "default"))
	position = JsonUtil.to_vector3(data.get("position"))
	var region_name := str(Content.db.get_region(target_region).get("name", target_region))
	prompt = str(data.get("prompt", "Travel to " + region_name))
	name = "Exit_" + target_region


func _ready() -> void:
	super._ready()
	# A lantern post marks every way out of a region.
	add_child(PropFactory.mesh_instance(PropFactory.cylinder(0.07, 0.09, 1.8, 5), PropFactory.color("driftwood"), Vector3(0, 0.9, 0)))
	add_child(PropFactory.mesh_instance(PropFactory.box(Vector3(0.3, 0.35, 0.3)), PropFactory.color("ember"), Vector3(0, 1.9, 0), true))


func interact() -> void:
	GameState.travel(target_region, target_spawn)
