class_name JournalUI
extends CanvasLayer
## Full-screen book panel with three tabs: the quest Journal (J), the Satchel (I) and the
## Lanes (L, Day 65: Oda's chart to look at, read-only, once the first crossing is made).
## Pressing a tab's key opens it (or closes the panel if that tab is already showing); the
## pad's shoulder buttons step between tabs; Esc / gamepad B closes. Locks player input
## while open. Content comes from JournalModel and Lanes.
## A satchel entry with a `memory` (Day 70) can be remembered: interact (or Enter / pad A on the
## list, or the Remember button) hides the panel, plays the memory in the dialogue box, and opens
## the satchel again on the same entry when it ends. Meanwhile the world behind goes soft, drained
## and dim (Day 71: a memory's own look).

signal opened(tab: int)
signal closed
## A memory began playing from the satchel (item id, memory dialogue id).
signal remembering(item_id: String, memory: String)

## Seconds for the world to go soft behind a memory.
const VEIL_FADE := 0.6

enum Tab { JOURNAL, SATCHEL, LANES }

const TAB_NAMES: Array[String] = ["Journal", "Satchel", "Lanes"]
const TAB_ACTIONS: Array[String] = ["journal", "inventory", "lanes"]
## The read-only chart's size inside the panel (Oda's is LaneMap.CHART_SIZE).
const CHART_SIZE := Vector2(640, 340)

var tab: Tab = Tab.JOURNAL

var _root: Control
var _tab_buttons: Array[Button] = []
var _list: ItemList
var _heading: Label
var _subheading: Label
var _body: RichTextLabel
var _empty: Label
var _hint: Label
var _split: Control
var _lanes: LaneMap
var _no_chart: Label
var _remember: Button
## The item whose memory is playing ("" when none); the satchel reopens on it afterwards.
var _remembering := ""
## The world behind a memory (Day 71): soft, drained and dim while the dialogue box plays it.
var _veil: ColorRect
var _veil_tween: Tween
## Entries currently listed (JournalModel dictionaries), parallel to _list items.
var _entries: Array[Dictionary] = []


func _ready() -> void:
	layer = 8
	_build()
	_root.hide()
	GameState.world.quest_changed.connect(func(_id: String, _s: String, _st: String) -> void: _refresh_if_open())
	GameState.world.inventory_changed.connect(func(_id: String, _c: int) -> void: _refresh_if_open())
	GameState.input_device_changed.connect(_label_hint)
	GameSettings.current().changed.connect(_label_hint)


## Tab keys and "[Esc] close" / "[LB] [RB] tabs  [B] close", following the bindings and the
## device used last.
func _label_hint() -> void:
	for i in _tab_buttons.size():
		_tab_buttons[i].text = TAB_NAMES[i] if InputSetup.pad_last else "%s  %s" % [TAB_NAMES[i], InputSetup.hint(TAB_ACTIONS[i])]
	_hint.text = InputSetup.back_hint() + " close"
	_remember.text = "%s Remember" % InputSetup.hint("interact")
	if InputSetup.pad_last:
		_hint.text = "%s %s tabs   %s" % [InputSetup.hint("tab_left"), InputSetup.hint("tab_right"), _hint.text]


func is_open() -> bool:
	return _root.visible


func open(which: Tab) -> void:
	if not is_open():
		if GameState.input_locked:
			return # another modal (dialogue) owns input
		GameState.input_locked = true
		_root.show()
	tab = which
	_refresh()
	opened.emit(tab)


func close() -> void:
	if not is_open():
		return
	_root.hide()
	(func() -> void: GameState.input_locked = false).call_deferred()
	closed.emit()


## The text shown in the detail pane (for tests / smoke checks).
func detail_text() -> String:
	return _body.get_parsed_text()


func entry_count() -> int:
	return _entries.size()


## The Lanes tab's chart (tests, screenshots).
func lane_chart() -> LaneMap:
	return _lanes


## True when the Lanes tab shows the chart rather than "no chart yet".
func chart_shown() -> bool:
	return is_open() and tab == Tab.LANES and _lanes.visible


