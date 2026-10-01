class_name Hud
extends CanvasLayer
## Interaction prompt, region title card, toast notifications, and the Greying: the ember
## meter, a grey wash as the ember wanes, and the full-screen fade when it runs out.

const TOAST_SECONDS := 3.0
## Seconds the ember meter lingers once full and out of the fog.
const METER_LINGER := 1.5
## Strongest grey wash over the screen, at an empty ember.
const WASH_ALPHA := 0.35

var _prompt: Label
var _title: Label
var _toasts: VBoxContainer
var _meter: Control
var _meter_bar: ProgressBar
var _wash: ColorRect
var _fade: ColorRect
var _keys: Label
## Starts "long idle" so the meter doesn't flash up on load.
var _meter_idle := METER_LINGER


func _ready() -> void:
	layer = 5
	# Keeps updating under the pause menu (so the key hint hides there too).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	GameState.toast.connect(show_toast)


func set_focus(target: Interactable) -> void:
	if target and is_instance_valid(target):
		_prompt.text = "[E] " + target.prompt
		_prompt.show()
	else:
		_prompt.hide()


## Updates the ember meter and grey wash (GreyingWalker.ember_changed).
func set_ember(ember: float, depth: float) -> void:
	_meter_bar.value = ember * 100.0
	var active := depth >= Greying.CLEAR_DEPTH or ember < 1.0
	_meter_idle = 0.0 if active else _meter_idle + get_physics_process_delta_time()
	var want := 1.0 if _meter_idle < METER_LINGER else 0.0
	_meter.modulate.a = move_toward(_meter.modulate.a, want, get_physics_process_delta_time() * 3.0)
	_meter.visible = _meter.modulate.a > 0.0
	_wash.color.a = WASH_ALPHA * (1.0 - ember) * (1.0 if depth >= Greying.CLEAR_DEPTH else ember)


## The key hint hides while a modal (dialogue, journal, menu, act card) holds input — the
## dialogue panel would cover it anyway, and its keys don't apply there.
func _process(_delta: float) -> void:
	_keys.visible = not GameState.input_locked


## True while the bottom-left key hint is on screen.
func is_key_hint_shown() -> bool:
	return _keys.visible


## True while the ember meter is on screen.
func is_meter_shown() -> bool:
	return _meter.visible


## Fades the whole screen to fog (`alpha` 1) or back (0); await the result.
func fade_screen(alpha: float, seconds: float) -> Signal:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)
	return tween.finished


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
	var fog := PropFactory.color("silverfog")
	_wash = ColorRect.new()
	_wash.name = "GreyingWash"
	_wash.color = Color(fog, 0.0)
	_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_wash)
	_build_meter(root)
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
	keys.name = "KeyHint"
	keys.text = "[J] Journal   [I] Satchel   [Esc] Menu"
	keys.theme_type_variation = UiTheme.HUD_KEYS
	keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	keys.offset_left = 20
	keys.offset_top = -40
	root.add_child(keys)
	_keys = keys
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_toasts.offset_left = -420
	_toasts.offset_right = -20
	_toasts.offset_top = 20
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(_toasts)
	# Last, so the turn-back fade covers everything.
	_fade = ColorRect.new()
	_fade.name = "GreyingFade"
	_fade.color = Color(fog, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)


## "Ember" and a bar, top-left; shown only in or just out of the Greying.
func _build_meter(root: Control) -> void:
	var box := VBoxContainer.new()
	box.name = "EmberMeter"
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	box.offset_left = 24
	box.offset_top = 20
	box.custom_minimum_size = Vector2(220, 0)
	box.add_theme_constant_override(&"separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _make_label(UiTheme.HUD_METER)
	label.text = "Ember"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(label)
	_meter_bar = ProgressBar.new()
	_meter_bar.show_percentage = false
	_meter_bar.custom_minimum_size = Vector2(220, 12)
	_meter_bar.value = 100.0
	_meter_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_meter_bar)
	box.modulate.a = 0.0
	box.visible = false
	_meter = box
	root.add_child(box)


func _make_label(variation: StringName) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.theme_type_variation = variation
	return label
