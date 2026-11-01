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
##   --enemy=ID  --cards=a,b  --summon=ID   (v0.6/v0.7 captures: spawn an enemy, hold cards, summon an ally)

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
var open_picker_shot := false
var pause_shot := false
var shots_prefix := ""
var shot_at: Array = []
var wait_frames := 60
var quit_at := -1
var picker_cycle := false
var cli_cards := {}
var demo: Array = []
var _trace := OS.has_environment("MERA_TRACE")   # debug: print Mera's animation changes (demo tuning)
var _trace_k := ""
var defeated := 0
var last_strike: Node2D = null
var knight_calm_until := 0   # demo: frame before which the knight does not swing
var layers: Array = []             # [Sprite2D, scroll, period] parallax layers of the level map
var tile_surfaces: Array = []      # one-way tops: [x0, x1, y]
var map_w := 19200.0
var run_mode := false
var stage_n := 1
var run_seed := 1
var lives := 0
var quota := 3
var run_spawned := 0
var run_title := ""
var run_wiped := false
var _clear_saved := false
var cleared_stage := 0
var cleared := false
var quake_t := 0.0           # v0.5 earthquake: time left of the 1 s quake
var quake_age := 0.0
var quaked := {}             # enemies already stunned by the current quake
var exit_gate: Node2D
var test_mode_no_exit := false
# v0.6 roster (levels 2-4; scripts/game/roster.gd, monster.gd)
const MONSTER := preload("res://scripts/game/monster.gd")
const DRAGON := preload("res://scripts/game/dragon.gd")
var mobs: Array = []
var boss: Node2D = null
var boss_spawned := false
var boss_dead := false
var wave_i := 0
var wave_type_i := 0
var trickle_t := 8.0
var spawn_arg := ""
var last_up_bolt: Node2D = null   # v0.9.1 tests
var last_vbeam: Node2D = null
var pulses: Array = []
var behind_spawns: Array = []     # v0.9.1 monsters that came from behind Mera (tests)
# v0.7 allies (scripts/game/allies.gd, ally.gd, ally_card.gd, ally_picker.gd)
const ALLY := preload("res://scripts/game/ally.gd")
const CARD := preload("res://scripts/game/ally_card.gd")
var cards := {}               # ally id -> cards held
var allies_on: Array = []
var summons := 0
var picker: CanvasLayer
var card_nodes: Array = []          # --enemy=ID: one of that enemy ahead of Mera (screenshots)
# v0.8 (S4) impact pass, breakables, secrets, debris (scripts/game/props.gd, prop.gd, debris.gd, hit_stop.gd)
const PROP := preload("res://scripts/game/prop.gd")
const PULSE_FX := preload("res://scripts/game/pulse_wave.gd")   # v0.9.1
const VBEAM := preload("res://scripts/game/vbeam.gd")
var debris: Debris
var props: Array = []
var secrets_found := 0
var drops_made: Array = []           # [tier, kind] of every smart drop (tests)
var mark_lock := false
var marker: Node2D


func _ready() -> void:
	var forced_level := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			Levels.current = clampi(int(a.get_slice("=", 1)) - 1, 0, maxi(Levels.list().size() - 1, 0))
			forced_level = true
	if not test_mode and not forced_level:
		if carry.is_empty():
			_load_run()
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
	picker = load("res://scripts/game/ally_picker.gd").new()
	picker.game = self
	add_child(picker)
	marker = load("res://scripts/game/mark_slash.gd").new()
	marker.game = self
	add_child(marker)
	HitStop.clear()
	debris = Debris.new()
	debris.game = self
	debris.ground_y = GROUND_Y
	debris.lo_x = Levels.EDGE - 60.0
	debris.hi_x = map_w - Levels.EDGE + 60.0
	world.add_child(debris)
	_place_cards()
	_place_props()
	_parse_args()
	var had_carry := FileAccess.file_exists(Carry.PATH)
	Carry.ensure()
	if not test_mode:
		if carry.is_empty():
			_load_run()
		if had_carry:
			_apply_carry()
		elif not carry.is_empty():
			_apply_run(carry)
			_sync_carry()
		else:
			_sync_carry()
	for c in cli_cards:
		cards[c] = int(cli_cards[c])
	mera.set_size(mera.size, true)
	explored_max = mera.position.x
	explored_min = mera.position.x


func _build_background() -> void:
	if run_mode:
		RunMaps.build(self)
		exit_gate = load("res://scripts/game/exit_gate.gd").new()
		exit_gate.position = Vector2(map_w - Levels.EXIT_PAD, GROUND_Y)
		exit_gate.set("game", self)
		exit_gate.z_index = -5
		add_child(exit_gate)
		return
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
	exit_gate.set("game", self)
	exit_gate.z_index = -5
	add_child(exit_gate)
	tile_surfaces = lv.get("surfaces", [])
	_start_music(lv)


func _start_music(lv: Dictionary) -> void:
	if test_mode or not lv.has("music"):
		return
	var stream: AudioStream = load(String(lv["music"]))
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -8.0
	add_child(player)
	player.play()


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
			mera.gallery_dev = true
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
		elif a.begins_with("--summon="):         # --summon=dancer: that ally comes at once (capture / smoke tests)
			cards[v] = int(cards.get(v, 0)) + 1
			summon_type.call_deferred(v)
		elif a.begins_with("--cards="):          # --cards=priestess,ranger (capture / testing)
			for c in v.split(","):
				if c == "":
					continue
				cards[c] = int(cards.get(c, 0)) + 1
				cli_cards[c] = cards[c]
		elif a == "--open-picker":
			open_picker_shot = true
		elif a == "--picker-cycle":
			picker_cycle = true
		elif a == "--hold=right":
			mera.forced["right"] = true
		elif a == "--pause":
			pause_shot = true
		elif a.begins_with("--x="):
			mera.position.x = float(v)
		elif a.begins_with("--enemy="):
			spawn_arg = v
		elif a == "--demo":
			demo = load("res://scripts/game/demo.gd").STEPS.duplicate()
	if shot_path != "" or picker_cycle or quit_at > 0:
		process_mode = Node.PROCESS_MODE_ALWAYS


