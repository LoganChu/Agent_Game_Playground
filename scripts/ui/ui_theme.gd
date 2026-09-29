class_name UiTheme
extends RefCounted
## The game's one UI Theme (palette colours, font sizes, panel style), built in code and
## shared by every UI root so a text-size setting applies everywhere at once.
## Widgets pick a look with `theme_type_variation` (the constants below) instead of
## per-widget overrides.

const SPEAKER := &"SpeakerLabel"  ## dialogue speaker name
const HEADING := &"HeadingLabel"  ## journal entry title
const SUBHEADING := &"SubheadingLabel"  ## journal entry kind / giver line
const HINT := &"HintLabel"  ## key hints, empty-list notes
const HUD_PROMPT := &"HudPromptLabel"  ## "[E] Talk to Mara"
const HUD_TITLE := &"HudTitleLabel"  ## region name on arrival
const HUD_KEYS := &"HudKeysLabel"  ## "[J] Journal [I] Satchel"
const HUD_TOAST := &"HudToastLabel"  ## "Got: Harbormaster's Token"
const HUD_METER := &"HudMeterLabel"  ## "Ember" over the Greying meter

## Base font sizes at text scale 1.0: [theme type, theme item, size].
const FONT_SIZES: Array = [
	[&"Label", &"font_size", 20],
	[&"Button", &"font_size", 20],
	[&"ItemList", &"font_size", 19],
	[&"RichTextLabel", &"normal_font_size", 20],
	[&"RichTextLabel", &"italics_font_size", 20],
	[&"RichTextLabel", &"bold_font_size", 20],
	[SPEAKER, &"font_size", 22],
	[HEADING, &"font_size", 28],
	[SUBHEADING, &"font_size", 16],
	[HINT, &"font_size", 17],
	[HUD_PROMPT, &"font_size", 22],
	[HUD_TITLE, &"font_size", 40],
	[HUD_KEYS, &"font_size", 15],
	[HUD_TOAST, &"font_size", 18],
	[HUD_METER, &"font_size", 16],
]
const DEFAULT_FONT_SIZE := 20

static var _theme: Theme = null
static var _text_scale := 1.0


## The shared theme (built on first use).
static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
		_apply_font_sizes(_theme, _text_scale)
	return _theme


static func text_scale() -> float:
	return _text_scale


## Scales every font size (e.g. 1.25 for large text). Updates the shared theme in place,
## so every open UI picks it up immediately.
static func set_text_scale(value: float) -> void:
	_text_scale = clampf(value, 0.75, 2.0)
	_apply_font_sizes(get_theme(), _text_scale)


static func _apply_font_sizes(theme: Theme, value: float) -> void:
	theme.default_font_size = roundi(DEFAULT_FONT_SIZE * value)
	for entry: Array in FONT_SIZES:
		theme.set_font_size(entry[1], entry[0], roundi(int(entry[2]) * value))


static func _build() -> Theme:
	var theme := Theme.new()
	var bone := PropFactory.color("bone")
	var ink := PropFactory.color("ink")
	var ember := PropFactory.color("ember")
	var kindle := PropFactory.color("kindle")
	var silverfog := PropFactory.color("silverfog")

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(ink, 0.94)
	panel.border_color = ember
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(18)
	theme.set_stylebox(&"panel", &"PanelContainer", panel)

	theme.set_color(&"font_color", &"Label", bone)
	theme.set_color(&"default_color", &"RichTextLabel", bone)
	theme.set_constant(&"line_separation", &"RichTextLabel", 6)
	theme.set_color(&"font_color", &"Button", bone)
	theme.set_color(&"font_pressed_color", &"Button", ember)
	theme.set_color(&"font_color", &"ItemList", bone)
	theme.set_color(&"font_selected_color", &"ItemList", kindle)
	theme.set_constant(&"separation", &"VBoxContainer", 8)

	_label_variation(theme, SPEAKER, ember)
	_label_variation(theme, HEADING, ember)
	_label_variation(theme, SUBHEADING, silverfog)
	_label_variation(theme, HINT, silverfog)
	# HUD text floats over the world, so it gets an ink outline to stay readable in fog.
	_label_variation(theme, HUD_PROMPT, bone, 8)
	_label_variation(theme, HUD_TITLE, kindle, 8)
	_label_variation(theme, HUD_KEYS, bone, 5)
	_label_variation(theme, HUD_TOAST, kindle, 6)
	_label_variation(theme, HUD_METER, kindle, 5)

	# The ember meter (HUD, while in the Greying).
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(ink, 0.8)
	bar_bg.border_color = Color(silverfog, 0.6)
	bar_bg.set_border_width_all(1)
	bar_bg.set_corner_radius_all(4)
	theme.set_stylebox(&"background", &"ProgressBar", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = ember
	bar_fill.set_corner_radius_all(4)
	theme.set_stylebox(&"fill", &"ProgressBar", bar_fill)
	return theme


static func _label_variation(theme: Theme, type: StringName, color: Color, outline: int = 0) -> void:
	theme.set_type_variation(type, &"Label")
	theme.set_color(&"font_color", type, color)
	if outline > 0:
		theme.set_color(&"font_outline_color", type, PropFactory.color("ink"))
		theme.set_constant(&"outline_size", type, outline)
