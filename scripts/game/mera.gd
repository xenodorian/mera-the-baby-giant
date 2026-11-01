class_name Mera
extends Node2D
## Mera, player controller for the playable level (docs/CONTROLS.md, docs/GAME_RULES.md).
## Size is HP: she starts at 2x, every hit costs sizes equal to its damage, a hit at 1x is fatal.
## Damage dealt = move base damage x size. Speeds are px/s at 1x and scale with size.
## All animation comes from AnimLib (pack animations + the canon casts, baked by tools/export_game_anims.py).

signal size_changed(size: int)
signal died
signal move_started(key: String)

const WALK := 50.0          # v0.3: 50 px/s at 1x
const RUN := 200.0
const DASH := 400.0         # slide, dodge attack lunge
const DASH_FAST := 1600.0   # v0.3 ground/aerial dash: 2x the distance in half the time (4x the old 400 px/s)
const DODGE := 800.0        # v0.3 back dodge: same distance as before in half the time
const FAST_ANIMS := {"gdash": 2.0, "adash": 2.0, "bdodge": 2.0, "heal": 4.0, "datk2": Tuning.RSLASH_WINDUP_SPEED}   # heal: the drink plays at 4x; datk2: windup only
const FLY := 320.0
const GRAVITY := 1500.0
const JUMP_V := 520.0
const SIZE_MIN := 1
const SIZE_HEAL_MAX := 6
const SIZE_DEBUG_MAX := 19
const CHORD_MS := Tuning.CHORD_MS      # v0.4: input windows live in scripts/game/tuning.gd (docs/CONTROLS.md)
const HOLD_MS := Tuning.HOLD_MS
const BUFFER_MS := Tuning.BUFFER_MS
const IFRAMES := 1.2
const R1_COST := 100.0      # the lightning strike needs a full meter and spends all of it
const DODGE_KEYS := ["bdodge", "gdash", "adash"]
const FURY_TIME := 12.0
const FURY_COST := 100.0     # a bigger rage meter still pays only this much
const TRACK := ["btn_x", "btn_y", "btn_a", "btn_b", "up", "down", "l1", "r1", "l2", "r2"]
# base damage per move (x size); beam ticks every BEAM_TICK frames while it is lit
const DMG := {"atk1": 1, "atk2": 1, "atk2_1": 2, "atk2_2": 2, "atk3": 2, "beam_ender": 1, "datk1": 1, "datk2": 1,
	"datk3": 2, "jatk1": 1, "jatk2": 2, "slide": 1, "rear_blast": 1}
const BEAM_TICK := 5

var game: Node = null
var size := 2                 # HP
var shown := 2.0              # displayed size, steps toward size
var facing := 1               # 1 = right, -1 = left (screen)
var vel := Vector2.ZERO
var on_ground := true
var state := "ground"         # ground | air | move | fly | hurt | dead | gallery
var mv := {}                  # current committed move
var now := 0.0                # ms, advanced by physics ticks (deterministic for tests)
var presses: Array = []       # {a, t, used}
var held := {}
var held_since := {}
var _pending := {}
var invuln := 0.0
var potions := 1
var rage := 0.0
var super_quakes := 0         # v0.8 (tests)
var rage_spending := false     # R1 drained the meter; it empties visibly first
var fury := false
var fury_left := 0.0
var flying := false
var air_jumps := 1
var air_dashes := 1
var barrier_on := false
var jump_t0 := -1e9            # v0.9.1 Up+Y: when the last ground jump started, from where, and its Up press time
var jump_y0 := 0.0
var jump_up_t := -1e9
var move_keys: Array = []      # v0.9.1 every move key started (move_log has animation keys) (tests)
var ychain_log: Array = []     # v0.9.1 Y chain: [move key, frame the shot / effect came out] (tests)
var stamina := Tuning.STAMINA_START
var stamina_max := Tuning.STAMINA_START
var rage_max := Tuning.RAGE_MAX_START
var combo_after := {}          # a combo hit that just recovered to neutral: {from, until, x3_t} (COMBO_GRACE_MS)
var debug := false
var gallery_idx := 0
var move_log: Array = []      # keys of every move/animation started (tests)
var forced := {}              # scripted input for demos/tests: action -> bool
var ground_y := 1060.0
var size_step_t := 0.0
var anim: LayeredAnim
var hurtbox: Area2D
var hitbox: Area2D
var aura_mat: ShaderMaterial
var aura_fx: CPUParticles2D
var flame_back: CPUParticles2D     # v0.4 Fury aura: world-space flame tongues behind her ...
var flame_front: CPUParticles2D    # ... and an additive layer over her (both trail behind when she moves)
var aura_quality := 2              # caps the particle counts: see AURA_AMOUNTS
const AURA_AMOUNTS := [[0, 0, 20], [90, 0, 30], [160, 70, 60]]   # [back flames, front flames, embers] per quality
var barrier: Sprite2D
# v0.8 (S4) parry: L2 pressed at most Tuning.PARRY_MS before a hit lands -> no damage, the attacker staggers,
# projectiles fly back, and Mera's hits do double damage for a moment (the counter window)
var last_l2_t := -1e9          # Mera.now of the latest L2 press
var crouch_t := -1e9           # Mera.now when this crouch started (the small bubble's parry window)
var crouch_bubble_left := 0.0 # seconds left on the small bubble (0 = dropped, even if still crouched)
var bubble_dial: Node2D
var cast_orb: Sprite2D
var counter_until := -1e9      # Mera.now until which her hits count as counters
var parries := 0               # tests / stats
var deflects := 0
var swing_parries := 0         # v0.9.1: projectiles reflected by a timed basic attack (tests)
var _neutral := ""
var _hover_t := 0.0
var _bob := 0.0
var tilt_target := 0.0             # flight tilt (rad, clockwise from upright), eased in _tilt_tick
const TILT_PIVOT := Vector2(0, -27)   # native px: she rotates around her body centre, not her feet
var beam_strip: SegStrip           # tessellating beam segments (child of anim, so it flips and scales with her)
var beam_len := 0.0                # native px from the beam origin to its far end this frame (0 = no beam)
var beam_end_x := 0.0              # world x of the beam's far end, for tests
const BEAM_MARGIN := 160.0         # screen px the beam runs past the viewport edge


func _ready() -> void:
	anim = LayeredAnim.new()
	add_child(anim)
	beam_strip = SegStrip.new()
	anim.add_child(beam_strip)
	aura_mat = ShaderMaterial.new()
	aura_mat.shader = load("res://shaders/mera_aura.gdshader")
	anim.body.material = aura_mat
	anim.finished.connect(_on_finished)
	anim.frame_changed.connect(_on_frame)
	cast_orb = _bolt_orb()
	cast_orb.visible = false
	cast_orb.z_index = 4
	anim.add_child(cast_orb)
	hurtbox = _box("Hurtbox", Color(0.2, 0.8, 1.0, 0.35))
	hitbox = _box("Hitbox", Color(1.0, 0.2, 0.2, 0.4))
	barrier = Sprite2D.new()
	barrier.texture = AnimLib.spell_tex("barrier")
	barrier.hframes = int(AnimLib.spell_cell("barrier")[2])
	barrier.material = AnimLib.fx_mat
	barrier.visible = false
	add_child(barrier)
	bubble_dial = Node2D.new()
	bubble_dial.set_script(load("res://scripts/game/bubble_dial.gd"))
	bubble_dial.z_index = 3
	bubble_dial.visible = false
	add_child(bubble_dial)
	# v0.4 Fury aura = world-space particles: flame tongues rise around her while she stands still and stream back
	# into a trail when she moves or flies (local_coords off). Back layer behind her body, additive front layer over it.
	flame_back = _make_flame(false)
	add_child(flame_back)
	move_child(flame_back, 0)
	flame_front = _make_flame(true)
	add_child(flame_front)
	aura_fx = CPUParticles2D.new()
	aura_fx.local_coords = false
	aura_fx.emitting = false
	aura_fx.amount = 90
	aura_fx.lifetime = 0.55
	aura_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	aura_fx.direction = Vector2(0, -1)
	aura_fx.spread = 12.0
	aura_fx.gravity = Vector2(0, -260)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.62, 0.28, 1.0))
	grad.set_color(1, Color(0.45, 0.0, 0.06, 0.0))
	grad.add_point(0.35, Color(1.0, 0.22, 0.12, 0.95))
	aura_fx.color_ramp = grad
	var amat := CanvasItemMaterial.new()
	amat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	aura_fx.material = amat
	add_child(aura_fx)
	for a in TRACK:
		held[a] = false
		held_since[a] = 0.0
	_play("idle")
	_apply_size()


func _box(n: String, c: Color) -> Area2D:
	var a := Area2D.new()
	a.name = n
	a.monitoring = false
	a.monitorable = false
	var s := CollisionShape2D.new()
	s.shape = RectangleShape2D.new()
	s.debug_color = c
	a.add_child(s)
	add_child(a)
	return a


# ---------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	for a in TRACK:
		if event.is_action_pressed(a) and not event.is_echo():
			_pending[a] = true


func pressed(a: String) -> bool:
	if forced.has(a):
		return forced[a]
	return Input.is_action_pressed(a)


func _poll_input() -> void:
	for a in TRACK:
		var p := pressed(a)
		if (p and not held[a]) or _pending.get(a, false):
			presses.append({"a": a, "t": now, "used": false})
			held_since[a] = now
			if a == "l2":
				last_l2_t = now
		var was: bool = held[a]
		held[a] = p or (_pending.get(a, false) and held[a])
		if p:
			held[a] = true
		if was and not held[a]:
			for k in range(presses.size() - 1, -1, -1):      # remember how long each press was held
				if presses[k]["a"] == a:
					if not presses[k].has("rel"):
						presses[k]["rel"] = now
					break
	_pending.clear()
	var keep: Array = []
	for e in presses:
		if not e["used"] and now - float(e["t"]) <= Tuning.KEEP_MS:
			keep.append(e)
	presses = keep


## first unused press of `a` made at or after `since` (default: within BUFFER_MS, for neutral actions). Chains pass
## their move's start time instead, so a press made any time during the move is kept until the chain point.
func _find(a: String, since: float = -1e9) -> Dictionary:
	if since <= -1e8:
		since = now - BUFFER_MS
	for e in presses:
		if e["a"] == a and not e["used"] and float(e["t"]) >= since:
			return e
	return {}


func _use(e: Dictionary) -> void:
	if not e.is_empty():
		e["used"] = true


func _dir() -> int:
	return int(pressed("right")) - int(pressed("left"))


func _dir2() -> Vector2:
	return Vector2(_dir(), int(pressed("down")) - int(pressed("up")))


# ---------------------------------------------------------------- size / hp
func s() -> float:
	return shown