# ---------------------------------------------------------------- frame
func _physics_process(delta: float) -> void:
	_menu_guard_tick()
	_impact_tick()
	frame_n += 1
	_run_demo()
	mera.ground_y = surface_under(mera.global_position, mera.ground_y)
	if _trace and (mera.anim.key != _trace_k or (frame_n >= int(OS.get_environment("MERA_TRACE")) and frame_n < int(OS.get_environment("MERA_TRACE")) + 80)):
		_trace_k = mera.anim.key
		print("TRACE %d %s size=%d x=%.0f face=%d rage=%.0f" % [frame_n, _trace_k, mera.size, mera.global_position.x, mera.facing, mera.rage])
	if not test_mode and not mark_lock:
		if run_mode:
			_manage_run()
		elif Roster.LEVELS.has(Levels.current):
			_manage_roster(delta)
		else:
			_manage_knight(delta)
		_manage_potions()
	if over or cleared:
		over_t += delta
	_quake_tick(delta)
	debug_draw.queue_redraw()


func _process(_delta: float) -> void:
	if open_picker_shot and frame_n >= 5 and picker != null and not picker.open:
		open_picker_shot = false
		summon_ally()
	if picker_cycle and picker != null:
		if frame_n == 8 and not picker.open:
			summon_ally()
		if picker.open and frame_n > 30 and frame_n < 230 and frame_n % 45 == 0:
			picker.move(1)
		if frame_n == 240 and picker.open:
			picker.close()
			_line_up_cards()
	if pause_shot and frame_n >= 8 and not paused_play:
		pause_shot = false
		toggle_pause()
	if shot_path != "" and frame_n >= wait_frames:
		_save(shot_path)
		get_tree().quit()
		shot_path = ""
	if shots_prefix != "" and frame_n in shot_at:
		_save("%s_%04d.png" % [shots_prefix, frame_n])
		shot_at.erase(frame_n)
	if quit_at > 0 and frame_n >= quit_at:
		get_tree().quit()
	if not test_mode and not over:
		_save_t += _delta
		if _save_t >= 2.0:
			_save_t = 0.0
			if not run_mode:
				_bank(false)


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
	for e in mobs:
		if is_instance_valid(e) and e.alive():
			out.append(e)
	return out


## v0.8: everything Mera's attacks can hit: live enemies + hittable props near the screen (breakables, levers ...)
func targets() -> Array:
	var out := enemies()
	for p in props:
		if is_instance_valid(p) and p.alive() and absf(p.global_position.x - cam_x) < 1500.0:
			out.append(p)
	return out


## the first breakable a projectile's rect touches (bolts, arrows, enemy shots, dragon bolts)
func prop_at(r: Rect2) -> Node2D:
	for p in props:
		if is_instance_valid(p) and p.alive() and r.intersects(p.hurt_rect()):
			return p
	return null


# ---------------------------------------------------------------- v0.8 props, secrets, smart drops
func _place_props() -> void:
	var cards_by_i := {}
	var lv_cards: Array = Allies.CARDS.get(Levels.current, [])
	for c in card_nodes:
		for i in lv_cards.size():
			if absf(float(lv_cards[i][0]) - c.global_position.x) < 1.0:
				cards_by_i[i] = c
	var doors := {}
	for it in Props.layout(_layout_level(), map_w):
		var pr: Node2D = PROP.new()
		pr.setup(self, String(it[0]), float(it[1]), it[2])
		world.add_child(pr)
		props.append(pr)
		var ex: Dictionary = it[2]
		if ex.has("card") and cards_by_i.has(int(ex["card"])):
			var cd: Node2D = cards_by_i[int(ex["card"])]
			pr.card = cd
			if pr.kind == "ledge":
				cd.base_y = pr.top_y - 40.0            # on the ledge: reached by the crumbling step (or flight, or a big Mera)
			else:
				cd.hidden_by = pr                      # behind the cracked wall / the door
		if pr.kind == "door":
			doors[float(it[1])] = pr
	for pr in props:
		if pr.kind == "lever":
			pr.door = doors.get(float(pr.extra["door_x"]), null)


## a secret wall broke / a door opened: its card can be taken
func reveal_secret(pr: Node2D) -> void:
	secrets_found += 1
	if pr.card != null and is_instance_valid(pr.card):
		pr.card.hidden_by = null
	Sfx.play("sphere", 0.6)
	hud.flash("pickup:secret found!")


## v0.8 one-way platforms (crumbling steps, card ledges): the surface Mera stands on or will land on at `p`
func surface_under(p: Vector2, cur: float) -> float:
	var best := GROUND_Y
	for pr in props:
		if not is_instance_valid(pr) or not pr.has_method("solid") or not pr.solid():
			continue
		var s3: Vector3 = pr.surface()
		if p.x >= s3.x and p.x <= s3.y and p.y <= s3.z + 2.0 and s3.z < best:
			best = s3.z
	for s in tile_surfaces:
		var x0 := float(s[0])
		var x1 := float(s[1])
		var y := float(s[2])
		if p.x >= x0 and p.x <= x1 and p.y <= y + 8.0 and y < best:
			best = y
	return best


## v0.8 drop table that favours what Mera is low on (size -> green potion, stamina -> blue potion, rage -> sphere)
func need_weights() -> Dictionary:
	var m := mera
	var size_need := clampf(float(Mera.SIZE_HEAL_MAX - m.size) / 5.0, 0.0, 1.0) * (1.0 if m.potions < 2 else 0.35)
	var st_need := clampf(1.0 - m.stamina / maxf(m.stamina_max, 1.0), 0.0, 1.0)
	var rage_need := 0.0 if m.fury else clampf(1.0 - m.rage / 100.0, 0.0, 1.0) * 0.7
	return {"potion": 0.12 + size_need, "stamina": 0.12 + st_need, "sphere": 0.12 + rage_need}


func _pick(w: Dictionary) -> String:
	var tot := 0.0
	for kk in w:
		tot += float(w[kk])
	var r := drop_rng.randf() * tot
	for kk in w:
		r -= float(w[kk])
		if r <= 0.0:
			return kk
	return w.keys()[0]


func smart_drop(p: Vector2, tier: String) -> Array:
	var out: Array = []
	if drop_rng.randf() > float(Props.DROP_P.get(tier, 1.0)):
		return out
	var w := need_weights()
	if tier == "small":
		w["potion"] = float(w["potion"]) * 0.25        # candles rarely drop a whole potion
	var first := _pick(w)
	out.append(first)
	if tier == "big":
		w.erase(first)
		out.append(_pick(w))
		if drop_rng.randf() < 0.15:
			out.append("stamina_max")
	var off := -50.0 * (out.size() - 1) / 2.0
	for kd in out:
		var pk: Pickup = Pickup.new()
		var v := -1.0
		if kd == "sphere":
			v = 4.0 if tier == "small" else 8.0
		elif kd == "stamina":
			v = 12.0 if tier == "small" else Tuning.STAMINA_POTION
		pk.setup(self, kd, Vector2(p.x + off, GROUND_Y) if kd != "sphere" else p + Vector2(off, 0), v)
		world.add_child.call_deferred(pk)
		drops_made.append([tier, kd])
		off += 50.0
	return out


