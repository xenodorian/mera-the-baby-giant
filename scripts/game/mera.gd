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
const FAST_ANIMS := {"gdash": 2.0, "adash": 2.0, "bdodge": 2.0}   # animation playback rate (keeps every key frame)
const FLY := 320.0
const GRAVITY := 1500.0
const JUMP_V := 520.0
const SIZE_MIN := 1
const SIZE_HEAL_MAX := 6
const SIZE_DEBUG_MAX := 19
const CHORD_MS := 50.0        # simultaneous-press window (X+Y, A+Y, Up+...)
const HOLD_MS := 180.0        # "XX hold X": third X held this long -> 2x-1
const BUFFER_MS := 450.0      # how long a press stays buffered for a chain
const IFRAMES := 1.2
const BEAM_Y_MS := 300.0     # X X X Y: the Y may come up to this long after the third X
const R1_COST := 100.0      # the lightning strike needs a full meter and spends all of it
const DODGE_KEYS := ["bdodge", "gdash", "adash"]
const FURY_TIME := 12.0
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
var rage_spending := false     # R1 drained the meter; it empties visibly first
var fury := false
var fury_left := 0.0
var flying := false
var air_jumps := 1
var air_dashes := 1
var barrier_on := false
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
var flame_back: Sprite2D           # Kaioken-style Fury flame (shaders/fury_flame.gdshader): behind her ...
var flame_front: Sprite2D          # ... and thin additive tongues over her; children of anim so they scale/flip/tilt
var aura_quality := 2              # 2 = both flame layers + 90 embers, 1 = back flame + 45 embers, 0 = outline + 20 embers
const FLAME_SIZE := Vector2(84, 124)
var barrier: Sprite2D
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
	hurtbox = _box("Hurtbox", Color(0.2, 0.8, 1.0, 0.35))
	hitbox = _box("Hitbox", Color(1.0, 0.2, 0.2, 0.4))
	barrier = Sprite2D.new()
	barrier.texture = AnimLib.spell_tex("barrier")
	barrier.hframes = int(AnimLib.spell_cell("barrier")[2])
	barrier.material = AnimLib.fx_mat
	barrier.visible = false
	add_child(barrier)
	var blank := Image.create(int(FLAME_SIZE.x), int(FLAME_SIZE.y), false, Image.FORMAT_L8)
	blank.fill(Color.WHITE)
	var btex := ImageTexture.create_from_image(blank)
	var fsh: Shader = load("res://shaders/fury_flame.gdshader")
	for k in 2:
		var sp := Sprite2D.new()
		sp.texture = btex
		sp.centered = false
		var mat := ShaderMaterial.new()
		mat.shader = fsh
		mat.set_shader_parameter("front", float(k))
		mat.set_shader_parameter("size", FLAME_SIZE)
		mat.set_shader_parameter("seed", 3.0 + k)
		if k == 1:
			mat.shader = load("res://shaders/fury_flame_front.gdshader")
			mat.set_shader_parameter("front", 1.0)
		sp.material = mat
		sp.visible = false
		anim.add_child(sp)
		if k == 0:
			anim.move_child(sp, 0)       # behind the light/body/fx layers
			flame_back = sp
		else:
			flame_front = sp
	aura_fx = CPUParticles2D.new()
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
		held[a] = p or (_pending.get(a, false) and held[a])
		if p:
			held[a] = true
	_pending.clear()
	var keep: Array = []
	for e in presses:
		if not e["used"] and now - float(e["t"]) <= BUFFER_MS:
			keep.append(e)
	presses = keep


func _find(a: String, since: float = -1e9) -> Dictionary:
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


func hurt_rect() -> Rect2:
	if barrier_on:                      # while shielded the bubble is what gets hit (and blocks)
		var bc := barrier_circle()
		return Rect2(bc.x - bc.z, bc.y - bc.z, 2.0 * bc.z, 2.0 * bc.z)
	var hs := hurtbox.get_child(0) as CollisionShape2D
	var sz := (hs.shape as RectangleShape2D).size
	return Rect2(global_position + hs.position - sz / 2.0, sz)


## screen position of an art-space point (relative to the feet pivot)
func art_to_world(p: Vector2) -> Vector2:
	return global_position + Vector2(-facing * p.x * shown, p.y * shown)


