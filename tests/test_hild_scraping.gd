extends TestCase
## Day 71 — Sister Hild at work: back on Kindleby's shingle from the Northing's stage she no longer just
## stands by the skiff with an oar; she's stooped at its bow with a long-handled scraper taking the weed off
## the strakes (`hild_scraping`), in a new "scrape" idle — sets of strokes, a breather to look at the work —
## and she puts the work down and straightens up while she talks.

const BY := "kindleby"
const CAST := "res://assets/models/characters/"
const KIT := "res://assets/models/dressing/"
## The scraper's edge (build_characters.HILD_SCRAPER_EDGE, Blender (0.21, -0.95, 0.44)) in Godot model space.
const EDGE := Vector3(0.21, 0.44, 0.95)

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _hild_at_home() -> Dictionary:
	for placed: Dictionary in _content().get_region(BY)["npcs"]:
		if placed["npc"] == "hild":
			return placed
	return {}


func _xform(entry: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(entry.get("rotation_y", 0.0)))), JsonUtil.to_vector3(entry["position"]))


## Every vertex of a model (or of one `part` of it) in its own space, each part's rest transform applied.
func _points(path: String, part := "") -> PackedVector3Array:
	var out := PackedVector3Array()
	var node := (load(path) as PackedScene).instantiate() as Node3D
	var root: Node = node if part.is_empty() else node.find_child(part, true, false)
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for mi: MeshInstance3D in meshes:
		var xf := mi.transform
		var up := mi.get_parent() as Node3D
		while up != null and up != node:
			xf = up.transform * xf
			up = up.get_parent() as Node3D
		for s in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				out.append(xf * v)
	node.free()
	return out


func _nearest(points: PackedVector3Array, to: Vector3) -> float:
	var best := INF
	for p in points:
		best = minf(best, p.distance_to(to))
	return best


func test_the_scrape_idle() -> void:
	assert_true(CharacterRig.STYLES.has("scrape"), "a scrape idle")
	var p := CharacterRig.SCRAPE_PERIOD
	assert_true(CharacterRig.scrape_stroke(0.0) < 0.01, "a stroke starts drawn back")
	assert_true(CharacterRig.scrape_stroke(p * 0.65) > 0.99, "pushed home two-thirds through")
	assert_true(CharacterRig.scrape_stroke(p * 0.99) < 0.05, "and drawn back by the end")
	var breather := p * CharacterRig.SCRAPE_SET + CharacterRig.SCRAPE_BREATHER * 0.5
	assert_true(CharacterRig.scrape_stroke(breather) == 0.0, "no strokes in the breather")
	assert_true(CharacterRig.scrape_breather(breather) > 0.99, "straightened up in the middle of it")
	assert_true(CharacterRig.scrape_breather(p * 2.3) == 0.0, "bent to the work between breathers")

	var model := CharacterRig.instantiate(CAST + "hild_scraping.glb", "scrape")
	var rig := model.find_child("CharacterRig", true, false) as CharacterRig
	rig._ready()  # outside the tree: store the rest poses by hand
	var arm := model.find_child("ArmR", true, false) as Node3D
	var torso := model.find_child("Torso", true, false) as Node3D
	var leg := model.find_child("LegL", true, false) as Node3D
	rig.pose(0.0)
	var back := arm.transform.basis.get_euler().x
	var bent := torso.transform.basis.get_euler().x
	var leg_rest := leg.transform
	rig.pose(p * 0.65)
	assert_true(back - arm.transform.basis.get_euler().x > 0.15, "the arms push the scraper along")
	assert_true(leg.transform.is_equal_approx(leg_rest), "the feet stay planted")
	rig.pose(breather)
	assert_true(bent - torso.transform.basis.get_euler().x > 0.25, "the back comes up for the breather")
	# Resting (talking): no strokes, and straightened up.
	rig.rest = 1.0
	rig.pose(0.0)
	var still := arm.transform.basis.get_euler().x
	assert_true(bent - torso.transform.basis.get_euler().x > 0.25, "straightened up to talk")
	rig.pose(p * 0.65)
	assert_true(absf(arm.transform.basis.get_euler().x - still) < 0.01, "the work put down while she talks")
	model.free()


