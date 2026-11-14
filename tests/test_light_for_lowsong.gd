extends TestCase
## Day 77 — Act II's close, steps 3-4: *A Light for Lowsong*. The fog on the Low Water leaves nothing lying, so
## Brother Iver makes Lowsong's Remnant himself with the ember beside him: his lamp (his listening, the nearest
## voice in the Choir) or his cell key (Kindleby, the way home). It can be given back until it burns. The cradle
## won't take the Stair-Taper. Lit: the Choir goes off past the skerries, the ember gives back the Hood-Pin (the
## second own Remnant), and Iver either rows home with Hild (lamp) or keeps the rock not knowing Kindleby (key).

const SOMETHING := "Then it'll have to be something of yours."
const LAMP := "Give me the lamp."
const KEY := "Give me the key."
const PRESS := "She's been at it longer than you have. You said yourself she's tired."
const BYE := "Goodbye."
const BACK_LAMP := "Here. Take your lamp back. I'll not burn that."
const PIN := "This came out of the light's smoke, into my hand."

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


## On Lowsong with the Keeper met (the `lowsong` checkpoint + the meeting).
func _met() -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("lowsong"))
	_lines(state, "iver", [BYE])
	assert_eq(state.quest_stage("a_light_for_lowsong"), "the_singing", "met")
	return state


