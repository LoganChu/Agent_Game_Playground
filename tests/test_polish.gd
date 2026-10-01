extends TestCase
## Day 15 polish pass: the orbit camera stops at roofs and canopies (camera-only blockers
## over tall props) and eases back out; the pause menu's slots and key binding.


func _prop(db: ContentDatabase, region_id: String, model_suffix: String) -> Dictionary:
	for prop: Dictionary in db.get_region(region_id)["props"]:
		if str(prop.get("model", "")).ends_with(model_suffix):
			return prop
	return {}


func _blocker(node: Node) -> StaticBody3D:
	return node.find_child("CameraBlocker", true, false) as StaticBody3D


func test_tall_house_blocks_the_camera_above_its_walls() -> void:
	var db := load_content()
	var region := Region.new()
	var prop := _prop(db, "saltmarrow", "house_porch.glb")
	var node := region._build_prop(prop)
	var blocker := _blocker(node)
	assert_true(blocker != null, "Mara's house gets a camera blocker")
	if blocker:
		assert_true(blocker.get_collision_layer_value(Layers.CAMERA), "blocker is on the camera layer")
		assert_false(blocker.get_collision_layer_value(Layers.WORLD), "blocker doesn't stop the player")
		assert_eq(blocker.collision_mask, 0, "blocker detects nothing")
		var shape := blocker.get_child(0) as CollisionShape3D
		var box := shape.shape as BoxShape3D
		var bottom := shape.position.y - box.size.y * 0.5
		var wall_top := JsonUtil.to_vector3(prop["collider"]).y
		assert_true(is_equal_approx(bottom, wall_top), "blocker starts at the walls' top (%.2f vs %.2f)" % [bottom, wall_top])
		var bounds := Region.mesh_bounds(node)
		assert_true(box.size.x >= 2.6 and box.size.z >= 2.2, "blocker spans the roof's eaves (%s)" % box.size)
		assert_true(is_equal_approx(shape.position.y + box.size.y * 0.5, bounds.end.y), "blocker reaches the roof's peak")
	node.free()
	region.free()


func test_small_props_get_no_camera_blocker() -> void:
	var db := load_content()
	var region := Region.new()
	for suffix: String in ["crate.glb", "fence.glb", "stool.glb"]:
		var prop := _prop(db, "saltmarrow", suffix)
		if prop.is_empty():
			prop = _prop(db, "gulls_head", suffix)
		assert_true(not prop.is_empty(), "%s is placed somewhere" % suffix)
		if prop.is_empty():
			continue
		var node := region._build_prop(prop)
		assert_true(_blocker(node) == null, "%s doesn't block the camera" % suffix)
		node.free()
	region.free()


## Every building stops the camera up to its roof peak: with a blocker over the roof, or
## (the net-lofts) a walk collider that already reaches the peak.
func test_every_building_blocks_the_camera_to_its_peak() -> void:
	var db := load_content()
	var region := Region.new()
	for region_id: String in ["saltmarrow", "gulls_head"]:
		for prop: Dictionary in db.get_region(region_id)["props"]:
			if str(prop.get("shape", "")) != "house":
				continue
			var node := region._build_prop(prop)
			var top := JsonUtil.to_vector3(prop["collider"]).y
			var blocker := _blocker(node)
			if blocker:
				var shape := blocker.get_child(0) as CollisionShape3D
				top = shape.position.y + (shape.shape as BoxShape3D).size.y * 0.5
			var peak := Region.mesh_bounds(node).end.y
			assert_true(top >= peak - 0.2, "%s %s stops the camera to its peak (%.2f of %.2f)" % [region_id, prop.get("model"), top, peak])
			node.free()
	region.free()


func test_camera_snaps_in_and_eases_out() -> void:
	assert_eq(Player.next_camera_distance(7.0, 2.0, 0.016), 2.0, "jumps in to a blocking hit at once")
	var out := Player.next_camera_distance(2.0, 7.0, 0.1)
	assert_true(out > 2.0 and out < 7.0, "eases back out (%.2f)" % out)
	assert_true(is_equal_approx(out, 2.0 + Player.CAMERA_RETURN_SPEED * 0.1), "at CAMERA_RETURN_SPEED")
	assert_eq(Player.next_camera_distance(6.9, 7.0, 1.0), 7.0, "never overshoots the full distance")


func test_save_slot_labels() -> void:
	var save_system: GDScript = load("res://scripts/autoload/save_system.gd")
	assert_eq(save_system.slot_label("quick"), "Quicksave")
	assert_eq(save_system.slot_label("slot2"), "Slot 2")
	assert_eq(save_system.SLOTS.size(), 3, "three manual slots")
	assert_false(save_system.SLOTS.has(save_system.QUICK_SLOT), "the quicksave is not a manual slot")


func test_pause_is_bound() -> void:
	InputSetup.ensure_actions()
	assert_true(InputMap.has_action("pause"), "pause action registered")
	var keys: Array = InputSetup.BINDINGS["pause"]
	assert_true(keys.has(KEY_ESCAPE), "Esc pauses")
	assert_eq(InputSetup.PAD_BUTTONS["pause"], JOY_BUTTON_START, "Start pauses")
