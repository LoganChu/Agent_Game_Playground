extends TestCase
## Day 111 — polish pass nineteen. The tied-up Mercy's fore and aft warps make fast round a mooring post at every port
## (the short quays left them running into open water), standing beside the landing's head rather than across it.

const POST := "mooring_post.glb"
const TIED := "ferry_tied.glb"
## build_dressing.MOORING_FORE / MOORING_AFT, in Godot's frame of the ferry (Blender (x, y) → Godot (x, -y)).
const FORE := Vector2(4.5, 5.45)
const AFT := Vector2(3.1, -4.6)
const PORTS: Array[String] = ["saltmarrow", "thornwold_landing", "glasswater_fen", "wrackholm", "kindleby",
		"cindermoor_boat_stair"]


func _xz(value: Variant) -> Vector2:
	var arr := value as Array
	return Vector2(float(arr[0]), float(arr[2]))


func _props(region: Dictionary, suffix: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for prop: Dictionary in region.get("props", []):
		if str(prop.get("model", "")).ends_with("/" + suffix):
			found.append(prop)
	return found


## Where a point in the ferry's frame lands in the region, for the ferry prop's position and turn.
func _world(ferry: Dictionary, local: Vector2) -> Vector2:
	var turn := deg_to_rad(float(ferry.get("rotation_y", 0.0)))
	var basis := Basis(Vector3.UP, turn)
	var p := basis * Vector3(local.x, 0, local.y)
	return _xz(ferry["position"]) + Vector2(p.x, p.z)


func _on_pier(region: Dictionary, at: Vector2) -> bool:
	for pier: Dictionary in region.get("ground", {}).get("piers", []):
		var r := pier["rect"] as Array
		if at.x >= float(r[0]) and at.x <= float(r[1]) and at.y >= float(r[2]) and at.y <= float(r[3]):
			return true
	return false


func test_every_port_has_a_post_where_each_warp_makes_fast() -> void:
	var db := load_content()
	for id in PORTS:
		var region := db.get_region(id)
		var tied := _props(region, TIED)
		assert_eq(tied.size(), 1, "%s: the tied Mercy" % id)
		if tied.is_empty():
			continue
		var posts := _props(region, POST)
		for end: String in ["fore", "aft"]:
			var at := _world(tied[0], FORE if end == "fore" else AFT)
			var nearest := INF
			for post in posts:
				nearest = minf(nearest, _xz(post["position"]).distance_to(at))
			# Cindermoor's aft warp lands on the Keepers' quay itself (a ring in its face): no post needed there.
			assert_true(nearest < 0.1 or _on_pier(region, at), "%s: the %s warp makes fast to a post or the quay (%s, nearest post %.2f m)"
					% [id, end, at, nearest])


func test_posts_stand_right_in_the_water_or_on_the_shingle() -> void:
	var db := load_content()
	var total := 0
	for id in PORTS:
		var region := db.get_region(id)
		var field := TerrainField.from_data(region["ground"], float(region.get("water_level", -INF)))
		var water := float(region.get("water_level", -INF))
		for post in _props(region, POST):
			total += 1
			var at := _xz(post["position"])
			var ground := field.height_at(at.x, at.y)
			if ground < water:
				# In the shallows: stood at the water line, its foot (1.7 m down) in the bed, and walked round by nobody.
				assert_eq(post.get("snap", true), false, "%s %s: wet posts stand at the water line" % [id, at])
				assert_true(is_equal_approx(float((post["position"] as Array)[1]), water), "%s %s: at the water level" % [id, at])
				assert_true(ground > water - 1.7, "%s %s: the foot reaches the bed (%.2f)" % [id, at, ground])
			else:
				# Up the shingle: snapped to the ground, with a collider so nobody walks through it.
				assert_eq(post.get("snap", true), true, "%s %s: dry posts stand on the ground" % [id, at])
				assert_true(post.has("collider"), "%s %s: a dry post is solid" % [id, at])
	assert_eq(total, 11, "two posts a port, one at Cindermoor (its aft warp is on the quay)")


func test_shore_posts_stand_clear_of_the_landing_and_the_folk() -> void:
	var db := load_content()
	for id in PORTS:
		var region := db.get_region(id)
		for post in _props(region, POST):
			if not post.has("collider"):
				continue
			var at := _xz(post["position"])
			# Not across the head of the landing: outside its width, so the way off the jetty stays open.
			for pier: Dictionary in region.get("ground", {}).get("piers", []):
				var r := pier["rect"] as Array
				var across := at.x >= float(r[0]) - 0.3 and at.x <= float(r[1]) + 0.3
				var near_end := at.y >= float(r[2]) - 2.0 and at.y <= float(r[3]) + 2.0
				assert_false(across and near_end, "%s %s: beside the landing's head, not across it" % [id, at])
			for key: String in ["npcs", "objects", "pickups"]:
				for entry: Dictionary in region.get(key, []):
					var places: Array = entry.get("placements", [entry])
					for place: Dictionary in places:
						if place.has("position"):
							assert_true(_xz(place["position"]).distance_to(at) > 0.8, "%s: %s stands clear of the post at %s"
									% [id, entry.get("id", key), at])
			for spawn: String in region.get("spawn_points", {}):
				assert_true(_xz(region["spawn_points"][spawn]).distance_to(at) > 1.0, "%s: spawn %s clear of the post" % [id, spawn])


func test_the_post_model_and_the_warps_eyes() -> void:
	var scene := load("res://assets/models/dressing/" + POST) as PackedScene
	assert_true(scene != null, "the mooring post loads")
	if scene == null:
		return
	var node := scene.instantiate() as Node3D
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var aabb := mi.transform * mi.get_aabb()
		box = aabb if first else box.merge(aabb)
		first = false
	node.free()
	assert_true(box.end.y > 1.0 and box.end.y < 1.3, "head a little over a metre up (%.2f)" % box.end.y)
	assert_true(box.position.y < -1.5, "foot driven well down (%.2f)" % box.position.y)
	assert_true(box.size.x < 0.5 and box.size.z < 0.5, "one pile, not a dolphin (%s)" % box.size)
	# The tied Mercy's tarred warps reach out round both posts (the eye's ring is 0.23 m round the post's centre).
	var root := (load("res://assets/models/dressing/" + TIED) as PackedScene).instantiate()
	var tar := AABB()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if str(mi.name).begins_with("driftwood_d55"):
			tar = mi.transform * mi.get_aabb()
	root.free()
	assert_true(absf(tar.end.x - (FORE.x + 0.23)) < 0.08, "the warps reach the fore post's far side (%.2f)" % tar.end.x)
	assert_true(absf(tar.end.z - (FORE.y + 0.23)) < 0.08, "...and round it fore (%.2f)" % tar.end.z)
	assert_true(absf(tar.position.z - (AFT.y - 0.23)) < 0.08, "...and round the aft post (%.2f)" % tar.position.z)