## an explosive barrel went off at c: fixed damage + launch in a radius (kind "explosion" pierces the Fire Knight's
## block), other props caught in it react (barrels chain, chandeliers drop, breakables break). Mera is not hurt.
func barrel_blast(c: Vector2, src: Node2D) -> void:
	shake(22.0, 0.45)
	HitStop.stop(Tuning.HITSTOP_HEAVY_MS)
	Sfx.play("boom_big", 0.9)
	var b := Blast.new()
	b.setup("explosion", Vector2(c.x, GROUND_Y), 4.0)
	world.add_child(b)
	debris.spark(c, 5.0)
	for e in enemies():
		var ec: Vector2 = e.hurt_rect().get_center()
		if ec.distance_to(c) <= Props.BARREL_R + e.hurt_rect().size.x * 0.4:
			e.take_damage(Props.BARREL_DMG, c.x, "explosion")
	_blast_props(c, Props.BARREL_R, src)


func _blast_props(c: Vector2, r: float, src: Node2D) -> void:
	for pr in props:
		if pr == src or not is_instance_valid(pr) or not pr.alive():
			continue
		var pc: Vector2 = pr.hurt_rect().get_center()
		var reach := r * (1.8 if pr.kind == "chandelier" else 1.0)
		if absf(pc.x - c.x) <= reach and (pr.kind == "chandelier" or pc.distance_to(c) <= reach):
			pr.blast_hit(Props.BARREL_CHAIN_S)


## Q+W+1+2 at 100 rage: freeze the world and mark up to 9 nearest enemies. Costs 100. Does not start Fury.
func begin_mark() -> bool:
	if mark_lock or marker == null:
		return false
	var pool: Array = enemies()
	if pool.is_empty():
		return false
	pool.sort_custom(func(a, b): return mera.global_position.distance_squared_to(a.global_position) < mera.global_position.distance_squared_to(b.global_position))
	if pool.size() > 9:
		pool = pool.slice(0, 9)
	Controls.clear_gestures()
	marker.open(pool, Controls.prompt_arrows())
	mark_lock = true
	world.process_mode = Node.PROCESS_MODE_DISABLED
	return true


func end_mark() -> void:
	mark_lock = false
	if world:
		world.process_mode = Node.PROCESS_MODE_INHERIT


# ---------------------------------------------------------------- v0.6 roster
## one roster enemy at x (opts: variant, seed)
func spawn_enemy(eid: String, x: float, opts: Dictionary = {}) -> Node2D:
	var e: Node2D = (DRAGON if eid == "dragon" else MONSTER).new()     # v0.8: the dragon has its own boss script
	e.setup(self, eid, clampf(x, Levels.EDGE, map_w - Levels.EDGE), opts)
	e.facing = -1 if x > mera.global_position.x else 1
	world.add_child(e)
	mobs.append(e)
	if e.boss:
		boss = e
		boss_spawned = true
	return e


## waves every WAVE_EVERY px, cycling through the level's list so every enemy type shows up; a trickle when the
## screen stays empty; the boss (Infernal Caverns: the dragon) in front of the exit
func _manage_roster(delta: float) -> void:
	for e in mobs.duplicate():
		if not is_instance_valid(e):
			mobs.erase(e)
		elif e.alive() and not e.boss and absf(e.global_position.x - mera.global_position.x) > 1920.0 * 1.6:
			mobs.erase(e)
			e.queue_free()
	if over:
		return
	if spawn_arg != "":
		spawn_enemy(spawn_arg, mera.global_position.x + mera.facing * 700.0)
		spawn_arg = ""
	var list: Array = Roster.LEVELS[Levels.current]
	var alive := 0
	for e in mobs:
		if is_instance_valid(e) and e.alive():
			alive += 1
	var wx := Roster.WAVE_FIRST + wave_i * Roster.WAVE_EVERY
	if wx < map_w - Roster.BOSS_AT and mera.global_position.x > wx - 900.0:
		var n: int = Roster.WAVE_SIZES[wave_i % Roster.WAVE_SIZES.size()]
		var behind: bool = wave_i in Roster.BEHIND_WAVES.get(Levels.current, [])
		wave_i += 1
		var jf := 0                                   # slots ahead / behind are numbered separately
		for j in n:
			if alive >= Roster.MAX_ALIVE:
				break
			if _spawn_next(list, jf, behind):
				behind = false                         # one walker per listed wave comes from behind
			else:
				jf += 1
			alive += 1
	trickle_t -= delta
	if not _waves_done() and alive == 0 and trickle_t <= 0.0:
		_spawn_next(list, 0)
		trickle_t = 8.0
	elif alive > 0:
		trickle_t = maxf(trickle_t, 5.0)
	if Roster.BOSSES.has(Levels.current) and not boss_spawned and mera.global_position.x > map_w - Roster.BOSS_AT:
		spawn_enemy(Roster.BOSSES[Levels.current], map_w - Roster.BOSS_X)
		Sfx.play("boom_big", 0.6)


## the current level's roster list (tests)
func Roster_list() -> Array:
	return Roster.LEVELS[Levels.current]


## returns true when this one came from behind Mera (v0.9.1: `behind` asks for it; risers never do)
func _spawn_next(list: Array, j: int, behind: bool = false) -> bool:
	var eid: String = list[wave_type_i % list.size()]
	wave_type_i += 1
	var riser: bool = Roster.def(eid).has("spawn")
	var back := behind and not riser and String(Roster.def(eid).get("ai", "")) != "turret"   # it has to walk in
	var side := _spawn_side(-mera.facing if back else mera.facing, 960.0 + 200.0)
	back = back and side == -mera.facing    # no room behind (map end): it comes from ahead as before
	var x := cam_x + side * (960.0 + 200.0 + (0 if back else j) * 240.0)
	if riser:                               # risers (skeleton, Death) climb out of the ground on screen
		x = mera.global_position.x + side * (520.0 + j * 200.0)
	var e := spawn_enemy(eid, x)
	if back:
		behind_spawns.append({"id": eid, "x": x, "mera_x": mera.global_position.x, "facing": mera.facing, "level": Levels.current, "node": e})
	return back


