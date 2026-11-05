class_name PerryPlayer
extends Mera
## Perry Riposte as a playable character (Stage 3 phase 3, docs/CONTROLS.md "Perry", docs/GAME_RULES.md "Perry").
## She extends Mera so every member game.gd, monster.gd, allies, pickups, props, enemy shots and the HUD read on the
## player exists (position, facing, state, mv, hurt_rect(), take_hit(), size, shown, stamina, rage, potions, debug ...).
## The Mera-only systems (Fury, lightning, the bubbles, the freeze slash, the size animation) are stubs. Her art, moves,
## frame data and attack boxes come from assets/perry/perry_player.json (tools/build_perry_player.py).
## Her health is hp / hp_max (HUD: HP bar). `size` only mirrors Carry's size for Mera, so a run saved as Perry does not
## change Mera. Moves she has not bought (PerryUnlocks) never start.

const DATA_PATH := "res://assets/perry/perry_player.json"
const DIR := "res://assets/characters/perry/player/"
const S := Tuning.PERRY_SCALE
const BEAMS := {"l2": ["beam_cloud", "cloud"], "l1": ["beam_laser", "laser"], "r2": ["beam_fire", "fire"], "r1": ["beam_plasma", "plasma"]}
## the supers that fill the screen (the meteor shower, the earthquake): the original drew them over its 384 px screen at Perry's scale 2 = 768 px; this game's screen is 1920 px wide, so they are drawn 2.5x bigger
const SCREEN_FX := ["meteor_shower", "earthquake"]
const CHAIN_MOVES := ["slash", "chain2", "chain3", "chain4"]
const SHOULDER_KEYS := ["l1", "l2", "r1", "r2"]
const ULT_STEPS := ["taunt", "beam_plasma", "beam_cloud", "beam_fire", "beam_laser"]
const BOTH_SIDES := ["spin_attack", "energy_wave"]
const HILT := Vector2(58.0, 48.0)             # native px from the anchor: where a beam leaves her (08_beams.js)
const BEAM_CORE := 0.7
## 00_core.js replaces the push kick's and the energy kick's small foot capsule with a box from 38 px to this x (native px from the
## move's anchor), from 1 px below the floor up to 34.8 px, on both active frames
const KICK_BOX_X1 := {"push_kick": 95.0, "energy_kick": 102.9}
const KICK_BOX_X0 := 38.0
const KICK_BOX_TOP := 34.8
const ANCHOR_TO_JSON_X := 64.0      # the move data's x is the source's anchor-relative x minus the body centre (64)

static var _data: Dictionary = {}
static var _tex: Dictionary = {}

var is_perry := true
var hp := Tuning.PERRY_HP_START
var hp_max := Tuning.PERRY_HP_START
var empower := Tuning.PERRY_EMPOWER_START
var empower_max := Tuning.PERRY_EMPOWER_START
var spr: Sprite2D
var fx_a: Sprite2D
var fx_b: Sprite2D
var beam_spr: Sprite2D
var pa := ""                 # animation (move) shown
var pk := 0                  # its frame
var pt := 0.0                # ms into the frame
var lift := 0.0              # px above the surface (move root motion), drawn and hit with her
var lift_k := 1.0
var root_x := 0.0
var hist: Array = []         # every press {a, t}, used or not, for sequences
var chain := {"n": 0, "t": -1e9}
var charging := {}           # {move, keys, ms}
var ult: Array = []
var block_hold := false
var parry_t0 := -1e9
var hurt_t := 0.0
var down_rel_t := -1e9
var ed_armed_t := -1e9
var dbl_used := false
var spin_t := -1e9
var grav := 0.0
var rainbow_t := 0.0
var air_v0 := 0.0
var meter_acc := 0.0
var heal_acc := 0.0
var beam_cut := false
var beam_t := 0.0
var beam_ms := 0.0
var beam_state := {}         # kind, len, box (world) for tests and projectile clashes
var _prev_held := {}
var _dir_prev := {}
var _tap_dir := ""
var _tap_t := -1e9
var hit_count := 0           # enemies / props hit (tests)
var blocks := 0
var _flash_t := 0.0


# ---------------------------------------------------------------- data
static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		_data = _prepare(JSON.parse_string(f.get_as_text()))
	return _data


## attack boxes become Rect2 relative to the body centre (the hurtbox centre), y down from the feet
static func _prepare(raw: Dictionary) -> Dictionary:
	var hurt: Array = raw["hurt"]
	var hc := (float(hurt[0]) + float(hurt[1])) / 2.0
	var out := {"hc": hc, "hw": (float(hurt[1]) - float(hurt[0])) / 2.0, "moves": {}, "fx": raw["fx"], "beams": raw["beams"]}
	for id in raw["moves"]:
		var m: Dictionary = raw["moves"][id]
		var frames: Array = []
		var last_hit := -1
		var i := 0
		for f in m["frames"]:
			var boxes: Array = []
			for b in f["hits"]:
				boxes.append(Rect2(float(b[0]) - hc, float(b[1]), float(b[2]) - float(b[0]), float(b[3]) - float(b[1])))
			if not boxes.is_empty():
				last_hit = i
			frames.append({"name": String(f["name"]), "ms": float(f["ms"]), "rx": float(f["root"][0]), "ry": float(f["root"][1]),
				"top": float(f["top"]), "hits": boxes, "beam": f.get("beam", {})})
			i += 1
		if KICK_BOX_X1.has(id):
			for fr in frames:
				if not (fr["hits"] as Array).is_empty():
					fr["hits"] = [Rect2(KICK_BOX_X0 - ANCHOR_TO_JSON_X - hc, -KICK_BOX_TOP, float(KICK_BOX_X1[id]) - KICK_BOX_X0, KICK_BOX_TOP + 1.0)]
		var pv: Array = m["pivot"]
		var an: Array = m["anchor"]
		out["moves"][id] = {"anim": String(m["anim"]), "frames": frames, "loop": bool(m["loop"]), "loop_from": int(m["loopFrom"]),
			"origin": Vector2(float(pv[0]) + hc, float(pv[1])), "anchor": Vector2(float(an[0]), float(an[1])),
			"ao": float(pv[0]) + hc - float(an[0]), "last_hit": last_hit, "fx": String(m.get("fx", "")), "fx_scale": float(m.get("fxScale", 1.0)) * (Tuning.PERRY_SCREEN_FX_K if id in SCREEN_FX else 1.0),
			"enter": m.get("enter")}
	return out


static func mdef(id: String) -> Dictionary:
	return data()["moves"][id]


static func frames_tex(anim: String, n: int) -> Array:
	if not _tex.has(anim):
		var a: Array = []
		for i in n:
			a.append(load("%s%s/%s_%d.png" % [DIR, anim, anim, i + 1]))
		_tex[anim] = a
	return _tex[anim]


func _ready() -> void:
	anim = LayeredAnim.new()                  # only carries key / idx for the HUD's state line and the tests
	anim.visible = false
	add_child(anim)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for a in TRACK:
		held[a] = false
		held_since[a] = 0.0
		_prev_held[a] = false
	spr = Sprite2D.new()
	spr.centered = false
	fx_a = Sprite2D.new()
	fx_a.centered = false
	fx_b = Sprite2D.new()
	fx_b.centered = false
	beam_spr = Sprite2D.new()
	beam_spr.centered = false
	beam_spr.region_enabled = true
	beam_spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for n in [fx_a, fx_b, spr, beam_spr]:
		add_child(n)
	Carry.ensure()
	hp_max = Carry.perry_hp_max
	hp = hp_max
	size = Carry.size                          # mirrors Mera's saved size; never changes here
	shown = float(size)
	grav = _jump_g()
	_set_anim("idle")
	_place()


