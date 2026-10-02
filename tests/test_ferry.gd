extends TestCase
## The ferry's arrival (pays off *Across the Grey*): the horn as a region arrival event,
## Oda Farrow weighing the deed, Pell's crossing settled with Mara, farewells, the act-end
## recap, and the validator rules for events and conditional multi-placement.

const FERRY := "across_the_grey"

var _db: ContentDatabase


## Act I closed: beacon burned with `burn`, Aldous confessed, the green lantern hung.
func _state(burn: String = "knot") -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "shingle_met_pell", "saltmarrow_met_mara", "saltmarrow_met_aldous", "saltmarrow_mara_saw_beacon_lit"]:
		state.set_flag(flag, true)
	state.set_flag("saltmarrow_beacon_burned", burn)
	state.start_quest("a_light_for_saltmarrow", "speak_to_aldous")
	state.complete_quest("a_light_for_saltmarrow")
	state.set_flag("saltmarrow_aldous_confessed", "full")
	state.start_quest(FERRY, "ask_mara")
	state.set_quest_stage(FERRY, "await_the_ferry")
	state.set_flag("saltmarrow_ferry_lantern_hung", true)
	return state


## The horn has sounded (as the arrival event would) and the player has spoken to Oda.
func _arrived(burn: String = "knot") -> WorldState:
	var state := _state(burn)
	var event := RegionEvents.arrival(_db.get_region("shingle_point"), state)
	play_dialogue(_db, state, RegionEvents.fire(event, state), [])
	return state


func _shown(region_id: String, kind: String, key: String, value: String, state: WorldState) -> bool:
	for entry: Dictionary in _db.get_region(region_id).get(kind, []):
		if str(entry.get(key, "")) == value and Conditions.evaluate(entry.get("if"), state):
			return true
	return false


func test_the_horn_sounds_once_away_from_the_harbor() -> void:
	var state := _state()
	state.set_flag("saltmarrow_ferry_lantern_hung", false)
	for region_id: String in ["shingle_point", "gulls_head", "saltmarrow"]:
		assert_true(RegionEvents.arrival(_db.get_region(region_id), state).is_empty(), "no horn before the lantern (%s)" % region_id)
	state.set_flag("saltmarrow_ferry_lantern_hung", true)
	assert_true(RegionEvents.arrival(_db.get_region("saltmarrow"), state).is_empty(), "watched harbors never get ferries")
	for region_id: String in ["shingle_point", "gulls_head"]:
		assert_eq(RegionEvents.arrival(_db.get_region(region_id), state).get("dialogue"), "ferry_horn", region_id)
	var event := RegionEvents.arrival(_db.get_region("gulls_head"), state)
	var text := play_dialogue(_db, state, RegionEvents.fire(event, state), [])
	assert_true(text.contains("one long low note"), "the horn")
	assert_eq(state.get_flag("saltmarrow_ferry_arrived"), true)
	assert_eq(state.quest_stage(FERRY), "meet_the_ferry")
	for region_id: String in ["shingle_point", "gulls_head"]:
		assert_true(RegionEvents.arrival(_db.get_region(region_id), state).is_empty(), "the horn doesn't sound twice (%s)" % region_id)


func test_ferry_and_pell_move_when_the_ferry_is_in() -> void:
	var state := _state()
	assert_true(_shown("shingle_point", "npcs", "npc", "pell", state), "Pell on the beach before")
	assert_false(_shown("saltmarrow", "npcs", "npc", "pell", state), "not yet on the dock")
	assert_false(_shown("saltmarrow", "npcs", "npc", "oda", state), "no ferry-master yet")
	assert_false(_shown("saltmarrow", "props", "model", "res://assets/models/dressing/ferry.glb", state), "no ferry yet")
	state.set_flag("saltmarrow_ferry_arrived", true)
	assert_false(_shown("shingle_point", "npcs", "npc", "pell", state), "Pell has left the beach")
	assert_true(_shown("saltmarrow", "npcs", "npc", "pell", state), "Pell on the dock")
	assert_true(_shown("saltmarrow", "npcs", "npc", "oda", state), "Oda at the dock end")
	assert_true(_shown("saltmarrow", "props", "model", "res://assets/models/dressing/ferry.glb", state), "the Slow Mercy alongside")
	assert_false(_shown("saltmarrow", "props", "model", "res://assets/models/dressing/bundle.glb", state), "no bundle unless promised")
	state.set_flag("saltmarrow_pell_ferry_ask", "promised")
	assert_true(_shown("saltmarrow", "props", "model", "res://assets/models/dressing/bundle.glb", state), "Pell's bundle when promised")


