extends TestCase
## Day 43 — Wrackholm, part three: the Wrack's burning. What Wrackholm holds (Wenna's answer; the
## Gannet's crew board, the yard's to give; Hale's white-lead pot, Jory's day on the Teeth behind his
## brother — never into a Keeper's fire), weighed and burned in the cradle; the Wrack lit (the lit
## model, the fog leaning back, the light warming on the hard and the Teeth); then the answering horn
## unlashed and sounded (it takes two), the lane-house Book (the Lamp's page; the last line), and the
## friend-of-the-lanes swearing. The unburned Remnants go back to their owners.

const HOLM := "wrackholm"
const TEETH := "wrack_teeth"
const KIT := "res://assets/models/dressing/"
const NAMES := "The Gannet's crew: Hale Corbet, master. Annis Corbet. Ruan Pask."
const WRACK := "What would it take to light the Wrack?"
const ABOUT := "About the Teeth."
const WAIT := "Wait for the ebb."
const HOLD := "Hold the ember to the rock."
const FEED := "The Wrack wants something somebody here holds."
const GIVE := "Give me your answer, Wenna."
const NOT_ANSWER := "Not your answer."
const PRISE := "Prise the board off the transom."
const PUT_BACK := "Put the board back on the transom."
const ANSWER := "The Wrack's lit. Answer it."
const BOOK := "Show me the Book."
const SWEAR := "Swear me a friend of the lanes."
const SET := {"answer": "Set Wenna's answer in the cradle.", "board": "Set the Gannet's crew board in the cradle.",
		"white": "Set Hale's white-lead pot in the cradle."}
const BURN := {"answer": "Burn Wenna's answer.", "board": "Burn the Gannet's crew board.", "white": "Burn Hale's white-lead pot."}
const ITEM := {"answer": "wennas_answer", "board": "gannets_crew_board", "white": "white_lead_pot"}

var _db: ContentDatabase


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_db, state, dialogue, typed, offered)


func _offered(state: WorldState, dialogue: String) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [], offered)
	return offered


## Across the Teeth and up the Wrack (`feed_the_wrack`), back on the hard: the names said into the
## horn and Ruan's given to Jory unless `named` is false; Jory told `who`; the landing's events fired
## (so with `who` = wenna, Jory has gone up).
func _feeding(who: String = "dark", named: bool = true) -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "saltmarrow_ferry_arrived", "thornwold_landed", "fen_landed",
			"fen_dunstan_met", "wrackholm_landed", "wrackholm_met_wenna", "wrackholm_met_jory", "wrackholm_wenna_offer"]:
		state.set_flag(flag, true)
	state.set_flag("lanes_ferry_at", HOLM)
	state.start_quest("a_light_for_wrackholm", "the_lashed_horn")
	if named:
		state.set_flag("wrackholm_board_read", true)
		state.start_quest("the_gannets_crew", "say_the_names")
		_lines(state, "wenna", [NAMES])
		state.set_flag("wrackholm_jory_brother", true)
		state.set_flag("wrackholm_who_answered", who)
	_lines(state, "wenna", [WRACK])
	_lines(state, "wenna", [ABOUT])
	_lines(state, "teeth_spit", [WAIT, HOLD])
	RegionEvents.fire(RegionEvents.arrival(_db.get_region(TEETH), state), state)
	_lines(state, "wrack_light")
	_lines(state, "teeth_way_back", ["Go back across before the flood."])
	RegionEvents.fire(RegionEvents.arrival(_db.get_region(HOLM), state), state)
	assert_eq(state.quest_stage("a_light_for_wrackholm"), "feed_the_wrack")
	return state


## ...with all three Remnants in the satchel (Jory told `dark`, so he gives his own).
func _holding_all() -> WorldState:
	var state := _feeding()
	_lines(state, "wenna", [FEED, GIVE])
	_lines(state, "gannet_board", [PRISE])
	_lines(state, "jory", [FEED])
	for item: String in ITEM.values():
		assert_true((state.item_count(item) > 0), "holding %s" % item)
	return state


