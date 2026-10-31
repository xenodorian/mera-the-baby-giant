extends Node2D
## Playable level (v0.5): one of four large native maps (scripts/game/levels.gd, tools/build_levels.py), Mera with
## every pack + canon animation, enemies, potions, rage spheres, Fury mode, earthquake, HUD, Game Over / Level Clear.
## Rules: docs/GAME_RULES.md. Controls: docs/CONTROLS.md.
##
## Command-line options (after "--"):
##   --size=N  --rage=N  --potions=N  --fury  --no-knight  --debug  --gallery=KEY  --overlay
##   --demo           play the scripted demo input (used for the gameplay capture)
##   --shot=PATH      save a PNG after --wait frames (default 60), then quit
##   --shots=PREFIX   with --demo: save PREFIX_<frame>.png at the frames listed by --at=f1,f2,...
##   --quit=N         quit after N frames
##   --level=N        play level N (1-4) directly

const GROUND_Y := 1060.0
const ART := 5
# v0.3.1: the camera is hard-locked horizontally on Mera's feet pivot, with no look-ahead and no smoothing, so turning
# around never shifts the view and fast moves never drift. Vertical stays fixed (the level is one screen tall).
const KNIGHT_GAP := 480.0     # new knights appear this far past the screen edge, ahead of Mera
const POTION_EVERY := 2600.0  # a potion appears on the ground ahead for every 2600 px of new ground

var mera: Mera
var cam: Camera2D
var cam_x := 960.0
var knight: Node2D = null       # the Fire Knight (one at a time)
var blues: Array = []           # v0.4 Blue Knights he calls in
var blues_spawned := 0
var drop_rng := RandomNumberGenerator.new()
var knight_timer := 1.2
var knights_spawned := 0
var shake_amt := 0.0
var shake_t := 0.0
var hud: Node
var world: Node2D
var debug_draw: Node2D
var over := false
var over_t := 0.0
var explored_max := 0.0
var explored_min := 0.0
var potion_next_r := POTION_EVERY
var potion_next_l := -POTION_EVERY
var test_mode := false
var frame_n := 0
var shot_path := ""
var shots_prefix := ""
var shot_at: Array = []
var wait_frames := 60
var quit_at := -1
var demo: Array = []
var _trace := OS.has_environment("MERA_TRACE")   # debug: print Mera's animation changes (demo tuning)
var _trace_k := ""
var defeated := 0
var last_strike: Node2D = null
var knight_calm_until := 0   # demo: frame before which the knight does not swing
var layers: Array = []       # [Sprite2D, scroll, period] parallax layers of the level map
var map_w := 19200.0
var cleared := false
var quake_t := 0.0           # v0.5 earthquake: time left of the 1 s quake
var quake_age := 0.0
var quaked := {}             # enemies already stunned by the current quake
var exit_gate: Node2D
var test_mode_no_exit := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			Levels.current = clampi(int(a.get_slice("=", 1)) - 1, 0, 3)
	map_w = Levels.map_w()
	_build_background()
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	mera = Mera.new()
	mera.name = "Mera"
	mera.game = self
	mera.ground_y = GROUND_Y
	mera.position = Vector2(760, GROUND_Y)
	add_child(mera)
	mera.died.connect(_on_died)
	cam = Camera2D.new()
	cam.position = Vector2(cam_x, 540)
	add_child(cam)
	var rig := preload("res://scripts/game/cam_rig.gd").new()   # camera update after Mera has moved this frame
	rig.game = self
	add_child(rig)
	cam.make_current()
	snap_camera()
	debug_draw = Node2D.new()
	debug_draw.z_index = 50
	debug_draw.draw.connect(_draw_debug)
	add_child(debug_draw)
	hud = load("res://scripts/game/hud.gd").new()
	hud.game = self
	add_child(hud)
	_parse_args()
	mera.set_size(mera.size, true)
	explored_max = mera.position.x
	explored_min = mera.position.x


func _build_background() -> void:
	var lv := Levels.level()
	RenderingServer.set_default_clear_color(Color8(int(lv["bg"][0]), int(lv["bg"][1]), int(lv["bg"][2])))
	for L in lv["layers"]:
		var sp := Sprite2D.new()
		sp.texture = load(String(L["file"]))
		sp.centered = false
		sp.scale = Vector2(ART, ART)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.z_index = int(L["z"])
		sp.position.y = float(L["y"])
		var period := float(L["period"])
		if period > 0.0:
			sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			sp.region_enabled = true
			sp.region_rect = Rect2(0, 0, ceilf((1920.0 + period + 2.0 * Levels.pad()) / ART) + 1.0, sp.texture.get_height())
		add_child(sp)
		layers.append([sp, float(L["scroll"]), period])
	exit_gate = load("res://scripts/game/exit_gate.gd").new()
	exit_gate.position = Vector2(map_w - Levels.EXIT_PAD, GROUND_Y)
	exit_gate.z_index = -5
	add_child(exit_gate)


