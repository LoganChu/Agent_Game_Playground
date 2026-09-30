class_name ActRecap
extends RefCounted
## End-of-act cards (`act_ends` in data/game.json): which acts the story has reached and the
## recap lines a card shows for the current world state. Pure logic; ActEndCard draws it.
##
##   {"id": "act1", "when": condition, "title": "...", "subtitle": "...",
##    "recap": [{"if": condition, "text": "..."}], "coda": "..."}


## The act_ends entries from game.json.
static func acts(db: ContentDatabase) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for act: Variant in db.game.get("act_ends", []):
		if act is Dictionary:
			out.append(act)
	return out


## Ids of every act whose `when` holds now.
static func reached(db: ContentDatabase, world: WorldState) -> Dictionary:
	var out: Dictionary = {}
	for act in acts(db):
		if Conditions.evaluate(act.get("when"), world):
			out[str(act["id"])] = true
	return out


## Recap lines whose `if` holds (all of them, in data order).
static func lines(act: Dictionary, world: WorldState) -> PackedStringArray:
	var out: PackedStringArray = []
	for line: Dictionary in act.get("recap", []):
		if Conditions.evaluate(line.get("if"), world):
			out.append(str(line["text"]))
	return out
