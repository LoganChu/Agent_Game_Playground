extends TestCase
## Day 40 — the lane to Wrackholm: Oda sails east-about from the lit fen once she's told where the
## lane runs and the player is done there (Dunstan found), honouring what was carried to him; the
## Tidewrights' own island, dark — the yard, the lane-house, the answering horn lashed since the
## Snuffing; Wenna Garrow, lane-warden, who answered the Gannet as the Wrack went out; the Gannet's
## crew board brought back by the ember (*The Gannet's Crew*); Jory Pask and who called his brother
## in; the Keepers' second fare (the Book) and the Lamp's lost name; a glass float for Pell's pouch.

const HOLM := "wrackholm"
const FEN := "glasswater_fen"
const LANE := "Where does the lane go from here?"
const MAP := "Where can you take me?"
const NAMES := "The Gannet's crew: Hale Corbet, master. Annis Corbet. Ruan Pask."
const WRACK := "What would it take to light the Wrack?"
const READ := "Hold the ember to the board."
const BROTHER := "Your brother's name was Ruan. Ruan Pask. It's on the Gannet's crew board."
const TOLD_WENNA := "Wenna answered, as she'd answered for fifty years. Then the Wrack went out."
const TOLD_KEEPERS := "The Spire didn't go out. Keepers put it out, on purpose."
const TOLD_DARK := "The Wrack went out under them. Nobody's to blame for the dark."
const FLOAT := "Have you found anything lost? Something good, for a child who keeps lost things."
const KIT := "res://assets/models/dressing/"
## build_wrackholm GANNET_BOARD: the crew board on the hulk's transom, Godot model space.
const GANNET_BOARD := Vector3(0.0, 1.3, -3.25)

var _db: ContentDatabase


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_db, state, dialogue, typed, offered)


## Whether the lane map would sail the ferry to `port` now.
func _sails(state: WorldState, port: String) -> bool:
	return bool(Lanes.voyage(_db, state, port).get("ok", false))


func _offered(state: WorldState, dialogue: String) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [], offered)
	return offered


## The Heron lit and Dunstan found, at the fen with the ferry in.
func _done_at_the_fen(met_dunstan: bool = true) -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "saltmarrow_ferry_arrived", "thornwold_landed", "fen_landed",
			"fen_lantern_seen"]:
		state.set_flag(flag, true)
	state.set_flag("lanes_ferry_at", "fen")
	state.set_flag("fen_beacon_burned", "channels")
	state.complete_quest("a_light_for_thornwold")
	state.complete_quest("a_light_for_glasswater")
	if met_dunstan:
		state.set_flag("fen_dunstan_met", true)
		state.set_flag("fen_dunstan_mara", "message")
		state.set_flag("fen_dunstan_rule", "asked")
		state.complete_quest("for_after")
	return state


## Landed on Wrackholm (the first sailing and the arrival scene played).
func _landed() -> WorldState:
	var state := _done_at_the_fen()
	_lines(state, "oda", [LANE])
	_lines(state, "oda", [MAP, "@wrackholm"])
	assert_true(RegionEvents.fire(RegionEvents.arrival(_db.get_region(HOLM), state), state) == "wrackholm_arrival", "the arrival scene")
	_lines(state, "wrackholm_arrival")
	return state


func _xz(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[2]))


func _props(model: String) -> Array:
	return (_db.get_region(HOLM)["props"] as Array).filter(func(p: Dictionary) -> bool:
		return str(p.get("model", "")) == KIT + model + ".glb")