func _exit_tree() -> void:
	pass


# ---------------------------------------------------------------- small helpers
func _m(id: String) -> Dictionary:
	return mdef(id)


func _frame() -> Dictionary:
	return _m(pa)["frames"][pk]


func _jump_g() -> float:
	return 2.0 * Tuning.PERRY_JUMP_H * S / pow(Tuning.PERRY_JUMP_APEX_S, 2.0)


func _jump_v() -> float:
	return 2.0 * Tuning.PERRY_JUMP_H * S / Tuning.PERRY_JUMP_APEX_S


func _has(move: String) -> bool:
	return PerryUnlocks.has_move(move)


func _own(id: String) -> bool:
	return PerryUnlocks.has(id)


func _btn_on(a: String) -> bool:
	return PerryUnlocks.button_on(a.to_upper())


func air_height() -> float:
	return maxf(ground_y - position.y, 0.0) + lift


## last press time of `a` (hist), or -1e9
func _last_t(a: String) -> float:
	for i in range(hist.size() - 1, -1, -1):
		if hist[i]["a"] == a:
			return float(hist[i]["t"])
	return -1e9


func _near(a: String) -> bool:
	return bool(held.get(a, false)) or now - _last_t(a) <= Tuning.CHORD_MS


## the last n presses are exactly `list`, each within PERRY_SEQ_MS of the next and the last within it of now
func _tail(list: Array) -> bool:
	var n := list.size()
	if hist.size() < n:
		return false
	var tail := hist.slice(hist.size() - n)
	for i in n:
		if tail[i]["a"] != list[i]:
			return false
		if i > 0 and float(tail[i]["t"]) - float(tail[i - 1]["t"]) > Tuning.PERRY_SEQ_MS:
			return false
	return now - float(tail[n - 1]["t"]) <= Tuning.PERRY_SEQ_MS


func _deny(meter: String) -> void:
	Sfx.play("fail", 1.3, -4.0)
	if game:
		game.flash_hud("stamina" if meter != "super" else "rage")


func _spend_energy(v: float) -> bool:
	if stamina + 0.001 < v:
		_deny("energy")
		return false
	stamina = maxf(stamina - v, 0.0)
	return true


func add_empower(v: float) -> void:
	empower = clampf(empower + v, 0.0, empower_max)


func heal(n: int) -> void:
	if state == "dead":
		return
	hp = mini(hp + n, hp_max)


# ---------------------------------------------------------------- Mera interface: stubs and Perry versions
func scale_cap() -> int:
	return size + 1 if hp < hp_max else size      # game.collect: a green potion heals her while HP is not full


func set_size(n: int, instant: bool = false) -> void:
	if instant:
		size = n                                    # a saved run restores Mera's size, which she only carries
		shown = float(size)
		return
	if n > size:
		heal(Tuning.PERRY_POTION_HP)                # a potion pickup


func start_fury() -> void:
	pass


func set_aura_quality(_q: int) -> void:
	pass


func gallery_toggle() -> void:
	pass


func crouch_bubble_on() -> bool:
	return false


func _try_mark() -> bool:
	return false


func can_lightning() -> bool:
	return false


func parry_ready() -> bool:
	return false


func dodging() -> bool:
	return state == "move" and String(mv.get("key", "")) == "dash" and _progress() < Tuning.PERRY_DASH_IFRAME


func swing_parry_open() -> bool:
	if state != "move" or not mv.has("swing_t"):
		return false
	return now - float(mv["swing_t"]) <= Tuning.SWING_PARRY_MS


func art_to_world(p: Vector2) -> Vector2:
	return global_position + Vector2(facing * p.x * S, p.y * S)


func _progress() -> float:
	var m := _m(pa)
	var tot := 0.0
	var at := 0.0
	for i in m["frames"].size():
		var ms: float = m["frames"][i]["ms"]
		if i < pk:
			at += ms
		elif i == pk:
			at += minf(pt, ms)
		tot += ms
	return at / maxf(tot, 1.0)


func hurt_rect() -> Rect2:
	var d := data()
	var top := float(_frame()["top"]) if pa != "" else 80.0
	if pa == "duck":
		top -= 5.0
	var hw := float(d["hw"]) * S
	return Rect2(position.x - hw, position.y - lift - top * S, hw * 2.0, top * S)


func body_rect() -> Rect2:
	return hurt_rect()


## the attack boxes of the live frame in world space (both sides for the spin and the wave); empty when none
func hit_rects() -> Array:
	var out: Array = []
	if state != "move" or int(mv.get("dmg", 0)) <= 0:
		return out
	var f := _frame()
	var m := _m(pa)
	var both: bool = String(mv.get("key", "")) in BOTH_SIDES
	for b in f["hits"]:
		var r: Rect2 = b
		out.append(_world_rect(r.position.x, r.end.x, r, 1))
		if both:
			var ao := float(m["ao"])
			out.append(_world_rect(-r.end.x - 2.0 * ao, -r.position.x - 2.0 * ao, r, 1))
	return out


func _world_rect(x0: float, x1: float, r: Rect2, _side: int) -> Rect2:
	var xa := x0 * S
	var xb := x1 * S
	if facing < 0:
		var t := -xb
		xb = -xa
		xa = t
	return Rect2(position.x + xa, position.y - lift + r.position.y * S, xb - xa, r.size.y * S)


func hit_rect() -> Rect2:
	var rs := hit_rects()
	if rs.is_empty():
		return Rect2()
	var u: Rect2 = rs[0]
	for i in range(1, rs.size()):
		u = u.merge(rs[i])
	return u


func beam_world_rect() -> Rect2:
	if beam_state.is_empty():
		return Rect2()
	return beam_state["box"]


func counter_active() -> bool:
	return now < counter_until


# ---------------------------------------------------------------- animation
func _set_anim(id: String, start: int = 0) -> void:
	pa = id
	pk = start
	pt = 0.0
	anim.key = id
	anim.idx = start
	move_log.append(id)
	move_started.emit(id)


func _tex_now() -> Texture2D:
	var m := _m(pa)
	return frames_tex(String(m["anim"]), m["frames"].size())[pk]


func _place() -> void:
	if pa == "":
		_set_anim("idle")
	var m := _m(pa)
	var fr: Array = m["frames"]
	pk = clampi(pk, 0, fr.size() - 1)
	anim.idx = pk
	var org: Vector2 = m["origin"]
	spr.texture = _tex_now()
	spr.offset = -org
	spr.scale = Vector2(facing * S, S)
	spr.position = Vector2(0, -lift)
	if spin_t > -1e8 and now - spin_t < 420.0 and state == "air":      # the double jump's spin: a full turn about her middle
		spr.rotation = TAU * ((now - spin_t) / 420.0) * facing
		spr.position = Vector2(0, -lift - 40.0 * S)
		spr.offset = -org + Vector2(0, 40.0)
	else:
		spr.rotation = 0.0
	var tint := Color(1, 1, 1, 1)
	if invuln > 0.0 and state != "dead":
		tint.a = 0.35 if int(invuln * 14.0) % 2 == 0 else 1.0
	if rainbow_t > 0.0:
		tint = Color.from_hsv(fmod(now / 450.0, 1.0), 0.6, 1.0, 1.0)
	elif counter_active():
		var q2 := 0.5 + 0.5 * sin(now / 40.0)
		tint = Color(1.0 + 0.5 * q2, 1.0 + 0.35 * q2, 0.75, tint.a)
	elif charging.size() > 0 and float(charging["ms"]) >= Tuning.PERRY_CHARGE_FULL_MS:
		tint = Color(0.6, 0.75, 1.5, tint.a)
	elif state == "dead" or hurt_t > 0.25:
		tint = Color(1.4, 0.55, 0.55, tint.a)
	spr.modulate = tint
	# effects (energy wave, burst, meteor shower) at their own scale, behind her
	var fxn := String(m["fx"])
	fx_a.visible = false
	fx_b.visible = false
	if fxn != "" and state == "move":
		var info: Dictionary = data()["fx"][fxn]
		var ft := frames_tex(fxn, int(info["frames"]))
		var idx := mini(pk, ft.size() - 1)
		var fs := float(m["fx_scale"])
		for side in 2:
			var n: Sprite2D = fx_a if side == 0 else fx_b
			if side == 1 and String(mv.get("key", "")) not in BOTH_SIDES:
				continue
			if String(mv.get("key", "")) == "energy_wave" and bool((mv.get("blast", {}) as Dictionary).get(side, false)) and pk >= 2:
				continue
			n.texture = ft[idx]
			n.offset = -(m["anchor"] as Vector2)
			n.scale = Vector2((facing if side == 0 else -facing) * S * fs, S * fs)
			n.position = Vector2(-facing * float(m["ao"]) * S, -lift)
			n.visible = true
	_place_beam()