func set_size(n: int, instant: bool = false) -> void:
	size = clampi(n, SIZE_MIN, SIZE_DEBUG_MAX)
	if instant:
		shown = size
		_apply_size()
	size_changed.emit(size)


func _apply_size() -> void:
	anim.scale = Vector2(shown * -facing, shown)
	if crouch_bubble_on():
		_place_crouch_bubble()
	else:
		_place_barrier()
	aura_fx.emission_rect_extents = Vector2(22, 24) * shown
	aura_fx.position = Vector2(0, -24 * shown)
	aura_fx.scale_amount_min = shown
	aura_fx.scale_amount_max = shown * 2.0
	aura_fx.initial_velocity_min = 60.0 * shown
	aura_fx.initial_velocity_max = 140.0 * shown
	aura_fx.gravity = Vector2(0, -260.0 * shown)
	_update_boxes()


func _step_size(delta: float) -> void:
	if int(shown) == size:
		return
	size_step_t += delta
	if size_step_t >= 0.07:      # one size per 70 ms: the change animates through every integer step
		size_step_t = 0.0
		shown += 1 if size > shown else -1
		_apply_size()


# ---------------------------------------------------------------- animation helpers
func _play(k: String, start: int = 0) -> void:
	anim.play(k, start)
	move_log.append(k)
	move_started.emit(k)


func _face(d: int) -> void:
	if d != 0 and d != facing:
		facing = d
		_apply_size()


func _cur() -> Dictionary:
	return anim.cur()


func body_rect() -> Rect2:
	var r := LayeredAnim.box_to_rect(_cur()["body"], facing, shown)
	return Rect2(r.position + global_position, r.size)


func _update_boxes() -> void:
	if anim == null or anim.frames.is_empty():
		return
	var f: Dictionary = _cur()
	var hs := hurtbox.get_child(0) as CollisionShape2D
	var r := LayeredAnim.box_to_rect(f["body"], facing, shown)
	if anim.rotation != 0.0:                 # tilted in flight: hurtbox = bounds of the rotated body box
		r = _rot_rect(r)
	(hs.shape as RectangleShape2D).size = r.size
	hs.position = r.get_center()
	var hb := hitbox.get_child(0) as CollisionShape2D
	var attacking: bool = state == "move" and mv.get("dmg", 0) > 0 and f["hit"] != null
	hb.disabled = not attacking
	if attacking:
		var hbox: Array = f["hit"]
		if f.has("beam") and beam_len > 0.0:     # the beam's hitbox covers its full tessellated length
			var bx := float(f["bo"][0])
			hbox = [minf(float(hbox[0]), bx - beam_len), minf(float(hbox[1]), float(f["beam"][1])), maxf(float(hbox[2]), bx), maxf(float(hbox[3]), float(f["beam"][3]))]
		var h := LayeredAnim.box_to_rect(hbox, facing, shown)
		(hb.shape as RectangleShape2D).size = h.size
		hb.position = h.get_center()


## Beam frames carry "bo" (origin just past the wand tip) and "bk" (index within the phase). The baked frame keeps the
## first `cap` px of the canon beam (start cap); tessellating segments run from there to BEAM_MARGIN past the
## viewport edge, recomputed every frame from the camera, so the beam is off-screen at any size and position.
func _update_beam() -> void:
	var f: Dictionary = _cur() if anim != null and not anim.frames.is_empty() else {}
	if not f.has("bo"):
		if beam_len != 0.0 or beam_strip.n > 0:
			beam_strip.clear()
		beam_len = 0.0
		return
	var info: Dictionary = AnimLib.spells["beam"]
	var rows: Dictionary = info["rows"]
	var tw := float(info["tw"])
	var th := float(info["th"])
	var cy := float(info["cy"])
	var cap := float(info["cap"])
	var bo := Vector2(f["bo"][0], f["bo"][1])
	var bk := int(f["bk"])
	var ph := String(f["phase"])
	var tex := AnimLib.spell_tex("beam")
	var ltex := AnimLib.spell_tex_field("beam", "light")
	# native px from the origin to past the viewport edge, in the facing direction
	var ox := art_to_world(bo).x
	var edge: float = ox + facing * (1920.0 + BEAM_MARGIN)
	if game != null:
		edge = float(game.camera_x()) + facing * (960.0 + BEAM_MARGIN)
	var total := maxf((edge - ox) * facing / shown, cap)
	var lf := int(now / float(info["ms"])) % int(rows["sustain"][2])
	var row := "sustain"
	var fi := lf
	var reach := total
	var end_row := "impact"
	match ph:
		"fire":
			reach = maxf(total * [0.3, 0.62, 0.88][clampi(bk, 0, 2)], cap)
			end_row = "front"
		"fade":
			row = "fade"
			fi = clampi(bk, 0, int(rows["fade"][2]) - 1)
			if bk > 2:
				end_row = ""
		"recover":
			row = "linger"
			fi = clampi(bk, 0, int(rows["linger"][2]) - 1)
			end_row = ""
	var mid := maxf(reach - cap, 0.0)
	beam_strip.begin()
	var x := bo.x - cap                 # segments run toward -x in art space (the art faces left)
	var i := 0
	var left := mid
	while left > 0.0:
		var w := minf(tw, left)
		var v := (i * 7 + 1) % int(rows[row][1])
		var r0 := Rect2(fi * tw + tw - w, (int(rows[row][0]) + v) * th, w, th)
		var p := Vector2(x - w, bo.y - cy)
		if not beam_strip.put(tex, r0, p, AnimLib.fx_mat, 1):
			break
		if row != "linger":
			beam_strip.put(ltex, r0, p, AnimLib.light_mat, 0)
		x -= w
		left -= w
		i += 1
	if end_row != "":
		var rr := Rect2(lf * tw, int(rows[end_row][0]) * th, tw, th)
		beam_strip.put(tex, rr, Vector2(x - tw / 2.0, bo.y - cy), AnimLib.fx_mat, 1)
		beam_strip.put(ltex, rr, Vector2(x - tw / 2.0, bo.y - cy), AnimLib.light_mat, 0)
	beam_strip.end()
	beam_len = bo.x - x
	beam_end_x = art_to_world(Vector2(x, bo.y)).x


## world rect of the live beam (v0.9.1: it destroys enemy projectiles). Empty when no beam is out.
func beam_world_rect() -> Rect2:
	if beam_len <= 0.0 or anim == null or anim.frames.is_empty():
		return Rect2()
	var f: Dictionary = _cur()
	if not f.has("bo"):
		return Rect2()
	var origin := art_to_world(Vector2(float(f["bo"][0]), float(f["bo"][1])))
	var half_h := 28.0 * shown
	var x0 := minf(origin.x, beam_end_x)
	return Rect2(x0, origin.y - half_h, absf(beam_end_x - origin.x), half_h * 2.0)


## v0.9.1: atk1 / jatk1, within SWING_PARRY_MS of the hitbox going live
func swing_parry_open() -> bool:
	if state != "move":
		return false
	var k := String(mv.get("key", ""))
	if k not in ["atk1", "jatk1"]:
		return false
	if not mv.has("swing_t"):
		return false
	return now - float(mv["swing_t"]) <= Tuning.SWING_PARRY_MS


func _track_swing() -> void:
	var k := String(mv.get("key", ""))
	if k not in ["atk1", "jatk1"]:
		return
	var f: Dictionary = _cur()
	if f.get("hit") == null:
		return
	if not mv.has("swing_t"):
		mv["swing_t"] = now


func _rot_rect(r: Rect2) -> Rect2:
	var c := TILT_PIVOT * shown
	var out := Rect2()
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var q: Vector2 = c + (pts[i] - c).rotated(anim.rotation) + Vector2(0, _bob)
		out = Rect2(q, Vector2.ZERO) if i == 0 else out.expand(q)
	return out


func hit_rect() -> Rect2:
	var hb := hitbox.get_child(0) as CollisionShape2D
	if hb.disabled:
		return Rect2()
	var sz := (hb.shape as RectangleShape2D).size
	return Rect2(global_position + hb.position - sz / 2.0, sz)


## L2 bubble: centre and radius (art px, feet pivot, art faces left) fitted by tools/fit_barrier.py around every opaque
## pixel of the held barrier pose (heal f5-8, incl. the raised hand and the energy ball) + a 3 px margin
func barrier_fit() -> Vector3:
	var b: Dictionary = AnimLib.spells["barrier"]
	if b.has("fit"):
		var f: Array = b["fit"]
		return Vector3(float(f[0]), float(f[1]), float(f[2]))
	return Vector3(-3.0, -38.0, 46.0)


func _place_barrier() -> void:
	var f := barrier_fit()
	var k := f.z / float(AnimLib.spells["barrier"].get("rim_r", 36)) * shown
	barrier.scale = Vector2(k, k)
	barrier.position = Vector2(-facing * f.x * shown, f.y * shown)


## the bubble's circle in world space (centre, radius)
func barrier_circle() -> Vector3:
	var f := barrier_fit()
	var c := global_position + Vector2(-facing * f.x * shown, f.y * shown)
	return Vector3(c.x, c.y, f.z * shown)


## v0.9.4: the small bubble lasts CROUCH_BUBBLE_S, then it drops even if she stays crouched.
func crouch_bubble_on() -> bool:
	return state == "ground" and _neutral == "crouch" and crouch_bubble_left > 0.0


func crouch_bubble_circle() -> Vector3:
	var body := body_rect()
	var c := body.get_center()
	return Vector3(c.x, c.y, Tuning.CROUCH_BUBBLE_R * shown)


func _place_crouch_bubble() -> void:
	var c := crouch_bubble_circle()
	var rim := float(AnimLib.spells["barrier"].get("rim_r", 36))
	var k := c.z / rim
	barrier.scale = Vector2(k, k)
	barrier.position = to_local(Vector2(c.x, c.y))
	barrier.visible = true


func _sync_crouch_bubble() -> void:
	if barrier_on:
		bubble_dial.visible = false
		return
	if crouch_bubble_on():
		if not barrier.visible:
			Sfx.play("barrier", 0.45)
		_place_crouch_bubble()
	elif barrier.visible and not barrier_on:
		barrier.visible = false
		_place_barrier()
	var show_dial := crouch_bubble_on()
	bubble_dial.visible = show_dial
	if show_dial:
		bubble_dial.position = barrier.position
		bubble_dial.frac = clampf(crouch_bubble_left / Tuning.CROUCH_BUBBLE_S, 0.0, 1.0)
		bubble_dial.radius = crouch_bubble_circle().z + 10.0
		bubble_dial.queue_redraw()


