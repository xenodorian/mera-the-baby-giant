extends "res://scripts/game/monster.gd"
## Perry as the boss of Perry's Arena (docs/GAME_RULES.md "Perry's boss fight"). A roster enemy (monster.gd interface) with its own AI:
## - SIZE IS HEALTH like the dragon: 25x, Tuning.DRAGON_HP_PER_SIZE hp per size, the HUD draws "PERRY   25x" with ticks. Her drawn scale
##   (k = 5) never changes.
## - ALL her player moves, as data: Tuning.PERRY_BOSS_MOVES (frames, timing, root motion and hit boxes come from assets/perry/perry_player.json
##   through PerryPlayer.mdef). Picked by distance band and weight, never the same move more than twice in a row, in chains of up to 3 with no
##   pause. Every attack has a tell of at least Telegraph.MIN_TELL; the riposte after a parry is the one exception (the parry was the warning).
## - PARRY: a free Perry (idle, walking, healing, in a tell) parries Mera's melee 9 times in 10 and every real projectile (reflected at Mera).
##   Beams, lightning, explosions, quakes and allies are never parried. Stunned, bursting, guarding, in the ultimate or in the active and
##   recovery frames of a move, she cannot parry.
## - HEAL: undamaged for 1 s, nobody attacking her, Mera far: she kneels (recover) and regains a full bar in 6 s.
## - BURST: 3 hits in 2.5 s with Mera within 260 px (parried ones count), or Mera in melee range for 3 s: energy burst (2 damage, Mera thrown
##   back 600 px), then she backs off. 5 s between bursts.
## - PHASES by hp: 1 above 66 %, 2 to 33 % (beams, meteors, bigger kicks, x0.75 pauses), 3 below (x0.5, rainbow guard, ultimate chain, burst chain).

const PP := preload("res://scripts/game/perry_player.gd")
const FX := preload("res://scripts/game/perry_boss_fx.gd")
const MOVES: Dictionary = Tuning.PERRY_BOSS_MOVES

var size := 25
var hps := 8
var clock := 0.0
var dmg_t := 99.0                  # seconds since she last lost hp
var hit_times: Array = []          # clock times of Mera's hits on her (parried ones too)
var near_t := 0.0                  # seconds Mera has stayed within melee range
var burst_pending := false
var burst_cd := 0.0
var guard_cd := 0.0
var ult_cd := 0.0
var guard_t := 0.0
var inv_now := false               # the dash's invulnerable part
var parry_cd := 0.0
var parry_t := 0.0
var riposte_pending := false
var queue: Array = []              # moves to run next: {"id", "dir"}
var cur_id := ""
var cur: Dictionary = {}
var steps: Array = []
var step_i := 0
var st_id := ""
var st: Dictionary = {}
var st_frames: Array = []
var st_i := 0
var st_t := 0.0
var st_x0 := 0.0
var st_dir := 1
var st_retreat := false
var st_win := -1
var st_hits := {}
var st_flags := {}
var st_xe := 0.0
var tell_len := 0.35
var chain_n := 0
var chain_next := false
var mcd := {}
var recent: Array = []
var move_log: Array = []           # tests: every move started (top level ids)
var step_log: Array = []           # tests: every step started
var tell_log: Array = []           # tests: every tell length used (the riposte has none)
var riposte_log: Array = []
var phase_seen := 1
var phase_log: Array = []
var lift := 0.0
var heal_acc := 0.0
var healed := 0
var heal_spark := 0.0
var parries := 0
var blocks := 0
var reflected := 0
var reflected_hits := 0
var bursts := 0
var guards := 0
var ults := 0
var knock := {}                    # Mera's slide: {"left": px, "v": px/s}
var wander_t := 0.0
var wander_dir := 0
var fx_node: AnimatedSprite2D
var fx_live: Array = []
var meteor_left := 0
var meteor_t := 0.0
var meteor_i := 0
var hc := -29.0
var inv_t := 0.0
var last_burst_knock := 0.0


func setup(g: Node, enemy_id: String, x: float, opts: Dictionary = {}) -> void:
	var o := opts.duplicate()
	o["stage2"] = false                                 # she is never resized or doubled
	super(g, enemy_id, x, o)
	hps = Tuning.DRAGON_HP_PER_SIZE
	size = Tuning.PERRY_BOSS_SIZE
	hp_max = size * hps
	hp = hp_max
	k = Tuning.PERRY_BOSS_K
	speed = Tuning.PERRY_BOSS_SPEED
	hc = float(PP.data()["hc"])
	if g != null and g.get("mera") != null:               # never inside Mera at spawn
		var mx: float = g.mera.global_position.x
		if absf(position.x - mx) < 900.0:
			var side := 1.0 if mx < float(g.map_w) * 0.5 else -1.0
			position.x = clampf(mx + side * 1100.0, Levels.EDGE, float(g.map_w) - Levels.EDGE)


func _ready() -> void:
	super()
	queue.append({"id": "taunt"})                         # the opening feint
	cooldown = 0.8


# ---------------------------------------------------------------- shape and drawing
func size_of_hp() -> int:
	return clampi(ceili(float(hp) / float(hps)), 1, Tuning.PERRY_BOSS_SIZE)


func phase_now() -> int:
	var f := float(hp) / float(hp_max)
	if f <= float(Tuning.PERRY_BOSS_PHASES[1]):
		return 3
	if f <= float(Tuning.PERRY_BOSS_PHASES[0]):
		return 2
	return 1


