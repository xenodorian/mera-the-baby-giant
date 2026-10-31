extends Node2D
## v0.8 dragon phase bolt: an explosive fire bolt lobbed from the dragon's mouth on a ballistic arc onto a point
## at Mera's feet (docs/GAME_RULES.md "Infernal Dragon"). A red ring on the ground shows where it will land
## (telegraph standard: red = ranged). It explodes on touching Mera or the ground: AoE DRAGON_BOLT_R, fixed
## DRAGON_BOLT_DMG. If the blast hurts Mera, the dragon grows (dragon.bolt_hit, once per phase).
## The barrier blocks it; a parry in the window pops it harmlessly.

var game: Node
var dragon: Node2D
var vel := Vector2.ZERO
var target := Vector2.ZERO
var t := 0.0
var spr: AnimatedSprite2D
var warn: Node2D
var done := false
var hurt_mera := false
var flight := 1.0               # solved flight time (s)
var launch_vel := Vector2.ZERO  # tests
var launch_pos := Vector2.ZERO
var land_x := NAN               # tests: where it hit the ground / Mera
## the fireball art (ansimuz hell beast) faces LEFT: blunt round head at -x, flame trail at +x
const NATIVE_HEAD := -1


func setup(g: Node, dr: Node2D, p: Vector2, tgt: Vector2, flight_s: float = -1.0) -> void:
	game = g
	dragon = dr
	position = p
	target = tgt
	var G := Tuning.DRAGON_BOLT_G
	var drop := tgt.y - p.y
	if drop > 20.0 and flight_s <= 0.0:
		# v0.8.2: horizontal launch out of the mouth; gravity alone brings it down onto tgt
		flight = sqrt(2.0 * drop / G)
		vel = Vector2((tgt.x - p.x) / flight, 0.0)
	else:                                          # fallback: a lob with a fixed flight time
		flight = Tuning.DRAGON_BOLT_FLIGHT_S if flight_s <= 0.0 else flight_s
		vel = Vector2((tgt.x - p.x) / flight, (drop - 0.5 * G * flight * flight) / flight)
	launch_vel = vel
	launch_pos = p


func _ready() -> void:
	z_index = 15
	var RO := load("res://scripts/game/roster.gd")
	var e: Dictionary = RO.art("hell_beast")["anims"]["fireball"]
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", float(e["fps"]))
	for f in e["frames"]:
		sf.add_frame("default", load(f))
	spr = AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.scale = Vector2(6, 6)
	spr.modulate = Color(1.6, 0.7, 0.4)
	add_child(spr)
	_orient()
	spr.play("default")
	warn = Node2D.new()
	warn.top_level = true
	warn.z_index = 4
	warn.position = target
	warn.draw.connect(_draw_warn)
	add_child(warn)


func _draw_warn() -> void:
	var q := 0.5 + 0.5 * sin(t * 18.0)
	var c := Telegraph.color("ranged")
	var r := Tuning.DRAGON_BOLT_R
	warn.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.22))
	warn.draw_circle(Vector2.ZERO, r * (0.6 + 0.4 * minf(t / flight, 1.0)), Color(c.r, c.g, c.b, 0.18 + 0.2 * q))
	warn.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(c.r, c.g, c.b, 0.6 + 0.3 * q), 6.0)


func rect() -> Rect2:
	return Rect2(global_position - Vector2(50, 40), Vector2(100, 80))


func _physics_process(delta: float) -> void:
	if done:
		return
	t += delta
	vel.y += Tuning.DRAGON_BOLT_G * delta
	position += vel * delta
	_orient()
	warn.queue_redraw()
	if game == null:
		return
	var m: Node2D = game.mera
	if m and m.state != "dead" and rect().intersects(m.hurt_rect()):
		if m.has_method("try_parry_shot") and m.try_parry_shot(self):
			_pop()
			return
		_explode()
		return
	if position.y >= float(game.GROUND_Y) - 10.0 or t > 4.0:
		position.y = minf(position.y, float(game.GROUND_Y) - 10.0)
		_explode()


## blunt head along the velocity, flame trailing behind. The art's head is at -x (NATIVE_HEAD), so it is
## mirrored (flip_h) to put the head at +x, then rotated to the velocity. When it flies left, flip_v keeps the
## flame curl on the upper side instead of upside down.
func _orient() -> void:
	if spr == null:
		return
	spr.flip_h = NATIVE_HEAD < 0
	spr.rotation = vel.angle()
	spr.flip_v = vel.x < 0.0


## the direction the blunt head points (tests)
func head_dir() -> Vector2:
	var hx := float(NATIVE_HEAD) * (-1.0 if spr.flip_h else 1.0)
	return Vector2(hx, 0.0).rotated(spr.rotation)


func _pop() -> void:
	done = true
	if game:
		game.hit_spark(global_position, 3.0)
	queue_free()


func _explode() -> void:
	done = true
	land_x = global_position.x
	var c := Vector2(global_position.x, float(game.GROUND_Y))
	var b := Blast.new()
	b.setup("explosion", c, 3.2)
	get_parent().add_child(b)
	game.shake(10.0, 0.25)
	Sfx.play("boom_big", 1.1, -3.0)
	var m: Node2D = game.mera
	var r := Tuning.DRAGON_BOLT_R
	if m and m.state != "dead":
		var mr: Rect2 = m.hurt_rect()
		var near := Vector2(clampf(global_position.x, mr.position.x, mr.end.x), clampf(global_position.y, mr.position.y, mr.end.y))
		if near.distance_to(global_position) <= r:
			var sz0: int = m.size
			m.take_hit(Tuning.DRAGON_BOLT_DMG, c.x, dragon if is_instance_valid(dragon) else null)
			if m.size < sz0 or m.state == "dead":
				hurt_mera = true
				if is_instance_valid(dragon) and dragon.has_method("bolt_hit"):
					dragon.bolt_hit()
	if game.has_method("allies"):
		for a in game.allies():
			if is_instance_valid(a) and absf(a.global_position.x - c.x) <= r:
				a.take_hit(Tuning.DRAGON_BOLT_DMG, c.x)
	queue_free()
