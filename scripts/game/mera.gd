class_name Mera
extends Node2D
## Mera, player controller for the playable level (docs/CONTROLS.md, docs/GAME_RULES.md).
## Size is HP: she starts at 2x, every hit costs sizes equal to its damage, a hit at 1x is fatal.
## Damage dealt = move base damage x size. Speeds are px/s at 1x and scale with size.
## All animation comes from AnimLib (pack animations + the canon casts, baked by tools/export_game_anims.py).

signal size_changed(size: int)
signal died
signal move_started(key: String)

const WALK := 100.0
const RUN := 200.0
const DASH := 400.0
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
var barrier: Sprite2D
var _neutral := ""
var _hover_t := 0.0


func _ready() -> void:
	anim = LayeredAnim.new()
	add_child(anim)
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
	aura_fx = CPUParticles2D.new()
	aura_fx.emitting = false
	aura_fx.amount = 40
	aura_fx.lifetime = 0.7
	aura_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	aura_fx.direction = Vector2(0, -1)
	aura_fx.spread = 15.0
	aura_fx.gravity = Vector2(0, -60)
	aura_fx.color = Color(0.9, 0.08, 0.1, 0.85)
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
	barrier.scale = Vector2(shown, shown)
	barrier.position = Vector2(0, -30 * shown)
	aura_fx.emission_rect_extents = Vector2(18, 26) * shown
	aura_fx.position = Vector2(0, -27 * shown)
	aura_fx.scale_amount_min = shown
	aura_fx.scale_amount_max = shown * 2.0
	aura_fx.initial_velocity_min = 20.0 * shown
	aura_fx.initial_velocity_max = 50.0 * shown
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
	(hs.shape as RectangleShape2D).size = r.size
	hs.position = r.get_center()
	var hb := hitbox.get_child(0) as CollisionShape2D
	var attacking: bool = state == "move" and mv.get("dmg", 0) > 0 and f["hit"] != null
	hb.disabled = not attacking
	if attacking:
		var h := LayeredAnim.box_to_rect(f["hit"], facing, shown)
		(hb.shape as RectangleShape2D).size = h.size
		hb.position = h.get_center()


func hit_rect() -> Rect2:
	var hb := hitbox.get_child(0) as CollisionShape2D
	if hb.disabled:
		return Rect2()
	var sz := (hb.shape as RectangleShape2D).size
	return Rect2(global_position + hb.position - sz / 2.0, sz)


func hurt_rect() -> Rect2:
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
		_start_move("lightning")
		return true
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
	anim.position.y = 0.0 if want == 2 else roundf(sin(_hover_t * 3.0) * 1.0) * shown
	position.y = clampf(position.y, 40.0 + 60.0 * shown, ground_y)
	if position.y >= ground_y and pressed("down"):
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
func add_rage(v: float) -> void:
	if fury:
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
	aura_fx.emitting = true
	if game:
		game.shake(10.0, 0.3)


func _fury_tick(delta: float) -> void:
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
	match k:
		"bdodge":
			Sfx.play("dash", 1.2)
		"gdash", "adash":
			vel = Vector2(facing * DASH * shown, 0.0)
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
		"bdodge":
			vel.x = -facing * DASH * shown if i >= 2 and i <= 16 else 0.0
			if i >= 12 and not _find("btn_x", float(mv["t0"])).is_empty():
				_use(_find("btn_x", float(mv["t0"])))
				vel.x = 0.0
				_chain("datk1")
		"datk1":
			vel.x = facing * DASH * shown if i >= 1 and i <= 8 else 0.0
			if i >= 15 and not _find("btn_x", float(mv["t0"]) + 200.0).is_empty():
				_use(_find("btn_x", float(mv["t0"]) + 200.0))
				vel.x = 0.0
				_chain("datk2")
		"datk2":
			vel.x = 0.0
			if i >= 7 and i <= 11:
				vel.y = -380.0 * shown
				on_ground = false
			if i >= 13 and not _find("btn_x", float(mv["t0"]) + 160.0).is_empty():
				_use(_find("btn_x", float(mv["t0"]) + 160.0))
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
			if i >= 4 and not _find("btn_x", float(mv["t0"]) + 120.0).is_empty() and i >= 7:
				_use(_find("btn_x", float(mv["t0"]) + 120.0))
				_chain("jatk2")
		"jatk2":
			vel.x = move_toward(vel.x, 0.0, 300.0 * shown * delta)
		"adash", "gdash":
			vel = Vector2(facing * DASH * shown, 0.0)
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
	var x := _find("btn_x", float(mv["t0"]) + open * 40.0)
	if not x.is_empty() and i <= grace:
		_use(x)
		_chain("atk2")


## 2x atk branch: Y -> 3x (XXY); X then Y -> beam ender (XXXY); X held -> 2x-1; X tapped -> 2x-2.
## Presses are buffered through 2x atk; the decision is made at f9 (late presses until f12 still count). While a
## third X is undecided she holds the current pose (at most HOLD_MS) to learn whether it is held, tapped or followed by Y.
func _chain_window_2x(i: int) -> void:
	if i < 9:
		return
	var since := float(mv["t0"]) + 80.0
	var px: Dictionary = mv.get("pending_x", {})
	var x: Dictionary = px if not px.is_empty() else _find("btn_x", since)
	var y := _find("btn_y", since)
	if not y.is_empty():
		var beam := not x.is_empty() and float(x["t"]) <= float(y["t"])
		_use(y)
		_use(x)
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
	elif not held["btn_x"] and now - float(mv["pend_t"]) >= 60.0:
		mv.erase("pending_x")
		anim.paused = false
		_chain("atk2_2")


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


func take_hit(dmg: int, from_x: float) -> void:
	if state == "dead" or state == "gallery" or invuln > 0.0:
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
