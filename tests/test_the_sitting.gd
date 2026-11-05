extends TestCase
## Day 86 — the chapter sits at the Spire's foot (Act III step 4's close). The Provost says when (dusk); the chapter's
## NPCs leave the Boat Stair for a ring of candles before the warden's niche; on reaching the crown the sitting plays:
## the roll read (if she was told of it), the Long Book with no line for the Spire, the woman on the ring path seen by
## the Wakebearer alone, what the Wakebearer says, and the stair under Aldous's seat. Then night, and "tomorrow".

const STAIR := "cindermoor_boat_stair"
const FOOT := "cindermoor_spire_foot"
const UP := "cindermoor_chapter_up"
const SAT := "cindermoor_chapter_sat"
const ASK_WHEN := "When does the chapter go up?"

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


func _at(scenario: String) -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve(scenario))
	return state


func _region(id: String) -> Dictionary:
	return _content().regions[id]


func _placed(region_id: String, npc: String) -> Array:
	return (_region(region_id)["npcs"] as Array).filter(func(n: Dictionary) -> bool: return str(n["npc"]) == npc)


func _shown(region_id: String, npc: String, state: WorldState) -> bool:
	return _placed(region_id, npc).any(func(n: Dictionary) -> bool: return Conditions.evaluate(n.get("if", []), state))


## The Boat Stair after the claim, the weighing, the roll told and the road asked after: ready to ask when.
func _claimed() -> WorldState:
	var state := _at("the_chapter")
	_lines(state, "provost", ["The chapter can sit. I'll hear what it says.", "Let her hold the Stair-Taper and the Hood-Pin.",
			"Put the Stair-Taper and the Hood-Pin in her hands.", "Tell her about the novices' roll.", "Scraped. Down to the skin, with a blade.",
			"Who kept the roll?", "The road up forgets where it goes. You'll want the cressets.", "Leave her to the quay."])
	assert_true(bool(state.get_flag("cindermoor_provost_heard_roll")) and str(state.get_flag("cindermoor_chapter_weigh")) == "shown")
	return state


## Asks the Provost when, and returns what was said.
func _go_up(state: WorldState) -> String:
	return _lines(state, "provost", [ASK_WHEN])


## Fires the crown's arrival (the sitting) with the given pick, and returns what it said.
func _sit(state: WorldState, pick: String = "The Spire must have kept its own book.") -> String:
	var event := RegionEvents.arrival(_region(FOOT), state)
	assert_eq(str(event.get("id", "")), "cindermoor_sitting")
	return _lines(state, RegionEvents.fire(event, state), [pick])


func test_she_says_when_only_after_the_road() -> void:
	var state := _at("the_chapter")
	var offered: Array[String] = []
	_lines(state, "provost", ["The chapter can sit. I'll hear what it says.", "Leave her to the quay."], offered)
	assert_false(offered.has(ASK_WHEN), "not before the road's been asked after")
	state = _claimed()
	var told := _go_up(state)
	assert_true(told.contains("At dusk.") and told.contains("only a meeting") and told.contains("It's the coming down I count."), told)
	assert_true(bool(state.get_flag(UP)))
	assert_eq(state.quest_stage("the_chapter"), "the_sitting")
	offered.clear()
	_lines(state, "provost", [], offered)
	assert_false(offered.has(ASK_WHEN), "said once")
	state = _at("the_chapter")
	state.set_flag("cindermoor_chapter_road", true)
	state.set_flag("cindermoor_chapter_claim", "refused")
	assert_true(_go_up(state).contains("the hand it's writing down"))


func test_the_chapter_leaves_the_quay_for_the_crown() -> void:
	var state := _claimed()
	state.set_flag("lowsong_iver_home", true)
	state.set_flag("lowsong_beacon_burned", "lamp")
	state.set_flag("thornwold_skiff", "kindleby")
	state.set_flag("thornwold_far_shore", "")
	for npc: String in ["provost", "hild", "iver", "wenna_coll"]:
		assert_true(_shown(STAIR, npc, state) and not _shown(FOOT, npc, state), npc + " on the quay")
	var told := _go_up(state)
	assert_true(told.contains("Wenna Coll goes after the Keepers") and told.contains("Iver goes last"), told)
	for npc: String in ["provost", "hild", "iver", "wenna_coll"]:
		assert_true(_shown(FOOT, npc, state) and not _shown(STAIR, npc, state), npc + " at the Spire's foot")
	assert_true(_shown(STAIR, "merrit", state), "Merrit stays on his bollard")
	assert_true(_lines(state, "merrit", ["Leave him to his rope."]).contains("Nobody in her. They've all gone up."))
	var ring: Array = (_region(FOOT)["props"] as Array).filter(func(p: Dictionary) -> bool: return str(p.get("model", "")).ends_with("chapter_ring.glb"))
	assert_eq(ring.size(), 1)
	assert_true(Conditions.evaluate(ring[0]["if"], state), "the candles are up")


func test_the_light_goes_to_dusk_then_night() -> void:
	var state := _claimed()
	var morning := RegionMood.light(_region(FOOT), state)
	_go_up(state)
	var dusk := RegionMood.light(_region(FOOT), state)
	assert_true(dusk["sun_energy"] < morning["sun_energy"] and dusk["sun_yaw"] < 0.0, "dusk, the sun in the west")
	for id: String in [STAIR, "cindermoor_long_steps", FOOT]:
		assert_eq(RegionMood.light(_region(id), state)["sun_energy"], dusk["sun_energy"], id + " at dusk too")
	_sit(state)
	var night := RegionMood.light(_region(FOOT), state)
	assert_true(night["sun_energy"] < dusk["sun_energy"] and night["ambient_energy"] < dusk["ambient_energy"], "night")
	assert_true(RegionMood.fog(_region(STAIR), state)["color"] != RegionMood.fog(_region(STAIR), _at("the_chapter"))["color"], "the fog darkens with it")


