class_name JournalUI
extends CanvasLayer
## Full-screen book panel with two tabs: the quest Journal (J) and the Satchel (I).
## Pressing a tab's key opens it (or closes the panel if that tab is already showing);
## Esc / gamepad B closes. Locks player input while open. Content comes from JournalModel.

signal opened(tab: int)
signal closed

enum Tab { JOURNAL, SATCHEL }

const TAB_NAMES: Array[String] = ["Journal  [J]", "Satchel  [I]"]

var tab: Tab = Tab.JOURNAL

var _root: Control
var _tab_buttons: Array[Button] = []
var _list: ItemList
var _heading: Label
var _subheading: Label
var _body: RichTextLabel
var _empty: Label
## Entries currently listed (JournalModel dictionaries), parallel to _list items.
var _entries: Array[Dictionary] = []


func _ready() -> void:
	layer = 8
	_build()
	_root.hide()
	GameState.world.quest_changed.connect(func(_id: String, _s: String, _st: String) -> void: _refresh_if_open())
	GameState.world.inventory_changed.connect(func(_id: String, _c: int) -> void: _refresh_if_open())


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


func _unhandled_input(event: InputEvent) -> void:
	for pair: Array in [["journal", Tab.JOURNAL], ["inventory", Tab.SATCHEL]]:
		if event.is_action_pressed(pair[0]):
			if is_open() and tab == pair[1]:
				close()
			else:
				open(pair[1])
			get_viewport().set_input_as_handled()
			return
	if is_open() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _refresh_if_open() -> void:
	if is_open():
		_refresh()


func _refresh() -> void:
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = i == tab
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
				_list.set_item_custom_fg_color(i, PropFactory.color("ember"))
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
	_subheading.add_theme_color_override("font_color",
			PropFactory.color("ember" if entry.get("remnant", false) else "silverfog"))
	_body.text = "\n".join(lines)


func _build() -> void:
	_root = Control.new()
	_root.name = "JournalRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PropFactory.color("ink"), 0.96)
	style.border_color = PropFactory.color("ember")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
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
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_pressed_color", PropFactory.color("ember"))
		button.pressed.connect(func() -> void: open(i as Tab))
		tabs.add_child(button)
		_tab_buttons.append(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var hint := Label.new()
	hint.text = "[Esc] close"
	hint.add_theme_color_override("font_color", PropFactory.color("silverfog"))
	tabs.add_child(hint)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 20)
	outer.add_child(split)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 300
	left.size_flags_stretch_ratio = 0.4
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_size_override("font_size", 19)
	_list.add_theme_color_override("font_color", PropFactory.color("bone"))
	_list.add_theme_color_override("font_selected_color", PropFactory.color("kindle"))
	_list.item_selected.connect(_show_entry)
	left.add_child(_list)
	_empty = Label.new()
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.add_theme_color_override("font_color", PropFactory.color("silverfog"))
	_empty.add_theme_font_size_override("font_size", 18)
	left.add_child(_empty)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	split.add_child(right)
	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 28)
	_heading.add_theme_color_override("font_color", PropFactory.color("ember"))
	right.add_child(_heading)
	_subheading = Label.new()
	_subheading.add_theme_font_size_override("font_size", 16)
	right.add_child(_subheading)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("default_color", PropFactory.color("bone"))
	_body.add_theme_font_size_override("normal_font_size", 20)
	_body.add_theme_font_size_override("italics_font_size", 20)
	_body.add_theme_constant_override("line_separation", 6)
	right.add_child(_body)
