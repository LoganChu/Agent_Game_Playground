extends TestCase
## Saltmarrow after the burn: burn-specific dressing and inspectables, and the ferry-lantern
## and sleeve-ember reactions, driven through the real content.

var _db: ContentDatabase


## A state just after the Gull's Beacon was fed `burned` ("" = still unlit).
func _state(burned: String = "") -> WorldState:
	if _db == null:
		_db = load_content()
	var state := fresh_state(_db)
	state.set_flag("saltmarrow_met_mara", true)
	state.set_flag("shingle_met_pell", true)
	state.start_quest("a_light_for_saltmarrow", "speak_to_aldous")
	if burned:
		state.set_flag("saltmarrow_beacon_burned", burned)
		state.complete_quest("a_light_for_saltmarrow")
	return state


## Shapes of the Saltmarrow props whose `if` holds in `state`, conditional ones only.
func _conditional_shapes(state: WorldState) -> Array[String]:
	var shapes: Array[String] = []
	for prop: Dictionary in _db.regions["saltmarrow"]["props"]:
		if prop.has("if") and Conditions.evaluate(prop["if"], state):
			shapes.append(str(prop.get("shape", "")))
	shapes.sort()
	return shapes


func test_dressing_follows_the_burn() -> void:
	# (The wrapped ember sign hangs by the Wrens' door until Aldous confesses: test_wrens_and_lofts.
	# The two net-lofts by the gate are broken before the burn and half-mended after: one "house"
	# each either way, test_aldous_bench.)
	assert_eq(_conditional_shapes(_state()), ["ember_sign", "house", "house"] as Array[String], "nothing extra while unlit")
	assert_eq(_conditional_shapes(_state("pebble")), ["ember_sign", "house", "house", "net_rack", "net_rack"] as Array[String])
	assert_eq(_conditional_shapes(_state("knot")), ["ember_sign", "house", "house", "net_frame", "net_frame"] as Array[String])
	assert_eq(_conditional_shapes(_state("gull")), ["cups", "ember_sign", "house", "house", "net_rack", "net_rack"] as Array[String])


func test_new_prop_shapes_build() -> void:
	for shape: String in ["stool", "cups", "net_rack", "net_frame"]:
		var node := PropFactory.build(shape)
		assert_true(node is StaticBody3D, "%s is a static body" % shape)
		assert_true(node.get_child_count() >= 3, "%s has meshes and a collider" % shape)
		node.free()


func test_dunstans_stool_tracks_what_mara_knows() -> void:
	var state := _state()
	assert_true(play_dialogue(_db, state, "dunstans_stool", []).contains("Someone big sat here"))
	state.set_flag("saltmarrow_mara_told_of_dunstan", true)
	assert_true(play_dialogue(_db, state, "dunstans_stool", []).contains("Dunstan's stool"))
	state.set_flag("saltmarrow_mara_knows_dunstan_chose", true)
	assert_true(play_dialogue(_db, state, "dunstans_stool", []).contains("facing north"))
	# The gull lent and handed back: it sits on his stool.
	state.set_flag("saltmarrow_mara_offered_gull", true)
	state.set_flag("saltmarrow_beacon_burned", "knot")
	state.complete_quest("a_light_for_saltmarrow")
	state.add_item("dunstans_gull")
	assert_false(play_dialogue(_db, state, "dunstans_stool", []).contains("whittled gull"), "not while you hold it")
	state.remove_item("dunstans_gull")
	assert_true(play_dialogue(_db, state, "dunstans_stool", []).contains("whittled gull"))


func test_dunstans_stool_after_the_gull_burn_names_no_one() -> void:
	var state := _state("gull")
	state.set_flag("saltmarrow_mara_told_of_dunstan", true)
	var text := play_dialogue(_db, state, "dunstans_stool", [])
	assert_true(text.contains("Two cups"))
	assert_false(text.contains("Dunstan"), "the burned memory is gone from the description too")


func test_drying_nets_have_no_first_knot_after_the_knot_burn() -> void:
	assert_true(play_dialogue(_db, _state("knot"), "drying_nets", []).contains("None of them has a first knot"))
	var text := play_dialogue(_db, _state("gull"), "drying_nets", [])
	assert_true(text.contains("same small, stubborn knot"))
	assert_false(text.contains("first knot"))


func test_pells_lost_things_keep_room_for_the_burned_pebble() -> void:
	var state := _state()
	state.set_flag("saltmarrow_pebble_fate", "given")
	assert_true(play_dialogue(_db, state, "pells_lost_things", []).contains("sits the humming pebble"))
	state.set_flag("saltmarrow_pell_lent_pebble", true)
	state.add_item("humming_pebble")
	assert_true(play_dialogue(_db, state, "pells_lost_things", []).contains("pebble in your pocket"))
	state.remove_item("humming_pebble")
	state.set_flag("saltmarrow_beacon_burned", "pebble")
	state.complete_quest("a_light_for_saltmarrow")
	var text := play_dialogue(_db, state, "pells_lost_things", [])
	assert_true(text.contains("DONT MOVE THE NEST"))
	assert_false(text.contains("humming pebble"))
	assert_false(text.contains("FERRY"))
	state.set_flag("saltmarrow_ferry_lantern_hung", true)
	assert_true(play_dialogue(_db, state, "pells_lost_things", []).contains("FERRY"))


func test_pell_asks_to_come_on_the_ferry_once() -> void:
	var picks := {
		"When the ferry comes, you can come.": "promised",
		"You belong here, Pell. Mara needs you.": "refused",
		"Ask me again when you hear the horn.": "undecided",
	}
	for pick: String in picks:
		var state := _state("knot")
		var offered: Array[String] = []
		play_dialogue(_db, state, "pell", ["Mara's hung a green lantern by her door."], offered)
		assert_false(offered.has("Mara's hung a green lantern by her door."), "hidden before the lantern")
		state.set_flag("saltmarrow_ferry_lantern_hung", true)
		play_dialogue(_db, state, "pell", ["Mara's hung a green lantern by her door.", pick])
		assert_eq(state.get_flag("saltmarrow_pell_ferry_ask"), picks[pick])
		offered.clear()
		play_dialogue(_db, state, "pell", [], offered)
		assert_false(offered.has("Mara's hung a green lantern by her door."), "asked only once (%s)" % pick)


func test_tam_explains_the_fare_and_minds_the_knot() -> void:
	for burned: String in ["knot", "pebble"]:
		var state := _state(burned)
		state.add_item("harbor_token")
		state.set_flag("saltmarrow_ferry_lantern_hung", true)
		var text := play_dialogue(_db, state, "tam", ["Mara's hung the green lantern."])
		assert_true(text.contains("You pay the lanes a deed"))
		assert_eq(text.contains("thank you for the knot"), burned == "knot")


func test_mara_reads_the_sleeve_ember_once() -> void:
	var state := _state("gull")
	state.set_flag("saltmarrow_mara_saw_beacon_lit", true)
	var offered: Array[String] = []
	play_dialogue(_db, state, "mara", [], offered)
	assert_false(offered.has("Show Mara the Keeper's sleeve-ember."))
	state.add_item("keepers_sleeve_ember")
	var text := play_dialogue(_db, state, "mara", ["Show Mara the Keeper's sleeve-ember."])
	assert_true(text.contains("Tidewrights don't love Keepers"))
	assert_true(state.get_flag("saltmarrow_mara_saw_sleeve_ember"))
	offered.clear()
	play_dialogue(_db, state, "mara", [], offered)
	assert_false(offered.has("Show Mara the Keeper's sleeve-ember."))