## parallax: every layer is placed from the (unshaken) camera X, so the whole map shakes together with the camera
func _place_layers() -> void:
	var p := Levels.pad()
	for L in layers:
		var sp: Sprite2D = L[0]
		var s: float = L[1]
		var period: float = L[2]
		if period > 0.0:
			sp.position.x = roundf(cam_x - 960.0 - p - fposmod(cam_x * s, period))
		else:
			sp.position.x = roundf(cam_x * (1.0 - s) - 960.0 - p)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var v := a.get_slice("=", 1)
		if a.begins_with("--size="):
			mera.set_size(int(v), true)
		elif a.begins_with("--rage="):
			mera.rage = float(v)
		elif a.begins_with("--potions="):
			mera.potions = int(v)
		elif a == "--fury":
			mera.start_fury()
		elif a.begins_with("--aura-quality="):
			mera.set_aura_quality(int(v))
		elif a == "--no-knight":
			test_mode = true
		elif a == "--debug":
			mera.debug = true
		elif a == "--overlay":
			hud.overlay = true
		elif a.begins_with("--gallery="):
			var ks: Array = AnimLib.keys()
			mera.gallery_idx = maxi(ks.find(v), 0)
			mera.gallery_toggle()
		elif a.begins_with("--shot="):
			shot_path = v
		elif a.begins_with("--shots="):
			shots_prefix = v
		elif a.begins_with("--at="):
			for f in v.split(","):
				shot_at.append(int(f))
		elif a.begins_with("--wait="):
			wait_frames = int(v)
		elif a.begins_with("--quit="):
			quit_at = int(v)
		elif a == "--demo":
			demo = load("res://scripts/game/demo.gd").STEPS.duplicate()


# ---------------------------------------------------------------- frame
func _physics_process(delta: float) -> void:
	frame_n += 1
	_run_demo()
	if _trace and (mera.anim.key != _trace_k or (frame_n >= int(OS.get_environment("MERA_TRACE")) and frame_n < int(OS.get_environment("MERA_TRACE")) + 80)):
		_trace_k = mera.anim.key
		print("TRACE %d %s size=%d x=%.0f face=%d rage=%.0f" % [frame_n, _trace_k, mera.size, mera.global_position.x, mera.facing, mera.rage])
	if not test_mode:
		_manage_knight(delta)
		_manage_potions()
	if over or cleared:
		over_t += delta
	_quake_tick(delta)
	debug_draw.queue_redraw()


func _process(_delta: float) -> void:
	if shot_path != "" and frame_n >= wait_frames:
		_save(shot_path)
		get_tree().quit()
		shot_path = ""
	if shots_prefix != "" and frame_n in shot_at:
		_save("%s_%04d.png" % [shots_prefix, frame_n])
		shot_at.erase(frame_n)
	if quit_at > 0 and frame_n >= quit_at:
		get_tree().quit()


func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path, " ", img.get_size())


func _run_demo() -> void:
	while not demo.is_empty() and int(demo[0][0]) <= frame_n:
		var st: Array = demo.pop_front()
		match String(st[1]):
			"press":
				mera.forced[st[2]] = true
			"release":
				mera.forced[st[2]] = false
			"size":
				mera.set_size(int(st[2]))
			"rage":
				mera.rage = float(st[2])
			"potions":
				mera.potions = int(st[2])
			"calm":
				knight_calm_until = int(st[2])
			"spawning":                       # demo: stop/allow automatic knight spawns
				test_mode = not bool(st[2])
			"overlay":
				hud.overlay = bool(st[2])
			"spawn":
				_spawn_knight(signi(int(st[2])))
				knight.position.x = mera.global_position.x + (float(st[2]) if absi(int(st[2])) > 1 else signf(float(st[2])) * 900.0)


## called by cam_rig.gd after all physics this frame: X locked on Mera, independent of her facing
func _follow_camera(delta: float) -> void:
	_clamp_to_map()
	cam_x = mera.global_position.x
	_place_layers()
	var off := Vector2.ZERO
	if shake_t > 0.0:
		shake_t -= delta
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
		if shake_t <= 0.0:
			shake_amt = 0.0
	cam.position = Vector2(roundf(cam_x + off.x), roundf(540 + off.y))


