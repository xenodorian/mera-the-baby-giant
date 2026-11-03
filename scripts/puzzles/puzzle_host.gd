extends CanvasLayer
## Base of the chest puzzles (pipes.gd, match3.gd, needle.gd). It owns the CanvasLayer, the dim backdrop and the panel,
## routes input (keyboard and pad actions, touch and mouse), pauses the tree while it is up, and reports the result.
##
## game.start_puzzle() creates one and calls open(). The layer runs with PROCESS_MODE_ALWAYS, like the victory card.
## `done(won: bool)` is called once, after the SOLVED / FAILED banner, or at once from finish_now().
## Subclasses override: title(), hint_keys(), hint_touch(), _setup(), _tick(dt), _draw_puzzle(), _on_action(a),
## _on_press(p), _on_drag(p), _on_release(p), solve(). Positions are in the 1920x1080 design space.

signal finished(won: bool)

const W := 1920.0
const H := 1080.0
const PANEL := Rect2(260.0, 70.0, 1400.0, 940.0)
const AREA := Rect2(260.0, 180.0, 1400.0, 760.0)          # where a puzzle draws
const GIVE_UP := Rect2(1450.0, 96.0, 180.0, 54.0)
const INPUT_DELAY_S := 0.25                                # a button held when the chest opened must not act
const GOLD := Color(1.0, 0.82, 0.45)
const INK := Color(0.95, 0.92, 0.88)
const DARK := Color(0.06, 0.03, 0.09, 0.96)

var game: Node = null
var rng := RandomNumberGenerator.new()
var done: Callable = Callable()
var ui: Control
var font: Font
var result := ""                   # "" while playing, then "won" or "lost"
var closed := false
var age := 0.0
var _result_t := 0.0
var _banner := ""


func open(g: Node, seed_v: int, cb: Callable) -> void:
	game = g
	done = cb
	rng.seed = seed_v
	layer = 25                                              # over the HUD (20), under the touch pad (30, hidden while open)
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ui.draw.connect(_paint)
	add_child(ui)
	_setup()
	g.add_child(self)
	g.get_tree().paused = true
	_pad_hidden(true)
	Sfx.play("swipe", 1.0, -8.0)


# ---------------------------------------------------------------- for subclasses
func title() -> String:
	return "PUZZLE"


func hint_keys() -> String:
	return "B give up"


func hint_touch() -> String:
	return "Tap to play"


## footer hint: font size and baseline y (a puzzle may draw it larger or lower)
func hint_size() -> int:
	return 26


func hint_y() -> float:
	return 985.0


func _setup() -> void:
	pass


func _tick(_dt: float) -> void:
	pass


func _draw_puzzle() -> void:
	pass


func _on_action(_a: String) -> void:
	pass


func _on_press(_p: Vector2) -> void:
	pass


func _on_drag(_p: Vector2) -> void:
	pass


func _on_release(_p: Vector2) -> void:
	pass


## test hook: play the puzzle to a win through its own rules
func solve() -> void:
	win()


func win() -> void:
	if result != "":
		return
	result = "won"
	_banner = "SOLVED"
	Sfx.play("potion", 1.0, -4.0)


func lose(why: String = "FAILED") -> void:
	if result != "":
		return
	result = "lost"
	_banner = why
	Sfx.play("fail", 1.0)


## test hook and the end of the banner: close now and report
func finish_now() -> void:
	if result == "":
		result = "lost"
	_close()


# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	age += delta
	if result != "":
		_result_t += delta
		if _result_t >= Tuning.PUZZLE_RESULT_S:
			_close()
	else:
		_tick(delta)
	if ui:
		ui.queue_redraw()


func _close() -> void:
	if closed:
		return
	closed = true
	_release()
	var won := result == "won"
	finished.emit(won)
	if done.is_valid():
		done.call(won)
	queue_free()


## also runs when the scene changes under an open puzzle: give the tree back
func _exit_tree() -> void:
	_pad_hidden(false)
	if not closed:
		closed = true
		_release()


