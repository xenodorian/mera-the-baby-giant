extends "res://scripts/game/enemy_shot.gd"
## Stage 3 drawn projectiles (no art needed, so nothing to cut): the Mud Revenant's lobbed mud blob and the Weaver's
## spinning bone. Same hit rules as enemy_shot.gd (Mera, allies, props, parry / deflect), plus the mud's landing splash.

const GRAVITY_MUD := 1500.0
const FLIGHT := 0.95                  # seconds a mud blob spends in the air

var kind := "bone"
var art: Node2D
var spin := 0.0
var landed := false


## kind "mud": lobbed so it lands at target_x on the ground. kind "bone": flies straight along v.
func setup_drawn(g: Node, what: String, p: Vector2, v: Vector2, damage: int, scale_k: float, target_x: float = 0.0) -> void:
	game = g
	kind = what
	dmg = damage
	k = scale_k
	position = p
	vel = v
	if kind == "mud":
		var gy: float = float(g.GROUND_Y) - 30.0
		vel = Vector2((target_x - p.x) / FLIGHT, (gy - p.y) / FLIGHT - 0.5 * GRAVITY_MUD * FLIGHT)
		size_px = Vector2(6.0, 6.0) * k
	else:
		size_px = Vector2(13.0, 3.0) * k
	art = Node2D.new()
	art.draw.connect(_draw_art)
	add_child(art)


func _draw_art() -> void:
	if kind == "mud":
		var r := 3.2 * k
		art.draw_circle(Vector2.ZERO, r, Color(0.23, 0.15, 0.08))
		art.draw_circle(Vector2(-r * 0.25, -r * 0.2), r * 0.72, Color(0.36, 0.24, 0.12))
		art.draw_circle(Vector2(-r * 0.4, -r * 0.4), r * 0.22, Color(0.55, 0.4, 0.22))
		art.draw_circle(Vector2(r * 0.9, r * 0.3), r * 0.28, Color(0.23, 0.15, 0.08))
	else:
		var w := 6.0 * k
		var t := 0.8 * k
		var c := Color(0.93, 0.9, 0.8)
		var sh := Color(0.62, 0.58, 0.48)
		art.draw_line(Vector2(-w, 0), Vector2(w, 0), sh, t * 1.5)
		art.draw_line(Vector2(-w, 0), Vector2(w, 0), c, t)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				art.draw_circle(Vector2(sx * w, sy * t * 0.8), t * 0.95, c)


func _physics_process(delta: float) -> void:
	if art:
		if kind == "bone":
			spin += delta * 9.0
			art.rotation = spin
		if deflected:
			art.modulate = Color(1.6, 1.4, 0.8)
	if kind == "mud" and not deflected:
		vel.y += GRAVITY_MUD * delta
	super(delta)
	if kind == "mud" and not deflected and not is_queued_for_deletion() and game != null and position.y >= float(game.GROUND_Y) - 24.0 and vel.y > 0.0:
		_splash()


## the blob hits the ground: a wide splash that hurts whoever stands in it, then a fading puddle
func _splash() -> void:
	landed = true
	var r := Rect2(position.x - 4.0 * k * 2.2, float(game.GROUND_Y) - 90.0, 4.0 * k * 4.4, 100.0)
	var m: Node2D = game.mera
	if m.state != "dead" and r.intersects(m.hurt_rect()):
		m.take_hit(dmg, position.x, shooter if is_instance_valid(shooter) else null)
		if is_instance_valid(shooter):
			shooter.hits_landed += 1
	if game.has_method("allies"):
		for a in game.allies():
			if a.alive() and r.intersects(a.hurt_rect()):
				a.take_hit(dmg, position.x)
	var pud := Node2D.new()
	pud.position = Vector2(position.x, float(game.GROUND_Y) - 4.0)
	var rad := 4.0 * k * 2.0
	pud.draw.connect(func() -> void:
		pud.draw_circle(Vector2(0, 0), rad * 0.5, Color(0.23, 0.15, 0.08, 0.9))
		pud.draw_rect(Rect2(-rad, -6, rad * 2.0, 10), Color(0.3, 0.2, 0.1, 0.9))
		pud.draw_circle(Vector2(-rad * 0.5, -8), rad * 0.2, Color(0.4, 0.28, 0.14)))
	get_parent().add_child(pud)
	var tw := pud.create_tween()
	tw.tween_property(pud, "modulate:a", 0.0, 0.7)
	tw.tween_callback(pud.queue_free)
	if game.has_method("shake"):
		game.shake(3.0, 0.08)
	queue_free()
