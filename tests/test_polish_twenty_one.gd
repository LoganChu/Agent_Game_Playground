extends TestCase
## Day 117 — polish pass twenty-one. A walk between placements whose straight way is blocked bends round what's in
## the way (Region.walk_route / route_between) instead of fading: once to one side, or twice round a longer obstacle,
## never more than WALK_ROUTE_STRETCH times the straight distance, a bent leg clear to a body's width. The walker
## passes its bend points in order (NpcActor.walk_to's `via`) and hands over at the new spot as before.
## The test runner has no physics world, so the obstacles here are made up: `clear` callables standing in for rays.

const FLAG := "test_polish_twenty_one_move"
const FROM := [0.0, 0.0, 9.5]  # Saltmarrow's landing spawn: open ground
const TO := [0.0, 0.0, 3.5]  # 6 m up the landing


func _setup() -> ContentDatabase:
	var saved := Content.db
	if Content.db.game.is_empty():
		Content.db = load_content()
	return saved


func _region() -> Region:
	var region := Region.new()
	region.build("saltmarrow")
	return region


## Distance on the ground plane from point `p` to the segment `a`–`b`.
static func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## A `clear` callable for Region.route_between: a round obstacle at `center` of radius `radius`; a bent leg must pass
## it by Region.WALK_ROUTE_HALF_WIDTH more. Every leg asked about is appended to `asked`.
static func _round_obstacle(center: Vector2, radius: float, asked: Array) -> Callable:
	return func(a: Vector3, b: Vector3, _last: bool, bent: bool) -> bool:
		asked.append([a, b, bent])
		var margin := Region.WALK_ROUTE_HALF_WIDTH if bent else 0.0
		return _to_segment(center, _flat(a), _flat(b)) > radius + margin


## A `clear` callable: an axis-aligned box (x0..x1, z0..z1) no leg may cross (a bent leg kept its half-width off).
static func _box_obstacle(x0: float, x1: float, z0: float, z1: float) -> Callable:
	return func(a: Vector3, b: Vector3, _last: bool, bent: bool) -> bool:
		var m := Region.WALK_ROUTE_HALF_WIDTH if bent else 0.0
		for i in 41:
			var p := a.lerp(b, i / 40.0)
			if p.x > x0 - m and p.x < x1 + m and p.z > z0 - m and p.z < z1 + m:
				return false
		return true


func _assert_route_clear(route: Array[Vector3], from: Vector3, clear: Callable, label: String) -> void:
	var at := from
	for i in route.size():
		assert_true(clear.call(at, route[i], i == route.size() - 1, route.size() > 1), "%s: leg %d is clear" % [label, i])
		at = route[i]


func test_a_clear_way_is_straight() -> void:
	var saved := _setup()
	var region := _region()
	var from := region.place(FROM)
	var to := region.place(TO)
	assert_false(region.walk_ground_clear(from, to).is_empty(), "the landing's open ground")
	var route := region.walk_route(from, to)
	assert_eq(route.size(), 1, "out of the tree the ground alone decides: straight")
	assert_true(route[0].is_equal_approx(to), "and the last point is the new spot")
	assert_true(region.walk_route(from, from + Vector3(0.5, 0, 0)).is_empty(), "a swap in place isn't a walk")
	assert_true(region.walk_route(from, region.place([0.0, 0.0, -6.5])).is_empty(), "past WALK_REACH")
	var slab := Region.new()
	assert_true(slab.walk_route(Vector3.ZERO, Vector3(4, 0, 0)).is_empty(), "a slab region never walks")
	slab.free()
	region.free()
	Content.db = saved


func test_a_round_obstacle_is_walked_round_with_one_bend() -> void:
	var saved := _setup()
	var region := _region()
	var from := region.place(FROM)
	var to := region.place(TO)
	var asked: Array = []
	var clear := _round_obstacle(Vector2(0.0, 6.5), 1.6, asked)
	var route := region.route_between(from, to, clear)
	assert_eq(route.size(), 2, "one bend, then the new spot")
	assert_true(route[1].is_equal_approx(to), "ending at the new spot")
	_assert_route_clear(route, from, clear, "round")
	var bend := route[0]
	assert_true(absf(bend.x) >= Region.WALK_ROUTE_OFFSETS[0] - 0.01, "the bend is off to one side (%.2f)" % bend.x)
	assert_true(absf(bend.y - region.ground_y(bend.x, bend.z)) < 0.01, "and on the ground")
	assert_false(asked.is_empty() or asked[0][2], "the straight way was asked first, without the body's width")
	var length := Vector2(bend.x - from.x, bend.z - from.z).length() + Vector2(to.x - bend.x, to.z - bend.z).length()
	assert_true(length <= from.distance_to(to) * Region.WALK_ROUTE_STRETCH, "within the stretch (%.2f)" % length)
	# The shortest clear route wins: a smaller obstacle is passed with a nearer bend.
	var nearer := region.route_between(from, to, _round_obstacle(Vector2(0.0, 6.5), 0.5, []))
	assert_eq(nearer.size(), 2)
	assert_true(absf(nearer[0].x) < absf(bend.x), "a smaller obstacle bends nearer (%.2f < %.2f)" % [absf(nearer[0].x), absf(bend.x)])
	region.free()
	Content.db = saved


