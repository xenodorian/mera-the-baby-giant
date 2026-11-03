extends Node2D
## Stage 3: a low floor shockwave from the Warlord's jump slam. Rolls along the ground, hurts Mera (and allies) once
## unless they are in the air, and dies at the map edge or after LIFE seconds. Jump it.

const LIFE := 1.8
const SPEED := 640.0
var game: Node
var dir := 1.0
var dmg := 2
var shooter: Node = null
var t := 0.0
var hit_mera := false
var hit_ids := {}


func setup(g: Node, x: float, d: float, damage: int, from: Node) -> void:
	game = g
	dir = d
	dmg = damage
	shooter = from
	position = Vector2(x, float(g.GROUND_Y))
	z_index = 3


func rect() -> Rect2:
	return Rect2(global_position.x - 50.0, global_position.y - 70.0, 100.0, 70.0)


func _physics_process(delta: float) -> void:
	t += delta
	position.x += dir * SPEED * delta
	queue_redraw()
	if t > LIFE or position.x < Levels.EDGE - 60.0 or position.x > float(game.map_w) - Levels.EDGE + 60.0:
		queue_free()
		return
	var m: Node2D = game.mera
	if not hit_mera and m.state != "dead" and rect().intersects(m.hurt_rect()):
		hit_mera = true
		m.take_hit(dmg, global_position.x - dir * 40.0, shooter if is_instance_valid(shooter) else null)
		if is_instance_valid(shooter):
			shooter.hits_landed += 1
	if game.has_method("allies"):
		for a in game.allies():
			if not hit_ids.has(a.get_instance_id()) and a.hit_by(rect(), shooter):
				hit_ids[a.get_instance_id()] = true
				a.take_hit(dmg, global_position.x, shooter)


func _draw() -> void:
	var fade := clampf((LIFE - t) / 0.5, 0.0, 1.0)
	var c := Color(1.0, 0.82, 0.4, 0.9 * fade)
	var pts := PackedVector2Array([Vector2(-dir * 80.0, 0), Vector2(-dir * 20.0, -28.0), Vector2(dir * 10.0, -70.0), Vector2(dir * 40.0, -20.0), Vector2(dir * 50.0, 0)])
	draw_colored_polygon(pts, c)
	draw_polyline(pts, Color(1.0, 1.0, 0.85, fade), 4.0)
