class_name AllyFaces
extends RefCounted
## Stage 3 phase 7: the AI of the face allies (cl_knight, cl_ranger, cl_weaver, cl_mage, perry). ally.gd (the one ally node)
## calls ai() / gravity() / windows() / fire() for these ids; the per-id numbers are the OPTS table below.
## Styles: "melee" (chase and swing a combo, an optional special every Nth swing) and "ranged" (keep a distance and shoot,
## back off when crowded). cl_ranger also climbs: with a flyer within FLYER_RANGE she targets it first and, when it is more
## than RangerPlanner.SHOT_REACH above her feet, builds a stair (Game.build_platform / build_ladder, planned by
## RangerPlanner) and climbs it before shooting. cl_knight draws attention (Game.taunter, monster.gd _prey).

const G := 3000.0
const FLYER_RANGE := 1500.0
const BUILD_TTL := 25.0
const PERRY_MOVE := {"atk1": "slash", "atk2": "thrust", "atk3": "spin_attack", "sp": "energy_wave"}
## melee: [anim, damage]; shots: [anim, damage, frame the shot leaves]; reach / min_gap / max_gap are px between the bodies
const OPTS := {
	"cl_knight": {"style": "melee", "melee": [["atk1", 4], ["atk2", 5]], "reach": 150.0, "run": 1.4, "taunt": true},
	"perry": {"style": "melee", "melee": [["atk1", 3], ["atk2", 3], ["atk3", 4]], "reach": 90.0, "run": 2.2,
		"special": {"anim": "sp", "dmg": 5, "frame": 2, "every": 4, "proj": {"kind": "wave", "speed": 1100.0, "pierce": true, "life": 0.9}}},
	"cl_mage": {"style": "ranged", "shots": [["cast", 4, 4]], "min_gap": 260.0, "max_gap": 1000.0, "cd": 0.5,
		"proj": {"kind": "orb", "speed": 1300.0, "color": Color(0.7, 0.5, 1.0)}},
	"cl_weaver": {"style": "ranged", "shots": [["shoot", 3, 9]], "min_gap": 220.0, "max_gap": 900.0, "cd": 0.5,
		"proj": {"kind": "bone", "speed": 1200.0, "color": Color(0.93, 0.9, 0.78)}, "melee": [["atk1", 2]]},
	"cl_ranger": {"style": "ranged", "shots": [["shoot", 3, 9]], "min_gap": 200.0, "max_gap": 1000.0, "cd": 0.4,
		"proj": {"kind": "arrow", "speed": 1500.0}, "melee": [["atk1", 2]], "builds": true},
}

static var _pj: Dictionary = {}


static func opts(id: String) -> Dictionary:
	return OPTS.get(id, {})


static func is_flyer(e: Node2D) -> bool:
	return is_instance_valid(e) and e.get("flyer") == true


static func max_rise() -> float:
	return float(Tuning.PLATFORM_STEP_H)


## the enemy this ally fights: the Changeling Ranger takes a live flyer within FLYER_RANGE first, the rest the nearest
static func target_for(a) -> Node2D:
	if bool(opts(a.id).get("builds", false)):
		var best: Node2D = null
		var bd := INF
		for e in a._enemies():
			if is_flyer(e):
				var d: float = e.global_position.distance_to(a.global_position)
				if d <= FLYER_RANGE and d < bd:
					bd = d
					best = e
		if best != null:
			return best
	return a._nearest()


# ---------------------------------------------------------------- the AI
static func ai(a, delta: float) -> void:
	var o: Dictionary = OPTS[a.id]
	var fx: Dictionary = a.fx
	fx["cool"] = float(fx.get("cool", 0.0)) - delta
	fx["plan_cool"] = float(fx.get("plan_cool", 0.0)) - delta
	var e: Node2D = target_for(a)
	fx["target"] = e
	if bool(o.get("builds", false)) and _build_ai(a, e, delta):
		return
	if e == null:
		fx["back_t"] = 0.0
		a._follow(a.game.mera)
		return
	var gap: float = a._gap(e)
	var face := 1 if e.global_position.x > a.global_position.x else -1
	a._face(face)
	if String(o["style"]) == "melee":
		_melee_ai(a, o, e, gap, face)
	else:
		_ranged_ai(a, o, gap, face, delta)


