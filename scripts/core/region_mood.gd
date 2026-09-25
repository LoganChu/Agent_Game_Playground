class_name RegionMood
extends RefCounted
## Resolves a region's fog from its data and the world state.
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
