extends "res://scripts/game/monster.gd"
## v0.8 Infernal Dragon boss (docs/GAME_RULES.md "Infernal Dragon"). Same roster enemy (tail sweep, breath), plus:
## - SIZE IS HEALTH, like Mera: it starts at 19x (drawn at k = size) and loses one size per DRAGON_HP_PER_SIZE
##   damage, down to 1x. A hit can't take it below 1x; any hit at 1x kills it. The size change is tweened.
## - PHASES at 12x, 9x, 6x, 3x, each exactly once, when its size first drops to or past the threshold. A big hit
##   that skips several thresholds QUEUES every crossed one, and they run back to back (each once).
##   A phase: take off (the pack has no wing frames, so flight is faked: a lift tween + bob on the idle frames,
##   played fast like flapping), spit DRAGON_BOLTS explosive fire bolts that lob onto Mera from above (each with a
##   red "ranged" tell), then LAND, always. If any bolt hurts Mera, it grows +DRAGON_GROW sizes, once per phase;
##   growing never re-arms a used threshold.
## Its damage never scales with its size.

const BOLT := preload("res://scripts/game/dragon_bolt.gd")

var size := 19
var hps := 8
var phases_done := {}            # threshold -> true (never re-armed)
var phase_queue: Array = []
var phase_log: Array = []        # tests: thresholds in the order they ran
var phase := ""                  # "" | takeoff | volley | land
var phase_thr := 0
var phase_t := 0.0
var phase_hit := false           # a bolt hurt Mera in this phase (the +3 is spent)
var bolt_i := 0
var bolt_t := 0.0
var bolt_fired := false
var bolts_fired := 0
var lift := 0.0
var landings := 0
var growths := 0


func setup(g: Node, enemy_id: String, x: float, opts: Dictionary = {}) -> void:
	super(g, enemy_id, x, opts)
	hps = Tuning.DRAGON_HP_PER_SIZE
	size = int(opts.get("size", Tuning.DRAGON_START_SIZE))
	hp_max = Tuning.DRAGON_START_SIZE * hps
	hp = size * hps
	k = float(size)


func size_of_hp() -> int:
	return clampi(ceili(float(hp) / float(hps)), 1, Tuning.DRAGON_START_SIZE)


func take_damage(amount: int, from_x: float, kind: String = "melee") -> bool:
	if hp <= 0 or amount <= 0:
		return false
	flash = 0.12
	last_from_x = from_x
	last_kind = kind
	if size <= 1:                                   # hit at 1x: dead (like Mera)
		hp = 0
		phase = ""
		lift = 0.0
		bar.queue_redraw()
		_die()
		return true
	hp = maxi(hp - amount, 1)                       # never below 1x from above it
	_resize()
	bar.queue_redraw()
	return true


func _resize() -> void:
	var nsz := size_of_hp()
	if nsz < size:
		for thr in Tuning.DRAGON_PHASES:
			if nsz <= int(thr) and not phases_done.has(int(thr)):
				phases_done[int(thr)] = true
				phase_queue.append(int(thr))
	size = nsz


## a phase bolt hurt Mera: +3 sizes, once per phase
func bolt_hit() -> void:
	if phase_hit or hp <= 0:
		return
	phase_hit = true
	growths += 1
	hp = mini(hp + Tuning.DRAGON_GROW * hps, hp_max)
	size = size_of_hp()
	Sfx.play("roar" if Sfx.SOUNDS.has("roar") else "charge", 0.6, 2.0)
	if game:
		game.hud.flash("pickup:the dragon feeds on your pain: +%dx" % Tuning.DRAGON_GROW)


# ---------------------------------------------------------------- tick
func _physics_process(delta: float) -> void:
	_size_tick(delta)
	if state == "dead" or hp <= 0 or game == null:
		super(delta)
		return
	if phase == "" and not phase_queue.is_empty() and state != "spawn":
		_begin_phase(int(phase_queue.pop_front()))
	if phase != "":
		t_state += delta
		flash -= delta
		_tint()
		_phase_tick(delta)
		return
	super(delta)


