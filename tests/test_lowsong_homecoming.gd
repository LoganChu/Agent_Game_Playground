extends TestCase
## Day 103 — the epilogues, part six: Lowsong. Lowsong has no Mercy port, so after the ending Hild (who crossed home in
## the Mercy's stern) is back at the chapter's skiff on Kindleby and rows the Wakebearer out (arrival event
## `lowsong_homecoming`). Per ending (lit: quiet, gone in to the fire; released: quiet, only fog; dark: the singing
## further off) and per Lowsong's burning (key: Iver never left; lamp: the rock empty). Lit, Lowsong goes gold with the
## far Spire in the north. Hild and Iver have after-lines; Iver can be told the nearest voice's name.

const ENDINGS: Array[String] = ["lit", "released", "dark"]
const BYE := "Goodbye."
const ROW_OUT := "Row me out to Lowsong."
const ISOLDE := "Her name is Isolde Vane."

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed)


## After `ending`, the Mercy at Kindleby; `burned` is Lowsong's burning (key / lamp). Not yet rowed out.
func _home(ending: String, burned := "key") -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_wrack_answers"))
	state.set_flag("cindermoor_cradle_choice", ending)
	state.set_flag("kindleby_midwinter", "ring" if ending == "dark" else "")
	state.set_flag("lowsong_beacon_burned", burned)
	state.set_flag("lowsong_iver_home", burned == "lamp")
	state.set_flag("lanes_ferry_at", "kindleby")
	if ending == "lit":
		state.remove_item("hood_pin")
	return state


## The same, rowed out by Hild from Kindleby's shingle.
func _out(ending: String, burned := "key") -> WorldState:
	var state := _home(ending, burned)
	_lines(state, "hild", [ROW_OUT])
	return state


func _event(state: WorldState) -> Dictionary:
	return RegionEvents.arrival(_content().regions["lowsong"], state)


func _homecoming_next(state: WorldState) -> bool:
	return str(_event(state).get("id", "")) == "lowsong_homecoming"


func _placed(region: String, npc: String, state: WorldState) -> int:
	var n := 0
	for placed: Dictionary in _content().regions[region]["npcs"]:
		if str(placed["npc"]) == npc and Conditions.evaluate(placed.get("if"), state):
			n += 1
	return n


## The choices `dialogue` offers when greeted (then `leave`).
func _offered(state: WorldState, dialogue: String, leave := BYE) -> Array[String]:
	var offered: Array[String] = []
	var picks: Array[String] = [leave]
	play_dialogue(_content(), state, dialogue, picks, offered)
	return offered


func test_hild_crossed_home_and_rows_out() -> void:
	var state := _home("lit")
	assert_eq(_placed("kindleby", "hild", state), 1, "Hild at the chapter's skiff after the ending")
	for region: String in ["cindermoor_spire_foot", "cindermoor_boat_stair", "cindermoor_lower_rooms", "lowsong"]:
		assert_eq(_placed(region, "hild", state), 0, "not on %s too" % region)
	var said := _lines(state, "hild", [ROW_OUT])
	assert_true(said.contains("I came over in the Mercy's stern."), said)
	assert_true(bool(state.get_flag("lowsong_out")))
	assert_eq(_placed("kindleby", "hild", state), 0, "she's in the boat")
	assert_eq(_placed("lowsong", "hild", state), 1, "on Lowsong's landing")
	var before := fresh_state(_content())
	Scenarios.apply(_content(), before, Scenarios.resolve("the_spire_lit"))
	before.set_flag("lowsong_out", true)
	assert_false(_homecoming_next(before), "not before the lane out")


func test_the_homecoming_per_ending() -> void:
	var marks := {
		"lit": "They've gone in. To the fire.",
		"released": "The door's open. There's nobody in the room.",
		"dark": "out past the rocks to the north where the Spire stands dark",
	}
	for ending in ENDINGS:
		var state := _out(ending)
		var event := _event(state)
		assert_eq(str(event.get("id", "")), "lowsong_homecoming", ending)
		var said := _lines(state, RegionEvents.fire(event, state))
		assert_true(said.contains("Kindleby's candles go small astern"), ending)
		assert_true(said.contains(marks[ending]), "%s: %s" % [ending, said])
		for other in ENDINGS:
			if other != ending:
				assert_false(said.contains(marks[other]), "%s: not %s's" % [ending, other])
		assert_true(bool(state.get_flag("lowsong_homecoming_seen")), ending)
		assert_false(_homecoming_next(state), "%s: once" % ending)


func test_iver_never_left_or_the_rock_is_empty() -> void:
	var marks := {
		"lit": "I think she got to the end.",
		"released": "I sit on the other end now.",
		"dark": "I'll put my own name on it",
	}
	for ending in ENDINGS:
		var key := _out(ending, "key")
		assert_eq(_placed("lowsong", "iver", key), 1, "%s: Iver under the light (key)" % ending)
		var said := _lines(key, "lowsong_homecoming")
		assert_true(said.contains("Hild. I'll keep that."), "%s: he asks her name" % ending)
		assert_true(said.contains(marks[ending]), "%s: %s" % [ending, said])
		var lamp := _out(ending, "lamp")
		assert_eq(_placed("lowsong", "iver", lamp), 0, "%s: Iver went home (lamp)" % ending)
		said = _lines(lamp, "lowsong_homecoming")
		assert_true(said.contains("Nobody stands under the light."), "%s: %s" % [ending, said])
		assert_false(said.contains("Hild. I'll keep that."), ending)
	assert_true(_lines(_out("released", "lamp"), "lowsong_homecoming").contains("It isn't Iver."))
	assert_true(_lines(_out("dark", "lamp"), "lowsong_homecoming").contains("Hild Garrow, for Lowsong"))