func test_oda_weighs_the_deed_and_asks_what_it_cost() -> void:
	var expected := {"pebble": "rain off a coat", "knot": "sits easy with my crew", "gull": "Then it'll be Dunstan"}
	for burn: String in expected:
		var state := _arrived(burn)
		var text := play_dialogue(_db, state, "oda", ["Saltmarrow relit it. I carried the ember up the hill."])
		assert_eq(state.get_flag("saltmarrow_ferry_deed"), "shared", burn)
		assert_true(text.contains(expected[burn]), "Oda on the %s burn" % burn)
		assert_true(text.contains("Thornwold"), "passage only as far as Thornwold")
		assert_eq(state.quest_stage(FERRY), "take_passage", burn)
		assert_eq(state.get_flag("saltmarrow_oda_knew_dunstan"), burn == "gull", "Oda remembers Dunstan only matters after the gull burn")
		# The deed is weighed once; later visits go straight to the hub.
		var offered: Array[String] = []
		text = play_dialogue(_db, state, "oda", [], offered)
		assert_false(text.contains("Tell it me"), "no second weighing (%s)" % burn)
		assert_true(offered.has("I'm ready. Take me across."))
	var brusque := _arrived()
	var told := play_dialogue(_db, brusque, "oda", ["Does it matter? I need to cross."])
	assert_eq(brusque.get_flag("saltmarrow_ferry_deed"), "brusque")
	assert_true(told.contains("You tell it poorly"))


func test_passage_ends_act_one_with_a_recap() -> void:
	var state := _arrived("pebble")
	state.set_flag("saltmarrow_pell_lent_pebble", true)
	state.add_item("keepers_sleeve_ember")
	assert_true(ActRecap.reached(_db, state).is_empty(), "act not ended yet")
	play_dialogue(_db, state, "oda", ["I relit the Gull's Beacon.", "Show Oda the Keeper's sleeve-ember.", "I'm ready. Take me across."])
	assert_eq(state.get_flag("saltmarrow_ferry_passage"), true)
	assert_eq(state.quest_stage(FERRY), "evening_tide")
	assert_eq(state.quest_state(FERRY), "active", "Act II completes the crossing")
	var reached := ActRecap.reached(_db, state)
	assert_true(reached.has("act1"), "act one ends on taking passage")
	var lines := "\n".join(ActRecap.lines(ActRecap.acts(_db)[0], state))
	assert_true(lines.contains("lullaby"), "recap names the burn")
	assert_true(lines.contains("empty nest"), "recap remembers Pell's pebble")
	assert_true(lines.contains("sleeve"), "recap: Aldous's sleeve / Oda saw it")
	assert_false(lines.contains("founding knot"), "no other burn in the recap")
	var offered: Array[String] = []
	play_dialogue(_db, state, "oda", [], offered)
	assert_false(offered.has("I'm ready. Take me across."), "passage taken once")
	assert_true(offered.has("Cast off for Thornwold."))


func test_a_promised_pell_needs_maras_leave() -> void:
	for yes: bool in [true, false]:
		var state := _arrived()
		state.set_flag("saltmarrow_pell_ferry_ask", "promised")
		play_dialogue(_db, state, "oda", ["I relit the Gull's Beacon."])
		var text := play_dialogue(_db, state, "oda", ["I'm ready. Take me across."])
		assert_true(text.contains("Not while that kid's waiting"), "Oda won't sail with Pell unanswered")
		assert_eq(state.get_flag("saltmarrow_ferry_passage"), false)
		text = play_dialogue(_db, state, "pell", [])
		assert_true(text.contains("You tell her?") or text.contains("Did you tell Mara?"), "Pell asks the player to tell Mara")
		var pick := "I'll keep Pell close. You have my word, on the ember." if yes else "You're right. Pell should stay with you."
		text = play_dialogue(_db, state, "mara", ["About Pell and the ferry.", pick])
		assert_eq(state.get_flag("saltmarrow_pell_crossing"), "aboard" if yes else "let_down")
		text = play_dialogue(_db, state, "pell", [])
		assert_true(text.contains("SHE SAID YES") if yes else text.contains("You said I could come."), "Pell's reaction")
		play_dialogue(_db, state, "oda", ["I'm ready. Take me across."])
		assert_eq(state.get_flag("saltmarrow_ferry_passage"), true, "passage once Pell is settled")
		var lines := "\n".join(ActRecap.lines(ActRecap.acts(_db)[0], state))
		assert_true(lines.contains("Pell is crossing with you") if yes else lines.contains("took it back"))


