extends TestCase
## Day 32 — Saltmarrow art: Aldous seated on a plank bench by the Wrens' steps (`aldous_seated`,
## the "bottle" idle: a swig now and then), and the two net-lofts by the boardwalk gate broken
## before the burn and half-mended after it (`net_loft_broken` → `net_loft_mended`).

const REGION := "saltmarrow"
const DRESSING := "res://assets/models/dressing/"
const SEATED := "res://assets/models/characters/aldous_seated.glb"
const BURNED := "quest:a_light_for_saltmarrow=done"

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _props(file: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop: Dictionary in _content().get_region(REGION)["props"]:
		if str(prop.get("model", "")).get_file() == file:
			out.append(prop)
	return out


func test_aldous_sits_on_his_bench() -> void:
	var places: Array[Dictionary] = []
	for placement: Dictionary in _content().get_region(REGION)["npcs"]:
		if str(placement.get("npc", "")) == "aldous":
			places.append(placement)
	assert_eq(places.size(), 1, "Aldous has one place in Saltmarrow")
	var aldous: Dictionary = places[0]
	assert_eq(str(aldous.get("model", "")), SEATED)
	assert_eq(str(aldous.get("idle", "")), "bottle")
	assert_false(aldous.has("if"), "he's always on it")
	var benches := _props("plank_bench.glb")
	assert_eq(benches.size(), 1, "one bench")
	assert_eq(benches[0].get("position"), aldous.get("position"), "Aldous sits on it")
	assert_eq(float(benches[0].get("rotation_y", 0)), float(aldous.get("rotation_y", 0)), "facing the way the bench faces")
	assert_false(benches[0].has("if"), "the bench is there whatever he's told you")
	# The seat is a seated model's seat height (build_characters.Body: hip 0.46), like log_bench.
	var node := (load(DRESSING + "plank_bench.glb") as PackedScene).instantiate() as Node3D
	var bounds := Region.mesh_bounds(node)
	node.free()
	assert_true(absf(bounds.end.y - 0.44) < 0.03, "seat top at 0.44 m (got %.2f)" % bounds.end.y)
	assert_true(bounds.size.x > 1.1 and bounds.size.x < 1.5, "a bench for one or two")
	# By the Wrens' steps (LORE), not out on the walkway.
	var house := JsonUtil.to_vector3(_props("house_wren.glb")[0]["position"])
	var d := house.distance_to(JsonUtil.to_vector3(aldous["position"]))
	assert_true(d > 2.0 and d < 4.0, "by his family's house (%.1f m)" % d)
	# The NPC itself still stands everywhere else (the lineup, any later placement).
	assert_eq(str(_content().npcs["aldous"]["model"]).get_file(), "aldous.glb")


## Where a part's meshes sit in the model (centre of their bounds), through the rig's parents.
func _part_centre(model: Node3D, part: String) -> Vector3:
	var node := model.find_child(part, true, false) as Node3D
	var xf := node.transform
	var parent := node.get_parent() as Node3D
	while parent != null and parent != model:
		xf = parent.transform * xf
		parent = parent.get_parent() as Node3D
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var b := mi.transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if node is MeshInstance3D:
		var own := (node as MeshInstance3D).get_aabb()
		box = own if first else box.merge(own)
	return xf * box.get_center()


## The "bottle" idle: the bottle on his thigh most of the time; once a cycle it comes up to his
## mouth and his head goes back, then down again. The legs stay put.
func test_the_bottle_idle_swigs() -> void:
	assert_true("bottle" in CharacterRig.STYLES)
	assert_eq(CharacterRig.bottle_swig(1.0), 0.0, "the bottle on his thigh")
	var top := 0.0
	var at := 0.0
	var up_time := 0.0
	for i in int(CharacterRig.BOTTLE_PERIOD * 50.0):
		var t := i * 0.02
		var s := CharacterRig.bottle_swig(t)
		if s > 0.05:
			up_time += 0.02
		if s > top:
			top = s
			at = t
	assert_true(top > 0.95, "all the way up")
	assert_true(up_time < CharacterRig.BOTTLE_PERIOD * 0.35, "a swig, not a sit with the bottle up (%.1f s)" % up_time)
	assert_eq(CharacterRig.bottle_swig(at + CharacterRig.BOTTLE_PERIOD), CharacterRig.bottle_swig(at), "every cycle")

	var model := CharacterRig.instantiate(SEATED, "bottle")
	var rig := model.get_node("CharacterRig") as CharacterRig
	rig._ready()
	var head := model.find_child("Head", true, false) as Node3D
	var leg := model.find_child("LegL", true, false) as Node3D
	var leg_rest := leg.transform
	rig.pose(1.0)
	var hand_down := _part_centre(model, "ArmL")
	var face := _part_centre(model, "Head")
	var head_rest := head.transform.basis.z
	rig.pose(at)
	var hand_up := _part_centre(model, "ArmL")
	assert_true(hand_up.y > hand_down.y + 0.25, "the bottle comes up (%.2f → %.2f)" % [hand_down.y, hand_up.y])
	assert_true(absf(hand_up.x - face.x) < absf(hand_down.x - face.x), "and in toward his mouth")
	assert_true(head.transform.basis.z.y > head_rest.y + 0.1, "his head goes back")
	assert_true(leg.transform.is_equal_approx(leg_rest), "the legs stay put")
	rig.pose(1.0, 2.0, 1.0)
	assert_true(leg.transform.is_equal_approx(leg_rest), "a sitter doesn't swing his legs")
	model.free()


## The two lofts by the boardwalk gate: broken while the fog sits on them, half-mended once the
## Gull is lit — one model per spot either way, on the same footprint and collider.
func test_gate_lofts_mend_after_the_burn() -> void:
	assert_eq(_props("net_loft.glb").size(), 0, "no whole lofts by the gate any more")
	var broken := _props("net_loft_broken.glb")
	var mended := _props("net_loft_mended.glb")
	assert_eq(broken.size(), 2, "two broken lofts")
	assert_eq(mended.size(), 2, "two mended ones")
	for k in 2:
		assert_eq(mended[k]["position"], broken[k]["position"], "mended where it was broken")
		assert_eq(mended[k]["rotation_y"], broken[k]["rotation_y"], "turned the same")
		assert_eq(mended[k]["collider"], broken[k]["collider"], "same collider")
	for burned: bool in [false, true]:
		var state := fresh_state(_content())
		state.start_quest("a_light_for_saltmarrow", "speak_to_aldous")
		if burned:
			state.set_flag("saltmarrow_beacon_burned", "gull")
			state.complete_quest("a_light_for_saltmarrow")
		var shown: Array[String] = []
		for prop: Dictionary in broken + mended:
			if Conditions.evaluate(prop["if"], state):
				shown.append(str(prop["model"]).get_file())
		var want := "net_loft_mended.glb" if burned else "net_loft_broken.glb"
		assert_eq(shown, [want, want] as Array[String], "%s: both lofts %s" % ["burned" if burned else "unlit", want])


func test_mended_loft_keeps_the_broken_footprint() -> void:
	var boxes: Array[AABB] = []
	for file: String in ["net_loft_broken.glb", "net_loft_mended.glb"]:
		var node := (load(DRESSING + file) as PackedScene).instantiate() as Node3D
		boxes.append(Region.mesh_bounds(node))
		node.free()
	var broken := boxes[0]
	var mended := boxes[1]
	assert_true(absf(mended.end.y - broken.end.y) < 0.15, "same roof height")
	# Inside the broken loft's footprint: the slid roof strip is gone, nothing new sticks out.
	assert_true(mended.position.x >= broken.position.x - 0.05 and mended.end.x <= broken.end.x + 0.05, "no wider")
	assert_true(mended.position.z >= broken.position.z - 0.05 and mended.end.z <= broken.end.z + 0.05, "no deeper")
	assert_true(mended.position.y > -0.05, "stands on its origin")
