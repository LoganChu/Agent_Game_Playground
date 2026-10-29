class_name LaneMap
extends PanelContainer
## The lane map (Day 59): Oda's chart of the Tidewright lanes, opened from her "Where can you
## take me?" option. Islands the player knows sit round dark Cindermoor; lit lanes are drawn
## gold, lanes not yet sailed dashed, lanes the ferry won't sail yet grey. Focusing a port
## shows its light and the way there; pressing it sails (if the ferry will), "Not yet" or
## Esc goes back to Oda's options. Owned by DialogueUI, which holds the input lock.
##
## `read_only` (Day 65) is the journal's Lanes tab: the same chart, smaller and unframed,
## where focusing a port tells of it and nothing sails; the journal owns Esc and the lock.

signal chosen(port_id: String)
signal cancelled

const CHART_SIZE := Vector2(720, 420)
const ISLAND_RADIUS := 22.0

var _chart: Control
var _heading: Label
var _info: Label
var _legend: Label
var _cancel: Button
var _buttons: Dictionary = {}  # port id -> Button
var _focused := ""
## Set before adding to the tree: a chart to look at, not sail from (the journal's Lanes tab).
var read_only := false
var chart_size := CHART_SIZE


func _ready() -> void:
	GameState.input_device_changed.connect(_label_legend)
	theme = UiTheme.get_theme()
	if read_only:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		grow_horizontal = Control.GROW_DIRECTION_BOTH
		grow_vertical = Control.GROW_DIRECTION_BOTH
	var vbox := VBoxContainer.new()
	add_child(vbox)
	_heading = Label.new()
	_heading.theme_type_variation = UiTheme.HEADING
	vbox.add_child(_heading)
	_chart = Control.new()
	_chart.custom_minimum_size = chart_size
	_chart.clip_contents = true
	_chart.draw.connect(_draw_chart)
	vbox.add_child(_chart)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(chart_size.x, 0)
	vbox.add_child(_info)
	_legend = Label.new()
	_legend.theme_type_variation = UiTheme.HINT
	_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legend.custom_minimum_size = Vector2(chart_size.x, 0)
	vbox.add_child(_legend)
	_label_legend()
	_cancel = Button.new()
	_cancel.text = "Not yet."
	_cancel.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cancel.pressed.connect(func() -> void: cancelled.emit())
	_cancel.focus_entered.connect(_focus_port.bind(""))
	vbox.add_child(_cancel)
	_cancel.visible = not read_only
	hide()


## Fills the chart from the lanes and the world state and shows it, focus on the ferry's port.
func open() -> void:
	for button: Button in _buttons.values():
		button.queue_free()
	_buttons.clear()
	var db := Content.db
	var state := GameState.world
	var here := Lanes.current_port(db, state)
	_heading.text = "The Lanes — the Slow Mercy lies at %s" % Lanes.port(db, here).get("name", "")
	for id in Lanes.known_ports(db, state):
		var button := Button.new()
		button.flat = true
		button.text = str(Lanes.port(db, id).get("name", id))
		button.pressed.connect(press_port.bind(id))
		button.focus_entered.connect(_focus_port.bind(id))
		button.mouse_entered.connect(button.grab_focus)
		_chart.add_child(button)
		_buttons[id] = button
	show()
	_place_buttons.call_deferred()
	var start := here if read_only else _first_destination(here)
	var first: Button = _buttons.get(start, _cancel)
	first.call_deferred("grab_focus")
	_focus_port(start)


func close() -> void:
	hide()


## The port buttons' ids (tests, smoke).
func port_ids() -> Array:
	return _buttons.keys()


## Moves focus to a port's button (debug screenshots).
func focus_port(id: String) -> void:
	if _buttons.has(id):
		(_buttons[id] as Button).grab_focus()


func info_text() -> String:
	return _info.text


## A port pressed (or the smoke test's pick): sails if the ferry will, else says why not.
func press_port(id: String) -> void:
	if read_only:
		_focus_port(id)
		return
	var voyage := Lanes.voyage(Content.db, GameState.world, id)
	if bool(voyage.get("ok", false)):
		chosen.emit(id)
	else:
		_focus_port(id)
		_info.text = str(voyage.get("reason", ""))


func _unhandled_input(event: InputEvent) -> void:
	if not visible or read_only:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()
	elif event.is_action_pressed("interact"):
		# The talk key works the chart like the choice buttons' accept does.
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and is_ancestor_of(focused):
			get_viewport().set_input_as_handled()
			(focused as Button).pressed.emit()


