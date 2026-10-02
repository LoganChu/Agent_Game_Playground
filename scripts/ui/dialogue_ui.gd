class_name DialogueUI
extends CanvasLayer
## Bottom-of-screen dialogue box. Listens to GameState.dialogue_requested, drives a
## DialogueRunner, and locks player input while open.
##
## Controls: interact/click to continue; click, number keys or gamepad to pick a choice.

signal closed

var runner: DialogueRunner
var current_event: Dictionary = {}

var _panel: PanelContainer
var _name_label: Label
var _text_label: RichTextLabel
var _continue_hint: Label
var _choices_box: VBoxContainer


func _ready() -> void:
	layer = 10
	runner = DialogueRunner.new(Content.db, GameState.world)
	GameState.dialogue_requested.connect(func(dialogue_id: String, _npc: String) -> void: open(dialogue_id))
	_build()
	_panel.hide()


func is_open() -> bool:
	return _panel.visible


func open(dialogue_id: String) -> void:
	if is_open() or dialogue_id.is_empty():
		return
	GameState.input_locked = true
	_panel.show()
	_show(runner.start(dialogue_id))


func advance() -> void:
	if current_event.get("type") == "line":
		_show(runner.next())


func select(index: int) -> void:
	if current_event.get("type") == "choices":
		_show(runner.choose(index))


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if current_event.get("type") == "line":
		var click := event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		if event.is_action_pressed("interact") or click:
			get_viewport().set_input_as_handled()
			advance()
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
			_continue_hint.show()
		"choices":
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
		_:
			_close()


func _close() -> void:
	_panel.hide()
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
	_continue_hint.text = "[E] continue"
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_hint.theme_type_variation = UiTheme.HINT
	vbox.add_child(_continue_hint)
