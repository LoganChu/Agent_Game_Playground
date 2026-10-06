class_name TerrainField
extends RefCounted
## A region's sculpted ground as a height grid built from its `ground` data (see docs/TECH.md
## "Ground"). Pure logic — no scene nodes — so the validator and tests can ask where the
## ground is, what is walkable and what can be reached on foot. `TerrainBuilder` turns it
## into the visible mesh and collider.
##
## Height = max over `land` features of lerp(base, feature height, influence), where
## influence is 1 inside the feature and smoothsteps to 0 over its `falloff`; plus a small
## deterministic `roughness` so flat ground still reads as faceted low-poly. `ragged`
## pushes rect/ellipse edges in and out with smooth noise so coastlines aren't geometric.

## Steepest walkable rise per metre (≈ 40°; the player's floor limit is 45°).
const MAX_WALK_SLOPE := 0.84
## Height of the invisible shore wall above the water (the player can't wade out to sea).
const WALL_HEIGHT := 2.5

var bounds := Rect2()  ## x/z extent
var cell := 1.0
var base := -1.5
var water_level := -INF
var wade_depth := 0.35
var roughness := 0.06
var ragged := 1.2  ## metres of coastline wobble on rect/ellipse edges (per-feature override)
var ragged_scale := 5.0  ## metres between wobble lattice points
var seed_value := 0
var land: Array = []
## Paint zones in effect: those without an `if`, plus (after `select_paint`) the conditional
## ones whose condition holds. `all_paint` is every zone in the data.
var paint: Array = []
var all_paint: Array = []
## Walkable decks over the water: [{"rect": [x0,z0,x1,z1], "deck": absolute height}].
var piers: Array = []
var colors: Dictionary = {}
var cols := 0  ## vertices along x
var rows := 0  ## vertices along z
var heights := PackedFloat32Array()


## Builds the field from a region's `ground` dictionary. `water` = the region's water_level
## (or -INF for none). Invalid data yields a small flat field; the validator reports errors.
static func from_data(ground: Dictionary, water: float = -INF) -> TerrainField:
	var field := TerrainField.new()
	var b: Array = ground.get("bounds", [-10, -10, 10, 10])
	if b.size() == 4:
		field.bounds = Rect2(float(b[0]), float(b[1]), float(b[2]) - float(b[0]), float(b[3]) - float(b[1])).abs()
	else:
		field.bounds = Rect2(-10, -10, 20, 20)
	field.cell = maxf(0.25, float(ground.get("cell", 1.0)))
	field.base = float(ground.get("base", -1.5))
	field.water_level = water
	field.wade_depth = float(ground.get("wade_depth", 0.35))
	field.roughness = float(ground.get("roughness", 0.06))
	field.ragged = float(ground.get("ragged", 1.2))
	field.ragged_scale = maxf(0.5, float(ground.get("ragged_scale", 5.0)))
	field.seed_value = int(ground.get("seed", 0))
	field.land = ground.get("land", [])
	field.all_paint = ground.get("paint", [])
	field.paint = field.all_paint.filter(func(zone: Variant) -> bool: return zone is Dictionary and not zone.has("if"))
	for pier: Variant in ground.get("piers", []):
		# Malformed piers are dropped here; the validator reports them.
		if pier is Dictionary and pier.get("rect") is Array and (pier["rect"] as Array).size() == 4:
			field.piers.append(pier)
	field.colors = ground.get("colors", {})
	field._build()
	return field


## Re-picks the paint zones whose `if` holds in `world` (e.g. the moss under a lantern goes
## when the lantern is moved). Returns true if the set changed (the ground needs recolouring).
func select_paint(world: WorldState) -> bool:
	var want := all_paint.filter(func(zone: Variant) -> bool:
		return zone is Dictionary and Conditions.evaluate(zone.get("if"), world))
	if want == paint:
		return false
	paint = want
	return true


## True if any paint zone is conditional (the ground may need recolouring when flags change).
func has_conditional_paint() -> bool:
	return all_paint.any(func(zone: Variant) -> bool: return zone is Dictionary and zone.has("if"))


func _build() -> void:
	cols = int(ceil(bounds.size.x / cell)) + 1
	rows = int(ceil(bounds.size.y / cell)) + 1
	heights.resize(cols * rows)
	for iz in rows:
		for ix in cols:
			var p := vertex_xz(ix, iz)
			heights[iz * cols + ix] = shape_height(p.x, p.y) + _noise(ix, iz) * roughness


func vertex_xz(ix: int, iz: int) -> Vector2:
	return Vector2(bounds.position.x + ix * cell, bounds.position.y + iz * cell)


