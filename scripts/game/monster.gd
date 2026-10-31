extends Node2D
## v0.6 roster enemy (docs/GAME_RULES.md "Enemy roster"): one data-driven script for all 16 enemies.
## Definitions + AttackData: scripts/game/roster.gd. Art and per-frame boxes: assets/enemies/roster.json.
## Telegraphs follow scripts/game/telegraph.gd. Same duck-typed interface as the knights:
##   alive() hurt_rect() attack_rect() take_damage(amount, from_x, kind) stun(t) on_ground position
## States: spawn idle move tell atk hop stun dead (S3 adds dance).

signal defeated(e: Node2D)

const ROSTER := preload("res://scripts/game/roster.gd")
const TELE := preload("res://scripts/game/telegraph.gd")
const GRAVITY := 3000.0

static var _cache: Dictionary = {}      # id -> SpriteFrames

var game: Node = null
var id := ""
var d: Dictionary = {}
var art: Dictionary = {}
var k := 4.0
var hp := 5
var hp_max := 5
var facing := -1
var native := 1
var flyer := false
var boss := false
var state := "idle"
var t_state := 0.0
var atk: Dictionary = {}
var windows: Array = []                # frames attacks: [[f0, f1, ...], ...]
var hits_done := {}
var shot_done := false
var cooldown := 0.8
var hop_cd := 0.6
var tell_t := 0.0
var vx := 0.0
var vy := 0.0
var on_ground := true
var rest_y := 0.0
var bob := 0.0
var swoop_v := Vector2.ZERO
var stun_t := 0.0
var stunned_total := 0
var flash := 0.0
var speed := 100.0
var idle_a := "idle"
var move_a := "walk"
var attacks: Array = []
var disarmed := false
var lamp_lost := false
var doused_t := 0.0
var variant := ""
var history: Array = []
var played := {}                        # every animation that has been shown (tests: "uses all its animations")
var hits_landed := 0
# v0.8 (S4) juggles and corpse launch (docs/GAME_RULES.md "Juggles")
var juggle_n := 0                      # air hits in the current juggle (gravity grows with it)
var bounced := false                   # one ground bounce per launch
var wall_bounces := 0
var launches := 0                      # tests
var max_air := 0.0                     # tests: highest point of the last launch (px above rest)
var last_from_x := 0.0
var last_kind := "melee"
var corpse_t := 0.0
var spin := 0.0
var gore_kind := "flesh"
var rng := RandomNumberGenerator.new()
var sprite: AnimatedSprite2D
var marker: Node2D
var bar: Node2D


func setup(g: Node, enemy_id: String, x: float, opts: Dictionary = {}) -> void:
	game = g
	id = enemy_id
	d = ROSTER.def(id)
	art = ROSTER.art(id)
	k = float(d["k"])
	hp_max = int(d["hp"])
	hp = hp_max
	native = int(art["facing"])
	flyer = bool(art["flyer"])
	boss = bool(d.get("boss", false))
	speed = float(d["speed"])
	idle_a = String(d["idle"])
	move_a = String(d["move"])
	attacks = d["attacks"]
	rng.seed = hash(str(get_instance_id())) if not opts.has("seed") else int(opts["seed"])
	variant = String(opts.get("variant", ""))
	if d.has("clothed") and (variant == "clothed" or (variant == "" and rng.randf() < 0.5)):
		variant = "clothed"
		idle_a = String(d["clothed"]["idle"])
		move_a = String(d["clothed"]["move"])
	if d.has("skins"):
		var sk: Array = d["skins"]
		var s: String = sk[rng.randi_range(0, sk.size() - 1)] if variant == "" else variant
		variant = s
		idle_a = s
		move_a = s
	var gy: float = float(g.GROUND_Y) if g else 1060.0
	if flyer:
		rest_y = gy - float(d.get("hover", 200.0)) - float(art["body"][3]) * k
	else:
		rest_y = gy
	position = Vector2(x, rest_y)
	on_ground = not flyer
	gore_kind = String(GORE_KIND.get(id, "flesh"))


## what a creature bursts into (debris.gd gore): undead rattle into bones, spirits and fire puff away
const GORE_KIND := {"skeleton": "bone", "ghost": "ghost", "fire_skull": "fire", "death": "bone", "nightmare": "fire"}


