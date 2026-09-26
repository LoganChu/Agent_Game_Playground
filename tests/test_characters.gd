extends TestCase
## Character models (tools/blender/build_characters.py) follow the rig contract that
## CharacterRig animates, and the rig moves them without breaking their rest pose.


func _model_paths() -> Array[String]:
	var db := load_content()
	var paths: Array[String] = [str(db.game.get("player_model", ""))]
	for id: String in db.npcs:
		paths.append(str(db.npcs[id].get("model", "")))
	return paths


func test_every_character_model_has_the_rig_parts() -> void:
	for path in _model_paths():
		assert_false(path.is_empty(), "every NPC and the player should have a model")
		var model := CharacterRig.instantiate(path)
		assert_true(model != null, "%s should load" % path)
		if model == null:
			continue
		var parts := CharacterRig.find_parts(model)
		for part in CharacterRig.PARTS:
			assert_true(parts.has(part), "%s is missing rig part %s" % [path, part])
		# Arms and head must hang off the torso so breathing carries them.
		for part: String in ["Head", "ArmL", "ArmR"]:
			if parts.has(part):
				assert_eq((parts[part] as Node).get_parent().name, &"Torso", "%s %s parent" % [path, part])
		model.free()


func test_rig_poses_around_rest_and_returns() -> void:
	var model := CharacterRig.instantiate(str(load_content().game["player_model"]))
	var rig := model.get_node("CharacterRig") as CharacterRig
	rig._ready()
	var torso := model.find_child("Torso", true, false) as Node3D
	var leg := model.find_child("LegL", true, false) as Node3D
	var rest_torso := torso.transform
	var rest_leg := leg.transform
	rig.pose(0.0)
	assert_true(torso.transform.is_equal_approx(rest_torso), "t=0 standing pose should be the rest pose")
	rig.pose(0.9)
	assert_false(torso.transform.is_equal_approx(rest_torso), "breathing should move the torso")
	assert_true(leg.transform.is_equal_approx(rest_leg), "standing legs should not swing")
	rig.pose(0.0, PI / 2, 1.0)
	assert_false(leg.transform.is_equal_approx(rest_leg), "walking should swing the legs")
	assert_true(torso.transform.origin.distance_to(rest_torso.origin) < 0.05, "walk bob should stay small")
	model.free()


func test_missing_model_falls_back() -> void:
	assert_true(CharacterRig.instantiate("") == null, "empty path -> fallback")
	assert_true(CharacterRig.instantiate("res://assets/models/characters/nobody.glb") == null, "missing -> fallback")


func test_validator_checks_character_models() -> void:
	var db := load_content()
	db.npcs["mara"]["model"] = "res://assets/models/characters/nobody.glb"
	db.npcs["hesk"]["idle"] = "juggle"
	db.game["player_model"] = "res://data/game.json"
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	var report := validator.report()
	for needle: String in ["nobody.glb' does not exist", "idle must be one of", "must be a .glb or .tscn"]:
		assert_true(report.contains(needle), "report should mention '%s'" % needle)
