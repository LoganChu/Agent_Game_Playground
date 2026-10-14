extends TestCase
## Day 42 — Wrackholm, part two: the Teeth. Wenna remembers nobody ever knew the way across by
## heart (you put your feet on the lampwardens' white-lead marks); the spring tide waited down at
## the spit's end; the ember brings the marks back; the crossing on the white to the Wrack's stack
## (region `wrack_teeth`), its lantern room framed in tagged timbers off boats that never came home
## (*A Light for Wrackholm* → `feed_the_wrack`); back before the flood; Jory goes up to Wenna.

const HOLM := "wrackholm"
const TEETH := "wrack_teeth"
const WRACK := "What would it take to light the Wrack?"
const ABOUT := "About the Teeth."
const WAIT := "Wait for the ebb."
const HOLD := "Hold the ember to the rock."
const BACK := "Go back across before the flood."
const SEEN := "I've been out to the Wrack."
const RUAN := "Did Ruan ever take you out on the Teeth?"
const NAMES := "The Gannet's crew: Hale Corbet, master. Annis Corbet. Ruan Pask."
const KIT := "res://assets/models/dressing/"
## build_wrackholm: the reef slab's top over its origin, and the Wrack's door sill (the stack's top)
## and door face in Godot model space.
const TEETH_TOP := 0.42
const WRACK_DOOR := Vector3(0, 3.5, 1.33)

var _db: ContentDatabase


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_db, state, dialogue, typed, offered)


func _offered(state: WorldState, dialogue: String) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [], offered)
	return offered


## On Wrackholm with the Wrack asked about (stage `the_teeth`); the board read and the names said
## into the horn unless `named` is false.
func _at_the_teeth(named: bool = true) -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "saltmarrow_ferry_arrived", "thornwold_landed", "fen_landed",
			"fen_dunstan_met", "wrackholm_landed", "wrackholm_met_wenna", "wrackholm_met_jory"]:
		state.set_flag(flag, true)
	state.set_flag("lanes_ferry_at", HOLM)
	state.start_quest("a_light_for_wrackholm", "the_lashed_horn")
	if named:
		state.set_flag("wrackholm_board_read", true)
		state.start_quest("the_gannets_crew", "say_the_names")
		_lines(state, "wenna", [NAMES])
	_lines(state, "wenna", [WRACK])
	assert_eq(state.quest_stage("a_light_for_wrackholm"), "the_teeth")
	return state


## ...and across: the white told, the tide waited down, the marks brought back, the crossing played.
func _across(named: bool = true) -> WorldState:
	var state := _at_the_teeth(named)
	_lines(state, "wenna", [ABOUT])
	_lines(state, "teeth_spit", [WAIT, HOLD])
	var teeth := _db.get_region(TEETH)
	assert_eq(RegionEvents.fire(RegionEvents.arrival(teeth, state), state), "teeth_crossing", "the crossing on the white")
	_lines(state, "teeth_crossing")
	return state


func _xz(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[2]))


func _exit(state: WorldState) -> bool:
	var exits: Array = (_db.get_region(HOLM)["exits"] as Array).filter(func(e: Dictionary) -> bool: return e["to"] == TEETH)
	assert_eq(exits.size(), 1, "one way onto the Teeth")
	return Conditions.evaluate(exits[0].get("requires"), state)


func _shown(region_id: String, model: String, state: WorldState) -> int:
	var n := 0
	for p: Dictionary in _db.get_region(region_id)["props"]:
		if str(p.get("model", "")) == KIT + model + ".glb" and Conditions.evaluate(p.get("if"), state):
			n += 1
	return n


