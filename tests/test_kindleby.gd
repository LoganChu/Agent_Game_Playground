extends TestCase
## Day 62 — the lane on from Wrackholm: with the Wrack lit, Oda tells of the Taper, south-about to
## Kindleby, the Keepers' mother-house; the quay bell answers before she blows; an island ringed with
## candles, the fog a cable's width off; Brother Tobin at the bell; Provost Agathe Lorn, who weighs what
## the Wakebearer carries (Aldous's sleeve-ember, the story on the Tidewright decks, the oath) and asks
## them to bow to the rite (*A Light for Kindleby*); the far shore's promise to tell the Spire kept; the
## Quiet House, barred from outside.

const BY := "kindleby"
const HOLM := "wrackholm"
const LANE := "Where does the lane go from here?"
const MAP := "Where can you take me?"
const LIGHT := "What would it take to light the Vigil Light?"
const ABOUT := "About the rite..."
const BOW := "I'll bow to the rite."
const REFUSE := "I'll choose, as I've chosen everywhere."
const WRONG := "And if the chapter chooses wrong?"
const THINK := "I'll think on it."
const ALDOUS := "Aldous told me the High Keeper put the flame out."
const WYNN := "Wynn Sallow is alive. He keeps the Ridge Light on Thornwold."
const LAMP := "There's a Keeper at the Ridge Light on Thornwold. He calls himself the Lamp."
const STAGE := "There are colliers on the Northing's boat-stage, waiting for the Spire's boat. I promised I'd tell the Spire."
const QUIET := "Who's in the Quiet House?"
const KIT := "res://assets/models/dressing/"

var _db: ContentDatabase


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_db, state, dialogue, typed, offered)


func _offered(state: WorldState, dialogue: String) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [], offered)
	return offered


func _sails(state: WorldState, port: String) -> bool:
	return bool(Lanes.voyage(_db, state, port).get("ok", false))


## At Wrackholm with the ferry in; `lit` lights the Wrack (A Light for Wrackholm done).
func _at_wrackholm(lit: bool = true) -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "saltmarrow_ferry_arrived", "thornwold_landed", "fen_landed",
			"fen_oda_lane_asked", "fen_dunstan_met", "wrackholm_landed", "wrackholm_met_wenna"]:
		state.set_flag(flag, true)
	state.set_flag("saltmarrow_beacon_burned", "knot")
	state.set_flag("thornwold_beacon_burned", "boots")
	state.set_flag("fen_beacon_burned", "channels")
	state.set_flag("lanes_ferry_at", HOLM)
	for quest: String in ["across_the_grey", "a_light_for_thornwold", "a_light_for_glasswater"]:
		state.complete_quest(quest)
	if lit:
		state.set_flag("wrackholm_beacon_burned", "board")
		state.complete_quest("a_light_for_wrackholm")
	else:
		state.start_quest("a_light_for_wrackholm", "the_teeth")
	return state


## Landed on Kindleby: the Taper told and sailed, the arrival scene played.
func _landed(state: WorldState = null) -> WorldState:
	if state == null:
		state = _at_wrackholm()
	_lines(state, "oda", [LANE])
	_lines(state, "oda", [MAP, "@" + BY])
	assert_eq(RegionEvents.fire(RegionEvents.arrival(_db.get_region(BY), state), state), "kindleby_arrival", "the arrival scene")
	_lines(state, "kindleby_arrival")
	return state


func _xz(p: Array) -> Vector2:
	return Vector2(float(p[0]), float(p[2]))


func _props(model: String) -> Array:
	return (_db.get_region(BY)["props"] as Array).filter(func(p: Dictionary) -> bool:
		return str(p["model"]).get_file().get_basename() == model)


