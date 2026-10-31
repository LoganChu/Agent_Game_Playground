extends TestCase
## Day 75 — Act II's close, step 2b: rowing out to the Low Water. The Provost says nobody goes out in the wet,
## and then yes; Hild's skiff is clean by then and she rows the Wakebearer out through the singing to Lowsong,
## where the light is cold and its Keeper, Brother Iver Lusk, is alive under it with one small lamp
## (*The Low Water* done, *A Light for Lowsong* begun). While the skiff is out, Hild and the skiff are on
## Lowsong's landing and not on Kindleby's shingle; she rows back whenever she's asked.

const ASK_PROVOST := "Sister Hild would row me out to the Low Water, with your leave."
const ROW := "Would you row me out to the Low Water?"
const CLEAN := "Is she clean yet?"
const ROW_OUT := "Row me out to Lowsong."
const BACK := "Take me back to Kindleby."
const BYE := "Goodbye."

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


## Plays `picks` and returns the travel left pending ([] if none).
func _travel(state: WorldState, dialogue: String, picks: Array) -> Array:
	var runner := DialogueRunner.new(_content(), state)
	var ev := runner.start(dialogue)
	var guard := 0
	while ev["type"] != "end" and guard < 100:
		guard += 1
		if ev["type"] == "line":
			ev = runner.next()
			continue
		var texts: Array[String] = []
		for option: Dictionary in ev["options"]:
			texts.append(str(option["text"]))
		var want: String = picks.pop_front() if not picks.is_empty() else ""
		var pick := texts.find(want)
		ev = runner.choose(pick if pick >= 0 else texts.size() - 1)
	return runner.pending_travel


## Kindleby lit with the Stair-Taper in hand (the checkpoint), and Oda's told of the Low Water.
func _kindleby(north := true) -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_stair_taper"))
	state.set_flag("kindleby_skiff_north", north)
	state.set_flag("thornwold_skiff", "home" if north else "")
	_lines(state, "oda", ["Where does the ring go from here?", "Why go round?"])
	assert_eq(state.quest_stage("the_low_water"), "ask_a_keeper", "Oda's told")
	return state


## …and Hild's said she'll row once the bottom's clean.
func _asked_hild(north := true) -> WorldState:
	var state := _kindleby(north)
	_lines(state, "hild", [ROW, BYE])
	assert_eq(state.quest_stage("the_low_water"), "the_skiff")
	return state


## …and the Provost's said yes.
func _leave(north := true) -> WorldState:
	var state := _asked_hild(north)
	_lines(state, "provost", [ASK_PROVOST, BYE])
	return state


func _placed(region: String, npc: String, state: WorldState) -> int:
	var n := 0
	for placed: Dictionary in _content().get_region(region)["npcs"]:
		if placed["npc"] == npc and Conditions.evaluate(placed.get("if"), state):
			n += 1
	return n


func _skiffs_on_kindleby(state: WorldState) -> int:
	var n := 0
	for prop: Dictionary in _content().get_region("kindleby")["props"]:
		if str(prop.get("model", "")).ends_with("kindleby_skiff.glb") and Conditions.evaluate(prop.get("if"), state):
			n += 1
	return n


func test_the_provost_says_no_and_then_yes() -> void:
	var offered: Array[String] = []
	_lines(_kindleby(), "provost", [BYE], offered)
	assert_false(ASK_PROVOST in offered, "nothing to ask before Hild's said she'll row")
	for north: bool in [true, false]:
		var state := _asked_hild(north)
		offered.clear()
		var told := _lines(state, "provost", [ASK_PROVOST, BYE], offered)
		assert_true(ASK_PROVOST in offered, str(north))
		assert_true(told.contains("Nobody goes out in the wet, Wakebearer.") and told.contains("It's a Keepers' light. And it's you asking."), told)
		assert_true(told.contains("Brother Iver Lusk") and told.contains("the way we write the drowned"), "she wrote him in the Long Book")
		assert_eq(told.contains("I sent Hild north anyway"), north, "she's broken the rule for the Wakebearer once already")
		assert_true(bool(state.get_flag("kindleby_provost_low_water")))
		assert_eq(state.quest_stage("the_low_water"), "row_out")
		offered.clear()
		_lines(state, "provost", [BYE], offered)
		assert_false(ASK_PROVOST in offered, "asked once")


