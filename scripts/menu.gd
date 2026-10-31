extends Control
## v0.5 title / level select: four levels (scripts/game/levels.gd). Left/Right (d-pad, stick, arrows) choose,
## A / Start / Enter (or a click) plays. Esc quits.

var sel := 0
var thumbs: Array = []
var t := 0.0
var _stick_ready := true
var font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sel = Levels.current
	for lv in Levels.list():
		thumbs.append(load("res://assets/levels/%s/thumb.png" % String(lv["id"])))
	RenderingServer.set_default_clear_color(Color(0.02, 0.01, 0.04))
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--menu-shot="):
			_shot.call_deferred(a.get_slice("=", 1))
			return
	if not args.is_empty():          # capture / test args (--demo, --level=N, --shot=...): straight into the game
		get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")


func _shot(path: String) -> void:
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
	get_tree().quit()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _card(i: int) -> Rect2:
	return Rect2(90 + i * 445, 420, 400, 225)


func _move(d: int) -> void:
	sel = (sel + d + thumbs.size()) % thumbs.size()
	Sfx.play("swipe", 1.4, -8.0)


func _start() -> void:
	Levels.current = sel
	Sfx.play("potion", 1.0)
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _unhandled_input(e: InputEvent) -> void:
	if e.is_echo():
		return
	if e.is_action_pressed("left"):
		_move(-1)
	elif e.is_action_pressed("right"):
		_move(1)
	elif e.is_action_pressed("btn_a") or e.is_action_pressed("start") or e.is_action_pressed("ui_accept"):
		_start()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in thumbs.size():
			if _card(i).has_point(e.position):
				if sel == i:
					_start()
				sel = i
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		get_tree().quit()


func _draw() -> void:
	# backdrop: the selected level, dimmed
	draw_texture_rect(thumbs[sel], Rect2(0, 0, 1920, 1080), false, Color(0.35, 0.3, 0.4))
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.02, 0.0, 0.05, 0.45))
	draw_string(font, Vector2(0, 200), "MERA", HORIZONTAL_ALIGNMENT_CENTER, 1920, 140, Color(1.0, 0.8, 0.45))
	draw_string(font, Vector2(0, 280), "THE BABY GIANT", HORIZONTAL_ALIGNMENT_CENTER, 1920, 56, Color(0.95, 0.9, 1.0))
	draw_string(font, Vector2(0, 370), "SELECT A LEVEL", HORIZONTAL_ALIGNMENT_CENTER, 1920, 34, Color(0.8, 0.8, 0.9))
	var ls := Levels.list()
	for i in thumbs.size():
		var r := _card(i)
		var on := i == sel
		if on:
			var g := 0.5 + 0.5 * sin(t * 5.0)
			draw_rect(r.grow(10), Color(1.0, 0.8, 0.4, 0.6 + 0.4 * g))
		draw_texture_rect(thumbs[i], r, false, Color(1, 1, 1) if on else Color(0.55, 0.55, 0.6))
		draw_rect(r, Color(0, 0, 0), false, 3.0)
		var lv: Dictionary = ls[i]
		draw_string(font, Vector2(r.position.x, r.end.y + 52), "%d  %s" % [i + 1, String(lv["name"])], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34,
			Color(1, 0.85, 0.5) if on else Color(0.75, 0.75, 0.8))
		draw_string(font, Vector2(r.position.x, r.end.y + 90), String(lv["sub"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, Color(0.8, 0.8, 0.85))
	draw_string(font, Vector2(0, 900), "Left / Right (arrows): choose      A / Start (Z / Enter): play      Esc: quit", HORIZONTAL_ALIGNMENT_CENTER, 1920, 30, Color(0.85, 0.85, 0.9))
	draw_string(font, Vector2(0, 950), "In game: Start / F1 = controls    Game Over or Level Clear: B (X key) = back here", HORIZONTAL_ALIGNMENT_CENTER, 1920, 24, Color(0.7, 0.7, 0.78))