func test_oda_tells_of_the_taper_once_the_wrack_is_lit() -> void:
	var dark := _at_wrackholm(false)
	assert_false(_offered(dark, "oda").has(LANE), "not while the Wrack is dark")
	assert_false(_sails(dark, BY), "and the chart has no Kindleby")
	var state := _at_wrackholm()
	assert_true(_offered(state, "oda").has(LANE), "asked once the Wrack is lit")
	assert_false(_sails(state, BY), "Kindleby isn't on the chart till she's said where the lane runs")
	var told := _lines(state, "oda", [LANE])
	assert_true(told.contains("the Taper") and told.contains("Kindleby") and told.contains("mother-house"), told)
	assert_true(state.get_flag("wrackholm_oda_lane_asked") == true)
	assert_true(_sails(state, BY), "so she sails it")
	var text := _lines(state, "oda", [MAP, "@" + BY])
	assert_true(text.contains("Candles") and text.contains("one stroke, then three"), "the first sailing is the full scene")
	assert_eq(state.get_flag("lanes_ferry_at"), BY, "the Slow Mercy lies at Kindleby")
	assert_true(_db.dialogues["oda"]["knots"]["sail_kindleby"].any(func(s: Dictionary) -> bool: return s.get("travel", []) == [BY, "from_ferry"]),
			"and the sailing travels to Kindleby's quay")
	assert_true(_sails(state, HOLM) and not _sails(state, "fen"), "the Taper runs back to the Wrack; the fen only once it's been sailed")
	state.set_flag("kindleby_landed", true)
	assert_true(_sails(state, "fen") and _sails(state, "saltmarrow"), "...and once it has, the long passages run home from here")
	_lines(state, "oda", [MAP, "@" + HOLM])
	assert_eq(state.get_flag("lanes_ferry_at"), HOLM)
	var again := _lines(state, "oda", [MAP, "@" + BY])
	assert_false(again.contains("Tallow. They're holding"), "later sailings are short")
	assert_eq(state.get_flag("lanes_ferry_at"), BY)


func test_the_sailing_weighs_what_came_before() -> void:
	var plain := _at_wrackholm()
	_lines(plain, "oda", [LANE])
	var text := _lines(plain, "oda", [MAP, "@" + BY])
	for line: String in ["Pask lad", "Wynn Sallow", "Northing's stage", "sworn a friend"]:
		assert_false(text.contains(line), "nothing about '%s' unless it happened" % line)
	var state := _at_wrackholm()
	state.set_flag("wrackholm_who_answered", "keepers")
	state.set_flag("thornwold_lamp_name", "told")
	state.set_flag("thornwold_far_shore", "waiting")
	state.set_flag("wrackholm_sworn", "sworn")
	assert_true(_lines(state, "oda", [LANE]).contains("sworn a friend of the lanes"), "Oda on the oath")
	text = _lines(state, "oda", [MAP, "@" + BY])
	for line: String in ["Pask lad", "Wynn Sallow", "Northing's stage"]:
		assert_true(text.contains(line), "the sailing remembers '%s'" % line)


func test_the_kindleby_layout() -> void:
	_db = load_content()
	var region := _db.get_region(BY)
	var field := TerrainField.from_data(region["ground"], float(region["water_level"]))
	var spawn: Array = region["spawn_points"]["from_ferry"]
	var reachable := field.reachable_from(float(spawn[0]), float(spawn[2]))
	var areas := Greying.worst_case_areas(region)
	for who: Dictionary in region["npcs"]:
		assert_true(field.near_reachable(reachable, float(who["position"][0]), float(who["position"][2]), 1.5), "%s can be walked to" % who["npc"])
		assert_true(Greying.depth_at(areas, _xz(who["position"])) < Greying.CLEAR_DEPTH, "%s stands inside the candles" % who["npc"])
	for object: Dictionary in region["objects"]:
		assert_true(field.near_reachable(reachable, float(object["position"][0]), float(object["position"][2]), 1.5), "%s can be walked to" % object["id"])
	# The candle wall rings the island: ledges on every side of the chapter-house, all clear of the fog,
	# and the fog standing past them.
	var ledges := _props("candle_ledge")
	assert_true(ledges.size() >= 14, "a ring of candle ledges (%d)" % ledges.size())
	var sides := {}
	for ledge: Dictionary in ledges:
		var p := _xz(ledge["position"])
		assert_true(Greying.depth_at(areas, p) < Greying.CLEAR_DEPTH, "a ledge at %s is inside the clear" % p)
		sides[Vector2i(signi(int(round(p.x / 8.0))), signi(int(round((p.y + 5.0) / 5.0))))] = true
	assert_true(sides.size() >= 6, "...all the way round (%d sides)" % sides.size())
	for edge: Vector2 in [Vector2(0, -24), Vector2(-26, -5), Vector2(26, -5), Vector2(0, 19)]:
		assert_true(Greying.depth_at(areas, edge) > 0.6, "the fog stands off at %s" % edge)
	# Tobin by the bell, the Provost at the foot of the chapter-house steps, the Vigil Light on the crown.
	var npcs := {}
	for n: Dictionary in region["npcs"]:
		npcs[n["npc"]] = n
	var bell: Dictionary = _props("vigil_bell")[0]
	assert_true(_xz(npcs["tobin"]["position"]).distance_to(_xz(bell["position"])) < 2.0, "Tobin by the bell")
	var hall: Dictionary = _props("chapter_house")[0]
	var door := _xz(hall["position"]) + Vector2(0, 2.9)
	assert_true(_xz(npcs["provost"]["position"]).distance_to(door) < 0.8, "the Provost at the chapter-house steps")
	var vigil: Dictionary = _props("vigil_light")[0]
	assert_eq(vigil["if"], "!quest:a_light_for_kindleby=done", "the Vigil Light, dark")
	var ground_at_light := field.height_at(float(vigil["position"][0]), float(vigil["position"][2]))
	assert_true(ground_at_light > field.height_at(float(spawn[0]), float(spawn[2])) + 0.8, "on the crown of the island (%.2f)" % ground_at_light)
	# Arrival scene once, and only off the ferry.
	var state := fresh_state(_db)
	assert_true(RegionEvents.arrival(region, state).is_empty(), "no arrival scene without the ferry")
	state.set_flag("lanes_ferry_at", BY)
	assert_eq(RegionEvents.fire(RegionEvents.arrival(region, state), state), "kindleby_arrival", "the arrival scene plays")
	assert_true(state.get_flag("kindleby_landed") == true)
	assert_true(RegionEvents.arrival(region, state).is_empty(), "and only once")