func test_pell_asks_on_the_dock_and_a_refusal_earns_the_pouch() -> void:
	for ask: String in ["", "undecided"]:
		var state := _arrived()
		state.set_flag("saltmarrow_pell_ferry_ask", ask)
		var text := play_dialogue(_db, state, "pell", ["No, Pell. You stay."])
		assert_true(text.contains("LOUD") if ask == "undecided" else text.contains("A real ferry"), "Pell asks (%s)" % ask)
		assert_eq(state.get_flag("saltmarrow_pell_ferry_ask"), "refused")
		assert_eq(state.get_flag("saltmarrow_pell_crossing"), "stayed")
		assert_eq(state.item_count("pells_pouch"), 1, "the finding pouch")
		text = play_dialogue(_db, state, "pell", [])
		assert_true(text.contains("Not a sock"), "Pell reminds you")
		assert_eq(state.item_count("pells_pouch"), 1, "one pouch only")
	var refused := _arrived()
	refused.set_flag("saltmarrow_pell_ferry_ask", "refused")
	play_dialogue(_db, refused, "pell", [])
	assert_eq(refused.item_count("pells_pouch"), 1, "a refusal at the lantern also earns the pouch")
	var yes := _arrived()
	play_dialogue(_db, yes, "pell", ["Yes. Come with me."])
	assert_eq(yes.get_flag("saltmarrow_pell_ferry_ask"), "promised")
	assert_eq(yes.get_flag("saltmarrow_pell_crossing"), "", "still needs Mara's leave")


func test_mara_says_goodbye_once_and_may_send_word_to_dunstan() -> void:
	var state := _arrived("knot")
	state.set_flag("saltmarrow_mara_knows_dunstan_chose", true)
	var text := play_dialogue(_db, state, "mara", ["The ferry's in."])
	assert_true(text.contains("the stool's still by the door"), "message for Dunstan")
	assert_eq(state.get_flag("saltmarrow_mara_message_for_dunstan"), true)
	assert_true(text.contains("Let them. The nets still hold."), "knot farewell")
	var offered: Array[String] = []
	play_dialogue(_db, state, "mara", [], offered)
	assert_false(offered.has("The ferry's in."), "farewell once")
	var gull := _arrived("gull")
	gull.set_flag("saltmarrow_mara_knows_dunstan_chose", true)
	text = play_dialogue(_db, gull, "mara", ["The ferry's in."])
	assert_true(text.contains("one of those is for a traveller"), "the cold cup")
	assert_false(text.contains("Tollen shoulders"), "no message for a brother she no longer remembers")


func test_aldous_and_tam_see_the_ferry_in() -> void:
	var state := _arrived()
	assert_true(play_dialogue(_db, state, "aldous", ["The ferry's come."]).contains("I'm not coming"))
	assert_true(play_dialogue(_db, state, "tam", ["The ferry's in."]).contains("Oda Farrow"))


func test_validator_checks_events_and_multi_placement() -> void:
	var db := load_content()
	var region: Dictionary = db.regions["shingle_point"]
	region["events"] = [
		{"id": "no_set", "if": "flag:intro_seen", "dialogue": "ferry_horn"},
		{"id": "never_off", "if": "flag:intro_seen", "set": {"saltmarrow_ferry_arrived": true}, "dialogue": "ferry_horn"},
		{"id": "bad_dialogue", "if": "!flag:saltmarrow_ferry_arrived", "set": {"saltmarrow_ferry_arrived": true}, "dialogue": "nope"},
	]
	(region["npcs"] as Array).append({"npc": "mara", "position": [0, 0, 0]})
	var v := ContentValidator.new(db)
	assert_false(v.validate())
	var report := v.report()
	assert_true(report.contains("event 'no_set' needs a 'set'"), "event without set")
	assert_true(report.contains("event 'never_off' must read one of its 'set' flags"), "event that never switches off")
	assert_true(report.contains("unknown dialogue 'nope'"), "event dialogue checked")
	assert_true(report.contains("npc 'mara' is placed more than once"), "unconditional second placement")
	assert_false(report.contains("npc 'pell' is placed more than once"), "Pell's two conditional placements are fine")