func hurt_rect() -> Rect2:
	var hw := Tuning.PERRY_BOSS_HURT_HW * k
	var h := Tuning.PERRY_BOSS_HURT_H * k
	return Rect2(global_position.x - hw, global_position.y - h, hw * 2.0, h)


func body_w() -> float:
	return Tuning.PERRY_BOSS_HURT_HW * k * 2.0


func gap_to(m: Node2D) -> float:
	var mr: Rect2 = m.hurt_rect()
	return absf(mr.get_center().x - global_position.x) - mr.size.x / 2.0 - Tuning.PERRY_BOSS_HURT_HW * k


func blocking() -> bool:
	return false


func _play(a: String, from: int = 0) -> void:
	super(a, from)
	if sprite != null and art["anims"].has(a):
		var e: Dictionary = art["anims"][a]
		sprite.offset = Vector2(-(float(e["pivot"][0]) + hc), -float(e["pivot"][1]))   # her body centre sits on the node


func _face(dd: int) -> void:
	super(dd)
	if fx_node != null and dd != 0:
		fx_node.scale = Vector2(k * dd, k)


func _show(anim: String, i: int) -> void:
	if sprite == null:
		return
	if sprite.animation != anim or sprite.is_playing():
		_play(anim)
		sprite.pause()
	var n := sprite.sprite_frames.get_frame_count(anim)
	sprite.frame = clampi(i, 0, maxi(n - 1, 0))


func _on_anim_done() -> void:
	pass


func _draw_bar() -> void:
	pass                                                 # the HUD draws the boss bar


func _tint() -> void:
	var a := modulate.a
	if flash > 0.0:
		sprite.modulate = Color(3, 3, 3, 1)
	elif state == "tell" and not atk.is_empty():
		sprite.modulate = TELE.pulse(String(atk["kind"]), tell_t)
	elif state == "stun":
		var q := 0.5 + 0.5 * sin(t_state * 18.0)
		sprite.modulate = Color(0.8 + 0.4 * q, 0.8 + 0.4 * q, 0.55)
	elif state == "heal":
		var q2 := 0.5 + 0.5 * sin(t_state * 9.0)
		sprite.modulate = Color(0.75 + 0.1 * q2, 1.2 + 0.5 * q2, 0.8 + 0.1 * q2)
	elif guard_t > 0.0:
		sprite.modulate = Color.from_hsv(fmod(clock * 1.6, 1.0), 0.55, 1.7)
	else:
		sprite.modulate = Color(1, 1, 1, 1)
	modulate.a = a


## a hit box relative to her body centre (x forward, y down from the feet, native px) -> world rect
func _wrect(r: Rect2) -> Rect2:
	var x0 := r.position.x * k
	var x1 := r.end.x * k
	if facing < 0:
		var t := x0
		x0 = -x1
		x1 = -t
	return Rect2(global_position.x + x0, global_position.y + r.position.y * k, x1 - x0, r.size.y * k)


func _hit_rects() -> Array:
	var out: Array = []
	if state != "atk" or st.is_empty():
		return out
	if String(st.get("h", "")) == "burst":
		if st_i >= 3 and st_i <= 5:
			out.append(Rect2(global_position.x - Tuning.PERRY_BOSS_BURST_R, global_position.y - Tuning.PERRY_BOSS_BURST_H, Tuning.PERRY_BOSS_BURST_R * 2.0, Tuning.PERRY_BOSS_BURST_H))
		return out
	if st_i < st_frames.size():
		for r in st_frames[st_i]["hits"]:
			out.append(_wrect(r))
	return out


func attack_rect() -> Rect2:
	var rs := _hit_rects()
	if rs.is_empty():
		return Rect2()
	var u: Rect2 = rs[0]
	for r in rs:
		u = u.merge(r)
	return u


func table() -> Dictionary:
	return MOVES


# ---------------------------------------------------------------- damage
func _invulnerable() -> bool:
	return inv_t > 0.0 or inv_now


func _can_parry() -> bool:
	if hp <= 0 or guard_t > 0.0 or parry_cd > 0.0:
		return false
	if state in ["idle", "move", "heal"]:
		return true
	if state == "tell":
		return not bool(cur.get("np", false))
	return false


func _can_reflect() -> bool:
	if hp <= 0 or guard_t > 0.0 or state in ["stun", "dead", "juggle", "spawn", "gone"]:
		return false
	if state in ["tell", "atk"] and bool(cur.get("np", false)):
		return false
	return true


func take_damage(amount: int, from_x: float, kind: String = "melee") -> bool:
	if hp <= 0 or amount <= 0 or game == null:
		return false
	if _invulnerable():
		return false
	var m: Node2D = game.mera
	var mera_melee: bool = kind in ["melee", "launch", "slam"] and absf(from_x - m.global_position.x) < 2.0
	hit_times.append(clock)
	if mera_melee:
		if _can_parry() and rng.randf() < Tuning.PERRY_BOSS_PARRY_P:
			_do_parry(m)
			return false
		if state in ["idle", "move"] and parry_cd > 0.0:                  # caught between parries: she blocks
			amount = maxi(1, roundi(float(amount) * Tuning.PERRY_BOSS_BLOCK_MUL))
			blocks += 1
			position.x += signf(global_position.x - m.global_position.x) * Tuning.PERRY_BOSS_BLOCK_SLIDE
			Sfx.play("block")
	if guard_t > 0.0:
		amount = maxi(1, roundi(float(amount) * Tuning.PERRY_BOSS_GUARD_DMG))
	hp = maxi(hp - amount, 0)
	size = size_of_hp()
	flash = 0.12
	dmg_t = 0.0
	last_from_x = from_x
	last_kind = kind
	if state == "heal":
		_to_idle_p(0.1)
	if hp == 0:
		_die()
	return true


