extends CanvasLayer
## HUD: size (= HP) pips, rage / Fury meter, potions, current move, Fury timer, controls overlay, Game Over.

var game: Node = null
var overlay := false
var ui := Control.new()
var font: Font
var _flash := ""
var _flash_t := 0.0

## [gamepad (Xbox names), keyboard (v0.8 PC layout, Controls.MAP), what it does]
const CONTROLS := [
	["D-pad / left stick", "arrows", "walk left / right, Up = jump, Down = crouch"],
	["A (hold) + direction", "Z (hold) + arrow", "run      (Down + A = slide)"],
	["B", "X", "back dodge (free)   B then X = dodge attack   B then Y = FAST quick fire"],
	["B+Y together", "X+S", "rising slash (fast windup), no dodge (free)    Y again during it = slam (free)"],
	["X", "A", "1x attack.  X X X = 1x 2x 2x-2,  X X hold X = 1x 2x 2x-1"],
	["X X Y", "A A S", "1x 2x 3x (with slash)     X X X Y = combo into beam, 20 mana"],
	["Y", "S", "quick fire (bolt) 5 mana     X+Y together = rear explosion 12 mana"],
	["A+Y / Y while running", "Z+S", "ground dash (aerial dash animation), 6 mana"],
	["In the air", "", "X = jump attack (X again: 2nd hit), Y = aerial dash 6 mana, Up = double jump"],
	["Down + Y (crouching)", "Down + S", "EARTHQUAKE: 1 s quake, grounded enemies stunned 5 s (20 mana)"],
	["L1", "Q", "heal: drink a green potion, +1 size (max 6x), plays at 4x"],
	["L2", "1", "full bubble while held (3 mana + 4/s). L1 drinks without dropping it"],
	["L2 + R2 (100 rage)", "1 + 2", "lightning from the sky (AOE). Costs 100 rage"],
	["R2 (100 rage)", "2", "Fury for 12 s. Costs 100 rage. In Fury, R2 takes off / lands"],
	["Down hold", "Down hold", "small bubble, 3 s, subtracts 1 damage. L1 drinks without dropping it"],
	["X just as a shot arrives", "A just as a shot arrives", "reflect it (within 0.15 s of the hitbox): flies back and hurts them"],
	["L2 just before a hit", "1 just before", "PARRY (within 0.15 s): no damage, attacker staggered and knocked back, shots fly back, x2 counter"],
	["Any button in a bubble", "", "drops that bubble and does the move. L1 drinks and the bubble stays"],
	["L1+R1+L2+R2 (100 rage)", "Q+W+1+2", "freeze slash: mark up to 9 enemies, cut each for 3. Costs 100 rage"],
	["R1", "W", "summon an ally (needs an ally card; several cards: picker)"],
	["Fury flight", "arrows", "8-way move, Down on the ground lands, R2 lands"],
	["Start", "Enter / F1", "pause (game freezes) and this overlay; again to resume. Restarts after Game Over"],
	["Back (Share)", "Tab / G", "animation gallery (Left/Right: previous/next, A: replay)"],
	["-", "F2", "debug: hit/hurt boxes, PageUp/PageDown or right stick = size 1x-19x"],
	["Menus", "arrows, Z ok, X back", "level select, ally picker, level clear / Game Over (Esc quits, F11 fullscreen)"],
]


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
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


## v0.9.1: while the game is paused the rest of the tree is frozen, so Start comes through here
func _unhandled_input(event: InputEvent) -> void:
	if game == null or not game.paused_play or event.is_echo():
		return
	if event.is_action_pressed("start"):
		game.toggle_pause()
		get_viewport().set_input_as_handled()


func _txt(p: Vector2, t: String, sz: int = 28, c: Color = Color(0.95, 0.92, 0.88)) -> void:
	ui.draw_string(font, p + Vector2(2, 2), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.7))
	ui.draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)


