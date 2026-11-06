class_name ContentValidator
extends RefCounted
## Cross-checks all content for broken references and orphans. Run by the test suite
## (tests/test_content.gd) and, in debug builds, at game start.
##
## Errors fail the build. Warnings are printed but allowed (e.g. an item nobody uses yet).

const STEP_ACTIONS: Array[String] = ["say", "choice", "goto", "end"]
const STEP_KEYS: Array[String] = ["say", "text", "choice", "goto", "end", "if", "count", "note"]
const OPTION_KEYS: Array[String] = ["text", "goto", "end", "if", "count", "note", "lane_map"]
const ITEM_KINDS: Array[String] = ["own", "remnant", "key", "misc"]
## Two props of one family closer than this (metres, ground plane) are variants of one thing.
const PROP_VARIANT_SPOT := 0.6
## How far under the water an NPC's feet may be before the placement must say "wading" (surf at the ankles).
const DRY_FEET := 0.1

var db: ContentDatabase
var errors: Array[String] = []
var warnings: Array[String] = []

# Usage tracking for orphan detection.
var _flags_set: Dictionary = {}
var _flags_read: Dictionary = {}
var _quests_started: Dictionary = {}
var _quests_completed: Dictionary = {}
var _items_obtainable: Dictionary = {}
var _items_used: Dictionary = {}
var _dialogues_used: Dictionary = {}
var _npcs_placed: Dictionary = {}
var _sounds_used: Dictionary = {}
## False while the region being validated has a malformed Greying area (its geometric
## checks are skipped then, the malformed area is reported instead).
var _greying_ok := true
## The flags' defaults and value lists for _joint_witness, built once per validate().
var _witness_defaults: Dictionary = {}
var _witness_values: Dictionary = {}
var _witness_ready := false

## Day 84: the ground's geometric checks (reachability, the Greying budget, the road that forgets,
## dry feet, piers) cost ~1.3 s of a ~1.5 s validate and depend on nothing but the region's own
## data, so their findings are remembered by a hash of it, across validators. The validator tests
## edit one region and validate everything again; only the edited region is walked again.
## [errors, warnings] by hash([where, _greying_ok, region]).
static var _ground_memo: Dictionary = {}
## Validators that walked the ground (memo misses) since the process started (for tests).
static var ground_walks := 0


func _init(p_db: ContentDatabase) -> void:
	db = p_db


## Returns true when there are no errors.
func validate() -> bool:
	errors = db.errors.duplicate()
	warnings.clear()
	_witness_ready = false
	_validate_game()
	_validate_flags()
	_validate_audio()
	_validate_lanes()
	for id: String in db.items:
		_validate_item(id, db.items[id])
	for id: String in db.npcs:
		_validate_npc(id, db.npcs[id])
	for id: String in db.quests:
		_validate_quest(id, db.quests[id])
	for id: String in db.regions:
		_validate_region(id, db.regions[id])
	for id: String in db.dialogues:
		_validate_dialogue(id, db.dialogues[id])
	_check_orphans()
	_check_placements_exclusive()
	for message in Scenarios.validate(db, Scenarios.all()):
		_err("data/scenarios.json", message)
	for message in Scenarios.half_made(db, Scenarios.all()):
		_err("data/scenarios.json", message)
	return errors.is_empty()


func report() -> String:
	var lines: PackedStringArray = []
	for e in errors:
		lines.append("ERROR   " + e)
	for w in warnings:
		lines.append("WARNING " + w)
	return "\n".join(lines)


func _err(where: String, msg: String) -> void:
	errors.append("%s: %s" % [where, msg])


## Day 88: the long legs of a painted path that are *nearly* straight along an axis — a drift
## of a few tenths over a long leg crosses one or two of the ground's 1 m triangle rows and the
## paint's edge shows a lone step (Day 84's cresset road: z −1.2 → −1.4 over 15 m). A wandering
## track (slant ≥ SAW_SLANT) steps often enough to read as ragged, so only near-axis drift warns.
const SAW_LEG := 10.0
const SAW_SLANT := 0.1


static func sawing_legs(points: Array) -> Array[String]:
	var out: Array[String] = []
	for i in range(1, points.size()):
		var a := Vector2(float(points[i - 1][0]), float(points[i - 1][1]))
		var b := Vector2(float(points[i][0]), float(points[i][1]))
		if a.distance_to(b) < SAW_LEG:
			continue
		var d := (b - a).abs()
		var slant := minf(d.x, d.y) / maxf(d.x, d.y)
		if slant >= 0.001 and slant < SAW_SLANT:
			out.append("%s → %s (%.0f m, slant %.2f)" % [a, b, a.distance_to(b), slant])
	return out


func _warn(where: String, msg: String) -> void:
	warnings.append("%s: %s" % [where, msg])


func _require_fields(where: String, record: Dictionary, fields: Array[String]) -> void:
	for f in fields:
		if not record.has(f) or str(record[f]).is_empty():
			_err(where, "missing required field '%s'" % f)


func _validate_game() -> void:
	var where := "data/game.json"
	var start_region := str(db.game.get("start_region", ""))
	if not db.regions.has(start_region):
		_err(where, "start_region '%s' does not exist" % start_region)
		return
	var spawns: Dictionary = db.get_region(start_region).get("spawn_points", {})
	var spawn := str(db.game.get("start_spawn", "default"))
	if not spawns.has(spawn):
		_err(where, "start_spawn '%s' not in region '%s'" % [spawn, start_region])
	if db.game.has("intro_dialogue"):
		_ref_dialogue(where, str(db.game["intro_dialogue"]))
	if db.game.has("player_model"):
		_ref_character_model(where, str(db.game["player_model"]))
	var acts: Variant = db.game.get("act_ends", [])
	if not acts is Array:
		_err(where, "act_ends must be a list")
		return
	for act: Variant in acts:
		if not act is Dictionary:
			_err(where, "act_ends entries must be objects")
			continue
		var a: Dictionary = act
		_require_fields(where + " act_ends", a, ["id", "when", "title", "coda"])
		_ref_condition(where, a.get("when"))
		for line: Variant in a.get("recap", []):
			if not line is Dictionary or str((line as Dictionary).get("text", "")).is_empty():
				_err(where, "act_ends recap lines need 'text'")
				continue
			_ref_condition(where, (line as Dictionary).get("if"))
		if a.has("unfinished") and str(a["unfinished"]).count("%s") != 1:
			_err(where, "act_ends '%s' unfinished needs exactly one %%s (the quest titles)" % a.get("id", ""))


## Every knot of the lanes dialogue the lane map can jump to.
func _lane_knots() -> Array[String]:
	var out: Array[String] = []
	for port: Variant in db.lanes.get("ports", []):
		if port is Dictionary and (port as Dictionary).has("passage"):
			out.append(str(port["passage"]))
	for lane: Variant in db.lanes.get("lanes", []):
		if lane is Dictionary and (lane as Dictionary).get("knots") is Dictionary:
			for to: String in lane["knots"]:
				out.append(str(lane["knots"][to]))
	return out


## data/lanes.json: ports on real regions with flag values of their own, lanes between known
## ports, every voyage knot in the ferry dialogue and landing where its port is.
func _validate_lanes() -> void:
	var where := "data/lanes.json"
	var dialogue_id := str(db.lanes.get("dialogue", ""))
	_ref_dialogue(where, dialogue_id)
	_ref_condition(where + " chart", db.lanes.get("chart"))
	var knots: Dictionary = db.get_dialogue(dialogue_id).get("knots", {})
	var flag_values := db.flag_values(Lanes.FLAG)
	var ports: Dictionary = {}
	for port_v: Variant in db.lanes.get("ports", []):
		if not port_v is Dictionary:
			_err(where, "ports must be objects")
			continue
		var port: Dictionary = port_v
		var pw := "%s port %s" % [where, port.get("id", "?")]
		_require_fields(pw, port, ["id", "name", "light", "region", "passage"])
		var id := str(port.get("id", ""))
		if ports.has(id):
			_err(pw, "duplicate port id")
		ports[id] = port
		if id not in flag_values:
			_err(pw, "port id must be a value of %s (%s)" % [Lanes.FLAG, flag_values])
		if not db.regions.has(str(port.get("region", ""))):
			_err(pw, "unknown region '%s'" % port.get("region", ""))
		_ref_condition(pw, port.get("lit"))
		_ref_condition(pw, port.get("known"))
		_check_map_point(pw, port.get("map"))
		_check_lane_knot(pw, knots, str(port.get("passage", "")), str(port.get("region", "")), id)
	if not ports.has(str(db.lanes.get("home", ""))):
		_err(where, "home '%s' is not a port" % db.lanes.get("home", ""))
	for mark: Variant in db.lanes.get("landmarks", []):
		if not mark is Dictionary:
			_err(where, "landmarks must be objects")
			continue
		_require_fields(where + " landmark", mark, ["name", "text"])
		var mw := where + " landmark " + str((mark as Dictionary).get("name", "?"))
		_check_map_point(mw, (mark as Dictionary).get("map"))
		_ref_condition(mw, (mark as Dictionary).get("known"))
		if str((mark as Dictionary).get("look", "spire")) not in Lanes.LANDMARK_LOOKS:
			_err(mw, "look must be one of %s" % [Lanes.LANDMARK_LOOKS])
		_ref_condition(mw, (mark as Dictionary).get("lit"))
		var links: Variant = (mark as Dictionary).get("links", [])
		if not links is Array or not (links as Array).all(func(l: Variant) -> bool: return ports.has(str(l))):
			_err(mw, "'links' must list ports")
		if (mark as Dictionary).has("ferry"):
			# Day 81: the Mercy can lie at a landmark (lanes_ferry_at = its `ferry`); `moored` says why she sails nowhere.
			var at := str((mark as Dictionary)["ferry"])
			var declared: Array = (db.flags.get(Lanes.FLAG, {}) as Dictionary).get("values", [])
			if ports.has(at) or not declared.has(at):
				_err(mw, "'ferry' must be a declared lanes_ferry_at value that isn't a port")
			if not (mark as Dictionary).has("moored"):
				_err(mw, "a landmark the ferry lies at needs 'moored' (why she sails nowhere from it)")
		var mark_lane: Variant = (mark as Dictionary).get("lane")
		if mark_lane != null:
			if not mark_lane is Dictionary:
				_err(mw, "'lane' must be an object")
			else:
				_require_fields(mw + " lane", mark_lane, ["from", "name"])
				if not ports.has(str((mark_lane as Dictionary).get("from", ""))):
					_err(mw, "lane 'from' must be a port")
				_ref_condition(mw + " lane", (mark_lane as Dictionary).get("known"))
	for lane_v: Variant in db.lanes.get("lanes", []):
		if not lane_v is Dictionary:
			_err(where, "lanes must be objects")
			continue
		var lane: Dictionary = lane_v
		var ends: Variant = lane.get("between", [])
		var lw := "%s lane %s" % [where, lane.get("name", "?")]
		if not ends is Array or (ends as Array).size() != 2 or not ports.has(str(ends[0])) or not ports.has(str(ends[1])) or str(ends[0]) == str(ends[1]):
			_err(lw, "'between' must name two different ports")
			continue
		_ref_condition(lw, lane.get("open"))
		_ref_condition(lw, lane.get("sailed"))
		var lane_knots: Variant = lane.get("knots", {})
		if not lane_knots is Dictionary:
			_err(lw, "'knots' must map each end to a knot")
			continue
		for end: Variant in ends:
			var to := str(end)
			if not (lane_knots as Dictionary).has(to):
				_err(lw, "no knot sails it towards '%s'" % to)
				continue
			_check_lane_knot(lw, knots, str(lane_knots[to]), str((ports[to] as Dictionary).get("region", "")), to)


