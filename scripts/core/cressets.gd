class_name Cressets
extends RefCounted
## Waymark cressets (Day 82, Act III's way up): cold iron fire-baskets up a road the Greying has
## made forget where it goes. Lighting one from the ember makes the road remember as far as the
## next. Region data `cressets` is an ordered list (the order they must be lit in):
##   {"id": "moor_1", "flag": "cindermoor_cresset_moor_1", "position": [x, y, z], "rotation_y": deg,
##    "dialogue": "<story id: lighting it; must set `flag` true>", "if": condition (when it may be lit),
##    "pool": [shape, ...] (clear areas the lit fire holds open: rect/ellipse, strength, falloff),
##    "road": [[x, z, 0], ...] (optional: the leg of road painted back in when lit)}
## `ContentDatabase` expands each entry at load into ordinary region content — a cold prop and a lit
## prop, a "Light the cresset" object, `clear` Greying areas and a conditional road paint, all keyed
## on `flag` — so the region builder, fog, conditions and validator need nothing new. The raw list
## stays on the region for the validator's chain check (each cresset reachable with only the ones
## before it lit — see ContentValidator and docs/TECH.md "The way up").

const MODEL_COLD := "res://assets/models/dressing/cinder_cresset.glb"
const MODEL_LIT := "res://assets/models/dressing/cinder_cresset_lit.glb"
const COLLIDER := [1.0, 2.4, 1.0]
## Model-space top of the basket, where the fire's glow and smoke sit.
const FIRE := [0.0, 2.25, 0.0]
const PROMPT := "Light the cresset"
const ROAD_COLOR := "#262322"
const ROAD_WIDTH := 1.6
const KEYS: Array[String] = ["id", "flag", "position", "rotation_y", "dialogue", "if", "pool", "road", "note"]


## Expands a region's `cressets` into props/objects/greying/paint in place. Idempotent: entries it
## added carry `"cresset": id` and are replaced on a second call.
static func expand(region: Dictionary) -> void:
	var list: Variant = region.get("cressets")
	if not list is Array:
		return
	for key: String in ["props", "objects", "greying"]:
		region[key] = _without_generated(region.get(key, []))
	if region.get("ground") is Dictionary:
		region["ground"]["paint"] = _without_generated(region["ground"].get("paint", []))
	for entry: Variant in list:
		if not entry is Dictionary or str(entry.get("flag", "")).is_empty():
			continue  # the validator reports it
		var c: Dictionary = entry
		var id := str(c.get("id", ""))
		var lit := "flag:" + str(c["flag"])
		var unlit := "!flag:" + str(c["flag"])
		var pos: Variant = c.get("position", [0, 0, 0])
		var rot := float(c.get("rotation_y", 0.0))
		(region["props"] as Array).append({
			"model": MODEL_COLD, "position": pos, "rotation_y": rot,
			"collider": COLLIDER, "if": unlit, "cresset": id, "note": "Cresset '%s', cold." % id})
		(region["props"] as Array).append({
			"model": MODEL_LIT, "position": pos, "rotation_y": rot, "collider": COLLIDER, "if": lit,
			"halo": FIRE, "halo_size": 3.2, "halo_strength": 1.0, "halo_bloom": 0.35,
			"smoke": [FIRE], "smoke_scale": 0.45,
			"sound": {"id": "fire", "offset": FIRE, "volume": 0.5}, "cresset": id,
			"note": "Cresset '%s', lit from the ember." % id})
		var when: Variant = unlit
		if c.get("if") != null:
			when = [unlit] + (c["if"] as Array if c["if"] is Array else [c["if"]])
		(region["objects"] as Array).append({
			"id": "cresset_" + id, "prompt": PROMPT, "dialogue": str(c.get("dialogue", "")),
			"position": pos, "reach": 2.0, "glint": [0, 2.4, 0], "if": when, "cresset": id})
		for shape: Variant in c.get("pool", []):
			if not shape is Dictionary:
				continue
			var area: Dictionary = (shape as Dictionary).duplicate(true)
			area["clear"] = true
			area["if"] = lit
			area["cresset"] = id
			(region["greying"] as Array).append(area)
		if c.get("road") is Array and region.get("ground") is Dictionary:
			(region["ground"]["paint"] as Array).append({
				"path": c["road"], "width": ROAD_WIDTH, "color": ROAD_COLOR, "if": lit, "cresset": id,
				"note": "The road as far as the next cresset, remembered."})


## The cresset entries of a region (raw data), in lighting order.
static func of(region: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Variant in region.get("cressets", []):
		if entry is Dictionary:
			out.append(entry)
	return out


## The pool areas (as expanded into the region's greying) of the cresset with `id`.
static func pools_of(region: Dictionary, id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for area: Dictionary in region.get("greying", []):
		if str(area.get("cresset", "")) == id:
			out.append(area)
	return out


static func _without_generated(list: Variant) -> Array:
	var out: Array = []
	if list is Array:
		for item: Variant in list:
			if not (item is Dictionary and (item as Dictionary).has("cresset")):
				out.append(item)
	return out
