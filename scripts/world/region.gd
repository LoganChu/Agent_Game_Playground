class_name Region
extends Node3D
## Builds a region from its JSON data: sculpted ground (or legacy terrain slabs), water,
## props, NPCs, pickups, inspectable objects, exits, and Greying fog areas.
## With `ground`, every position's y is an offset above the ground surface (props may opt
## out with `"snap": false`). See docs/TECH.md "Region format" and "Ground".

## Models shorter than this get no camera blocker (see `camera_blocker`).
const CAMERA_BLOCK_MIN_HEIGHT := 2.4
## Region data key per content kind.
const KINDS := {"prop": "props", "npc": "npcs", "pickup": "pickups", "object": "objects"}

var region_id := ""
var data: Dictionary = {}
## The sculpted ground, or null for a legacy slab-only region.
var field: TerrainField = null
## The built ground (recoloured when conditional paint changes).
var _terrain: StaticBody3D = null
## Content with an `if` condition, re-evaluated live: [{kind, data, node}] where kind is
## prop | npc | pickup | object and node is the built node, or null while hidden.
var _conditional: Array[Dictionary] = []
## Greying areas whose `if` currently holds (see Greying); drives the ember drain.
var greying_areas: Array[Dictionary] = []
## Shown fog per area index in data.greying: index -> GreyingFog.
var _greying_fog: Dictionary = {}
## Clear areas (lantern light) the shown fog was last cut around.
var _greying_clears: Array[Dictionary] = []


func build(id: String) -> void:
	region_id = id
	data = Content.db.get_region(id)
	name = "Region_" + id
	add_to_group("region")
	if data.has("ground"):
		field = TerrainField.from_data(data["ground"], float(data.get("water_level", -INF)))
		field.select_paint(GameState.world)
		_terrain = TerrainBuilder.build(field)
		add_child(_terrain)
	for slab: Dictionary in data.get("terrain", []):
		add_child(_build_slab(slab))
	if data.has("water_level"):
		add_child(WaterBuilder.build(field, float(data["water_level"]), data.get("water", {})))
	for kind: String in KINDS:
		for entry: Dictionary in data.get(KINDS[kind], []):
			if entry.has("if") or kind == "pickup":
				# Pickups also disappear once collected, so they're always tracked.
				_conditional.append({"kind": kind, "data": entry, "node": null})
			else:
				add_child(_build(kind, entry))
	refresh_conditional(false)
	for exit_data: Dictionary in data.get("exits", []):
		var exit := RegionExit.new()
		exit.setup(exit_data)
		exit.position = place(exit_data.get("position"))
		add_child(exit)


## Adds/removes content whose `if` condition changed (and collected pickups). Safe to call
## any time (e.g. when a flag changes mid-visit); unconditional content is never touched.
## Greying areas that come or go fade over a few seconds when `animate`.
func refresh_conditional(animate: bool = true) -> void:
	var world := GameState.world
	_refresh_greying(world, animate)
	if field and _terrain and field.has_conditional_paint() and field.select_paint(world):
		TerrainBuilder.recolor(_terrain, field)
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


func _refresh_greying(world: WorldState, animate: bool) -> void:
	greying_areas = Greying.active_areas(data, world)
	var clears := Greying.clear_areas(greying_areas)
	if clears != _greying_clears:
		# The light changed: re-cut every shown fog layer around the new pools (dissolving
		# from the old cut when `animate`).
		var before := _greying_clears
		_greying_clears = clears
		for fog: GreyingFog in _greying_fog.values():
			fog.recut(clears, before, animate)
	var areas: Array = data.get("greying", [])
	for i in areas.size():
		var want := greying_areas.has(areas[i]) and not Greying.is_clear(areas[i])
		var fog: GreyingFog = _greying_fog.get(i)
		if want and fog == null:
			fog = GreyingFog.new()
			fog.setup(areas[i], fog_surface, clears)
			add_child(fog)
			if animate:
				fog.fade(true)
			_greying_fog[i] = fog
		elif not want and fog != null:
			if animate:
				fog.fade(false)
			else:
				fog.queue_free()
			_greying_fog.erase(i)


## Fog depth (0..1) of the Greying at x/z right now.
func greying_depth(x: float, z: float) -> float:
	return Greying.depth_at(greying_areas, Vector2(x, z))


## Height the Greying lies on at x/z: the ground, or the water where the ground is below it.
func fog_surface(x: float, z: float) -> float:
	return maxf(ground_y(x, z), float(data.get("water_level", -INF)))


## Number of Greying fog areas currently shown (for tests).
func shown_greying() -> int:
	return _greying_fog.size()


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
			actor.setup(npc_id, placed_npc_data(Content.db.get_npc(npc_id), entry))
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


## An NPC's data as placed by `entry`: a placement's own `model` and `idle` (a pose for that
## spot, e.g. Hob seated on the camp bench) override the NPC's.
static func placed_npc_data(npc: Dictionary, entry: Dictionary) -> Dictionary:
	var data := npc.duplicate()
	for key: String in ["model", "idle"]:
		if entry.has(key):
			data[key] = entry[key]
	return data


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


