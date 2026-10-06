class_name TerrainBuilder
extends RefCounted
## Turns a `TerrainField` into the visible ground (flat-shaded, vertex-coloured triangles)
## and its collider (the same grid, with underwater vertices raised into an invisible
## shore wall).

## Per-triangle brightness jitter so large areas of one colour still read as facets.
const SHADE_JITTER := 0.05


static func build(field: TerrainField) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Terrain"
	var mi := MeshInstance3D.new()
	mi.name = "GroundMesh"
	mi.mesh = _mesh(field)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mi.material_override = mat
	body.add_child(mi)
	# A wide seabed under the grid so the sea doesn't show where the sculpted area ends.
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	var seabed := PropFactory.mesh_instance(plane, PropFactory.color(str(field.colors.get("seabed", "driftwood"))), Vector3(field.bounds.get_center().x, field.base - 0.12, field.bounds.get_center().y))
	seabed.name = "Seabed"
	body.add_child(seabed)
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(_collision_faces(field))
	shape.shape = concave
	body.add_child(shape)
	return body


## Rebuilds the visible ground's colours after the field's paint changed (the collider and the
## shape stay; only the mesh is regenerated).
static func recolor(body: StaticBody3D, field: TerrainField) -> void:
	var mi := body.get_node_or_null("GroundMesh") as MeshInstance3D
	if mi:
		mi.mesh = _mesh(field)


static func _mesh(field: TerrainField) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in field.rows - 1:
		for ix in field.cols - 1:
			var v00 := _vertex(field, ix, iz, false)
			var v10 := _vertex(field, ix + 1, iz, false)
			var v01 := _vertex(field, ix, iz + 1, false)
			var v11 := _vertex(field, ix + 1, iz + 1, false)
			# Split along the (0,0)-(1,1) diagonal — TerrainField.height_at relies on it.
			# Clockwise seen from above = front face in Godot.
			_triangle(st, field, v00, v10, v11, ix * 2 + iz * 7)
			_triangle(st, field, v00, v11, v01, ix * 2 + 1 + iz * 7)
	st.generate_normals()
	return st.commit()


static func _triangle(st: SurfaceTool, field: TerrainField, a: Vector3, b: Vector3, c: Vector3, salt: int) -> void:
	var center := (a + b + c) / 3.0
	var slope := 0.0
	for pair: Array in [[a, b], [b, c], [c, a]]:
		var p: Vector3 = pair[0]
		var q: Vector3 = pair[1]
		var run := Vector2(p.x - q.x, p.z - q.z).length()
		if run > 0.001:
			slope = maxf(slope, absf(p.y - q.y) / run)
	var col := PropFactory.color(field.color_name(center.x, center.z, center.y, slope))
	var shade := 1.0 + SHADE_JITTER * field._noise(salt, field.seed_value + 11)
	col = Color(col.r * shade, col.g * shade, col.b * shade)
	st.set_smooth_group(-1)  # flat shading: each triangle keeps its own normal
	for v: Vector3 in [a, b, c]:
		st.set_color(col)
		st.add_vertex(v)


static func _collision_faces(field: TerrainField) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for iz in field.rows - 1:
		for ix in field.cols - 1:
			var v00 := _vertex(field, ix, iz, true)
			var v10 := _vertex(field, ix + 1, iz, true)
			var v01 := _vertex(field, ix, iz + 1, true)
			var v11 := _vertex(field, ix + 1, iz + 1, true)
			faces.append_array([v00, v10, v11, v00, v11, v01])
	return faces


static func _vertex(field: TerrainField, ix: int, iz: int, collision: bool) -> Vector3:
	var p := field.vertex_xz(ix, iz)
	var h := field.collision_height(ix, iz) if collision else field.vertex_height(ix, iz)
	return Vector3(p.x, h, p.y)