func test_the_kit_models() -> void:
	for model: String in ["chapter_house", "candle_ledge", "vigil_bell", "quiet_house", "vigil_light"]:
		var node := (load(KIT + model + ".glb") as PackedScene).instantiate() as Node3D
		var glowing := 0
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var m := mi.mesh.surface_get_material(0) as StandardMaterial3D
			if m != null and m.emission_enabled:
				glowing += 1
		# Candles burn on everything but the bell; the chapter-house windows glow too.
		assert_eq(glowing > 0, model != "vigil_bell", "%s: lit candles (%d glowing surfaces)" % [model, glowing])
		node.free()
	for who: String in ["provost", "tobin"]:
		assert_true(ResourceLoader.exists("res://assets/models/characters/%s.glb" % who), "%s's model" % who)


func test_the_arrival_starts_a_light_for_kindleby() -> void:
	var state := _landed()
	assert_eq(state.quest_stage("a_light_for_kindleby"), "the_candles")
	assert_eq(state.get_flag("lanes_ferry_at"), BY)
	var oda := _lines(state, "oda")
	assert_true(oda.contains("hospitable the way a net is"), "Oda at the quay before the Provost")


func test_the_provost_weighs_what_the_wakebearer_carries() -> void:
	var plain := _landed()
	var first := _lines(plain, "provost")
	assert_true(first.contains("Agathe Lorn") and first.contains("I'd remember an ember"), "she introduces herself")
	assert_true(plain.get_flag("kindleby_met_provost") == true)
	for line: String in ["sleeve-ember", "Tidewright decks that Keepers", "sworn a friend"]:
		assert_false(first.contains(line), "nothing about '%s' unless it happened" % line)
	assert_false(_lines(plain, "provost").contains("Agathe Lorn"), "her first words are said once")
	var state := _at_wrackholm()
	state.add_item("keepers_sleeve_ember")
	state.set_flag("wrackholm_who_answered", "keepers")
	state.set_flag("wrackholm_sworn", "sworn")
	_landed(state)
	first = _lines(state, "provost")
	assert_true(first.contains("Aldous Wren. He always did pick at things."), "she knows whose sleeve")
	assert_true(first.contains("Stories like that get people drowned."), "she has heard the story off the decks")
	assert_true(first.contains("Their oath is about decks. Ours is about light."), "and of the oath")


