extends CanvasLayer
## Android on-screen pad. Shown unless a gamepad is connected, then it fades out.
## Grayscale. Xbox diamond (Y top, B right, A bottom, X left), not Xbox colors.
## The round L3 button in the middle of the d-pad drinks a mana potion (the "mana" action: E / left-stick click).
## The phone's volume buttons pause and open the controls list. There is no Start button.

## Positions copied from the 2128x912 mockup, then scaled to the live viewport.
const MOCK_W := 2128.0
const MOCK_H := 912.0
const LAYOUT := [
	["l2", 86.0, 172.0, 264.0, 98.0, false],
	["l1", 86.0, 292.0, 264.0, 100.0, false],
	["left", 86.0, 562.0, 122.0, 116.0, false],
	["up", 210.0, 442.0, 122.0, 116.0, false],
	["down", 210.0, 680.0, 122.0, 116.0, false],
	["right", 334.0, 562.0, 122.0, 116.0, false],
	["mana", 210.0, 562.0, 122.0, 116.0, true],       # L3: the empty middle of the d-pad drinks a mana potion
	["r2", 1774.0, 172.0, 264.0, 98.0, false],
	["r1", 1784.0, 292.0, 254.0, 100.0, false],
	["btn_x", 1702.0, 570.0, 100.0, 100.0, true],
	["btn_y", 1810.0, 462.0, 100.0, 100.0, true],
	["btn_a", 1812.0, 678.0, 100.0, 100.0, true],
	["btn_b", 1920.0, 570.0, 100.0, 100.0, true],
]

var _root: Control
var _buttons: Array = []
var _fingers := {}
var _down := {}
var _pad := false
var _alpha := 1.0
var _vol_ms := 0
var _font: Font
var _box: StyleBoxFlat
var _box_down: StyleBoxFlat
var _laid := Vector2.ZERO


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() != "Android":
		set_process(false)
		set_process_input(false)
		return
	_font = ThemeDB.fallback_font
	_box = _style(Color(0.16, 0.16, 0.18, 0.82), Color(0.82, 0.82, 0.86, 0.95), 22)
	_box_down = _style(Color(0.55, 0.55, 0.58, 0.92), Color(1, 1, 1, 1), 22)
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	Input.joy_connection_changed.connect(func(_d, _c): _scan_pads())
	_scan_pads()
	_layout()