## jump the camera onto its target (level start / restart)
func snap_camera() -> void:
	cam_x = mera.global_position.x
	_place_layers()
	cam.position = Vector2(roundf(cam_x), 540)


func camera_x() -> float:
	return cam_x


func shake(amount: float, t: float) -> void:
	shake_amt = maxf(shake_amt, amount)
	shake_t = maxf(shake_t, t)


# ---------------------------------------------------------------- enemies
func enemies() -> Array:
	var out: Array = []
	if knight != null and is_instance_valid(knight) and knight.alive():
		out.append(knight)
	for b in blues:
		if is_instance_valid(b) and b.alive():
			out.append(b)
	return out


func _spawn_knight(side: int = 0) -> void:
	if side == 0:
		side = mera.facing
	if knight != null and is_instance_valid(knight):
		knight.queue_free()
	var k: FireKnight = FireKnight.new()
	k.setup(self, "fire")
	side = _spawn_side(side, 960.0 + KNIGHT_GAP)
	k.position = Vector2(clampf(cam_x + side * (960.0 + KNIGHT_GAP), Levels.EDGE, map_w - Levels.EDGE), GROUND_Y)
	k.facing = -side
	world.add_child(k)
	knight = k
	knights_spawned += 1


func _manage_knight(delta: float) -> void:
	if knight != null and not is_instance_valid(knight):
		knight = null
	if knight == null:
		knight_timer -= delta
		if knight_timer <= 0.0 and not over:
			_spawn_knight()
		return
	for b in blues.duplicate():           # Blue Knights left far behind are removed
		if not is_instance_valid(b):
			blues.erase(b)
		elif b.alive() and absf(b.global_position.x - mera.global_position.x) > 1920.0 * 1.5:
			blues.erase(b)
			b.queue_free()
	# off-screen and left far behind -> replace him with a new one ahead of Mera
	if knight.alive():
		var off_screen := absf(knight.global_position.x - cam_x) > 960.0 + 120.0
		if off_screen and absf(knight.global_position.x - mera.global_position.x) > 1920.0 * 1.25:
			knight.queue_free()
			knight = null
			knight_timer = 0.0


## a side of the screen that still lies inside the map (near an end, enemies come in from the other side)
func _spawn_side(side: int, dist: float) -> int:
	var x := cam_x + side * dist
	if x < Levels.EDGE or x > map_w - Levels.EDGE:
		return -side
	return side


## invisible walls at both map ends; reaching the exit gate clears the level
func _clamp_to_map() -> void:
	var lo := Levels.EDGE
	var hi := map_w - Levels.EDGE
	mera.position.x = clampf(mera.position.x, lo, hi)
	for e in enemies():
		e.position.x = clampf(e.position.x, lo, hi)
	if not cleared and not over and not test_mode_no_exit and mera.position.x >= map_w - Levels.EXIT_PAD - 40.0:
		cleared = true
		over_t = 0.0
		Sfx.play("potion", 0.7)


## v0.4: a Blue Knight comes in from off-screen behind Mera (he prefers her back)
func spawn_blue(_from: Node2D = null) -> FireKnight:
	var b: FireKnight = FireKnight.new()
	b.setup(self, "blue")
	var side := _spawn_side(-mera.facing, 960.0 + 160.0)
	b.position = Vector2(clampf(cam_x + side * (960.0 + 160.0), Levels.EDGE, map_w - Levels.EDGE), GROUND_Y)
	b.facing = -side
	world.add_child(b)
	blues.append(b)
	blues_spawned += 1
	return b


func on_knight_defeated(k: Node2D) -> void:
	if k.variant == "blue":
		_blue_defeated(k)
		return
	defeated += 1
	var sp: Pickup = Pickup.new()
	sp.setup(self, "sphere", k.global_position + Vector2(0, -10), 10.0)    # Fire Knight: +10 % rage
	world.add_child.call_deferred(sp)
	if randf() < 0.35:
		var po: Pickup = Pickup.new()
		po.setup(self, "potion", k.global_position + Vector2(-k.facing * 90.0, 0))
		world.add_child.call_deferred(po)
	knight = null
	knight_timer = 2.0
	Sfx.play("boom", 1.6, -8.0)


## the two independent rolls -> what a Blue Knight drops
func blue_drops(r_stamina: float, r_max: float) -> Array:
	var out: Array = []
	if r_stamina < Tuning.BLUE_STAMINA_P:
		out.append("stamina")
	if r_max < Tuning.BLUE_MAX_P:
		out.append("stamina_max")
	return out


