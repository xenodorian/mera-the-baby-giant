extends Node2D
## Playable test level: an endless looping cemetery (ansimuz, blurred seams), Mera with every pack + canon
## animation, one Fire Knight at a time, potions, rage spheres, Fury mode, HUD, Game Over.
## Rules: docs/GAME_RULES.md. Controls: docs/CONTROLS.md.
##
## Command-line options (after "--"):
##   --size=N  --rage=N  --potions=N  --fury  --no-knight  --debug  --gallery=KEY  --overlay
##   --demo           play the scripted demo input (used for the gameplay capture)
##   --shot=PATH      save a PNG after --wait frames (default 60), then quit
##   --shots=PREFIX   with --demo: save PREFIX_<frame>.png at the frames listed by --at=f1,f2,...
##   --quit=N         quit after N frames

const GROUND_Y := 1060.0
const ART := 5
const LOOP_W := 384 * ART
# v0.3.1: the camera is hard-locked horizontally on Mera's feet pivot, with no look-ahead and no smoothing, so turning
# around never shifts the view and fast moves never drift. Vertical stays fixed (the level is one screen tall).
const KNIGHT_GAP := 480.0     # new knights appear this far past the screen edge, ahead of Mera
const POTION_EVERY := 2600.0  # a potion appears on the ground ahead for every 2600 px of new ground

var mera: Mera
var cam: Camera2D
var cam_x := 960.0
var knight: Node2D = null
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


func _ready() -> void:
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
	var dir := "res://assets/environments/ansimuz/gothicvania-cemetery/loop/"
	for layer in [["far_loop.png", 0.5, -20], ["near_loop.png", 1.0, -10]]:
		var p := Parallax2D.new()
		p.scroll_scale = Vector2(layer[1], 1.0)
		p.repeat_size = Vector2(LOOP_W, 0)
		p.repeat_times = 3
		p.z_index = layer[2]
		var s := Sprite2D.new()
		s.texture = load(dir + String(layer[0]))
		s.centered = false
		s.scale = Vector2(ART, ART)
		p.add_child(s)
		add_child(p)


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
	if over:
		over_t += delta
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
	cam_x = mera.global_position.x
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
	cam.position = Vector2(roundf(cam_x), 540)


func camera_x() -> float:
	return cam_x


func shake(amount: float, t: float) -> void:
	shake_amt = maxf(shake_amt, amount)
	shake_t = maxf(shake_t, t)


# ---------------------------------------------------------------- enemies
func enemies() -> Array:
	if knight != null and is_instance_valid(knight) and knight.alive():
		return [knight]
	return []


func _spawn_knight(side: int = 0) -> void:
	if side == 0:
		side = mera.facing
	if knight != null and is_instance_valid(knight):
		knight.queue_free()
	var k: Node2D = load("res://scripts/game/fire_knight.gd").new()
	k.game = self
	k.position = Vector2(cam_x + side * (960.0 + KNIGHT_GAP), GROUND_Y)
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
	# off-screen and left far behind -> replace him with a new one ahead of Mera
	if knight.alive():
		var off_screen := absf(knight.global_position.x - cam_x) > 960.0 + 120.0
		if off_screen and absf(knight.global_position.x - mera.global_position.x) > 1920.0 * 1.25:
			knight.queue_free()
			knight = null
			knight_timer = 0.0


func on_knight_defeated(k: Node2D) -> void:
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


func _manage_potions() -> void:
	var x := mera.global_position.x
	if x > potion_next_r:
		potion_next_r += POTION_EVERY
		_drop_potion(cam_x + 960.0 + 200.0)
	elif x < potion_next_l:
		potion_next_l -= POTION_EVERY
		_drop_potion(cam_x - 960.0 - 200.0)


func _drop_potion(x: float) -> void:
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
func spawn_bolt(_m: Node, p: Vector2, d: int, s: float, dmg: bool) -> void:
	var sh := Shot.new()
	sh.setup(self, "bolt", p, d, s, {}, dmg)
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
				mera.deal(e, 3, p.x)


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
			m.deal(e, 3, x)


func hit_spark(p: Vector2, s: float) -> void:
	var b := Blast.new()
	b.setup("spark", p, s)
	world.add_child(b)


# ---------------------------------------------------------------- game over / input
func _on_died() -> void:
	over = true
	over_t = 0.0


func restart() -> void:
	AnimLib.set_fury(false)
	Sfx.fury = false
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
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
