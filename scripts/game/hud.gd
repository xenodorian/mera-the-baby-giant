extends CanvasLayer
## HUD: size (= HP) pips, rage / Fury meter, potions, current move, Fury timer, pause menu, Game Over.

const ROSTER := preload("res://scripts/game/roster.gd")
const AL := preload("res://scripts/game/allies.gd")

var game: Node = null
var overlay := false
var pause_sel := 0
var pause_controls := false
var ui := Control.new()
var font: Font
var _flash := ""
var _flash_t := 0.0

const PAUSE_ITEMS := ["CONTINUE", "RESTART LEVEL", "BACK TO TITLE", "CONTROLS", "QUIT GAME"]

## [gamepad (Xbox names), keyboard (v0.8 PC layout, Controls.MAP), what it does]
const CONTROLS := [
	["D-pad / left stick", "arrows", "walk left / right, Up = jump, Down = crouch"],
	["A (hold) + direction", "Z (hold) + arrow", "run      (Down + A = slide: breaks loot props, takes the drop)"],
	["B", "X", "back dodge (free)   B then X = dodge attack   B then Y = FAST quick fire"],
	["B+Y together", "X+S", "rising slash (fast windup), no dodge (free)    Y again during it = slam (free)"],
	["X", "A", "1x attack.  X X X = 1x 2x 2x-2,  X X hold X = 1x 2x 2x-1"],
	["X X Y", "A A S", "1x 2x 3x (with slash)     X X X Y = combo into beam, 20 mana"],
	["Y", "S", "quick fire (bolt) 5 mana     X+Y together = rear explosion 12 mana"],
	["Up + Y", "Up + S", "three large bolts: up and both diagonals, 15 mana"],
	["A+Y / Y while running", "Z+S", "ground dash (aerial dash animation), 6 mana"],
	["In the air", "", "X = jump attack (X again: 2nd hit), Y = aerial dash 6 mana, Up = double jump"],
	["Down + Y", "Down + S", "EARTHQUAKE: hold Down and press Y, even together. 1 s quake, grounded enemies stunned 5 s (20 mana)"],
	["L1", "Q", "heal: drink a green potion, +1 size, up to the size cap. One drawing per frame"],
	["L2", "1", "full bubble while held (3 mana + 4/s). Pulls every item on screen. L1 drinks and it stays"],
	["R2 (100 rage)", "2", "LIGHTNING: one bolt per enemy on screen, in a quick row. Costs 100 rage"],
	["L2 + R2 (100 rage)", "1 + 2", "Fury for 12 s. Costs 100 rage. She cannot be hit. In Fury, R2 takes off / lands"],
	["Down hold", "Down hold", "small bubble, 3 s, subtracts 1 damage, pulls every item on screen. L1 drinks and it stays"],
	["X just as a shot arrives", "A just as a shot arrives", "reflect it (within 0.15 s of the hitbox): flies back and hurts them"],
	["L2 just before a hit", "1 just before", "PARRY (within 0.15 s): no damage, attacker staggered and knocked back, shots fly back, x2 counter"],
	["Any button in a bubble", "", "drops that bubble and does the move. L1 drinks and the bubble stays"],
	["L1+R1+L2+R2 (100 rage)", "Q+W+1+2", "freeze slash: mark up to 9 enemies, cut each for 3. Costs 100 rage"],
	["R1", "W", "summon an ally (needs an ally card; several cards: picker)"],
	["Fury flight", "arrows", "8-way move, Down on the ground lands, R2 lands"],
	["Start", "Enter / F1", "pause: continue, restart, title, controls, or quit. B or Start continues"],
	["-", "F2", "debug: hit/hurt boxes, PageUp/PageDown or right stick = size 1x-19x"],
	["Menus", "arrows, Z ok, X back", "level select, ally picker, level clear / Game Over (Esc quits, F11 fullscreen)"],
]


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.draw.connect(_draw_ui)
	add_child(ui)


