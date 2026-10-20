extends TestCase
## Day 53 — *The Northing*. With the Ridge Light lit, the old Keepers' road runs north along Thornwold's
## spine to the Northing, the Keepers' fire-cairn on the north cliff. Ottie Swale, the fourth collier, keeps
## a charcoal fire in its basket for the three who went down to the far shore. The Lamp lights him a lantern
## off the Ridge Light; the player hangs it on the Northing (Ottie goes home to his boots) or puts it in his
## hand (he takes it down the Keepers' steps after the three).

const ROAD := "thornwold_old_road"
const RIDGE := "thornwold_ridge"
const WOODS := "thornwold_woods"
const WHERE := "Where does the old road north go?"
const TELL_LAMP := "One of the four is at the Northing. Ottie Swale."
const GIVE := "This is for you. The Lamp lit it off the Ridge Light."
const HANG := "Hang it on the Northing, Ottie. Go home."
const DOWN := "Take it down to them."
const BOOTS_BACK := "I've brought your boots."
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


func _offered(state: WorldState, dialogue: String) -> Array[String]:
	var offered: Array[String] = []
	_lines(state, dialogue, [BYE], offered)
	return offered


## Thornwold lit; `burned` is what the Ridge Light took. On the salt-row path Ottie's boots are still on
## his seat; on the boots path they burned.
func _lit(burned: String = "salt_row") -> WorldState:
	var state := fresh_state(_content())
	for flag: String in ["intro_seen", "thornwold_landed", "thornwold_met_bram", "thornwold_met_hob", "thornwold_hob_paid",
			"thornwold_met_lamp", "thornwold_ladder_stood", "thornwold_ridge_reached", "thornwold_lamp_ladder_told",
			"thornwold_lamp_saw_light", "thornwold_hob_came_in"]:
		state.set_flag(flag, true)
	state.set_flag("thornwold_beacon_burned", burned)
	state.set_flag("thornwold_" + ("salt_row" if burned == "salt_row" else "boots") + "_away", true)
	state.complete_quest("a_light_for_thornwold")
	return state


## As `_lit`, but the Ridge Light still waiting on its burn.
func _dark() -> WorldState:
	var state := _lit()
	state.quests["a_light_for_thornwold"] = {"state": WorldState.QUEST_ACTIVE, "stage": "feed_the_light"}
	return state


## Met Ottie at the Northing, then asked the Lamp for a light: the player carries the Ridge Light's lantern.
func _carrying(burned: String = "salt_row") -> WorldState:
	var state := _lit(burned)
	_lines(state, "lamp", [WHERE, BYE])
	_lines(state, "ottie", [BYE])
	_lines(state, "lamp", [TELL_LAMP, BYE])
	return state