func vertex_height(ix: int, iz: int) -> float:
	return heights[clampi(iz, 0, rows - 1) * cols + clampi(ix, 0, cols - 1)]


## Height of the collision surface at a vertex: underwater vertices deeper than the wading
## depth become an invisible wall so the shoreline is the edge of the playable area —
## except under a pier, where the collider is raised to the deck instead.
func collision_height(ix: int, iz: int) -> float:
	var h := vertex_height(ix, iz)
	var p := vertex_xz(ix, iz)
	var deck := pier_deck(p.x, p.y)
	if deck > -INF:
		return maxf(h, deck)
	if is_wet(h):
		return water_level + WALL_HEIGHT
	return h


## Deck height of the highest pier covering (x, z), or -INF. Pier rects should lie on grid
## lines: the walkable collider only spans the vertices inside the rect.
func pier_deck(x: float, z: float) -> float:
	var deck := -INF
	for pier: Dictionary in piers:
		if TerrainField.shape_distance(pier, Vector2(x, z)) <= 0.001:
			deck = maxf(deck, float(pier.get("deck", 0.0)))
	return deck


## Height the player stands at over (x, z): the ground, or a pier deck above it.
func surface_at(x: float, z: float) -> float:
	return maxf(height_at(x, z), pier_deck(x, z))


func is_wet(h: float) -> bool:
	return water_level > -INF and h < water_level - wade_depth


## The smooth designed height (no roughness) from the `land` features.
func shape_height(x: float, z: float) -> float:
	var h := base
	for feature: Dictionary in land:
		var top := float(feature.get("height", 0.0))
		var d := 0.0
		if feature.has("path"):
			var hit := _path_hit(feature["path"], Vector2(x, z))
			d = hit.x - float(feature.get("width", 2.0)) * 0.5
			top = hit.y
			d += float(feature.get("ragged", 0.0)) * smooth_noise(x, z)  # ramps stay clean by default
		else:
			d = shape_distance(feature, Vector2(x, z))
			d += float(feature.get("ragged", ragged)) * smooth_noise(x, z)
		d = maxf(0.0, d)
		var falloff := maxf(0.001, float(feature.get("falloff", 2.0)))
		var influence := 1.0 - smoothstep(0.0, falloff, d)
		if influence > 0.0:
			h = maxf(h, lerpf(base, top, influence))
	return h


## Height of the rendered surface at any x/z (matches the mesh triangles exactly).
func height_at(x: float, z: float) -> float:
	var fx := clampf((x - bounds.position.x) / cell, 0.0, cols - 1.0)
	var fz := clampf((z - bounds.position.y) / cell, 0.0, rows - 1.0)
	var ix := mini(int(fx), cols - 2)
	var iz := mini(int(fz), rows - 2)
	var u := fx - ix
	var v := fz - iz
	var h00 := vertex_height(ix, iz)
	var h10 := vertex_height(ix + 1, iz)
	var h01 := vertex_height(ix, iz + 1)
	var h11 := vertex_height(ix + 1, iz + 1)
	# Each cell is split along the (0,0)-(1,1) diagonal (see TerrainBuilder).
	if u >= v:
		return h00 + (h10 - h00) * u + (h11 - h10) * v
	return h00 + (h11 - h01) * u + (h01 - h00) * v


func contains(x: float, z: float) -> bool:
	return bounds.grow(0.001).has_point(Vector2(x, z))


## Palette name (or #hex) of the ground at a triangle with the given average height and
## steepest slope (rise per metre). Painted zones win, then cliffs, seabed, shore, ground.
func color_name(x: float, z: float, h: float, slope: float) -> String:
	for zone: Dictionary in paint:
		var inside := false
		if zone.has("path"):
			inside = _path_hit(zone["path"], Vector2(x, z)).x <= float(zone.get("width", 2.0)) * 0.5
		else:
			inside = shape_distance(zone, Vector2(x, z)) <= 0.0
		if inside:
			return str(zone.get("color", "driftwood"))
	if slope > float(colors.get("cliff_slope", 0.9)):
		return str(colors.get("cliff", "slate"))
	var water := water_level if water_level > -INF else base
	if h < water - 0.15:
		return str(colors.get("seabed", "driftwood"))
	if h < water + float(colors.get("shore_height", 0.35)):
		return str(colors.get("shore", "driftwood"))
	return str(colors.get("ground", "moss"))


