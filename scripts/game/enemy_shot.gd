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


## v0.8: sent back toward whoever shot it (or straight back), faster, and with a fresh lifetime
func deflect() -> void:
	deflected = true
	t = 0.0
	var sp := vel.length() * Tuning.DEFLECT_SPEED
	if is_instance_valid(shooter) and shooter.alive():
		vel = (shooter.hurt_rect().get_center() - global_position).normalized() * sp
	else:
		vel = -vel.normalized() * sp
	spr.scale.x = -spr.scale.x
	spr.modulate = Color(1.6, 1.4, 0.8)
