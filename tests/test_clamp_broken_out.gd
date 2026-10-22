extends TestCase
## Day 58 art pass — Coll's Hearth once Wenna is home. *The Bend in the Road* ends with her sitting by her door
## for the first time since the Snuffing; the next time the player comes along the bend she is up at her clamp
## with the rake (`wenna_coll_rake`), its front raked open and the charcoal coming out a sack at a time
## (`clamp_spent_open`). Also: Abe Dray's hands on his hips, bent at the elbow (`_bent_arm`).

const HEARTH := "thornwold_colls_hearth"
const CHARACTERS := "res://assets/models/characters/"
const DRESSING := "res://assets/models/dressing/"
const ROAD := "Hang it on the bend's waymark. Let the road be a road again."
const KEEP := "Keep it by your own door. You went a long way for a light of your own."
const SHOW := "Show me."
const ASK := "Can I walk out with you in the morning?"

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed)


## Home from the far shore, out along the bend with Wenna, her light given to `choice` (ROAD or KEEP; "" not yet).
func _settled(choice: String) -> WorldState:
	var state := fresh_state(_content())
	for flag: String in ["intro_seen", "thornwold_met_hob", "thornwold_met_lamp", "thornwold_met_wenna_coll",
			"thornwold_far_shore_reached", "thornwold_salt_row_away"]:
		state.set_flag(flag, true)
	state.set_flag("thornwold_beacon_burned", "salt_row")
	state.set_flag("thornwold_far_shore", "up")
	state.complete_quest("the_far_shore")
	_lines(state, "wenna_coll", [ASK])
	_lines(state, RegionEvents.fire(RegionEvents.arrival(_content().get_region("thornwold_woods"), state), state))
	_lines(state, "wenna_coll", [SHOW])
	if not choice.is_empty():
		_lines(state, "wenna_coll", [choice])
	return state


func _arrive(state: WorldState) -> Dictionary:
	return RegionEvents.arrival(_content().get_region(HEARTH), state)


func _wenna(state: WorldState) -> Array[String]:
	var out: Array[String] = []
	for placement: Dictionary in _content().get_region(HEARTH)["npcs"]:
		if str(placement["npc"]) == "wenna_coll" and Conditions.evaluate(placement.get("if"), state):
			out.append(str(placement.get("model", _content().get_npc("wenna_coll")["model"])).get_file().get_basename())
	return out


func _models(state: WorldState) -> Array[String]:
	var out: Array[String] = []
	for prop: Dictionary in _content().get_region(HEARTH)["props"]:
		if Conditions.evaluate(prop.get("if"), state):
			out.append(str(prop.get("model", "")).get_file().get_basename())
	return out


## A rig part's bounds in the model's own space (its parents' transforms applied, not the scene root's).
func _part_bounds(model: Node3D, part: String) -> AABB:
	var node := model.find_child(part, true, false) as Node3D
	var xf := Transform3D.IDENTITY
	var walk: Node = node.get_parent()
	while walk != model and walk is Node3D:
		xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf * node.transform * Region.mesh_bounds(node)


func test_she_sits_the_day_it_ends() -> void:
	var state := _settled(ROAD)
	assert_eq(_wenna(state), ["wenna_coll"] as Array[String], "seated by her door, the fire in")
	assert_true(_models(state).has("clamp_spent"))
	assert_false(_models(state).has("clamp_spent_open"))


func test_the_next_arrival_finds_her_at_the_clamp() -> void:
	for choice: String in [ROAD, KEEP]:
		var state := _settled(choice)
		var event := _arrive(state)
		assert_eq(str(event.get("id", "")), "colls_hearth_breaking_out")
		var text := _lines(state, RegionEvents.fire(event, state))
		assert_true(text.contains("a rake, drawn through charcoal"))
		assert_true(text.contains("It's a sack at a time, this."))
		assert_true(text.contains("Her light's by the door") == (choice == KEEP), "the hearth way in finds the hollow by her light")
		assert_true(state.get_flag("thornwold_bend_breaking_out"))
		assert_true(_arrive(state).is_empty(), "once")
		assert_eq(_wenna(state), ["wenna_coll_rake"] as Array[String], "up at the clamp with the rake")
		var models := _models(state)
		assert_true(models.has("clamp_spent_open") and not models.has("clamp_spent"), "the front raked open")
		assert_eq(models.has("hut_lantern"), choice == KEEP, "her own light stays by her door")
		assert_eq(models.has("waymark_lit"), choice == ROAD, "the bend stays lit")