func _build_prop(prop: Dictionary) -> Node3D:
	var node: Node3D
	var model := str(prop.get("model", ""))
	if not model.is_empty() and ResourceLoader.exists(model):
		if prop.has("idle"):
			# A figure: a character model as set dressing (an Unmoored sitting by a pool), no
			# dialogue, moved by a CharacterRig in its `idle` style.
			node = CharacterRig.instantiate(model, str(prop["idle"]))
			if node and prop.get("averts") is Dictionary:
				# Won't look at the player while the condition holds (a bare ember in the fen).
				var rig := node.get_node("CharacterRig") as CharacterRig
				rig.avert_if = prop["averts"].get("if")
				rig.avert_radius = float(prop["averts"].get("radius", CharacterRig.AVERT_RADIUS))
		else:
			var scene := load(model) as PackedScene
			node = scene.instantiate() as Node3D if scene else null
		if node:
			node.scale = Vector3.ONE * float(prop.get("scale", 1.0))
			if prop.has("collider"):
				node.add_child(_box_collider(JsonUtil.to_vector3(prop["collider"])))
			for extra: Dictionary in prop.get("colliders", []):
				node.add_child(_box_collider(JsonUtil.to_vector3(extra["size"]), JsonUtil.to_vector3(extra.get("offset", [0, 0, 0]))))
			if prop.has("collider"):
				var blocker := camera_blocker(node, JsonUtil.to_vector3(prop["collider"]).y)
				if blocker:
					node.add_child(blocker)
			if prop.has("light"):
				node.add_child(build_light(prop["light"]))
			if prop.get("smoke") is Array:
				node.add_child(PropSmoke.build(prop["smoke"]))
			if prop.get("halo") is Array:
				node.add_child(LanternHalo.build(JsonUtil.to_vector3(prop["halo"]), float(prop.get("halo_size", LanternHalo.SIZE)),
					float(prop.get("halo_strength", LanternHalo.STRENGTH)), float(prop.get("halo_bloom", 0.0))))
			if prop.get("float") is Dictionary:
				node = FloatingProp.wrap(node, prop["float"], float(prop.get("scale", 1.0)))
	if node == null:
		node = PropFactory.build(str(prop.get("shape", "crate")), str(prop.get("color", "")), float(prop.get("scale", 1.0)))
	node.position = place(prop.get("position"), bool(prop.get("snap", true)))
	node.rotation_degrees.y = float(prop.get("rotation_y", 0.0))
	if prop.get("wading") is Array and not node is FloatingProp:
		_add_wading_foam(node, prop["wading"], float(prop.get("scale", 1.0)))
	return node


## Foam rings where a prop's legs stand in the sea (`wading`: [[x, z, radius], ...], model
## space before `scale`). The rings sit level on the water; a leg whose ground is above the
## water (the tide line runs under the house) gets none. Needs sculpted ground and a sea.
func _add_wading_foam(node: Node3D, rings: Array, scale_factor: float) -> void:
	var water := float(data.get("water_level", -INF))
	if field == null or is_inf(water):
		return
	var wet: Array[Vector3] = []
	for ring: Array in rings:
		var world := node.transform * Vector3(float(ring[0]), 0, float(ring[1]))
		if field.height_at(world.x, world.z) < water - 0.02:
			wet.append(Vector3(float(ring[0]), float(ring[2]), float(ring[1])))
	if wet.is_empty():
		return
	var foam := MeshInstance3D.new()
	foam.name = "WadingFoam"
	foam.mesh = FloatingProp.wading_mesh(wet)
	foam.material_override = FloatingProp.foam_material()
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam.position.y = (water - node.position.y + 0.03) / scale_factor
	node.add_child(foam)


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


## A camera-only box over a solid model's mesh bounds *above its walk collider* (model
## space, from `collider_top` up), so the orbit camera pulls in before it can pass through
## a roof, an eave or a canopy that the walk collider doesn't cover. Starting at the
## collider's top keeps the box off the ground, so it never swallows the camera's pivot
## when the player stands under the eaves. Only for models at least
## CAMERA_BLOCK_MIN_HEIGHT tall with something above the collider. Null otherwise.
static func camera_blocker(model: Node3D, collider_top: float) -> StaticBody3D:
	var bounds := mesh_bounds(model)
	if bounds.size.y < CAMERA_BLOCK_MIN_HEIGHT or bounds.end.y - collider_top < 0.2:
		return null
	var bottom := maxf(bounds.position.y, collider_top)
	bounds = AABB(Vector3(bounds.position.x, bottom, bounds.position.z), Vector3(bounds.size.x, bounds.end.y - bottom, bounds.size.z))
	var body := StaticBody3D.new()
	body.name = "CameraBlocker"
	body.collision_layer = 0
	body.set_collision_layer_value(Layers.CAMERA, true)
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bounds.size
	shape.shape = box
	shape.position = bounds.get_center()
	body.add_child(shape)
	return body


## Merged AABB of every mesh under `root`, in `root`'s own space (ignoring its transform).
static func mesh_bounds(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var xf: Transform3D = item[1]
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var box := xf * (node as MeshInstance3D).mesh.get_aabb()
			out = box if first else out.merge(box)
			first = false
		for child in node.get_children():
			if child is Node3D:
				stack.append([child, xf * (child as Node3D).transform])
	return out


## A box collider standing on the model's origin (+ `offset`, model space; y lifts the base).
func _box_collider(size: Vector3, offset := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset + Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)
	return body
