extends TestCase
## Day 39 — fen art follow-ups: the fen's flat white light (peat water, not blue; a pale mud band
## at the shore; bleached sedge; fog and sky a neutral white), the keepers' stage carried on to
## the ladder by a landing (and a cleat on the leg), the ladder lashed tight to its leg (its
## rungs' shadows had striped the leg in zig-zags), Mara's red cord round the sill gull's neck.

const KIT := "res://assets/models/dressing/"
const FEN_REGIONS: Array[String] = ["glasswater_fen", "heron_mere"]
## The Heron's ladder leg (build_fen legs[0]) in the model's Godot frame: foot and top.
const LEG_FOOT := Vector3(-1.6, 0.0, 1.6)
const LEG_TOP := Vector3(-1.15, 6.2, 1.15)
## build_fen LADDER_OUT (Blender -Y → Godot +Z); before Day 39 it was 0.25.
const LADDER_OUT := 0.19
## build_fen GULL_AT (Blender (0.57, -0.64, 6.52) → Godot).
const GULL := Vector3(0.57, 6.52, 0.64)


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


func _in(verts: PackedVector3Array, box: AABB) -> PackedVector3Array:
	var out := PackedVector3Array()
	for v in verts:
		if box.has_point(v):
			out.append(v)
	return out


func _leg_at(y: float) -> Vector3:
	return LEG_FOOT.lerp(LEG_TOP, y / LEG_TOP.y)


func _bluish(c: Color) -> bool:
	return c.b - maxf(c.r, c.g) > 0.02


func _color(region: Dictionary, path: Array) -> Color:
	var v: Variant = region
	for key: String in path:
		v = (v as Dictionary)[key]
	return PropFactory.color(str(v))


func test_the_fen_light_is_white_and_its_water_peat() -> void:
	var db := load_content()
	for region_id in FEN_REGIONS:
		var region := db.get_region(region_id)
		for path: Array in [["water", "shallow"], ["water", "deep"], ["water", "sheen"], ["fog", "color"],
				["light", "ambient_color"], ["light", "sky_horizon"], ["ground", "colors", "seabed"]]:
			var c := _color(region, path)
			assert_false(_bluish(c), "%s %s: no blue in the fen's white (%s)" % [region_id, "/".join(path), c.to_html(false)])
		var ground := _color(region, ["ground", "colors", "ground"])
		var shore := _color(region, ["ground", "colors", "shore"])
		assert_true(shore.get_luminance() > ground.get_luminance() + 0.15, "%s: a pale mud band at the shore" % region_id)
		assert_true(ground.s < PropFactory.color("moss").s, "%s: the sedge bleached, not moss-green" % region_id)
		# The fog-coloured ground (Stillhithe, the Foot) is whiter than the fog, not bluer.
		for zone: Dictionary in region["ground"]["paint"]:
			if str(zone.get("note", "")).contains("colour of the fog"):
				var c := PropFactory.color(str(zone["color"]))
				assert_false(_bluish(c), "%s: %s" % [region_id, zone["note"]])
	# Lit, the sky over the mere warms (the burn's payoff) — that blue is meant.
	var lit := db.get_region("heron_mere")["light"]["overrides"] as Array
	assert_eq(str(lit[0].get("sky_top")), "tide", "lit, the sky over the mere opens blue")


func test_the_ladder_is_lashed_tight_to_its_leg() -> void:
	for model: String in ["heron_light.glb", "heron_light_lit.glb", "heron_light_near.glb", "heron_light_near_lit.glb"]:
		var verts := _verts(KIT + model)
		var near := 0
		for v in verts:
			if v.y < 2.0 or v.y > 5.5:
				continue
			var leg := _leg_at(v.y)
			if absf(v.x - leg.x) > 0.2:
				continue
			var out := v.z - leg.z
			assert_false(out > LADDER_OUT + 0.06 and out < 0.32, "%s: nothing stands where the ladder used to (%.2f out at y %.1f)" % [model, out, v.y])
			if absf(out - LADDER_OUT) < 0.05:
				near += 1
		assert_true(near > 40, "%s: the rails and rungs %.2f out from the leg (%d verts)" % [model, LADDER_OUT, near])