static func _melee_ai(a, o: Dictionary, e: Node2D, gap: float, face: int) -> void:
	var dy: float = absf(e.hurt_rect().get_center().y - a.hurt_rect().get_center().y)
	if gap <= float(o["reach"]) and dy >= 320.0:           # a flyer far overhead: hold
		a.vx = 0.0
		if a.state != "idle":
			a._idle()
		return
	if gap <= float(o["reach"]):
		var sp = o.get("special", null)
		if sp != null and a.attacks_done % int(sp["every"]) == int(sp["every"]) - 1:
			a._attack(String(sp["anim"]), int(sp["dmg"]), int(sp["frame"]))
			return
		var ml: Array = o["melee"]
		var m: Array = ml[a.combo_i % ml.size()]
		a.combo_i += 1
		a._attack(String(m[0]), int(m[1]))
		return
	if sp_range(o, gap, a):
		var sp2: Dictionary = o["special"]
		a._attack(String(sp2["anim"]), int(sp2["dmg"]), int(sp2["frame"]))      # Perry throws the wave at range
		return
	var far: bool = gap > 350.0
	a.vx = face * float(_speed(a)) * (float(o.get("run", 1.0)) if far else 1.0)
	if a.state != "move" or a.sprite.animation != "walk":
		a._go("move", "walk")
	a.sprite.speed_scale = 1.7 if far else 1.0


static func sp_range(o: Dictionary, gap: float, a) -> bool:
	return o.has("special") and gap > 260.0 and gap < 900.0 and a.attacks_done % int(o["special"]["every"]) == int(o["special"]["every"]) - 1


static func _speed(a) -> float:
	return float(Allies.SPEED[a.id])


static func _ranged_ai(a, o: Dictionary, gap: float, face: int, delta: float) -> void:
	var fx: Dictionary = a.fx
	var crowded: bool = gap < float(o["min_gap"])
	if crowded:
		fx["back_t"] = float(fx.get("back_t", 0.0)) + delta
	else:
		fx["back_t"] = 0.0
	if crowded and float(fx["back_t"]) < 1.2:                      # step back; cornered for 1.2 s: shoot anyway
		a.vx = -face * _speed(a) * 0.85
		if a.state != "move" or a.sprite.animation != "walk":
			a._go("move", "walk")
		a.sprite.speed_scale = 1.0
		return
	if gap <= float(o["max_gap"]):
		if float(fx["cool"]) > 0.0:
			a.vx = 0.0
			if a.state != "idle":
				a._idle()
			return
		if crowded and o.has("melee") and gap < 90.0:
			var m: Array = o["melee"][0]
			a._attack(String(m[0]), int(m[1]))
		else:
			var sh: Array = o["shots"][a.combo_i % o["shots"].size()]
			a.combo_i += 1
			a._attack(String(sh[0]), int(sh[1]), int(sh[2]))
		fx["cool"] = float(o.get("cd", 0.5))
		return
	a.vx = face * _speed(a) * 1.3
	if a.state != "move" or a.sprite.animation != "walk":
		a._go("move", "walk")
	a.sprite.speed_scale = 1.4


# ---------------------------------------------------------------- shots and hit windows
## called from ally.gd _arrow() on the frame the shot leaves
static func fire(a) -> void:
	var o: Dictionary = OPTS[a.id]
	var proj: Dictionary = o.get("proj", {})
	if o.has("special") and a.mv == String(o["special"]["anim"]):
		proj = o["special"]["proj"]
	var hr: Rect2 = a.hurt_rect()
	var from := Vector2(a.global_position.x + a.facing * hr.size.x * 0.6, hr.get_center().y - hr.size.y * 0.1)
	var dir := Vector2(a.facing, 0.0)
	var t = a.fx.get("target", null)
	if t != null and is_instance_valid(t):
		dir = (t.hurt_rect().get_center() - from).normalized()
		if dir.x * a.facing <= 0.2 or absf(dir.y) > 0.65:
			dir = Vector2(a.facing, signf(dir.y) * 0.65).normalized() if dir.x * a.facing > 0.0 else Vector2(a.facing, 0.0)
	var s: Node2D = load("res://scripts/game/ally_bolt.gd").new()
	s.setup(a.game, a, from, dir, a.mv_dmg, a.k, proj)
	a.get_parent().add_child(s)
	a.played["bolt"] = true
	Sfx.play("cast", 1.2, -8.0)


