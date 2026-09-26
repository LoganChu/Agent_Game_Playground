class_name NpcActor
extends Interactable
## An NPC placed in a region. Visuals are the NPC's Blender-made character model (`model`,
## animated by a CharacterRig in its `idle` style), or a primitive figure tinted by the NPC's
## signature color when it has none; talking starts the NPC's dialogue.

var npc_id := ""
var npc_data: Dictionary = {}


func setup(id: String, data: Dictionary) -> void:
	npc_id = id
	npc_data = data
	name = "Npc_" + id
	prompt = "Talk to " + str(data.get("name", id))


func _ready() -> void:
	super._ready()
	add_to_group("npcs")
	_build_body()


func interact() -> void:
	GameState.dialogue_requested.emit(str(npc_data.get("dialogue", "")), npc_id)


func _build_body() -> void:
	var tint := PropFactory.color(str(npc_data.get("color", "slate")))
	var body := StaticBody3D.new()
	body.name = "Body"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.85, 0)
	body.add_child(shape)
	var model := CharacterRig.instantiate(str(npc_data.get("model", "")), str(npc_data.get("idle", "breathe")))
	if model:
		model.name = "Model"
		body.add_child(model)
	else:
		body.add_child(PropFactory.mesh_instance(PropFactory.cylinder(0.25, 0.42, 1.0, 6), tint, Vector3(0, 0.5, 0)))
		var head := SphereMesh.new()
		head.radius = 0.3
		head.height = 0.6
		head.radial_segments = 8
		head.rings = 4
		body.add_child(PropFactory.mesh_instance(head, PropFactory.color("kindle").darkened(0.15), Vector3(0, 1.3, 0)))
	add_child(body)
	var label := Label3D.new()
	label.text = str(npc_data.get("name", npc_id))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.0, 0)
	label.font_size = 40
	label.outline_size = 8
	label.modulate = PropFactory.color("bone")
	add_child(label)