func _release() -> void:
	if game != null and is_instance_valid(game) and game.puzzle == self:
		game.puzzle = null
		if is_inside_tree():
			get_tree().paused = bool(game.paused_play)


func _pad_hidden(on: bool) -> void:
	var tp: Node = Engine.get_main_loop().root.get_node_or_null("TouchPad") if Engine.get_main_loop() is SceneTree else null
	if tp != null:
		tp.set("suppressed", on)


# ---------------------------------------------------------------- input
func origin() -> Vector2:
	var vp := get_viewport()
	var sz: Vector2 = vp.get_visible_rect().size if vp else Vector2(W, H)
	return Vector2((sz.x - W) * 0.5, (sz.y - H) * 0.5)


func _input(event: InputEvent) -> void:
	if closed:
		return
	var used := false
	if event.is_action_pressed("start") or event.is_action_pressed("select"):
		used = true                                         # the pause menu cannot open on a puzzle
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		used = true
		if result == "" and age >= INPUT_DELAY_S:
			lose("GAVE UP")
	elif event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION):
		used = true
		var p: Vector2 = event.position - origin()
		if result == "" and age >= INPUT_DELAY_S:
			if event.pressed:
				if GIVE_UP.has_point(p):
					lose("GAVE UP")
				else:
					_on_press(p)
			else:
				_on_release(p)
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and event.device != InputEvent.DEVICE_ID_EMULATION):
		used = true
		if result == "" and age >= INPUT_DELAY_S:
			_on_drag(event.position - origin())
	else:
		for a in ["left", "right", "up", "down", "btn_a", "btn_b"]:
			if event.is_action_pressed(a, a in ["left", "right", "up", "down"]):
				used = true
				if result == "" and age >= INPUT_DELAY_S:
					press_action(a)
				break
	if used:
		get_viewport().set_input_as_handled()


## one pad / keyboard action (also the test hook for inputs)
func press_action(a: String) -> void:
	if result != "":
		return
	if a == "btn_b":
		lose("GAVE UP")
		return
	_on_action(a)


# ---------------------------------------------------------------- drawing
func _paint() -> void:
	var o := origin()
	ui.draw_rect(Rect2(Vector2.ZERO, ui.size), Color(0.0, 0.0, 0.02, 0.78))
	ui.draw_set_transform(o, 0.0, Vector2.ONE)
	ui.draw_rect(PANEL, DARK)
	ui.draw_rect(PANEL, GOLD, false, 4.0)
	text(Vector2(PANEL.position.x, 150.0), title(), 54, GOLD, HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x)
	ui.draw_rect(GIVE_UP, Color(0.28, 0.1, 0.1, 0.95))
	ui.draw_rect(GIVE_UP, Color(0.85, 0.45, 0.4), false, 3.0)
	text(Vector2(GIVE_UP.position.x, GIVE_UP.position.y + 37.0), "GIVE UP", 26, Color(1.0, 0.8, 0.75), HORIZONTAL_ALIGNMENT_CENTER, GIVE_UP.size.x)
	_draw_puzzle()
	var hint := hint_touch() if Controls.scheme == "touch" else hint_keys()
	text(Vector2(PANEL.position.x, hint_y()), hint, hint_size(), Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER, PANEL.size.x)
	if result != "":
		var r := Rect2(PANEL.position.x, 440.0, PANEL.size.x, 200.0)
		ui.draw_rect(r, Color(0.0, 0.0, 0.0, 0.82))
		var c := Color(0.5, 1.0, 0.55) if result == "won" else Color(1.0, 0.5, 0.45)
		text(Vector2(r.position.x, r.position.y + 128.0), _banner, 96, c, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	ui.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func text(p: Vector2, t: String, sz: int, c: Color = INK, align: int = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0) -> void:
	ui.draw_string(font, p + Vector2(2, 2), t, align, w, sz, Color(0, 0, 0, 0.7))
	ui.draw_string(font, p, t, align, w, sz, c)


## a plate with a border, the look of the shop rows
func plate(r: Rect2, fill: Color, edge: Color, width: float = 3.0) -> void:
	ui.draw_rect(r, fill)
	ui.draw_rect(r, edge, false, width)
