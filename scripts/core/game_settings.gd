class_name GameSettings
extends RefCounted
## Player settings: audio bus volumes, text size and dialogue text speed, camera
## sensitivity/invert, stick deadzone, window mode and vsync, and keyboard rebinding. Persisted to `user://settings.cfg` (ConfigFile), never in save games, so they
## carry across playthroughs. `current()` is the live instance the game reads; tests make
## their own with a scratch `path`.
##
## Every setter clamps, applies at once (bus volume, UiTheme text scale, InputMap, the window) and emits
## `changed`; `save()` writes the file (the settings page saves as it goes).

signal changed

const PATH := "user://settings.cfg"

## Audio buses, created in code if the project has no bus layout. "Master" always exists.
const BUSES: Array[String] = ["Master", "Music", "Ambience", "Effects", "Voice"]
## Player-facing bus names, in BUSES order.
const BUS_LABELS: Array[String] = ["Master", "Music", "Ambience", "Effects", "Voices"]
const DEFAULT_VOLUME := 0.8

## Text size presets offered by the menu: [scale, label].
const TEXT_SIZES: Array = [[0.85, "Small"], [1.0, "Normal"], [1.25, "Large"], [1.5, "Larger"]]
const SENSITIVITY_MIN := 0.25
const SENSITIVITY_MAX := 2.5
## Dialogue text speed presets, in the order the menu button steps through them:
## [characters per second (0 = the whole line at once), label].
const TEXT_SPEEDS: Array = [[25.0, "Slow"], [50.0, "Normal"], [100.0, "Fast"], [0.0, "Instant"]]
const DEFAULT_TEXT_SPEED := 50.0
const TEXT_SPEED_MAX := 400.0
## Stick deadzone (move and camera axes): how far a stick must lean before it counts.
const DEADZONE_MIN := 0.05
const DEADZONE_MAX := 0.5
const DEFAULT_DEADZONE := 0.2
## Window modes offered by the menu: [setting value, label].
const WINDOW_MODES: Array = [["windowed", "Windowed"], ["fullscreen", "Fullscreen"]]

static var _current: GameSettings = null

var path := PATH
## Linear 0..1 per bus name.
var volumes: Dictionary = {}
var text_scale := 1.0
## Dialogue characters revealed per second; 0 shows each line whole.
var text_speed := DEFAULT_TEXT_SPEED
## Multiplies mouse and stick camera turning.
var camera_sensitivity := 1.0
var invert_x := false
var invert_y := false
var stick_deadzone := DEFAULT_DEADZONE
## "windowed" or "fullscreen" (WINDOW_MODES).
var window_mode := "windowed"
var vsync := true
## Rebound primary keys: action → physical keycode. Only actions the player changed.
var keys: Dictionary = {}


func _init() -> void:
	reset_values()


## The live settings, loaded from disk (and applied) on first use.
static func current() -> GameSettings:
	if _current == null:
		_current = GameSettings.new()
		_current.load_file()
		_current.apply_all()
	return _current


## Swaps in another instance as the live settings (tests); null reloads from disk next use.
static func set_current(settings: GameSettings) -> void:
	_current = settings


func reset_values() -> void:
	volumes.clear()
	for bus in BUSES:
		volumes[bus] = DEFAULT_VOLUME
	text_scale = 1.0
	text_speed = DEFAULT_TEXT_SPEED
	camera_sensitivity = 1.0
	invert_x = false
	invert_y = false
	stick_deadzone = DEFAULT_DEADZONE
	window_mode = "windowed"
	vsync = true
	keys.clear()


## Back to defaults, applied and saved.
func reset() -> void:
	reset_values()
	apply_all()
	save()
	changed.emit()


func volume(bus: String) -> float:
	return float(volumes.get(bus, DEFAULT_VOLUME))


func set_volume(bus: String, value: float) -> void:
	if not BUSES.has(bus):
		push_warning("Unknown audio bus '%s'" % bus)
		return
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volume(bus)
	changed.emit()


func set_text_scale(value: float) -> void:
	text_scale = clampf(value, 0.75, 2.0)
	UiTheme.set_text_scale(text_scale)
	changed.emit()


## The label of the text size preset closest to the current scale.
func text_size_label() -> String:
	return _nearest_label(TEXT_SIZES, text_scale)