func _die() -> void:
	_clear_fx()
	lift = 0.0
	guard_t = 0.0
	inv_now = false
	super()


func _do_parry(m: Node2D) -> void:
	parries += 1
	parry_cd = Tuning.PERRY_BOSS_PARRY_CD_S
	_abort_move()
	marker.visible = false
	riposte_pending = true
	parry_t = 0.0
	_set_state("parry")
	_face(1 if m.global_position.x > global_position.x else -1)
	_show("parry", 0)
	var away := 1.0 if m.global_position.x > global_position.x else -1.0
	_stagger_mera(m, away)
	game.parry_fx(Vector2((m.global_position.x + global_position.x) / 2.0, global_position.y - 160.0), 1.6)
	Sfx.play("parry")


func _stagger_mera(m: Node2D, away: float) -> void:
	if m.state in ["dead", "gallery"]:
		return
	if m.has_method("_interrupt"):
		m._interrupt()
	elif m.has_method("_interrupt_p"):
		m._interrupt_p()
	m.state = "hurt"
	if m.get("hurt_t") != null:                          # PerryPlayer
		m.hurt_t = Tuning.PERRY_BOSS_STAGGER_S
		m._set_hurt_pose()
	elif m.has_method("_play"):
		m._play("hurt")
	if m.get("vel") != null:
		m.vel.x = 0.0
	_shove_mera(away * Tuning.PERRY_BOSS_STAGGER_PX, 0.3)


func _shove_mera(px: float, dur: float) -> void:
	knock = {"left": px, "v": absf(px) / maxf(dur, 0.05)}


func _knock_tick(delta: float) -> void:
	if knock.is_empty():
		return
	var m: Node2D = game.mera
	var left: float = knock["left"]
	var step := signf(left) * minf(absf(left), float(knock["v"]) * delta)
	m.position.x = clampf(m.position.x + step, Levels.EDGE, float(game.map_w) - Levels.EDGE)
	knock["left"] = left - step
	if absf(float(knock["left"])) < 0.5 or m.state == "dead":
		knock = {}


## Mera takes a hit from one of her moves (or a beam, meteor, wave, reflected bolt). Returns true when it landed.
func hit_mera(dmg: int, from_x: float, knock_px: float = 0.0, knock_s: float = 0.0) -> bool:
	var m: Node2D = game.mera
	if m.state == "dead" or dmg <= 0:
		return false
	var prev_state: String = m.state
	var prev_inv := 0.0
	if m.get("invuln") != null:
		prev_inv = float(m.invuln)
	m.take_hit(dmg, from_x, self)
	var landed: bool = (m.state == "hurt" or m.state == "dead") and prev_state != "hurt" and prev_inv <= 0.0
	if landed:
		hits_landed += 1
		if knock_px > 0.0 and m.state == "hurt":
			var away := 1.0 if m.global_position.x >= from_x else -1.0
			_shove_mera(away * knock_px, knock_s if knock_s > 0.0 else Tuning.PERRY_BOSS_KNOCK_S)
			if m.get("vel") != null:
				m.vel.x = 0.0
	return landed


## earthquake and every other stun: on the ground she is stunned for the full time (at least PERRY_BOSS_STUN_MIN_S)
func stun(t: float) -> void:
	if hp <= 0 or not on_ground or t <= 0.0 or lift > 1.0:
		return
	if state == "stun":
		stun_t = maxf(stun_t, t)
		return
	_abort_move()
	queue.clear()
	chain_n = 0
	chain_next = false
	marker.visible = false
	vx = 0.0
	stun_t = maxf(t, Tuning.PERRY_BOSS_STUN_MIN_S)
	stunned_total += 1
	_set_state("stun")
	sprite.pause()


func parried(_t: float) -> void:
	pass                                                 # parry stuns do not apply to her


func shove(_d: float) -> void:
	pass


# ---------------------------------------------------------------- tick
func _physics_process(delta: float) -> void:
	t_state += delta
	flash -= delta
	clock += delta
	_tint()
	if state == "dead" and game != null:
		_corpse_tick(delta)
		return
	if hp <= 0 or game == null:
		return
	var m: Node2D = game.mera
	cooldown -= delta
	dmg_t += delta
	parry_cd -= delta
	burst_cd -= delta
	guard_cd -= delta
	ult_cd -= delta
	inv_t -= delta
	if guard_t > 0.0 and not (state == "atk" and String(st.get("h", "")) == "guard"):
		guard_t = 0.0
	for id in mcd.keys():
		mcd[id] = float(mcd[id]) - delta
	_knock_tick(delta)
	while not hit_times.is_empty() and clock - float(hit_times[0]) > Tuning.PERRY_BOSS_AGG_WINDOW_S:
		hit_times.pop_front()
	if state == "stun":
		stun_t -= delta
		sprite.position.x = sin(t_state * 30.0) * 1.5 * k
		if stun_t <= 0.0:
			sprite.position.x = 0.0
			sprite.play()
			_to_idle_p(0.3)
		return
	if m.state == "dead":
		if state != "idle":
			_abort_move()
			_to_idle_p(0.0)
		return
	_scan_projectiles(m)
	_pressure(delta, m)
	var ph := phase_now()
	if ph > phase_seen:                                   # a new phase starts with a taunt feint
		phase_seen = ph
		phase_log.append(ph)
		if state in ["idle", "move", "heal"] or state == "tell":
			_abort_move()
		queue.push_front({"id": "taunt", "feint": true})
	match state:
		"tell":
			tell_t += delta
			if not st_retreat and tell_t < tell_len * 0.5:
				_face(1 if m.global_position.x > global_position.x else -1)
			if tell_t >= tell_len:
				_start_step()
		"atk":
			_step_tick(delta, m)
		"parry":
			_parry_tick(delta, m)
		"heal":
			_heal_tick(delta, m)
		_:
			_brain(delta, m)
	position.x += vx * delta
	position.x = clampf(position.x, Levels.EDGE, float(game.map_w) - Levels.EDGE)
	position.y = rest_y - lift
	on_ground = lift <= 1.0