## The first port the ferry would sail to from `here` (where focus starts), else `here`.
func _first_destination(here: String) -> String:
	for id in Lanes.known_ports(Content.db, GameState.world):
		if bool(Lanes.voyage(Content.db, GameState.world, id).get("ok", false)):
			return id
	return here


func _point(map: Variant) -> Vector2:
	var p: Array = map if map is Array else [0.5, 0.5]
	return Vector2(float(p[0]), float(p[1])) * chart_size


func _place_buttons() -> void:
	for id: String in _buttons:
		var button: Button = _buttons[id]
		var at := _point(Lanes.port(Content.db, id).get("map"))
		var size := button.get_combined_minimum_size()
		var pos := at + Vector2(-size.x * 0.5, ISLAND_RADIUS + 2.0)
		if at.y > chart_size.y * 0.7:
			pos.y = at.y - ISLAND_RADIUS - size.y - 2.0
		button.position = pos.clamp(Vector2.ZERO, chart_size - size)
		button.size = size


## The legend, ending in the back key for the device used last. The journal's narrower chart
## gets the short form, so it stays on one line.
func _label_legend() -> void:
	if read_only:
		_legend.text = "Gold: sailed · dashed: not yet · grey: not this tide · %s close" % InputSetup.back_hint()
	else:
		_legend.text = "Solid gold: a lane sailed · dashed gold: not sailed yet · grey: not this tide · %s back" \
				% InputSetup.back_hint()


## True when the legend fits on one line at the chart's width, in the game's theme at the
## current text size (tests).
func legend_fits() -> bool:
	var theme := UiTheme.get_theme()
	var font := theme.get_font(&"font", UiTheme.HINT)
	var size := theme.get_font_size(&"font_size", UiTheme.HINT)
	return font.get_string_size(_legend.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= chart_size.x


func _focus_port(id: String) -> void:
	_focused = id
	_chart.queue_redraw()
	if id.is_empty():
		_info.text = "Stay ashore for now."
		return
	var db := Content.db
	var state := GameState.world
	var entry := Lanes.port(db, id)
	var lit := "lit" if Lanes.port_lit(db, state, id) else "dark"
	var line := "%s — %s, %s." % [entry.get("name", id), entry.get("light", ""), lit]
	var voyage := Lanes.voyage(db, state, id)
	if id == Lanes.current_port(db, state):
		line += " The Slow Mercy is moored here."
	elif bool(voyage.get("ok", false)):
		var press := "Oda can sail you there." if read_only else "Press to sail."
		var path: Array = voyage["route"]
		if path.size() == 2:
			var lane_name := str(Lanes.lane_between(db, path[0], path[1]).get("name", ""))
			line += " %s. %s" % [lane_name.left(1).to_upper() + lane_name.substr(1), press]
		else:
			var via: Array = path.slice(1, path.size() - 1).map(func(p: String) -> String: return str(Lanes.port(db, p).get("name", p)))
			line += " By way of %s. %s" % [", ".join(via), press]
	else:
		line += " " + str(voyage.get("reason", ""))
	_info.text = line


func _draw_chart() -> void:
	var db := Content.db
	var state := GameState.world
	var ink := PropFactory.color("ink")
	var abyss := PropFactory.color("abyss")
	var tide := PropFactory.color("tide")
	var fog := PropFactory.color("silverfog")
	var kindle := PropFactory.color("kindle")
	var ember := PropFactory.color("ember")
	_chart.draw_rect(Rect2(Vector2.ZERO, chart_size), abyss.lerp(ink, 0.35))
	# Faint chart lines, like a pilot's grid.
	for x in range(0, int(chart_size.x) + 1, 60):
		_chart.draw_line(Vector2(x, 0), Vector2(x, chart_size.y), Color(tide, 0.12), 1.0)
	for y in range(0, int(chart_size.y) + 1, 60):
		_chart.draw_line(Vector2(0, y), Vector2(chart_size.x, y), Color(tide, 0.12), 1.0)
	var route: Array = []
	if not _focused.is_empty():
		route = Lanes.voyage(db, state, _focused).get("route", [])
	for lane in Lanes.known_lanes(db, state):
		var ends: Array = lane["between"]
		var a := _point(Lanes.port(db, str(ends[0])).get("map"))
		var b := _point(Lanes.port(db, str(ends[1])).get("map"))
		var on_route := _on_route(route, str(ends[0]), str(ends[1]))
		if not Lanes.lane_open(lane, state):
			_chart.draw_dashed_line(a, b, Color(fog, 0.35), 2.0, 8.0)
		elif Lanes.lane_sailed(lane, state):
			_chart.draw_line(a, b, ember if on_route else Color(kindle, 0.75), 4.0 if on_route else 3.0, true)
		else:
			_chart.draw_dashed_line(a, b, ember if on_route else Color(kindle, 0.6), 3.0, 12.0)
	for mark in Lanes.known_landmarks(db, state):
		var c := _point(mark.get("map"))
		var below := ISLAND_RADIUS * 1.8
		if str(mark.get("look", "spire")) == "water":
			# Water nobody sails: a patch of fog and a few skerries in it, no lane drawn in.
			below = _draw_fog_water(c, Color(fog, 1.0), Color(ink, 1.0).lerp(fog, 0.25))
		else:
			_draw_island(c, ISLAND_RADIUS * 1.8, Color(ink, 1.0).lerp(fog, 0.15), false)
			# The dark Spire: a cold spike on the isle.
			_chart.draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 6), c + Vector2(5, 6), c + Vector2(0, -26)]), Color(fog, 0.45))
		var font := get_theme_default_font()
		var text := str(mark.get("name", ""))
		var fsize := get_theme_default_font_size()
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var at := c + Vector2(-w * 0.5, below + fsize + 4)
		if str(mark.get("look", "spire")) == "water":
			at = c + Vector2(-below - w, fsize * 0.35)  # beside the fog: water lies low on the chart, under Cindermoor's name
		_chart.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(fog, 0.6))
	var here := Lanes.current_port(db, state)
	for id in Lanes.known_ports(db, state):
		var c := _point(Lanes.port(db, id).get("map"))
		var lit := Lanes.port_lit(db, state, id)
		if lit:
			_chart.draw_circle(c, ISLAND_RADIUS * 1.9, Color(kindle, 0.12))
		_draw_island(c, ISLAND_RADIUS, PropFactory.color("moss") if lit else PropFactory.color("slate"), lit)
		if id == here:
			_chart.draw_arc(c, ISLAND_RADIUS + 7.0, 0.0, TAU, 32, ember, 2.5, true)
		if id == _focused:
			_chart.draw_arc(c, ISLAND_RADIUS + 12.0, 0.0, TAU, 32, Color(kindle, 0.9), 1.5, true)