func _size_tick(delta: float) -> void:
	var want := float(size)
	if absf(want - k) > 0.001:
		k = move_toward(k, want, maxf(absf(want - k), 1.0) * Tuning.DRAGON_SIZE_RATE * delta)
		_face(facing)
		_place_overhead()


func _begin_phase(thr: int) -> void:
	phase_thr = thr
	phase = "takeoff"
	phase_t = 0.0
	phase_hit = false
	bolt_i = 0
	bolt_t = 0.0
	bolt_fired = false
	atk = {}
	vx = 0.0
	stun_t = 0.0
	marker.visible = false
	sprite.play()
	_set_state("fly")
	_play(idle_a)
	sprite.speed_scale = 2.2                        # fast "flapping" on the idle frames (no wing frames in the pack)
	history.append("phase:%d" % thr)
	Sfx.play("dash", 0.5, 2.0)
	if game:
		game.shake(8.0, 0.4)


func _phase_tick(delta: float) -> void:
	phase_t += delta
	var m: Node2D = game.mera
	if m and m.state != "dead":
		_face(1 if m.global_position.x > global_position.x else -1)
	match phase:
		"takeoff":
			var q := clampf(phase_t / Tuning.DRAGON_TAKEOFF_S, 0.0, 1.0)
			lift = Tuning.DRAGON_FLY_H * (1.0 - pow(1.0 - q, 2.0))
			if q >= 1.0:
				phase = "volley"
				phase_t = 0.0
		"volley":
			lift = Tuning.DRAGON_FLY_H + sin(phase_t * 3.0) * 22.0
			bolt_t += delta
			if bolt_i < Tuning.DRAGON_BOLTS:
				if not bolt_fired:
					sprite.modulate = TELE.pulse("ranged", bolt_t)          # red tell before every bolt
					marker.set_kind("ranged")
					marker.visible = true
					if sprite.animation != "spit":
						_play("spit")                      # v0.8.1: breath frames with the fire plume masked out (no plume in the volley)
						sprite.pause()
						sprite.frame = 0
					if bolt_t >= Tuning.DRAGON_BOLT_TELL_S:
						_spit(m)
						bolt_fired = true
						marker.visible = false
						sprite.play()
				elif bolt_t >= Tuning.DRAGON_BOLT_TELL_S + Tuning.DRAGON_BOLT_GAP_S:
					bolt_i += 1
					bolt_t = 0.0
					bolt_fired = false
			elif bolt_t >= 0.6:
				phase = "land"
				phase_t = 0.0
				_play(idle_a)
				sprite.speed_scale = 1.4
		"land":
			var q := clampf(phase_t / Tuning.DRAGON_LAND_S, 0.0, 1.0)
			lift = Tuning.DRAGON_FLY_H * (1.0 - q * q)
			if q >= 1.0:
				lift = 0.0
				phase = ""
				landings += 1
				phase_log.append(phase_thr)
				position.y = rest_y
				on_ground = true
				if game:
					game.shake(14.0, 0.3)
				Sfx.play("boom_big", 0.6, -4.0)
				_to_idle(1.2)
	position.y = rest_y - lift


func _spit(m: Node2D) -> void:
	var hr := hurt_rect()
	var mouth := Vector2(global_position.x + facing * hr.size.x * 0.46, hr.position.y + hr.size.y * 0.3)
	var tx: float = m.global_position.x if m else global_position.x + facing * 600.0
	if bolt_i > 0:
		tx += rng.randf_range(-Tuning.DRAGON_BOLT_SPREAD, Tuning.DRAGON_BOLT_SPREAD)
	tx = clampf(tx, Levels.EDGE, game.map_w - Levels.EDGE)
	var b: Node2D = BOLT.new()
	b.setup(game, self, mouth, Vector2(tx, float(game.GROUND_Y)))
	get_parent().add_child(b)
	bolts_fired += 1
	played["spit"] = true
	if game and game.debris:
		game.debris.spark(mouth, 3.0)                # a small muzzle flash at most; the bolt itself is the fire
	Sfx.play("cast", 0.55, -2.0)


func stun(t: float) -> void:
	if phase != "":
		return                                       # in the air: the earthquake can't reach it
	super(t)


func _draw_bar() -> void:
	pass                                             # the HUD draws the boss bar (size + health)