func _place_beam() -> void:
	beam_spr.visible = false
	beam_state = {}
	if state != "move" or beam_cut:
		return
	var b: Dictionary = _frame()["beam"]
	if b.is_empty():
		return
	var kind := String(b["kind"])
	var info: Dictionary = data()["beams"][kind]
	var m := _m(pa)
	var el := beam_ms
	var blen := minf(Tuning.PERRY_BEAM_LEN, 40.0 + el * 8.0)
	var ox := (HILT.x - float(m["ao"]))              # native, from the body centre
	var oy := HILT.y
	var h := float(info["h"])
	var tex: Texture2D = frames_tex(String(info["anim"]), 1)[0]
	beam_spr.texture = tex
	beam_spr.region_rect = Rect2(float(int(float(info["w"]) - fmod(now * 0.45, float(info["w"])))), 0, blen, h)
	beam_spr.offset = Vector2(0, -h / 2.0)
	beam_spr.scale = Vector2(facing * S, S)
	beam_spr.position = Vector2(facing * ox * S, -(oy * S + lift))
	beam_spr.modulate.a = 0.6 if _last_beam_frame() else 1.0
	beam_spr.visible = true
	var cx0 := position.x + facing * ox * S
	var cx1 := cx0 + facing * blen * S
	var cy := position.y - (oy * S + lift)
	var half := h * BEAM_CORE / 2.0 * S
	beam_state = {"kind": kind, "len": blen, "box": Rect2(minf(cx0, cx1), cy - half, absf(cx1 - cx0), half * 2.0)}


func _last_beam_frame() -> bool:
	var fr: Array = _m(pa)["frames"]
	return pk + 1 >= fr.size() or (fr[pk + 1]["beam"] as Dictionary).is_empty()


## a frame's length. The black and white impact frame of the chop, the jump crash and the earthquake always lasts 110 ms (the original skipped it on an uncharged chop and a low crash; the owner wants it every time)
func _frame_ms(fr: Array, i: int) -> float:
	var bw_frame := {"heavy": "impactbw", "jump_crash": "flash", "earthquake": "flash"}     # the black and white frame of each (moves_extra.js bw)
	if bw_frame.get(String(mv.get("key", "")), "") == String(fr[i]["name"]):
		return Tuning.PERRY_HEAVY_BW_MS
	return float(fr[i]["ms"])


## advance the animation; true when a non-looping one ran off its end (it holds its last frame)
func _advance(delta: float) -> bool:
	var m := _m(pa)
	var fr: Array = m["frames"]
	pt += delta * 1000.0
	while pt >= _frame_ms(fr, pk):
		pt -= _frame_ms(fr, pk)
		if pk + 1 < fr.size():
			pk += 1
			_enter_frame()
		elif bool(m["loop"]):
			pk = int(m["loop_from"])
			_enter_frame()
		else:
			pt = 0.0
			return true
	return false


func _enter_frame() -> void:
	anim.idx = pk
	if state != "move":
		return
	var f := _frame()
	var rx := float(f["rx"])
	var reach_k := Tuning.PERRY_DASH_REACH if String(mv.get("key", "")) in ["dash", "dash_thrust", "energy_dash_thrust"] else 1.0
	position.x += facing * (rx - root_x) * S * reach_k
	root_x = rx
	lift = float(f["ry"]) * S * lift_k
	var key := String(mv.get("key", ""))
	if key == "earthquake" and String(f["name"]) == "slam" or key == "jump_crash" and String(f["name"]) == "crash":
		if game:
			game.shake(10.0, 0.45)
			if key == "earthquake":
				game.heavy_slam(Tuning.PERRY_HEAVY_QUAKE_SHAKE, Tuning.PERRY_QUAKE_RUMBLE_S)    # the impact frame, then the 1.5 s aftershake and a real quake
		Sfx.play("boom", 0.8)
	if key == "energy_wave" and String(f["name"]) == "plow":
		for side in 2:
			_wave_blast(side, Vector2(position.x + (facing if side == 0 else -facing) * 200.0 * S, position.y - 30.0 * S))
	if not (f["hits"] as Array).is_empty() or not (f["beam"] as Dictionary).is_empty():
		if not mv.has("swing_t") and key in CHAIN_MOVES:
			mv["swing_t"] = now


# ---------------------------------------------------------------- the main loop
func _physics_process(delta: float) -> void:
	now += HitStop.input_dt(delta) * 1000.0
	_poll_input()
	_log_presses()
	if game != null and game.mark_lock:
		for e in presses:
			e["used"] = true
		vel = Vector2.ZERO
		return
	_timers(delta)
	_items_tick()
	if state == "move":
		_early_chord()
	Climb.tick(self, delta)       # phase 4: Up grabs a ladder; state "climb" runs no branch below
	match state:
		"ground":
			_ground_tick(delta)
		"air":
			_air_tick(delta)
		"move":
			_move_tick(delta)
		"hurt":
			_hurt_tick(delta)
		"dead":
			vel.x = move_toward(vel.x, 0.0, 600.0 * delta)
			_gravity_p(delta)
	position += vel * delta
	_land_p()
	if pa == "":
		_set_anim("idle")
	_advance_pose(delta)
	_place()
	if state == "move":
		_perry_hits(delta)
	for a in TRACK:
		_prev_held[a] = bool(held[a])
	if game != null:
		game.resolve_projectiles()


func _log_presses() -> void:
	for e in presses:
		if not e.has("seen"):
			e["seen"] = true
			hist.append({"a": e["a"], "t": e["t"]})
			_press_sequences(e)
	while hist.size() > 24 or (hist.size() > 0 and now - float(hist[0]["t"]) > 3000.0):
		hist.pop_front()
	if _prev_held.get("down", false) and not held["down"]:
		down_rel_t = now
	for dk in ["left", "right"]:                         # a double tap of the same direction arms the energy dash thrust
		var on := pressed(dk)
		if on and not bool(_dir_prev.get(dk, false)):
			if dk == _tap_dir and now - _tap_t <= Tuning.PERRY_SEQ_MS:
				ed_armed_t = now
			_tap_dir = dk
			_tap_t = now
		_dir_prev[dk] = on


