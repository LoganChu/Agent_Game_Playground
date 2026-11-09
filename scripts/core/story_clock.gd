class_name StoryClock
extends RefCounted
## Story clocks (Day 94): a time of day moved by story flags, not by a running day/night (data/clocks.json).
## A region with `"clock": id` can give its fog and light overrides a `"time"` instead of an `"if"`; RegionMood
## resolves the clock once and picks the override for the time it is. The order of a clock's times holds the
## story's order in one place, so the regions under it can't drift out of step with each other.

const PATH := "res://data/clocks.json"

static var _clocks: Dictionary = {}
static var _loaded := false


## Every clock: id -> {"default": String, "times": [{"id", "if"}]} ("note" keys dropped).
static func clocks() -> Dictionary:
	if not _loaded:
		_loaded = true
		var errors: Array[String] = []
		var parsed: Variant = JsonUtil.load_file(PATH, errors)
		if parsed is Dictionary:
			for id: String in parsed:
				if parsed[id] is Dictionary:
					_clocks[id] = parsed[id]
		for error in errors:
			push_error(error)
	return _clocks


static func has_clock(clock_id: String) -> bool:
	return clocks().has(clock_id)


## The clock's default time (no time's condition holds).
static func default_time(clock_id: String) -> String:
	return str((clocks().get(clock_id, {}) as Dictionary).get("default", ""))


## Every time the clock can show, default last.
static func times(clock_id: String) -> Array[String]:
	var out: Array[String] = []
	for time: Dictionary in (clocks().get(clock_id, {}) as Dictionary).get("times", []):
		out.append(str(time.get("id", "")))
	out.append(default_time(clock_id))
	return out


## The time it is on `clock_id` under `state`: the first time whose condition holds, else the default.
static func now(clock_id: String, state: WorldState) -> String:
	var clock: Dictionary = clocks().get(clock_id, {})
	for time: Dictionary in clock.get("times", []):
		if Conditions.evaluate(time.get("if"), state):
			return str(time.get("id", ""))
	return str(clock.get("default", ""))