func _shown(region_id: String, model: String, state: WorldState) -> int:
	var n := 0
	for p: Dictionary in _db.get_region(region_id)["props"]:
		if str(p.get("model", "")) == KIT + model + ".glb" and Conditions.evaluate(p.get("if"), state):
			n += 1
	return n


func _deepest(region_id: String, state: WorldState) -> float:
	var deepest := 0.0
	for area: Dictionary in Greying.active_areas(_db.get_region(region_id), state):
		deepest = maxf(deepest, float(area.get("strength", 1.0)))
	return deepest


func test_what_wrackholm_holds() -> void:
	var state := _feeding()
	assert_false((state.item_count("wennas_answer") > 0))
	var cradle := _lines(state, "wrack_light")
	assert_true(cradle.contains("nothing of theirs to set in it") and cradle.contains("Wenna, by the horn"), "nothing to burn yet")
	assert_false(_offered(state, "wrack_light").has(SET["answer"]))
	# Wenna weighs her answer and gives it on purpose; then the yard's leave for the Gannet's board.
	var text := _lines(state, "wenna", [FEED, GIVE])
	assert_true(text.contains("Fifty years of boats came home on it") and text.contains("long, and two short"), "her answer, blown bare into the fog")
	assert_true(text.contains("it's the yard's to give, and I'm the yard"), "leave for the board")
	assert_true(text.contains("Jory's got something of his brother's"), "...and a word about Jory")
	assert_true((state.item_count("wennas_answer") > 0) and state.get_flag("wrackholm_board_leave") == true)
	var again := _lines(state, "wenna", [FEED])
	assert_false(again.contains("Fifty years of boats"), "her answer is given once")
	# Refused: she keeps it and still gives leave for the board.
	var kept := _feeding()
	_lines(kept, "wenna", [FEED, NOT_ANSWER])
	assert_false((kept.item_count("wennas_answer") > 0), "not your answer: she keeps it")
	assert_true(kept.get_flag("wrackholm_board_leave") == true)
	# Without the names said there's no board to give.
	var unnamed := _feeding("", false)
	_lines(unnamed, "wenna", [FEED, GIVE])
	assert_true((unnamed.item_count("wennas_answer") > 0))
	assert_false(unnamed.get_flag("wrackholm_board_leave") == true, "the board is blank to the yard until the names are said")
	assert_false(_offered(unnamed, "jory").has(FEED), "Jory, without his brother's name, has nothing of Ruan's")


func test_jory_gives_his_white_but_never_to_a_keepers_fire() -> void:
	var state := _feeding("dark")
	assert_true(_offered(state, "jory").has(FEED))
	var text := _lines(state, "jory", [FEED])
	assert_true(text.contains("Hale's white-lead pot") and text.contains("only mine"), "the pot, Ruan's")
	assert_true((state.item_count("white_lead_pot") > 0))
	assert_false(_offered(state, "jory").has(FEED), "given once")
	var told_keepers := _feeding("keepers")
	var refused := _lines(told_keepers, "jory", [FEED])
	assert_true(refused.contains("Not a thing of mine goes in a Keeper's fire"), "told the Keepers put it out, he refuses")
	assert_false((told_keepers.item_count("white_lead_pot") > 0))
	assert_true(_offered(told_keepers, "jory").has(FEED), "...every time")
	var unasked := _feeding("")
	_lines(unasked, "jory", [FEED])
	assert_true((unasked.item_count("white_lead_pot") > 0), "never told who: he gives")


func test_wenna_and_jory_decide_together() -> void:
	var state := _feeding("wenna")
	assert_true(state.get_flag("wrackholm_jory_up") == true, "he went up to her")
	assert_true(_lines(state, "jory", [FEED]).contains("we'll give it together"), "Jory at the horn sends you to Wenna")
	assert_false((state.item_count("white_lead_pot") > 0))
	var text := _lines(state, "wenna", [FEED])
	assert_true(text.contains("No. Not hers.") and text.contains("We'll each give"), "the two of them, together")
	assert_true((state.item_count("wennas_answer") > 0) and (state.item_count("white_lead_pot") > 0), "both given, for you to weigh")
	assert_false(_lines(state, "wenna", [FEED]).contains("Not hers"), "once")


