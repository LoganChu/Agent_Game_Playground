class_name ContentValidator
extends RefCounted
## Cross-checks all content for broken references and orphans. Run by the test suite
## (tests/test_content.gd) and, in debug builds, at game start.
##
## Errors fail the build. Warnings are printed but allowed (e.g. an item nobody uses yet).

const STEP_ACTIONS: Array[String] = ["say", "choice", "goto", "end"]
const STEP_KEYS: Array[String] = ["say", "text", "choice", "goto", "end", "if", "count", "note"]
const OPTION_KEYS: Array[String] = ["text", "goto", "end", "if", "count", "note"]
const ITEM_KINDS: Array[String] = ["remnant", "key", "misc"]

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
## False while the region being validated has a malformed Greying area (its geometric
## checks are skipped then, the malformed area is reported instead).
var _greying_ok := true


func _init(p_db: ContentDatabase) -> void:
	db = p_db


## Returns true when there are no errors.
func validate() -> bool:
	errors = db.errors.duplicate()
	warnings.clear()
	_validate_game()
	_validate_flags()
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
	for message in Scenarios.validate(db, Scenarios.all()):
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


func _validate_flags() -> void:
	for id: String in db.flags:
		var entry: Variant = db.flags[id]
		if not entry is Dictionary or str((entry as Dictionary).get("description", "")).is_empty():
			_err("data/flags.json", "flag '%s' needs a description" % id)
		if id != id.to_snake_case() or id.contains(" "):
			_err("data/flags.json", "flag '%s' must be snake_case" % id)


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


## `smoke` (model props only): vents [[x, y, z], ...] in model space that smoke rises from.
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


## `halo` (model props only): [x, y, z] in model space where a soft lantern glow hangs, with an
## optional `halo_size` (metres, > 0).
func _check_prop_halo(where: String, prop: Dictionary, model: String) -> void:
	if not prop.has("halo"):
		return
	if model.is_empty():
		_err(where, "prop 'halo' needs a 'model'")
	if not _is_vector(prop["halo"]):
		_err(where, "prop 'halo' must be [x, y, z]")
	if prop.has("halo_size") and not ((prop["halo_size"] is float or prop["halo_size"] is int) and float(prop["halo_size"]) > 0.0):
		_err(where, "prop 'halo_size' must be a number > 0")


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


func _validate_npc(id: String, npc: Dictionary) -> void:
	var where := "npc " + id
	_require_fields(where, npc, ["name", "dialogue", "color"])
	if npc.has("dialogue"):
		_ref_dialogue(where, str(npc["dialogue"]))
	if npc.has("color") and not _valid_color(str(npc["color"])):
		_err(where, "invalid color '%s' (palette name or #hex)" % npc["color"])
	if npc.has("model"):
		_ref_character_model(where, str(npc["model"]))
	if npc.has("faces_player") and not npc["faces_player"] is bool:
		_err(where, "faces_player must be true or false")
	if npc.has("idle") and str(npc["idle"]) not in CharacterRig.STYLES:
		_err(where, "idle must be one of %s" % [CharacterRig.STYLES])


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


func _validate_region(id: String, region: Dictionary) -> void:
	var where := "region " + id
	_require_fields(where, region, ["name", "description"])
	var spawns: Variant = region.get("spawn_points", {})
	if not spawns is Dictionary or not (spawns as Dictionary).has("default"):
		_err(where, "spawn_points must contain 'default'")
	for placement: Dictionary in region.get("npcs", []):
		var npc_id := str(placement.get("npc", ""))
		if not db.npcs.has(npc_id):
			_err(where, "places unknown npc '%s'" % npc_id)
		else:
			# An NPC may stand in several places only if every placement is conditional
			# (e.g. Pell on the beach until the ferry comes, then on the dock).
			var placements: Array = _npcs_placed.get(npc_id, [])
			placements.append({"region": id, "conditional": placement.has("if")})
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
		_check_prop_smoke(where, prop, model)
		_check_prop_halo(where, prop, model)
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
	for pickup: Dictionary in region.get("pickups", []):
		var pid := str(pickup.get("id", ""))
		if pid.is_empty():
			_err(where, "pickup missing 'id'")
		var item_id := str(pickup.get("item", ""))
		if not db.items.has(item_id):
			_err(where, "pickup '%s' gives unknown item '%s'" % [pid, item_id])
		_items_obtainable[item_id] = true
		_ref_condition(where, pickup.get("if"))
		for flag_id: String in (pickup.get("set", {}) as Dictionary):
			_ref_flag_set(where, flag_id)
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
	_validate_events(where, region)
	_validate_greying(where, region)
	if region.has("ground"):
		_validate_ground(where, region)


## Region `events` (arrival events, main.gd): each needs an id, an `if`, a dialogue and a
## `set` that switches its own `if` off (a `!flag:x` term with x in `set`), so an event can
## never fire twice.
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
			if key not in ["rect", "ellipse", "strength", "falloff", "height", "if", "clear", "note"]:
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
	var cost := Greying.ember_cost_map(field, reachable, areas)
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
	if not piers_ok:
		return
	for pier: Dictionary in ground.get("piers", []):
		var r: Array = pier["rect"]
		var mid := Vector2((float(r[0]) + float(r[2])) * 0.5, (float(r[1]) + float(r[3])) * 0.5)
		if not field.near_reachable(reachable, mid.x, mid.y, 0.1):
			_err(where, "pier %s can't be walked onto from the default spawn (does it touch land?)" % [r])


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
	while not queue.is_empty():
		var knot_name: String = queue.pop_back()
		var knot: Variant = knots[knot_name]
		var kw := "%s/%s" % [where, knot_name]
		if not knot is Array or (knot as Array).is_empty():
			_err(kw, "knot must be a non-empty array of steps")
			continue
		for step: Variant in knot:
			if not step is Dictionary:
				_err(kw, "step must be an object")
				continue
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
	return targets.filter(func(t: String) -> bool: return not t.is_empty())


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


func _ref_flag_set(where: String, id: String) -> void:
	if not db.flags.has(id):
		_err(where, "sets undeclared flag '%s' (declare it in data/flags.json)" % id)
	_flags_set[id] = true


func _ref_effects(where: String, step: Dictionary) -> void:
	if step.has("set"):
		if not step["set"] is Dictionary:
			_err(where, "'set' must be an object")
		else:
			for flag_id: String in step["set"]:
				_ref_flag_set(where, flag_id)
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


func _flag_exempt(id: String) -> bool:
	var entry: Dictionary = db.flags[id]
	return bool(entry.get("future", false)) or bool(entry.get("read_by_code", false))


func _check_orphans() -> void:
	for id: String in db.flags:
		if not _flags_set.has(id):
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
	for id: String in db.items:
		if not _items_obtainable.has(id):
			_warn("item " + id, "can never be obtained")
		elif not _items_used.has(id) and not bool(db.get_item(id).get("future", false)):
			_warn("item " + id, "is obtainable but never used")
