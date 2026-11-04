extends TestCase
## Day 83 — the doused cresset and the Spire's foot (Act III steps 2-3). Past the Unmoored the cresset they put out
## can be dug out and relit over their wish (they go off into the fog; Merrit counts seven lit), or Ness walks the
## Wakebearer up in the dark by her rake, the ember covered. Either way the road ends at the Hearthspire's foot: the
## east stair door ajar on the dark, the warden's niche with Aldous's tapers and knife, and the novices' roll with
## the seventh name scraped out.

const STEPS := "cindermoor_long_steps"
const FOOT := "cindermoor_spire_foot"
const GONE := "flag:cindermoor_cresset_steps_5"

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


## At the top of the long steps, Ness met with the ember as given, the doused cresset looked at.
func _at_the_doused(ember: String) -> WorldState:
	var state := _at("the_unmoored")
	var pick := "Close your hand over the ember." if ember == "cupped" else "Let it burn."
	_lines(state, "ness", [pick, "Leave her to the fog."])
	_lines(state, "cindermoor_doused")
	return state


func _region(id: String) -> Dictionary:
	return _content().regions[id]


func _object(region_id: String, id: String) -> Dictionary:
	for o: Dictionary in _region(region_id)["objects"]:
		if str(o["id"]) == id:
			return o
	return {}


func _travel_after(state: WorldState, dialogue: String, picks: Array) -> Array:
	var runner := DialogueRunner.new(_content(), state)
	var ev := runner.start(dialogue)
	while ev["type"] != "end":
		if ev["type"] == "line":
			ev = runner.next()
			continue
		var texts: Array[String] = []
		for option: Dictionary in ev["options"]:
			texts.append(str(option["text"]))
		var want: String = picks.pop_front() if not picks.is_empty() else ""
		var pick := texts.find(want)
		ev = runner.choose(pick if pick >= 0 else texts.size() - 1)
	return runner.pending_travel


func test_the_doused_cresset_can_be_dug_out_once_seen() -> void:
	var state := _at("the_unmoored")
	var dig := _object(STEPS, "cresset_steps_5")
	assert_eq(str(dig.get("prompt", "")), "Dig out the doused cresset")
	assert_false(Conditions.evaluate(dig["if"], state), "not before it's been looked at")
	assert_true(Conditions.evaluate(_object(STEPS, "steps_doused")["if"], state), "first a look")
	_lines(state, "cindermoor_doused")
	assert_true(Conditions.evaluate(dig["if"], state), "then it can be dug out")
	assert_false(Conditions.evaluate(_object(STEPS, "steps_doused")["if"], state), "one prompt on it at a time")
	var cold: Array = (_region(STEPS)["props"] as Array).filter(func(p: Dictionary) -> bool: return str(p.get("cresset", "")) == "steps_5" and p["if"] == "!" + GONE)
	assert_eq(cold.size(), 1)
	assert_true(str(cold[0]["model"]).ends_with("cinder_cresset_doused.glb"), "it looks doused until it's relit")
	# Leaving it changes nothing.
	var told := _lines(state, "cindermoor_cresset_steps_5", ["Leave it as they left it."])
	assert_true(told.contains("the people who put it out will know it"), told)
	assert_false(bool(state.get_flag("cindermoor_cresset_steps_5")))
	assert_eq(str(state.get_flag("cindermoor_way_on")), "")


func test_relit_over_their_wish() -> void:
	var state := _at_the_doused("cupped")
	var exit: Dictionary = (_region(STEPS)["exits"] as Array).filter(func(e: Dictionary) -> bool: return str(e["to"]) == FOOT)[0]
	assert_false(Conditions.evaluate(exit["requires"], state), "the road up forgets while it's doused")
	var told := _lines(state, "cindermoor_cresset_steps_5", ["Lift the stone and dig it out."])
	assert_true(told.contains("Don't.") and told.contains("I thought that meant something."), told)
	assert_true(told.contains("stop telling it no") and told.contains("all the way to the crown"), told)
	assert_true(told.contains("There'll be next ones now."), told)
	assert_true(bool(state.get_flag("cindermoor_cresset_steps_5")))
	assert_eq(str(state.get_flag("cindermoor_way_on")), "relit")
	assert_true(Conditions.evaluate(exit["requires"], state), "the road remembers up to the crown")
	# The Unmoored are gone; what's left is where they stood.
	var placed: Array = (_region(STEPS)["npcs"] as Array).filter(func(n: Dictionary) -> bool: return str(n["npc"]) == "ness")
	assert_false(Conditions.evaluate(placed[0]["if"], state), "Ness has gone")
	var figures: Array = (_region(STEPS)["props"] as Array).filter(func(p: Dictionary) -> bool: return p.has("averts"))
	assert_eq(figures.size(), 2)
	assert_true(figures.all(func(p: Dictionary) -> bool: return not Conditions.evaluate(p["if"], state)), "and the two in the fog")
	assert_true(Conditions.evaluate(_object(STEPS, "steps_unmoored_gone")["if"], state))
	told = _lines(state, "cindermoor_unmoored_gone")
	assert_true(told.contains("Her cinder-rake leans on the shelter") and told.contains("Gone."), told)
	# Bare ember, never covered: no reproach for the hand.
	state = _at_the_doused("bare")
	told = _lines(state, "cindermoor_cresset_steps_5", ["Lift the stone and dig it out."])
	assert_true(told.contains("Don't.") and not told.contains("I thought that meant something."), told)
	# Not having met her: strangers in the fog.
	state = _at("the_unmoored")
	_lines(state, "cindermoor_doused")
	told = _lines(state, "cindermoor_cresset_steps_5", ["Lift the stone and dig it out."])
	assert_true(told.contains("You never see their faces.") and not told.contains("Don't."), told)


