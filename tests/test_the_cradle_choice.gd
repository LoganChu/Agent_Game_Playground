extends TestCase
## Day 96 — the choice at the cradle (Act III step 9's close). With the ember held over the cradle once
## (`cindermoor_cradle_held`), the Wakebearer weighs the six lights (once) and chooses: light it, let the Hollow Choir
## go home by the ember, or leave it dark (`cindermoor_cradle_choice`). Back down the east stair the chapter counts
## them down, the Provost writes the Long Book's last line and a witness signs (`cindermoor_counted_down`): Act III's
## card.

const FOOT := "cindermoor_spire_foot"
const ROOM := "cindermoor_lantern_room"
const QUEST := "the_lantern_room"
const PICK := {
	"lit": ["Put the ember in the ash.", "Put it in."],
	"released": ["Open your hand. Let them go home by it.", "Open your hand."],
	"dark": ["Close your hand on it, and go down.", "Close your hand on it."],
}

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


func _region(id: String) -> Dictionary:
	return _content().regions[id]


## In the lantern room with the ember held over the cradle once; Oriel `oriel`, Isolde `how`, the roll `roll`.
func _held(oriel: String = "climb", how: String = "named", roll: String = "written") -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_lantern_room"))
	state.set_flag("cindermoor_oriel_choice", oriel)
	state.set_flag("cindermoor_choir_answered", how)
	state.set_flag("cindermoor_seventh_answered", roll)
	_lines(state, "cindermoor_cradle", ["Hold the ember out over the cradle."])
	return state


## Choose `ending` at the cradle; returns what was said.
func _choose(state: WorldState, ending: String) -> String:
	return _lines(state, "cindermoor_cradle", PICK[ending])


## Down the stair: the foot's arrival event and its dialogue.
func _count_down(state: WorldState) -> String:
	var event := RegionEvents.arrival(_region(FOOT), state)
	assert_eq(str(event.get("id", "")), "cindermoor_count_down")
	return _lines(state, RegionEvents.fire(event, state))


func _shows(region: String, model_suffix: String, state: WorldState) -> bool:
	for prop: Dictionary in _region(region)["props"]:
		if str(prop.get("model", "")).ends_with(model_suffix) and Conditions.evaluate(prop.get("if", []), state):
			return true
	return false


func test_the_choice_waits_for_the_hand() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_lantern_room"))
	var offered: Array[String] = []
	_lines(state, "cindermoor_cradle", [], offered)
	assert_false(offered.has(PICK["lit"][0]), "not before the ember's been held over it: %s" % [offered])
	state = _held()
	for ending: String in PICK:
		offered.clear()
		var said := _lines(state, "cindermoor_cradle", [PICK[ending][0], "Not yet."], offered)
		assert_true(offered.has(PICK[ending][1]) and offered.has("Not yet."), str(offered))
		assert_true(said.contains("Not yet. They start singing again"), said)
		assert_eq(str(state.get_flag("cindermoor_cradle_choice")), "", ending)
	assert_true(RegionEvents.arrival(_region(FOOT), state).is_empty(), "nothing to count down before a choice")


func test_the_six_lights_weighed_once() -> void:
	var state := _held()
	state.set_flag("saltmarrow_beacon_burned", "gull")
	state.set_flag("fen_beacon_burned", "channels")
	state.set_flag("kindleby_beacon_burned", "pan")
	var said := _lines(state, "cindermoor_cradle")
	assert_true(said.contains("on Mara's brother") and said.contains("on Corran's channels") and said.contains("on Tobin's coal-pan"), said)
	assert_false(said.contains("on a lullaby") or said.contains("the night of the boats"), "only what was burned")
	assert_true(said.contains("This one would cost more"), said)
	assert_false(_lines(state, "cindermoor_cradle").contains("on Mara's brother"), "once")
	# Every burning value has its line.
	var text := JSON.stringify(_content().dialogues["cindermoor_cradle"])
	for flag: String in ["saltmarrow", "thornwold", "fen", "wrackholm", "kindleby", "lowsong"]:
		for value: String in _content().flags[flag + "_beacon_burned"]["values"]:
			if not value.is_empty():
				assert_true(text.contains("flag:%s_beacon_burned=%s" % [flag, value]), "%s=%s" % [flag, value])


func test_light_it() -> void:
	var state := _held()
	assert_eq(state.item_count("stair_taper"), 1, "carried up")
	assert_eq(state.item_count("hood_pin"), 1, "carried up")
	var said := _choose(state, "lit")
	assert_eq(str(state.get_flag("cindermoor_cradle_choice")), "lit")
	assert_true(said.contains("It takes.") and said.contains("it starts with you"), said)
	assert_true(said.contains("We'll keep you company"), "Isolde, named")
	assert_true(said.contains("I'll carry you down. Somebody has to count."), "Oriel, climbed")
	assert_false(state.item_count("stair_taper") > 0 or state.item_count("hood_pin") > 0, "the own Remnants go into the fire")
	assert_eq(state.quest_stage(QUEST), "the_choice")
	assert_true(_shows(ROOM, "firstflame_cradle_lit.glb", state) and not _shows(ROOM, "firstflame_cradle.glb", state))
	assert_eq(RegionMood.light(_region(ROOM), state)["sun_color"], "#E0A866")
	for id: String in ["cindermoor_boat_stair", "cindermoor_long_steps", FOOT]:
		assert_eq(RegionMood.clock_time(_region(id), state), "spire_lit", id)
		assert_eq(RegionMood.light(_region(id), state)["sun_color"], "#E8C79A", "gold over %s" % id)
	var down := _count_down(state)
	assert_true(down.contains("You can't count with them") and down.contains("Oriel has your arm"), down)
	assert_true(down.contains("took that hand first") and down.contains("written in this book by name, and is asked"), down)
	assert_true(down.contains("copy your name off the roll"), "written, and they can't remember it")
	assert_true(bool(state.get_flag("cindermoor_counted_down")))
	assert_eq(state.quest_state(QUEST), WorldState.QUEST_DONE)
	# After: the cradle burns.
	assert_true(_lines(state, "cindermoor_cradle").contains("Gold all through the ash"))


