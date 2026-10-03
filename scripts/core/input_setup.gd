class_name InputSetup
extends RefCounted
## Registers default input actions in code (keeps project.godot readable) and applies the
## player's rebound keys (GameSettings). Each keyboard action's first key in BINDINGS is its
## rebindable primary; the rest are fixed secondaries (arrow keys, Enter), dropped while
## another action has claimed them as its primary.

const BINDINGS: Dictionary = {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E, KEY_ENTER],
	"camera_left": [KEY_Q],
	"camera_right": [KEY_R],
	"quick_save": [KEY_F5],
	"quick_load": [KEY_F9],
	"journal": [KEY_J],
	"inventory": [KEY_I],
	"pause": [KEY_ESCAPE, KEY_P],
}

## Actions the settings page lets the player rebind, in menu order. "pause" stays on
## Esc/P/Start so the menu can always be reached.
const REBINDABLE: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right", "interact", "camera_left",
	"camera_right", "journal", "inventory", "quick_save", "quick_load",
]

## Keys a rebinding can't take (Esc backs out of every menu).
const RESERVED_KEYS: Array[Key] = [KEY_ESCAPE]

const ACTION_LABELS: Dictionary = {
	"move_forward": "Move forward",
	"move_back": "Move back",
	"move_left": "Move left",
	"move_right": "Move right",
	"interact": "Interact / talk",
	"camera_left": "Turn camera left",
	"camera_right": "Turn camera right",
	"journal": "Journal",
	"inventory": "Satchel",
	"quick_save": "Quicksave",
	"quick_load": "Quickload",
	"pause": "Menu",
}

const PAD_BUTTONS: Dictionary = {
	"interact": JOY_BUTTON_A,
	"journal": JOY_BUTTON_BACK,
	"inventory": JOY_BUTTON_Y,
	"pause": JOY_BUTTON_START,
}

const PAD_AXES: Dictionary = {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"camera_left": [JOY_AXIS_RIGHT_X, -1.0],
	"camera_right": [JOY_AXIS_RIGHT_X, 1.0],
}


static func ensure_actions() -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for keycode: Key in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
		if PAD_BUTTONS.has(action):
			var pb := InputEventJoypadButton.new()
			pb.button_index = PAD_BUTTONS[action]
			InputMap.action_add_event(action, pb)
		if PAD_AXES.has(action):
			var pa := InputEventJoypadMotion.new()
			pa.axis = PAD_AXES[action][0]
			pa.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action, pa)


## The default primary key of an action (KEY_NONE if it has no keyboard binding).
static func default_key(action: String) -> Key:
	var defaults: Array = BINDINGS.get(action, [])
	return defaults[0] as Key if not defaults.is_empty() else KEY_NONE


static func action_label(action: String) -> String:
	return str(ACTION_LABELS.get(action, action.capitalize()))


## "E", "Space", "F5" — physical keycodes are named by their US-layout key.
static func key_label(keycode: Key) -> String:
	return OS.get_keycode_string(keycode) if keycode != KEY_NONE else "—"


## Replaces the keyboard events of every rebindable action: its primary from `primaries`
## (action → physical keycode), then its default secondaries that no action uses as a
## primary. Pad events are left alone.
static func apply_keys(primaries: Dictionary) -> void:
	ensure_actions()
	var claimed := {}
	for action: String in primaries:
		claimed[primaries[action]] = true
	for action: String in REBINDABLE:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		var primary: Key = primaries.get(action, default_key(action))
		var wanted: Array[Key] = [primary]
		for keycode: Key in BINDINGS[action].slice(1):
			if not claimed.has(keycode) and not wanted.has(keycode):
				wanted.append(keycode)
		for keycode in wanted:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycode
			InputMap.action_add_event(action, key_event)


## The keys currently bound to an action, for hints ("E" — the first keyboard key).
static func bound_key(action: String) -> Key:
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				return (ev as InputEventKey).physical_keycode
	return default_key(action)


## "[E]" — a HUD hint for an action's current key.
static func hint(action: String) -> String:
	return "[%s]" % key_label(bound_key(action))