## sequences are read the moment the last press lands, in any state (a queued press would miss its window)
func _press_sequences(e: Dictionary) -> void:
	if state in ["dead", "hurt"]:
		return
	var a := String(e["a"])
	if a == "btn_b" and _own("rainbow") and _tail(["btn_a", "btn_b", "btn_a", "btn_b", "btn_a", "btn_b"]):
		_use(e)
		rainbow_t = Tuning.PERRY_RAINBOW_S
		invuln = maxf(invuln, rainbow_t)
		Sfx.play("heal", 0.7)
		return
	if state not in ["ground", "air", "move"] or not charging.is_empty():
		return
	if a == "btn_b" and _has("meteor_shower") and _tail(["btn_b", "btn_b", "btn_b", "btn_b", "btn_b"]) and state != "air":
		_use(e)
		_super("meteor_shower")
	elif a == "btn_a" and _has("earthquake") and _tail(["down", "down", "down", "down", "btn_a"]) and state != "air":
		_use(e)
		_super("earthquake")
	elif a == "up" and _own("fly") and _tail(["btn_a", "btn_b", "btn_a", "btn_b", "up"]):
		_use(e)
		_flight()


func _timers(delta: float) -> void:
	if invuln > 0.0:
		invuln -= delta
	if rainbow_t > 0.0:
		rainbow_t -= delta
		invuln = maxf(invuln, rainbow_t)
	_stamina_tick(delta)
	empower = minf(empower + Tuning.PERRY_EMPOWER_REGEN * delta, empower_max)
	if _flash_t > 0.0:
		_flash_t -= delta


func _gravity_p(delta: float) -> void:
	if not on_ground:
		vel.y += grav * delta


func _land_p() -> void:
	if position.y >= ground_y:
		position.y = ground_y
		if not on_ground:
			on_ground = true
			vel.y = 0.0
			_on_land()
	elif position.y < ground_y - 0.5:
		if on_ground and state == "ground":              # walked off a platform (or it crumbled): fall
			state = "air"
			grav = _jump_g()
			dbl_used = false
		on_ground = false


func _on_land() -> void:
	grav = _jump_g()
	if state == "air":
		state = "ground"
		pa = ""
		dbl_used = false
		spin_t = -1e9
		vel.x = 0.0


## a pose or the end of a move
func _advance_pose(delta: float) -> void:
	if state in ["air", "dead", "hurt"] or pa == "":
		return
	var done := _advance(delta)
	if state == "move" and done:
		_end_move()


# ---------------------------------------------------------------- neutral on the ground
func _set_pose(id: String) -> void:
	if pa != id:
		_set_anim(id)


func _ground_tick(delta: float) -> void:
	var d := _dir()
	vel.y = 0.0
	if not ult.is_empty():
		_ult_next()
		if state != "ground":
			return
	if not charging.is_empty():
		_charge_tick(delta)
		return
	if _decide():
		return
	# neutral pose
	var want := "idle"
	var mc: bool = bool(held["l1"]) and bool(held["r1"]) and _own("meter_charge") and not held["l2"] and not held["r2"]
	if mc:
		want = "charge"
		meter_acc += delta
		while meter_acc >= Tuning.PERRY_METER_CHARGE_S:
			meter_acc -= Tuning.PERRY_METER_CHARGE_S
			if PerryUnlocks.meter_on("energy"):
				stamina = minf(stamina + 1.0, stamina_max)
			if PerryUnlocks.meter_on("empower"):
				empower = minf(empower + 1.0, empower_max)
			if PerryUnlocks.meter_on("super"):
				rage = minf(rage + 1.0, rage_max)
	else:
		meter_acc = 0.0
	if not held["btn_b"]:
		block_hold = false
	if not mc and block_hold and held["btn_b"]:
		want = "block"
	elif not mc and held["r1"] and _own("recover") and now - float(held_since["r1"]) >= 200.0 and hp < hp_max and empower >= Tuning.PERRY_EMPOWER_COST:
		want = "recover"
		heal_acc += delta
		while heal_acc >= Tuning.PERRY_HEAL_EVERY_S and hp < hp_max and empower >= Tuning.PERRY_EMPOWER_COST:
			heal_acc -= Tuning.PERRY_HEAL_EVERY_S
			empower -= Tuning.PERRY_EMPOWER_COST
			heal(Tuning.PERRY_HEAL_AMOUNT)
			Sfx.play("heal", 1.2, -10.0)
	elif not mc and pressed("down"):
		want = "duck"
	elif not mc and d != 0:
		want = "walk_right"
	if want != "recover":
		heal_acc = 0.0
	if d != 0 and want in ["idle", "walk_right", "duck"]:
		_face(d)
	vel.x = d * Tuning.PERRY_WALK if want == "walk_right" else 0.0
	_set_pose(want)
	# heavy chop: still holding A after the slash (or from the start) charges the chop
	if _own("heavy_chop") and _has("heavy") and held["btn_a"] and now - float(held_since["btn_a"]) >= 200.0 and _find("btn_a").is_empty() and stamina >= 1.0 and want in ["idle", "duck", "walk_right"]:
		_begin_charge("heavy", ["btn_a"])


func _face(d: int) -> void:
	if d != 0:
		facing = d


# ---------------------------------------------------------------- deciding what a press does
func _decide() -> bool:
	if _chords():
		return true
	var list: Array = []
	for e in presses:
		if not e["used"] and now - float(e["t"]) <= Tuning.BUFFER_MS:
			list.append(e)
	list.sort_custom(func(p, q): return float(p["t"]) < float(q["t"]))
	for e in list:
		if e["used"]:
			continue
		if _single(e):
			return true
	return false


func _early_chord() -> void:
	if not bool(mv.get("chord_ok", false)) or now - float(mv.get("t0", -1e9)) > Tuning.CHORD_MS + 20.0:
		return
	_chords()


func _chords() -> bool:
	var a := _find("btn_a")
	var x := _find("btn_x")
	var y := _find("btn_y")
	var b := _find("btn_b")
	# Ultimate Chain: A x4, then the four shoulders together
	if _has("ultimate") and _ult_ready():
		for k in SHOULDER_KEYS:
			_use(_find(k))
		ult = ULT_STEPS.duplicate()
		chain = {"n": 0, "t": -1e9}
		return true
	for sh in BEAMS:
		var s := _find(sh)
		var fresh: bool = (not a.is_empty() and _near(sh)) or (not s.is_empty() and _near("btn_a"))
		if not fresh or not _btn_on(sh) or not _has(BEAMS[sh][0]):
			continue
		_use(a)
		_use(s)
		return _start_beam(String(BEAMS[sh][0]), String(BEAMS[sh][1]))
	# energy kick: hold B + L1
	var l1 := _find("l1")
	if _has("energy_kick") and _btn_on("l1") and ((not l1.is_empty() and _near("btn_b")) or (not b.is_empty() and _near("l1"))):
		_use(l1)
		_use(b)
		if stamina >= 1.0:
			_begin_charge("energy_kick", ["btn_b", "l1"])
		else:
			_deny("energy")
		return true
	# dash thrust / energy dash thrust: X + A
	if (not x.is_empty() and _near("btn_a")) or (not a.is_empty() and _near("btn_x")):
		if _has("dash_thrust") or (_has("energy_dash_thrust") and now - ed_armed_t < 700.0):
			_use(x)
			_use(a)
			if _has("energy_dash_thrust") and now - ed_armed_t < 700.0 and stamina >= 1.0:
				ed_armed_t = -1e9
				_begin_charge("energy_dash_thrust", ["btn_x", "btn_a"])
				return true
			if _has("dash_thrust"):
				_start("dash_thrust", {"chord_ok": false})
				return true
	# taunt: X + Y
	if _has("taunt") and ((not x.is_empty() and _near("btn_y")) or (not y.is_empty() and _near("btn_x"))):
		_use(x)
		_use(y)
		_start("taunt")
		return true
	# heavy horizontal: hold B, tap A
	if _has("heavy_horizontal") and ((not a.is_empty() and _near("btn_b")) or (not b.is_empty() and now - _last_t("btn_a") <= Tuning.CHORD_MS)):
		_use(a)
		_use(b)
		_start("heavy_horizontal")
		return true
	return false


