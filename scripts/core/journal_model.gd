class_name JournalModel
extends RefCounted
## Builds the view data for the quest journal and the satchel (inventory) from content +
## world state. Pure logic so the ordering and text rules are unit-testable; JournalUI only
## renders what this returns.

## Sort order of item kinds in the satchel; unknown kinds go last.
const KIND_ORDER: Array[String] = ["remnant", "key", "misc"]
const KIND_LABELS: Dictionary = {
	"remnant": "Remnant",
	"key": "Key item",
	"misc": "Oddment",
}


## One entry per started quest: active quests first, then completed ones; within each group
## the most recently started comes first (WorldState.quests keeps insertion order).
## Entry: {id, title, description, done: bool, current: String (stage text, "" when done),
##         completed: Array[String] (texts of stages already passed, oldest first)}
static func quest_entries(db: ContentDatabase, world: WorldState) -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	var done: Array[Dictionary] = []
	var ids: Array = world.quests.keys()
	ids.reverse()
	for id: String in ids:
		var state := world.quest_state(id)
		if state == WorldState.QUEST_INACTIVE:
			continue
		var quest := db.get_quest(id)
		var is_done := state == WorldState.QUEST_DONE
		var entry := {
			"id": id,
			"title": str(quest.get("title", id)),
			"description": str(quest.get("description", "")),
			"done": is_done,
			"current": "",
			"completed": _passed_stage_texts(quest, world.quest_stage(id), is_done),
		}
		if not is_done:
			entry["current"] = _stage_text(quest, world.quest_stage(id))
		(done if is_done else active).append(entry)
	active.append_array(done)
	return active


## One entry per carried item, Remnants first, then keys, then everything else, by name.
## Entry: {id, name, kind, kind_label, count, description, remnant: bool}
static func item_entries(db: ContentDatabase, world: WorldState) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for id: String in world.inventory:
		var count := world.item_count(id)
		if count <= 0:
			continue
		var item := db.get_item(id)
		var kind := str(item.get("kind", "misc"))
		entries.append({
			"id": id,
			"name": str(item.get("name", id)),
			"kind": kind,
			"kind_label": str(KIND_LABELS.get(kind, kind.capitalize())),
			"count": count,
			"description": str(item.get("description", "")),
			"remnant": kind == "remnant",
		})
	entries.sort_custom(_item_before)
	return entries


static func _item_before(a: Dictionary, b: Dictionary) -> bool:
	var ka := _kind_rank(str(a["kind"]))
	var kb := _kind_rank(str(b["kind"]))
	if ka != kb:
		return ka < kb
	return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0


static func _kind_rank(kind: String) -> int:
	var i := KIND_ORDER.find(kind)
	return i if i >= 0 else KIND_ORDER.size()


static func _stage_text(quest: Dictionary, stage_id: String) -> String:
	for stage: Dictionary in quest.get("stages", []):
		if str(stage.get("id", "")) == stage_id:
			return str(stage.get("text", ""))
	return ""


## Texts of the stages before `stage_id` (all stages up to and including it when done).
static func _passed_stage_texts(quest: Dictionary, stage_id: String, done: bool) -> Array[String]:
	var texts: Array[String] = []
	for stage: Dictionary in quest.get("stages", []):
		var is_current := str(stage.get("id", "")) == stage_id
		if is_current and not done:
			break
		texts.append(str(stage.get("text", "")))
		if is_current:
			break
	return texts
