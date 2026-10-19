extends TestCase
## Day 51 — *The Walk Back*. Back on the fen once the Wrack is lit, Dunstan's lantern has come
## halfway in along the long walk and stopped: the boards are laid for going in. The player walks
## ahead of him with the ember; at the staithe's foot he asks Hesper for his name himself (after the
## gull burn it slides off the player). Then the player's word: home to Saltmarrow (rowing backward;
## Mara and the stool, or a stranger who drinks the second cup), stay and turn the boards, or "yours
## to choose" (home).

const FEN := "glasswater_fen"
const SALTMARROW := "saltmarrow"
const WALK := "Walk ahead of him with the ember."
const WAIT := "Not yet. Wait here."
const HOME := "Go home. Mara's keeping the stool."
const CUP := "There's a second cup going cold by her door. Go home and drink it."
const STAY := "Stay a while. Till you're sure it's done."
const YOURS := "That's yours to choose. Not mine."
const CHARS := "res://assets/models/characters/"

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


func _offered(state: WorldState, dialogue: String) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [], offered)
	return offered


## Dunstan found at the end of the long walk; the Wrack lit (or not); `burn` fed the Gull.
func _found(wrack: String = "white", burn: String = "knot", heron: String = "channels") -> WorldState:
	var state := fresh_state(_content())
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "thornwold_landed", "fen_landed", "fen_met_hesper",
			"fen_met_corran", "fen_heard_of_dunstan", "fen_heron_reached", "fen_heron_climbed", "fen_lantern_seen",
			"fen_dunstan_met", "saltmarrow_mara_told_of_dunstan", "saltmarrow_met_mara", "saltmarrow_mara_saw_beacon_lit"]:
		state.set_flag(flag, true)
	state.set_flag("lanes_ferry_at", "fen")
	state.set_flag("fen_ember", "bare")
	state.set_flag("fen_beacon_burned", heron)
	state.set_flag("saltmarrow_beacon_burned", burn)
	state.set_flag("wrackholm_beacon_burned", wrack)
	state.set_flag("fen_dunstan_mara", "burned" if burn == "gull" else "well")
	state.complete_quest("a_light_for_saltmarrow")
	state.complete_quest("a_light_for_glasswater")
	state.complete_quest("for_after")
	return state


## The arrival scene played: his lantern is halfway in.
func _coming(burn: String = "knot", heron: String = "channels") -> WorldState:
	var state := _found("white", burn, heron)
	var event := RegionEvents.arrival(_content().get_region(FEN), state)
	assert_eq(str(event.get("id", "")), "fen_dunstan_coming")
	_lines(state, RegionEvents.fire(event, state))
	return state


## Walked in to the staithe's foot.
func _in(burn: String = "knot", heron: String = "channels") -> WorldState:
	var state := _coming(burn, heron)
	_lines(state, "dunstan", [WALK])
	return state