## Blue Knight drops: a small red sphere (+4 % rage) always; rolled independently: 35 % a blue +30 stamina potion,
## 10 % a blue-and-white +5 max-stamina potion
func _blue_defeated(k: Node2D) -> void:
	defeated += 1
	blues.erase(k)
	var p: Vector2 = k.global_position
	var sp: Pickup = Pickup.new()
	sp.setup(self, "sphere", p + Vector2(0, -10), float(Tuning.BLUE["rage"]))
	world.add_child.call_deferred(sp)
	var off := -60.0
	for kind in blue_drops(drop_rng.randf(), drop_rng.randf()):
		var po: Pickup = Pickup.new()
		po.setup(self, kind, p + Vector2(k.facing * off, 0))
		world.add_child.call_deferred(po)
		off = -off
	Sfx.play("boom", 2.0, -10.0)


func _manage_potions() -> void:
	var x := mera.global_position.x
	if x > potion_next_r:
		potion_next_r += POTION_EVERY
		_drop_potion(cam_x + 960.0 + 200.0)
	elif x < potion_next_l:
		potion_next_l -= POTION_EVERY
		_drop_potion(cam_x - 960.0 - 200.0)


func _drop_potion(x: float) -> void:
	if x < Levels.EDGE or x > map_w - Levels.EDGE:
		return
	var n := 0
	for c in world.get_children():
		if c is Pickup and c.kind == "potion":
			n += 1
	if n >= 2:
		return
	var po: Pickup = Pickup.new()
	po.setup(self, "potion", Vector2(x, GROUND_Y))
	world.add_child(po)


func collect(p: Pickup) -> void:
	if p.kind == "potion":
		mera.potions += 1
		Sfx.play("potion")
	elif p.kind == "stamina":
		mera.add_stamina(Tuning.STAMINA_POTION)
		Sfx.play("potion", 1.3)
		hud.flash("pickup:+30 stamina")
	elif p.kind == "stamina_max":
		var before := mera.stamina_max
		mera.add_stamina_max(Tuning.STAMINA_MAX_POTION)
		Sfx.play("potion", 1.6)
		hud.flash("pickup:+5 max stamina (%d)" % int(mera.stamina_max) if mera.stamina_max > before else "pickup:max stamina is already 120")
	else:
		mera.add_rage(p.value)
		Sfx.play("sphere")
	on_potions_changed()


func on_potions_changed() -> void:
	if hud:
		hud.queue_redraw_all()


func flash_hud(what: String) -> void:
	hud.flash(what)


# ---------------------------------------------------------------- spells
func spawn_bolt(_m: Node, p: Vector2, d: int, s: float, dmg: bool, speed_mult: float = 1.0) -> void:
	var sh := Shot.new()
	sh.setup(self, "bolt", p, d, s, {}, dmg)
	sh.speed_mult = speed_mult
	world.add_child(sh)


func spawn_fireball(_m: Node, p: Vector2, d: int, s: float, shot: Dictionary, dmg: bool) -> void:
	var sh := Shot.new()
	sh.setup(self, "fireball", p, d, s, shot, dmg)
	world.add_child(sh)


func explode(p: Vector2, s: float, dmg: bool) -> void:
	var b := Blast.new()
	b.setup("explosion", p, s)
	world.add_child(b)
	shake(10.0 + 3.0 * s, 0.35)            # rear explosion: screen shake on detonation
	Sfx.play("boom")
	if dmg:
		var r := Rect2(p.x - 50.0 * s, p.y - 90.0 * s, 100.0 * s, 90.0 * s)
		for e in enemies():
			if r.intersects(e.hurt_rect()):
				mera.deal(e, 3, p.x, "explosion")


func call_lightning(m: Mera) -> void:
	var s := m.shown
	var x := m.global_position.x + m.facing * 160.0 * s
	for e in enemies():
		if absf(e.global_position.x - m.global_position.x) < 1100.0:
			x = e.global_position.x
	x = clampf(x, cam_x - 900.0, cam_x + 900.0)  # keep the strike on screen at big sizes
	var b := Strike.new()                    # tessellated: ground impact + segments up past the screen top
	world.add_child(b)
	b.setup(self, Vector2(x, GROUND_Y), s)
	last_strike = b
	var e2 := Blast.new()
	e2.setup("electro", Vector2(x, GROUND_Y), s)
	world.add_child(e2)
	shake(8.0 + 2.0 * s, 0.3)
	Sfx.play("thunder")
	var top := cam.position.y - 540.0 - Strike.MARGIN
	var r := Rect2(x - 40.0 * s, top, 80.0 * s, GROUND_Y + 10.0 - top)
	for e in enemies():
		if r.intersects(e.hurt_rect()):
			m.deal(e, 3, x, "lightning")


