extends TestCase
## Day 28 — the Ridge Light, lit (art): the lit tower's horn panes show the fire in the cradle and
## the rack's one lantern burns; a wide halo with a bloom so the light reads from the woods; Hob
## seated on the camp bench by the tally-house step (`hob_seated`, the "sit" idle) through a
## placement's own `model`/`idle`; the split-log bench.

const LANDING := "thornwold_landing"
const WOODS := "thornwold_woods"
const RIDGE := "thornwold_ridge"
const DRESSING := "res://assets/models/dressing/"
const SEATED := "res://assets/models/characters/hob_seated.glb"
const LIT := "quest:a_light_for_thornwold=done"

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lit_tower(region_id: String) -> Dictionary:
	for prop: Dictionary in _content().get_region(region_id)["props"]:
		if str(prop.get("model", "")) == DRESSING + "thornwold_beacon_lit.glb":
			return prop
	return {}


## Every material in a model, by surface.
func _materials(path: String) -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = []
	var node := (load(path) as PackedScene).instantiate()
	for mesh_node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mesh_node as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i) as StandardMaterial3D
			if material:
				out.append(material)
	node.free()
	return out


## Lit, the horn is see-through and glowing with fire behind it (emissive coals, tongues and a
## heart, the rack lantern); cold, nothing is see-through and nothing in the cage glows.
func test_lit_tower_shows_its_fire() -> void:
	var lit := _materials(DRESSING + "thornwold_beacon_lit.glb")
	var horn := lit.filter(func(m: StandardMaterial3D) -> bool: return m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED)
	assert_eq(horn.size(), 1, "one see-through material: the horn panes")
	if horn.size() == 1:
		var pane: StandardMaterial3D = horn[0]
		assert_true(pane.albedo_color.a > 0.15 and pane.albedo_color.a < 0.6, "the horn lets the fire show (alpha %s)" % pane.albedo_color.a)
		assert_true(pane.emission_enabled, "and glows faintly itself")
	var glowing := lit.filter(func(m: StandardMaterial3D) -> bool: return m.emission_enabled and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
	assert_true(glowing.size() >= 3, "coals, tongues and the heart glow (%d)" % glowing.size())
	var cold := _materials(DRESSING + "thornwold_beacon.glb")
	assert_true(cold.all(func(m: StandardMaterial3D) -> bool: return m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not m.emission_enabled),
		"the cold tower: dark, opaque horn and no fire")


## The lit tower reads from the woods: a big halo with a bloom (the fog lit round it) on the woods'
## skyline, a smaller one at the cage on the ridge beside the real light.
func test_the_light_reads_from_afar() -> void:
	var woods := _lit_tower(WOODS)
	var ridge := _lit_tower(RIDGE)
	assert_eq(str(woods.get("if", "")), LIT)
	assert_eq(str(ridge.get("if", "")), LIT)
	assert_true(float(woods.get("halo_size", 0)) >= 10.0, "a wide halo on the woods' skyline")
	assert_true(float(woods.get("halo_bloom", 0)) > 0.0, "with a bloom")
	assert_false(woods.has("light"), "no light spent on the far view")
	assert_true(ridge.get("halo") is Array and ridge.has("light"), "on the ridge a halo and the beacon's light")
	for prop: Dictionary in [woods, ridge]:
		var y := float((prop["halo"] as Array)[1])
		assert_true(y > 6.1 and y < 7.5, "the halo hangs in the lantern cage")
	var halo := LanternHalo.build(Vector3(0, 6.85, 0), 14.0, 1.0, 0.35)
	var material := halo.material_override as ShaderMaterial
	assert_eq((halo.mesh as QuadMesh).size, Vector2(14, 14))
	assert_eq(float(material.get_shader_parameter("strength")), 1.0)
	assert_eq(float(material.get_shader_parameter("bloom")), 0.35)
	halo.free()
	var plain := LanternHalo.build(Vector3.ZERO)
	assert_eq(float((plain.material_override as ShaderMaterial).get_shader_parameter("bloom")), 0.0, "lanterns keep no bloom")
	plain.free()


## Every lit lantern post (Saltmarrow's, the landing's) carries a halo at its glass too.
func test_lantern_posts_have_halos() -> void:
	var posts := 0
	for region_id: String in _content().regions:
		for prop: Dictionary in _content().get_region(region_id).get("props", []):
			if str(prop.get("model", "")) == DRESSING + "lantern_post.glb":
				posts += 1
				assert_true(prop.get("halo") is Array and JsonUtil.to_vector3(prop["halo"]).is_equal_approx(Vector3(0, 1.85, 0.58)), "lantern post at %s in %s has a halo at its glass" % [prop["position"], region_id])
	assert_true(posts >= 3, "Saltmarrow's two posts and the landing's")


## A placement's own `model` and `idle` pose the NPC for that spot only.
func test_placement_overrides_the_pose() -> void:
	var hob: Dictionary = _content().npcs["hob"]
	var placed := Region.placed_npc_data(hob, {"npc": "hob", "model": SEATED, "idle": "sit"})
	assert_eq(str(placed["model"]), SEATED)
	assert_eq(str(placed["idle"]), "sit")
	assert_eq(str(placed["name"]), "Hob Marl", "the rest of the NPC stays")
	assert_eq(str(hob["idle"]), "rake", "the NPC itself is untouched")
	assert_eq(Region.placed_npc_data(hob, {"npc": "hob"}), hob, "no override, no change")


## Hob comes in and sits: on the bench by the tally-house step, seated, rake across his knees.
func test_hob_sits_on_the_bench() -> void:
	var region := _content().get_region(LANDING)
	var at_camp: Array[Dictionary] = []
	for placement: Dictionary in region["npcs"]:
		if str(placement.get("npc", "")) == "hob":
			at_camp.append(placement)
	assert_eq(at_camp.size(), 1, "Hob has one place at the camp")
	var hob: Dictionary = at_camp[0]
	assert_eq(str(hob.get("if", "")), "flag:thornwold_hob_came_in")
	assert_eq(str(hob.get("model", "")), SEATED)
	assert_eq(str(hob.get("idle", "")), "sit")
	var bench: Dictionary = {}
	for prop: Dictionary in region["props"]:
		if str(prop.get("model", "")) == DRESSING + "log_bench.glb":
			bench = prop
	assert_false(bench.is_empty(), "the bench is at the camp")
	assert_eq(bench.get("position"), hob.get("position"), "Hob sits on it")
	assert_eq(float(bench.get("rotation_y", 0)), float(hob.get("rotation_y", 0)), "facing the way the bench faces")
	# The bench's seat is a seated model's seat height (build_characters.Body: hip 0.46).
	var node := (load(DRESSING + "log_bench.glb") as PackedScene).instantiate() as Node3D
	var bounds := Region.mesh_bounds(node)
	node.free()
	assert_true(absf(bounds.end.y - 0.44) < 0.03, "seat top at 0.44 m (got %.2f)" % bounds.end.y)
	assert_true(bounds.size.x > 1.1 and bounds.size.x < 1.5, "a bench for one or two")
	# The tally house is just behind him: the bench is by its step, not out in the yard.
	var house: Dictionary = {}
	for prop: Dictionary in region["props"]:
		if str(prop.get("model", "")) == DRESSING + "tally_house.glb":
			house = prop
	var d := Vector2(float(hob["position"][0]), float(hob["position"][2])).distance_to(
		Vector2(float(house["position"][0]), float(house["position"][2])))
	assert_true(d > 2.2 and d < 3.2, "by the tally-house step (%.1f m)" % d)


## The "sit" idle: awake and breathing most of the time; once a cycle the head sinks as he dozes,
## holds, and comes up with a start.
func test_the_sit_idle_dozes() -> void:
	assert_true("sit" in CharacterRig.STYLES)
	assert_eq(CharacterRig.sit_doze(1.0), 0.0, "awake")
	var deepest := 0.0
	var at := 0.0
	for i in int(CharacterRig.DOZE_PERIOD * 50.0):
		var t := i * 0.02
		if CharacterRig.sit_doze(t) > deepest:
			deepest = CharacterRig.sit_doze(t)
			at = t
	assert_true(deepest > 0.95, "nods right off")
	var started := 0.0
	for i in 100:
		started = maxf(started, CharacterRig.sit_start(at + i * 0.03))
	assert_true(started > 0.9, "and wakes with a start")
	assert_eq(CharacterRig.sit_doze(at + CharacterRig.DOZE_PERIOD), CharacterRig.sit_doze(at), "every cycle")

	var model := CharacterRig.instantiate(SEATED, "sit")
	var rig := model.get_node("CharacterRig") as CharacterRig
	rig._ready()
	var head := model.find_child("Head", true, false) as Node3D
	var leg := model.find_child("LegL", true, false) as Node3D
	var rake := model.find_child("Stool", true, false) as Node3D
	assert_true(rake != null, "the rake across his knees is a static extra")
	var leg_rest := leg.transform
	rig.pose(1.0)
	var awake := head.transform.basis.z
	rig.pose(at)
	assert_true(head.transform.basis.z.angle_to(awake) > 0.25, "the head sinks")
	assert_true(head.transform.basis.z.y < awake.y, "chin down")
	assert_true(leg.transform.is_equal_approx(leg_rest), "the legs stay put")
	rig.pose(1.0, 2.0, 1.0)  # even if something asked it to walk
	assert_true(leg.transform.is_equal_approx(leg_rest), "a sitter doesn't swing his legs")
	model.free()


func test_validator_checks_placement_poses_and_halo_numbers() -> void:
	var db := load_content()
	var npcs: Array = db.regions[LANDING]["npcs"]
	npcs.append({"npc": "bram", "position": [0, 0, 0], "if": "flag:thornwold_landed", "idle": "dance"})
	npcs.append({"npc": "bram", "position": [1, 0, 0], "if": "flag:thornwold_landed", "model": "res://nope.glb"})
	var props: Array = db.regions[RIDGE]["props"]
	props.append({"model": DRESSING + "waymark_lit.glb", "position": [0, 0, 0], "halo": [0, 1, 0], "halo_bloom": 3})
	props.append({"model": DRESSING + "waymark_lit.glb", "position": [0, 0, 0], "halo": [0, 1, 0], "halo_strength": "x"})
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["placement idle must be one of", "res://nope.glb", "'halo_bloom' must be a number in 0..2",
			"'halo_strength' must be a number in 0..2"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)