func _to_idle_p(cd: float) -> void:
	marker.visible = false
	atk = {}
	vx = 0.0
	lift = 0.0
	inv_now = false
	cooldown = maxf(cooldown, cd)
	_set_state("idle")
	_play(idle_a)
	sprite.speed_scale = 1.0


func _clear_fx() -> void:
	for n in fx_live:
		if is_instance_valid(n):
			n.queue_free()
	fx_live.clear()
	if fx_node != null and is_instance_valid(fx_node):
		fx_node.queue_free()
	fx_node = null


## drop whatever she is doing (a parry, a stun, a phase change)
func _abort_move() -> void:
	_clear_fx()
	meteor_left = 0
	lift = 0.0
	position.y = rest_y
	inv_now = false
	guard_t = 0.0
	st = {}
	steps = []
	cur = {}
	cur_id = ""
	atk = {}
	vx = 0.0
	marker.visible = false
	if state in ["tell", "atk", "heal"]:
		_set_state("idle")


# ---------------------------------------------------------------- what is happening around her
func _player_attacking(m: Node2D) -> bool:
	var dx := absf(m.global_position.x - global_position.x)
	if m.state == "move" and dx < Tuning.PERRY_BOSS_WATCH_PX + 400.0:
		var mvd = m.get("mv")
		if mvd != null and int(mvd.get("dmg", 0)) > 0:
			return true
	if m.has_method("beam_world_rect"):
		var br: Rect2 = m.beam_world_rect()
		if br.size != Vector2.ZERO and absf(br.get_center().x - global_position.x) < 1400.0:
			return true
	if game.world != null:
		for n in game.world.get_children():
			if is_instance_valid(n) and n is Shot and not n.done and absf(n.global_position.x - global_position.x) < Tuning.PERRY_BOSS_WATCH_PX:
				return true
	return false


func _shot_dir(n: Node) -> float:
	if n.homing:
		return n.heading.x
	if n.aim != Vector2.ZERO:
		return n.aim.x
	if n.up:
		return 0.0
	return float(n.dir)


## every real projectile heading at her within PARRY_SCAN_PX is reflected at Mera (beams, area effects and allies are not)
func _scan_projectiles(m: Node2D) -> void:
	if game.world == null or not _can_reflect():
		return
	var hr := hurt_rect()
	var c := hr.get_center()
	for n in game.world.get_children():
		if not is_instance_valid(n) or not (n is Shot) or n.done or not n.damaging:
			continue
		var vdir: float = _shot_dir(n)
		var dxs: float = c.x - n.global_position.x
		if vdir == 0.0 or dxs * vdir <= 0.0 or absf(dxs) > Tuning.PERRY_BOSS_PARRY_SCAN_PX + hr.size.x / 2.0:
			continue
		if n.global_position.y < hr.position.y - 150.0 or n.global_position.y > hr.end.y + 150.0:
			continue
		_reflect(n, m)


func _reflect(n: Node, m: Node2D) -> void:
	reflected += 1
	var p: Vector2 = n.global_position
	var sp: float = (float(n.speed()) if n.kind == "bolt" else 700.0) * Tuning.PERRY_BOSS_REFLECT_SPEED
	var dir: Vector2 = (m.hurt_rect().get_center() - p).normalized()
	var vis: Node2D = null
	if n.spr != null and is_instance_valid(n.spr):
		vis = n.spr.duplicate()
	var r: Node2D = FX.Reflect.new()
	r.setup(game, self, p, dir * sp, vis, n.hit_rect().size)
	game.world.add_child(r)
	n.done = true
	n.queue_free()
	hit_times.append(clock)                              # a reflected shot is pressure too
	game.parry_fx(p, 1.2)
	Sfx.play("parry", 1.1)
	if state in ["idle", "move", "heal"]:
		_set_state("parry")
		parry_t = 0.0
		riposte_pending = false
		vx = 0.0
		_face(1 if m.global_position.x > global_position.x else -1)
		_show("parry", 0)


func _pressure(delta: float, m: Node2D) -> void:
	var gap := gap_to(m)
	if gap <= Tuning.PERRY_BOSS_AGG_NEAR:
		near_t += delta
	else:
		near_t = maxf(0.0, near_t - delta * 2.0)
	if burst_cd <= 0.0 and not burst_pending and hp > 0:
		if (hit_times.size() >= Tuning.PERRY_BOSS_AGG_HITS and gap <= Tuning.PERRY_BOSS_AGG_NEAR) or near_t > Tuning.PERRY_BOSS_AGG_MELEE_S:
			burst_pending = true


