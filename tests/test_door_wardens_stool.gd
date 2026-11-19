extends TestCase
## Day 113 — after Aldous before the Provost: the door-warden's stool, and who notices he's gone.
## Aldous (door kept) asked for a stool; the Wakebearer asks Tobin, who carries his quay-bell stool up the steps
## (`kindleby_aldous_stool`): Aldous sits on it (aldous_warden_seated) and the bell's stool is gone. Going aboard,
## Aldous leaves the bottle where he sat (`kindleby_aldous_bottle_left`): it stands corked on his bench (Saltmarrow) or
## the plank seat (Thornwold's ridge); Mara and Wynn notice him gone, kept, or home; home with leave he sits sober
## beside it (aldous_seated_sober).

const CAND := "The Provost's home. She says the candles are lit."
const KEEP := "Keep the door. This time, ask who's going by."
const HOME := "Go home. You've kept enough doors."
const STOOL := "You asked for a stool."
const ASK_TOBIN := "I'll ask him."
const STAND := "Then stand, Brother."
const BYE := "Goodbye."
const CHARS := "res://assets/models/characters/"
const BOTTLE := "res://assets/models/dressing/bottle_corked.glb"

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


## Aldous's model where he stands now, by region ("" if nowhere).
func _aldous_models(state: WorldState) -> Dictionary:
	var out := {}
	for region_id: String in _content().regions:
		for placement: Dictionary in _content().regions[region_id].get("npcs", []):
			if str(placement["npc"]) == "aldous" and Conditions.evaluate(placement.get("if", []), state):
				out[region_id] = str(placement.get("model", "")).get_file()
	return out


