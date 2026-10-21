extends TestCase
## Day 55 — *The Far Shore*. With a light at the Northing or below it, the Keepers' steps go down the north
## cliff to the far shore: Wenna Coll on the end of the Keepers' boat-stage waiting for the Spire's boat, the
## Drays arguing by a driftwood fire, Ottie under the lantern he hung on the stage (if he carried it down) and
## Hob counting heads (if he went). The player's word: come up (the three walk the old road to the Ridge Light,
## where the Lamp breaks the warm side of its kept coal into lanterns, and come home to the colliers'
## clearing) or wait (the Wakebearer promises to tell the Spire; they stay on the shore).

const SHORE := "thornwold_far_shore"
const ROAD := "thornwold_old_road"
const WOODS := "thornwold_woods"
const LANDING := "thornwold_landing"
const DOWN := "Go down the Keepers' steps."
const UP := "Come up. Somebody came down for you: me."
const WAIT := "Wait for it, then. I'll tell the Spire you're here."
const LATER_UP := "Come up, Wenna. It's not too late to go home."
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


## Thornwold lit (`burned` is what the Ridge Light took) and The Northing done with `northing` ('lit' or
## 'carried'); '' leaves the Northing undone (Ottie still at the basket).
func _state(northing: String = "carried", burned: String = "salt_row") -> WorldState:
	var state := fresh_state(_content())
	for flag: String in ["intro_seen", "thornwold_landed", "thornwold_met_bram", "thornwold_met_hob", "thornwold_hob_paid",
			"thornwold_met_lamp", "thornwold_ladder_stood", "thornwold_ridge_reached", "thornwold_lamp_ladder_told",
			"thornwold_lamp_saw_light", "thornwold_hob_came_in", "thornwold_old_road_reached", "thornwold_met_ottie"]:
		state.set_flag(flag, true)
	state.set_flag("thornwold_beacon_burned", burned)
	state.set_flag("thornwold_" + ("salt_row" if burned == "salt_row" else "boots") + "_away", true)
	state.complete_quest("a_light_for_thornwold")
	if northing != "":
		state.set_flag("thornwold_northing", northing)
		state.complete_quest("the_northing")
	return state


## As `_state`, gone down the steps and met Wenna.
func _met(northing: String = "carried", burned: String = "salt_row") -> WorldState:
	var state := _state(northing, burned)
	_lines(state, "keepers_steps", [DOWN])
	_lines(state, "wenna_coll", [BYE])
	return state


## "region:npc:model" for every NPC placement shown in `region`.
func _shown(state: WorldState, region: String) -> Array[String]:
	var out: Array[String] = []
	for placement: Dictionary in _content().get_region(region)["npcs"]:
		if not Conditions.evaluate(placement.get("if"), state):
			continue
		var npc := str(placement["npc"])
		var model := str(placement.get("model", _content().get_npc(npc).get("model", "")))
		out.append("%s:%s" % [npc, model.get_file().get_basename()])
	out.sort()
	return out


## Ottie's one placement in the clearing ("" if he isn't there).
func _ottie(state: WorldState) -> String:
	var found := ""
	for shown in _shown(state, WOODS):
		if shown.begins_with("ottie:"):
			assert_eq(found, "", "Ottie sits in one place")
			found = shown
	return found


func _models(state: WorldState, region: String) -> Array[String]:
	var out: Array[String] = []
	for prop: Dictionary in _content().get_region(region)["props"]:
		if Conditions.evaluate(prop.get("if"), state):
			out.append(str(prop.get("model", "")).get_file().get_basename())
	return out


