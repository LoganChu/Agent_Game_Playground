class_name ActEndCard
extends CanvasLayer
## Full-screen end-of-act card: title, the player's choices as recap lines, a coda, and a
## "Keep exploring" button, or "Return to title" (asks for a second press: unsaved progress
## is lost). Fades in over the world; modal (locks input) while open. A recap taller than about half
## the screen (Act II's) scrolls: mouse wheel, or up/down on keys and pad. While there is more
## below, a faint "more below" cue sits under the box (Day 80) and goes once the end is reached.

signal closed
## "Return to title" was confirmed; main resets the world and shows the title screen.
signal title_requested

const TITLE_TEXT := "Return to title"
const TITLE_CONFIRM_TEXT := "Return to title? Unsaved progress is lost. Press again."
const MORE_TEXT := "·  more below  ·"

var _root: Control
var _title: Label
var _subtitle: Label
var _recap: RichTextLabel
var _recap_scroll: ScrollContainer
var _more: Label
var _coda: Label
var _button: Button
var _title_button: Button


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
	_title_button.text = TITLE_TEXT
	_root.modulate.a = 0.0
	_root.show()
	_recap_scroll.scroll_vertical = 0
	_fit_recap.call_deferred()
	create_tween().tween_property(_root, "modulate:a", 1.0, 1.5)
	_button.call_deferred("grab_focus")


func close() -> void:
	if not is_open():
		return
	_root.hide()
	(func() -> void: GameState.input_locked = false).call_deferred()
	closed.emit()


## First press arms, second press closes the card and asks for the title screen.
func return_to_title() -> void:
	if _title_button.text != TITLE_CONFIRM_TEXT:
		_title_button.text = TITLE_CONFIRM_TEXT
		return
	close()
	title_requested.emit()


## Whether the recap is taller than its box (and scrolls).
func recap_scrolls() -> bool:
	return _recap.get_content_height() > _recap_scroll.custom_minimum_size.y + 1.0


## The recap box: as tall as the lines, up to a bit over half the screen.
func _fit_recap() -> void:
	var screen := _root.get_viewport_rect().size.y if _root.is_inside_tree() else 720.0
	var limit := maxf(160.0, screen * 0.55)
	_recap_scroll.custom_minimum_size.y = minf(float(_recap.get_content_height()), limit)
	_update_more()


## Whether the "more below" cue is showing (for tests / smoke checks).
func more_cue_visible() -> bool:
	return _more.modulate.a > 0.5


## The cue shows while the recap scrolls and its end isn't in view. It keeps its space either way
## (alpha only) so the card doesn't jump when the end is reached.
func _update_more(_value: float = 0.0) -> void:
	var bar := _recap_scroll.get_v_scroll_bar()
	var hidden_below := float(_recap.get_content_height()) - _recap_scroll.custom_minimum_size.y \
			- float(_recap_scroll.scroll_vertical)
	var show := recap_scrolls() and hidden_below > 4.0
	if bar != null and bar.max_value > 0.0:
		show = recap_scrolls() and bar.value + bar.page < bar.max_value - 4.0
	_more.modulate.a = 1.0 if show else 0.0


func _input(event: InputEvent) -> void:
	if not is_open() or not recap_scrolls():
		return
	var step := 0
	if event.is_action_pressed("ui_down", true):
		step = 1
	elif event.is_action_pressed("ui_up", true):
		step = -1
	if step != 0:
		get_viewport().set_input_as_handled()
		_recap_scroll.scroll_vertical += step * 40
		_update_more()


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
	_recap.custom_minimum_size.x = 760
	_recap_scroll = ScrollContainer.new()
	_recap_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_recap_scroll.add_child(_recap)
	box.add_child(_recap_scroll)
	_recap_scroll.get_v_scroll_bar().value_changed.connect(_update_more)
	_more = Label.new()
	_more.text = MORE_TEXT
	_more.theme_type_variation = UiTheme.HINT
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_more.modulate.a = 0.0
	box.add_child(_more)
	_coda = Label.new()
	_coda.theme_type_variation = UiTheme.HINT
	_coda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_coda)
	_button = Button.new()
	_button.text = "Keep exploring"
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(close)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 16)
	box.add_child(buttons)
	buttons.add_child(_button)
	_title_button = Button.new()
	_title_button.text = TITLE_TEXT
	_title_button.pressed.connect(return_to_title)
	buttons.add_child(_title_button)
