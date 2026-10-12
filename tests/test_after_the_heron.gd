extends TestCase
## Day 37 — After the Heron: back on the fen, the lantern lit at the fog's foot sits at the end of
## the long walk (For After); Dunstan Tollen by it, whittling — "The big man" until he says his name
## (and always after the gull burn); what he hears of Mara (her word → a gull for the stool, facing
## the door; the gull burn → two cups); the rule; the Heron's climber (the carrier left open). Oda
## three-lit at the fen (the lane on to Wrackholm, the trip out, Dunstan), Hesper keeping his name,
## Mara and the stool.

const FEN := "glasswater_fen"
const GULL_BURN := "saltmarrow_beacon_burned"
const WELL := "She's well. She keeps the harbor, and everyone fed."
const MESSAGE := "She sent word: the stool's still by the door."
const POSTED := "It was me tied her word on the post. She meant it."
const CUPS := "She says Tollens end with her. And she keeps setting out two cups."
const NOT_MINE := "That's not mine to carry out here."
const LANTERN := "What's the lantern for?"
const ASK := "What did you come here to put down?"
const KEEP := "I won't ask what you came here for."
const CLIMB := "Is it you who climbs the Heron's ladder?"

var _db: ContentDatabase


## The Heron lit (the name burned), back on the fen; `word` left on the letting post.
func _lit(word: String = "", burn: String = "knot") -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "thornwold_landed", "fen_landed", "fen_met_hesper",
			"fen_met_corran", "fen_heard_of_dunstan", "fen_heron_reached", "fen_heron_climbed", "saltmarrow_mara_told_of_dunstan"]:
		state.set_flag(flag, true)
	state.set_flag("lanes_ferry_at", "fen")
	state.set_flag("fen_ember", "bare")
	state.set_flag("fen_skiff_bell", "hung")
	state.set_flag("fen_dunstan_glimpsed", "nameless" if burn == "gull" else "watched")
	state.set_flag("fen_beacon_burned", "name")
	state.set_flag(GULL_BURN, burn)
	state.set_flag("fen_dunstan_word", word)
	state.complete_quest("a_light_for_glasswater")
	return state


## The arrival scene played (For After begun).
func _seen(word: String = "", burn: String = "knot") -> WorldState:
	var state := _lit(word, burn)
	state.set_flag("fen_lantern_seen", true)
	_lines(state, "fen_lantern_for_after")
	return state


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_db, state, dialogue, typed, offered)


func _offered(state: WorldState, dialogue: String) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [], offered)
	return offered


func _event(state: WorldState) -> Dictionary:
	for e: Dictionary in _db.get_region(FEN)["events"]:
		if str(e["id"]) == "fen_lantern_for_after":
			return e
	return {}


func _placements(state: WorldState) -> Array:
	return (_db.get_region(FEN)["npcs"] as Array).filter(func(p: Dictionary) -> bool:
		return str(p["npc"]) == "dunstan" and Conditions.evaluate(p.get("if"), state))


func test_the_lantern_is_seen_once_after_the_burn() -> void:
	var state := _lit()
	var event := _event(state)
	assert_false(event.is_empty(), "the arrival scene exists")
	assert_true(Conditions.evaluate(event["if"], state), "fires on the first arrival after the burn")
	var before := fresh_state(load_content())
	before.set_flag("fen_landed", true)
	assert_false(Conditions.evaluate(event["if"], before), "not while the Heron is dark")
	var text := _lines(state, "fen_lantern_for_after")
	assert_true(text.contains("end of the long walk") and text.contains("not one of mine"), "seen from the landing; Corran's not")
	assert_eq(state.quest_stage("for_after"), "the_light_on_the_long_walk", "For After begins")
	state.set_flag("fen_lantern_seen", true)
	assert_false(Conditions.evaluate(event["if"], state), "once")