## v0.9.4: one drop. sphere / green potion / blue stamina are common; +5 max stamina and +5 max rage are rare.
func enemy_loot_kind(roll: float) -> String:
	var x := clampf(roll, 0.0, 0.999999) * 100.0
	var acc := 0.0
	for row in Tuning.ENEMY_LOOT:
		acc += float(row[1])
		if x < acc:
			return String(row[0])
	return "sphere"


func _spawn_loot(kind: String, p: Vector2, rage_v: float) -> void:
	var po: Pickup = Pickup.new()
	po.setup(self, kind, p, rage_v if kind == "sphere" else -1.0)
	world.add_child.call_deferred(po)


func on_enemy_defeated(e: Node2D) -> void:
	defeated += 1
	mobs.erase(e)
	var p: Vector2 = Vector2(e.global_position.x, GROUND_Y)
	_spawn_loot(enemy_loot_kind(drop_rng.randf()), p + Vector2(0, -10), float(Roster.def(e.id)["rage"]))
	if e == boss:
		boss_dead = true
		shake(24.0, 0.8)
		Sfx.play("boom_big", 0.5)
	else:
		Sfx.play("boom", 1.8, -10.0)


# ---------------------------------------------------------------- v0.7 allies
func _layout_level() -> int:
	if run_mode:
		var cycle := [0, 1, 2, 4]
		return cycle[posmod(stage_n - 1, cycle.size())]
	return Levels.current


func _place_cards() -> void:
	return
	var idx := _layout_level()
	for pair in Allies.CARDS.get(idx, []):
		var c: Node2D = CARD.new()
		c.setup(self, String(pair[1]), Vector2(float(pair[0]), GROUND_Y - 40.0))
		world.add_child(c)
		card_nodes.append(c)


func collect_card(c: Node2D) -> void:
	Carry.ensure()
	if Carry.give_card(c.ally_id):
		cards = Carry.cards.duplicate(true)
		Sfx.play("sphere", 0.8)
		hud.flash("pickup:%s card  (R1: summon)" % Allies.NAMES[c.ally_id])
	else:
		Carry.add_gold(1)
		hud.flash("pickup:card slots full  +1 gold")
	card_nodes.erase(c)
	if not run_mode:
		_bank(false)


func allies() -> Array:
	var out: Array = []
	for a in allies_on:
		if is_instance_valid(a) and a.alive():
			out.append(a)
	return out


## the dancing girl while she is out (not leaving). Enemies come watch instead of swinging into her.
func dancer() -> Node2D:
	for a in allies():
		if a.id == "dancer" and a.state != "leave" and a.state != "dead":
			return a
	return null


## the brawler while she is out (monster.gd: non-boss enemies chase her instead of Mera)
func brawler() -> Node2D:
	for a in allies():
		if a.id == "brawler" and a.alive() and a.state != "leave" and a.state != "dead":
			return a
	return null


## card types that can be summoned now (held, and that ally isn't already on the field)
func summonable() -> Array:
	var out: Array = []
	var here := {}
	for a in allies():
		if a.state != "leave":
			here[a.id] = true
	for aid in Allies.IDS:
		if int(cards.get(aid, 0)) > 0 and not here.has(aid):
			out.append(aid)
	return out


## R1 (mera.gd): one type -> summon it; several -> the picker; none -> false (fail cue)
func summon_ally() -> bool:
	var ch := summonable()
	var active := 0
	for a in allies():
		if a.state != "leave":
			active += 1
	if ch.is_empty() or active >= Allies.MAX_ACTIVE:
		return false
	if ch.size() == 1:
		summon_type(ch[0])
	else:
		picker.show_choices(ch)
	return true


func summon_type(aid: String) -> Node2D:
	Carry.ensure()
	if not Carry.take_card(aid):
		return null
	cards = Carry.cards.duplicate(true)
	var a: Node2D = ALLY.new()
	a.setup(self, aid)
	world.add_child(a)
	allies_on.append(a)
	summons += 1
	Sfx.play("heal", 0.8)
	return a


func exit_locked() -> bool:
	if run_mode:
		return defeated < quota or _roster_threat()
	if not Roster.LEVELS.has(Levels.current):
		return knights_spawned < Roster.KNIGHT_CAP or _knight_fight_live()
	if Roster.BOSSES.has(Levels.current):
		return not boss_dead
	return not _waves_done() or _roster_threat()


## the scheduled waves have all been placed (the boss, if any, stands in the ground after that)
func _waves_done() -> bool:
	return Roster.WAVE_FIRST + float(wave_i) * Roster.WAVE_EVERY >= map_w - Roster.BOSS_AT


func _roster_threat() -> bool:
	for e in mobs:
		if is_instance_valid(e) and e.alive() and not e.boss:
			return true
	return false


func _knight_fight_live() -> bool:
	if knight != null and is_instance_valid(knight) and knight.alive():
		return true
	for b in blues:
		if is_instance_valid(b) and b.alive():
			return true
	return false


## tests: the level's fight is over, so the exit may open
func finish_endpoint() -> void:
	if Roster.BOSSES.has(Levels.current):
		boss_dead = true
		return
	if not Roster.LEVELS.has(Levels.current):
		knights_spawned = Roster.KNIGHT_CAP
		if knight != null and is_instance_valid(knight):
			knight.queue_free()
		knight = null
		blues.clear()
		return
	wave_i = 100
	for e in mobs.duplicate():
		if is_instance_valid(e) and not e.boss:
			e.queue_free()
	mobs = mobs.filter(func(e): return is_instance_valid(e) and e.boss)


func exit_lock_text() -> String:
	if Roster.BOSSES.has(Levels.current):
		return "SLAY THE DRAGON"
	if not Roster.LEVELS.has(Levels.current):
		return "SLAY THE KNIGHT"
	return "CLEAR THE ROAD"


func is_last_level() -> bool:
	return Levels.current >= Levels.list().size() - 1


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
		if knights_spawned >= Roster.KNIGHT_CAP:
			return
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
			if knights_spawned >= Roster.KNIGHT_CAP:
				return
			knight.queue_free()
			knight = null
			knight_timer = 0.0


## a side of the screen that still lies inside the map (near an end, enemies come in from the other side)
func _spawn_side(side: int, dist: float) -> int:
	var x := cam_x + side * dist
	if x < Levels.EDGE or x > map_w - Levels.EDGE:
		return -side
	return side


