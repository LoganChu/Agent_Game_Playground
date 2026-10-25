extends TestCase
## Day 63 — Kindleby's art pass: the candle ring glows from the quay and the sea (a halo on every length
## of wall — a glow, not a light: the light budget), the Quiet House's step candle and the chapter-house's
## step candles carry one too; the chapter-house has an open bell-cote with its bell, a hood over the door
## and candles on both steps; and the island isn't empty: a sister stooped at the south wall with her
## taper to a wick, an old brother bringing a tray of new tallow down the wall.

const BY := "kindleby"
const CAST := "res://assets/models/characters/"
const KIT := "res://assets/models/dressing/"
## The sister's taper tip in her model's space (build_characters.build_keeper_sister: Blender
## (-0.12, -0.98, 0.70) × the 0.98 rig scale, Blender -Y = Godot +Z).
const TAPER_TIP := Vector3(-0.1176, 0.686, 0.9604)

var _db: ContentDatabase


func _region() -> Dictionary:
	if _db == null:
		_db = load_content()
	return _db.get_region(BY)


func _props(model: String) -> Array:
	return (_region()["props"] as Array).filter(func(p: Dictionary) -> bool:
		return str(p["model"]).get_file().get_basename() == model)


func _xz(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[2]))


## A point in a prop's model space, in the region (ground snapping aside).
func _world(prop: Dictionary, local: Vector3) -> Vector3:
	var basis := Basis(Vector3.UP, deg_to_rad(float(prop.get("rotation_y", 0.0))))
	return JsonUtil.to_vector3(prop["position"]) + basis * local


func test_the_candle_ring_glows() -> void:
	var ledges := _props("candle_ledge")
	assert_true(ledges.size() >= 14)
	for ledge: Dictionary in ledges:
		assert_true(ledge.get("halo") is Array, "a halo on the ledge at %s" % [ledge["position"]])
		if not ledge.get("halo") is Array:
			continue
		var at := JsonUtil.to_vector3(ledge["halo"])
		assert_true(at.y > 0.6 and at.y < 1.0, "over the candles, not the stone (%.2f)" % at.y)
		assert_true(float(ledge.get("halo_size", 0.0)) >= 2.0, "wide enough to read along the wall")
		assert_true(float(ledge.get("halo_strength", 0.0)) >= 0.5, "strong enough to read through the fog")
		assert_false(ledge.has("light"), "a glow, not a light (the light budget)")
	for model: String in ["quiet_house", "chapter_house"]:
		var prop: Dictionary = _props(model)[0]
		assert_true(prop.get("halo") is Array, "%s: a halo over its step candles" % model)
		assert_false(prop.has("light"), "%s: no real light" % model)
	# The halos are built: one LanternHalo on each prop that asks for one.
	var region := Region.new()
	var built := 0
	for prop: Dictionary in _region()["props"]:
		if not prop.has("halo"):
			continue
		var node := region._build_prop(prop)
		built += node.find_children("*", "LanternHalo", true, false).size()
		node.free()
	assert_eq(built, ledges.size() + 2, "every halo built")
	region.free()


func test_the_chapter_house_bell_cote() -> void:
	var node := (load(KIT + "chapter_house.glb") as PackedScene).instantiate() as Node3D
	var top := -INF
	var bell_metal := 0
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var box := mi.get_aabb()
		top = maxf(top, (mi.transform * box).end.y)
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m != null and not m.emission_enabled and m.albedo_color.r > m.albedo_color.b * 1.6:
				bell_metal += 1
	# The cote stands clear of the ridge now (5.7 m before Day 63) with its finial over it.
	assert_true(top > 6.2, "the bell-cote rises over the ridge (%.2f m)" % top)
	assert_true(bell_metal > 0, "bronze in the model (the bell, the ember)")
	node.free()


func test_the_keepers_on_the_candles() -> void:
	for who: String in ["keeper_sister", "keeper_brother"]:
		assert_true(ResourceLoader.exists(CAST + who + ".glb"), "%s's model" % who)
		var placed := _props(who)
		assert_eq(placed.size(), 1, "one %s on the wall" % who)
		if placed.is_empty():
			continue
		var fig: Dictionary = placed[0]
		assert_true(str(fig.get("idle", "")) in CharacterRig.STYLES, "%s breathes (a figure, not an NPC)" % who)
		assert_false(fig.has("if"), "%s: there is always someone on the candles" % who)
		assert_true(fig.has("collider"), "%s can't be walked through" % who)
	var region := _region()
	var areas := Greying.worst_case_areas(region)
	var people: Array = []
	for n: Dictionary in region["npcs"]:
		people.append(_xz(n["position"]))
	for o: Dictionary in region["objects"]:
		people.append(_xz(o["position"]))
	for who: String in ["keeper_sister", "keeper_brother"]:
		var at := _xz(_props(who)[0]["position"])
		assert_true(Greying.depth_at(areas, at) < Greying.CLEAR_DEPTH, "%s inside the candles" % who)
		for p: Vector2 in people:
			assert_true(at.distance_to(p) > 2.5, "%s clear of who the player talks to at %s" % [who, p])
	# The sister's taper tip is down among the candles on the wall in front of her.
	var sister: Dictionary = _props("keeper_sister")[0]
	var tip := _world(sister, TAPER_TIP)
	var nearest: Dictionary = {}
	var best := INF
	for ledge: Dictionary in _props("candle_ledge"):
		var d := _xz(ledge["position"]).distance_to(Vector2(tip.x, tip.z))
		if d < best:
			best = d
			nearest = ledge
	var local := Basis(Vector3.UP, deg_to_rad(float(nearest["rotation_y"]))).inverse() * (tip - JsonUtil.to_vector3(nearest["position"]))
	assert_true(absf(local.x) < 1.2 and absf(local.z) < 0.25, "the taper's tip over the wall top (%s)" % local)
	assert_true(local.y > 0.6 and local.y < 0.9, "...among the candles (%.2f)" % local.y)
	# The brother is on his way down the wall: near it, not across it.
	var brother := _xz(_props("keeper_brother")[0]["position"])
	var near_wall := INF
	for ledge: Dictionary in _props("candle_ledge"):
		near_wall = minf(near_wall, brother.distance_to(_xz(ledge["position"])))
	assert_true(near_wall < 3.0, "the brother walks the wall (%.1f m)" % near_wall)


func test_the_embers_cut_over_the_doors_stay_on_them() -> void:
	# Day 62 turned the stone embers 45° where they stood, which swung them round the model's origin:
	# the Vigil Light's hung in the air two metres off its door. Its bronze (the sigil, the finial's ember)
	# is all on the tower's centre line.
	var node := (load(KIT + "vigil_light.glb") as PackedScene).instantiate() as Node3D
	var bronze := 0
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m == null or m.emission_enabled or m.albedo_color.r < m.albedo_color.b * 1.6:
				continue
			var box := mi.transform * mi.get_aabb()
			bronze += 1
			assert_true(absf(box.get_center().x) < 0.3, "the Vigil Light's ember on the door's line (x %.2f)" % box.get_center().x)
	assert_true(bronze > 0, "the Vigil Light has its ember")
	node.free()