func _placed(region: String, npc: String, state: WorldState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for placed: Dictionary in _content().get_region(region)["npcs"]:
		if placed["npc"] == npc and Conditions.evaluate(placed.get("if"), state):
			out.append(placed)
	return out


func _model(placed: Dictionary) -> String:
	return str(placed.get("model", _content().npcs["iver"]["model"]))


## Made the Remnant (`which`: "lamp" or "key") and burned it in the cradle.
func _lit(which: String) -> WorldState:
	var state := _met()
	if which == "lamp":
		_lines(state, "iver", [SOMETHING, LAMP, PRESS, BYE])
		_lines(state, "lowsong_light", ["Set Iver's Lamp in the cradle.", "Burn Iver's listening."])
	else:
		_lines(state, "iver", [SOMETHING, KEY, BYE])
		_lines(state, "lowsong_light", ["Set Iver's Cell Key in the cradle.", "Burn Iver's Kindleby."])
	assert_eq(state.quest_state("a_light_for_lowsong"), "done", which)
	return state


func test_iver_offers_two_things() -> void:
	var state := _met()
	var offered: Array[String] = []
	var told := _lines(state, "iver", [SOMETHING, "Neither. Not yet.", BYE], offered)
	assert_true(SOMETHING in offered)
	assert_true(told.contains("A Remnant, made on purpose.") and told.contains("you'll choose. I'd only choose wrong."), told)
	assert_true(told.contains("I'll not remember I ever heard her") and told.contains("I'll not know there was anywhere else"), told)
	assert_eq(str(state.get_flag("lowsong_iver_gave")), "", "nothing made yet")
	assert_eq(state.quest_stage("a_light_for_lowsong"), "the_singing")


func test_the_lamp_has_to_be_pressed_for() -> void:
	var state := _met()
	var told := _lines(state, "iver", [SOMETHING, LAMP, "Keep it. I'll think.", BYE])
	assert_true(told.contains("She nearly had a word out last night."), told)
	assert_eq(state.item_count("iver_lamp"), 0, "backed off")
	told = _lines(state, "iver", [SOMETHING, LAMP, PRESS, BYE])
	assert_true(told.contains("...I did say that.") and told.contains("the lamp doesn't fall"), told)
	assert_eq(state.item_count("iver_lamp"), 1)
	assert_eq(str(state.get_flag("lowsong_iver_gave")), "lamp")
	assert_eq(state.quest_stage("a_light_for_lowsong"), "put_down")
	var offered: Array[String] = []
	_lines(state, "iver", [BYE], offered)
	assert_false(SOMETHING in offered, "one at a time")
	var on_rock := _placed("lowsong", "iver", state)
	assert_eq(on_rock.size(), 1)
	assert_true(_model(on_rock[0]).ends_with("iver_nolamp.glb"), "his hands are empty while you carry it")


func test_given_back_until_it_burns() -> void:
	var state := _met()
	_lines(state, "iver", [SOMETHING, LAMP, PRESS, BYE])
	var told := _lines(state, "iver", [BACK_LAMP, BYE])
	assert_true(told.contains("There she is."), told)
	assert_eq([state.item_count("iver_lamp"), str(state.get_flag("lowsong_iver_gave"))], [0, ""])
	assert_true(_model(_placed("lowsong", "iver", state)[0]).ends_with("iver.glb"), "the lamp back in his hand")
	told = _lines(state, "iver", [SOMETHING, KEY, BYE])
	assert_true(told.contains("A drowned man doesn't want a key."), told)
	assert_eq([state.item_count("iver_key"), str(state.get_flag("lowsong_iver_gave"))], [1, "key"])
	_lines(state, "iver", ["Here. Take your key back. I'll not burn that.", BYE])
	assert_eq(state.item_count("iver_key"), 0)


func test_the_cradle_wont_take_the_taper() -> void:
	var state := _met()
	var offered: Array[String] = []
	var told := _lines(state, "lowsong_light", ["Set the Stair-Taper in the cradle.", "Not yet."], offered)
	assert_true(told.contains("You have nothing to set in it."), told)
	assert_true(told.contains("The cradle doesn't lean to it."), told)
	assert_false("Set Iver's Lamp in the cradle." in offered)
	assert_eq(state.item_count("stair_taper"), 1, "the ember won't let go of it")
	assert_eq(str(state.get_flag("lowsong_beacon_burned")), "")
	var before := fresh_state(_content())
	Scenarios.apply(_content(), before, Scenarios.resolve("lowsong"))
	told = _lines(before, "lowsong_light")
	assert_false(told.contains("a Keeper's stair"), "not up the stair before the Keeper's been met")


func test_burning_the_lamp() -> void:
	var state := _lit("lamp")
	assert_eq(str(state.get_flag("lowsong_beacon_burned")), "lamp")
	assert_eq(state.item_count("iver_lamp"), 0, "burned")
	var landing := _placed("lowsong", "iver", state)
	assert_eq(landing.size(), 1)
	assert_true(_model(landing[0]).ends_with("iver_nolamp.glb") and float(landing[0]["position"][0]) > 15.0, "down by the skiff")
	var told := _lines(state, "iver", [BYE])
	assert_true(told.contains("nothing out there but the wind in the skerries"), told)
	assert_true(_lines(state, "hild", ["Goodbye."]).contains("He's coming home with us."))
	state.set_flag("lowsong_landed", true)
	_lines(state, "hild", ["Take me back to Kindleby."])
	assert_true(bool(state.get_flag("lowsong_iver_home")), "rowed home with Hild")
	assert_eq(_placed("lowsong", "iver", state).size(), 0, "gone off the rock")
	assert_eq(_placed("kindleby", "iver", state).size(), 1, "on Kindleby")
	told = _lines(state, "iver", [BYE])
	assert_true(told.contains("Agathe's struck me out of the Book."), told)
	told = _lines(state, "provost", ["Brother Iver's home.", "Goodbye."])
	assert_true(told.contains("It's the first line I've ever struck."), told)
	state.set_flag("lowsong_out", true)
	assert_eq(_placed("lowsong", "iver", state).size(), 0, "rowing out again, he's not there")


func test_burning_the_key() -> void:
	var state := _lit("key")
	assert_eq(str(state.get_flag("lowsong_beacon_burned")), "key")
	var rock := _placed("lowsong", "iver", state)
	assert_eq(rock.size(), 1)
	assert_true(_model(rock[0]).ends_with("iver.glb"), "still holding his lamp, still listening")
	var told := _lines(state, "iver", ["Who is she, the one you listen for?", BYE])
	assert_true(told.contains("Kindleby? I don't know it.") and told.contains("I'll know her when she says it."), told)
	assert_true(_lines(state, "hild", ["Goodbye."]).contains("He asked me my name."))
	_lines(state, "hild", ["Take me back to Kindleby."])
	assert_false(bool(state.get_flag("lowsong_iver_home")), "he stays")
	assert_eq(_placed("kindleby", "iver", state).size(), 0)
	told = _lines(state, "provost", ["Brother Iver's alive. He's keeping Lowsong's light, and he's staying.", "Goodbye."])
	assert_true(told.contains("I'll write him in again, under the light"), told)


func test_the_light_catches_and_gives_back_the_hood_pin() -> void:
	for which: String in ["lamp", "key"]:
		var state := _lit(which)
		assert_eq(state.item_count("hood_pin"), 1, which)
		assert_true(bool(state.get_flag("lowsong_hood_pin")))
		assert_eq(state.quest_stage("what_the_ember_keeps"), "the_hood_pin")
		assert_eq(str(_content().items["hood_pin"]["kind"]), "own")
		var lit := _lines(state, "lowsong_light")
		assert_true(lit.contains("burns gold behind its dull horn"), lit)
		var pin := _lines(state, "iver", [PIN, BYE])
		assert_true(pin.contains("A novice's hood-pin."), pin)
		assert_eq(pin.contains("She's stopped again."), which == "key", which)
		var offered: Array[String] = []
		_lines(state, "iver", [BYE], offered)
		assert_false(PIN in offered, "shown once")
		var remembered := _lines(state, "memory_hood_pin")
		assert_true(remembered.contains("Nobody's to see your face on this stair tonight."), remembered)


func test_lowsong_lit_changes_the_rock() -> void:
	var region := _content().get_region("lowsong")
	for which: String in ["", "lamp", "key"]:
		var state := fresh_state(_content())
		state.set_flag("lowsong_beacon_burned", which)
		if which != "":
			state.start_quest("a_light_for_lowsong", "the_singing")
			state.complete_quest("a_light_for_lowsong")
		var lights := 0
		var lit_model := false
		for prop: Dictionary in region["props"]:
			if str(prop.get("model", "")).contains("lowsong_light") and Conditions.evaluate(prop.get("if"), state):
				lights += 1
				lit_model = str(prop["model"]).ends_with("lowsong_light_lit.glb")
		assert_eq(lights, 1, which)
		assert_eq(lit_model, which != "", "the lit light: " + which)
		var choir := 0.0
		for layer: Dictionary in region["ambience"]:
			if layer["sound"] == "choir_near" and Conditions.evaluate(layer.get("if"), state):
				choir = maxf(choir, float(layer["volume"]))
		assert_true(choir > 0.0 and (choir < 0.5) == (which != ""), "the Choir further off once lit: %s %f" % [which, choir])
	for path: String in ["res://assets/models/dressing/lowsong_light_lit.glb", "res://assets/models/characters/iver_nolamp.glb"]:
		assert_true(ResourceLoader.exists(path), path)
	assert_false(Scenarios.resolve("lowsong_lit").is_empty(), "a checkpoint")


func test_never_a_name() -> void:
	# Day 90: her name is said at last (Act III step 7) — but only on lines gated on having read it in the Spire's book.
	for id: String in ["iver", "lowsong_light", "memory_hood_pin", "memory_iver_lamp", "hild", "provost"]:
		for knot: String in _content().dialogues[id]["knots"]:
			for step: Dictionary in _content().dialogues[id]["knots"][knot]:
				# A choice step is checked per option (Day 103: "Her name is Isolde Vane.", told Iver after the ending).
				var parts: Array = step["choice"] if step.has("choice") else [step]
				for part: Dictionary in parts:
					if JSON.stringify(part).contains("Isolde"):
						assert_true(JSON.stringify(part.get("if", "")).contains("cindermoor_choir_"), "%s/%s: %s" % [id, knot, part])
