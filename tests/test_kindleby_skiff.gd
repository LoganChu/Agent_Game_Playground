extends TestCase
## Day 67 — Kindleby's skiff gets her own model (she borrowed the Heron's drowned one: half full of water,
## its painter climbing 1.4 m into the air toward a fen leg that isn't on Kindleby's shingle). At the
## Northing's stage her bow lantern is lit (a halo), the painter lies over the kerb to the stage's ring and
## the stern line runs up to Sister Pim's hands; Pim leans back on it, and Sister Hild has a model of her own.
## And on Saltmarrow, once Dunstan is home teaching Pell to whittle, Pell's first gull sits on a crate.

const SHORE := "thornwold_far_shore"
const BY := "kindleby"
const CAST := "res://assets/models/characters/"
const KIT := "res://assets/models/dressing/"
## Pim's leading hand (build_characters.PIM_LINE_HAND, Blender (-0.04, -0.42, 0.86) × the 0.98 rig scale).
const PIM_HAND := Vector3(-0.0392, 0.8428, 0.4116)
## The boat-stage's mooring ring in its model's space (build_old_road.build_boat_stage: Blender (0.55, 0.24, 0.32)).
const RING := Vector3(0.55, 0.32, -0.24)
## What build_kindleby.py builds the stage skiff's lines against: move these props and rebuild it.
const SKIFF_AT := Vector3(5.5, -0.5, -11.6)
const PIM_AT := Vector2(7.1, -10.2)
const STAGE_DECK := 0.7

var _db: ContentDatabase


func _props(region: String, model: String) -> Array:
	if _db == null:
		_db = load_content()
	return (_db.get_region(region)["props"] as Array).filter(func(p: Dictionary) -> bool:
		return str(p["model"]).get_file().get_basename() == model)


func _world(prop: Dictionary, local: Vector3, y := NAN) -> Vector3:
	var at := JsonUtil.to_vector3(prop["position"])
	if not is_nan(y):
		at.y = y
	return at + Basis(Vector3.UP, deg_to_rad(float(prop.get("rotation_y", 0.0)))) * local


