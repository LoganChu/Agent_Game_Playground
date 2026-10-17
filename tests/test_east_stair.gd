extends TestCase
## Day 47 — *The East Stair*. Told its name, the Lamp remembers a novice on the east landing who
## said "Keep one back this year, Keeper Sallow" and sends the player to the door-warden. Aldous,
## back in Saltmarrow, hears Wynn Sallow is alive, counts six novices by name and a seventh light
## with no face, and is asked for Wynn's sake or "could it have been me?". He tells of the roll in
## the warden's niche and lays the Wrens' brazier. Wynn can be told what he counted.

const ASK := "Wynn Sallow kept a coal."
const FOR_WYNN := "Wynn would want to know who it was."
const ME := "Could it have been me?"
const KNOW := "Do you know me?"
const BYE := "Rest easy, Brother."
const TELL_WYNN := "Aldous Wren counted the novices on the stair that winter."
const LAMP_BYE := "Goodbye."

var _db: ContentDatabase


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_db, state, dialogue, typed, offered)


func _back_db() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _offered(state: WorldState, dialogue: String, bye: String = BYE) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [bye], offered)
	return offered


## Back in Saltmarrow after the ridge: Aldous told the player `confessed` ('full'/'grudging'), the
## Lamp's name said (`name`), sworn to the lanes or not.
func _back(confessed: String = "full", name: String = "told", sworn: String = "") -> WorldState:
	var state := fresh_state(_back_db())
	for flag: String in ["intro_seen", "saltmarrow_met_aldous", "saltmarrow_ferry_passage", "thornwold_landed",
			"thornwold_met_lamp", "wrackholm_lamp_name_read"]:
		state.set_flag(flag, true)
	state.set_flag("saltmarrow_aldous_approach", "gentle" if confessed == "full" else "pressed")
	state.set_flag("saltmarrow_aldous_confessed", confessed)
	state.set_flag("saltmarrow_beacon_burned", "knot")
	state.set_flag("thornwold_beacon_burned", "salt_row")
	state.set_flag("wrackholm_sworn", sworn)
	state.set_flag("lanes_ferry_at", "saltmarrow")
	state.complete_quest("a_light_for_saltmarrow")
	state.complete_quest("paid_twice")
	state.set_flag("thornwold_lamp_name", name)
	if name == "told":
		state.start_quest("the_east_stair", "ask_the_door_warden")
	return state


## The brazier models whose `if` holds in `state` (all three sit in the Wrens' bowl).
func _brazier(state: WorldState) -> Array[String]:
	var shown: Array[String] = []
	var wren: Array = (_db.get_region("saltmarrow")["props"] as Array).filter(
			func(p: Dictionary) -> bool: return str(p.get("model", "")).get_file() == "house_wren.glb")
	for prop: Dictionary in _db.get_region("saltmarrow")["props"]:
		if str(prop.get("shape", "")) != "brazier":
			continue
		assert_eq(prop["position"], wren[0]["position"], "the brazier sits on the house's origin")
		assert_eq(prop["rotation_y"], wren[0]["rotation_y"], "and turns with it")
		if Conditions.evaluate(prop["if"], state):
			shown.append(str(prop["model"]).get_file().get_basename())
	return shown


func test_the_lamp_sends_you_to_the_door_warden() -> void:
	_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["thornwold_met_lamp", "thornwold_lamp_name_lost", "wrackholm_lamp_name_read"]:
		state.set_flag(flag, true)
	state.start_quest("paid_twice", "carry_it_home")
	_lines(state, "lamp", ["I read your name. In the Tidewrights' Book, on Wrackholm.", "Your name is Wynn Sallow.", LAMP_BYE])
	assert_eq(state.quest_state("the_east_stair"), WorldState.QUEST_ACTIVE)
	assert_eq(state.quest_stage("the_east_stair"), "ask_the_door_warden")
	var left := _back("full", "left")
	assert_false(_offered(left, "aldous").has(ASK), "left in the Book: no novice to ask about")
	assert_eq(left.quest_state("the_east_stair"), WorldState.QUEST_INACTIVE)


func test_asked_for_wynn() -> void:
	var state := _back()
	assert_eq(_brazier(state), ["brazier_raked"] as Array[String], "a full confession rakes the ash")
	assert_true(_offered(state, "aldous").has(ASK))
	var text := _lines(state, "aldous", [ASK, FOR_WYNN, BYE])
	assert_true(text.contains("Wynn Sallow's alive?"))
	assert_true(text.contains("counted Wynn among the dead"), "full: he'd poured one out")
	assert_true(text.contains("Ama Rusk") and text.contains("Fennick"), "six novices by name")
	assert_true(text.contains("Six. I know there were seven."))
	assert_true(text.contains("The fog's had one."))
	assert_true(text.contains("the door-warden's sorry"), "a word for Wynn")
	assert_true(text.contains("warden's niche at the foot of the east stair"), "the roll: a Cindermoor hook")
	assert_false(text.contains("I can't find it anywhere"))
	assert_eq(state.get_flag("saltmarrow_aldous_novice"), "lamp")
	assert_eq(state.quest_state("the_east_stair"), WorldState.QUEST_DONE)
	assert_false(_offered(state, "aldous").has(ASK), "asked once")
	assert_eq(_brazier(state), ["brazier_laid"] as Array[String], "a fire laid for whoever comes down")
	assert_true(_lines(state, "aldous", [KNOW, BYE]).contains("since Wynn's novice"))


