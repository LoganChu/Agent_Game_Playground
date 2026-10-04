extends TestCase
## The Blender dressing kit (assets/models/dressing/): every model loads with meshes and sane
## bounds, model props carry their `light`, and the validator guards lights on model props.

const DIR := "res://assets/models/dressing/"
const MAX_BYTES := 5 * 1024 * 1024


func _models() -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(DIR):
		if file.ends_with(".glb"):
			out.append(DIR + file)
	return out


## World-space AABB of every mesh under `node` (node at the origin, unscaled).
func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != node and n is Node3D:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var aabb := xf * mi.get_aabb()
		box = aabb if first else box.merge(aabb)
		first = false
	return box


func test_every_model_loads_small_and_upright() -> void:
	var models := _models()
	assert_true(models.size() >= 20, "the kit has its models (found %d)" % models.size())
	for path in models:
		assert_true(FileAccess.get_file_as_bytes(path).size() < MAX_BYTES, "%s is under 5 MB" % path)
		var scene := load(path) as PackedScene
		assert_true(scene != null, "%s loads" % path)
		if scene == null:
			continue
		var node := scene.instantiate() as Node3D
		var meshes := node.find_children("*", "MeshInstance3D", true, false)
		assert_true(meshes.size() > 0, "%s has meshes" % path)
		# Merged by material in Blender: a handful of draw calls, not one per strand.
		assert_true(meshes.size() <= 16, "%s has %d mesh nodes (merge by material)" % [path, meshes.size()])
		var box := _bounds(node)
		# The ferry is the one big vessel (9 m hull, 8 m mast) and Thornwold's beacon the one tall
		# landmark (~10 m to its vane); everything else fits in 8 × 7 m.
		var limit := Vector3(8.0, 7.0, 8.0)
		if path.ends_with("ferry.glb"):
			limit = Vector3(12.0, 9.0, 12.0)
		elif path.get_file().begins_with("thornwold_beacon"):
			limit = Vector3(8.0, 11.0, 8.0)
		assert_true(box.size.length() > 0.2 and box.size.x < limit.x and box.size.z < limit.z and box.size.y < limit.y, "%s has sane bounds %s" % [path, box])
		# Boats sit on the waterline; the dock and lantern room are placed at absolute heights.
		if not path.get_file().get_basename() in ["moored_boat", "ferry", "dock", "beacon_lit"]:
			assert_true(box.position.y > -0.3, "%s stands on its origin (min y %.2f)" % [path, box.position.y])
		node.free()


func test_replacements_keep_their_shape_heights() -> void:
	# The dock's deck top must stay at 0.675 so it matches the Saltmarrow pier (placed at -0.4).
	var dock := (load(DIR + "dock.glb") as PackedScene).instantiate() as Node3D
	var planks := 0
	for mi: MeshInstance3D in dock.find_children("*", "MeshInstance3D", true, false):
		var aabb := mi.transform * mi.get_aabb()
		if absf(aabb.end.y - 0.675) < 0.01 and aabb.size.z > 5.5:
			planks += 1
	assert_true(planks >= 1, "dock planks top out at 0.675")
	dock.free()
	# The lit beacon's glass sits inside the Gull's Beacon lantern (4.12–5.02).
	var lit := (load(DIR + "beacon_lit.glb") as PackedScene).instantiate() as Node3D
	var box := _bounds(lit)
	assert_true(box.position.y > 4.0 and box.end.y < 5.2, "beacon glass between 4.0 and 5.2 (%s)" % box)
	lit.free()


func test_model_props_get_their_light() -> void:
	var db := load_content()
	var region := Region.new()
	for id: String in ["saltmarrow", "gulls_head"]:
		for prop: Dictionary in db.get_region(id)["props"]:
			if not prop.has("light"):
				continue
			var node := region._build_prop(prop)
			var lights := node.find_children("*", "OmniLight3D", true, false)
			assert_eq(lights.size(), 1, "%s in %s has one light" % [prop.get("shape"), id])
			if lights.size() == 1:
				var light := lights[0] as OmniLight3D
				assert_eq(light.light_color, PropFactory.color(str(prop["light"].get("color", "kindle"))))
				assert_true(light.omni_range > 1.0, "light has a range")
			node.free()
	region.free()


func test_validator_checks_prop_lights() -> void:
	var db := load_content()
	var props: Array = db.regions["saltmarrow"]["props"]
	props.append({"shape": "crate", "position": [0, 0, 0], "light": {"color": "kindle"}})
	props.append({"model": DIR + "signal_lantern.glb", "shape": "signal_lantern", "position": [0, 0, 0]})
	props.append({"model": DIR + "lantern_post.glb", "position": [0, 0, 0], "light": {"color": "no_such_colour", "range": "far"}})
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["'light' needs a 'model'", "needs a 'light'", "unknown color 'no_such_colour'", "range must be a number"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)
