extends TestCase
## Day 18 art pass: Thornwold's own look — log bunkhouse and tally-house, the saw trestle, a
## charcoal clamp past the bramble wall, dark pines and Greyed snags, underbrush and fallen
## trunks, and smoke rising from stove pipes and the clamp's vents (prop `smoke`).

const DIR := "res://assets/models/dressing/"
const KIT: Array[String] = ["bunkhouse", "tally_house", "saw_pit", "charcoal_clamp", "pine_dark", "pine_snag",
		"underbrush", "fallen_trunk"]


func _thornwold_models() -> Dictionary:
	var counts := {}
	for prop: Dictionary in load_content().get_region("thornwold_landing")["props"]:
		var file := str(prop.get("model", "")).get_file().get_basename()
		counts[file] = int(counts.get(file, 0)) + 1
	return counts


func test_kit_models_exist_and_are_placed() -> void:
	var counts := _thornwold_models()
	for name in KIT:
		assert_true(ResourceLoader.exists(DIR + name + ".glb"), "%s.glb exists" % name)
		assert_true(int(counts.get(name, 0)) >= 1, "Thornwold uses %s" % name)


func test_thornwold_no_longer_borrows_saltmarrow() -> void:
	var counts := _thornwold_models()
	for borrowed: String in ["house_stilt", "house_tall", "pine_tree"]:
		assert_false(counts.has(borrowed), "Thornwold doesn't use Saltmarrow's %s" % borrowed)
	assert_true(int(counts.get("pine_dark", 0)) >= 15, "the woods are Thornwold's dark pines (%d)" % int(counts.get("pine_dark", 0)))


## The smoke vents sit at the top of a stove pipe or on the clamp's crown, not floating in the
## air or buried in the roof: every vent is within the model's bounds (x/z) and near its top
## for the buildings.
func test_smoke_vents_sit_on_their_models() -> void:
	var smoking := 0
	for prop: Dictionary in load_content().get_region("thornwold_landing")["props"]:
		if not prop.has("smoke"):
			continue
		smoking += 1
		var node := (load(str(prop["model"])) as PackedScene).instantiate() as Node3D
		var bounds := Region.mesh_bounds(node)
		for vent: Array in prop["smoke"]:
			var v := JsonUtil.to_vector3(vent)
			var file := str(prop["model"]).get_file()
			assert_true(bounds.grow(0.05).has_point(Vector3(v.x, bounds.get_center().y, v.z)), "%s vent %s is over the model" % [file, v])
			assert_true(v.y <= bounds.end.y + 0.3 and v.y >= bounds.end.y - 0.4 if file != "charcoal_clamp.glb" else v.y > 0.6,
					"%s vent %s is at the pipe top / crown (model top %.2f)" % [file, v, bounds.end.y])
		node.free()
	assert_true(smoking >= 3, "bunkhouse, tally-house and clamp smoke (%d)" % smoking)


func test_smoke_builds_particles_per_vent() -> void:
	var db := load_content()
	var region := Region.new()
	region.data = db.get_region("thornwold_landing")
	region.field = TerrainField.from_data(region.data["ground"], float(region.data["water_level"]))
	var prop := {"model": DIR + "charcoal_clamp.glb", "position": [0, 0, 0], "smoke": [[0, 1, 0], [0.5, 0.9, 0.2]]}
	var node := region._build_prop(prop)
	var smoke := node.find_child("Smoke", false, false)
	assert_true(smoke != null, "the prop has a Smoke node")
	if smoke:
		var vents := smoke.find_children("*", "CPUParticles3D", false, false)
		assert_eq(vents.size(), 2, "one emitter per vent")
		var first := vents[0] as CPUParticles3D
		assert_true(first.position.is_equal_approx(Vector3(0, 1, 0)), "emitter at its vent")
		assert_true(first.emitting and first.preprocess > 0.0, "already smoking when the region loads")
	node.free()
	var plain := region._build_prop({"model": DIR + "stump.glb", "position": [0, 0, 0]})
	assert_true(plain.find_child("Smoke", false, false) == null, "no smoke without the field")
	plain.free()
	region.free()


func test_validator_checks_smoke() -> void:
	var db := load_content()
	var props: Array = db.regions["thornwold_landing"]["props"]
	props.append({"shape": "crate", "position": [0, 0, 0], "smoke": [[0, 1, 0]]})
	props.append({"model": DIR + "bunkhouse.glb", "position": [0, 0, 0], "smoke": [[0, 1]]})
	props.append({"model": DIR + "bunkhouse.glb", "position": [0, 0, 0], "smoke": []})
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["'smoke' needs a 'model'", "smoke vent must be [x, y, z]", "'smoke' must be a list"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)


## The clamp smokes in the Greying past the wall, where the camp can't go (LORE: nobody sees
## who brings the charcoal sacks).
func test_clamp_stands_past_the_bramble_wall() -> void:
	for prop: Dictionary in load_content().get_region("thornwold_landing")["props"]:
		if str(prop.get("model", "")).ends_with("charcoal_clamp.glb"):
			assert_true(float(prop["position"][2]) < -19.0, "the clamp is north of the wall, in the woods")