func hurt_rect() -> Rect2:
	if barrier_on:                      # while shielded the bubble is what gets hit (and blocks)
		var bc := barrier_circle()
		return Rect2(bc.x - bc.z, bc.y - bc.z, 2.0 * bc.z, 2.0 * bc.z)
	if crouch_bubble_on():
		var cc := crouch_bubble_circle()
		return Rect2(cc.x - cc.z, cc.y - cc.z, 2.0 * cc.z, 2.0 * cc.z)
	var hs := hurtbox.get_child(0) as CollisionShape2D
	var sz := (hs.shape as RectangleShape2D).size
	return Rect2(global_position + hs.position - sz / 2.0, sz)


## screen position of an art-space point (relative to the feet pivot)
func art_to_world(p: Vector2) -> Vector2:
	return global_position + Vector2(-facing * p.x * shown, p.y * shown)


# ---------------------------------------------------------------- main loop
func _physics_process(delta: float) -> void:
	# v0.8: Mera's input clock runs on real time through a hit-stop (the world freezes, her timing windows don't),
	# so a press made during the freeze is judged exactly as it would be without it
	now += HitStop.input_dt(delta) * 1000.0
	_poll_input()
	if game != null and game.mark_lock:
		for e in presses:
			e["used"] = true
		vel = Vector2.ZERO
		return
	if _try_mark():
		vel = Vector2.ZERO
		return
	_step_size(delta)
	if invuln > 0.0:
		invuln -= delta
		anim.modulate.a = 0.35 if int(invuln * 14.0) % 2 == 0 else 1.0
		if invuln <= 0.0:
			anim.modulate.a = 1.0
	_fury_tick(delta)
	_stamina_tick(delta)
	_counter_tint()
	aura_mat.set_shader_parameter("time_s", now / 1000.0)
	match state:
		"ground":
			_ground_tick(delta)
		"air":
			_air_tick(delta)
		"fly":
			_fly_tick(delta)
		"move":
			_move_tick(delta)
		"hurt":
			_hurt_tick(delta)
		"dead":
			vel.x = move_toward(vel.x, 0.0, 600.0 * shown * delta)
			_gravity(delta)
		"gallery":
			_gallery_tick()
	position += vel * delta
	if state != "gallery":
		_land_check()
	anim.step(delta * 1000.0)
	_tilt_tick(delta)
	_place_flame()
	_update_beam()
	_update_boxes()
	if state == "move":
		_do_hits()
		_track_swing()
	if game != null:
		game.resolve_projectiles()
	_sync_crouch_bubble()
	if barrier.visible:
		barrier.frame = int(now / float(AnimLib.spells["barrier"]["ms"])) % barrier.hframes


func _gravity(delta: float, k: float = 1.0) -> void:
	if not on_ground and not flying:
		vel.y += GRAVITY * shown * k * delta


func _land_check() -> void:
	if position.y >= ground_y:
		position.y = ground_y
		if not on_ground:
			on_ground = true
			vel.y = 0.0
			air_jumps = 1
			air_dashes = 1
			_on_landed()
	elif not flying and state != "move":
		if on_ground and state == "ground":      # v0.8: walked off a platform (or it crumbled): fall
			state = "air"
			_neutral = ""
			_play("jump", 16)
		on_ground = false


# ---------------------------------------------------------------- neutral ground
func _ground_tick(delta: float) -> void:
	var d := _dir()
	if _try_ground_actions():
		return
	var top := RUN * shown
	if pressed("down"):
		vel.x = 0.0
		if _neutral != "crouch":
			_neutral = "crouch"
			crouch_t = now
			crouch_bubble_left = Tuning.CROUCH_BUBBLE_S
			_play("crouch")
			anim.section(6, 8)
		elif crouch_bubble_left > 0.0:
			crouch_bubble_left = maxf(crouch_bubble_left - delta, 0.0)
		return
	if _neutral == "crouch":
		_neutral = "crouch_up"
		anim.section(-1, -1)
		anim.seek(9)
		return
	if _neutral == "crouch_up":
		if d == 0 and not anim.paused:
			return
	if d != 0:
		var running := pressed("btn_a")
		if running:
			if d != facing and _neutral in ["run", "run_start"]:
				_neutral = "run_turn"
				_play("run_turn")
			elif _neutral == "run_turn":
				vel.x = move_toward(vel.x, 0.0, top * 4.0 * delta)
				return
			else:
				_face(d)
				if _neutral not in ["run", "run_start"]:
					_neutral = "run_start"
					_play("run_start")
				vel.x = facing * (top * 0.6 if _neutral == "run_start" else top)
		else:
			_face(d)
			if _neutral != "walk":
				_neutral = "walk"
				_play("walk")
				anim.section(2, 25)
			vel.x = facing * WALK * shown
	else:
		if _neutral in ["run", "run_start"]:
			_neutral = "run_stop"
			_play("run_stop")
		if _neutral == "run_stop":
			vel.x = move_toward(vel.x, 0.0, top * 3.0 * delta)
			return
		if _neutral != "idle":
			_neutral = "idle"
			_play("idle")
		vel.x = 0.0


func _go_neutral(start_idle: int = 0) -> void:
	mv = {}
	barrier_on = false
	barrier.visible = false
	if flying:
		state = "fly"
		_play("djump_v", 3)
		anim.paused = true
		return
	if on_ground:
		state = "ground"
		_neutral = "idle"
		_play("idle", start_idle)
		vel = Vector2.ZERO
	else:
		state = "air"
		_neutral = ""
		_play("jump", 16)
		anim.section(16, 18)


## X / Y / A / B / Up / R1 / L2 / R2 from the ground. L1 drinks and does not drop a bubble. Returns true when a move started.
func _try_ground_actions() -> bool:
	if crouch_bubble_on():
		_sip()
	if crouch_bubble_on() and not _pressed_since(-1e9, ["btn_x", "btn_y", "btn_a", "btn_b", "up", "r1", "l2", "r2"]).is_empty():
		crouch_bubble_left = 0.0
	var x := _find("btn_x")
	var y := _find("btn_y")
	var b := _find("btn_b")
	var up := _find("up")
	if not combo_after.is_empty():
		if now > float(combo_after["until"]):
			combo_after = {}
		elif _combo_continue(x, y):
			return true
	# v0.4: X and Y commit on the frame they are pressed (no waiting to see whether a chord follows). A chord partner
	# that lands within CHORD_MS converts the just-started move in its first frames (see _chord_convert).
	if not y.is_empty() and pressed("down") and _neutral == "crouch":   # v0.5 Down+Y crouching -> earthquake
		_use(y)
		return _stamina_move("earthquake")
	if not y.is_empty():
		var uu := _find("up", float(y["t"]) - CHORD_MS)
		if not uu.is_empty():                                        # v0.9.1 Up+Y (same frame) -> vertical quick fire
			_use(uu); _use(y)
			return _stamina_move("vfire")
		var xx := _find("btn_x", float(y["t"]) - CHORD_MS)
		var aa := _find("btn_a", float(y["t"]) - CHORD_MS)
		if not xx.is_empty():                                        # X+Y -> rear explosion
			_use(xx); _use(y)
			return _stamina_move("rear_blast")
		if not aa.is_empty() or held["btn_a"]:                       # A+Y (or Y while A held) -> ground dash
			_use(aa); _use(y)
			return _stamina_move("gdash")
		var bb := _find("btn_b", float(y["t"]) - CHORD_MS)
		if held["btn_b"] or not bb.is_empty():                       # B+Y -> rising slash (no stamina, no dodge)
			_use(bb); _use(y)
			_start_move("datk2")
			return true
		_use(y)                                                      # Y -> quick fire, now
		var ok := _stamina_move("quick_fire")
		if state == "move" and String(mv.get("key", "")) == "quick_fire":
			mv["chain_since"] = float(y["t"])
		return ok
	if not x.is_empty():                                             # X -> 1x (combo starter), now
		_use(x)
		_start_move("atk1")
		return true
	if not b.is_empty():
		_use(b)
		if held["btn_y"]:                                            # Y already held when B lands -> rising slash
			_start_move("datk2")
			return true
		_start_move("bdodge")                                        # B commits now; a Y within CHORD_MS converts it
		return true
	var a := _find("btn_a")
	if not a.is_empty() and pressed("down"):
		_use(a)
		_start_move("slide")
		return true
	if not up.is_empty():
		_use(up)
		jump_up_t = float(up["t"])
		_jump()
		return true
	if _special_buttons():
		return true
	if state == "ground" and debug:
		pass
	return false


## stamina-gated move: not enough stamina -> fail cue + HUD flash, nothing starts (the press is spent)
func _stamina_move(k: String) -> bool:
	if not spend_stamina(k):
		return true
	_start_move(k)
	return true


func stamina_cost(k: String) -> float:
	return float(Tuning.STAMINA_COST.get(k, 0.0))


func spend_stamina(k: String) -> bool:
	var c := stamina_cost(k)
	if stamina + 0.001 < c:
		Sfx.play("fail", 1.3, -4.0)
		if game:
			game.flash_hud("stamina")
		return false
	stamina = maxf(stamina - c, 0.0)
	return true


## +STAMINA_REGEN per second; the held bubble drains BUBBLE_DRAIN per second instead and drops when it runs out
func _stamina_tick(delta: float) -> void:
	if barrier_on:
		stamina = maxf(stamina - Tuning.BUBBLE_DRAIN * delta, 0.0)
		if stamina <= 0.0 and state == "move" and String(mv.get("key", "")) == "barrier":
			barrier_on = false
			barrier.visible = false
			mv["released"] = true
			anim.section(-1, -1)
			anim.seek(9)
			Sfx.play("fail", 1.3, -4.0)
			if game:
				game.flash_hud("stamina")
	else:
		stamina = minf(stamina + Tuning.STAMINA_REGEN * delta, stamina_max)


func add_stamina(v: float) -> void:
	stamina = clampf(stamina + v, 0.0, stamina_max)


func add_stamina_max(v: float) -> void:
	stamina_max = minf(stamina_max + v, Tuning.STAMINA_MAX_CAP)
	add_stamina(v)


func add_rage_max(v: float) -> void:
	rage_max = minf(rage_max + v, Tuning.RAGE_MAX_CAP)
	add_rage(v)


func _sip() -> bool:
	var l1 := _find("l1")
	if l1.is_empty():
		return false
	_use(l1)
	if potions > 0 and size < SIZE_HEAL_MAX:
		potions -= 1
		set_size(size + 1)
		Sfx.play("heal")
		if game:
			game.on_potions_changed()
	else:
		Sfx.play("fail")
		if game:
			game.flash_hud("potions" if potions <= 0 else "max")
	return true


## the newest unused press of one of `actions` at or after `since` ({} if none)
func _pressed_since(since: float, actions: Array) -> Dictionary:
	var best := {}
	for a in actions:
		var e := _find(String(a), since)
		if e.is_empty():
			continue
		if best.is_empty() or float(e["t"]) >= float(best["t"]):
			best = e
	return best


