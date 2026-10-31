class_name FireKnight
extends Node2D
## chierit Fire Knight, the demo's only enemy (docs/GAME_RULES.md): 10 HP with a health bar, deals 1 damage with
## his attack, simple AI (walk up, swing, flinch, die), drops a red rage sphere (+10 %) and sometimes a potion.
## Always drawn at 6x (264 px tall), the scale test's reference size: enemies never scale with Mera, and every
## connecting swing costs her exactly 1 size, whatever her size. Frames are 288x128, feet at (146, 127), he faces RIGHT.
## Tuned for 6x: he stops just outside his own body, shows a 0.4 s glowing tell, then swings slowly (frames 0-3
## wind up), so a back dodge (i-frames), a barrier or backing off all work at any of Mera's sizes.

signal defeated(knight: Node2D)

const DIR := "res://assets/characters/chierit/fire-knight/png/fire_knight/"
const PIVOT := Vector2(146, 127)
const SCALE := 6.0                   # fixed: enemies do not scale in size or damage
const HP_MAX := 10
const SPEED := 32.0 * SCALE          # walk speed, px/s (192)
const DAMAGE := 1                    # sizes per connecting swing, never multiplied
const TELL := 0.4                    # s of glowing tell before a swing
const REACH := 56.0 * SCALE          # starts a swing when Mera's near edge is this close (sword reaches 68)
const CLOSE := 16.0 * SCALE          # walks up to this gap (just outside his 13 px half-body) before waiting
const HURT_BOX := Vector2(26, 44)    # native px, centred on the feet
const ANIMS := {"idle": ["01_idle", "idle_", 8, 10.0, true], "run": ["02_run", "run_", 8, 12.0, true],
	"atk": ["05_1_atk", "1_atk_", 11, 11.0, false], "hit": ["10_take_hit", "take_hit_", 6, 16.0, false],
	"death": ["11_death", "death_", 13, 12.0, false]}
const ATK_FRAMES := [4, 5, 6]        # frames whose sword reaches forward
const ATK_BOX := Rect2(14, -84, 54, 84)   # native px in front of him (sword arc of 1_atk frames 4-6)

var game: Node = null
var hp := HP_MAX
var facing := -1
var state := "idle"
var cooldown := 0.6
var flash := 0.0
var hit_done := false
var hurt_t := 0.0
var tell_t := 0.0
var sprite: AnimatedSprite2D
var hurtbox: Area2D
var hitbox: Area2D
var bar: Node2D
static var _frames: SpriteFrames


func _ready() -> void:
	if _frames == null:
		_frames = SpriteFrames.new()
		_frames.remove_animation("default")
		for a in ANIMS:
			var d: Array = ANIMS[a]
			_frames.add_animation(a)
			_frames.set_animation_speed(a, d[3])
			_frames.set_animation_loop(a, d[4])
			for i in range(1, int(d[2]) + 1):
				_frames.add_frame(a, load(DIR + "%s/%s%d.png" % [d[0], d[1], i]))
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _frames
	sprite.centered = false
	sprite.offset = -PIVOT
	add_child(sprite)
	sprite.animation_finished.connect(_on_anim_done)
	hurtbox = _area("Hurtbox", Color(0.2, 0.8, 1.0, 0.35))
	var hs := hurtbox.get_child(0) as CollisionShape2D
	(hs.shape as RectangleShape2D).size = HURT_BOX * SCALE
	hs.position = Vector2(0, -HURT_BOX.y * SCALE / 2.0)
	hitbox = _area("Hitbox", Color(1, 0.2, 0.2, 0.4))
	bar = Node2D.new()
	bar.position = Vector2(0, -52 * SCALE)
	bar.draw.connect(_draw_bar)
	add_child(bar)
	_anim("idle")
	_face(facing)


func _area(n: String, c: Color) -> Area2D:
	var a := Area2D.new()
	a.name = n
	a.monitoring = false
	a.monitorable = false
	var s := CollisionShape2D.new()
	s.shape = RectangleShape2D.new()
	s.debug_color = c
	a.add_child(s)
	add_child(a)
	return a


func _anim(s: String) -> void:
	state = s
	if s == "tell":                 # hold the first swing frame while glowing
		sprite.play("atk")
		sprite.pause()
		sprite.frame = 0
		return
	sprite.play(s)


