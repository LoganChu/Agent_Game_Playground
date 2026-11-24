class_name ShoreSound
extends RefCounted
## Sound that comes from the shoreline (Day 123). An ambience layer marked `"at": "shore"`
## plays from the nearest point where a region's ground meets its water
## (`TerrainField.shore_points`) instead of everywhere at once: louder the nearer the player
## stands to the water, quiet (never silent) inland, and panned toward the sea. Pure logic;
## `AudioDirector` moves a positional player to `anchor()` and scales it by `gain()`.

## Within this many metres of the water the layer plays at its full volume.
const NEAR := 2.5
## Defaults for a layer's `reach` (metres to fall to the floor) and `floor` (0..1 of its volume).
const REACH := 16.0
const FLOOR := 0.35
## The anchor never sits closer to the listener than this, so standing at the waterline
## doesn't swing the sound from ear to ear.
const MIN_SPREAD := 3.0
## How fast the anchor slides along the shore (m/s) when the nearest point changes.
const SLIDE := 14.0
## The one place a layer can be anchored today.
const PLACES := ["shore"]


## The layer's anchoring, or {} for a plain layer: {at, reach, floor}.
static func spec(entry: Dictionary) -> Dictionary:
	if not entry.has("at"):
		return {}
	return {
		"at": str(entry["at"]),
		"reach": maxf(NEAR + 1.0, float(entry.get("reach", REACH))),
		"floor": clampf(float(entry.get("floor", FLOOR)), 0.0, 1.0),
	}


## The shore point nearest `listener` on the ground plane, or Vector3.INF if there is none.
static func nearest(points: PackedVector3Array, listener: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	var here := Vector2(listener.x, listener.z)
	for p: Vector3 in points:
		var d := here.distance_squared_to(Vector2(p.x, p.z))
		if d < best_d:
			best_d = d
			best = p
	return best


## Horizontal distance from `listener` to the shore (INF with no shore).
static func distance(points: PackedVector3Array, listener: Vector3) -> float:
	var p := nearest(points, listener)
	if p == Vector3.INF:
		return INF
	return Vector2(listener.x, listener.z).distance_to(Vector2(p.x, p.z))


## Share (floor..1) of a layer's volume heard `d` metres from the water.
static func gain(d: float, reach: float = REACH, floor_share: float = FLOOR) -> float:
	if is_inf(d):
		return floor_share
	return lerpf(1.0, floor_share, smoothstep(NEAR, maxf(NEAR + 1.0, reach), d))


## Where the sound should come from: the nearest shore point, pushed out along the line
## from the listener to at least MIN_SPREAD away. Vector3.INF with no shore.
static func anchor(points: PackedVector3Array, listener: Vector3) -> Vector3:
	var p := nearest(points, listener)
	if p == Vector3.INF:
		return p
	var flat := Vector2(p.x - listener.x, p.z - listener.z)
	if flat.length() < MIN_SPREAD:
		# Right at the water (or in it): keep the direction if there is one, else push seaward-ish
		# along +Z so the sound still has somewhere to be.
		var dir := flat.normalized() if flat.length() > 0.01 else Vector2(0.0, 1.0)
		flat = dir * MIN_SPREAD
	return Vector3(listener.x + flat.x, p.y, listener.z + flat.y)