func _check_map_point(where: String, point: Variant) -> void:
	if not point is Array or (point as Array).size() != 2 \
			or not (point as Array).all(func(v: Variant) -> bool: return v is float or v is int) or float(point[0]) < 0.0 or float(point[0]) > 1.0 \
			or float(point[1]) < 0.0 or float(point[1]) > 1.0:
		_err(where, "'map' must be [x, y] within 0..1")


## A voyage knot must exist and (on its own or through a goto) set the ferry's flag to the
## port and travel to the port's region.
func _check_lane_knot(where: String, knots: Dictionary, knot_name: String, region: String, port_id: String) -> void:
	if not knots.has(knot_name):
		_err(where, "knot '%s' is not in the lanes dialogue" % knot_name)
		return
	var seen: Dictionary = {}
	var queue: Array[String] = [knot_name]
	var travels := false
	var sets := false
	while not queue.is_empty():
		var k: String = queue.pop_back()
		if seen.has(k) or not knots.has(k) or not knots[k] is Array:
			continue
		seen[k] = true
		for step: Variant in knots[k]:
			if not step is Dictionary:
				continue
			var st: Dictionary = step
			if st.get("travel") is Array and str((st["travel"] as Array)[0]) == region:
				travels = true
			if st.get("set") is Dictionary and (st["set"] as Dictionary).has(Lanes.FLAG) and str(st["set"][Lanes.FLAG]) == port_id:
				sets = true
			if st.has("goto"):
				queue.append(str(st["goto"]))
	if not travels or not sets:
		_err(where, "knot '%s' must set %s=%s and travel to %s" % [knot_name, Lanes.FLAG, port_id, region])


func _validate_flags() -> void:
	for id: String in db.flags:
		var entry: Variant = db.flags[id]
		if not entry is Dictionary or str((entry as Dictionary).get("description", "")).is_empty():
			_err("data/flags.json", "flag '%s' needs a description" % id)
		if id != id.to_snake_case() or id.contains(" "):
			_err("data/flags.json", "flag '%s' must be snake_case" % id)
		if not entry is Dictionary:
			continue
		# A string flag lists every value it can take, its default first (Day 44).
		var default: Variant = (entry as Dictionary).get("default", false)
		var values: Variant = (entry as Dictionary).get("values")
		if default is String and values == null:
			_err("data/flags.json", "string flag '%s' needs a 'values' list" % id)
		elif values != null:
			if not default is String:
				_err("data/flags.json", "flag '%s' has 'values' but a non-string default" % id)
			elif not values is Array or (values as Array).is_empty() or (values as Array).any(func(v: Variant) -> bool: return not v is String):
				_err("data/flags.json", "flag '%s' values must be a list of strings" % id)
			elif not (values as Array).has(default):
				_err("data/flags.json", "flag '%s' default %s is not among its values" % [id, JSON.stringify(default)])


## `light` is only for model props, and a model standing in for a shape that lights itself
## (signal_lantern, beacon_light) must bring its own, or the lit version goes dark.
func _check_prop_light(where: String, prop: Dictionary, model: String) -> void:
	var shape := str(prop.get("shape", ""))
	if not prop.has("light"):
		if not model.is_empty() and shape in PropFactory.LIT_SHAPES:
			_err(where, "model prop standing in for '%s' needs a 'light'" % shape)
		return
	if model.is_empty():
		_err(where, "prop 'light' needs a 'model' (shape '%s' builds its own)" % shape)
	if not prop["light"] is Dictionary:
		_err(where, "prop 'light' must be an object {color, energy, range, offset}")
		return
	var light: Dictionary = prop["light"]
	if light.has("color") and not _valid_color(str(light["color"])):
		_err(where, "prop light has unknown color '%s'" % light["color"])
	for key: String in ["energy", "range"]:
		if light.has(key) and not (light[key] is float or light[key] is int):
			_err(where, "prop light %s must be a number" % key)


## `colliders` (model props only): extra boxes [{size: [w,h,d], offset: [x,y,z]}] beside the
## single `collider`, for models that aren't one block (Mara's porch and steps).
func _check_prop_colliders(where: String, prop: Dictionary, model: String) -> void:
	if not prop.has("colliders"):
		return
	if model.is_empty():
		_err(where, "prop 'colliders' needs a 'model' (shapes build their own)")
	if not prop["colliders"] is Array:
		_err(where, "prop 'colliders' must be a list of {size, offset}")
		return
	for entry: Variant in prop["colliders"]:
		if not entry is Dictionary or not _is_vector((entry as Dictionary).get("size")) \
				or ((entry as Dictionary).has("offset") and not _is_vector(entry["offset"])):
			_err(where, "prop collider must be {size: [w,h,d], offset: [x,y,z]}")


## `float` (model props only; FloatingProp): known keys, numbers, `foam` = [rx, rz] > 0.
func _check_prop_float(where: String, prop: Dictionary, model: String) -> void:
	if not prop.has("float"):
		return
	if model.is_empty():
		_err(where, "prop 'float' needs a 'model'")
	if not prop["float"] is Dictionary:
		_err(where, "prop 'float' must be an object {bob, roll, period, foam, foam_y}")
		return
	var spec: Dictionary = prop["float"]
	for key: String in spec:
		if key not in FloatingProp.KEYS:
			_err(where, "prop float has unknown key '%s'" % key)
	for key: String in ["bob", "roll", "period", "foam_y"]:
		if spec.has(key) and not (spec[key] is float or spec[key] is int):
			_err(where, "prop float %s must be a number" % key)
	if spec.has("foam"):
		var foam: Variant = spec["foam"]
		if not (foam is Array and (foam as Array).size() == 2 and (foam as Array).all(
				func(v: Variant) -> bool: return (v is float or v is int) and float(v) > 0.0)):
			_err(where, "prop float foam must be [rx, rz] (positive numbers)")


## `wading` (model props only, not floating ones): foam rings [[x, z, radius], ...] round
## legs standing in the sea.
func _check_prop_wading(where: String, prop: Dictionary, model: String) -> void:
	if not prop.has("wading"):
		return
	if model.is_empty():
		_err(where, "prop 'wading' needs a 'model'")
	if prop.has("float"):
		_err(where, "prop 'wading' can't go with 'float' (a floating prop has its own foam)")
	if not prop["wading"] is Array or (prop["wading"] as Array).is_empty():
		_err(where, "prop 'wading' must be a list of [x, z, radius]")
		return
	for ring: Variant in prop["wading"]:
		if not (ring is Array and (ring as Array).size() == 3 and (ring as Array).all(
				func(v: Variant) -> bool: return v is float or v is int) and float(ring[2]) > 0.0):
			_err(where, "prop wading ring must be [x, z, radius] (radius > 0)")


## `over_water` (model props only, Day 36): true draws the model's surfaces after the
## transparent sea (a glint lying on it, like the lit Heron's gold), so the water can't hide it.
func _check_prop_over_water(where: String, prop: Dictionary, model: String) -> void:
	if not prop.has("over_water"):
		return
	if not prop["over_water"] is bool:
		_err(where, "prop 'over_water' must be true or false")
	if model.is_empty():
		_err(where, "prop 'over_water' needs a 'model'")


## `smoke` (model props only): vents [[x, y, z], ...] in model space that smoke rises from;
## optional `smoke_scale` (Day 80) thins or thickens the column.
func _check_prop_smoke(where: String, prop: Dictionary, model: String) -> void:
	if not prop.has("smoke"):
		return
	if model.is_empty():
		_err(where, "prop 'smoke' needs a 'model'")
	if not prop["smoke"] is Array or (prop["smoke"] as Array).is_empty():
		_err(where, "prop 'smoke' must be a list of [x, y, z] vents")
		return
	for vent: Variant in prop["smoke"]:
		if not _is_vector(vent):
			_err(where, "prop smoke vent must be [x, y, z]")
	if prop.has("smoke_scale"):
		var s: Variant = prop["smoke_scale"]
		if not (s is float or s is int) or float(s) < PropSmoke.MIN_SCALE or float(s) > PropSmoke.MAX_SCALE:
			_err(where, "prop 'smoke_scale' must be a number %.2f..%.1f" % [PropSmoke.MIN_SCALE, PropSmoke.MAX_SCALE])


