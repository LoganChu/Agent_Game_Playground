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
