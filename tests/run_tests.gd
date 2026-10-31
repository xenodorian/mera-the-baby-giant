extends SceneTree
## Headless tests: godot --headless --path . -s tests/run_tests.gd
## Each case loads the level (no enemy spawning unless the case asks for it), feeds scripted input to Mera
## frame by frame (60 physics ticks/s, the same path real input takes) and checks what she did.

var failures := 0
var passes := 0
var game: Node


func _initialize() -> void:
	_run.call_deferred()


func _tap(steps: Array, frame: int, action: String, hold: int = 3) -> void:
	steps.append([frame, action, true])
	steps.append([frame + hold, action, false])


func _new_game(knights: bool = false) -> Node:
	var g: Node = load("res://scenes/game.tscn").instantiate()
	g.test_mode = not knights
	root.add_child(g)
	await physics_frame
	return g


func _drive(g: Node, steps: Array, frames: int) -> void:
	var m: Node = g.mera
	for f in range(1, frames + 1):
		for st in steps:
			if int(st[0]) == f:
				m.forced[st[1]] = st[2]
		await physics_frame


func _has_seq(log: Array, want: Array) -> bool:
	var j := 0
	for k in log:
		if j < want.size() and k == want[j]:
			j += 1
	return j == want.size()


func _check(name: String, ok: bool, info: String = "") -> void:
	if ok:
		passes += 1
		print("PASS  ", name)
	else:
		failures += 1
		print("FAIL  ", name, "   ", info)


func _combo(name: String, steps: Array, frames: int, want: Array, forbid: Array = [], setup: Callable = Callable()) -> void:
	var g: Node = await _new_game()
	if setup.is_valid():
		setup.call(g)
	await _drive(g, steps, frames)
	var log: Array = g.mera.move_log
	var ok := _has_seq(log, want)
	for f in forbid:
		if f in log:
			ok = false
	_check(name, ok, "log=%s" % [log])
	g.queue_free()
	await process_frame