## An NPC's (or placement's) `halo`: {"part": one of the rig parts, optional `size` > 0 and
## `strength` 0..2} — a glow on that part's lit lantern.
func _check_npc_halo(where: String, data: Dictionary) -> void:
	if not data.has("halo"):
		return
	if not data["halo"] is Dictionary:
		_err(where, "halo must be {\"part\": ..., \"size\": ..., \"strength\": ...}")
		return
	var halo: Dictionary = data["halo"]
	if str(halo.get("part", "")) not in CharacterRig.PARTS:
		_err(where, "halo part must be one of %s" % [CharacterRig.PARTS])
	if halo.has("size") and not ((halo["size"] is float or halo["size"] is int) and float(halo["size"]) > 0.0):
		_err(where, "halo size must be a number > 0")
	if halo.has("strength") and not ((halo["strength"] is float or halo["strength"] is int) and float(halo["strength"]) >= 0.0 and float(halo["strength"]) <= 2.0):
		_err(where, "halo strength must be 0..2")


## `halo` (model props only): [x, y, z] in model space where a soft lantern glow hangs, with an
## optional `halo_size` (metres, > 0), `halo_strength` and `halo_bloom` (0..2).
func _check_prop_halo(where: String, prop: Dictionary, model: String) -> void:
	if not prop.has("halo"):
		return
	if model.is_empty():
		_err(where, "prop 'halo' needs a 'model'")
	if not _is_vector(prop["halo"]):
		_err(where, "prop 'halo' must be [x, y, z]")
	if prop.has("halo_size") and not ((prop["halo_size"] is float or prop["halo_size"] is int) and float(prop["halo_size"]) > 0.0):
		_err(where, "prop 'halo_size' must be a number > 0")
	for key: String in ["halo_strength", "halo_bloom"]:
		if prop.has(key) and not ((prop[key] is float or prop[key] is int) and float(prop[key]) >= 0.0 and float(prop[key]) <= 2.0):
			_err(where, "prop '%s' must be a number in 0..2" % key)


func _is_vector(value: Variant) -> bool:
	return value is Array and (value as Array).size() == 3 \
			and (value as Array).all(func(v: Variant) -> bool: return v is float or v is int)


func _valid_color(value: String) -> bool:
	return PropFactory.PALETTE.has(value) or Color.html_is_valid(value)


func _validate_item(id: String, item: Dictionary) -> void:
	var where := "item " + id
	_require_fields(where, item, ["name", "description", "kind"])
	if item.has("color") and not _valid_color(str(item["color"])):
		_err(where, "invalid color '%s' (palette name or #hex)" % item["color"])
	if str(item.get("kind", "")) not in ITEM_KINDS:
		_err(where, "kind must be one of %s" % [ITEM_KINDS])
	if item.has("memory"):
		_check_memory(where, item["memory"])


## An item's `memory` (Day 70) is a dialogue the satchel plays on "Remember". Remembering can be
## done any number of times from anywhere, so the memory may only speak (and play sounds): no
## flags, quests, items or travel.
func _check_memory(where: String, memory: Variant) -> void:
	if not memory is String or str(memory).is_empty():
		_err(where, "'memory' must be a dialogue id")
		return
	_ref_dialogue(where, str(memory))
	var knots: Variant = db.get_dialogue(str(memory)).get("knots", {})
	if not knots is Dictionary:
		return
	for knot_name: String in knots:
		if not knots[knot_name] is Array:
			continue
		for step: Variant in knots[knot_name]:
			if not step is Dictionary:
				continue
			var parts: Array = [step]
			if (step as Dictionary).get("choice") is Array:
				parts.append_array(step["choice"])
			for part: Variant in parts:
				if not part is Dictionary:
					continue
				for key in DialogueRunner.EFFECT_KEYS:
					if key != "sound" and (part as Dictionary).has(key):
						_err(where, "memory '%s' knot '%s' has '%s': a memory may only speak" % [memory, knot_name, key])


## data/audio.json: every sound a valid recipe (or file) on a real bus, and every sound the
## config names exists (Day 46).
func _validate_audio() -> void:
	var where := "data/audio.json"
	for id: String in db.sounds:
		var entry: Variant = db.sounds[id]
		if not entry is Dictionary:
			_err(where, "sound '%s' must be an object" % id)
			continue
		if str((entry as Dictionary).get("bus", "")) not in GameSettings.BUSES:
			_err(where, "sound '%s' bus must be one of %s" % [id, GameSettings.BUSES])
		if (entry as Dictionary).has("file"):
			if not ResourceLoader.exists(str(entry["file"])):
				_err(where, "sound '%s' file '%s' does not exist" % [id, entry["file"]])
		else:
			_check_recipe(where + " sound '%s'" % id, entry)
	var footsteps: Dictionary = db.audio.get("footsteps", {}) if db.audio.get("footsteps") is Dictionary else {}
	var surfaces: Variant = footsteps.get("surfaces", {})
	if not surfaces is Dictionary or (surfaces as Dictionary).is_empty():
		_err(where, "footsteps.surfaces must map surface names to sounds")
	else:
		for surface: String in surfaces:
			_ref_sound(where + " footsteps", str(surfaces[surface]))
		for needed: String in [str(footsteps.get("default", "")), "boards", "wade"]:
			if not (surfaces as Dictionary).has(needed):
				_err(where, "footsteps.surfaces needs '%s'" % needed)
	_check_voice(where + " player_voice", db.audio.get("player_voice"))
	var greying: Dictionary = db.audio.get("greying", {}) if db.audio.get("greying") is Dictionary else {}
	for key: String in ["heart", "turn_back"]:
		if greying.has(key):
			_ref_sound(where + " greying." + key, str(greying[key]))
	if greying.has("heart") and not bool((db.sounds.get(str(greying["heart"]), {}) as Dictionary).get("loop", false)):
		_err(where, "greying.heart must be a looping sound")
	var events: Variant = db.audio.get("events", {})
	if events is Dictionary:
		for key: String in events:
			_ref_sound(where + " events." + key, str(events[key]))
	var music: Variant = db.audio.get("music", {})
	if music is Dictionary and (music as Dictionary).has("title"):
		_ref_music(where + " music.title", str(music["title"]))
		_ref_loop(where + " music.title", str(music["title"]))
	var work: Variant = db.audio.get("work", {})
	if not work is Dictionary:
		_err(where, "'work' must map idle styles to {sound, volume, range}")
	else:
		for style: String in work:
			if style == "note":
				continue
			if style not in CharacterRig.STYLES:
				_err(where, "work '%s' is not an idle style (%s)" % [style, CharacterRig.STYLES])
			if not work[style] is Dictionary or not (work[style] as Dictionary).has("sound"):
				_err(where, "work '%s' must be {sound, volume, range}" % style)
				continue
			_ref_sound(where + " work." + style, str(work[style]["sound"]))
			if bool((db.sounds.get(str(work[style]["sound"]), {}) as Dictionary).get("loop", false)):
				_err(where, "work '%s' plays once a stroke; '%s' loops" % [style, work[style]["sound"]])


func _check_recipe(where: String, recipe: Dictionary, depth: int = 0) -> void:
	var kind := str(recipe.get("kind", ""))
	if kind not in SoundSynth.KINDS:
		_err(where, "kind must be one of %s" % [SoundSynth.KINDS])
		return
	for key: String in ["length", "gain", "attack", "decay", "release", "lowpass", "highpass", "freq", "rate", "swell", "gusts", "pitch", "tempo", "ring", "note_attack", "note_release", "legato"]:
		if recipe.has(key) and (not (recipe[key] is float or recipe[key] is int) or float(recipe[key]) < 0.0):
			_err(where, "'%s' must be a number ≥ 0" % key)
	if depth == 0 and not recipe.has("length"):
		_err(where, "needs a 'length' (s)")
	if float(recipe.get("length", 1.0)) <= 0.0 or float(recipe.get("length", 1.0)) > SoundSynth.MAX_LENGTH:
		_err(where, "length must be in (0, %s] s" % SoundSynth.MAX_LENGTH)
	if float(recipe.get("gain", 0.8)) > 1.0:
		_err(where, "gain must be ≤ 1")
	if recipe.has("color") and str(recipe["color"]) not in SoundSynth.NOISE_COLORS:
		_err(where, "color '%s' must be one of %s" % [recipe["color"], SoundSynth.NOISE_COLORS])
	if kind == "chime" and (not recipe.get("notes") is Array or (recipe["notes"] as Array).is_empty()):
		_err(where, "a chime needs 'notes'")
	if kind == "melody":
		_check_melody(where, recipe)
	if kind == "mix":
		if not recipe.get("parts") is Array or (recipe["parts"] as Array).is_empty():
			_err(where, "a mix needs 'parts'")
		else:
			for part: Variant in recipe["parts"]:
				if part is Dictionary:
					# A part without its own length runs the whole mix's.
					var sub: Dictionary = (part as Dictionary).duplicate()
					if not sub.has("length") and recipe.has("length"):
						sub["length"] = recipe["length"]
					_check_recipe(where + " part", sub, depth + 1)
				else:
					_err(where, "mix parts must be recipes")


## A melody: notes as [pitch, beats] with readable pitches, and all of it inside its length.
func _check_melody(where: String, recipe: Dictionary) -> void:
	var notes: Variant = recipe.get("notes")
	if not notes is Array or (notes as Array).is_empty():
		_err(where, "a melody needs 'notes' [[pitch, beats]…]")
		return
	for note: Variant in notes:
		if not note is Array or (note as Array).size() != 2 or not (note[1] is float or note[1] is int) or float(note[1]) <= 0.0:
			_err(where, "melody note %s must be [pitch, beats > 0]" % [note])
		elif SoundSynth.note_hz(note[0]) < 0.0:
			_err(where, "melody pitch '%s' must be a note name (\"D4\", \"F#3\"), Hz or \"-\"" % [note[0]])
	if float(recipe.get("tempo", 60.0)) <= 0.0:
		_err(where, "tempo must be > 0")
	var length := float(recipe.get("length", SoundSynth.MAX_LENGTH))
	if SoundSynth.melody_seconds(recipe) > length + 0.001:
		_err(where, "the melody runs %.2f s, longer than its length (%.2f s)" % [SoundSynth.melody_seconds(recipe), length])


