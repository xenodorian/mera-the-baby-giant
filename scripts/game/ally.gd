extends Node2D
## v0.7 summoned ally (docs/GAME_RULES.md "Allies"): Water Priestess, Leaf Ranger, Brawler Girl, Dancing Girl.
## Numbers: scripts/game/allies.gd. Art + per-frame boxes: assets/enemies/roster.json (tools/build_roster.py).
## Melee hit boxes are cut from the frames that reach out past the body, as for the roster enemies.
## States: arrive idle move atk air dodge defend heal hit dead leave dance

const ROSTER := preload("res://scripts/game/roster.gd")
const AL := preload("res://scripts/game/allies.gd")
const GRAVITY := 3000.0

# move lists: [anim, damage]; "shot" = frame on which an arrow leaves the bow
const MELEE := {"priestess": [["atk1", 3], ["atk2", 3], ["atk3", 4]], "ranger": [["atk3", 4]], "brawler": [["jab", 2], ["punch", 3], ["kick", 4]]}
const SPECIAL := {"priestess": ["sp", 6], "ranger": ["sp", 6]}
const RANGED := {"ranger": [["atk1", 3, 6], ["atk2", 3, 9]]}
const MELEE_REACH := {"priestess": 150.0, "ranger": 120.0, "brawler": 110.0}

var game: Node = null
var id := ""
var art: Dictionary = {}
var k := 4.0
var hp := 10
var hp_max := 10
var facing := 1
var state := "arrive"
var t_state := 0.0
var stay := 25.0
var age := 0.0
var vx := 0.0
var vy := 0.0
var on_ground := true
var gy := 1060.0
var mv := ""                     # the attack animation being played
var mv_dmg := 0
var windows: Array = []
var hits := {}                   # "window:enemy id" -> true
var shot_frame := -1
var shot_done := false
var combo_i := 0
var attacks_done := 0
var heal_cd := 0.0
var heals := 0
var heal_done := false
var air_phase := ""
var dance_i := 0
var march := 1                   # the brawler always runs right, ahead of Mera
var heal_farewell := false       # the priestess's second heal, played as she leaves
var flash := 0.0
var target_x := 0.0
var played := {}
var history: Array = []
var hits_landed := 0
var sprite: AnimatedSprite2D
var tag: Node2D


func setup(g: Node, ally_id: String) -> void:
	game = g
	id = ally_id
	art = ROSTER.art(id)
	k = float(AL.K[id])
	k = fit_k()
	hp_max = int(AL.HP[id])
	hp = hp_max
	stay = float(AL.STAY_S[id])
	gy = float(g.GROUND_Y) if g else 1060.0
	var m: Node2D = g.mera if g else null
	var mf: int = m.facing if m else 1
	var mx: float = m.global_position.x if m else 960.0
	facing = mf
	march = 1
	match id:
		"priestess":
			position = Vector2(mx - mf * 1000.0, gy)
			target_x = mx - mf * 170.0
		"dancer":
			position = Vector2(mx - mf * 60.0, gy)
			target_x = mx + mf * 460.0
		"brawler":
			facing = 1
			position = Vector2(mx + 40.0, gy)
			target_x = mx + 280.0
		_:
			position = Vector2(mx - mf * 520.0, gy)
			target_x = mx - mf * 160.0


func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _frames(id)
	sprite.centered = false
	add_child(sprite)
	sprite.animation_finished.connect(_on_anim_done)
	tag = Node2D.new()
	tag.position = Vector2(0, float(art["body"][1]) * k - 22.0)
	tag.draw.connect(_draw_tag)
	add_child(tag)
	_arrive()


static var _cache: Dictionary = {}


static func _frames(aid: String) -> SpriteFrames:
	if _cache.has(aid):
		return _cache[aid]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var anims: Dictionary = ROSTER.art(aid)["anims"]
	for a in anims:
		var e: Dictionary = anims[a]
		sf.add_animation(a)
		sf.set_animation_speed(a, float(e["fps"]))
		sf.set_animation_loop(a, bool(e["loop"]))
		for p in e["frames"]:
			sf.add_frame(a, load(p))
	_cache[aid] = sf
	return sf