func _style(fill: Color, edge: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(4)
	s.set_corner_radius_all(radius)
	return s


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout()


func _layout() -> void:
	if _root == null:
		return
	var vs := get_viewport().get_visible_rect().size
	if vs.x < 200.0 or vs.y < 200.0 or vs == _laid:
		return
	_laid = vs
	_release_all()
	for b in _buttons:
		b.free()
	_buttons.clear()
	var sx := vs.x / MOCK_W
	var sy := vs.y / MOCK_H
	for item in LAYOUT:
		var rect := Rect2(float(item[1]) * sx, float(item[2]) * sy, float(item[3]) * sx, float(item[4]) * sy)
		_add(String(item[0]), rect, _label(String(item[0])), bool(item[5]))


func _label(action: String) -> String:
	match action:
		"l1": return "L1"
		"l2": return "L2"
		"r1": return "R1"
		"r2": return "R2"
		"btn_a": return "A"
		"btn_b": return "B"
		"btn_x": return "X"
		"btn_y": return "Y"
		"mana": return "L3"
		_: return action


func _add(action: String, rect: Rect2, label: String, round: bool) -> void:
	var b := Control.new()
	b.position = rect.position
	b.size = rect.size
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("action", action)
	b.set_meta("label", label)
	b.set_meta("round", round)
	b.draw.connect(_draw_button.bind(b))
	_root.add_child(b)
	_buttons.append(b)
	_down[action] = false


func _draw_button(b: Control) -> void:
	var action := String(b.get_meta("action"))
	var label := String(b.get_meta("label"))
	var hot: bool = _down.get(action, false)
	var r := Rect2(Vector2.ZERO, b.size)
	if b.get_meta("round"):
		var c := r.get_center()
		var rad := r.size.x * 0.5 - 2.0
		b.draw_circle(c, rad, Color(0.62, 0.62, 0.66) if hot else Color(0.2, 0.2, 0.22, 0.88))
		b.draw_arc(c, rad - 2.0, 0, TAU, 48, Color(0.9, 0.9, 0.92), 4.0)
	else:
		( _box_down if hot else _box ).draw(b.get_canvas_item(), r)
	if label in ["up", "down", "left", "right"]:
		_chevron(b, r.get_center(), label, hot)
	else:
		var col := Color(0.08, 0.08, 0.08) if hot else Color(0.94, 0.94, 0.96)
		b.draw_string(_font, Vector2(0, r.size.y * 0.5 + 16), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 42, col)


func _chevron(b: Control, c: Vector2, dir: String, hot: bool) -> void:
	var u := 16.0
	var pts: PackedVector2Array
	match dir:
		"up":
			pts = PackedVector2Array([c + Vector2(0, -u), c + Vector2(u, u * 0.7), c + Vector2(-u, u * 0.7)])
		"down":
			pts = PackedVector2Array([c + Vector2(0, u), c + Vector2(u, -u * 0.7), c + Vector2(-u, -u * 0.7)])
		"left":
			pts = PackedVector2Array([c + Vector2(-u, 0), c + Vector2(u * 0.7, u), c + Vector2(u * 0.7, -u)])
		"right":
			pts = PackedVector2Array([c + Vector2(u, 0), c + Vector2(-u * 0.7, u), c + Vector2(-u * 0.7, -u)])
	b.draw_colored_polygon(pts, Color(0.08, 0.08, 0.08) if hot else Color(0.94, 0.94, 0.96))


func _process(delta: float) -> void:
	var target := 0.0 if _pad else 1.0
	_alpha = move_toward(_alpha, target, delta * 3.5)
	if _root:
		_root.modulate.a = _alpha
		_root.visible = _alpha > 0.04
	if _pad:
		_release_all()


func _scan_pads() -> void:
	var found := false
	for d in Input.get_connected_joypads():
		var n := Input.get_joy_name(int(d)).to_lower()
		if n.is_empty() or n.contains("touch") or n.contains("virtual") or n.contains("uinput"):
			continue
		found = true
	_pad = found


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_VOLUMEUP, KEY_VOLUMEDOWN]:
		_volume_pause()
		get_viewport().set_input_as_handled()
		return
	if _pad or _alpha < 0.35:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var hit := _hit(event.position)
			if hit != "":
				_fingers[event.index] = hit
				_hold(hit, true)
				get_viewport().set_input_as_handled()
		elif _fingers.has(event.index):
			_hold(String(_fingers[event.index]), false)
			_fingers.erase(event.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _fingers.has(event.index):
		get_viewport().set_input_as_handled()


func _hit(p: Vector2) -> String:
	for b in _buttons:
		if Rect2(b.position, b.size).has_point(p):
			return String(b.get_meta("action"))
	return ""


func _hold(action: String, down: bool) -> void:
	if _down.get(action, false) == down:
		return
	_down[action] = down
	for b in _buttons:
		if String(b.get_meta("action")) == action:
			b.queue_redraw()
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = down
	ev.strength = 1.0
	Input.parse_input_event(ev)


func _release_all() -> void:
	for action in _down.keys():
		if _down[action]:
			_hold(String(action), false)
	_fingers.clear()


func _volume_pause() -> void:
	var now := Time.get_ticks_msec()
	if now - _vol_ms < 350:
		return
	_vol_ms = now
	var scene := get_tree().current_scene
	if scene and scene.has_method("toggle_pause"):
		scene.toggle_pause()