func _unhandled_input(event: InputEvent) -> void:
	for i in TAB_ACTIONS.size():
		if event.is_action_pressed(TAB_ACTIONS[i]):
			if is_open() and tab == i:
				close()
			else:
				open(i as Tab)
			get_viewport().set_input_as_handled()
			return
	if is_open():
		for pair: Array in [["tab_left", -1], ["tab_right", 1]]:
			if event.is_action_pressed(pair[0]):
				open(posmod(tab + int(pair[1]), TAB_NAMES.size()) as Tab)
				get_viewport().set_input_as_handled()
				return
	if is_open() and tab == Tab.SATCHEL and event.is_action_pressed("interact"):
		remember()
		get_viewport().set_input_as_handled()
		return
	if is_open() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## The memory of the selected satchel entry ("" when it has none, or the satchel isn't showing).
func selected_memory() -> String:
	var selected := _list.get_selected_items()
	if not is_open() or tab != Tab.SATCHEL or selected.is_empty() or selected[0] >= _entries.size():
		return ""
	return str(_entries[selected[0]].get("memory", ""))


## True while a memory started from the satchel is playing.
func is_remembering() -> bool:
	return not _remembering.is_empty()


## Plays the selected entry's memory: the panel steps aside (input stays locked) for the dialogue
## box, and comes back on the same entry when the memory ends.
func remember() -> void:
	var memory := selected_memory()
	if memory.is_empty():
		return
	var dialogue := get_tree().get_first_node_in_group(&"dialogue_ui") as DialogueUI if is_inside_tree() else null
	_remembering = _selected_id()
	_root.hide()
	_fade_veil(1.0)
	remembering.emit(_remembering, memory)
	if dialogue == null:
		return # tests drive the memory themselves, then call end_remembering()
	dialogue.open(memory)
	await dialogue.closed
	# The dialogue unlocks input on a deferred call queued before `closed`; reopen after it.
	end_remembering.call_deferred()


## Back to the satchel on the remembered entry. Input is still locked here only by the satchel
## itself (when no dialogue box played the memory), so it is taken over rather than refused.
func end_remembering() -> void:
	if _remembering.is_empty():
		return
	var item := _remembering
	_remembering = ""
	_fade_veil(0.0)
	GameState.input_locked = false
	open(Tab.SATCHEL)
	for i in _entries.size():
		if str(_entries[i]["id"]) == item:
			_list.select(i)
			_show_entry(i)


## How far the world is veiled for a memory (0..1; for tests).
func veil_amount() -> float:
	return float((_veil.material as ShaderMaterial).get_shader_parameter("amount")) if _veil.visible else 0.0


## Eases the memory veil in (1) or straight off (0: the satchel's own shade takes over).
func _fade_veil(to: float) -> void:
	if _veil_tween:
		_veil_tween.kill()
	var look := _veil.material as ShaderMaterial
	if to <= 0.0:
		_veil.hide()
		look.set_shader_parameter("amount", 0.0)
		return
	_veil.show()
	if not is_inside_tree():
		look.set_shader_parameter("amount", to)
		return
	look.set_shader_parameter("amount", 0.0)
	_veil_tween = create_tween()
	_veil_tween.tween_method(func(v: float) -> void: look.set_shader_parameter("amount", v), 0.0, to, VEIL_FADE)


func _refresh_if_open() -> void:
	if is_open():
		_refresh()


func _refresh() -> void:
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = i == tab
	_split.visible = tab != Tab.LANES
	if tab == Tab.LANES:
		_show_lanes()
		return
	_lanes.close()
	_no_chart.hide()
	var previous := _selected_id()
	_entries = JournalModel.quest_entries(Content.db, GameState.world) if tab == Tab.JOURNAL \
			else JournalModel.item_entries(Content.db, GameState.world)
	_list.clear()
	var select_index := 0
	for i in _entries.size():
		var entry := _entries[i]
		if tab == Tab.JOURNAL:
			_list.add_item(str(entry["title"]) + ("  (done)" if entry["done"] else ""))
			if entry["done"]:
				_list.set_item_custom_fg_color(i, PropFactory.color("silverfog"))
		else:
			var count: int = entry["count"]
			_list.add_item(str(entry["name"]) + (" ×%d" % count if count > 1 else ""))
			if entry["remnant"]:
				_list.set_item_custom_fg_color(i, PropFactory.color("kindle" if entry["own"] else "ember"))
		if entry["id"] == previous:
			select_index = i
	var has_entries := not _entries.is_empty()
	_empty.visible = not has_entries
	_empty.text = "No tasks yet. Talk to the people of the Lanternreach." if tab == Tab.JOURNAL \
			else "Your satchel is empty."
	_list.visible = has_entries
	if has_entries:
		_list.select(select_index)
		_show_entry(select_index)
		_list.grab_focus.call_deferred()
	else:
		_heading.text = ""
		_subheading.text = ""
		_body.text = ""
		_remember.hide()