# ---------------------------------------------------------------- helpers
func _play(a: String, from: int = 0) -> void:
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(a):
		return
	if not art["anims"].has(a):
		return
	var n := sprite.sprite_frames.get_frame_count(a)
	if n <= 0:
		return
	played[a] = true
	var e: Dictionary = art["anims"][a]
	sprite.offset = Vector2(-float(e["pivot"][0]), -float(e["pivot"][1]))
	sprite.play(a)
	sprite.frame = clampi(from, 0, n - 1)
	sprite.speed_scale = 1.0


func _go(s: String, a: String = "") -> void:
	state = s
	t_state = 0.0
	history.append(s if a == "" else s + ":" + a)
	if a != "":
		_play(a)


## v0.8: allies are drawn relative to Mera's size so a 1x Mera isn't dwarfed: about 1.1x her height, never bigger
## than their v0.7 size (AL.K) and never below 35 % of it. Eases over ~0.5 s when she grows or shrinks.
func fit_k() -> float:
	var full := float(AL.K[id])
	if game == null or game.get("mera") == null:
		return full
	var ib: Array = AnimLib.frames("idle")[0]["body"]
	var mh: float = (float(ib[3]) - float(ib[1])) * float(game.mera.shown)
	var b: Array = art["body"]
	var bh := float(b[3]) - float(b[1])
	return clampf(mh * 1.1 / maxf(bh, 1.0), full * 0.35, full)


func _fit_size(delta: float) -> void:
	var want := fit_k()
	if absf(want - k) > 0.001:
		k = move_toward(k, want, maxf(absf(want - k), 0.5) * 4.0 * delta)
		_face(0)
		tag.position = Vector2(0, float(art["body"][1]) * k - 22.0)


func _face(d: int) -> void:
	if d != 0:
		facing = d
	sprite.scale = Vector2(k * facing, k)


func _box(b: Array) -> Rect2:
	var x0 := float(b[0])
	var x1 := float(b[2])
	if facing < 0:
		var t := x0
		x0 = -x1
		x1 = -t
	return Rect2(global_position + Vector2(x0, float(b[1])) * k, Vector2(x1 - x0, float(b[3]) - float(b[1])) * k)


func hurt_rect() -> Rect2:
	if id == "dancer":
		return Rect2()
	var b: Array = art["body"]
	var w := float(b[2]) - float(b[0])
	return _box([float(b[0]) + w * 0.15, b[1], float(b[2]) - w * 0.15, b[3]])


func alive() -> bool:
	return hp > 0 and state != "dead"


func dancing() -> bool:
	return id == "dancer" and state == "dance"


func _calc_windows(a: String) -> Array:
	var out: Array = []
	var boxes: Array = art["anims"][a]["boxes"]
	var body: Array = art["body"]
	var bw := float(body[2]) - float(body[0])
	var cur: Array = []
	for f in boxes.size():
		var b: Array = boxes[f]
		var act := f > 0 and (float(b[2]) - float(body[2]) >= 0.25 * bw or (float(b[3]) - float(b[1])) > 1.4 * (float(body[3]) - float(body[1])))
		if act:
			cur.append(f)
		elif not cur.is_empty():
			out.append(cur)
			cur = []
	if not cur.is_empty():
		out.append(cur)
	if out.is_empty():                                  # no frame reaches out: the middle third of the move hits
		var n := boxes.size()
		var w: Array = []
		for f in range(n / 3, maxi(n * 2 / 3, n / 3 + 1)):
			w.append(f)
		out.append(w)
	return out


func _attack_rect() -> Rect2:
	var f := sprite.frame
	var boxes: Array = art["anims"][mv]["boxes"]
	var b: Array = boxes[mini(f, boxes.size() - 1)].duplicate()
	var body: Array = art["body"]
	b[0] = maxf(float(b[0]), 0.0)                       # only what is in front of her
	b[2] = maxf(float(b[2]), float(body[2]) + 6.0)
	return _box(b)


func _enemies() -> Array:
	return game.enemies() if game else []


func _nearest() -> Node2D:
	var best: Node2D = null
	var bd := INF
	for e in _enemies():
		var dd: float = absf(e.global_position.x - global_position.x)
		if dd < bd:
			bd = dd
			best = e
	return best


func _gap(e: Node2D) -> float:
	var r: Rect2 = e.hurt_rect()
	var me := hurt_rect()
	return absf(r.get_center().x - me.get_center().x) - r.size.x / 2.0 - me.size.x / 2.0