func test_the_board_off_the_transom_and_back() -> void:
	var state := _feeding()
	assert_false(_offered(state, "gannet_board").has(PRISE), "not without the yard's leave")
	_lines(state, "wenna", [FEED, NOT_ANSWER])
	assert_eq(_shown(HOLM, "gannet_hulk_named", state), 1)
	assert_eq(_shown(HOLM, "gannet_hulk_bare", state), 0)
	assert_true(_lines(state, "gannet_board", [PRISE]).contains("lighter than it ought to be"))
	assert_true((state.item_count("gannets_crew_board") > 0) and state.get_flag("wrackholm_board_taken") == true)
	assert_eq(_shown(HOLM, "gannet_hulk_named", state), 0, "the board off...")
	assert_eq(_shown(HOLM, "gannet_hulk_bare", state), 1, "...a bare transom")
	assert_true(_lines(state, "jory").contains("Ruan's name you've got under your arm"), "Jory sees it go by")
	_lines(state, "gannet_board", [PUT_BACK])
	assert_false((state.item_count("gannets_crew_board") > 0))
	assert_false(state.get_flag("wrackholm_board_taken") == true)
	assert_eq(_shown(HOLM, "gannet_hulk_named", state), 1, "back on its nails (still named, Day 44)")
	assert_true(_offered(state, "gannet_board").has(PRISE), "and can come off again")


func test_each_burning() -> void:
	for burn: String in ["answer", "board", "white"]:
		var state := _holding_all()
		assert_eq(_shown(TEETH, "wrack_light", state), 1)
		assert_eq(_shown(TEETH, "wrack_light_lit", state), 0)
		var dark_fog := _deepest(TEETH, state)
		var weighed := _lines(state, "wrack_light", [SET[burn], "No. Not this."])
		assert_true(weighed.contains("Burn it, and"), "%s weighed" % burn)
		assert_true((state.item_count(ITEM[burn]) > 0), "%s: weighing and refusing keeps it" % burn)
		var text := _lines(state, "wrack_light", [SET[burn], BURN[burn]])
		assert_eq(state.get_flag("wrackholm_beacon_burned"), burn)
		assert_eq(state.quest_state("a_light_for_wrackholm"), WorldState.QUEST_DONE, "%s lights the Wrack" % burn)
		assert_true(text.contains("The Wrack Light catches") and text.contains("Not gone. Standing back."), "the kindling")
		assert_false((state.item_count(ITEM[burn]) > 0), "%s burned" % burn)
		for other: String in ITEM:
			if other != burn:
				assert_true((state.item_count(ITEM[other]) > 0), "%s: the %s still held" % [burn, other])
		assert_eq(text.contains("as if she'd set something down"), burn == "answer")
		assert_eq(text.contains("gets to the first, and stops"), burn == "board")
		assert_eq(text.contains("as if he's never seen it before"), burn == "white")
		# Lit, on the Teeth and seen from the hard: the lit model, a light, a halo; the fog leans back.
		for region_id: String in [TEETH, HOLM]:
			assert_eq(_shown(region_id, "wrack_light", state), 0, "%s: the dark Wrack gone" % region_id)
			assert_eq(_shown(region_id, "wrack_light_lit", state), 1, "%s: the lit Wrack" % region_id)
			var lit: Dictionary = (_db.get_region(region_id)["props"] as Array).filter(func(p: Dictionary) -> bool:
				return str(p.get("model", "")).ends_with("wrack_light_lit.glb"))[0]
			assert_true(lit.has("light") and lit.has("halo"), "%s: it lights the water" % region_id)
			assert_true(RegionMood.light(_db.get_region(region_id), state)["sun_energy"] > 0.7, "%s: the light warms" % region_id)
		assert_true(_deepest(TEETH, state) < dark_fog, "the Teeth's fog thins (%.2f < %.2f)" % [_deepest(TEETH, state), dark_fog])
		var room := _lines(state, "wrack_light")
		assert_true(room.contains("burns gold") and room.contains("for a heartbeat"), "the lit lantern room")
		# The island after.
		var wenna := _lines(state, "wenna")
		assert_eq(wenna.contains("I get to three, and no further"), burn == "board", "%s: Wenna's count" % burn)
		assert_eq(wenna.contains("So are they, now."), burn != "board", "%s: the names, unless burned" % burn)
		var jory := _lines(state, "jory")
		assert_eq(jory.contains("I had his name a while"), burn == "board", "%s: Jory's gap" % burn)
		assert_eq(jory.contains("I'll learn it off the marks"), burn == "white", "%s: Jory and the spring" % burn)
		var oda := _lines(state, "oda", ["Not yet."])
		assert_true(oda.contains("Four lit"), "Oda counts four")
		assert_eq(oda.contains("I'll keep that for her"), burn == "answer", "%s: an off-islander keeps it" % burn)
		assert_eq(oda.contains("every jetty I tie up at"), burn == "board")
		assert_eq(oda.contains("never looked up the whole way"), burn == "white")


