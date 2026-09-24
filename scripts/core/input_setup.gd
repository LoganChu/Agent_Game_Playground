class_name InputSetup
extends RefCounted
## Registers default input actions in code (keeps project.godot readable and gives one place
## to hook up rebinding later).

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
}

const PAD_BUTTONS: Dictionary = {
	"interact": JOY_BUTTON_A,
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