func test_ness_leads_the_way_in_the_dark() -> void:
	var state := _at("the_unmoored")
	var offered: Array[String] = []
	_lines(state, "ness", ["Close your hand over the ember.", "Leave her to the fog."], offered)
	assert_false(offered.has("Is there another way up? One you'd allow?"), "not before the doused cresset's been seen")
	# A bare ember: she asks again, and only then shows the way.
	state = _at_the_doused("bare")
	assert_eq(_travel_after(state, "ness", ["Is there another way up? One you'd allow?", "No.", "Leave her to the fog."]), [])
	assert_eq(str(state.get_flag("cindermoor_way_on")), "")
	var travel := _travel_after(state, "ness", ["Is there another way up? One you'd allow?", "Close your hand over the ember.", "Show me."])
	assert_eq(travel, [FOOT, "from_ness"])
	assert_eq(str(state.get_flag("cindermoor_ness_ember")), "cupped", "covered at last")
	assert_eq(str(state.get_flag("cindermoor_way_on")), "led")
	assert_false(bool(state.get_flag("cindermoor_cresset_steps_5")), "the cresset stays doused")
	# Cupped from the start: straight to the offer; the walk up counts.
	state = _at_the_doused("cupped")
	var told := _lines(state, "ness", ["Is there another way up? One you'd allow?", "Show me."])
	assert_true(told.contains("My rake is.") and told.contains("Forty-one.") and told.contains("Stop that."), told)
	assert_true(told.contains("Higher up's hers"), told)
	# Back down, she'll take them again; the relighting is still there to choose, and names the betrayal.
	offered.clear()
	told = _lines(state, "ness", ["Take me up again, the way you go."], offered)
	assert_true(told.contains("her rake across her knees") and told.contains("And stop counting."), told)
	assert_false(offered.has("Is there another way up? One you'd allow?"))
	assert_true(Conditions.evaluate(_object(STEPS, "cresset_steps_5")["if"], state))
	told = _lines(state, "cindermoor_cresset_steps_5", ["Lift the stone and dig it out."])
	assert_true(told.contains("She'd know whose fire it was."), told)
	assert_eq(str(state.get_flag("cindermoor_way_on")), "relit")


func test_the_crown_arrival_either_way() -> void:
	var foot := _region(FOOT)
	for way: String in ["relit", "led"]:
		var state := _at_the_doused("cupped")
		assert_true(RegionEvents.arrival(foot, state).is_empty(), "not before a way up (%s)" % way)
		state.set_flag("cindermoor_way_on", way)
		var told := _lines(state, RegionEvents.fire(RegionEvents.arrival(foot, state), state))
		assert_true(told.contains("the Hearthspire stands up out of the middle of it"), told)
		assert_true(told.contains("the fog stops") if way == "relit" else told.contains("like a door opening"), told)
		assert_true(told.contains("the middle of a drain is dry"), "Ness's drain (%s)" % way)
		assert_eq(state.quest_state("the_way_up"), "done", way)
		assert_true(RegionEvents.arrival(foot, state).is_empty(), "once (%s)" % way)
		told = _lines(state, "cindermoor_crown_view")
		assert_true(told.contains("Seven lights in a line") if way == "relit" else told.contains("how many steps"), told)