func test_the_answer_burned_with_jory_up() -> void:
	var state := _feeding("wenna")
	_lines(state, "wenna", [FEED])
	_lines(state, "wrack_light", [SET["answer"], BURN["answer"]])
	assert_true(_lines(state, "jory").contains("I don't know what for"), "he stands by her and doesn't know why")
	assert_false(_lines(state, "jory").contains("I don't know what to say to her"))
	assert_true(_lines(state, "wenna").contains("I've not the heart to ask him what for"))


func test_the_horn_unlashed_and_sounded() -> void:
	for up: bool in [false, true]:
		var state := _feeding("wenna" if up else "dark")
		_lines(state, "wenna", [FEED, GIVE])
		if not up:
			_lines(state, "jory", [FEED])
		assert_false(_offered(state, "wenna").has(ANSWER), "not while the Wrack is dark")
		_lines(state, "wrack_light", [SET["white"], BURN["white"]])
		assert_true(_lines(state, "answering_horn").contains("waiting on Wenna"), "lashed, bell to the light")
		assert_eq(_shown(HOLM, "answering_horn", state), 1)
		assert_eq(_shown(HOLM, "answering_horn_open", state), 0)
		var text := _lines(state, "wenna", [ANSWER])
		assert_true(text.contains("cuts the tarred line") and text.contains("It takes two"), "unlashed")
		assert_eq(text.contains("Jory sets his shoulder under the bell"), up, "Jory takes the bell end if he came up")
		assert_eq(text.contains("Get your shoulder under the bell"), not up, "else you do")
		assert_true(text.contains("Her brass is still in your satchel"), "her answer, held unburned: bare lips")
		assert_true(text.contains("the Slow Mercy's horn answers"), "Oda answers from the jetty")
		assert_true(state.get_flag("wrackholm_horn_sounded") == true)
		assert_eq(_shown(HOLM, "answering_horn", state), 0)
		assert_eq(_shown(HOLM, "answering_horn_open", state), 1, "the open horn")
		assert_true(_lines(state, "answering_horn").contains("unlashed"))
		assert_false(_offered(state, "wenna").has(ANSWER), "once")
		# The unburned Remnant goes back to its owner.
		assert_true(_lines(state, "wenna", ["Give Wenna back her answer."]).contains("Fifty years. And one."))
		assert_false((state.item_count("wennas_answer") > 0))
	# The answer burned: she blows bare-lipped, and wants a mouthpiece made.
	var burned := _holding_all()
	_lines(burned, "wrack_light", [SET["answer"], BURN["answer"]])
	burned.set_flag("lanes_ferry_at", "fen")
	var text := _lines(burned, "wenna", [ANSWER])
	assert_true(text.contains("They tell me I answered boats") and text.contains("There's no brass on her cord"))
	assert_true(text.contains("I'll want a mouthpiece made"))
	assert_false(text.contains("Slow Mercy"), "no ferry at the jetty, no answer from it")
	# The others go back: the board on its nails, the pot to Jory.
	_lines(burned, "gannet_board", [PUT_BACK])
	assert_eq(_shown(HOLM, "gannet_hulk_named", burned), 1)
	assert_true(_lines(burned, "jory", ["Give Jory back Hale's pot."]).contains("Look at the white"))
	assert_false((burned.item_count("white_lead_pot") > 0))