# ---------------------------------------------------------------- the brain (idle / walking)
func _brain(delta: float, m: Node2D) -> void:
	var gap := gap_to(m)
	var face := 1 if m.global_position.x > global_position.x else -1
	_face(face)
	if burst_pending and burst_cd <= 0.0:
		burst_pending = false
		burst_cd = Tuning.PERRY_BOSS_BURST_CD_S
		near_t = 0.0
		hit_times.clear()
		bursts += 1
		start_move("energy_burst")
		return
	if not queue.is_empty():
		var q: Dictionary = queue.pop_front()
		start_move(String(q["id"]), q)
		return
	var ph := phase_now()
	if ph >= 2 and float(hp) <= Tuning.PERRY_BOSS_GUARD_HP * float(hp_max) and guard_cd <= 0.0 and gap < 900.0:
		guard_cd = Tuning.PERRY_BOSS_GUARD_CD_S
		start_move("rainbow_guard")
		return
	if ph >= 3 and float(hp) <= Tuning.PERRY_BOSS_ULT_HP * float(hp_max) and ult_cd <= 0.0:
		ult_cd = Tuning.PERRY_BOSS_ULT_CD_S
		ults += 1
		start_move("ultimate_chain")
		return
	if hp < hp_max and dmg_t >= Tuning.PERRY_BOSS_HEAL_IDLE_S and gap >= Tuning.PERRY_BOSS_HEAL_MIN_GAP and not _player_attacking(m):
		vx = 0.0
		heal_acc = 0.0
		heal_spark = 0.0
		_set_state("heal")
		_play("recover")
		return
	if cooldown <= 0.0 or chain_next:
		var id := _pick(gap, m)
		if id != "":
			chain_next = false
			start_move(id)
			return
		chain_next = false
	_reposition(delta, m, gap)


func _reposition(delta: float, m: Node2D, gap: float) -> void:
	wander_t -= delta
	var v := 0.0
	if gap > 320.0:
		v = float(facing) * speed
	elif gap < 70.0:
		v = -float(facing) * speed * 0.6
	else:
		if wander_t <= 0.0:
			wander_t = rng.randf_range(0.35, 0.9)
			wander_dir = rng.randi_range(-1, 1)
		v = float(wander_dir) * speed * 0.45
	if gap < 20.0 and v * float(facing) > 0.0:
		v = 0.0
	vx = v
	if absf(v) > 1.0:
		if state != "move" or sprite.animation != move_a:
			_set_state("move")
			_play(move_a)
	elif state != "idle" or sprite.animation != idle_a:
		_set_state("idle")
		_play(idle_a)


## weighted pick by distance band, phase, cooldowns and history (never the same move more than REPEAT_MAX times in a row)
func _pick(gap: float, m: Node2D) -> String:
	var ph := phase_now()
	var airborne: bool = not bool(m.get("on_ground")) if m.get("on_ground") != null else false
	var ids: Array = []
	var ws: Array = []
	var total := 0.0
	for id in MOVES:
		var mv: Dictionary = MOVES[id]
		if bool(mv.get("only", false)) or int(mv["ph"]) > ph or float(mcd.get(id, 0.0)) > 0.0:
			continue
		var band: Array = mv["band"]
		if gap < float(band[0]) or gap > float(band[1]):
			continue
		var w := float(mv["w"])
		if w <= 0.0:
			continue
		var n := recent.size()
		if n >= Tuning.PERRY_BOSS_REPEAT_MAX and recent[n - 1] == id and recent[n - 2] == id:
			continue
		if recent.slice(maxi(0, n - 3)).has(id):
			w *= 0.35
		if gap > Tuning.PERRY_BOSS_FAR_GAP and float(mv.get("closer", 0.0)) > 0.0:
			w *= float(mv["closer"])
		if gap <= 90.0 and float(mv.get("close", 0.0)) > 0.0:
			w *= float(mv["close"])
		if mv.has("air"):
			w = float(mv["air"]) if airborne else w * 0.3
		ids.append(id)
		ws.append(w)
		total += w
	if ids.is_empty():
		return ""
	var r := rng.randf() * total
	for i in ids.size():
		r -= float(ws[i])
		if r <= 0.0:
			return String(ids[i])
	return String(ids[ids.size() - 1])


# ---------------------------------------------------------------- moves
## start a move now (the brain, queue and tests). opts: dir -1 = back away, riposte = no tell of its own
func start_move(id: String, opts: Dictionary = {}) -> void:
	if not MOVES.has(id) or hp <= 0:
		return
	_abort_move()
	cur_id = id
	cur = MOVES[id]
	steps = cur.get("steps", [id])
	step_i = 0
	st_retreat = int(opts.get("dir", 1)) < 0
	move_log.append(id)
	recent.append(id)
	if recent.size() > 8:
		recent.pop_front()
	var m: Node2D = game.mera
	if not st_retreat:
		_face(1 if m.global_position.x > global_position.x else -1)
	var t := float(cur["tell"])
	var rip: bool = bool(opts.get("riposte", false))
	if rip:
		t = Tuning.PERRY_BOSS_RIPOSTE_TELL_S
		riposte_log.append(id)
	if t > 0.0:
		var first: Dictionary = MOVES[String(steps[0])]
		atk = {"anim": String(first.get("anim", steps[0])), "kind": String(cur["kind"]), "tell": t, "dmg": int(cur["dmg"]), "mode": "perry", "cd": 0.5}
		tell_len = t if rip else maxf(t, TELE.MIN_TELL)
		tell_t = 0.0
		vx = 0.0
		_set_state("tell")
		_show(String(first.get("anim", steps[0])), 0)
		marker.set_kind(String(cur["kind"]))
		marker.visible = not rip
		if not rip:
			tell_log.append(tell_len)
			if String(cur["kind"]) in ["heavy", "ranged"]:
				Sfx.play("charge", 0.8, -6.0)
	else:
		_start_step()


