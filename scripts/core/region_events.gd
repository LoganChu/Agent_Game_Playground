class_name RegionEvents
extends RefCounted
## Region `events` — things that happen on arriving in a region (the ferry's horn heard from
## the beach). Pure logic; main.gd fires them after a region loads.
##
##   "events": [{"id": "ferry_horn", "if": [..., "!flag:x"], "set": {"x": true},
##               "dialogue": "ferry_horn"}]
## The validator requires `set` to switch the event's own `if` off, so each fires once.


## The first event whose `if` holds now, or {} if none.
static func arrival(region: Dictionary, world: WorldState) -> Dictionary:
	for event: Dictionary in region.get("events", []):
		if Conditions.evaluate(event.get("if"), world):
			return event
	return {}


## Applies the event's `set` flags and returns the dialogue to play.
static func fire(event: Dictionary, world: WorldState) -> String:
	var sets: Dictionary = event.get("set", {})
	for flag_id: String in sets:
		world.set_flag(flag_id, sets[flag_id])
	return str(event.get("dialogue", ""))
