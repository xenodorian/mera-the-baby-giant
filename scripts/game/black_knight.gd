extends "res://scripts/game/monster.gd"
## The Black Knight (Roster id black_knight): the end-stage mini-boss (Fellor's pack, owner supplied). Every animation of the armed set is used:
##   draw        he draws the glowing blade as he arrives (the spawn animation)
##   idle, walk  standing and running
##   attack1..4  a four-hit sword combo (the cycle takes them in order while you are close)
##   heavy1..3   three heavy swings with longer tells
##   art         the weapon art: a wide flame sweep
##   roll        a fast roll at you that closes the gap
##   jump, midair, fall_heavy, land   the leap: up, the apex, down on you, the landing recovery
##   jump, midair, fall_light, land   a short hop in
##   parry_start, parry, parry_miss   he raises a guard when you swing at him close by: a blow that lands in the guard does nothing and
##                                    he counters at once; if you do not swing into it he is open (x1.5 damage) while he recovers
##   hurt, hurt2  the two flinches, taken in turn
##   sheathe, draw, buff   at half health he sheathes the blade, draws it again and powers up: faster, shorter waits, and he cannot be hurt
##                         while he does it
##   death
## He is a boss (the exit stays locked until he falls) but not a stage finale. Damage does not scale.

const GUARD_RANGE := 420.0
const GUARD_WINDOW := 0.55            # seconds of the parry anim in which a blow is turned aside
const OPEN_MUL := 1.5                 # damage taken while he is open after a missed parry
const MY_STATES := ["parry", "miss", "recover", "buff"]

var parry_cd := 1.5
var parries := 0                      # blows turned aside (tests)
var parry_misses := 0
var buffed := false
var buff_step := 0
var hurt_flip := false
var mid_played := false
var buff_log: Array = []


func setup(g: Node, enemy_id: String, x: float, opts: Dictionary = {}) -> void:
	super(g, enemy_id, x, opts)
	d = d.duplicate()                                 # the flinch name is swapped per hit: never touch the shared definition


func _physics_process(delta: float) -> void:
	if hp > 0 and game != null and state in MY_STATES:
		t_state += delta
		flash -= delta
		_tint()
		_apply_knock(delta)
		_physics(delta)
		_my_tick(delta)
		return
	parry_cd -= delta
	if state in ["idle", "move"]:
		_watch_swing()
	if state == "atk" and atk.has("fall") and not mid_played and not on_ground and absf(vy) < 220.0 and sprite.animation == String(atk["anim"]):
		mid_played = true
		_play("midair")                               # the apex of a leap or a hop
	super(delta)


## ---- parry: raised when you swing at him close by
func _watch_swing() -> void:
	if parry_cd > 0.0 or game == null or not is_instance_valid(game.mera) or game.mera.state == "dead":
		return
	var hr: Rect2 = game.mera.hit_rect()
	if hr.size == Vector2.ZERO or gap_to(game.mera) > GUARD_RANGE:
		return
	if rng.randf() > 0.5:
		parry_cd = 1.0
		return
	_face(1 if game.mera.global_position.x > global_position.x else -1)
	vx = 0.0
	atk = {}
	_set_state("parry")
	_play("parry_start")


func take_damage(amount: int, from_x: float, kind: String = "melee") -> bool:
	if hp <= 0:
		return false
	if state == "buff":
		flash = 0.1
		return true                                   # untouchable while he powers up
	if state == "parry" and sprite.animation == "parry" and t_state < GUARD_WINDOW + 0.3:
		parries += 1
		flash = 0.15
		Sfx.play("block")
		if game:
			game.shake(6.0, 0.15)
			game.hit_spark(hurt_rect().get_center(), 3.0)
		parry_cd = 2.5
		_counter()
		return false
	if state == "miss":
		amount = maxi(int(round(float(amount) * OPEN_MUL)), amount + 1)
	var r := super(amount, from_x, kind)
	if hp > 0 and not buffed and hp <= hp_max / 2:
		_begin_buff()
	return r


func _flinch() -> void:
	hurt_flip = not hurt_flip
	d["hurt"] = "hurt2" if hurt_flip else "hurt"      # the two flinches in turn
	super()


## the blow was turned aside: he strikes back at once (his fastest swing)
func _counter() -> void:
	if game == null:
		return
	_face(1 if game.mera.global_position.x > global_position.x else -1)
	_to_idle(0.0)
	atk = attacks[1]
	hits_done = {}
	shot_done = false
	_set_state("atk")
	history.append("atk:counter")
	_play(String(atk["anim"]))
	windows = _calc_windows(atk)
	Sfx.play("swipe", 0.8, -4.0)


## ---- half health: sheathe, draw, buff
func _begin_buff() -> void:
	buffed = true
	buff_step = 0
	atk = {}
	marker.visible = false
	vx = 0.0
	_set_state("buff")
	buff_log = ["sheathe"]
	_play("sheathe")
	if game:
		game.shake(10.0, 0.4)


func _on_anim_done() -> void:
	match state:
		"buff":
			buff_step += 1
			if buff_step == 1:
				buff_log.append("draw")
				_play("draw")
			elif buff_step == 2:
				buff_log.append("buff")
				_play("buff")
				if game:
					game.shake(14.0, 0.5)
				Sfx.play("boom_big", 0.7, -2.0)
			else:
				speed *= 1.3
				var faster: Array = []
				for a in attacks:
					var b: Dictionary = a.duplicate()
					b["cd"] = float(a.get("cd", 1.0)) * 0.7
					b["tell"] = maxf(float(a["tell"]) * 0.85, TELE.MIN_TELL)
					faster.append(b)
				attacks = faster
				_to_idle(0.5)
		"parry":
			if sprite.animation == "parry_start":
				_play("parry")
			else:                                     # the guard ran out with nothing to stop: he is open
				parry_misses += 1
				_set_state("miss")
				_play("parry_miss")
		"miss":
			parry_cd = 3.0
			_to_idle(0.4)
		"recover":
			_to_idle(0.3)
		_:
			super()


func _my_tick(_delta: float) -> void:
	pass


## a leap or hop ends: he lands and takes a breath (the land animation)
func _finish_attack() -> void:
	if not atk.is_empty() and atk.has("fall") and hp > 0:
		mid_played = false
		atk = {}
		vx = 0.0
		_set_state("recover")
		_play("land")
		return
	super()


func _start_active(m: Node2D) -> void:
	mid_played = false
	super(m)
