class_name InputSetup
extends RefCounted
## Registers default input actions in code (keeps project.godot readable) and applies the
## player's rebound keys and pad buttons (GameSettings). Each keyboard action's first key in
## BINDINGS is its rebindable primary; the rest are fixed secondaries (arrow keys, Enter),
## dropped while another action has claimed them as its primary. Pad buttons (Day 112): each
## action in PAD_REBINDABLE has at most one button (PAD_BUTTONS is the default); the sticks
## and Start stay fixed. Prompts name the buttons in the pad's own family (PAD_STYLES).

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
	"lanes": [KEY_L],
	"tab_left": [],
	"tab_right": [],
	"pause": [KEY_ESCAPE, KEY_P],
}

## Actions the settings page lets the player rebind, in menu order. "pause" stays on
## Esc/P/Start so the menu can always be reached.
const REBINDABLE: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right", "interact", "camera_left",
	"camera_right", "journal", "inventory", "lanes", "quick_save", "quick_load",
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
	"lanes": "Lanes (the chart)",
	"tab_left": "Previous journal tab",
	"tab_right": "Next journal tab",
	"quick_save": "Quicksave",
	"quick_load": "Quickload",
	"pause": "Menu",
}

## Default pad buttons. Since Day 112 Lanes has one (X), so the chart is a press away on a pad too.
const PAD_BUTTONS: Dictionary = {
	"interact": JOY_BUTTON_A,
	"journal": JOY_BUTTON_BACK,
	"inventory": JOY_BUTTON_Y,
	"lanes": JOY_BUTTON_X,
	"tab_left": JOY_BUTTON_LEFT_SHOULDER,
	"tab_right": JOY_BUTTON_RIGHT_SHOULDER,
	"pause": JOY_BUTTON_START,
}

## Actions the Controls page lets the player put on another pad button, in menu order. The
## quick save/load have no button until the player gives them one.
const PAD_REBINDABLE: Array[String] = [
	"interact", "journal", "inventory", "lanes", "tab_left", "tab_right", "quick_save", "quick_load",
]

## Pad buttons a rebinding can't take: Start opens the menu, B backs out of every menu
## (`ui_cancel`), and the guide button belongs to the system overlay.
const RESERVED_BUTTONS: Array[JoyButton] = [JOY_BUTTON_START, JOY_BUTTON_B, JOY_BUTTON_GUIDE]

## How the pad's moving parts read on the Controls page (they can't be rebound).
const PAD_AXIS_LABELS: Dictionary = {
	"move_forward": "Left stick",
	"move_back": "Left stick",
	"move_left": "Left stick",
	"move_right": "Left stick",
	"camera_left": "Right stick",
	"camera_right": "Right stick",
}

## Button-prompt families, in the order the Settings page steps through them ("auto" reads the
## connected pad's name: `style_for_name`).
const PROMPT_STYLES: Array = [["auto", "Auto"], ["xbox", "Xbox"], ["playstation", "PlayStation"], ["nintendo", "Nintendo"]]

## Button names per family, by Godot's (SDL's) button index. Godot numbers face buttons by
## position (A = bottom), so a Nintendo pad's bottom button is "B" and a Sony pad's is "Cross".
const PAD_STYLES: Dictionary = {
	"xbox": {
		JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
		JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
		JOY_BUTTON_MISC1: "Share",
	},
	"playstation": {
		JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle",
		JOY_BUTTON_BACK: "Create", JOY_BUTTON_GUIDE: "PS", JOY_BUTTON_START: "Options",
		JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
		JOY_BUTTON_MISC1: "Mute", JOY_BUTTON_TOUCHPAD: "Touchpad",
	},
	"nintendo": {
		JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
		JOY_BUTTON_BACK: "−", JOY_BUTTON_GUIDE: "Home", JOY_BUTTON_START: "+",
		JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
		JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R",
		JOY_BUTTON_MISC1: "Capture",
	},
}

## Names every family shares (the d-pad, the paddles).
const PAD_COMMON_LABELS: Dictionary = {
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
	JOY_BUTTON_PADDLE1: "P1", JOY_BUTTON_PADDLE2: "P2", JOY_BUTTON_PADDLE3: "P3", JOY_BUTTON_PADDLE4: "P4",
	JOY_BUTTON_TOUCHPAD: "Touchpad",
}

## The Xbox names (kept for older callers and tests: `PAD_LABELS[JOY_BUTTON_B]`).
const PAD_LABELS: Dictionary = PAD_STYLES["xbox"]

