extends SceneTree
## Prints an ASCII map of each region's sculpted ground for tuning `ground` data:
##   godot --headless --path . -s res://tools/debug/terrain_map.gd [-- <region_id>]
## '#' reachable from the default spawn, '+' walkable but unreachable, '^' too steep,
## '~' sea (behind the shore wall), '=' reachable pier deck, '@' an NPC/pickup/object/exit/spawn. North (-z) is up.


func _init() -> void:
	var db := ContentDatabase.new()
	db.load_all()
	var only := OS.get_cmdline_user_args()
	for id: String in db.regions:
		if not only.is_empty() and id not in only:
			continue
		var region: Dictionary = db.get_region(id)
		if not region.has("ground"):
			continue
		var field := TerrainField.from_data(region["ground"], float(region.get("water_level", -INF)))
		var spawn := JsonUtil.to_vector3(region["spawn_points"]["default"])
		var reach := field.reachable_from(spawn.x, spawn.z)
		var marks: Dictionary = {}
		for key: String in ["npcs", "pickups", "objects", "exits"]:
			for entry: Dictionary in region.get(key, []):
				var p := JsonUtil.to_vector3(entry.get("position"))
				marks[field.cell_of(p.x, p.z)] = true
		for spawn_name: String in region["spawn_points"]:
			var p := JsonUtil.to_vector3(region["spawn_points"][spawn_name])
			marks[field.cell_of(p.x, p.z)] = true
		print("== %s  (x %s..%s, z %s..%s)" % [id, field.bounds.position.x, field.bounds.end.x, field.bounds.position.y, field.bounds.end.y])
		for iz in field.rows - 1:
			var line := ""
			for ix in field.cols - 1:
				var c := Vector2i(ix, iz)
				if marks.has(c):
					line += "@"
				elif reach.has(c):
					var mid := field.vertex_xz(ix, iz) + Vector2(field.cell, field.cell) * 0.5
					line += "=" if field.pier_deck(mid.x, mid.y) > -INF and field.is_wet(field.vertex_height(ix, iz)) else "#"
				elif field.is_cell_walkable(ix, iz):
					line += "+"
				elif field.is_wet(field.vertex_height(ix, iz)):
					line += "~"
				else:
					line += "^"
			print("%4d %s" % [int(field.vertex_xz(0, iz).y), line])
	quit(0)
