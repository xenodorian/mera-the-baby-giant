class_name FireKnight
extends Node2D
## v0.4 knights (docs/GAME_RULES.md). One script, two variants, numbers in scripts/game/tuning.gd:
##  "fire": chierit Fire Knight, always 6x, 20 HP. Normal hits cost Mera 2 sizes, his special 3.
##          He blocks (09_defend), uses the special (08_sp_atk), and spawns a Blue Knight when he first loses HP
##          and again when he first drops below 10 HP.
##  "blue": the same art palette-swapped blue (shaders/knight_blue.gdshader), 3x, 5 HP, 3x his speed. Hits cost 1 size.
##          Prefers to attack from behind Mera. Everything he does except block and special.
## Every chierit animation is used:
##  idle, run, 03_jump + jump_up / jump_down, 04_roll (chase dash), 05_1_atk / 06_2_atk / 07_3_atk (1-, 2- and 3-hit
##  strings), 08_sp_atk, 09_defend, 10_take_hit, 11_death, air_atk (jump attack).
## Frames are 288x128, feet at (146, 127), he faces RIGHT. Attack boxes are cut from each frame's sword extent.

signal defeated(knight: Node2D)

const DIR := "res://assets/characters/chierit/fire-knight/png/fire_knight/"
const PIVOT := Vector2(146, 127)
const HURT_BOX := Vector2(26, 44)    # native px, centred on the feet
const ANIMS := {
	"idle": ["01_idle", "idle_", 8, 10.0, true], "run": ["02_run", "run_", 8, 12.0, true],
	"jump": ["03_jump", "jump_", 20, 16.0, false], "jump_up": ["03_jump_up", "jump_up_", 3, 10.0, true],
	"jump_down": ["03_jump_down", "jump_down_", 3, 10.0, true], "roll": ["04_roll", "roll_", 8, 16.0, true],
	"atk1": ["05_1_atk", "1_atk_", 11, 11.0, false], "atk2": ["06_2_atk", "2_atk_", 19, 12.0, false],
	"atk3": ["07_3_atk", "3_atk_", 28, 12.0, false], "sp": ["08_sp_atk", "sp_atk_", 18, 10.0, false],
	"defend": ["09_defend", "defend_", 10, 12.0, false], "hit": ["10_take_hit", "take_hit_", 6, 16.0, false],
	"death": ["11_death", "death_", 13, 12.0, false], "air": ["air_atk", "air_atk_", 8, 14.0, false],
}
# sword extent per active frame: [front x, top y] native px (bottom is the ground / his feet)
const _A1 := {4: [66, -83], 5: [65, -81], 6: [64, -73], 7: [62, -38]}
const _A2 := {11: [44, -43], 12: [69, -53], 14: [71, -52], 15: [70, -53]}
const _A3 := {22: [74, -79], 23: [95, -72], 24: [102, -79], 25: [95, -73], 26: [94, -71], 27: [94, -69]}
const REACH_FRAMES := {
	"atk1": [_A1], "atk2": [_A1, _A2], "atk3": [_A1, _A2, _A3],
	"sp": [{12: [104, -90], 13: [104, -95], 14: [104, -105], 15: [104, -105], 16: [102, -102]}],
	"air": [{3: [90, -54], 4: [93, -54], 5: [97, -54], 6: [99, -53]}],
}
# hit windows (each lands once per string)
const WINDOWS := {"atk1": [[4, 7]], "atk2": [[4, 7], [11, 12], [14, 15]], "atk3": [[4, 7], [11, 12], [14, 15], [22, 27]],
	"sp": [[12, 16]], "air": [[3, 6]]}
const COMMIT_FRAME := 3              # from this frame on a swing is committed: hits don't flinch him

