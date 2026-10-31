extends Node2D
## v0.7 Leaf Ranger arrow: the chierit arrow sprite flies straight; on an enemy it plays arrow_hit and deals damage.

const SPEED := 1500.0
var game: Node
var owner_ally: Node
var dir := 1
var dmg := 3
var k := 4.0
var t := 0.0
var spr: AnimatedSprite2D
var done := false


func setup(g: Node, o: Node, p: Vector2, d: int, damage: int, scale_k: float) -> void:
	game = g
	owner_ally = o
	dir = d
	dmg = damage
	k = scale_k
	position = p
	var ROSTER := load("res://scripts/game/roster.gd")
	var A: Dictionary = ROSTER.art("ranger")["anims"]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in ["arrow", "arrow_hit"]:
		sf.add_animation(a)
		sf.set_animation_speed(a, float(A[a]["fps"]))
		sf.set_animation_loop(a, a == "arrow")
		for f in A[a]["frames"]:
			sf.add_frame(a, load(f))
	spr = AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.scale = Vector2(k * 0.6 * d, k * 0.6)
	add_child(spr)
	spr.play("arrow")
	spr.animation_finished.connect(queue_free)


func _physics_process(delta: float) -> void:
	t += delta
	if done:
		return
	position.x += dir * SPEED * delta
	if t > 1.5:
		queue_free()
		return
	var r := Rect2(global_position - Vector2(40, 12), Vector2(80, 24))
	for e in game.enemies():
		if r.intersects(e.hurt_rect()):
			done = true
			if e.take_damage(dmg, global_position.x - dir * 50.0, "bolt") and is_instance_valid(owner_ally):
				owner_ally.hits_landed += 1
				owner_ally.played["arrow_hit"] = true
			spr.play("arrow_hit")
			return
