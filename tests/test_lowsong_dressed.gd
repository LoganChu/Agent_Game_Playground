extends TestCase
## Day 76 — Lowsong dressed (art): Brother Iver's lamp reads through the fog (an NPC `halo` on the lit horn
## of a held lantern, moving with the arm; Hob's and Wenna's lanterns too), a thread of peat smoke from the
## bothy, sea stacks stood up out of the deeper water round the field, the cairns weeded, the fog's light
## casting faint shadows (a region light `shadow`), and Hild's oars heard on every rowing out and back.

const KIT := "res://assets/models/dressing/"
## build_lowsong.py's BOTHY_SMOKE: where the bothy chimney lets out its smoke (model space).
const BOTHY_SMOKE := Vector3(1.0, 2.7, -2.5)

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _region() -> Dictionary:
	return _content().get_region("lowsong")


func _props(model: String) -> Array:
	return (_region()["props"] as Array).filter(func(p: Dictionary) -> bool: return str(p.get("model", "")).ends_with(model + ".glb"))


func _halos(node: Node) -> Array[Node]:
	return node.find_children("*", "LanternHalo", true, false)


func test_ivers_lamp_glows_and_moves_with_his_arm() -> void:
	var actor := NpcActor.new()
	actor.setup("iver", _content().get_npc("iver"))
	actor._build_body()
	var halos := _halos(actor)
	assert_eq(halos.size(), 1, "one glow, on his lamp")
	if halos.size() == 1:
		var halo := halos[0] as Node3D
		assert_eq(str(halo.get_parent().name), "ArmR", "hung on the arm that holds the lamp, so it moves with it")
		var part := halo.get_parent() as MeshInstance3D
		assert_true(halo.position.distance_to(NpcActor.glow_centre(part.mesh)) < 0.001, "on the lamp's lit horn")
		assert_true(halo.position.y < -0.5, "held out low, well below the shoulder (%s)" % halo.position)
	actor.free()
	# Someone with nothing lit in that hand gets no glow, whatever the data says.
	var mara := NpcActor.new()
	var data := _content().get_npc("mara").duplicate()
	data["halo"] = {"part": "ArmR"}
	mara.setup("mara", data)
	mara._build_body()
	assert_empty(_halos(mara), "no lit lantern, no halo")
	mara.free()


func test_the_lamp_lanterns_glow_where_they_are_carried() -> void:
	var placed := 0
	for region_id: String in _content().regions:
		for entry: Dictionary in _content().get_region(region_id).get("npcs", []):
			var model := str(entry.get("model", ""))
			if not (model.ends_with("hob_lantern.glb") or model.ends_with("wenna_coll_lantern.glb")):
				continue
			placed += 1
			assert_true(entry.get("halo") is Dictionary, "%s: %s carries the lantern lit" % [region_id, entry["npc"]])
			var data := Region.placed_npc_data(_content().get_npc(str(entry["npc"])), entry)
			var actor := NpcActor.new()
			actor.setup(str(entry["npc"]), data)
			actor._build_body()
			assert_eq(_halos(actor).size(), 1, "%s: %s's lantern glows" % [region_id, entry["npc"]])
			actor.free()
	assert_true(placed >= 6, "every lantern placement checked (%d)" % placed)


func test_the_validator_checks_npc_halos() -> void:
	var db := load_content()
	db.npcs["iver"]["halo"] = {"part": "Tail", "size": -1, "strength": 3}
	(db.regions["lowsong"]["npcs"] as Array)[0]["halo"] = "lamp"
	db.regions["lowsong"]["light"]["shadow"] = 1.5
	(db.regions["lowsong"]["props"] as Array)[0]["shadow"] = "no"
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["halo part must be one of", "halo size must be a number > 0", "halo strength must be 0..2",
			"halo must be {", "light shadow must be 0..1", "prop 'shadow' must be true or false"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)


func test_the_bothy_keeps_a_fire_in() -> void:
	var light: Dictionary = _props("lowsong_light")[0]
	var vents: Array = light.get("smoke", [])
	assert_eq(vents.size(), 1, "one chimney")
	if vents.size() != 1:
		return
	var vent := Vector3(vents[0][0], vents[0][1], vents[0][2])
	assert_true(vent.is_equal_approx(BOTHY_SMOKE), "the smoke leaves where the script put the chimney (%s)" % vent)
	# The chimney lip is in the model just under the vent.
	var model := (load(KIT + "lowsong_light.glb") as PackedScene).instantiate() as Node3D
	var nearest := INF
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			for point: Vector3 in mesh.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
				nearest = minf(nearest, (mesh.transform * point).distance_to(vent))
	assert_true(nearest < 0.4, "the chimney is under the smoke (%.2f m)" % nearest)
	model.free()