func test_resting_eases_in_and_out() -> void:
	var model := CharacterRig.instantiate(CAST + "hild_scraping.glb", "scrape")
	var rig := model.find_child("CharacterRig", true, false) as CharacterRig
	rig._ready()
	rig.resting = true
	rig._process(0.1)
	assert_true(rig.rest > 0.0 and rig.rest < 1.0, "the work goes down over a moment, not at once")
	for i in 30:
		rig._process(0.1)
	assert_eq(rig.rest, 1.0, "down")
	rig.resting = false
	for i in 30:
		rig._process(0.1)
	assert_eq(rig.rest, 0.0, "back to it")
	model.free()


func test_hild_at_the_skiff() -> void:
	var placed := _hild_at_home()
	assert_false(placed.is_empty(), "Hild placed on Kindleby")
	if placed.is_empty():
		return
	assert_eq(str(placed.get("model", "")), CAST + "hild_scraping.glb", "at work on the skiff")
	assert_eq(str(placed.get("idle", "")), "scrape")
	assert_eq(str(_content().npcs["hild"]["model"]), CAST + "hild.glb", "elsewhere (the far shore) she keeps her oar")
	for far: Dictionary in _content().get_region("thornwold_far_shore")["npcs"]:
		if far["npc"] == "hild":
			assert_false(far.has("model"), "at the stage she's waiting, not working")
	# The scraper is carried by the right arm (it moves with the strokes), out to the edge.
	var arm := _points(CAST + "hild_scraping.glb", "ArmR")
	assert_true(_nearest(arm, EDGE) < 0.05, "the right arm holds the scraper's edge (%.3f)" % _nearest(arm, EDGE))
	# Placed so the edge meets the skiff's hull (the drawn-up skiff she came home in).
	var skiff: Dictionary = {}
	for prop: Dictionary in _content().get_region(BY)["props"]:
		if str(prop["model"]).get_file() == "kindleby_skiff.glb" and str(prop.get("if", "")).contains("kindleby_skiff_north"):
			skiff = prop
	assert_false(skiff.is_empty(), "the skiff back on the shingle")
	if skiff.is_empty():
		return
	assert_eq(skiff["if"], placed["if"], "she's there exactly when the skiff is")
	var edge := _xform(skiff).affine_inverse() * (_xform(placed) * EDGE)
	var hull := _points(KIT + "kindleby_skiff.glb")
	var gap := _nearest(hull, edge)
	assert_true(gap < 0.2, "the scraper on the hull, not in the air (%.2f m off)" % gap)
	# Stooped, she's out of everyone's way and out of the wet.
	var field := TerrainField.from_data(_content().get_region(BY)["ground"])
	var at := JsonUtil.to_vector3(placed["position"])
	assert_true(field.height_at(at.x, at.z) > float(_content().get_region(BY).get("water_level", 0.0)) + 0.1,
		"on the shingle, not in the sea")
	for other: Dictionary in _content().get_region(BY)["npcs"]:
		if other != placed and other["npc"] != "hild":  # her other placement (Day 72: the skiff never went north) is the same spot
			var there := JsonUtil.to_vector3(other["position"])
			assert_true(Vector2(at.x, at.z).distance_to(Vector2(there.x, there.z)) > 1.2, "clear of %s" % other["npc"])


func test_puts_the_work_down_to_talk() -> void:
	var placed := _hild_at_home()
	var actor := NpcActor.new()
	actor.setup("hild", Region.placed_npc_data(_content().get_npc("hild"), placed))
	actor._build_body()
	var rig := actor._rig
	assert_true(rig != null and rig.style == "scrape", "the actor keeps her rig")
	if rig == null:
		actor.free()
		return
	var was := GameState.input_locked
	actor._talking = true  # as face() sets it when the player starts the conversation (needs the tree)
	GameState.input_locked = true
	actor._process(0.05)
	assert_true(rig.resting, "talking: the scraper goes down")
	GameState.input_locked = false
	actor._process(0.05)
	assert_false(rig.resting, "the dialogue closed: back to work")
	GameState.input_locked = was
	actor.free()