func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _frames(id)
	sprite.centered = false
	add_child(sprite)
	sprite.animation_finished.connect(_on_anim_done)
	marker = TELE.marker()
	add_child(marker)
	bar = Node2D.new()
	bar.draw.connect(_draw_bar)
	add_child(bar)
	_place_overhead()
	if d.has("spawn"):
		var sa: String = d["spawn"] if variant != "clothed" else d["clothed"]["spawn"]
		_set_state("spawn")
		_play(sa)
	else:
		_set_state("idle")
		_play(idle_a)
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	_face(facing)


static func _frames(eid: String) -> SpriteFrames:
	if _cache.has(eid):
		return _cache[eid]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var anims: Dictionary = ROSTER.art(eid)["anims"]
	for a in anims:
		var e: Dictionary = anims[a]
		sf.add_animation(a)
		sf.set_animation_speed(a, float(e["fps"]))
		sf.set_animation_loop(a, bool(e["loop"]))
		for p in e["frames"]:
			var tx: Texture2D = load(p)
			sf.add_frame(a, tx)
	_cache[eid] = sf
	return sf


# ---------------------------------------------------------------- helpers
func _play(a: String, from: int = 0) -> void:
	played[a] = true
	var e: Dictionary = art["anims"][a]
	sprite.offset = Vector2(-float(e["pivot"][0]), -float(e["pivot"][1]))
	sprite.play(a)
	sprite.frame = from
	sprite.speed_scale = 1.0


func _set_state(s: String) -> void:
	state = s
	t_state = 0.0
	history.append(s)


func _face(dd: int) -> void:
	if dd == 0:
		return
	facing = dd
	if sprite:
		sprite.scale = Vector2(k * dd * native, k)


func _place_overhead() -> void:
	var b: Array = art["body"]
	marker.position = Vector2(0, float(b[1]) * k - 30.0)
	bar.position = Vector2(0, float(b[1]) * k - 16.0)


## a native box [x0, y0, x1, y1] (relative to the pivot, as drawn) -> world rect for the current facing
func _box(b: Array) -> Rect2:
	var x0 := float(b[0])
	var x1 := float(b[2])
	if facing != native:
		var t := x0
		x0 = -x1
		x1 = -t
	return Rect2(global_position + Vector2(x0, float(b[1])) * k, Vector2(x1 - x0, float(b[3]) - float(b[1])) * k)


func alive() -> bool:
	return hp > 0


func blocking() -> bool:
	return false


func hurt_rect() -> Rect2:
	var b: Array = art["body"]
	var w := float(b[2]) - float(b[0])
	return _box([float(b[0]) + w * 0.12, b[1], float(b[2]) - w * 0.12, b[3]])


func body_w() -> float:
	return (float(art["body"][2]) - float(art["body"][0])) * k * 0.76


## the active hit box this frame (empty when none)
func attack_rect() -> Rect2:
	if state != "atk" or atk.is_empty():
		return Rect2()
	match String(atk["mode"]):
		"contact":
			return hurt_rect()
		"frames":
			var f := sprite.frame
			if _window_of(f) < 0:
				return Rect2()
			var b: Array = art["anims"][atk["anim"]]["boxes"][f]
			var body: Array = art["body"]
			var tall := (float(b[3]) - float(b[1])) > 1.4 * (float(body[3]) - float(body[1]))
			var c := b.duplicate()
			if not tall:                       # only the half in front of the pivot hurts
				if native < 0:
					c[2] = minf(float(c[2]), 0.0)
				else:
					c[0] = maxf(float(c[0]), 0.0)
			return _box(c)
	return Rect2()


func _window_of(f: int) -> int:
	for i in windows.size():
		if f in windows[i]:
			return i
	return -1


## frames-mode windows: the listed "active" range, else every frame that reaches out past the body
## (20 % of its width forward, or 40 % taller), grouped into runs
func _calc_windows(a: Dictionary) -> Array:
	var out: Array = []
	if a.has("active"):
		var r: Array = a["active"]
		var w: Array = []
		for f in range(int(r[0]), int(r[1]) + 1):
			w.append(f)
		return [w]
	var boxes: Array = art["anims"][a["anim"]]["boxes"]
	var body: Array = art["body"]
	var bw := float(body[2]) - float(body[0])
	var bh := float(body[3]) - float(body[1])
	var cur: Array = []
	for f in boxes.size():
		var b: Array = boxes[f]
		var ext := (float(body[0]) - float(b[0])) if native < 0 else (float(b[2]) - float(body[2]))
		var act := f > 0 and (ext >= 0.2 * bw or (float(b[3]) - float(b[1])) > 1.4 * bh)
		if act:
			cur.append(f)
		elif not cur.is_empty():
			out.append(cur)
			cur = []
	if not cur.is_empty():
		out.append(cur)
	return out


