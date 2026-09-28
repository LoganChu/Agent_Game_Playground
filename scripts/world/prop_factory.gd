class_name PropFactory
extends RefCounted
## Builds simple flat-shaded low-poly props from primitives. Used for greyboxing and as a
## fallback when a region prop has no Blender-made model.

const SHAPES: Array[String] = ["pine", "rock", "house", "post", "crate", "beacon", "dock", "beacon_light", "signal_lantern", "stool", "cups", "net_rack", "net_frame"]

## Shapes that carry their own OmniLight3D (a model standing in for one needs a `light`).
const LIT_SHAPES: Array[String] = ["beacon_light", "signal_lantern"]

const PALETTE: Dictionary = {
	"ember": Color("#F2A541"),
	"kindle": Color("#F4D58D"),
	"coal": Color("#B5452F"),
	"moss": Color("#5E8C61"),
	"pine": Color("#2F5D50"),
	"tide": Color("#3D7EA6"),
	"abyss": Color("#1F3A5F"),
	"slate": Color("#6B7280"),
	"driftwood": Color("#C9B28F"),
	"silverfog": Color("#C7CCD4"),
	"ink": Color("#1B1B2F"),
	"bone": Color("#EDE6D6"),
}

static var _materials: Dictionary = {}


## Returns a palette color by name, or parses a hex string.
static func color(name_or_hex: String) -> Color:
	if PALETTE.has(name_or_hex):
		return PALETTE[name_or_hex]
	if Color.html_is_valid(name_or_hex):
		return Color(name_or_hex)
	return PALETTE["slate"]


static func material(c: Color, emissive: bool = false) -> StandardMaterial3D:
	var key := "%s|%s" % [c.to_html(), emissive]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.95
	if emissive:
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 2.0
	_materials[key] = mat
	return mat


## Converts a primitive mesh into a flat-shaded ArrayMesh (faceted low-poly look).
static func flat(mesh: Mesh) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.deindex()
	st.generate_normals()
	return st.commit()