# ---------------------------------------------------------------- main loop
func _physics_process(delta: float) -> void:
	now += delta * 1000.0
	_poll_input()
	_step_size(delta)
	if invuln > 0.0:
		invuln -= delta
		anim.modulate.a = 0.35 if int(invuln * 14.0) % 2 == 0 else 1.0
		if invuln <= 0.0:
			anim.modulate.a = 1.0
	_fury_tick(delta)
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
			_play("crouch")
			anim.section(6, 8)
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


## X / Y / A / B / Up / L1 / R1 / L2 / R2 from the ground. Returns true when a move started.
func _try_ground_actions() -> bool:
	var x := _find("btn_x")
	var y := _find("btn_y")
	var b := _find("btn_b")
	var up := _find("up")
	if not y.is_empty():
		var xx := _find("btn_x", float(y["t"]) - CHORD_MS)
		var aa := _find("btn_a", float(y["t"]) - CHORD_MS)
		if not xx.is_empty():                                        # X+Y -> rear explosion
			_use(xx); _use(y)
			_start_move("rear_blast")
			return true
		if not aa.is_empty() or held["btn_a"]:                       # A+Y (or Y while A held) -> ground dash
			_use(aa); _use(y)
			_start_move("gdash")
			return true
		if now - float(y["t"]) >= CHORD_MS:                          # Y alone -> quick fire
			_use(y)
			_start_move("quick_fire")
			return true
		return false
	if not x.is_empty():
		if now - float(x["t"]) >= CHORD_MS:                          # X alone -> 1x (combo starter)
			_use(x)
			_start_move("atk1")
			return true
		return false
	if not b.is_empty():
		_use(b)
		_start_move("bdodge")
		return true
	var a := _find("btn_a")
	if not a.is_empty() and pressed("down"):
		_use(a)
		_start_move("slide")
		return true
	if not up.is_empty():
		_use(up)
		_jump()
		return true
	if _special_buttons():
		return true
	if state == "ground" and debug:
		pass
	return false


func _special_buttons() -> bool:
	var l1 := _find("l1")
	var r1 := _find("r1")
	var l2 := _find("l2")
	var r2 := _find("r2")
	if not r2.is_empty():
		_use(r2)
		if fury:
			if not flying:
				_take_off()
				return true
		elif rage >= 100.0:
			start_fury()
			return false
		else:
			Sfx.play("fail", 1.4, -6.0)
	if not l1.is_empty():
		_use(l1)
		if potions > 0 and size < SIZE_HEAL_MAX:
			_start_move("heal")
			return true
		Sfx.play("fail")
		if game:
			game.flash_hud("potions" if potions <= 0 else "max")
	if not r1.is_empty():
		_use(r1)
		if can_lightning():
			spend_rage()
			_start_move("lightning")
			return true
		Sfx.play("fail", 1.2, -4.0)
		if game:
			game.flash_hud("rage")
	if not l2.is_empty():
		_use(l2)
		_start_move("barrier")
		return true
	return false


func _jump() -> void:
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
	if not x.is_empty():
		_use(x)
		_start_move("jatk1")
		return
	if not y.is_empty() and air_dashes > 0:                          # Y in the air -> aerial dash
		_use(y)
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
	if not r2.is_empty():
		_use(r2)
		if fury:
			_take_off()
			return true
		if rage >= 100.0:
			start_fury()
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


## spend the whole meter; it drains visibly over ~0.45 s, and nothing refills it until it is empty
func spend_rage() -> void:
	rage_spending = true


func add_rage(v: float) -> void:
	if fury or rage_spending:
		return
	rage = clampf(rage + v, 0.0, 100.0)


func start_fury() -> void:
	fury = true
	fury_left = FURY_TIME
	rage = 100.0
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
	aura_fx.amount = [20, 45, 90][aura_quality]
	if fury:
		aura_fx.emitting = true
		flame_back.visible = aura_quality >= 1
		flame_front.visible = aura_quality >= 2


## keep the flame centred on the current frame's body (native px, anim space), feet slightly inside its base
func _place_flame() -> void:
	if not flame_back.visible and not flame_front.visible:
		return
	var b = _cur().get("body")
	var cx := 0.0
	var bot := 0.0
	if b != null:
		cx = (float(b[0]) + float(b[2])) / 2.0
		bot = float(b[3])
	var p := Vector2(roundf(cx - FLAME_SIZE.x / 2.0), roundf(bot + 6.0 - FLAME_SIZE.y))
	flame_back.position = p
	flame_front.position = p


