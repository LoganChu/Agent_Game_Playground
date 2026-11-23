class_name WalkSurvey
extends RefCounted
## Day 121 — every pair of one NPC's placements in a region, and what a move between them would do mid-visit:
## `swap` (a change of pose or model in place), `straight` or `bent` (walked, Region.walk_route), or `fades` with the
## reason (seated, circuit, far, ground, blocked). Read by `tools/debug/walk_probe.gd` and the tests.
## It asks the region as built: in the tree the props' colliders and the other NPCs count (the props shown for the
## world state it was built under); out of it only the ground decides.
## Not every pair is a move the story makes: it lists them all, both ways, so a content session can see what a new
## placement will look like whichever way the flags flip.

const SWAP := "swap"
const STRAIGHT := "straight"
const BENT := "bent"
const FADES := "fades"


## Rows for `region` (built), ordered by NPC id then placement index: {npc, from, to (placement indices among that
## NPC's placements in the region's `npcs`), from_pos, to_pos, distance, kind, reason, route}.
static func survey(region: Region) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var by_npc := placements(region.data)
	var ids: Array = by_npc.keys()
	ids.sort()
	for npc: String in ids:
		var list: Array = by_npc[npc]
		for i in list.size():
			for j in list.size():
				if i != j:
					rows.append(classify(region, npc, i, list[i], j, list[j]))
	return rows


## npc id -> its placement entries in the region's data, in order; only NPCs placed more than once.
static func placements(region_data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in region_data.get("npcs", []):
		var npc := str(entry.get("npc", ""))
		out[npc] = out.get(npc, []) + [entry]
	for npc: String in out.keys():
		if (out[npc] as Array).size() < 2:
			out.erase(npc)
	return out


## What a move from placement `a` (index `i`) to placement `b` (index `j`) of `npc` would do.
static func classify(region: Region, npc: String, i: int, a: Dictionary, j: int, b: Dictionary) -> Dictionary:
	var from := region.place(a.get("position"))
	var to := region.place(b.get("position"))
	var distance := Vector2(to.x - from.x, to.z - from.z).length()
	var row := {"npc": npc, "from": i, "to": j, "from_pos": from, "to_pos": to, "distance": distance,
		"kind": FADES, "reason": "", "route": [] as Array[Vector3]}
	var npc_data: Dictionary = Content.db.npcs.get(npc, {}) if Content.db != null else {}
	var seated := CharacterRig.is_seated_style(str(Region.placed_npc_data(npc_data, a).get("idle", "breathe")))
	if distance <= Region.SWAP_IN_PLACE:
		row["kind"] = SWAP
	elif seated:
		row["reason"] = "seated"
	elif a.get("circuit") is Dictionary or b.get("circuit") is Dictionary:
		row["reason"] = "circuit"
	elif region.field == null:
		row["reason"] = "no ground"
	elif distance > Region.WALK_REACH:
		row["reason"] = "far"
	else:
		var route := region.walk_route(from, to, _actor_at(region, npc, from))
		if route.is_empty():
			row["reason"] = "ground" if region.walk_ground_clear(from, to).is_empty() else "blocked"
		else:
			row["kind"] = STRAIGHT if route.size() == 1 else BENT
			row["route"] = route
	return row


## One row as a line: "mara  0 -> 2  straight  6.1 m" / "... bent 2  9.0 m via (x, z)" / "... fades (far)  18.2 m".
static func describe(row: Dictionary) -> String:
	var kind := str(row["kind"])
	if kind == BENT:
		var route: Array = row["route"]
		var via: PackedStringArray = []
		for p: Vector3 in route.slice(0, route.size() - 1):
			via.append("(%.1f, %.1f)" % [p.x, p.z])
		kind = "bent %d via %s" % [route.size() - 1, " ".join(via)]
	elif kind == FADES:
		kind = "fades (%s)" % row["reason"]
	return "%-12s %d -> %d  %5.1f m  %s" % [row["npc"], row["from"], row["to"], row["distance"], kind]


## How many rows of each kind: {"swap": n, "straight": n, "bent": n, "fades": n}.
static func tally(rows: Array[Dictionary]) -> Dictionary:
	var out := {SWAP: 0, STRAIGHT: 0, BENT: 0, FADES: 0}
	for row: Dictionary in rows:
		out[row["kind"]] += 1
	return out


## The actor standing at `at` for `npc`, if the region shows one there (its own body isn't in its way).
static func _actor_at(region: Region, npc: String, at: Vector3) -> NpcActor:
	for child in region.get_children():
		if child is NpcActor and (child as NpcActor).npc_id == npc \
				and Vector2(child.position.x - at.x, child.position.z - at.z).length() < 0.3:
			return child as NpcActor
	return null
