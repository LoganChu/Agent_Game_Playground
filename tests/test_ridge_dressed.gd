extends TestCase
## Day 26 — the ridge, dressed: the Lamp's chisel idle, Ottie's cap on the cold hut's seat,
## lantern halos, conditional ground paint (the fourth waymark's moss goes grey when its lantern
## is taken), and the ridge top's Blender dressing (outcrops, heather, the old road's waymarks).

const WOODS := "thornwold_woods"
const RIDGE := "thornwold_ridge"
const DIR := "res://assets/models/dressing/"
const KIT: Array[String] = ["collier_hut_cold_cap", "ridge_outcrop", "ridge_outcrop_low", "heather_silver", "waymark_tumbled"]

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _props(region_id: String, model: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop: Dictionary in _content().get_region(region_id)["props"]:
		if str(prop.get("model", "")) == DIR + model + ".glb":
			out.append(prop)
	return out


func _xz(pos: Array) -> Vector2:
	return Vector2(float(pos[0]), float(pos[2]))


func test_kit_models_load_and_stay_small() -> void:
	for model in KIT:
		var path := DIR + model + ".glb"
		assert_true(ResourceLoader.exists(path), "%s exists" % model)
		var scene := load(path) as PackedScene
		assert_true(scene != null, "%s loads" % model)
		if scene:
			var node := scene.instantiate() as Node3D
			assert_true(Region.mesh_bounds(node).size.length() > 0.3, "%s has geometry" % model)
			node.free()
		assert_true(FileAccess.get_file_as_bytes(path).size() < 5 * 1024 * 1024, "%s under 5 MB" % model)


## The Lamp works at the bench: tap, tap, a pause; now and then the hood turns to listen.
func test_the_lamp_chisels() -> void:
	var lamp: Dictionary = _content().npcs["lamp"]
	assert_eq(str(lamp.get("idle", "")), "chisel", "the Lamp chisels at the bench")
	# The beat: two lifts at the start of each period, then rest.
	var lifts := 0
	var was_up := false
	for i in int(CharacterRig.CHISEL_PERIOD * 100.0):
		var up := CharacterRig.chisel_tap(i * 0.01) > 0.5
		if up and not was_up:
			lifts += 1
		was_up = up
	assert_eq(lifts, 2, "two taps per beat")
	assert_eq(CharacterRig.chisel_tap(CharacterRig.CHISEL_PERIOD - 0.5), 0.0, "then a pause")
	var listens := 0.0
	for i in 300:
		listens = maxf(listens, CharacterRig.chisel_listen(i * 0.034 * 3.0))
	assert_true(listens > 0.9, "the head turns aside")
	assert_eq(CharacterRig.chisel_listen(0.5), 0.0, "but not every beat")

	var model := CharacterRig.instantiate(str(lamp["model"]), "chisel")
	var rig := model.get_node("CharacterRig") as CharacterRig
	assert_eq(rig.style, "chisel")
	rig._ready()
	var arm := model.find_child("ArmL", true, false) as Node3D
	var head := model.find_child("Head", true, false) as Node3D
	var torso := model.find_child("Torso", true, false) as Node3D
	var rest_torso := torso.transform
	rig.pose(CharacterRig.CHISEL_PERIOD - 0.3)  # resting on the work
	var resting := arm.transform
	assert_true((torso.transform.basis.y - rest_torso.basis.y).z > 0.05, "bent over the bench")
	rig.pose(0.16)  # the top of the first tap
	assert_false(arm.transform.is_equal_approx(resting), "the hammer hand lifts")
	var ahead := head.transform.basis.z
	rig.pose(CharacterRig.CHISEL_PERIOD * 1.2 + 1.4)  # mid-listen
	assert_true(head.transform.basis.z.angle_to(ahead) > 0.3, "the hood turns")
	model.free()


## The cold hut shows Ottie's cap on the seat once Hob has it — exactly one hut either way.
func test_the_cap_on_the_seat() -> void:
	var db := _content()
	var cold := _props(WOODS, "collier_hut_cold")
	var capped := _props(WOODS, "collier_hut_cold_cap")
	assert_eq(cold.size(), 1)
	assert_eq(capped.size(), 1)
	assert_eq(cold[0]["position"], capped[0]["position"], "the same hut, in the same place")
	for has_cap: bool in [false, true]:
		var state := fresh_state(db)
		state.set_flag("thornwold_hob_has_cap", has_cap)
		var shown := int(Conditions.evaluate(cold[0].get("if"), state)) + int(Conditions.evaluate(capped[0].get("if"), state))
		assert_eq(shown, 1, "one cold hut (cap %s)" % has_cap)
		assert_eq(Conditions.evaluate(capped[0].get("if"), state), has_cap, "the cap shows only once Hob has it")
	# The capped hut is the cold hut plus a cap: a little more geometry, same footprint.
	var a := (load(DIR + "collier_hut_cold.glb") as PackedScene).instantiate() as Node3D
	var b := (load(DIR + "collier_hut_cold_cap.glb") as PackedScene).instantiate() as Node3D
	assert_true(_vertices(b) > _vertices(a), "the cap adds geometry")
	assert_true((Region.mesh_bounds(b).size - Region.mesh_bounds(a).size).length() < 0.2, "same hut")
	a.free()
	b.free()


func _vertices(root: Node) -> int:
	var count := 0
	for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			count += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return count


## Every lit waymark carries a halo at its glass so it reads at a distance.
func test_lit_waymarks_have_halos() -> void:
	var count := 0
	for region_id: String in [WOODS, RIDGE]:
		for prop in _props(region_id, "waymark_lit"):
			assert_true(prop.get("halo") is Array, "lit waymark at %s in %s has a halo" % [prop["position"], region_id])
			count += 1
	assert_true(count >= 7, "the woods' and the ridge's lanterns")
	var halo := LanternHalo.build(Vector3(0, 1.76, 0.5))
	assert_eq(halo.position, Vector3(0, 1.76, 0.5))
	assert_true(halo.mesh is QuadMesh and halo.material_override is ShaderMaterial, "a camera-facing quad")
	assert_eq(halo.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	halo.free()


## Paint zones may carry an `if`: the ground recolours when the condition changes.
func test_conditional_paint() -> void:
	var db := _content()
	var ground := {"bounds": [-5, -5, 5, 5], "colors": {"ground": "pine"},
		"paint": [{"ellipse": [0, 0, 1, 1], "color": "silverfog", "if": "flag:thornwold_fourth_lantern_taken"},
			{"ellipse": [0, 0, 3, 3], "color": "moss"}]}
	var field := TerrainField.from_data(ground)
	assert_eq(field.color_name(0, 0, 0, 0), "moss", "a conditional zone is off until selected")
	assert_true(field.has_conditional_paint())
	var state := fresh_state(db)
	assert_false(field.select_paint(state), "nothing changes while the flag is unset")
	state.set_flag("thornwold_fourth_lantern_taken", true)
	assert_true(field.select_paint(state), "setting the flag changes the paint")
	assert_eq(field.color_name(0, 0, 0, 0), "silverfog", "the conditional zone wins (listed first)")
	assert_eq(field.color_name(2, 0, 0, 0), "moss")
	assert_false(field.select_paint(state), "no change the second time")
	# The woods: the fourth waymark's ground greys when its lantern goes to the stair.
	var woods := TerrainField.from_data(db.get_region(WOODS)["ground"])
	var spot := Vector2(-13, -47)  # the fourth waymark
	var lit := fresh_state(db)
	woods.select_paint(lit)
	assert_eq(woods.color_name(spot.x, spot.y, 0, 0), "moss", "green while the fourth lantern hangs")
	lit.set_flag("thornwold_fourth_lantern_taken", true)
	assert_true(woods.select_paint(lit))
	assert_eq(woods.color_name(spot.x, spot.y, 0, 0), "silverfog", "grey once it's taken")


## The built ground recolours (mesh only) when its paint changes — what Region does when a
## flag flips mid-visit (`refresh_conditional`).
func test_ground_recolours() -> void:
	var db := _content()
	var field := TerrainField.from_data(db.get_region(WOODS)["ground"])
	var state := fresh_state(db)
	field.select_paint(state)
	var body := TerrainBuilder.build(field)
	var mi := body.get_node("GroundMesh") as MeshInstance3D
	var before := _color_near(mi.mesh, Vector2(-13, -47))
	state.set_flag("thornwold_fourth_lantern_taken", true)
	assert_true(field.select_paint(state))
	TerrainBuilder.recolor(body, field)
	var after := _color_near(mi.mesh, Vector2(-13, -47))
	assert_true(before.g > before.b + 0.1, "green under the fourth waymark while it is lit")
	assert_true(after.b >= after.g, "gone grey once its lantern is taken")
	assert_true(body.get_node("GroundMesh") == mi, "the same node, a new mesh")
	body.free()


func _color_near(mesh: Mesh, at: Vector2) -> Color:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var best := 0
	for i in verts.size():
		if Vector2(verts[i].x, verts[i].z).distance_squared_to(at) < Vector2(verts[best].x, verts[best].z).distance_squared_to(at):
			best = i
	return colors[best]


func test_validator_checks_paint_conditions_and_halos() -> void:
	var db := load_content()
	var ground: Dictionary = db.regions[WOODS]["ground"]
	(ground["paint"] as Array).append({"ellipse": [0, 0, 1, 1], "color": "moss", "if": "flag:no_such_flag"})
	(ground["land"] as Array).append({"ellipse": [0, 0, 1, 1], "height": 0.0, "if": "flag:thornwold_landed"})
	var props: Array = db.regions[RIDGE]["props"]
	props.append({"model": DIR + "waymark_lit.glb", "position": [0, 0, 0], "halo": [0, 1]})
	props.append({"shape": "rock", "position": [0, 0, 0], "halo": [0, 1, 0]})
	props.append({"model": DIR + "waymark_lit.glb", "position": [0, 0, 0], "halo": [0, 1, 0], "halo_size": -1})
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["undeclared flag 'no_such_flag'", "ground.land can't be conditional", "'halo' must be [x, y, z]",
			"'halo' needs a 'model'", "'halo_size' must be a number > 0"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)


## The ridge top is dressed from Blender: no procedural rocks left, outcrops off the paths,
## heather in clumps, and the old Keepers' road's waymarks going on north-east into the fog.
func test_ridge_top_dressing() -> void:
	var region := _content().get_region(RIDGE)
	for prop: Dictionary in region["props"]:
		assert_false(str(prop.get("shape", "")) == "rock" and not prop.has("model"), "no procedural rocks on the ridge")
	var outcrops := _props(RIDGE, "ridge_outcrop") + _props(RIDGE, "ridge_outcrop_low")
	assert_true(outcrops.size() >= 4, "stone outcrops")
	assert_true(_props(RIDGE, "heather_silver").size() >= 10, "heather across the plateau")
	# Outcrops stand clear of the trodden paths (the Lamp's, to the tower, the old road).
	for zone: Dictionary in region["ground"]["paint"]:
		if not zone.has("path"):
			continue
		var pts: Array = zone["path"]
		for i in pts.size() - 1:
			for k in 11:
				var p := Vector2(float(pts[i][0]), float(pts[i][1])).lerp(Vector2(float(pts[i + 1][0]), float(pts[i + 1][1])), k / 10.0)
				for o in outcrops:
					var c: Array = o["collider"]
					var r := maxf(float(c[0]), float(c[2])) * 0.5 * float(o.get("scale", 1.0))
					assert_true(p.distance_to(_xz(o["position"])) > r + 0.5, "outcrop at %s clear of the path at %s" % [o["position"], p])
	# The road's waymarks: bare, bare, tumbled, each further north-east and higher up the spine.
	var marks: Array[Dictionary] = _props(RIDGE, "waymark") + _props(RIDGE, "waymark_tumbled")
	assert_eq(marks.size(), 3, "two bare waymarks and a tumbled one along the old road")
	var field := TerrainField.from_data(region["ground"])
	var spawn: Array = region["spawn_points"]["default"]
	var reach := field.reachable_from(float(spawn[0]), float(spawn[2]))
	for i in marks.size() - 1:
		var a := _xz(marks[i]["position"])
		var b := _xz(marks[i + 1]["position"])
		assert_true(b.x > a.x and b.y < a.y, "the road goes on north-east")
	var last := _xz(marks[2]["position"])
	assert_false(reach.has(field.cell_of(last.x, last.y)), "the tumbled waymark is seen, not reached")
	assert_true(field.height_at(last.x, last.y) > field.height_at(_xz(marks[0]["position"]).x, _xz(marks[0]["position"]).y) + 1.0,
			"up on the spine")
