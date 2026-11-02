class_name ActRecap
extends RefCounted
## End-of-act cards (`act_ends` in data/game.json): which acts the story has reached and the
## recap lines a card shows for the current world state. Pure logic; ActEndCard draws it.
##
##   {"id": "act1", "when": condition, "title": "...", "subtitle": "...",
##    "recap": [{"if": condition, "text": "..."}], "coda": "...",
##    "unfinished": "Still undone on the islands: %s."}
##
## `unfinished` (Day 80): the card's last line names the quests of that act (a quest's `act`) still
## in progress, oldest first — the errands the Wakebearer could still go back for. No line when
## every one is done.


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


## Titles of the quests tagged with `act_id` (a quest's `act`) still in progress, in the order they
## were started.
static func unfinished_titles(db: ContentDatabase, world: WorldState, act_id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in world.quests:
		if world.quest_state(id) != WorldState.QUEST_ACTIVE:
			continue
		var quest := db.get_quest(id)
		if str(quest.get("act", "")) == act_id:
			out.append(str(quest.get("title", id)))
	return out


## Everything the act's card shows: its recap lines, then the `unfinished` line if any quest of
## the act is still in progress.
static func card_lines(db: ContentDatabase, act: Dictionary, world: WorldState) -> PackedStringArray:
	var out := lines(act, world)
	var template := str(act.get("unfinished", ""))
	var titles := unfinished_titles(db, world, str(act.get("id", "")))
	if not template.is_empty() and not titles.is_empty():
		out.append(template % ", ".join(titles))
	return out