func test_the_warden_niche_and_the_roll() -> void:
	var state := _at("the_spire_foot")
	state.set_flag("saltmarrow_aldous_novice", "self")
	state.set_flag("kindleby_provost_saw_taper", true)
	state.add_item("stair_taper")
	var offered: Array[String] = []
	var told := _lines(state, "cindermoor_niche", ["Leave the niche as it is."], offered)
	assert_true(told.contains("Aldous's knife") and told.contains("you could set the blade in any one of them"), told)
	assert_false(offered.has("Turn the roll over."), "only once it's been read")
	told = _lines(state, "cindermoor_niche", ["Read the roll.", "Turn the roll over.", "Sit in the warden's seat."])
	assert_true(told.begins_with("Aldous's seat, his tapers, his knife."), "the second look is short")
	for name: String in ["Ama Rusk", "Tobin Petch", "Kit Petch", "Joss Merrow", "Edda Pike", "Fennick"]:
		assert_true(told.contains(name), name)
	assert_true(told.contains("Aldous named six") and told.contains("scraped the name off"), told)
	assert_true(told.contains("Nobody scrapes one."), told)
	assert_eq(state.quest_stage("the_seventh_name"), "scraped")
	assert_true(told.contains("Merrit's hand") and told.contains("Eighth — kept back. Her word."), told)
	assert_true(told.contains("All but one."), told)
	for flag: String in ["cindermoor_niche_seen", "cindermoor_roll_read", "cindermoor_roll_boats"]:
		assert_true(bool(state.get_flag(flag)), flag)
	# Never named here: mysteries #1/#2 stay closed.
	for secret: String in ["Oriel", "Sayre", "High Keeper"]:
		assert_false(told.contains(secret), secret)
	# Without the taper or the Provost's word, the plain look.
	state = _at("the_spire_foot")
	state.remove_item("stair_taper", state.item_count("stair_taper"))
	told = _lines(state, "cindermoor_niche", ["Leave the niche as it is."])
	assert_false(told.contains("Aldous's knife") or told.contains("Stair-Taper"), told)


func test_the_door_and_the_ring() -> void:
	var state := _at("the_spire_foot")
	state.add_item("stair_taper")
	var told := _lines(state, "cindermoor_stair_door")
	assert_true(told.contains("can't think what comes after one") and told.contains("A taper's for the stair"), told)
	assert_true(bool(state.get_flag("cindermoor_stair_door_tried")))
	told = _lines(state, "cindermoor_ring")
	assert_true(told.contains("One pair of feet") and told.contains("Doesn't sit at all."), told)
	assert_false(told.contains("Oriel"), told)


func test_merrit_counts_seven() -> void:
	var state := _at("the_spire_foot")
	var told := _lines(state, "merrit", ["Leave him to his coiling."])
	assert_true(told.contains("Seven out. Seven lit. Somebody's coming down, then."), told)
	told = _lines(state, "merrit", [])
	assert_false(told.contains("Seven up the moor"), "once")
	state = _at("the_unmoored")
	state.set_flag("cindermoor_way_on", "led")
	assert_false(_lines(state, "merrit", []).contains("Seven up the moor"), "not when led up in the dark")


func test_the_spire_foot_region() -> void:
	var region := _region(FOOT)
	var spire: Dictionary = region["props"][0]
	assert_true(str(spire["model"]).ends_with("spire_foot.glb") and ResourceLoader.exists(spire["model"]))
	for spawn: String in ["from_steps", "from_ness"]:
		assert_true(region["spawn_points"].has(spawn), spawn)
	assert_true(_region(STEPS)["spawn_points"].has("from_crown"))
	var back: Dictionary = region["exits"][0]
	assert_eq([str(back["to"]), str(back["spawn"])], [STEPS, "from_crown"])
	# The way down comes out at the light's edge: without its breath of clear, the spawn would lie in the fog.
	var db := load_content()
	var steps: Dictionary = db.regions[STEPS]
	steps["greying"] = (steps["greying"] as Array).filter(func(a: Dictionary) -> bool: return not str(a.get("note", "")).contains("from_crown"))
	var v := ContentValidator.new(db)
	v._validate_region(STEPS, steps)
	var report := "\n".join(v.errors)
	assert_true(report.contains("spawn 'from_crown' lies in the Greying"), report)
	# A cresset's cold_model must be a model that exists.
	db = load_content()
	steps = db.regions[STEPS]
	steps["cressets"][4]["cold_model"] = "res://assets/models/dressing/no_such.glb"
	Cressets.expand(steps)
	v = ContentValidator.new(db)
	v._validate_region(STEPS, steps)
	report = "\n".join(v.errors)
	assert_true(report.contains("no_such.glb"), report)
