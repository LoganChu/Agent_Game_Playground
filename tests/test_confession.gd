extends TestCase
## Aldous's Act I confession and the Act II ferry hook, driven through the real story content.

const FERRY := "across_the_grey"

var _db: ContentDatabase


func _state(approach: String, beacon_lit: bool = true) -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	state.set_flag("saltmarrow_met_aldous", true)
	state.set_flag("saltmarrow_aldous_approach", approach)
	state.start_quest("a_light_for_saltmarrow", "speak_to_aldous")
	state.set_quest_stage("a_light_for_saltmarrow", "feed_the_beacon")
	if beacon_lit:
		state.set_flag("saltmarrow_beacon_burned", "knot")
		state.complete_quest("a_light_for_saltmarrow")
	return state


func test_no_confession_before_the_beacon_is_lit() -> void:
	for approach: String in ["", "gentle", "pressed"]:
		var state := _state(approach, false)
		var offered: Array[String] = []
		play_dialogue(_db, state, "aldous", [], offered)
		assert_false(offered.has("I'm ready for the rest of your story."), "gentle option hidden (%s)" % approach)
		assert_false(offered.has("You said I'd make you talk. So talk."), "pressed option hidden (%s)" % approach)
		assert_eq(state.quest_state(FERRY), "inactive")


func test_gentle_confession_is_full_and_gives_the_sleeve_ember() -> void:
	var state := _state("gentle")
	var text := play_dialogue(_db, state, "aldous", ["The Gull's Beacon is lit.", "Sit with him.", "Whose hand?", "Say the name.", "I don't know."])
	assert_eq(state.get_flag("saltmarrow_aldous_confessed"), "full")
	assert_eq(state.item_count("keepers_sleeve_ember"), 1)
	assert_eq(state.quest_state(FERRY), "active")
	assert_eq(state.quest_stage(FERRY), "ask_mara")
	assert_true(text.contains("The High Keeper's"), "names the High Keeper as the culprit")
	assert_true(text.contains("cupped in someone's hands"), "the light going down the stair")
	assert_false(text.contains("Oriel"), "never names the High Keeper")
	# Once told, the spire question gets the short answer and no re-confession is offered.
	var offered: Array[String] = []
	text = play_dialogue(_db, state, "aldous", ["What happened at the Hearthspire?"], offered)
	assert_true(text.contains("I held the door"))
	assert_false(offered.has("I'm ready for the rest of your story."))


func test_gentle_player_can_defer_and_ask_later() -> void:
	var state := _state("gentle")
	play_dialogue(_db, state, "aldous", ["The Gull's Beacon is lit.", "Later, Brother."])
	assert_eq(state.get_flag("saltmarrow_aldous_confessed"), "")
	play_dialogue(_db, state, "aldous", ["I'm ready for the rest of your story.", "Whose hand?", "Why would the High Keeper do that?"])
	assert_eq(state.get_flag("saltmarrow_aldous_confessed"), "full")


func test_pressed_confession_needs_a_second_visit_and_is_grudging() -> void:
	for approach: String in ["pressed", ""]:
		var state := _state(approach)
		play_dialogue(_db, state, "aldous", ["You said I'd make you talk. So talk."])
		assert_true(state.get_flag("saltmarrow_aldous_balked"), "balks first (%s)" % approach)
		assert_eq(state.get_flag("saltmarrow_aldous_confessed"), "")
		var text := play_dialogue(_db, state, "aldous", ["Hold out your ember. \"Look at it, Brother. Then tell me.\"", "That's all?"])
		assert_eq(state.get_flag("saltmarrow_aldous_confessed"), "grudging")
		assert_eq(state.item_count("keepers_sleeve_ember"), 0, "no sleeve-ember when pressed")
		assert_eq(state.quest_stage(FERRY), "ask_mara")
		assert_true(text.contains("By the High Keeper"))
		assert_false(text.contains("cupped in someone's hands"), "grudging version holds back the stair light")


func test_mara_hangs_the_ferry_lantern() -> void:
	var state := _state("gentle")
	play_dialogue(_db, state, "aldous", ["I'm ready for the rest of your story.", "Whose hand?", "Why would the High Keeper do that?"])
	var offered: Array[String] = []
	play_dialogue(_db, state, "mara", ["Aldous says the ferry might run again."], offered)
	assert_true(offered.has("Aldous says the ferry might run again."))
	assert_true(state.get_flag("saltmarrow_ferry_lantern_hung"))
	assert_eq(state.quest_stage(FERRY), "await_the_ferry")
	offered.clear()
	play_dialogue(_db, state, "mara", [], offered)
	assert_false(offered.has("Aldous says the ferry might run again."), "asked once")


func test_ferry_lantern_prop_shape_builds_with_light() -> void:
	var node := PropFactory.build("signal_lantern")
	assert_true(node.find_children("*", "OmniLight3D", true, false).size() == 1)
	node.free()