func _fury_tick(delta: float) -> void:
	if rage_spending:
		rage = maxf(rage - 220.0 * delta, 0.0)
		if rage <= 0.0:
			rage_spending = false
	if not fury:
		return
	fury_left -= delta
	rage = 100.0 * maxf(fury_left, 0.0) / FURY_TIME
	if fury_left <= 0.0:
		fury = false
		rage = 0.0
		AnimLib.set_fury(false)
		Sfx.fury = false
		aura_mat.set_shader_parameter("aura", 0.0)
		aura_fx.emitting = false
		flame_back.visible = false
		flame_front.visible = false
		if flying:
			flying = false
			anim.position.y = 0.0
			if state == "fly":
				state = "air"
				_play("jump", 16)


# ---------------------------------------------------------------- committed moves
func _start_move(k: String) -> void:
	var a := k
	var extra := {}
	match k:
		"gdash":
			a = "adash"
		"lightning", "barrier":
			a = "heal"
	mv = {"key": k, "anim": a, "dmg": DMG.get(k, 0), "hits": {}, "hitwin": false, "t0": now, "fired": false, "beam_n": 0}
	mv.merge(extra)
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
		"quick_fire", "rear_blast":
			Sfx.play("charge", 1.6 if k == "quick_fire" else 1.2)
		"atk1", "atk2", "atk2_1", "atk2_2", "jatk1", "jatk2", "datk1":
			Sfx.play("swipe", randf_range(0.95, 1.1))
	if k in ["atk1", "quick_fire", "rear_blast", "bdodge", "heal", "lightning", "barrier", "slide", "gdash"]:
		vel.x = 0.0 if k not in ["gdash"] else vel.x


func _chain(next: String) -> void:
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
	if not flying and k not in ["adash", "gdash", "datk3"]:
		_gravity(delta, 0.35 if k in ["jatk1", "jatk2"] else 1.0)
	match k:
		"land":
			if _dir() != 0 or not presses.is_empty():
				_root_from_body()
				_go_neutral()
				_ground_tick(delta)
		"atk1":
			_chain_window(i, 2, 10, 12, "atk1")
		"atk2":
			_chain_window_2x(i)
		"atk2_1", "atk2_2":
			# X X X Y: a Y that follows the third X within BEAM_Y_MS still becomes the beam combo, even after the
			# third X already resolved into 2x-1 / 2x-2 (human timing). Only a Y pressed AFTER that third X counts,
			# so X X Y (3x) and X X Y Y never reach here.
			if mv.has("x3_t") and i <= 5:
				var yb := _find("btn_y", float(mv["x3_t"]))
				if not yb.is_empty() and float(yb["t"]) - float(mv["x3_t"]) <= BEAM_Y_MS:
					_use(yb)
					_chain("beam_ender")
		"bdodge":
			vel.x = -facing * DODGE * shown if i >= 2 and i <= 16 else 0.0
			_trail()
			if i >= 12 and not _find("btn_x", float(mv["t0"])).is_empty():
				_use(_find("btn_x", float(mv["t0"])))
				vel.x = 0.0
				_chain("datk1")
		"datk1":
			vel.x = facing * DASH * shown if i >= 1 and i <= 8 else 0.0
			if i >= 15 and not _find("btn_x", float(mv["t0"]) - 100.0).is_empty():
				_use(_find("btn_x", float(mv["t0"]) - 100.0))
				vel.x = 0.0
				_chain("datk2")
		"datk2":
			vel.x = 0.0
			if i >= 7 and i <= 11:
				vel.y = -380.0 * shown
				on_ground = false
			if i >= 13 and not _find("btn_x", float(mv["t0"]) - 100.0).is_empty():
				_use(_find("btn_x", float(mv["t0"]) - 100.0))
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
			if not barrier_on and not mv.get("released", false) and i >= 5 and i < 9:
				if pressed("l2"):
					barrier_on = true
					barrier.visible = true
					anim.section(5, 8)
					Sfx.play("barrier")
				else:
					mv["released"] = true
					anim.seek(9)
			elif barrier_on and not _find("r1").is_empty():
				# R1 inside the bubble: same rule as outside (full meter, spends 100 %), she keeps the pose and keeps blocking
				_use(_find("r1"))
				if can_lightning():
					spend_rage()
					mv["bubble_strikes"] = int(mv.get("bubble_strikes", 0)) + 1
					if game:
						game.call_lightning(self)
					Sfx.play("cast", 0.8)
				else:
					Sfx.play("fail", 1.2, -4.0)
					if game:
						game.flash_hud("rage")
			elif barrier_on and not pressed("l2"):
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