static func mesh_instance(mesh: Mesh, c: Color, offset: Vector3 = Vector3.ZERO, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = flat(mesh)
	mi.material_override = material(c, emissive)
	mi.position = offset
	return mi


static func cylinder(top: float, bottom: float, height: float, sides: int = 6) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return m


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## Builds a prop node for `shape`, scaled by `scale`, with a simple static collider.
static func build(shape: String, tint: String = "", scale: float = 1.0) -> Node3D:
	if shape == "beacon_light":
		return _beacon_light(tint, scale)
	var root := StaticBody3D.new()
	root.name = shape.capitalize()
	var collider_size := Vector3.ONE
	match shape:
		"pine":
			root.add_child(mesh_instance(cylinder(0.12, 0.18, 1.0), color("driftwood"), Vector3(0, 0.5, 0)))
			var leaf := color(tint if tint else "pine")
			root.add_child(mesh_instance(cylinder(0.0, 1.1, 1.6, 7), leaf, Vector3(0, 1.5, 0)))
			root.add_child(mesh_instance(cylinder(0.0, 0.8, 1.3, 7), leaf.lightened(0.08), Vector3(0, 2.3, 0)))
			collider_size = Vector3(0.5, 3.0, 0.5)
		"rock":
			var rock := SphereMesh.new()
			rock.radial_segments = 6
			rock.rings = 3
			rock.radius = 0.8
			rock.height = 1.0
			root.add_child(mesh_instance(rock, color(tint if tint else "slate"), Vector3(0, 0.3, 0)))
			collider_size = Vector3(1.4, 0.8, 1.4)
		"house":
			var wall := color(tint if tint else "driftwood")
			# Stilts
			for x: float in [-1.1, 1.1]:
				for z: float in [-0.9, 0.9]:
					root.add_child(mesh_instance(cylinder(0.08, 0.08, 1.0, 5), color("slate"), Vector3(x, 0.5, z)))
			root.add_child(mesh_instance(box(Vector3(2.6, 1.6, 2.2)), wall, Vector3(0, 1.8, 0)))
			var roof := PrismMesh.new()
			roof.size = Vector3(3.0, 1.1, 2.6)
			var roof_mi := mesh_instance(roof, color("coal"), Vector3(0, 3.15, 0))
			root.add_child(roof_mi)
			root.add_child(mesh_instance(box(Vector3(0.5, 0.5, 0.05)), color("kindle"), Vector3(0.6, 1.9, 1.11), true))
			collider_size = Vector3(2.6, 3.6, 2.2)
		"post":
			root.add_child(mesh_instance(cylinder(0.1, 0.12, 1.4, 5), color(tint if tint else "driftwood"), Vector3(0, 0.7, 0)))
			collider_size = Vector3(0.3, 1.4, 0.3)
		"crate":
			root.add_child(mesh_instance(box(Vector3(0.8, 0.8, 0.8)), color(tint if tint else "driftwood"), Vector3(0, 0.4, 0)))
			collider_size = Vector3(0.8, 0.8, 0.8)
		"beacon":
			root.add_child(mesh_instance(cylinder(0.9, 1.3, 4.0, 8), color("slate"), Vector3(0, 2.0, 0)))
			root.add_child(mesh_instance(cylinder(0.7, 0.7, 0.9, 8), color("ink"), Vector3(0, 4.45, 0)))
			root.add_child(mesh_instance(cylinder(0.0, 1.0, 0.8, 8), color("coal"), Vector3(0, 5.3, 0)))
			collider_size = Vector3(2.4, 5.6, 2.4)
		"dock":
			root.add_child(mesh_instance(box(Vector3(2.0, 0.15, 6.0)), color(tint if tint else "driftwood"), Vector3(0, 0.6, 0)))
			for z: float in [-2.6, 0.0, 2.6]:
				for x: float in [-0.9, 0.9]:
					root.add_child(mesh_instance(cylinder(0.08, 0.08, 1.6, 5), color("slate"), Vector3(x, 0.0, z)))
			collider_size = Vector3(2.0, 0.15, 6.0)
		"signal_lantern":
			# Harbor signal post: a lantern hung from a crossarm, glowing in its tint (moss green
			# = "passengers waiting" to the Tidewright ferry).
			var glow := color(tint if tint else "moss")
			root.add_child(mesh_instance(cylinder(0.08, 0.11, 2.4, 5), color("driftwood"), Vector3(0, 1.2, 0)))
			root.add_child(mesh_instance(box(Vector3(0.08, 0.08, 0.7)), color("driftwood"), Vector3(0, 2.3, 0.3)))
			root.add_child(mesh_instance(cylinder(0.0, 0.2, 0.14, 6), color("ink"), Vector3(0, 2.07, 0.58)))
			root.add_child(mesh_instance(cylinder(0.14, 0.14, 0.3, 6), glow, Vector3(0, 1.85, 0.58), true))
			var lamp := OmniLight3D.new()
			lamp.light_color = glow
			lamp.light_energy = 1.4
			lamp.omni_range = 6.0
			lamp.position = Vector3(0, 1.85, 0.58)
			root.add_child(lamp)
			collider_size = Vector3(0.3, 2.4, 0.3)
		"stool":
			# Three-legged driftwood stool; the darker disc is a big man's dent worn into the seat.
			var wood := color(tint if tint else "driftwood")
			for i: int in 3:
				var a := TAU * i / 3.0
				root.add_child(mesh_instance(cylinder(0.035, 0.045, 0.42, 4), wood.darkened(0.15), Vector3(cos(a) * 0.15, 0.21, sin(a) * 0.15)))
			root.add_child(mesh_instance(cylinder(0.24, 0.22, 0.07, 7), wood, Vector3(0, 0.45, 0)))
			root.add_child(mesh_instance(cylinder(0.14, 0.14, 0.01, 7), wood.darkened(0.25), Vector3(0, 0.485, 0)))
			collider_size = Vector3(0.45, 0.5, 0.45)
		"cups":
			# An upturned half-crate with two cups set out on it.
			root.add_child(mesh_instance(box(Vector3(0.5, 0.36, 0.4)), color("driftwood").darkened(0.1), Vector3(0, 0.18, 0)))
			var cup := color(tint if tint else "bone")
			for x: float in [-0.11, 0.12]:
				root.add_child(mesh_instance(cylinder(0.05, 0.04, 0.1, 6), cup, Vector3(x, 0.41, 0.02)))
			collider_size = Vector3(0.5, 0.36, 0.4)
		"net_rack", "net_frame":
			# Drying frame: two posts and a crossbar. `net_rack` hangs a whole net; `net_frame`
			# holds a net begun from the middle — a small patch with no edge to start from.
			var wood := color("driftwood")
			for x: float in [-1.1, 1.1]:
				root.add_child(mesh_instance(cylinder(0.06, 0.08, 1.8, 5), wood, Vector3(x, 0.9, 0)))
			root.add_child(mesh_instance(box(Vector3(2.5, 0.08, 0.08)), wood, Vector3(0, 1.76, 0)))
			var net := color(tint if tint else "slate")
			if shape == "net_rack":
				root.add_child(mesh_instance(box(Vector3(2.0, 1.3, 0.03)), net, Vector3(0, 1.05, 0)))
				root.add_child(mesh_instance(box(Vector3(2.0, 0.06, 0.05)), color("coal"), Vector3(0, 0.42, 0)))
			else:
				root.add_child(mesh_instance(box(Vector3(0.02, 0.5, 0.02)), net, Vector3(0, 1.47, 0)))
				root.add_child(mesh_instance(box(Vector3(0.7, 0.55, 0.03)), net, Vector3(0, 0.95, 0)))
			collider_size = Vector3(2.4, 1.8, 0.2)
		_:
			root.add_child(mesh_instance(box(Vector3.ONE), color("coal"), Vector3(0, 0.5, 0)))
	var shape_node := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = collider_size
	shape_node.shape = box_shape
	shape_node.position = Vector3(0, collider_size.y * 0.5, 0) if shape != "dock" else Vector3(0, 0.6, 0)
	root.add_child(shape_node)
	root.scale = Vector3.ONE * scale
	return root


## A lit beacon's lantern room: glowing glass around the Gull's Beacon lantern plus a warm
## light. No collider — it sits inside the beacon's own.
static func _beacon_light(tint: String, scale: float) -> Node3D:
	var root := Node3D.new()
	root.name = "BeaconLight"
	var c := color(tint if tint else "kindle")
	root.add_child(mesh_instance(cylinder(0.74, 0.74, 0.86, 8), c, Vector3(0, 4.57, 0), true))
	var light := OmniLight3D.new()
	light.light_color = c
	light.light_energy = 2.5
	light.omni_range = 14.0
	light.position = Vector3(0, 4.6, 0)
	root.add_child(light)
	root.scale = Vector3.ONE * scale
	return root
