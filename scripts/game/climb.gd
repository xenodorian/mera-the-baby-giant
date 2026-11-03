class_name Climb
extends RefCounted
## Ladder climbing for Mera and Perry (Stage 3 phase 4), the shared "climb" state. Mera._physics_process and
## PerryPlayer._physics_process both call Climb.tick(self, delta) right before their `match state`; with state == "climb"
## the match runs no branch, so the rest of the frame (position += vel * delta, landing, animation) is unchanged.
## Up grabs a ladder at her feet (Up with no ladder is still the jump), Up / Down climb, Left / Right lets go.

const STATE := "climb"


static func tick(m, delta: float) -> void:
	var g = m.game
	if g == null or g.get("ladders") == null or g.ladders.is_empty() and m.state != STATE:
		return
	if m.state == STATE:
		_climb(m, g, delta)
	elif m.state == "ground" or m.state == "air":
		_try_grab(m, g)


static func _is_perry(m) -> bool:
	return m.get("is_perry") == true


static func _try_grab(m, g) -> void:
	var up: Dictionary = m._find("up")
	var dn: Dictionary = m._find("down")
	if up.is_empty() and dn.is_empty():
		return
	var lad := Ladder.nearest(g, m.position.x, m.position.y)
	if lad == null:
		return
	var y: float = m.position.y
	if not up.is_empty() and y > lad.top_y + 12.0:
		m._use(up)
	elif not dn.is_empty() and y <= lad.top_y + 6.0 and y < lad.bottom_y - 20.0:
		m._use(dn)
	else:
		return
	m.state = STATE
	m.set_meta("climb_ladder", lad)
	m.set_meta("climb_side", false)
	m.vel = Vector2.ZERO
	m.on_ground = false
	m.mv = {}
	if _is_perry(m):
		m.pa = ""
	else:
		m._neutral = ""
		m._play("jump", 12)
		m.anim.paused = true


static func _climb(m, g, delta: float) -> void:
	for e in m.presses:               # no attacks on a ladder: whatever was pressed is spent
		e["used"] = true
	var lad = m.get_meta("climb_ladder", null)
	if lad == null or not is_instance_valid(lad) or lad.is_queued_for_deletion():
		_fall(m, 0)
		return
	var real_gy: float = m.ground_y
	var side: int = int(m.pressed("right")) - int(m.pressed("left"))
	if side == 0:
		m.set_meta("climb_side", true)
	var dir: int = int(m.pressed("down")) - int(m.pressed("up"))
	var at_top: bool = m.position.y <= lad.top_y + 0.01
	var at_bot: bool = m.position.y >= lad.bottom_y - 0.01
	if side != 0 and (bool(m.get_meta("climb_side", false)) or at_top or at_bot):
		if at_top:
			var sy: float = g.surface_under(Vector2(m.position.x, lad.top_y), 1e9)
			if sy <= lad.top_y + 8.0:
				m._face(side)
				_land_on(m, sy)
				return
		_fall(m, side)
		return
	m.vel = Vector2.ZERO
	var r := Ladder.climb_step(m, lad, dir, delta, Tuning.LADDER_SPEED)
	if dir < 0 and r < 0:
		var sy2: float = g.surface_under(Vector2(m.position.x, lad.top_y), 1e9)
		if sy2 <= lad.top_y + 8.0:
			_land_on(m, sy2)
			return
	elif dir > 0:
		if m.position.y >= real_gy - 1.0 and m.position.y > lad.top_y + 12.0:
			_land_on(m, real_gy)
			return
		if r > 0:
			_fall(m, 0)
			return
	if not _is_perry(m):
		m.anim.paused = dir == 0
		if dir != 0:
			m.anim.section(10, 15)
	else:
		m.pa = ""
	m.on_ground = false
	m.ground_y = maxf(real_gy, m.position.y + 1.0)        # the landing check must not snap her to a ledge she is climbing past


static func _land_on(m, y: float) -> void:
	m.position.y = y
	m.ground_y = y
	m.on_ground = true
	m.vel = Vector2.ZERO
	m.state = "ground"
	m.remove_meta("climb_ladder")
	if _is_perry(m):
		m.pa = ""
		m.dbl_used = false
		m.grav = m._jump_g()
	else:
		m.anim.paused = false
		m.anim.section(-1, -1)
		m.air_jumps = 1
		m.air_dashes = 1
		m._neutral = "idle"
		m._play("idle")


static func _fall(m, side: int) -> void:
	m.state = "air"
	m.on_ground = false
	m.vel = Vector2(side * 160.0, 0.0)
	if side != 0:
		m._face(side)
	if m.has_meta("climb_ladder"):
		m.remove_meta("climb_ladder")
	if _is_perry(m):
		m.pa = ""
		m.grav = m._jump_g()
	else:
		m.anim.paused = false
		m.anim.section(-1, -1)
		m._neutral = ""
		m._play("jump", 16)
