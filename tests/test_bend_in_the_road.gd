extends TestCase
## Day 57 — *The Bend in the Road*. Home from the far shore (`thornwold_far_shore=up`), Wenna Coll means to walk
## out along the cart road at first light to find her clamp. Asked, she waits by the first waymark past the wall
## the next time the player comes into the woods; her lantern finds the old bend the Snuffing straightened, east to
## Coll's Hearth (a cold hut, a clamp burned clean through). Her one light goes on the bend's waymark (`road`: the
## bend a road again) or by her own door (`hearth`: a light of her own; the road still lies about her).

const WOODS := "thornwold_woods"
const HEARTH := "thornwold_colls_hearth"
const ASK := "Can I walk out with you in the morning?"
const SHOW := "Show me."
const ROAD := "Hang it on the bend's waymark. Let the road be a road again."
const KEEP := "Keep it by your own door. You went a long way for a light of your own."
const BYE := "Goodbye."

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


func _lines(state: WorldState, dialogue: String, picks: Array = [], offered: Array[String] = []) -> String:
	var typed: Array[String] = []
	typed.assign(picks)
	return play_dialogue(_content(), state, dialogue, typed, offered)


## Thornwold lit and the four home from the far shore (`burned` is what the Ridge Light took).
func _home(burned: String = "salt_row") -> WorldState:
	var state := fresh_state(_content())
	for flag: String in ["intro_seen", "thornwold_landed", "thornwold_met_bram", "thornwold_met_hob", "thornwold_hob_paid",
			"thornwold_met_lamp", "thornwold_ladder_stood", "thornwold_ridge_reached", "thornwold_hob_came_in",
			"thornwold_old_road_reached", "thornwold_met_ottie", "thornwold_far_shore_reached", "thornwold_met_wenna_coll"]:
		state.set_flag(flag, true)
	state.set_flag("thornwold_beacon_burned", burned)
	state.set_flag("thornwold_" + ("salt_row" if burned == "salt_row" else "boots") + "_away", true)
	state.complete_quest("a_light_for_thornwold")
	state.set_flag("thornwold_northing", "lit")
	state.complete_quest("the_northing")
	state.set_flag("thornwold_far_shore", "up")
	state.complete_quest("the_far_shore")
	return state


## As `_home`, asked, come back into the woods at first light, and walked the bend with her.
func _walked(burned: String = "salt_row") -> WorldState:
	var state := _home(burned)
	_lines(state, "wenna_coll", [ASK])
	_lines(state, RegionEvents.fire(RegionEvents.arrival(_content().get_region(WOODS), state), state))
	_lines(state, "wenna_coll", [SHOW])
	return state


## "npc:model" for every NPC placement shown in `region`.
func _shown(state: WorldState, region: String, npc_id: String) -> Array[String]:
	var out: Array[String] = []
	for placement: Dictionary in _content().get_region(region)["npcs"]:
		if str(placement["npc"]) != npc_id or not Conditions.evaluate(placement.get("if"), state):
			continue
		var model := str(placement.get("model", _content().get_npc(npc_id).get("model", "")))
		out.append("%s@%.0f,%.0f" % [model.get_file().get_basename(), placement["position"][0], placement["position"][2]])
	return out


func _models(state: WorldState, region: String) -> Array[String]:
	var out: Array[String] = []
	for prop: Dictionary in _content().get_region(region)["props"]:
		if Conditions.evaluate(prop.get("if"), state):
			out.append(str(prop.get("model", "")).get_file().get_basename())
	return out


func _clear_areas(state: WorldState, region: String) -> int:
	var count := 0
	for area: Dictionary in _content().get_region(region)["greying"]:
		if area.get("clear", false) and Conditions.evaluate(area.get("if"), state):
			count += 1
	return count


func test_asking_to_walk_out() -> void:
	var state := _home()
	var offered: Array[String] = []
	var text := _lines(state, "wenna_coll", [BYE], offered)
	assert_true(text.contains("If it's lying, I'll know, now."), "home from the shore")
	assert_true(offered.has(ASK))
	text = _lines(state, "wenna_coll", [ASK])
	assert_true(text.contains("Maybe it wants two."))
	assert_eq(str(state.get_flag("thornwold_bend")), "asked")
	assert_eq(state.quest_stage("the_bend_in_the_road"), "first_light")
	assert_true(_lines(state, "wenna_coll", ["First light."]).contains("I'll not go without you"), "the night before")
	assert_eq(_shown(state, WOODS, "wenna_coll"), ["wenna_coll_lantern@-10,-57"] as Array[String], "still in the clearing tonight")


