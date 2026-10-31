extends "res://scripts/game/monster.gd"
## v0.8 Infernal Dragon boss (docs/GAME_RULES.md "Infernal Dragon"). Same roster enemy (tail sweep, breath), plus:
## - SIZE IS HEALTH, like Mera: it starts at 19x (drawn at k = size) and loses one size per DRAGON_HP_PER_SIZE
##   damage, down to 1x. A hit can't take it below 1x; any hit at 1x kills it. The size change is tweened.
## - PHASES at 12x, 9x, 6x, 3x, each exactly once, when its size first drops to or past the threshold. A big hit
##   that skips several thresholds QUEUES every crossed one, and they run back to back (each once).
##   A phase: take off on the "fly" wing loop (v0.8.1: the user-picked breath frames 1,5,4,5 without fire), then
##   DRAGON_BOLTS times: fly to a lob spot (short/mid/long, in front of or behind Mera, varied heights, on screen,
##   inside the walls), red "ranged" tell, spit one explosive bolt on a ballistic arc solved for that distance.
##   Then LAND, always, where he is. If any bolt hurts Mera, it grows +DRAGON_GROW sizes, once per phase;
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
var fly_sub := ""                # volley step: move | tell | after
var fly_from := Vector2.ZERO     # (x, lift) at the start of a move
var fly_to := Vector2.ZERO       # (x, lift) of the current lob spot
var fly_plan: Array = []
var phase_spots: Array = []      # x of the lob spots already used in this phase
var fly_base := 0.0              # lift without the bob
var spit_spots: Array = []       # tests: [dragon x, lift, x - Mera x, phase] at every lob
var bolt_times: Array = []       # tests: flight time of every lob
var last_bolt: Node2D            # tests
var last_mouth := Vector2.ZERO   # tests: mouth and head top at the last spit
var last_head_y := 0.0
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
	if _distracted(delta):
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
	_play("fly")                                    # v0.8.1 wing loop (no fire), DRAGON_FLY_FPS
	sprite.speed_scale = 1.0
	fly_plan = Tuning.DRAGON_FLY_SPOTS.duplicate()
	fly_plan.shuffle()
	phase_spots = []
	fly_sub = ""
	history.append("phase:%d" % thr)
	Sfx.play("dash", 0.5, 2.0)
	if game:
		game.shake(8.0, 0.4)


func _phase_tick(delta: float) -> void:
	phase_t += delta
	var m: Node2D = game.mera
	if m and m.state != "dead":
		_face(1 if m.global_position.x > global_position.x else -1)
	var bob := sin(phase_t * TAU * Tuning.DRAGON_FLY_BOB_HZ) * Tuning.DRAGON_FLY_BOB
	match phase:
		"takeoff":
			var q := clampf(phase_t / Tuning.DRAGON_TAKEOFF_S, 0.0, 1.0)
			fly_base = Tuning.DRAGON_FLY_H * (1.0 - pow(1.0 - q, 2.0))
			lift = fly_base + bob * q
			if q >= 1.0:
				phase = "volley"
				_next_spot()
		"volley":
			bolt_t += delta
			match fly_sub:
				"move":                                  # glide to the lob spot, wings beating
					var q := clampf(bolt_t / Tuning.DRAGON_FLY_MOVE_S, 0.0, 1.0)
					var e := q * q * (3.0 - 2.0 * q)
					position.x = lerpf(fly_from.x, fly_to.x, e)
					fly_base = lerpf(fly_from.y, fly_to.y, e)
					if q >= 1.0:
						fly_sub = "tell"
						bolt_t = 0.0
						_play("spit")
						sprite.pause()
						sprite.frame = 0
				"tell":                                  # red tell, then one lob
					sprite.modulate = TELE.pulse("ranged", bolt_t)
					marker.set_kind("ranged")
					marker.visible = true
					if bolt_t >= Tuning.DRAGON_BOLT_TELL_S:
						marker.visible = false
						_spit(m)
						sprite.play()                    # from the open-mouth frame
						fly_sub = "after"
						bolt_t = 0.0
				"after":
					if bolt_t >= Tuning.DRAGON_BOLT_GAP_S:
						bolt_i += 1
						if bolt_i < Tuning.DRAGON_BOLTS:
							_next_spot()
						else:
							fly_sub = "done"
							_play("fly")
				"done":
					if bolt_t >= Tuning.DRAGON_BOLT_GAP_S + 0.6:
						phase = "land"
						phase_t = 0.0
						fly_from = Vector2(position.x, fly_base + bob)
			lift = fly_base + bob
		"land":                                          # always lands, where he is
			var q := clampf(phase_t / Tuning.DRAGON_LAND_S, 0.0, 1.0)
			lift = fly_from.y * (1.0 - q * q)
			if q >= 1.0:
				lift = 0.0
				phase = ""
				landings += 1
				phase_log.append(phase_thr)
				position.y = rest_y
				on_ground = true
				sprite.speed_scale = 1.0
				if game:
					game.shake(14.0, 0.3)
				Sfx.play("boom_big", 0.6, -4.0)
				_to_idle(1.2)
	position.y = rest_y - lift


