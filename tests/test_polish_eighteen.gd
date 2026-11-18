extends TestCase
## Day 108 — polish pass eighteen. The lantern room's arrival faces the cradle with the swung-back door leaf out of the
## first frame; the lit far Spire stands on Gull's Head and Shingle Point on Saltmarrow's bearing, carried across each
## seam; and the tied-up Mercy's warps are thick, tarred and doubled so they read from the quay.

const LIT := "flag:cindermoor_cradle_choice=lit"
const SPIRE_LIT := "hearthspire_far_lit.glb"


func _angle_deg(a: Vector2, b: Vector2) -> float:
	return rad_to_deg(absf(a.angle_to(b)))


func _v2(value: Variant) -> Vector2:
	var arr := value as Array
	return Vector2(float(arr[0]), float(arr[arr.size() - 1]))


func test_the_lantern_room_arrival_faces_the_cradle_not_the_door_leaf() -> void:
	var region := load_content().get_region("cindermoor_lantern_room")
	var leaf := Vector2.INF
	for prop: Dictionary in region.get("props", []):
		if str(prop.get("model", "")).ends_with("/lantern_room.glb"):
			for box: Dictionary in prop.get("colliders", []):
				var off := box["offset"] as Array
				if float(off[0]) > 3.0:
					leaf = Vector2(float(off[0]), float(off[2]))
	assert_true(leaf != Vector2.INF, "the door leaf's collider")
	for spawn: String in ["default", "from_stair"]:
		var p := region["spawn_points"][spawn] as Array
		var from := Vector2(float(p[0]), float(p[2]))
		var look := _v2(region["spawn_facing"][spawn]) - from
		assert_true(_angle_deg(look, -from) <= 20.0, "%s: the cradle near the middle of the frame (%.0f°)"
				% [spawn, _angle_deg(look, -from)])
		assert_true(_angle_deg(look, leaf - from) >= 100.0, "%s: the door leaf well behind the frame's edge (%.0f°)"
				% [spawn, _angle_deg(look, leaf - from)])


## The z offset of `region`'s frame inside Saltmarrow's, from the exit pair across their seam.
func _seam_offset(db: ContentDatabase, region_id: String) -> float:
	var here := 0.0
	var there := 0.0
	for exit: Dictionary in db.get_region("saltmarrow").get("exits", []):
		if str(exit.get("to", "")) == region_id:
			here = float((exit["position"] as Array)[2])
	for exit: Dictionary in db.get_region(region_id).get("exits", []):
		if str(exit.get("to", "")) == "saltmarrow":
			there = float((exit["position"] as Array)[2])
	return here - there


func _spire(db: ContentDatabase, region_id: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for prop: Dictionary in db.get_region(region_id).get("props", []):
		if str(prop.get("model", "")).ends_with(SPIRE_LIT):
			found.append(prop)
	return found


func test_the_lit_spire_stands_off_gulls_head_and_shingle_point_on_saltmarrows_bearing() -> void:
	var db := load_content()
	var home := _spire(db, "saltmarrow")
	assert_eq(home.size(), 1, "Saltmarrow's lit Spire")
	var home_pos := home[0]["position"] as Array
	for region_id: String in ["gulls_head", "shingle_point"]:
		var props := _spire(db, region_id)
		assert_eq(props.size(), 1, "%s: one lit Spire" % region_id)
		if props.is_empty():
			continue
		var prop := props[0]
		assert_eq(str(prop.get("if", "")), LIT, "%s: only when lit" % region_id)
		assert_eq(prop.get("snap", true), false, "%s: absolute height" % region_id)
		var pos := prop["position"] as Array
		var shift := _seam_offset(db, region_id)
		assert_true(absf(shift) > 10.0, "%s: a real seam (%.1f)" % [region_id, shift])
		assert_true(is_equal_approx(float(pos[0]), float(home_pos[0])), "%s: same easting" % region_id)
		assert_true(absf(float(pos[2]) + shift - float(home_pos[2])) < 0.01,
				"%s: Saltmarrow's point carried across the seam (%.1f + %.1f vs %.1f)"
				% [region_id, float(pos[2]), shift, float(home_pos[2])])
		assert_true(Vector2(float(pos[0]), float(pos[2])).length() > 100.0, "%s: far out past the fog" % region_id)
		for key: String in ["scale", "halo", "halo_size", "halo_strength", "halo_bloom"]:
			assert_eq(prop.get(key), home[0].get(key), "%s: the same %s as Saltmarrow's" % [region_id, key])
		for ending: String in ["", "lit", "released", "dark"]:
			var state := fresh_state(db)
			state.set_flag("cindermoor_cradle_choice", ending)
			assert_eq(Conditions.evaluate(prop.get("if"), state), ending == "lit", "%s / %s" % [region_id, ending])


## The warps are the only thing on the Mercy in the dark tarred brown (`driftwood`, shade -0.55), so the export merges
## them into one mesh named for that material.
const TAR_MESH := "driftwood_d55"


func _tar(path: String) -> Array[AABB]:
	var root := (load(path) as PackedScene).instantiate()
	var found: Array[AABB] = []
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if str(mi.name).begins_with(TAR_MESH):
			found.append(mi.transform * mi.get_aabb())
	root.free()
	return found


func test_the_tied_mercys_warps_run_fore_and_aft_to_the_quay() -> void:
	assert_eq(_tar("res://assets/models/dressing/ferry.glb").size(), 0, "the sailing Mercy has no warps out")
	var warps := _tar("res://assets/models/dressing/ferry_tied.glb")
	assert_eq(warps.size(), 1, "the tied Mercy's warps, tarred")
	if warps.is_empty():
		return
	var box := warps[0]
	assert_true(box.position.x >= 1.0 and box.end.x >= 2.9, "out to port, to the quay's edge (x %.2f..%.2f)"
			% [box.position.x, box.end.x])
	assert_true(box.size.z >= 9.5, "fore and aft past both ends of the hull (%.2f m)" % box.size.z)
	# Day 111 (polish nineteen): they drop to the eye round each port's mooring post, not to the waterline.
	assert_true(box.position.y <= 0.85, "the fore and aft warps drop low, to the mooring posts (%.2f)" % box.position.y)