func _ult_ready() -> bool:
	for k in SHOULDER_KEYS:
		if not _btn_on(k) or now - _last_t(k) > Tuning.BUFFER_MS:
			return false
	var fresh := false
	var lo := 1e18
	var hi := -1e18
	for k in SHOULDER_KEYS:
		var t := _last_t(k)
		lo = minf(lo, t)
		hi = maxf(hi, t)
		if not _find(k).is_empty():
			fresh = true
	if not fresh or hi - lo > Tuning.PERRY_ULT_MS:
		return false
	var n := 0
	for h in hist:
		if h["a"] == "btn_a" and now - float(h["t"]) < 2500.0:
			n += 1
	return n >= 4


func _single(e: Dictionary) -> bool:
	var a := String(e["a"])
	match a:
		"up":
			_use(e)
			return _jump_press()
		"btn_a":
			_use(e)
			return _a_action()
		"btn_x":
			_use(e)
			_face(_dir())
			return _start("dash", {"chord_ok": true, "src": "btn_x"})
		"btn_b":
			_use(e)
			return _b_action()
		"btn_y":
			_use(e)
			if state == "air":
				return false
			_face(_dir())
			return _start("spin_attack", {"chord_ok": true, "src": "btn_y"})   # Y is the spin attack (Perry Riposte); X + Y becomes the taunt
		"down":
			_use(e)
			return false
		"mana":
			_use(e)
			return _drink_mana_p()
		"l1":
			_use(e)
			if bool(held["r1"]) and _own("meter_charge"):
				return false
			if _has("push_kick") and _btn_on("l1"):
				return _start("push_kick", {"chord_ok": true, "src": "l1"})
			return false                               # items are on the right stick, so L1 is only her kick
		"l2", "r2":
			if now - float(e["t"]) < Tuning.CHORD_MS:
				return false                           # wait out the chord window (a beam chord is A + L2 / R2)
			_use(e)
			var mv_id := "energy_burst" if a == "l2" else "energy_wave"
			if _btn_on(a) and _has(mv_id) and held[a]:
				if stamina >= 1.0:
					_begin_charge(mv_id, [a])
				else:
					_deny("energy")
			return state != "ground"
		"r1":
			if bool(held["l1"]) and _own("meter_charge"):
				_use(e)
				return false
			if held["r1"]:
				if now - float(e["t"]) < 200.0:
					return false
				if _own("recover") and _btn_on("r1"):
					_use(e)                            # held: kneel and heal instead of summoning
					return false
			_use(e)
			return false                               # R1 is recover (hold), the empower beam and meter charge only
	return false


## Perry's items live on the right stick (it has no other job for her), so they never take an attack button:
## flick up = health potion, flick down = mana potion, flick left / right or a stick click (R3) = summon an ally.
## Touch swipes give the same flicks. A tap on an empty screen (Controls reports it as R3) is ignored on touch.
func _items_tick() -> void:
	var n: int = Controls.consume_flick()
	var click: bool = Controls.consume_r3() and Controls.scheme != "touch"
	if state == "dead":
		return
	if n == 7 or n == 8 or n == 9:
		_drink_potion()
	elif n == 1 or n == 2 or n == 3:
		_drink_mana_p()
	elif n == 4 or n == 6 or click:
		_summon_p()


func _summon_p() -> void:
	if game and game.has_method("summon_ally") and game.summon_ally():
		return
	Sfx.play("fail", 1.2, -4.0)
	if game:
		game.flash_hud("ally")


func _drink_mana_p() -> bool:
	if mana_pots > 0 and (stamina < stamina_max - 0.5 or empower < empower_max - 0.5):
		mana_pots -= 1
		add_stamina(Tuning.STAMINA_POTION)
		add_empower(Tuning.STAMINA_POTION)
		Sfx.play("heal", 1.15)
		if game:
			game.on_potions_changed()
			game._sync_carry()
	else:
		Sfx.play("fail")
	return false


func _drink_potion() -> bool:
	if potions > 0 and hp < hp_max:
		potions -= 1
		heal(Tuning.PERRY_POTION_HP)
		Sfx.play("heal")
		if game:
			game.on_potions_changed()
	else:
		Sfx.play("fail")
		if game:
			game.flash_hud("potions" if potions <= 0 else "max")
	return false


func _a_action() -> bool:
	var d := _dir()
	var was := facing
	_face(d)
	if pressed("down") and _has("upswing"):
		return _start("upswing", {"chord_ok": true, "src": "btn_a"})
	# hold the way she is already facing (walking): the lunge
	if d != 0 and d == was and _has("thrust"):
		return _start("thrust", {"chord_ok": true, "src": "btn_a"})
	# 00_core.js: Left+A and Right+A are both the thrust (she turns and lunges the way pressed); without it, A is the plain slash. The spin is Y only.
	if d != 0 and d != was and _has("thrust"):
		return _start("thrust", {"chord_ok": true, "src": "btn_a"})
	if _own("chain"):
		var n := 1
		if now - float(chain["t"]) <= Tuning.PERRY_CHAIN_MS and _last_t("btn_b") <= float(chain["t"]):
			n = int(chain["n"]) + 1
		if n >= 2 and n <= 4:
			chain = {"n": n, "t": now}
			return _start(CHAIN_MOVES[n - 1], {"chord_ok": false})
		if n >= 5:                                     # the 5th press: the chop, uncharged (it still costs energy)
			chain = {"n": 0, "t": -1e9}
			if stamina < 1.0:
				_deny("energy")
				return false
			stamina -= minf(Tuning.PERRY_CHARGE_COST, stamina)
			return _start("heavy", {})
		chain = {"n": 1, "t": now}
	return _start("slash", {"chord_ok": true, "src": "btn_a"})


func _b_action() -> bool:
	if _own("chain_burst") and int(chain["n"]) == 4 and now - float(chain["t"]) <= Tuning.PERRY_CHAIN_MS:
		chain = {"n": 0, "t": -1e9}
		if stamina < 1.0:
			_deny("energy")
			return false
		var pay := minf(Tuning.PERRY_CHARGE_COST, stamina)
		stamina -= pay
		return _start("energy_burst", {"power": 0.5 + 0.5 * pay / Tuning.PERRY_CHARGE_COST})
	parry_t0 = now
	block_hold = true
	return _start("parry", {"chord_ok": true, "src": "btn_b"})


func _super(id: String) -> bool:
	if rage + 0.001 < Tuning.PERRY_SUPER_NEED:
		_deny("super")
		return false
	rage = 0.0
	return _start(id, {})


func _sky_dash() -> bool:
	return _start("sky_dash", {"lift_k": Tuning.PERRY_SKY_LIFT})


func _jump_press() -> bool:
	if _own("sky_dash") and now - down_rel_t <= Tuning.PERRY_SEQ_MS and not held["down"]:
		return _sky_dash()
	if on_ground and state == "ground":
		on_ground = false
		state = "air"
		grav = _jump_g()
		vel.y = -_jump_v()
		dbl_used = false
		_set_anim("jump", 1)
		return true
	return false