func _dunstans(state: WorldState, region: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for placement: Dictionary in _content().get_region(region)["npcs"]:
		if str(placement["npc"]) == "dunstan" and Conditions.evaluate(placement.get("if"), state):
			out.append(placement)
	return out


func _model(placement: Dictionary) -> String:
	return str(placement.get("model", _content().get_npc("dunstan")["model"])).get_file().get_basename()


## Props of `region` whose model contains `name` and whose `if` holds.
func _shown(state: WorldState, region: String, name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for prop: Dictionary in _content().get_region(region)["props"]:
		if str(prop.get("model", "")).contains(name) and Conditions.evaluate(prop.get("if"), state):
			out.append(prop)
	return out


func _object_shown(state: WorldState, region: String, id: String) -> bool:
	for object: Dictionary in _content().get_region(region)["objects"]:
		if str(object["id"]) == id:
			return Conditions.evaluate(object.get("if"), state)
	return false


func test_the_models_load() -> void:
	for name: String in ["dunstan_lantern", "dunstan_home", "dunstan_turning"]:
		var path := CHARS + name + ".glb"
		assert_true(ResourceLoader.exists(path), path)
		assert_true(FileAccess.get_file_as_bytes(path).size() < 5 * 1024 * 1024, "%s is small" % name)


func test_not_before_the_wrack_is_lit() -> void:
	var dark := _found("")
	var event := RegionEvents.arrival(_content().get_region(FEN), dark)
	assert_false(str(event.get("id", "")) == "fen_dunstan_coming", "still nearly, while the Wrack is dark")
	assert_eq(_model(_dunstans(dark, FEN)[0]), "dunstan_seated", "still at the end of the walk")
	var state := _coming()
	assert_eq(state.get_flag("fen_dunstan_walk"), "coming")
	assert_eq(state.quest_stage("the_walk_back"), "out_on_the_walk")
	assert_true(RegionEvents.arrival(_content().get_region(FEN), state).is_empty(), "once")
	var shown := _dunstans(state, FEN)
	assert_eq(shown.size(), 1, "one Dunstan")
	assert_eq(_model(shown[0]), "dunstan_lantern", "standing with the lantern lit")
	var at: Array = shown[0]["position"]
	assert_true(float(at[2]) > -24.0 and float(at[2]) < -17.0 and absf(float(at[0])) < 1.2, "halfway in, on the long walk")
	for prop: Dictionary in _shown(state, FEN, "plank_path"):
		assert_false(prop.has("halo"), "no light left at the end of the walk")


func test_walking_him_in() -> void:
	var state := _coming()
	var text := _lines(state, "dunstan", [WAIT])
	assert_true(text.contains("laid by somebody going in"), "the boards only go one way")
	assert_eq(state.get_flag("fen_dunstan_walk"), "coming", "waiting leaves him on the walk")
	text = _lines(state, "dunstan", [WALK])
	assert_true(text.contains("find each board before he needs it") and text.contains("one or two turn back to look"))
	assert_false(text.contains("You open your hand"), "the ember was bare already")
	assert_eq(state.get_flag("fen_dunstan_walk"), "in")
	assert_eq(state.quest_stage("the_walk_back"), "his_name")
	var shown := _dunstans(state, FEN)
	assert_eq(shown.size(), 1)
	var at: Array = shown[0]["position"]
	assert_true(Vector2(float(at[0]), float(at[2])).distance_to(Vector2(3.6, 6.4)) < 2.5, "at the staithe's foot by Hesper")
	assert_true(_content().get_region(FEN)["spawn_points"].has("from_long_walk"), "the walk ends at the staithe")
	var cupped := _coming()
	cupped.set_flag("fen_ember", "cupped")
	text = _lines(cupped, "dunstan", [WALK])
	assert_true(text.contains("open your hand") and text.contains("You open your hand"), "cupped: opened, just this once")
	assert_eq(cupped.get_flag("fen_ember"), "cupped", "Hesper's manners stand otherwise")


func test_he_asks_for_it_himself() -> void:
	var state := _in()
	assert_true(_lines(state, "hesper").contains("He's to ask for it himself"), "Hesper won't hand it to the player")
	var text := _lines(state, "dunstan", [STAY])
	assert_true(text.contains("Dunstan Tollen. Of Saltmarrow.") and text.contains("It'll wear in."))
	assert_false(text.contains("rain off a coat"))
	assert_false(text.contains("I couldn't keep my own"), "Hesper kept her own name")
	var gull := _in("gull", "name")
	text = _lines(gull, "dunstan", [CUP])
	assert_true(text.contains("rain off a coat"), "after the gull burn the name slides off the player")
	assert_true(text.contains("I couldn't keep my own. I've still got yours."), "the name burned: she kept his")
	assert_eq(ContentDatabase.npc_display_name(_content().get_npc("dunstan"), gull), "The big man")


func test_home() -> void:
	var state := _in()
	state.add_item("gull_for_mara")
	var offered := _offered(_in(), "dunstan")
	assert_true(offered.has(HOME) and offered.has(STAY) and offered.has(YOURS))
	assert_false(offered.has(CUP), "no cups without the gull burn")
	var text := _lines(state, "dunstan", [HOME])
	assert_true(text.contains("so he can watch where he's been"), "rows home backward")
	assert_true(text.contains("Give us that gull back"), "he'll set it on the stool himself")
	assert_eq(state.item_count("gull_for_mara"), 0)
	assert_eq(state.get_flag("fen_dunstan_walk"), "home")
	assert_eq(state.quest_state("the_walk_back"), WorldState.QUEST_DONE)
	assert_empty(_dunstans(state, FEN), "gone from the fen")
	assert_empty(_shown(state, FEN, "rowboat.glb"), "and his boat with him")
	assert_false(_object_shown(state, FEN, "fen_rowboat"))
	assert_true(_lines(state, "hesper").contains("First one ever."))
	# Saltmarrow: on his stool by Mara's door, his boat at the dock.
	var home := _dunstans(state, SALTMARROW)
	assert_eq(home.size(), 1)
	assert_eq(_model(home[0]), "dunstan_home")
	assert_empty(_shown(state, SALTMARROW, "/stool.glb"), "the stool prop gives way to his own")
	assert_false(_object_shown(state, SALTMARROW, "saltmarrow_dunstans_stool"))
	assert_eq(_shown(state, SALTMARROW, "rowboat.glb").size(), 2, "his rowboat tied outboard of the other")
	text = _lines(state, "mara")
	assert_true(text.contains("He came in backward. Course he did.") and text.contains("Thank you."))
	assert_true(state.get_flag("saltmarrow_mara_saw_dunstan_home"))
	assert_false(_lines(state, "mara").contains("came in backward"), "once")
	text = _lines(state, "dunstan")
	assert_true(text.contains("Mara never came down"))
	assert_false(text.contains("She doesn't know me"))
	# Not home, nothing at Saltmarrow.
	assert_empty(_dunstans(_in(), SALTMARROW))
	assert_eq(_shown(_in(), SALTMARROW, "/stool.glb").size(), 1)


func test_home_to_a_stranger() -> void:
	var state := _in("gull")
	var offered := _offered(_in("gull"), "dunstan")
	assert_true(offered.has(CUP))
	assert_false(offered.has(HOME), "she isn't keeping the stool: she doesn't know whose it is")
	var text := _lines(state, "dunstan", [CUP])
	assert_true(text.contains("a stranger who knows where the cups go"))
	assert_eq(state.get_flag("fen_dunstan_walk"), "home")
	text = _lines(state, "mara")
	assert_true(text.contains("Says he's my brother") and text.contains("the second cup's his"))
	assert_false(text.contains("Course he did"))
	text = _lines(state, "dunstan")
	assert_true(text.contains("She doesn't know me") and text.contains("the bit after the end"))
	assert_eq(_shown(state, SALTMARROW, "cups").size(), 1, "the cups stay on the crate")


func test_yours_to_choose_is_home() -> void:
	var state := _in()
	var text := _lines(state, "dunstan", [YOURS])
	assert_true(text.contains("A Tollen goes backward."))
	assert_eq(state.get_flag("fen_dunstan_walk"), "home")


func test_stay_and_turn_the_boards() -> void:
	var state := _in()
	state.add_item("gull_for_mara")
	var text := _lines(state, "dunstan", [STAY])
	assert_true(text.contains("I'll turn the boards") and text.contains("Mending's remembering."))
	assert_eq(state.get_flag("fen_dunstan_walk"), "stayed")
	assert_eq(state.quest_state("the_walk_back"), WorldState.QUEST_DONE)
	assert_eq(state.item_count("gull_for_mara"), 1, "the gull stays the player's to carry")
	var shown := _dunstans(state, FEN)
	assert_eq(shown.size(), 1)
	assert_eq(_model(shown[0]), "dunstan_turning", "stooped over a board (Day 52)")
	var at: Array = shown[0]["position"]
	assert_true(float(at[2]) > -17.0 and float(at[2]) < -14.0, "at the head of the long walk")
	assert_empty(_dunstans(state, SALTMARROW))
	assert_eq(_shown(state, FEN, "rowboat.glb").size(), 1, "his boat waits at the staithe")
	# The first two boards turned round: same spots, half a turn.
	var turned := _shown(state, FEN, "plank_path").filter(func(p: Dictionary) -> bool:
		return str(p.get("note", "")).begins_with("Turned round"))
	assert_eq(turned.size(), 2)
	for prop: Dictionary in turned:
		var twin := _shown(_in(), FEN, "plank_path").filter(func(p: Dictionary) -> bool: return p["position"] == prop["position"])
		assert_eq(twin.size(), 1, "the board it replaces")
		assert_true(is_equal_approx(float(prop["rotation_y"]) - float(twin[0]["rotation_y"]), 180.0))
	assert_true(_lines(state, "dunstan").contains("Two turned so far"))
	assert_true(_lines(state, "hesper").contains("He's turning the boards"))
	assert_true(_lines(state, "mara").find("came in backward") < 0, "Mara hears nothing yet")


func test_turning_a_board() -> void:
	# Day 52: the `stayed` Dunstan is stooped over a board, not standing with the lantern in his hand.
	var model := CharacterRig.instantiate(CHARS + "dunstan_turning.glb")
	var standing := CharacterRig.instantiate(CHARS + "dunstan_lantern.glb")
	var parts := CharacterRig.find_parts(model)
	for part: String in ["LegL", "LegR", "Torso", "Head", "ArmL", "ArmR"]:
		assert_true(parts.has(part), "rigged: %s" % part)
	var torso := parts["Torso"] as Node3D
	assert_true(torso.rotation.x > 0.6 and torso.rotation.x < 1.1, "bent at the waist (%.2f rad)" % torso.rotation.x)
	var height := Region.mesh_bounds(model).size.y
	var upright := Region.mesh_bounds(standing).size.y
	assert_true(height < upright * 0.92, "stooped below his standing height (%.2f vs %.2f)" % [height, upright])
	var glowing: Array[String] = []
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(i) as StandardMaterial3D
			if material and material.emission_enabled:
				glowing.append(str(mesh_instance.name))
	assert_eq(glowing, ["Stool"] as Array[String], "the lantern stood lit on the boards, not in his hand")
	model.free()
	standing.free()
