class_name ActEndCard
extends CanvasLayer
## Full-screen end-of-act card: title, the player's choices as recap lines, a coda, and a
## "Keep exploring" button. Fades in over the world; modal (locks input) while open.

signal closed

var _root: Control
var _title: Label
var _subtitle: Label
var _recap: RichTextLabel
var _coda: Label
var _button: Button


func _ready() -> void:
	layer = 12
	_build()
	_root.hide()


func is_open() -> bool:
	return _root.visible


## The recap text currently shown (for tests / smoke checks).
func recap_text() -> String:
	return _recap.get_parsed_text()


func show_act(act: Dictionary, recap: PackedStringArray) -> void:
	if is_open():
		return
	GameState.input_locked = true
	_title.text = str(act.get("title", ""))
	_subtitle.text = str(act.get("subtitle", ""))
	_subtitle.visible = not _subtitle.text.is_empty()
	_recap.text = "\n".join(Array(recap).map(func(line: String) -> String: return "•  " + line))
	_coda.text = str(act.get("coda", ""))
	_root.modulate.a = 0.0
	_root.show()
	create_tween().tween_property(_root, "modulate:a", 1.0, 1.5)
	_button.call_deferred("grab_focus")


func close() -> void:
	if not is_open():
		return
	_root.hide()
	(func() -> void: GameState.input_locked = false).call_deferred()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	_root = Control.new()
	_root.name = "ActEndRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(PropFactory.color("ink"), 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 760
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)
	_title = Label.new()
	_title.theme_type_variation = UiTheme.HUD_TITLE
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_subtitle = Label.new()
	_subtitle.theme_type_variation = UiTheme.SUBHEADING
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)
	_recap = RichTextLabel.new()
	_recap.fit_content = true
	_recap.bbcode_enabled = false
	box.add_child(_recap)
	_coda = Label.new()
	_coda.theme_type_variation = UiTheme.HINT
	_coda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_coda)
	_button = Button.new()
	_button.text = "Keep exploring"
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(close)
	box.add_child(_button)
