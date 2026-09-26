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


func _validate_flags() -> void:
	for id: String in db.flags:
		var entry: Variant = db.flags[id]
		if not entry is Dictionary or str((entry as Dictionary).get("description", "")).is_empty():
			_err("data/flags.json", "flag '%s' needs a description" % id)
		if id != id.to_snake_case() or id.contains(" "):
			_err("data/flags.json", "flag '%s' must be snake_case" % id)


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
		elif _npcs_placed.has(npc_id):
			_err(where, "npc '%s' is placed more than once (also in %s)" % [npc_id, _npcs_placed[npc_id]])
		_npcs_placed[npc_id] = id
		_ref_condition(where, placement.get("if"))
	for prop: Dictionary in region.get("props", []):
		var model := str(prop.get("model", ""))
		if not model.is_empty() and not ResourceLoader.exists(model):
			_err(where, "prop model '%s' does not exist" % model)
		if model.is_empty() and str(prop.get("shape", "")) not in PropFactory.SHAPES:
			_err(where, "prop needs 'model' or a 'shape' in %s" % [PropFactory.SHAPES])
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
		if not _quests_completed.has(id):
			_warn("quest " + id, "is never completed")
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
