extends TestCase
## Day 23 polish pass: lantern pools fade when the light changes (the fog layers dissolve
## from the old cut to the new), settings save as they change, the interaction prompt
## follows a rebound key, and inspectables glint.

const SCRATCH := "user://test_polish_two.cfg"


func _flat(_x: float, _z: float) -> float:
	return 0.0


func test_recut_mesh_carries_both_cuts() -> void:
	var fog := {"rect": [-6, -6, 6, 6], "falloff": 1.0}
	var lamp: Array[Dictionary] = [{"ellipse": [0, 0, 3, 3], "falloff": 1.0, "clear": true}]
	var none: Array[Dictionary] = []
	var whole := GreyingFog.build_mesh(fog, _flat)
	var fading := GreyingFog.build_mesh(fog, _flat, lamp, none)
	var arrays := fading.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var whole_verts := (whole.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	assert_eq(verts.size(), whole_verts, "while the old (unlit) cut fades, the pool's triangles stay")
	var centre_new := -1.0
	var centre_old := -1.0
	for i in verts.size():
		if Vector2(verts[i].x, verts[i].z).length() < 0.01:
			centre_new = colors[i].a
			centre_old = uv2[i].x
			break
	assert_eq(centre_new, 0.0, "the new cut is clear under the lantern")
	assert_true(centre_old > 0.0, "the old cut still has fog there (%.2f)" % centre_old)
	# Putting the lantern out: the pool's triangles are there to fade fog back in.
	var dousing := GreyingFog.build_mesh(fog, _flat, none, lamp)
	assert_eq((dousing.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), whole_verts,
		"a lantern going out keeps every triangle")
	# Without a cut to fade from, both channels agree (the shader's blend is a no-op).
	var settled := GreyingFog.build_mesh(fog, _flat, lamp)
	var s_arrays := settled.surface_get_arrays(0)
	var s_colors: PackedColorArray = s_arrays[Mesh.ARRAY_COLOR]
	var s_uv2: PackedVector2Array = s_arrays[Mesh.ARRAY_TEX_UV2]
	var same := true
	for i in s_colors.size():
		same = same and s_uv2[i].x == s_uv2[i].y and absf(s_colors[i].a - s_uv2[i].y) < 0.01  # colours are 8-bit
	assert_true(same, "a settled mesh has one cut in both channels")


func test_fog_node_fades_a_recut() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var fog_area := {"rect": [-6, -6, 6, 6], "falloff": 1.0}
	var lamp: Array[Dictionary] = [{"ellipse": [0, 0, 3, 3], "falloff": 1.0, "clear": true}]
	var none: Array[Dictionary] = []
	var fog := GreyingFog.new()
	fog.setup(fog_area, _flat)
	root.add_child(fog)
	fog.recut(lamp, none, true)
	assert_eq(fog.recut_progress(), 0.0, "an animated re-cut starts from the old cut")
	fog.recut(none, lamp, false)
	assert_eq(fog.recut_progress(), 1.0, "an instant re-cut (region load) is settled at once")
	fog.free()


func test_prompt_follows_a_rebound_interact_key() -> void:
	DirAccess.remove_absolute(SCRATCH)
	var settings := GameSettings.new()
	settings.path = SCRATCH
	GameSettings.set_current(settings)
	var hud := Hud.new()
	hud._build()
	var target := Interactable.new()
	target.prompt = "Talk to Mara"
	hud.set_focus(target)
	assert_eq(hud.prompt_text(), "[E] Talk to Mara", "default prompt")
	settings.rebind("interact", KEY_G)
	assert_eq(hud.prompt_text(), "[G] Talk to Mara", "the prompt re-labels at once")
	hud.set_focus(null)
	settings.rebind("interact", KEY_E)
	assert_eq(hud.prompt_text(), "", "a hidden prompt stays hidden")
	target.free()
	hud.free()
	DirAccess.remove_absolute(SCRATCH)
	GameSettings.new().apply_all()
	GameSettings.set_current(null)


func test_inspectables_glint() -> void:
	var object := Inspectable.new()
	object.setup({"id": "x", "prompt": "Examine", "dialogue": "x", "position": [0, 0, 0], "reach": 1.5})
	assert_true(object.glint != null, "an object glints by default")
	assert_eq(object.glint.position, Glint.DEFAULT_OFFSET, "at the default height")
	assert_eq(object.glint.reach, 1.5, "and knows the object's reach")
	object.free()
	var low := Inspectable.new()
	low.setup({"id": "y", "prompt": "Examine", "dialogue": "y", "position": [0, 0, 0], "glint": [0, 0.8, 0]})
	assert_eq(low.glint.position, Vector3(0, 0.8, 0), "`glint` places it")
	low.free()
	var plain := Inspectable.new()
	plain.setup({"id": "z", "prompt": "Examine", "dialogue": "z", "position": [0, 0, 0], "glint": false})
	assert_true(plain.glint == null, "`glint: false` opts out")
	plain.free()


func test_glint_shows_in_the_middle_distance() -> void:
	assert_eq(Glint.strength_at(1.0, 1.8), 0.0, "within reach the prompt takes over")
	assert_eq(Glint.strength_at(5.0, 1.8), 1.0, "a few steps away it shows fully")
	assert_eq(Glint.strength_at(Glint.SHOW_FROM + 1.0, 1.8), 0.0, "far off, nothing")
	var edge := Glint.strength_at(Glint.SHOW_FROM - Glint.FADE_SPAN * 0.5, 1.8)
	assert_true(edge > 0.0 and edge < 1.0, "it fades in with distance (%.2f)" % edge)


func test_every_placed_object_glints_somewhere_sensible() -> void:
	var db := load_content()
	for region_id: String in db.regions:
		for object: Dictionary in db.get_region(region_id).get("objects", []):
			var spot: Variant = object.get("glint", null)
			if spot is Array:
				var y := float((spot as Array)[1])
				assert_true(y > 0.2 and y < 4.0, "%s glint height %.2f" % [object["id"], y])


func test_validator_checks_glint() -> void:
	var db := load_content()
	(db.regions["saltmarrow"]["objects"] as Array)[0]["glint"] = "high"
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	assert_true(validator.report().contains("glint must be false or [x, y, z]"), validator.report())