func test_first_light_by_the_wall() -> void:
	var state := _home()
	var woods := _content().get_region(WOODS)
	assert_true(RegionEvents.arrival(woods, state).is_empty(), "no morning until she's asked")
	_lines(state, "wenna_coll", [ASK])
	var event := RegionEvents.arrival(woods, state)
	assert_eq(str(event.get("id", "")), "woods_first_light", "the next arrival in the woods is the morning")
	assert_true(_lines(state, RegionEvents.fire(event, state)).contains("She knew you'd come."))
	assert_eq(str(state.get_flag("thornwold_bend")), "morning")
	assert_true(RegionEvents.arrival(woods, state).is_empty(), "once")
	assert_eq(_shown(state, WOODS, "wenna_coll"), ["wenna_coll_lantern@4,-19"] as Array[String], "by the first waymark")
	var text := _lines(state, "wenna_coll", ["Where was your hearth?", "How does a road lie?", "Not yet."])
	assert_true(text.contains("It bent. Here, just past the first mark"))
	assert_true(text.contains("That's the lie: it doesn't stop you."))
	assert_eq(state.quest_stage("the_bend_in_the_road"), "the_bend")
	assert_eq(str(state.get_flag("thornwold_bend")), "morning", "not yet: she waits")


func test_the_bend_found() -> void:
	var state := _home()
	_lines(state, "wenna_coll", [ASK])
	RegionEvents.fire(RegionEvents.arrival(_content().get_region(WOODS), state), state)
	var runner := DialogueRunner.new(_content(), state)
	var travel := _travel_after(state, runner, [SHOW])
	assert_eq(travel, [HEARTH, "from_road"], "her light finds the ruts east")
	assert_eq(str(state.get_flag("thornwold_bend")), "walked")
	assert_eq(state.quest_stage("the_bend_in_the_road"), "her_hearth")
	assert_eq(_shown(state, WOODS, "wenna_coll"), [] as Array[String], "gone from the woods")
	assert_eq(_shown(state, HEARTH, "wenna_coll"), ["wenna_coll_lantern@8,4"] as Array[String], "at her clamp")
	var hearth := _content().get_region(HEARTH)
	var event := RegionEvents.arrival(hearth, state)
	assert_eq(str(event.get("id", "")), "colls_hearth_arrival")
	assert_true(_lines(state, RegionEvents.fire(event, state)).contains("There it was all along."))
	assert_true(RegionEvents.arrival(hearth, state).is_empty(), "once")
	var models := _models(state, HEARTH)
	for model: String in ["clamp_spent", "collier_hut_cold_empty", "waymark"]:
		assert_true(models.has(model), model)
	assert_false(models.has("hut_lantern") or models.has("waymark_lit") or models.has("collier_hut"))
	var back: Dictionary = hearth["exits"][0]
	assert_eq([str(back["to"]), str(back["spawn"])], [WOODS, "from_bend"], "back along the ruts to the wall")


## Plays `picks` through `runner` and returns the travel it leaves pending ([] if none).
func _travel_after(state: WorldState, runner: DialogueRunner, picks: Array) -> Array:
	var ev := runner.start("wenna_coll")
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


func test_at_her_hearth() -> void:
	var state := _walked()
	var text := _lines(state, "wenna_clamp")
	assert_true(text.contains("a collier's best work, done in the dark"))
	assert_true(state.get_flag("thornwold_wenna_clamp_seen"))
	var offered: Array[String] = []
	text = _lines(state, "wenna_coll", ["What was it like, when the road started lying?", "Where does the road go from here?",
			"What will you do with your light?", BYE], offered)
	assert_true(text.contains("Best burn I ever had. I wasn't there for it."), "she has a word for the clamp once you've seen it")
	assert_true(text.contains("Knowing where a thing is and getting there aren't the same"))
	assert_true(text.contains("Anybody'd find anybody."))
	assert_true(offered.has(ROAD) and offered.has(KEEP))
	assert_true(_lines(state, "bend_waymark").contains("The hook is empty"))


