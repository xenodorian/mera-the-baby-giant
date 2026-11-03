extends "res://scripts/game/cl_enemy.gd"
## Stage 3 boss: the Warlord (Roster id cl_warlord; original: assets/changeling/source/src/enemies.js E5).
## Three phases by hp (above 2/3, above 1/3, the rest). Each attack in Roster.DEFS carries the first phase that uses it:
##   phase 1  walks at Mera, sword swing, arrows from range, a hop
##   phase 2  + a CHARGE across the arena; if he reaches the arena edge he crashes and is stunned (CHARGE_STUN s)
##   phase 3  + a JUMP SLAM: two floor shockwaves roll out from the landing spot (jump them); tells are faster and he walks faster
## His damage never scales.

const WAVE := preload("res://scripts/game/cl_wave.gd")
const CHARGE_STUN := 1.4
const FAST_TELL := 0.76

var phase := 1
var phase_log: Array = [1]           # phases entered, in order (tests)
var charge_stuns := 0
var slams := 0
var charges := 0
var base_speed := 0.0
var mid := false                     # the Stage 3 mid-boss: a smaller, weaker copy (Tuning.MID_BOSS_*)
var mid_ratio := 1.0                 # its size / the full Warlord's size: attack distances shrink with it


func setup(g: Node, enemy_id: String, x: float, opts: Dictionary = {}) -> void:
	super(g, enemy_id, x, opts)
	if bool(opts.get("mid", false)):
		mid = true
		mid_ratio = Tuning.MID_BOSS_K / k
		k = Tuning.MID_BOSS_K
		hp_max = Tuning.MID_BOSS_HP
		hp = hp_max
	base_speed = speed
	attacks = _phase_attacks(1)


## the attacks of a phase (phase 3 gets shorter tells and waits)
func _phase_attacks(ph: int) -> Array:
	var out: Array = []
	for a in d["attacks"]:
		if int(a.get("phase", 1)) > ph:
			continue
		var b: Dictionary = a.duplicate()
		if mid:                                            # a smaller body reaches less far
			if float(b["near"]) > 0.0:
				b["near"] = float(b["near"]) * mid_ratio
			b["far"] = float(b["far"]) * mid_ratio
		if ph >= 3:
			b["tell"] = maxf(float(a["tell"]) * FAST_TELL, TELE.MIN_TELL)
			b["cd"] = float(a["cd"]) * 0.75
		out.append(b)
	return out


func phase_for_hp() -> int:
	var f := float(hp) / float(hp_max)
	return 1 if f > 2.0 / 3.0 else (2 if f > 1.0 / 3.0 else 3)


func take_damage(amount: int, from_x: float, kind: String = "melee") -> bool:
	var r := super(amount, from_x, kind)
	if hp > 0:
		_check_phase()
	return r


func _check_phase() -> void:
	var ph := phase_for_hp()
	if ph <= phase:
		return
	phase = ph
	phase_log.append(ph)
	atk_i = 0
	attacks = _phase_attacks(ph)
	if ph >= 3:
		speed = base_speed * 1.2
	if game:
		game.shake(8.0, 0.25)
	Sfx.play("boom_big", 0.5, -6.0)


func _start_active(m: Node2D) -> void:
	super(m)
	if bool(atk.get("charge", false)):
		charges += 1


func _physics_process(delta: float) -> void:
	if state == "atk" and bool(atk.get("charge", false)) and game != null:
		var edge_l: bool = facing < 0 and position.x <= Levels.EDGE + 40.0
		var edge_r: bool = facing > 0 and position.x >= float(game.map_w) - Levels.EDGE - 40.0
		if edge_l or edge_r:
			_crash()
	super(delta)


## the charge ran into the arena wall: he is stunned and open
func _crash() -> void:
	atk = {}
	vx = 0.0
	marker.visible = false
	charge_stuns += 1
	stunned_total += 1
	stun_t = CHARGE_STUN
	_set_state("stun")
	sprite.pause()
	if game:
		game.shake(10.0, 0.3)
		game.hit_spark(hurt_rect().get_center(), 3.0)
	Sfx.play("hit_heavy", 0.6)


func _finish_attack() -> void:
	if not atk.is_empty() and bool(atk.get("slam", false)) and hp > 0 and game != null:
		_slam_waves()
	super()


func _slam_waves() -> void:
	slams += 1
	var dmg := int(atk["dmg"])
	for dir in [-1.0, 1.0]:
		var w: Node2D = WAVE.new()
		w.setup(game, global_position.x + dir * 80.0, dir, dmg, self)
		get_parent().add_child(w)
	game.shake(12.0, 0.3)
	Sfx.play("boom_big", 0.7)