## Perry's real hit frames (assets/perry/perry_player.json) as attack windows; [] for the others (ally.gd cuts them from the art)
static func windows(a, anim: String) -> Array:
	if a.id != "perry" or not PERRY_MOVE.has(anim):
		return []
	if _pj.is_empty():
		var f := FileAccess.open("res://assets/perry/perry_player.json", FileAccess.READ)
		_pj = JSON.parse_string(f.get_as_text()) if f != null else {"moves": {}}
	var mv: Dictionary = _pj.get("moves", {}).get(PERRY_MOVE[anim], {})
	var out: Array = []
	var cur: Array = []
	var frames: Array = mv.get("frames", [])
	for i in frames.size():
		if not (frames[i]["hits"] as Array).is_empty():
			cur.append(i)
		elif not cur.is_empty():
			out.append(cur)
			cur = []
	if not cur.is_empty():
		out.append(cur)
	return out


# ---------------------------------------------------------------- ground: platforms
## the surface under the ally (the level ground, a map ledge or a built plank)
static func floor_y(a, from_y: float) -> float:
	if a.game != null and a.game.has_method("surface_under"):
		return float(a.game.surface_under(Vector2(a.position.x, from_y), from_y))
	return a.gy


## replaces ally.gd _gravity for the face allies: they stand on built planks and fall off when one goes
static func gravity(a, delta: float) -> void:
	if bool(a.fx.get("climbing", false)):
		return
	if a.on_ground:
		if a.state != "arrive" and floor_y(a, a.position.y) > a.position.y + 3.0:
			a.on_ground = false
			a.vy = 0.0
		return
	var prev: float = a.position.y
	a.vy += G * delta
	a.position.y += a.vy * delta
	if a.vy >= 0.0:
		var fl := floor_y(a, prev)
		if a.position.y >= fl:
			a.position.y = fl
			a.vy = 0.0
			a.on_ground = true


# ---------------------------------------------------------------- the Changeling Ranger builds
static func _alive(n) -> bool:
	return n != null and is_instance_valid(n) and not n.is_queued_for_deletion()


static func live_builds(a) -> int:
	var n := 0
	for b in a.fx.get("built", []):
		if _alive(b):
			n += 1
	return n


static func _abort(a, cool: float = 3.0) -> void:
	var fx: Dictionary = a.fx
	fx["steps"] = []
	fx["i"] = 0
	fx["plan_cool"] = cool
	if bool(fx.get("climbing", false)):
		fx["climbing"] = false
		a.on_ground = false
		a.vy = 0.0


## builds the stair for flyer `e` from where she stands; returns the plan (steps carry their nodes) or {}
static func build_stair(a, e: Node2D) -> Dictionary:
	var g = a.game
	if g == null or not g.has_method("build_platform") or not g.has_method("build_ladder"):
		return {}
	var tc: Vector2 = e.hurt_rect().get_center()
	var p := RangerPlanner.plan(a.position.x, a.position.y, e.global_position.x, tc.y, max_rise(), BUILD_TTL)
	if p["steps"].is_empty():
		return {}
	var built: Array = []
	for st in p["steps"]:
		if st["kind"] == "platform":
			st["node"] = g.build_platform(float(st["x"]), float(st["top_y"]), float(st["w"]), BUILD_TTL)
		else:
			st["node"] = g.build_ladder(float(st["x"]), float(st["bottom_y"]), float(st["top_y"]), BUILD_TTL)
		built.append(st["node"])
	a.fx["built"] = built
	a.fx["steps"] = p["steps"]
	a.fx["i"] = 0
	a.fx["tries"] = 0
	a.fx["plan_t"] = 0.0
	a.played["build"] = true
	return p