## pick the next lob spot (short / mid / long, in front of or behind Mera, varied height), on screen, inside the walls
func _next_spot() -> void:
	var m: Node2D = game.mera
	var mx: float = m.global_position.x if m else global_position.x
	var mf: int = int(m.facing) if m and m.get("facing") != null else 1
	var spot: Array = fly_plan[bolt_i % fly_plan.size()]
	var d: float = float(spot[1]) + rng.randf_range(-Tuning.DRAGON_FLY_SPOT_JITTER, Tuning.DRAGON_FLY_SPOT_JITTER)
	# v0.8.2: the bolt leaves the mouth horizontally, so Mera must be in front of his mouth, not under it
	d = maxf(d, absf(Tuning.DRAGON_MOUTH.x) * k + Tuning.DRAGON_BOLT_MIN_DX)
	var side: int = int(spot[0]) * (mf if mf != 0 else 1)
	# keep most of his body on screen: the bigger he is, the closer to the screen centre
	var reach := clampf(960.0 - hurt_rect().size.x * 0.2, 380.0, Tuning.DRAGON_FLY_SCREEN)   # >= ~2/3 of him on screen
	var lo: float = maxf(Levels.EDGE + 200.0, game.cam_x - reach)
	var hi: float = minf(game.map_w - Levels.EDGE - 200.0, game.cam_x + reach)
	var x := mx + side * d
	if x < lo or x > hi:                               # no room on that side: take the same distance on the other
		x = mx - side * d
	x = clampf(x, lo, hi)
	if absf(x - global_position.x) < 200.0:            # never lob twice from (almost) the same spot
		x = clampf(mx - (x - mx), lo, hi)
	var need := absf(Tuning.DRAGON_MOUTH.x) * k + Tuning.DRAGON_BOLT_MIN_DX
	if absf(x - mx) < need:                            # clamped too close to her: take the side with more room
		x = mx + need if hi - mx > mx - lo else mx - need
	var sd := signf(x - mx) if x != mx else 1.0
	var room := (hi - mx) if sd > 0.0 else (mx - lo)
	# v0.9: when he is big, the room between "mouth clear of Mera" and the screen edge is small. Fill each
	# side near edge -> far edge -> middle, and switch sides if this one is used up, so a phase never lobs twice
	# from (almost) the same place.
	var cramped := room - need < 2.0 * Tuning.DRAGON_FLY_SPOT_GAP
	if cramped or _spot_gap(x) < Tuning.DRAGON_FLY_SPOT_GAP:
		var best := x
		var best_gap := -1.0
		for sgn in [sd, -sd]:
			var rm: float = (hi - mx) if sgn > 0.0 else (mx - lo)
			if rm < need:
				continue
			var n := 0
			for u in phase_spots:
				if signf(float(u) - mx) == sgn:
					n += 1
			var cx: float = mx + sgn * lerpf(need, rm, [0.0, 1.0, 0.5, 0.25, 0.75][n % 5])
			var gp := _spot_gap(cx)
			if gp >= Tuning.DRAGON_FLY_SPOT_GAP:
				best = cx
				break
			if gp > best_gap:
				best_gap = gp
				best = cx
		x = best
	phase_spots.append(x)
	var h: float = rng.randf_range(float(Tuning.DRAGON_FLY_LIFT[0]), float(Tuning.DRAGON_FLY_LIFT[1]))
	fly_from = Vector2(global_position.x, fly_base)
	fly_to = Vector2(x, h)
	fly_sub = "move"
	bolt_t = 0.0
	if sprite.animation != "fly":
		_play("fly")


func _spot_gap(x: float) -> float:
	var gmin := INF
	for u in phase_spots:
		gmin = minf(gmin, absf(float(u) - x))
	return gmin


## the mouth in world space for the current facing and size (measured on the spit frames, see DRAGON_MOUTH)
func mouth_pos() -> Vector2:
	var mo: Vector2 = Tuning.DRAGON_MOUTH
	var x := mo.x if facing == native else -mo.x
	return global_position + Vector2(x, mo.y) * k


func _spit(m: Node2D) -> void:
	if m:
		_face(1 if m.global_position.x > global_position.x else -1)   # always spits toward Mera
	sprite.frame = 3                                 # mouth wide open (plume-free spit frame)
	var mouth := mouth_pos()
	var tx: float = m.global_position.x if m else global_position.x + facing * 600.0
	if bolt_i > 0:
		tx += rng.randf_range(-Tuning.DRAGON_BOLT_SPREAD, Tuning.DRAGON_BOLT_SPREAD)
	if (tx - mouth.x) * facing < Tuning.DRAGON_BOLT_MIN_DX:   # never spit backwards / straight down
		tx = mouth.x + facing * Tuning.DRAGON_BOLT_MIN_DX
	tx = clampf(tx, Levels.EDGE, game.map_w - Levels.EDGE)
	var b: Node2D = BOLT.new()
	b.setup(game, self, mouth, Vector2(tx, float(game.GROUND_Y)))
	last_mouth = mouth
	last_head_y = hurt_rect().position.y
	get_parent().add_child(b)
	last_bolt = b
	bolt_times.append(b.flight)
	spit_spots.append([global_position.x, lift, global_position.x - (m.global_position.x if m else global_position.x), phase_thr])
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