func test_let_them_go() -> void:
	var state := _held("own", "left", "left")
	var said := _choose(state, "released")
	assert_eq(str(state.get_flag("cindermoor_cradle_choice")), "released")
	assert_true(said.contains("Walking them out") and said.contains("the size of a hazelnut"), said)
	assert_true(said.contains("Going home. Wherever that is now."), "Isolde, left")
	assert_true(said.contains("one of them says your name. Once"), "the roll, left")
	assert_true(said.contains("two voices counting stop"), "Oriel, at the foot")
	assert_true(state.item_count("stair_taper") > 0, "nothing burned")
	assert_true(_shows(ROOM, "firstflame_cradle.glb", state))
	assert_true(RegionMood.fog(_region(ROOM), state)["density"] < 0.02, "the Choir's gone")
	assert_false(AudioDirector.ambience_layers(_region(ROOM), state).has("choir_near"), "and the singing")
	var down := _count_down(state)
	assert_true(down.contains("You count with her") and down.contains("let them out by it"), down)
	assert_true(down.contains("No name.") and down.contains("signs under you without being asked"), down)


func test_leave_it_dark() -> void:
	var state := _held("boat", "written", "struck")
	var said := _choose(state, "dark")
	assert_eq(str(state.get_flag("cindermoor_cradle_choice")), "dark")
	assert_true(said.contains("Six lights round a dark Spire"), said)
	assert_true(said.contains("goes back for the others"), "Isolde, written")
	assert_true(said.contains("pulls it back up the rollers"), "Oriel, on the water")
	assert_true(AudioDirector.ambience_layers(_region(ROOM), state).has("choir_near"), "they sing on")
	var down := _count_down(state)
	assert_true(down.contains("carried it down again, still lit") and down.contains("every island chooses for itself"), down)
	assert_true(down.contains("struck through") and down.contains("nobody writes her in"), down)


func test_oriel_comes_down_with_them() -> void:
	var state := _held()
	_choose(state, "dark")
	var room := 0
	for npc: Dictionary in _region(ROOM)["npcs"]:
		if Conditions.evaluate(npc.get("if", []), state):
			room += 1
	assert_eq(room, 0, "she doesn't stay up there")
	var at_foot := false
	for npc: Dictionary in _region(FOOT)["npcs"]:
		if str(npc["npc"]) == "oriel" and Conditions.evaluate(npc.get("if", []), state):
			at_foot = true
	assert_true(at_foot, "she's at the foot")


func test_after_lines() -> void:
	var expect := {"lit": "somebody ought to sing it", "released": "It's very small", "dark": "row the first lane"}
	var provost := {"lit": "ask them twice", "released": "A hand opened", "dark": "choose badly"}
	for ending: String in expect:
		var state := _held()
		state.set_flag("cindermoor_provost_would_light", true)
		_choose(state, ending)
		var down := _count_down(state)
		assert_true(down.contains("I'd have lit it."), ending)
		assert_true(_lines(state, "oriel").contains(expect[ending]), ending)
		var said := _lines(state, "provost")
		assert_true(said.contains("That's the Long Book shut") == false and said.contains(provost[ending]), "%s: %s" % [ending, said])


func test_act_three_ends() -> void:
	var state := _held()
	_choose(state, "released")
	assert_false(ActRecap.reached(_content(), state).has("act3"))
	_count_down(state)
	assert_true(ActRecap.reached(_content(), state).has("act3"))
	var act: Dictionary = {}
	for a in ActRecap.acts(_content()):
		if a["id"] == "act3":
			act = a
	var lines := "\n".join(ActRecap.card_lines(_content(), act, state))
	assert_true(lines.contains("walked the Hollow Choir out"), lines)
	assert_true(lines.contains("came up the east stair behind you") and lines.contains("talked to you like a person"), lines)
	assert_false(lines.contains("Hearthspire burns again"), lines)
	for line in ["The Hearthspire stands dark. The ember walked", "The Hearthspire burns again", "sings at the top of it"]:
		assert_eq(lines.count(line), 1 if line.contains("walked") else 0, line)


func test_the_name_is_never_said() -> void:
	for id: String in ["cindermoor_cradle", "cindermoor_count_down"]:
		var text := JSON.stringify(_content().dialogues[id]).to_lower()
		assert_false(text.contains("your name is"), id)


func test_the_checkpoint() -> void:
	var state := fresh_state(_content())
	var scenario := Scenarios.resolve("the_spire_lit")
	assert_eq(str(scenario.get("region", "")), ROOM)
	Scenarios.apply(_content(), state, scenario)
	assert_eq(str(state.get_flag("cindermoor_cradle_choice")), "lit")
	assert_true(_shows(ROOM, "firstflame_cradle_lit.glb", state))