## chain point = frame `point`; presses from frame `open` on are buffered; until `grace` a late press still chains
func _chain_window(i: int, open: int, point: int, grace: int, _from: String) -> void:
	if i < point:
		return
	var x := _find("btn_x", float(mv["t0"]) - 200.0)
	if not x.is_empty() and i <= grace:
		_use(x)
		_chain("atk2")


## 2x atk branch: Y -> 3x (XXY); X then Y -> beam ender (XXXY); X held -> 2x-1; X tapped -> 2x-2.
## Presses are buffered through 2x atk; the decision is made at f9 (late presses until f12 still count). While a
## third X is undecided she holds the current pose (at most HOLD_MS) to learn whether it is held, tapped or followed by Y.
func _chain_window_2x(i: int) -> void:
	if i < 9:
		return
	var since := float(mv["t0"]) - 200.0
	var px: Dictionary = mv.get("pending_x", {})
	var x: Dictionary = px if not px.is_empty() else _find("btn_x", since)
	var y := _find("btn_y", since)
	if not y.is_empty():
		# beam only for X X X Y: a third X pressed before the Y. A Y first means X X Y -> 3x, and any later X or Y
		# (X X Y Y, X X Y X) is swallowed, never the beam.
		var beam := not x.is_empty() and float(x["t"]) <= float(y["t"])
		_use(y)
		_use(x)
		for e in presses:
			if e["a"] == "btn_y" and float(e["t"]) >= float(y["t"]):
				e["used"] = true
		mv.erase("pending_x")
		anim.paused = false
		_chain("beam_ender" if beam else "atk3")
		return
	if x.is_empty():
		return
	if px.is_empty():
		if i > 12:
			return
		mv["pending_x"] = x
		mv["pend_t"] = now
		_use(x)
	anim.paused = true
	var held_for := now - float(x["t"])
	if held["btn_x"] and held_for >= HOLD_MS:
		mv.erase("pending_x")
		anim.paused = false
		_chain("atk2_1")
		mv["x3_t"] = float(x["t"])
	elif not held["btn_x"] and now - float(mv["pend_t"]) >= 60.0:
		mv.erase("pending_x")
		anim.paused = false
		_chain("atk2_2")
		mv["x3_t"] = float(x["t"])


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
				game.spawn_bolt(self, art_to_world(Vector2(sp[0], sp[1])), facing, shown, state != "gallery")
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
		"atk2":
			if mv.has("pending_x"):
				return
		"datk2":
			_root_from_body()
			mv = {}
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
	if on_ground and a.has("end_dx") and not flying:
		position.x += -facing * float(a["end_dx"]) * shown
		_go_neutral(int(a.get("end_idle", 0)))
	else:
		_root_from_body()
		_go_neutral()


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
	for e in game.enemies():
		if mv["hits"].has(e.get_instance_id()):
			continue
		if e.alive() and r.intersects(e.hurt_rect()):
			mv["hits"][e.get_instance_id()] = true
			deal(e, dmg, global_position.x)


func deal(e: Node, base: int, from_x: float) -> void:
	var amount := base * size          # damage scales with Mera's size
	e.take_damage(amount, from_x)
	add_rage(1.0)                      # small rage for every hit landed; spheres are the main source
	Sfx.play("hit" if amount < 6 else "hit_heavy", randf_range(0.9, 1.1))
	if game:
		game.hit_spark(e.hurt_rect().get_center(), shown)


## dodge i-frames: the back dodge and the dashes are invulnerable for their first 70 %
func dodging() -> bool:
	return state == "move" and String(mv.get("key", "")) in DODGE_KEYS and anim.idx < int(anim.frames.size() * 0.7)


func take_hit(dmg: int, from_x: float) -> void:
	if state == "dead" or state == "gallery" or invuln > 0.0:
		return
	if dodging():
		return
	if barrier_on:
		Sfx.play("block")
		if game:
			game.shake(4.0, 0.1)
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
