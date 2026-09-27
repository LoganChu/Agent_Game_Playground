extends TestCase
## The shared UI Theme: palette colours, type variations and the text-scale hook.


func test_variations_use_palette_colours() -> void:
	var theme := UiTheme.get_theme()
	assert_eq(theme.get_color(&"font_color", &"Label"), PropFactory.color("bone"), "body text is bone")
	assert_eq(theme.get_color(&"font_color", UiTheme.SPEAKER), PropFactory.color("ember"), "speaker is ember")
	assert_eq(theme.get_type_variation_base(UiTheme.HUD_TOAST), &"Label", "HUD toast is a Label variation")
	assert_true(theme.get_constant(&"outline_size", UiTheme.HUD_TITLE) > 0, "HUD text is outlined")
	assert_true(theme.get_stylebox(&"panel", &"PanelContainer") is StyleBoxFlat, "panels share the ink/ember box")


func test_text_scale_updates_every_font_size() -> void:
	var theme := UiTheme.get_theme()
	UiTheme.set_text_scale(1.5)
	assert_eq(theme.get_font_size(&"font_size", UiTheme.HEADING), 42, "heading 28 → 42")
	assert_eq(theme.get_font_size(&"normal_font_size", &"RichTextLabel"), 30, "body 20 → 30")
	assert_eq(theme.default_font_size, 30, "default font size scales too")
	UiTheme.set_text_scale(9.0)
	assert_eq(UiTheme.text_scale(), 2.0, "scale is clamped")
	UiTheme.set_text_scale(1.0)
	assert_eq(theme.get_font_size(&"font_size", UiTheme.HUD_TITLE), 40, "back to base size")