func test_the_steps_wait_for_a_light() -> void:
	var dark := _state("")
	assert_false(_offered(dark, "keepers_steps").has(DOWN), "not while only Ottie's charcoal burns up top")
	assert_true(_lines(dark, "keepers_steps").contains("Not today."))
	var shore := _content().get_region(SHORE)
	assert_true(RegionEvents.arrival(shore, dark).is_empty(), "no arrival scene for a debug teleport before there's a light")
	for northing: String in ["lit", "carried"]:
		var state := _state(northing)
		assert_true(_offered(state, "keepers_steps").has(DOWN), "a light at the top or below: %s" % northing)
		_lines(state, "keepers_steps", [DOWN])
		assert_eq(state.quest_stage("the_far_shore"), "the_three", "going down starts The Far Shore")
		var event := RegionEvents.arrival(shore, state)
		assert_eq(str(event.get("id", "")), "far_shore_arrival")
		var text := _lines(state, RegionEvents.fire(event, state))
		assert_true(text.contains("The Keepers' boat-stage."))
		assert_eq(text.contains("Ottie's standing under it."), northing == "carried")
		assert_eq(text.contains("the Northing's lantern makes a gold place"), northing == "lit")
		assert_true(RegionEvents.arrival(shore, state).is_empty(), "once")
	var back: Dictionary = shore["exits"][0]
	assert_eq(str(back["to"]), ROAD, "the steps go back up to the Northing")


func test_who_waits_on_the_shore() -> void:
	assert_eq(_shown(_state("lit"), SHORE), ["abe:abe", "tolly:tolly", "wenna_coll:wenna_coll"] as Array[String],
			"the three; Ottie went home")
	assert_eq(_shown(_state("carried"), SHORE), ["abe:abe", "ottie:ottie", "tolly:tolly", "wenna_coll:wenna_coll"] as Array[String],
			"Ottie came down with the lantern")
	var gone := _state("carried")
	gone.set_flag("thornwold_hob_ladder", "gone")
	gone.set_flag("thornwold_ottie_cap", true)
	assert_eq(_shown(gone, SHORE), ["abe:abe", "hob:hob_lantern", "ottie:ottie_cap", "tolly:tolly", "wenna_coll:wenna_coll"] as Array[String],
			"Hob went down before him, with his own light")
	assert_true(_models(_state("carried"), SHORE).has("stage_lantern"), "the Ridge Light's lantern on the stage's bracket")
	assert_false(_models(_state("lit"), SHORE).has("stage_lantern"))
	assert_true(_models(_state("lit"), SHORE).has("cresset_lantern"), "the Northing's lantern high on the cliff")


func test_meeting_wenna() -> void:
	var state := _state("carried")
	_lines(state, "keepers_steps", [DOWN])
	var text := _lines(state, "wenna_coll", [BYE])
	assert_true(text.contains("Wenna Coll. Collier, near side."))
	assert_true(text.contains("Told you somebody'd come down."), "Ottie, beside her")
	assert_true(state.get_flag("thornwold_met_wenna_coll"))
	assert_eq(state.quest_stage("the_far_shore"), "the_boat")
	text = _lines(state, "wenna_coll", ["Why did you need a light of your own?", BYE])
	assert_true(text.contains("My own smoke, and I couldn't find the fire under it."), "the road lies")
	assert_false(_offered(state, "wenna_coll").has("You've been counting days on the bollard."), "not before the stage is looked at")
	assert_true(_lines(state, "boat_stage").contains("Not winters. Days."))
	assert_true(_offered(state, "wenna_coll").has("You've been counting days on the bollard."))
	assert_true(_lines(state, "abe", ["Why are you so sure the boat's coming?", BYE]).contains("Because Tolly says it isn't."))
	assert_true(_lines(state, "abe", ["There's a rake driven into a waymark on the old road.", BYE]).contains("A rake that's both of ours is the road's."))
	assert_true(_lines(state, "tolly", ["Why did you come down, if you don't think it's coming?", BYE]).contains("couldn't find a beach with both hands"))
	text = _lines(state, "wenna_coll", ["The Spire's dark. The boat isn't coming.", BYE])
	assert_true(text.contains("Spires get lit again"))
	assert_false(text.contains("Put out."), "Aldous hasn't confessed in this state")
	var told := _met("carried")
	told.set_flag("saltmarrow_aldous_confessed", "full")
	assert_true(_lines(told, "wenna_coll", ["The Spire's dark. The boat isn't coming.", BYE]).contains("Then somebody can put it back."))


