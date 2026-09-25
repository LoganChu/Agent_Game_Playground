class_name Region
extends Node3D
## Builds a region from its JSON data: terrain slabs, water, props, NPCs, pickups,
## inspectable objects, exits.
## See docs/TECH.md "Region format".

var region_id := ""
var data: Dictionary = {}
## Props with an `if` condition: index in data.props -> built node (or null while hidden).
var _conditional_props: Dictionary = {}


func build(id: String) -> void:
	region_id = id
	data = Content.db.get_region(id)
	name = "Region_" + id
	add_to_group("region")
	for slab: Dictionary in data.get("terrain", []):
		add_child(_build_slab(slab))
	if data.has("water_level"):
		add_child(_build_water(float(data["water_level"])))
	var props: Array = data.get("props", [])
	for i in props.size():
		var prop: Dictionary = props[i]
		if prop.has("if"):
			_conditional_props[i] = null
			continue
		var node := _build_prop(prop)
		if node:
			add_child(node)
	refresh_conditional_props()
	var world := GameState.world
	for placement: Dictionary in data.get("npcs", []):
		if not Conditions.evaluate(placement.get("if"), world):
			continue
		var npc_id := str(placement.get("npc", ""))
		var actor := NpcActor.new()
		actor.setup(npc_id, Content.db.get_npc(npc_id))
		actor.position = JsonUtil.to_vector3(placement.get("position"))
		actor.rotation_degrees.y = float(placement.get("rotation_y", 0.0))
		add_child(actor)
	for pickup_data: Dictionary in data.get("pickups", []):
		if world.is_collected(str(pickup_data.get("id", ""))):
			continue
		if not Conditions.evaluate(pickup_data.get("if"), world):
			continue
		var pickup := Pickup.new()
		pickup.setup(pickup_data)
		pickup.position = JsonUtil.to_vector3(pickup_data.get("position"))
		add_child(pickup)
	for object_data: Dictionary in data.get("objects", []):
		if not Conditions.evaluate(object_data.get("if"), world):
			continue
		var object := Inspectable.new()
		object.setup(object_data)
		add_child(object)
	for exit_data: Dictionary in data.get("exits", []):
		var exit := RegionExit.new()
		exit.setup(exit_data)
		add_child(exit)


## Adds/removes props whose `if` condition changed. Safe to call any time (e.g. when a
## flag changes mid-visit); unconditional content is never touched.
func refresh_conditional_props() -> void:
	var props: Array = data.get("props", [])
	for i: int in _conditional_props:
		var prop: Dictionary = props[i]
		var want := Conditions.evaluate(prop.get("if"), GameState.world)
		var node: Node3D = _conditional_props[i]
		if want and node == null:
			node = _build_prop(prop)
			add_child(node)
			_conditional_props[i] = node
		elif not want and node != null:
			node.queue_free()
			_conditional_props[i] = null


## Number of conditional props currently shown (for tests).
func shown_conditional_props() -> int:
	var shown := 0
	for node: Variant in _conditional_props.values():
		if node != null:
			shown += 1
	return shown


func spawn_position(spawn: String) -> Vector3:
	var spawns: Dictionary = data.get("spawn_points", {})
	return JsonUtil.to_vector3(spawns.get(spawn, spawns.get("default", [0, 1, 0])))


func _build_slab(slab: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	var size := JsonUtil.to_vector3(slab.get("size", [10, 1, 10]))
	body.position = JsonUtil.to_vector3(slab.get("position"))
	body.rotation_degrees.y = float(slab.get("rotation_y", 0.0))
	# Slabs are positioned by their top surface so data reads as "ground height".
	body.add_child(PropFactory.mesh_instance(PropFactory.box(size), PropFactory.color(str(slab.get("color", "moss"))), Vector3(0, -size.y * 0.5, 0)))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, -size.y * 0.5, 0)
	body.add_child(shape)
	return body


func _build_water(level: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PropFactory.color("tide")
	mat.albedo_color.a = 0.85
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.3
	mi.material_override = mat
	mi.position.y = level
	return mi


func _build_prop(prop: Dictionary) -> Node3D:
	var node: Node3D
	var model := str(prop.get("model", ""))
	if not model.is_empty() and ResourceLoader.exists(model):
		var scene := load(model) as PackedScene
		node = scene.instantiate() as Node3D if scene else null
		if node:
			node.scale = Vector3.ONE * float(prop.get("scale", 1.0))
			if prop.has("collider"):
				node.add_child(_box_collider(JsonUtil.to_vector3(prop["collider"])))
	if node == null:
		node = PropFactory.build(str(prop.get("shape", "crate")), str(prop.get("color", "")), float(prop.get("scale", 1.0)))
	node.position = JsonUtil.to_vector3(prop.get("position"))
	node.rotation_degrees.y = float(prop.get("rotation_y", 0.0))
	return node


func _box_collider(size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
	return body