## invisible walls at both map ends, and cracked walls / closed doors in the level
func _clamp_to_map() -> void:
	var lo := Levels.EDGE
	var hi := map_w - Levels.EDGE
	mera.position.x = clampf(mera.position.x, lo, hi)
	_block_body(mera)
	for e in enemies():
		e.position.x = clampf(e.position.x, lo, hi)
		_block_body(e)
	for a in allies_on:
		if is_instance_valid(a):
			a.position.x = clampf(a.position.x, lo, hi)
			_block_body(a)
	if not cleared and not over and not test_mode_no_exit and not exit_locked() and mera.position.x >= map_w - Levels.EXIT_PAD - 40.0:
		cleared = true
		over_t = 0.0
		Sfx.play("potion", 0.7)
		if run_mode and not _clear_saved:
			cleared_stage = stage_n
			lives += 1
			stage_n += 1
			quota += 1
			_clear_saved = true
			_bank(false, true)


func _line_up_cards() -> void:
	var i := 0
	for c in card_nodes:
		if not is_instance_valid(c):
			continue
		c.hidden_by = null
		c.global_position = Vector2(cam_x - 420.0 + float(i) * 220.0, GROUND_Y - 40.0)
		c.base_y = GROUND_Y - 40.0
		i += 1


func _block_body(body: Node2D) -> void:
	if body == null or not is_instance_valid(body) or not body.has_method("hurt_rect"):
		return
	var prev := float(body.get_meta("_bx", body.global_position.x))
	var hr: Rect2 = body.hurt_rect()
	for pr in props:
		if not is_instance_valid(pr) or not pr.has_method("blocks_path") or not pr.blocks_path():
			continue
		var r: Rect2 = pr.hurt_rect()
		if hr.size.x < 1.0 or hr.size.y < 1.0 or hr.end.y <= r.position.y + 6.0 or hr.position.y >= r.end.y:
			continue
		var to_x := body.global_position.x
		var overlap := hr.intersects(r)
		var sweep_l := minf(hr.position.x, hr.position.x - (to_x - prev))
		var sweep_r := maxf(hr.end.x, hr.end.x - (to_x - prev))
		var crossed := sweep_r >= r.position.x and sweep_l <= r.end.x and absf(to_x - prev) > 0.25
		if not overlap and not crossed:
			continue
		var from_left := prev <= r.get_center().x
		var lead_r := hr.end.x - to_x
		var lead_l := to_x - hr.position.x
		if from_left:
			var nx := r.position.x - lead_r - 0.5
			if to_x > nx:
				body.position.x += nx - to_x
				_kill_x(body, 1)
		else:
			var nx2 := r.end.x + lead_l + 0.5
			if to_x < nx2:
				body.position.x += nx2 - to_x
				_kill_x(body, -1)
		hr = body.hurt_rect()
	body.set_meta("_bx", body.global_position.x)


func _kill_x(body: Node2D, dir: int) -> void:
	if body == mera:
		if (dir > 0 and mera.vel.x > 0.0) or (dir < 0 and mera.vel.x < 0.0):
			mera.vel.x = 0.0
		return
	if body.get("vx") != null:
		var vx := float(body.vx)
		if (dir > 0 and vx > 0.0) or (dir < 0 and vx < 0.0):
			body.vx = 0.0


func _manage_run() -> void:
	for e in mobs.duplicate():
		if not is_instance_valid(e):
			mobs.erase(e)
	if over or cleared or run_spawned >= quota:
		return
	var spacing := (map_w - 2800.0) / float(maxi(quota, 1))
	while run_spawned < quota:
		var x := 1600.0 + float(run_spawned) * spacing
		if mera.global_position.x < x - 1200.0:
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = stage_n * 1000 + run_spawned
		var pool: Array = Roster.RUN_POOL
		spawn_enemy(String(pool[rng.randi() % pool.size()]), x)
		run_spawned += 1


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
	_spawn_loot(enemy_loot_kind(drop_rng.randf()), k.global_position + Vector2(0, -10), 10.0)
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


## one roll from the same table as every other enemy. A sphere still grants this knight's small rage value.
func _blue_defeated(k: Node2D) -> void:
	defeated += 1
	blues.erase(k)
	_spawn_loot(enemy_loot_kind(drop_rng.randf()), k.global_position + Vector2(0, -10), float(Tuning.BLUE["rage"]))
	Sfx.play("boom", 2.0, -10.0)


func _manage_potions() -> void:
	return
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


func _apply_carry() -> void:
	mera.potions = Carry.potions
	mera.mana_pots = Carry.mana_pots
	mera.stamina_max = Carry.stamina_max
	mera.stamina = clampf(Carry.stamina, 0.0, mera.stamina_max)
	mera.rage_max = Carry.rage_max
	mera.rage = clampf(Carry.rage, 0.0, mera.rage_max)
	cards = Carry.cards.duplicate(true)
	mera.set_size(mini(Carry.size, Carry.scale_cap), true)
	on_potions_changed()


func _sync_carry() -> void:
	if mera == null:
		return
	Carry.push_play({
		"potions": mera.potions,
		"mana_pots": mera.mana_pots,
		"cards": cards,
		"stamina": mera.stamina,
		"stamina_max": mera.stamina_max,
		"rage": mera.rage,
		"rage_max": mera.rage_max,
		"size": mera.size,
	})


## one item from a broken prop. Always 40% gold, 25% health potion, 25% mana potion, 10% card,
## even when the bar and the potion slots are already full. Fury orbs never come from these.
func break_drop(p: Vector2) -> void:
	Carry.ensure()
	var roll := drop_rng.randf()
	var kind := "coin"
	if roll < 0.40:
		kind = "coin"
	elif roll < 0.65:
		kind = "potion"
	elif roll < 0.90:
		kind = "mana"
	else:
		kind = "card"
	var po: Pickup = Pickup.new()
	po.setup(self, kind, Vector2(p.x, GROUND_Y - 10.0))
	if _sliding():
		collect(po)
		po.free()
		return
	world.add_child.call_deferred(po)


func _sliding() -> bool:
	return mera != null and is_instance_valid(mera) and mera.state == "move" and String(mera.mv.get("key", "")) == "slide"