func _start_step() -> void:
	if step_i >= steps.size():
		_end_move()
		return
	var m: Node2D = game.mera
	marker.visible = false
	st_id = String(steps[step_i])
	st = MOVES[st_id]
	var data_id := String(st.get("data", st_id))
	st_frames = PP.mdef(data_id)["frames"]
	st_i = 0
	st_t = 0.0
	st_x0 = global_position.x
	st_dir = -facing if st_retreat else facing
	st_win = -1
	st_hits = {}
	st_flags = {}
	step_log.append(st_id)
	_set_state("atk")
	var anim := String(st.get("anim", st_id))
	atk = {"anim": anim, "kind": String(st.get("kind", "melee")), "tell": 0.0, "dmg": int(st.get("dmg", 0)), "mode": "perry", "cd": 0.5}
	_show(anim, 0)
	var h := String(st.get("h", "melee"))
	match h:
		"sky":
			if st_retreat:
				st_xe = st_x0 + float(st_dir) * 700.0
			else:
				st_xe = m.global_position.x + float(facing) * Tuning.PERRY_BOSS_SKY_OVER
			st_xe = clampf(st_xe, Levels.EDGE, float(game.map_w) - Levels.EDGE)
		"leap":
			st_xe = m.global_position.x - float(facing) * (m.hurt_rect().size.x / 2.0 + Tuning.PERRY_BOSS_HURT_HW * k + 140.0)
			st_xe = clampf(st_xe, Levels.EDGE, float(game.map_w) - Levels.EDGE)
		"guard":
			guard_t = Tuning.PERRY_BOSS_GUARD_S
			guards += 1
		"burst":
			_spawn_fx_sprite("energy_burst_fx")
		"meteor":
			_spawn_fx_sprite("meteor_fx")
	Sfx.play("swipe", 0.7, -4.0)


func _spawn_fx_sprite(anim: String) -> void:
	if fx_node != null and is_instance_valid(fx_node):
		fx_node.queue_free()
	var e: Dictionary = art["anims"][anim]
	fx_node = AnimatedSprite2D.new()
	fx_node.sprite_frames = sprite.sprite_frames
	fx_node.centered = false
	fx_node.animation = anim
	fx_node.offset = Vector2(-(float(e["pivot"][0]) + hc), -float(e["pivot"][1]))
	fx_node.scale = Vector2(k * facing, k)
	fx_node.show_behind_parent = true
	add_child(fx_node)
	fx_node.pause()
	fx_node.frame = 0
	played[anim] = true


func _total_ms() -> float:
	var t := 0.0
	for f in st_frames:
		t += float(f["ms"])
	return t


func _step_tick(delta: float, m: Node2D) -> void:
	var h := String(st.get("h", "melee"))
	var tm := float(st.get("tm", 1.0))
	if h == "guard":
		guard_t -= delta
		_show("block", int(clock * 8.0) % 3)
		if guard_t <= 0.0:
			guard_t = 0.0
			_step_end()
		return
	st_t += delta * 1000.0 / tm
	var n := st_frames.size()
	while st_i < n and st_t >= float(st_frames[st_i]["ms"]):
		st_t -= float(st_frames[st_i]["ms"])
		if st_i == n - 1 and h == "meteor" and meteor_left > 0:
			st_t = float(st_frames[st_i]["ms"]) - 0.001         # hold the last frame until the meteors are down
			break
		st_i += 1
		if st_i < n:
			_enter_frame(h, m)
	if h == "meteor":
		_meteor_tick(delta, m)
	if st_i >= n or (h == "sky" and st_i >= 4):
		inv_now = false
		if h == "sky":
			position.x = st_xe
			lift = 0.0
		_step_end()
		return
	var anim := String(st.get("anim", st_id))
	_show(anim, st_i)
	if fx_node != null and is_instance_valid(fx_node):
		fx_node.frame = clampi(st_i, 0, fx_node.sprite_frames.get_frame_count(fx_node.animation) - 1)
	_root(h, m)
	_hits(h, m)


func _enter_frame(h: String, m: Node2D) -> void:
	var f: Dictionary = st_frames[st_i]
	var fname := String(f["name"])
	match h:
		"wave":
			if fname == "release":
				_fire_wave(m)
		"meteor":
			if fname == "call":
				meteor_left = Tuning.PERRY_BOSS_METEORS
				meteor_t = 0.0
				meteor_i = 0
				game.shake(6.0, 0.3)
		"quake":
			if fname == "slam":
				_quake()
		"beam":
			if not (f["beam"] as Dictionary).is_empty() and not st_flags.has("beam"):
				st_flags["beam"] = true
				_fire_beam()
		"leap":
			if fname == "crash":
				game.shake(14.0, 0.3)
				Sfx.play("boom_big", 0.7, -4.0)
				if game.debris:
					game.debris.spark(Vector2(global_position.x + facing * 300.0, global_position.y - 20.0), 3.0)
		_:
			if fname == "impact" and st_id == "heavy":
				game.shake(12.0, 0.25)
				Sfx.play("boom_big", 0.8, -6.0)


