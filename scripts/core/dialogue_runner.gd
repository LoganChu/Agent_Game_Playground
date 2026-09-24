class_name DialogueRunner
extends RefCounted
## Steps through a JSON dialogue (see docs/TECH.md "Dialogue format") against a WorldState.
##
## Usage:
##   var runner := DialogueRunner.new(db, state)
##   var ev := runner.start("mara_intro")
##   while ev.type != "end":
##       ev = runner.choose(i) if ev.type == "choices" else runner.next()
##
## Events are Dictionaries:
##   {"type": "line", "speaker": id, "name": display_name, "text": String}
##   {"type": "choices", "options": [{"text": String}]}
##   {"type": "end"}

## Emitted for every applied effect, so UI can show toasts ("Quest started", "Got item").
signal effect_applied(kind: String, data: Dictionary)

const EFFECT_KEYS: Array[String] = ["set", "quest_start", "quest_stage", "quest_complete", "give_item", "take_item"]
const SPECIAL_SPEAKERS: Dictionary = {"player": "You", "narrator": ""}
const MAX_STEPS_PER_ADVANCE := 1000

var db: ContentDatabase
var state: WorldState
var dialogue_id := ""
var knot := ""
var _steps: Array = []
var _index := 0
var _pending_options: Array = []
var _running := false


func _init(p_db: ContentDatabase, p_state: WorldState) -> void:
	db = p_db
	state = p_state


func is_running() -> bool:
	return _running


func start(id: String, start_knot: String = "start") -> Dictionary:
	var dialogue := db.get_dialogue(id)
	if dialogue.is_empty():
		push_error("Dialogue '%s' not found" % id)
		return _end()
	dialogue_id = id
	_running = true
	if not _jump(start_knot):
		return _end()
	return next()


func next() -> Dictionary:
	if not _running:
		return {"type": "end"}
	if not _pending_options.is_empty():
		# Waiting for a choice; re-offer it.
		return _choices_event()
	for _guard in MAX_STEPS_PER_ADVANCE:
		if _index >= _steps.size():
			return _end()
		var step: Dictionary = _steps[_index]
		_index += 1
		if step.has("if") and not Conditions.evaluate(step["if"], state):
			continue
		apply_effects(step)
		if step.has("say"):
			var speaker := str(step["say"])
			return {"type": "line", "speaker": speaker, "name": speaker_name(speaker), "text": str(step.get("text", ""))}
		if step.has("choice"):
			_pending_options = []
			for option: Dictionary in step["choice"]:
				if Conditions.evaluate(option.get("if"), state):
					_pending_options.append(option)
			if _pending_options.is_empty():
				continue
			return _choices_event()
		if step.has("goto"):
			if not _jump(str(step["goto"])):
				return _end()
			continue
		if step.get("end", false):
			return _end()
	push_error("Dialogue '%s' exceeded %d steps without output (goto loop?)" % [dialogue_id, MAX_STEPS_PER_ADVANCE])
	return _end()


func choose(option_index: int) -> Dictionary:
	if option_index < 0 or option_index >= _pending_options.size():
		push_error("Invalid choice %d" % option_index)
		return next()
	var option: Dictionary = _pending_options[option_index]
	_pending_options = []
	apply_effects(option)
	if option.get("end", false):
		return _end()
	if option.has("goto") and not _jump(str(option["goto"])):
		return _end()
	return next()


func speaker_name(speaker: String) -> String:
	if SPECIAL_SPEAKERS.has(speaker):
		return SPECIAL_SPEAKERS[speaker]
	var npc := db.get_npc(speaker)
	return str(npc.get("name", speaker))


func apply_effects(step: Dictionary) -> void:
	if step.has("set"):
		var sets: Dictionary = step["set"]
		for flag_id: String in sets:
			state.set_flag(flag_id, sets[flag_id])
			effect_applied.emit("set", {"flag": flag_id, "value": sets[flag_id]})
	if step.has("quest_start"):
		var quest_id := str(step["quest_start"])
		var stages: Array = db.get_quest(quest_id).get("stages", [])
		var first := str((stages[0] as Dictionary).get("id", "")) if not stages.is_empty() else ""
		if state.quest_state(quest_id) == WorldState.QUEST_INACTIVE:
			state.start_quest(quest_id, first)
			effect_applied.emit("quest_start", {"quest": quest_id})
	if step.has("quest_stage"):
		var pair: Array = step["quest_stage"]
		state.set_quest_stage(str(pair[0]), str(pair[1]))
		effect_applied.emit("quest_stage", {"quest": str(pair[0]), "stage": str(pair[1])})
	if step.has("quest_complete"):
		var quest_id := str(step["quest_complete"])
		if state.quest_state(quest_id) != WorldState.QUEST_DONE:
			state.complete_quest(quest_id)
			effect_applied.emit("quest_complete", {"quest": quest_id})
	if step.has("give_item"):
		var count := int(step.get("count", 1))
		state.add_item(str(step["give_item"]), count)
		effect_applied.emit("give_item", {"item": str(step["give_item"]), "count": count})
	if step.has("take_item"):
		var count := int(step.get("count", 1))
		if state.remove_item(str(step["take_item"]), count):
			effect_applied.emit("take_item", {"item": str(step["take_item"]), "count": count})


func _jump(target: String) -> bool:
	var knots: Dictionary = db.get_dialogue(dialogue_id).get("knots", {})
	if not knots.has(target):
		push_error("Dialogue '%s' has no knot '%s'" % [dialogue_id, target])
		return false
	knot = target
	_steps = knots[target]
	_index = 0
	return true


func _choices_event() -> Dictionary:
	var options: Array = []
	for option: Dictionary in _pending_options:
		options.append({"text": str(option.get("text", "..."))})
	return {"type": "choices", "options": options}


func _end() -> Dictionary:
	_running = false
	_pending_options = []
	return {"type": "end"}