func collect(p: Pickup) -> void:
	Carry.ensure()
	if p.kind == "potion":
		if mera.size < mera.scale_cap():
			mera.set_size(mera.size + 1)
			Sfx.play("heal")
			hud.flash("pickup:+1 size")
		elif Carry.give_potion():
			mera.potions = Carry.potions
			Sfx.play("potion")
			hud.flash("pickup:health potion stored  %d" % mera.potions)
		else:
			Carry.add_gold(1)
			hud.flash("pickup:potion slots full  +1 gold")
	elif p.kind == "mana":
		if mera.stamina < mera.stamina_max - 0.5:
			mera.add_stamina(Tuning.STAMINA_POTION)
			Sfx.play("heal", 1.15)
			hud.flash("pickup:+%d mana" % int(Tuning.STAMINA_POTION))
		elif Carry.give_mana():
			mera.mana_pots = Carry.mana_pots
			Sfx.play("potion", 1.3)
			hud.flash("pickup:mana potion stored  %d" % mera.mana_pots)
		else:
			Carry.add_gold(1)
			hud.flash("pickup:mana slots full  +1 gold")
	elif p.kind == "coin":
		Carry.add_gold(1)
		Sfx.play("potion", 1.2)
		hud.flash("pickup:gold  %d" % Carry.gold)
	elif p.kind == "card":
		var id := String(Carry.ALLIES[drop_rng.randi() % Carry.ALLIES.size()])
		if Carry.give_card(id):
			cards = Carry.cards.duplicate(true)
			Sfx.play("sphere", 0.8)
			hud.flash("pickup:%s card" % Allies.NAMES[id])
		else:
			Carry.add_gold(1)
			hud.flash("pickup:card slots full  +1 gold")
	elif p.kind == "stamina":
		var amt := p.value if p.value > 0.0 else Tuning.STAMINA_POTION
		mera.add_stamina(amt)
		Sfx.play("potion", 1.3)
		hud.flash("pickup:+%d mana" % int(amt))
	elif p.kind == "stamina_max":
		var before := mera.stamina_max
		mera.add_stamina_max(Tuning.STAMINA_MAX_POTION)
		Sfx.play("potion", 1.6)
		hud.flash("pickup:+5 max mana (%d)" % int(mera.stamina_max) if mera.stamina_max > before else "pickup:max mana is already %d" % int(Tuning.STAMINA_MAX_CAP))
	elif p.kind == "rage_max":
		var before_r := mera.rage_max
		mera.add_rage_max(Tuning.RAGE_MAX_POTION)
		Sfx.play("sphere", 1.3)
		hud.flash("pickup:+5 max rage (%d)" % int(mera.rage_max) if mera.rage_max > before_r else "pickup:max rage is already %d" % int(Tuning.RAGE_MAX_CAP))
	else:
		mera.add_rage(p.value)
		Sfx.play("sphere")
	on_potions_changed()
	_sync_carry()


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


## Up+Y: the same bolt, three of them, drawn twice as big. Straight up, and both upward diagonals.
func spawn_bolt_up(_m: Node, p: Vector2, s: float, dmg: bool) -> Node2D:
	var last: Node2D = null
	for aim in [Vector2(-0.7071, -0.7071), Vector2.UP, Vector2(0.7071, -0.7071)]:
		var sh := Shot.new()
		sh.up = true
		sh.aim = aim
		sh.bulk = 2.0
		sh.setup(self, "bolt", p, 1, s, {}, dmg)
		world.add_child(sh)
		last = sh
	last_up_bolt = last
	return last


