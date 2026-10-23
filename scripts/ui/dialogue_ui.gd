class_name DialogueUI
extends CanvasLayer
## Bottom-of-screen dialogue box. Listens to GameState.dialogue_requested, drives a
## DialogueRunner, and locks player input while open.
##
## Controls: interact/click to continue; click, number keys or gamepad to pick a choice.
## Lines type out at the player's text speed (GameSettings); interact/click while a line is
## still typing shows the rest of it at once (nothing waits on the reveal).

signal closed
## Each spoken line as it shows (`speaker` is an NPC id, "player" or "narrator"); the
## AudioDirector speaks it in that voice.
signal line_shown(speaker: String, text: String)

var runner: DialogueRunner
var current_event: Dictionary = {}

var _panel: PanelContainer
var _name_label: Label
var _text_label: RichTextLabel
var _continue_hint: Label
var _choices_box: VBoxContainer
## Oda's chart, shown in place of the dialogue box for a `lane_map` option.
var lane_map: LaneMap
## Characters of the current line shown so far (fractional; ticks up at the text speed).
var _revealed := 0.0


func _ready() -> void:
	layer = 10
	add_to_group(&"dialogue_ui")
	runner = DialogueRunner.new(Content.db, GameState.world)
	GameState.dialogue_requested.connect(func(dialogue_id: String, _npc: String) -> void: open(dialogue_id))
	_build()
	_panel.hide()


func is_open() -> bool:
	return _panel.visible or (lane_map != null and lane_map.visible)


func open(dialogue_id: String) -> void:
	if is_open() or dialogue_id.is_empty():
		return
	GameState.input_locked = true
	_panel.show()
	_show(runner.start(dialogue_id))


## True while the current line is still typing out.
func is_revealing() -> bool:
	return _text_label != null and _text_label.visible_characters >= 0


## Shows the rest of the current line at once (a press mid-line; screenshots).
func finish_reveal() -> void:
	if _text_label != null:
		_text_label.visible_characters = -1


func _process(delta: float) -> void:
	if not is_open() or not is_revealing():
		return
	_revealed += delta * GameSettings.current().text_speed
	if GameSettings.current().text_speed <= 0.0 or int(_revealed) >= _text_label.get_total_character_count():
		finish_reveal()
	else:
		_text_label.visible_characters = int(_revealed)


## The player's continue press: shows the rest of a line still typing, else moves on.
func press_continue() -> void:
	if is_revealing():
		finish_reveal()
	else:
		advance()


func advance() -> void:
	if current_event.get("type") == "line":
		_show(runner.next())


func select(index: int) -> void:
	if current_event.get("type") == "choices":
		_show(runner.choose(index))


## The lane map's answer: a port to sail for, or "" to go back to the options.
func sail_to(port_id: String) -> void:
	if current_event.get("type") == "lane_map":
		lane_map.close()
		_panel.show()
		_show(runner.sail_to(port_id))


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if current_event.get("type") == "line":
		var click := event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		if event.is_action_pressed("interact") or click:
			get_viewport().set_input_as_handled()
			press_continue()
	elif current_event.get("type") == "choices" and event is InputEventKey and event.is_pressed():
		var key := (event as InputEventKey).physical_keycode
		if key >= KEY_1 and key <= KEY_9:
			var index := key - KEY_1
			if index < (current_event["options"] as Array).size():
				get_viewport().set_input_as_handled()
				select(index)


func _show(event: Dictionary) -> void:
	current_event = event
	for child in _choices_box.get_children():
		child.queue_free()
	match event.get("type"):
		"line":
			var speaker_name := str(event.get("name", ""))
			_name_label.text = speaker_name
			_name_label.visible = not speaker_name.is_empty()
			_text_label.text = str(event.get("text", ""))
			_revealed = 0.0
			_text_label.visible_characters = 0 if GameSettings.current().text_speed > 0.0 else -1
			_continue_hint.text = InputSetup.hint("interact") + " continue"
			_continue_hint.show()
			line_shown.emit(str(event.get("speaker", "")), _text_label.text)
		"choices":
			finish_reveal()
			_continue_hint.hide()
			var i := 0
			for option: Dictionary in event.get("options", []):
				var button := Button.new()
				button.text = "%d. %s" % [i + 1, option.get("text", "")]
				button.alignment = HORIZONTAL_ALIGNMENT_LEFT
				button.pressed.connect(select.bind(i))
				_choices_box.add_child(button)
				i += 1
			if _choices_box.get_child_count() > 0:
				(_choices_box.get_child(0) as Button).call_deferred("grab_focus")
		"lane_map":
			finish_reveal()
			_panel.hide()
			lane_map.open()
		_:
			_close()


func _close() -> void:
	finish_reveal()
	_panel.hide()
	lane_map.close()
	current_event = {}
	# Defer unlocking so the key press that closed dialogue doesn't re-trigger interact.
	(func() -> void: GameState.input_locked = false).call_deferred()
	closed.emit()
	# A `travel` effect (the ferry sailing) moves the player once the scene has been read.
	if not runner.pending_travel.is_empty():
		var target := runner.pending_travel
		runner.pending_travel = []
		GameState.travel(str(target[0]), str(target[1]))


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DialoguePanel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -230
	_panel.offset_left = 80
	_panel.offset_right = -80
	_panel.offset_bottom = -24
	_panel.theme = UiTheme.get_theme()
	add_child(_panel)
	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)
	_name_label = Label.new()
	_name_label.theme_type_variation = UiTheme.SPEAKER
	vbox.add_child(_name_label)
	_text_label = RichTextLabel.new()
	_text_label.fit_content = true
	_text_label.bbcode_enabled = true
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_text_label)
	_choices_box = VBoxContainer.new()
	vbox.add_child(_choices_box)
	_continue_hint = Label.new()
	_continue_hint.text = InputSetup.hint("interact") + " continue"
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_hint.theme_type_variation = UiTheme.HINT
	vbox.add_child(_continue_hint)
	lane_map = LaneMap.new()
	lane_map.name = "LaneMap"
	add_child(lane_map)
	lane_map.chosen.connect(sail_to)
	lane_map.cancelled.connect(sail_to.bind(""))