var game: Node = null
var variant := "fire"
var cfg: Dictionary = Tuning.FIRE
var k := 6.0                         # his scale (fixed; never follows Mera)
var hp := 20
var hp_max := 20
var facing := -1
var state := "idle"                  # idle run tell atk roll takeoff air land defend hit death
var atk := ""                        # atk1 atk2 atk3 sp air
var cooldown := 0.6
var flash := 0.0
var hurt_t := 0.0
var tell_t := 0.0
var t_state := 0.0
var hits_done := {}                  # window index -> true
var vy := 0.0
var vx := 0.0
var on_ground := true
var dash_t := 0.0
var dash_cd := 0.0
var block_t := 0.0
var block_cd := 0.0
var air_cd := 0.0
var strings := 0
var flank_t := 0.0
var spawned_first := false           # Fire Knight: blue spawned on the first HP loss ...
var spawned_second := false          # ... and on first dropping below 10 HP
var block_chance := 0.55             # per threat (tests may set 1.0 / 0.0)
var _threat_seen := false
var seen_bolts := {}                 # bolt instance id -> distance when first seen
var jumped_bolts := 0                # tests / stats
var blocked := 0
var stun_t := 0.0                    # v0.5 earthquake stun left (s)
var stunned_total := 0               # tests
var history: Array = []              # states/attacks entered (tests)
var rng := RandomNumberGenerator.new()
var sprite: AnimatedSprite2D
var hurtbox: Area2D
var hitbox: Area2D
var bar: Node2D
var marker: Node2D                   # v0.6 telegraph "!" (scripts/game/telegraph.gd)
static var _frames: SpriteFrames
static var played_all := {}          # every chierit animation any knight has played (tests: all 14 are used)
static var _blue_mat: ShaderMaterial


func setup(g: Node, v: String) -> void:
	game = g
	variant = v
	cfg = Tuning.BLUE if v == "blue" else Tuning.FIRE
	k = float(cfg["scale"])
	hp_max = int(cfg["hp"])
	hp = hp_max
	rng.seed = hash(str(get_instance_id()))


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
	sprite.speed_scale = float(cfg["anim_speed"])
	if variant == "blue":
		if _blue_mat == null:
			_blue_mat = ShaderMaterial.new()
			_blue_mat.shader = load("res://shaders/knight_blue.gdshader")
		sprite.material = _blue_mat
	add_child(sprite)
	sprite.animation_finished.connect(_on_anim_done)
	hurtbox = _area("Hurtbox", Color(0.2, 0.8, 1.0, 0.35))
	var hs := hurtbox.get_child(0) as CollisionShape2D
	(hs.shape as RectangleShape2D).size = HURT_BOX * k
	hs.position = Vector2(0, -HURT_BOX.y * k / 2.0)
	hitbox = _area("Hitbox", Color(1, 0.2, 0.2, 0.4))
	bar = Node2D.new()
	bar.position = Vector2(0, -52 * k)
	bar.draw.connect(_draw_bar)
	add_child(bar)
	marker = Telegraph.marker()
	marker.position = Vector2(0, -62 * k)
	add_child(marker)
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


func _play(a: String) -> void:
	played_all[a] = true
	sprite.play(a)


func _anim(s: String, a: String = "") -> void:
	state = s
	t_state = 0.0
	history.append(s if a == "" else a)
	if marker:
		marker.visible = s == "tell"
		if s == "tell":
			marker.set_kind("heavy" if a == "sp" else "melee")
	match s:
		"tell":                         # hold the first frame of the coming attack while glowing
			_play(a)
			sprite.pause()
			sprite.frame = 0
		"atk":
			_play(a)
		"takeoff":                      # 03_jump f0: crouch
			_play("jump")
			sprite.pause()
			sprite.frame = 0
		"air":
			_play("jump_up")
		"land":                         # 03_jump f17-19: landing
			_play("jump")
			sprite.frame = 17
		"defend":
			_play("defend")
		_:
			_play(s)


func _face(d: int) -> void:
	if d == 0:
		return
	facing = d
	sprite.scale = Vector2(k * d, k)


func alive() -> bool:
	return hp > 0


func blocking() -> bool:
	return state == "defend" and sprite.frame >= 1 and sprite.frame <= 8


func hurt_rect() -> Rect2:
	var sz := HURT_BOX * k
	return Rect2(global_position + Vector2(-sz.x / 2.0, -sz.y), sz)


