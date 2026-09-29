class_name RegionMood
extends RefCounted
## Resolves a region's mood — fog and light — from its data and the world state.
##
## Region `fog` may carry `overrides`: [{"if": condition, "density"?: float, "color"?: name}].
## The first override whose condition holds replaces the base values it names, so story
## flags (a relit beacon) can thin the Greying without new region files.

const DEFAULT_DENSITY := 0.012
const DEFAULT_COLOR := "silverfog"


## Returns {"density": float, "color": String} for `region_data` under `state`.
static func fog(region_data: Dictionary, state: WorldState) -> Dictionary:
	var base: Dictionary = region_data.get("fog", {})
	var out := {
		"density": float(base.get("density", DEFAULT_DENSITY)),
		"color": str(base.get("color", DEFAULT_COLOR)),
	}
	for override: Dictionary in base.get("overrides", []):
		if Conditions.evaluate(override.get("if"), state):
			if override.has("density"):
				out["density"] = float(override["density"])
			if override.has("color"):
				out["color"] = str(override["color"])
			break
	return out


## Keys a region's `light` block (and its overrides) may set, with defaults: a soft kindle
## sun from the south-west, cool silverfog ambient, a tide-blue sky fading into the fog.
## Colours are palette names or #hex; `sun_pitch`/`sun_yaw` are degrees.
const LIGHT_DEFAULTS := {
	"sun_color": "kindle",
	"sun_energy": 1.1,
	"sun_pitch": -42.0,
	"sun_yaw": -35.0,
	"ambient_color": "silverfog",
	"ambient_energy": 0.3,
	"sky_top": "tide",
	"sky_horizon": "silverfog",
}
const LIGHT_COLOR_KEYS := ["sun_color", "ambient_color", "sky_top", "sky_horizon"]


## Returns the region's light after overrides: every LIGHT_DEFAULTS key, colours as names.
## Like fog, `light.overrides` = [{"if": condition, <any light key>...}], first match wins.
static func light(region_data: Dictionary, state: WorldState) -> Dictionary:
	var base: Dictionary = region_data.get("light", {})
	var out := {}
	for key: String in LIGHT_DEFAULTS:
		out[key] = base.get(key, LIGHT_DEFAULTS[key])
	for override: Dictionary in base.get("overrides", []):
		if Conditions.evaluate(override.get("if"), state):
			for key: String in LIGHT_DEFAULTS:
				if override.has(key):
					out[key] = override[key]
			break
	for key: String in LIGHT_DEFAULTS:
		out[key] = str(out[key]) if key in LIGHT_COLOR_KEYS else float(out[key])
	return out