func test_oda_sails_east_about_once_told_and_done_here() -> void:
	var early := _done_at_the_fen(false)
	assert_false(_sails(early, HOLM), "no Wrackholm before she's said where the lane runs")
	var not_done := _lines(early, "oda", [LANE])
	assert_true(not_done.contains("You've a look like you're not."), "...and while Dunstan's still out there she won't")
	assert_true(early.get_flag("fen_oda_lane_asked") == true, "she has said it")
	assert_false(_sails(early, HOLM), "not done here yet")
	assert_true(str(Lanes.voyage(_db, early, HOLM).get("reason", "")).contains("Not this tide"), "the map says why")
	var state := _done_at_the_fen()
	assert_false(_sails(state, HOLM), "found Dunstan, but not told of the lane")
	var told := _lines(state, "oda", [LANE])
	assert_true(told.contains("done here, near enough") and not told.contains("You've a look like you're not."), "done here now")
	assert_true(_sails(state, HOLM), "so she sails it")
	var text := _lines(state, "oda", [MAP, "@wrackholm"])
	assert_true(text.contains("Nothing answers") and text.contains("Teeth"), "the first sailing is the full scene")
	assert_eq(state.get_flag("lanes_ferry_at"), HOLM, "the Slow Mercy lies at Wrackholm")
	assert_true(_db.dialogues["oda"]["knots"]["sail_wrackholm"].any(func(s: Dictionary) -> bool: return s.get("travel", []) == [HOLM, "from_ferry"]),
			"and the sailing travels to Wrackholm's jetty")
	assert_true(_sails(state, "fen") and not _sails(state, HOLM) and not _sails(state, "thornwold"),
			"lanes run light to light: from Wrackholm, the fen; Thornwold only once the lane back's been sailed")
	_lines(state, "oda", [MAP, "@fen"])
	assert_eq(state.get_flag("lanes_ferry_at"), "fen")
	state.set_flag("wrackholm_landed", true)
	var again := _lines(state, "oda", [MAP, "@wrackholm"])
	assert_false(again.contains("Wenna Garrow swore me"), "later sailings are short")
	assert_eq(state.get_flag("lanes_ferry_at"), HOLM)


func test_the_sailing_honours_what_was_carried_to_dunstan() -> void:
	var lines := {
		"message": "A gull for the stool, facing the door.", "burned": "about the two cups", "well": "That's a message too.",
		"spared": "and not the rest", "nothing": "Some things don't go in a satchel.",
	}
	for mara: String in lines:
		var state := _done_at_the_fen()
		state.set_flag("fen_dunstan_mara", mara)
		state.set_flag("fen_dunstan_rule", "kept")
		_lines(state, "oda", [LANE])
		var text := _lines(state, "oda", [MAP, "@wrackholm"])
		assert_true(text.contains(lines[mara]), "Oda on what Mara sent (%s)" % mara)
		for other: String in lines:
			if other != mara:
				assert_false(text.contains(lines[other]), "...and only that (%s, not %s)" % [mara, other])
		assert_true(text.contains("Tidewright manners") and not text.contains("he didn't know"), "the rule kept")
	var asked := _done_at_the_fen()
	_lines(asked, "oda", [LANE])
	assert_true(_lines(asked, "oda", [MAP, "@wrackholm"]).contains("he didn't know"), "the rule asked")


func test_the_ferry_and_oda_lie_in_one_place_on_every_lane() -> void:
	_db = load_content()
	for at: String in ["", "saltmarrow", "thornwold", "fen", HOLM, "kindleby"]:
		var state := fresh_state(_db)
		state.set_flag("saltmarrow_ferry_arrived", true)
		state.set_flag("lanes_ferry_at", at)
		var odas := 0
		var ferries := 0
		var where := ""
		for region_id: String in _db.regions:
			var region := _db.get_region(region_id)
			for n: Dictionary in region.get("npcs", []):
				if str(n["npc"]) == "oda" and Conditions.evaluate(n.get("if"), state):
					odas += 1
					where = region_id
			for p: Dictionary in region.get("props", []):
				if str(p.get("model", "")).ends_with("/ferry.glb") and Conditions.evaluate(p.get("if"), state):
					ferries += 1
		assert_eq(odas, 1, "Oda in exactly one place with the ferry at '%s'" % at)
		assert_eq(ferries, 1, "the Slow Mercy in exactly one place at '%s'" % at)
		if at == HOLM:
			assert_eq(where, HOLM, "at Wrackholm's jetty")


