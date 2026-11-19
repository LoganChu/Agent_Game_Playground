extends TestCase
## Day 114 — polish pass twenty. An NPC who moves mid-visit to a near spot with a clear way walks there instead of
## fading out and in (Region.walkable_move, NpcActor.walk_to): the one at the old spot walks while the one at the new
## spot waits unseen, then hands over its heading. Too far, over water, seated or on a circuit still fades.

const FLAG := "test_polish_twenty_move"
const FROM := [0.0, 0.0, 9.5]  # Saltmarrow's landing spawn: open ground
const NEAR := [0.0, 0.0, 6.0]
const FAR := [0.0, 0.0, -6.5]  # 16 m: past WALK_REACH
const WET := [0.0, 0.0, 19.0]  # out in the harbor


func _region() -> Region:
	var region := Region.new()
	region.build("saltmarrow")
	return region


func _actors(region: Region, npc: String) -> Array[NpcActor]:
	var out: Array[NpcActor] = []
	for child in region.get_children():
		if child is NpcActor and (child as NpcActor).npc_id == npc and not child.is_queued_for_deletion():
			out.append(child as NpcActor)
	return out


## Adds two placements of `npc` (shown before / after FLAG) to `region`, builds the first, and sets FLAG with an
## animated refresh. Returns the actor that stood at `from`.
func _move(region: Region, npc: String, from: Dictionary, to: Dictionary) -> NpcActor:
	GameState.world.flags[FLAG] = false
	from["npc"] = npc
	from["if"] = "!flag:" + FLAG
	to["npc"] = npc
	to["if"] = "flag:" + FLAG
	region._conditional.append({"kind": "npc", "data": from, "node": null})
	region._conditional.append({"kind": "npc", "data": to, "node": null})
	region.refresh_conditional(false)
	var before := _actors(region, npc)
	assert_eq(before.size(), 1, npc + " stands at the first spot")
	GameState.world.flags[FLAG] = true
	region.refresh_conditional(true)
	# Out of the tree _ready never runs: build the bodies as entering the tree would.
	for actor in _actors(region, npc):
		if actor.get_node_or_null("Body") == null:
			actor._ready()
	return before[0] if not before.is_empty() else null


func _setup() -> ContentDatabase:
	var saved := Content.db
	if Content.db.game.is_empty():
		Content.db = load_content()
	return saved


func _teardown(region: Region, saved: ContentDatabase) -> void:
	GameState.world.flags.erase(FLAG)
	region.free()
	Content.db = saved


func test_the_ground_decides_where_a_walk_can_go() -> void:
	var saved := _setup()
	var region := _region()
	var from := region.place(FROM)
	assert_false(region.walk_ground_clear(from, region.place(NEAR)).is_empty(), "the landing's open ground")
	assert_true(region.walkable_move(from, region.place(NEAR)), "out of the tree, the ground alone decides")
	assert_true(region.walk_ground_clear(from, region.place(FAR)).is_empty(), "past WALK_REACH")
	assert_true(region.walk_ground_clear(from, region.place(WET)).is_empty(), "nobody walks into the harbor")
	assert_true(region.walk_ground_clear(from, from + Vector3(0.6, 0, 0)).is_empty(), "a swap in place isn't a walk")
	var points := region.walk_ground_clear(from, region.place(NEAR))
	var last := points[points.size() - 1]
	var short := Vector2(last.x - region.place(NEAR).x, last.z - region.place(NEAR).z).length()
	assert_true(short >= Region.WALK_PROBE_SHORT - 0.01, "the probe stops short of the far spot (%.2f)" % short)
	var slab := Region.new()
	assert_false(slab.walkable_move(Vector3.ZERO, Vector3(4, 0, 0)), "a slab region never walks")
	slab.free()
	_teardown(region, saved)


