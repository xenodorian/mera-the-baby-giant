extends Control
## Title / level select. Left/Right choose, A / Start plays.
## Down goes to SHOP, RESET, CHECK FOR UPDATES, and CREDITS.

const CREDITS := preload("res://scripts/app/credits.gd")
const SHOP_N := 8

var sel := 0
var thumbs: Array = []
var t := 0.0
var _stick_ready := true
var font: Font
var row := 0                    # 0 = level cards, 1 = bottom buttons
var btn := 0                    # 0 shop, 1 reset, 2 updates, 3 credits
var mode := "menu"              # menu | credits | update | shop
var credit_sel := 0
var shop_i := 0
var shop_ally := 0
var note := ""
var note_t := 0.0


func _ready() -> void:
	Carry.ensure()
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
	if note_t > 0.0:
		note_t -= delta
		if note_t <= 0.0:
			note_t = 0.0
			note = ""
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
	return Rect2(80 + i * 444, 980, 420, 64)


func _button_text(i: int) -> String:
	if i == 0:
		return "SHOP"
	if i == 1:
		return "RESET"
	if i == 3:
		return "CREDITS"
	var u := _upd()
	if u and u.state in ["available", "ready"]:
		return "UPDATE TO v%s" % u.version_text(u.latest["version"])
	return "CHECK FOR UPDATES"


func _press_button() -> void:
	Sfx.play("swipe", 1.0, -6.0)
	if btn == 0:
		Carry.ensure()
		mode = "shop"
		return
	if btn == 1:
		Carry.reset()
		note = "Reset. Gold, items, and upgrades cleared."
		note_t = 4.0
		return
	if btn == 3:
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


func _shop_what(i: int) -> String:
	match i:
		0:
			return "potion_cap"
		1:
			return "mana_cap"
		2:
			return "card_cap"
		3:
			return "card"
		4:
			return "fury"
		5:
			return "mana_bar"
		6:
			return "scale"
		7:
			return "key"
		_:
			return ""


func _shop_name(i: int) -> String:
	match i:
		0:
			return "Health potion slots"
		1:
			return "Mana potion slots"
		2:
			return "Card slots"
		3:
			var id := String(Carry.ALLIES[posmod(shop_ally, Carry.ALLIES.size())])
			return "Buy summon card   < %s >" % id.capitalize()
		4:
			return "Fury bar +%d" % int(Carry.RAGE_STEP)
		5:
			return "Mana bar +%d" % int(Carry.STAMINA_STEP)
		6:
			return "Size cap +1 (max %dx)" % Carry.SCALE_CAP_MAX
		7:
			return "Stage key"
		_:
			return ""


func _shop_stat(i: int) -> String:
	match i:
		0:
			return "%d / %d" % [Carry.potion_cap, Carry.POTION_CAP_MAX]
		1:
			return "%d / %d" % [Carry.mana_potion_cap, Carry.MANA_POTION_CAP_MAX]
		2:
			return "%d / %d" % [Carry.card_cap, Carry.CARD_CAP_MAX]
		3:
			var id := String(Carry.ALLIES[posmod(shop_ally, Carry.ALLIES.size())])
			return "x%d" % int(Carry.cards.get(id, 0))
		4:
			return str(int(Carry.rage_max))
		5:
			return str(int(Carry.stamina_max))
		6:
			return str(Carry.scale_cap)
		7:
			if Carry.unlocked >= Carry.stage_count() - 1:
				return "all open"
			return "opens stage %d" % (Carry.unlocked + 2)
		_:
			return ""


func _shop_price(i: int) -> int:
	match i:
		0:
			return Carry.PRICE_POTION_CAP
		1:
			return Carry.PRICE_MANA_CAP
		2:
			return Carry.PRICE_CARD_CAP
		3:
			return Carry.PRICE_CARD
		4:
			return Carry.PRICE_FURY
		5:
			return Carry.PRICE_MANA_BAR
		6:
			return Carry.PRICE_SCALE
		7:
			return Carry.PRICE_KEY
		_:
			return 0


func _shop_row_rect(i: int) -> Rect2:
	return Rect2(160, 248 + i * 68, 1600, 62)


func _shop_buy() -> void:
	var what := _shop_what(shop_i)
	var ally := ""
	if what == "card" and not Carry.ALLIES.is_empty():
		ally = String(Carry.ALLIES[posmod(shop_ally, Carry.ALLIES.size())])
	var result := Carry.buy(what, ally)
	if result == "":
		note = "Bought."
		Sfx.play("potion", 1.0, -4.0)
	elif result == "gold":
		note = "Not enough gold."
		Sfx.play("swipe", 0.8, -10.0)
	elif result == "max":
		note = "Already maxed."
		Sfx.play("swipe", 0.8, -10.0)
	elif result == "full":
		note = "Card slots full."
		Sfx.play("swipe", 0.8, -10.0)
	else:
		note = "Can't buy that."
		Sfx.play("swipe", 0.8, -10.0)
	note_t = 4.0


