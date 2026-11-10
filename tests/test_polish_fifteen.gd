extends TestCase
## Day 94 — polish pass fifteen. Cindermoor's story clock lives in one place (data/clocks.json, StoryClock) and
## its regions name a time instead of repeating the flags in order; an NPC who comes or goes mid-visit fades in or
## out instead of cutting (the Provost on the niche step once the box closes).

const CINDERMOOR_OUTSIDE: Array[String] = ["cindermoor_boat_stair", "cindermoor_long_steps", "cindermoor_spire_foot"]
const CLOCK_FLAGS: Array[String] = ["cindermoor_chapter_up", "cindermoor_chapter_sat", "cindermoor_morning"]


func _actors(region: Region, npc: String) -> Array[NpcActor]:
	var out: Array[NpcActor] = []
	for child in region.get_children():
		if child is NpcActor and (child as NpcActor).npc_id == npc and not child.is_queued_for_deletion():
			out.append(child as NpcActor)
	return out


func test_the_cindermoor_clock_reads_the_story_in_order() -> void:
	assert_true(StoryClock.has_clock("cindermoor"))
	assert_eq(StoryClock.default_time("cindermoor"), "day")
	assert_eq(StoryClock.times("cindermoor"), ["spire_lit", "morning", "night", "dusk", "day"] as Array[String], "Day 96: spire_lit")
	var world := WorldState.new()
	assert_eq(StoryClock.now("cindermoor", world), "day", "before the chapter comes up")
	var expected := ["dusk", "night", "morning"]
	for i in CLOCK_FLAGS.size():
		world.set_flag(CLOCK_FLAGS[i], true)
		assert_eq(StoryClock.now("cindermoor", world), expected[i], "after " + CLOCK_FLAGS[i])
	world.set_flag("cindermoor_cradle_choice", "dark")
	assert_eq(StoryClock.now("cindermoor", world), "morning", "a dark Spire keeps the morning")
	world.set_flag("cindermoor_cradle_choice", "lit")
	assert_eq(StoryClock.now("cindermoor", world), "spire_lit", "the Spire lit (Day 96)")
	assert_eq(StoryClock.now("no_such_clock", world), "")


func test_every_cindermoor_outside_region_keeps_the_one_clock() -> void:
	var db := load_content()
	for id in CINDERMOOR_OUTSIDE:
		var region: Dictionary = db.get_region(id)
		assert_eq(str(region.get("clock", "")), "cindermoor", id)
		for block: String in ["fog", "light"]:
			var times: Array = []
			for override: Dictionary in (region[block] as Dictionary).get("overrides", []):
				assert_false(override.has("if"), "%s %s: a time, not the flags again" % [id, block])
				times.append(override.get("time"))
			times.sort()
			assert_eq(times, ["dusk", "morning", "night", "spire_lit"], "%s %s gives every time its look" % [id, block])


func test_the_crown_darkens_and_lightens_with_the_clock() -> void:
	var db := load_content()
	var foot: Dictionary = db.get_region("cindermoor_spire_foot")
	var world := WorldState.new()
	var energy := func() -> float: return float(RegionMood.light(foot, world)["sun_energy"])
	assert_true(absf(energy.call() - 0.4) < 0.001, "day")
	world.set_flag("cindermoor_chapter_up", true)
	assert_true(absf(energy.call() - 0.32) < 0.001, "dusk")
	assert_eq(str(RegionMood.fog(foot, world)["color"]), "#90939A", "dusk fog")
	world.set_flag("cindermoor_chapter_sat", true)
	assert_true(absf(energy.call() - 0.2) < 0.001, "night")
	assert_eq(str(RegionMood.fog(foot, world)["color"]), "#737987", "night fog")
	world.set_flag("cindermoor_morning", true)
	assert_true(absf(energy.call() - 0.36) < 0.001, "morning")
	# The order the overrides are listed in no longer matters: the clock decides.
	var shuffled: Dictionary = foot.duplicate(true)
	(shuffled["light"]["overrides"] as Array).reverse()
	assert_true(absf(float(RegionMood.light(shuffled, world)["sun_energy"]) - 0.36) < 0.001, "still morning reversed")
	# A region without a clock ignores a time it can't read.
	var no_clock: Dictionary = shuffled.duplicate(true)
	no_clock.erase("clock")
	assert_true(absf(float(RegionMood.light(no_clock, world)["sun_energy"]) - 0.4) < 0.001, "base light")


func test_the_validator_keeps_clock_times_honest() -> void:
	var db := load_content()
	var boat: Dictionary = db.regions["cindermoor_boat_stair"]
	(boat["fog"]["overrides"] as Array).append({"time": "noon", "density": 0.02})
	(boat["light"]["overrides"] as Array).append({"time": "day", "sun_energy": 1.0})
	var steps: Dictionary = db.regions["cindermoor_long_steps"]
	(steps["fog"]["overrides"] as Array).append({"time": "dusk", "if": "flag:cindermoor_chapter_up"})
	(steps["light"]["overrides"] as Array).append({"time": "night", "sun_energy": 0.1})
	var saltmarrow: Dictionary = db.regions["saltmarrow"]
	if not saltmarrow.has("fog"):
		saltmarrow["fog"] = {}
	saltmarrow["fog"]["overrides"] = [{"time": "night", "density": 0.02}]
	var validator := ContentValidator.new(db)
	assert_false(validator.validate())
	var report := validator.report()
	assert_true(report.contains("fog override time 'noon' is not one of clock 'cindermoor''s times"), report)
	assert_true(report.contains("light override time 'day' is not one of clock 'cindermoor''s times"), report)
	assert_true(report.contains("fog override needs an 'if' condition or a story-clock 'time' (one, not both)"), report)
	assert_true(report.contains("light overrides name time 'night' twice"), report)
	assert_true(report.contains("region saltmarrow: fog override names time 'night' but the region has no 'clock'"), report)