func _flight() -> bool:
	if state == "move":
		_cancel_move_state()
	elif state != "ground" and state != "air":
		return false
	charging = {}
	state = "air"
	on_ground = false
	var h := Tuning.PERRY_SKY_H * S
	grav = 2.0 * h / pow(Tuning.PERRY_SKY_APEX_S, 2.0)
	vel.y = -2.0 * h / Tuning.PERRY_SKY_APEX_S
	dbl_used = true
	_set_anim("jump", 3)
	if game:
		game.hud.flash("pickup:Flight")
	return true


# ---------------------------------------------------------------- starting a move
func _start(id: String, opts: Dictionary = {}) -> bool:
	var m := _m(id)
	if state == "move":
		_cancel_move_state()
	state = "move"
	vel.x = 0.0
	charging = {}
	var f0 := int(opts.get("k0", 0))
	var en = m["enter"]
	if en is Dictionary and not opts.has("k0"):
		var fr: Array = m["frames"]
		var want := String((en as Dictionary).get("default", ""))
		if pa == "charge" and (en as Dictionary).has("fromMove"):
			want = "high"
		for i in fr.size():
			if String(fr[i]["name"]) == want:
				f0 = i
				break
	mv = {"key": id, "t0": now, "hits": {}, "hit_t": {}, "power": float(opts.get("power", 1.0)), "chord_ok": bool(opts.get("chord_ok", false)),
		"src": String(opts.get("src", "")), "blast": {}, "dmg": 0}
	var any_hit := false
	for f in m["frames"]:
		if not (f["hits"] as Array).is_empty() or not (f["beam"] as Dictionary).is_empty():
			any_hit = true
	if id in ["earthquake", "meteor_shower"] or any_hit:
		mv["dmg"] = maxi(Tuning.perry_dmg(id.replace("beam_", "")), 1)
	lift_k = float(opts.get("lift_k", 1.0))
	lift = 0.0
	beam_cut = false
	beam_ms = 0.0
	beam_t = 0.0
	if opts.has("air_s"):
		lift_k = float(opts["air_s"])
	_set_anim(String(id), f0)
	root_x = float(_frame()["rx"])
	lift = float(_frame()["ry"]) * S * lift_k
	Sfx.play("swipe", randf_range(0.9, 1.1), -8.0)
	if id == "taunt":
		_taunt()
	if id == "parry":
		parry_t0 = now
	return true


func _cancel_move_state() -> void:
	mv = {}
	lift = 0.0
	beam_cut = false


func _end_move() -> void:
	var key := String(mv.get("key", ""))
	mv = {}
	var was_lift := lift
	lift = 0.0
	lift_k = 1.0
	beam_state = {}
	if was_lift > 4.0 and key == "sky_dash":
		state = "air"
		on_ground = false
		position.y = minf(ground_y - was_lift, ground_y)
		vel = Vector2(0, 0)
		grav = _jump_g()
		_set_anim("jump", 4)
		return
	state = "ground"
	pa = ""
	if key == "parry":
		block_hold = bool(held["btn_b"])


func _begin_charge(id: String, keys: Array) -> void:
	if state == "move":                                  # a chord converted a move that had just started
		_cancel_move_state()
		state = "ground"
	vel.x = 0.0
	block_hold = false
	charging = {"move": id, "keys": keys, "ms": 0.0}
	pa = ""
	_set_anim("charge")
	if game:
		Sfx.play("charge", 1.0, -10.0)


func _charge_tick(delta: float) -> void:
	vel.x = 0.0
	var ms := float(charging["ms"])
	if ms < Tuning.PERRY_CHARGE_FULL_MS:
		var want := delta * Tuning.PERRY_CHARGE_COST / (Tuning.PERRY_CHARGE_FULL_MS / 1000.0)
		var pay := minf(want, stamina)
		if pay > 0.0:
			stamina -= pay
			ms = minf(Tuning.PERRY_CHARGE_FULL_MS, ms + delta * 1000.0 * pay / want)
			charging["ms"] = ms
	var released := false
	for k in charging["keys"]:
		if not held[k]:
			released = true
	if released:
		var id := String(charging["move"])
		charging = {}
		if ms >= Tuning.PERRY_MIN_FIRE_MS:
			_start(id, {"power": 0.5 + 0.5 * minf(1.0, ms / Tuning.PERRY_CHARGE_FULL_MS), "full": ms >= Tuning.PERRY_CHARGE_FULL_MS})
		else:
			pa = ""
		return
	_set_pose("charge")


func _start_beam(move: String, kind: String) -> bool:
	var cost: float = Tuning.PERRY_BEAM_COST[kind]
	var have := empower if kind == "plasma" else stamina
	if have + 0.001 < cost:
		_deny("empower" if kind == "plasma" else "energy")
		return false
	return _start(move, {"chord_ok": false, "src": "beam"})


func _ult_next() -> void:
	while not ult.is_empty():
		var id := String(ult.pop_front())
		if id == "taunt":
			_start("taunt")
			return
		var kind := id.replace("beam_", "")
		var cost: float = Tuning.PERRY_BEAM_COST[kind]
		var have := empower if kind == "plasma" else stamina
		if have >= cost:
			_start(id)
			return


func _taunt() -> void:
	if game == null:
		return
	for e in game.enemies():
		if e.get("boss") == true:
			continue
		if e.has_meta("taunted"):
			continue
		e.set_meta("taunted", true)
		e.modulate = Color(1.3, 0.7, 0.7)
		if e.get("speed_mul") != null:                       # 03_state.js: a taunted enemy rushes her (speedMul 2) and hits twice as hard (dmgMul 2, see take_hit)
			e.speed_mul *= Tuning.PERRY_TAUNT_MUL
			e.speed *= Tuning.PERRY_TAUNT_MUL


# ---------------------------------------------------------------- air
func _air_tick(delta: float) -> void:
	var d := _dir()
	var sp := Tuning.PERRY_AIR_SPEED_DBL if dbl_used else Tuning.PERRY_AIR_SPEED
	vel.x = d * sp
	if d != 0:
		_face(d)
	_gravity_p(delta)
	# frame from the vertical speed (03_state.js stepJump): takeoff, rise, apex, fall
	if pa != "jump":
		_set_anim("jump", 3)
	var up := -vel.y
	var v0 := _jump_v()
	pk = 1 if up > 0.6 * v0 else (2 if up > 0.2 * v0 else (3 if up > -0.2 * v0 else 4))
	pt = 0.0
	for e in presses:
		if e["used"] or now - float(e["t"]) > Tuning.BUFFER_MS:
			continue
		var a := String(e["a"])
		if a == "up" and not dbl_used:
			var room := Tuning.PERRY_DBL_H * S - air_height()
			if room > 8.0:
				_use(e)
				dbl_used = true
				spin_t = now
				vel.y = -sqrt(2.0 * _jump_g() * room)
				grav = _jump_g()
				Sfx.play("swipe", 1.4, -8.0)
				continue
			_use(e)
		elif a == "btn_a" and _has("jump_crash") and air_height() >= Tuning.PERRY_CRASH_MIN * S:
			_use(e)
			if _spend_energy(Tuning.PERRY_CRASH_COST):
				_air_crash()
				return
		elif a == "btn_a" and not _has("jump_crash"):
			_use(e)


func _air_crash() -> void:
	var h := air_height()
	var m := _m("jump_crash")
	var k0 := 0
	for i in m["frames"].size():
		if String(m["frames"][i]["name"]) == "apex":
			k0 = i
	var apex_y := float(m["frames"][k0]["ry"]) * S
	position.y = ground_y
	on_ground = true
	vel = Vector2.ZERO
	state = "ground"
	_start("jump_crash", {"power": 1.0, "air_s": h / maxf(apex_y, 1.0), "k0": k0})
	mv["crash_h"] = h


