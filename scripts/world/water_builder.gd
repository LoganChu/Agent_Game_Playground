class_name WaterBuilder
extends RefCounted
## Builds a region's sea: a grid over the sculpted ground's bounds whose vertices carry the
## water depth above the ground (COLOR.r, normalised by DEEP), plus a skirt out to the
## horizon at full depth. assets/shaders/water.gdshader turns that into shallow→deep colour,
## waves that calm towards the shore, and a foam line where the depth reaches 0 — no depth
## buffer needed, so it looks the same in the Compatibility renderer.

const SHADER := preload("res://assets/shaders/water.gdshader")
## Metres of water at which the sea reads fully deep (COLOR.r = 1).
const DEEP := 1.2
## Vertices per ground cell along each axis (2 = a half-metre grid on a 1 m field).
const SUBDIVIDE := 2
## How far the skirt reaches past the grid (metres).
const SKIRT := 300.0
## A region's `water` settings (all optional) and their allowed ranges: `swell` scales the wave
## height (0 = mirror-flat), `wash` the broken foam lines washing in, `foam` the shore foam's
## width, `mirror` how much the surface takes the sky's colour at a glancing look (0..1).
const SETTINGS := {"swell": Vector2(0.0, 2.0), "wash": Vector2(0.0, 1.0), "foam": Vector2(0.0, 2.0), "mirror": Vector2(0.0, 1.0)}
## Colour keys (palette names or #hex): `shallow`, `deep`, and `sheen` (the mirrored sky).
const COLOR_KEYS: Array[String] = ["shallow", "deep", "sheen"]
const WAVE_HEIGHT := 0.07
const FOAM_WIDTH := 0.13


## Normalised water depth at x/z: 0 where the ground reaches the water (or rises above it),
## 1 at DEEP metres or more. Without a sculpted field the sea is deep everywhere.
static func depth_at(field: TerrainField, level: float, x: float, z: float) -> float:
	if field == null or not field.contains(x, z):
		return 1.0
	return clampf((level - field.height_at(x, z)) / DEEP, 0.0, 1.0)


static func build(field: TerrainField, level: float, spec: Dictionary = {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = build_mesh(field, level)
	mi.material_override = material(spec)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = level
	return mi


## The water material, tuned by a region's `water` settings (see SETTINGS / COLOR_KEYS).
static func material(spec: Dictionary = {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var shallow := PropFactory.color(str(spec["shallow"])) if spec.has("shallow") else PropFactory.color("tide").lerp(PropFactory.color("moss"), 0.25)
	mat.set_shader_parameter("shallow_color", shallow)
	mat.set_shader_parameter("deep_color", PropFactory.color(str(spec.get("deep", "abyss"))))
	mat.set_shader_parameter("foam_color", PropFactory.color("bone"))
	mat.set_shader_parameter("sheen_color", PropFactory.color(str(spec.get("sheen", "silverfog"))))
	mat.set_shader_parameter("wave_height", WAVE_HEIGHT * float(spec.get("swell", 1.0)))
	mat.set_shader_parameter("wash_strength", float(spec.get("wash", 1.0)))
	mat.set_shader_parameter("foam_width", FOAM_WIDTH * float(spec.get("foam", 1.0)))
	mat.set_shader_parameter("mirror", float(spec.get("mirror", 0.0)))
	return mat


## The water surface in local space (y = 0 is the water level).
static func build_mesh(field: TerrainField, level: float) -> ArrayMesh:
	var rect := field.bounds if field else Rect2(-60, -60, 120, 120)
	var step := (field.cell if field else 10.0) / SUBDIVIDE
	var nx := int(ceil(rect.size.x / step))
	var nz := int(ceil(rect.size.y / step))
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for iz in nz + 1:
		for ix in nx + 1:
			var x := minf(rect.position.x + ix * step, rect.end.x)
			var z := minf(rect.position.y + iz * step, rect.end.y)
			verts.append(Vector3(x, 0, z))
			colors.append(Color(depth_at(field, level, x, z), 0, 0))
	for iz in nz:
		for ix in nx:
			var a := iz * (nx + 1) + ix
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			# Skip cells that lie wholly under dry land: the ground hides them anyway.
			if colors[a].r + colors[b].r + colors[c].r + colors[d].r == 0.0 and _dry(field, level, verts[a], verts[d]):
				continue
			indices.append_array([a, b, d, a, d, c])
	_add_skirt(verts, colors, indices, nx, nz)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## True if a cell's corners and centre are all above the water (well inland).
static func _dry(field: TerrainField, level: float, lo: Vector3, hi: Vector3) -> bool:
	if field == null:
		return false
	var mid := (lo + hi) * 0.5
	return field.height_at(mid.x, mid.z) > level + 0.3


## A ring of strips from every grid edge vertex out to SKIRT metres, sharing the grid's edge
## vertices exactly (no T-junctions, so the waves never open a crack at the seam).
static func _add_skirt(verts: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, nx: int, nz: int) -> void:
	var ring: Array[int] = []  # grid edge vertex indices, counter-clockwise seen from above
	for ix in nx + 1:
		ring.append(ix)
	for iz in range(1, nz + 1):
		ring.append(iz * (nx + 1) + nx)
	for ix in range(nx - 1, -1, -1):
		ring.append(nz * (nx + 1) + ix)
	for iz in range(nz - 1, 0, -1):
		ring.append(iz * (nx + 1))
	var centre := (verts[0] + verts[verts.size() - 1]) * 0.5
	var outer_start := verts.size()
	for i: int in ring:
		var v := verts[i]
		var dir := Vector3(v.x - centre.x, 0, v.z - centre.z).normalized()
		verts.append(v + dir * SKIRT)
		colors.append(Color(1, 0, 0))
	var count := ring.size()
	for k in count:
		var a := ring[k]
		var b := ring[(k + 1) % count]
		var oa := outer_start + k
		var ob := outer_start + (k + 1) % count
		indices.append_array([a, oa, b, b, oa, ob])