## Walkability of the cell whose min corner is (ix, iz): dry (or decked by a pier), and no
## edge of the collision surface steeper than the player can climb.
func is_cell_walkable(ix: int, iz: int) -> bool:
	if ix < 0 or iz < 0 or ix >= cols - 1 or iz >= rows - 1:
		return false
	var hs: Array[float] = []
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var p := vertex_xz(ix + corner.x, iz + corner.y)
		if is_wet(vertex_height(ix + corner.x, iz + corner.y)) and pier_deck(p.x, p.y) == -INF:
			return false
		hs.append(collision_height(ix + corner.x, iz + corner.y))
	var limit := MAX_WALK_SLOPE * cell
	return absf(hs[0] - hs[1]) <= limit and absf(hs[2] - hs[3]) <= limit \
		and absf(hs[0] - hs[2]) <= limit and absf(hs[1] - hs[3]) <= limit \
		and absf(hs[0] - hs[3]) <= limit * 1.414


func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor((x - bounds.position.x) / cell)), int(floor((z - bounds.position.y) / cell)))


## Walkable cells reachable on foot from (x, z) (4-neighbour flood fill). Keys are Vector2i.
func reachable_from(x: float, z: float) -> Dictionary:
	var seen: Dictionary = {}
	var start := cell_of(x, z)
	if not is_cell_walkable(start.x, start.y):
		return seen
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + step
			if not seen.has(n) and is_cell_walkable(n.x, n.y):
				seen[n] = true
				queue.append(n)
	return seen


## True if some reachable cell lies within `radius` of (x, z).
func near_reachable(reachable: Dictionary, x: float, z: float, radius: float) -> bool:
	var c := cell_of(x, z)
	var r := int(ceil(radius / cell))
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var n := c + Vector2i(dx, dz)
			if not reachable.has(n):
				continue
			var center := vertex_xz(n.x, n.y) + Vector2(cell, cell) * 0.5
			if center.distance_to(Vector2(x, z)) <= radius + cell * 0.71:
				return true
	return false


## Signed distance from the edge of a `rect` [x0,z0,x1,z1] or `ellipse` [cx,cz,rx,rz]
## shape (negative inside). Ellipse distance is approximate (scaled), fine for falloffs.
static func shape_distance(shape: Dictionary, p: Vector2) -> float:
	if shape.has("rect"):
		var r: Array = shape["rect"]
		var ox := maxf(float(r[0]) - p.x, p.x - float(r[2]))
		var oz := maxf(float(r[1]) - p.y, p.y - float(r[3]))
		if ox <= 0.0 and oz <= 0.0:
			return maxf(ox, oz)
		return Vector2(maxf(ox, 0.0), maxf(oz, 0.0)).length()
	if shape.has("ellipse"):
		var e: Array = shape["ellipse"]
		var rx := maxf(0.01, float(e[2]))
		var rz := maxf(0.01, float(e[3]))
		var q := Vector2((p.x - float(e[0])) / rx, (p.y - float(e[1])) / rz)
		return (q.length() - 1.0) * minf(rx, rz)
	return INF


## Smooth value noise in [-1, 1] over the world (bilinear on a `ragged_scale` lattice).
func smooth_noise(x: float, z: float) -> float:
	var fx := x / ragged_scale
	var fz := z / ragged_scale
	var ix := int(floor(fx))
	var iz := int(floor(fz))
	var u := smoothstep(0.0, 1.0, fx - ix)
	var v := smoothstep(0.0, 1.0, fz - iz)
	var a := lerpf(_noise(ix + 5000, iz + 5000), _noise(ix + 5001, iz + 5000), u)
	var b := lerpf(_noise(ix + 5000, iz + 5001), _noise(ix + 5001, iz + 5001), u)
	return lerpf(a, b, v)


## Distance from p to a polyline of [x, z, height] points, and the height interpolated at
## the closest point. Returns Vector2(distance, height).
static func _path_hit(points: Array, p: Vector2) -> Vector2:
	var best := Vector2(INF, 0.0)
	for i in points.size() - 1:
		var a: Array = points[i]
		var b: Array = points[i + 1]
		var pa := Vector2(float(a[0]), float(a[1]))
		var pb := Vector2(float(b[0]), float(b[1]))
		var ab := pb - pa
		var t := 0.0 if ab.length_squared() < 0.0001 else clampf((p - pa).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p.distance_to(pa + ab * t)
		if d < best.x:
			best = Vector2(d, lerpf(float(a[2]) if a.size() > 2 else 0.0, float(b[2]) if b.size() > 2 else 0.0, t))
	return best


## Deterministic per-vertex noise in [-1, 1].
func _noise(ix: int, iz: int) -> float:
	var n := (ix * 73856093) ^ (iz * 19349663) ^ (seed_value * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 32767.5 - 1.0