## Music is a sound on the Music bus.
func _ref_music(where: String, id: String) -> void:
	_ref_sound(where, id)
	if db.sounds.has(id) and str((db.sounds[id] as Dictionary).get("bus", "")) != "Music":
		_err(where, "music '%s' must be on the Music bus" % id)


func _ref_sound(where: String, id: String) -> void:
	_sounds_used[id] = true
	if not db.sounds.has(id):
		_err(where, "unknown sound '%s' (data/audio.json)" % id)


## A voice: {sound, pitch} with a known sound and a sane pitch.
func _check_voice(where: String, voice: Variant) -> void:
	if voice == null:
		return
	if not voice is Dictionary or not (voice as Dictionary).has("sound"):
		_err(where, "voice must be {sound, pitch}")
		return
	_ref_sound(where, str(voice["sound"]))
	var pitch := float((voice as Dictionary).get("pitch", 1.0))
	if pitch < 0.3 or pitch > 3.0:
		_err(where, "voice pitch must be in 0.3..3")


## A sound something plays as a loop (an ambience layer, a prop's sound) must loop.
func _ref_loop(where: String, id: String) -> void:
	_ref_sound(where, id)
	if db.sounds.has(id) and not bool((db.sounds[id] as Dictionary).get("loop", false)):
		_err(where, "sound '%s' must loop (\"loop\": true)" % id)


func _validate_npc(id: String, npc: Dictionary) -> void:
	var where := "npc " + id
	_require_fields(where, npc, ["name", "dialogue", "color"])
	if npc.has("dialogue"):
		_ref_dialogue(where, str(npc["dialogue"]))
	if npc.has("color") and not _valid_color(str(npc["color"])):
		_err(where, "invalid color '%s' (palette name or #hex)" % npc["color"])
	if npc.has("model"):
		_ref_character_model(where, str(npc["model"]))
	if npc.has("voice"):
		_check_voice(where, npc["voice"])
	if npc.has("faces_player") and not npc["faces_player"] is bool:
		_err(where, "faces_player must be true or false")
	if npc.has("idle") and str(npc["idle"]) not in CharacterRig.STYLES:
		_err(where, "idle must be one of %s" % [CharacterRig.STYLES])
	_check_npc_halo(where, npc)
	if npc.has("names"):
		if not npc["names"] is Array:
			_err(where, "names must be a list of {if, name}")
		else:
			for entry: Variant in npc["names"]:
				if not entry is Dictionary or not (entry as Dictionary).has("if") or str((entry as Dictionary).get("name", "")).is_empty():
					_err(where, "each names entry needs an 'if' and a non-empty 'name'")
				else:
					_ref_condition(where, (entry as Dictionary)["if"])