func test_a_long_obstacle_takes_two_bends() -> void:
	var saved := _setup()
	var region := _region()
	var from := region.place(FROM)
	var to := region.place(TO)
	# A long box down the middle of the way: one bend wide enough to clear it is too long a way round.
	var clear := _box_obstacle(-1.0, 1.0, 4.5, 8.5)
	var route := region.route_between(from, to, clear)
	assert_eq(route.size(), 3, "two bends, then the new spot")
	_assert_route_clear(route, from, clear, "two bends")
	assert_true(signf(route[0].x) == signf(route[1].x), "both bends on the same side")
	region.free()
	Content.db = saved


func test_no_way_round_within_the_stretch_still_fades() -> void:
	var saved := _setup()
	var region := _region()
	var from := region.place(FROM)
	var to := region.place(TO)
	# A wall right across the landing, wider than any bend reaches.
	assert_true(region.route_between(from, to, _box_obstacle(-8.0, 8.0, 6.0, 7.0)).is_empty(), "a wall across: no route")
	assert_true(region.route_between(from, to, func(_a: Vector3, _b: Vector3, _l: bool, _bent: bool) -> bool:
		return false).is_empty(), "nothing clear: no route")
	region.free()
	Content.db = saved


func test_the_walker_passes_its_bends_in_order() -> void:
	var saved := _setup()
	var region := _region()
	GameState.world.flags[FLAG] = false
	region._conditional.append({"kind": "npc", "data": {"npc": "corran", "position": FROM, "if": "!flag:" + FLAG}, "node": null})
	region._conditional.append({"kind": "npc", "data": {"npc": "corran", "position": TO, "if": "flag:" + FLAG}, "node": null})
	region.refresh_conditional(false)
	GameState.world.flags[FLAG] = true
	region.refresh_conditional(true)
	var walker: NpcActor = null
	var arrival: NpcActor = null
	for child in region.get_children():
		if child is NpcActor and (child as NpcActor).npc_id == "corran":
			if (child as NpcActor).is_walking():
				walker = child
			elif (child as NpcActor).is_awaiting_walker():
				arrival = child
	assert_true(walker != null and arrival != null, "a walk between the two spots")
	if walker == null or arrival == null:
		GameState.world.flags.erase(FLAG)
		region.free()
		Content.db = saved
		return
	for actor: NpcActor in [walker, arrival]:
		if actor.get_node_or_null("Body") == null:
			actor._ready()
	assert_true(walker.walk_bends().is_empty(), "the straight way out of the tree: no bends")
	# Bend it as walk_route would round something in the way.
	var bends: Array[Vector3] = [region.place([2.5, 0.0, 8.0]), region.place([2.5, 0.0, 5.0])]
	walker.walk_to(arrival, region.ground_y, bends)
	var closest: Array[float] = [INF, INF]
	for i in 200:
		if not walker.is_walking():
			break
		var left := walker.walk_bends().size()
		walker.step_walk(0.1)
		var bend_index := bends.size() - left
		if bend_index < bends.size():
			closest[bend_index] = minf(closest[bend_index], _flat(walker.position).distance_to(_flat(bends[bend_index])))
		assert_true(absf(walker.position.y - region.ground_y(walker.position.x, walker.position.z)) < 0.01, "on the ground")
	assert_false(walker.is_walking(), "arrived")
	assert_true(closest[0] < 0.15 and closest[1] < 0.15, "passed both bends (%.2f, %.2f)" % closest)
	assert_false(arrival.is_awaiting_walker(), "the one at the new spot takes over")
	assert_true(arrival.can_interact(), "in play")
	GameState.world.flags.erase(FLAG)
	region.free()
	Content.db = saved