func test_the_sitting() -> void:
	var state := _claimed()
	assert_true(RegionEvents.arrival(_region(FOOT), state).is_empty(), "no sitting before the chapter goes up")
	_go_up(state)
	var told := _sit(state)
	assert_true(told.contains("which up here means standing") and told.contains("The chapter sits for the Hearthspire."), told)
	assert_true(told.contains("By the hand that said it would hear us."), told)
	assert_true(told.contains("There's always a line.") and told.contains("Not for the Spire."), told)
	assert_true(told.contains("I never asked."), "Kindleby's 'I never asked them', paid on the crown: " + told)
	assert_true(told.contains("a line that isn't there"), "the weighing remembered: " + told)
	assert_true(told.contains("the oldest thing in the order") and told.contains("like the lid of a box"), told)
	assert_true(told.contains("smells of nothing") and told.contains("twelve steps"), told)
	assert_true(told.contains("Nobody goes down before."), told)
	assert_true(bool(state.get_flag(SAT)))
	assert_eq(str(state.get_flag("cindermoor_sitting_spoke")), "asked")
	assert_eq(state.quest_stage("the_chapter"), "the_lower_rooms")
	assert_true(RegionEvents.arrival(_region(FOOT), state).is_empty(), "once")
	assert_false(told.contains("Oriel") or told.contains("High Keeper"), "never named yet")


func test_who_reads_the_long_book() -> void:
	var state := _claimed()
	state.set_flag("lowsong_iver_home", false)
	_go_up(state)
	var told := _sit(state)
	assert_true(told.contains("Hild turns the pages a long time") and not told.contains("Nine hundred years, Lorn."), told)
	state = _claimed()
	state.set_flag("lowsong_iver_home", true)
	state.set_flag("lowsong_beacon_burned", "lamp")
	_go_up(state)
	told = _sit(state)
	assert_true(told.contains("argued about every comma") and told.contains("Nine hundred years, Lorn."), told)


func test_the_roll_read_for_herself() -> void:
	var state := _claimed()
	_go_up(state)
	var told := _sit(state)
	assert_true(told.contains("puts her thumb on the scraped place") and told.contains("says nothing aloud at all"), told)
	assert_eq(state.quest_stage("the_seventh_name"), "she_read_it")
	assert_true(_lines(state, "provost").contains("I've seen it now."))
	state = _claimed()
	state.set_flag("cindermoor_provost_heard_roll", false)
	state.set_quest_stage("the_seventh_name", "scraped")
	_go_up(state)
	told = _sit(state)
	assert_true(told.contains("and doesn't go in") and not told.contains("scraped place"), told)
	assert_eq(state.quest_stage("the_seventh_name"), "scraped")


func test_what_the_hand_says() -> void:
	var picks := {
		"Weigh the ember, then. It's all I came with.": ["offered", "Not till we know what it's fed on."],
		"The Spire must have kept its own book.": ["asked", "...It did. It must have."],
		"Say nothing. You're the hand.": ["silent", "Thank you."],
	}
	for pick: String in picks:
		var state := _claimed()
		_go_up(state)
		var told := _sit(state, pick)
		assert_eq(str(state.get_flag("cindermoor_sitting_spoke")), picks[pick][0])
		assert_true(told.contains(picks[pick][1]) and told.contains("like the lid of a box"), told)


func test_the_woman_on_the_ring_path() -> void:
	for seen: bool in [false, true]:
		var state := _claimed()
		state.set_flag("cindermoor_ring_seen", seen)
		_go_up(state)
		var told := _sit(state)
		assert_true(told.contains("grey to the shoulders") and told.contains("Nobody in the ring saw her."), told)
		assert_eq(told.contains("One pair of feet. Round and round."), seen, told)
		assert_false(told.contains("Ness"), "not Ness: the one higher up")


func test_after_the_sitting() -> void:
	var state := _at("the_sitting")
	assert_eq(str(Scenarios.resolve("the_sitting")["region"]), FOOT)
	assert_true(RegionEvents.arrival(_region(FOOT), state).is_empty(), "the checkpoint is past the sitting")
	var niche := _lines(state, "cindermoor_niche", ["Look down the stair under the seat.", "Leave the niche as it is."])
	assert_true(niche.contains("stands up on its pin") and niche.contains("nobody before"), niche)
	var offered: Array[String] = []
	_lines(state, "cindermoor_niche", ["Leave the niche as it is."], offered)
	assert_false(offered.has("Sit in the warden's seat."), "the seat's up")
	var props: Array = _region(FOOT)["props"]
	var foot: Array = props.filter(func(p: Dictionary) -> bool: return str(p.get("model", "")).get_file().begins_with("spire_foot"))
	assert_eq(foot.size(), 2)
	assert_eq(foot.filter(func(p: Dictionary) -> bool: return Conditions.evaluate(p["if"], state)).map(func(p: Dictionary) -> String: return str(p["model"]).get_file()), ["spire_foot_open.glb"])
	assert_true(_lines(state, "provost").contains("I can wait a night."))
	assert_true(_lines(state, "hild").contains("smells of fire but that"))
	state.set_flag("lowsong_iver_home", true)
	state.set_flag("thornwold_skiff", "kindleby")
	assert_true(_lines(state, "iver").contains("You read what's written."))
	assert_true(_lines(state, "wenna_coll").contains("I kept fourteen back."))
	var v := ContentValidator.new(load_content())
	assert_true(v.validate(), "\n".join(v.errors))