func test_the_road() -> void:
	var state := _walked()
	var before := _clear_areas(state, HEARTH)
	var text := _lines(state, "wenna_coll", [ROAD])
	assert_true(text.contains("Now it's a road."))
	assert_eq(str(state.get_flag("thornwold_bend")), "road")
	assert_eq(state.quest_state("the_bend_in_the_road"), WorldState.QUEST_DONE)
	assert_eq(_clear_areas(state, HEARTH), before + 2, "the bend's lantern holds the fog off the bend")
	var models := _models(state, HEARTH)
	assert_true(models.has("waymark_lit") and models.has("collier_hut"), "the bend lit, the fire in")
	assert_false(models.has("hut_lantern") or models.has("collier_hut_cold_empty") or models.has("waymark"))
	assert_eq(_shown(state, HEARTH, "wenna_coll"), ["wenna_coll@2,-2"] as Array[String], "on her own seat")
	text = _lines(state, "wenna_coll", ["Goodbye, Wenna."])
	assert_true(text.contains("Said I'd come in when it was."), "Hob came along the bend to see")
	assert_true(_lines(state, "bend_waymark").contains("You can see the straight road from here"))
	assert_true(_lines(state, "woods_old_bend", ["Leave them."]).contains("It's a road."))
	assert_true(_lines(state, "hob").contains("Road's a road again."))
	assert_true(_lines(state, "bram_tally_board").contains("marked along its side: BEND"))


func test_a_light_of_her_own() -> void:
	var state := _walked()
	var before := _clear_areas(state, HEARTH)
	var text := _lines(state, "wenna_coll", [KEEP])
	assert_true(text.contains("Let the road lie. I know where I am."))
	assert_eq(str(state.get_flag("thornwold_bend")), "hearth")
	assert_eq(state.quest_state("the_bend_in_the_road"), WorldState.QUEST_DONE)
	assert_eq(_clear_areas(state, HEARTH), before, "the road keeps lying")
	var models := _models(state, HEARTH)
	assert_true(models.has("hut_lantern") and models.has("collier_hut") and models.has("waymark"), "her light by her door")
	assert_false(models.has("waymark_lit"))
	assert_true(_lines(state, "wenna_coll", ["Goodbye, Wenna."]).contains("I don't call out."))
	assert_true(_lines(state, "woods_old_bend", ["Leave them."]).contains("You only find them because you've walked them."))
	assert_true(_lines(state, "hob").contains("Wenna brings her sacks to my cart herself."))
	var board := _lines(state, "bram_tally_board")
	assert_true(board.contains("four and five to a load"))
	assert_false(board.contains("BEND"))


func test_the_boots_path() -> void:
	var state := _walked("boots")
	_lines(state, "wenna_coll", [ROAD])
	assert_true(_lines(state, "wenna_coll", ["Goodbye, Wenna."]).contains("Didn't know me from Abe."))
	assert_true(_lines(state, "hob").contains("Never knew there was a hearth out there."))
	var kept := _walked("boots")
	_lines(kept, "wenna_coll", [KEEP])
	assert_true(_lines(kept, "hob").contains("Tells me her name every time."))


func test_hob_gone_down_and_home() -> void:
	var state := _walked()
	state.set_flag("thornwold_hob_ladder", "gone")
	_lines(state, "wenna_coll", [ROAD])
	var text := _lines(state, "hob")
	assert_true(text.contains("Came up the steps behind them."), "Hob home from the steps")
	assert_true(text.contains("Road's a road again."))


func test_hobs_hut_lantern() -> void:
	var woods := _content().get_region(WOODS)
	var count := func(state: WorldState) -> int:
		return _models(state, WOODS).count("hut_lantern")
	assert_eq(count.call(_home()), 1, "Ottie's promise: a lantern by Hob's door once the four are home")
	var waiting := _home()
	waiting.set_flag("thornwold_far_shore", "waiting")
	assert_eq(count.call(waiting), 0)
	assert_true(woods["spawn_points"].has("from_bend"))


func test_hob_at_the_bottom_of_the_road() -> void:
	var state := _walked()
	state.set_flag("thornwold_hob_ladder", "stayed")
	_lines(state, "wenna_coll", [ROAD])
	var text := _lines(state, "hob")
	assert_true(text.contains("Well. I'm in."), "Wenna sat with him at the bottom of the road")
	assert_false(text.contains("Went along it with the cart"), "he doesn't haul a cart from the bottom of the road")