func gap_to(m: Node2D) -> float:
	var mr: Rect2 = m.hurt_rect()
	return absf(mr.get_center().x - global_position.x) - mr.size.x / 2.0 - body_w() / 2.0


# ---------------------------------------------------------------- damage
func take_damage(amount: int, from_x: float, _kind: String = "melee") -> bool:
	if hp <= 0:
		return false
	hp = maxi(hp - amount, 0)
	flash = 0.12
	last_from_x = from_x
	last_kind = _kind
	bar.queue_redraw()
	if hp == 0:
		_die()
		return true
	if d.has("disarm") and not disarmed and hp <= hp_max / 2:
		disarmed = true                                       # the ogre loses his club: unarmed idle / walk + shove
		idle_a = String(d["disarm"]["idle"])
		move_a = String(d["disarm"]["move"])
		speed = float(d["disarm"]["speed"])
		attacks = d["attacks_disarmed"]
	if d.has("lamp") and not lamp_lost:
		lamp_lost = true                                      # Death drops his lamp and speeds up
		idle_a = String(d["lamp"]["idle"])
		move_a = String(d["lamp"]["move"])
		speed = float(d["lamp"]["speed"])
	if d.has("douse"):
		doused_t = float(d["douse"]["t"])                     # the fire skull's flame goes out for a while
		if state != "atk":
			_play(String(d["douse"]["idle"]))
	if _juggle_hit(from_x, _kind):                            # v0.8 launch / juggle / slam
		return true
	if boss or state == "stun" or state == "spawn":
		return true
	if state == "tell" or (state == "atk" and String(atk["mode"]) == "contact" and not flyer):
		_to_idle(0.6)                                         # a hit during the wind-up (or a lunge) cancels it
	var away := -1.0 if from_x > global_position.x else 1.0
	position.x += away * 4.0 * k
	return true


## v0.8 launch / juggle: launchers (rising slash, 3x, 2x-1, explosions) throw a ground enemy up; any hit while it
## is airborne pops it up again (less each time, gravity grows); the slam spikes it into a ground bounce.
## Bosses and flyers are never launched; heavy enemies fly less (mass from their size).
func _juggle_hit(from_x: float, kind: String) -> bool:
	if boss or flyer:
		return false
	var away := -1.0 if from_x > global_position.x else 1.0
	var mass := _mass()
	if state == "juggle":
		marker.visible = false
		if kind == "slam":
			vy = maxf(vy, 1400.0 / mass)
			bounced = false
		elif juggle_n < Tuning.JUGGLE_MAX:
			juggle_n += 1
			vy = -Tuning.JUGGLE_HIT_VY * (1.0 - float(juggle_n) / float(Tuning.JUGGLE_MAX + 2)) / sqrt(mass)
			vx = away * 120.0
		return true
	var up := 0.0
	match kind:
		"launch":
			up = Tuning.LAUNCH_VY
		"explosion":
			up = Tuning.LAUNCH_VY * 0.8
		"slam":
			up = Tuning.LAUNCH_VY * 0.45
	if up <= 0.0 or state == "spawn":
		return false
	_launch(away * (Tuning.LAUNCH_VX * (2.6 if kind == "explosion" else 1.0)) / mass, -up / mass)
	return true


func _mass() -> float:
	var b: Array = art["body"]
	return clampf((float(b[3]) - float(b[1])) * k / 260.0, 1.0, 2.2)


func _launch(lvx: float, lvy: float) -> void:
	launches += 1
	juggle_n = 0
	bounced = false
	max_air = 0.0
	atk = {}
	swoop_v = Vector2.ZERO
	marker.visible = false
	stun_t = 0.0
	vx = lvx
	vy = lvy
	on_ground = false
	_set_state("juggle")
	sprite.pause()
	sprite.position.x = 0.0