func test_hild_wont_row_without_leave_then_does() -> void:
	var state := _asked_hild()
	var not_yet := _lines(state, "hild", [CLEAN, BYE])
	assert_true(not_yet.contains("Not yet.") and not_yet.contains("I'll not row out there without her leave"), not_yet)
	assert_eq(_travel(state, "hild", [CLEAN, BYE]), [], "nowhere to go yet")
	for north: bool in [true, false]:
		state = _leave(north)
		var offered: Array[String] = []
		var told := _lines(state, "hild", ["Not yet."], offered)
		assert_true(told.contains("She's clean. Every strake.") and told.contains("I'm not to stop and listen."), told)
		assert_true(ROW_OUT in offered, str(north))
		assert_false(bool(state.get_flag("lowsong_out")), "not until she's asked")
		assert_eq(_travel(state, "hild", [ROW_OUT]), ["lowsong", "from_skiff"], str(north))
		assert_true(bool(state.get_flag("lowsong_out")))


func test_the_skiff_is_in_one_place() -> void:
	var state := _leave()
	assert_eq([_placed("kindleby", "hild", state), _placed("lowsong", "hild", state), _skiffs_on_kindleby(state)], [1, 0, 1],
		"on the shingle before she rows")
	state.set_flag("lowsong_out", true)
	assert_eq([_placed("kindleby", "hild", state), _placed("lowsong", "hild", state), _skiffs_on_kindleby(state)], [0, 1, 0],
		"out at Lowsong")
	assert_eq(_placed("lowsong", "iver", state), 1, "the Keeper's always on his rock")
	var spawns: Dictionary = _content().get_region("kindleby")["spawn_points"]
	assert_true(spawns.has("from_skiff"), "rowed home to the shingle")


func test_rowing_out_into_the_singing() -> void:
	var state := _leave()
	_travel(state, "hild", [ROW_OUT])
	var event: Dictionary = _content().get_region("lowsong")["events"][0]
	assert_true(Conditions.evaluate(event["if"], state), "fires on the first landing")
	var told := _lines(state, "lowsong_rowing_out")
	assert_true(told.contains("Kindleby's candles go small astern") and told.contains("Evening office, and the door shut."), told)
	assert_true(told.contains("He's alive, then. Iver Lusk."), told)
	assert_eq(state.quest_stage("the_low_water"), "lowsong")
	var sounds: Array[String] = []
	for step: Dictionary in _content().dialogues["lowsong_rowing_out"]["knots"]["start"]:
		if step.has("sound"):
			sounds.append(str(step["sound"]))
	assert_eq(sounds, ["choir_far"], "the singing heard as it closes round the boat")
	state.set_flag("lowsong_landed", true)
	assert_false(Conditions.evaluate(event["if"], state), "once")


func test_meeting_the_keeper() -> void:
	var state := _leave()
	_travel(state, "hild", [ROW_OUT])
	_lines(state, "lowsong_rowing_out")
	var offered: Array[String] = []
	var met := _lines(state, "iver", ["Who is singing?", "Why is the light cold?", BYE], offered)
	assert_true(met.contains("Iver Lusk. Keeper of Lowsong, thirty-one winters."), met)
	assert_true(bool(state.get_flag("lowsong_met_keeper")))
	assert_eq(state.quest_state("the_low_water"), "done")
	assert_eq(state.quest_stage("a_light_for_lowsong"), "the_singing")
	assert_true(met.contains("all trying to remember the one thing at once") and met.contains("A woman, I think."), "the Choir, close")
	assert_true(met.contains("Here it only sings. Whatever it carries, it keeps."), "the fog leaves nothing to burn")
	assert_true("The Provost wrote you in the Long Book, with the drowned." in offered, "asked her leave, so heard of the Book")
	var again := _lines(state, "iver", [BYE])
	assert_true(again.begins_with("Still here."), again)
	assert_eq(state.quest_stage("a_light_for_lowsong"), "the_singing", "started once")


