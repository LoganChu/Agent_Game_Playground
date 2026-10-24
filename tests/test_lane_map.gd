extends TestCase
## The lane map (Day 59): data/lanes.json, Lanes (which ports, which lanes, which knot sails a
## voyage), Oda's "Where can you take me?" opening it, and the validator's lanes checks.

const MAP := "Where can you take me?"

var _db: ContentDatabase


## After the first crossing, at Thornwold; `lit` lights the Ridge Light (the fen lane opens).
func _crossed(lit: bool = false) -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	for flag: String in ["intro_seen", "saltmarrow_ferry_passage", "saltmarrow_ferry_arrived", "thornwold_landed"]:
		state.set_flag(flag, true)
	state.set_flag("saltmarrow_beacon_burned", "knot")
	state.set_flag("saltmarrow_ferry_deed", "shared")
	state.set_flag("lanes_ferry_at", "thornwold")
	state.complete_quest("across_the_grey")
	if lit:
		state.set_flag("thornwold_beacon_burned", "boots")
		state.complete_quest("a_light_for_thornwold")
	return state


## Every lane sailed once and every light lit, the ferry at `at`.
func _everywhere(at: String) -> WorldState:
	var state := _crossed(true)
	for flag: String in ["fen_landed", "fen_oda_lane_asked", "fen_dunstan_met", "wrackholm_landed", "wrackholm_oda_lane_asked", "kindleby_landed"]:
		state.set_flag(flag, true)
	state.set_flag("fen_beacon_burned", "channels")
	state.set_flag("wrackholm_beacon_burned", "board")
	state.complete_quest("a_light_for_wrackholm")
	state.set_flag("lanes_ferry_at", at)
	return state


## Runs Oda's dialogue to its end (picks as TestCase.play_dialogue; "@port" on the map) and
## returns where it would move the player.
func _travel(state: WorldState, picks: Array[String]) -> Array:
	var runner := DialogueRunner.new(_db, state)
	var ev := runner.start("oda")
	var guard := 0
	while ev["type"] != "end" and guard < 200:
		guard += 1
		match ev["type"]:
			"line":
				ev = runner.next()
			"lane_map":
				var pick: String = picks.pop_front() if not picks.is_empty() else ""
				ev = runner.sail_to(pick.substr(1) if pick.begins_with("@") else "")
			_:
				var texts: Array = (ev["options"] as Array).map(func(o: Dictionary) -> String: return str(o["text"]))
				var want: String = picks.pop_front() if not picks.is_empty() else ""
				var index := texts.find(want)
				ev = runner.choose(index if index >= 0 else texts.size() - 1)
	return runner.pending_travel


func test_the_ferry_lies_at_home_before_the_first_crossing() -> void:
	_db = load_content()
	var state := fresh_state(_db)
	assert_eq(Lanes.current_port(_db, state), "saltmarrow", "'' is the Saltmarrow dock")
	state.set_flag("lanes_ferry_at", "fen")
	assert_eq(Lanes.current_port(_db, state), "fen")


func test_the_chart_grows_as_oda_tells_of_lanes() -> void:
	var state := _crossed()
	assert_eq(Lanes.known_ports(_db, state), ["saltmarrow", "thornwold"] as Array[String], "two islands after the crossing")
	assert_eq(Lanes.known_lanes(_db, state).size(), 1)
	state = _crossed(true)
	assert_eq(Lanes.known_ports(_db, state), ["saltmarrow", "thornwold", "fen"] as Array[String], "the Ridge Light lit: Oda tells of the fen")
	state.set_flag("fen_oda_lane_asked", true)
	assert_true(Lanes.known_ports(_db, state).has("wrackholm"), "asked where the lane runs: Wrackholm")
	assert_true(Lanes.port_lit(_db, state, "thornwold") and not Lanes.port_lit(_db, state, "fen"), "lit and dark lights")


func test_the_map_replaces_the_sailing_options_after_the_first_crossing() -> void:
	_db = load_content()
	var before := fresh_state(_db)
	before.set_flag("saltmarrow_ferry_passage", true)
	before.set_flag("saltmarrow_ferry_deed", "shared")
	before.start_quest("across_the_grey", "take_passage")
	var offered: Array[String] = []
	play_dialogue(_db, before, "oda", [], offered)
	assert_true(offered.has("Cast off for Thornwold.") and not offered.has(MAP), "the first crossing is still Act I's ending, not the map")
	var home := _crossed()
	home.set_flag("lanes_ferry_at", "saltmarrow")
	offered.clear()
	play_dialogue(_db, home, "oda", [], offered)
	assert_true(offered.has(MAP) and not offered.has("Cast off for Thornwold."), "home again: the map")
	for at: String in ["thornwold", "fen", "wrackholm"]:
		offered.clear()
		play_dialogue(_db, _everywhere(at), "oda", [], offered)
		assert_true(offered.has(MAP), "Oda opens the map at %s" % at)
		assert_false(offered.any(func(t: String) -> bool: return t.begins_with("Take me back") or t.begins_with("Sail ")),
				"no per-lane sailing options left at %s" % at)