func test_the_wrackholm_layout() -> void:
	_db = load_content()
	var region := _db.get_region(HOLM)
	var field := TerrainField.from_data(region["ground"], float(region["water_level"]))
	var spawn: Array = region["spawn_points"]["from_ferry"]
	var reachable := field.reachable_from(float(spawn[0]), float(spawn[2]))
	var areas := Greying.worst_case_areas(region)
	assert_true(Greying.depth_at(areas, _xz(spawn)) < Greying.CLEAR_DEPTH, "the jetty is clear of the fog")
	for who: Dictionary in region["npcs"]:
		assert_true(field.near_reachable(reachable, float(who["position"][0]), float(who["position"][2]), 1.5), "%s can be walked to" % who["npc"])
	for object: Dictionary in region["objects"]:
		assert_true(field.near_reachable(reachable, float(object["position"][0]), float(object["position"][2]), 1.5), "%s can be walked to" % object["id"])
	var jory: Dictionary = (region["npcs"] as Array).filter(func(n: Dictionary) -> bool: return n["npc"] == "jory")[0]
	var yard := Greying.depth_at(areas, _xz(jory["position"]))
	assert_true(yard > 0.15 and yard < 0.5, "Jory works in the yard's thin fog (%.2f)" % yard)
	var wenna: Dictionary = (region["npcs"] as Array).filter(func(n: Dictionary) -> bool: return n["npc"] == "wenna")[0]
	var house: Dictionary = _props("lane_house")[0]
	var horn: Dictionary = _props("answering_horn")[0]
	assert_true(_xz(wenna["position"]).distance_to(_xz(horn["position"])) < 2.5, "Wenna sits by the horn")
	assert_true(_xz(wenna["position"]).distance_to(Vector2(float(house["position"][0]), float(house["position"][2]) + 2.5)) < 3.0,
			"...by the lane-house door")
	# The Wrack Light: out on the Teeth, in the deep fog, out of reach.
	var wrack: Dictionary = _props("wrack_light")[0]
	assert_false(bool(wrack.get("snap", true)) or wrack.has("collider"), "the Wrack Light stands on the seabed, never reached")
	assert_false(field.near_reachable(reachable, float(wrack["position"][0]), float(wrack["position"][2]), 4.0), "it is out of reach")
	assert_true(Greying.depth_at(areas, _xz(wrack["position"])) > 0.9, "deep in the Teeth's fog")
	# The crew board object stands behind the Gannet's transom and its glint is on the board.
	var hulk: Dictionary = _props("gannet_hulk")[0]
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(float(hulk["rotation_y"]))), Vector3(float(hulk["position"][0]), 0, float(hulk["position"][2])))
	var board := xf * GANNET_BOARD
	var object: Dictionary = (region["objects"] as Array).filter(func(o: Dictionary) -> bool: return o["id"] == "gannet_board")[0]
	var glint := Vector3(float(object["position"][0]), 0, float(object["position"][2])) + Vector3(object["glint"][0], object["glint"][1], object["glint"][2])
	assert_true(glint.distance_to(board) < 0.15, "the board's glint sits on the board (%s vs %s)" % [glint, board])
	# Arrival scene once, and only off the ferry.
	var state := fresh_state(_db)
	assert_true(RegionEvents.arrival(region, state).is_empty(), "no arrival scene without the ferry")
	state.set_flag("lanes_ferry_at", HOLM)
	assert_eq(RegionEvents.fire(RegionEvents.arrival(region, state), state), "wrackholm_arrival", "the arrival scene plays")
	assert_true(RegionEvents.arrival(region, state).is_empty(), "and only once")


func test_the_kit_models() -> void:
	# The crew board in the model is where the test's GANNET_BOARD says (the Blank's centre).
	var hulk := (load(KIT + "gannet_hulk.glb") as PackedScene).instantiate() as Node3D
	var found := false
	for mi: MeshInstance3D in hulk.find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with("silverfog"):
			var box := mi.transform * mi.get_aabb()
			found = box.get_center().distance_to(GANNET_BOARD + Vector3(0, -0.0, -0.04)) < 0.2
	assert_true(found, "the blank crew board is on the Gannet's transom")
	hulk.free()
	# The lane-house's firelight glows in the shutters (they're inside); the horn is lashed (a bung in the bell).
	var house := (load(KIT + "lane_house.glb") as PackedScene).instantiate() as Node3D
	var glowing := 0
	for mi: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
		var m := mi.mesh.surface_get_material(0) as StandardMaterial3D
		if m != null and m.emission_enabled:
			glowing += 1
	assert_eq(glowing, 1, "one glowing surface: the firelight in the shutters")
	house.free()
	for model: String in ["wenna", "jory"]:
		var rig := CharacterRig.instantiate("res://assets/models/characters/%s.glb" % model)
		assert_true(rig != null, "%s follows the rig contract" % model)
		if rig != null:
			rig.free()