func test_what_the_keeper_hears_of() -> void:
	var state := _leave()
	state.set_flag("lowsong_met_keeper", true)
	state.set_flag("kindleby_ring_held", false)
	state.set_flag("kindleby_provost_read_letter", false)
	var offered: Array[String] = []
	_lines(state, "iver", [BYE], offered)
	assert_false("The chapter sat while Kindleby was lit. I held the ring for them." in offered, "only if the ember held it")
	assert_false("Aldous Wren wrote to the Provost." in offered, "only if she read the letter")
	state.set_flag("kindleby_ring_held", true)
	state.set_flag("kindleby_provost_read_letter", true)
	var told := _lines(state, "iver", ["The chapter sat while Kindleby was lit. I held the ring for them.", "Aldous Wren wrote to the Provost.", BYE])
	assert_true(told.contains("somebody not under the rule") and told.contains("one day the chapter will weigh it"), told)
	assert_true(told.contains("He cut the tapers for the east stair."), told)
	assert_eq(state.item_count("stair_taper"), 1, "the checkpoint carries the taper")
	var taper := _lines(state, "iver", ["This came out of the Vigil Light's smoke, into my hand.", BYE])
	assert_true(taper.contains("A stair-taper. Burned past the third notch.") and taper.contains("one voice has."), taper)
	assert_true(bool(state.get_flag("lowsong_keeper_saw_taper")))
	offered.clear()
	_lines(state, "iver", [BYE], offered)
	assert_false("This came out of the Vigil Light's smoke, into my hand." in offered, "shown once")


func test_rowing_back_and_out_again() -> void:
	var state := _leave()
	_travel(state, "hild", [ROW_OUT])
	_lines(state, "lowsong_rowing_out")
	state.set_flag("lowsong_landed", true)  # the arrival event's `set`
	assert_eq(_travel(state, "hild", [BACK]), ["kindleby", "from_skiff"], "Hild on the landing")
	assert_false(bool(state.get_flag("lowsong_out")))
	state.set_flag("lowsong_out", true)
	assert_eq(_travel(state, "lowsong_row_back", ["Ask Hild to row you back to Kindleby."]), ["kindleby", "from_skiff"], "or at the skiff")
	assert_false(bool(state.get_flag("lowsong_out")))
	var told := _lines(state, "hild", [BYE])
	assert_true(told.contains("Back out?"), told)
	assert_eq(_travel(state, "hild", [ROW_OUT]), ["lowsong", "from_skiff"], "as often as you like")


func test_never_a_name_in_the_choir() -> void:
	# Mystery #4: the Choir's nearest voice is a woman's, tired, nearly getting a word out — never her name yet.
	for id: String in ["iver", "lowsong_rowing_out", "lowsong_light", "lowsong_row_back", "hild", "provost"]:
		assert_false(JSON.stringify(_content().dialogues[id]).contains("Isolde"), id)


func test_lowsong_assets() -> void:
	_content()
	for path: String in ["res://assets/models/dressing/lowsong_light.glb", "res://assets/models/dressing/lowsong_cairn.glb",
			"res://assets/models/characters/iver.glb"]:
		assert_true(ResourceLoader.exists(path), path)
	var choir: Dictionary = _db.sounds["choir_near"]
	assert_true(bool(choir.get("loop", false)) and str(choir["bus"]) == "Ambience", "the Choir close is a loop under everything")
	var layers: Array[String] = []
	for layer: Dictionary in _db.get_region("lowsong")["ambience"]:
		layers.append(str(layer["sound"]))
	assert_true("choir_near" in layers, "heard all over Lowsong")
	assert_false(Scenarios.resolve("lowsong").is_empty(), "a checkpoint")