func flash(what: String) -> void:
	_flash = what
	_flash_t = 1.0


func queue_redraw_all() -> void:
	ui.queue_redraw()


func _process(delta: float) -> void:
	_flash_t = maxf(_flash_t - delta, 0.0)
	ui.queue_redraw()


## v0.10.6: while the game is paused the rest of the tree is frozen, so the pause menu lives here
func _unhandled_input(event: InputEvent) -> void:
	if game == null or not game.paused_play or event.is_echo():
		return
	if pause_controls:
		if event.is_action_pressed("btn_a") or event.is_action_pressed("btn_b") or event.is_action_pressed("ui_accept") \
				or event.is_action_pressed("start") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE) \
				or (event is InputEventMouseButton and event.pressed):
			pause_controls = false
			overlay = false
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("up"):
		pause_sel = posmod(pause_sel - 1, PAUSE_ITEMS.size())
		Sfx.play("swipe", 1.3, -8.0)
	elif event.is_action_pressed("down"):
		pause_sel = posmod(pause_sel + 1, PAUSE_ITEMS.size())
		Sfx.play("swipe", 1.3, -8.0)
	elif event.is_action_pressed("btn_a") or event.is_action_pressed("ui_accept"):
		_pause_confirm()
	elif event.is_action_pressed("start") or event.is_action_pressed("btn_b"):
		game.toggle_pause()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		game.toggle_pause()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in PAUSE_ITEMS.size():
			if _pause_item(i).has_point(event.position):
				pause_sel = i
				_pause_confirm()
				break
	else:
		return
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()


func _pause_confirm() -> void:
	match pause_sel:
		0:
			game.toggle_pause()
		1:
			game.toggle_pause()
			game.restart()
		2:
			game.toggle_pause()
			game.to_menu()
		3:
			pause_controls = true
			overlay = true
		4:
			game.get_tree().quit()


func _origin() -> Vector2:
	return Vector2((ui.size.x - 1920.0) * 0.5, (ui.size.y - 1080.0) * 0.5)


func _pause_item(i: int) -> Rect2:
	var o := _origin()
	return Rect2(o.x + 620.0, o.y + 390.0 + float(i) * 68.0, 680.0, 58.0)


func _txt(p: Vector2, t: String, sz: int = 28, c: Color = Color(0.95, 0.92, 0.88)) -> void:
	ui.draw_string(font, p + Vector2(2, 2), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.7))
	ui.draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)