func _shown_props(state: WorldState, region: String, file: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop: Dictionary in _content().regions[region].get("props", []):
		if str(prop.get("model", "")).get_file() == file and Conditions.evaluate(prop.get("if", []), state):
			out.append(prop)
	return out


## The before_the_provost checkpoint's world, rebuilt for an ending and a seat (ridge or bench), Aldous told and aboard.
func _aboard(ending := "lit", ridge := true) -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_quiet_water"))
	state.set_flag("cindermoor_cradle_choice", ending)
	state.set_flag("lanes_ferry_at", "cindermoor")
	_lines(state, "provost", ["Tobin asks when you're coming home."])
	_lines(state, "oda", ["Take me out to Kindleby."])
	_lines(state, RegionEvents.fire(RegionEvents.arrival(_content().regions["kindleby"], state), state))
	state.set_flag("saltmarrow_aldous_boat", "letter")
	state.set_flag("kindleby_provost_read_letter", true)
	state.set_flag("saltmarrow_aldous_after_seen", true)
	state.set_flag("saltmarrow_aldous_crossing", "now")
	state.set_flag("saltmarrow_aldous_novice", "lamp" if ridge else "")
	state.set_flag("thornwold_aldous_landed", ridge)
	state.set_flag("thornwold_aldous_met_wynn", ridge)
	state.set_flag("thornwold_met_lamp", true)
	state.set_flag("thornwold_lamp_saw_light", true)
	_lines(state, "aldous", [CAND])
	return state


func _met(state: WorldState, pick: String) -> void:
	_lines(state, RegionEvents.fire(RegionEvents.arrival(_content().regions["kindleby"], state), state), [pick])


func test_the_bottle_stays_where_he_sat() -> void:
	for ridge: bool in [true, false]:
		var state := _aboard("released", ridge)
		assert_true(bool(state.get_flag("kindleby_aldous_bottle_left")), "set going aboard")
		var home := "thornwold_ridge" if ridge else "saltmarrow"
		var other := "saltmarrow" if ridge else "thornwold_ridge"
		assert_eq(_shown_props(state, home, "bottle_corked.glb").size(), 1, "%s: on his seat" % home)
		assert_eq(_shown_props(state, other, "bottle_corked.glb").size(), 0, "%s: not where he wasn't" % other)
		assert_eq(_aldous_models(state), {}, "below on the Mercy")
	var before := fresh_state(_content())
	for region: String in ["saltmarrow", "thornwold_ridge"]:
		before.set_flag("thornwold_aldous_landed", region == "thornwold_ridge")
		assert_eq(_shown_props(before, region, "bottle_corked.glb").size(), 0, "%s: no bottle before he goes" % region)


func test_the_bottle_stands_on_the_seat() -> void:
	# On the plank's end, at the seat height, turned with the bench; standing on the seat (not sunk, not floating).
	var node := (load(BOTTLE) as PackedScene).instantiate() as Node3D
	var bounds := Region.mesh_bounds(node)
	node.free()
	assert_true(absf(bounds.position.y) < 0.01, "origin at its base")
	assert_true(bounds.size.y > 0.28 and bounds.size.y < 0.4, "a bottle's height (%.2f)" % bounds.size.y)
	for region_id: String in ["saltmarrow", "thornwold_ridge"]:
		var bench: Dictionary = {}
		var bottle: Dictionary = {}
		for prop: Dictionary in _content().regions[region_id]["props"]:
			match str(prop.get("model", "")).get_file():
				"plank_bench.glb": bench = prop
				"bottle_corked.glb": bottle = prop
		var b := JsonUtil.to_vector3(bench["position"])
		var p := JsonUtil.to_vector3(bottle["position"])
		assert_true(absf(p.y - 0.44) < 0.01, "%s: at the seat's height" % region_id)
		var along := Vector3(1, 0, 0).rotated(Vector3.UP, deg_to_rad(float(bench.get("rotation_y", 0))))
		var off := Vector3(p.x - b.x, 0, p.z - b.z)
		assert_true(absf(off.dot(along)) > 0.4 and absf(off.dot(along)) < 0.6, "%s: at the plank's end (%.2f)" % [region_id, off.dot(along)])
		assert_true(absf(off.cross(along).y) < 0.05, "%s: on the plank's line" % region_id)
		var region: Dictionary = _content().regions[region_id]
		var field := TerrainField.from_data(region["ground"], float(region.get("water_level", -10.0)))
		var step := absf(field.surface_at(p.x, p.z) - field.surface_at(b.x, b.z))
		assert_true(step < 0.03, "%s: the ground under the bottle is the bench's (%.3f)" % [region_id, step])


func test_mara_and_wynn_notice() -> void:
	# Gone, before the meeting.
	var bench := _aboard("lit", false)
	assert_true(_lines(bench, "mara").contains("Tam walks round it"), "Mara: gone")
	var ridge := _aboard("lit", true)
	var said := _lines(ridge, "lamp")
	assert_true(said.contains("I sat in his end of the bench"), said)
	assert_false(said.contains("He snores."), "he's not there to snore")
	# Kept.
	_met(bench, KEEP)
	said = _lines(bench, "mara")
	assert_true(said.contains("If he wants it he can come and ask me for it."), said)
	assert_false(said.contains("Tam walks round it"), "not 'gone' any more")
	_met(ridge, KEEP)
	said = _lines(ridge, "lamp")
	assert_true(said.contains("I don't like it as much as I did."), said)
	assert_false(said.contains("It was warm."), said)
	# Home with leave.
	var bench_home := _aboard("released", false)
	_met(bench_home, HOME)
	said = _lines(bench_home, "mara")
	assert_true(said.contains("So I didn't say it."), said)
	assert_true(_lines(bench_home, "aldous", [BYE]).contains("He doesn't look at it."), "the corked bottle beside him")
	var ridge_home := _aboard("released", true)
	_met(ridge_home, HOME)
	said = _lines(ridge_home, "lamp")
	assert_true(said.contains("He snores with leave now."), said)
	assert_false(said.contains("He snores. Thirty winters"), "the old line gives way")
	assert_true(_lines(ridge_home, "aldous", [BYE]).contains("Wynn has dusted round it."))
	# Nobody remarks on it when he never went (the ridge Aldous, before the Provost's home).
	var still := fresh_state(_content())
	still.set_flag("thornwold_aldous_met_wynn", true)
	still.set_flag("thornwold_met_lamp", true)
	still.set_flag("thornwold_lamp_saw_light", true)
	assert_true(_lines(still, "lamp").contains("He snores. Thirty winters"))


func test_home_he_sits_sober_beside_it() -> void:
	for ridge: bool in [true, false]:
		var state := _aboard("lit", ridge)
		_met(state, HOME)
		var where := "thornwold_ridge" if ridge else "saltmarrow"
		assert_eq(_aldous_models(state), {where: "aldous_seated_sober.glb"}, where)
		assert_eq(_shown_props(state, where, "bottle_corked.glb").size(), 1, "%s: still beside him" % where)
	# Before he ever went, the bottle's in his hand.
	var before := fresh_state(_content())
	assert_eq(_aldous_models(before), {"saltmarrow": "aldous_seated.glb"})


func test_the_stool() -> void:
	var state := _aboard("lit", true)
	_met(state, KEEP)
	assert_eq(_aldous_models(state), {"kindleby": "aldous_warden.glb"}, "standing first")
	assert_eq(_shown_props(state, "kindleby", "stool.glb").size(), 1, "the stool by the quay bell")
	assert_true(_lines(state, "provost").contains("I said a warden stands"), "the Provost, before")
	# Told to stand: nothing moves, and he can still be asked.
	var said := _lines(state, "aldous", [STOOL, STAND])
	assert_true(said.contains("I'll stand."), said)
	assert_false(bool(state.get_flag("kindleby_aldous_stool")))
	# Asked for: Tobin carries it up.
	said = _lines(state, "aldous", [STOOL, ASK_TOBIN])
	assert_true(said.contains("He can have it."), said)
	assert_true(said.contains("I'm stopping here."), said)
	assert_true(bool(state.get_flag("kindleby_aldous_stool")))
	assert_eq(_aldous_models(state), {"kindleby": "aldous_warden_seated.glb"}, "sitting on it")
	assert_eq(_shown_props(state, "kindleby", "stool.glb").size(), 0, "gone from the bell")
	said = _lines(state, "aldous", [BYE])
	assert_true(said.contains("sits on Tobin's stool"), said)
	assert_false(said.contains("stands by the chapter-house steps"), said)
	var offered: Array[String] = []
	_lines(state, "aldous", [BYE], offered)
	assert_false(offered.has(STOOL), "asked once")
	assert_true(_lines(state, "provost").contains("on Tobin's stool by six"), "the Provost, after")
	assert_true(_lines(state, "tobin", [BYE]).contains("Brother Wren's got my stool."), "Tobin, after")


func test_the_seated_warden_model() -> void:
	# The stool is part of the model: its seat at the seated hip, its feet on the ground.
	var node := (load(CHARS + "aldous_warden_seated.glb") as PackedScene).instantiate() as Node3D
	var stool := node.find_child("Stool", true, false) as Node3D
	assert_true(stool != null, "a Stool part")
	var bounds := Region.mesh_bounds(node)
	node.free()
	assert_true(absf(bounds.position.y) < 0.02, "feet and stool legs on the ground (%.3f)" % bounds.position.y)
	assert_true(bounds.end.y > 1.2 and bounds.end.y < 1.6, "a seated height (%.2f)" % bounds.end.y)
	var sober := (load(CHARS + "aldous_seated_sober.glb") as PackedScene).instantiate() as Node3D
	assert_true(sober.find_child("Stool", true, false) == null, "the bench is a prop, not part of him")
	sober.free()


func test_the_checkpoint() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_door_wardens_stool"))
	assert_eq(_aldous_models(state), {"kindleby": "aldous_warden_seated.glb"})
	assert_eq(_shown_props(state, "kindleby", "stool.glb").size(), 0)
	assert_eq(_shown_props(state, "thornwold_ridge", "bottle_corked.glb").size(), 1, "the bottle on the ridge seat")
	assert_true(RegionEvents.arrival(_content().regions["kindleby"], state).is_empty(), "everything seen")