func test_an_npc_who_moves_mid_visit_fades_rather_than_cuts() -> void:
	var region := Region.new()
	var flag := "test_polish_fifteen_move"
	GameState.world.flags[flag] = false
	var stand := {"npc": "corran", "position": [2, 0, 3], "if": "!flag:" + flag}
	var swap := {"npc": "corran", "position": [2.3, 0, 3], "if": "flag:" + flag}
	var away := {"npc": "hild", "position": [0, 0, 0], "if": "!flag:" + flag}
	var there := {"npc": "hild", "position": [8, 0, 0], "if": "flag:" + flag}
	for entry: Dictionary in [stand, swap, away, there]:
		region._conditional.append({"kind": "npc", "data": entry, "node": null})
	region.refresh_conditional(false)  # as Region.build does
	for npc: String in ["corran", "hild"]:
		assert_eq(_actors(region, npc).size(), 1)
		assert_eq(_actors(region, npc)[0].opacity(), 1.0, npc + " is there from the start: no fade")
	var hild_before := _actors(region, "hild")[0]
	GameState.world.flags[flag] = true
	region.refresh_conditional(true)
	var corran := _actors(region, "corran")
	assert_eq(corran.size(), 1)
	assert_eq(corran[0].opacity(), 1.0, "a swap in place doesn't fade")
	assert_true(hild_before.is_leaving(), "the Hild who walked off fades out")
	assert_false(hild_before.can_interact(), "and can't be talked to while she does")
	var arrivals := _actors(region, "hild").filter(func(a: NpcActor) -> bool: return not a.is_leaving())
	assert_eq(arrivals.size(), 1)
	var hild: NpcActor = arrivals[0]
	assert_true(hild.position.x > 7.0, "at her new spot")
	assert_eq(hild.opacity(), 0.0, "fading in from nothing")
	hild._process(NpcActor.FADE_SECONDS * 0.5)
	assert_true(hild.opacity() > 0.4 and hild.opacity() < 0.6, "halfway in: %s" % hild.opacity())
	hild._process(NpcActor.FADE_SECONDS)
	assert_eq(hild.opacity(), 1.0, "solid")
	hild_before._process(NpcActor.FADE_SECONDS * 0.5)
	assert_true(hild_before.opacity() > 0.4 and not hild_before.is_queued_for_deletion(), "halfway out")
	hild_before._process(NpcActor.FADE_SECONDS)
	assert_true(hild_before.is_queued_for_deletion(), "gone once faded")
	# Unanimated (building a region, loading) never fades.
	GameState.world.flags[flag] = false
	region.refresh_conditional(false)
	var back := _actors(region, "hild").filter(func(a: NpcActor) -> bool: return not a.is_leaving())
	assert_true(back.size() == 1 and back[0].opacity() == 1.0, "a cut when not animated")
	GameState.world.flags.erase(flag)
	region.free()


func test_a_second_speaker_joins_the_shot() -> void:
	var saved_db := Content.db
	if Content.db.game.is_empty():
		Content.db = load_content()
	var player := Player.new()
	player._ready()
	var arm := player.find_child("CameraArm", true, false) as SpringArm3D
	GameState.input_locked = true
	var hild := Vector3(2.0, 0.0, -2.0)
	var provost := Vector3(-1.5, 0.0, -3.0)
	player.frame_towards(hild)
	for i in 20:
		player._update_framing(0.1)
	assert_eq(player.framed_count(), 1)
	assert_true(is_equal_approx(arm.spring_length, Player.DIALOGUE_DISTANCE), "one: the usual distance")
	assert_false(player.frame_also(hild + Vector3(0.2, 0, 0)), "the one already framed doesn't count twice")
	assert_false(player.frame_also(Vector3(20, 0, 0)), "someone across the region isn't pulled in")
	assert_true(player.frame_also(provost), "the second speaker joins")
	assert_eq(player.framed_count(), 2)
	var before := player.view_yaw()
	player._update_framing(0.05)
	var step := absf(angle_difference(before, player.view_yaw()))
	assert_true(step > 0.0 and step < 0.2, "eases round, no cut (%.3f)" % step)
	for i in 40:
		player._update_framing(0.1)
	assert_true(arm.spring_length > Player.DIALOGUE_DISTANCE + 0.5, "backs off to fit both (%.2f)" % arm.spring_length)
	# Where the camera stands (on the ground plane): back from the slid pivot along the view, by the arm's reach.
	var forward := Basis(Vector3.UP, player.view_yaw()) * Vector3(0, 0, -1)
	var pivot := (player.find_child("CameraYaw", true, false) as Node3D).position
	var camera := Vector3(pivot.x, 0, pivot.z) - forward * arm.spring_length * cos(deg_to_rad(Player.DIALOGUE_PITCH))
	for at: Vector3 in [hild, provost]:
		var dir := (at - camera).normalized()
		assert_true(forward.dot(dir) > cos(deg_to_rad(40.0)), "both well inside the view (%s: %.0f°)" \
				% [at, rad_to_deg(acos(forward.dot(dir)))])
	GameState.input_locked = false
	for i in 20:
		player._update_framing(0.1)
	assert_eq(player.framed_count(), 0, "the shot forgets them once the box closes")
	assert_true(is_equal_approx(arm.spring_length, Player.CAMERA_DISTANCE), "full distance again")
	player.free()
	Content.db = saved_db