func test_come_up() -> void:
	var state := _met("carried")
	var text := _lines(state, "wenna_coll", [UP])
	assert_true(text.contains("Somebody came down."))
	assert_true(text.contains("It said that? For us?"), "told what the Lamp keeps the coal for")
	assert_true(text.contains("I'll leave the lantern on the bracket. For the boat."))
	assert_eq(state.get_flag("thornwold_far_shore"), "up")
	assert_true(state.quest_state("the_far_shore") == WorldState.QUEST_DONE)
	assert_empty(_shown(state, SHORE), "the shore's empty")
	var models := _models(state, SHORE)
	assert_true(models.has("drift_fire_out") and not models.has("drift_fire"), "the fire raked out")
	assert_true(models.has("stage_lantern"), "Ottie's light left on the stage for the boat")
	assert_eq(_shown(state, WOODS), ["abe:abe", "ottie:ottie_home", "tolly:tolly_lantern", "wenna_coll:wenna_coll_lantern"] as Array[String],
			"home in the clearing (Hob's at the camp)")
	assert_true(_models(state, WOODS).has("collier_hut_cold_empty"), "Ottie's boots on him, not on the seat")
	assert_false(_models(state, WOODS).has("collier_hut_cold"))
	text = _lines(state, "lamp", [BYE])
	assert_true(text.contains("I knew them before they were in the light."))
	assert_true(text.contains("I broke the warm side for them."))
	assert_true(text.contains("the side that went cold the night the Spire went dark"), "the cold side kept (mystery)")
	assert_false(text.contains("I saw a light go down off the Northing."), "superseded")
	text = _lines(state, "wenna_coll")
	assert_true(text.contains("It knew all four faces."))
	assert_true(text.contains("Then sat down on his step"), "Hob keeps the four on the salt-row path")
	assert_true(_lines(state, "tolly", [BYE]).contains("For Hob's hut."), "Ottie's promise of a lantern (Day 25)")
	assert_true(_lines(state, "abe", [BYE]).contains("Higher. You're holding it like a kettle."))
	text = _lines(state, "ottie", [BYE])
	assert_true(text.contains("All four. All four home."))
	assert_true(text.contains("Left my light on the stage for the boat."))
	assert_true(state.get_flag("thornwold_ottie_four_home_seen"))
	assert_true(_lines(state, "ottie", [BYE]).contains("Four seats."), "home once")
	assert_true(_lines(state, "hob", [BYE]).contains("Four. Four home."))
	assert_true(_lines(state, "keepers_steps", [BYE]).contains("Nobody beside it now."))


func test_come_up_by_the_northings_light() -> void:
	var state := _met("lit")
	assert_true(_lines(state, "tolly", ["How long have you been down here?", BYE]).contains("We could go up by it any time we liked."))
	var text := _lines(state, "wenna_coll", [UP])
	assert_true(text.contains("the Northing's lantern makes a gold place in the fog"))
	assert_false(text.contains("I'll leave the lantern on the bracket."), "no lantern down here")
	assert_false(_models(state, SHORE).has("stage_lantern"))
	assert_true(_lines(state, "lamp", [BYE]).contains("by the light on the Northing"))
	text = _lines(state, "ottie", [BYE])
	assert_true(text.contains("Took somebody going down to make it a thing to climb to."))
	assert_eq(_ottie(state), "ottie:ottie_home")