func test_not_before_she_has_chosen() -> void:
	var state := _settled("")
	assert_eq(str(state.get_flag("thornwold_bend")), "walked")
	assert_false(str(_arrive(state).get("id", "")) == "colls_hearth_breaking_out")


func test_what_she_and_the_clamp_say_after() -> void:
	var state := _settled(KEEP)
	_lines(state, RegionEvents.fire(_arrive(state), state))
	var text := _lines(state, "wenna_coll", ["Goodbye, Wenna."])
	assert_true(text.contains("at her clamp with the rake, stooped into it"))
	assert_true(text.contains("Her own lantern burns by the hut door"))
	assert_false(text.contains("sits on the seat by her hut door"))
	assert_true(text.contains("I don't call out."), "the rest of her talk is as it was")
	var clamp := _lines(state, "wenna_clamp")
	assert_true(clamp.contains("The front's raked open to the hearth now."))
	assert_false(clamp.contains("Where the front fell in"))
	var road := _settled(ROAD)
	_lines(road, RegionEvents.fire(_arrive(road), road))
	assert_true(_lines(road, "wenna_coll", ["Goodbye, Wenna."]).contains("Down the ruts the bend's lantern burns"))


func test_the_rake_is_on_the_ground_in_front_of_her() -> void:
	var path := CHARACTERS + "wenna_coll_rake.glb"
	assert_true(FileAccess.open(path, FileAccess.READ).get_length() < 5 * 1024 * 1024)
	var model := (load(path) as PackedScene).instantiate() as Node3D
	var rake := _part_bounds(model, "Stool")
	assert_true(rake.position.y < 0.05, "the rake's head is down on the ground (%.2f)" % rake.position.y)
	assert_true(rake.end.z > 1.1, "out in front of her (front is +Z; reaches %.2f)" % rake.end.z)
	assert_true(rake.end.y > 0.8 and rake.end.y < 1.1, "its top at her hip (%.2f)" % rake.end.y)
	for arm: String in ["ArmL", "ArmR"]:
		var hands := _part_bounds(model, arm)
		assert_true(hands.end.z > 0.15, "%s reaches forward to the pole (%.2f)" % [arm, hands.end.z])
	model.free()


func test_the_open_clamp_is_low_and_on_its_origin() -> void:
	var path := DRESSING + "clamp_spent_open.glb"
	assert_true(FileAccess.open(path, FileAccess.READ).get_length() < 5 * 1024 * 1024)
	var node := (load(path) as PackedScene).instantiate() as Node3D
	var bounds := Region.mesh_bounds(node)
	assert_true(bounds.position.y > -0.15, "on its origin (%.2f)" % bounds.position.y)
	assert_true(bounds.size.y < 0.75, "a clamp sunk low (%.2f)" % bounds.size.y)
	assert_true(bounds.end.z > 2.2, "the charcoal raked out in front (+Z) (%.2f)" % bounds.end.z)
	node.free()


func test_abe_has_his_hands_on_his_hips() -> void:
	var model := (load(CHARACTERS + "abe.glb") as PackedScene).instantiate() as Node3D
	for arm: String in ["ArmL", "ArmR"]:
		var b := _part_bounds(model, arm)
		assert_true(b.position.y > 0.6, "%s's hand is up at his hip, not hanging (%.2f)" % [arm, b.position.y])
		assert_true(maxf(absf(b.position.x), absf(b.end.x)) > 0.55, "%s's elbow out wide (%.2f)" % [arm, maxf(absf(b.position.x), absf(b.end.x))])
		assert_true(minf(absf(b.position.x), absf(b.end.x)) < 0.36, "%s's fist back in at his side" % arm)
	model.free()