## a combo hit just recovered to idle: within COMBO_GRACE_MS the next press still continues the string
## (1x -> X -> 2x; 2x -> X -> 2x-2/2x-1, Y -> 3x; 2x-1/2x-2 -> Y -> beam). Root motion committed at the end of the
## hit is undone so the next hit's frames line up exactly as in a direct chain.
func _combo_continue(x: Dictionary, y: Dictionary) -> bool:
	var from: String = combo_after["from"]
	var nxt := ""
	var use_x := false
	var use_y := false
	if from == "ychain":
		var n := int(combo_after["yn"])
		var since := float(combo_after["since"])
		return _ychain_next(n, since)        # a move that starts clears combo_after; otherwise the grace runs on
	match from:
		"bdodge":                    # right after the dodge: Y -> fast quick fire, X -> dodge attack
			if not y.is_empty():
				_use(y)
				combo_after = {}
				if spend_stamina("quick_fire"):
					_start_move("quick_fire")
					_make_fast()
				return true
			if not x.is_empty():
				_use(x)
				combo_after = {}
				_start_move("datk1")
				return true
		"atk1":
			if not x.is_empty():
				nxt = "atk2"; use_x = true
		"atk2":
			if not y.is_empty():
				nxt = "atk3"; use_y = true
			elif not x.is_empty():
				nxt = "atk2_1" if ((float(x["rel"]) if x.has("rel") else now) - float(x["t"])) >= HOLD_MS else "atk2_2"; use_x = true
		"atk2_1", "atk2_2":
			if not y.is_empty() and float(y["t"]) >= float(combo_after.get("x3_t", 0.0)):
				nxt = "beam_ender"; use_y = true
	if nxt == "":
		return false
	if nxt == "beam_ender" and not spend_stamina("beam_ender"):
		_use(y)
		combo_after = {}
		return true
	combo_after = {}
	if use_x: _use(x)
	if use_y: _use(y)
	var a: Dictionary = AnimLib.anims[from]
	position.x -= -facing * float(a.get("end_dx", 0.0)) * shown
	_start_move(nxt)
	if nxt == "atk2":
		mv["from_t"] = float(x["t"])
	if nxt in ["atk2_1", "atk2_2"]:
		mv["x3_t"] = float(x["t"])
		mv["may_upgrade"] = nxt == "atk2_2" and held["btn_x"]
	if nxt == "atk3":
		_swallow_y(float(y["t"]))
	return true


## v0.9.1 Y chain (owner t99u). `n` shots fired so far in the chain (1 = the plain quick fire), presses counted from
## `since` (the current shot's start). Y (n < 3) -> another shot from f14; after the 3rd shot the first of
## Y -> beam (exactly the X X X Y beam), X -> vertical beam (heal pose), L2 -> pulse wave (knockback only) wins.
## Returns true when a new move started.
func _ychain_next(n: int, since: float) -> bool:
	var y := _find("btn_y", since)
	if n < 3:
		if y.is_empty():
			return false
		_use(y)
		if not spend_stamina("quick_fire"):
			return false
		_start_aligned("qf_chain", Tuning.YCHAIN_START)
		mv["yn"] = n + 1
		mv["chain_since"] = float(y["t"])     # presses after this Y (even ones made during an earlier shot) count
		return true
	var x := _find("btn_x", since)
	var l2 := _find("l2", since)
	var pick := ""
	var best := 1e18
	for c in [["y", y], ["x", x], ["l2", l2]]:
		var e: Dictionary = c[1]
		if not e.is_empty() and float(e["t"]) < best:
			best = float(e["t"])
			pick = c[0]
	match pick:
		"y":
			_use(y)
			if not spend_stamina("beam_ender"):
				return false
			_start_aligned("beam_ender", 0)
			ychain_log.append(["beam_ender", 0])
			return true
		"x":
			_use(x)
			if not spend_stamina("vbeam"):
				return false
			_start_aligned("vbeam", 0)
			return true
		"l2":
			_use(l2)
			if not spend_stamina("pulse"):
				return false
			_start_aligned("pulse", 0)
			return true
	return false


## start a move whose first frame comes from another animation, keeping the body where it is (no visible jump)
func _start_aligned(k: String, start: int) -> void:
	var old_cx := _body_cx(_cur())
	_start_move(k)
	if start > 0:
		anim.seek(start)
	position.x += -facing * (old_cx - _body_cx(_cur())) * shown


func _body_cx(f: Dictionary) -> float:
	var b = f.get("body") if not f.is_empty() else null
	if b == null:
		return 0.0
	return (float(b[0]) + float(b[2])) / 2.0


## the heal-pose moves (vertical fire, pulse, vertical beam) end at HEAL_POSE_END, before the heal burst frames
func _end_pose() -> void:
	anim.section(-1, -1)
	if cast_orb:
		cast_orb.visible = false
	_root_from_body()
	_go_neutral()


## X X Y Y / X X Y X: once 3x is chosen, later Y presses are swallowed (never the beam)
func _swallow_y(t: float) -> void:
	for e in presses:
		if e["a"] == "btn_y" and float(e["t"]) >= t:
			e["used"] = true


## B, Y: the quick fire plays at 2x and its bolt flies at 2x (Tuning.FAST_FIRE_*)
func _make_fast() -> void:
	mv["fast"] = true
	anim.speed = Tuning.FAST_FIRE_ANIM


## chord partner landing just after the move it would modify already started (sloppy X+Y / Y+A): convert the move
## within its first CHORD_MS. Returns true if it converted.
func _chord_convert(k: String) -> bool:
	if now - float(mv["t0"]) > CHORD_MS:
		return false
	var since := float(mv["t0"]) - CHORD_MS
	var into := ""
	var e := {}
	if k == "atk1":
		e = _find("btn_y", since)
		if not e.is_empty():
			into = "rear_blast"
	elif k == "quick_fire" and not mv.get("fast", false):
		e = _find("btn_x", since)
		if not e.is_empty():
			into = "rear_blast"
		elif not _find("up", since).is_empty():             # v0.9.1 Y then Up within CHORD_MS -> vertical quick fire
			e = _find("up", since)
			into = "vfire"
		elif not _find("btn_b", since).is_empty():        # Y then B within CHORD_MS -> rising slash
			e = _find("btn_b", since)
			into = "datk2"
		else:
			e = _find("btn_a", since)
			if not e.is_empty():
				into = "gdash"
	if into == "":
		return false
	_use(e)
	if k == "quick_fire":
		add_stamina(stamina_cost("quick_fire"))          # refund: the chord replaces it
	if into != "datk2" and not spend_stamina(into):
		return false
	_start_move(into)
	return true


## L1+R1+L2+R2 together (Q+W+1+2): the freeze-frame slash. Costs 100 rage. It does not start Fury.
func _try_mark() -> bool:
	if game == null or state in ["dead", "gallery"]:
		return false
	if rage_spending or rage < FURY_COST:
		return false
	var got: Array = []
	var newest := -1e9
	for a in ["l1", "r1", "l2", "r2"]:
		var e := _find(a, now - Tuning.MARK_CHORD_MS)
		if e.is_empty() or not held[a]:
			return false
		got.append(e)
		newest = maxf(newest, float(e["t"]))
	for e in got:
		if newest - float(e["t"]) > Tuning.MARK_CHORD_MS:
			return false
	if not game.begin_mark():
		return false
	for e in got:
		_use(e)
	pay_rage()
	return true


func _special_buttons() -> bool:
	var l1 := _find("l1")
	var r1 := _find("r1")
	var l2 := _find("l2")
	var r2 := _find("r2")
	# L2 alone raises the bubble. L2+R2 (either order, or R2 while the bubble is held) drops lightning.
	# R2 alone, after the chord window, starts Fury. In Fury, R2 takes off or lands.
	if not r2.is_empty():
		if fury:
			_use(r2)
			if not flying:
				_take_off()
				return true
		else:
			var l2c := _find("l2", float(r2["t"]) - CHORD_MS)
			if not l2c.is_empty() or held["l2"]:
				_use(r2); _use(l2c)
				return _try_lightning()
			if now - float(r2["t"]) > CHORD_MS:
				_use(r2)
				return _try_fury()
	if not l1.is_empty():
		_use(l1)
		if potions > 0 and size < SIZE_HEAL_MAX:
			_start_move("heal")
			return true
		Sfx.play("fail")
		if game:
			game.flash_hud("potions" if potions <= 0 else "max")
	if not r1.is_empty():                               # v0.5: R1 = summon an ally (cards: S3)
		_use(r1)
		if game and game.has_method("summon_ally"):
			if game.summon_ally():
				return false
		Sfx.play("fail", 1.2, -4.0)
		if game:
			game.flash_hud("ally")
	if not l2.is_empty():
		_use(l2)
		var r2c := _find("r2", float(l2["t"]) - CHORD_MS)
		if not fury and (not r2c.is_empty() or held["r2"]):
			_use(r2c)
			return _try_lightning()
		_start_move("barrier")
		mv["no_tap"] = true
		return true
	return false


func _try_fury() -> bool:
	if rage >= 100.0 and not rage_spending and not fury:
		start_fury()
		return false
	Sfx.play("fail", 1.4, -6.0)
	if game:
		game.flash_hud("rage")
	return false


func _try_lightning() -> bool:
	if fury or not pay_rage():
		Sfx.play("fail", 1.4, -6.0)
		if game:
			game.flash_hud("rage")
		return false
	_start_move("lightning")
	return true


func _jump() -> void:
	jump_t0 = now
	jump_y0 = position.y
	on_ground = false
	position.y -= 1.0
	vel.y = -JUMP_V * shown
	state = "air"
	_neutral = ""
	_play("jump")