## the current frame's sword box (empty when no window is active)
func attack_rect() -> Rect2:
	var w := _window()
	if w < 0:
		return Rect2()
	var f := sprite.frame
	for part in REACH_FRAMES[atk]:
		if part.has(f):
			var e: Array = part[f]
			var x0 := 10.0 * k
			var x1 := float(e[0]) * k
			var top := float(e[1]) * k
			var r := Rect2(x0, top, x1 - x0, -top)
			if facing < 0:
				r.position.x = -x1
			r.position += global_position
			return r
	return Rect2()


## index of the active hit window, or -1
func _window() -> int:
	if state != "atk" or not WINDOWS.has(atk):
		return -1
	var ws: Array = WINDOWS[atk]
	for i in ws.size():
		if sprite.frame >= int(ws[i][0]) and sprite.frame <= int(ws[i][1]):
			return i
	return -1


func damage_for(a: String) -> int:
	return int(cfg["sp_dmg"]) if a == "sp" else int(cfg["dmg"])


## kind: melee | bolt | beam | explosion | lightning. Blocking stops everything except explosions and Fury attacks.
func take_damage(amount: int, from_x: float, kind: String = "melee") -> bool:
	if hp <= 0:
		return false
	var fury: bool = game != null and game.mera.fury
	if blocking() and kind != "explosion" and kind != "quake" and not fury:     # v0.8: the super quake goes through the guard
		blocked += 1
		flash = 0.06
		Sfx.play("block", 0.8)
		return false
	hp = maxi(hp - amount, 0)
	flash = 0.12
	bar.queue_redraw()
	if variant == "fire" and game:
		if not spawned_first and hp < hp_max:
			spawned_first = true
			game.spawn_blue(self)
		if not spawned_second and hp < 10:
			spawned_second = true
			game.spawn_blue(self)
	if hp == 0:
		vx = 0.0
		_anim("death")
		if game:
			game.on_knight_defeated(self)
		defeated.emit(self)
		return true
	if state == "defend":               # Fury / explosion broke through: the block drops
		block_cd = Tuning.BLOCK_COOLDOWN_S
	if state == "stun":                 # stunned: takes the damage, stays dazed
		return true
	if state == "atk" and sprite.frame >= COMMIT_FRAME:      # committed swing: no flinch
		return true
	if not on_ground:
		return true
	tell_t = 0.0
	vx = 0.0
	_face(1 if from_x > global_position.x else -1)
	_anim("hit")
	hurt_t = 0.3
	position.x += (-4.0 if from_x > global_position.x else 4.0) * k
	return true


## v0.8 parry: Mera parried his swing -> staggered (dazed like the quake stun, but also in the air)
func parried(t: float) -> void:
	if hp <= 0:
		return
	history.append("parried")
	if not on_ground:
		return
	stun(t)


## v0.5 earthquake: stunned for t seconds (only when on the ground). He can't act, block or flinch out of it.
func stun(t: float) -> void:
	if hp <= 0 or not on_ground or t <= 0.0:
		return
	stun_t = maxf(stun_t, t)
	stunned_total += 1
	if state != "stun":
		vx = 0.0
		tell_t = 0.0
		_anim("hit")
		state = "stun"
		sprite.pause()
		sprite.frame = 1
		history.append("stun")


func _on_anim_done() -> void:
	match state:
		"atk":
			if atk == "air":
				return                    # falls on in jump_down
			cooldown = 1.3 if atk != "sp" else 1.8
			_anim("idle")
		"hit":
			cooldown = 0.6
			_anim("idle")
		"land":
			_anim("idle")
		"defend":
			_anim("idle")
		"death":
			# v0.8: after his (canon) death animation the body shatters into debris (+ gore)
			if game and game.get("debris"):
				var c := hurt_rect().get_center()
				game.debris.shatter_node(sprite, c + Vector2(0, 60), 600.0, {"cols": 8 if variant == "fire" else 5, "rows": 8 if variant == "fire" else 5, "life": 2.2})
				game.debris.gore(c, k, c + Vector2(0, 40), "flesh", 10 if variant == "fire" else 6)
				Sfx.play("gore", 0.8)
			queue_free()