func _on_route(route: Array, a: String, b: String) -> bool:
	for i in route.size() - 1:
		if (route[i] == a and route[i + 1] == b) or (route[i] == b and route[i + 1] == a):
			return true
	return false


## Unsailed water on the chart: soft fog puffs with a scatter of tiny skerries; returns how far out from the
## centre the label should go.
func _draw_fog_water(c: Vector2, fog: Color, rock: Color) -> float:
	var r := ISLAND_RADIUS * 1.6
	for i in 7:
		var a := TAU * float(i) / 7.0
		_chart.draw_circle(c + Vector2(cos(a) * r * 0.9, sin(a) * r * 0.45), r * 0.7, Color(fog, 0.07))
	_chart.draw_circle(c, r, Color(fog, 0.08))
	for spot: Vector2 in [Vector2(-0.7, 0.1), Vector2(-0.2, -0.3), Vector2(0.35, 0.2), Vector2(0.8, -0.15), Vector2(0.05, 0.35)]:
		_draw_island(c + spot * r, ISLAND_RADIUS * 0.28, rock, false)
	for row: float in [-0.55, 0.6]:
		var y := c.y + row * r
		_chart.draw_dashed_line(Vector2(c.x - r * 1.3, y), Vector2(c.x + r * 1.3, y), Color(fog, 0.25), 1.0, 5.0)
	return r * 1.7


## A faceted low-poly isle; a lit one carries its beacon as a bright point.
func _draw_island(c: Vector2, r: float, color: Color, lit: bool) -> void:
	var points := PackedVector2Array()
	var sides := 7
	for i in sides:
		var angle := TAU * i / sides + 0.3
		var wobble := 0.78 + 0.22 * absf(sin(i * 2.3 + c.x * 0.01))
		points.append(c + Vector2(cos(angle), sin(angle) * 0.75) * r * wobble)
	_chart.draw_colored_polygon(points, color)
	points.append(points[0])
	_chart.draw_polyline(points, Color(PropFactory.color("ink"), 0.8), 1.5, true)
	_chart.draw_circle(c + Vector2(0, -3), 4.0, PropFactory.color("kindle") if lit else Color(PropFactory.color("silverfog"), 0.5))
