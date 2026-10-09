class_name Greying
extends RefCounted
## The Greying as a place: fog areas that drain the Wakebearer's ember (pure logic).
##
## Region data `greying` is a list of areas:
##   {"rect": [x0,z0,x1,z1] | "ellipse": [cx,cz,rx,rz], "strength": 0..1 (default 1),
##    "falloff": metres (default 2), "height": metres of visible fog (default 2.4),
##    "if": condition, "clear": true}
## An area's *depth* at a point is its strength inside the shape, smoothstepping to 0 over
## `falloff` outside it; overlapping areas take the deepest. Areas with an `if` come and
## go with the story (a relit beacon shrinks them) — see docs/TECH.md "The Greying".
## A `clear` area is light holding the fog back (a waymark lantern): it draws no fog of its
## own and scales the fog under it by (1 - its depth), so a full-strength clear area cuts a
## clear pool out of any fog it overlaps.

## Seconds for a full ember to drain standing at depth 1.
const DRAIN_SECONDS := 24.0
## Seconds for an empty ember to refill outside the fog.
const REFILL_SECONDS := 4.0
## Depth below which a point counts as clear of the fog (safe to return the player to).
const CLEAR_DEPTH := 0.02
## The player's run speed (Player.SPEED), for the validator's ember-budget check.
const WALK_SPEED := 5.0
## Content in the fog must be reachable spending at most this much ember one way, so the
## player can always get there and back out.
const MAX_ONE_WAY_EMBER := 0.45
const DEFAULT_FALLOFF := 2.0
const DEFAULT_HEIGHT := 2.4


## The region's areas whose `if` holds under `state`.
static func active_areas(region_data: Dictionary, state: WorldState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for area: Dictionary in region_data.get("greying", []):
		if Conditions.evaluate(area.get("if"), state):
			out.append(area)
	return out


## Every area regardless of its condition (all fog and all light).
static func all_areas(region_data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(region_data.get("greying", []))
	return out


## The worst case for the validator: every fog area, but only the clear areas that hold
## unconditionally (a lantern the story may take away doesn't count).
static func worst_case_areas(region_data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for area: Dictionary in region_data.get("greying", []):
		if not is_clear(area) or area.get("if") == null:
			out.append(area)
	return out


## True for an area of light that holds the fog back rather than fog.
static func is_clear(area: Dictionary) -> bool:
	var clear: Variant = area.get("clear", false)
	return clear is bool and clear


## Depth of one area at `p` (x/z), 0..strength.
static func area_depth(area: Dictionary, p: Vector2) -> float:
	var d := TerrainField.shape_distance(area, p)
	if d == INF:
		return 0.0
	var strength := clampf(float(area.get("strength", 1.0)), 0.0, 1.0)
	if d <= 0.0:
		return strength
	var falloff := float(area.get("falloff", DEFAULT_FALLOFF))
	if falloff <= 0.0 or d >= falloff:
		return 0.0
	return strength * (1.0 - smoothstep(0.0, falloff, d))


## Fog depth at `p` (x/z) over `areas`: the deepest fog area wins, then the brightest clear
## area thins it.
static func depth_at(areas: Array[Dictionary], p: Vector2) -> float:
	var depth := 0.0
	for area: Dictionary in areas:
		if not is_clear(area):
			depth = maxf(depth, area_depth(area, p))
	if depth <= 0.0:
		return 0.0
	return depth * (1.0 - clearing_at(areas, p))


## How much the clear areas among `areas` hold the fog back at `p`, 0..1.
static func clearing_at(areas: Array, p: Vector2) -> float:
	var light := 0.0
	for area: Dictionary in areas:
		if is_clear(area):
			light = maxf(light, area_depth(area, p))
	return light


## The clear areas among `areas`.
static func clear_areas(areas: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for area: Dictionary in areas:
		if is_clear(area):
			out.append(area)
	return out


## The x/z extent an area's fog can reach (shape + falloff), for building its visual.
static func area_bounds(area: Dictionary) -> Rect2:
	var f := float(area.get("falloff", DEFAULT_FALLOFF))
	if area.has("rect"):
		var r: Array = area["rect"]
		return Rect2(float(r[0]) - f, float(r[1]) - f, float(r[2]) - float(r[0]) + f * 2.0, float(r[3]) - float(r[1]) + f * 2.0)
	var e: Array = area.get("ellipse", [0, 0, 0, 0])
	return Rect2(float(e[0]) - float(e[2]) - f, float(e[1]) - float(e[3]) - f, (float(e[2]) + f) * 2.0, (float(e[3]) + f) * 2.0)


## Ember (0..1) spent walking one way from the nearest clear ground to each reachable cell
## (Dijkstra over walkable cells; cost of a step = depth × time / DRAIN_SECONDS).
## Keys are Vector2i cells of `field`; cells in `reachable` only.
static func ember_cost_map(field: TerrainField, reachable: Dictionary, areas: Array[Dictionary]) -> Dictionary:
	var step_cost := field.cell / WALK_SPEED / DRAIN_SECONDS
	var depth: Dictionary = {}
	var cost: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for c: Vector2i in reachable:
		var centre := field.vertex_xz(c.x, c.y) + Vector2(field.cell, field.cell) * 0.5
		depth[c] = depth_at(areas, centre)
		if depth[c] < CLEAR_DEPTH:
			cost[c] = 0.0
			frontier.append(c)
	# Dijkstra with a binary heap of [cost, cell]. (Until Day 31 this was a LIFO label-correcting
	# search, which re-relaxed cells over and over: 8.6 s on the woods' 2,210 cells.)
	var heap: Array = []
	for c: Vector2i in frontier:
		_heap_push(heap, [0.0, c])
	var done: Dictionary = {}
	while not heap.is_empty():
		var top: Array = _heap_pop(heap)
		var c: Vector2i = top[1]
		if done.has(c):
			continue
		done[c] = true
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + step
			if not reachable.has(n) or done.has(n):
				continue
			var through := float(cost[c]) + (float(depth[c]) + float(depth[n])) * 0.5 * step_cost
			if not cost.has(n) or through < float(cost[n]) - 0.00001:
				cost[n] = through
				_heap_push(heap, [through, n])
	return cost


## Min-heap helpers for ember_cost_map: `heap` holds [cost, payload] pairs.
static func _heap_push(heap: Array, entry: Array) -> void:
	heap.append(entry)
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if float(heap[parent][0]) <= float(heap[i][0]):
			break
		var swap: Array = heap[parent]
		heap[parent] = heap[i]
		heap[i] = swap
		i = parent


static func _heap_pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	var n := heap.size()
	while true:
		var smallest := i
		for child: int in [i * 2 + 1, i * 2 + 2]:
			if child < n and float(heap[child][0]) < float(heap[smallest][0]):
				smallest = child
		if smallest == i:
			break
		var swap: Array = heap[smallest]
		heap[smallest] = heap[i]
		heap[i] = swap
		i = smallest
	return top