func _juggle_tick(delta: float) -> void:
	vy += GRAVITY * (1.0 + Tuning.JUGGLE_GRAVITY_STEP * juggle_n) * delta
	position += Vector2(vx, vy) * delta
	max_air = maxf(max_air, rest_y - position.y)
	sprite.rotation = clampf(vx * -0.0006, -0.5, 0.5) * signf(float(facing))
	_wall_bounce()
	if position.y >= rest_y:
		position.y = rest_y
		if vy > Tuning.BOUNCE_MIN_VY and not bounced:
			bounced = true                                  # ground bounce: one more chance to juggle
			vy = -vy * Tuning.GROUND_BOUNCE
			vx *= 0.6
			if game:
				game.shake(4.0, 0.1)
				game.hit_spark(Vector2(global_position.x, rest_y - 10.0), 2.0)
			Sfx.play("hit_heavy", 0.6, -8.0)
			return
		vy = 0.0
		vx = 0.0
		on_ground = true
		sprite.rotation = 0.0
		sprite.play()
		_to_idle(0.7)


## flung into a map wall: bounce back off it (1 damage)
func _wall_bounce() -> void:
	if game == null:
		return
	var lo := Levels.EDGE
	var hi: float = game.map_w - Levels.EDGE
	if (position.x <= lo and vx < -150.0) or (position.x >= hi and vx > 150.0):
		position.x = clampf(position.x, lo, hi)
		vx = -vx * Tuning.WALL_BOUNCE
		wall_bounces += 1
		Sfx.play("hit_heavy", 0.7, -6.0)
		if game:
			game.shake(6.0, 0.12)
		if hp > 0:
			hp = maxi(hp - 1, 0)
			flash = 0.1
			if hp == 0:
				_die()


## v0.8 parry: staggered (any enemy; flyers drift back)
func parried(t: float) -> void:
	if hp <= 0 or boss:
		return
	atk = {}
	swoop_v = Vector2.ZERO
	marker.visible = false
	vx = 0.0
	stun_t = maxf(stun_t, t)
	if state != "stun" and state != "juggle":
		_set_state("stun")
		sprite.pause()
	history.append("parried")


func _die() -> void:
	_set_state("dead")
	marker.visible = false
	sprite.pause()
	# v0.8 corpse launch: flung away from the killing blow, spinning, then it shatters (+ gore) where it lands
	var away := -1.0 if last_from_x > global_position.x else 1.0
	var pw := 1.6 if last_kind in ["explosion", "crush"] else (1.25 if last_kind in ["launch", "slam", "lightning"] else 1.0)
	var mass := _mass() * (2.5 if boss else 1.0)
	vx = away * Tuning.CORPSE_VX * pw / mass
	vy = -Tuning.CORPSE_VY * pw / mass
	on_ground = false
	spin = away * randf_range(5.0, 9.0) / mass
	corpse_t = 0.0
	if game and game.has_method("on_enemy_defeated"):
		game.on_enemy_defeated(self)
	defeated.emit(self)


## the corpse flies, spins, bounces off walls, and bursts on landing (or after CORPSE_MAX_S)
func _corpse_tick(delta: float) -> void:
	corpse_t += delta
	vy += GRAVITY * delta
	position += Vector2(vx, vy) * delta
	sprite.rotation += spin * delta
	_wall_bounce()
	var floor_y := (float(game.GROUND_Y) if game else rest_y) - 20.0
	if (position.y >= floor_y and vy > 0.0) or corpse_t >= Tuning.CORPSE_MAX_S:
		position.y = minf(position.y, floor_y)
		_burst()


func _burst() -> void:
	_set_state("gone")
	if game and game.get("debris"):
		var c := hurt_rect().get_center()
		var big := boss or k >= 5.0
		game.debris.shatter_node(sprite, c + Vector2(-vx * 0.05, 40.0), 520.0 if not boss else 800.0,
			{"cols": 10 if boss else (7 if big else 5), "rows": 10 if boss else (7 if big else 5), "life": 2.2})
		game.debris.gore(c, k, Vector2(last_from_x, c.y), gore_kind, 16 if boss else (10 if big else 7))
		Sfx.play("gore", 1.0 if not boss else 0.6)
	_death_puff()
	queue_free()