func test_wenna_and_the_gannet() -> void:
	var state := _landed()
	assert_eq(state.quest_stage("a_light_for_wrackholm"), "the_lashed_horn", "A Light for Wrackholm begins on landing")
	var text := _lines(state, "wenna")
	assert_true(text.contains("Wenna Garrow") and text.contains("A horn answered is a lane promised"), "she names herself and the law")
	assert_true(text.contains("Gannet") and text.contains("Hold it to the board"), "the Gannet, and the board")
	assert_eq(state.quest_stage("the_gannets_crew"), "the_crew_board")
	assert_false(_offered(state, "wenna").has(NAMES), "nothing to tell her yet")
	var board := _lines(state, "gannet_board", [READ])
	assert_true(board.contains("HALE CORBET") and board.contains("RUAN PASK"), "the ember brings the chalk back")
	assert_eq(state.quest_stage("the_gannets_crew"), "say_the_names")
	assert_true(_lines(state, "gannet_board").contains("stays where your light brought it back"), "read once, it stays")
	var names := _lines(state, "wenna", [NAMES])
	assert_true(names.contains("They're home") and names.contains("It was my answer brought them in"), "she says them, and the rest")
	assert_eq(state.quest_state("the_gannets_crew"), WorldState.QUEST_DONE)
	assert_true(state.get_flag("wrackholm_gannet_named") == true)
	assert_false(_offered(state, "wenna").has(NAMES), "said once")
	assert_true(_lines(state, "answering_horn").contains("wiped the salt off the brass"), "the horn after")
	assert_true(_lines(state, "oda").contains("Then they're home"), "Oda hears")
	# Reading the board first: she sees it on you, and the names can be told at once.
	var early := _landed()
	_lines(early, "gannet_board", [READ])
	assert_true(_lines(early, "gannet_board").length() > 0)
	var first := _lines(early, "wenna", ["Why didn't anybody answer her?", NAMES])
	assert_true(first.contains("You've looked already") and first.contains("They're home"), "read before she asked")
	assert_eq(early.quest_state("the_gannets_crew"), WorldState.QUEST_DONE)


func test_wenna_on_the_wrack_the_deed_and_the_book() -> void:
	var state := _landed()
	_lines(state, "wenna")
	var wrack := _lines(state, "wenna", [WRACK])
	assert_true(wrack.contains("spring tide") and wrack.contains("It isn't."), "the Teeth at low water, and not yet")
	assert_eq(state.quest_stage("a_light_for_wrackholm"), "the_teeth")
	assert_true(_offered(state, "wenna").has("About the Teeth.") and not _offered(state, "wenna").has(WRACK), "asked once")
	var deeds := {"claimed": "A deed ought to be owned.", "shared": "half of it was other people's", "brusque": "The scale doesn't need telling."}
	for deed: String in deeds:
		var s := _landed()
		s.set_flag("saltmarrow_ferry_deed", deed)
		_lines(s, "wenna")
		var text := _lines(s, "wenna", ["Oda says Tidewrights weigh a deed."])
		assert_true(text.contains(deeds[deed]) and text.contains("friend of the lanes"), "weighed (%s), and courted" % deed)
		assert_true(s.get_flag("wrackholm_wenna_offer") == true)
	# The sleeve-ember: Oda's word, or not; the Keepers' second fare.
	for saw: bool in [true, false]:
		var s := _landed()
		s.add_item("keepers_sleeve_ember")
		s.set_flag("saltmarrow_oda_saw_sleeve_ember", saw)
		_lines(s, "wenna")
		var text := _lines(s, "wenna", ["Show Wenna the Keeper's sleeve-ember."])
		assert_true(text.contains("into the Book"), "Keepers pay twice: the second fare is their name")
		assert_eq(text.contains("Oda told me"), saw, "Oda's word on it only if she saw it")
	# The Lamp's lost name may be in the Book.
	var lamp := _landed()
	assert_false(_offered(lamp, "wenna").has("Thornwold's beacon-keeper has lost its name."), "only once the Lamp has said so")
	lamp.set_flag("thornwold_lamp_name_lost", true)
	_lines(lamp, "wenna")
	var book := _lines(lamp, "wenna", ["Thornwold's beacon-keeper has lost its name."])
	assert_true(book.contains("Thirty winters back") and book.contains("Light the Wrack"), "the page, once the Wrack is lit")
	assert_true(lamp.get_flag("wrackholm_book_told") == true)


