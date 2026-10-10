extends TestCase
## Day 34 — the Heron up close (art): out at the Heron's legs the Heron is the near model (no block
## skiff; the ladder's rungs scraped pale above the slime), the keeper's skiff is her own prop (half
## full of still water, her lantern on its side, the painter made fast to the back leg, the bell on
## her bow only once it's hung back), sedge tussocks under the figures in the fog, and Corran wears
## the knot-cord he counts the channels back on.

const MERE := "heron_mere"
const KIT := "res://assets/models/dressing/"
const CHARS := "res://assets/models/characters/"
## Where the painter meets the leg in the skiff's own frame (Godot axes): build_fen.PAINTER_TO.
const PAINTER_TO := Vector3(1.0, 0.83, 1.43)

var _db: ContentDatabase


func _region() -> Dictionary:
	if _db == null:
		_db = load_content()
	return _db.regions[MERE]


func _props(file: String) -> Array:
	return (_region()["props"] as Array).filter(func(p: Dictionary) -> bool: return str(p["model"]).get_file() == file)


## Every mesh surface in a model: [{"color": Color, "box": AABB}] in the model's frame.
func _surfaces(path: String) -> Array:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	var out := []
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
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
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			out.append({"color": m.albedo_color if m else Color.WHITE, "box": box, "node": mi.name})
	node.free()
	return out


func _bounds(surfaces: Array) -> AABB:
	var box: AABB = surfaces[0]["box"]
	for s: Dictionary in surfaces:
		box = box.merge(s["box"])
	return box


## The leg the skiff is tied to (the model's back-right leg) at height `y`, in the region.
func _leg_at(heron: Dictionary, y: float) -> Vector2:
	var at := JsonUtil.to_vector3(heron["position"])
	var t := (y - at.y) / 6.2
	var half := 1.6 + (1.15 - 1.6) * t
	return Vector2(at.x + half, at.z - half)


func test_the_mere_has_the_near_heron() -> void:
	var near := _props("heron_light_near.glb")
	assert_eq(near.size(), 1, "the Heron up close")
	assert_eq(_props("heron_light.glb").size(), 0, "...not the distance model with its block skiff")
	var fen: Array = (_db.regions["glasswater_fen"]["props"] as Array).filter(
			func(p: Dictionary) -> bool: return str(p["model"]).get_file() == "heron_light.glb")
	assert_eq(fen.size(), 1, "the fen still sees the distance model")
	var far_box := _bounds(_surfaces(KIT + "heron_light.glb"))
	var near_box := _bounds(_surfaces(KIT + "heron_light_near.glb"))
	assert_true(far_box.end.x > 3.0, "the distance model carries the skiff (%.1f)" % far_box.end.x)
	assert_true(near_box.end.x < 2.0, "the near model doesn't (%.1f)" % near_box.end.x)
	assert_true(absf(near_box.size.y - far_box.size.y) < 0.05, "same Heron otherwise")


func test_the_rungs_are_scraped_pale_above_the_slime() -> void:
	# The ladder is up the front-left leg (Godot -X, +Z); its rungs are the only moss and bone on it
	# (meshes are merged by material and named for it). The moss ones are the lowest four; the pale
	# middles start above them.
	var surfaces := _surfaces(KIT + "heron_light_near.glb")
	var slime := surfaces.filter(func(s: Dictionary) -> bool: return str(s["node"]).begins_with("moss"))
	assert_eq(slime.size(), 1, "one slime-green surface: the low rungs")
	var low: AABB = slime[0]["box"]
	assert_true(low.position.x < -0.9 and low.end.z > 1.2, "on the ladder leg")
	var worn := surfaces.filter(func(s: Dictionary) -> bool: return str(s["node"]).begins_with("bone"))
	assert_eq(worn.size(), 1, "one pale surface: the worn middles")
	var pale: AABB = worn[0]["box"]
	assert_true(pale.end.x < -0.5 and pale.position.z > 0.5, "on the ladder leg")
	assert_true((worn[0]["color"] as Color).get_luminance() > 0.6, "pale")
	assert_true(pale.position.y > low.end.y - 0.05, "worn above the slime, not in it (%.2f vs %.2f)" % [pale.position.y, low.end.y])
	assert_true(pale.end.y > 5.0, "...all the way up")
	assert_true(pale.size.x < 0.6, "only the middles, where boots go (%.2f m wide)" % pale.size.x)