# ---------------------------------------------------------------- air
func _air_tick(delta: float) -> void:
	var d := _dir()
	_face(d)
	vel.x = d * (RUN if pressed("btn_a") else WALK) * shown
	_gravity(delta)
	var x := _find("btn_x")
	var y := _find("btn_y")
	var up := _find("up")
	# v0.9.1 Up then Y within CHORD_MS: the jump that Up started a moment ago becomes the vertical quick fire
	if not y.is_empty() and now - jump_t0 <= CHORD_MS and float(y["t"]) - jump_up_t <= CHORD_MS \
			and stamina + 0.001 >= stamina_cost("vfire"):
		_use(y)
		jump_t0 = -1e9
		position.y = jump_y0
		vel = Vector2.ZERO
		on_ground = true
		_stamina_move("vfire")
		return
	if not combo_after.is_empty() and combo_after.get("from", "") == "datk2" and now <= float(combo_after["until"]):
		if not y.is_empty():             # Y right after the rising slash -> slam (not the aerial dash)
			_use(y)
			combo_after = {}
			_start_move("datk3")
			return
	if not x.is_empty():
		_use(x)
		_start_move("jatk1")
		return
	if not y.is_empty() and air_dashes > 0:                          # Y in the air -> aerial dash
		_use(y)
		if spend_stamina("adash"):
			air_dashes -= 1
			_start_move("adash")
			return
	if not up.is_empty():
		_use(up)
		if fury:
			_take_off()
			return
		if air_jumps > 0:
			air_jumps -= 1
			vel.y = -JUMP_V * 0.9 * shown
			_start_move("djump_f" if d != 0 else "djump_v")
			return
	if _special_air():
		return
	# jump anim follows the vertical speed: rise loop 4-9, apex 10-15, fall loop 16-18
	if anim.key != "jump":
		_play("jump", 4)
	var i := anim.idx
	if vel.y < -160.0 * shown:
		if i > 9:
			anim.seek(4)
		if i >= 4:
			anim.section(4, 9)
		else:
			anim.section(-1, -1)
	elif vel.y < 160.0 * shown:
		anim.section(-1, -1)
		if i < 10 or i > 15:
			anim.seek(10)
	else:
		if i < 16 or i > 18:
			anim.seek(16)
		anim.section(16, 18)


func _special_air() -> bool:
	var r2 := _find("r2")
	var l2 := _find("l2")
	if not r2.is_empty():
		if fury:
			_use(r2)
			_take_off()
			return true
		var l2c := _find("l2", float(r2["t"]) - CHORD_MS)
		if not l2c.is_empty() or held["l2"]:
			_use(r2); _use(l2c)
			_try_lightning()
			return true
		if now - float(r2["t"]) > CHORD_MS:
			_use(r2)
			_try_fury()
			return true
	elif not l2.is_empty():
		var r2c := _find("r2", float(l2["t"]) - CHORD_MS)
		if not fury and (not r2c.is_empty() or held["r2"]):
			_use(l2); _use(r2c)
			_try_lightning()
			return true
		elif not flying:
			_use(l2)
			_start_move("barrier")
			mv["no_tap"] = true
			return true
	return false


func _on_landed() -> void:
	if state == "air":
		state = "move"
		mv = {"key": "land", "dmg": 0, "cancel": true}
		vel.x = 0.0
		_play("jump", 20)
	elif state == "move":
		var k: String = mv.get("key", "")
		if k in ["jatk1", "jatk2", "adash", "djump_v", "djump_f"]:
			_root_from_body()
			mv = {"key": "land", "dmg": 0, "cancel": true}
			vel.x = 0.0
			_play("roll_land" if absf(vel.x) > 0.0 or k == "adash" else "jump", 0 if k == "adash" else 20)
		elif k == "datk3" and anim.idx < 21:
			vel = Vector2.ZERO
			anim.section(-1, -1)
			anim.seek(21)
			if game:
				game.shake(8.0 * shown, 0.25)
			Sfx.play("boom", 1.3, -4.0)
		elif k == "datk2":
			pass
		elif k in ["barrier", "lightning"]:          # v0.9.1 air bubble: she lands in it and stops
			vel.x = 0.0
	elif state == "hurt" or state == "dead":
		vel.y = 0.0


# ---------------------------------------------------------------- flight (Fury)
func _take_off() -> void:
	flying = true
	on_ground = false
	position.y = minf(position.y, ground_y - 2.0)
	state = "fly"
	mv = {}
	_play("djump_v", 2)
	anim.paused = true
	Sfx.play("dash", 0.8)


func _fly_tick(delta: float) -> void:
	var v := _dir2()
	_face(int(v.x))
	vel = v.normalized() * FLY * shown if v != Vector2.ZERO else vel.move_toward(Vector2.ZERO, FLY * 4.0 * shown * delta)
	_hover_t += delta
	var want := 2 if v != Vector2.ZERO else 3                      # active flight pose / idle hover (user's attachment)
	if anim.key != "djump_v" or anim.idx != want:
		anim.play("djump_v", want)
		anim.paused = true
	_bob = 0.0 if want == 2 else roundf(sin(_hover_t * 3.0) * 1.0) * shown
	# face the flight direction: her head leads along the velocity (the raised-arms pose reads as flying head-first),
	# flipped for left/right by _face; in the idle hover she eases back upright
	if v != Vector2.ZERO:
		tilt_target = atan2(v.x, -v.y)
	else:
		tilt_target = 0.0
	position.y = clampf(position.y, 40.0 + 60.0 * shown, ground_y)
	if position.y >= ground_y - 1.0 and pressed("down"):
		_land_from_flight()
		return
	var x := _find("btn_x")
	var y := _find("btn_y")
	if not x.is_empty():
		_use(x)
		_start_move("jatk1")
		return
	if not y.is_empty():
		_use(y)
		if spend_stamina("quick_fire"):
			_start_move("quick_fire")
			return
	var b := _find("btn_b")
	if not b.is_empty():
		_use(b)
		_start_move("bdodge")
		return
	var r2 := _find("r2")
	if not r2.is_empty():
		_use(r2)
		_land_from_flight()
		return
	_special_buttons()


func _land_from_flight() -> void:
	flying = false
	anim.position.y = 0.0
	if position.y >= ground_y - 1.0:
		on_ground = true
		position.y = ground_y
		_go_neutral()
	else:
		on_ground = false
		state = "air"
		_play("jump", 16)


# ---------------------------------------------------------------- fury / rage
## R1 lightning: only with a full meter outside Fury (in Fury the meter is the Fury timer, already spent by R2)
func can_lightning() -> bool:
	return not fury and not rage_spending and rage >= R1_COST


## spend 100 rage. Fury, lightning and the freeze slash each call this. The rest of a raised meter stays.
func pay_rage() -> bool:
	if rage_spending or rage < FURY_COST:
		return false
	rage -= FURY_COST
	return true


## spend the whole meter; it drains visibly over ~0.45 s, and nothing refills it until it is empty
func spend_rage() -> void:
	rage_spending = true


func add_rage(v: float) -> void:
	if fury or rage_spending:
		return
	rage = clampf(rage + v, 0.0, rage_max)


func start_fury() -> void:
	fury = true
	fury_left = FURY_TIME
	rage = maxf(rage - FURY_COST, 0.0)
	AnimLib.set_fury(true)
	Sfx.fury = true
	Sfx.play("fury")
	aura_mat.set_shader_parameter("aura", 1.0)
	set_aura_quality(aura_quality)
	if game:
		game.shake(10.0, 0.3)


## afterimage trail for the fast dashes and the dodge: up to TRAIL_CAP pooled ghost copies of the body frame, one every
## 2 physics frames, fading over 0.2 s (teal, deep red in Fury)
const TRAIL_CAP := 8
var _ghosts: Array = []
var _ghost_i := 0
var _trail_n := 0


func _trail() -> void:
	_trail_n += 1
	if _trail_n % 2 != 0 or game == null or not anim.body.visible:
		return
	var g: Sprite2D
	if _ghosts.size() < TRAIL_CAP:
		g = Sprite2D.new()
		g.centered = false
		g.region_enabled = true
		game.world.add_child(g)
		_ghosts.append(g)
	else:
		g = _ghosts[_ghost_i % TRAIL_CAP]
		_ghost_i += 1
	g.texture = anim.body.texture
	g.region_rect = anim.body.region_rect
	g.global_transform = anim.body.global_transform
	g.z_index = -1
	g.modulate = Color(1.0, 0.15, 0.15, 0.55) if fury else Color(0.45, 1.0, 0.85, 0.5)
	g.visible = true
	g.set_meta("t", 0.2)


func _fade_trail(delta: float) -> void:
	for g in _ghosts:
		if g.visible:
			var t: float = float(g.get_meta("t", 0.0)) - delta
			g.set_meta("t", t)
			g.modulate.a = maxf(t / 0.2, 0.0) * 0.55
			if t <= 0.0:
				g.visible = false


func _exit_tree() -> void:
	for g in _ghosts:
		if is_instance_valid(g):
			g.queue_free()
	_ghosts.clear()


func _tilt_tick(delta: float) -> void:
	_fade_trail(delta)
	if state != "fly":
		tilt_target = 0.0
		_bob = 0.0
	var rate := 12.0 if state == "fly" and tilt_target != 0.0 else (7.0 if state == "fly" else 22.0)
	var r := lerp_angle(anim.rotation, tilt_target, 1.0 - exp(-rate * delta))
	if absf(angle_difference(r, tilt_target)) < 0.002:
		r = tilt_target
	anim.rotation = r
	var c := TILT_PIVOT * shown
	anim.position = Vector2(0.0, _bob) + c - c.rotated(r)


## quality cap for the Fury aura (low-end devices): see aura_quality
func set_aura_quality(q: int) -> void:
	aura_quality = clampi(q, 0, 2)
	var n: Array = AURA_AMOUNTS[aura_quality]
	flame_back.amount = maxi(int(n[0]), 1)
	flame_front.amount = maxi(int(n[1]), 1)
	aura_fx.amount = int(n[2])
	if fury:
		aura_fx.emitting = true
		flame_back.emitting = int(n[0]) > 0
		flame_front.emitting = int(n[1]) > 0
	flame_back.visible = int(n[0]) > 0
	flame_front.visible = int(n[1]) > 0


static var _flame_img: ImageTexture


## a 12x20 pixel flame tongue: pointed top, round base, solid core, softer rim (tinted by the colour ramp)
static func _flame_tex() -> ImageTexture:
	if _flame_img == null:
		var img := Image.create(12, 20, false, Image.FORMAT_RGBA8)
		for y in 20:
			var ny := float(y) / 19.0                            # 0 top .. 1 base
			var w := 5.8 * pow(sin(PI * clampf(ny * 0.62 + 0.38, 0.0, 1.0)), 0.8) * (0.25 + 0.75 * pow(ny, 0.55))
			for x in 12:
				var dx := absf(float(x) - 5.5)
				if dx <= w:
					img.set_pixel(x, y, Color(1, 1, 1, 1.0 if dx <= w * 0.55 else 0.6))
		_flame_img = ImageTexture.create_from_image(img)
	return _flame_img


func _make_flame(front: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.local_coords = false
	p.emitting = false
	p.amount = 70 if front else 160
	p.lifetime = 0.38 if front else 0.6
	p.texture = _flame_tex()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0, -1)
	p.spread = 8.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.7))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.2))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	if front:
		grad.set_color(0, Color(1.0, 0.6, 0.3, 0.32))       # faint: licks over her outline without hiding her
		grad.set_color(1, Color(0.8, 0.05, 0.05, 0.0))
		grad.add_point(0.4, Color(1.0, 0.3, 0.1, 0.22))
		var am := CanvasItemMaterial.new()
		am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = am
	else:
		grad.set_color(0, Color(1.0, 0.45, 0.15, 0.95))
		grad.set_color(1, Color(0.25, 0.0, 0.03, 0.0))
		grad.add_point(0.3, Color(0.95, 0.16, 0.08, 0.9))
		grad.add_point(0.7, Color(0.5, 0.02, 0.05, 0.6))
	p.color_ramp = grad
	return p


