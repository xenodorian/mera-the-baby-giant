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
	s = []; _tap(s, 5, "btn_b"); _tap(s, 15, "btn_x"); _tap(s, 60, "btn_x"); _tap(s, 100, "btn_x")
	await _combo("B X X X -> dodge attack 1x, 2x, 3x", s, 200, ["bdodge", "datk1", "datk2", "datk3"], [])
	s = [[5, "down", true], [40, "down", false]]; _tap(s, 15, "btn_a")
	await _combo("Down + A -> slide", s, 60, ["crouch", "slide"], [])
	# ---- specials
	s = []; _tap(s, 5, "r1")
	await _combo("R1 -> heal pose (lightning)", s, 70, ["heal"], [])
	var gb: Node = await _new_game()
	await _drive(gb, [[5, "l2", true], [80, "l2", false]], 60)
	_check("L2 held -> barrier up", gb.mera.barrier_on and gb.mera.anim.key == "heal", "state=%s barrier=%s" % [gb.mera.state, gb.mera.barrier_on])
	gb.mera.take_hit(1, gb.mera.global_position.x + 100.0)
	_check("barrier blocks a hit", gb.mera.size == 2, "size=%d" % gb.mera.size)
	await _drive(gb, [[2, "l2", false]], 40)
	_check("L2 released -> barrier down", not gb.mera.barrier_on, "")
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
	# camera dead zone + looping map
	g = await _new_game()
	m = g.mera
	m.position.x = g.cam_x + 300.0
	await _drive(g, [], 3)
	var c0: float = g.cam_x
	m.position.x = g.cam_x + 700.0
	await _drive(g, [], 3)
	_check("camera holds while Mera is >480 px from the edges, follows inside 480 px", c0 == 960.0 and is_equal_approx(m.global_position.x - g.cam_x, 480.0), "cam=%f" % g.cam_x)
	g.queue_free()
	await process_frame
	print("\n%d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)