func _face(d: int) -> void:
	facing = d
	sprite.scale = Vector2(SCALE * d, SCALE)
	var hb := hitbox.get_child(0) as CollisionShape2D
	(hb.shape as RectangleShape2D).size = ATK_BOX.size * SCALE
	hb.position = Vector2((ATK_BOX.position.x + ATK_BOX.size.x / 2.0) * SCALE * d, (ATK_BOX.position.y + ATK_BOX.size.y / 2.0) * SCALE)


func alive() -> bool:
	return hp > 0


func hurt_rect() -> Rect2:
	var sz := HURT_BOX * SCALE
	return Rect2(global_position + Vector2(-sz.x / 2.0, -sz.y), sz)


func attack_rect() -> Rect2:
	var hb := hitbox.get_child(0) as CollisionShape2D
	var sz := (hb.shape as RectangleShape2D).size
	return Rect2(global_position + hb.position - sz / 2.0, sz)


func take_damage(amount: int, from_x: float) -> void:
	if hp <= 0:
		return
	hp = maxi(hp - amount, 0)
	flash = 0.12
	bar.queue_redraw()
	if hp == 0:
		_anim("death")
		if game:
			game.on_knight_defeated(self)
		defeated.emit(self)
		return
	if state == "atk" and sprite.frame >= 3:     # committed swing: he takes the damage but does not flinch
		return
	tell_t = 0.0
	_face(1 if from_x > global_position.x else -1)
	_anim("hit")
	hurt_t = 0.3
	position.x += (-4.0 if from_x > global_position.x else 4.0) * SCALE


func _on_anim_done() -> void:
	match state:
		"atk", "hit":
			cooldown = 1.4 if state == "atk" else 0.9
			_anim("idle")
		"death":
			var t := create_tween()
			t.tween_property(self, "modulate:a", 0.0, 0.6)
			t.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if flash > 0.0:
		sprite.modulate = Color(3, 3, 3)
	elif state == "tell":
		var k := 0.5 + 0.5 * sin(tell_t * 40.0)
		sprite.modulate = Color(1.0 + 0.9 * k, 1.0 + 0.3 * k, 1.0 - 0.3 * k)
	else:
		sprite.modulate = Color(1, 1, 1)
	flash -= delta
	if hp <= 0 or game == null:
		return
	var m: Node2D = game.mera
	var hitbox_on := state == "atk" and sprite.frame in ATK_FRAMES
	(hitbox.get_child(0) as CollisionShape2D).disabled = not hitbox_on
	if hitbox_on and not hit_done and m.state != "dead" and attack_rect().intersects(m.hurt_rect()):
		hit_done = true
		m.take_hit(DAMAGE, global_position.x)               # exactly 1 size per connecting swing
	if state == "hit" or state == "atk":
		return
	if state == "tell":
		tell_t += delta
		if tell_t >= TELL:
			hit_done = false
			_anim("atk")
		return
	cooldown -= delta
	if m.state == "dead":
		if state != "idle":
			_anim("idle")
		return
	var mr: Rect2 = m.hurt_rect()
	var dx := mr.get_center().x - global_position.x
	_face(1 if dx > 0 else -1)
	var gap := absf(dx) - mr.size.x / 2.0
	var can_swing: bool = cooldown <= 0.0 and game.frame_n >= game.knight_calm_until
	if gap <= REACH and absf(m.global_position.y - global_position.y) < 60.0 * SCALE and (can_swing or gap <= CLOSE):
		if can_swing:
			tell_t = 0.0
			_anim("tell")
		elif state != "idle":
			_anim("idle")
	else:
		if state != "run":
			_anim("run")
		position.x += facing * SPEED * delta


func _draw_bar() -> void:
	var w := 40.0 * SCALE
	var h := 14.0
	bar.draw_rect(Rect2(-w / 2.0 - 3, -3, w + 6, h + 6), Color(0.05, 0.03, 0.06, 0.85))
	bar.draw_rect(Rect2(-w / 2.0, 0, w, h), Color(0.25, 0.05, 0.08))
	bar.draw_rect(Rect2(-w / 2.0, 0, w * float(hp) / HP_MAX, h), Color(0.86, 0.18, 0.16))
	for i in range(1, HP_MAX):
		var x := -w / 2.0 + w * i / HP_MAX
		bar.draw_line(Vector2(x, 0), Vector2(x, h), Color(0.05, 0.03, 0.06, 0.6), 2.0)
