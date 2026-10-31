extends Node2D
## v0.6 enemy projectile (the hell beast's fireball). Flies straight, hurts Mera once on contact (the barrier
## blocks it: Mera.take_hit ignores hits while the bubble is up), dies on contact or after LIFE seconds.

const LIFE := 3.0
var game: Node
var vel := Vector2.ZERO
var dmg := 1
var t := 0.0
var spr: AnimatedSprite2D
var k := 4.0
var size_px := Vector2(16, 12)
var deflected := false
var shooter: Node = null


func setup(g: Node, enemy_id: String, anim: String, p: Vector2, v: Vector2, damage: int, scale_k: float) -> void:
	game = g
	vel = v
	dmg = damage
	k = scale_k
	position = p
	var ROSTER := load("res://scripts/game/roster.gd")
	var e: Dictionary = ROSTER.art(enemy_id)["anims"][anim]
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", float(e["fps"]))
	for f in e["frames"]:
		sf.add_frame("default", load(f))
	spr = AnimatedSprite2D.new()
	spr.sprite_frames = sf
	var nf := int(ROSTER.art(enemy_id)["facing"])
	spr.scale = Vector2(k * (1.0 if signf(v.x) == float(nf) else -1.0), k)
	add_child(spr)
	spr.play("default")
	size_px = Vector2(float(e["size"][0]), float(e["size"][1])) * k * 0.7


func rect() -> Rect2:
	return Rect2(global_position - size_px / 2.0, size_px)


func _physics_process(delta: float) -> void:
	t += delta
	position += vel * delta
	if t > LIFE:
		queue_free()
		return
	if game == null:
		return
	if deflected:                       # v0.8 parried: flies back and hurts the first enemy it meets
		for e in game.enemies():
			if e.alive() and rect().intersects(e.hurt_rect()):
				e.take_damage(Tuning.DEFLECT_DMG, global_position.x - signf(vel.x) * 50.0, "bolt")
				game.hit_spark(global_position, 3.0)
				HitStop.stop(Tuning.HITSTOP_HEAVY_MS)
				Sfx.play("hit_heavy", 1.1)
				queue_free()
				return
		var bounced: Node2D = game.prop_at(rect())
		if bounced != null:
			bounced.take_damage(Tuning.DEFLECT_DMG, global_position.x, "bolt")
			game.hit_spark(global_position, 3.0)
			queue_free()
		return
	var m: Node2D = game.mera
	if m.state != "dead" and rect().intersects(m.hurt_rect()):
		if m.has_method("try_parry_shot") and m.try_parry_shot(self):
			deflect()
			return
		m.take_hit(dmg, global_position.x, shooter if is_instance_valid(shooter) else null)
		if is_instance_valid(shooter):
			shooter.hits_landed += 1
		queue_free()
		return
	if game.has_method("allies"):
		for a in game.allies():
			if a.alive() and rect().intersects(a.hurt_rect()):
				a.take_hit(dmg, global_position.x)
				if is_instance_valid(shooter):
					shooter.hits_landed += 1
				queue_free()
				return
	var pr: Node2D = game.prop_at(rect())
	if pr != null:
		pr.take_damage(dmg, global_position.x, "bolt")
		game.hit_spark(pr.hurt_rect().get_center(), 2.0)
		queue_free()


## v0.8: sent back toward whoever shot it (or the nearest enemy), faster, and with a fresh lifetime
func deflect() -> void:
	deflected = true
	t = 0.0
	var sp := maxf(vel.length(), 280.0) * Tuning.DEFLECT_SPEED
	var aim: Node = shooter if is_instance_valid(shooter) and shooter.has_method("alive") and shooter.alive() else _nearest_enemy()
	if aim != null:
		vel = (aim.hurt_rect().get_center() - global_position).normalized() * sp
	else:
		vel = (-vel.normalized() if vel.length() > 1.0 else Vector2(-1, 0)) * sp
	if spr:
		spr.scale.x = -spr.scale.x
		spr.modulate = Color(1.6, 1.4, 0.8)


func _nearest_enemy() -> Node:
	var best: Node = null
	var best_d := 1.0e20
	if game == null:
		return null
	for e in game.enemies():
		if not e.alive():
			continue
		var d := global_position.distance_squared_to(e.hurt_rect().get_center())
		if d < best_d:
			best_d = d
			best = e
	return best


## v0.9.1: met a player shot or a beam. Explodes; does not hurt Mera.
func pop_clash() -> void:
	if game:
		game.explode(global_position, 1.1, false)
	queue_free()