func test_could_it_have_been_me() -> void:
	var state := _back()
	var text := _lines(state, "aldous", [ASK, ME, BYE])
	assert_true(text.contains("I can't find it anywhere. Not on the stair. Not off it."))
	assert_true(text.contains("less sure, now, that it's soon at all"), "the Day 1 'too soon', turned")
	assert_false(text.contains("the door-warden's sorry"))
	assert_true(text.contains("the seventh's yours to read. Whoever's it is."))
	assert_eq(state.get_flag("saltmarrow_aldous_novice"), "self")
	assert_eq(state.quest_state("the_east_stair"), WorldState.QUEST_DONE)
	var again := _lines(state, "aldous", [KNOW, BYE])
	assert_true(again.contains("as if it might come back to him"), "he looks at you now")
	assert_true(again.contains("I'm still looking"))
	assert_false(again.contains("after the fourth cup"), "no more pretending")


func test_the_ember_knocks_once() -> void:
	var steps: Array = _back_db().get_dialogue("aldous")["knots"]["novice"]
	var sounds := steps.filter(func(s: Dictionary) -> bool: return s.has("sound")).map(func(s: Dictionary) -> String: return s["sound"])
	assert_eq(sounds, ["ember_knock"], "one knock where the seventh face should be")
	assert_false(bool((_db.sounds["ember_knock"] as Dictionary).get("loop", false)), "a one-shot")


func test_a_grudging_wren_softens() -> void:
	var state := _back("grudging")
	assert_eq(_brazier(state), ["brazier_ash"] as Array[String], "grey all the way down")
	var text := _lines(state, "aldous", [ASK, FOR_WYNN, BYE])
	assert_true(text.contains("only one of us who ran and lived"))
	assert_false(text.contains("counted Wynn among the dead"))
	assert_eq(_brazier(state), ["brazier_laid"] as Array[String])
	assert_true(_lines(state, "wrens_door", []).contains("raked level at last"))


func test_the_lanes_oath_is_weighed() -> void:
	assert_true(_lines(_back("full", "told", "sworn"), "aldous", [ASK, ME, BYE]).contains("A friend of the lanes, asking a Keeper"))
	var declined := _lines(_back("full", "told", "declined"), "aldous", [ASK, ME, BYE])
	assert_true(declined.contains("you stepped off it"))
	assert_false(_lines(_back(), "aldous", [ASK, ME, BYE]).contains("scale"), "never offered: nothing said")


func test_old_saves_start_and_finish_it() -> void:
	var state := _back()
	state.quests.erase("the_east_stair")
	assert_eq(state.quest_state("the_east_stair"), WorldState.QUEST_INACTIVE, "said before Day 47")
	assert_true(_offered(state, "aldous").has(ASK), "Aldous can still be asked")
	_lines(state, "aldous", [ASK, FOR_WYNN, BYE])
	assert_eq(state.quest_state("the_east_stair"), WorldState.QUEST_DONE)


func test_the_wrens_brazier() -> void:
	_back_db()
	for confessed: String in ["", "grudging", "full"]:
		var state := fresh_state(_db)
		state.set_flag("saltmarrow_aldous_confessed", confessed)
		assert_eq(_brazier(state), ["brazier_raked" if confessed == "full" else "brazier_ash"] as Array[String], confessed)
		state.set_flag("saltmarrow_aldous_novice", "self")
		assert_eq(_brazier(state), ["brazier_laid"] as Array[String], confessed + " asked")
	for name: String in ["house_wren", "brazier_ash", "brazier_raked", "brazier_laid"]:
		assert_true(ResourceLoader.exists("res://assets/models/dressing/%s.glb" % name), name)
	var text := _lines(_back(), "wrens_door", [])
	assert_true(text.contains("Raked, the way you'd make up a bed"))
	var asked := _back()
	asked.set_flag("saltmarrow_aldous_novice", "lamp")
	text = _lines(asked, "wrens_door", [])
	assert_true(text.contains("three sticks of driftwood") and not text.contains("make up a bed"))


func test_wynn_hears_what_he_counted() -> void:
	var state := _back()
	assert_false(_offered(state, "lamp", LAMP_BYE).has(TELL_WYNN), "nothing to tell yet")
	_lines(state, "aldous", [ASK, FOR_WYNN, BYE])
	assert_true(_offered(state, "lamp", LAMP_BYE).has(TELL_WYNN))
	var text := _lines(state, "lamp", [TELL_WYNN, LAMP_BYE])
	assert_true(text.contains("Seven. I'd not have said seven."))
	assert_true(text.contains("a door-warden isn't the door"), "Wynn answers his sorry")
	assert_true(text.contains("I'd ask them how they knew"))
	assert_true(state.get_flag("thornwold_lamp_heard_seventh"))
	assert_false(_offered(state, "lamp", LAMP_BYE).has(TELL_WYNN), "told once")
	var me := _back()
	_lines(me, "aldous", [ASK, ME, BYE])
	text = _lines(me, "lamp", [TELL_WYNN, LAMP_BYE])
	assert_true(text.contains("You asked him if it was you") and not text.contains("isn't the door"))