func test_wenna_remembers_the_white() -> void:
	var state := _at_the_teeth()
	var text := _lines(state, "wenna", [ABOUT])
	assert_true(text.contains("I've remembered I never knew") and text.contains("You put them on the white"), "nobody knew the Teeth by heart")
	assert_true(text.contains("Hale Corbet did it") and not text.contains("can't give you his name"), "the names said, she names Hale")
	assert_true(text.contains("wait it down"), "...and sends you to the spit's end")
	assert_true(state.get_flag("wrackholm_teeth_marks_told") == true)
	assert_eq(state.quest_stage("a_light_for_wrackholm"), "the_marks")
	var offered := _offered(state, "wenna")
	assert_eq(offered.count(ABOUT), 1, "one 'About the Teeth.' at a time")
	assert_true(_lines(state, "wenna", [ABOUT]).contains("The white's there or it isn't"), "the short answer after")
	# Before the names come back she can't say whose hand painted the white.
	var unnamed := _at_the_teeth(false)
	var early := _lines(unnamed, "wenna", [ABOUT])
	assert_true(early.contains("can't give you his name") and not early.contains("Hale"), "no names out of the fog (%s)" % early)
	assert_false(_lines(unnamed, "wenna", [ABOUT]).contains("Hale"))


func test_the_spit_and_the_spring_tide() -> void:
	var state := _at_the_teeth()
	var before := _lines(state, "teeth_spit", [], [])
	assert_true(before.contains("You'd want to know where to put your feet"), "nobody's said yet")
	assert_true(_offered(state, "teeth_spit").is_empty(), "and nothing to do but look")
	assert_false(_exit(state), "the Teeth are under")
	assert_eq(_shown(HOLM, "teeth_rock", state) + _shown(HOLM, "teeth_mark", state), 0, "no Teeth up at high water")
	_lines(state, "wenna", [ABOUT])
	assert_true(_offered(state, "teeth_spit").has(WAIT), "told, you can wait it down")
	_lines(state, "teeth_spit", ["Not yet."])
	assert_eq(state.get_flag("wrackholm_tide"), "", "not waiting leaves the tide in")
	var ebb := _lines(state, "teeth_spit", [WAIT, "Not yet."])
	assert_true(ebb.contains("breath goes out of a sleeper") and ebb.contains("shape of nothing"), "the ebb, and a smear on the first rock")
	assert_eq(state.get_flag("wrackholm_tide"), "low")
	assert_false(_exit(state), "low water, but no way to put your feet")
	assert_eq(_shown(HOLM, "teeth_rock", state), 3, "the Teeth stand up off the spit, bare")
	assert_eq(_shown(HOLM, "teeth_mark", state), 0)
	var marks := _lines(state, "teeth_spit", [HOLD])
	assert_true(marks.contains("only backward") and marks.contains("laying them down"), "the ember brings the white back")
	assert_true(state.get_flag("wrackholm_teeth_marks") == true)
	assert_true(_exit(state), "now the Teeth can be crossed")
	assert_eq(_shown(HOLM, "teeth_rock", state), 0, "the same rocks...")
	assert_eq(_shown(HOLM, "teeth_mark", state), 3, "...carry the white")
	assert_true(_lines(state, "teeth_spit").contains("a hand on each"), "at low water after: the white out into the fog")
	# The flood back: the spit offers the wait again, and needs no second ember.
	state.set_flag("wrackholm_tide", "")
	assert_false(_exit(state), "under again at the flood")
	var again := _lines(state, "teeth_spit", [WAIT])
	assert_false(again.contains("shape of nothing"), "the white is already back")
	assert_true(_exit(state))