## every frame in Fury: emit from her current body (world space), sized by her size; when she moves the tongues are
## launched backwards along her motion and, being world-space, stay behind as a trail
func _place_flame() -> void:
	if not fury:
		return
	var br := body_rect()
	if br.size == Vector2.ZERO:
		br = Rect2(global_position + Vector2(-12, -48) * shown, Vector2(24, 48) * shown)
	var c := br.get_center() - global_position
	var half := br.size / 2.0
	var spd := vel.length()
	var back := Vector2(0, -1)
	if spd > 40.0 * shown:
		back = (Vector2(0, -0.6) - vel.normalized()).normalized()
	for p in [flame_back, flame_front]:
		p.position = c + Vector2(0, half.y * 0.25)
		p.emission_rect_extents = Vector2(half.x * (1.05 if p == flame_back else 0.6), half.y * 0.7)
		p.direction = back
		p.initial_velocity_min = 70.0 * shown + 0.25 * spd
		p.initial_velocity_max = 150.0 * shown + 0.45 * spd
		p.gravity = Vector2(0, -380.0 * shown)
		p.scale_amount_min = (1.2 if p == flame_back else 0.7) * shown
		p.scale_amount_max = (2.4 if p == flame_back else 1.1) * shown
	aura_fx.position = c


func _fury_tick(delta: float) -> void:
	if rage_spending:
		rage = maxf(rage - 220.0 * delta, 0.0)
		if rage <= 0.0:
			rage_spending = false
	if not fury:
		return
	fury_left -= delta
	if fury_left <= 0.0:
		fury = false
		AnimLib.set_fury(false)
		Sfx.fury = false
		aura_mat.set_shader_parameter("aura", 0.0)
		aura_fx.emitting = false
		flame_back.emitting = false
		flame_front.emitting = false
		if flying:
			flying = false
			anim.position.y = 0.0
			if state == "fly":
				state = "air"
				_play("jump", 16)


# ---------------------------------------------------------------- committed moves
func _start_move(k: String) -> void:
	combo_after = {}               # any new move ends the post-recovery grace of the previous combo hit
	var a := k
	var extra := {}
	match k:
		"gdash":
			a = "adash"
		"lightning", "barrier", "vfire", "pulse", "vbeam":
			a = "heal"
		"qf_chain":
			a = "quick_fire"
		"earthquake":
			a = "roll_land"
	mv = {"key": k, "anim": a, "dmg": DMG.get(k, 0), "hits": {}, "hitwin": false, "t0": now, "fired": false, "beam_n": 0}
	mv.merge(extra)
	move_keys.append(k)
	state = "move"
	_neutral = ""
	if flying:
		vel = Vector2.ZERO
	_play(a)
	anim.speed = FAST_ANIMS.get(k, 1.0)
	match k:
		"bdodge":
			Sfx.play("dash", 1.2)
		"gdash", "adash":
			vel = Vector2(facing * DASH_FAST * shown, 0.0)
			Sfx.play("dash", 1.0)
		"slide":
			Sfx.play("dash", 0.9)
		"barrier":
			pass
		"earthquake":
			vel = Vector2.ZERO
			if game:
				if can_lightning():          # v0.8 full meter, outside Fury: SUPER EARTHQUAKE (spends the whole meter)
					spend_rage()
					super_quakes += 1
					game.super_earthquake()
				else:
					game.earthquake()
		"quick_fire", "rear_blast", "vfire":
			Sfx.play("charge", 1.2 if k == "rear_blast" else 1.6)
		"atk1", "atk2", "atk2_1", "atk2_2", "jatk1", "jatk2", "datk1":
			Sfx.play("swipe", randf_range(0.95, 1.1))
	var keep_air := not on_ground and k in ["barrier", "lightning"]     # v0.9.1 air bubble keeps her momentum
	if k in ["atk1", "quick_fire", "qf_chain", "rear_blast", "bdodge", "heal", "lightning", "barrier", "slide", "gdash", "vfire", "pulse", "vbeam"] and not keep_air:
		vel.x = 0.0 if k not in ["gdash"] else vel.x


func _chain(next: String) -> void:
	move_keys.append(next)
	# same combo context: frames already carry the chain's offsets, so the position stays put
	var keep_hits := false
	mv = {"key": next, "anim": next, "dmg": DMG.get(next, 0), "hits": {} if not keep_hits else mv["hits"], "hitwin": false,
		"t0": now, "fired": false, "beam_n": 0}
	_play(next)
	if next in ["atk2", "atk2_1", "atk2_2", "jatk2", "datk2"]:
		Sfx.play("swipe", randf_range(0.9, 1.05))
	if next == "atk3":
		Sfx.play("swipe", 0.85)


func _move_tick(delta: float) -> void:
	var k: String = mv.get("key", "")
	var i := anim.idx
	if cast_orb:
		cast_orb.visible = k == "vfire" and i >= 3
		if k == "vfire":
			anim.fx.visible = false
	if not flying and k not in ["adash", "gdash", "datk3"]:
		_gravity(delta, 0.35 if k in ["jatk1", "jatk2"] else 1.0)
	match k:
		"land":
			if _dir() != 0 or not presses.is_empty():
				_root_from_body()
				_go_neutral()
				_ground_tick(delta)
		"atk1":
			if _chord_convert(k):
				return
			_chain_window(i)
		"quick_fire":
			if _chord_convert(k):
				return
			if on_ground:
				vel.x = 0.0
			if i >= Tuning.YCHAIN_FIRST_FRAME and on_ground and not flying and _ychain_next(int(mv.get("yn", 1)), float(mv.get("chain_since", mv["t0"]))):
				return
		"qf_chain":
			if on_ground:
				vel.x = 0.0
			if i >= Tuning.YCHAIN_FIRE and not mv.get("fired", false):
				mv["fired"] = true
				if game:
					game.spawn_bolt(self, art_to_world(Vector2(Tuning.YCHAIN_SPAWN[0], Tuning.YCHAIN_SPAWN[1])), facing, shown, true)
				Sfx.play("cast", randf_range(1.0, 1.1))
				ychain_log.append(["qf_chain", i, int(mv.get("yn", 2))])
			if i >= Tuning.YCHAIN_NEXT_FRAME and mv.get("fired", false) and _ychain_next(int(mv.get("yn", 2)), float(mv.get("chain_since", mv["t0"]))):
				return
		"vfire":
			if on_ground:
				vel.x = 0.0
			if i >= Tuning.VFIRE_FRAME and not mv.get("fired", false):
				mv["fired"] = true
				if game:
					game.spawn_bolt_up(self, art_to_world(Vector2(Tuning.VFIRE_SPAWN[0], Tuning.VFIRE_SPAWN[1])), shown, true)
				Sfx.play("cast", 1.15)
				ychain_log.append(["vfire", i])
			if i >= Tuning.HEAL_POSE_END:
				_end_pose()
		"pulse":
			if on_ground:
				vel.x = 0.0
			if i >= 5 and not mv.get("fired", false):
				mv["fired"] = true
				if game:
					game.pulse_wave(self)
				ychain_log.append(["pulse", i])
			if i >= Tuning.HEAL_POSE_END:
				_end_pose()
		"vbeam":
			if on_ground:
				vel.x = 0.0
			if i >= 5 and not mv.get("fired", false):
				mv["fired"] = true
				mv["beam_t"] = now
				anim.section(5, 8)                     # the raised-wand pose holds while the beam runs
				if game:
					game.vertical_beam(self, art_to_world(Vector2(Tuning.VFIRE_SPAWN[0], Tuning.VFIRE_SPAWN[1])))
				ychain_log.append(["vbeam", i])
			if mv.get("fired", false) and now - float(mv["beam_t"]) >= Tuning.VBEAM_S * 1000.0:
				_end_pose()
		"atk2":
			_chain_window_2x(i)
		"atk2_1", "atk2_2":
			# X X X Y: a Y pressed after the third X, any time during this third hit (or BEAM_GRACE_MS after it, see
			# _combo_continue), becomes the beam combo. X X Y (3x) and X X Y Y never reach here.
			if mv.has("x3_t"):
				var yb := _find("btn_y", float(mv["x3_t"]))
				if not yb.is_empty():
					_use(yb)
					if spend_stamina("beam_ender"):
						_chain("beam_ender")
						return
			# X X, hold X: a hold that completes in 2x-2's first frames still becomes 2x-1 (no freeze to wait for it)
			if k == "atk2_2" and mv.get("may_upgrade", false) and i <= Tuning.UPGRADE_FRAMES:
				if not held["btn_x"]:
					mv["may_upgrade"] = false
				elif now - float(mv["x3_t"]) >= HOLD_MS:
					var t3 := float(mv["x3_t"])
					_chain("atk2_1")
					mv["x3_t"] = t3
		"bdodge":
			vel.x = -facing * DODGE * shown if i >= 2 and i <= 16 else 0.0
			_trail()
			# v0.4: B then Y -> FAST quick fire (2x animation, 2x bolt speed) from FAST_FIRE_FRAME; B then X -> dodge
			# attack from f12. Both buffered from the start of the dodge (and DODGE_GRACE_MS after it, _combo_continue).
			if not mv.has("x0"):
				mv["x0"] = position.x
			var yb := _find("btn_y", float(mv["t0"]))
			var xb := _find("btn_x", float(mv["t0"]))
			if not yb.is_empty() and float(yb["t"]) - float(mv["t0"]) <= CHORD_MS:
				# B+Y chord (Y within CHORD_MS of B): the dodge's first frames convert into the rising slash, in place
				_use(yb)
				position.x = float(mv["x0"])
				vel = Vector2.ZERO
				_start_move("datk2")
				return
			if not yb.is_empty() and i >= Tuning.FAST_FIRE_FRAME:
				_use(yb)
				vel.x = 0.0
				if spend_stamina("quick_fire"):
					_start_move("quick_fire")
					_make_fast()
				return
			elif not xb.is_empty() and i >= 12:
				_use(xb)
				vel.x = 0.0
				_chain("datk1")
		"datk1":
			vel.x = facing * DASH * shown if i >= 1 and i <= 8 else 0.0
			# v0.4: the dodge attack no longer chains (mashing X can't reach the rising slash or the slam)
		"datk2":
			vel.x = 0.0
			# v0.9.1 (t108u): windup plays at 4x. Drop to 1x on the last windup frame so the rise
			# (frames RISE_FROM..RISE_TO) is not consumed at 4x. 2x vy over that 1x window is 2x distance.
			anim.speed = Tuning.RSLASH_WINDUP_SPEED if i < Tuning.RSLASH_RISE_FROM - 1 else 1.0
			if i >= Tuning.RSLASH_RISE_FROM and i <= Tuning.RSLASH_RISE_TO:
				vel.y = Tuning.RSLASH_VY * shown
				on_ground = false
			var ys := _find("btn_y", float(mv["t0"]))           # Y any time in the rising slash -> slam
			if i >= 13 and not ys.is_empty():
				_use(ys)
				_chain("datk3")
		"datk3":
			if i < 18:
				vel = Vector2.ZERO
			elif i <= 20:
				anim.section(18, 20)
				vel = Vector2(0.0, 1100.0 * shown)
				if on_ground or flying:
					anim.section(-1, -1)
					anim.seek(21)
					vel = Vector2.ZERO
			else:
				vel = Vector2.ZERO
		"jatk1":
			vel.x = move_toward(vel.x, 0.0, 300.0 * shown * delta)
			if i >= 4 and not _find("btn_x", float(mv["t0"]) - 100.0).is_empty() and i >= 7:
				_use(_find("btn_x", float(mv["t0"]) - 100.0))
				_chain("jatk2")
		"jatk2":
			vel.x = move_toward(vel.x, 0.0, 300.0 * shown * delta)
		"adash", "gdash":
			vel = Vector2(facing * DASH_FAST * shown, 0.0)
			_trail()
		"slide":
			vel.x = facing * DASH * shown if i >= 2 and i <= 12 else move_toward(vel.x, 0.0, DASH * 4.0 * shown * delta)
		"beam_ender":
			var ph: String = String(_cur().get("phase", ""))
			if ph == "fire" or ph == "sustain":                    # heavy recoil: pushed away from the beam, screen shakes
				vel.x = -facing * (420.0 if ph == "fire" else 260.0) * shown
				if game:
					game.shake(minf(6.0 + 2.0 * shown, 36.0), 0.08)
			else:
				vel.x = move_toward(vel.x, 0.0, 1800.0 * shown * delta)
		"barrier":
			# v0.8: right after a parry, X / Y (or a direction) cut the pose short so the counter comes out at once
			if mv.has("parry_t") and not barrier_on and on_ground:
				var cx := _find("btn_x", float(mv["parry_t"]))
				var cy := _find("btn_y", float(mv["parry_t"]))
				if not cx.is_empty() or not cy.is_empty():
					_root_from_body()
					_go_neutral()
					_ground_tick(delta)
					return
			# R2 with L2, or R2 while the bubble is up: lightning. The bubble stays if it is already up.
			var r2b := _find("r2", float(mv["t0"]) - CHORD_MS)
			if not r2b.is_empty() and not fury:
				_use(r2b)
				if pay_rage():
					if barrier_on:
						if game:
							game.call_lightning(self)
					else:
						mv["key"] = "lightning"
				else:
					Sfx.play("fail", 1.4, -6.0)
					if game:
						game.flash_hud("rage")
				return
			# letting go before the bubble forms just drops the pose. It is never a lightning tap.
			if not barrier_on and not mv.get("released", false) and i < Tuning.L2_TAP_FRAMES and not pressed("l2"):
				mv["released"] = true
			if not barrier_on and not mv.get("released", false) and i >= 5 and i < 9:
				if pressed("l2") and spend_stamina("barrier"):
					barrier_on = true
					barrier.visible = true
					anim.section(5, 8)
					Sfx.play("barrier")
				else:
					mv["released"] = true
					anim.seek(9)
			elif mv.get("released", false) and not barrier_on and i < 9 and i >= 5:
				anim.seek(9)
			elif barrier_on:
				_sip()
				var act := _pressed_since(float(mv["t0"]), ["btn_x", "btn_y", "btn_a", "btn_b", "up", "r1"])
				if not act.is_empty():
					_root_from_body()
					var grounded := on_ground
					barrier_on = false
					barrier.visible = false
					_go_neutral()
					if grounded:
						_ground_tick(delta)
					else:
						_air_tick(delta)
					return
				if not pressed("l2"):
					barrier_on = false
					barrier.visible = false
					mv["released"] = true
					anim.section(-1, -1)
					anim.seek(9)
		"datk2_fall":
			pass
		_:
			if k in ["quick_fire", "rear_blast", "heal", "lightning", "atk2_1", "atk2_2", "atk3", "djump_v", "djump_f"]:
				if on_ground:
					vel.x = 0.0


