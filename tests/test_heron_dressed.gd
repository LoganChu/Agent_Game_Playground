extends TestCase
## Day 36 — the Heron lit, dressed (art): up close the lit lantern room holds the cold put-down
## things in a row along its front sill and the keeper's coat folded on the boards; Corran stands
## without his knot-cord once he's given it away (swapped live, mid-talk, without losing his turn
## to the player); the lit Heron's gold lies on the mere in both regions, drawn over the water.

const KIT := "res://assets/models/dressing/"
const CHARS := "res://assets/models/characters/"
## The lantern room's floor (the sill's top) in the Heron's own frame: build_fen rz + 0.16.
const FLOOR := 6.52
## build_fen SILL_ROW_Y (Blender -0.66 → Godot +0.66) and SILL_ROW; COAT_AT (Godot z = -Blender y).
const ROW_Z := 0.66
const ROW_X := Vector2(-0.6, 0.62)
const COAT := Vector2(0.5, -0.36)


## Every vertex of a model in its own frame.
func _verts(path: String) -> PackedVector3Array:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	var out := PackedVector3Array()
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var xf := mi.transform
		var parent := mi.get_parent() as Node3D
		while parent != null and parent != node:
			xf = parent.transform * xf
			parent = parent.get_parent() as Node3D
		for i in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
				out.append(xf * v)
	node.free()
	return out


func _count_in(verts: PackedVector3Array, box: AABB) -> int:
	var n := 0
	for v in verts:
		if box.has_point(v):
			n += 1
	return n


func _sill_box(x0: float, x1: float) -> AABB:
	return AABB(Vector3(x0, FLOOR - 0.01, ROW_Z - 0.09), Vector3(x1 - x0, 0.25, 0.18))


func _coat_box() -> AABB:
	# Clear of the cradle plate's corner (x, z within ±0.25).
	return AABB(Vector3(COAT.x - 0.21, FLOOR - 0.01, COAT.y - 0.2), Vector3(0.42, 0.2, 0.4))


func test_the_things_lie_along_the_sill_once_lit() -> void:
	var lit := _verts(KIT + "heron_light_near_lit.glb")
	# Something all the way along the row: in each fifth of it, not one heap.
	var span := ROW_X.y - ROW_X.x
	for k in 5:
		var x0 := ROW_X.x + span * k / 5.0
		assert_true(_count_in(lit, _sill_box(x0, x0 + span / 5.0)) > 0, "a put-down thing along the sill at x %.2f" % x0)
	# Small things, lying down: nothing in the row stands taller than the gull (~0.25 m).
	var row := _sill_box(ROW_X.x, ROW_X.y)
	for v in lit:
		if row.has_point(v):
			assert_true(v.y < FLOOR + 0.25, "the things lie low on the sill (%.2f)" % v.y)
	assert_true(_count_in(lit, _coat_box()) >= 8, "the keeper's coat folded on the boards beside the plate")
	# Before the burn they're heaped in the cradle (dark panes; the dialogue tells it): no row.
	var cold := _verts(KIT + "heron_light_near.glb")
	assert_eq(_count_in(cold, row), 0, "no row along the sill before the burn")
	assert_eq(_count_in(cold, _coat_box()), 0, "the cold model leaves the coat to the dialogue")
	# From the staithe they're too small to see: the distance model doesn't carry them.
	assert_eq(_count_in(_verts(KIT + "heron_light_lit.glb"), row), 0, "the distance model stays light")


func test_the_dialogue_still_says_so() -> void:
	# The art follows the text; if the text moves them, this should fail loudly.
	var text := FileAccess.get_file_as_string("res://story/heron_ladder.json")
	assert_true(text.contains("set them in a row along the sill"), "the burn sets the cold things along the sill")
	assert_true(text.contains("the gull at the end"), "the gull at the end of the row")
	assert_true(text.contains("coat is still folded on the boards"), "the coat stays folded on the boards")


## Whether a model's torso carries the knot-cord: a narrow surface at the front of the left hip,
## hanging below the belt (the test_heron_close check).
func _wears_cord(path: String) -> bool:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	var found := false
	for mi: MeshInstance3D in node.find_children("Torso*", "MeshInstance3D", true, false):
		var xf := mi.transform
		var parent := mi.get_parent() as Node3D
		while parent != null and parent != node:
			xf = parent.transform * xf
			parent = parent.get_parent() as Node3D
		for i in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
			var box := AABB(xf * verts[0], Vector3.ZERO)
			for v: Vector3 in verts:
				box = box.expand(xf * v)
			if box.position.z > 0.2 and box.size.x < 0.15 and box.size.y > 0.25 and box.get_center().x > 0.1:
				found = true
	node.free()
	return found


func test_corran_without_his_cord() -> void:
	assert_true(_wears_cord(CHARS + "corran.glb"), "the cord at his hip")
	assert_false(_wears_cord(CHARS + "corran_nocord.glb"), "nothing hangs there once it's given")
	assert_true(_verts(CHARS + "corran_nocord.glb").size() < _verts(CHARS + "corran.glb").size(), "the same man, less the cord")