func _placements(state: WorldState, region: String, npc: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for placement: Dictionary in _content().get_region(region)["npcs"]:
		if str(placement["npc"]) == npc and Conditions.evaluate(placement.get("if"), state):
			out.append(placement)
	return out


## The one place Ottie stands in `state`, as "region:model" ("" if nowhere).
func _ottie(state: WorldState) -> String:
	var found: Array[String] = []
	for region: String in [ROAD, WOODS]:
		for placement in _placements(state, region, "ottie"):
			var model := str(placement.get("model", _content().get_npc("ottie")["model"]))
			found.append("%s:%s" % [region, model.get_file().get_basename()])
	assert_true(found.size() <= 1, "Ottie stands in one place at most: %s" % [found])
	return found[0] if found.size() == 1 else ""


## Model basenames of `region`'s shown props at (x, z).
func _props_at(state: WorldState, region: String, x: float, z: float) -> Array[String]:
	var shown: Array[String] = []
	for prop: Dictionary in _content().get_region(region)["props"]:
		var p: Array = prop["position"]
		if absf(float(p[0]) - x) < 0.01 and absf(float(p[2]) - z) < 0.01 and Conditions.evaluate(prop.get("if"), state):
			shown.append(str(prop.get("model", "")).get_file().get_basename())
	shown.sort()
	return shown


func _northing(state: WorldState) -> Array[String]:
	return _props_at(state, ROAD, 2.0, -41.0)


func _hut(state: WorldState) -> Array[String]:
	return _props_at(state, WOODS, -6.5, -60.5)


func test_the_road_waits_for_the_ridge_light() -> void:
	var exit: Dictionary = {}
	for e: Dictionary in _content().get_region(RIDGE)["exits"]:
		if str(e["to"]) == ROAD:
			exit = e
	assert_false(exit.is_empty(), "the ridge has a way onto the old road")
	var dark := _dark()
	assert_false(Conditions.evaluate(exit["requires"], dark), "not with the Ridge Light cold")
	assert_true(Conditions.evaluate(exit["requires"], _lit()), "walkable once it burns")
	var road := _content().get_region(ROAD)
	assert_true(RegionEvents.arrival(road, dark).is_empty(), "no arrival scene for a debug teleport before the burn")
	var state := _lit()
	var event := RegionEvents.arrival(road, state)
	assert_eq(str(event.get("id", "")), "old_road_arrival")
	assert_true(_lines(state, RegionEvents.fire(event, state)).contains("the smell of a charcoal clamp"))
	assert_true(RegionEvents.arrival(road, state).is_empty(), "once")


func test_the_lamp_sends_you_north() -> void:
	var dark := _dark()
	assert_false(_offered(dark, "lamp").has(WHERE), "only once the road is the beacon's")
	var state := _lit()
	var text := _lines(state, "lamp", [WHERE, BYE])
	assert_true(text.contains("the Spire's boat came in under the cliff for me"), "the keeper's road to midwinter")
	assert_true(text.contains("coal-smoke on the north wind"))
	assert_eq(state.quest_stage("the_northing"), "walk_north")
	assert_false(_offered(state, "lamp").has(WHERE), "asked once")
	assert_false(_offered(state, "lamp").has(TELL_LAMP), "nothing to tell yet")


func test_meeting_ottie() -> void:
	var state := _lit()
	assert_eq(_ottie(state), ROAD + ":ottie", "at the Northing, bareheaded")
	assert_eq(_northing(state), ["cresset_coals", "northing_cairn"] as Array[String], "his charcoal in the basket")
	var text := _lines(state, "ottie", [BYE])
	assert_true(text.contains("Ottie Swale. Collier"))
	assert_true(state.get_flag("thornwold_met_ottie"))
	assert_eq(state.quest_stage("the_northing"), "a_proper_light", "met without the Lamp's errand: the quest starts here")
	var sent := _lit()
	_lines(sent, "lamp", [WHERE, BYE])
	_lines(sent, "ottie", [BYE])
	assert_eq(sent.quest_stage("the_northing"), "a_proper_light", "the Lamp's errand moves on")
	text = _lines(_lit(), "ottie", ["Where are the other three?", BYE])
	assert_true(text.contains("Wenna Coll, and the Drays. Abe and Tolly."), "the three, by name (LORE)")
	text = _lines(_lit(), "ottie", ["Your boots are on your seat by the cold hut.", BYE])
	assert_true(text.contains("A man doesn't leave his boots unless he's coming back for them."), "why the boots (Day 22's hook)")
	text = _lines(_lit(), "ottie", ["Your cap's still hanging on the mark at the foot of the stair.", BYE])
	assert_true(text.contains("Till I'm down, it's telling the truth."), "he leaves the cap hung")


func test_his_cap_back() -> void:
	var state := _lit()
	state.set_flag("thornwold_stair_lantern_hung", true)
	state.add_item("colliers_cap")
	var text := _lines(state, "ottie", [BYE])
	assert_true(text.contains("Crooked cord on the band"), "he knows it")
	assert_eq(state.item_count("colliers_cap"), 0)
	assert_true(state.get_flag("thornwold_ottie_cap"))
	assert_eq(_ottie(state), ROAD + ":ottie_cap", "he wears it")
	assert_false(_offered(state, "ottie").has("Your cap's still hanging on the mark at the foot of the stair."))


func test_hob_as_ottie_hears_of_him() -> void:
	var text := _lines(_lit(), "ottie", ["I've met Hob Marl.", BYE])
	assert_true(text.contains("Hob still counts four, every night"), "salt row: Hob keeps the four")
	text = _lines(_lit("boots"), "ottie", ["I've met Hob Marl.", BYE])
	assert_true(text.contains("Hob doesn't count anyone now. He sleeps."), "boots: told the truth")
	assert_true(text.contains("So I'm nobody's, down there."))
	text = _lines(_lit("boots"), "ottie", ["Your boots went into the Ridge Light.", BYE])
	assert_true(text.contains("My boots lit a beacon."))
	var gone := _lit()
	gone.set_flag("thornwold_hob_ladder", "gone")
	assert_false(_offered(gone, "ottie").has("I've met Hob Marl."))
	text = _lines(gone, "ottie", ["Hob Marl came up this road.", BYE])
	assert_true(text.contains("Then he went on down the steps after them."), "The Fifth, gone: Hob passed the Northing")


func test_the_lamp_lights_a_lantern() -> void:
	var state := _lit()
	_lines(state, "ottie", [BYE])
	assert_true(_offered(state, "lamp").has(TELL_LAMP))
	var text := _lines(state, "lamp", [TELL_LAMP, BYE])
	assert_true(text.contains("the first collier up the road lights it with charcoal for his friends"))
	assert_eq(state.item_count("ridge_lantern"), 1)
	assert_eq(state.quest_stage("the_northing"), "carry_it")
	assert_false(_offered(state, "lamp").has(TELL_LAMP), "one lantern")
	assert_true(_offered(state, "ottie").has(GIVE))


func test_hung_on_the_northing_ottie_goes_home() -> void:
	var state := _carrying()
	var text := _lines(state, "ottie", [GIVE, HANG])
	assert_true(text.contains("somewhere below there is a warm place in it"))
	assert_true(text.contains("Boots. I'm going home to my boots."))
	assert_eq(state.get_flag("thornwold_northing"), "lit")
	assert_eq(state.item_count("ridge_lantern"), 0)
	assert_true(state.quest_state("the_northing") == WorldState.QUEST_DONE)
	assert_eq(_northing(state), ["cresset_lantern", "northing_cairn"] as Array[String], "the lantern on the hook, the charcoal out")
	assert_eq(_ottie(state), WOODS + ":ottie_home", "on his own seat, boots on, bare-headed (cap still on the stair's mark)")
	assert_eq(_hut(state), ["collier_hut_cold_empty"] as Array[String], "the boots are on him, not the seat")
	text = _lines(state, "ottie", [BYE])
	assert_true(text.contains("Hob said I'd want them."))
	assert_true(text.contains("Then he said, 'Boots.'"), "Hob knows him")
	assert_true(state.get_flag("thornwold_ottie_home_seen"))
	assert_true(_lines(state, "ottie", [BYE]).contains("Light's still on the Northing."), "home once")
	assert_true(_lines(state, "lamp", [BYE]).contains("There's a light at the north end."))
	assert_true(_lines(state, "keepers_steps").contains("the only thing to climb to"))
	var capped := _carrying()
	capped.set_flag("thornwold_hob_has_cap", true)
	_lines(capped, "ottie", [GIVE, HANG])
	assert_eq(_ottie(capped), WOODS + ":ottie_home_cap", "the cap Hob set on his seat, on his head")


func test_carried_down_to_the_three() -> void:
	var state := _carrying()
	var text := _lines(state, "ottie", [GIVE, DOWN])
	assert_true(text.contains("Tell Hob leave my boots be."))
	assert_eq(state.get_flag("thornwold_northing"), "carried")
	assert_true(state.quest_state("the_northing") == WorldState.QUEST_DONE)
	assert_eq(_ottie(state), "", "gone down the Keepers' steps")
	assert_eq(_northing(state), ["cresset_coals", "northing_cairn"] as Array[String], "his charcoal banked in the basket")
	assert_eq(_hut(state), ["collier_hut_cold"] as Array[String], "his boots wait on his seat")
	assert_true(_lines(state, "lamp", [BYE]).contains("I saw a light go down off the Northing."))
	assert_true(_lines(state, "keepers_steps").contains("Ottie's, the Ridge Light's gold"))
	var gone := _carrying()
	gone.set_flag("thornwold_hob_ladder", "gone")
	_lines(gone, "ottie", [GIVE, DOWN])
	assert_true(_lines(gone, "keepers_steps").contains("two lights are standing close together"), "Hob and Ottie, below")


func test_home_without_his_boots() -> void:
	var state := _carrying("boots")
	var text := _lines(state, "ottie", [GIVE, HANG])
	assert_true(text.contains("No boots to go home to."))
	assert_eq(_ottie(state), WOODS + ":ottie_home_unshod", "the boots burned: feet still in sacking")
	assert_eq(_hut(state), ["collier_hut_cold_empty"] as Array[String])
	text = _lines(state, "ottie", [BYE])
	assert_true(text.contains("'Always just me, this side of the ridge,'"), "Hob doesn't know him")
	assert_false(_offered(state, "ottie").has(BOOTS_BACK), "nothing to bring back")
	# Salt row burned, but the player still carries the unburned boots Hob gave them.
	var held := _carrying()
	held.add_item("otties_boots")
	held.set_flag("thornwold_boots_away", true)
	_lines(held, "ottie", [GIVE, HANG])
	assert_eq(_ottie(held), WOODS + ":ottie_home_unshod")
	text = _lines(held, "ottie", [BYE])
	assert_true(text.contains("Now I'm home."), "given straight back on the seat")
	assert_eq(held.item_count("otties_boots"), 0)
	assert_false(held.get_flag("thornwold_boots_away"))
	assert_eq(_ottie(held), WOODS + ":ottie_home", "boots on")
	assert_eq(_hut(held), ["collier_hut_cold_empty"] as Array[String])


func test_the_kit() -> void:
	var dir := "res://assets/models/dressing/"
	var glow := {"northing_cairn": false, "cresset_coals": true, "cresset_lantern": true, "waymark_rake": false}
	for name: String in glow:
		var scene := load(dir + name + ".glb") as PackedScene
		assert_true(scene != null, "%s loads" % name)
		var node := scene.instantiate()
		assert_eq(_emissive(node) > 0, bool(glow[name]), "%s glows only if it burns" % name)
		node.free()
	var road := _content().get_region(ROAD)
	var halos := 0
	for prop: Dictionary in road["props"]:
		if str(prop.get("model", "")).get_file() == "cresset_lantern.glb":
			assert_true(JsonUtil.to_vector3(prop.get("halo")).is_equal_approx(Vector3(0, 1.69, 0.78)), "the halo sits on the lantern's glass")
			halos += 1
	assert_eq(halos, 1)


func _emissive(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i) as StandardMaterial3D
			if material != null and material.emission_enabled:
				count += 1
	for child in node.get_children():
		count += _emissive(child)
	return count