## the shop: Up/Down a row, Left/Right the summon card, A buys, B closes
func _shop_input(e: InputEvent) -> void:
	if e.is_action_pressed("btn_b") or (e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE):
		mode = "menu"
	elif e.is_action_pressed("up"):
		shop_i = (shop_i - 1 + SHOP_N) % SHOP_N
		Sfx.play("swipe", 1.2, -8.0)
	elif e.is_action_pressed("down"):
		shop_i = (shop_i + 1) % SHOP_N
		Sfx.play("swipe", 1.2, -8.0)
	elif e.is_action_pressed("left"):
		if shop_i == 3 and not Carry.ALLIES.is_empty():
			shop_ally = (shop_ally - 1 + Carry.ALLIES.size()) % Carry.ALLIES.size()
			Sfx.play("swipe", 1.4, -8.0)
	elif e.is_action_pressed("right"):
		if shop_i == 3 and not Carry.ALLIES.is_empty():
			shop_ally = (shop_ally + 1) % Carry.ALLIES.size()
			Sfx.play("swipe", 1.4, -8.0)
	elif e.is_action_pressed("btn_a") or e.is_action_pressed("ui_accept"):
		_shop_buy()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var p := _to_design(e.position)
		for i in SHOP_N:
			if _shop_row_rect(i).has_point(p):
				shop_i = i
				_shop_buy()
				return


func _move(d: int) -> void:
	sel = (sel + d + thumbs.size()) % thumbs.size()
	Sfx.play("swipe", 1.4, -8.0)


func _start() -> void:
	Carry.ensure()
	if not Carry.stage_open(sel):
		note = "Locked. Beat the previous stage, or buy a 200 gold key."
		note_t = 4.0
		Sfx.play("swipe", 0.7, -8.0)
		return
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
	if mode == "shop":
		_shop_input(e)
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
		if e.is_action_pressed("left"):
			btn = (btn + 3) % 4
			Sfx.play("swipe", 1.4, -8.0)
		elif e.is_action_pressed("right"):
			btn = (btn + 1) % 4
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
	for i in 4:
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
		var open := Carry.stage_open(i)
		if not open:
			draw_rect(r, Color(0.02, 0.0, 0.04, 0.72))
		draw_string(font, Vector2(r.position.x, r.end.y + 52), "%d  %s" % [i + 1, String(lv["name"])], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28,
			Color(1, 0.85, 0.5) if on else Color(0.75, 0.75, 0.8))
		var sub := "LOCKED" if not open else String(lv["sub"])
		draw_string(font, Vector2(r.position.x, r.end.y + 86), sub, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18,
			Color(1.0, 0.45, 0.4) if not open else Color(0.8, 0.8, 0.85))
	draw_string(font, Vector2(0, 860), "Left / Right: choose      A / Start: play      Down: Shop / Reset / updates / credits      Esc: quit", HORIZONTAL_ALIGNMENT_CENTER, 1920, 28, Color(0.85, 0.85, 0.9))
	if mode == "menu":
		_draw_note_at(930)
	for i in 4:
		var r := _button(i)
		var on := row == 1 and btn == i
		var u := _upd()
		var hot: bool = i == 2 and u != null and u.state in ["available", "ready"]
		draw_rect(r, Color(0.25, 0.12, 0.05, 0.9) if on else Color(0.08, 0.05, 0.12, 0.8))
		draw_rect(r, Color(1.0, 0.8, 0.4) if on else (Color(0.4, 1.0, 0.5) if hot else Color(0.5, 0.45, 0.6)), false, 3.0)
		draw_string(font, Vector2(r.position.x, r.position.y + 42), _button_text(i), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28,
			Color(1, 0.9, 0.6) if on else (Color(0.6, 1.0, 0.65) if hot else Color(0.85, 0.85, 0.9)))
	_draw_version()
	if mode == "credits":
		_draw_credits()
	elif mode == "update":
		_draw_update()
	elif mode == "shop":
		_draw_shop()
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
		draw_string(font, Vector2(0, 50), "Update available: v%s   (Down, then CHECK FOR UPDATES)" % u.version_text(u.latest["version"]), HORIZONTAL_ALIGNMENT_RIGHT, 1900, 26, Color(0.5, 1.0, 0.55, g))


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


func _draw_note_at(y: float) -> void:
	if note == "" or note_t <= 0.0:
		return
	var a := 1.0 if note_t > 0.7 else note_t / 0.7
	draw_string(font, Vector2(0, y), note, HORIZONTAL_ALIGNMENT_CENTER, 1920, 26, Color(1.0, 0.86, 0.45, a))


func _draw_shop() -> void:
	Carry.ensure()
	_panel(Rect2(120, 60, 1680, 960))
	draw_string(font, Vector2(0, 150), "SHOP", HORIZONTAL_ALIGNMENT_CENTER, 1920, 50, Color(1.0, 0.8, 0.45))
	draw_string(font, Vector2(0, 220), "Gold: %d" % Carry.gold, HORIZONTAL_ALIGNMENT_CENTER, 1920, 32, Color(1.0, 0.85, 0.4))
	for i in SHOP_N:
		var r := _shop_row_rect(i)
		var on := i == shop_i
		if on:
			draw_rect(r, Color(0.3, 0.15, 0.05, 0.8))
		var col := Color(1, 0.9, 0.6) if on else Color(0.95, 0.9, 1.0)
		var y := r.position.y + 44
		draw_string(font, Vector2(r.position.x + 24, y), _shop_name(i), HORIZONTAL_ALIGNMENT_LEFT, 860, 28, col)
		draw_string(font, Vector2(r.position.x + 900, y), _shop_stat(i), HORIZONTAL_ALIGNMENT_LEFT, 340, 28, col)
		var price := _shop_price(i)
		var pc := Color(1.0, 0.8, 0.45) if Carry.gold >= price else Color(0.75, 0.45, 0.4)
		draw_string(font, Vector2(r.position.x + 1240, y), "%d g" % price, HORIZONTAL_ALIGNMENT_RIGHT, 320, 28, pc)
	_draw_note_at(900)
	draw_string(font, Vector2(0, 970), "Up/Down row   Left/Right card   A buy   B back", HORIZONTAL_ALIGNMENT_CENTER, 1920, 24, Color(0.85, 0.85, 0.9))


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