func _draw_ui() -> void:
	if game == null:
		return
	var m: Mera = game.mera
	var hx := 0.0
	if OS.get_name() == "Android":
		hx = maxf(0.0, ui.size.x * 0.23 - 20.0)
	# size = HP
	var cap := maxi(m.scale_cap(), 1)
	var step := 46.0 if cap <= 6 else 36.0
	var pip_w := 40.0 if cap <= 6 else 30.0
	var panel_w := maxf(560.0, 190.0 + float(cap) * step + 24.0)
	ui.draw_rect(Rect2(20 + hx, 16, panel_w, 196), Color(0.04, 0.03, 0.07, 0.55))
	_txt(Vector2(36 + hx, 52), "SIZE  %dx" % m.size, 34)
	for i in cap:
		var on := i < m.size
		var r := Rect2(200 + hx + float(i) * step, 28, pip_w, 26)
		ui.draw_rect(r, Color(0.98, 0.66, 0.33) if on else Color(0.2, 0.16, 0.22))
		ui.draw_rect(r, Color(0.05, 0.03, 0.06), false, 3.0)
	if m.size > cap:
		_txt(Vector2(200 + hx + float(cap) * step, 52), "+%d" % (m.size - cap), 22)
	# rage / fury
	_txt(Vector2(36 + hx, 100), "FURY" if m.fury else "RAGE", 26, Color(1, 0.35, 0.3) if m.fury else Color(0.95, 0.92, 0.88))
	var w := 330.0
	ui.draw_rect(Rect2(140 + hx, 78, w, 26), Color(0.15, 0.03, 0.06))
	var fc := Color(0.86, 0.08, 0.12) if m.fury else (Color(1.0, 0.25, 0.2) if m.rage >= 100.0 else Color(0.7, 0.12, 0.14))
	var rage_frac := (m.fury_left / Mera.FURY_TIME) if m.fury else (m.rage / maxf(m.rage_max, 1.0))
	ui.draw_rect(Rect2(140 + hx, 78, w * clampf(rage_frac, 0.0, 1.0), 26), fc)
	ui.draw_rect(Rect2(140 + hx, 78, w, 26), Color(0.05, 0.03, 0.06), false, 3.0)
	_txt(Vector2(482 + hx, 100), ("%d/%d" % [int(m.rage), int(m.rage_max)]), 24)
	if m.rage >= 100.0 and not m.fury and int(Time.get_ticks_msec() / 300) % 2 == 0:
		_txt(Vector2(140 + hx, 136), "R2 LIGHTNING   ·   L2+R2 FURY   ·   Q+W+1+2 SLASH", 22, Color(1, 0.3, 0.25))
	if _flash == "rage" and _flash_t > 0.0:
		_txt(Vector2(200 + hx, 146), "Fury, lightning and the freeze slash each need 100 rage", 22, Color(1, 0.5, 0.4))
	if _flash == "fury_chord" and _flash_t > 0.0:
		_txt(Vector2(260 + hx, 146), "Fury is L2 + R2 together. She is invulnerable while it lasts", 22, Color(1, 0.6, 0.4))
	if _flash == "parry" and _flash_t > 0.0:            # v0.8
		_txt(Vector2(840, 300), "PARRY!", 64, Color(1.0, 0.92, 0.55, minf(_flash_t * 2.0, 1.0)))
	if m.counter_active():
		_txt(Vector2(800, 360), "COUNTER  x%d" % Tuning.PARRY_COUNTER_MULT, 36, Color(1.0, 0.8, 0.4))
	if _flash == "ally" and _flash_t > 0.0:
		_txt(Vector2(260, 146), "R1: no ally card to use (or that ally / two allies are already out)", 22, Color(0.6, 0.85, 1.0))
	# potions
	var pc := Color(0.45, 0.95, 0.45)
	if _flash == "potions" and _flash_t > 0.0:
		pc = Color(1, 0.3, 0.3)
	_txt(Vector2(36 + hx, 146), "HP %d   MANA %d" % [m.potions, m.mana_pots], 26, pc)
	if game.key_held:                                   # v0.12.1: the level's key (touch a locked chest)
		_txt(Vector2(250 + hx, 146), "KEY", 26, Color(1.0, 0.82, 0.25))
	if game.run_mode:
		_txt(Vector2(280 + hx, 146), "STAGE %d    LIVES %d    FOES %d" % [game.stage_n, game.lives, maxi(game.quota - game.defeated, 0)], 26, Color(1.0, 0.86, 0.55))
	if _flash == "max" and _flash_t > 0.0:
		_txt(Vector2(260 + hx, 146), "max size is %dx" % m.scale_cap(), 22, Color(1, 0.6, 0.4))
	# stamina (v0.4): bar length grows with the max (60 -> 120)
	var sw := minf(500.0, 330.0 * m.stamina_max / 60.0 * 0.5 + 165.0)
	var sc := Color(0.25, 0.6, 1.0)
	# v0.7 ally cards held
	var cx := 36.0 + hx
	for aid in Allies.IDS:
		var n := int(game.cards.get(aid, 0))
		if n <= 0:
			continue
		var cc: Color = AL.COLORS[aid]
		var box := Rect2(cx, 248, 40, 54)
		ui.draw_rect(box, Color(0.06, 0.05, 0.09))
		_card_portrait(aid, box)
		ui.draw_rect(box, cc, false, 3.0)
		_txt(Vector2(cx + 46, 284), "%d" % n, 24, cc)
		cx += 96.0
	if cx > 36.0 + hx:
		_txt(Vector2(cx + 4, 280), "R1: summon", 20, Color(0.8, 0.85, 0.95))
	if _flash == "stamina" and _flash_t > 0.0:
		sc = Color(1, 0.3, 0.3)
	_txt(Vector2(36 + hx, 194), "MANA", 26, Color(0.6, 0.8, 1.0))
	ui.draw_rect(Rect2(140 + hx, 172, sw, 22), Color(0.04, 0.08, 0.18))
	ui.draw_rect(Rect2(140 + hx, 172, sw * m.stamina / maxf(m.stamina_max, 1.0), 22), sc)
	ui.draw_rect(Rect2(140 + hx, 172, sw, 22), Color(0.05, 0.03, 0.06), false, 3.0)
	_txt(Vector2(150 + sw + hx, 194), "%d/%d" % [int(m.stamina), int(m.stamina_max)], 22, Color(0.75, 0.88, 1.0))
	if _flash == "stamina" and _flash_t > 0.0:
		_txt(Vector2(140 + hx, 236), "not enough mana", 22, Color(1, 0.5, 0.4))
	if _flash.begins_with("pickup:") and _flash_t > 0.0:
		_txt(Vector2(140 + hx, 236), _flash.substr(7), 24, Color(0.6, 0.85, 1.0))
	# state line
	var mk: String = m.mv.get("key", m.state) if m.state == "move" else m.state
	_txt(Vector2(1300, 46), "move: %s   anim: %s f%d" % [mk, m.anim.key, m.anim.idx], 22, Color(0.8, 0.8, 0.85))
	_txt(Vector2(1300, 76), "defeated: %d    %s" % [game.defeated, "volume: pause" if OS.get_name() == "Android" else "F1 / Start: pause"], 22, Color(0.8, 0.8, 0.85))
	var bs = game.boss                                          # untyped: may be a freed instance
	if bs != null and is_instance_valid(bs) and bs.alive():        # v0.6 boss bar
		ui.draw_rect(Rect2(460, 1000, 1000, 34), Color(0.05, 0.02, 0.03, 0.85))
		ui.draw_rect(Rect2(465, 1005, 990.0 * float(bs.hp) / float(bs.hp_max), 24), Color(0.85, 0.15, 0.1))
		if bs.get("size") != null:                                   # v0.8: its size is its health
			var hps := float(bs.hps)
			for i in range(1, int(bs.hp_max / bs.hps)):
				var tx := 465.0 + 990.0 * float(i) * hps / float(bs.hp_max)
				ui.draw_line(Vector2(tx, 1005), Vector2(tx, 1029), Color(0, 0, 0, 0.5), 2.0)
			_txt(Vector2(470, 990), "INFERNAL DRAGON   %dx" % bs.size, 28, Color(1, 0.7, 0.5))
		else:
			_txt(Vector2(470, 990), "INFERNAL DRAGON", 28, Color(1, 0.7, 0.5))
	if m.debug:
		_txt(Vector2(1300, 106), "DEBUG: boxes on, PageUp/PageDown size   x %d" % int(m.global_position.x), 22, Color(1, 1, 0.4))
	if overlay:
		var oo := _origin()
		ui.draw_set_transform(oo, 0.0, Vector2.ONE)
		ui.draw_rect(Rect2(140, 130, 1640, 900), Color(0.03, 0.02, 0.06, 0.92))
		_txt(Vector2(180, 175), "CONTROLS  (pad: Xbox names; PS4: A = Cross, B = Circle, X = Square, Y = Triangle)", 26, Color(1, 0.8, 0.5))
		_txt(Vector2(180, 215), "GAMEPAD", 20, Color(1, 0.75, 0.45))
		_txt(Vector2(530, 215), "KEYBOARD", 20, Color(0.55, 0.85, 1.0))
		for i in CONTROLS.size():
			var y := 250 + i * 35
			var pad_name := String(CONTROLS[i][0])
			if pad_name == "Start" and OS.get_name() == "Android":
				pad_name = "Volume up / down"
			_txt(Vector2(180, y), pad_name, 20, Color(1, 0.75, 0.45))
			_txt(Vector2(530, y), String(CONTROLS[i][1]), 20, Color(0.55, 0.85, 1.0))
			_txt(Vector2(760, y), String(CONTROLS[i][2]), 20)
		ui.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if game.over and game.over_t > 0.9:
		var o := _origin()
		ui.draw_rect(Rect2(Vector2.ZERO, ui.size), Color(0.08, 0, 0.02, minf((game.over_t - 0.9) * 1.5, 0.7)))
		_center(o.y + 520, "GAME OVER", 110, Color(0.95, 0.2, 0.2))
		if game.run_mode and game.run_wiped:
			_center(o.y + 640, "No lives left. The save is gone.   A / Start: title    B: title", 28, Color(0.95, 0.92, 0.88))
		elif game.run_mode:
			_center(o.y + 640, "Back at 2x. One life spent (%d left). Items stay.   A: retry this map    B: title" % game.lives, 28, Color(0.95, 0.92, 0.88))
		else:
			_center(o.y + 640, "Back at 2x. Potions, cards, mana and rage stay.   A / Start: retry    B: level select", 28, Color(0.95, 0.92, 0.88))
	if game.cleared and game.over_t > 0.3 and not game.victory:
		var o2 := _origin()
		ui.draw_rect(Rect2(Vector2.ZERO, ui.size), Color(0.02, 0.02, 0.06, minf(game.over_t * 1.5, 0.65)))
		var last: bool = game.has_method("is_last_level") and game.is_last_level() and not game.run_mode
		_center(o2.y + 500, "JOURNEY COMPLETE" if last else ("STAGE CLEAR" if game.run_mode else "LEVEL CLEAR"), 90, Color(1.0, 0.85, 0.45))
		if game.run_mode:
			_center(o2.y + 620, "Stage %d cleared. Saved. +1 life (%d). Next map has %d foes.   A: continue    B: title" % [game.cleared_stage, game.lives, game.quota], 28, Color(0.95, 0.92, 0.88))
			_center(o2.y + 670, "Upgrades and items come with you. A death with no lives ends the run.", 26, Color(0.8, 0.9, 1.0))
		else:
			_center(o2.y + 620, "A / Start (Z / Enter): level select      B (X): level select" if last else "A / Start (Z / Enter): next level      B (X): level select", 32, Color(0.95, 0.92, 0.88))
			if not last:
				_center(o2.y + 670, "potions, cards, mana and rage come with you. A death returns her to 2x", 26, Color(0.8, 0.9, 1.0))
	if game.paused_play:
		_draw_pause()
	if game.frame_n < 150 and not game.test_mode and not game.paused_play:
		var al := clampf((150 - game.frame_n) / 40.0, 0.0, 1.0)
		if game.run_mode:
			_txt(Vector2(560, 330), "STAGE %d   %s" % [game.stage_n, game.run_title], 54, Color(1, 0.85, 0.5, al))
			_txt(Vector2(620, 380), "%d foes. Clear it for a life." % game.quota, 30, Color(0.9, 0.9, 0.95, al))
		else:
			var lv: Dictionary = Levels.level()
			var o3 := _origin()
			_center(o3.y + 330, "LEVEL %d   %s" % [Levels.current + 1, String(lv["name"])], 54, Color(1, 0.85, 0.5, al))
			_center(o3.y + 400, String(lv["sub"]), 30, Color(0.9, 0.9, 0.95, al))
	if game.victory_card:
		var vt := "You Defeated the Cavern Dragon!"
		ui.draw_string(font, Vector2(4, 504), vt, HORIZONTAL_ALIGNMENT_CENTER, 1920, 64, Color(0, 0, 0, 0.55))
		ui.draw_string(font, Vector2(0, 500), vt, HORIZONTAL_ALIGNMENT_CENTER, 1920, 64, Color(1.0, 0.82, 0.35))


