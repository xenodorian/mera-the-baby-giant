class_name Ladder
extends Node2D
## A climbable ladder (Stage 3 phase 4). Built by Game.build_ladder() at run time (ttl > 0, fades out) or from a level's
## "ladders" array (ttl 0, permanent). The node sits at (x, top_y) and draws down to bottom_y. Everything that climbs
## (Mera, Perry, allies, enemies) asks Ladder.nearest(game, x, y) and moves with Ladder.climb_step().

var game: Node = null
var top_y := 0.0
var bottom_y := 0.0
var ttl := 25.0
var age := 0.0


static func make(g: Node, x: float, bottom: float, top: float, life: float) -> Ladder:
	var l := Ladder.new()
	l.game = g
	l.top_y = minf(top, bottom)
	l.bottom_y = maxf(top, bottom)
	l.ttl = life
	l.position = Vector2(x, l.top_y)
	l.z_index = -1
	g.add_child(l)
	g.ladders.append(l)
	return l


## a ladder whose column holds x (within Tuning.LADDER_GRAB_PX) and whose span holds y (pad px of slack at both ends)
static func nearest(g: Node, x: float, y: float, pad: float = 6.0) -> Ladder:
	var best: Ladder = null
	var bd := Tuning.LADDER_GRAB_PX + 0.01
	if g == null or g.get("ladders") == null:
		return null
	for l in g.ladders:
		if not is_instance_valid(l) or l.is_queued_for_deletion():
			continue
		var d := absf(l.global_position.x - x)
		if d <= bd and y >= l.top_y - pad and y <= l.bottom_y + pad:
			best = l
			bd = d
	return best


## Move any Node2D along a ladder: dir -1 up, +1 down, 0 holds. The body is pulled onto the ladder's column. Returns -1 when
## it is at the top, +1 at the bottom, 0 between. The caller decides what happens at an end (step onto the surface, fall).
static func climb_step(body: Node2D, ladder: Node2D, dir: int, delta: float, speed: float) -> int:
	var p := body.global_position
	p.x = move_toward(p.x, ladder.global_position.x, 900.0 * delta)
	p.y = clampf(p.y + float(dir) * speed * delta, ladder.top_y, ladder.bottom_y)
	body.global_position = p
	if p.y <= ladder.top_y + 0.01:
		return -1
	if p.y >= ladder.bottom_y - 0.01:
		return 1
	return 0


func _physics_process(delta: float) -> void:
	if ttl <= 0.0:
		return
	age += delta
	var left := ttl - age
	if left <= 0.0:
		queue_free()
	elif left < Tuning.PLATFORM_FADE_S:
		modulate.a = left / Tuning.PLATFORM_FADE_S
		scale.y = lerpf(0.6, 1.0, left / Tuning.PLATFORM_FADE_S)


func _exit_tree() -> void:
	if game != null and is_instance_valid(game) and game.get("ladders") != null:
		game.ladders.erase(self)


func _draw() -> void:
	var h := bottom_y - top_y
	var wood := Color8(139, 94, 52)
	var dark := Color8(84, 52, 28)
	var hw := 17.0
	draw_rect(Rect2(-hw - 4.0, 0.0, 8.0, h), wood)
	draw_rect(Rect2(hw - 4.0, 0.0, 8.0, h), wood)
	draw_rect(Rect2(-hw - 4.0, 0.0, 2.0, h), dark)
	draw_rect(Rect2(hw - 4.0, 0.0, 2.0, h), dark)
	var y := 14.0
	while y < h:
		draw_rect(Rect2(-hw, y, hw * 2.0, 6.0), wood)
		draw_rect(Rect2(-hw, y + 4.0, hw * 2.0, 2.0), dark)
		y += 32.0
