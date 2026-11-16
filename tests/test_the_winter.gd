extends TestCase
## Day 107 — the winter's first days. After the final card (`epilogue_tied_up`): Oda's first word, once, per winter
## (crew / stay / walk); the stay port's folk notice the Wakebearer wintering with them, once (`epilogue_winter_port`,
## recorded at the tie-up); crew and walk get a line from each port's folk; and the Slow Mercy lies dark at her warps
## (`ferry_tied.glb`, no masthead light) wherever she is.

const TIE := "That's the ring. Tie her up for the winter."
const STAY := "Stay here."
const CREW := "Crew the Mercy, if you'll have me."
const WALK := "Walk the islands. Nobody's counting now."
const BYE := "Not yet."
const PORT_FOLK := {
	"saltmarrow": "mara", "thornwold": "bram", "fen": "hesper", "wrackholm": "wenna", "kindleby": "tobin",
}
const PORT_REGION := {
	"saltmarrow": "saltmarrow", "thornwold": "thornwold_landing", "fen": "glasswater_fen", "wrackholm": "wrackholm",
	"kindleby": "kindleby", "cindermoor": "cindermoor_boat_stair",
}
## One phrase from each port's welcome, then one per ending.
const WELCOME := {
	"mara": "loft over the net store", "bram": "a little ring cut with the point of a knife",
	"hesper": "Nobody winters on the fen", "wenna": "a bunk nobody's used since the Gannet went",
	"tobin": "moved my candles off the spare cot",
}
const WELCOME_ENDING := {
	"mara": {"lit": "from the pillow", "released": "up the Gull with him", "dark": "you're not on the list"},
	"bram": {"lit": "saying goodnight to the gold", "released": "the second cup up the ladder", "dark": "stand at the ladder's foot"},
	"hesper": {"lit": "you can see the gold", "released": "top step is warm", "dark": "read its list out"},
	"wenna": {"lit": "Nothing to listen for", "released": "something sits with the Wrack", "dark": "hold the lamp for me"},
	"tobin": {"lit": "practising what I'd say", "released": "two of us changing them", "dark": "carries it up the wall"},
}

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _talk(state: WorldState, who: String, picks: Array = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, who, typed)


## Every homecoming seen (the Day 103 checkpoint), re-coloured by `ending`, the Mercy at `port`, not yet tied up.
func _before(ending := "lit", port := "kindleby") -> WorldState:
	var state := fresh_state(_content())
	Scenarios.apply(_content(), state, Scenarios.resolve("the_quiet_water"))
	state.set_flag("cindermoor_cradle_choice", ending)
	state.set_flag("lanes_ferry_at", port)
	return state


func _tied(winter: String, ending := "lit", port := "kindleby") -> WorldState:
	var state := _before(ending, port)
	_talk(state, "oda", [TIE, {"stay": STAY, "crew": CREW, "walk": WALK}[winter]])
	assert_true(bool(state.get_flag("epilogue_tied_up")), "tied up at " + port)
	return state


func test_the_stay_port_is_recorded_at_the_tie_up() -> void:
	for port: String in PORT_FOLK:
		var state := _tied("stay", "lit", port)
		assert_eq(state.get_flag("epilogue_winter_port"), port)
		state.set_flag("lanes_ferry_at", "cindermoor")
		assert_eq(state.get_flag("epilogue_winter_port"), port, "ferrying after doesn't move it")
	var saltmarrow := _before("lit", "")
	_talk(saltmarrow, "oda", [TIE, STAY])
	assert_eq(saltmarrow.get_flag("epilogue_winter_port"), "saltmarrow", "the unsailed default is Saltmarrow")
	for winter: String in ["crew", "walk"]:
		assert_eq(_tied(winter).get_flag("epilogue_winter_port"), "", winter + " records no port")


func test_oda_s_first_word_once_per_winter() -> void:
	var expect := {
		"crew": "Crew's up before the gulls", "stay": "you'll sleep ashore", "walk": "I'll not count it",
	}
	for winter: String in expect:
		var state := _tied(winter)
		var said := _talk(state, "oda", [BYE])
		assert_true(said.contains(expect[winter]), winter + ": " + said)
		for other: String in expect:
			if other != winter:
				assert_false(said.contains(expect[other]), winter + " shows " + other)
		assert_true(bool(state.get_flag("epilogue_oda_winter_seen")))
		assert_false(_talk(state, "oda", [BYE]).contains(expect[winter]), winter + ": once")
	var not_yet := _before()
	assert_false(_talk(not_yet, "oda", [BYE]).contains("Crew's up before the gulls"), "nothing before the tie-up")
	assert_false(bool(not_yet.get_flag("epilogue_oda_winter_seen")))


