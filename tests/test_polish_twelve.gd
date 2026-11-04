extends TestCase
## Day 84, polish pass twelve: nameplates hide under every modal; the road warns before it forgets
## (a fog veil and "Which way was it?"); the validator remembers each region's ground walk (the test
## suite re-validates all content a few dozen times); the long steps' cresset road runs along the
## grid (no sawtooth) and the far Spire stands on the crown road's line instead of floating.


func test_every_nameplate_hides_while_a_modal_holds_input() -> void:
	var db := load_content()
	var actor := NpcActor.new()
	actor.setup("tobin", db.get_npc("tobin"))
	actor._build_body()
	var was := GameState.input_locked
	GameState.input_locked = false
	actor._process(0.05)
	assert_true(actor.is_nameplate_shown(), "free to walk: the name shows")
	# Not talking to him: the act card (or a menu) holds input over the world.
	GameState.input_locked = true
	actor._process(0.05)
	assert_false(actor.is_nameplate_shown(), "the card's shade: no name showing through it")
	GameState.input_locked = false
	actor._process(0.05)
	assert_true(actor.is_nameplate_shown(), "the card gone: the name is back")
	GameState.input_locked = was
	actor.free()


func test_the_lost_cue_rises_before_the_road_forgets() -> void:
	var half := Greying.FORGET_DEPTH * 0.5
	assert_eq(GreyingWalker.lost_cue(0.0, 0.0), 0.0, "on a remembered road: nothing")
	assert_eq(GreyingWalker.lost_cue(half, 0.0), 0.0, "where the way stops being remembered: still nothing")
	var unsure := GreyingWalker.lost_cue(half * 1.5, 0.0)
	assert_true(unsure > 0.0 and unsure < GreyingWalker.LOST_HINT, "unsure of the way: a hint (%.2f)" % unsure)
	assert_eq(GreyingWalker.lost_cue(Greying.FORGET_DEPTH, 0.0), GreyingWalker.LOST_HINT, "lost, no time yet: the hint")
	var mid := GreyingWalker.lost_cue(1.0, Greying.FORGET_SECONDS * 0.5)
	assert_true(mid > GreyingWalker.LOST_HINT and mid < 1.0, "half the time gone: rising (%.2f)" % mid)
	assert_eq(GreyingWalker.lost_cue(1.0, Greying.FORGET_SECONDS), 1.0, "about to be turned back: full")
	# Found the way again: the time eases off and the cue with it, never below what the ground says.
	assert_true(GreyingWalker.lost_cue(0.0, Greying.FORGET_SECONDS * 0.25) < mid, "easing off once found")


func test_the_hud_shows_the_lost_cue() -> void:
	var hud := Hud.new()
	hud._ready()
	var line := hud.get("_lost_line") as Label
	assert_false(line.visible, "hidden to begin with")
	assert_eq(line.text, Hud.LOST_TEXT)
	hud.set_lost(0.5)
	assert_true(line.visible, "shown as the way goes")
	assert_true(absf(hud.lost_shown() - 0.5) < 0.001, "the veil at half (%.2f)" % hud.lost_shown())
	hud.set_lost(2.0)
	assert_true(absf(hud.lost_shown() - 1.0) < 0.001, "clamped to full")
	hud.set_lost(0.0)
	assert_false(line.visible, "gone once the way is found")
	assert_eq(hud.lost_shown(), 0.0)
	hud.free()


func test_the_validator_walks_each_ground_once() -> void:
	var db := load_content()
	var first := ContentValidator.new(db)
	assert_true(first.validate(), first.report())
	var walks := ContentValidator.ground_walks
	var again := ContentValidator.new(db)
	assert_true(again.validate(), again.report())
	assert_eq(ContentValidator.ground_walks, walks, "unchanged content: no region walked again")
	# Strand an NPC on Gull's Head: that region alone is walked again, and the finding is reported.
	var region: Dictionary = db.regions["gulls_head"]
	var saved: Dictionary = region.duplicate(true)
	(region["npcs"][0] as Dictionary)["position"] = [999.0, 0.0, 999.0]
	var broken := ContentValidator.new(db)
	assert_false(broken.validate(), "the stranded NPC is caught")
	assert_eq(ContentValidator.ground_walks, walks + 1, "only the edited region walked")
	assert_true(broken.report().contains("is outside ground.bounds"), broken.report())
	# Remembered findings are still findings.
	var remembered := ContentValidator.new(db)
	assert_false(remembered.validate(), "still caught from the memo")
	assert_eq(ContentValidator.ground_walks, walks + 1, "not walked a third time")
	assert_eq(remembered.errors, broken.errors, "the same errors")
	db.regions["gulls_head"] = saved
	var fixed := ContentValidator.new(db)
	assert_true(fixed.validate(), fixed.report())


func test_the_long_steps_road_runs_along_the_grid() -> void:
	var db := load_content()
	var region := db.get_region("cindermoor_long_steps")
	var legs := 0
	for c: Dictionary in region.get("cressets", []):
		var road: Array = c.get("road", [])
		for i in range(1, road.size()):
			var a := Vector2(float(road[i - 1][0]), float(road[i - 1][1]))
			var b := Vector2(float(road[i][0]), float(road[i][1]))
			if a.distance_to(b) < 6.0:
				continue  # the turns: short enough not to saw
			legs += 1
			# A shallow slant crosses the triangle rows one at a time and saws; along an axis, or a
			# real diagonal (the switchbacks' turns), it doesn't.
			var d := (b - a).abs()
			var slant := minf(d.x, d.y) / maxf(d.x, d.y)
			assert_true(slant < 0.001 or slant >= 0.5,
					"cresset %s: the %.0f m leg %s → %s runs along the grid or turns properly (slant %.2f saws on the 1 m cells)" \
					% [c["id"], a.distance_to(b), a, b, slant])
	assert_true(legs >= 8, "the long legs were checked (%d)" % legs)


func test_the_far_spire_stands_on_the_crown_road() -> void:
	var db := load_content()
	var region := db.get_region("cindermoor_long_steps")
	var spire: Dictionary = {}
	for prop: Dictionary in region.get("props", []):
		if str(prop.get("model", "")).ends_with("hearthspire_far.glb"):
			spire = prop
	assert_false(spire.is_empty(), "the far Spire is there")
	var pos := JsonUtil.to_vector3(spire["position"])
	assert_true(pos.y <= 5.8, "its foot below the top terrace's edge, not floating on the fog (y %.1f)" % pos.y)
	var crown := Vector3.ZERO
	for exit: Dictionary in region.get("exits", []):
		if exit.get("to") == "cindermoor_spire_foot":
			crown = JsonUtil.to_vector3(exit["position"])
	assert_true(absf(pos.x - crown.x) < 8.0 and pos.z < crown.z - 30.0, "beyond the crown exit, on its line: %s" % pos)
