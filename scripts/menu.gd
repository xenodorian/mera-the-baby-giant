extends Control
## Title / level select: four built levels. Left/Right choose, A / Start plays.
## Down goes to CHECK FOR UPDATES and CREDITS.

const CREDITS := preload("res://scripts/app/credits.gd")

var sel := 0
var thumbs: Array = []
var t := 0.0
var _stick_ready := true
var font: Font
var row := 0                    # 0 = level cards, 1 = bottom buttons
var btn := 0                    # 0 = updates, 1 = credits
var mode := "menu"              # menu | credits | update
var credit_sel := 0


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
	if not args.is_empty() and not ("--menu" in args) and not ("--update-selftest" in args):   # capture / test args (--demo, --level=N, ...): into the game
		get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")
		return
	var upd := _upd()
	if upd and upd.auto_check and not upd.auto_checked and not ("--no-update-check" in args):
		upd.auto_checked = true
		upd.check()


func _upd() -> Node:
	return get_node_or_null("/root/Updater")


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


func _origin() -> Vector2:
	return Vector2((size.x - 1920.0) * 0.5, (size.y - 1080.0) * 0.5)


func _to_design(p: Vector2) -> Vector2:
	return p - _origin()


func _card(i: int) -> Rect2:
	var n := maxi(thumbs.size(), 1)
	var gap := 18.0
	var margin := 28.0
	var w := (1920.0 - margin * 2.0 - gap * float(n - 1)) / float(n)
	return Rect2(margin + float(i) * (w + gap), 400, w, 168)


func _button(i: int) -> Rect2:
	return Rect2(560 + i * 420, 980, 380, 64)


func _button_text(i: int) -> String:
	if i == 1:
		return "CREDITS"
	var u := _upd()
	if u and u.state in ["available", "ready"]:
		return "UPDATE TO v%s" % u.version_text(u.latest["version"])
	return "CHECK FOR UPDATES"


func _press_button() -> void:
	Sfx.play("swipe", 1.0, -6.0)
	if btn == 1:
		mode = "credits"
		credit_sel = 0
		return
	mode = "update"
	var u := _upd()
	if u and u.state in ["idle", "uptodate", "error", "unsupported"]:
		u.check()


## the update panel: A = next step (download -> install), B = close
func _update_input(e: InputEvent) -> void:
	var u := _upd()
	if e.is_action_pressed("btn_b") or (e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE):
		mode = "menu"
	elif e.is_action_pressed("btn_a") or e.is_action_pressed("start") or e.is_action_pressed("ui_accept"):
		if u == null:
			mode = "menu"
		elif u.state == "available":
			u.download()
		elif u.state == "ready":
			u.apply()
		elif u.state in ["uptodate", "error", "unsupported"]:
			mode = "menu"


func _credits_input(e: InputEvent) -> void:
	var n: int = CREDITS.ENTRIES.size()
	if e.is_action_pressed("btn_b") or (e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE):
		mode = "menu"
	elif e.is_action_pressed("up"):
		credit_sel = (credit_sel - 1 + n) % n
	elif e.is_action_pressed("down"):
		credit_sel = (credit_sel + 1) % n
	elif e.is_action_pressed("btn_a") or e.is_action_pressed("ui_accept"):
		OS.shell_open(String(CREDITS.ENTRIES[credit_sel]["url"]))
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in n:
			if Rect2(160, 190 + i * 74 - 30, 1600, 70).has_point(_to_design(e.position)):
				credit_sel = i
				OS.shell_open(String(CREDITS.ENTRIES[i]["url"]))


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
	if mode == "credits":
		_credits_input(e)
		return
	if mode == "update":
		_update_input(e)
		return
	if e.is_action_pressed("down") and row == 0:
		row = 1
		Sfx.play("swipe", 1.2, -8.0)
		return
	if e.is_action_pressed("up") and row == 1:
		row = 0
		Sfx.play("swipe", 1.2, -8.0)
		return
	if row == 1:
		if e.is_action_pressed("left") or e.is_action_pressed("right"):
			btn = 1 - btn
			Sfx.play("swipe", 1.4, -8.0)
		elif e.is_action_pressed("btn_a") or e.is_action_pressed("start") or e.is_action_pressed("ui_accept"):
			_press_button()
		elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
			get_tree().quit()
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_click_buttons(_to_design(e.position))
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _click_buttons(_to_design(e.position)):
		return
	if e.is_action_pressed("left"):
		_move(-1)
	elif e.is_action_pressed("right"):
		_move(1)
	elif e.is_action_pressed("btn_a") or e.is_action_pressed("start") or e.is_action_pressed("ui_accept"):
		_start()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in thumbs.size():
			if _card(i).has_point(_to_design(e.position)):
				if sel == i:
					_start()
				sel = i
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		get_tree().quit()


func _click_buttons(p: Vector2) -> bool:
	for i in 2:
		if _button(i).has_point(p):
			row = 1
			btn = i
			_press_button()
			return true
	return false