## Steps through TEXT_SIZES (wrapping), for a one-button menu entry.
func cycle_text_size() -> void:
	var index := 0
	for i in TEXT_SIZES.size():
		if str(TEXT_SIZES[i][1]) == text_size_label():
			index = i
	set_text_scale(float(TEXT_SIZES[(index + 1) % TEXT_SIZES.size()][0]))


func set_text_speed(value: float) -> void:
	text_speed = clampf(value, 0.0, TEXT_SPEED_MAX)
	changed.emit()


## The label of the text speed preset closest to the current speed ("Instant" only at 0).
func text_speed_label() -> String:
	if text_speed <= 0.0:
		return "Instant"
	return _nearest_label(TEXT_SPEEDS.filter(func(preset: Array) -> bool: return float(preset[0]) > 0.0), text_speed)


## Steps through TEXT_SPEEDS (wrapping): Slow → Normal → Fast → Instant → Slow.
func cycle_text_speed() -> void:
	var index := 0
	for i in TEXT_SPEEDS.size():
		if str(TEXT_SPEEDS[i][1]) == text_speed_label():
			index = i
	set_text_speed(float(TEXT_SPEEDS[(index + 1) % TEXT_SPEEDS.size()][0]))


static func _nearest_label(presets: Array, value: float) -> String:
	var best: Array = presets[0]
	for preset: Array in presets:
		if absf(float(preset[0]) - value) < absf(float(best[0]) - value):
			best = preset
	return str(best[1])


func set_camera_sensitivity(value: float) -> void:
	camera_sensitivity = clampf(value, SENSITIVITY_MIN, SENSITIVITY_MAX)
	changed.emit()


func set_invert_x(value: bool) -> void:
	invert_x = value
	changed.emit()


func set_invert_y(value: bool) -> void:
	invert_y = value
	changed.emit()


func set_stick_deadzone(value: float) -> void:
	stick_deadzone = clampf(value, DEADZONE_MIN, DEADZONE_MAX)
	InputSetup.apply_deadzone(stick_deadzone)
	changed.emit()


func set_window_mode(value: String) -> void:
	if not _window_modes().has(value):
		push_warning("Unknown window mode '%s'" % value)
		return
	window_mode = value
	_apply_display()
	changed.emit()


func window_mode_label() -> String:
	for mode: Array in WINDOW_MODES:
		if str(mode[0]) == window_mode:
			return str(mode[1])
	return window_mode


## Steps through WINDOW_MODES (wrapping), for a one-button menu entry.
func cycle_window_mode() -> void:
	var modes := _window_modes()
	set_window_mode(modes[(modes.find(window_mode) + 1) % modes.size()])


func set_vsync(value: bool) -> void:
	vsync = value
	_apply_display()
	changed.emit()


static func _window_modes() -> Array[String]:
	var out: Array[String] = []
	for mode: Array in WINDOW_MODES:
		out.append(str(mode[0]))
	return out


## Camera turn (radians) for a mouse drag of `relative` pixels at base `per_pixel`.
func mouse_turn(relative: Vector2, per_pixel: float) -> Vector2:
	var turn := relative * per_pixel * camera_sensitivity
	return Vector2(-turn.x if invert_x else turn.x, -turn.y if invert_y else turn.y)


## Stick/keyboard yaw multiplier (sign follows invert_x).
func yaw_factor() -> float:
	return -camera_sensitivity if invert_x else camera_sensitivity


## The primary key of a rebindable action (rebound or default).
func key_for(action: String) -> Key:
	if keys.has(action):
		return keys[action] as Key
	return InputSetup.default_key(action)


## Binds `keycode` as the primary key of `action`. If another action had it as its primary,
## the two swap. Returns "" on success, else why not (reserved key, not rebindable).
func rebind(action: String, keycode: Key) -> String:
	if not InputSetup.REBINDABLE.has(action):
		return "%s can't be rebound." % InputSetup.action_label(action)
	if InputSetup.RESERVED_KEYS.has(keycode):
		return "%s is reserved." % InputSetup.key_label(keycode)
	for fixed: String in InputSetup.BINDINGS:
		if not InputSetup.REBINDABLE.has(fixed) and (InputSetup.BINDINGS[fixed] as Array).has(keycode):
			return "%s is the %s key." % [InputSetup.key_label(keycode), InputSetup.action_label(fixed)]
	var old := key_for(action)
	for other: String in InputSetup.REBINDABLE:
		if other != action and key_for(other) == keycode:
			_set_key(other, old)
	_set_key(action, keycode)
	InputSetup.apply_keys(primary_keys())
	changed.emit()
	return ""


