class_name LineupLight
extends RefCounted
## The art-review lineups are lit by the game's own `Atmosphere` (gradient sky, sun, glow,
## grading) in a region's mood, so what they show matches play. `--mood=<region>` picks the
## region (default Saltmarrow). Distance fog is off so far-off overviews stay readable.

const DEFAULT_REGION := "saltmarrow"


static func add_to(parent: Node3D) -> Atmosphere:
	var region_id := DEFAULT_REGION
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mood="):
			region_id = arg.substr(7)
	var data := Content.db.get_region(region_id)
	if data.is_empty():
		push_warning("--mood: unknown region '%s'" % region_id)
	var atmosphere := Atmosphere.new()
	atmosphere.name = "Atmosphere"
	parent.add_child(atmosphere)
	var state := WorldState.new()
	atmosphere.apply_mood(RegionMood.fog(data, state), RegionMood.light(data, state), false)
	# Distance fog would wash out the wide prop overview; the lineups are about the models.
	atmosphere.environment.fog_enabled = false
	return atmosphere
