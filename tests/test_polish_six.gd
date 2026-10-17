extends TestCase
## Day 48 — Polish/debt pass six: no model prop stands wholly under the sea (the Teeth's road
## rocks moved onto the road's shoulder, the "awash" outcrops raised to break the surface, the
## reeds out of deep water into the shallows); the title screen's name follows the text size.

const TEETH := "wrack_teeth"
const ROCK := "teeth_rock.glb"

var _tops: Dictionary = {}


## The highest point of a model (model space, before the prop's `scale`).
func _model_top(path: String) -> float:
	if not _tops.has(path):
		var root := (load(path) as PackedScene).instantiate() as Node3D
		var top := -INF
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var box := mi.transform * mi.get_aabb()
			var parent := mi.get_parent()
			while parent is Node3D and parent != root:
				box = (parent as Node3D).transform * box
				parent = parent.get_parent()
			top = maxf(top, box.end.y)
		root.free()
		_tops[path] = top
	return float(_tops[path])


## The world height of a prop's top, placed as Region.place does (ground-relative unless `snap`
## is false).
func _prop_top(field: TerrainField, prop: Dictionary) -> float:
	var pos := JsonUtil.to_vector3(prop["position"])
	var y := pos.y + (field.surface_at(pos.x, pos.z) if bool(prop.get("snap", true)) else 0.0)
	return y + _model_top(str(prop["model"])) * float(prop.get("scale", 1.0))


func test_no_model_prop_stands_under_the_sea() -> void:
	var db := load_content()
	var drowned: Array[String] = []
	for id: String in db.regions:
		var region: Dictionary = db.get_region(id)
		if not region.has("ground") or not region.has("water_level"):
			continue
		var water := float(region["water_level"])
		var field := TerrainField.from_data(region["ground"], water)
		for prop: Dictionary in region.get("props", []):
			if str(prop.get("model", "")).is_empty():
				continue
			var top := _prop_top(field, prop)
			if top < water + 0.02:
				drowned.append("%s: %s at %s (top %.2f, sea %.2f)" % [id, str(prop["model"]).get_file(), prop["position"], top, water])
	assert_empty(drowned, "props hidden under the sea")


func test_the_teeths_road_rocks_stand_on_its_shoulder() -> void:
	var region := load_content().get_region(TEETH)
	var water := float(region["water_level"])
	var field := TerrainField.from_data(region["ground"], water)
	var road: Array = (region["ground"]["land"] as Array).filter(
			func(f: Dictionary) -> bool: return str(f.get("note", "")) == "the reef road on the white")[0]["path"]
	var edge := 0
	for prop: Dictionary in region["props"]:
		if str(prop.get("model", "")).get_file() != ROCK or not bool(prop.get("snap", true)):
			continue
		edge += 1
		var pos := JsonUtil.to_vector3(prop["position"])
		var p := Vector2(pos.x, pos.z)
		var off := INF
		for i in road.size() - 1:
			var a := Vector2(float(road[i][0]), float(road[i][1]))
			var b := Vector2(float(road[i + 1][0]), float(road[i + 1][1]))
			off = minf(off, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
		assert_true(off > 1.5 and off < 2.0, "a road rock at %s sits on the shoulder (%.2f m off the line)" % [pos, off])
		assert_true(_prop_top(field, prop) >= water + 0.1, "...and stands a hand proud of the sea (%s)" % pos)
	assert_eq(edge, 9, "nine rocks along the road's edges (the tenth, by the gully, is awash with the slabs)")


func test_the_title_name_follows_the_text_size() -> void:
	var title := TitleScreen.new()
	title._build()
	assert_eq(title._game_title.theme_type_variation, UiTheme.GAME_TITLE, "the name has its own type")
	assert_false(title._game_title.has_theme_font_size_override(&"font_size"), "no fixed size on the label")
	title.free()
	var theme := UiTheme.get_theme()
	assert_eq(theme.get_font_size(&"font_size", UiTheme.GAME_TITLE), 64, "64 px at normal size")
	assert_true(theme.get_constant(&"outline_size", UiTheme.GAME_TITLE) > 0, "outlined over the beach")
	UiTheme.set_text_scale(1.5)
	assert_eq(theme.get_font_size(&"font_size", UiTheme.GAME_TITLE), 96, "and grows with large text")
	UiTheme.set_text_scale(1.0)
