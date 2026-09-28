class_name Region
extends Node3D
## Builds a region from its JSON data: sculpted ground (or legacy terrain slabs), water,
## props, NPCs, pickups, inspectable objects, exits.
## With `ground`, every position's y is an offset above the ground surface (props may opt
## out with `"snap": false`). See docs/TECH.md "Region format" and "Ground".

## Region data key per content kind.
const KINDS := {"prop": "props", "npc": "npcs", "pickup": "pickups", "object": "objects"}

var region_id := ""
var data: Dictionary = {}
## The sculpted ground, or null for a legacy slab-only region.
var field: TerrainField = null
## Content with an `if` condition, re-evaluated live: [{kind, data, node}] where kind is
## prop | npc | pickup | object and node is the built node, or null while hidden.
var _conditional: Array[Dictionary] = []


func build(id: String) -> void:
	region_id = id
	data = Content.db.get_region(id)
	name = "Region_" + id
	add_to_group("region")
	if data.has("ground"):
		field = TerrainField.from_data(data["ground"], float(data.get("water_level", -INF)))
		add_child(TerrainBuilder.build(field))
	for slab: Dictionary in data.get("terrain", []):
		add_child(_build_slab(slab))
	if data.has("water_level"):
		add_child(_build_water(float(data["water_level"])))
	for kind: String in KINDS:
		for entry: Dictionary in data.get(KINDS[kind], []):
			if entry.has("if") or kind == "pickup":
				# Pickups also disappear once collected, so they're always tracked.
				_conditional.append({"kind": kind, "data": entry, "node": null})
			else:
				add_child(_build(kind, entry))
	refresh_conditional()
	for exit_data: Dictionary in data.get("exits", []):
		var exit := RegionExit.new()
		exit.setup(exit_data)
		exit.position = place(exit_data.get("position"))
		add_child(exit)


## Adds/removes content whose `if` condition changed (and collected pickups). Safe to call
## any time (e.g. when a flag changes mid-visit); unconditional content is never touched.
func refresh_conditional() -> void:
	var world := GameState.world
	for entry: Dictionary in _conditional:
		var entry_data: Dictionary = entry["data"]
		var want := Conditions.evaluate(entry_data.get("if"), world)
		if entry["kind"] == "pickup" and world.is_collected(str(entry_data.get("id", ""))):
			want = false
		var node: Node3D = entry["node"] if is_instance_valid(entry["node"]) else null
		if node != null and node.is_queued_for_deletion():
			node = null
		if want and node == null:
			node = _build(entry["kind"], entry_data)
			if node:
				add_child(node)
		elif not want and node != null:
			node.queue_free()
			node = null
		entry["node"] = node


## Number of conditional props currently shown, optionally only those of `shape` (for tests).
func shown_conditional_props(shape: String = "") -> int:
	var shown := 0
	for entry: Dictionary in _conditional:
		if shape and str(entry["data"].get("shape", "")) != shape:
			continue
		if entry["kind"] == "prop" and is_instance_valid(entry["node"]):
			shown += 1
	return shown


func _build(kind: String, entry: Dictionary) -> Node3D:
	match kind:
		"prop":
			return _build_prop(entry)
		"npc":
			var npc_id := str(entry.get("npc", ""))
			var actor := NpcActor.new()
			actor.setup(npc_id, Content.db.get_npc(npc_id))
			actor.position = place(entry.get("position"))
			actor.rotation_degrees.y = float(entry.get("rotation_y", 0.0))
			return actor
		"pickup":
			var pickup := Pickup.new()
			pickup.setup(entry)
			pickup.position = place(entry.get("position"))
			return pickup
		"object":
			var object := Inspectable.new()
			object.setup(entry)
			object.position = place(entry.get("position"))
			return object
	return null


func spawn_position(spawn: String) -> Vector3:
	var spawns: Dictionary = data.get("spawn_points", {})
	return place(spawns.get(spawn, spawns.get("default", [0, 1, 0])))


## Height the player stands at over x/z — the ground or a pier deck (0 for a legacy slab
## region).
func ground_y(x: float, z: float) -> float:
	return field.surface_at(x, z) if field else 0.0


## Converts a data position to a local one: with sculpted ground, y is added to the ground
## (or pier deck) height beneath it unless `snap` is false.
func place(value: Variant, snap: bool = true) -> Vector3:
	var pos := JsonUtil.to_vector3(value)
	if field and snap:
		pos.y += field.surface_at(pos.x, pos.z)
	return pos


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
			if prop.has("light"):
				node.add_child(build_light(prop["light"]))
	if node == null:
		node = PropFactory.build(str(prop.get("shape", "crate")), str(prop.get("color", "")), float(prop.get("scale", 1.0)))
	node.position = place(prop.get("position"), bool(prop.get("snap", true)))
	node.rotation_degrees.y = float(prop.get("rotation_y", 0.0))
	return node


## An OmniLight3D from a prop's `light` field: {color, energy, range, offset}. Only model
## props use it — procedural shapes (signal_lantern, beacon_light) build their own light.
static func build_light(spec: Dictionary) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "PropLight"
	light.light_color = PropFactory.color(str(spec.get("color", "kindle")))
	light.light_energy = float(spec.get("energy", 1.0))
	light.omni_range = float(spec.get("range", 6.0))
	light.position = JsonUtil.to_vector3(spec.get("offset", [0, 0, 0]))
	return light


func _box_collider(size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
	return body