## returns true when it took over this frame (building, walking to a step, jumping, climbing)
static func _build_ai(a, e: Node2D, delta: float) -> bool:
	var fx: Dictionary = a.fx
	var steps: Array = fx.get("steps", [])
	if steps.is_empty():
		if e == null or not is_flyer(e) or not a.on_ground or float(fx.get("plan_cool", 0.0)) > 0.0:
			return false
		if a.state in ["atk", "hit", "leave", "dead", "arrive"] or live_builds(a) > 0:
			return false
		if RangerPlanner.climb_needed(a.position.y, e.hurt_rect().get_center().y) <= 0.0:
			return false
		a.vx = 0.0
		a._face(1 if e.global_position.x > a.global_position.x else -1)
		if build_stair(a, e).is_empty():
			fx["plan_cool"] = 3.0
			return false
		a.mv = ""
		a._go("atk", "cast")                       # the cast animation (no hit window: mv is empty)
		return true
	# a stair is under way
	if e == null or not is_flyer(e):
		_abort(a, 2.0)
		return false
	fx["plan_t"] = float(fx.get("plan_t", 0.0)) + delta
	if float(fx["plan_t"]) > 14.0 or int(fx.get("tries", 0)) > 5:
		_abort(a, 6.0)
		return false
	if a.state == "atk" or a.state == "hit":
		return true                                # let the cast animation finish
	var i: int = int(fx.get("i", 0))
	if i >= steps.size():                          # at the top: shoot from here
		fx["steps"] = []
		fx["plan_cool"] = 4.0
		return false
	var st: Dictionary = steps[i]
	if not _alive(st.get("node")):
		_abort(a)
		return false
	a._face(1 if e.global_position.x > a.global_position.x else -1)
	if st["kind"] == "platform":
		return _step_platform(a, fx, st)
	return _step_ladder(a, fx, st, steps, i, delta)


static func _step_platform(a, fx: Dictionary, st: Dictionary) -> bool:
	var cx := float(st["x"])
	var half := float(st["w"]) * 0.5 - 40.0
	var dx: float = cx - float(a.position.x)
	if not a.on_ground:                            # in the air: drift over the plank
		a.vx = clampf(dx * 3.0, -420.0, 420.0)
		return true
	if absf(a.position.y - float(st["top_y"])) < 6.0 and absf(a.position.x - cx) <= float(st["w"]) * 0.5:
		fx["i"] = int(fx["i"]) + 1                 # standing on it
		return true
	if absf(dx) > half * 0.7:                      # walk under / onto the plank first
		a.vx = signf(dx) * _speed(a)
		if a.state != "move" or a.sprite.animation != "walk":
			a._go("move", "walk")
		a.sprite.speed_scale = 1.3
		return true
	var rise: float = a.position.y - float(st["top_y"])
	a.vy = -sqrt(2.0 * G * (maxf(rise, 0.0) + 50.0))
	a.vx = clampf(dx * 2.0, -300.0, 300.0)
	a.on_ground = false
	fx["tries"] = int(fx.get("tries", 0)) + 1
	a._go("move", "jump")
	return true


static func _step_ladder(a, fx: Dictionary, st: Dictionary, steps: Array, i: int, delta: float) -> bool:
	var lad: Node2D = st["node"]
	if not bool(fx.get("climbing", false)):
		var dx: float = float(lad.global_position.x) - float(a.position.x)
		if not a.on_ground:
			return true
		if absf(dx) > 14.0:
			a.vx = signf(dx) * _speed(a)
			if a.state != "move" or a.sprite.animation != "walk":
				a._go("move", "walk")
			a.sprite.speed_scale = 1.3
			return true
		fx["climbing"] = true                      # she grabs the ladder
		a.vx = 0.0
		a.vy = 0.0
		a._go("move", "walk")
	a.vx = 0.0
	var r: int = Ladder.climb_step(a, lad, -1, delta, Tuning.LADDER_SPEED)
	a.sprite.speed_scale = 0.8
	if r == -1:                                    # the top: step onto the plank
		var nxt: float = float(steps[i + 1]["x"]) if i + 1 < steps.size() else lad.global_position.x
		fx["climbing"] = false
		a.position.y = lad.top_y
		a.position.x += signf(nxt - lad.global_position.x) * 70.0
		a.on_ground = true
		a.vy = 0.0
		fx["i"] = i + 1
	return true