func _physics_process(delta: float) -> void:
	t_state += delta
	_tint()
	flash -= delta
	if hp <= 0 or game == null:
		return
	dash_cd -= delta
	block_cd -= delta
	air_cd -= delta
	var m: Node2D = game.mera
	_air_physics(delta)
	# hits on Mera
	var w := _window()
	var hb := hitbox.get_child(0) as CollisionShape2D
	hb.disabled = w < 0
	if w >= 0:
		var r := attack_rect()
		hb.position = r.get_center() - global_position
		(hb.shape as RectangleShape2D).size = r.size
		if not hits_done.has(w) and m.state != "dead" and r.intersects(m.hurt_rect()):
			hits_done[w] = true
			m.take_hit(damage_for(atk), global_position.x, self)     # fixed sizes per hit, never multiplied
	match state:
		"stun":
			stun_t -= delta
			sprite.position.x = sin(t_state * 30.0) * 1.5 * k      # wobbling in place
			if stun_t <= 0.0:
				sprite.position.x = 0.0
				cooldown = 0.4
				_anim("idle")
			return
		"hit", "death", "land", "takeoff":
			if state == "takeoff" and t_state >= 0.08:
				_launch()
			return
		"atk":
			if atk != "air" and on_ground:
				vx = 0.0
			return
		"tell":
			tell_t += delta
			if tell_t >= (float(cfg["sp_tell"]) if atk == "sp" else float(cfg["tell"])):
				hits_done = {}
				_anim("atk", atk)
				if atk == "sp":
					Sfx.play("boom", 0.7, -8.0)
			return
		"air":
			_air_ai(m)
			return
		"defend":
			_defend_tick(m, delta)
			return
		"roll":
			_roll_tick(m, delta)
			return
	if m.state == "dead":
		if state != "idle":
			_anim("idle")
		return
	cooldown -= delta
	_ground_ai(m, delta)


func _tint() -> void:
	if flash > 0.0:
		sprite.modulate = Color(3, 3, 3)
	elif state == "tell":
		var q := 0.5 + 0.5 * sin(tell_t * 40.0)
		if atk == "sp":                  # special: white-gold pulse, clearly different from the orange swing tell
			sprite.modulate = Color(1.0 + 1.2 * q, 1.0 + 1.0 * q, 1.0 + 0.6 * q)
		else:
			sprite.modulate = Color(1.0 + 0.9 * q, 1.0 + 0.3 * q, 1.0 - 0.3 * q)
	elif state == "stun":                # dazed: dim, flickering yellow
		var q2 := 0.5 + 0.5 * sin(t_state * 18.0)
		sprite.modulate = Color(0.8 + 0.4 * q2, 0.8 + 0.4 * q2, 0.55)
	elif blocking():
		sprite.modulate = Color(0.8, 0.9, 1.3)
	elif state == "roll":
		sprite.modulate = Color(1.15, 1.15, 1.15)
	else:
		sprite.modulate = Color(1, 1, 1)


# ---------------------------------------------------------------- movement
func _gy() -> float:
	return float(game.GROUND_Y)


func _air_physics(delta: float) -> void:
	if on_ground:
		position.x += vx * delta
		return
	vy += Tuning.KNIGHT_GRAVITY * (k / 6.0) * delta
	position += Vector2(vx, vy) * delta
	if state == "air" and vy > 0.0 and sprite.animation != "jump_down":
		_play("jump_down")
	if position.y >= _gy():
		position.y = _gy()
		on_ground = true
		vy = 0.0
		vx = 0.0
		if state != "death" and state != "hit":
			cooldown = maxf(cooldown, 0.35)
			_anim("land")


func _jump(target_vx: float, v: float) -> void:
	vx = target_vx
	vy = -v
	_anim("takeoff")


func _launch() -> void:
	on_ground = false
	position.y -= 1.0
	_anim("air")


func _jump_v() -> float:
	return Tuning.JUMP_V * k / 6.0