func test_oda_still_ferries_after_her_first_word() -> void:
	var state := _tied("crew")
	var offered: Array[String] = []
	var picks: Array[String] = ["Sun-wise.", BYE]
	var said := play_dialogue(_content(), state, "oda", picks, offered)
	assert_true(said.contains("Somebody taught you right"), said)
	assert_true(offered.has("Where can you take me?"), "the port's hub follows on: %s" % [offered])


func test_crew_lines_per_ending() -> void:
	var expect := {"lit": "Gold, in the middle", "released": "I wasn't lonely", "dark": "a place for the coal-pan"}
	for ending: String in expect:
		var said := _talk(_tied("crew", ending), "oda", [BYE])
		assert_true(said.contains(expect[ending]), ending + ": " + said)
		for other: String in expect:
			if other != ending:
				assert_false(said.contains(expect[other]), ending + " shows " + other)


func test_the_stay_port_s_folk_notice_once() -> void:
	for port: String in PORT_FOLK:
		var state := _tied("stay", "lit", port)
		for other_port: String in PORT_FOLK:
			if other_port != port:
				var them: String = PORT_FOLK[other_port]
				assert_false(_talk(state, them).contains(WELCOME[them]), them + " doesn't welcome a " + port + " stay")
		var who: String = PORT_FOLK[port]
		var said := _talk(state, who)
		assert_true(said.contains(WELCOME[who]), who + ": " + said)
		assert_true(bool(state.get_flag("epilogue_winter_welcomed")))
		assert_false(_talk(state, who).contains(WELCOME[who]), who + ": once")


func test_the_welcome_per_ending() -> void:
	for port: String in PORT_FOLK:
		var who: String = PORT_FOLK[port]
		var lines: Dictionary = WELCOME_ENDING[who]
		for ending: String in lines:
			var said := _talk(_tied("stay", ending, port), who)
			assert_true(said.contains(lines[ending]), "%s %s: %s" % [who, ending, said])
			for other: String in lines:
				if other != ending:
					assert_false(said.contains(lines[other]), "%s %s shows %s" % [who, ending, other])


func test_the_welcome_answers() -> void:
	var state := _tied("stay", "lit", "saltmarrow")
	assert_true(_talk(state, "mara", ["Thank you, Mara."]).contains("That makes you somebody's"))
	var other := _tied("stay", "lit", "wrackholm")
	assert_true(_talk(other, "wenna", ["I'll take the bunk."]).contains("Mind the third board"))


func test_crew_and_walk_get_a_line_from_everyone() -> void:
	var crew := _tied("crew")
	var walk := _tied("walk")
	var before := _before()
	for who: String in PORT_FOLK.values():
		var crewed := _talk(crew, who)
		var walked := _talk(walk, who)
		assert_true(crewed != walked, who + " tells crew from walk")
		assert_false(crewed.contains(WELCOME[who]), who + ": no stay welcome for crew")
		assert_false(walked.contains(WELCOME[who]), who + ": no stay welcome for walk")
		var plain := _talk(before, who)
		assert_true(crewed.length() > plain.length() and walked.length() > plain.length(), who + " adds a line")
	assert_true(_talk(crew, "mara").contains("Oda's taken you on"))
	assert_true(_talk(walk, "tobin").contains("keep a candle in the quay window"))


func _ferries(region: String, state: WorldState) -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	for prop: Dictionary in _content().get_region(region).get("props", []):
		if str(prop.get("model", "")).get_file().begins_with("ferry") and Conditions.evaluate(prop.get("if"), state):
			shown.append(prop)
	return shown


func test_the_mercy_lies_dark_once_tied_up() -> void:
	for port: String in PORT_REGION:
		var region: String = PORT_REGION[port]
		var before := _before("lit", "kindleby")
		before.set_flag("lanes_ferry_at", port)
		var lit := _ferries(region, before)
		assert_eq(lit.size(), 1, port + ": one Mercy before")
		assert_eq(str(lit[0]["model"]).get_file(), "ferry.glb")
		assert_true(lit[0].has("light"), port + ": masthead lantern lit before")
		var after := _tied("crew")
		after.set_flag("lanes_ferry_at", port)
		var dark := _ferries(region, after)
		assert_eq(dark.size(), 1, port + ": one Mercy after")
		assert_eq(str(dark[0]["model"]).get_file(), "ferry_tied.glb")
		assert_false(dark[0].has("light"), port + ": the masthead lantern let go out")
		assert_eq(dark[0]["position"], lit[0]["position"], port + ": lies where she always did")
	assert_true(load("res://assets/models/dressing/ferry_tied.glb") != null, "the tied-up model loads")