# ---------------------------------------------------------------- moves in progress
func _move_tick(delta: float) -> void:
	var key := String(mv.get("key", ""))
	vel.x = 0.0
	if not on_ground and lift <= 0.0:
		_gravity_p(delta)
	if key in ["beam_cloud", "beam_fire", "beam_laser", "beam_plasma"]:
		_beam_tick(delta, key)
	# a chain strike cancels the recovery of the one before it
	if key in CHAIN_MOVES and _own("chain") and pk > int(_m(pa)["last_hit"]) and not _find("btn_a").is_empty():
		_use(_find("btn_a"))
		var n := int(chain["n"])
		if now - float(chain["t"]) <= Tuning.PERRY_CHAIN_MS and n >= 1 and n <= 3:
			chain = {"n": n + 1, "t": now}
			_start(CHAIN_MOVES[n], {})
		elif n == 4:
			chain = {"n": 0, "t": -1e9}
			if stamina >= 1.0:
				stamina -= minf(Tuning.PERRY_CHARGE_COST, stamina)
				_start("heavy", {})


func _beam_tick(delta: float, key: String) -> void:
	var f := _frame()
	var b: Dictionary = f["beam"]
	if b.is_empty() or beam_cut:
		beam_ms = 0.0
		return
	beam_ms += delta * 1000.0
	var kind := String(b["kind"])
	beam_t -= delta
	if beam_t > 0.0:
		return
	beam_t = Tuning.PERRY_BEAM_TICK_S
	var cost: float = Tuning.PERRY_BEAM_COST[kind]
	var have := empower if kind == "plasma" else stamina
	if have + 0.001 < cost:                           # the meter ran dry: the beam stops and she recovers
		beam_cut = true
		_deny("empower" if kind == "plasma" else "energy")
		var fr: Array = _m(pa)["frames"]
		var j := pk
		while j < fr.size() and not (fr[j]["beam"] as Dictionary).is_empty():
			j += 1
		pk = mini(j, fr.size() - 1)
		pt = 0.0
		return
	if kind == "plasma":
		empower -= cost
	else:
		stamina -= cost
	if beam_state.is_empty() or game == null:
		return
	var box: Rect2 = beam_state["box"]
	var dmg := Tuning.perry_dmg(kind)
	for e in game.targets():
		if not e.alive() or not box.intersects(e.hurt_rect()):
			continue
		if e.get("is_prop"):
			e.take_damage(maxi(dmg, 1), position.x, "beam")
			continue
		if kind == "plasma":
			if e.get("boss") == true:
				continue
			if not e.has_meta("plasma"):                 # an energy gem drops from it (once)
				e.set_meta("plasma", true)
				add_stamina(10.0)
				e.modulate = Color(0.8, 0.5, 1.2)
		if dmg > 0:
			_strike(e, dmg, position.x, "beam")
		var push: float = Tuning.PERRY_BEAM_PUSH[kind]
		if push > 0.0 and e.alive() and e.has_method("shove"):
			e.shove(facing * push * S)
	# the cloud beam keeps firing while A is held
	if key == "beam_cloud" and held["btn_a"] and stamina >= cost and _last_beam_frame():
		var fr2: Array = _m(pa)["frames"]
		for i in fr2.size():
			if not (fr2[i]["beam"] as Dictionary).is_empty():
				pk = i
				break
		pt = 0.0


func _perry_hits(delta: float) -> void:
	if game == null:
		return
	var key := String(mv.get("key", ""))
	var f := _frame()
	var fname := String(f["name"])
	# the supers hit every enemy on screen: the earthquake the grounded ones, the meteors all of them
	if key == "earthquake" and fname in ["slam", "quake1", "quake2"] or key == "meteor_shower" and fname.begins_with("rain"):
		for e in game.enemies():
			if absf(e.global_position.x - game.camera_x()) > 1000.0:
				continue
			if key == "earthquake" and (e.get("flyer") == true or not e.get("on_ground")):
				continue
			var last: float = float((mv["hit_t"] as Dictionary).get(e.get_instance_id(), -1e9))
			if now - last >= float(Tuning.PERRY_REHIT_MS[key]):
				(mv["hit_t"] as Dictionary)[e.get_instance_id()] = now
				_strike(e, Tuning.perry_dmg(key), position.x, "quake" if key == "earthquake" else "lightning")
	var rects := hit_rects()
	if rects.is_empty():
		mv["hitwin"] = false
		return
	var dmg := Tuning.perry_dmg(key)
	var done: Dictionary = mv["hits"]
	for e in game.targets():
		if done.has(e.get_instance_id()):
			continue
		if not e.alive():
			continue
		var er: Rect2 = e.hurt_rect()
		var hit_side := -1
		for i in rects.size():
			if key == "energy_wave" and bool((mv["blast"] as Dictionary).get(i % 2 if rects.size() > 1 else 0, false)):
				continue                                   # that projectile has burst
			if (rects[i] as Rect2).intersects(er):
				hit_side = i
				break
		if hit_side < 0:
			continue
		done[e.get_instance_id()] = true
		if key == "energy_wave":
			var side := 0 if hit_side == 0 or rects.size() == 1 else (hit_side % 2)
			_wave_blast(side, er.get_center())
			continue
		_hit_target(e, key, dmg)
	if key == "heavy" and fname == "impact" and not mv.has("aoe"):
		mv["aoe"] = true
		game.heavy_slam()                                      # every chop: the impact frame, then a camera rumble and an earthquake
		var blade: Vector2 = (rects[0] as Rect2).get_center()
		var dmg_aoe := Tuning.perry_dmg("heavy")
		for e in game.enemies():                               # big area damage to every enemy near where the blade lands
			if not e.alive() or done.has(e.get_instance_id()):
				continue
			if e.hurt_rect().get_center().distance_to(blade) <= Tuning.PERRY_HEAVY_AOE_R:
				done[e.get_instance_id()] = true
				_strike(e, dmg_aoe, position.x, "melee")
	if key == "jump_crash" and fname == "crash" and not mv.has("aoe"):
		mv["aoe"] = true
		game.heavy_slam()                                      # the same always-on impact as the chop: black and white frame, rumble, quake
		var land: Vector2 = (rects[0] as Rect2).get_center()
		var dmg_shock := Tuning.perry_dmg("jump_crash")
		for e in game.enemies():                               # the ground shock: the crash damage to every enemy near where she lands
			if not e.alive() or done.has(e.get_instance_id()):
				continue
			if e.hurt_rect().get_center().distance_to(land) <= Tuning.PERRY_CRASH_SHOCK_R:
				done[e.get_instance_id()] = true
				_strike(e, dmg_shock, position.x, "melee")


func _hit_target(e: Node, key: String, dmg: int) -> void:
	var pw := 1.0 if key == "heavy" else float(mv.get("power", 1.0))       # the original chop's damage is flat: the charge no longer scales it
	var amount := maxi(int(round(float(dmg) * pw)), 1 if dmg > 0 else 0)
	if amount <= 0:
		return
	hit_count += 1
	var kind := "melee"
	if key == "energy_burst":
		kind = "explosion"
	if not _strike(e, amount, position.x, kind):
		return
	if not is_instance_valid(e) or e.get("is_prop"):
		return
	var kn: float = Tuning.PERRY_KNOCK.get(key, 0.0)
	if kn > 0.0 and e.alive() and e.has_method("shove"):
		var away := 1.0 if e.global_position.x >= position.x else -1.0
		e.shove((away if key == "energy_burst" else float(facing)) * kn * S)
		if e.has_method("stun") and key != "slash":
			e.stun(float(Tuning.PERRY_STUN_S.get(key, Tuning.PERRY_STUN_DEFAULT_S)))