# ---------------------------------------------------------------- AI
func _ground_ai(m: Node2D, delta: float) -> void:
	var mr: Rect2 = m.hurt_rect()
	var dx: float = mr.get_center().x - global_position.x
	var gap: float = absf(dx) - mr.size.x / 2.0 - HURT_BOX.x * k / 2.0
	# 1) quick-fire bolts: seen far away (> BOLT_SEE_PX) -> jump over; seen close -> block (fire) or take it
	if _bolt_ai():
		return
	# 2) Mera in the air (jumping / flying) and near: chase with a jump attack
	var m_air: bool = m.global_position.y < _gy() - 60.0 * float(m.shown) and m.state != "dead"
	if m_air and absf(dx) < Tuning.AIR_CHASE_PX * k / 6.0 + 200.0 and air_cd <= 0.0 and cooldown <= 0.0 and _may_attack():
		var h: float = clampf(_gy() - mr.get_center().y, 120.0 * k / 6.0, 900.0)
		var g := Tuning.KNIGHT_GRAVITY * (k / 6.0)
		var v := sqrt(2.0 * g * h)
		var t_up := v / g
		_face(1 if dx > 0 else -1)
		air_cd = Tuning.AIR_CHASE_COOLDOWN_S
		_jump(clampf(dx / maxf(t_up, 0.2), -float(cfg["speed"]) * 2.5, float(cfg["speed"]) * 2.5), v)
		return
	# 3) block a melee attack coming at him (Fire Knight only)
	if _should_block(m, gap):
		return
	# 4) too far: chase dash
	if gap > Tuning.DASH_TRIGGER and dash_cd <= 0.0:
		_face(1 if dx > 0 else -1)
		dash_t = 0.0
		_anim("roll")
		return
	# 5) approach and attack. The Blue Knight circles to Mera's back first.
	var reach := 56.0 * k
	var close := 16.0 * k
	var tx: float = mr.get_center().x
	var behind_ok := true
	if variant == "blue":
		var mf: int = m.facing
		var on_back: bool = signf(global_position.x - m.global_position.x) == -mf
		flank_t += delta
		if not on_back and flank_t < 2.5:
			behind_ok = false
			tx = m.global_position.x - mf * (mr.size.x / 2.0 + 30.0 * k)   # a spot behind her back
		elif on_back:
			flank_t = 0.0
	if behind_ok and gap <= reach and absf(m.global_position.y - global_position.y) < 60.0 * k:
		_face(1 if dx > 0 else -1)
		if cooldown <= 0.0 and _may_attack():
			_start_string()
			return
		if gap <= close:
			if state != "idle":
				_anim("idle")
			return
	var d := tx - global_position.x
	if absf(d) < 8.0:
		if state != "idle":
			_anim("idle")
		_face(1 if dx > 0 else -1)
		return
	_face(1 if d > 0 else -1)
	if state != "run":
		_anim("run")
	position.x += facing * float(cfg["speed"]) * delta


func _may_attack() -> bool:
	return game.frame_n >= game.knight_calm_until


func _start_string() -> void:
	strings += 1
	if bool(cfg["special"]) and strings % Tuning.SPECIAL_EVERY == 0:
		atk = "sp"
		Sfx.play("charge", 0.6, -2.0)
	else:
		atk = ["atk1", "atk2", "atk3"][rng.randi_range(0, 2)]
	tell_t = 0.0
	_anim("tell", atk)


func _roll_tick(m: Node2D, delta: float) -> void:
	dash_t += delta
	var dx: float = m.global_position.x - global_position.x
	var gap: float = absf(dx) - 60.0 * k / 6.0
	position.x += facing * float(cfg["speed"]) * Tuning.DASH_MULT * delta
	if dash_t >= Tuning.DASH_MAX_S or gap < 40.0 * k or signf(dx) != float(facing):
		dash_cd = Tuning.DASH_COOLDOWN_S
		_anim("idle")


func _air_ai(m: Node2D) -> void:
	# jump attack at the top of the jump when Mera is in front of him and near
	if atk == "air" and state == "atk":
		return
	if vy > -350.0 * k / 6.0:
		var mr: Rect2 = m.hurt_rect()
		var dx: float = mr.get_center().x - global_position.x
		if absf(dx) < 140.0 * k and m.state != "dead" and _may_attack() and global_position.y - mr.get_center().y < 140.0 * k:
			_face(1 if dx > 0 else -1)
			atk = "air"
			hits_done = {}
			_anim("atk", "air")


