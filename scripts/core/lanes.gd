class_name Lanes
extends RefCounted
## The Tidewright lanes (data/lanes.json) as the lane map sees them: which ports the player
## knows, where the Slow Mercy lies, which lanes are lit and open, and which knot of the
## ferry dialogue sails a voyage. Pure logic over a ContentDatabase and a WorldState.
##
## A voyage to a neighbouring port plays that lane's knot (a first sailing redirects itself
## to its arrival story). A longer voyage needs every lane on the way sailed before: Oda puts
## in at each light only to take on water, and the destination's `passage` knot tells it.

const FLAG := "lanes_ferry_at"
const LANDMARK_LOOKS: Array[String] = ["spire", "water"]


static func data(db: ContentDatabase) -> Dictionary:
	return db.lanes


## The port the ferry lies at now ('' — before the first crossing — is `home`).
static func current_port(db: ContentDatabase, state: WorldState) -> String:
	var at := str(state.get_flag(FLAG, ""))
	return at if not at.is_empty() else str(db.lanes.get("home", ""))


## Whether the player has seen Oda's chart (the journal's Lanes tab shows it from then on).
static func chart_known(db: ContentDatabase, state: WorldState) -> bool:
	return db.lanes.has("chart") and Conditions.evaluate(db.lanes["chart"], state)


static func port(db: ContentDatabase, id: String) -> Dictionary:
	for entry: Dictionary in db.lanes.get("ports", []):
		if str(entry.get("id", "")) == id:
			return entry
	return {}


static func port_known(db: ContentDatabase, state: WorldState, id: String) -> bool:
	var entry := port(db, id)
	return not entry.is_empty() and Conditions.evaluate(entry.get("known"), state)


static func port_lit(db: ContentDatabase, state: WorldState, id: String) -> bool:
	var entry := port(db, id)
	return entry.has("lit") and Conditions.evaluate(entry["lit"], state)


## Every port the player knows of, in data order.
static func known_ports(db: ContentDatabase, state: WorldState) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in db.lanes.get("ports", []):
		if Conditions.evaluate(entry.get("known"), state):
			out.append(str(entry.get("id", "")))
	return out


## The chart's landmarks the player knows of (each `known` condition, if any), in data order. A landmark is
## drawn, never sailed to: Cindermoor's dark Spire, or water Oda won't sail (`look`: "spire" | "water").
static func known_landmarks(db: ContentDatabase, state: WorldState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mark: Dictionary in db.lanes.get("landmarks", []):
		if Conditions.evaluate(mark.get("known"), state):
			out.append(mark)
	return out


## Lanes whose both ends the player knows (drawn on the map, open or not).
static func known_lanes(db: ContentDatabase, state: WorldState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lane: Dictionary in db.lanes.get("lanes", []):
		var ends: Array = lane.get("between", [])
		if port_known(db, state, str(ends[0])) and port_known(db, state, str(ends[1])):
			out.append(lane)
	return out


static func lane_open(lane: Dictionary, state: WorldState) -> bool:
	return Conditions.evaluate(lane.get("open"), state)


static func lane_sailed(lane: Dictionary, state: WorldState) -> bool:
	return Conditions.evaluate(lane.get("sailed"), state)


static func lane_between(db: ContentDatabase, a: String, b: String) -> Dictionary:
	for lane: Dictionary in db.lanes.get("lanes", []):
		var ends: Array = lane.get("between", [])
		if (str(ends[0]) == a and str(ends[1]) == b) or (str(ends[0]) == b and str(ends[1]) == a):
			return lane
	return {}


## The shortest chain of ports from `from` to `to` over open lanes (both ends included), or
## [] if the lanes don't reach.
static func route(db: ContentDatabase, state: WorldState, from: String, to: String) -> Array[String]:
	var came_from: Dictionary = {from: ""}
	var queue: Array[String] = [from]
	while not queue.is_empty():
		var here: String = queue.pop_front()
		if here == to:
			break
		for lane: Dictionary in db.lanes.get("lanes", []):
			if not lane_open(lane, state):
				continue
			var ends: Array = lane.get("between", [])
			var other := ""
			if str(ends[0]) == here:
				other = str(ends[1])
			elif str(ends[1]) == here:
				other = str(ends[0])
			if not other.is_empty() and not came_from.has(other):
				came_from[other] = here
				queue.append(other)
	if not came_from.has(to):
		return []
	var path: Array[String] = [to]
	while path[0] != from:
		path.push_front(str(came_from[path[0]]))
	return path


## Whether the ferry will sail from where it lies to `to`, and how:
## {"ok": true, "knot": <knot of the lanes dialogue>, "route": [...]} or
## {"ok": false, "reason": <a line for the map>}.
static func voyage(db: ContentDatabase, state: WorldState, to: String) -> Dictionary:
	var from := current_port(db, state)
	if not port_known(db, state, to):
		return {"ok": false, "reason": "Oda knows no lane there."}
	if to == from:
		return {"ok": false, "reason": "The Slow Mercy is moored here."}
	var path := route(db, state, from, to)
	if path.is_empty():
		var direct := lane_between(db, from, to)
		if not direct.is_empty() and direct.has("closed_text"):
			return {"ok": false, "reason": str(direct["closed_text"])}
		for lane: Dictionary in known_lanes(db, state):
			if to in (lane.get("between", []) as Array) and not lane_open(lane, state) and lane.has("closed_text"):
				return {"ok": false, "reason": str(lane["closed_text"])}
		return {"ok": false, "reason": "No lit lane runs there yet."}
	if path.size() == 2:
		var lane := lane_between(db, from, to)
		return {"ok": true, "knot": str((lane.get("knots", {}) as Dictionary).get(to, "")), "route": path}
	for i in path.size() - 1:
		if not lane_sailed(lane_between(db, path[i], path[i + 1]), state):
			return {"ok": false, "reason": "Oda sails a new lane from its near end. Go by %s first." % str(port(db, path[path.size() - 2]).get("name", ""))}
	return {"ok": true, "knot": str(port(db, to).get("passage", "")), "route": path}