func _show_lanes() -> void:
	var known := Lanes.chart_known(Content.db, GameState.world)
	_no_chart.visible = not known
	if known:
		_lanes.open()
	else:
		_lanes.close()


func _selected_id() -> String:
	var selected := _list.get_selected_items()
	if selected.is_empty() or selected[0] >= _entries.size():
		return ""
	return str(_entries[selected[0]]["id"])


func _show_entry(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	var entry := _entries[index]
	var lines: PackedStringArray = []
	if tab == Tab.JOURNAL:
		_heading.text = str(entry["title"])
		_subheading.text = "Completed" if entry["done"] else "In progress"
		if not str(entry["description"]).is_empty():
			lines.append("[i]%s[/i]\n" % entry["description"])
		if not entry["done"]:
			lines.append("[color=#%s]• %s[/color]" % [PropFactory.color("kindle").to_html(false), entry["current"]])
		var faded := PropFactory.color("silverfog").to_html(false)
		var completed: Array[String] = entry["completed"]
		for i in range(completed.size() - 1, -1, -1):
			lines.append("[color=#%s][s]%s[/s][/color]" % [faded, completed[i]])
	else:
		_heading.text = str(entry["name"])
		_subheading.text = str(entry["kind_label"])
		if int(entry["count"]) > 1:
			_subheading.text += "  ·  carrying %d" % int(entry["count"])
		lines.append(str(entry["description"]))
	_remember.visible = tab == Tab.SATCHEL and not str(entry.get("memory", "")).is_empty()
	# Remnants are called out in ember (the Wakebearer's own in pale kindle); everything else uses the
	# theme's subheading colour.
	if entry.get("remnant", false):
		_subheading.add_theme_color_override("font_color", PropFactory.color("kindle" if entry.get("own", false) else "ember"))
	else:
		_subheading.remove_theme_color_override("font_color")
	_body.text = "\n".join(lines)


func _build() -> void:
	_veil = ColorRect.new()
	_veil.name = "RememberVeil"
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var veil_look := ShaderMaterial.new()
	veil_look.shader = preload("res://assets/shaders/remembering.gdshader")
	_veil.material = veil_look
	_veil.hide()
	add_child(_veil)
	_root = Control.new()
	_root.name = "JournalRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(PropFactory.color("ink"), 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 0.1
	panel.anchor_bottom = 0.9
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	_root.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	panel.add_child(outer)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	outer.add_child(tabs)
	var group := ButtonGroup.new()
	for i in TAB_NAMES.size():
		var button := Button.new()
		button.text = TAB_NAMES[i]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: open(i as Tab))
		tabs.add_child(button)
		_tab_buttons.append(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	_hint = Label.new()
	_hint.theme_type_variation = UiTheme.HINT
	tabs.add_child(_hint)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 20)
	outer.add_child(split)
	_split = split

	_lanes = LaneMap.new()
	_lanes.name = "LaneChart"
	_lanes.read_only = true
	_lanes.chart_size = CHART_SIZE
	_lanes.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.add_child(_lanes)
	_no_chart = Label.new()
	_no_chart.text = "No chart yet. The Tidewrights keep the lanes; their ferry-master will show you, once you sail with her."
	_no_chart.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_no_chart.theme_type_variation = UiTheme.HINT
	_no_chart.hide()
	outer.add_child(_no_chart)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 300
	left.size_flags_stretch_ratio = 0.4
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_show_entry)
	_list.item_activated.connect(func(_i: int) -> void: remember())
	left.add_child(_list)
	_empty = Label.new()
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.theme_type_variation = UiTheme.HINT
	left.add_child(_empty)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	split.add_child(right)
	_heading = Label.new()
	_heading.theme_type_variation = UiTheme.HEADING
	right.add_child(_heading)
	_subheading = Label.new()
	_subheading.theme_type_variation = UiTheme.SUBHEADING
	right.add_child(_subheading)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_body)
	_remember = Button.new()
	_remember.name = "Remember"
	_remember.focus_mode = Control.FOCUS_NONE
	_remember.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_remember.pressed.connect(remember)
	_remember.hide()
	right.add_child(_remember)
	_label_hint()
