extends Node
## Autoload "Controls": the input map, built in code so it is easy to read (docs/CONTROLS.md).
## Godot names joypad buttons by Xbox position, so on a PS4 pad A = Cross, B = Circle, X = Square, Y = Triangle,
## L1/R1 = shoulders, L2/R2 = triggers (axes), Start = Options, Back = Share/Touchpad (SDL mapping).

const DEAD := 0.45
# action: [keys], [joy buttons], [joy axis, sign]
const MAP := {
	"left": [[KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], [JOY_AXIS_LEFT_X, -1.0]],
	"right": [[KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], [JOY_AXIS_LEFT_X, 1.0]],
	"up": [[KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP], [JOY_AXIS_LEFT_Y, -1.0]],
	"down": [[KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN], [JOY_AXIS_LEFT_Y, 1.0]],
	"btn_a": [[KEY_SHIFT, KEY_SPACE], [JOY_BUTTON_A], []],
	"btn_b": [[KEY_L], [JOY_BUTTON_B], []],
	"btn_x": [[KEY_J], [JOY_BUTTON_X], []],
	"btn_y": [[KEY_K], [JOY_BUTTON_Y], []],
	"l1": [[KEY_U], [JOY_BUTTON_LEFT_SHOULDER], []],
	"r1": [[KEY_I], [JOY_BUTTON_RIGHT_SHOULDER], []],
	"l2": [[KEY_O], [], [JOY_AXIS_TRIGGER_LEFT, 1.0]],
	"r2": [[KEY_P], [], [JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"start": [[KEY_ENTER, KEY_F1], [JOY_BUTTON_START], []],
	"select": [[KEY_TAB, KEY_G], [JOY_BUTTON_BACK], []],
	"debug": [[KEY_F2], [], []],
	"size_up": [[KEY_PAGEUP, KEY_EQUAL], [], [JOY_AXIS_RIGHT_Y, -1.0]],
	"size_down": [[KEY_PAGEDOWN, KEY_MINUS], [], [JOY_AXIS_RIGHT_Y, 1.0]],
}


func _ready() -> void:
	for action in MAP:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEAD)
		var m: Array = MAP[action]
		for k in m[0]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
		for b in m[1]:
			var j := InputEventJoypadButton.new()
			j.button_index = b
			j.device = -1
			InputMap.action_add_event(action, j)
		if m[2].size() == 2:
			var ax := InputEventJoypadMotion.new()
			ax.axis = m[2][0]
			ax.axis_value = m[2][1]
			ax.device = -1
			InputMap.action_add_event(action, ax)