# ---------------------------------------------------------------- life cycle
func _arrive() -> void:
	match id:
		"priestess":
			_go("arrive", "surf")
		"dancer":
			_go("arrive", "skip")
		_:
			_go("arrive", "jump")
			vy = -1100.0
			on_ground = false
	_face(1 if target_x > position.x else -1)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


func leave() -> void:
	if state == "leave" or state == "dead":
		return
	var away: int = -int(game.mera.facing) if game else -1
	_face(away)
	match id:
		"priestess":
			_go("leave", "surf")
		"ranger":
			_go("leave", "run")
		"brawler":
			_go("leave", "walk")
		"dancer":
			_go("leave", "skip")
	vx = 0.0
	on_ground = true
	position.y = gy


## enemies hit allies too (monster.gd); the priestess / ranger block while defending
func take_hit(dmg: int, from_x: float) -> void:
	if not alive() or state == "leave" or state == "arrive" or state == "dodge" or id == "dancer":
		return
	if state == "defend":
		Sfx.play("block", 1.2)
		return
	hp -= dmg
	flash = 0.12
	_face(1 if from_x > global_position.x else -1)
	vx = 0.0
	if hp <= 0:
		hp = 0
		if id == "brawler":
			_go("dead", "hurt")
		else:
			_go("dead", "death")
		var t := create_tween()
		t.tween_interval(1.4)
		t.tween_property(self, "modulate:a", 0.0, 0.5)
		t.tween_callback(queue_free)
		return
	_go("hit", "hurt" if id == "brawler" else "hit")
	position.x += (-1.0 if from_x > global_position.x else 1.0) * 3.0 * k


func _on_anim_done() -> void:
	match state:
		"atk", "heal", "hit", "dodge":
			if state == "heal" and heal_farewell:
				leave()
			else:
				_idle()
		"defend":
			if sprite.animation == "defend":
				_idle()
		"air":
			if air_phase == "attack":
				air_phase = "fall"
				if id == "brawler":
					_play("dive_kick")
					mv = "dive_kick"
					mv_dmg = 4
					windows = _calc_windows("dive_kick")
					hits = {}
					vx = facing * 500.0
					vy = maxf(vy, 900.0)
				else:
					_play("j_down")
		"leave":
			pass


func _idle() -> void:
	vx = 0.0
	mv = ""
	_go("idle", "hips" if id == "dancer" else "idle")


func _physics_process(delta: float) -> void:
	t_state += delta
	age += delta
	heal_cd -= delta
	flash -= delta
	sprite.modulate = Color(3, 3, 3) if flash > 0.0 else Color(1, 1, 1)
	if game == null:
		return
	_fit_size(delta)
	_gravity(delta)
	if state == "leave":
		vx = 0.0
	position.x += vx * delta
	match state:
		"dead":
			return
		"leave":
			modulate.a = clampf(1.0 - t_state / 0.6, 0.0, 1.0)
			if t_state >= 0.6:
				queue_free()
			return
		"arrive":
			_arrive_tick()
			return
		"atk", "air":
			_hit_tick()
			if state == "air" and on_ground and t_state > 0.15:
				_idle()
			return
		"hit", "heal":
			if state == "heal" and sprite.frame >= 7 and not heal_done:
				heal_done = true
				heals += 1
				game.mera.set_size(AL.HEAL_TO)
				Sfx.play("heal", 1.0)
				game.hit_spark(game.mera.hurt_rect().get_center(), 3.0)
			return
		"dodge":
			if t_state > 0.45:
				vx = move_toward(vx, 0.0, 3000.0 * delta)
			return
		"defend":
			if sprite.animation == "defend_pose" and _threat() == null:
				_play("defend")                                         # the blow comes: the block itself
			return
		"dance":
			_dance_tick()
			if t_state >= AL.DANCE_S:
				_idle()
				return
			if age >= stay:
				leave()
			return
	if age >= stay:
		if id == "priestess" and heals < 2:
			_begin_heal(true)
			return
		leave()
		return
	_ai(delta)