## 1x atk -> 2x atk: an X pressed any time during 1x atk (buffered from its first frame) chains at CHAIN_1X;
## an X pressed later, up to the end of the animation, chains immediately.
func _chain_window(i: int) -> void:
	if i < Tuning.CHAIN_1X:
		return
	var x := _find("btn_x", float(mv["t0"]))
	if not x.is_empty():
		_use(x)
		_chain("atk2")
		mv["from_t"] = float(x["t"])     # fast mashing: presses after this X (even ones made during 1x) count for 2x


## 2x atk branch, resolved at CHAIN_2X (or the moment the press arrives after it), never by freezing her:
##   Y (no third X before it) -> 3x atk;  third X then Y -> beam ender (X X X Y);
##   third X still held for HOLD_MS -> 2x-1, otherwise 2x-2 (which upgrades to 2x-1 if the hold completes in its
##   first UPGRADE_FRAMES frames). Presses made any time during 2x atk count.
func _chain_window_2x(i: int) -> void:
	if i < Tuning.CHAIN_2X:
		return
	var since := float(mv.get("from_t", mv["t0"]))
	var x := _find("btn_x", since)
	var y := _find("btn_y", since)
	if not y.is_empty():
		var beam := not x.is_empty() and float(x["t"]) <= float(y["t"])
		_use(y)
		_use(x)
		if beam:
			if spend_stamina("beam_ender"):
				_swallow_y(float(y["t"]))
				_chain("beam_ender")
				return
			_chain("atk2_2")                       # no stamina: the third X still lands as 2x-2
			mv["x3_t"] = 1e12
			return
		_swallow_y(float(y["t"]))
		_chain("atk3")
		return
	if x.is_empty():
		return
	_use(x)
	var t3 := float(x["t"])
	var holding: bool = held["btn_x"] and _latest("btn_x") == t3
	var held_ms: float = (float(x["rel"]) if x.has("rel") else now) - t3   # a hold that already finished counts too
	if held_ms >= HOLD_MS:
		_chain("atk2_1")
	else:
		_chain("atk2_2")
		mv["may_upgrade"] = holding
	mv["x3_t"] = t3


func _bolt_orb() -> Sprite2D:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	var c := Vector2(23.5, 23.5)
	var rings: Array = [
		[22.0, Color8(163, 33, 33)],
		[15.0, Color8(207, 86, 56)],
		[9.0, Color8(250, 169, 83)],
		[4.0, Color8(255, 248, 230)],
	]
	for y in 48:
		for x in 48:
			var d := Vector2(x, y).distance_to(c)
			for ring in rings:
				if d <= float(ring[0]):
					img.set_pixel(x, y, ring[1])
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.centered = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = Vector2(Tuning.VFIRE_SPAWN[0], Tuning.VFIRE_SPAWN[1])
	return s


## time of the most recent press of `a` (used or not)
func _latest(a: String) -> float:
	var t := -1.0
	for e in presses:
		if e["a"] == a:
			t = maxf(t, float(e["t"]))
	return t


func _on_frame(i: int) -> void:
	if state != "move" and state != "gallery":
		return
	var k: String = mv.get("key", "") if state == "move" else anim.key
	var a: Dictionary = AnimLib.anims[anim.key]
	if a.has("fire_frame") and i == int(a["fire_frame"]) and game:
		if state == "move" and mv.get("fired", false):
			return
		if state == "move":
			mv["fired"] = true
		var sp: Array = a.get("spawn", [0, 0])
		match anim.key:
			"quick_fire", "quick_fire_v3":
				game.spawn_bolt(self, art_to_world(Vector2(sp[0], sp[1])), facing, shown, state != "gallery",
					Tuning.FAST_FIRE_BOLT if mv.get("fast", false) else 1.0)
				Sfx.play("cast", 1.0)
			"rear_blast", "rear_blast_v3":
				game.spawn_fireball(self, art_to_world(Vector2(sp[0], sp[1])), -facing, shown, a["shot"], state != "gallery")
				Sfx.play("cast", 0.7)
			"beam_ender", "beam_combo_v1":
				Sfx.play("beam", 1.0)
	if anim.key == "heal" and i == 7 and state == "move":
		match k:
			"heal":
				if potions > 0 and size < SIZE_HEAL_MAX:
					potions -= 1
					set_size(size + 1)
					Sfx.play("heal")
					if game:
						game.on_potions_changed()
			"lightning":
				if game:
					game.call_lightning(self)
	if anim.key == "atk3" and i == 26:
		Sfx.play("claw")


func _on_finished(k: String) -> void:
	if state == "gallery":
		return
	if state == "hurt":
		_root_from_body()
		_go_neutral()
		return
	if state == "dead":
		return
	if state == "ground":
		if _neutral in ["run_start"]:
			_neutral = "run"
			_play("run")
		elif _neutral == "run_turn":
			_face(-facing)
			_neutral = "run"
			_play("run")
		elif _neutral in ["run_stop", "crouch_up"]:
			_neutral = "idle"
			_play("idle")
		return
	if state != "move":
		return
	var key: String = mv.get("key", "")
	match key:
		"datk2":
			_root_from_body()
			mv = {}
			combo_after = {"from": "datk2", "until": now + Tuning.SLAM_GRACE_MS}    # Y while falling -> slam
			state = "air"
			on_ground = false
			_play("jump", 16)
			anim.section(16, 18)
			return
		"jatk1", "jatk2", "adash", "gdash", "djump_v", "djump_f", "datk3":
			if not on_ground or key in ["gdash", "adash", "datk3"]:
				_root_from_body()
				mv = {}
				state = "air" if not flying else "fly"
				if flying or on_ground:
					_go_neutral()
				else:
					_play("jump", 12)
				return
	# end of a ground move: commit the baked root motion so idle continues exactly where the last frame was
	var a: Dictionary = AnimLib.anims[anim.key]
	var ca := {}
	if key in ["atk1", "atk2", "atk2_1", "atk2_2", "bdodge"] and on_ground and not flying:
		var grace: float = Tuning.BEAM_GRACE_MS if key in ["atk2_1", "atk2_2"] else (Tuning.DODGE_GRACE_MS if key == "bdodge" else Tuning.COMBO_GRACE_MS)
		ca = {"from": key, "until": now + grace, "x3_t": float(mv.get("x3_t", 0.0))}
	elif key in ["quick_fire", "qf_chain"] and on_ground and not flying:     # v0.9.1 Y chain grace
		ca = {"from": "ychain", "until": now + Tuning.YCHAIN_GRACE_MS, "yn": int(mv.get("yn", 1)), "since": float(mv.get("chain_since", mv["t0"]))}
	if on_ground and a.has("end_dx") and not flying:
		position.x += -facing * float(a["end_dx"]) * shown
		_go_neutral(int(a.get("end_idle", 0)))
	else:
		_root_from_body()
		_go_neutral()
	combo_after = ca


