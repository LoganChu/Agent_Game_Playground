extends TestCase
## Day 50 — Wrackholm's yard folk: inside round the fire until the Wrack is lit, then out on the
## shingle standing looking at it (Tidewrights don't shout at a lighting); once the horn has
## answered the light, back at work about the yard.

const REGION := "wrackholm"
const DIR := "res://assets/models/characters/"
const FOLK: Array[String] = ["yard_smock", "yard_smock_mallet", "yard_shawl", "yard_lad"]
const WRACK := Vector2(-29.0, -1.5)

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


## The yard folk shown in `state`.
func _shown(state: WorldState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop: Dictionary in _content().get_region(REGION)["props"]:
		var model := str(prop.get("model", ""))
		if model.begins_with(DIR + "yard_") and Conditions.evaluate(prop.get("if"), state):
			out.append(prop)
	return out


func _xz(pos: Array) -> Vector2:
	return Vector2(float(pos[0]), float(pos[2]))


func _lit_state() -> WorldState:
	var state := fresh_state(_content())
	state.start_quest("a_light_for_wrackholm", "the_teeth")
	state.complete_quest("a_light_for_wrackholm")
	state.flags["wrackholm_beacon_burned"] = "white"
	return state


func test_models_load_and_stay_small() -> void:
	for model in FOLK:
		var path := DIR + model + ".glb"
		assert_true(ResourceLoader.exists(path), "%s exists" % model)
		var node := CharacterRig.instantiate(path, "still")
		assert_true(node != null, "%s rigs" % model)
		if node:
			assert_true(Region.mesh_bounds(node).size.y > 1.0, "%s stands up" % model)
			node.free()
		assert_true(FileAccess.get_file_as_bytes(path).size() < 5 * 1024 * 1024, "%s under 5 MB" % model)


func test_inside_until_the_wrack_is_lit() -> void:
	var state := fresh_state(_content())
	assert_empty(_shown(state), "nobody came out to the dark")
	state.start_quest("a_light_for_wrackholm", "the_teeth")
	state.set_quest_stage("a_light_for_wrackholm", "feed_the_wrack")
	assert_empty(_shown(state), "nor while it waits to be fed")


func test_out_on_the_shingle_looking() -> void:
	var state := _lit_state()
	var shown := _shown(state)
	assert_eq(shown.size(), 3, "three come out")
	var region := _content().get_region(REGION)
	var field := TerrainField.from_data(region["ground"], float(region["water_level"]))
	var from := _xz(region["spawn_points"]["from_teeth"])
	var spit := Vector2.ZERO
	for obj: Dictionary in region["objects"]:
		if str(obj["id"]) == "teeth_spit":
			spit = _xz(obj["position"])
	var models: Array[String] = []
	for prop in shown:
		var at := _xz(prop["position"])
		models.append(str(prop["model"]).get_file().get_basename())
		assert_eq(str(prop["idle"]), "still", "standing still")
		var yaw := deg_to_rad(float(prop["rotation_y"]))
		var facing := Vector2(sin(yaw), cos(yaw))
		assert_true(facing.angle_to(WRACK - at) < deg_to_rad(15.0) and facing.angle_to(WRACK - at) > -deg_to_rad(15.0),
			"%s looks at the Wrack" % prop["model"])
		assert_true(field.height_at(at.x, at.y) > float(region["water_level"]) + 0.2, "on dry shingle")
		var on_line := Geometry2D.get_closest_point_to_segment(at, from, spit)
		assert_true(at.distance_to(on_line) > 1.5, "clear of the way out to the spit")
	assert_true("yard_smock" in models and "yard_shawl" in models and "yard_lad" in models, "the old hand, the woman, the lad")


func test_back_at_work_once_the_horn_answers() -> void:
	var state := _lit_state()
	state.flags["wrackholm_horn_sounded"] = true
	var shown := _shown(state)
	assert_eq(shown.size(), 3, "the same three")
	var looking := 0
	var caulking := false
	for prop in shown:
		var yaw := deg_to_rad(float(prop["rotation_y"]))
		var to_wrack := WRACK - _xz(prop["position"])
		if absf(Vector2(sin(yaw), cos(yaw)).angle_to(to_wrack)) < deg_to_rad(15.0):
			looking += 1
		if str(prop["model"]).ends_with("yard_smock_mallet.glb"):
			caulking = str(prop["idle"]) == "chisel"
	assert_eq(looking, 0, "nobody stands looking any more")
	assert_true(caulking, "the old hand caulks a seam")
