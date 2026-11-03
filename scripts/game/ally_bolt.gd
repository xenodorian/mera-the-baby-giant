extends Node2D
## Stage 3 phase 7: the face allies' shots. kinds: "arrow" (Changeling Ranger, the Leaf Ranger arrow art), "orb" (Mage bolt),
## "bone" (Weaver bone shot), "wave" (Perry's energy wave, her real fx frames, pierces). Flies along `dir`, damages the
## first enemy it touches (every enemy it touches when it pierces) and breaks props. Numbers: AllyFaces.OPTS.

var game: Node
var owner_ally: Node
var kind := "orb"
var dir := Vector2.RIGHT
var speed := 1400.0
var dmg := 3
var k := 4.0
var pierce := false
var life := 1.6
var t := 0.0
var done := false
var color := Color(0.7, 0.5, 1.0)
var spr: AnimatedSprite2D
var hit_ids := {}


func setup(g: Node, o: Node, p: Vector2, d: Vector2, damage: int, scale_k: float, opts: Dictionary) -> void:
	game = g
	owner_ally = o
	position = p
	dir = d.normalized()
	dmg = damage
	k = scale_k
	kind = String(opts.get("kind", "orb"))
	speed = float(opts.get("speed", 1400.0))
	pierce = bool(opts.get("pierce", false))
	color = opts.get("color", color)
	life = float(opts.get("life", 1.6))
	z_index = 4
	if kind == "arrow" or kind == "wave":
		var art_key: String = "ranger" if kind == "arrow" else "ally_perry"
		var anim := "arrow" if kind == "arrow" else "wave"
		var e: Dictionary = Roster.art(art_key)["anims"][anim]
		var sf := SpriteFrames.new()
		sf.remove_animation("default")
		sf.add_animation("fly")
		sf.set_animation_speed("fly", float(e["fps"]))
		sf.set_animation_loop("fly", true)
		for f in e["frames"]:
			sf.add_frame("fly", load(f))
		spr = AnimatedSprite2D.new()
		spr.sprite_frames = sf
		spr.centered = false
		spr.offset = Vector2(-float(e["pivot"][0]), -float(e["pivot"][1]))
		var sc: float = k * 0.6 if kind == "arrow" else k * 0.55
		spr.scale = Vector2(sc * (1.0 if dir.x >= 0.0 else -1.0), sc)
		add_child(spr)
		spr.play("fly")
		if kind == "arrow":
			rotation = atan2(dir.y, absf(dir.x)) * (1.0 if dir.x >= 0.0 else -1.0)
	else:
		rotation = 0.0


func hit_rect() -> Rect2:
	var s := 22.0 * k / 4.0 if kind != "wave" else 70.0
	if kind == "arrow":
		return Rect2(global_position - Vector2(40, 12), Vector2(80, 24))
	return Rect2(global_position - Vector2(s, s), Vector2(s * 2.0, s * 2.0))


func _physics_process(delta: float) -> void:
	t += delta
	if done:
		return
	position += dir * speed * delta
	if t > life:
		queue_free()
		return
	queue_redraw()
	var r := hit_rect()
	for e in game.enemies():
		if hit_ids.has(e.get_instance_id()) or not r.intersects(e.hurt_rect()):
			continue
		hit_ids[e.get_instance_id()] = true
		if e.take_damage(dmg, global_position.x - signf(dir.x) * 50.0, "bolt") and is_instance_valid(owner_ally):
			owner_ally.hits_landed += 1
			owner_ally.played["bolt_hit"] = true
		if game.has_method("hit_spark"):
			game.hit_spark(e.hurt_rect().get_center(), 2.0)
		if not pierce:
			_finish()
			return
	var pr: Node2D = game.prop_at(r)
	if pr != null:
		pr.take_damage(dmg, global_position.x, "bolt")
		if not pierce:
			_finish()


func _finish() -> void:
	done = true
	if spr != null:
		spr.visible = false
	create_tween().tween_callback(queue_free).set_delay(0.12)
	queue_redraw()


func _draw() -> void:
	if kind == "arrow" or kind == "wave":
		return
	var s := 22.0 * k / 4.0
	if done:
		draw_circle(Vector2.ZERO, s * 1.8, Color(color.r, color.g, color.b, 0.4))
		return
	if kind == "orb":
		for i in 4:
			draw_circle(-dir * float(i) * s * 0.9, s * (1.0 - float(i) * 0.18), Color(color.r, color.g, color.b, 0.5 - float(i) * 0.1))
		draw_circle(Vector2.ZERO, s, color)
		draw_circle(Vector2.ZERO, s * 0.5, Color(1, 1, 1, 0.9))
	elif kind == "bone":
		draw_set_transform(Vector2.ZERO, t * 18.0 * signf(dir.x if dir.x != 0.0 else 1.0), Vector2.ONE)
		var bone := Color(0.93, 0.9, 0.78)
		draw_rect(Rect2(-s * 1.2, -s * 0.22, s * 2.4, s * 0.44), bone)
		for sx in [-1.0, 1.0]:
			draw_circle(Vector2(sx * s * 1.25, -s * 0.28), s * 0.32, bone)
			draw_circle(Vector2(sx * s * 1.25, s * 0.28), s * 0.32, bone)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
