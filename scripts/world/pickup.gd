class_name Pickup
extends Interactable
## A collectible item lying in the world. Collected pickups are remembered in WorldState.

var pickup_id := ""
var item_id := ""
var data: Dictionary = {}


func setup(p_data: Dictionary) -> void:
	data = p_data
	pickup_id = str(data.get("id", ""))
	item_id = str(data.get("item", ""))
	name = "Pickup_" + pickup_id
	prompt = "Pick up " + str(Content.db.get_item(item_id).get("name", item_id))
	reach = 1.4


func _ready() -> void:
	super._ready()
	add_to_group("pickups")
	var item := Content.db.get_item(item_id)
	var glow: bool = item.get("kind", "") == "remnant"
	var gem := SphereMesh.new()
	gem.radius = 0.18
	gem.height = 0.3
	gem.radial_segments = 6
	gem.rings = 2
	add_child(PropFactory.mesh_instance(gem, PropFactory.color(str(item.get("color", "kindle"))), Vector3(0, 0.25, 0), glow))
	if glow:
		var light := OmniLight3D.new()
		light.light_color = PropFactory.color("ember")
		light.omni_range = 3.0
		light.light_energy = 0.8
		light.position = Vector3(0, 0.5, 0)
		add_child(light)


func interact() -> void:
	var world := GameState.world
	world.add_item(item_id, int(data.get("count", 1)))
	var sets: Dictionary = data.get("set", {})
	for flag_id: String in sets:
		world.set_flag(flag_id, sets[flag_id])
	if data.has("quest_stage"):
		var pair: Array = data["quest_stage"]
		world.set_quest_stage(str(pair[0]), str(pair[1]))
	world.mark_collected(pickup_id)
	queue_free()