func _death_puff() -> void:
	var fx := AnimatedSprite2D.new()
	var e: Dictionary = ROSTER.data()["_fx"]["enemy_death"]
	var sf := SpriteFrames.new()
	sf.set_animation_loop("default", false)
	sf.set_animation_speed("default", float(e["fps"]))
	for p in e["frames"]:
		sf.add_frame("default", load(p))
	fx.sprite_frames = sf
	fx.scale = Vector2.ONE * clampf(k * 1.5, 4.0, 10.0)
	fx.position = hurt_rect().get_center() + Vector2(0, -10)
	fx.animation_finished.connect(fx.queue_free)
	if get_parent():
		get_parent().add_child(fx)
	fx.play("default")


## v0.5 earthquake: only enemies standing on the ground
func stun(t: float) -> void:
	if hp <= 0 or flyer or not on_ground or t <= 0.0:
		return
	stun_t = maxf(stun_t, t)
	stunned_total += 1
	if state != "stun":
		marker.visible = false
		vx = 0.0
		_set_state("stun")
		sprite.pause()


func _to_idle(cd: float) -> void:
	marker.visible = false
	atk = {}
	vx = 0.0
	cooldown = maxf(cooldown, cd)
	_set_state("idle")
	_play(_cur_idle())
	sprite.speed_scale = 1.0


func _cur_idle() -> String:
	return String(d["douse"]["idle"]) if doused_t > 0.0 else idle_a


func _cur_move() -> String:
	return String(d["douse"]["move"]) if doused_t > 0.0 else move_a


func _on_anim_done() -> void:
	match state:
		"spawn":
			_to_idle(0.5)
		"atk":
			if String(atk["mode"]) != "contact":
				_to_idle(float(atk["cd"]))
		"hop":
			pass


# ---------------------------------------------------------------- tick
func _physics_process(delta: float) -> void:
	t_state += delta
	flash -= delta
	_tint()
	if state == "dead" and game != null:
		_corpse_tick(delta)
		return
	if hp <= 0 or game == null:
		return
	if state == "juggle":
		_juggle_tick(delta)
		return
	cooldown -= delta
	hop_cd -= delta
	if doused_t > 0.0:
		doused_t -= delta
		if doused_t <= 0.0 and state in ["idle", "move"]:
			_play(_cur_idle())
	var m: Node2D = game.mera
	_physics(delta)
	if (state == "tell" or state == "atk") and not boss and game.has_method("dancer") and game.dancer() != null and absf(global_position.x - game.cam_x) <= 1100.0:
		swoop_v = Vector2.ZERO           # the dancing girl starts: wind-ups and attacks are dropped to go watch her
		_to_idle(0.0)
	match state:
		"spawn":
			return
		"stun":
			stun_t -= delta
			sprite.position.x = sin(t_state * 30.0) * 1.5 * k
			if stun_t <= 0.0:
				sprite.position.x = 0.0
				sprite.play()
				_to_idle(0.4)
			return
		"tell":
			tell_t += delta
			if tell_t >= maxf(float(atk["tell"]), TELE.MIN_TELL):
				_start_active(m)
			return
		"atk":
			_active_tick(m, delta)
			return
		"hop":
			if on_ground and t_state > 0.1:
				_to_idle(0.0)
			return
	if m.state == "dead":
		if state != "idle":
			_to_idle(0.0)
		return
	if _distracted(delta):
		return
	_ai(m, delta)


## v0.7 dancing girl: every non-boss enemy on screen rushes to her side and jumps up and down, cheering
var distracted_t := 0.0
var cheer_hops := 0


