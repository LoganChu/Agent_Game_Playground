extends TestCase
## Day 123 — the surf comes from the shore (systems, ROADMAP #7): an ambience layer marked
## `"at": "shore"` plays from the nearest point where the ground meets the water
## (TerrainField.shore_points), louder near the water and panned toward it (ShoreSound,
## AudioDirector), instead of the same everywhere at once.

const SHORE_REGIONS := ["shingle_point", "kindleby", "wrackholm", "thornwold_far_shore", "wrack_teeth"]

var _saved_db: ContentDatabase


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


## The autoloads aren't readied under the test runner: give Content this content for a test.
func _use_content() -> void:
	_saved_db = Content.db
	if Content.db.sounds.is_empty():
		Content.db = load_content()


func _restore() -> void:
	Content.db = _saved_db


func _field(db: ContentDatabase, id: String) -> TerrainField:
	var data: Dictionary = db.get_region(id)
	return TerrainField.from_data(data["ground"], float(data.get("water_level", -INF)))


func test_the_shoreline_is_where_ground_meets_water() -> void:
	# A square island 10 m across in a sea: every shore point is on its edge, at the water.
	var ground := {"bounds": [-20, -20, 20, 20], "cell": 1.0, "base": -2.0, "roughness": 0.0, "ragged": 0.0,
		"land": [{"rect": [-5, -5, 5, 5], "height": 1.0, "falloff": 1.0}]}
	var field := TerrainField.from_data(ground, 0.0)
	var points := field.shore_points()
	assert_true(points.size() >= 16, "the island has a shoreline all round (%d points)" % points.size())
	for p: Vector3 in points:
		assert_true(is_equal_approx(p.y, 0.0), "at the water's height")
		var edge := maxf(absf(p.x), absf(p.z))
		assert_true(edge >= 4.9 and edge <= 6.1, "on the island's edge (%s)" % p)
	assert_true(field.shore_points() == points, "cached")
	assert_true(field.shore_points(4.0).size() < points.size(), "thinned more on a wider spacing")
	assert_true(TerrainField.from_data(ground).shore_points().is_empty(), "no water, no shore")
	var dry := TerrainField.from_data({"bounds": [-5, -5, 5, 5], "land": [{"rect": [-9, -9, 9, 9], "height": 1.0}]}, 0.0)
	assert_true(dry.shore_points().is_empty(), "all land, no shore")


func test_the_surf_is_loud_by_the_water_and_quiet_inland() -> void:
	assert_true(is_equal_approx(ShoreSound.gain(0.0, 16.0, 0.35), 1.0), "full at the water")
	assert_true(is_equal_approx(ShoreSound.gain(ShoreSound.NEAR, 16.0, 0.35), 1.0), "full within NEAR")
	assert_true(is_equal_approx(ShoreSound.gain(16.0, 16.0, 0.35), 0.35), "down to the floor at the reach")
	assert_true(is_equal_approx(ShoreSound.gain(80.0, 16.0, 0.35), 0.35), "never below the floor")
	assert_true(is_equal_approx(ShoreSound.gain(INF, 16.0, 0.35), 0.35), "no shore: the floor")
	var last := 2.0
	for d in range(0, 20):
		var g := ShoreSound.gain(float(d), 16.0, 0.35)
		assert_true(g <= last + 0.0001, "never louder further off (%d m)" % d)
		last = g
	assert_eq(ShoreSound.spec({"sound": "surf"}), {}, "a plain layer has no anchor")
	var spec := ShoreSound.spec({"sound": "surf", "at": "shore"})
	assert_eq(spec["at"], "shore")
	assert_true(is_equal_approx(float(spec["reach"]), ShoreSound.REACH) and is_equal_approx(float(spec["floor"]), ShoreSound.FLOOR), "defaults")


func test_the_anchor_is_toward_the_water_and_never_on_top_of_you() -> void:
	var points := PackedVector3Array([Vector3(10, 0, 0), Vector3(0, 0, -20)])
	assert_eq(ShoreSound.nearest(points, Vector3(2, 1, 0)), Vector3(10, 0, 0), "the nearer point")
	assert_true(is_equal_approx(ShoreSound.distance(points, Vector3(2, 5, 0)), 8.0), "distance on the ground plane")
	assert_eq(ShoreSound.anchor(points, Vector3(2, 1, 0)), Vector3(10, 0, 0), "far enough: right at the shore")
	var close := ShoreSound.anchor(points, Vector3(9, 1, 0))
	assert_true(is_equal_approx(Vector2(close.x - 9.0, close.z).length(), ShoreSound.MIN_SPREAD), "pushed out to MIN_SPREAD")
	assert_true(close.x > 9.0, "still toward the water (%s)" % close)
	var on_it := ShoreSound.anchor(points, Vector3(10, 1, 0))
	assert_true(is_equal_approx(Vector2(on_it.x - 10.0, on_it.z).length(), ShoreSound.MIN_SPREAD), "standing on the point: still somewhere")
	assert_eq(ShoreSound.anchor(PackedVector3Array(), Vector3.ZERO), Vector3.INF, "no shore, no anchor")