## Every vertex of a model, in its own space.
func _points(path: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	var node := (load(path) as PackedScene).instantiate() as Node3D
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
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


func _emissive_boxes(path: String) -> Array[AABB]:
	var out: Array[AABB] = []
	var node := (load(path) as PackedScene).instantiate() as Node3D
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m != null and m.emission_enabled:
				out.append(mi.transform * mi.get_aabb())
	node.free()
	return out


func test_kindleby_has_its_own_skiff() -> void:
	assert_eq(_props(BY, "keeper_skiff").size(), 0, "the Heron's drowned skiff isn't Kindleby's")
	assert_eq(_props(BY, "kindleby_skiff").size(), 2, "drawn up on the shingle, before and after the run north")
	var top := -INF
	for p in _points(KIT + "kindleby_skiff.glb"):
		top = maxf(top, p.y)
	assert_true(top < 1.1, "nothing climbs out of her into the air (%.2f m)" % top)
	assert_true(_emissive_boxes(KIT + "kindleby_skiff.glb").is_empty(), "her lantern is cold on the shingle")


func test_the_skiff_at_the_stage() -> void:
	var placed := _props(SHORE, "kindleby_skiff_stage")
	assert_eq(placed.size(), 1)
	assert_eq(_props(SHORE, "keeper_skiff").size(), 0)
	if placed.is_empty():
		return
	var skiff: Dictionary = placed[0]
	assert_eq(JsonUtil.to_vector3(skiff["position"]), SKIFF_AT, "where build_kindleby.py builds her lines")
	assert_eq(float(skiff["rotation_y"]), 180.0)
	# The bow lantern is lit and its halo sits in the glass.
	assert_true(skiff.get("halo") is Array, "a halo at her bow lantern")
	var boxes := _emissive_boxes(KIT + "kindleby_skiff_stage.glb")
	assert_eq(boxes.size(), 1, "one lit lantern")
	if skiff.get("halo") is Array and boxes.size() == 1:
		assert_true(boxes[0].grow(0.02).has_point(JsonUtil.to_vector3(skiff["halo"])), "the halo in the panes")
	assert_false(skiff.has("light"), "a glow, not a light (the light budget)")
	# The painter reaches the stage's ring; the stern line reaches Pim's hand.
	var points := _points(KIT + "kindleby_skiff_stage.glb")
	var stage: Dictionary = _props(SHORE, "boat_stage")[0]
	var ring := _world(stage, RING)
	var ring_local := Basis(Vector3.UP, PI).inverse() * (ring - SKIFF_AT)
	assert_true(_nearest(points, ring_local) < 0.06, "the painter on the ring (%.2f m off)" % _nearest(points, ring_local))
	var pim: Dictionary = _props(SHORE, "keeper_pim")[0]
	assert_eq(_xz(pim["position"]), PIM_AT, "Pim where the line was built to")
	var hand := _world(pim, PIM_HAND, STAGE_DECK)
	var hand_local := Basis(Vector3.UP, PI).inverse() * (hand - SKIFF_AT)
	assert_true(_nearest(points, hand_local) < 0.06, "the stern line in Pim's hand (%.2f m off)" % _nearest(points, hand_local))
	assert_true(_nearest(_points(CAST + "keeper_pim.glb"), PIM_HAND) < 0.1, "Pim's hand is where the line ends")


func test_the_stage_deck_height() -> void:
	# Pim stands on the region's ground; the line was built to a deck at STAGE_DECK.
	var field := TerrainField.from_data(load_content().get_region(SHORE)["ground"])
	var deck := field.height_at(PIM_AT.x, PIM_AT.y)
	assert_true(absf(deck - STAGE_DECK) < 0.05, "the stage deck at %.2f" % deck)


func test_hild_and_pim() -> void:
	if _db == null:
		_db = load_content()
	assert_eq(str(_db.npcs["hild"]["model"]), CAST + "hild.glb", "Hild has her own model")
	var hild := CharacterRig.instantiate(CAST + "hild.glb")
	assert_true(hild.find_child("Stool", true, false) != null, "her oar stands beside her (a static extra)")
	hild.free()
	# Back on Kindleby she stands on the shingle by the skiff (Day 66 put her knee-deep in the sea).
	var field := TerrainField.from_data(_db.get_region(BY)["ground"])
	for placed: Dictionary in _db.get_region(BY)["npcs"]:
		if placed["npc"] == "hild":
			var at := _xz(placed["position"])
			assert_true(field.height_at(at.x, at.y) > 0.1, "Hild out of the wet (%.2f)" % field.height_at(at.x, at.y))
	var pim: Dictionary = _props(SHORE, "keeper_pim")[0]
	assert_eq(str(pim.get("idle", "")), "breathe", "Pim breathes (her hands barely move on the line)")


func test_pells_gull_on_the_crate() -> void:
	var gulls := _props("saltmarrow", "pell_gull")
	assert_eq(gulls.size(), 1)
	if gulls.is_empty():
		return
	var gull: Dictionary = gulls[0]
	var crate: Dictionary = {}
	for c: Dictionary in _props("saltmarrow", "crate"):
		if c["position"] == gull["position"]:
			crate = c
	assert_false(crate.is_empty(), "modelled on a crate's lid: placed where the crate is")
	assert_eq(float(crate.get("scale", 1.0)), 1.0, "a full-size crate (the lid at 0.8 m)")
	var low := INF
	for p in _points(KIT + "pell_gull.glb"):
		low = minf(low, p.y)
	assert_true(absf(low - 0.8) < 0.03, "sitting on the lid (%.2f)" % low)
	var state := WorldState.new()
	state.set_flag("saltmarrow_ferry_arrived", true)
	assert_false(Conditions.evaluate(gull["if"], state), "not before Dunstan is home")
	state.set_flag("fen_dunstan_walk", "home")
	assert_true(Conditions.evaluate(gull["if"], state), "Dunstan home, Pell on Saltmarrow")
	state.set_flag("thornwold_pell_landed", true)
	assert_false(Conditions.evaluate(gull["if"], state), "not while Pell's away on Thornwold")


func _xz(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[2]))
