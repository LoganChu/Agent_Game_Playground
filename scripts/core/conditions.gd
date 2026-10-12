class_name Conditions
extends RefCounted
## Tiny condition language used by dialogue and content data.
##
## A condition is a String, or an Array of Strings that must all be true (AND).
## Terms (prefix any term with "!" to negate it):
##   flag:<id>                 flag is truthy
##   flag:<id>=<value>         str(flag) == value
##   quest:<id>=<state>        state is inactive | active | done
##   stage:<quest_id>=<stage>  quest is active and currently at <stage>
##   item:<id>                 player has at least one
##   item:<id>>=<n>            player has at least n

const KINDS: Array[String] = ["flag", "quest", "stage", "item"]
const QUEST_STATES: Array[String] = ["inactive", "active", "done"]


## Parses one term. Returns {"negate", "kind", "id", "op", "value"} or {"error": String}.
static func parse(term: String) -> Dictionary:
	var t := term.strip_edges()
	var negate := t.begins_with("!")
	if negate:
		t = t.substr(1)
	var colon := t.find(":")
	if colon <= 0:
		return {"error": "condition '%s' must look like kind:id" % term}
	var kind := t.substr(0, colon)
	if kind not in KINDS:
		return {"error": "condition '%s' has unknown kind '%s'" % [term, kind]}
	var rest := t.substr(colon + 1)
	var op := ""
	var value := ""
	for candidate: String in [">=", "="]:
		var at := rest.find(candidate)
		if at >= 0:
			op = candidate
			value = rest.substr(at + candidate.length())
			rest = rest.substr(0, at)
			break
	if rest.is_empty():
		return {"error": "condition '%s' has empty id" % term}
	match kind:
		"quest":
			if op != "=" or value not in QUEST_STATES:
				return {"error": "condition '%s' must be quest:<id>=inactive|active|done" % term}
		"stage":
			if op != "=" or value.is_empty():
				return {"error": "condition '%s' must be stage:<quest>=<stage>" % term}
		"item":
			if op == "=" or (op == ">=" and not value.is_valid_int()):
				return {"error": "condition '%s' must be item:<id> or item:<id>>=<n>" % term}
		"flag":
			if op == ">=":
				return {"error": "condition '%s': flags support only '='" % term}
	return {"negate": negate, "kind": kind, "id": rest, "op": op, "value": value}


## Normalizes a String / Array / null condition into an Array of terms.
static func terms(condition: Variant) -> Array[String]:
	var out: Array[String] = []
	if condition is String:
		if not (condition as String).is_empty():
			out.append(condition)
	elif condition is Array:
		for term: Variant in condition:
			out.append(str(term))
	return out


static func evaluate(condition: Variant, state: WorldState) -> bool:
	for term in terms(condition):
		if not _evaluate_term(term, state):
			return false
	return true


static func _evaluate_term(term: String, state: WorldState) -> bool:
	var p := parse(term)
	if p.has("error"):
		push_warning(p["error"])
		return false
	var result := false
	var id: String = p["id"]
	match p["kind"]:
		"flag":
			var v: Variant = state.get_flag(id, false)
			result = str(v) == p["value"] if p["op"] == "=" else _truthy(v)
		"quest":
			result = state.quest_state(id) == p["value"]
		"stage":
			result = state.quest_state(id) == WorldState.QUEST_ACTIVE and state.quest_stage(id) == p["value"]
		"item":
			var needed := int(p["value"]) if p["op"] == ">=" else 1
			result = state.item_count(id) >= needed
	return not result if p["negate"] else result


static func _truthy(v: Variant) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	if v is String:
		return not (v as String).is_empty()
	return true


## Searches for a world state in which every condition in `conditions` holds at once, trying
## each flag at its default (`flag_defaults`), at every value the conditions name, true, false
## and one value none of them names; each quest inactive, done, or active at each named stage
## (or another); each item at 0, 1 and every named count. Returns that state's assignments
## ({"flag:x": v, "quest:q": "active@stage", "item:i": n}), or {} if no such state exists.
## Used by the validator to prove an NPC's placements never show two at once. Gives up (and
## returns {}) past `max_states` combinations.
static func joint_witness(conditions: Array, flag_defaults: Dictionary, max_states: int = 65536) -> Dictionary:
	var domains: Dictionary = {}  # "kind:id" -> Array of candidate values
	for condition: Variant in conditions:
		for term in terms(condition):
			var p := parse(term)
			if p.has("error"):
				return {}
			var id: String = p["id"]
			match p["kind"]:
				"flag":
					var key := "flag:" + id
					if not domains.has(key):
						domains[key] = [flag_defaults.get(id, false), true, false, "\u0001other"]
					if p["op"] == "=" and not (domains[key] as Array).has(p["value"]):
						(domains[key] as Array).append(p["value"])
				"quest", "stage":
					var key := "quest:" + id
					if not domains.has(key):
						domains[key] = ["inactive", "done", "active@\u0001other"]
					if p["kind"] == "stage" and not (domains[key] as Array).has("active@" + p["value"]):
						(domains[key] as Array).append("active@" + p["value"])
				"item":
					var key := "item:" + id
					if not domains.has(key):
						domains[key] = [0, 1]
					if p["op"] == ">=" and not (domains[key] as Array).has(int(p["value"])):
						(domains[key] as Array).append(int(p["value"]))
	var keys: Array = domains.keys()
	var total := 1
	for key: String in keys:
		total *= (domains[key] as Array).size()
		if total > max_states:
			push_warning("joint_witness: too many states to search (%s…)" % ", ".join(PackedStringArray(keys)))
			return {}
	var state := WorldState.new()
	for n in total:
		var assignment: Dictionary = {}
		var rest := n
		state.flags.clear()
		state.quests.clear()
		state.inventory.clear()
		for key: String in keys:
			var domain: Array = domains[key]
			var value: Variant = domain[rest % domain.size()]
			rest /= domain.size()
			assignment[key] = value
			var id := key.substr(key.find(":") + 1)
			if key.begins_with("flag:"):
				state.flags[id] = value
			elif key.begins_with("quest:"):
				var s := str(value)
				state.quests[id] = {"state": s.get_slice("@", 0), "stage": s.get_slice("@", 1)} if s.begins_with("active@") \
						else {"state": s, "stage": ""}
			else:
				state.inventory[id] = value
		if conditions.all(func(c: Variant) -> bool: return evaluate(c, state)):
			return assignment
	return {}
