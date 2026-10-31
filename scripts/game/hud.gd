extends CanvasLayer
## HUD: size (= HP) pips, rage / Fury meter, potions, current move, Fury timer, controls overlay, Game Over.

var game: Node = null
var overlay := false
var ui := Control.new()
var font: Font
var _flash := ""
var _flash_t := 0.0

const CONTROLS := [
	["D-pad / left stick", "walk left / right, Up = jump, Down = crouch"],
	["A (hold) + direction", "run      (Down + A = slide)"],
	["B", "back dodge     B then X = dodge attack (X, X again: rising slash, slam)"],
	["X", "1x attack.  X X X = 1x 2x 2x-2,  X X hold X = 1x 2x 2x-1"],
	["X X Y", "1x 2x 3x (with slash)     X X X Y = combo into beam (Y within 0.3 s of the 3rd X)"],
	["Y", "quick fire (bolt)     X+Y together = rear explosion"],
	["A+Y together / Y while running", "ground dash (aerial dash animation)"],
	["In the air", "X = jump attack (X again: 2nd hit), Y = aerial dash, Up = double jump"],
	["L1", "heal: drink a green potion, +1 size (max 6x)"],
	["R1 (rage 100 %)", "heal pose + lightning strike from the sky (AOE), uses the whole meter"],
	["L2 (hold)", "heal pose + spherical barrier, blocks hits while held (R1 works inside)"],
	["R2 (rage 100 %)", "Fury: red aura, red spells, flight (Up in the air / R2 again)"],
	["Fury flight", "8-way move, Down on the ground lands, R2 lands"],
	["Start / Enter / F1", "this overlay (and restart after Game Over)"],
	["Back(Share) / Tab / G", "animation gallery (Left/Right: previous/next, A: replay)"],
	["F2", "debug: hit/hurt boxes, PageUp/PageDown or right stick = size 1x-19x"],
	["Keyboard", "arrows/WASD move, Shift A, L B, J X, K Y, U L1, I R1, O L2, P R2"],
]


func _ready() -> void:
	layer = 20
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


func _txt(p: Vector2, t: String, sz: int = 28, c: Color = Color(0.95, 0.92, 0.88)) -> void:
	ui.draw_string(font, p + Vector2(2, 2), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.7))
	ui.draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, c)


func _draw_ui() -> void:
	if game == null:
		return
	var m: Mera = game.mera
	# size = HP
	ui.draw_rect(Rect2(20, 16, 560, 150), Color(0.04, 0.03, 0.07, 0.55))
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
	ui.draw_rect(Rect2(140, 78, w * m.rage / 100.0, 26), fc)
	ui.draw_rect(Rect2(140, 78, w, 26), Color(0.05, 0.03, 0.06), false, 3.0)
	_txt(Vector2(482, 100), "%d%%" % int(m.rage), 24)
	if m.rage >= 100.0 and not m.fury and int(Time.get_ticks_msec() / 300) % 2 == 0:
		_txt(Vector2(140, 136), "R2: FURY!   or   R1: LIGHTNING", 24, Color(1, 0.3, 0.25))
	if _flash == "rage" and _flash_t > 0.0:
		_txt(Vector2(260, 146), "R1 lightning needs a full meter (not in Fury)", 22, Color(1, 0.5, 0.4))
	# potions
	var pc := Color(0.45, 0.95, 0.45)
	if _flash == "potions" and _flash_t > 0.0:
		pc = Color(1, 0.3, 0.3)
	_txt(Vector2(36, 146), "POTIONS  %d" % m.potions, 26, pc)
	if _flash == "max" and _flash_t > 0.0:
		_txt(Vector2(260, 146), "max size for potions is 6x", 22, Color(1, 0.6, 0.4))
	# state line
	var mk: String = m.mv.get("key", m.state) if m.state == "move" else m.state
	_txt(Vector2(1300, 46), "move: %s   anim: %s f%d" % [mk, m.anim.key, m.anim.idx], 22, Color(0.8, 0.8, 0.85))
	_txt(Vector2(1300, 76), "knights defeated: %d    F1 / Start: controls" % game.defeated, 22, Color(0.8, 0.8, 0.85))
	if m.state == "gallery":
		var ks: Array = AnimLib.keys()
		_txt(Vector2(660, 150), "GALLERY  %d/%d  %s   (Left/Right, A replay, Back/Tab exit)" % [m.gallery_idx + 1, ks.size(), ks[m.gallery_idx]], 30, Color(1, 0.85, 0.5))
	if m.debug:
		_txt(Vector2(1300, 106), "DEBUG: boxes on, PageUp/PageDown size   x %d" % int(m.global_position.x), 22, Color(1, 1, 0.4))
	if overlay:
		ui.draw_rect(Rect2(260, 190, 1400, 760), Color(0.03, 0.02, 0.06, 0.88))
		_txt(Vector2(300, 240), "CONTROLS  (Xbox names; PS4: A = Cross, B = Circle, X = Square, Y = Triangle)", 28, Color(1, 0.8, 0.5))
		for i in CONTROLS.size():
			_txt(Vector2(300, 290 + i * 38), String(CONTROLS[i][0]), 24, Color(1, 0.75, 0.45))
			_txt(Vector2(720, 290 + i * 38), String(CONTROLS[i][1]), 24)
	if game.over and game.over_t > 0.9:
		ui.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.08, 0, 0.02, minf((game.over_t - 0.9) * 1.5, 0.7)))
		_txt(Vector2(700, 520), "GAME OVER", 110, Color(0.95, 0.2, 0.2))
		_txt(Vector2(720, 600), "Mera was hit at 1x.   Start / Enter: restart", 30)