func test_dunstan_sits_by_the_lantern_with_or_without_the_cord() -> void:
	_db = load_content()
	assert_eq(_placements(fresh_state(_db)).size(), 0, "nobody at the end of the walk while the Heron is dark")
	for word: String in ["", "mara", "own", "none"]:
		var shown := _placements(_lit(word))
		assert_eq(shown.size(), 1, "one Dunstan for word '%s'" % word)
		var model := str((shown[0] as Dictionary).get("model", _db.get_npc("dunstan")["model"]))
		assert_eq(model.ends_with("dunstan_seated_cord.glb"), word == "mara", "the red cord at his belt only for Mara's word (%s)" % word)
	var all: Array = (_db.get_region(FEN)["npcs"] as Array).filter(func(p: Dictionary) -> bool: return str(p["npc"]) == "dunstan")
	assert_eq(all[0]["position"], all[1]["position"], "the same spot")
	assert_eq(all[0]["rotation_y"], all[1]["rotation_y"], "facing the same way")
	for path: String in ["res://assets/models/characters/dunstan_seated.glb", "res://assets/models/characters/dunstan_seated_cord.glb"]:
		assert_true(ResourceLoader.exists(path), path)
	# His lantern is lit: the last board carries its halo, beside him (no real light: the budget).
	var pos: Array = all[0]["position"]
	var lit := (_db.get_region(FEN)["props"] as Array).filter(func(p: Dictionary) -> bool:
		if not p.has("halo"):
			return false
		var at: Array = p["position"]
		var off: Array = p["halo"]
		var light := Vector3(float(at[0]), 0, float(at[2])) + Vector3(float(off[0]), 0, float(off[2])).rotated(Vector3.UP, deg_to_rad(float(p.get("rotation_y", 0))))
		return light.distance_to(Vector3(float(pos[0]), 0, float(pos[2]))) < 1.0)
	assert_eq(lit.size(), 1, "a lantern halo by his tussock")
	assert_true(Conditions.evaluate(lit[0]["if"], _lit()) and not Conditions.evaluate(lit[0]["if"], fresh_state(_db)), "lit with the Heron")


func test_the_big_man_until_he_says_his_name() -> void:
	var state := _seen()
	var npc: Dictionary = _db.get_npc("dunstan")
	assert_eq(ContentDatabase.npc_display_name(npc, state), "The big man", "unnamed before he says it")
	var runner := DialogueRunner.new(_db, state)
	var ev := runner.start("dunstan")
	var names: Array[String] = []
	while ev["type"] == "line":
		if str(ev["speaker"]) == "dunstan":
			names.append(str(ev["name"]))
		ev = runner.next()
	assert_eq(names[0], "The big man", "speaks first as the big man")
	assert_eq(names[-1], "Dunstan Tollen", "...and as himself once he's said it")
	assert_true(state.get_flag("fen_dunstan_met"))
	assert_eq(state.quest_state("for_after"), WorldState.QUEST_DONE, "For After done")
	var gull := _seen("", "gull")
	_lines(gull, "dunstan")
	assert_true(gull.get_flag("fen_dunstan_met"))
	assert_eq(ContentDatabase.npc_display_name(npc, gull), "The big man", "after the gull burn the name won't stay")


func test_the_first_talk_honours_earlier_choices() -> void:
	var mara := _seen("mara")
	var text := _lines(mara, "dunstan", [POSTED])
	for bit: String in ["red cord", "That was you carried it", "Dunstan Tollen", "Mara's brother", "Hesper's gone without her name",
			"let me go"]:
		assert_true(text.contains(bit), "word=mara: " + bit)
	var own := _seen("own")
	assert_true(_lines(own, "dunstan").contains("I cut it off the hook. Then I went back for it"), "own word: cut off, then taken")
	var none := _seen("none")
	assert_true(_lines(none, "dunstan").contains("nothing on the letting post"), "no word: the best of it")
	var gull := _seen("", "gull")
	gull.set_flag("fen_ember", "cupped")
	var gull_text := _lines(gull, "dunstan")
	assert_true(gull_text.contains("rain off a coat") and gull_text.contains("My sister keeps the harbor"), "the gull burn: the name slides, his sister lands")
	assert_true(gull_text.contains("like I was weather"), "nameless at the Heron's foot")
	assert_true(gull_text.contains("open your hand"), "a cupped ember")
	assert_false(gull_text.contains("Mara's brother"), "no narration of who he is")