func _fire_wave(_m: Node2D) -> void:
	var s: Node2D = load("res://scripts/game/enemy_shot.gd").new()
	var p := Vector2(global_position.x + facing * 260.0, global_position.y - 90.0)
	s.setup(game, id, "wave_fx", p, Vector2(float(facing) * Tuning.PERRY_BOSS_WAVE_SPEED, 0.0), int(st["dmg"]), k * 0.6, true)
	s.shooter = self
	played["wave_fx"] = true
	get_parent().add_child(s)
	Sfx.play("cast", 0.7, -2.0)


func _fire_beam() -> void:
	var kind := String(st["beam"])
	var total := 0.0
	for f in st_frames:
		if not (f["beam"] as Dictionary).is_empty():
			total += float(f["ms"])
	var b: Node2D = FX.Beam.new()
	b.setup(game, self, kind, global_position.x + float(facing) * 230.0, facing, total / 1000.0 + 0.1)
	game.world.add_child(b)
	fx_live.append(b)
	Sfx.play("cast", 0.5, 2.0)


func _quake() -> void:
	game.shake(16.0, 0.4)
	Sfx.play("boom_big", 0.6, -2.0)
	for d in [-1, 1]:
		var q: Node2D = FX.Quake.new()
		q.setup(game, self, global_position.x + float(d) * 200.0, d)
		game.world.add_child(q)


func _meteor_tick(delta: float, m: Node2D) -> void:
	if meteor_left <= 0:
		return
	meteor_t -= delta
	if meteor_t > 0.0:
		return
	meteor_t = Tuning.PERRY_BOSS_METEOR_GAP_S
	var mx: float = m.global_position.x
	var x := mx + rng.randf_range(-120.0, 120.0) if meteor_i % 2 == 0 else mx + rng.randf_range(-850.0, 850.0)
	x = clampf(x, Levels.EDGE + 60.0, float(game.map_w) - Levels.EDGE - 60.0)
	var mt: Node2D = FX.Meteor.new()
	mt.setup(game, self, x, Tuning.PERRY_BOSS_METEOR_WARN_S)
	game.world.add_child(mt)
	meteor_i += 1
	meteor_left -= 1
	Sfx.play("charge", 1.3, -8.0)


## root motion of the Perry Riposte move, scaled by k; the sky dash and the plunge follow arcs of their own
func _root(h: String, m: Node2D) -> void:
	var n := st_frames.size()
	var i := mini(st_i, n - 1)
	var u := clampf(st_t / maxf(float(st_frames[i]["ms"]), 1.0), 0.0, 1.0)
	match h:
		"sky":
			if st_i >= 1 and st_i <= 3:
				var tot := 0.0
				var el := 0.0
				for j in range(1, 4):
					tot += float(st_frames[j]["ms"])
					if j < st_i:
						el += float(st_frames[j]["ms"])
				el += st_t
				var q := clampf(el / tot, 0.0, 1.0)
				var e := q * q * (3.0 - 2.0 * q)
				position.x = lerpf(st_x0, st_xe, e)
				lift = sin(q * PI) * Tuning.PERRY_BOSS_SKY_LIFT
				if q >= 1.0:
					lift = 0.0
			elif st_i == 0:
				lift = 0.0
			return
		"leap":
			if st_i >= 1 and st_i <= 4:
				var tot2 := 0.0
				var el2 := 0.0
				for j in range(1, 5):
					tot2 += float(st_frames[j]["ms"])
					if j < st_i:
						el2 += float(st_frames[j]["ms"])
				el2 += st_t
				var q2 := clampf(el2 / tot2, 0.0, 1.0)
				position.x = lerpf(st_x0, st_xe, q2 * q2 * (3.0 - 2.0 * q2))
			var r0 := float(st_frames[i]["ry"])
			var r1 := float(st_frames[mini(i + 1, n - 1)]["ry"])
			lift = lerpf(r0, r1, u) * k * Tuning.PERRY_BOSS_LEAP_LIFT
			if st_i >= 5:
				lift = 0.0
			return
	var rx0 := float(st_frames[i]["rx"])
	var rx1 := float(st_frames[mini(i + 1, n - 1)]["rx"])
	var nx := st_x0 + float(st_dir) * lerpf(rx0, rx1, u) * k
	if not bool(st.get("pass", false)) and st_dir == facing:       # she stops at Mera
		var mr: Rect2 = m.hurt_rect()
		var gap_after := absf(mr.get_center().x - nx) - mr.size.x / 2.0 - Tuning.PERRY_BOSS_HURT_HW * k
		if gap_after < 20.0 and absf(mr.get_center().x - nx) < absf(mr.get_center().x - position.x):
			nx = position.x
	position.x = nx
	if h == "dash":
		var tot3 := _total_ms()
		var el3 := st_t
		for j in st_i:
			el3 += float(st_frames[j]["ms"])
		inv_now = el3 / maxf(tot3, 1.0) < Tuning.PERRY_BOSS_DASH_IFRAME