func test_corran_is_placed_by_his_cord() -> void:
	var db := load_content()
	for region_id: String in ["glasswater_fen", "heron_mere"]:
		var placements := (db.get_region(region_id)["npcs"] as Array).filter(
				func(n: Dictionary) -> bool: return n["npc"] == "corran")
		assert_eq(placements.size(), 2, "%s: Corran with and without the cord" % region_id)
		for punt_out: bool in [false, true]:
			for given: bool in [false, true]:
				var state := fresh_state(db)
				state.flags["fen_punt_out"] = punt_out
				state.flags["fen_corran_cord_away"] = given
				var shown := placements.filter(func(n: Dictionary) -> bool: return Conditions.evaluate(n.get("if"), state))
				var here := punt_out == (region_id == "heron_mere")
				assert_eq(shown.size(), 1 if here else 0, "%s: one Corran (out %s, given %s)" % [region_id, punt_out, given])
				if shown.size() == 1:
					var model := str(Region.placed_npc_data(db.get_npc("corran"), shown[0]).get("model", ""))
					assert_eq(model.get_file(), "corran_nocord.glb" if given else "corran.glb", "%s: his model (given %s)" % [region_id, given])
		# The two placements stand on the same spot, so the swap reads as the cord going, not a jump.
		assert_eq(placements[0]["position"], placements[1]["position"], "%s: the same spot" % region_id)
		assert_eq(placements[0].get("rotation_y"), placements[1].get("rotation_y"), "%s: the same facing" % region_id)


func test_burned_channels_keep_him_bare_and_a_returned_cord_dresses_him() -> void:
	var db := load_content()
	var state := fresh_state(db)
	state.flags["fen_corran_cord_away"] = true
	state.flags["fen_beacon_burned"] = "channels"
	var at_landing := (db.get_region("glasswater_fen")["npcs"] as Array).filter(
			func(n: Dictionary) -> bool: return n["npc"] == "corran" and Conditions.evaluate(n.get("if"), state))
	assert_eq(str(at_landing[0].get("model", "")).get_file(), "corran_nocord.glb", "burned: no cord at his landing")
	# Burned with Hesper's name instead, the cord goes back to him (Day 35 clears the flag).
	state.flags["fen_corran_cord_away"] = false
	state.flags["fen_beacon_burned"] = "name"
	at_landing = (db.get_region("glasswater_fen")["npcs"] as Array).filter(
			func(n: Dictionary) -> bool: return n["npc"] == "corran" and Conditions.evaluate(n.get("if"), state))
	assert_false(at_landing[0].has("model"), "given back: his own model, the cord on")


func test_a_swapped_npc_keeps_his_turn() -> void:
	var db := load_content()
	var before := NpcActor.new()
	before.setup("corran", db.get_npc("corran"))
	before._build_body()  # (as _ready would, in a region)
	before._talking = true
	before._face_yaw = 1.5
	before._body.rotation.y = 1.2
	var after := NpcActor.new()
	after.setup("corran", Region.placed_npc_data(db.get_npc("corran"), {"model": CHARS + "corran_nocord.glb"}))
	after.take_over(before)
	after._build_body()
	assert_true(after._talking, "still talking")
	assert_true(is_equal_approx(after._face_yaw, 1.5), "still turning to the player")
	assert_true(is_equal_approx(after.body_yaw(), 1.2), "the body starts where the old one stood (%.2f)" % after.body_yaw())
	before.free()
	after.free()


func test_the_gold_lies_on_the_mere() -> void:
	var db := load_content()
	var streak := _verts(KIT + "gold_streak.glb")
	var flat := AABB(streak[0], Vector3.ZERO)
	for v in streak:
		flat = flat.expand(v)
	assert_true(flat.size.y < 0.05 and flat.size.z > 6.0, "a long flat streak (%s)" % flat)
	for region_id: String in ["glasswater_fen", "heron_mere"]:
		var region := db.get_region(region_id)
		var water := float(region["water_level"])
		var field := TerrainField.from_data(region["ground"], water)
		var props := (region["props"] as Array).filter(func(p: Dictionary) -> bool: return str(p.get("model", "")).get_file() == "gold_streak.glb")
		assert_eq(props.size(), 1, "%s: the gold on the mere" % region_id)
		if props.is_empty():
			continue
		var prop: Dictionary = props[0]
		assert_eq(prop.get("if"), "quest:a_light_for_glasswater=done", "%s: only once the Heron is lit" % region_id)
		assert_eq(prop.get("over_water"), true, "%s: drawn over the water" % region_id)
		var at := JsonUtil.to_vector3(prop["position"])
		assert_true(at.y > water + 0.03 and at.y < water + 0.12, "%s: just over the swell (%.2f)" % [region_id, at.y])
		# It starts at the Heron's legs, and most of it lies on open water, not under the mud.
		var heron := (region["props"] as Array).filter(func(p: Dictionary) -> bool: return str(p.get("model", "")).get_file().begins_with("heron_light") and str(p.get("model", "")).contains("lit"))
		var foot := JsonUtil.to_vector3(heron[0]["position"])
		assert_true(Vector2(at.x - foot.x, at.z - foot.z).length() < 1.6, "%s: from the Heron's legs" % region_id)
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(prop.get("rotation_y", 0)))).scaled(Vector3.ONE * float(prop.get("scale", 1.0))), at)
		var wet := 0
		for v in streak:
			var w := xf * v
			if field.height_at(w.x, w.z) < water:
				wet += 1
		assert_true(wet > streak.size() * 0.6, "%s: the gold lies on open water (%d of %d)" % [region_id, wet, streak.size()])


func test_over_water_draws_after_the_sea() -> void:
	var node := (load(KIT + "gold_streak.glb") as PackedScene).instantiate() as Node3D
	Region.draw_over_water(node)
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			assert_eq(mi.get_active_material(i).render_priority, 1, "surface %d drawn after the sea" % i)
			assert_eq(mi.mesh.surface_get_material(i).render_priority, 0, "the shared material is left alone")
	node.free()


func test_validator_checks_over_water() -> void:
	var db := load_content()
	var props: Array = db.regions["heron_mere"]["props"]
	for p: Dictionary in props:
		if str(p.get("model", "")).ends_with("gold_streak.glb"):
			p["over_water"] = "yes"
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	assert_true(validator.report().contains("prop 'over_water' must be true or false"), validator.report())