func test_the_coastal_regions_play_their_surf_from_the_shore() -> void:
	var db := load_content()
	var state := fresh_state(db)
	for id: String in SHORE_REGIONS:
		var region: Dictionary = db.get_region(id)
		var anchors := AudioDirector.ambience_anchors(region, state)
		assert_true(anchors.has("surf"), "%s: the surf comes from the shore" % id)
		assert_true(AudioDirector.ambience_layers(region, state).has("surf"), "%s: and it's still a layer" % id)
		var field := _field(db, id)
		var points := field.shore_points()
		assert_true(points.size() >= 20, "%s has a shoreline (%d points)" % [id, points.size()])
		# Everywhere the player can walk hears it from somewhere at least at its floor, and
		# somewhere walkable is near enough to hear it in full.
		var spawn: Array = region["spawn_points"]["default"]
		var reach := field.reachable_from(float(spawn[0]), float(spawn[2]))
		var loudest := 0.0
		var quietest := 1.0
		for cell: Vector2i in reach:
			var p := field.vertex_xz(cell.x, cell.y)
			var g := ShoreSound.gain(ShoreSound.distance(points, Vector3(p.x, 0.0, p.y)), float(anchors["surf"]["reach"]), float(anchors["surf"]["floor"]))
			loudest = maxf(loudest, g)
			quietest = minf(quietest, g)
		assert_true(is_equal_approx(loudest, 1.0), "%s: full surf somewhere by the water" % id)
		assert_true(quietest >= float(anchors["surf"]["floor"]) - 0.001, "%s: never below the floor" % id)
	# Saltmarrow's harbor keeps the distant sea as a bed: nothing anchored there.
	assert_true(AudioDirector.ambience_anchors(db.get_region("saltmarrow"), state).is_empty(), "Saltmarrow's surf_far is everywhere")


func test_the_director_moves_the_surf_along_the_shore() -> void:
	_use_content()
	var region := {"ambience": [{"sound": "surf", "volume": 0.8, "at": "shore", "reach": 12, "floor": 0.25}, {"sound": "wind_low", "volume": 0.5}]}
	var shore := PackedVector3Array([Vector3(10, -0.25, 0), Vector3(-10, -0.25, 0)])
	var audio := AudioDirector.new()
	_root().add_child(audio)
	audio.follow_listener(Vector3(8, 0, 0))
	audio.enter_region(region, shore)
	assert_true(audio.layer_anchored("surf"), "the surf is a positional player")
	assert_false(audio.layer_anchored("wind_low"), "the wind isn't")
	assert_eq(audio.layer_position("surf"), Vector3(11, -0.25, 0), "placed toward the nearest shore at once (pushed out to MIN_SPREAD)")
	assert_eq(audio.layer_position("wind_low"), Vector3.INF)
	audio._process(0.1)
	assert_true(is_equal_approx(audio.layer_gain("surf"), 1.0), "2 m from the water: full (%s)" % audio.layer_gain("surf"))
	assert_true(is_equal_approx(audio.layer_gain("wind_low"), 1.0), "a plain layer isn't scaled")
	# Walk across to the other side: the anchor slides, it doesn't jump.
	audio.follow_listener(Vector3(-6, 0, 0))
	audio._process(0.1)
	var moved := audio.layer_position("surf")
	assert_true(moved.x < 10.0 and moved.x > -10.0, "sliding toward the far shore (%s)" % moved)
	for i in 40:
		audio._process(0.1)
	assert_eq(audio.layer_position("surf"), Vector3(-10, -0.25, 0), "arrived at the far shore")
	# Inland, in the middle: quieter, at the floor past the reach.
	audio.follow_listener(Vector3(0, 0, 30))
	audio._process(0.1)
	assert_true(is_equal_approx(audio.layer_gain("surf"), 0.25), "past the reach: the floor (%s)" % audio.layer_gain("surf"))
	# A region without water: the same layer plays everywhere, and the shore player gives way.
	audio.enter_region(region, PackedVector3Array())
	assert_false(audio.layer_anchored("surf"), "no shore: a plain layer")
	var retired := audio._layers.keys().filter(func(k: String) -> bool: return k.begins_with("surf~"))
	assert_eq(retired.size(), 1, "the shore player fades out under another name")
	assert_eq(float(audio.ambience_targets().get("surf", 0.0)), 0.8, "still the same volume")
	audio.free()
	_restore()


func test_the_validator_checks_where_a_sound_comes_from() -> void:
	var db := load_content()
	var validator := ContentValidator.new(db)
	var region := {"ground": {}, "water_level": -0.25, "ambience": [
		{"sound": "surf", "at": "sky"},
		{"sound": "surf", "at": "shore", "reach": 1},
		{"sound": "surf", "at": "shore", "floor": 2},
		{"sound": "surf", "at": "shore", "reach": 14, "floor": 0.4}]}
	validator._validate_region_audio("region test", region)
	var report := "\n".join(validator.errors)
	for needle: String in ["at 'sky' is not a place", "reach must be", "floor must be"]:
		assert_true(report.contains(needle), "caught: %s\n%s" % [needle, report])
	assert_eq(validator.errors.size(), 3, "the good layer passes\n" + report)
	validator = ContentValidator.new(db)
	validator._validate_region_audio("region dry", {"ambience": [{"sound": "surf", "at": "shore"}]})
	assert_true("\n".join(validator.errors).contains("needs sculpted ground and a water_level"), "a shore needs water")