func test_the_lane_house_book() -> void:
	for told: bool in [false, true]:
		var state := _holding_all()
		if told:
			state.set_flag("thornwold_lamp_name_lost", true)
			state.set_flag("wrackholm_book_told", true)
		_lines(state, "wrack_light", [SET["board"], BURN["board"]])
		assert_false(_offered(state, "wenna").has(BOOK), "not before the horn")
		_lines(state, "wenna", [ANSWER])
		var text := _lines(state, "wenna", [BOOK])
		assert_eq(text.contains("WYNN SALLOW, keeper, for the Ridge Light"), told, "the Lamp's page only if asked for")
		assert_eq(state.get_flag("wrackholm_lamp_name_read") == true, told)
		assert_eq(state.quest_state("paid_twice") == WorldState.QUEST_ACTIVE, told, "Paid Twice: carry it home")
		assert_true(text.contains("the night the Spire went dark") and text.contains("you've shut the Book"), "the last line")
		assert_true(state.get_flag("wrackholm_book_opened") == true)
		assert_false(_offered(state, "wenna").has(BOOK), "opened once")


func test_the_friend_of_the_lanes() -> void:
	for pick: String in ["Swear it.", "No. I'd rather owe nobody.", "Not yet."]:
		var state := _holding_all()
		_lines(state, "wrack_light", [SET["white"], BURN["white"]])
		assert_false(_offered(state, "wenna").has(SWEAR), "not before the horn")
		_lines(state, "wenna", [ANSWER])
		var text := _lines(state, "wenna", [SWEAR, pick])
		assert_true(text.contains("Weighed, and not found light"))
		var want: String = {"Swear it.": "sworn", "No. I'd rather owe nobody.": "declined", "Not yet.": ""}[pick]
		assert_eq(state.get_flag("wrackholm_sworn"), want)
		assert_eq(_offered(state, "wenna").has(SWEAR), want == "", "asked until answered")
		assert_eq(_lines(state, "oda", ["Not yet."]).contains("Did you cry?"), want == "sworn")
	# No offer weighed, nothing to swear.
	var unoffered := _holding_all()
	unoffered.set_flag("wrackholm_wenna_offer", false)
	_lines(unoffered, "wrack_light", [SET["white"], BURN["white"]])
	_lines(unoffered, "wenna", [ANSWER])
	assert_false(_offered(unoffered, "wenna").has(SWEAR))


func test_the_burning_kit() -> void:
	var names := func(model: String) -> Array[String]:
		var node := (load(KIT + model + ".glb") as PackedScene).instantiate() as Node3D
		var out: Array[String] = []
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			out.append(str(mi.name))
		node.free()
		return out
	var lit: Array[String] = names.call("wrack_light_lit")
	assert_true(lit.any(func(n: String) -> bool: return n.begins_with("kindle_glow")), "a fire behind the horn")
	assert_false((names.call("wrack_light") as Array[String]).any(func(n: String) -> bool: return n.contains("glow")), "the dark one stays dark")
	assert_true((names.call("answering_horn") as Array[String]).any(func(n: String) -> bool: return n.begins_with("bone")), "the bung in the lashed bell")
	assert_false((names.call("answering_horn_open") as Array[String]).any(func(n: String) -> bool: return n.begins_with("bone")), "no bung once sounded")
	assert_false((names.call("gannet_hulk_bare") as Array[String]).any(func(n: String) -> bool: return n.begins_with("silverfog")), "no board on the bare transom")
	for item: String in ITEM.values():
		assert_eq(str(_db_or_load().get_item(item).get("kind", "")), "remnant", "%s is a Remnant" % item)


func _db_or_load() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db