func _center(y: float, t: String, sz: int, c: Color) -> void:
	ui.draw_string(font, Vector2(2, y + 2), t, HORIZONTAL_ALIGNMENT_CENTER, ui.size.x, sz, Color(0, 0, 0, 0.55))
	ui.draw_string(font, Vector2(0, y), t, HORIZONTAL_ALIGNMENT_CENTER, ui.size.x, sz, c)


func _card_portrait(aid: String, box: Rect2) -> void:
	var tex: Texture2D = ROSTER.face(aid)
	if tex == null:
		return
	var inner := Rect2(box.position.x + 3.0, box.position.y + 3.0, box.size.x - 6.0, box.size.y - 6.0)
	var ts := tex.get_size()
	var fit := minf(inner.size.x / maxf(ts.x, 1.0), inner.size.y / maxf(ts.y, 1.0))
	var ds := ts * fit
	var dp := Vector2(inner.position.x + (inner.size.x - ds.x) * 0.5, inner.end.y - ds.y)
	ui.draw_texture_rect(tex, Rect2(dp, ds), false)


func _draw_pause() -> void:
	var o := _origin()
	ui.draw_rect(Rect2(Vector2.ZERO, ui.size), Color(0.0, 0.0, 0.02, 0.72))
	if pause_controls:
		ui.draw_set_transform(o, 0.0, Vector2.ONE)
		ui.draw_rect(Rect2(140, 80, 1640, 920), Color(0.03, 0.02, 0.06, 0.96))
		ui.draw_rect(Rect2(140, 80, 1640, 920), Color(1.0, 0.8, 0.45), false, 4.0)
		_txt(Vector2(180, 130), "CONTROLS", 48, Color(1.0, 0.82, 0.45))
		_txt(Vector2(180, 180), "GAMEPAD", 20, Color(1, 0.75, 0.45))
		_txt(Vector2(530, 180), "KEYBOARD", 20, Color(0.55, 0.85, 1.0))
		for i in CONTROLS.size():
			var y := 214 + i * 30
			var pad_name := String(CONTROLS[i][0])
			if pad_name == "Start" and OS.get_name() == "Android":
				pad_name = "Volume up / down"
			_txt(Vector2(180, y), pad_name, 18, Color(1, 0.75, 0.45))
			_txt(Vector2(530, y), String(CONTROLS[i][1]), 18, Color(0.55, 0.85, 1.0))
			_txt(Vector2(760, y), String(CONTROLS[i][2]), 18)
		_center(o.y + 980, "A / B / Start: back to pause", 26, Color(0.85, 0.85, 0.9))
		ui.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var panel := Rect2(o.x + 520.0, o.y + 220.0, 880.0, 640.0)
	ui.draw_rect(panel, Color(0.06, 0.03, 0.09, 0.96))
	ui.draw_rect(panel, Color(1.0, 0.8, 0.45), false, 4.0)
	_center(o.y + 300, "PAUSED", 72, Color(1.0, 0.82, 0.45))
	for i in PAUSE_ITEMS.size():
		var r := _pause_item(i)
		var on := i == pause_sel
		ui.draw_rect(r, Color(0.28, 0.14, 0.05, 0.95) if on else Color(0.1, 0.06, 0.14, 0.9))
		ui.draw_rect(r, Color(1.0, 0.82, 0.4) if on else Color(0.45, 0.4, 0.55), false, 3.0)
		ui.draw_string(font, Vector2(r.position.x, r.position.y + 40), PAUSE_ITEMS[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, Color(1, 0.92, 0.65) if on else Color(0.88, 0.88, 0.92))
	_center(o.y + 800, "Up / Down: choose     A: confirm     B / Start: continue", 26, Color(0.85, 0.85, 0.9))
