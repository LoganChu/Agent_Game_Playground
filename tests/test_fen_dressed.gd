extends TestCase
## Day 30 — the fen, dressed (art): the staithe with a whittled gull on every post, a low
## boardwalk for the west walk (no ladder, no bollards), boards laid along the long walk, Corran's
## moored punt and eel-traps, dead alders instead of pines, reed beds, the Unmoored sitting by the
## pools (figure props with the "still" idle), mirror-still fen water, the Heron's skiff readable.

const FEN := "glasswater_fen"
const DIR := "res://assets/models/dressing/"
const CHARS := "res://assets/models/characters/"
## build_fen.BOARDWALK_PILES in Godot space ([x, z]): where the boardwalk's piles stand.
const BOARDWALK_PILES := [[-0.88, -2.4], [0.88, -2.4], [-0.88, -0.8], [0.88, -0.8], [-0.88, 0.8], [0.88, 0.8], [-0.88, 2.4], [0.88, 2.4]]
const DECK_TOP := 0.675

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _region() -> Dictionary:
	return _content().get_region(FEN)


func _field() -> TerrainField:
	var region := _region()
	return TerrainField.from_data(region["ground"], float(region["water_level"]))


func _props(model: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop: Dictionary in _region()["props"]:
		if str(prop.get("model", "")).get_file() == model + ".glb":
			out.append(prop)
	return out


func _bounds(path: String) -> AABB:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	var box := Region.mesh_bounds(node)
	node.free()
	return box


## Distance from p to the segment a-b (x/z).
func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func test_the_staithe_wears_its_gulls() -> void:
	assert_empty(_props("dock"), "the fen borrows no Saltmarrow dock any more")
	var staithe := _props("staithe")
	assert_eq(staithe.size(), 1, "one staithe")
	if staithe.is_empty():
		return
	var at: Array = staithe[0]["position"]
	assert_true(Vector3(float(at[0]), float(at[1]), float(at[2])).is_equal_approx(Vector3(5, -0.4, 11)), "...where the dock stood (pier deck 0.275)")
	assert_eq((staithe[0]["wading"] as Array).size(), 8, "...wading on its eight posts")
	var node := (load(DIR + "staithe.glb") as PackedScene).instantiate() as Node3D
	var deck := false
	var gulls := false
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var box := mi.transform * mi.get_aabb()
		deck = deck or (absf(box.end.y - DECK_TOP) < 0.01 and box.size.z > 5.5)
		# The whittled gulls perch on the post tops, over a hand above the deck.
		gulls = gulls or (box.end.y > DECK_TOP + 0.6 and box.size.y < 0.6 and box.size.z > 5.0)
	assert_true(deck, "the staithe's planks top out at the dock's 0.675")
	assert_true(gulls, "a whittled gull on the posts at both ends")
	node.free()


func test_the_west_walk_is_a_low_boardwalk() -> void:
	var walks := _props("boardwalk")
	assert_eq(walks.size(), 1, "the west walk is the boardwalk")
	if walks.is_empty():
		return
	var walk := walks[0]
	var box := _bounds(DIR + "boardwalk.glb")
	assert_true(box.end.y < DECK_TOP + 0.12, "no ladder, no bollards, no rail: nothing stands over the deck (top %.2f)" % box.end.y)
	assert_true(box.size.z > 5.8 and box.size.z < 6.3 and box.size.x < 2.1, "6 m long, the dock's 2 m wide (%s)" % box.size)
	var pier: Dictionary = {}
	for p: Dictionary in _region()["ground"]["piers"]:
		if float(p["rect"][0]) == -14.0:
			pier = p
	assert_false(pier.is_empty(), "the west walk's pier")
	if not pier.is_empty():
		var rect: Array = pier["rect"]
		assert_true(absf(float(rect[3]) - float(rect[1]) - box.size.x) < 0.15, "the walkable strip matches the planks' width")
	var rings: Array = walk["wading"]
	assert_eq(rings.size(), BOARDWALK_PILES.size(), "foam round every pile")
	for i in rings.size():
		assert_true(Vector2(float(rings[i][0]), float(rings[i][1])).distance_to(Vector2(BOARDWALK_PILES[i][0], BOARDWALK_PILES[i][1])) < 0.01,
			"ring %d sits on its pile" % i)
	var field := _field()
	var reachable := field.reachable_from(5, 12)
	assert_true(field.near_reachable(reachable, -11, -10, 0.6), "the boardwalk is walked over")
	assert_true(field.near_reachable(reachable, -15.8, -10.4, 1.5), "...to the letting post")


func test_the_long_walk_is_boarded_going_in() -> void:
	var boards := _props("plank_path")
	assert_true(boards.size() >= 3, "boards along the long walk (%d)" % boards.size())
	var a := Vector2(0, -15)
	var b := Vector2(-1, -22)
	var c := Vector2(1, -29)
	var deepest := 0.0  # the northernmost board's z
	for board: Dictionary in boards:
		var p := Vector2(float(board["position"][0]), float(board["position"][2]))
		assert_true(minf(_to_segment(p, a, b), _to_segment(p, b, c)) < 0.4, "board at %s lies on the long walk" % p)
		assert_false(board.has("collider"), "boards are walked over, not into")
		deepest = minf(deepest, p.y)
	var areas := Greying.worst_case_areas(_region())
	assert_true(Greying.depth_at(areas, Vector2(0, deepest)) > 0.6, "the boards go on into the Deeps' fog")


func test_corrans_landing() -> void:
	assert_empty(_props("rowboat_upturned"), "the upturned Saltmarrow rowboat is gone")
	var punts := _props("punt")
	assert_eq(punts.size(), 1, "Corran's punt")
	var field := _field()
	var water := float(_region()["water_level"])
	if not punts.is_empty():
		var punt := punts[0]
		assert_true(punt.get("float") is Dictionary and not bool(punt.get("snap", true)), "she floats, moored")
		var pos: Array = punt["position"]
		assert_true(field.height_at(float(pos[0]), float(pos[2])) < water - 0.3, "...in water deep enough to float her")
		assert_true(Vector2(float(pos[0]), float(pos[2])).distance_to(Vector2(13, -6)) < 6.0, "...off his landing")
	var traps := _props("eel_traps")
	assert_eq(traps.size(), 1, "eel-traps on the landing")
	if not traps.is_empty():
		var at: Array = traps[0]["position"]
		assert_true(field.height_at(float(at[0]), float(at[2])) > water, "...on dry ground")
	var box := _bounds(DIR + "punt.glb")
	assert_true(box.size.z > 3.8 and box.size.x < 1.2, "a long narrow fen punt (%s)" % box.size)


func test_the_fen_grows_its_own() -> void:
	assert_empty(_props("pine_snag"), "no pine snags: the fen's trees are alders")
	assert_true(_props("alder_snag").size() >= 5, "dead alders stand about the fen")
	var beds := _props("reed_bed")
	assert_true(beds.size() >= 6, "reed beds along the pools (%d)" % beds.size())
	var field := _field()
	var water := float(_region()["water_level"])
	for bed: Dictionary in beds:
		var at: Array = bed["position"]
		var h := field.height_at(float(at[0]), float(at[2]))
		assert_true(h > water - 0.4 and h < 0.4, "reed bed at %s stands at the water's edge (ground %.2f)" % [at, h])
		assert_false(bed.has("collider"), "reeds are walked through")
	var box := _bounds(DIR + "alder_snag.glb")
	assert_true(box.size.y > 3.0 and box.size.y < 5.0, "an alder ~4 m (%.2f)" % box.size.y)


func test_the_unmoored_sit_by_the_pools() -> void:
	var figures: Array[Dictionary] = []
	for prop: Dictionary in _region()["props"]:
		if prop.has("idle"):
			figures.append(prop)
	assert_true(figures.size() >= 3, "Unmoored sit about Stillhithe (%d)" % figures.size())
	var field := _field()
	var water := float(_region()["water_level"])
	var reachable := field.reachable_from(5, 12)
	var paths: Array = _region()["ground"]["paint"][0]["path"]
	for figure: Dictionary in figures:
		var model := str(figure["model"])
		assert_true(model.begins_with(CHARS + "unmoored_"), "%s is one of the Unmoored" % model)
		assert_eq(str(figure["idle"]), "still", "...sitting still")
		var at := Vector2(float(figure["position"][0]), float(figure["position"][2]))
		assert_true(field.height_at(at.x, at.y) > water, "...on dry ground at %s" % at)
		assert_true(field.near_reachable(reachable, at.x, at.y, 1.5), "...where the player can walk up to them")
		# Facing the water: two metres ahead of them the ground falls toward (or under) the pool.
		var yaw := deg_to_rad(float(figure.get("rotation_y", 0.0)))
		var ahead := at + Vector2(sin(yaw), cos(yaw)) * 2.0
		assert_true(field.height_at(ahead.x, ahead.y) < field.height_at(at.x, at.y), "...facing the water at %s" % at)
		for i in paths.size() - 1:
			var a := Vector2(float(paths[i][0]), float(paths[i][1]))
			var b := Vector2(float(paths[i + 1][0]), float(paths[i + 1][1]))
			assert_true(_to_segment(at, a, b) > 1.2, "...off the trodden way (%s)" % at)
		for who: Dictionary in _region()["npcs"] + _region()["objects"]:
			assert_true(at.distance_to(Vector2(float(who["position"][0]), float(who["position"][2]))) > 2.0, "...out of everyone's way")
		# Built as the region builds it: the model with a rig in the still style.
		var region := Region.new()
		var node := region._build_prop(figure)
		var rig := node.find_child("CharacterRig", true, false) as CharacterRig
		assert_true(rig != null and rig.style == "still", "%s has a rig in the still style" % model)
		assert_true(CharacterRig.find_parts(node).size() == CharacterRig.PARTS.size(), "...and every rig part")
		node.free()
		region.free()


func test_the_still_idle() -> void:
	assert_true(CharacterRig.STYLES.has("still"), "a still idle")
	assert_true(CharacterRig.still_drift(0.0) < 0.01, "head up at the start")
	assert_true(CharacterRig.still_drift(CharacterRig.STILL_PERIOD * 0.5) > 0.99, "down to the water half a cycle on")
	var model := CharacterRig.instantiate(CHARS + "unmoored_shawl.glb", "still")
	var rig := model.find_child("CharacterRig", true, false) as CharacterRig
	rig._ready()  # outside the tree: store the rest poses by hand
	var head := model.find_child("Head", true, false) as Node3D
	var leg := model.find_child("LegL", true, false) as Node3D
	rig.pose(0.0)
	var up := head.transform.basis
	var leg_rest := leg.transform
	rig.pose(CharacterRig.STILL_PERIOD * 0.5)
	assert_true(head.transform.basis.get_euler().x - up.get_euler().x > 0.2, "the head goes down to the water")
	assert_true(leg.transform.is_equal_approx(leg_rest), "the legs stay put on the seat")
	model.free()


func test_mirror_still_water() -> void:
	var spec: Dictionary = _region().get("water", {})
	assert_true(float(spec.get("swell", 1.0)) <= 0.3, "barely a swell")
	assert_eq(float(spec.get("wash", 1.0)), 0.0, "no foam washing in")
	assert_true(float(spec.get("mirror", 0.0)) >= 0.5, "the sky lies on it")
	var mat := WaterBuilder.material(spec)
	assert_true(float(mat.get_shader_parameter("wave_height")) < WaterBuilder.WAVE_HEIGHT * 0.3, "the shader gets the low swell")
	assert_eq(float(mat.get_shader_parameter("wash_strength")), 0.0, "...and no wash")
	assert_true((mat.get_shader_parameter("deep_color") as Color).is_equal_approx(PropFactory.color("ink")), "...and peat-dark water")
	var sea := WaterBuilder.material()
	assert_eq(float(sea.get_shader_parameter("wave_height")), WaterBuilder.WAVE_HEIGHT, "the sea elsewhere keeps its swell")
	assert_eq(float(sea.get_shader_parameter("mirror")), 0.0, "...and no mirror")


func test_the_heron_skiff_reads() -> void:
	# The skiff's bone gunwale and oar: a pale thing at the Heron's feet (the legs are dark silver).
	var node := (load(DIR + "heron_light.glb") as PackedScene).instantiate()
	var pale := false
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi.mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as StandardMaterial3D
			var box := mi.transform * mesh.get_aabb()
			if m and m.albedo_color.get_luminance() > 0.7 and box.end.y < 2.0:
				pale = true
	assert_true(pale, "something pale low down: the skiff")
	node.free()


func test_validator_checks_figures_and_water() -> void:
	var db := load_content()
	var region: Dictionary = db.regions[FEN]
	var props: Array = region["props"]
	props.append({"model": DIR + "punt.glb", "position": [0, 0, 0], "idle": "still"})
	props.append({"model": CHARS + "unmoored_coat.glb", "position": [0, 0, 0], "idle": "dance"})
	region["water"] = {"swell": 5, "ripple": 1, "deep": "plaid"}
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["needs a character model", "prop idle must be one of", "water swell must be a number",
			"water has unknown key 'ripple'", "water deep has unknown color"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)