func test_the_stacks_stand_in_deep_water_out_of_reach() -> void:
	var region := _region()
	var stacks := _props("lowsong_stack")
	assert_true(stacks.size() >= 4, "a field of stacks (%d)" % stacks.size())
	var field := TerrainField.from_data(region["ground"], float(region["water_level"]))
	var spawn: Array = region["spawn_points"]["from_skiff"]
	var reachable := field.reachable_from(float(spawn[0]), float(spawn[2]))
	var knoll := Vector2(-16.5, -3.2)
	var seen := 0
	for stack: Dictionary in stacks:
		var at := Vector2(float(stack["position"][0]), float(stack["position"][2]))
		assert_false(field.near_reachable(reachable, at.x, at.y, 2.5), "a stack at %s can't be waded to" % at)
		assert_false(bool(stack.get("snap", true)), "stood on the seabed")
		assert_eq(stack.get("shadow"), false, "the fog lights them from nowhere")
		var foot := float(stack["position"][1])
		assert_true(foot < float(region["water_level"]) - 0.4, "its foot under water (%.2f)" % foot)
		if at.distance_to(knoll) < 24.0:
			seen += 1
	assert_true(seen >= 3, "several of them seen from Lowsong's knoll through the fog (%d)" % seen)
	var model := (load(KIT + "lowsong_stack.glb") as PackedScene).instantiate() as Node3D
	var top := 0.0
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		top = maxf(top, (mesh.transform * mesh.get_aabb()).end.y)
	assert_true(top > 4.5, "a good deal higher than a man (%.1f m)" % top)
	model.free()


func test_the_fog_casts_faint_shadows() -> void:
	var state := fresh_state(_content())
	assert_eq(RegionMood.light({}, state)["shadow"], 1.0, "full shadows by default")
	var light := RegionMood.light(_region(), state)
	assert_true(light["shadow"] > 0.0 and light["shadow"] < 0.5, "faint on Lowsong (%s)" % light["shadow"])
	var atmosphere := Atmosphere.new()
	atmosphere._ready()
	atmosphere.apply_mood(RegionMood.fog(_region(), state), light, false)
	assert_true(absf(atmosphere.sun.shadow_opacity - float(light["shadow"])) < 0.001, "the sun's shadows follow the mood")
	atmosphere.apply_mood(RegionMood.fog({}, state), RegionMood.light({}, state), false)
	assert_true(absf(atmosphere.sun.shadow_opacity - 1.0) < 0.001, "and come back elsewhere")
	atmosphere.free()


func test_the_oars_are_heard_on_every_rowing() -> void:
	var recipe: Dictionary = _content().sounds.get("oars", {})
	assert_eq(str(recipe.get("bus", "")), "Effects", "the oars are an effect")
	var samples := SoundSynth.render(recipe, 1)
	# Three strokes: louder in the middle of each 1.4 s stroke than at the catch.
	var strokes := 0
	for k in 3:
		var mid := _rms(samples, (k + 0.5) * 1.4, 0.2)
		var catch_ := _rms(samples, k * 1.4 + 0.2, 0.15)
		if mid > catch_ * 1.3:
			strokes += 1
	assert_eq(strokes, 3, "three pulls through the water")
	var rowings := 0
	for id: String in _content().dialogues:
		for knot: Array in (_content().get_dialogue(id).get("knots", {}) as Dictionary).values():
			for step: Variant in knot:
				if not step is Dictionary:
					continue
				var travel: Variant = (step as Dictionary).get("travel")
				var by_skiff: bool = travel is Array and str(travel[1]) == "from_skiff" and str(travel[0]) in ["lowsong", "kindleby"]
				if by_skiff:
					rowings += 1
					assert_eq(str(step.get("sound", "")), "oars", "%s: Hild's oars as the skiff goes" % id)
	assert_true(rowings >= 3, "out, back from Hild, back from the skiff (%d)" % rowings)
	var first: Dictionary = _content().get_dialogue("lowsong_rowing_out")["knots"]["start"][0]
	assert_eq(str(first.get("sound", "")), "oars", "the rowing out opens on the oars")


func _rms(samples: PackedFloat32Array, at: float, span: float) -> float:
	var start := int(at * SoundSynth.MIX_RATE)
	var count := int(span * SoundSynth.MIX_RATE)
	var sum := 0.0
	for i in range(start, mini(start + count, samples.size())):
		sum += samples[i] * samples[i]
	return sqrt(sum / maxf(1.0, float(count)))