func _distracted(delta: float) -> bool:
	if boss or game == null or not game.has_method("dancer"):
		return false
	var dn: Node2D = game.dancer()
	if dn == null or absf(global_position.x - game.cam_x) > 1100.0 or absf(dn.global_position.x - global_position.x) > 1600.0:
		if distracted_t > 0.0:
			distracted_t = 0.0
			_to_idle(0.3)
		return false
	distracted_t += delta
	marker.visible = false
	var slot := (float(posmod(get_instance_id(), 7)) - 3.0) * 70.0
	slot += 140.0 * signf(slot if slot != 0.0 else 1.0)
	var tx: float = dn.global_position.x + slot
	var d := tx - global_position.x
	var face := 1 if dn.global_position.x > global_position.x else -1
	if absf(d) > 24.0:
		_face(1 if d > 0.0 else -1)
		vx = signf(d) * maxf(speed, 260.0) * 1.6
		if sprite.animation != _cur_move():
			_play(_cur_move())
		if state != "move":
			_set_state("move")
		return true
	vx = 0.0
	_face(face)
	if state != "cheer":
		_set_state("cheer")
		_play(_cur_idle())
	if flyer:
		position.y = rest_y + 60.0 - absf(sin(distracted_t * 7.0)) * 90.0
	elif on_ground:
		vy = -720.0                       # hop, hop, hop
		on_ground = false
		cheer_hops += 1
	return true


func _physics(delta: float) -> void:
	if flyer:
		if state == "atk" and String(atk.get("mode", "")) == "contact":
			position += swoop_v * delta
		else:
			bob += delta
			var ty := rest_y + sin(bob * 2.2) * 14.0
			position.y = move_toward(position.y, ty, 500.0 * delta)
			position.x += vx * delta
		return
	if not on_ground:
		vy += GRAVITY * delta
		position.y += vy * delta
		if vy > 0.0 and state == "atk" and atk.has("fall") and sprite.animation != atk["fall"]:
			_play(String(atk["fall"]))
		if position.y >= rest_y:
			position.y = rest_y
			vy = 0.0
			on_ground = true
	position.x += vx * delta


func _ai(m: Node2D, delta: float) -> void:
	var gap := gap_to(m)
	var dx: float = m.global_position.x - global_position.x
	var face := 1 if dx > 0.0 else -1
	# 1) an attack in range
	if cooldown <= 0.0 and doused_t <= 0.0 and _may_attack():
		for a in attacks:
			if gap >= float(a["near"]) and gap <= float(a["far"]) and (flyer or absf(m.global_position.y - global_position.y) < 400.0 or a["mode"] == "shot"):
				_start_tell(a, face)
				return
	# 2) move
	var reach := 9999.0
	for a in attacks:
		reach = minf(reach, float(a["far"]))
	var want := gap > reach * 0.7
	var ai := String(d["ai"])
	var spd := speed
	var anim_m := _cur_move()
	if ai == "charger" and d.has("run") and gap < 600.0:     # the hell hound walks far off, runs once near
		spd = float(d["run_speed"])
		anim_m = String(d["run"])
	if doused_t > 0.0:
		spd = float(d["douse"]["speed"])
	if ai == "hopper":
		if want and hop_cd <= 0.0 and on_ground:
			_face(face)
			_set_state("hop")
			_play(String(d["hop"]))
			vy = -1000.0
			vx = face * 320.0
			on_ground = false
			hop_cd = 1.3
			return
		_face(face)
		vx = 0.0
		if sprite.animation != _cur_idle():
			_play(_cur_idle())
		return
	if ai == "flyer":
		var tx: float = m.global_position.x - face * 220.0
		var ddx := tx - global_position.x
		_face(face)
		vx = clampf(ddx * 3.0, -spd, spd)
		if sprite.animation != anim_m:
			_play(anim_m)
		return
	if want and spd > 0.0:
		_face(face)
		vx = face * spd
		if state != "move" or sprite.animation != anim_m:
			_set_state("move")
			_play(anim_m)
	else:
		_face(face)
		vx = 0.0
		if state != "idle" or sprite.animation != _cur_idle():
			_set_state("idle")
			_play(_cur_idle())


func _may_attack() -> bool:
	return game == null or game.frame_n >= int(game.get("knight_calm_until"))


func _start_tell(a: Dictionary, face: int) -> void:
	atk = a
	tell_t = 0.0
	vx = 0.0
	_face(face)
	_set_state("tell")
	history.append("tell:" + String(a["anim"]))
	_play(String(a["anim"]))
	sprite.pause()
	sprite.frame = 0
	marker.set_kind(String(a["kind"]))
	marker.visible = true
	if String(a["kind"]) in ["heavy", "ranged"]:
		Sfx.play("charge", 0.8 if boss else 1.2, -6.0)


