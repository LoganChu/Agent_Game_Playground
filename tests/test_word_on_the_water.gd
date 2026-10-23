extends TestCase
## Day 60 — *Word on the Water*, and Saltmarrow noticing Dunstan home. Dunstan's message for Oda
## ("not laughing at the weather") is carried to the Slow Mercy at any port; she sends word back
## (home: his berth's still swung; stayed: the Mercy will carry him home, no fare), he answers, and
## the answer goes back to her. Tam, Hesk, Pell and Aldous each notice he walked back.

const FEN := "glasswater_fen"
const HOME := "Go home. Mara's keeping the stool."
const CUP := "There's a second cup going cold by her door. Go home and drink it."
const STAY := "Stay a while. Till you're sure it's done."
const TELL := "Dunstan had word for you."
const TELL_GULL := "The big man from the rowboat had word for you."
const TELL_STAYED := "Dunstan's staying on the fen. Turning the long walk's boards round."
const BERTH := "Oda says your berth's still swung on the Slow Mercy."
const NO_FARE := "Oda says the Mercy will carry you home when you're done. No fare."
const ANSWER := "I've brought Dunstan's answer."
const ANSWER_GULL := "I've brought the big man's answer."
const ALDOUS_HOME := "Dunstan Tollen walked back out of the fog."
const ALDOUS_GULL := "The big man on Mara's stool walked back out of the fog."
const QUEST := "word_on_the_water"

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


## Dunstan walked in to the staithe's foot (as test_walk_back builds it), then sent on his way by `word`
## ("" leaves him there, still to ask for his name).
func _after(word: String, burn: String = "knot") -> WorldState:
	var state := fresh_state(_content())
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "saltmarrow_ferry_arrived", "thornwold_landed",
			"fen_landed", "fen_met_hesper", "fen_met_corran", "fen_heard_of_dunstan", "fen_heron_reached",
			"fen_heron_climbed", "fen_lantern_seen", "fen_dunstan_met", "saltmarrow_mara_told_of_dunstan",
			"saltmarrow_met_mara", "saltmarrow_mara_saw_beacon_lit", "saltmarrow_met_aldous"]:
		state.set_flag(flag, true)
	state.set_flag("lanes_ferry_at", "fen")
	state.set_flag("saltmarrow_ferry_deed", "claimed")
	state.set_flag("fen_ember", "bare")
	state.set_flag("fen_beacon_burned", "channels")
	state.set_flag("saltmarrow_beacon_burned", burn)
	state.set_flag("wrackholm_beacon_burned", "white")
	state.set_flag("fen_dunstan_mara", "burned" if burn == "gull" else "well")
	state.set_flag("fen_dunstan_walk", "in")
	for quest: String in ["a_light_for_saltmarrow", "across_the_grey", "a_light_for_glasswater", "for_after"]:
		state.complete_quest(quest)
	state.start_quest("the_walk_back", "his_name")
	if not word.is_empty():
		_lines(state, "dunstan", [word])
	return state


func test_not_before_he_is_named() -> void:
	var state := _after("")
	var offered := _offered(state, "oda")
	for text: String in [TELL, TELL_GULL, TELL_STAYED, ANSWER]:
		assert_false(offered.has(text), "nothing to carry yet: %s" % text)
	assert_eq(state.quest_state(QUEST), WorldState.QUEST_INACTIVE)


func test_oda_hears_it_at_every_port() -> void:
	for port: String in ["", "saltmarrow", "thornwold", "fen", "wrackholm"]:
		var state := _after(HOME)
		state.set_flag("lanes_ferry_at", port)
		var offered := _offered(state, "oda")
		assert_true(offered.has(TELL), "offered with the ferry at '%s'" % port)
		assert_true(offered.has("Where can you take me?"), "the map still there at '%s'" % port)
		assert_eq(offered.back(), "Not yet.", "the way out stays last at '%s'" % port)


func test_home_the_berth_and_the_stool() -> void:
	var state := _after(HOME)
	assert_eq(state.get_flag("fen_dunstan_walk"), "home")
	assert_false(_offered(state, "dunstan").has(BERTH), "nothing from Oda yet")
	var text := _lines(state, "oda", [TELL])
	assert_true(text.contains("not laughing at the weather") and text.contains("Two winters he crewed for me"))
	assert_true(text.contains("berth's still swung"))
	assert_false(text.contains("wrong way round"), "his sister knows him")
	assert_eq(state.quest_stage(QUEST), "to_dunstan")
	var offered := _offered(state, "oda")
	assert_false(offered.has(TELL), "told once")
	assert_false(offered.has(ANSWER), "no answer yet")
	text = _lines(state, "dunstan", [BERTH])
	assert_true(text.contains("like an anchor going over") and text.contains("it's a stool now"))
	assert_false(text.contains("comfort"))
	assert_eq(state.quest_stage(QUEST), "to_oda")
	assert_false(_offered(state, "dunstan").has(BERTH), "answered once")
	text = _lines(state, "oda", [ANSWER])
	assert_true(text.contains("A stool.") and text.contains("unswing the berth"))
	assert_false(text.contains("By oar"))
	assert_eq(state.quest_state(QUEST), WorldState.QUEST_DONE)
	offered = _offered(state, "oda")
	assert_false(offered.has(ANSWER) or offered.has(TELL), "done")


