extends Node
## Autoload "Controls": the input map, built in code so it is easy to read (docs/CONTROLS.md).
## Godot names joypad buttons by Xbox position, so on a PS4 pad A = Cross, B = Circle, X = Square, Y = Triangle,
## L1/R1 = shoulders, L2/R2 = triggers (axes), Start = Options, Back = Share/Touchpad (SDL mapping).

const DEAD := 0.45
## v0.8 Android fix (docs/AI_HANDOFF.md "Android L2 bug"). Godot's Android backend reports a digital L2/R2
## (KeyEvent.KEYCODE_BUTTON_L2/R2) as joypad button 15/16 and sends the analog trigger as a raw axis, and the
## SDL mapping database can remap a cheap pad's triggers onto Back/Start. So: L2/R2 also listen to 15/16, no other
## action may use a trigger axis or 15/16 (tests/run_tests.gd "input map"), and joypad Start/Select are deferred a
## few frames and dropped if a trigger moved at the same moment (game.gd _menu_guard_tick).
const ANDROID_L2 := 15   # JOY_BUTTON_MISC1 on desktop SDL
const ANDROID_R2 := 16   # JOY_BUTTON_PADDLE1 on desktop SDL
const TRIGGER_AXES := [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
const GUARD_FRAMES := 6  # ~100 ms at 60 fps: a Start/Select this close to trigger activity is a collision
var last_trigger_frame := -100000
# action: [keys], [joy buttons], [joy axis, sign]
## v0.8 PC keyboard (user t86u): arrows = D-pad, Z = A, X = B, A = X, S = Y, Q = L1, W = R1, 1 = L2, 2 = R2
## (top row; keypad 1/2 too). Space also jumps. No key is shared between actions (tests/run_tests.gd "input map").
const MAP := {
	"left": [[KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [JOY_AXIS_LEFT_X, -1.0]],
	"right": [[KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [JOY_AXIS_LEFT_X, 1.0]],
	"up": [[KEY_UP], [JOY_BUTTON_DPAD_UP], [JOY_AXIS_LEFT_Y, -1.0]],
	"down": [[KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [JOY_AXIS_LEFT_Y, 1.0]],
	"btn_a": [[KEY_Z, KEY_SPACE], [JOY_BUTTON_A], []],
	"btn_b": [[KEY_X], [JOY_BUTTON_B], []],
	"btn_x": [[KEY_A], [JOY_BUTTON_X], []],
	"btn_y": [[KEY_S], [JOY_BUTTON_Y], []],
	"l1": [[KEY_Q], [JOY_BUTTON_LEFT_SHOULDER], []],
	"r1": [[KEY_W], [JOY_BUTTON_RIGHT_SHOULDER], []],
	"l2": [[KEY_1, KEY_KP_1], [ANDROID_L2], [JOY_AXIS_TRIGGER_LEFT, 1.0]],
	"r2": [[KEY_2, KEY_KP_2], [ANDROID_R2], [JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	"start": [[KEY_ENTER, KEY_F1], [JOY_BUTTON_START], []],
	"select": [[KEY_TAB, KEY_G], [JOY_BUTTON_BACK], []],
	"debug": [[KEY_F2], [], []],
	"size_up": [[KEY_PAGEUP, KEY_EQUAL], [], [JOY_AXIS_RIGHT_Y, -1.0]],
	"size_down": [[KEY_PAGEDOWN, KEY_MINUS], [], [JOY_AXIS_RIGHT_Y, 1.0]],
}
## keys the game reads directly (game.gd / menu.gd): never bind them to an action
const RAW_KEYS := [KEY_ESCAPE, KEY_F11]


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


## Remember when a trigger last moved, so a Start/Select press arriving with it can be dropped.
func _input(event: InputEvent) -> void:
	if is_trigger_event(event):
		last_trigger_frame = Engine.get_physics_frames()


static func is_trigger_event(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		return event.axis in TRIGGER_AXES and absf(event.axis_value) > 0.2
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index in [ANDROID_L2, ANDROID_R2]
	return false


func trigger_near(frame: int) -> bool:
	return absi(last_trigger_frame - frame) <= GUARD_FRAMES or Input.is_action_pressed("l2") or Input.is_action_pressed("r2")


## every joypad binding as "btn:N" / "axis:N:+/-" -> [actions] (used by the collision test)
static func joy_bindings() -> Dictionary:
	var out := {}
	for action in MAP:
		var m: Array = MAP[action]
		for b in m[1]:
			out["btn:%d" % b] = out.get("btn:%d" % b, []) + [action]
		if m[2].size() == 2:
			var key := "axis:%d:%s" % [m[2][0], "+" if m[2][1] > 0.0 else "-"]
			out[key] = out.get(key, []) + [action]
	return out


## every keyboard binding: physical keycode -> [actions] (used by the collision test)
static func key_bindings() -> Dictionary:
	var out := {}
	for action in MAP:
		for kc in MAP[action][0]:
			out[kc] = out.get(kc, []) + [action]
	return out


## keyboard label of an action for the overlay ("Z", "1")
static func key_label(action: String) -> String:
	var ks: Array = MAP[action][0]
	return OS.get_keycode_string(ks[0]) if not ks.is_empty() else ""