func _start_active(m: Node2D) -> void:
	marker.visible = false
	hits_done = {}
	shot_done = false
	_set_state("atk")
	history.append("atk:" + String(atk["anim"]))
	_play(String(atk["anim"]))
	match String(atk["mode"]):
		"frames":
			windows = _calc_windows(atk)
			Sfx.play("swipe", 0.7 if k >= 5.0 else 1.0, -4.0)
		"shot":
			windows = []
		"contact":
			windows = []
			sprite.speed_scale = 1.6
			var v := float(atk.get("vx", 600.0))
			if flyer:
				var mc: Vector2 = m.hurt_rect().get_center()
				swoop_v = (mc - global_position).normalized() * v
			else:
				vx = facing * v
				if atk.has("jump"):
					vy = -float(atk["jump"])
					on_ground = false
			Sfx.play("dash", 1.1, -4.0)


func _active_tick(m: Node2D, delta: float) -> void:
	var mode := String(atk["mode"])
	if mode == "contact":
		if not hits_done.has(0) and m.state != "dead" and hurt_rect().intersects(m.hurt_rect()):
			hits_done[0] = true
			hits_landed += 1
			m.take_hit(int(atk["dmg"]), global_position.x, self)
		_hit_allies(hurt_rect(), 0)
		var done := false
		if atk.has("jump") and not flyer:
			done = on_ground and t_state > 0.1
		else:
			done = t_state >= float(atk.get("dur", 0.5))
		if done:
			if flyer:
				swoop_v = Vector2.ZERO
			_to_idle(float(atk["cd"]))
		return
	if mode == "shot":
		if not shot_done and sprite.frame >= int(atk["shot_frame"]):
			shot_done = true
			_fire(m)
		return
	var w := _window_of(sprite.frame)
	if w >= 0 and not hits_done.has(w) and m.state != "dead":
		if attack_rect().intersects(m.hurt_rect()):
			hits_done[w] = true
			hits_landed += 1
			m.take_hit(int(atk["dmg"]), global_position.x, self)
	if w >= 0:
		_hit_allies(attack_rect(), w)


## v0.7: attacks hurt Mera's allies as well (each ally once per window)
func _hit_allies(r: Rect2, w: int) -> void:
	if game == null or not game.has_method("allies"):
		return
	for a in game.allies():
		var key := "a%d:%d" % [w, a.get_instance_id()]
		if not hits_done.has(key) and r.intersects(a.hurt_rect()):
			hits_done[key] = true
			a.take_hit(int(atk["dmg"]), global_position.x)


func _fire(m: Node2D) -> void:
	var s: Node2D = load("res://scripts/game/enemy_shot.gd").new()
	var hr := hurt_rect()
	var p := Vector2(global_position.x + facing * hr.size.x * 0.4, hr.get_center().y - hr.size.y * 0.15)
	var dir: Vector2 = (m.hurt_rect().get_center() - p).normalized()
	if absf(dir.y) > 0.6:
		dir = Vector2(facing, signf(dir.y) * 0.6).normalized()
	s.setup(game, id, String(atk["shot"]), p, dir * float(atk.get("shot_speed", 700.0)), int(atk["dmg"]), k)
	s.shooter = self
	played[String(atk["shot"])] = true
	get_parent().add_child(s)
	Sfx.play("cast", 0.7, -4.0)


# ---------------------------------------------------------------- look
func _tint() -> void:
	var a := modulate.a
	var base_a := float(d.get("fade", 1.0)) if state != "tell" and state != "atk" else 1.0
	if flash > 0.0:
		sprite.modulate = Color(3, 3, 3, 1)
	elif state == "tell":
		sprite.modulate = TELE.pulse(String(atk["kind"]), tell_t)
	elif state == "stun":
		var q := 0.5 + 0.5 * sin(t_state * 18.0)
		sprite.modulate = Color(0.8 + 0.4 * q, 0.8 + 0.4 * q, 0.55)
	else:
		sprite.modulate = Color(1, 1, 1, base_a)
	modulate.a = a


func _draw_bar() -> void:
	if boss or hp <= 0 or hp >= hp_max:
		return
	var w := 70.0
	bar.draw_rect(Rect2(-w / 2.0 - 2, -2, w + 4, 10), Color(0, 0, 0, 0.7))
	bar.draw_rect(Rect2(-w / 2.0, 0, w * float(hp) / float(hp_max), 6), Color(0.9, 0.2, 0.2))