func _set_key(action: String, keycode: Key) -> void:
	if keycode == InputSetup.default_key(action):
		keys.erase(action)
	else:
		keys[action] = keycode


## Every rebindable action's primary key.
func primary_keys() -> Dictionary:
	var out := {}
	for action: String in InputSetup.REBINDABLE:
		out[action] = key_for(action)
	return out


func apply_all() -> void:
	for bus in BUSES:
		_apply_volume(bus)
	UiTheme.set_text_scale(text_scale)
	InputSetup.apply_keys(primary_keys())
	InputSetup.apply_deadzone(stick_deadzone)
	_apply_display()


## Window mode and vsync. Nothing to do without a window (headless runs, the test runner).
func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var current := DisplayServer.window_get_mode()
	var fullscreen := current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if window_mode == "fullscreen" and not fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif window_mode == "windowed" and fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


func _apply_volume(bus: String) -> void:
	var index := ensure_bus(bus)
	var value := volume(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(index, value <= 0.0)


## The bus's index, creating it (routed to Master) if missing.
static func ensure_bus(bus: String) -> int:
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")
	return index


func save() -> bool:
	var cfg := ConfigFile.new()
	for bus in BUSES:
		cfg.set_value("audio", bus, volume(bus))
	cfg.set_value("display", "text_scale", text_scale)
	cfg.set_value("display", "text_speed", text_speed)
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("camera", "sensitivity", camera_sensitivity)
	cfg.set_value("camera", "invert_x", invert_x)
	cfg.set_value("camera", "invert_y", invert_y)
	cfg.set_value("pad", "stick_deadzone", stick_deadzone)
	for action: String in keys:
		cfg.set_value("keys", action, OS.get_keycode_string(keys[action] as Key))
	var err := cfg.save(path)
	if err != OK:
		push_warning("Couldn't save settings to %s (%s)" % [path, error_string(err)])
	return err == OK


## Reads the file over the defaults; a missing file is fine (defaults). Unknown or bad
## entries are ignored, so an old or hand-edited file never breaks the game.
func load_file() -> bool:
	reset_values()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	for bus in BUSES:
		volumes[bus] = clampf(float(cfg.get_value("audio", bus, DEFAULT_VOLUME)), 0.0, 1.0)
	text_scale = clampf(float(cfg.get_value("display", "text_scale", 1.0)), 0.75, 2.0)
	text_speed = clampf(float(cfg.get_value("display", "text_speed", DEFAULT_TEXT_SPEED)), 0.0, TEXT_SPEED_MAX)
	var mode := str(cfg.get_value("display", "window_mode", "windowed"))
	window_mode = mode if _window_modes().has(mode) else "windowed"
	vsync = bool(cfg.get_value("display", "vsync", true))
	camera_sensitivity = clampf(float(cfg.get_value("camera", "sensitivity", 1.0)), SENSITIVITY_MIN, SENSITIVITY_MAX)
	invert_x = bool(cfg.get_value("camera", "invert_x", false))
	invert_y = bool(cfg.get_value("camera", "invert_y", false))
	stick_deadzone = clampf(float(cfg.get_value("pad", "stick_deadzone", DEFAULT_DEADZONE)), DEADZONE_MIN, DEADZONE_MAX)
	if cfg.has_section("keys"):
		for action in cfg.get_section_keys("keys"):
			var keycode := OS.find_keycode_from_string(str(cfg.get_value("keys", action, "")))
			if InputSetup.REBINDABLE.has(action) and keycode != KEY_NONE and not InputSetup.RESERVED_KEYS.has(keycode):
				_set_key(action, keycode)
	_drop_duplicate_keys()
	return true


## A hand-edited file could give two actions the same key: the later ones fall back to
## their defaults (and if that clashes too, the rebinding is dropped altogether).
func _drop_duplicate_keys() -> void:
	var seen := {}
	for action: String in InputSetup.REBINDABLE:
		var key := key_for(action)
		if seen.has(key):
			keys.erase(action)
		seen[key_for(action)] = true
	seen.clear()
	for action: String in InputSetup.REBINDABLE:
		var key := key_for(action)
		if seen.has(key):
			keys.clear()
			return
		seen[key] = true