func test_a_near_move_walks_and_hands_over() -> void:
	var saved := _setup()
	var region := _region()
	var walker := _move(region, "corran", {"position": FROM, "rotation_y": 90.0}, {"position": NEAR, "rotation_y": 0.0})
	assert_true(walker.is_walking(), "the one at the old spot walks")
	assert_false(walker.is_leaving(), "rather than fading")
	assert_eq(walker.opacity(), 1.0)
	assert_true(walker.can_interact(), "and can be spoken to on the way")
	var waiting := _actors(region, "corran").filter(func(a: NpcActor) -> bool: return a != walker)
	assert_eq(waiting.size(), 1, "one waits at the new spot")
	var arrival: NpcActor = waiting[0]
	assert_true(arrival.is_awaiting_walker(), "waiting")
	assert_eq(arrival.opacity(), 0.0, "unseen")
	assert_false(arrival.can_interact(), "and out of play")
	var start := walker.position
	var walked := walker.step_walk(0.5)
	assert_true(absf(walked - NpcActor.WALK_SPEED * 0.5) < 0.01, "walks at WALK_SPEED (%.2f)" % walked)
	assert_true(walker.position.z < start.z, "towards the new spot")
	assert_true(absf(walker.position.y - region.ground_y(walker.position.x, walker.position.z)) < 0.01, "on the ground")
	var heading := walker.rotation.y
	assert_true(absf(angle_difference(heading, deg_to_rad(90.0))) > 0.05, "turning to the way (%.2f)" % heading)
	# Held while talking, as a circuit walker is.
	walker._talking = true
	assert_eq(walker.step_walk(0.5), 0.0, "holds while talking")
	walker._talking = false
	for i in 40:
		if not walker.is_walking():
			break
		walker.step_walk(0.25)
	assert_false(walker.is_walking(), "arrived")
	assert_true(walker.is_queued_for_deletion(), "the walker hands over and goes")
	assert_false(arrival.is_awaiting_walker(), "the one at the new spot takes over")
	assert_eq(arrival.opacity(), 1.0, "shown at once")
	assert_true(arrival.can_interact(), "and in play")
	var yaw := arrival.rotation.y + arrival.body_yaw()
	assert_true(absf(angle_difference(yaw, walker.rotation.y + walker.body_yaw())) < 0.01, "facing the way it walked")
	for i in 60:
		arrival._process(0.1)
	assert_true(absf(angle_difference(arrival.body_yaw(), 0.0)) < 0.01, "then turns to its placed facing (%.3f)" % arrival.body_yaw())
	_teardown(region, saved)


func test_too_far_wet_seated_or_circling_still_fades() -> void:
	var saved := _setup()
	var cases := [
		["too far", {"position": FROM}, {"position": FAR}],
		["into the harbor", {"position": FROM}, {"position": WET}],
		["seated", {"position": FROM, "idle": "sit"}, {"position": NEAR}],
		["onto a circuit", {"position": FROM}, {"position": NEAR, "circuit": {"center": [0, 4], "radius": 2.0}}],
	]
	for case: Array in cases:
		var region := _region()
		var gone := _move(region, "corran", case[1], case[2])
		assert_false(gone.is_walking(), str(case[0]) + ": no walk")
		assert_true(gone.is_leaving(), str(case[0]) + ": fades out")
		_teardown(region, saved)
		saved = _setup()
	Content.db = saved


func test_the_new_spot_going_first_fades_the_walker() -> void:
	var saved := _setup()
	var region := _region()
	var walker := _move(region, "corran", {"position": FROM}, {"position": NEAR})
	walker.step_walk(0.5)
	# The story moves on again before the walk is done: the placement walked to goes away.
	GameState.world.flags[FLAG] = false
	region.refresh_conditional(true)
	walker.step_walk(0.1)
	assert_false(walker.is_walking(), "stops walking")
	assert_true(walker.is_leaving(), "and fades")
	var back := _actors(region, "corran").filter(func(a: NpcActor) -> bool: return not a.is_leaving() and a != walker)
	assert_eq(back.size(), 1, "the first spot's actor comes back")
	_teardown(region, saved)


func test_unanimated_still_cuts() -> void:
	var saved := _setup()
	var region := _region()
	GameState.world.flags[FLAG] = false
	var from := {"npc": "corran", "position": FROM, "if": "!flag:" + FLAG}
	var to := {"npc": "corran", "position": NEAR, "if": "flag:" + FLAG}
	region._conditional.append({"kind": "npc", "data": from, "node": null})
	region._conditional.append({"kind": "npc", "data": to, "node": null})
	region.refresh_conditional(false)
	GameState.world.flags[FLAG] = true
	region.refresh_conditional(false)
	var now := _actors(region, "corran")
	assert_eq(now.size(), 1, "a load or a build cuts")
	assert_false(now[0].is_awaiting_walker() or now[0].is_walking(), "no walk")
	_teardown(region, saved)