## damage one target with the same enemy interface Mera uses: take_damage(amount, from_x, kind)
func _strike(e: Node, amount: int, from_x: float, kind: String = "melee") -> bool:
	var countered := counter_active() and kind != "beam"
	if countered:
		amount *= Tuning.PARRY_COUNTER_MULT
	if e.get("is_prop"):
		if e.take_damage(amount, from_x, kind):
			HitStop.stop(Tuning.HITSTOP_LIGHT_MS * 0.6)
			if game:
				game.hit_spark(e.hurt_rect().get_center(), S * 0.7)
		return true
	var was: bool = e.alive()
	if not e.take_damage(amount, from_x, kind):
		if game:
			game.hit_spark(e.hurt_rect().get_center(), S * 0.6)
		HitStop.stop(Tuning.HITSTOP_LIGHT_MS * 0.5)
		Sfx.play("clang", 1.1, -6.0)
		return false
	add_rage(1.0)
	Sfx.play("hit" if amount < 6 else "hit_heavy", randf_range(0.95, 1.05))
	if game:
		game.hit_spark(e.hurt_rect().get_center(), S)
	if was and not e.alive() and e.has_meta("taunted"):
		add_empower(12.0)
	var ms := Tuning.HITSTOP_LIGHT_MS
	if not e.alive():
		ms = Tuning.HITSTOP_KILL_MS
	elif kind == "beam":
		ms = 0.0
	elif amount >= 6 or countered:
		ms = Tuning.HITSTOP_HEAVY_MS
	HitStop.stop(ms)
	return true


## the energy wave bursts where it touches an enemy (or at the end of its flight): every enemy within the radius is hurt
func _wave_blast(side: int, p: Vector2) -> void:
	var blast: Dictionary = mv["blast"]
	if blast.get(side, false):
		return
	blast[side] = true
	if game == null:
		return
	game.hit_spark(p, 4.0)
	game.shake(5.0, 0.35)
	Sfx.play("boom", 1.0)
	var r := Tuning.PERRY_WAVE_R * S
	var amount := maxi(int(round(float(Tuning.perry_dmg("wave_blast")) * float(mv.get("power", 1.0)))), 1)
	for e in game.targets():
		if not e.alive():
			continue
		var er: Rect2 = e.hurt_rect()
		var cx := clampf(p.x, er.position.x, er.end.x)
		var cy := clampf(p.y, er.position.y, er.end.y)
		if Vector2(cx, cy).distance_to(p) <= r:
			_strike(e, amount, p.x, "explosion")


# ---------------------------------------------------------------- being hit
func _parry_open() -> bool:
	return now - parry_t0 <= Tuning.PERRY_PARRY_MS


func blocking() -> bool:
	return state == "ground" and pa == "block" and bool(held["btn_b"])


func try_parry_shot(shot: Node) -> bool:
	if not _parry_open() or state == "dead":
		return false
	deflects += 1
	_parry(null, shot.global_position.x)
	return true


func _parry(src: Node, from_x: float) -> void:
	parries += 1
	invuln = maxf(invuln, Tuning.PARRY_IFRAMES_S)
	counter_until = now + Tuning.PARRY_COUNTER_S * 1000.0
	parry_t0 = -1e9
	Sfx.play("parry")
	Sfx.play("clang", 1.2, -2.0)
	HitStop.stop(Tuning.HITSTOP_PARRY_MS)
	_face(1 if from_x > global_position.x else -1)
	if src != null and is_instance_valid(src):
		if src.has_method("parried"):
			src.parried(Tuning.PERRY_PARRY_STUN_S)
		if src.has_method("take_damage") and src.get("boss") != true:
			src.take_damage(maxi(1, roundi(float(Tuning.PERRY_PARRY_DMG) * Tuning.PERRY_DMG_SCALE)), global_position.x, "melee")
		if src.get("boss") != true and src.has_method("shove") and is_instance_valid(src):
			var away := 1.0 if src.global_position.x >= global_position.x else -1.0
			src.shove(away * Tuning.PERRY_PARRY_KNOCK_PX)
	if game:
		game.parry_fx(Vector2(global_position.x + facing * 30.0 * S, global_position.y - 40.0 * S), S)


func take_hit(dmg: int, from_x: float, src: Node = null) -> void:
	if state == "dead" or invuln > 0.0 or rainbow_t > 0.0:
		return
	if _parry_open():                                 # a tap of B just before the blow: no damage, the attacker is stunned
		_parry(src, from_x)
		return
	if dodging():
		return
	if blocking():                                    # a blocked hit does no damage but slides her back
		blocks += 1
		Sfx.play("block")
		HitStop.stop(40.0)
		var back := 1.0 if global_position.x > from_x else -1.0
		position.x += back * Tuning.PERRY_BLOCK_SLIDE_PX
		if game:
			game.shake(3.0, 0.08)
			game.hit_spark(Vector2(global_position.x + facing * 30.0 * S, global_position.y - 40.0 * S), S * 0.6)
		return
	if src != null and is_instance_valid(src) and src.has_meta("taunted"):
		dmg = roundi(float(dmg) * Tuning.PERRY_TAUNT_MUL)
	hp -= dmg * Tuning.PERRY_HP_PER_DMG
	if hp <= 0:
		hp = 0
		_die(from_x)
		return
	_interrupt_p()
	state = "hurt"
	hurt_t = 0.45
	var away := 1.0 if global_position.x > from_x else -1.0
	vel = Vector2(away * 420.0, -260.0)
	on_ground = false
	grav = _jump_g()
	_face(-int(away))
	pa = ""
	_set_hurt_pose()
	invuln = Tuning.PERRY_IFRAMES_S
	Sfx.play("hurt")
	if game:
		game.shake(6.0, 0.15)


func _interrupt_p() -> void:
	mv = {}
	charging = {}
	ult = []
	lift = 0.0
	lift_k = 1.0
	beam_cut = false
	beam_state = {}
	block_hold = false
	chain = {"n": 0, "t": -1e9}


func _set_hurt_pose() -> void:
	var m := _m("heavy")
	var k := 0
	for i in m["frames"].size():
		if String(m["frames"][i]["name"]) == "high":
			k = i
	_set_anim("heavy", k)


func _hurt_tick(delta: float) -> void:
	hurt_t -= delta
	vel.x = move_toward(vel.x, 0.0, 900.0 * delta)
	_gravity_p(delta)
	if hurt_t <= 0.0 and on_ground:
		state = "ground"
		pa = ""
		vel = Vector2.ZERO


func _die(from_x: float) -> void:
	_interrupt_p()
	state = "dead"
	var away := 1.0 if global_position.x > from_x else -1.0
	_face(-int(away))
	vel = Vector2(away * 300.0, -200.0)
	on_ground = false
	grav = _jump_g()
	_set_hurt_pose()
	Sfx.play("boom_big", 0.6)
	died.emit()


## The respawn minigame won: back where she fell, with a third of her HP (at least 15) and a short invulnerability.
func revive_here(x: float, gy: float) -> void:
	_interrupt_p()
	state = "ground"
	position.x = x
	ground_y = gy
	position.y = gy
	on_ground = true
	vel = Vector2.ZERO
	hp = clampi(maxi(15, int(float(hp_max) / 3.0)), 1, hp_max)
	invuln = 1.8
	hurt_t = 0.0
	pa = ""


# ---------------------------------------------------------------- deal() for Mera's callers (shots, reflected projectiles)
func deal(e: Node, base: int, from_x: float, kind: String = "melee") -> void:
	_strike(e, base * 3, from_x, kind)