func test_it_took_me_first_is_kept_for() -> void:
	var key := _out("lit", "key")
	var said := _lines(key, "lowsong_homecoming", ["It took me first."])
	assert_true(said.contains("Then I'll listen for it."), said)
	assert_true(bool(key.get_flag("lowsong_kept_for")))
	key.set_flag("lowsong_homecoming_seen", true)
	assert_true(_lines(key, "iver", [BYE]).contains("I'm listening for yours."))
	var lamp := _out("lit", "lamp")
	said = _lines(lamp, "lowsong_homecoming", ["It took me first."])
	assert_true(said.contains("I'll row you, then."), said)
	assert_true(bool(lamp.get_flag("lowsong_kept_for")))
	var not_said := _out("lit", "key")
	assert_true(_lines(not_said, "lowsong_homecoming", ["Nothing I can count."]).contains("You only know by the hole."))
	assert_false(bool(not_said.get_flag("lowsong_kept_for")))


func test_the_dark_round_puts_lowsong_fifth() -> void:
	for burned: String in ["key", "lamp"]:
		var said := _lines(_out("dark", burned), "lowsong_homecoming")
		assert_true(said.contains("That makes Lowsong fifth and Kindleby last."), burned)
		assert_true(said.contains("You don't take it out."), "%s: the hood-pin kept in" % burned)
	var first := _out("dark")
	first.set_flag("kindleby_midwinter", "first")
	assert_false(_lines(first, "lowsong_homecoming").contains("fifth"), "Kindleby asked first: no order told")


func test_iver_told_her_name() -> void:
	var marks := {"lit": "She got to the end, then.", "released": "to the step of a morning", "dark": "when she gets her word out"}
	for ending in ENDINGS:
		var state := _out(ending)
		state.set_flag("cindermoor_choir_line_read", true)
		assert_false(_offered(state, "iver").has(ISOLDE), "%s: not before the homecoming" % ending)
		state.set_flag("lowsong_homecoming_seen", true)
		assert_true(_offered(state, "iver").has(ISOLDE), ending)
		var said := _lines(state, "iver", [ISOLDE, BYE])
		assert_true(said.contains(marks[ending]), "%s: %s" % [ending, said])
		assert_true(bool(state.get_flag("lowsong_iver_told_isolde")))
		var offered := _offered(state, "iver")
		assert_false(offered.has(ISOLDE), "%s: once" % ending)
		assert_false(offered.has("Who is she, the one you listen for?"), "%s: he knows now" % ending)
	var unread := _out("lit")
	unread.set_flag("cindermoor_choir_line_read", false)
	unread.set_flag("lowsong_homecoming_seen", true)
	assert_false(_offered(unread, "iver").has(ISOLDE), "only once the Wakebearer's read it")


func test_after_lines() -> void:
	var hild := {"lit": "I keep looking north for the gold.", "released": "just to hear it quiet", "dark": "Iver's list'll want fetching"}
	var iver := {"lit": "That's when you hold it out.", "released": "I said good morning to it.", "dark": "The list's one name long."}
	for ending in ENDINGS:
		var state := _out(ending)
		RegionEvents.fire(_event(state), state)
		assert_true(_lines(state, "iver", [BYE]).contains(iver[ending]), "iver / %s" % ending)
		state.set_flag("lowsong_out", false)
		assert_true(_lines(state, "hild", ["Not yet."]).contains(hild[ending]), "hild / %s" % ending)
	var lamp := _out("dark", "lamp")
	RegionEvents.fire(_event(lamp), lamp)
	lamp.set_flag("lowsong_out", false)
	assert_true(_lines(lamp, "hild", ["Not yet."]).contains("I've written it. Hild Garrow, for Lowsong."))


func test_lowsong_goes_gold_when_lit() -> void:
	var region: Dictionary = _content().regions["lowsong"]
	for ending in ENDINGS:
		var state := _out(ending)
		var light := RegionMood.light(region, state)
		assert_true((str(light.get("sky_horizon", "")) == "#D9BE96") == (ending == "lit"), ending)
	var far: Array = (region["props"] as Array).filter(
			func(p: Dictionary) -> bool: return str(p.get("model", "")).ends_with("hearthspire_far_lit.glb"))
	assert_eq(far.size(), 1)
	assert_eq(str((far[0] as Dictionary)["if"]), "flag:cindermoor_cradle_choice=lit")
	var at: Array = (far[0] as Dictionary)["position"]
	assert_true(float(at[2]) < -100.0 and absf(float(at[0])) < 60.0, "north: Cindermoor on the chart")


func test_rowing_back() -> void:
	var state := _out("released")
	_lines(state, "lowsong_homecoming")
	var said := _lines(state, "hild", ["Take me back to Kindleby."])
	assert_true(said.contains("Eyes on the ember"), said)
	assert_false(bool(state.get_flag("lowsong_out")))
	assert_eq(_placed("kindleby", "hild", state), 1, "back on the shingle")


func test_the_checkpoint() -> void:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_quiet_water"))
	assert_eq(str(state.get_flag("cindermoor_cradle_choice")), "lit")
	assert_true(bool(state.get_flag("lowsong_out")))
	assert_false(_homecoming_next(state), "the homecoming's been seen")
	assert_eq(_placed("lowsong", "iver", state), 1)
	assert_eq(_placed("lowsong", "hild", state), 1)
	assert_true(_lines(state, "iver", [BYE]).contains("I'm listening for yours."))