func test_wait_for_the_boat() -> void:
	var state := _met("carried")
	var text := _lines(state, "wenna_coll", [WAIT])
	assert_true(text.contains("Tell them there's colliers on the Northing's stage"))
	assert_true(text.contains("Waiting, then. I don't wait well."), "Ottie stays with them")
	assert_eq(state.get_flag("thornwold_far_shore"), "waiting")
	assert_true(state.quest_state("the_far_shore") == WorldState.QUEST_DONE)
	assert_eq(_shown(state, SHORE).size(), 4, "they stay on the shore")
	assert_true(_models(state, SHORE).has("drift_fire"))
	assert_true(_lines(state, "lamp", [BYE]).contains("I'll keep the coal for them. All of it."))
	assert_true(_lines(state, "boat_stage").contains("more of them every time you come down"))
	assert_true(_lines(state, "abe", [BYE]).contains("Still coming."))
	assert_true(_lines(state, "tolly", [BYE]).contains("Still not coming."))
	assert_true(_lines(state, "wenna_coll", [BYE]).contains("You told them?"))
	text = _lines(state, "wenna_coll", [LATER_UP])
	assert_true(text.contains("Somebody came down."), "the word can still change")
	assert_eq(state.get_flag("thornwold_far_shore"), "up")


func test_hob_and_the_far_shore() -> void:
	var gone := _state("carried")
	gone.set_flag("thornwold_hob_ladder", "gone")
	_lines(gone, "keepers_steps", [DOWN])
	assert_true(_lines(gone, "hob", [BYE]).contains("All four, on a beach."))
	_lines(gone, "wenna_coll", [UP])
	assert_true(_shown(gone, WOODS).has("hob:hob_lantern"), "Hob home to his clamp with his lantern")
	var text := _lines(gone, "hob", [BYE])
	assert_true(text.contains("Stopped counting, top of the steps."))
	assert_true(text.contains("My rake's at Bram Kettle's"))
	var stayed := _met("lit")
	stayed.set_flag("thornwold_hob_ladder", "stayed")
	_lines(stayed, "wenna_coll", [UP])
	assert_true(_lines(stayed, "hob", [BYE]).contains("I crossed them through. All four."))
	text = _lines(stayed, "bram_tally_board")
	assert_true(text.contains("every one of them crossed through"))
	assert_false(text.contains("the first of them crossed through"))


func test_the_boots_path() -> void:
	var state := _met("lit", "boots")
	_lines(state, "wenna_coll", [UP])
	assert_true(_lines(state, "wenna_coll").contains("Hob looked at us like weather."), "Hob doesn't know them")
	assert_true(_lines(state, "hob", [BYE]).contains("There's more charcoal folk in the clearing now."))
	assert_true(_lines(state, "ottie", [BYE]).contains("Four strangers in his clearing."))
	assert_eq(_ottie(state), "ottie:ottie_home_unshod", "his boots burned")


func test_the_kit() -> void:
	var glow := {"steps_foot": false, "boat_stage": false, "stage_lantern": true, "drift_fire": true, "drift_fire_out": false,
			"drift_shelter": false}
	for name: String in glow:
		var scene := load("res://assets/models/dressing/" + name + ".glb") as PackedScene
		assert_true(scene != null, "%s loads" % name)
		var node := scene.instantiate()
		assert_eq(_emissive(node) > 0, bool(glow[name]), "%s glows only if it burns" % name)
		node.free()
	for name: String in ["wenna_coll", "wenna_coll_lantern", "abe", "tolly", "tolly_lantern"]:
		var scene := load("res://assets/models/characters/" + name + ".glb") as PackedScene
		assert_true(scene != null, "%s loads" % name)
		var node := scene.instantiate()
		assert_eq(_emissive(node) > 0, name.ends_with("_lantern"), "%s: only a lantern glows" % name)
		node.free()
	var halos := 0
	for prop: Dictionary in _content().get_region(SHORE)["props"]:
		if str(prop.get("model", "")).get_file() == "stage_lantern.glb":
			assert_true(JsonUtil.to_vector3(prop.get("halo")).is_equal_approx(Vector3(-0.85, 1.87, 0.95)), "the halo sits on the lantern's glass")
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
