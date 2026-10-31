extends CanvasLayer
## Android on-screen pad. Shown unless a gamepad is connected, then it fades out.
## Grayscale. Xbox diamond (Y top, B right, A bottom, X left), not Xbox colors.
## The phone's volume buttons pause and open the controls list. There is no Start button.

const CELL := 112.0
const GAP := 16.0
const STEP := CELL + GAP
const SHOULDER := Vector2(236.0, 76.0)

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


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() != "Android":
		set_process(false)
		set_process_input(false)
		return
	_font = ThemeDB.fallback_font
	_box = _style(Color(0.16, 0.16, 0.18, 0.82), Color(0.82, 0.82, 0.86, 0.95))
	_box_down = _style(Color(0.55, 0.55, 0.58, 0.92), Color(1, 1, 1, 1))
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_build()
	Input.joy_connection_changed.connect(func(_d, _c): _scan_pads())
	_scan_pads()


func _style(fill: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(4)
	s.set_corner_radius_all(22)
	return s


func _build() -> void:
	var left := Vector2(230.0, 900.0)
	var right := Vector2(1690.0, 900.0)
	_diamond(left, [
		["up", Vector2(0, -STEP), "up"],
		["down", Vector2(0, STEP), "down"],
		["left", Vector2(-STEP, 0), "left"],
		["right", Vector2(STEP, 0), "right"],
	], false)
	_diamond(right, [
		["btn_y", Vector2(0, -STEP), "Y"],
		["btn_a", Vector2(0, STEP), "A"],
		["btn_x", Vector2(-STEP, 0), "X"],
		["btn_b", Vector2(STEP, 0), "B"],
	], true)
	_shoulders(left, "l2", "l1", "L2", "L1")
	_shoulders(right, "r2", "r1", "R2", "R1")


func _diamond(center: Vector2, slots: Array, round: bool) -> void:
	for s in slots:
		_add(String(s[0]), Rect2(center + s[1] - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)), String(s[2]), round)


func _shoulders(anchor: Vector2, top_action: String, bot_action: String, top_label: String, bot_label: String) -> void:
	var up_top := anchor.y - STEP - CELL * 0.5
	var bot_y := up_top - GAP - SHOULDER.y
	var top_y := bot_y - GAP - SHOULDER.y
	_add(bot_action, Rect2(anchor.x - SHOULDER.x * 0.5, bot_y, SHOULDER.x, SHOULDER.y), bot_label, false)
	_add(top_action, Rect2(anchor.x - SHOULDER.x * 0.5, top_y, SHOULDER.x, SHOULDER.y), top_label, false)


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