func test_what_he_hears_of_mara() -> void:
	var message := _seen("own")
	message.set_flag("saltmarrow_mara_message_for_dunstan", true)
	var offered: Array[String] = []
	var text := _lines(message, "dunstan", [MESSAGE], offered)
	assert_true(offered.has(MESSAGE) and not offered.has(POSTED) and not offered.has(CUPS), "Mara's message offered (%s)" % [offered])
	assert_true(text.contains("Facing the door") and text.contains("not a promise"), "a gull for the stool")
	assert_eq(message.get_flag("fen_dunstan_mara"), "message")
	assert_true(message.item_count("gull_for_mara") > 0, "the gull carried")
	var posted := _seen("mara")
	posted.set_flag("saltmarrow_mara_message_for_dunstan", true)
	var posted_offered: Array[String] = []
	_lines(posted, "dunstan", [POSTED], posted_offered)
	assert_false(posted_offered.has(MESSAGE), "her word already given on the post")
	assert_true(posted.item_count("gull_for_mara") > 0, "...the gull either way")
	var burned := _seen("", "gull")
	burned.set_flag("saltmarrow_mara_message_for_dunstan", true)
	var burned_offered: Array[String] = []
	var burned_text := _lines(burned, "dunstan", [CUPS], burned_offered)
	assert_false(burned_offered.has(MESSAGE), "no message after the gull burn (she can't have sent one)")
	assert_true(burned_text.contains("Two cups.") and burned_text.contains("backward"), "two cups; backward")
	assert_eq(burned.get_flag("fen_dunstan_mara"), "burned")
	assert_false(burned.item_count("gull_for_mara") > 0, "nothing for her after the gull burn")
	var spared := _seen("", "gull")
	_lines(spared, "dunstan", [WELL])
	assert_eq(spared.get_flag("fen_dunstan_mara"), "spared", "after the gull burn, 'she's well' spares him")
	var well := _seen()
	_lines(well, "dunstan", [WELL])
	assert_eq(well.get_flag("fen_dunstan_mara"), "well")
	var nothing := _seen()
	_lines(nothing, "dunstan", [NOT_MINE])
	assert_eq(nothing.get_flag("fen_dunstan_mara"), "nothing")


func test_the_lantern_the_rule_and_the_climber() -> void:
	var state := _seen()
	var text := _lines(state, "dunstan", [WELL, LANTERN, ASK, CLIMB])
	assert_true(text.contains("For after.") and text.contains("ask Hesper for my name"), "for after: to walk back by, then his name")
	assert_true(text.contains("I don't know. That's how you know it went"), "asked: he doesn't know")
	assert_eq(state.get_flag("fen_dunstan_rule"), "asked")
	assert_true(text.contains("I didn't carry them up") and text.contains("I don't know whose"), "the carrier stays open")
	assert_true(text.contains("never touched it"), "the coat left as it was left")
	var offered := _offered(state, "dunstan")
	assert_false(offered.has(ASK) or offered.has(KEEP), "the rule asked or kept once")
	assert_true(_lines(state, "dunstan").contains("Still here. Still nearly."), "later: still nearly")
	var kept := _seen()
	assert_true(_lines(kept, "dunstan", [WELL, KEEP]).contains("The light's good"), "the rule kept")
	assert_eq(kept.get_flag("fen_dunstan_rule"), "kept")
	var not_climbed := _seen()
	not_climbed.set_flag("fen_heron_climbed", false)
	assert_false(_offered(not_climbed, "dunstan").has(CLIMB), "the climber only once you've been up")