## A character model must exist and be a scene (the rig tolerates missing parts, so the part
## layout is checked by tests/test_characters.gd instead).
func _ref_character_model(where: String, path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		_err(where, "character model '%s' does not exist" % path)
	elif not path.ends_with(".glb") and not path.ends_with(".tscn"):
		_err(where, "character model '%s' must be a .glb or .tscn scene" % path)


func _validate_quest(id: String, quest: Dictionary) -> void:
	var where := "quest " + id
	_require_fields(where, quest, ["title", "description"])
	var stages: Variant = quest.get("stages", [])
	if not stages is Array or (stages as Array).is_empty():
		_err(where, "needs at least one stage")
		return
	var seen: Dictionary = {}
	for stage: Variant in stages:
		if not stage is Dictionary:
			_err(where, "stage must be an object")
			continue
		var sid := str((stage as Dictionary).get("id", ""))
		if sid.is_empty() or str((stage as Dictionary).get("text", "")).is_empty():
			_err(where, "every stage needs 'id' and 'text'")
		if seen.has(sid):
			_err(where, "duplicate stage '%s'" % sid)
		seen[sid] = true
	if quest.has("giver") and not db.npcs.has(str(quest["giver"])):
		_err(where, "giver npc '%s' does not exist" % quest["giver"])
	if quest.has("region") and not db.regions.has(str(quest["region"])):
		_err(where, "region '%s' does not exist" % quest["region"])
	# Which act a quest belongs to (Day 80): the act's end card names it if still in progress.
	# Quests that run across acts (`future`, the Wakebearer's own past) carry none.
	if quest.has("act"):
		if not _act_ids().has(str(quest["act"])):
			_err(where, "act '%s' is not an act_ends id in game.json" % quest["act"])
	elif not quest.get("future", false):
		_err(where, "needs an 'act' (an act_ends id), or 'future' if it runs across acts")


func _act_ids() -> Dictionary:
	var out: Dictionary = {}
	var acts: Variant = db.game.get("act_ends", [])
	if acts is Array:
		for act: Variant in acts:
			if act is Dictionary:
				out[str((act as Dictionary).get("id", ""))] = true
	return out


## `spawn_facing` (Day 88): {spawn: [x, z]}, a named spawn and a point away from it.
func _validate_spawn_facing(where: String, region: Dictionary) -> void:
	var facing: Variant = region.get("spawn_facing", {})
	if not facing is Dictionary:
		_err(where, "spawn_facing must be an object of spawn: [x, z]")
		return
	var spawns: Dictionary = region.get("spawn_points", {}) if region.get("spawn_points", {}) is Dictionary else {}
	for spawn: String in facing:
		var at: Variant = facing[spawn]
		if not spawns.has(spawn):
			_err(where, "spawn_facing names unknown spawn '%s'" % spawn)
		elif not at is Array or (at as Array).size() != 2:
			_err(where, "spawn_facing '%s' must be [x, z]" % spawn)
		else:
			var from := JsonUtil.to_vector3(spawns[spawn])
			if Vector2(float(at[0]) - from.x, float(at[1]) - from.z).length() < 0.5:
				_err(where, "spawn_facing '%s' points at the spawn itself" % spawn)


func _validate_region(id: String, region: Dictionary) -> void:
	var where := "region " + id
	_require_fields(where, region, ["name", "description"])
	var spawns: Variant = region.get("spawn_points", {})
	if not spawns is Dictionary or not (spawns as Dictionary).has("default"):
		_err(where, "spawn_points must contain 'default'")
	_validate_spawn_facing(where, region)
	_validate_region_audio(where, region)
	for placement: Dictionary in region.get("npcs", []):
		var npc_id := str(placement.get("npc", ""))
		# A placement may pose the NPC differently there (Hob seated at the camp): its own
		# `model` and `idle` override the NPC's.
		if placement.has("model"):
			_ref_character_model(where, str(placement["model"]))
		if placement.has("idle") and str(placement["idle"]) not in CharacterRig.STYLES:
			_err(where, "npc '%s' placement idle must be one of %s" % [npc_id, CharacterRig.STYLES])
		_check_npc_halo("%s npc '%s'" % [where, npc_id], placement)
		if not db.npcs.has(npc_id):
			_err(where, "places unknown npc '%s'" % npc_id)
		else:
			# An NPC may stand in several places only if every placement is conditional
			# (e.g. Pell on the beach until the ferry comes, then on the dock).
			var placements: Array = _npcs_placed.get(npc_id, [])
			placements.append({"region": id, "conditional": placement.has("if"), "if": placement.get("if")})
			_npcs_placed[npc_id] = placements
			if placements.size() > 1 and placements.any(func(p: Dictionary) -> bool: return not p["conditional"]):
				_err(where, "npc '%s' is placed more than once (also in %s); every placement then needs an 'if'" \
						% [npc_id, placements[0]["region"]])
		_ref_condition(where, placement.get("if"))
	for prop: Dictionary in region.get("props", []):
		var model := str(prop.get("model", ""))
		if not model.is_empty() and not ResourceLoader.exists(model):
			_err(where, "prop model '%s' does not exist" % model)
		if model.is_empty() and str(prop.get("shape", "")) not in PropFactory.SHAPES:
			_err(where, "prop needs 'model' or a 'shape' in %s" % [PropFactory.SHAPES])
		_check_prop_light(where, prop, model)
		_check_prop_colliders(where, prop, model)
		_check_prop_float(where, prop, model)
		_check_prop_wading(where, prop, model)
		_check_prop_over_water(where, prop, model)
		if prop.has("shadow") and not prop["shadow"] is bool:
			_err(where, "prop 'shadow' must be true or false")
		_check_prop_smoke(where, prop, model)
		_check_prop_halo(where, prop, model)
		_check_prop_figure(where, prop, model)
		_ref_condition(where, prop.get("if"))
	var fog: Dictionary = region.get("fog", {})
	for override: Variant in fog.get("overrides", []):
		if not override is Dictionary or not (override as Dictionary).has("if"):
			_err(where, "fog override needs an 'if' condition")
			continue
		_ref_condition(where, override["if"])
		if override.has("density") and not (override["density"] is float or override["density"] is int):
			_err(where, "fog override density must be a number")
		if override.has("color") and not _valid_color(str(override["color"])):
			_err(where, "fog override has unknown color '%s'" % override["color"])
	_check_region_light(where, region)
	_check_region_water(where, region)
	for pickup: Dictionary in region.get("pickups", []):
		var pid := str(pickup.get("id", ""))
		if pid.is_empty():
			_err(where, "pickup missing 'id'")
		var item_id := str(pickup.get("item", ""))
		if not db.items.has(item_id):
			_err(where, "pickup '%s' gives unknown item '%s'" % [pid, item_id])
		elif str(db.get_item(item_id).get("kind", "")) == "own":
			_err(where, "pickup '%s' lies about: '%s' is the Wakebearer's own, and only the ember gives those up" % [pid, item_id])
		_items_obtainable[item_id] = true
		_ref_condition(where, pickup.get("if"))
		for flag_id: String in (pickup.get("set", {}) as Dictionary):
			_ref_flag_set(where, flag_id, pickup["set"][flag_id])
		if pickup.has("quest_stage"):
			var pair: Variant = pickup["quest_stage"]
			if not pair is Array or (pair as Array).size() != 2:
				_err(where, "pickup quest_stage must be [quest_id, stage_id]")
			else:
				_ref_stage(where, str(pair[0]), str(pair[1]))
	var object_ids: Dictionary = {}
	for object: Dictionary in region.get("objects", []):
		var oid := str(object.get("id", ""))
		if oid.is_empty():
			_err(where, "object missing 'id'")
		elif object_ids.has(oid):
			_err(where, "duplicate object id '%s'" % oid)
		object_ids[oid] = true
		if str(object.get("prompt", "")).is_empty():
			_err(where, "object '%s' needs a 'prompt'" % oid)
		_ref_dialogue(where, str(object.get("dialogue", "")))
		_ref_condition(where, object.get("if"))
		var glint: Variant = object.get("glint", null)
		if glint != null and not (glint is bool or _is_vector(glint)):
			_err(where, "object '%s' glint must be false or [x, y, z]" % oid)
	for exit: Dictionary in region.get("exits", []):
		_ref_condition(where, exit.get("requires"))
		if exit.has("requires") and str(exit.get("locked_text", "")).is_empty():
			_err(where, "exit with 'requires' needs a 'locked_text'")
		var to := str(exit.get("to", ""))
		if not db.regions.has(to):
			_err(where, "exit leads to unknown region '%s'" % to)
			continue
		var target_spawns: Dictionary = db.get_region(to).get("spawn_points", {})
		if not target_spawns.has(str(exit.get("spawn", "default"))):
			_err(where, "exit spawn '%s' not in region '%s'" % [exit.get("spawn", "default"), to])
	_check_prop_variants(where, region)
	_validate_events(where, region)
	_validate_cressets(where, region)
	_validate_greying(where, region)
	if region.has("ground"):
		_validate_ground(where, region)


## Region `events` (arrival events, main.gd): each needs an id, an `if`, a dialogue and a
## `set` that switches its own `if` off (a `!flag:x` term with x in `set`), so an event can
## never fire twice.
## A region's `ambience` layers, `footsteps` surfaces and its props' `sound`s (Day 46).
func _validate_region_audio(where: String, region: Dictionary) -> void:
	var ambience: Variant = region.get("ambience", [])
	if not ambience is Array:
		_err(where, "ambience must be a list of {sound, volume, if}")
	else:
		for layer: Variant in ambience:
			if not layer is Dictionary or not (layer as Dictionary).has("sound"):
				_err(where, "each ambience layer needs a 'sound'")
				continue
			_ref_loop(where + " ambience", str(layer["sound"]))
			var volume := float((layer as Dictionary).get("volume", 1.0))
			if volume <= 0.0 or volume > 1.0:
				_err(where, "ambience volume must be in (0, 1]")
			_ref_condition(where, (layer as Dictionary).get("if"))
	var surfaces: Dictionary = (db.audio.get("footsteps", {}) as Dictionary).get("surfaces", {})
	for key: String in ["footsteps", "footsteps_raised"]:
		if region.has(key) and not surfaces.has(str(region[key])):
			_err(where, "%s '%s' is not a surface in data/audio.json (%s)" % [key, region[key], surfaces.keys()])
	for prop: Dictionary in region.get("props", []):
		if prop.has("sound"):
			if not prop["sound"] is Dictionary or not (prop["sound"] as Dictionary).has("id"):
				_err(where, "prop sound must be {id, offset, range, volume}")
				continue
			_ref_loop(where + " prop " + str(prop.get("model", prop.get("shape", "?"))).get_file(), str(prop["sound"]["id"]))
			if prop["sound"].has("offset") and not _is_vector(prop["sound"]["offset"]):
				_err(where, "prop sound offset must be [x, y, z]")


func _validate_events(where: String, region: Dictionary) -> void:
	var events: Variant = region.get("events", [])
	if not events is Array:
		_err(where, "events must be a list")
		return
	var ids: Dictionary = {}
	for event: Variant in events:
		if not event is Dictionary:
			_err(where, "events entries must be objects")
			continue
		var e: Dictionary = event
		for key: String in e:
			if key not in ["id", "if", "dialogue", "set", "note"]:
				_err(where, "event has unknown key '%s'" % key)
		var eid := str(e.get("id", ""))
		if eid.is_empty() or ids.has(eid):
			_err(where, "events need a unique 'id' ('%s')" % eid)
		ids[eid] = true
		if not e.has("if"):
			_err(where, "event '%s' needs an 'if'" % eid)
		_ref_condition(where, e.get("if"))
		_ref_dialogue(where, str(e.get("dialogue", "")))
		var sets: Variant = e.get("set", {})
		if not sets is Dictionary or (sets as Dictionary).is_empty():
			_err(where, "event '%s' needs a 'set' that switches it off" % eid)
			continue
		var once := false
		for flag_id: String in (sets as Dictionary):
			_ref_flag_set(where, flag_id)
			if ("!flag:" + flag_id) in Conditions.terms(e.get("if")):
				once = true
		if not once:
			_err(where, "event '%s' must read one of its 'set' flags as '!flag:<id>' in its 'if' (fires once)" % eid)


## A figure prop (`idle` on a prop): a character model (rig contract) and a known idle style.
func _check_prop_figure(where: String, prop: Dictionary, model: String) -> void:
	if not prop.has("idle"):
		if prop.has("averts"):
			_err(where, "'averts' is for figure props (a prop with an 'idle')")
		return
	if model.is_empty():
		_err(where, "prop 'idle' needs a character 'model'")
		return
	if not model.begins_with("res://assets/models/characters/"):
		_err(where, "prop 'idle' needs a character model (assets/models/characters/), not '%s'" % model)
	if str(prop["idle"]) not in CharacterRig.STYLES:
		_err(where, "prop idle must be one of %s" % [CharacterRig.STYLES])
	if prop.has("float") or prop.has("wading"):
		_err(where, "a figure prop can't 'float' or wade")
	if prop.has("averts"):
		var averts: Variant = prop["averts"]
		if not averts is Dictionary or not (averts as Dictionary).has("if"):
			_err(where, "figure 'averts' must be {\"if\": <condition>, \"radius\"?: metres}")
			return
		for key: String in averts:
			if key not in ["if", "radius"]:
				_err(where, "figure 'averts' has unknown key '%s'" % key)
		_ref_condition(where + " averts", averts["if"])
		if averts.has("radius") and not (typeof(averts["radius"]) in [TYPE_INT, TYPE_FLOAT] and float(averts["radius"]) >= 1.0 and float(averts["radius"]) <= 20.0):
			_err(where, "figure 'averts' radius must be a number of metres in 1..20")


## Region `water` (WaterBuilder.SETTINGS): known keys with numbers in range, palette colours;
## needs a `water_level`.
func _check_region_water(where: String, region: Dictionary) -> void:
	if not region.has("water"):
		return
	if not region["water"] is Dictionary:
		_err(where, "water must be an object")
		return
	if not region.has("water_level"):
		_err(where, "water settings need a water_level")
	var spec: Dictionary = region["water"]
	for key: String in spec:
		if key == "note":
			continue
		if key in WaterBuilder.COLOR_KEYS:
			if not _valid_color(str(spec[key])):
				_err(where, "water %s has unknown color '%s'" % [key, spec[key]])
		elif WaterBuilder.SETTINGS.has(key):
			var range_: Vector2 = WaterBuilder.SETTINGS[key]
			if not (spec[key] is float or spec[key] is int) or float(spec[key]) < range_.x or float(spec[key]) > range_.y:
				_err(where, "water %s must be a number in [%s, %s]" % [key, range_.x, range_.y])
		else:
			_err(where, "water has unknown key '%s'" % key)


## Region `light` (RegionMood.light): known keys, palette/#hex colours, numeric values;
## each override needs an `if`.
func _check_region_light(where: String, region: Dictionary) -> void:
	if not region.has("light"):
		return
	if not region["light"] is Dictionary:
		_err(where, "light must be an object")
		return
	var light: Dictionary = region["light"]
	var blocks: Array = [light]
	for override: Variant in light.get("overrides", []):
		if not override is Dictionary or not (override as Dictionary).has("if"):
			_err(where, "light override needs an 'if' condition")
			continue
		_ref_condition(where, override["if"])
		blocks.append(override)
	for block: Dictionary in blocks:
		for key: String in block:
			if key in ["note", "overrides", "if"]:
				continue
			if not RegionMood.LIGHT_DEFAULTS.has(key):
				_err(where, "light has unknown key '%s'" % key)
			elif key in RegionMood.LIGHT_COLOR_KEYS:
				if not _valid_color(str(block[key])):
					_err(where, "light %s has unknown color '%s'" % [key, block[key]])
			elif not (block[key] is float or block[key] is int):
				_err(where, "light %s must be a number" % key)
			elif key == "shadow" and (float(block[key]) < 0.0 or float(block[key]) > 1.0):
				_err(where, "light shadow must be 0..1")


## Greying areas: well-formed shapes and numbers, and no spawn point in the fog (the player
## is turned back to clear ground, and a spawn is the last resort).
func _validate_greying(where: String, region: Dictionary) -> void:
	var areas: Variant = region.get("greying", [])
	_greying_ok = false
	if not areas is Array:
		_err(where, "greying must be a list of areas")
		return
	var errors_before := errors.size()
	for area: Variant in areas:
		if not area is Dictionary:
			_err(where, "greying entries must be objects")
			continue
		for key: String in (area as Dictionary):
			if key not in ["rect", "ellipse", "strength", "falloff", "height", "if", "clear", "forgets", "cresset", "note"]:
				_err(where, "greying area has unknown key '%s'" % key)
		var shapes := 0
		for shape_key: String in ["rect", "ellipse"]:
			if area.has(shape_key):
				shapes += 1
				var arr: Variant = area[shape_key]
				if not arr is Array or (arr as Array).size() != 4:
					_err(where, "greying area has a malformed '%s'" % shape_key)
		if shapes != 1:
			_err(where, "greying areas need exactly one of rect/ellipse")
		for num: Array in [["strength", 0.0, 1.0], ["falloff", 0.0, 50.0], ["height", 0.1, 20.0]]:
			if area.has(num[0]):
				var v: Variant = area[num[0]]
				if not (v is float or v is int) or float(v) < float(num[1]) or float(v) > float(num[2]):
					_err(where, "greying %s must be a number in [%s, %s]" % num)
		if area.has("clear") and not area["clear"] is bool:
			_err(where, "greying clear must be true or false")
		if area.has("forgets") and not area["forgets"] is bool:
			_err(where, "greying forgets must be true or false")
		elif area.get("forgets", false) and area.get("clear", false):
			_err(where, "a greying area can't both forget and be clear")
		_ref_condition(where, area.get("if"))
	_greying_ok = errors.size() == errors_before
	if not _greying_ok:
		return
	var all := Greying.worst_case_areas(region)
	for spawn_name: String in region.get("spawn_points", {}):
		var pos := JsonUtil.to_vector3(region["spawn_points"][spawn_name])
		if Greying.depth_at(all, Vector2(pos.x, pos.z)) >= Greying.CLEAR_DEPTH:
			_err(where, "spawn '%s' lies in the Greying (spawns must be clear)" % spawn_name)


## Everything the player must reach can be reached spending at most
## Greying.MAX_ONE_WAY_EMBER, with every fog area present and only the unconditional lights
## (worst case), so they can always get
## there and walk back out before the ember runs out.
func _validate_greying_budget(where: String, region: Dictionary, field: TerrainField, reachable: Dictionary, spots: Array) -> void:
	var areas := Greying.worst_case_areas(region)
	if areas.is_empty() or not _greying_ok:
		return
	# Where the road forgets, nothing is walked without its cressets: _validate_forgetting checks the
	# budget with the lights the way up needs instead.
	if Greying.has_forgetting(areas):
		return
	_check_budget(where, field, reachable, areas, spots)


## Errors for each of `spots` (label, position, reach) costing more than Greying.MAX_ONE_WAY_EMBER to
## reach over `cells` under `areas`.
func _check_budget(where: String, field: TerrainField, cells: Dictionary, areas: Array[Dictionary], spots: Array) -> void:
	var cost := Greying.ember_cost_map(field, cells, areas)
	for spot: Array in spots:
		var pos := JsonUtil.to_vector3(spot[1])
		var radius := float(spot[2])
		var best := INF
		var c := field.cell_of(pos.x, pos.z)
		var r := int(ceil(radius / field.cell)) + 1
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dz)
				if not cost.has(n):
					continue
				var centre := field.vertex_xz(n.x, n.y) + Vector2(field.cell, field.cell) * 0.5
				if centre.distance_to(Vector2(pos.x, pos.z)) <= radius + field.cell * 0.71:
					best = minf(best, float(cost[n]))
		if best != INF and best > Greying.MAX_ONE_WAY_EMBER:
			_err(where, "%s at %s costs %.2f ember to reach through the Greying (max %.2f)" % [spot[0], pos, best, Greying.MAX_ONE_WAY_EMBER])