func test_turning_back_from_the_map_offers_odas_options_again() -> void:
	var state := _crossed()
	var runner := DialogueRunner.new(_db, state)
	var ev := runner.start("oda")
	while ev["type"] == "line":
		ev = runner.next()
	var texts: Array = (ev["options"] as Array).map(func(o: Dictionary) -> String: return str(o["text"]))
	ev = runner.choose(texts.find(MAP))
	assert_eq(ev["type"], "lane_map", "the option opens the map")
	assert_eq(runner.next()["type"], "lane_map", "and waits on it")
	ev = runner.sail_to("")
	assert_eq(ev["type"], "choices", "turning back offers the options again")
	assert_eq((ev["options"] as Array).size(), texts.size())
	ev = runner.choose(texts.find(MAP))
	ev = runner.sail_to("fen")
	assert_eq(ev["type"], "choices", "a voyage the ferry won't make (the fen lane's dark) comes back too")
	assert_eq(state.get_flag("lanes_ferry_at"), "thornwold", "and nothing moved")


func test_neighbouring_voyages_play_the_lane_knots() -> void:
	var state := _crossed(true)
	assert_eq(Lanes.voyage(_db, state, "fen")["knot"], "sail_fen")
	assert_eq(Lanes.voyage(_db, state, "saltmarrow")["knot"], "back")
	assert_false(Lanes.voyage(_db, state, "thornwold")["ok"], "not to where she lies")
	assert_eq(_travel(state, [MAP, "@fen"]), ["glasswater_fen", "from_ferry"])
	assert_eq(state.get_flag("lanes_ferry_at"), "fen")


func test_longer_voyages_go_light_to_light_over_sailed_lanes() -> void:
	var state := _everywhere("saltmarrow")
	var voyage := Lanes.voyage(_db, state, "wrackholm")
	assert_true(voyage["ok"])
	assert_eq(voyage["route"], ["saltmarrow", "thornwold", "fen", "wrackholm"] as Array[String])
	assert_eq(voyage["knot"], "passage_wrackholm")
	var text := play_dialogue(_db, state, "oda", [MAP, "@wrackholm"])
	assert_true(text.contains("light to light") and text.contains("Teeth"), "the long passage, told short")
	assert_eq(state.get_flag("lanes_ferry_at"), "wrackholm")
	for pair: Array in [["wrackholm", "saltmarrow"], ["wrackholm", "thornwold"], ["saltmarrow", "fen"], ["fen", "saltmarrow"], ["thornwold", "wrackholm"],
			["kindleby", "saltmarrow"], ["kindleby", "thornwold"], ["kindleby", "fen"], ["saltmarrow", "kindleby"], ["thornwold", "kindleby"], ["fen", "kindleby"]]:
		var s := _everywhere(pair[0])
		var to: String = pair[1]
		var region := str(Lanes.port(_db, to).get("region", ""))
		assert_eq(_travel(s, [MAP, "@" + to]), [region, "from_ferry"], "%s to %s" % pair)
		assert_eq(s.get_flag("lanes_ferry_at"), to, "%s to %s" % pair)
	# A lane never sailed is sailed from its near end first, with its arrival story.
	var new_lane := _everywhere("saltmarrow")
	new_lane.set_flag("wrackholm_landed", false)
	var refused := Lanes.voyage(_db, new_lane, "wrackholm")
	assert_false(refused["ok"])
	assert_true(str(refused["reason"]).contains("Go by Glasswater Fen first"), str(refused["reason"]))


func test_every_long_passage_says_where_it_came_from() -> void:
	# Each passage knot has a line for every port it can start from (a route of 3+ ports).
	_db = load_content()
	for to in ["saltmarrow", "thornwold", "fen", "wrackholm", "kindleby"]:
		for from in ["saltmarrow", "thornwold", "fen", "wrackholm", "kindleby"]:
			var state := _everywhere(from)
			var voyage := Lanes.voyage(_db, state, to)
			if not voyage.get("ok", false) or (voyage["route"] as Array).size() < 3:
				continue
			var text := play_dialogue(_db, state, "oda", [MAP, "@" + to])
			for via: String in (voyage["route"] as Array).slice(1, (voyage["route"] as Array).size() - 1):
				var light := str(Lanes.port(_db, via).get("light", "")).trim_prefix("the ").get_slice(" ", 0)
				assert_true(text.contains(light), "%s to %s names %s's light (%s)" % [from, to, via, light])


func test_the_validator_checks_the_lanes() -> void:
	var db := load_content()
	var v := ContentValidator.new(db)
	v._validate_lanes()
	assert_empty(v.errors, "the real lanes are clean")
	(db.lanes["lanes"][1]["knots"] as Dictionary)["fen"] = "back"
	db.lanes["ports"][0]["map"] = [1.4, 0.2]
	db.lanes["ports"].append({"id": "cindermoor", "name": "Cindermoor", "light": "the Hearthspire", "region": "nowhere", "passage": "nope", "map": [0.5, 0.5]})
	v = ContentValidator.new(db)
	v._validate_lanes()
	var report := "\n".join(v.errors)
	assert_true(report.contains("knot 'back' must set lanes_ferry_at=fen and travel to glasswater_fen"), report)
	assert_true(report.contains("'map' must be [x, y] within 0..1"), report)
	assert_true(report.contains("port id must be a value of lanes_ferry_at"), report)
	assert_true(report.contains("unknown region 'nowhere'"), report)
	assert_true(report.contains("knot 'nope' is not in the lanes dialogue"), report)
	# A lane_map option outside the ferry's dialogue.
	db = load_content()
	var knot: Array = db.dialogues["bram"]["knots"]["start"]
	knot.push_front({"choice": [{"text": "Map?", "lane_map": true}]})
	v = ContentValidator.new(db)
	v._validate_dialogue("bram", db.dialogues["bram"])
	assert_true("\n".join(v.errors).contains("a lane_map option only works in the lanes dialogue 'oda'"), "\n".join(v.errors))