func hit_spark(p: Vector2, s: float) -> void:
	var b := Blast.new()
	b.setup("spark", p, s)
	world.add_child(b)


# ---------------------------------------------------------------- v0.5 earthquake
## Down+Y while crouching: the ground shakes for QUAKE_S (very fast, violent shake of the whole map). Every enemy
## touching the ground at any moment of the quake is stunned until QUAKE_STUN_S after the quake started.
func earthquake() -> void:
	quake_t = Tuning.QUAKE_S
	quake_age = 0.0
	quaked = {}
	Sfx.play("boom_big", 0.5, 4.0)
	Sfx.play("thunder", 0.4, 2.0)


func _quake_tick(delta: float) -> void:
	if quake_t <= 0.0:
		return
	quake_t -= delta
	quake_age += delta
	shake(Tuning.QUAKE_SHAKE, 0.05)
	if int(quake_age * 60.0) % 6 == 0:
		for i in 2:                      # dust bursting out of the ground across the screen (visual only)
			var b := Blast.new()
			b.setup("explosion", Vector2(cam_x + randf_range(-960.0, 960.0), GROUND_Y + 6.0), randf_range(1.5, 2.6))
			b.modulate = Color(0.75, 0.62, 0.5, 0.8)
			world.add_child(b)
	for e in enemies():
		if quaked.has(e) or not is_instance_valid(e):
			continue
		if e.on_ground and e.has_method("stun"):
			quaked[e] = true
			e.stun(Tuning.QUAKE_STUN_S - quake_age)


# ---------------------------------------------------------------- game over / input
func _on_died() -> void:
	over = true
	over_t = 0.0


func restart() -> void:
	AnimLib.set_fury(false)
	Sfx.fury = false
	get_tree().reload_current_scene()


func to_menu() -> void:
	AnimLib.set_fury(false)
	Sfx.fury = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func next_level() -> void:
	Levels.current = (Levels.current + 1) % Levels.list().size()
	restart()


func _unhandled_input(event: InputEvent) -> void:
	if (over or cleared) and over_t > 1.0 and event.is_action_pressed("btn_b") and not event.is_echo():
		to_menu()
		return
	if cleared and over_t > 1.0 and (event.is_action_pressed("btn_a") or event.is_action_pressed("start")) and not event.is_echo():
		next_level()
		return
	if event.is_action_pressed("start") and not event.is_echo():
		if over and over_t > 1.0:
			restart()
		else:
			hud.overlay = not hud.overlay
	elif event.is_action_pressed("select") and not event.is_echo() and not over:
		mera.gallery_toggle()
	elif event.is_action_pressed("debug") and not event.is_echo():
		mera.debug = not mera.debug
	elif event.is_action_pressed("size_up") and mera.debug and not event.is_echo():
		mera.set_size(mera.size + 1)
	elif event.is_action_pressed("size_down") and mera.debug and not event.is_echo():
		mera.set_size(mera.size - 1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F11:
				var w := get_window()
				w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
			KEY_ESCAPE:
				if get_window().mode == Window.MODE_FULLSCREEN:
					get_window().mode = Window.MODE_WINDOWED
				else:
					get_tree().quit()


func _draw_debug() -> void:
	if not mera.debug:
		return
	var o := Vector2.ZERO
	debug_draw.draw_rect(mera.hurt_rect(), Color(0.2, 0.8, 1.0, 0.9), false, 2.0)
	var h := mera.hit_rect()
	if h.size != Vector2.ZERO:
		debug_draw.draw_rect(h, Color(1, 0.2, 0.2, 0.9), false, 3.0)
	for e in enemies():
		debug_draw.draw_rect(e.hurt_rect(), Color(0.2, 0.8, 1.0, 0.9), false, 2.0)
		if not (e.hitbox.get_child(0) as CollisionShape2D).disabled:
			debug_draw.draw_rect(e.attack_rect(), Color(1, 0.5, 0.1, 0.9), false, 3.0)
	debug_draw.draw_line(Vector2(cam_x, 0) + o, Vector2(cam_x, 1080), Color(1, 1, 0, 0.3), 2.0)


func _exit_tree() -> void:
	SegStrip.drain.call_deferred()