## Waymark cressets (Day 82, `Cressets`): well-formed entries, unique ids, a declared flag that the
## lighting dialogue sets, and pools of rect/ellipse shapes.
func _validate_cressets(where: String, region: Dictionary) -> void:
	if not region.has("cressets"):
		return
	if not region["cressets"] is Array:
		_err(where, "cressets must be a list")
		return
	var ids: Dictionary = {}
	for entry: Variant in region["cressets"]:
		if not entry is Dictionary:
			_err(where, "cressets entries must be objects")
			continue
		var c: Dictionary = entry
		var cid := str(c.get("id", ""))
		var at := "%s cresset '%s'" % [where, cid]
		for key: String in c:
			if key not in Cressets.KEYS:
				_err(at, "unknown key '%s'" % key)
		if cid.is_empty() or ids.has(cid):
			_err(at, "needs a unique 'id'")
		ids[cid] = true
		if not _is_vector(c.get("position")):
			_err(at, "position must be [x, y, z]")
		var flag := str(c.get("flag", ""))
		if not db.flags.has(flag):
			_err(at, "flag '%s' is not declared in data/flags.json" % flag)
			continue
		_ref_condition(at, c.get("if"))
		var pools: Variant = c.get("pool", [])
		if not pools is Array or (pools as Array).is_empty():
			_err(at, "pool must be a non-empty list of rect/ellipse areas (what the lit fire holds open)")
		if c.has("road"):
			var road: Variant = c["road"]
			var ok := road is Array and (road as Array).size() >= 2
			if ok:
				for point: Variant in road:
					ok = ok and point is Array and (point as Array).size() >= 2
			if not ok:
				_err(at, "road must be a path of at least two [x, z, 0] points")
			else:
				for leg in sawing_legs(road):
					_warn(at, "road leg %s saws on the 1 m grid (run it along an axis or a real diagonal)" % leg)
		var dialogue_id := str(c.get("dialogue", ""))
		_ref_dialogue(at, dialogue_id)
		if db.dialogues.has(dialogue_id) and not _sets_flag(db.get_dialogue(dialogue_id), flag):
			_err(at, "dialogue '%s' never sets %s (lighting it must)" % [dialogue_id, flag])


## True if some step anywhere under `node` sets flag `id` to true.
func _sets_flag(node: Variant, id: String) -> bool:
	if node is Dictionary:
		var set_block: Variant = (node as Dictionary).get("set")
		if set_block is Dictionary and (set_block as Dictionary).get(id) == true:
			return true
		for value: Variant in (node as Dictionary).values():
			if _sets_flag(value, id):
				return true
	elif node is Array:
		for value: Variant in node:
			if _sets_flag(value, id):
				return true
	return false


## The road that forgets (Day 82): where fog `forgets`, the player can only walk where the way is
## remembered (forgetting under Greying.FORGET_DEPTH). Each cresset must be reachable with only the
## cressets before it lit (so they can be lit in order), and everything else with every light lit.
func _validate_forgetting(where: String, region: Dictionary, field: TerrainField, reachable: Dictionary, spots: Array) -> void:
	if not _greying_ok or not Greying.has_forgetting(region.get("greying", [])):
		return
	var spawn: Vector3 = JsonUtil.to_vector3(region.get("spawn_points", {}).get("default", [0, 0, 0]))
	var base := Greying.worst_case_areas(region)
	var lit: Array[Dictionary] = []
	for c: Dictionary in Cressets.of(region):
		var cid := str(c.get("id", ""))
		var pos := JsonUtil.to_vector3(c.get("position"))
		var areas: Array[Dictionary] = base + lit
		var remembered := _remembered_cells(field, reachable, areas, spawn)
		if not field.near_reachable(remembered, pos.x, pos.z, 2.0):
			_err(where, "cresset '%s' at %s can't be reached with only the cressets before it lit (the road forgets)" % [cid, pos])
		else:
			_check_budget(where, field, remembered, areas, [["cresset '%s'" % cid, c.get("position"), 2.0]])
		lit.append_array(Cressets.pools_of(region, cid))
	var all := Greying.all_areas(region)
	var best := _remembered_cells(field, reachable, all, spawn)
	var walkable: Array = []
	for spot: Array in spots:
		var pos := JsonUtil.to_vector3(spot[1])
		if not field.near_reachable(reachable, pos.x, pos.z, float(spot[2])):
			continue  # reported by _validate_ground
		if field.near_reachable(best, pos.x, pos.z, float(spot[2])):
			walkable.append(spot)
		else:
			_err(where, "%s at %s lies where the road forgets, even with every light lit" % [spot[0], pos])
	_check_budget(where, field, best, all, walkable)


## Reachable cells (flood fill from `spawn` over `reachable`) where the way is remembered under `areas`.
func _remembered_cells(field: TerrainField, reachable: Dictionary, areas: Array, spawn: Vector3) -> Dictionary:
	var ok := func(c: Vector2i) -> bool:
		var centre := field.vertex_xz(c.x, c.y) + Vector2(field.cell, field.cell) * 0.5
		return reachable.has(c) and Greying.forgetting_at(areas, centre) < Greying.FORGET_DEPTH
	var seen: Dictionary = {}
	var start := field.cell_of(spawn.x, spawn.z)
	if not ok.call(start):
		return seen
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + step
			if not seen.has(n) and ok.call(n):
				seen[n] = true
				queue.append(n)
	return seen


## Sculpted ground: well-formed features, and every spawn/NPC/pickup/object/exit stands on
## ground the player can walk to from the default spawn (no stranded content).
func _validate_ground(where: String, region: Dictionary) -> void:
	var ground: Variant = region["ground"]
	if not ground is Dictionary:
		_err(where, "ground must be an object")
		return
	var b: Variant = ground.get("bounds")
	if not b is Array or (b as Array).size() != 4 or float(b[2]) <= float(b[0]) or float(b[3]) <= float(b[1]):
		_err(where, "ground.bounds must be [x_min, z_min, x_max, z_max]")
		return
	for key: String in ["land", "paint"]:
		for feature: Variant in ground.get(key, []):
			if not feature is Dictionary:
				_err(where, "ground.%s entries must be objects" % key)
				continue
			var shape_keys := 0
			for shape_key: String in ["rect", "ellipse", "path"]:
				if feature.has(shape_key):
					shape_keys += 1
					var arr: Variant = feature[shape_key]
					var ok := arr is Array and (arr as Array).size() >= (2 if shape_key == "path" else 4)
					if ok and shape_key == "path":
						for point: Variant in arr:
							ok = ok and point is Array and (point as Array).size() >= 2
					if not ok:
						_err(where, "ground.%s has a malformed '%s'" % [key, shape_key])
					elif shape_key == "path" and key == "paint":
						for leg in sawing_legs(arr):
							_warn(where, "ground.paint path leg %s saws on the 1 m grid (run it along an axis or a real diagonal)" % leg)
			if shape_keys != 1:
				_err(where, "ground.%s entries need exactly one of rect/ellipse/path" % key)
			if key == "paint" and not _valid_color(str(feature.get("color", ""))):
				_err(where, "ground.paint has unknown color '%s'" % feature.get("color", ""))
			if key == "paint":
				_ref_condition(where, feature.get("if"))
			elif feature.has("if"):
				_err(where, "ground.land can't be conditional (only paint may have an 'if')")
	for color_key: String in ["ground", "shore", "seabed", "cliff"]:
		var colors: Dictionary = ground.get("colors", {})
		if colors.has(color_key) and not _valid_color(str(colors[color_key])):
			_err(where, "ground.colors.%s is not a palette color" % color_key)
	var key := hash([where, _greying_ok, region])
	if _ground_memo.has(key):
		var found: Array = _ground_memo[key]
		errors.append_array(found[0])
		warnings.append_array(found[1])
		return
	var errors_before := errors.size()
	var warnings_before := warnings.size()
	_walk_ground(where, region, ground)
	ground_walks += 1
	_ground_memo[key] = [errors.slice(errors_before), warnings.slice(warnings_before)]