func _gravity(delta: float) -> void:
	if on_ground:
		return
	vy += GRAVITY * delta
	position.y += vy * delta
	if state == "air" and air_phase == "rise" and vy > -700.0:
		air_phase = "attack"
		var a := "jump_kick" if id == "brawler" else "air"
		_play(a)
		mv = a
		mv_dmg = 3
		windows = _calc_windows(a)
		hits = {}
	if position.y >= gy:
		position.y = gy
		vy = 0.0
		on_ground = true


func _arrive_tick() -> void:
	var d := target_x - position.x
	if id == "priestess" or id == "dancer":
		vx = signf(d) * (900.0 if id == "priestess" else 520.0)
		if absf(d) < 30.0:
			vx = 0.0
			if id == "dancer":
				_go("dance", "hips")
			elif id == "priestess":
				_begin_heal(false)
			else:
				_idle()
		return
	vx = clampf(d * 2.0, -700.0, 700.0)
	if on_ground and t_state > 0.1:
		vx = 0.0
		_idle()


func _dance_tick() -> void:
	vx = 0.0
	var moves := ["hips", "snap", "balancing", "slide"]
	var i := int(t_state / 1.5) % moves.size()
	if sprite.animation != moves[i]:
		_play(moves[i])
	_face(1 if int(t_state / 0.75) % 2 == 0 else -1)


## an enemy winding up an attack close by
func _threat() -> Node2D:
	for e in _enemies():
		if String(e.get("state")) == "tell" and _gap(e) < 320.0:
			return e
	return null


func _ai(_delta: float) -> void:
	var m: Node2D = game.mera
	if id == "dancer":
		vx = 0.0
		if state != "idle":
			_idle()
		return
	# a nearby wind-up: the priestess and ranger block or dodge. The brawler keeps chasing.
	if id != "brawler":
		var th := _threat()
		if th != null:
			_face(1 if th.global_position.x > global_position.x else -1)
			var rush: bool = th.get("atk") is Dictionary and String((th.get("atk") as Dictionary).get("kind", "")) == "rush"
			if not rush:
				_go("defend", "defend_pose" if id == "ranger" else "defend")
				vx = 0.0
				return
			if on_ground:
				_dodge(-facing)
				return
	var e: Node2D = _nearest()
	if e == null:
		if id == "brawler":
			vx = 0.0
			if state != "idle":
				_idle()
		else:
			_follow(m)
		return
	var gap := _gap(e)
	var face := 1 if e.global_position.x > global_position.x else -1
	_face(face)
	var air_target: bool = bool(e.get("flyer")) if e.get("flyer") != null else false
	# 3) flyers in reach: jump attack
	if air_target and gap < 260.0 and on_ground:
		_jump_attack()
		return
	# 4) the ranger shoots from range, backs off when crowded
	if id == "ranger":
		if gap > 200.0 and gap < 1000.0:
			if attacks_done % 4 == 3:
				_attack(SPECIAL[id][0], int(SPECIAL[id][1]))
			else:
				var r: Array = RANGED[id][combo_i % 2]
				combo_i += 1
				_attack(r[0], int(r[1]), int(r[2]))
			return
		if gap < 60.0 and on_ground:
			_dodge(-face)
			return
	# 5) melee in reach (every 4th attack the special, if she has one)
	if gap <= MELEE_REACH[id]:
		if SPECIAL.has(id) and attacks_done % 4 == 3:
			_attack(SPECIAL[id][0], int(SPECIAL[id][1]))
		else:
			var ml: Array = MELEE[id]
			var a: Array = ml[combo_i % ml.size()]
			combo_i += 1
			_attack(a[0], int(a[1]))
		return
	# 6) the brawler closes in with a jump kick
	if id == "brawler" and gap > 160.0 and gap < 420.0 and on_ground and attacks_done % 3 == 2:
		attacks_done += 1
		_jump_attack()
		vx = face * 450.0
		return
	# 7) walk / run over (the priestess surfs long distances)
	_travel(face, gap)


func _travel(face: int, gap: float) -> void:
	var a := "run" if id == "ranger" else "walk"
	var spd := float(AL.SPEED[id])
	if id == "priestess" and gap > 600.0:
		a = "surf"
		spd *= 2.6
	elif id == "ranger" and gap > 700.0:
		a = "slide_loop" if sprite.animation in ["slide", "slide_loop"] else "slide"
		spd *= 2.2
	vx = face * spd
	if state != "move" or sprite.animation != a:
		if a == "slide_loop" and sprite.animation == "slide" and sprite.is_playing():
			pass
		else:
			_go("move", a)