func test_the_stage_reaches_the_ladder() -> void:
	var db := load_content()
	var region := db.get_region("heron_mere")
	var heron: Array = (region["props"] as Array).filter(func(p: Dictionary) -> bool: return str(p.get("model", "")).get_file() == "heron_light_near.glb")[0]["position"]
	var pier: Dictionary = (region["ground"]["piers"] as Array)[0]
	var deck := float(pier["deck"]) - float(heron[1])
	var stage_end := float(pier["rect"][1]) - float(heron[2])  # the stage's far (north) end, in the Heron's frame
	var leg := _leg_at(deck)
	var rails := leg.z + LADDER_OUT
	assert_true(stage_end > rails + 0.2, "the stage stops short of the ladder (%.2f vs %.2f): it needs the landing" % [stage_end, rails])
	var gap := AABB(Vector3(leg.x - 0.7, deck - 0.12, rails + 0.04), Vector3(1.4, 0.16, stage_end - rails - 0.06))
	for model: String in ["heron_light_near.glb", "heron_light_near_lit.glb"]:
		var landing := _in(_verts(KIT + model), gap)
		assert_true(landing.size() >= 16, "%s: boards between the stage's end and the ladder (%d verts)" % [model, landing.size()])
		var top := -INF
		for v in landing:
			top = maxf(top, v.y)
		assert_true(absf(top - deck) < 0.03, "%s: the landing flush with the stage (%.3f vs %.3f)" % [model, top, deck])
		# ...and stops short of the rails rather than running through them.
		var into := _in(_verts(KIT + model), AABB(Vector3(leg.x - 0.2, deck - 0.08, leg.z + 0.12), Vector3(0.4, 0.07, rails - leg.z - 0.08)))
		assert_eq(into.size(), 0, "%s: no board under the rails" % model)
		# The cleat on the leg's outer face, a hand above the boards.
		var cleat := AABB(Vector3(leg.x - 0.35, deck + 0.35, leg.z - 0.2), Vector3(0.22, 0.35, 0.4))
		assert_true(_in(_verts(KIT + model), cleat).size() >= 8, "%s: a cleat on the leg by the landing" % model)
	# From the staithe the landing is out of sight: the distance model doesn't carry it.
	var far := _verts(KIT + "heron_light.glb")
	var far_leg := _leg_at(deck)
	assert_eq(_in(far, AABB(Vector3(far_leg.x - 0.45, deck - 0.12, rails + 0.04), Vector3(0.9, 0.16, 0.3))).size(), 0,
			"the distance model stays light")


func test_marias_word_round_the_gulls_neck() -> void:
	var cord := _verts(KIT + "gull_cord.glb")
	assert_true(cord.size() > 0, "the cord's model")
	var neck := AABB(GULL + Vector3(-0.05, 0.0, -0.1), Vector3(0.3, 0.25, 0.2))
	assert_eq(_in(cord, neck).size(), cord.size(), "all of it round the sill gull's neck")
	var db := load_content()
	var props := db.get_region("heron_mere")["props"] as Array
	var lit: Dictionary = props.filter(func(p: Dictionary) -> bool: return str(p.get("model", "")).get_file() == "heron_light_near_lit.glb")[0]
	var on: Array = props.filter(func(p: Dictionary) -> bool: return str(p.get("model", "")).get_file() == "gull_cord.glb")
	assert_eq(on.size(), 1, "the cord placed once")
	assert_eq(on[0]["position"], lit["position"], "in the Heron's own frame, placed where the Heron is")
	for done: bool in [false, true]:
		for word: String in ["mara", "own", "none"]:
			var state := fresh_state(db)
			if done:
				state.complete_quest("a_light_for_glasswater")
			state.flags["fen_dunstan_word"] = word
			assert_eq(Conditions.evaluate(on[0].get("if"), state), done and word == "mara",
					"the cord shows only lit and only for Mara's word (lit %s, word %s)" % [done, word])
	# The art follows the text.
	assert_true(FileAccess.get_file_as_string("res://story/heron_ladder.json").contains("Round its neck, knotted twice, a bit of red cord."),
			"the climb still tells of the cord")