## The geometric half of _validate_ground (memoized there): reads only the region's data.
func _walk_ground(where: String, region: Dictionary, ground: Dictionary) -> void:
	var piers_ok := _validate_piers(where, ground, float(region.get("water_level", -INF)))
	var field := TerrainField.from_data(ground, float(region.get("water_level", -INF)))
	var spawn: Vector3 = JsonUtil.to_vector3(region.get("spawn_points", {}).get("default", [0, 0, 0]))
	var reachable := field.reachable_from(spawn.x, spawn.z)
	if reachable.is_empty():
		_err(where, "default spawn is not on walkable ground")
		return
	for cell: Vector2i in reachable:
		if cell.x <= 0 or cell.y <= 0 or cell.x >= field.cols - 2 or cell.y >= field.rows - 2:
			_err(where, "walkable ground reaches the edge of ground.bounds at %s (widen bounds)" % field.vertex_xz(cell.x, cell.y))
			break
	var spots: Array = []  # [label, position, reach]
	for spawn_name: String in region.get("spawn_points", {}):
		spots.append(["spawn '%s'" % spawn_name, region["spawn_points"][spawn_name], 0.5])
	for placement: Dictionary in region.get("npcs", []):
		spots.append(["npc '%s'" % placement.get("npc", ""), placement.get("position"), 1.4])
	for pickup: Dictionary in region.get("pickups", []):
		spots.append(["pickup '%s'" % pickup.get("id", ""), pickup.get("position"), 1.4])
	for object: Dictionary in region.get("objects", []):
		spots.append(["object '%s'" % object.get("id", ""), object.get("position"), float(object.get("reach", 1.8))])
	for exit: Dictionary in region.get("exits", []):
		spots.append(["exit to '%s'" % exit.get("to", ""), exit.get("position"), 1.4])
	for spot: Array in spots:
		var pos := JsonUtil.to_vector3(spot[1])
		if not field.contains(pos.x, pos.z):
			_err(where, "%s at %s is outside ground.bounds" % [spot[0], pos])
		elif not field.near_reachable(reachable, pos.x, pos.z, float(spot[2])):
			_err(where, "%s at %s can't be reached on foot from the default spawn" % [spot[0], pos])
	_validate_greying_budget(where, region, field, reachable, spots)
	_validate_forgetting(where, region, field, reachable, spots)
	_check_npcs_dry(where, region, field)
	if not piers_ok:
		return
	for pier: Dictionary in ground.get("piers", []):
		var r: Array = pier["rect"]
		var mid := Vector2((float(r[0]) + float(r[2])) * 0.5, (float(r[1]) + float(r[3])) * 0.5)
		if not field.near_reachable(reachable, mid.x, mid.y, 0.1):
			_err(where, "pier %s can't be walked onto from the default spawn (does it touch land?)" % [r])


## NPCs stand on dry ground or a deck (Day 68: Hild stood 0.8 m under Kindleby's sea for a
## day). A placement that means its NPC to stand in the water says `"wading": true`.
func _check_npcs_dry(where: String, region: Dictionary, field: TerrainField) -> void:
	if field.water_level == -INF:
		return
	for placement: Dictionary in region.get("npcs", []):
		var npc_id := str(placement.get("npc", ""))
		var wading: Variant = placement.get("wading", false)
		if not wading is bool:
			_err(where, "npc '%s' placement 'wading' must be true or false" % npc_id)
		elif wading:
			continue
		var pos := JsonUtil.to_vector3(placement.get("position"))
		# A placement's y lifts it off the ground (a seat, a tussock).
		var feet := field.surface_at(pos.x, pos.z) + pos.y
		if feet < field.water_level - DRY_FEET:
			_err(where, "npc '%s' at %s stands %.2f m under the water (move it, or mark the placement \"wading\")" \
					% [npc_id, pos, field.water_level - feet])


## Piers: a grid-aligned `rect` and a numeric `deck` above the water. Returns false if any
## is malformed (the reachability check is skipped then).
func _validate_piers(where: String, ground: Dictionary, water: float) -> bool:
	var piers: Variant = ground.get("piers", [])
	if not piers is Array:
		_err(where, "ground.piers must be an array")
		return false
	var ok := true
	var b: Array = ground["bounds"]
	var cell := maxf(0.25, float(ground.get("cell", 1.0)))
	for pier: Variant in piers:
		var r: Variant = pier.get("rect") if pier is Dictionary else null
		var deck: Variant = pier.get("deck") if pier is Dictionary else null
		if not r is Array or (r as Array).size() != 4 or not (deck is float or deck is int):
			_err(where, "ground.piers entries need a 'rect' [x0,z0,x1,z1] and a numeric 'deck'")
			ok = false
			continue
		for i in 4:
			var offset := (float(r[i]) - float(b[i % 2])) / cell
			if absf(offset - roundf(offset)) > 0.001:
				_err(where, "pier rect %s must lie on the ground grid (multiples of cell from bounds)" % [r])
				ok = false
				break
		if water > -INF and float(pier["deck"]) <= water:
			_err(where, "pier deck %s is not above the water" % pier["deck"])
			ok = false
	return ok


func _validate_dialogue(id: String, dialogue: Dictionary) -> void:
	var where := "dialogue " + id
	var knots_v: Variant = dialogue.get("knots", {})
	if not knots_v is Dictionary or not (knots_v as Dictionary).has("start"):
		_err(where, "needs a 'knots' object with a 'start' knot")
		return
	var knots: Dictionary = knots_v
	var reachable: Dictionary = {"start": true}
	var queue: Array[String] = ["start"]
	# The lane map jumps straight into the ferry dialogue's voyage knots.
	if id == str(db.lanes.get("dialogue", "")):
		for knot_name in _lane_knots():
			if knots.has(knot_name) and not reachable.has(knot_name):
				reachable[knot_name] = true
				queue.append(knot_name)
	while not queue.is_empty():
		var knot_name: String = queue.pop_back()
		var knot: Variant = knots[knot_name]
		var kw := "%s/%s" % [where, knot_name]
		if not knot is Array or (knot as Array).is_empty():
			_err(kw, "knot must be a non-empty array of steps")
			continue
		var ended_at := -1
		for i in (knot as Array).size():
			var step: Variant = knot[i]
			if not step is Dictionary:
				_err(kw, "step must be an object")
				continue
			if ended_at >= 0:
				_err(kw, "step %d never plays: step %d always leaves the knot (goto/end/choice) before it" % [i, ended_at])
				ended_at = -2  # one error per knot
			elif ended_at == -1 and _always_leaves_knot(step):
				ended_at = i
			for target in _validate_step(kw, step, knots):
				if not reachable.has(target):
					reachable[target] = true
					queue.append(target)
	for knot_name: String in knots:
		if not reachable.has(knot_name):
			_err(where, "knot '%s' is unreachable from 'start'" % knot_name)


## Validates one step; returns the knot names it can jump to.
func _validate_step(where: String, step: Dictionary, knots: Dictionary) -> Array[String]:
	var targets: Array[String] = []
	var actions := 0
	for key: String in step:
		if key in STEP_ACTIONS:
			actions += 1
		elif key not in STEP_KEYS and key not in DialogueRunner.EFFECT_KEYS:
			_err(where, "unknown step key '%s'" % key)
	if actions > 1:
		_err(where, "step has more than one of %s" % [STEP_ACTIONS])
	if actions == 0 and not _has_effect(step):
		_err(where, "step does nothing")
	_ref_condition(where, step.get("if"))
	_ref_effects(where, step)
	if step.has("say"):
		var speaker := str(step["say"])
		if not db.npcs.has(speaker) and not DialogueRunner.SPECIAL_SPEAKERS.has(speaker):
			_err(where, "unknown speaker '%s'" % speaker)
		if str(step.get("text", "")).is_empty():
			_err(where, "'say' step needs 'text'")
	if step.has("goto"):
		targets.append(_ref_knot(where, str(step["goto"]), knots))
	if step.has("choice"):
		var options: Variant = step["choice"]
		if not options is Array or (options as Array).is_empty():
			_err(where, "'choice' needs a non-empty array")
			return targets
		for option: Variant in options:
			if not option is Dictionary:
				_err(where, "choice option must be an object")
				continue
			var opt: Dictionary = option
			for key: String in opt:
				if key not in OPTION_KEYS and key not in DialogueRunner.EFFECT_KEYS:
					_err(where, "unknown choice key '%s'" % key)
			if str(opt.get("text", "")).is_empty():
				_err(where, "choice option needs 'text'")
			_ref_condition(where, opt.get("if"))
			_ref_effects(where, opt)
			if opt.has("goto"):
				targets.append(_ref_knot(where, str(opt["goto"]), knots))
			if opt.has("lane_map"):
				if not where.begins_with("dialogue %s/" % db.lanes.get("dialogue", "")):
					_err(where, "a lane_map option only works in the lanes dialogue '%s' (data/lanes.json)" % db.lanes.get("dialogue", ""))
				if opt.has("goto") or opt.has("end"):
					_err(where, "a lane_map option opens the map; it can't also goto or end")
	return targets.filter(func(t: String) -> bool: return not t.is_empty())