func test_home_after_the_gull_burn() -> void:
	var state := _after(CUP, "gull")
	var offered := _offered(state, "oda")
	assert_true(offered.has(TELL_GULL))
	assert_false(offered.has(TELL), "the name slides off the player")
	var text := _lines(state, "oda", [TELL_GULL])
	assert_true(text.contains("That's the burn's way round."), "an off-islander keeps his face")
	text = _lines(state, "dunstan", [BERTH])
	assert_true(text.contains("Don't tell her I said comfort."))
	text = _lines(state, "oda", [ANSWER_GULL])
	assert_true(text.contains("the sense not to bring it aboard"))
	assert_eq(state.quest_state(QUEST), WorldState.QUEST_DONE)


func test_stayed_no_fare() -> void:
	var state := _after(STAY)
	assert_eq(state.get_flag("fen_dunstan_walk"), "stayed")
	var offered := _offered(state, "oda")
	assert_true(offered.has(TELL_STAYED))
	assert_false(offered.has(TELL))
	var text := _lines(state, "oda", [TELL_STAYED])
	assert_true(text.contains("no fare") and text.contains("Thirty-eight years sworn"))
	assert_eq(state.quest_stage(QUEST), "to_dunstan")
	text = _lines(state, "dunstan", [NO_FARE])
	assert_true(text.contains("I'll go home by oar") and text.contains("wave from the staithe"))
	assert_eq(state.get_flag("fen_dunstan_walk"), "stayed", "still turning boards")
	text = _lines(state, "oda", [ANSWER])
	assert_true(text.contains("By oar. Tollens.") and text.contains("waving back"))
	assert_false(text.contains("A stool."))
	assert_eq(state.quest_state(QUEST), WorldState.QUEST_DONE)


func test_tam_rang_the_bell() -> void:
	assert_true(_lines(_after(HOME), "tam").contains("I rang it like he was a fire."))
	var gull := _lines(_after(CUP, "gull"), "tam")
	assert_true(gull.contains("It seemed owed.") and not gull.contains("Dunstan"))
	assert_false(_lines(_after(STAY), "tam").contains("gate bell"), "nothing rang for the fen")


func test_hesk_remembers_that_one() -> void:
	assert_true(_lines(_after(HOME, "pebble"), "hesk").contains("Got it, did he? Good. Good."))
	assert_true(_lines(_after(HOME, "knot"), "hesk").contains("I remember that one."), "the knot burned, not him")
	var lit := _after(HOME, "pebble")
	assert_true(_lines(lit, "hesk").contains("The Tollen shoulders came home. Rowing"))
	var gull := _lines(_after(CUP, "gull"), "hesk")
	assert_true(gull.contains("Is it midwinter again?") and not gull.contains("Tollen"))
	assert_false(_lines(_after(STAY, "pebble"), "hesk").contains("came home"))


func test_pell_and_the_whittling() -> void:
	var state := _after(HOME)
	state.set_flag("saltmarrow_pell_ferry_ask", "refused")
	state.set_flag("saltmarrow_pell_crossing", "stayed")
	assert_true(_lines(state, "pell").contains("a potato with opinions"))
	var gull := _after(CUP, "gull")
	gull.set_flag("saltmarrow_pell_ferry_ask", "refused")
	gull.set_flag("saltmarrow_pell_crossing", "stayed")
	var text := _lines(gull, "pell")
	assert_true(text.contains("doesn't know him from a hake"))
	var let_down := _after(HOME)
	let_down.set_flag("saltmarrow_pell_ferry_ask", "promised")
	let_down.set_flag("saltmarrow_pell_crossing", "let_down")
	text = _lines(let_down, "pell")
	assert_true(text.contains("You said I could come.") and text.contains("I'm being cross a bit."))
	var stayed := _after(STAY)
	stayed.set_flag("saltmarrow_pell_ferry_ask", "refused")
	stayed.set_flag("saltmarrow_pell_crossing", "stayed")
	assert_false(_lines(stayed, "pell").contains("whittle"), "not home: nobody to teach Pell")


func test_aldous_said_it() -> void:
	var state := _after(HOME)
	var text := _lines(state, "aldous", [ALDOUS_HOME])
	assert_true(text.contains("the fog doesn't give back what walks into it"))
	assert_true(text.contains("I said it to Mara.") and text.contains("only true while the Spire burned"))
	assert_false(text.contains("long list"), "no confession heard")
	assert_true(state.get_flag("saltmarrow_aldous_heard_walk_back"))
	assert_false(_offered(state, "aldous").has(ALDOUS_HOME), "once")
	var full := _after(HOME)
	full.set_flag("saltmarrow_aldous_confessed", "full")
	assert_true(_lines(full, "aldous", [ALDOUS_HOME]).contains("getting to be a long list"))
	var gull := _after(CUP, "gull")
	var offered := _offered(gull, "aldous")
	assert_true(offered.has(ALDOUS_GULL))
	assert_false(offered.has(ALDOUS_HOME))
	text = _lines(gull, "aldous", [ALDOUS_GULL])
	assert_true(text.contains("I can't think who.") and not text.contains("Mara"))
	var stayed := _after(STAY)
	text = _lines(stayed, "aldous", ["Dunstan Tollen walked back out of the fog. He's staying on the fen to turn the boards for whoever comes next."])
	assert_true(text.contains("Aldous stops turning the bottle.") and text.contains("laying the boards the other way"))
	assert_false(_offered(_after(""), "aldous").has(ALDOUS_HOME), "not before he's walked back")