func test_the_crossing_the_lantern_room_and_back() -> void:
	var state := _across()
	var teeth := _db.get_region(TEETH)
	assert_true(state.get_flag("wrackholm_teeth_crossed") == true)
	assert_true(RegionEvents.arrival(teeth, state).is_empty(), "the crossing scene plays once")
	var fresh := fresh_state(_db)
	assert_true(RegionEvents.arrival(teeth, fresh).is_empty(), "never without the white (a debug jump in)")
	var room := _lines(state, "wrack_light")
	assert_true(room.contains("ships' timbers") and room.contains("lead tag") and room.contains("KITTIWAKE"), "the tagged timbers")
	assert_true(room.contains("new iron bracket") and room.contains("it won't burn what nobody holds"), "the empty bracket and the cold cradle")
	assert_true(room.contains("A horn and a light, facing each other"), "the horn across the water")
	assert_eq(state.quest_stage("a_light_for_wrackholm"), "feed_the_wrack")
	var again := _lines(state, "wrack_light")
	assert_true(again.contains("It wants something somebody on Wrackholm holds") and not again.contains("KITTIWAKE"), "short after")
	# Back before the flood: the tide comes in behind you, onto the hard.
	assert_true(_offered(state, "teeth_way_back").has(BACK))
	_lines(state, "teeth_way_back", ["Not yet."])
	assert_eq(state.get_flag("wrackholm_tide"), "low", "staying keeps the tide down")
	var back := _lines(state, "teeth_way_back", [BACK])
	assert_true(back.contains("flood at your heels"))
	assert_eq(state.get_flag("wrackholm_tide"), "", "the flood")
	var step: Dictionary = (_db.dialogues["teeth_way_back"]["knots"]["back"] as Array).back()
	assert_eq(step.get("travel"), [HOLM, "from_teeth"], "back up the hard")
	var holm := _db.get_region(HOLM)
	var spawn: Array = holm["spawn_points"]["from_teeth"]
	assert_true(Greying.depth_at(Greying.worst_case_areas(holm), _xz(spawn)) < Greying.CLEAR_DEPTH, "the hard's spawn is clear of fog")
	# Wenna, told of the room.
	var seen := _lines(state, "wenna", [SEEN])
	assert_true(seen.contains("A year and a tide") and seen.contains("Hale fitted it himself"), "the Gannet's bracket")
	assert_true(seen.contains("I'll sit with that a while"), "she'll think on what she holds")


func test_the_teeth_layout() -> void:
	_db = load_content()
	var region := _db.get_region(TEETH)
	var field := TerrainField.from_data(region["ground"], float(region["water_level"]))
	var spawn: Array = region["spawn_points"]["from_hard"]
	var reach := field.reachable_from(float(spawn[0]), float(spawn[2]))
	var areas := Greying.worst_case_areas(region)
	assert_true(Greying.depth_at(areas, _xz(spawn)) < Greying.CLEAR_DEPTH, "the spit's end is clear")
	for object: Dictionary in region["objects"]:
		assert_true(field.near_reachable(reach, float(object["position"][0]), float(object["position"][2]), 1.0), "%s can be walked to" % object["id"])
	# The marks: a road of them, each on reachable reef, in the fog, running on west toward the Wrack, the
	# slab's top just proud of the ground (feet go on the white).
	var marks: Array = (region["props"] as Array).filter(func(p: Dictionary) -> bool: return p["model"] == KIT + "teeth_mark.glb")
	assert_true(marks.size() >= 6, "a mark every few strides (%d)" % marks.size())
	var last_x := INF
	for m: Dictionary in marks:
		var at := _xz(m["position"])
		assert_true(field.near_reachable(reach, at.x, at.y, 0.6), "mark at %s is on the road" % at)
		assert_true(at.x < last_x, "marks run west, in order")
		last_x = at.x
		assert_true(bool(m.get("snap", true)) and absf(float(m["position"][1]) + TEETH_TOP) < 0.06, "the slab sits flush, its top a few cm proud")
		var depth := Greying.depth_at(areas, at)
		assert_true(at.x > 19.0 or (depth > 0.3 and depth < 0.8), "fog over the white, thin enough to see the next mark (%.2f)" % depth)
	# The Wrack: its door turned to the ramp's top, the sill at the walkable ground there.
	var wrack: Dictionary = (region["props"] as Array).filter(func(p: Dictionary) -> bool: return p["model"] == KIT + "wrack_light.glb")[0]
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(wrack["rotation_y"]))), JsonUtil.to_vector3(wrack["position"]))
	var door := xf * WRACK_DOOR
	var object: Dictionary = (region["objects"] as Array).filter(func(o: Dictionary) -> bool: return o["id"] == "wrack_door")[0]
	var spot := _xz(object["position"])
	assert_true(spot.distance_to(Vector2(door.x, door.z)) < 1.2, "the door object stands at the Wrack's door (%s vs %s)" % [spot, door])
	assert_true(absf(field.height_at(spot.x, spot.y) - door.y) < 0.3, "the sill meets the ramp's top (%.2f vs %.2f)" % [field.height_at(spot.x, spot.y), door.y])
	assert_true(field.near_reachable(reach, door.x, door.z, 1.0), "...which can be walked to")
	assert_true(Greying.depth_at(areas, spot) * 0.5 < Greying.MAX_ONE_WAY_EMBER, "the door is in the fog, not drowned in it")