func _hits(h: String, m: Node2D) -> void:
	if m.state == "dead":
		return
	var dmg := int(st.get("dmg", 0))
	if h == "sky":
		if not st_retreat and dmg > 0 and st_i >= 1 and st_i <= 3 and not st_hits.has("c") and hurt_rect().intersects(m.hurt_rect()):
			st_hits["c"] = true
			hit_mera(dmg, global_position.x)
		return
	if dmg <= 0:
		return
	if h == "burst":
		if st_i >= 3 and st_i <= 5 and not st_hits.has("b"):
			var box: Rect2 = _hit_rects()[0]
			if box.intersects(m.hurt_rect()):
				st_hits["b"] = true
				last_burst_knock = 0.0
				var x0: float = m.global_position.x
				hit_mera(dmg, global_position.x, Tuning.PERRY_BOSS_BURST_KNOCK, Tuning.PERRY_BOSS_KNOCK_S)
				last_burst_knock = x0
				game.shake(18.0, 0.4)
		if st_i == 3 and not st_flags.has("bfx"):
			st_flags["bfx"] = true
			game.shake(10.0, 0.3)
			Sfx.play("boom_big", 0.7, -2.0)
		return
	var rs := _hit_rects()
	if rs.is_empty():
		st_win = -1
		return
	if st_win < 0:
		st_win = st_i
	if st_hits.has(st_win):
		return
	for r in rs:
		if r.intersects(m.hurt_rect()):
			st_hits[st_win] = true
			hit_mera(dmg, global_position.x, float(st.get("shove", 0.0)), 0.25)
			return


func _step_end() -> void:
	step_i += 1
	if step_i < steps.size():
		var stell := float(cur.get("stell", 0.0))
		if stell > 0.0:
			var nxt: Dictionary = MOVES[String(steps[step_i])]
			_set_state("tell")
			tell_len = maxf(stell, TELE.MIN_TELL)
			tell_t = 0.0
			tell_log.append(tell_len)
			atk = {"anim": String(nxt.get("anim", steps[step_i])), "kind": String(cur["kind"]), "tell": stell, "dmg": int(cur["dmg"]), "mode": "perry", "cd": 0.5}
			_show(String(nxt.get("anim", steps[step_i])), 0)
			marker.set_kind(String(cur["kind"]))
			marker.visible = true
			return
		_start_step()
		return
	_end_move()


func _end_move() -> void:
	var was := cur_id
	var c := cur
	var retreat := st_retreat
	_clear_fx()
	meteor_left = 0
	marker.visible = false
	lift = 0.0
	position.y = rest_y
	inv_now = false
	guard_t = 0.0
	mcd[was] = float(c.get("mcd", 0.0))
	var ph := phase_now()
	if was == "energy_burst" or was == "burst_chain":
		queue.append({"id": "sky_dash" if rng.randf() < 0.4 else "dash", "dir": -1})
	elif was == "taunt":
		var m: Node2D = game.mera
		queue.append({"id": "dash_thrust" if gap_to(m) > 400.0 else "thrust"})
	var cdv := rng.randf_range(float(Tuning.PERRY_BOSS_CD[0]), float(Tuning.PERRY_BOSS_CD[1])) * float(Tuning.PERRY_BOSS_CD_MUL[ph - 1])
	_to_idle_p(cdv)
	cooldown = cdv
	chain_next = false
	if queue.is_empty() and not retreat and was != "taunt" and was != "rainbow_guard" and chain_n < Tuning.PERRY_BOSS_CHAIN_MAX - 1:
		var p := float(Tuning.PERRY_BOSS_CHAIN_P[ph - 1])
		if float(c.get("closer", 0.0)) > 0.0 and int(c["dmg"]) == 0:
			p = 0.9
		if rng.randf() < p:
			chain_n += 1
			chain_next = true
			cooldown = 0.0
	if not chain_next:
		chain_n = 0
	cur_id = ""
	cur = {}
	st = {}


func _parry_tick(delta: float, m: Node2D) -> void:
	parry_t += delta
	_show("parry", mini(int(parry_t / Tuning.PERRY_BOSS_PARRY_S * 5.0), 4))
	if parry_t < Tuning.PERRY_BOSS_PARRY_S:
		return
	parry_cd = maxf(parry_cd, Tuning.PERRY_BOSS_PARRY_REARM_S)
	var rip := riposte_pending
	riposte_pending = false
	_to_idle_p(0.0)
	if rip and m.state != "dead":
		var gap := gap_to(m)
		if gap <= 520.0:
			start_move("slash" if gap < 380.0 else "thrust", {"riposte": true})


func _heal_tick(delta: float, m: Node2D) -> void:
	var gap := gap_to(m)
	if dmg_t < Tuning.PERRY_BOSS_HEAL_IDLE_S or _player_attacking(m) or gap < Tuning.PERRY_BOSS_HEAL_BREAK_GAP:
		_to_idle_p(0.1)
		return
	heal_acc += float(hp_max) / Tuning.PERRY_BOSS_HEAL_FULL_S * delta
	var n := int(heal_acc)
	if n > 0:
		heal_acc -= float(n)
		var before := hp
		hp = mini(hp + n, hp_max)
		healed += hp - before
		size = size_of_hp()
	heal_spark -= delta
	if heal_spark <= 0.0:
		heal_spark = 0.22
		if game.debris:
			game.debris.spark(Vector2(global_position.x + rng.randf_range(-120.0, 120.0), global_position.y - rng.randf_range(20.0, 300.0)), 1.6)
	if hp >= hp_max:
		_to_idle_p(0.2)