func _draw() -> void:
	var bg: Texture2D = thumbs[sel]
	draw_texture_rect(bg, Rect2(Vector2.ZERO, size), false, Color(0.35, 0.3, 0.4))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.05, 0.45))
	draw_set_transform(_origin(), 0.0, Vector2.ONE)
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
		draw_string(font, Vector2(r.position.x, r.end.y + 52), "%d  %s" % [i + 1, String(lv["name"])], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28,
			Color(1, 0.85, 0.5) if on else Color(0.75, 0.75, 0.8))
		draw_string(font, Vector2(r.position.x, r.end.y + 86), String(lv["sub"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color(0.8, 0.8, 0.85))
	draw_string(font, Vector2(0, 860), "Left / Right: choose      A / Start: play      Down: updates / credits      Esc: quit", HORIZONTAL_ALIGNMENT_CENTER, 1920, 28, Color(0.85, 0.85, 0.9))
	for i in 2:
		var r := _button(i)
		var on := row == 1 and btn == i
		var u := _upd()
		var hot: bool = i == 0 and u != null and u.state in ["available", "ready"]
		draw_rect(r, Color(0.25, 0.12, 0.05, 0.9) if on else Color(0.08, 0.05, 0.12, 0.8))
		draw_rect(r, Color(1.0, 0.8, 0.4) if on else (Color(0.4, 1.0, 0.5) if hot else Color(0.5, 0.45, 0.6)), false, 3.0)
		draw_string(font, Vector2(r.position.x, r.position.y + 42), _button_text(i), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28,
			Color(1, 0.9, 0.6) if on else (Color(0.6, 1.0, 0.65) if hot else Color(0.85, 0.85, 0.9)))
	_draw_version()
	if mode == "credits":
		_draw_credits()
	elif mode == "update":
		_draw_update()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _saved_run() -> Dictionary:
	if not FileAccess.file_exists("user://mera_run.json"):
		return {}
	var f := FileAccess.open("user://mera_run.json", FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


func _draw_version() -> void:
	var u := _upd()
	var v := String(ProjectSettings.get_setting("application/config/version", "?"))
	draw_string(font, Vector2(20, 1062), "v" + v, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.6, 0.6, 0.7))
	if u and u.state == "available" and mode == "menu":
		var g := 0.6 + 0.4 * sin(t * 4.0)
		draw_string(font, Vector2(0, 50), "Update available: v%s   (Down, then A on UPDATE)" % u.version_text(u.latest["version"]), HORIZONTAL_ALIGNMENT_RIGHT, 1900, 26, Color(0.5, 1.0, 0.55, g))


func _panel(r: Rect2) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))
	draw_set_transform(_origin(), 0.0, Vector2.ONE)
	draw_rect(r, Color(0.06, 0.03, 0.09, 0.97))
	draw_rect(r, Color(1.0, 0.8, 0.45), false, 3.0)


func _draw_credits() -> void:
	_panel(Rect2(120, 60, 1680, 960))
	draw_string(font, Vector2(0, 130), "CREDITS", HORIZONTAL_ALIGNMENT_CENTER, 1920, 50, Color(1.0, 0.8, 0.45))
	var i := 0
	for c in CREDITS.ENTRIES:
		var y := 190 + i * 74
		var on := i == credit_sel
		if on:
			draw_rect(Rect2(160, y - 30, 1600, 70), Color(0.3, 0.15, 0.05, 0.8))
		draw_string(font, Vector2(180, y), "%s  [%s]" % [String(c["who"]), String(c["lic"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.9, 0.6) if on else Color(0.95, 0.9, 1.0))
		draw_string(font, Vector2(180, y + 30), "%s  -  %s" % [String(c["what"]), String(c["url"])], HORIZONTAL_ALIGNMENT_LEFT, 1560, 20, Color(0.75, 0.75, 0.85))
		i += 1
	draw_string(font, Vector2(0, 950), CREDITS.FOOTER, HORIZONTAL_ALIGNMENT_CENTER, 1920, 20, Color(0.7, 0.7, 0.8))
	draw_string(font, Vector2(0, 990), "Up / Down: select    A (Z) or click: open the link    B (X) / Esc: back", HORIZONTAL_ALIGNMENT_CENTER, 1920, 24, Color(0.85, 0.85, 0.9))


func _draw_update() -> void:
	var r := Rect2(360, 300, 1200, 440)
	_panel(r)
	draw_string(font, Vector2(0, 380), "UPDATES", HORIZONTAL_ALIGNMENT_CENTER, 1920, 46, Color(1.0, 0.8, 0.45))
	var u := _upd()
	if u == null:
		return
	draw_string(font, Vector2(0, 450), "This version: v%s" % String(ProjectSettings.get_setting("application/config/version", "?")), HORIZONTAL_ALIGNMENT_CENTER, 1920, 26, Color(0.8, 0.8, 0.9))
	draw_string(font, Vector2(400, 520), u.message, HORIZONTAL_ALIGNMENT_CENTER, 1120, 28, Color(0.95, 0.95, 1.0))
	if u.state == "downloading":
		var b := Rect2(560, 570, 800, 30)
		draw_rect(b, Color(0.15, 0.1, 0.2))
		draw_rect(Rect2(b.position, Vector2(b.size.x * u.progress, b.size.y)), Color(0.4, 1.0, 0.5))
		draw_rect(b, Color(0.8, 0.8, 0.9), false, 2.0)
	var hint := {"available": "A (Z): download and verify      B (X): later",
		"ready": "A (Z): install and restart%s      B (X): later" % (" (opens the Android installer)" if u.platform_name() == "Android" else ""),
		"checking": "B (X): close", "downloading": "B (X): hide (the download continues)", "installing": "",
		"uptodate": "A / B: close", "error": "A / B: close", "unsupported": "A / B: close", "idle": "B (X): close"}
	draw_string(font, Vector2(0, 690), String(hint.get(u.state, "")), HORIZONTAL_ALIGNMENT_CENTER, 1920, 26, Color(0.85, 0.85, 0.9))
