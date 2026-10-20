extends TestCase
## Day 54 polish pass seven: the ember drain eases with the fog when a lantern is lit or put out
## (it followed the new light at once while the fog took 4 s), Hob and Bram's tally board notice
## Ottie home from the Northing, and the old road's flanks fall to slate far below rather than a
## pale green plain.

const BYE := "Goodbye."

var _db: ContentDatabase


func _content() -> ContentDatabase:
	if _db == null:
		_db = load_content()
	return _db


## Thornwold lit (by `burned`), Hob paid and come in to the camp, Ottie home from the Northing.
func _ottie_home(burned: String = "salt_row") -> WorldState:
	var state := fresh_state(_content())
	for flag: String in ["intro_seen", "thornwold_landed", "thornwold_met_bram", "thornwold_met_hob", "thornwold_hob_paid",
			"thornwold_met_lamp", "thornwold_ladder_stood", "thornwold_ridge_reached", "thornwold_hob_came_in",
			"thornwold_old_road_reached", "thornwold_met_ottie"]:
		state.set_flag(flag, true)
	state.set_flag("thornwold_beacon_burned", burned)
	state.set_flag("thornwold_" + ("salt_row" if burned == "salt_row" else "boots") + "_away", true)
	state.complete_quest("a_light_for_thornwold")
	state.set_flag("thornwold_northing", "lit")
	state.complete_quest("the_northing")
	return state


func _hob(state: WorldState) -> String:
	var offered: Array[String] = []
	return play_dialogue(_content(), state, "hob", [BYE], offered)


func _board(state: WorldState) -> String:
	return play_dialogue(_content(), state, "bram_tally_board", [])


func test_the_ember_drain_eases_with_a_relit_lantern() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	var fog: Dictionary = {"rect": [-6, -6, 6, 6], "falloff": 1.0, "strength": 1.0}
	var lamp: Dictionary = {"ellipse": [0, 0, 3, 3], "falloff": 1.0, "clear": true}
	var dark: Array[Dictionary] = [fog]
	var lit: Array[Dictionary] = [fog, lamp]
	var region := Region.new()
	root.add_child(region)
	region.greying_areas = lit
	region._ease_greying_depth(dark, true)
	var deep := Greying.depth_at(dark, Vector2.ZERO)
	assert_true(deep > 0.5, "unlit, the centre is deep fog (%.2f)" % deep)
	assert_eq(Greying.depth_at(lit, Vector2.ZERO), 0.0, "lit, it's clear under the lantern")
	assert_eq(region.greying_settled(), 0.0, "an animated change starts from the old fog")
	assert_true(is_equal_approx(region.greying_depth(0, 0), deep), "the drain starts where the fog was")
	region._process(GreyingFog.FADE_SECONDS * 0.5)
	var halfway := region.greying_depth(0, 0)
	assert_true(halfway > 0.0 and halfway < deep, "halfway through the fade it's halfway clear (%.2f)" % halfway)
	region._process(GreyingFog.FADE_SECONDS)
	assert_eq(region.greying_settled(), 1.0, "settled with the fog")
	assert_false(region.is_processing(), "and stops ticking")
	region._ease_greying_depth(dark, true)
	region._ease_greying_depth(dark, false)
	assert_eq(region.greying_settled(), 1.0, "an instant change (region load) is settled at once")
	assert_eq(region.greying_depth(0, 0), 0.0, "settled, the drain follows the new light")
	region.free()


func test_hob_hears_ottie_is_home() -> void:
	var lines := _hob(_ottie_home())
	assert_true(lines.contains("Ottie's home."), "salt-row: Hob knows Ottie")
	assert_true(lines.contains("In his boots."), "his boots were still on the seat")
	assert_true(lines.contains("Three to come."), "Hob counts him in")
	assert_false(lines.contains("Charcoal man"), "not a stranger")

	var barefoot := _ottie_home()
	barefoot.set_flag("thornwold_boots_away", true)
	barefoot.add_item("otties_boots")
	lines = _hob(barefoot)
	assert_true(lines.contains("You've got his boots."), "the player still carries them")
	assert_false(lines.contains("In his boots."), "")

	var stayed := _ottie_home()
	stayed.set_flag("thornwold_hob_came_in", false)
	stayed.set_flag("thornwold_hob_ladder", "stayed")
	lines = _hob(stayed)
	assert_true(lines.contains("I crossed him through"), "at the bottom of the road, Hob crosses him off the stick")
	assert_false(lines.contains("Ottie's home."), "the plain homecoming lines are for Hob at the camp or clearing")

	lines = _hob(_ottie_home("boots"))
	assert_true(lines.contains("Charcoal man"), "boots burned: Ottie is a stranger on the next seat")
	assert_false(lines.contains("Ottie"), "and Hob never names him")

	var before := _ottie_home()
	before.set_flag("thornwold_northing", "")
	lines = _hob(before)
	assert_false(lines.contains("Ottie") or lines.contains("Charcoal man"), "nothing before the Northing is lit")
	var carried := _ottie_home()
	carried.set_flag("thornwold_northing", "carried")
	assert_false(_hob(carried).contains("Ottie"), "carried down the steps, Ottie never comes home")


func test_the_tally_board_counts_two_colliers() -> void:
	assert_true(_board(_ottie_home()).contains("in pairs now"), "two carts down the lanterns")
	var gone := _ottie_home()
	gone.set_flag("thornwold_hob_came_in", false)
	gone.set_flag("thornwold_hob_ladder", "gone")
	var lines := _board(gone)
	assert_true(lines.contains("a different hand"), "Hob down on the far shore: Ottie brings the loads alone")
	assert_false(lines.contains("in pairs now"), "")

	var stayed := _ottie_home()
	stayed.set_flag("thornwold_hob_ladder", "stayed")
	lines = _board(stayed)
	assert_true(lines.contains("the first of them crossed through"), "Hob's stick of four, one crossed off")
	assert_false(lines.contains("and nothing after them"), "one stick line, not two")
	stayed.set_flag("thornwold_northing", "carried")
	lines = _board(stayed)
	assert_true(lines.contains("and nothing after them"), "nobody home: the stick stays uncrossed")
	assert_false(lines.contains("in pairs now"), "")


func test_the_old_road_falls_away_to_slate() -> void:
	var ground: Dictionary = _content().get_region("thornwold_old_road")["ground"]
	var colors: Dictionary = ground["colors"]
	assert_eq(str(colors["shore"]), "slate", "the flanks are rock, not turf")
	assert_eq(str(colors["seabed"]), "slate", "")
	var field := TerrainField.from_data(ground, -INF)
	var spine := field.height_at(-1.0, 0.0)
	var flank := field.height_at(-16.0, 0.0)
	assert_true(spine - flank > 20.0, "a long drop off the spine (%.1f m)" % (spine - flank))
