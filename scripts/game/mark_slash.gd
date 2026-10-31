extends Node2D
## Fury mark (Q+W+1+2, or L1+R1+L2+R2). Up to 9 enemies get a unique 1-9. Keyboard shows the digit.
## A pad, the numpad or a touch shows the matching arrow (5 is a dot: R3, numpad 5, or a tap).
## The matching input draws a slash over that enemy, plays the slice, and deals Tuning.MARK_DMG flat.

var game: Node = null
var on := false
var arrows := false
var left := 0.0
var marks: Array = []          # {e, n, done}
var slashes: Array = []        # {p, d, t}
var slashed := 0
var font: Font


func _ready() -> void:
	z_index = 80
	font = ThemeDB.fallback_font


func open(pool: Array, scheme_arrows: bool) -> void:
	marks.clear()
	slashes.clear()
	slashed = 0
	arrows = scheme_arrows
	var bag := [1, 2, 3, 4, 5, 6, 7, 8, 9]
	bag.shuffle()
	for i in mini(pool.size(), 9):
		marks.append({"e": pool[i], "n": bag[i], "done": false})
	left = Tuning.MARK_S
	on = true
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not on and slashes.is_empty():
		return
	if on:
		left -= delta
		var n := Controls.consume_digit()
		if n == 0:
			n = Controls.consume_flick()
		if n == 0 and Controls.consume_r3():
			n = 5
		if n != 0:
			_hit(n)
		var waiting := false
		for m in marks:
			if not m["done"] and is_instance_valid(m["e"]) and m["e"].alive():
				waiting = true
		if not waiting or left <= 0.0:
			_finish()
	var keep: Array = []
	for s in slashes:
		s["t"] -= delta
		if float(s["t"]) > 0.0:
			keep.append(s)
	slashes = keep
	queue_redraw()


func _hit(n: int) -> void:
	for m in marks:
		if m["done"] or int(m["n"]) != n:
			continue
		m["done"] = true
		var e: Node2D = m["e"]
		if not is_instance_valid(e) or not e.alive():
			return
		e.take_damage(Tuning.MARK_DMG, e.global_position.x, "melee")
		Sfx.play("swipe")
		var d := Controls.vector_for(n)
		if d == Vector2.ZERO:
			d = Vector2(0.7, -0.7)
		slashes.append({"p": e.hurt_rect().get_center(), "d": d.normalized(), "t": 0.35})
		slashed += 1
		return


func _finish() -> void:
	on = false
	if game:
		game.end_mark()
	queue_redraw()


func _draw() -> void:
	if not on and slashes.is_empty():
		return
	for m in marks:
		if m["done"] or not is_instance_valid(m["e"]) or not m["e"].alive():
			continue
		var r: Rect2 = m["e"].hurt_rect()
		var p := Vector2(r.get_center().x, r.position.y - 28.0)
		if arrows:
			_arrow(p, int(m["n"]))
		else:
			_num(p, int(m["n"]))
	for s in slashes:
		var a := float(s["t"]) / 0.35
		var d: Vector2 = s["d"]
		var c: Vector2 = s["p"]
		var col := Color(0.55, 1.0, 0.9, a)
		draw_line(c - d * 70.0, c + d * 78.0, col, 8.0)
		draw_line(c - d * 40.0 + Vector2(-d.y, d.x) * 16.0, c + d * 20.0, Color(1, 1, 1, a), 3.0)


func _num(p: Vector2, n: int) -> void:
	var s := str(n)
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		draw_string(font, p + o + Vector2(-18, 14), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color(0.05, 0.02, 0.04))
	draw_string(font, p + Vector2(-18, 14), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color(1, 0.95, 0.9))


func _arrow(p: Vector2, n: int) -> void:
	if n == 5:
		draw_circle(p, 8.0, Color(1, 0.95, 0.9))
		draw_arc(p, 16.0, 0, TAU, 18, Color(1, 0.35, 0.28), 3.0)
		return
	var v := Controls.vector_for(n).normalized()
	var tip := p + v * 26.0
	draw_line(p - v * 18.0, tip, Color(1, 0.95, 0.9), 4.0)
	var side := Vector2(-v.y, v.x) * 9.0
	draw_colored_polygon(PackedVector2Array([tip + v * 14.0, tip - v * 4.0 + side, tip - v * 4.0 - side]), Color(1, 0.35, 0.28))