## v0.9.1 Y Y Y, L2: every enemy within reach is pushed away from Mera (bosses stay put). Knockback only: no damage,
## no rage, no stun; a wind-up in progress is cancelled.
func pulse_wave(m: Mera) -> Array:
	var s := m.shown
	var c := m.global_position + Vector2(0, -30.0 * s)
	var reach := Tuning.PULSE_REACH * s / 2.0
	var pushed: Array = []
	var fx: Node2D = PULSE_FX.new()
	fx.setup(c, reach, s)
	world.add_child(fx)
	shake(5.0 + s, 0.15)
	Sfx.play("barrier", 0.7)
	for e in enemies():
		if not e.alive() or e.get("boss"):
			continue
		var d: Vector2 = e.hurt_rect().get_center() - c
		if absf(d.x) > reach or absf(d.y) > reach:
			continue
		var away := 1.0 if d.x >= 0.0 else -1.0
		var to := clampf(e.position.x + away * Tuning.PULSE_PUSH * s / 2.0, Levels.EDGE, map_w - Levels.EDGE)
		if e.has_method("_to_idle") and String(e.get("state")) in ["tell", "atk"]:
			e._to_idle(0.4)
		var tw: Tween = e.create_tween()
		tw.tween_property(e, "position:x", to, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pushed.append(e)
	pulses.append({"t": frame_n, "pushed": pushed.size(), "reach": reach})
	return pushed


## v0.9.1 Y Y Y, X: vertical anti-air beam from the raised wand
func vertical_beam(m: Mera, p: Vector2) -> Node2D:
	var b: Node2D = VBEAM.new()
	world.add_child(b)
	b.setup(self, p, m.shown)
	last_vbeam = b
	shake(4.0 + m.shown, 0.2)
	Sfx.play("beam", 1.2)
	return b


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
		for e in targets():
			if r.intersects(e.hurt_rect()):
				mera.deal(e, 3, p.x, "explosion")
		_blast_props(p + Vector2(0, -40.0 * s), 60.0 * s, null)


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
	for e in targets():
		if r.intersects(e.hurt_rect()):
			m.deal(e, 3, x, "lightning")


func hit_spark(p: Vector2, s: float) -> void:
	var b := Blast.new()
	b.setup("spark", p, s)
	world.add_child(b)
	if debris:
		debris.spark(p, s)


## v0.8 parry: a white-gold flash ring + sparks where the blow was turned aside
func parry_fx(p: Vector2, s: float) -> void:
	shake(7.0, 0.12)
	if debris:
		debris.spark(p, s * 2.0)
		debris.spark(p, s * 1.2)
	var b := Blast.new()
	b.setup("spark", p, s * 1.8)
	b.modulate = Color(1.6, 1.5, 1.0)
	world.add_child(b)
	hud.flash("parry")


# ---------------------------------------------------------------- v0.5 earthquake
## Down+Y while crouching: the ground shakes for QUAKE_S (very fast, violent shake of the whole map). Every enemy
## touching the ground at any moment of the quake is stunned until QUAKE_STUN_S after the quake started.
func earthquake() -> void:
	quake_t = Tuning.QUAKE_S
	quake_age = 0.0
	quaked = {}
	for pr in props:                        # v0.8: the quake shakes every chandelier on screen loose
		if is_instance_valid(pr) and pr.kind == "chandelier" and pr.alive() and absf(pr.global_position.x - cam_x) < 1100.0:
			pr.blast_hit(0.0)
	Sfx.play("boom_big", 0.5, 4.0)
	Sfx.play("thunder", 0.4, 2.0)


# ---------------------------------------------------------------- v0.8 SUPER EARTHQUAKE
var impact_t := 0.0             # impact frame time left (real time, counted per physics tick)
var super_on := false           # the running quake is the super one
var super_count := 0
var impact_layer: CanvasLayer
var impact_rect: ColorRect


## Down+Y crouching with a full meter (outside Fury): impact frame, then a 2 s super quake
func super_earthquake() -> void:
	super_count += 1
	impact_t = Tuning.IMPACT_FRAME_S
	HitStop.impact(Tuning.IMPACT_FRAME_S * 1000.0)
	_impact_show(true, 1.0)
	Sfx.play("thunder", 0.5, 6.0)
	Sfx.play("boom_big", 0.4, 6.0)


func _impact_show(on: bool, inv: float) -> void:
	if impact_layer == null:
		impact_layer = CanvasLayer.new()
		impact_layer.layer = 60
		impact_rect = ColorRect.new()
		impact_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		impact_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/impact_frame.gdshader")
		impact_rect.material = mat
		impact_layer.add_child(impact_rect)
		add_child(impact_layer)
	impact_layer.visible = on
	(impact_rect.material as ShaderMaterial).set_shader_parameter("invert", inv)


func _impact_tick() -> void:
	if impact_t <= 0.0:
		return
	impact_t -= 1.0 / float(Engine.physics_ticks_per_second)
	if impact_t <= Tuning.IMPACT_FRAME_S * 0.4:
		_impact_show(true, 0.0)              # second beat: plain black/white
	if impact_t <= 0.0:
		impact_t = 0.0
		_impact_show(false, 0.0)
		_super_quake_go()


func _super_quake_go() -> void:
	quake_t = Tuning.SUPER_QUAKE_S
	quake_age = 0.0
	quaked = {}
	super_on = true
	shake(Tuning.SUPER_QUAKE_SHAKE, 0.3)
	Sfx.play("boom_big", 0.45, 8.0)
	Sfx.play("thunder", 0.35, 6.0)
	for e in enemies():                     # flat damage to every enemy, the dragon's size pool included
		if is_instance_valid(e) and e.alive():
			e.take_damage(Tuning.SUPER_QUAKE_DMG, mera.global_position.x, "quake")
	for pr in props:                        # every ground breakable near the screen is destroyed (barrels chain)
		if not is_instance_valid(pr) or not pr.alive() or absf(pr.global_position.x - cam_x) > Tuning.SUPER_QUAKE_REACH:
			continue
		if pr.kind == "chandelier":
			pr.blast_hit(0.0)
		elif pr.kind != "lever":
			pr.take_damage(999, pr.global_position.x + randf_range(-40.0, 40.0), "explosion")


func _quake_tick(delta: float) -> void:
	if quake_t <= 0.0:
		return
	quake_t -= delta
	quake_age += delta
	shake(Tuning.SUPER_QUAKE_SHAKE if super_on else Tuning.QUAKE_SHAKE, 0.05)
	var stun_total := Tuning.SUPER_QUAKE_STUN_S if super_on else Tuning.QUAKE_STUN_S
	if quake_t <= 0.0:
		super_on = false
	if int(quake_age * 60.0) % (3 if super_on else 6) == 0:
		for i in (4 if super_on else 2):    # dust bursting out of the ground across the screen (visual only)
			var b := Blast.new()
			b.setup("explosion", Vector2(cam_x + randf_range(-960.0, 960.0), GROUND_Y + 6.0), randf_range(1.5, 2.6))
			b.modulate = Color(0.75, 0.62, 0.5, 0.8)
			world.add_child(b)
	for e in enemies():
		if quaked.has(e) or not is_instance_valid(e):
			continue
		if e.on_ground and e.has_method("stun"):
			quaked[e] = true
			e.stun(stun_total - quake_age)


# ---------------------------------------------------------------- game over / input
func _on_died() -> void:
	over = true
	over_t = 0.0
	if run_mode:
		if lives > 0:
			lives -= 1
			_bank(true, true)
		else:
			_wipe_run()
		return
	_bank(true)


var restart_requests := 0       # tests


static var carry: Dictionary = {}   # the run. Never wiped by death or the level select.
const RUN_PATH := "user://mera_run.json"
var _save_t := 0.0


## potions, cards, size, both meters and both max upgrades.
func _pack_run() -> Dictionary:
	return {
		"potions": mera.potions,
		"stamina": mera.stamina,
		"stamina_max": mera.stamina_max,
		"rage": mera.rage,
		"rage_max": mera.rage_max,
		"size": mera.size,
		"cards": cards.duplicate(true),
		"stage": stage_n,
		"lives": lives,
		"quota": quota,
		"seed": run_seed,
	}


func _apply_run(bag: Dictionary) -> void:
	mera.potions = int(bag.get("potions", mera.potions))
	mera.stamina_max = float(bag.get("stamina_max", mera.stamina_max))
	mera.stamina = clampf(float(bag.get("stamina", mera.stamina)), 0.0, mera.stamina_max)
	mera.rage_max = float(bag.get("rage_max", mera.rage_max))
	mera.rage = clampf(float(bag.get("rage", mera.rage)), 0.0, mera.rage_max)
	var saved_cards: Dictionary = bag.get("cards", {})
	var clean := {}
	for k in saved_cards:
		clean[String(k)] = int(saved_cards[k])
	cards = clean
	if bag.has("stage"):
		stage_n = maxi(int(bag["stage"]), 1)
		lives = maxi(int(bag.get("lives", 0)), 0)
		quota = maxi(int(bag.get("quota", Roster.RUN_START)), Roster.RUN_START)
	mera.set_size(int(bag.get("size", mera.size)), true)
	on_potions_changed()


func _bank(reset_size: bool, checkpoint := false) -> void:
	if test_mode or mera == null or run_wiped:
		return
	if run_mode and not checkpoint:
		return
	var bag := _pack_run()
	if reset_size:
		bag["size"] = 2
		mera.size = 2
	carry = bag
	var f := FileAccess.open(RUN_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(bag))
	_sync_carry()


func _load_run() -> void:
	if not FileAccess.file_exists(RUN_PATH):
		return
	var f := FileAccess.open(RUN_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary and not data.is_empty():
		carry = data


func held_run() -> Dictionary:
	return carry


func drop_run() -> void:
	carry = {}


func death_bag() -> Dictionary:
	var bag := _pack_run()
	bag["size"] = 2
	return bag


func _wipe_run() -> void:
	run_wiped = true
	carry = {}
	var abs_path := ProjectSettings.globalize_path(RUN_PATH)
	if FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)


func restart() -> void:
	if run_wiped:
		to_menu()
		return
	if not run_mode:
		_bank(true)
	restart_requests += 1
	HitStop.clear()
	AnimLib.set_fury(false)
	Sfx.fury = false
	paused_play = false
	var tree := get_tree()
	if tree == null or tree.current_scene == null:      # headless tests add the game under root by hand: nothing to reload
		return
	tree.paused = false
	tree.reload_current_scene.call_deferred()


func to_menu() -> void:
	if run_wiped:
		carry = {}
	elif not run_mode:
		_bank(over and not cleared)
	HitStop.clear()
	AnimLib.set_fury(false)
	Sfx.fury = false
	paused_play = false
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	tree.change_scene_to_file.call_deferred("res://scenes/menu.tscn")


func next_level() -> void:
	if not run_mode:
		_bank(false)
		if is_last_level():
			to_menu()
			return
		Levels.current += 1
	restart_requests += 1
	HitStop.clear()
	AnimLib.set_fury(false)
	Sfx.fury = false
	if get_tree().current_scene == null:
		return
	get_tree().reload_current_scene()


var _menu_pending := {}   # joypad Start/Select waiting out the trigger-collision guard (Controls.GUARD_FRAMES)


func _menu_guard_tick() -> void:
	if _menu_pending.is_empty():
		return
	var f: int = _menu_pending["f"]
	if Engine.get_physics_frames() - f < Controls.GUARD_FRAMES:
		return
	var a: String = _menu_pending["a"]
	_menu_pending = {}
	if Controls.trigger_near(f):
		menu_guard_drops += 1
		return
	_menu_action(a)


var menu_guard_drops := 0
var paused_play := false          # v0.9.1: Start freezes gameplay (the controls overlay stays up)


func toggle_pause() -> void:
	if picker != null and picker.open:
		return
	if over or cleared:
		return
	paused_play = not paused_play
	if hud:
		hud.pause_sel = 0
		if hud.pause_controls:
			hud.pause_controls = false
			hud.overlay = false
	get_tree().paused = paused_play


func _menu_action(a: String) -> void:
	if a == "start":
		if over and over_t > 1.0:
			restart()
		else:
			toggle_pause()
	elif a == "select" and not over:
		pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and (event.is_action_pressed("start") or event.is_action_pressed("select")) \
			and not cleared and not (over and over_t > 1.0 and event.is_action_pressed("start")):
		if not Controls.trigger_near(Engine.get_physics_frames()):
			_menu_pending = {"a": "start" if event.is_action_pressed("start") else "select", "f": Engine.get_physics_frames()}
		else:
			menu_guard_drops += 1
		return
	if (over or cleared) and over_t > 1.0 and event.is_action_pressed("btn_b") and not event.is_echo():
		to_menu()
		return
	if cleared and over_t > 1.0 and (event.is_action_pressed("btn_a") or event.is_action_pressed("start")) and not event.is_echo():
		next_level()
		return
	if over and not cleared and over_t > 1.0 and event.is_action_pressed("btn_a") and not event.is_echo():
		restart()                                   # v0.8: A (Z key) restarts too, like Start
		return
	if event.is_action_pressed("start") and not event.is_echo():
		if over and over_t > 1.0:
			restart()
		else:
			toggle_pause()
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
		var ar: Rect2 = e.attack_rect()
		if ar.size != Vector2.ZERO:
			debug_draw.draw_rect(ar, Color(1, 0.5, 0.1, 0.9), false, 3.0)
	debug_draw.draw_line(Vector2(cam_x, 0) + o, Vector2(cam_x, 1080), Color(1, 1, 0, 0.3), 2.0)


func _exit_tree() -> void:
	if paused_play and is_inside_tree():
		paused_play = false
		get_tree().paused = false
	SegStrip.drain.call_deferred()


## v0.9.1 projectile rules: a timed basic attack reflects foe shots; a player shot and a foe shot both explode;
## beams (the combo beam and the vertical beam) destroy foe shots. Called after Mera's hitboxes update.
func resolve_projectiles() -> void:
	if world == null or mera == null:
		return
	var foes: Array = []
	var friends: Array = []
	for n in world.get_children():
		if not is_instance_valid(n):
			continue
		if n is Shot and not n.done:
			friends.append(n)
		elif _live_foe_shot(n):
			foes.append(n)
	var beams: Array[Rect2] = []
	var br: Rect2 = mera.beam_world_rect()
	if br.size != Vector2.ZERO:
		beams.append(br)
	if last_vbeam != null and is_instance_valid(last_vbeam):
		var cr: Rect2 = last_vbeam.column()
		if cr.size.y > 8.0:
			beams.append(cr)
	var swinging := mera.swing_parry_open()
	var sword := mera.hit_rect() if swinging else Rect2()
	for f in foes:
		if not is_instance_valid(f) or not _live_foe_shot(f):
			continue
		var fr: Rect2 = f.rect()
		if swinging and sword.size != Vector2.ZERO and sword.intersects(fr):
			f.deflect()
			mera.swing_parries += 1
			parry_fx(fr.get_center(), mera.shown)
			continue
		var beamed := false
		for b in beams:
			if b.intersects(fr):
				_pop_foe(f)
				beamed = true
				break
		if beamed:
			continue
		for p in friends:
			if not is_instance_valid(p) or p.done:
				continue
			if p.hit_rect().intersects(fr):
				p.burst()
				_pop_foe(f)
				break


func _live_foe_shot(n: Node) -> bool:
	if not is_instance_valid(n) or not n.has_method("rect") or not n.has_method("deflect"):
		return false
	if n.get("deflected") == true or n.get("done") == true:
		return false
	var path := ""
	if n.get_script() != null:
		path = str(n.get_script().resource_path)
	return path.ends_with("enemy_shot.gd") or path.ends_with("dragon_bolt.gd")


func _pop_foe(n: Node) -> void:
	if is_instance_valid(n) and n.has_method("pop_clash"):
		n.pop_clash()