## move the root under the body when an animation is cut short (keeps the silhouette from jumping)
func _root_from_body() -> void:
	var b = _cur()["body"]
	if b == null:
		return
	var cx := (float(b[0]) + float(b[2])) / 2.0
	var idle_b: Array = AnimLib.frames("idle")[0]["body"]
	var icx := (float(idle_b[0]) + float(idle_b[2])) / 2.0
	position.x += -facing * (cx - icx) * shown


# ---------------------------------------------------------------- hits
func _do_hits() -> void:
	if game == null:
		return
	var f: Dictionary = _cur()
	var dmg: int = mv.get("dmg", 0)
	if dmg <= 0 or f["hit"] == null:
		mv["hitwin"] = false
		return
	if not mv.get("hitwin", false):           # a new active window (e.g. 3x atk slash, then claw) can hit again
		mv["hitwin"] = true
		mv["hits"] = {}
	var is_beam := f.has("beam")
	if is_beam:
		mv["beam_n"] = int(mv["beam_n"]) + 1
		if int(mv["beam_n"]) % BEAM_TICK == 1:
			mv["hits"] = {}
	var r := hit_rect()
	for e in game.targets():
		if mv["hits"].has(e.get_instance_id()):
			continue
		if e.alive() and r.intersects(e.hurt_rect()):
			mv["hits"][e.get_instance_id()] = true
			deal(e, dmg, global_position.x, "beam" if is_beam else LAUNCH_KINDS.get(String(mv.get("key", "")), "melee"))


## kind: melee | bolt | beam | explosion | lightning (a blocking Fire Knight only takes explosions and Fury attacks),
## v0.8 also launch (rising slash, 3x: throws ground enemies up) and slam (spikes airborne ones into a bounce)
func deal(e: Node, base: int, from_x: float, kind: String = "melee") -> void:
	var amount := base * size          # damage scales with Mera's size
	var countered := counter_active() and kind != "beam"
	if countered:
		amount *= Tuning.PARRY_COUNTER_MULT
	if e.get("is_prop"):               # v0.8 breakables: no rage, a light thud of hit-stop
		if e.take_damage(amount, from_x, kind):
			HitStop.stop(Tuning.HITSTOP_LIGHT_MS * 0.6)
			if game:
				game.hit_spark(e.hurt_rect().get_center(), shown * 0.7)
		return
	if not e.take_damage(amount, from_x, kind):
		if game:
			game.hit_spark(e.hurt_rect().get_center(), shown * 0.6)
		HitStop.stop(Tuning.HITSTOP_LIGHT_MS * 0.5)
		Sfx.play("clang", 1.1, -6.0)
		return
	add_rage(1.0)                      # small rage for every hit landed; spheres are the main source
	Sfx.play("hit" if amount < 6 else "hit_heavy", randf_range(0.95, 1.05))
	if game:
		game.hit_spark(e.hurt_rect().get_center(), shown)
	# v0.8 impact: hit-stop by weight (beam ticks only stop on a kill so the beam doesn't stutter)
	var ms := Tuning.HITSTOP_LIGHT_MS
	if not e.alive():
		ms = Tuning.HITSTOP_KILL_MS
	elif kind == "beam":
		ms = 0.0
	elif base >= 2 or countered or kind in ["explosion", "lightning", "launch", "slam"]:
		ms = Tuning.HITSTOP_HEAVY_MS
	HitStop.stop(ms)


## v0.8 moves that launch / spike enemies (monster.gd juggles)
const LAUNCH_KINDS := {"datk2": "launch", "atk3": "launch", "datk3": "slam", "atk2_1": "launch"}


func counter_active() -> bool:
	return now < counter_until


func _counter_tint() -> void:
	var a := anim.modulate.a
	if counter_active():
		var q := 0.5 + 0.5 * sin(now / 40.0)
		anim.modulate = Color(1.0 + 0.5 * q, 1.0 + 0.35 * q, 0.75, a)
	else:
		anim.modulate = Color(1, 1, 1, a)


## v0.8 parry: L2 pressed at most PARRY_MS ago (the barrier pose was just raised, the bubble isn't up yet).
## v0.9.2: a crouch started within the same window parries the same way, small bubble and all.
func parry_ready() -> bool:
	if state in ["dead", "gallery", "hurt"]:
		return false
	if not barrier_on and now - last_l2_t <= Tuning.PARRY_MS:
		return true
	return crouch_bubble_on() and now - crouch_t <= Tuning.PARRY_MS


## the small bubble subtracts 1 from the hit and does not knock her down. A hit of 1 is stopped.
func _crouch_soak(dmg: int, from_x: float) -> void:
	var left := dmg - 1
	Sfx.play("block")
	if game:
		game.shake(3.0, 0.08)
	if left <= 0:
		return
	if game:
		game.hit_spark(Vector2(global_position.x, global_position.y - 18.0 * shown), shown * 0.45)
	if size - left < SIZE_MIN:
		_die(from_x)
		return
	set_size(size - left)


func _parry(src: Node, from_x: float) -> void:
	parries += 1
	invuln = maxf(invuln, Tuning.PARRY_IFRAMES_S)
	counter_until = now + Tuning.PARRY_COUNTER_S * 1000.0
	if state == "move" and String(mv.get("key", "")) == "barrier":
		mv["parry_t"] = now
	Sfx.play("parry")
	Sfx.play("clang", 1.2, -2.0)
	HitStop.stop(Tuning.HITSTOP_PARRY_MS)
	_face(1 if from_x > global_position.x else -1)
	var small := crouch_bubble_on() and (barrier_on or now - last_l2_t > Tuning.PARRY_MS)
	if src != null and is_instance_valid(src) and src.has_method("parried"):
		src.parried(Tuning.CROUCH_PARRY_STUN_S if small else Tuning.PARRY_STUN_S)
	_shove_attacker(src, Tuning.CROUCH_PARRY_KNOCK_PX if small else Tuning.PARRY_KNOCK_PX)
	if game:
		game.parry_fx(Vector2(global_position.x + facing * 30.0 * shown, global_position.y - 40.0 * shown), shown)


## slide the attacker `px` away. No stun. Bosses stay put.
func _shove_attacker(src: Node, px: float) -> void:
	if src == null or not is_instance_valid(src) or src.get("boss") == true or not src.has_method("shove"):
		return
	var away := 1.0 if src.global_position.x >= global_position.x else -1.0
	src.shove(away * px)


## an enemy projectile touched her: true when it is parried (enemy_shot.gd then flies back)
func try_parry_shot(shot: Node) -> bool:
	if not parry_ready():
		return false
	deflects += 1
	_parry(null, shot.global_position.x)
	return true


## dodge i-frames: the back dodge and the dashes are invulnerable for their first 70 %
func dodging() -> bool:
	return state == "move" and String(mv.get("key", "")) in DODGE_KEYS and anim.idx < int(anim.frames.size() * 0.7)


func take_hit(dmg: int, from_x: float, src: Node = null) -> void:
	if state == "dead" or state == "gallery" or invuln > 0.0:
		return
	if parry_ready():                  # v0.8 parry (before dodge / barrier: the timing is what counts)
		_parry(src, from_x)
		return
	if dodging():
		return
	if barrier_on:
		Sfx.play("block")
		if game:
			game.shake(4.0, 0.1)
		_shove_attacker(src, Tuning.BARRIER_KNOCK_PX)
		return
	if crouch_bubble_on():             # v0.9.4: the small bubble subtracts 1 and does not knock her down
		_crouch_soak(dmg, from_x)
		return
	if size - dmg < SIZE_MIN:          # hit at 1x (or a hit bigger than her) -> death
		_die(from_x)
		return
	set_size(size - dmg)
	_interrupt()
	state = "hurt"
	var away := 1 if global_position.x > from_x else -1
	vel = Vector2(away * 260.0 * shown, -120.0 * shown if not flying else 0.0)
	if not flying:
		on_ground = false
	_face(-away)
	_play("hurt_hard" if dmg >= 2 else "hurt")
	invuln = IFRAMES
	Sfx.play("hurt")
	if game:
		game.shake(6.0, 0.15)


func _interrupt() -> void:
	combo_after = {}
	if state == "move" or state == "fly":
		_root_from_body()
	mv = {}
	barrier_on = false
	barrier.visible = false
	anim.section(-1, -1)
	anim.position.y = 0.0


func _hurt_tick(delta: float) -> void:
	vel.x = move_toward(vel.x, 0.0, 900.0 * shown * delta)
	if flying:
		vel.y = move_toward(vel.y, 0.0, 900.0 * shown * delta)
	else:
		_gravity(delta)


func _die(from_x: float) -> void:
	_interrupt()
	flying = false
	state = "dead"
	var away := 1 if global_position.x > from_x else -1
	_face(-away)
	vel = Vector2(away * 300.0 * shown, -200.0 * shown)
	on_ground = false
	_play("knockback")
	Sfx.play("boom_big", 0.6)
	if fury:
		fury_left = 0.0
		_fury_tick(0.0)
	died.emit()


# ---------------------------------------------------------------- gallery (every animation, in place)
func gallery_toggle() -> void:
	if state == "gallery":
		state = "ground"
		position.y = ground_y
		_go_neutral()
	else:
		_interrupt()
		state = "gallery"
		vel = Vector2.ZERO
		gallery_play(gallery_idx)


func gallery_play(i: int) -> void:
	var ks: Array = AnimLib.keys()
	gallery_idx = posmod(i, ks.size())
	anim.play(ks[gallery_idx])
	anim.loop = true
	move_log.append(ks[gallery_idx])


func _gallery_tick() -> void:
	for e in presses:
		if e["used"]:
			continue
		if e["a"] == "btn_a" or e["a"] == "up":
			e["used"] = true
			gallery_play(gallery_idx)
	if _gal_edge("right"):
		gallery_play(gallery_idx + 1)
	elif _gal_edge("left"):
		gallery_play(gallery_idx - 1)


var _gal_prev := {}
func _gal_edge(a: String) -> bool:
	var p := pressed(a)
	var e: bool = p and not _gal_prev.get(a, false)
	_gal_prev[a] = p
	return e