func test_mara_and_the_stool() -> void:
	var state := _seen()
	state.set_flag("saltmarrow_mara_message_for_dunstan", true)
	_lines(state, "dunstan", [MESSAGE])
	state.set_flag("saltmarrow_met_mara", true)
	state.set_flag("saltmarrow_mara_saw_beacon_lit", true)
	state.complete_quest("a_light_for_saltmarrow")
	var text := _lines(state, "mara", ["Dunstan sent you this."])
	assert_true(text.contains("Facing the door. Not north.") and text.contains("If he comes."), "Mara sets it on the stool")
	assert_false(state.item_count("gull_for_mara") > 0, "given")
	assert_true(state.get_flag("saltmarrow_mara_got_gull"))
	assert_false(_offered(state, "mara").has("Dunstan sent you this."), "once")
	assert_true(_lines(state, "dunstans_stool").contains("beak turned to Mara's door"), "the stool shows it")


func test_oda_three_lit_and_the_lane_on() -> void:
	var state := _seen()
	var offered: Array[String] = []
	var text := _lines(state, "oda", ["Where does the lane go from here?"], offered)
	assert_true(text.contains("Three lit."), "three lit")
	assert_true(text.contains("Wrackholm") and text.contains("lane-house"), "the lane on: Wrackholm")
	assert_true(offered.has("I went out to the Heron's legs."), "the trip out, to tell")
	var trip := _lines(state, "oda", ["I went out to the Heron's legs."])
	assert_true(trip.contains("tied her bell back") and trip.contains("let him walk"), "the bell and the big man")
	assert_false(_offered(state, "oda").has("I went out to the Heron's legs."), "told once")
	_lines(state, "dunstan", [WELL])
	assert_true(_lines(state, "oda", ["I found Dunstan."]).contains("Is he laughing?"), "Oda asks one thing")
	assert_false(_offered(state, "oda").has("I found Dunstan."), "once")
	var gull := _seen("", "gull")
	_lines(gull, "dunstan", [WELL])
	var gull_offered := _offered(gull, "oda")
	assert_true(gull_offered.has("I found the big man from the rowboat.") and not gull_offered.has("I found Dunstan."),
			"after the gull burn the player can't name him")
	var thornwold := fresh_state(_db)
	thornwold.set_flag("lanes_ferry_at", "fen")
	assert_false(_lines(thornwold, "oda").contains("Three lit."), "not before the Heron")
	var dock := fresh_state(_db)
	dock.set_flag("saltmarrow_ferry_deed", "claimed")
	assert_true(_lines(dock, "oda", ["Why only as far as Thornwold?"]).contains("the one past that"), "the route line: one light at a time")


func test_hesper_keeps_his_name() -> void:
	var state := _seen()
	assert_false(_offered(state, "hesper").has("I found the man who left his name with you."), "not before he's found")
	_lines(state, "dunstan", [WELL])
	var text := _lines(state, "hesper", ["I found the man who left his name with you."])
	assert_true(text.contains("So he's not done. I'll keep it."), "she keeps it till he sends")
	assert_true(text.contains("I couldn't keep my own"), "the name burned: she still has his")
	assert_false(_offered(state, "hesper").has("I found the man who left his name with you."), "once")


func test_validator_checks_npc_names() -> void:
	var db := load_content()
	(db.npcs["dunstan"]["names"] as Array).append({"name": "Nobody"})
	var validator := ContentValidator.new(db)
	assert_false(validator.validate(), "validator should fail")
	assert_true(validator.report().contains("each names entry needs an 'if' and a non-empty 'name'"), validator.report())
	var db2 := load_content()
	db2.npcs["dunstan"]["names"] = [{"if": "flag:no_such_flag", "name": "X"}]
	var v2 := ContentValidator.new(db2)
	assert_false(v2.validate(), "an undeclared flag in a names condition fails")