func _march() -> void:
	march = 1
	_face(1)
	var spd := float(AL.SPEED[id]) * 1.85
	var hero: Node2D = game.mera
	if hero != null and global_position.x < hero.global_position.x + 120.0:
		spd = maxf(spd, 720.0)
	vx = spd
	if state != "move" or sprite.animation != "walk":
		_go("move", "walk")
	sprite.speed_scale = 1.8


func _wall_ahead() -> bool:
	if game == null:
		return false
	var probe := Rect2(global_position + Vector2(10.0, -100.0), Vector2(36.0, 96.0))
	for p in game.props:
		if not is_instance_valid(p) or not p.has_method("blocks_path") or not p.blocks_path():
			continue
		if p.hurt_rect().intersects(probe):
			return true
	return false


func _ahead() -> Node2D:
	var best: Node2D = null
	var bd := 1400.0
	for e in _enemies():
		var dx: float = (e.global_position.x - global_position.x) * float(march)
		if dx < -40.0:
			continue
		if dx < bd:
			bd = dx
			best = e
	return best


func _begin_heal(farewell: bool) -> void:
	if state == "heal" or state == "leave" or state == "dead":
		return
	if game == null or game.mera.state == "dead":
		if farewell:
			leave()
		return
	heal_farewell = farewell
	heal_done = false
	vx = 0.0
	_face(1 if game.mera.global_position.x > global_position.x else -1)
	_go("heal", "heal")


func _follow(m: Node2D) -> void:
	var tx: float = m.global_position.x - m.facing * 190.0
	var d := tx - global_position.x
	if absf(d) < 40.0:
		if state != "idle":
			_idle()
		_face(m.facing)
		vx = 0.0
		return
	_travel(1 if d > 0.0 else -1, absf(d))


func _attack(a: String, dmg: int, shot_at: int = -1) -> void:
	attacks_done += 1
	mv = a
	mv_dmg = dmg
	hits = {}
	vx = 0.0
	shot_frame = shot_at
	shot_done = false
	windows = [] if shot_at >= 0 else _calc_windows(a)
	_go("atk", a)
	Sfx.play("swipe", 1.2, -6.0)


func _jump_attack() -> void:
	mv = ""
	air_phase = "rise"
	vy = -1250.0
	on_ground = false
	if id == "brawler":
		_go("air", "jump")
	else:
		_go("air", "j_up")


func _dodge(dir: int) -> void:
	_face(-dir)
	vx = dir * 900.0
	_go("dodge", "tumble" if id == "priestess" else "roll" if id == "ranger" else "jump")
	if id == "brawler":
		vy = -800.0
		on_ground = false


func _hit_tick() -> void:
	if mv == "":
		return
	if shot_frame >= 0:
		if not shot_done and sprite.frame >= shot_frame:
			shot_done = true
			_arrow()
		return
	var f := sprite.frame
	var w := -1
	for i in windows.size():
		if f in windows[i]:
			w = i
	if w < 0:
		return
	var r := _attack_rect()
	for e in _enemies():
		var key := "%d:%d" % [w, e.get_instance_id()]
		if hits.has(key):
			continue
		if r.intersects(e.hurt_rect()):
			hits[key] = true
			if e.take_damage(mv_dmg, global_position.x, "melee"):
				hits_landed += 1
				game.hit_spark(e.hurt_rect().get_center(), 2.0)
				Sfx.play("hit", 1.2, -4.0)


func _arrow() -> void:
	var s: Node2D = load("res://scripts/game/ally_arrow.gd").new()
	var hr := hurt_rect()
	s.setup(game, self, Vector2(global_position.x + facing * hr.size.x * 0.6, hr.get_center().y - hr.size.y * 0.1), facing, mv_dmg, k)
	get_parent().add_child(s)
	played["arrow"] = true
	Sfx.play("cast", 1.4, -8.0)


func _draw_tag() -> void:
	var c: Color = AL.COLORS[id]
	tag.draw_rect(Rect2(-9, -9, 18, 18), Color(0, 0, 0, 0.6))
	tag.draw_rect(Rect2(-6, -6, 12, 12), c)