func test_jory_and_who_called_them_in() -> void:
	var state := _landed()
	var first := _lines(state, "jory")
	assert_true(first.contains("Jory Pask") and first.contains("I had a brother"), "Jory, and the gap")
	assert_false(_offered(state, "jory").has(BROTHER), "nothing to tell him before the board")
	_lines(state, "gannet_board", [READ])
	var brother := _lines(state, "jory", [BROTHER])
	assert_true(brother.contains("Ruan Pask. He'd laugh"), "his brother's name")
	assert_false(brother.contains("So who called them in?"), "he doesn't ask yet: Wenna hasn't said")
	assert_true(_lines(state, "jory").contains("I keep saying it"), "he keeps saying it")
	_lines(state, "wenna")
	_lines(state, "wenna", [NAMES])
	var offered: Array[String] = []
	var who := _lines(state, "jory", ["Wenna told me about the night the Gannet came in.", TOLD_WENNA], offered)
	assert_false(offered.has(TOLD_KEEPERS), "only someone who heard Aldous can say the Spire was put out")
	assert_true(who.contains("Course she answered. She's Wenna."), "the truth")
	assert_eq(state.get_flag("wrackholm_who_answered"), "wenna")
	assert_false(_offered(state, "jory").has("Wenna told me about the night the Gannet came in."), "told once")
	# Told after Wenna's said it: he asks straight away; the Keepers (heard of Aldous) or the dark.
	for answer: String in [TOLD_KEEPERS, TOLD_DARK]:
		var s := _landed()
		s.set_flag("saltmarrow_aldous_confessed", "grudging")
		_lines(s, "gannet_board", [READ])
		_lines(s, "wenna")
		_lines(s, "wenna", [NAMES])
		_lines(s, "jory")
		var text := _lines(s, "jory", [BROTHER, answer])
		assert_true(text.contains("So who called them in?"), "he asks once he has the name")
		if answer == TOLD_KEEPERS:
			assert_true(text.contains("comes out bent"), "the Keepers: harder")
			assert_eq(s.get_flag("wrackholm_who_answered"), "keepers")
		else:
			assert_true(text.contains("a hard thing to hate, the dark"), "the dark")
			assert_eq(s.get_flag("wrackholm_who_answered"), "dark")


func test_a_glass_float_for_pells_pouch() -> void:
	var state := _landed()
	_lines(state, "jory")
	assert_false(_offered(state, "jory").has(FLOAT), "only with Pell's finding pouch")
	state.add_item("pells_pouch")
	var text := _lines(state, "jory", [FLOAT])
	assert_true(text.contains("year and a tide") and state.item_count("glass_float") > 0, "off the come-home pile")
	assert_false(_offered(state, "jory").has(FLOAT), "once")
	# Back on Saltmarrow's dock: Pell stayed, and gets it.
	state.set_flag("saltmarrow_pell_crossing", "stayed")
	state.set_flag("saltmarrow_pell_ferry_ask", "refused")
	state.set_flag("shingle_met_pell", true)
	var pell := _lines(state, "pell", ["I brought you something lost. Something good."])
	assert_true(pell.contains("It's GLASS") and pell.contains("BEST kind of lost thing"), "something lost, something GOOD")
	assert_false(state.item_count("glass_float") > 0, "Pell has it")
	assert_true(state.item_count("pells_pouch") > 0, "you keep the pouch: not done finding")
	assert_true(_lines(state, "pell").contains("On top of the crate") or _lines(state, "pell").contains("on top of the crate"), "it sits on the crate")
	assert_false(_offered(state, "pell").has("I brought you something lost. Something good."), "given once")
	assert_true(_lines(state, "pells_lost_things").contains("NOBODYS. SO MINE."), "on top of the lost-things crate")
	state.set_flag("saltmarrow_ferry_lantern_hung", true)
	assert_eq(_lines(state, "pells_lost_things").count("NOBODYS"), 1, "once, after the ferry's green glass")
