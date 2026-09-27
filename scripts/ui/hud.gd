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
	label.theme_type_variation = UiTheme.HUD_TOAST
	_toasts.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


func _build() -> void:
	# One full-screen root carries the shared theme; it never takes mouse input.
	var root := Control.new()
	root.name = "HudRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)
	_prompt = _make_label(UiTheme.HUD_PROMPT)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -300
	_prompt.offset_bottom = -260
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.hide()
	root.add_child(_prompt)
	_title = _make_label(UiTheme.HUD_TITLE)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.offset_top = 60
	_title.offset_bottom = 120
	_title.offset_left = -400
	_title.offset_right = 400
	_title.modulate.a = 0.0
	root.add_child(_title)
	var keys := Label.new()
	keys.text = "[J] Journal   [I] Satchel"
	keys.theme_type_variation = UiTheme.HUD_KEYS
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	keys.offset_left = 20
	keys.offset_top = -40
	root.add_child(keys)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_toasts.offset_left = -420
	_toasts.offset_right = -20
	_toasts.offset_top = 20
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(_toasts)


func _make_label(variation: StringName) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.theme_type_variation = variation
	return label