## True if a step always jumps or ends, so nothing after it in its knot can play (Day 61): an
## unconditional goto or end, or an unconditional choice whose every option jumps, ends or opens
## the lane map (which sails or re-offers the choice), with one option always offered.
func _always_leaves_knot(step: Dictionary) -> bool:
	if step.has("if"):
		return false
	if step.has("goto") or bool(step.get("end", false)):
		return true
	if not step.get("choice") is Array:
		return false
	var options: Array = step["choice"]
	var always_offered := false
	for option: Variant in options:
		if not option is Dictionary:
			return false
		var opt: Dictionary = option
		if not (opt.has("goto") or bool(opt.get("end", false)) or bool(opt.get("lane_map", false))):
			return false
		if not opt.has("if"):
			always_offered = true
	return always_offered


func _has_effect(step: Dictionary) -> bool:
	for key in DialogueRunner.EFFECT_KEYS:
		if step.has(key):
			return true
	return false


func _ref_knot(where: String, target: String, knots: Dictionary) -> String:
	if not knots.has(target):
		_err(where, "goto unknown knot '%s'" % target)
		return ""
	return target


func _ref_dialogue(where: String, id: String) -> void:
	if not db.dialogues.has(id):
		_err(where, "references unknown dialogue '%s'" % id)
	_dialogues_used[id] = true


func _ref_flag_set(where: String, id: String, value: Variant = null) -> void:
	if not db.flags.has(id):
		_err(where, "sets undeclared flag '%s' (declare it in data/flags.json)" % id)
	elif value != null:
		var problem := db.flag_value_error(id, value)
		if not problem.is_empty():
			_err(where, "sets " + problem)
	_flags_set[id] = true


func _ref_effects(where: String, step: Dictionary) -> void:
	if step.has("set"):
		if not step["set"] is Dictionary:
			_err(where, "'set' must be an object")
		else:
			for flag_id: String in step["set"]:
				_ref_flag_set(where, flag_id, step["set"][flag_id])
	for key: String in ["quest_start", "quest_complete"]:
		if step.has(key):
			var qid := str(step[key])
			if not db.quests.has(qid):
				_err(where, "%s unknown quest '%s'" % [key, qid])
			if key == "quest_start":
				_quests_started[qid] = true
			else:
				_quests_completed[qid] = true
	if step.has("quest_stage"):
		var pair: Variant = step["quest_stage"]
		if not pair is Array or (pair as Array).size() != 2:
			_err(where, "quest_stage must be [quest_id, stage_id]")
		else:
			_ref_stage(where, str(pair[0]), str(pair[1]))
	if step.has("sound"):
		_ref_sound(where, str(step["sound"]))
		if db.sounds.has(str(step["sound"])) and bool((db.sounds[str(step["sound"])] as Dictionary).get("loop", false)):
			_err(where, "a dialogue sound plays once; '%s' loops" % step["sound"])
	if step.has("music"):
		_ref_music(where, str(step["music"]))
		if db.sounds.has(str(step["music"])) and bool((db.sounds[str(step["music"])] as Dictionary).get("loop", false)):
			_err(where, "dialogue music is a one-shot cue; '%s' loops" % step["music"])
	if step.has("travel"):
		var target: Variant = step["travel"]
		if not target is Array or (target as Array).size() not in [1, 2]:
			_err(where, "travel must be [region_id] or [region_id, spawn]")
		elif not db.regions.has(str(target[0])):
			_err(where, "travel to unknown region '%s'" % target[0])
		else:
			var spawn := str(target[1]) if (target as Array).size() > 1 else "default"
			if not (db.get_region(str(target[0])).get("spawn_points", {}) as Dictionary).has(spawn):
				_err(where, "travel spawn '%s' not in region '%s'" % [spawn, target[0]])
	for key: String in ["give_item", "take_item"]:
		if step.has(key):
			var item_id := str(step[key])
			if not db.items.has(item_id):
				_err(where, "%s unknown item '%s'" % [key, item_id])
			if key == "give_item":
				_items_obtainable[item_id] = true
			else:
				_items_used[item_id] = true


func _ref_stage(where: String, quest_id: String, stage_id: String) -> void:
	if not db.quests.has(quest_id):
		_err(where, "unknown quest '%s'" % quest_id)
		return
	for stage: Dictionary in db.get_quest(quest_id).get("stages", []):
		if str(stage.get("id", "")) == stage_id:
			return
	_err(where, "quest '%s' has no stage '%s'" % [quest_id, stage_id])


func _ref_condition(where: String, condition: Variant) -> void:
	for term in Conditions.terms(condition):
		var p := Conditions.parse(term)
		if p.has("error"):
			_err(where, p["error"])
			continue
		var id: String = p["id"]
		match p["kind"]:
			"flag":
				if not db.flags.has(id):
					_err(where, "reads undeclared flag '%s'" % id)
				elif p["op"] == "=":
					for value: String in p["values"]:
						var problem := db.flag_value_error(id, value)
						if not problem.is_empty():
							_err(where, "reads " + problem)
				_flags_read[id] = true
			"quest":
				if not db.quests.has(id):
					_err(where, "condition on unknown quest '%s'" % id)
			"stage":
				_ref_stage(where, id, p["value"])
			"item":
				if not db.items.has(id):
					_err(where, "condition on unknown item '%s'" % id)
				_items_used[id] = true


## An NPC placed more than once (all conditional) must never show in two places at once: no
## world state may satisfy two of its placements' conditions (Day 38; before, only "keep them
## exact negations" in the notes).
func _check_placements_exclusive() -> void:
	for npc_id: String in _npcs_placed:
		var placements: Array = _npcs_placed[npc_id]
		for i in placements.size():
			for j in range(i + 1, placements.size()):
				var a: Dictionary = placements[i]
				var b: Dictionary = placements[j]
				if not a["conditional"] or not b["conditional"]:
					continue  # already an error above
				var witness := _joint_witness([a["if"], b["if"]])
				if not witness.is_empty():
					_err("region " + str(b["region"]), "npc '%s' can show here and in %s at once (e.g. %s); make the placements' conditions exclusive" \
							% [npc_id, a["region"], JSON.stringify(witness)])


## Two model props of one family (the same first word of the file name: `wrack_light` and
## `wrack_light_lit`, `teeth_rock` and `teeth_mark`) standing on one spot are variants of one
## thing, swapped by their `if`s: no world state may show both (Day 44). Props of different
## families on one spot are overlays (the gold streak on the lit Heron) and may stack.
func _check_prop_variants(where: String, region: Dictionary) -> void:
	var props: Array = (region.get("props", []) as Array).filter(func(p: Dictionary) -> bool:
		return p.has("model") and _is_vector(p.get("position")))
	for i in props.size():
		for j in range(i + 1, props.size()):
			var a: Dictionary = props[i]
			var b: Dictionary = props[j]
			var family_a := str(a["model"]).get_file().get_slice("_", 0)
			if family_a != str(b["model"]).get_file().get_slice("_", 0):
				continue
			var pa: Array = a["position"]
			var pb: Array = b["position"]
			if Vector2(float(pa[0]) - float(pb[0]), float(pa[2]) - float(pb[2])).length() > PROP_VARIANT_SPOT:
				continue
			var label := "'%s' and '%s' at %s" % [str(a["model"]).get_file(), str(b["model"]).get_file(), JSON.stringify(pa)]
			if not a.has("if") and not b.has("if"):
				continue  # a matched pair placed together on purpose (fence runs, rock clusters)
			var witness := _joint_witness([a.get("if", []), b.get("if", [])])
			if not witness.is_empty():
				_err(where, "prop variants %s can both show (e.g. %s); make their conditions exclusive" % [label, JSON.stringify(witness)])


## Conditions.joint_witness over this content's flags (their defaults and value lists).
func _joint_witness(conditions: Array) -> Dictionary:
	if not _witness_ready:
		_witness_defaults = {}
		_witness_values = {}
		for flag_id: String in db.flags:
			_witness_defaults[flag_id] = db.flag_default(flag_id)
			if not db.flag_values(flag_id).is_empty():
				_witness_values[flag_id] = db.flag_values(flag_id)
		_witness_ready = true
	return Conditions.joint_witness(conditions, _witness_defaults, _witness_values)


func _flag_exempt(id: String) -> bool:
	var entry: Dictionary = db.flags[id]
	return bool(entry.get("future", false)) or bool(entry.get("read_by_code", false))


func _check_orphans() -> void:
	for id: String in db.flags:
		# `set_by_code` (Day 78): set by a system, not by content (the Greying's turn-back).
		if not _flags_set.has(id) and not bool((db.flags[id] as Dictionary).get("set_by_code", false)):
			_err("data/flags.json", "flag '%s' is declared but never set by any content" % id)
		elif not _flags_read.has(id) and not _flag_exempt(id):
			_warn("data/flags.json", "flag '%s' is set but never read (mark \"future\" or \"read_by_code\" if intentional)" % id)
	for id: String in db.quests:
		if not _quests_started.has(id):
			_err("quest " + id, "is never started by any dialogue")
		if not _quests_completed.has(id) and not bool(db.quests[id].get("future", false)):
			_warn("quest " + id, "is never completed (mark \"future\" if the payoff isn't written yet)")
	for id: String in db.dialogues:
		if not _dialogues_used.has(id):
			_err("dialogue " + id, "is orphaned (no NPC or game.json references it)")
	for id: String in db.npcs:
		if not _npcs_placed.has(id):
			_err("npc " + id, "is not placed in any region")
	for id: String in db.sounds:
		if not _sounds_used.has(id):
			_warn("data/audio.json", "sound '%s' is never played" % id)
	for id: String in db.items:
		if not _items_obtainable.has(id):
			_warn("item " + id, "can never be obtained")
		elif not _items_used.has(id) and not bool(db.get_item(id).get("future", false)):
			_warn("item " + id, "is obtainable but never used")