func _draw_ui() -> void:
	if game == null:
		return
	var m: Mera = game.mera
	# size = HP
	ui.draw_rect(Rect2(20, 16, 560, 196), Color(0.04, 0.03, 0.07, 0.55))
	_txt(Vector2(36, 52), "SIZE  %dx" % m.size, 34)
	for i in 6:
		var on := i < m.size
		var r := Rect2(210 + i * 56, 26, 46, 30)
		ui.draw_rect(r, Color(0.98, 0.66, 0.33) if on else Color(0.2, 0.16, 0.22))
		ui.draw_rect(r, Color(0.05, 0.03, 0.06), false, 3.0)
	if m.size > 6:
		_txt(Vector2(552, 52), "+%d" % (m.size - 6), 22)
	# rage / fury
	_txt(Vector2(36, 100), "FURY" if m.fury else "RAGE", 26, Color(1, 0.35, 0.3) if m.fury else Color(0.95, 0.92, 0.88))
	var w := 330.0
	ui.draw_rect(Rect2(140, 78, w, 26), Color(0.15, 0.03, 0.06))
	var fc := Color(0.86, 0.08, 0.12) if m.fury else (Color(1.0, 0.25, 0.2) if m.rage >= 100.0 else Color(0.7, 0.12, 0.14))
	var rage_frac := (m.fury_left / Mera.FURY_TIME) if m.fury else (m.rage / maxf(m.rage_max, 1.0))
	ui.draw_rect(Rect2(140, 78, w * clampf(rage_frac, 0.0, 1.0), 26), fc)
	ui.draw_rect(Rect2(140, 78, w, 26), Color(0.05, 0.03, 0.06), false, 3.0)
	_txt(Vector2(482, 100), ("%d/%d" % [int(m.rage), int(m.rage_max)]), 24)
	if m.rage >= 100.0 and not m.fury and int(Time.get_ticks_msec() / 300) % 2 == 0:
		_txt(Vector2(140, 136), "R2 FURY   ·   L2+R2 LIGHTNING   ·   Q+W+1+2 SLASH", 22, Color(1, 0.3, 0.25))
	if _flash == "rage" and _flash_t > 0.0:
		_txt(Vector2(200, 146), "Fury, lightning and the freeze slash each need 100 rage", 22, Color(1, 0.5, 0.4))
	if _flash == "fury_chord" and _flash_t > 0.0:
		_txt(Vector2(260, 146), "Fury is L2 + R2 together", 22, Color(1, 0.6, 0.4))
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
	_txt(Vector2(36, 146), "POTIONS  %d" % m.potions, 26, pc)
	if _flash == "max" and _flash_t > 0.0:
		_txt(Vector2(260, 146), "max size for potions is 6x", 22, Color(1, 0.6, 0.4))
	# stamina (v0.4): bar length grows with the max (60 -> 120)
	var sw := minf(500.0, 330.0 * m.stamina_max / 60.0 * 0.5 + 165.0)
	var sc := Color(0.25, 0.6, 1.0)
	# v0.7 ally cards held
	var cx := 36.0
	for aid in Allies.IDS:
		var n := int(game.cards.get(aid, 0))
		if n <= 0:
			continue
		var cc: Color = Allies.COLORS[aid]
		ui.draw_rect(Rect2(cx, 250, 26, 36), Color(0.06, 0.05, 0.09))
		ui.draw_rect(Rect2(cx, 250, 26, 36), cc, false, 4.0)
		_txt(Vector2(cx + 32, 280), "%d" % n, 24, cc)
		cx += 76.0
	if cx > 36.0:
		_txt(Vector2(cx + 4, 280), "R1: summon", 20, Color(0.8, 0.85, 0.95))
	if _flash == "stamina" and _flash_t > 0.0:
		sc = Color(1, 0.3, 0.3)
	_txt(Vector2(36, 194), "MANA", 26, Color(0.6, 0.8, 1.0))
	ui.draw_rect(Rect2(140, 172, sw, 22), Color(0.04, 0.08, 0.18))
	ui.draw_rect(Rect2(140, 172, sw * m.stamina / maxf(m.stamina_max, 1.0), 22), sc)
	ui.draw_rect(Rect2(140, 172, sw, 22), Color(0.05, 0.03, 0.06), false, 3.0)
	_txt(Vector2(150 + sw, 194), "%d/%d" % [int(m.stamina), int(m.stamina_max)], 22, Color(0.75, 0.88, 1.0))
	if _flash == "stamina" and _flash_t > 0.0:
		_txt(Vector2(140, 236), "not enough mana", 22, Color(1, 0.5, 0.4))
	if _flash.begins_with("pickup:") and _flash_t > 0.0:
		_txt(Vector2(140, 236), _flash.substr(7), 24, Color(0.6, 0.85, 1.0))
	# state line
	var mk: String = m.mv.get("key", m.state) if m.state == "move" else m.state
	_txt(Vector2(1300, 46), "move: %s   anim: %s f%d" % [mk, m.anim.key, m.anim.idx], 22, Color(0.8, 0.8, 0.85))
	_txt(Vector2(1300, 76), "defeated: %d    F1 / Start: controls" % game.defeated, 22, Color(0.8, 0.8, 0.85))
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
	if m.state == "gallery":
		var ks: Array = AnimLib.keys()
		_txt(Vector2(660, 150), "GALLERY  %d/%d  %s   (Left/Right, A replay, Back/Tab exit)" % [m.gallery_idx + 1, ks.size(), ks[m.gallery_idx]], 30, Color(1, 0.85, 0.5))
	if m.debug:
		_txt(Vector2(1300, 106), "DEBUG: boxes on, PageUp/PageDown size   x %d" % int(m.global_position.x), 22, Color(1, 1, 0.4))
	if overlay:
		ui.draw_rect(Rect2(140, 130, 1640, 900), Color(0.03, 0.02, 0.06, 0.9))
		_txt(Vector2(180, 175), "CONTROLS  (pad: Xbox names; PS4: A = Cross, B = Circle, X = Square, Y = Triangle)", 26, Color(1, 0.8, 0.5))
		_txt(Vector2(180, 215), "GAMEPAD", 20, Color(1, 0.75, 0.45))
		_txt(Vector2(530, 215), "KEYBOARD", 20, Color(0.55, 0.85, 1.0))
		for i in CONTROLS.size():
			var y := 250 + i * 35
			_txt(Vector2(180, y), String(CONTROLS[i][0]), 20, Color(1, 0.75, 0.45))
			_txt(Vector2(530, y), String(CONTROLS[i][1]), 20, Color(0.55, 0.85, 1.0))
			_txt(Vector2(760, y), String(CONTROLS[i][2]), 20)
	if game.over and game.over_t > 0.9:
		ui.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.08, 0, 0.02, minf((game.over_t - 0.9) * 1.5, 0.7)))
		_txt(Vector2(700, 520), "GAME OVER", 110, Color(0.95, 0.2, 0.2))
		_txt(Vector2(360, 600), "Back at 2x. Potions, cards, mana and rage stay.   A / Start: retry    B: level select", 28)
	if game.cleared and game.over_t > 0.3:
		ui.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.02, 0.02, 0.06, minf(game.over_t * 1.5, 0.65)))
		var last: bool = game.has_method("is_last_level") and game.is_last_level()
		_txt(Vector2(640, 500), "JOURNEY COMPLETE" if last else "LEVEL CLEAR", 90, Color(1.0, 0.85, 0.45))
		_txt(Vector2(470, 590), "A / Start (Z / Enter): level select      B (X): level select" if last else "A / Start (Z / Enter): next level      B (X): level select", 32)
		if not last:
			_txt(Vector2(380, 640), "potions, cards, mana and rage come with you. A death returns her to 2x", 28, Color(0.8, 0.9, 1.0))
	if game.frame_n < 150 and not game.test_mode:
		var lv: Dictionary = Levels.level()
		var al := clampf((150 - game.frame_n) / 40.0, 0.0, 1.0)
		_txt(Vector2(700, 330), "LEVEL %d   %s" % [Levels.current + 1, String(lv["name"])], 54, Color(1, 0.85, 0.5, al))
		_txt(Vector2(760, 380), String(lv["sub"]), 30, Color(0.9, 0.9, 0.95, al))