## a melee threat: Mera in an attacking move, facing him, close. 55 % (block_chance) he raises the block, at most
## BLOCK_MAX_S, then a forced drop and BLOCK_COOLDOWN_S without blocking.
func _should_block(m: Node2D, gap: float) -> bool:
	if not bool(cfg["block"]) or block_cd > 0.0:
		return false
	var threat: bool = m.state == "move" and int(m.mv.get("dmg", 0)) > 0 and gap < 90.0 * float(m.shown) + 40.0 \
		and signf(global_position.x - m.global_position.x) == float(m.facing)
	if not threat:
		_threat_seen = false
		return false
	if _threat_seen:
		return false
	_threat_seen = true
	if rng.randf() >= block_chance:
		return false
	_start_block(1 if m.global_position.x > global_position.x else -1)
	return true


func _start_block(face: int) -> void:
	_face(face)
	block_t = 0.0
	_anim("defend")
	history.append("block")


func _defend_tick(m: Node2D, delta: float) -> void:
	block_t += delta
	if sprite.frame >= 7 and block_t < Tuning.BLOCK_MAX_S:
		var still: bool = (m.state == "move" and int(m.mv.get("dmg", 0)) > 0) or _bolt_incoming(0.0, 900.0)
		if still:
			sprite.frame = 3              # hold the guard (frames 2-7)
		elif sprite.frame == 7:
			pass                          # lowers it: 8-9 then idle
	if block_t >= Tuning.BLOCK_MAX_S:     # forced drop
		block_cd = Tuning.BLOCK_COOLDOWN_S
		if sprite.frame < 8:
			sprite.frame = 8
	elif sprite.frame >= 8 and block_cd <= 0.0:
		block_cd = 0.5


## true when he reacted to a bolt (jumped or blocked)
func _bolt_ai() -> bool:
	for b in _bolts():
		var id: int = b.get_instance_id()
		var d := absf(b.global_position.x - global_position.x) - HURT_BOX.x * k / 2.0
		if not seen_bolts.has(id):
			seen_bolts[id] = d
		var first: float = seen_bolts[id]
		var speed: float = b.speed()
		var eta := d / maxf(speed, 1.0)
		if first > Tuning.BOLT_SEE_PX:
			if eta <= 0.32:
				jumped_bolts += 1
				history.append("jump_bolt")
				_jump(0.0, _jump_v())
				return true
		elif bool(cfg["block"]) and block_cd <= 0.0 and eta < 0.6:
			_start_block(1 if b.global_position.x > global_position.x else -1)
			return true
	return false


func _bolt_incoming(min_d: float, max_d: float) -> bool:
	for b in _bolts():
		var d := absf(b.global_position.x - global_position.x)
		if d >= min_d and d <= max_d:
			return true
	return false


## Mera's damaging quick-fire bolts flying at him, at a height he could be hit at, within BOLT_LOOK_PX
func _bolts() -> Array:
	var out: Array = []
	if game == null:
		return out
	for c in game.world.get_children():
		if c is Shot and c.kind == "bolt" and c.damaging and not c.is_queued_for_deletion():
			var rel: float = global_position.x - c.global_position.x
			if signf(rel) == float(c.dir) and absf(rel) < Tuning.BOLT_LOOK_PX and c.global_position.y > global_position.y - HURT_BOX.y * k:
				out.append(c)
	return out


func _draw_bar() -> void:
	var w := 40.0 * k
	var h := 14.0 if variant == "fire" else 10.0
	bar.draw_rect(Rect2(-w / 2.0 - 3, -3, w + 6, h + 6), Color(0.05, 0.03, 0.06, 0.85))
	bar.draw_rect(Rect2(-w / 2.0, 0, w, h), Color(0.25, 0.05, 0.08) if variant == "fire" else Color(0.05, 0.08, 0.25))
	bar.draw_rect(Rect2(-w / 2.0, 0, w * float(hp) / hp_max, h), Color(0.86, 0.18, 0.16) if variant == "fire" else Color(0.3, 0.55, 1.0))
	for i in range(1, hp_max):
		var x := -w / 2.0 + w * i / hp_max
		bar.draw_line(Vector2(x, 0), Vector2(x, h), Color(0.05, 0.03, 0.06, 0.6), 2.0)
