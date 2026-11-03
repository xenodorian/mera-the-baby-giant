extends "res://scripts/game/monster.gd"
## Stage 3 Changeling enemies (Roster ids cl_*). The shared monster.gd AI plus what the originals do:
##  - mud and bone shots are drawn by cl_shot.gd (the mud is lobbed to land near Mera);
##  - "style" enemies keep a gap band [lo, hi] between their attacks: ranger hops back, weaver walks back,
##    mage blinks away (fades, reappears 'lo' + a bit from Mera); above hi they walk closer.
## Everything else (grunt lunge, rat king hop, archer volleys, knight bash) is plain attack data in Roster.DEFS.

const SHOT := preload("res://scripts/game/cl_shot.gd")

var hold_cd := 0.0                   # hop-back / blink cooldown
var blink_t := 0.0
var blink_to := 0.0
var blink_moved := false
var blinking := false
var blinks := 0                      # tests
var hops_back := 0                   # tests


func _physics_process(delta: float) -> void:
	hold_cd -= delta
	if blinking and state != "blink":      # a launch or stun cut the blink short: show him again
		blinking = false
		modulate.a = 1.0
	super(delta)


func _ai(m: Node2D, delta: float) -> void:
	var style := String(d.get("style", ""))
	if style == "":
		super(m, delta)
		return
	if state == "blink":
		_blink_tick()
		return
	if cooldown > 0.0 and doused_t <= 0.0:
		var gap := gap_to(m)
		var face := 1 if m.global_position.x > global_position.x else -1
		var lo := float(d.get("lo", 400.0))
		var hi := float(d.get("hi", 800.0))
		if gap < lo and _room_behind(face) and on_ground:
			match style:
				"ranger":
					if hold_cd <= 0.0:
						_hop_back(face)
						return
				"mage":
					if hold_cd <= 0.0:
						_start_blink(m, face)
						return
				"weaver":
					_face(face)
					vx = -face * speed
					if state != "move" or sprite.animation != _cur_move():
						_set_state("move")
						_play(_cur_move())
					return
		elif gap > hi:
			_face(face)
			vx = face * speed
			if state != "move" or sprite.animation != _cur_move():
				_set_state("move")
				_play(_cur_move())
			return
		_face(face)
		vx = 0.0
		if state != "idle" or sprite.animation != _cur_idle():
			_set_state("idle")
			_play(_cur_idle())
		return
	super(m, delta)


func _room_behind(face: int) -> bool:
	var x := global_position.x - face * 220.0
	return x > Levels.EDGE + 30.0 and x < float(game.map_w) - Levels.EDGE - 30.0


func _hop_back(face: int) -> void:
	_face(face)
	_set_state("hop")
	_play("jump")
	vy = -1100.0
	vx = -face * 640.0
	on_ground = false
	hold_cd = 1.8
	hops_back += 1


func _start_blink(m: Node2D, face: int) -> void:
	_set_state("blink")
	blinking = true
	blinks += 1
	blink_t = 0.0
	blink_moved = false
	hold_cd = 2.6
	vx = 0.0
	_play("jump")
	sprite.pause()
	sprite.frame = 1
	var lo := float(d.get("lo", 400.0))
	var side := -face
	var dist := lo + 140.0 + rng.randf() * 140.0
	var tx: float = m.global_position.x + side * dist
	if tx < Levels.EDGE + 40.0 or tx > float(game.map_w) - Levels.EDGE - 40.0:
		tx = m.global_position.x - side * dist
	blink_to = clampf(tx, Levels.EDGE + 40.0, float(game.map_w) - Levels.EDGE - 40.0)


func _blink_tick() -> void:
	blink_t += get_physics_process_delta_time()
	if blink_t < 0.18:
		modulate.a = 1.0 - blink_t / 0.18
	elif not blink_moved:
		blink_moved = true
		position.x = blink_to
		_face(1 if game.mera.global_position.x > position.x else -1)
		modulate.a = 0.0
	elif blink_t < 0.4:
		modulate.a = (blink_t - 0.18) / 0.22
	else:
		modulate.a = 1.0
		blinking = false
		_to_idle(0.0)


func _fire(m: Node2D) -> void:
	var what := String(atk.get("shot", ""))
	if what != "mud" and what != "bone":
		super(m)
		return
	var aim := _prey()
	var hr := hurt_rect()
	var p := Vector2(global_position.x + facing * hr.size.x * 0.4, hr.get_center().y - hr.size.y * 0.15)
	var s: Node2D = SHOT.new()
	var sk := k * float(atk.get("shot_k", 1.0))
	if what == "mud":
		s.setup_drawn(game, "mud", p, Vector2.ZERO, int(atk["dmg"]), sk, aim.global_position.x)
	else:
		var dir: Vector2 = (aim.hurt_rect().get_center() - p).normalized()
		if absf(dir.y) > 0.6:
			dir = Vector2(facing, signf(dir.y) * 0.6).normalized()
		s.setup_drawn(game, "bone", p, dir * float(atk.get("shot_speed", 1000.0)), int(atk["dmg"]), sk)
	s.shooter = self
	get_parent().add_child(s)
	Sfx.play("cast", 0.7, -4.0)
