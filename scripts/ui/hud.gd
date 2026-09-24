class_name Hud
extends CanvasLayer
## Interaction prompt, region title card and toast notifications.

const TOAST_SECONDS := 3.0

var _prompt: Label
var _title: Label
var _toasts: VBoxContainer


func _ready() -> void:
	layer = 5
	_build()
	GameState.toast.connect(show_toast)


func set_focus(target: Interactable) -> void:
	if target and is_instance_valid(target):
		_prompt.text = "[E] " + target.prompt
		_prompt.show()
	else:
		_prompt.hide()


func show_region_title(text: String) -> void:
	_title.text = text
	_title.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(_title, "modulate:a", 0.0, 1.5)


func show_toast(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_color_override("font_color", PropFactory.color("kindle"))
	label.add_theme_color_override("font_outline_color", PropFactory.color("ink"))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", 18)
	_toasts.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


func _build() -> void:
	_prompt = _make_label(22, PropFactory.color("bone"))
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -300
	_prompt.offset_bottom = -260
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.hide()
	add_child(_prompt)
	_title = _make_label(40, PropFactory.color("kindle"))
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.offset_top = 60
	_title.offset_bottom = 120
	_title.offset_left = -400
	_title.offset_right = 400
	_title.modulate.a = 0.0
	add_child(_title)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_toasts.offset_left = -420
	_toasts.offset_right = -20
	_toasts.offset_top = 20
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_toasts)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", PropFactory.color("ink"))
	label.add_theme_constant_override("outline_size", 8)
	return label