## The player's prompt family ("auto" or a PAD_STYLES key), set by GameSettings.
static var prompt_style := "auto"
## The name of the pad used last (Input.get_joy_name), for "auto".
static var pad_name := ""

## A stick has to lean this far before it counts as "the pad was used" for prompts.
const PAD_NOTICE_LEAN := 0.5

## True when the last input came from a pad: prompts show pad buttons ("[A]") instead of keys.
static var pad_last := false

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


## Sets how far a stick must lean before the move and camera actions count (keys press at
## full strength, so only the pad axes feel it).
static func apply_deadzone(deadzone: float) -> void:
	ensure_actions()
	for action: String in PAD_AXES:
		InputMap.action_set_deadzone(action, deadzone)


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


## The default pad button of an action (JOY_BUTTON_INVALID if it has none).
static func default_button(action: String) -> JoyButton:
	return PAD_BUTTONS.get(action, JOY_BUTTON_INVALID) as JoyButton


## Replaces the pad button of every pad-rebindable action with the one in `buttons`
## (action → JoyButton; JOY_BUTTON_INVALID leaves it with none). Keys and axes are left alone.
static func apply_buttons(buttons: Dictionary) -> void:
	ensure_actions()
	for action: String in PAD_REBINDABLE:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton:
				InputMap.action_erase_event(action, ev)
		var button: JoyButton = buttons.get(action, default_button(action))
		if button != JOY_BUTTON_INVALID:
			var pad_event := InputEventJoypadButton.new()
			pad_event.button_index = button
			InputMap.action_add_event(action, pad_event)


## The pad button currently bound to an action (JOY_BUTTON_INVALID if none).
static func bound_button(action: String) -> JoyButton:
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton:
				return (ev as InputEventJoypadButton).button_index
		return JOY_BUTTON_INVALID
	return default_button(action)


## Which prompt family a pad's reported name belongs to.
static func style_for_name(joy_name: String) -> String:
	var lower := joy_name.to_lower()
	for word in ["playstation", "dualshock", "dualsense", "ps3", "ps4", "ps5", "sony"]:
		if lower.contains(word):
			return "playstation"
	for word in ["nintendo", "switch", "pro controller", "joy-con", "joycon"]:
		if lower.contains(word):
			return "nintendo"
	return "xbox"


## The family prompts use now: the player's choice, or (on Auto) the pad used last.
static func current_style() -> String:
	if PAD_STYLES.has(prompt_style):
		return prompt_style
	return style_for_name(pad_name)


## "A", "Cross", "D-pad up" — a pad button's name in the current family ("—" for none).
static func button_label(button: JoyButton, style: String = "") -> String:
	if button == JOY_BUTTON_INVALID:
		return "—"
	var names: Dictionary = PAD_STYLES.get(style if not style.is_empty() else current_style(), PAD_LABELS)
	if names.has(button):
		return str(names[button])
	return str(PAD_COMMON_LABELS.get(button, "Button %d" % int(button)))


## The keys currently bound to an action, for hints ("E" — the first keyboard key).
static func bound_key(action: String) -> Key:
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				return (ev as InputEventKey).physical_keycode
	return default_key(action)


## "[E]" — a HUD hint for an action's current key, or its pad button ("[A]") when the pad
## was used last and the action has one.
static func hint(action: String) -> String:
	if pad_last and has_pad_button(action):
		return "[%s]" % button_label(bound_button(action))
	return "[%s]" % key_label(bound_key(action))


## Whether an action can be pressed on the pad right now.
static func has_pad_button(action: String) -> bool:
	return bound_button(action) != JOY_BUTTON_INVALID


## "[Esc]" / "[B]" — the hint for backing out of a modal (`ui_cancel`, whose built-in key
## binding has no physical keycode for `hint` to read).
static func back_hint() -> String:
	return "[%s]" % button_label(JOY_BUTTON_B) if pad_last else "[Esc]"


## Notes which device `event` came from (a key or mouse click → keyboard; a pad button or a
## firm stick lean → pad). True when that changed — or, on Auto prompts, when a pad of another
## family was picked up — so prompts should be re-labelled.
static func note_device(event: InputEvent) -> bool:
	var pad := pad_last
	var style := current_style()
	if event is InputEventKey or event is InputEventMouseButton:
		pad = false
	elif event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) >= PAD_NOTICE_LEAN:
		pad = true
	if pad and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		pad_name = Input.get_joy_name(event.device)
	if pad == pad_last and style == current_style():
		return false
	pad_last = pad
	return true
