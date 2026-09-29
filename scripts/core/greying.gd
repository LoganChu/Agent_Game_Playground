class_name Greying
extends RefCounted
## The Greying as a place: fog areas that drain the Wakebearer's ember (pure logic).
##
## Region data `greying` is a list of areas:
##   {"rect": [x0,z0,x1,z1] | "ellipse": [cx,cz,rx,rz], "strength": 0..1 (default 1),
##    "falloff": metres (default 2), "height": metres of visible fog (default 2.4),
##    "if": condition}
## An area's *depth* at a point is its strength inside the shape, smoothstepping to 0 over
## `falloff` outside it; overlapping areas take the deepest. Areas with an `if` come and
## go with the story (a relit beacon shrinks them) — see docs/TECH.md "The Greying".

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


## Every area regardless of its condition (worst case, for validation).
static func all_areas(region_data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(region_data.get("greying", []))
	return out


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


## Fog depth at `p` (x/z) over `areas`: the deepest area wins.
static func depth_at(areas: Array[Dictionary], p: Vector2) -> float:
	var depth := 0.0
	for area: Dictionary in areas:
		depth = maxf(depth, area_depth(area, p))
	return depth


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
	# Label-correcting search; the grid is small (a few thousand cells).
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_back()
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + step
			if not reachable.has(n):
				continue
			var through := float(cost[c]) + (float(depth[c]) + float(depth[n])) * 0.5 * step_cost
			if not cost.has(n) or through < float(cost[n]) - 0.00001:
				cost[n] = through
				frontier.append(n)
	return cost