func test_the_rite() -> void:
	var state := _landed()
	var offered := _offered(state, "provost")
	assert_true(offered.has(LIGHT) and not offered.has(ABOUT), "first, what it would take")
	var asked := _lines(state, "provost", [LIGHT, WRONG, THINK])
	assert_true(asked.contains("a Keeper chose") and asked.contains("Bow to the rite"), asked)
	assert_true(asked.contains("the chapter's wrong, and not yours"), "the chapter's wrong, not yours")
	assert_eq(state.quest_stage("a_light_for_kindleby"), "the_rite", "thinking on it leaves the question open")
	assert_eq(state.get_flag("kindleby_rite"), "")
	offered = _offered(state, "provost")
	assert_true(offered.has(ABOUT) and not offered.has(LIGHT), "she asks again")
	var answer := _lines(state, "provost", [ABOUT, BOW])
	assert_true(answer.contains("done properly. Once."), answer)
	assert_eq(state.get_flag("kindleby_rite"), "bowed")
	assert_eq(state.quest_stage("a_light_for_kindleby"), "the_chapter")
	assert_false(_offered(state, "provost").has(ABOUT), "answered")
	assert_true(_lines(state, "provost").contains("The chapter will sit. I've said so"), "she holds to it")
	assert_true(_lines(state, "tobin").contains("The old brothers cried"), "Tobin heard")
	assert_true(_lines(state, "oda").contains("You bowed to their rite"), "and Oda")
	var refused := _landed()
	_lines(refused, "provost", [LIGHT, REFUSE])
	assert_eq(refused.get_flag("kindleby_rite"), "refused")
	assert_eq(refused.quest_stage("a_light_for_kindleby"), "the_chapter", "the chapter sits either way")
	assert_true(_lines(refused, "provost").contains("Still choosing for yourself"))
	assert_true(_lines(refused, "tobin").contains("Is it heavy? Choosing?"))
	assert_true(_lines(refused, "oda").contains("You told Lorn no."))


func test_aldous_and_the_lamp_told_to_the_provost() -> void:
	var untold := _landed()
	assert_false(_offered(untold, "provost").has(ALDOUS), "no Aldous to report if he never told")
	assert_true(_offered(untold, "provost").has(LAMP) and not _offered(untold, "provost").has(WYNN), "the Lamp, nameless")
	var nameless := _lines(untold, "provost", [LAMP])
	assert_true(nameless.contains("that's a post") and not nameless.contains("Sallow"), "she doesn't hand over the name the Book keeps")
	assert_false(_offered(untold, "provost").has(LAMP), "told once")
	for confessed: String in ["full", "grudging"]:
		var state := _at_wrackholm()
		state.set_flag("saltmarrow_aldous_confessed", confessed)
		state.set_flag("thornwold_lamp_name", "told")
		_landed(state)
		var text := _lines(state, "provost", [ALDOUS])
		assert_true(text.contains("the Firstflame failed") and text.contains("say it to the chapter"), "the order's word (%s)" % confessed)
		assert_eq(text.contains("...Did he."), confessed == "full", "the light down the stair only from a full confession (%s)" % confessed)
		assert_false(_offered(state, "provost").has(ALDOUS), "said once")
		assert_true(_offered(state, "provost").has(WYNN) and not _offered(state, "provost").has(LAMP), "the name, carried home")
		var struck := _lines(state, "provost", [WYNN])
		assert_true(struck.contains("We strike it, so anybody can see it was once wrong."), struck)
		assert_true(state.get_flag("kindleby_provost_heard_lamp") == true)


func test_the_far_shore_promise_kept() -> void:
	var up := _at_wrackholm()
	up.set_flag("thornwold_far_shore", "up")
	_landed(up)
	assert_false(_offered(up, "provost").has(STAGE), "nobody waiting if they came up")
	var state := _at_wrackholm()
	state.set_flag("thornwold_far_shore", "waiting")
	_landed(state)
	var text := _lines(state, "provost", [STAGE])
	assert_true(text.contains("There is no Spire to tell, Wakebearer. There's me.") and text.contains("the skiff goes north"), text)
	assert_true(state.get_flag("kindleby_told_of_stage") == true)
	assert_false(_offered(state, "provost").has(STAGE), "told once")


func test_the_quiet_house() -> void:
	var state := _landed()
	var provost := _lines(state, "provost", [QUIET])
	assert_true(provost.contains("To keep the Hushed.") and provost.contains("You can't go in."), provost)
	var door := _lines(state, "quiet_house")
	assert_true(door.contains("barred from outside") and door.contains("Not quite the same tune."), door)
	var tobin := _lines(state, "tobin", ["That house by the water, with its shutters barred."])
	assert_true(tobin.contains("put the bar back after"), tobin)
	var light := _lines(state, "vigil_door")
	assert_true(light.contains("Somebody on this island will have the key."), "before the rite's told of")
	_lines(state, "provost", [LIGHT])
	assert_true(_lines(state, "vigil_door").contains("The Provost has the key."), "after")