func _run() -> void:
	var s: Array
	# ---- X chains
	s = []; _tap(s, 5, "btn_x"); _tap(s, 18, "btn_x"); _tap(s, 31, "btn_x")
	await _combo("X X X from idle -> 1x, 2x, 2x-2", s, 150, ["atk1", "atk2", "atk2_2"], ["atk2_1", "atk3", "beam_ender"])
	s = [[5, "right", true], [70, "right", false]]; _tap(s, 20, "btn_x"); _tap(s, 33, "btn_x"); _tap(s, 46, "btn_x")
	await _combo("X X X while walking forward -> 1x, 2x, 2x-2", s, 160, ["walk", "atk1", "atk2", "atk2_2"], ["atk2_1"])
	s = []; _tap(s, 5, "btn_x"); _tap(s, 18, "btn_x"); _tap(s, 31, "btn_x", 40)
	await _combo("X X hold X -> 1x, 2x, 2x-1", s, 150, ["atk1", "atk2", "atk2_1"], ["atk2_2"])
	s = []; _tap(s, 5, "btn_x"); _tap(s, 18, "btn_x"); _tap(s, 40, "btn_y")
	await _combo("X X Y -> 1x, 2x, 3x", s, 150, ["atk1", "atk2", "atk3"], ["beam_ender", "quick_fire"])
	s = []; _tap(s, 5, "btn_x"); _tap(s, 18, "btn_x"); _tap(s, 31, "btn_x"); _tap(s, 45, "btn_y")
	await _combo("X X X Y -> 1x, 2x, beam combo", s, 150, ["atk1", "atk2", "beam_ender"], ["atk3", "atk2_2", "atk2_1"])
	s = []; _tap(s, 5, "btn_x"); _tap(s, 18, "btn_x"); _tap(s, 31, "btn_x"); _tap(s, 34, "btn_y")
	await _combo("X X X+Y (fast) -> beam combo", s, 150, ["atk1", "atk2", "beam_ender"], ["atk3"])
	for dy in [6, 10, 16]:     # human timing: Y 100-270 ms after the third X still gives the beam
		s = []; _tap(s, 5, "btn_x"); _tap(s, 18, "btn_x"); _tap(s, 31, "btn_x"); _tap(s, 31 + dy, "btn_y")
		await _combo("X X X Y (Y %d ms after the 3rd X) -> beam combo" % int(dy * 16.7), s, 170, ["atk1", "atk2", "beam_ender"], ["atk3"])
	for g2 in [[22, 30], [26, 36], [30, 38], [36, 46], [40, 44]]:
		s = []; _tap(s, 5, "btn_x"); _tap(s, 18, "btn_x"); _tap(s, g2[0], "btn_y"); _tap(s, g2[1], "btn_y")
		await _combo("X X Y Y (Y at f%d, f%d) -> 1x, 2x, 3x, never the beam" % g2, s, 170, ["atk1", "atk2", "atk3"], ["beam_ender"])
	s = []; _tap(s, 5, "btn_x"); _tap(s, 18, "btn_x"); _tap(s, 28, "btn_y")
	await _combo("X X Y (early Y) -> 1x, 2x, 3x", s, 150, ["atk1", "atk2", "atk3"], ["beam_ender"])
	# ---- Y family
	s = []; _tap(s, 5, "btn_y")
	await _combo("Y -> quick fire", s, 40, ["quick_fire"], ["rear_blast", "adash"])
	s = []; _tap(s, 5, "btn_x"); _tap(s, 5, "btn_y")
	await _combo("X+Y same frame -> rear explosion", s, 40, ["rear_blast"], ["atk1", "quick_fire"])
	s = []; _tap(s, 5, "btn_x"); _tap(s, 7, "btn_y")
	await _combo("X then Y within 50 ms -> rear explosion", s, 40, ["rear_blast"], ["atk1", "quick_fire"])
	s = []; _tap(s, 5, "btn_y"); _tap(s, 7, "btn_x")
	await _combo("Y then X within 50 ms -> rear explosion", s, 40, ["rear_blast"], ["atk1", "quick_fire"])
	s = []; _tap(s, 5, "btn_a"); _tap(s, 6, "btn_y")
	await _combo("A+Y chord -> ground dash (aerial dash anim)", s, 40, ["adash"], ["quick_fire", "rear_blast"])
	s = []; _tap(s, 6, "btn_a"); _tap(s, 5, "btn_y")
	await _combo("Y then A within 50 ms -> ground dash", s, 40, ["adash"], ["quick_fire"])
	s = [[5, "right", true], [5, "btn_a", true], [60, "right", false], [60, "btn_a", false]]; _tap(s, 40, "btn_y")
	await _combo("Y while running (A held) -> ground dash", s, 70, ["run_start", "adash"], ["quick_fire"])
	s = []; _tap(s, 5, "btn_x"); _tap(s, 5, "btn_a")
	await _combo("X+A no longer dashes -> 1x", s, 40, ["atk1"], ["adash"])
	# ---- air
	s = []; _tap(s, 5, "up"); _tap(s, 20, "btn_x")
	await _combo("jump then X -> jump attack", s, 60, ["jump", "jatk1"], ["adash", "atk1"])
	s = []; _tap(s, 5, "up"); _tap(s, 20, "btn_x"); _tap(s, 30, "btn_x")
	await _combo("jump then X X -> jump attack 1x, 2x", s, 80, ["jump", "jatk1", "jatk2"], [])
	s = []; _tap(s, 5, "up"); _tap(s, 20, "btn_y")
	await _combo("jump then Y -> aerial dash", s, 60, ["jump", "adash"], ["quick_fire", "jatk1"])
	s = []; _tap(s, 5, "up"); _tap(s, 20, "up")
	await _combo("jump, Up again -> double jump", s, 60, ["jump", "djump_v"], [])
	# ---- dodge
	s = []; _tap(s, 5, "btn_b"); _tap(s, 15, "btn_x")
	await _combo("B then X -> back dodge, dodge attack", s, 90, ["bdodge", "datk1"], ["atk1"])
	s = []; _tap(s, 5, "btn_b"); _tap(s, 15, "btn_x"); _tap(s, 45, "btn_x"); _tap(s, 75, "btn_x")
	await _combo("B X X X -> dodge attack 1x, 2x, 3x", s, 200, ["bdodge", "datk1", "datk2", "datk3"], [])
	s = [[5, "down", true], [40, "down", false]]; _tap(s, 15, "btn_a")
	await _combo("Down + A -> slide", s, 60, ["crouch", "slide"], [])
	# ---- specials
	s = []; _tap(s, 5, "r1")
	await _combo("R1 with a full meter -> heal pose (lightning)", s, 70, ["heal"], [], func(g): g.mera.rage = 100.0)
	await _combo("R1 with 99 % rage -> nothing (fail cue)", s, 70, [], ["heal"], func(g): g.mera.rage = 99.0)
	var gr: Node = await _new_game()
	gr.mera.rage = 100.0
	var struck := false
	await _drive(gr, [[5, "r1", true], [8, "r1", false]], 10)
	for _f in 80:
		await physics_frame
		if is_instance_valid(gr.last_strike):
			struck = true
	_check("R1 spends the whole meter (drains to 0) and strikes", gr.mera.rage == 0.0 and not gr.mera.rage_spending and struck, "rage=%f struck=%s" % [gr.mera.rage, struck])
	gr.mera.rage = 100.0
	await _drive(gr, [[5, "r2", true], [8, "r2", false]], 20)
	var before: int = gr.mera.move_log.size()
	await _drive(gr, [[5, "r1", true], [8, "r1", false]], 40)
	_check("R1 during Fury (meter already spent by R2) -> nothing", gr.mera.fury and not ("lightning" in gr.mera.move_log.slice(before)) and gr.mera.anim.key != "heal", "log=%s" % [gr.mera.move_log.slice(before)])
	var fails := 0
	for h in root.get_node("Sfx").history:
		if h[0] == "fail":
			fails += 1
	_check("R1 without a full meter plays the fail cue", fails > 0, "")
	gr.queue_free()
	await process_frame
	var gb: Node = await _new_game()
	await _drive(gb, [[5, "l2", true], [80, "l2", false]], 60)
	_check("L2 held -> barrier up", gb.mera.barrier_on and gb.mera.anim.key == "heal", "state=%s barrier=%s" % [gb.mera.state, gb.mera.barrier_on])
	gb.mera.take_hit(1, gb.mera.global_position.x + 100.0)
	_check("barrier blocks a hit", gb.mera.size == 2, "size=%d" % gb.mera.size)
	await _drive(gb, [[2, "l2", false]], 40)
	_check("L2 released -> barrier down", not gb.mera.barrier_on, "")
	gb.queue_free()
	await process_frame
	var alb: Node = root.get_node("AnimLib")
	# ---- v0.3 fix: 2x atk played to its end (no follow-up) keeps her drawn and doesn't teleport her (was 343 px x size)
	var a2: Dictionary = alb.anims["atk2"]
	var a2_drawn := true
	for fr2 in a2["frames"]:
		if fr2.get("c") == null:
			a2_drawn = false
	_check("2x atk tail holds her pose and its idle hand-off is a small step", a2_drawn and absf(float(a2["end_dx"])) < 40.0, "end_dx=%s" % a2["end_dx"])
	# ---- v0.3 bubble encloses the whole barrier pose (every opaque pixel of every layer, incl. hand + energy ball)
	var heal_img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/characters/merakintsugi/game/" + String(alb.anims["heal"]["sheet"])))
	for sz in [1, 2, 4, 6, 9]:
		for fc in [-1, 1]:
			gb = await _new_game()
			var mb: Node = gb.mera
			mb.set_size(sz, true)
			mb._face(fc)
			await _drive(gb, [[2, "l2", true]], 40)
			var bc: Vector3 = mb.barrier_circle()
			var worst := -1.0e9
			var npx := 0
			for fi in range(5, 9):
				var fr: Dictionary = alb.anims["heal"]["frames"][fi]
				for lk in ["c", "f", "l"]:
					var e = fr.get(lk)
					if e == null:
						continue
					for v in int(e[3]):
						for u in int(e[2]):
							if heal_img.get_pixel(int(e[0]) + u, int(e[1]) + v).a > 0.03:
								npx += 1
								for cx in [0.0, 1.0]:
									for cy in [0.0, 1.0]:   # all 4 pixel corners
										var ax: float = float(e[4]) + u + cx
										var ay: float = float(e[5]) + v + cy
										var wpt: Vector2 = mb.global_position + Vector2(-fc * ax * sz, ay * sz)
										worst = maxf(worst, wpt.distance_to(Vector2(bc.x, bc.y)) - bc.z)
			var spr: Sprite2D = mb.barrier
			var rim: float = float(alb.spells["barrier"].get("rim_r", 36)) * spr.scale.x
			var drawn_ok: bool = spr.visible and spr.global_position.distance_to(Vector2(bc.x, bc.y)) < 0.5 and absf(rim - bc.z) < 0.5
			var hr: Rect2 = mb.hurt_rect()
			var block_ok: bool = absf(hr.size.x - 2.0 * bc.z) < 0.5 and hr.get_center().distance_to(Vector2(bc.x, bc.y)) < 0.5
			_check("bubble encloses the barrier pose at %dx facing %d (%d px, worst %.1f px inside the rim), drawn = blocking area" % [sz, fc, npx, -worst],
				npx > 500 and worst <= -1.0 * sz and drawn_ok and block_ok, "drawn=%s block=%s" % [drawn_ok, block_ok])
			gb.queue_free()
			await process_frame
	# ---- v0.3 R1 works inside the bubble: needs the full meter, spends 100 %, she keeps the pose and keeps blocking
	gb = await _new_game()
	await _drive(gb, [[2, "l2", true]], 40)
	gb.mera.rage = 100.0
	var struck_b := false
	await _drive(gb, [[2, "r1", true], [5, "r1", false]], 6)
	for _f in 50:
		await physics_frame
		if is_instance_valid(gb.last_strike):
			struck_b = true
	_check("R1 inside the bubble strikes and spends the whole meter", struck_b and gb.mera.rage == 0.0 and not gb.mera.rage_spending, "rage=%f struck=%s" % [gb.mera.rage, struck_b])
	_check("...and she stays shielded in the bubble pose", gb.mera.barrier_on and gb.mera.state == "move" and String(gb.mera.mv["key"]) == "barrier" and gb.mera.anim.idx >= 5 and gb.mera.anim.idx <= 8,
		"state=%s idx=%d" % [gb.mera.state, gb.mera.anim.idx])
	gb.mera.take_hit(1, gb.mera.global_position.x + 100.0)
	_check("...and still blocks", gb.mera.size == 2, "size=%d" % gb.mera.size)
	gb.last_strike = null
	gb.mera.rage = 60.0
	await _drive(gb, [[2, "r1", true], [5, "r1", false]], 30)
	_check("R1 inside the bubble below 100 %: no strike, meter kept, still shielded", gb.last_strike == null and gb.mera.rage >= 60.0 and gb.mera.barrier_on, "rage=%f" % gb.mera.rage)
	gb.queue_free()
	await process_frame
	# ---- rules: size = HP, potions, damage x size, death at 1x
	var g: Node = await _new_game()
	var m: Node = g.mera
	_check("starts at 2x with 1 potion", m.size == 2 and m.potions == 1, "size=%d potions=%d" % [m.size, m.potions])
	await _drive(g, [[5, "l1", true], [8, "l1", false]], 90)
	_check("L1 drinks a potion: 2x -> 3x", m.size == 3 and m.potions == 0, "size=%d potions=%d" % [m.size, m.potions])
	await _drive(g, [[5, "l1", true], [8, "l1", false]], 60)
	_check("L1 without potions does nothing", m.size == 3 and not ("heal" in m.move_log.slice(m.move_log.rfind("heal") + 1)), "size=%d" % m.size)
	m.potions = 9
	for i in 5:
		await _drive(g, [[3, "l1", true], [6, "l1", false]], 80)
	_check("potions cap size at 6x", m.size == 6, "size=%d" % m.size)
	m.take_hit(1, m.global_position.x + 100.0)
	_check("a hit costs one size (6x -> 5x) and gives i-frames", m.size == 5 and m.invuln > 0.0, "size=%d" % m.size)
	m.take_hit(1, m.global_position.x + 100.0)
	_check("i-frames ignore the next hit", m.size == 5, "size=%d" % m.size)
	await _drive(g, [], 90)
	m.take_hit(3, m.global_position.x + 100.0)
	_check("a big hit costs several sizes (5x -> 2x)", m.size == 2, "size=%d" % m.size)
	g.queue_free()
	await process_frame
	g = await _new_game()
	m = g.mera
	m.set_size(1, true)
	m.take_hit(1, m.global_position.x + 100.0)
	await _drive(g, [], 10)
	_check("hit at 1x -> death, Game Over", m.state == "dead" and g.over, "state=%s over=%s" % [m.state, g.over])
	g.queue_free()
	await process_frame
	# damage x size against a Fire Knight
	for sz in [1, 2, 3]:
		g = await _new_game()
		m = g.mera
		m.set_size(sz, true)
		g._spawn_knight(1)
		g.knight.position.x = m.global_position.x + 70.0 * sz + 40.0
		g.knight.cooldown = 99.0
		await _drive(g, [[3, "btn_x", true], [6, "btn_x", false]], 30)
		_check("1x attack at %dx deals %d damage" % [sz, sz], g.knight.hp == 10 - sz, "hp=%d" % g.knight.hp)
		g.queue_free()
		await process_frame
	# knight: 10 HP, sphere +10 % rage, only one at a time, respawn after death
	g = await _new_game(true)
	m = g.mera
	await _drive(g, [], 90)
	_check("a Fire Knight spawns off-screen ahead", g.knight != null and absf(g.knight.global_position.x - g.cam_x) > 960.0, "")
	var k1: Node = g.knight
	k1.take_damage(10, m.global_position.x)
	_check("knight with 10 HP dies to 10 damage", not k1.alive(), "hp=%d" % k1.hp)
	await _drive(g, [], 5)
	var sphere: Node = null
	for c in g.world.get_children():
		if c.get("kind") == "sphere":
			sphere = c
	_check("knight drops a red sphere", sphere != null, "")
	if sphere:
		sphere.position = m.global_position + Vector2(0, -40)
		await _drive(g, [], 40)
		_check("red sphere gives +10 % rage", is_equal_approx(m.rage, 10.0), "rage=%f" % m.rage)
	_check("no second knight while one is dying", g.knight == null or g.knight == k1, "")
	await _drive(g, [], 200)
	_check("a new knight spawns after the previous one is defeated", g.knight != null and g.knight != k1 and g.knights_spawned == 2, "spawned=%d" % g.knights_spawned)
	var k2: Node = g.knight
	m.position.x += 6000.0
	await _drive(g, [], 30)
	_check("leaving the knight far behind replaces him ahead", g.knight != k2 and g.knight != null and g.knights_spawned >= 3, "spawned=%d" % g.knights_spawned)
	g.queue_free()
	await process_frame
	# fury
	g = await _new_game()
	m = g.mera
	m.rage = 100.0
	await _drive(g, [[5, "r2", true], [8, "r2", false], [20, "up", true], [24, "up", false], [30, "up", true], [34, "up", false], [40, "up", true]], 65)
	_check("R2 at 100 % rage -> Fury (red effects)", m.fury and root.get_node("AnimLib").fury, "")
	_check("Fury: Up in the air -> flight with the active pose", m.flying and m.state == "fly" and m.anim.key == "djump_v" and m.anim.idx == 2, "state=%s %s f%d" % [m.state, m.anim.key, m.anim.idx])
	await _drive(g, [[1, "up", false]], 20)
	_check("Fury flight idle -> hover pose", m.anim.idx == 3, "f%d" % m.anim.idx)
	await _drive(g, [[2, "btn_y", true], [5, "btn_y", false]], 30)
	var red := false
	for h in root.get_node("Sfx").history:
		if h[0] == "cast" and h[1] == "Fury":
			red = true
	_check("Fury sounds go through the deep Fury bus", red, "%s" % [root.get_node("Sfx").history.slice(-4)])
	g.queue_free()
	await process_frame
	# Fury flight faces the flight direction; aura layers
	g = await _new_game()
	m = g.mera
	m.rage = 100.0
	await _drive(g, [[5, "r2", true], [8, "r2", false], [20, "up", true], [24, "up", false], [30, "up", true], [34, "up", false], [40, "up", true], [60, "up", false], [60, "right", true]], 90)
	_check("Fury aura: back + front flame layers and embers on", m.flame_back.visible and m.flame_front.visible and m.aura_fx.emitting and m.aura_fx.amount == 90, "")
	_check("flying right -> tilted head-first to the right (+90 deg)", absf(m.anim.rotation - PI / 2.0) < 0.05 and m.facing == 1, "rot=%f" % m.anim.rotation)
	await _drive(g, [[1, "right", false], [1, "left", true], [1, "up", true]], 40)
	_check("flying up-left -> tilted -45 deg, facing left", absf(m.anim.rotation + PI / 4.0) < 0.05 and m.facing == -1, "rot=%f" % m.anim.rotation)
	await _drive(g, [[1, "left", false], [1, "up", false]], 60)
	_check("idle hover -> eases back upright", absf(m.anim.rotation) < 0.01 and m.anim.idx == 3, "rot=%f" % m.anim.rotation)
	m.set_aura_quality(0)
	_check("aura quality cap 0 -> flame layers off, 20 embers", not m.flame_back.visible and m.aura_fx.amount == 20, "")
	g.queue_free()
	await process_frame
	# ---- v0.3 speeds: walk 50 px/s at 1x; dashes 2x the distance in half the time; back dodge same distance, 2x faster
	var al: Node = root.get_node("AnimLib")
	g = await _new_game()
	m = g.mera
	m.set_size(1, true)
	await _drive(g, [[1, "right", true]], 30)
	var wx0: float = m.global_position.x
	await _drive(g, [], 30)
	_check("walk at 1x = 50 px/s", absf((m.global_position.x - wx0) - 25.0) < 2.0, "moved %f in 0.5 s" % (m.global_position.x - wx0))
	g.queue_free()
	await process_frame
	for mvk in ["gdash", "bdodge"]:
		for sz in [1, 2]:
			g = await _new_game()
			m = g.mera
			m.set_size(sz, true)
			await _drive(g, [], 3)
			var fr: Array = al.frames("adash" if mvk == "gdash" else "bdodge")
			var t_old := 0.0
			var t_win_old := 0.0
			for i in fr.size():
				t_old += float(fr[i]["ms"]) / 1000.0
				if i >= 2 and i <= 16:
					t_win_old += float(fr[i]["ms"]) / 1000.0
			var d_old: float = (400.0 * t_old if mvk == "gdash" else 400.0 * t_win_old) * sz
			var x0: float = m.global_position.x
			m._start_move(mvk)
			var n := 0
			while m.state == "move" and String(m.mv.get("key", "")) == mvk and n < 300:
				await physics_frame
				n += 1
			var d := absf(m.global_position.x - x0)
			var t_new := n / 60.0
			if mvk == "gdash":
				_check("ground dash at %dx: 2x the distance (%.0f vs %.0f) in half the time (%.2f vs %.2f s)" % [sz, d, d_old, t_new, t_old],
					absf(d / (2.0 * d_old) - 1.0) < 0.15 and absf(t_new / (t_old / 2.0) - 1.0) < 0.15, "")
			else:
				_check("back dodge at %dx: same distance (%.0f vs %.0f) in half the time (%.2f vs %.2f s)" % [sz, d, d_old, t_new, t_old],
					absf(d / d_old - 1.0) < 0.15 and absf(t_new / (t_old / 2.0) - 1.0) < 0.15, "")
			g.queue_free()
			await process_frame
	# camera: always follows Mera (centred + look-ahead), no edge dead zone
	g = await _new_game()
	m = g.mera
	await _drive(g, [], 3)
	var c_start: float = g.cam_x
	var la: float = g.CAM_LOOK * minf(m.shown, 2.0)
	_check("camera starts centred on Mera (+ look-ahead)", is_equal_approx(c_start, m.global_position.x + m.facing * la), "cam=%f m=%f" % [c_start, m.global_position.x])
	await _drive(g, [[1, "right", true], [90, "right", false]], 90)
	var lag: float = absf(g.cam_x - (m.global_position.x + la))
	_check("walking: camera scrolls with her every frame (lag < 60 px)", lag < 60.0 and g.cam_x > c_start + 100.0, "lag=%f" % lag)
	m.position.x += 300.0
	await _drive(g, [], 45)
	_check("camera recentres on her after a jump in position (no dead zone)", absf(g.cam_x - (m.global_position.x + m.facing * la)) < 2.0, "off=%f" % (g.cam_x - m.global_position.x))
	g.queue_free()
	await process_frame
	# ---- Fire Knight: fixed 6x, exactly 1 size per connecting swing at any Mera size
	for sz in [1, 2, 6]:
		g = await _new_game()
		m = g.mera
		m.set_size(sz, true)
		g._spawn_knight(1)
		var kn: Node = g.knight
		kn.position.x = m.global_position.x + 420.0
		kn.cooldown = 0.0
		await _drive(g, [], 2)
		var sc_ok: bool = absf(kn.sprite.scale.x) == 6.0 and kn.sprite.scale.y == 6.0 and kn.hurt_rect().size == Vector2(26, 44) * 6.0
		var hit_at := -1
		for fr in 240:
			await physics_frame
			if m.size != sz or m.state == "dead":
				hit_at = fr
				break
		await _drive(g, [], 20)
		if sz == 1:
			_check("6x knight swing at 1x Mera -> exactly one hit, death", sc_ok and m.state == "dead", "scale=%s state=%s at=%d" % [kn.sprite.scale, m.state, hit_at])
		else:
			_check("6x knight swing at %dx Mera -> exactly 1 size lost (%dx)" % [sz, sz - 1], sc_ok and m.size == sz - 1 and hit_at > int(kn.TELL * 60.0), "size=%d at=%d scale=%s" % [m.size, hit_at, kn.sprite.scale])
		m.set_size(6, true)
		await _drive(g, [], 3)
		_check("knight stays 6x when Mera is %dx -> 6x" % sz, absf(kn.sprite.scale.x) == 6.0 and kn.DAMAGE == 1, "scale=%s" % kn.sprite.scale)
		g.queue_free()
		await process_frame
	g = await _new_game()
	m = g.mera
	m.set_size(3, true)
	await _drive(g, [[2, "btn_b", true], [5, "btn_b", false]], 6)
	m.take_hit(1, m.global_position.x + 100.0)
	_check("back dodge has i-frames", m.size == 3 and m.dodging(), "size=%d" % m.size)
	g.queue_free()
	await process_frame
	# ---- beam (X X X Y ender) and R1 lightning reach past the viewport edges at any size and position
	for sz in [1, 2, 6]:
		for where in [-480.0, 0.0, 480.0]:
			for fc in [1, -1]:
				g = await _new_game()
				m = g.mera
				m.set_size(sz, true)
				m.position.x = g.cam_x + where
				m._face(fc)
				await _drive(g, [], 2)
				m._start_move("beam_ender")
				var worst := 1e9
				var hit_worst := 1e9
				var lit := 0
				for fr in 200:
					await physics_frame
					var f: Dictionary = m._cur()
					if String(f.get("phase", "")) == "sustain":
						lit += 1
						var edge: float = g.cam.position.x + fc * 960.0
						worst = minf(worst, (m.beam_end_x - edge) * fc)
						var hr: Rect2 = m.hit_rect()
						var far: float = hr.end.x if fc > 0 else hr.position.x
						hit_worst = minf(hit_worst, (far - edge) * fc)
				_check("beam %dx at screen %+d facing %s reaches off-screen (hitbox too)" % [sz, int(where), "R" if fc > 0 else "L"],
					lit > 5 and worst > 0.0 and hit_worst > 0.0 and m.beam_strip.dropped == 0, "lit=%d past=%.0f hit_past=%.0f dropped=%d" % [lit, worst, hit_worst, m.beam_strip.dropped])
				g.queue_free()
				await process_frame
		for where in [-480.0, 0.0, 480.0]:
			g = await _new_game()
			m = g.mera
			m.set_size(sz, true)
			m.position.x = g.cam_x + where
			await _drive(g, [], 2)
			g.call_lightning(m)
			var st: Node = g.last_strike
			var top_ok := true
			for fr in 12:
				await process_frame
				if is_instance_valid(st) and st.top_y > g.cam.position.y - 540.0:
					top_ok = false
			_check("lightning %dx at screen %+d runs from above the screen top to the ground" % [sz, int(where)],
				top_ok and st.segs > 0 and st.dropped == 0, "top=%.0f segs=%d" % [st.top_y if is_instance_valid(st) else 0.0, st.segs if is_instance_valid(st) else -1])
			g.queue_free()
			await process_frame
	print("\n%d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)