func test_the_keepers_skiff_by_bell_state() -> void:
	var plain := _props("keeper_skiff.glb")
	var belled := _props("keeper_skiff_bell.glb")
	assert_eq(plain.size(), 1)
	assert_eq(belled.size(), 1)
	assert_eq(plain[0]["position"], belled[0]["position"], "one skiff, two states")
	assert_eq(plain[0]["rotation_y"], belled[0]["rotation_y"])
	var state := fresh_state(_db)
	for value: String in ["", "kept", "hung"]:
		state.set_flag("fen_skiff_bell", value)
		var shown := [Conditions.evaluate(plain[0]["if"], state), Conditions.evaluate(belled[0]["if"], state)]
		assert_eq(shown, [value != "hung", value == "hung"], "bell %s: %s" % [value if value else "undecided", shown])
	# The bell model has one more thing than the plain one: a little brass bell at the bow (+Z).
	var is_brass := func(s: Dictionary) -> bool: return str(s["node"]).begins_with("ember")
	var brass := _surfaces(KIT + "keeper_skiff_bell.glb").filter(is_brass)
	assert_eq(brass.size(), 1, "a brass bell")
	assert_true((brass[0]["box"] as AABB).get_center().z > 1.1, "...at her bow")
	assert_true((brass[0]["box"] as AABB).size.y < 0.2, "...a little one")
	assert_eq(_surfaces(KIT + "keeper_skiff.glb").filter(is_brass).size(), 0, "none on the bare bow")


func test_the_skiff_is_tied_to_the_leg_and_sits_low() -> void:
	var skiff: Dictionary = _props("keeper_skiff.glb")[0]
	var heron: Dictionary = _props("heron_light_near.glb")[0]
	assert_false(skiff.get("snap", true), "placed at an absolute height on the water")
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(skiff["rotation_y"]))), JsonUtil.to_vector3(skiff["position"]))
	# The painter's end lands on the back-right leg (r 0.14) at its height.
	var end := xf * PAINTER_TO
	var leg := _leg_at(heron, end.y)
	var miss := Vector2(end.x, end.z).distance_to(leg)
	assert_true(miss < 0.14, "the painter is made fast to the leg (%.2f m off its axis)" % miss)
	var surfaces := _surfaces(KIT + "keeper_skiff.glb")
	var box := _bounds(surfaces)
	assert_true(box.end.x > PAINTER_TO.x - 0.05 and box.end.y > PAINTER_TO.y - 0.05, "the model's painter reaches that far")
	# Half full: the water in her lies about level with the mere's.
	var water_level := float(_region()["water_level"])
	var flat := surfaces.filter(func(s: Dictionary) -> bool:
		var b: AABB = s["box"]
		return b.size.y < 0.06 and b.size.x > 0.4 and b.size.z > 1.5)
	assert_eq(flat.size(), 1, "the water in her")
	var bilge := (xf * (flat[0]["box"] as AABB)).end.y
	assert_true(absf(bilge - water_level) < 0.1, "half full, at the mere's level (%.2f vs %.2f)" % [bilge, water_level])
	assert_true((xf * box).position.y < water_level, "her bottom is in the water")
	# By the mud bar's end, where her look-at is; clear of the leg itself.
	var look: Dictionary = (_region()["objects"] as Array).filter(func(o: Dictionary) -> bool: return o["id"] == "heron_skiff")[0]
	var centre := Vector2(xf.origin.x, xf.origin.z)
	assert_true(centre.distance_to(Vector2(look["position"][0], look["position"][2])) < 3.0, "by her look-at")
	assert_true(centre.distance_to(_leg_at(heron, water_level)) > 1.0, "not through the leg")


func test_tussocks_under_the_figures_in_the_fog() -> void:
	var tussocks := _props("tussock.glb")
	var figures := (_region()["props"] as Array).filter(func(p: Dictionary) -> bool: return p.has("idle"))
	assert_true(figures.size() >= 4, "the big man and the Unmoored")
	for figure: Dictionary in figures:
		var at := JsonUtil.to_vector3(figure["position"])
		var under := tussocks.filter(func(t: Dictionary) -> bool:
			var p := JsonUtil.to_vector3(t["position"])
			return Vector2(p.x, p.z).distance_to(Vector2(at.x, at.z)) < 0.5)
		assert_eq(under.size(), 1, "%s stands on a tussock" % figure["model"].get_file())
	var box := _bounds(_surfaces(KIT + "tussock.glb"))
	assert_true(box.size.x > 1.2 and box.size.x < 2.4 and box.size.y < 0.8, "a low mound of sedge %s" % box)
	# The middle is low enough to stand in: only the sedge ring (spread round the rim) stands up.
	for s: Dictionary in _surfaces(KIT + "tussock.glb"):
		var b: AABB = s["box"]
		if b.end.y > 0.12:
			assert_true(b.size.x + b.size.z > 1.6, "only the sedge ring stands up (%s)" % b)


func test_corran_wears_his_knot_cord() -> void:
	# A short cord at the front of his left hip, hanging below the belt, knots on it.
	var found := false
	for s: Dictionary in _surfaces(CHARS + "corran.glb"):
		var b: AABB = s["box"]
		if str(s["node"]).begins_with("Torso") and b.position.z > 0.2 and b.size.x < 0.15 and b.size.y > 0.25 and b.get_center().x > 0.1:
			found = true
	assert_true(found, "the knot-cord hangs at the front of his left hip")