func test_jory_goes_up_to_wenna() -> void:
	var holm: Dictionary
	for told: String in ["wenna", "keepers", "dark", ""]:
		var state := _across()
		holm = _db.get_region(HOLM)
		state.set_flag("wrackholm_who_answered", told)
		var fired := RegionEvents.fire(RegionEvents.arrival(holm, state), state)
		assert_eq(fired == "jory_goes_up", told == "wenna", "he goes up only knowing it was her answer (%s)" % told)
		if told != "wenna":
			continue
		assert_true(RegionEvents.arrival(holm, state).is_empty(), "once")
		var scene := _lines(state, "jory_goes_up")
		assert_true(scene.contains("Copper's off.") and scene.contains("takes hold of his sleeve"), "copper off, he went up")
		var placed: Array = (holm["npcs"] as Array).filter(func(n: Dictionary) -> bool:
			return n["npc"] == "jory" and Conditions.evaluate(n.get("if"), state))
		assert_eq(placed.size(), 1, "one Jory")
		var horn: Dictionary = (holm["objects"] as Array).filter(func(o: Dictionary) -> bool: return o["id"] == "answering_horn")[0]
		assert_true(_xz(placed[0]["position"]).distance_to(_xz(horn["position"])) < 4.0, "by Wenna at the horn")
		assert_true(_lines(state, "jory").contains("I came up"), "Jory at the horn")
		assert_true(_lines(state, "wenna").contains("He came up"), "Wenna on it")
		_lines(state, "wrack_light")
		assert_true(_lines(state, "wenna", [SEEN]).contains("The lad and I will sit with that"), "the two of them, on the Wrack")
	# Without the crossing he's still at the copper, whatever he was told.
	var stay := _at_the_teeth()
	stay.set_flag("wrackholm_who_answered", "wenna")
	assert_true(RegionEvents.arrival(_db.get_region(HOLM), stay).is_empty(), "not before the copper's off")


func test_jory_remembers_the_white() -> void:
	var state := _at_the_teeth()
	assert_false(_offered(state, "jory").has(RUAN), "not before he has his brother's name back")
	state.set_flag("wrackholm_jory_brother", true)
	assert_false(_offered(state, "jory").has(RUAN), "nor before the white is told of")
	_lines(state, "wenna", [ABOUT])
	var text := _lines(state, "jory", [RUAN])
	assert_true(text.contains("Put your feet where the white is") and text.contains("I don't remember where it was"), "the white, not where")
	_lines(state, "teeth_spit", [WAIT, HOLD])
	_lines(state, "wrack_light")
	assert_false(_offered(state, "jory").has(RUAN), "only while the white is still to find")


func test_the_teeth_kit() -> void:
	# The marked slab carries its white on top, where feet go; the plain slab has none.
	for model: String in ["teeth_mark", "teeth_rock"]:
		var node := (load(KIT + model + ".glb") as PackedScene).instantiate() as Node3D
		var white := false
		var top := 0.0
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var box := mi.transform * mi.get_aabb()
			top = maxf(top, box.end.y)
			if mi.name.begins_with("bone"):
				white = box.end.y > TEETH_TOP - 0.02 and box.end.y < TEETH_TOP + 0.05
		assert_eq(white, model == "teeth_mark", "%s: white lead on its back only if marked" % model)
		assert_true(absf(top - TEETH_TOP) < 0.06, "%s: top at %.2f" % [model, top])
		node.free()
	# The Wrack's timbers keep their lead tags.
	var wrack := (load(KIT + "wrack_light.glb") as PackedScene).instantiate() as Node3D
	var tags := false
	for mi: MeshInstance3D in wrack.find_children("*", "MeshInstance3D", true, false):
		var box := mi.transform * mi.get_aabb()
		if mi.name.begins_with("slate_l25"):
			tags = box.size.x > 1.8 and box.position.y > 7.0
	assert_true(tags, "lead tags ring the lantern room")
	wrack.free()
