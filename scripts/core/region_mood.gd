class_name RegionMood
extends RefCounted
## Resolves a region's mood — fog and light — from its data and the world state.
##
## Region `fog` may carry `overrides`: [{"if": condition, "density"?: float, "color"?: name}].
## The first override whose condition holds replaces the base values it names, so story
## flags (a relit beacon) can thin the Greying without new region files.
## A region with a story clock (`"clock": id`, Day 94) gives its overrides a `"time"` instead of an `"if"`:
## the override for the time it is on that clock (StoryClock.now) applies, wherever it sits in the list.

const DEFAULT_DENSITY := 0.012
const DEFAULT_COLOR := "silverfog"


## Returns {"density": float, "color": String} for `region_data` under `state`.
static func fog(region_data: Dictionary, state: WorldState) -> Dictionary:
	var base: Dictionary = region_data.get("fog", {})
	var out := {
		"density": float(base.get("density", DEFAULT_DENSITY)),
		"color": str(base.get("color", DEFAULT_COLOR)),
	}
	var now := clock_time(region_data, state)
	for override: Dictionary in base.get("overrides", []):
		if override_holds(override, now, state):
			if override.has("density"):
				out["density"] = float(override["density"])
			if override.has("color"):
				out["color"] = str(override["color"])
			break
	return out


## Keys a region's `light` block (and its overrides) may set, with defaults: a soft kindle
## sun from the south-west, cool silverfog ambient, a tide-blue sky fading into the fog.
## Colours are palette names or #hex; `sun_pitch`/`sun_yaw` are degrees; `shadow` is the sun's
## shadow opacity 0..1 (Day 76: Lowsong's fog lights everything from nowhere, so its shadows are faint).
const LIGHT_DEFAULTS := {
	"sun_color": "kindle",
	"sun_energy": 1.1,
	"sun_pitch": -42.0,
	"sun_yaw": -35.0,
	"ambient_color": "silverfog",
	"ambient_energy": 0.3,
	"sky_top": "tide",
	"sky_horizon": "silverfog",
	"shadow": 1.0,
}
const LIGHT_COLOR_KEYS := ["sun_color", "ambient_color", "sky_top", "sky_horizon"]


## Returns the region's light after overrides: every LIGHT_DEFAULTS key, colours as names.
## Like fog, `light.overrides` = [{"if": condition, <any light key>...}], first match wins.
static func light(region_data: Dictionary, state: WorldState) -> Dictionary:
	var base: Dictionary = region_data.get("light", {})
	var out := {}
	for key: String in LIGHT_DEFAULTS:
		out[key] = base.get(key, LIGHT_DEFAULTS[key])
	var now := clock_time(region_data, state)
	for override: Dictionary in base.get("overrides", []):
		if override_holds(override, now, state):
			for key: String in LIGHT_DEFAULTS:
				if override.has(key):
					out[key] = override[key]
			break
	for key: String in LIGHT_DEFAULTS:
		out[key] = str(out[key]) if key in LIGHT_COLOR_KEYS else float(out[key])
	return out


## The time on the region's story clock under `state`, or "" for a region without one.
static func clock_time(region_data: Dictionary, state: WorldState) -> String:
	var clock := str(region_data.get("clock", ""))
	return StoryClock.now(clock, state) if not clock.is_empty() else ""


## Whether a fog/light override applies: its `time` is the clock's time `now`, or its `if` holds.
static func override_holds(override: Dictionary, now: String, state: WorldState) -> bool:
	if override.has("time"):
		return not now.is_empty() and str(override["time"]) == now
	return Conditions.evaluate(override.get("if"), state)
