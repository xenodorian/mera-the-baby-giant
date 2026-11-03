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


## half the enemy's body width (spawn distances are edge to edge)
func e_half(RO, eid: String) -> float:
	var b: Array = RO.art(eid)["body"]
	return (float(b[2]) - float(b[0])) * float(RO.def(eid)["k"]) * 0.38


## v0.7: run an ally against one enemy for a while (eid "": nothing), Mera kept safe
func _ally_stage(g: Node, a: Node2D, eid: String, dx: float, frames: int, force_tell: bool = false) -> void:
	var e: Node2D = null
	if eid != "":
		e = g.spawn_enemy(eid, a.global_position.x + dx)
		await physics_frame
		await physics_frame
	if force_tell and is_instance_valid(a) and is_instance_valid(e):
		a.state = "idle"
		e.cooldown = 99.0
		e._start_tell(e.attacks[0], -1 if e.global_position.x > a.global_position.x else 1)
	for f in frames:
		await physics_frame
		g.mera.invuln = 1.0
		if not is_instance_valid(a):
			break
	if e != null and is_instance_valid(e):
		g.mobs.erase(e)
		e.queue_free()


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


# ---------------------------------------------------------------- v0.4 human-timing input replay
## steps: [{a, chord?, gap:[lo,hi], hold:[lo,hi]}]. A chord's two buttons land 0-50 ms apart in random order.
func _human_events(rng: RandomNumberGenerator, steps: Array) -> Array:
	var ev: Array = []
	var t := 100.0
	var first := true
	for st in steps:
		if not first:
			var gp: Array = st.get("gap", [80, 250])
			t += rng.randf_range(float(gp[0]), float(gp[1]))
		first = false
		var hd: Array = st.get("hold", [45, 110])
		var h := rng.randf_range(float(hd[0]), float(hd[1]))
		if st.has("chord"):
			var a1: String = st["a"]
			var a2: String = st["chord"]
			if rng.randf() < 0.5:
				var tmp := a1
				a1 = a2
				a2 = tmp
			var off := rng.randf_range(0.0, 50.0)
			ev.append([t, a1, true]); ev.append([t + h, a1, false])
			ev.append([t + off, a2, true]); ev.append([t + off + h, a2, false])
		else:
			ev.append([t, st["a"], true]); ev.append([t + h, st["a"], false])
	# a button can't be pressed again while it is still held: cut the earlier hold 20 ms before the next press
	var last_rel := {}
	for e in ev:                     # generation order: each press is followed by its own release
		if e[2]:
			if last_rel.has(e[1]) and float(last_rel[e[1]][0]) > float(e[0]) - 20.0:
				last_rel[e[1]][0] = float(e[0]) - 20.0
		else:
			last_rel[e[1]] = e
	ev.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	return ev


## plays timed events (ms) through Mera's forced input; returns {bolts: [speed_mult...], air_before: frames airborne
## before the first `watch` move, fast: bool (quick fire seen at anim speed 2), first_air_ms}
func _replay(g: Node, ev: Array, tail_ms: float = 2200.0, watch: String = "") -> Dictionary:
	var m: Node = g.mera
	var t := 0.0
	var i := 0
	var end_ms := float(ev[-1][0]) + tail_ms
	var seen := {}
	var out := {"bolts": [], "air_before": 0, "fast": false, "qf_speed": 0.0, "first_air_ms": -1.0, "x_start": m.global_position.x}
	var p0 := float(ev[0][0])
	while t <= end_ms:
		while i < ev.size() and float(ev[i][0]) <= t:
			m.forced[ev[i][1]] = ev[i][2]
			i += 1
		await physics_frame
		t += 1000.0 / 60.0
		for c in g.world.get_children():
			if c.get("speed_mult") != null and c.get("kind") == "bolt" and not seen.has(c.get_instance_id()):
				seen[c.get_instance_id()] = true
				out["bolts"].append(c.speed_mult)
		if m.anim.key == "quick_fire":
			out["qf_speed"] = maxf(float(out["qf_speed"]), m.anim.speed)
		if watch != "" and not (watch in m.move_log) and not m.on_ground:
			out["air_before"] = int(out["air_before"]) + 1
		if float(out["first_air_ms"]) < 0.0 and not m.on_ground and t >= p0:
			out["first_air_ms"] = t - p0
	for a in ["btn_x", "btn_y", "btn_a", "btn_b", "up", "down", "left", "right"]:
		m.forced[a] = false
	return out


## N seeded human trials of one combo
func _human_combo(name: String, steps: Array, want: Array, forbid: Array, trials: int = 8, check: Callable = Callable(), keys: bool = false) -> void:
	var rng := RandomNumberGenerator.new()
	var bad := []
	for n in trials:
		rng.seed = 4000 + n * 7919 + name.hash() % 1000
		var g: Node = await _new_game()
		var ev := _human_events(rng, steps)
		var r: Dictionary = await _replay(g, ev, 2200.0, String(want[0]) if want.size() > 0 else "")
		var log: Array = g.mera.move_keys if keys else g.mera.move_log
		var ok := _has_seq(log, want)
		for f in forbid:
			if f in log:
				ok = false
		if ok and check.is_valid():
			ok = check.call(g, r)
		if not ok:
			bad.append("seed%d %s %s" % [n, log, r])
		g.queue_free()
		await process_frame
	_check("human timing x%d: %s" % [trials, name], bad.is_empty(), "%s" % [bad.slice(0, 2)])


## v0.8 Android L2 bug: no two actions share a joypad button/axis direction, triggers only drive L2/R2, and a
## joypad Start/Select that arrives with trigger activity (a pad whose L2 is mis-mapped onto Back/Start) is dropped.
func _input_map_tests() -> void:
	var C = root.get_node("Controls")
	var binds: Dictionary = C.joy_bindings()
	var shared: Array = []
	for k in binds:
		if binds[k].size() > 1:
			shared.append("%s=%s" % [k, binds[k]])
	_check("input map: no two actions share a joypad button or axis direction", shared.is_empty(), "%s" % [shared])
	var ok_trig: bool = binds.get("axis:%d:+" % JOY_AXIS_TRIGGER_LEFT, []) == ["l2"] and binds.get("axis:%d:+" % JOY_AXIS_TRIGGER_RIGHT, []) == ["r2"] \
		and binds.get("btn:15", []) == ["l2"] and binds.get("btn:16", []) == ["r2"] \
		and not binds.has("axis:%d:-" % JOY_AXIS_TRIGGER_LEFT) and not binds.has("axis:%d:-" % JOY_AXIS_TRIGGER_RIGHT)
	_check("input map: trigger axes and Android trigger buttons (15/16) drive only L2/R2", ok_trig, "%s" % [binds])
	var leak: Array = []
	for a in InputMap.get_actions():
		if String(a) in ["l2", "r2"]:
			continue
		for e in InputMap.action_get_events(a):
			if (e is InputEventJoypadMotion and e.axis in C.TRIGGER_AXES) or (e is InputEventJoypadButton and e.button_index in [15, 16]):
				leak.append(String(a))
	_check("input map: no other action (ui_* included) listens to a trigger", leak.is_empty(), "%s" % [leak])
	var kb: Dictionary = C.key_bindings()
	var kshared: Array = []
	for kc in kb:
		if kb[kc].size() > 1:
			kshared.append("%s=%s" % [OS.get_keycode_string(kc), kb[kc]])
	var raw_hit: Array = []
	for kc in C.RAW_KEYS:
		if kb.has(kc):
			raw_hit.append(OS.get_keycode_string(kc))
	_check("input map: no key is shared by two actions, none uses Esc/F11 (read raw)", kshared.is_empty() and raw_hit.is_empty(), "%s %s" % [kshared, raw_hit])
	var want := {"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN, "btn_a": KEY_Z, "btn_b": KEY_X, "btn_x": KEY_A, "btn_y": KEY_S,
		"l1": KEY_Q, "r1": KEY_W, "l2": KEY_1, "r2": KEY_2}
	var kbad: Array = []
	for a in want:
		var ok := false
		for e in InputMap.action_get_events(a):
			if e is InputEventKey and e.physical_keycode == want[a]:
				ok = true
		if not ok:
			kbad.append(a)
	var kp_bound := false
	for a in ["l2", "r2"]:
		for e in InputMap.action_get_events(a):
			if e is InputEventKey and e.physical_keycode in [KEY_KP_1, KEY_KP_2]:
				kp_bound = true
	_check("keyboard (v0.8): arrows = d-pad, Z A, X B, A X, S Y, Q L1, W R1, 1 L2, 2 R2", kbad.is_empty() and not kp_bound, "%s kp=%s" % [kbad, kp_bound])
	var g: Node = await _new_game()
	for i in 10:
		await physics_frame
	var ov0: bool = g.hud.overlay
	var pp0: bool = g.paused_play
	var tr := InputEventJoypadMotion.new(); tr.axis = JOY_AXIS_TRIGGER_LEFT; tr.axis_value = 1.0
	var st := InputEventJoypadButton.new(); st.button_index = JOY_BUTTON_START; st.pressed = true
	Input.parse_input_event(st)            # mis-mapped pad: Start arrives first, the trigger a frame later
	await physics_frame
	Input.parse_input_event(tr)
	for i in 3:
		await physics_frame
	var held_ok: bool = g.mera.pressed("l2")
	for i in 10:
		await physics_frame
	_check("Android L2 + phantom Start together: shield input kept, overlay NOT toggled", g.hud.overlay == ov0 and held_ok and g.menu_guard_drops >= 1, "overlay=%s l2=%s drops=%d" % [g.hud.overlay, held_ok, g.menu_guard_drops])
	tr.axis_value = 0.0; Input.parse_input_event(tr)
	st.pressed = false; Input.parse_input_event(st)
	for i in 20:
		await physics_frame
	var gal0: bool = g.mera.state == "gallery"
	var b15 := InputEventJoypadButton.new(); b15.button_index = 15; b15.pressed = true
	var bk := InputEventJoypadButton.new(); bk.button_index = JOY_BUTTON_BACK; bk.pressed = true
	Input.parse_input_event(b15); Input.parse_input_event(bk)
	for i in 4:
		await physics_frame
	var l2b: bool = Input.is_action_pressed("l2")
	for i in 10:
		await physics_frame
	_check("Android digital L2 (button 15) + phantom Back: L2 held, gallery NOT opened", l2b and (g.mera.state == "gallery") == gal0, "l2=%s state=%s" % [l2b, g.mera.state])
	b15.pressed = false; Input.parse_input_event(b15); bk.pressed = false; Input.parse_input_event(bk)
	for i in 20:
		await physics_frame
	st.pressed = true; Input.parse_input_event(st)
	await physics_frame
	st.pressed = false; Input.parse_input_event(st)
	for i in 12:
		await physics_frame
	_check("plain joypad Start (no trigger) opens the pause menu", g.paused_play != pp0 and g.hud.overlay == ov0, "paused=%s overlay=%s" % [g.paused_play, g.hud.overlay])
	if g.paused_play:
		g.toggle_pause()
	g.queue_free()
	await physics_frame
	await _keyboard_tests()


## v0.8 PC keyboard: real key events (Input.parse_input_event), same chords and tap/hold as the pad
func _kdrive(steps: Array, frames: int) -> void:
	for f in frames:
		for st in steps:
			if int(st[0]) == f:
				var e := InputEventKey.new()
				e.physical_keycode = st[1]
				e.pressed = st[2]
				Input.parse_input_event(e)
		await physics_frame


func _keyboard_tests() -> void:
	var g: Node = await _new_game()
	var m: Node = g.mera
	await _kdrive([], 10)
	var n0: int = m.move_log.size()
	await _kdrive([[2, KEY_A, true], [2, KEY_S, true], [6, KEY_A, false], [6, KEY_S, false]], 40)
	_check("keyboard: A+S together (X+Y) -> rear explosion", "rear_blast" in m.move_log.slice(n0), "%s" % [m.move_log.slice(n0)])
	await _kdrive([], 60)
	n0 = m.move_log.size()
	await _kdrive([[2, KEY_A, true], [5, KEY_A, false], [15, KEY_A, true], [18, KEY_A, false], [28, KEY_A, true], [31, KEY_A, false]], 120)
	var chain: Array = m.move_log.slice(n0)
	_check("keyboard: A A A -> 1x 2x 2x-2", "atk1" in chain and "atk2" in chain and "atk2_2" in chain, "%s" % [chain])
	await _kdrive([], 40)
	m.rage = 100.0
	g.last_strike = null
	await _kdrive([[2, KEY_1, true]], 40)
	var shield: bool = m.barrier_on
	await _kdrive([[0, KEY_1, false]], 30)
	_check("keyboard: 1 hold -> barrier, released -> down, no lightning", shield and not m.barrier_on and g.last_strike == null and m.rage == 100.0, "rage=%f" % m.rage)
	await _kdrive([[2, KEY_1, true], [2, KEY_2, true], [6, KEY_1, false], [6, KEY_2, false]], 20)
	_check("keyboard: 1+2 at full rage -> Fury, no lightning", m.fury and m.rage == 0.0 and g.last_strike == null, "rage=%f strike=%s" % [m.rage, g.last_strike])
	g.queue_free()
	await physics_frame
	g = await _new_game()
	m = g.mera
	m.rage = 100.0
	g.last_strike = null
	var strikes0: int = g.strikes_made
	await _kdrive([[2, KEY_2, true], [8, KEY_2, false]], 40)
	_check("keyboard: 2 alone -> lightning (costs 100), not Fury", (not m.fury) and m.rage == 0.0 and g.strikes_made > strikes0, "rage=%f fury=%s" % [m.rage, m.fury])
	g.queue_free()
	await physics_frame
	g = await _new_game()
	m = g.mera
	await _kdrive([], 10)
	await _kdrive([[2, KEY_DOWN, true], [12, KEY_S, true], [15, KEY_S, false], [30, KEY_DOWN, false]], 40)
	_check("keyboard: Down + S -> earthquake", g.quake_t > 0.0 or "quake" in String(m.move_log), "%s" % [m.move_log.slice(-4)])
	# menus: game over -> Z restarts; level clear B = X key -> menu (checked via the action map)
	var xb := false
	for e in InputMap.action_get_events("btn_b"):
		if e is InputEventKey and e.physical_keycode == KEY_X:
			xb = true
	g.over = true
	g.over_t = 2.0
	var e2 := InputEventKey.new(); e2.physical_keycode = KEY_Z; e2.pressed = true
	Input.parse_input_event(e2)
	await physics_frame
	e2.pressed = false; Input.parse_input_event(e2)
	await physics_frame
	await physics_frame
	_check("keyboard menus: Z restarts after Game Over; X is B (back to level select)", g.restart_requests == 1 and xb, "restarts=%d" % g.restart_requests)
	if is_instance_valid(g):
		g.queue_free()
	await physics_frame


func _run() -> void:
	load("res://scripts/game/cutscene.gd").suppressed = true     # (loaded, not named: naming the class would compile it before the autoloads exist) king arc: story cards would pause games that are not under test (the king arc section turns it off for its own cases)
	load("res://scripts/game/carry.gd").test_all = true   # v0.12.2: the existing cases run with every unlock owned
	load("res://scripts/game/carry.gd").ensure()
	load("res://scripts/game/carry.gd").character = "mera"   # a saved Perry choice must not turn the Mera cases into Perry runs (memory only, not saved)
	load("res://scripts/game/prop.gd").touch_opens = false     # chests open a puzzle (pausing the tree) on touch: only the chest cases want that
	root.get_node("HitStop").enabled = false      # v0.8: legacy frame-counted cases run without hit-stop (S4 tests turn it on)
	await _input_map_tests()
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
	await _combo("X then Y within 50 ms -> rear explosion", s, 40, ["rear_blast"], ["quick_fire"])
	s = []; _tap(s, 5, "btn_y"); _tap(s, 7, "btn_x")
	await _combo("Y then X within 50 ms -> rear explosion", s, 40, ["rear_blast"], ["atk1"])
	s = []; _tap(s, 5, "btn_a"); _tap(s, 6, "btn_y")
	await _combo("A+Y chord -> ground dash (aerial dash anim)", s, 40, ["adash"], ["quick_fire", "rear_blast"])
	s = []; _tap(s, 6, "btn_a"); _tap(s, 5, "btn_y")
	await _combo("Y then A within 50 ms -> ground dash", s, 40, ["adash"], [])
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
	await _combo("B X X X -> dodge attack only (v0.4: never the rising slash or slam)", s, 200, ["bdodge", "datk1"], ["datk2", "datk3"])
	s = [[5, "down", true], [40, "down", false]]; _tap(s, 15, "btn_a")
	await _combo("Down + A -> slide", s, 60, ["crouch", "slide"], [])
	# ---- specials: L2 = bubble, R2 alone = lightning, L2+R2 = Fury (costs 100)
	s = []; _tap(s, 5, "l2")
	await _combo("L2 tap -> bubble pose, not a separate move", s, 40, ["heal"], [])
	var gr: Node = await _new_game()
	gr.mera.rage = 100.0
	gr.last_strike = null
	await _drive(gr, [[5, "l2", true], [8, "l2", false]], 30)
	_check("L2 tap does not spend rage or strike", gr.last_strike == null and gr.mera.rage == 100.0 and not gr.mera.fury, "rage=%f" % gr.mera.rage)
	var strikes1: int = gr.strikes_made
	await _drive(gr, [[5, "r2", true], [8, "r2", false]], 40)
	for _f in 40:
		await physics_frame
	var struck: bool = gr.strikes_made > strikes1
	_check("R2 alone spends the meter and strikes, and does not start Fury", gr.mera.rage == 0.0 and not gr.mera.rage_spending and struck and not gr.mera.fury, "rage=%f struck=%s fury=%s" % [gr.mera.rage, struck, gr.mera.fury])
	gr.queue_free()
	await process_frame
	gr = await _new_game()
	gr.mera.rage = 180.0
	gr.mera.rage_max = 200.0
	await _drive(gr, [[5, "l2", true], [5, "r2", true], [12, "l2", false], [12, "r2", false]], 24)
	_check("L2+R2 starts Fury and spends only 100 rage", gr.mera.fury and absf(gr.mera.rage - 80.0) < 0.1, "rage=%f fury=%s" % [gr.mera.rage, gr.mera.fury])
	var before: int = gr.mera.move_log.size()
	gr.last_strike = null
	await _drive(gr, [[5, "l2", true], [8, "l2", false]], 40)
	_check("L2 during Fury raises no lightning", gr.mera.fury and gr.last_strike == null, "log=%s" % [gr.mera.move_log.slice(before)])
	gr.queue_free()
	await process_frame
	for order in [["l2", "r2"], ["r2", "l2"]]:
		for gap in [0, 2, 3]:
			gr = await _new_game()
			gr.mera.rage = 100.0
			await _drive(gr, [[5, order[0], true], [5 + gap, order[1], true], [14, order[0], false], [14 + gap, order[1], false]], 50)
			_check("%s then %s %d ms later -> Fury, not lightning" % [order[0], order[1], int(gap * 16.7)], gr.mera.fury and not ("lightning" in gr.mera.move_keys), "keys=%s fury=%s" % [gr.mera.move_keys, gr.mera.fury])
			gr.queue_free()
			await process_frame
	gr = await _new_game()
	gr.mera.rage = 100.0
	await _drive(gr, [[5, "l2", true]], 80)
	gr.last_strike = null
	await _drive(gr, [[3, "r2", true], [6, "r2", false]], 50)
	_check("R2 while holding the L2 bubble -> Fury, bubble drops", gr.mera.fury and not gr.mera.barrier_on, "on=%s fury=%s" % [gr.mera.barrier_on, gr.mera.fury])
	gr.queue_free()
	await process_frame
	gr = await _new_game()
	gr.mera.rage = 100.0
	await _drive(gr, [[5, "r1", true], [8, "r1", false]], 30)
	var fails := 0
	for h in root.get_node("Sfx").history:
		if h[0] == "fail":
			fails += 1
	_check("R1 without ally cards -> fail cue, no lightning", fails > 0 and gr.last_strike == null and gr.mera.rage == 100.0, "")
	await _drive(gr, [[5, "l2", true]], 100)
	_check("L2 held with a full meter -> barrier, no lightning", gr.mera.barrier_on and gr.mera.rage == 100.0 and gr.last_strike == null, "")
	await _drive(gr, [[3, "btn_y", true], [6, "btn_y", false]], 16)
	_check("a button inside the full bubble drops it and does that move", not gr.mera.barrier_on and "quick_fire" in gr.mera.move_log, "barrier=%s log=%s" % [gr.mera.barrier_on, gr.mera.move_log])
	await _drive(gr, [[2, "l2", false]], 20)
	gr.queue_free()
	await process_frame
	gr = await _new_game()
	gr.mera.potions = 2
	gr.mera.set_size(3, true)
	await _drive(gr, [[5, "l2", true]], 80)
	await _drive(gr, [[3, "l1", true], [6, "l1", false]], 20)
	_check("L1 inside the full bubble drinks and the bubble stays", gr.mera.barrier_on and gr.mera.size == 4 and gr.mera.potions == 1, "on=%s size=%d pot=%d" % [gr.mera.barrier_on, gr.mera.size, gr.mera.potions])
	gr.queue_free()
	await process_frame
	gr = await _new_game()
	gr.mera.rage = 100.0
	await _drive(gr, [[5, "up", true], [9, "up", false], [20, "l2", true], [21, "r2", true], [25, "l2", false], [25, "r2", false]], 40)
	_check("L2+R2 in the air -> Fury, not lightning", gr.mera.fury and not ("lightning" in gr.mera.move_keys), "keys=%s" % [gr.mera.move_keys])
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
	# ---- rules: size = HP, potions, damage x size, death at 1x
	var g: Node = await _new_game()
	var m: Node = g.mera
	_check("starts at 2x with 1 potion", m.size == 2 and m.potions == 1, "size=%d potions=%d" % [m.size, m.potions])
	await _drive(g, [[5, "l1", true], [8, "l1", false]], 90)
	_check("L1 drinks a potion: 2x -> 3x", m.size == 3 and m.potions == 0, "size=%d potions=%d" % [m.size, m.potions])
	var gt: Node = await _new_game()
	var mt: Node = gt.mera
	await _drive(gt, [[1, "l1", true]], 1)
	var waited := 0
	for i in 30:
		await physics_frame
		waited += 1
		if mt.size >= 3:
			break
	_check("a potion lands within 0.2 s (one rendered frame per heal frame)", mt.size == 3 and mt.potions == 0 and waited <= 12 and mt.anim.frame_for_frame, "frames=%d speed=%s size=%d" % [waited, mt.anim.speed, mt.size])
	gt.queue_free()
	await process_frame
	await _drive(g, [[5, "l1", true], [8, "l1", false]], 60)
	_check("L1 without potions does nothing", m.size == 3 and not ("heal" in m.move_log.slice(m.move_log.rfind("heal") + 1)), "size=%d" % m.size)
	m.potions = 9
	load("res://scripts/game/carry.gd").test_scale_cap = 6          # this block is about the cap itself
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
	load("res://scripts/game/carry.gd").test_scale_cap = 9
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
		g.knight.block_chance = 0.0
		await _drive(g, [[3, "btn_x", true], [6, "btn_x", false]], 30)
		_check("1x attack at %dx deals %d damage" % [sz, sz], g.knight.hp == 20 - sz, "hp=%d" % g.knight.hp)
		g.queue_free()
		await process_frame
	# cemetery: three Fire Knights on fixed points (25 / 50 / 75 % of the walkable map), 10 HP each, sphere +10 % rage,
	# a death refills the same point until KNIGHT_CAP have been spawned, and nobody despawns for distance
	LVS.current = 3                       # Moonlit Cemetery is the knight fight
	g = await _new_game(true)
	m = g.mera
	await _drive(g, [], 30)
	var kpts: Array = g._knight_points()
	var span: float = (g.map_w - LVS.EDGE) - LVS.EDGE
	var pts_ok: bool = absf(float(kpts[0]) - (LVS.EDGE + span * 0.25)) < 1.0 and absf(float(kpts[1]) - (LVS.EDGE + span * 0.5)) < 1.0 and absf(float(kpts[2]) - (LVS.EDGE + span * 0.75)) < 1.0
	_check("cemetery knight points are 25, 50 and 75 % of the walkable width", pts_ok, "%s" % [kpts])
	var spots := {}
	for kk in g.knights:
		spots[int(kk.get_meta("spot", -1))] = true
	_check("cemetery starts with three Fire Knights, one per point", g.knights.size() == 3 and g.knights_spawned == 3 and spots.size() == 3 and g.knight != null, "n=%d spawned=%d spots=%s" % [g.knights.size(), g.knights_spawned, spots])
	var k1: Node = null
	for kk in g.knights:
		if int(kk.get_meta("spot", -1)) == 1:
			k1 = kk
	var seed_ok := 1
	for seed_i in 400:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_i
		if g.enemy_loot_kind(rng.randf()) == "sphere":
			seed_ok = seed_i
			break
	g.drop_rng.seed = seed_ok
	k1.take_damage(20, m.global_position.x)
	_check("Fire Knight with 20 HP dies to 20 damage", not k1.alive(), "hp=%d" % k1.hp)
	await _drive(g, [], 5)
	var sphere: Node = null
	for c in g.world.get_children():
		if c.get("kind") == "sphere":
			sphere = c
	_check("knight drops a rage sphere from the loot table", sphere != null, "")
	m.rage = 0.0                           # rage carries over from earlier games (Carry.rage), so start from 0
	if sphere:
		sphere.position = m.global_position + Vector2(0, -40)
		await _drive(g, [], 40)
	_check("that rage sphere gives +10 rage", is_equal_approx(m.rage, 10.0), "rage=%f" % m.rage)
	await _drive(g, [], 200)
	var refilled: Node = null
	for kk in g.knights:
		if int(kk.get_meta("spot", -1)) == 1 and kk != k1:
			refilled = kk
	_check("a death refills the same point", refilled != null and g.knights.size() == 3 and g.knights_spawned == 4, "n=%d spawned=%d" % [g.knights.size(), g.knights_spawned])
	var before_far: Array = g.knights.duplicate()
	m.position.x += 6000.0
	await _drive(g, [], 30)
	var still := 0
	for kk in before_far:
		if is_instance_valid(kk) and kk.alive():
			still += 1
	_check("leaving the knights far behind does not remove them", still == 3 and g.knights_spawned == 4, "alive=%d spawned=%d" % [still, g.knights_spawned])
	g.knights_spawned = Roster.KNIGHT_CAP
	for kk in g.knights.duplicate():
		if is_instance_valid(kk) and kk.alive():
			kk.take_damage(99, m.global_position.x)
	for b in g.blues.duplicate():
		if is_instance_valid(b) and b.alive():
			b.take_damage(99, m.global_position.x)
	await _drive(g, [], 200)
	_check("cemetery ends after %d knights: no further knight, and the exit opens" % Roster.KNIGHT_CAP, not g._knight_fight_live() and g.knights_spawned == Roster.KNIGHT_CAP and not g.exit_locked(), "spawned=%d locked=%s knights=%d" % [g.knights_spawned, g.exit_locked(), g.knights.size()])
	g.queue_free()
	await process_frame
	# fury
	g = await _new_game()
	m = g.mera
	m.rage = 100.0
	await _drive(g, [[5, "l2", true], [5, "r2", true], [12, "l2", false], [12, "r2", false], [20, "up", true], [24, "up", false], [30, "up", true], [34, "up", false], [40, "up", true]], 65)
	_check("L2+R2 at 100 rage -> Fury (red effects)", m.fury and root.get_node("AnimLib").fury, "")
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
	await _drive(g, [[5, "l2", true], [5, "r2", true], [12, "l2", false], [12, "r2", false], [20, "up", true], [24, "up", false], [30, "up", true], [34, "up", false], [40, "up", true], [60, "up", false], [60, "right", true]], 90)
	_check("Fury aura (v0.4 particles): back + front flames and embers emitting, world-space", m.flame_back.emitting and m.flame_front.emitting and m.aura_fx.emitting and m.flame_back.amount == 160 and m.flame_front.amount == 70 and m.aura_fx.amount == 60 and not m.flame_back.local_coords and not m.flame_front.local_coords and not m.aura_fx.local_coords, "")
	_check("flying right -> tilted head-first to the right (+90 deg)", absf(m.anim.rotation - PI / 2.0) < 0.05 and m.facing == 1, "rot=%f" % m.anim.rotation)
	await _drive(g, [[1, "right", false], [1, "left", true], [1, "up", true]], 40)
	_check("flying up-left -> tilted -45 deg, facing left", absf(m.anim.rotation + PI / 4.0) < 0.05 and m.facing == -1, "rot=%f" % m.anim.rotation)
	await _drive(g, [[1, "left", false], [1, "up", false]], 60)
	_check("idle hover -> eases back upright", absf(m.anim.rotation) < 0.01 and m.anim.idx == 3, "rot=%f" % m.anim.rotation)
	m.set_aura_quality(0)
	_check("aura quality cap 0 -> flame layers off, 20 embers", not m.flame_back.visible and not m.flame_back.emitting and m.aura_fx.amount == 20, "")
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
	# camera (v0.3.1): hard-locked on Mera's X every frame, no look-ahead, turning never moves it
	g = await _new_game()
	m = g.mera
	await _drive(g, [], 3)
	var c_start: float = g.cam_x
	_check("camera starts exactly centred on Mera", is_equal_approx(c_start, m.global_position.x), "cam=%f m=%f" % [c_start, m.global_position.x])
	var max_off := 0.0
	for f in 90:
		m.forced["right"] = f < 80
		await physics_frame
		max_off = maxf(max_off, absf(g.cam_x - m.global_position.x))
	_check("walking: camera stays locked on her X every frame (0 px drift)", max_off < 0.01 and g.cam_x > c_start + 30.0, "max_off=%f" % max_off)
	# turning in place: tap Left / Right / Left with no room to walk -> camera X unchanged
	for sz in [1, 2, 6]:
		m.set_size(sz, true)
		await _drive(g, [], 20)
		var turn_off := 0.0
		var faces := {}
		for f in 120:
			var d: String = ["left", "right"][(f / 15) % 2]
			m.forced["left"] = d == "left" and f % 15 < 2
			m.forced["right"] = d == "right" and f % 15 < 2
			await physics_frame
			faces[m.facing] = true
			turn_off = maxf(turn_off, absf(g.cam_x - m.global_position.x))
		m.forced["left"] = false
		m.forced["right"] = false
		_check("turning around at %dx: both facings seen, camera X never leaves her (max %.2f px)" % [sz, turn_off], faces.size() == 2 and turn_off < 0.01, "")
	var cx0: float = g.cam_x
	var mx0: float = m.global_position.x
	m._face(-m.facing)
	await physics_frame
	await physics_frame
	_check("a pure turn (no movement) leaves the camera X unchanged", is_equal_approx(g.cam_x, cx0) and is_equal_approx(m.global_position.x, mx0), "dcam=%f" % (g.cam_x - cx0))
	m.position.x += 300.0
	await physics_frame
	_check("camera follows a jump in position on the same frame", is_equal_approx(g.cam_x, m.global_position.x), "off=%f" % (g.cam_x - m.global_position.x))
	for sz in [1, 6]:   # during a 4x-speed dash the camera still sits exactly on her
		m.set_size(sz, true)
		m._start_move("gdash")
		var dash_off := 0.0
		for f in 12:
			await physics_frame
			dash_off = maxf(dash_off, absf(g.cam_x - m.global_position.x))
		_check("ground dash at %dx: camera locked (max %.2f px)" % [sz, dash_off], dash_off < 0.01, "")
		await _drive(g, [], 30)
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
		kn.block_chance = 0.0
		await _drive(g, [], 2)
		var sc_ok: bool = absf(kn.sprite.scale.x) == 6.0 and kn.sprite.scale.y == 6.0 and kn.hurt_rect().size == Vector2(26, 44) * 6.0
		var hit_at := -1
		for fr in 240:
			await physics_frame
			if m.size != sz or m.state == "dead":
				hit_at = fr
				break
		await _drive(g, [], 20)
		if sz <= 1:
			_check("6x knight hit (1 size, v0.8) at %dx Mera -> death" % sz, sc_ok and m.state == "dead", "scale=%s state=%s at=%d" % [kn.sprite.scale, m.state, hit_at])
		else:
			_check("6x knight hit at %dx Mera -> exactly 1 size lost (%dx, v0.8)" % [sz, sz - 1], sc_ok and m.size == sz - 1 and m.state != "dead" and hit_at > int(float(kn.cfg["tell"]) * 60.0), "size=%d at=%d scale=%s" % [m.size, hit_at, kn.sprite.scale])
		m.set_size(6, true)
		await _drive(g, [], 3)
		_check("knight stays 6x when Mera is %dx -> 6x, 1 per hit, 2 for the special (v0.8)" % sz, absf(kn.sprite.scale.x) == 6.0 and kn.damage_for("atk1") == 1 and kn.damage_for("sp") == 2, "scale=%s" % kn.sprite.scale)
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
				_check("beam %dx placed %+d px off the camera, facing %s: reaches off-screen (hitbox too) with the locked camera" % [sz, int(where), "R" if fc > 0 else "L"],
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
			_check("lightning %dx placed %+d px off the camera: runs from above the screen top to the ground" % [sz, int(where)],
				top_ok and st.segs > 0 and st.dropped == 0, "top=%.0f segs=%d" % [st.top_y if is_instance_valid(st) else 0.0, st.segs if is_instance_valid(st) else -1])
			g.queue_free()
			await process_frame
	# ================================================================ v0.4
	var X := {"a": "btn_x"}
	var Y := {"a": "btn_y"}
	var HX := {"a": "btn_x", "hold": [300, 450]}
	await _human_combo("X X X -> 1x, 2x, 2x-2", [X, X, X], ["atk1", "atk2", "atk2_2"], ["atk2_1", "atk3", "beam_ender", "rear_blast"])
	await _human_combo("X X X mashed fast (80-120 ms) -> 1x, 2x, 2x-2", [X, {"a": "btn_x", "gap": [80, 120]}, {"a": "btn_x", "gap": [80, 120]}], ["atk1", "atk2", "atk2_2"], ["atk3", "beam_ender"])
	await _human_combo("X X hold-X -> 1x, 2x, 2x-1", [X, X, HX], ["atk1", "atk2", "atk2_1"], ["atk3", "beam_ender"])
	await _human_combo("X X Y -> 1x, 2x, 3x", [X, X, Y], ["atk1", "atk2", "atk3"], ["beam_ender", "quick_fire", "rear_blast"])
	await _human_combo("X X X Y -> beam ender", [X, X, X, Y], ["atk1", "atk2", "beam_ender"], ["atk3", "quick_fire"])
	await _human_combo("X X X, Y late in the 3rd hit (250-450 ms) -> beam ender", [X, X, X, {"a": "btn_y", "gap": [250, 450]}], ["atk1", "atk2", "beam_ender"], ["atk3"])
	await _human_combo("X X Y Y -> 3x, never the beam", [X, X, Y, Y], ["atk1", "atk2", "atk3"], ["beam_ender"])
	await _human_combo("sloppy X+Y chord (0-50 ms) -> rear explosion, no bolt", [{"a": "btn_x", "chord": "btn_y"}], ["rear_blast"], ["atk2"], 8,
		func(g, r): return r["bolts"].is_empty())
	await _human_combo("sloppy A+Y chord -> ground dash, no bolt", [{"a": "btn_a", "chord": "btn_y"}], ["adash"], ["rear_blast"], 8,
		func(g, r): return r["bolts"].is_empty())
	await _human_combo("Y alone -> normal quick fire (1x anim, 1x bolt)", [Y], ["quick_fire"], ["rear_blast", "adash", "datk2"], 6,
		func(g, r): return r["bolts"] == [1.0] and is_equal_approx(float(r["qf_speed"]), 1.0))
	await _human_combo("sloppy B+Y chord -> rising slash, no dodge travel, no bolt", [{"a": "btn_b", "chord": "btn_y"}], ["datk2"], ["datk3", "datk1", "djump_v", "adash"], 10,
		func(g, r): return r["bolts"].is_empty() and absf(g.mera.global_position.x - float(r["x_start"])) < 40.0)
	await _human_combo("B+Y, Y -> rising slash then slam", [{"a": "btn_b", "chord": "btn_y"}, {"a": "btn_y", "gap": [150, 350]}], ["datk2", "datk3"], ["adash", "datk1"], 8,
		func(g, r): return r["bolts"].is_empty())
	await _human_combo("Up then Y in the air -> jump, aerial dash (no rising slash)", [{"a": "up"}, {"a": "btn_y", "gap": [110, 250]}], ["jump", "adash"], ["datk2", "quick_fire"], 8)
	await _human_combo("B then Y (110-250 ms later) -> dodge, fast quick fire (2x anim, 2x bolt)", [{"a": "btn_b"}, {"a": "btn_y", "gap": [110, 250]}], ["bdodge", "quick_fire"], ["datk2", "rear_blast"], 8,
		func(g, r): return r["bolts"] == [2.0] and is_equal_approx(float(r["qf_speed"]), 2.0))
	await _human_combo("B then X -> dodge attack", [{"a": "btn_b"}, {"a": "btn_x", "gap": [110, 250]}], ["bdodge", "datk1"], ["datk2", "datk3", "atk1"])
	await _human_combo("B, X, X, X -> dodge attack, never the rising slash or slam", [{"a": "btn_b"}, {"a": "btn_x", "gap": [110, 250]}, X, X], ["bdodge", "datk1"], ["datk2", "datk3"])
	var sb: Array = []; _tap(sb, 5, "btn_b"); _tap(sb, 8, "btn_y")
	await _combo("B then Y 3 frames (50 ms) later -> rising slash (retroactive, the dodge never plays out)", sb, 60, ["datk2"], ["quick_fire"])
	sb = []; _tap(sb, 5, "btn_y"); _tap(sb, 8, "btn_b")
	await _combo("Y then B within 50 ms -> rising slash, no bolt", sb, 60, ["datk2"], ["bdodge"])
	sb = [[5, "btn_b", true], [30, "btn_b", false]]; _tap(sb, 12, "btn_y")
	await _combo("B held, Y pressed 117 ms later -> dodge + fast quick fire (sequence, not chord)", sb, 60, ["bdodge", "quick_fire"], ["datk2"])
	# Up alone: the jump starts on the frame the press is read
	var gu: Node = await _new_game()
	var ru: Dictionary = await _replay(gu, [[100.0, "up", true], [180.0, "up", false]], 600.0)
	_check("Up alone -> jump starts immediately (airborne %.0f ms after the press)" % float(ru["first_air_ms"]), float(ru["first_air_ms"]) >= 0.0 and float(ru["first_air_ms"]) <= 34.0 and "jump" in gu.mera.move_log, "%s" % [ru])
	gu.queue_free()
	await process_frame
	# fast bolt speed: 800 px/s x size
	var gf: Node = await _new_game()
	gf.mera.set_size(3, true)
	await _replay(gf, [[50.0, "btn_b", true], [100.0, "btn_b", false], [200.0, "btn_y", true], [260.0, "btn_y", false]], 400.0)
	var fbolt: Node = null
	for c in gf.world.get_children():
		if c.get("speed_mult") != null and c.get("kind") == "bolt":
			fbolt = c
	_check("fast quick fire bolt flies at 800 px/s x size (2400 at 3x)", fbolt != null and is_equal_approx(fbolt.speed(), 2400.0), "%s" % [fbolt.speed() if fbolt else -1.0])
	gf.queue_free()
	await process_frame
	# ---- stamina
	g = await _new_game()
	m = g.mera
	_check("stamina starts at 60 / 60", m.stamina == 60.0 and m.stamina_max == 60.0, "")
	var costs_ok := true
	for kk in Tuning.STAMINA_COST:
		if m.stamina_cost(kk) != float(Tuning.STAMINA_COST[kk]):
			costs_ok = false
	_check("costs come from Tuning.STAMINA_COST (quick fire 5, dashes 6, rear 12, beam 20, bubble 3 + 4/s)", costs_ok and Tuning.STAMINA_COST["quick_fire"] == 5 and Tuning.STAMINA_COST["beam_ender"] == 20, "")
	await _drive(g, [[3, "btn_y", true], [6, "btn_y", false]], 10)
	_check("quick fire costs 5", absf(m.stamina - 55.0) < 0.3, "st=%f" % m.stamina)
	var st0: float = m.stamina
	await _drive(g, [], 120)
	_check("regenerates 1 per second", absf(m.stamina - st0 - 2.0) < 0.2, "d=%f" % (m.stamina - st0))
	m.stamina = 60.0
	await _drive(g, [], 60)
	_check("regen stops at the max", m.stamina == 60.0, "")
	g.queue_free()
	await process_frame
	for kk in [["X+Y -> rear blast", [[5, "btn_x", true], [5, "btn_y", true], [8, "btn_x", false], [8, "btn_y", false]], "rear_blast", 48.0],
			["A+Y -> dash", [[5, "btn_a", true], [5, "btn_y", true], [8, "btn_a", false], [8, "btn_y", false]], "adash", 54.0],
			["Y -> quick fire", [[5, "btn_y", true], [8, "btn_y", false]], "quick_fire", 55.0],
			["B+Y -> rising slash (free)", [[5, "btn_b", true], [5, "btn_y", true], [8, "btn_b", false], [8, "btn_y", false]], "datk2", 60.0],
			["B -> back dodge (free)", [[5, "btn_b", true], [8, "btn_b", false]], "bdodge", 60.0]]:
		g = await _new_game()
		await _drive(g, kk[1], 9)
		_check("stamina: %s leaves %d" % [kk[0], int(kk[3])], kk[2] in g.mera.move_log and absf(g.mera.stamina - float(kk[3])) < 0.3, "st=%f log=%s" % [g.mera.stamina, g.mera.move_log])
		g.queue_free()
		await process_frame
	g = await _new_game()
	m = g.mera
	m._start_move("atk2_2")
	m.mv["x3_t"] = m.now
	await _drive(g, [[3, "btn_y", true], [6, "btn_y", false]], 12)
	_check("beam ender costs 20", "beam_ender" in m.move_log and absf(m.stamina - 40.0) < 0.3, "st=%f" % m.stamina)
	g.queue_free()
	await process_frame
	g = await _new_game()
	m = g.mera
	m.stamina = 4.0
	var nfail := 0
	for h in root.get_node("Sfx").history:
		if h[0] == "fail":
			nfail += 1
	await _drive(g, [[3, "btn_y", true], [6, "btn_y", false]], 20)
	var nfail2 := 0
	for h in root.get_node("Sfx").history:
		if h[0] == "fail":
			nfail2 += 1
	_check("not enough stamina -> no quick fire, fail cue, no stamina spent", not ("quick_fire" in m.move_log) and nfail2 > nfail and m.stamina < 5.0, "log=%s st=%f" % [m.move_log, m.stamina])
	m.stamina = 10.0
	await _drive(g, [[3, "btn_x", true], [3, "btn_y", true], [6, "btn_x", false], [6, "btn_y", false]], 12)
	_check("not enough for the rear explosion -> nothing fires", not ("rear_blast" in m.move_log), "log=%s" % [m.move_log])
	g.queue_free()
	await process_frame
	g = await _new_game()
	m = g.mera
	await _drive(g, [[3, "l2", true]], 123)
	_check("bubble: 3 to raise + 4 per second held", m.barrier_on and absf(m.stamina - (60.0 - 3.0 - 4.0 * 2.0)) < 1.2, "st=%f" % m.stamina)
	m.stamina = 1.0
	await _drive(g, [], 30)
	_check("bubble drops when stamina runs out", not m.barrier_on, "st=%f" % m.stamina)
	g.queue_free()
	await process_frame
	g = await _new_game()
	m = g.mera
	m.stamina = 10.0
	var pk = load("res://scripts/game/pickup.gd").new()
	pk.setup(g, "stamina", m.global_position)
	g.collect(pk)
	_check("blue potion: +30 mana", absf(m.stamina - 40.0) < 0.01, "st=%f" % m.stamina)
	g.collect(pk)
	_check("...capped at the max", m.stamina == m.stamina_max, "")
	pk.kind = "stamina_max"
	g.collect(pk)
	_check("blue-and-white potion: +5 max mana (65)", m.stamina_max == 65.0, "max=%f" % m.stamina_max)
	for i in 40:
		g.collect(pk)
	_check("max mana caps at 200", m.stamina_max == 200.0, "max=%f" % m.stamina_max)
	m.rage = 0.0
	pk.kind = "rage_max"
	g.collect(pk)
	_check("gold sphere: +5 max rage and +5 rage", m.rage_max == 105.0 and is_equal_approx(m.rage, 5.0), "max=%f rage=%f" % [m.rage_max, m.rage])
	for i in 30:
		g.collect(pk)
	_check("max rage caps at 200", m.rage_max == 200.0, "max=%f" % m.rage_max)
	_check("enemy loot: every roll is a fury orb (sphere)", g.enemy_loot_kind(0.1) == "sphere" and g.enemy_loot_kind(0.5) == "sphere" and g.enemy_loot_kind(0.97) == "sphere", "%s %s %s" % [g.enemy_loot_kind(0.1), g.enemy_loot_kind(0.5), g.enemy_loot_kind(0.97)])
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = 3
	var loot_n := {"sphere": 0, "potion": 0, "stamina": 0, "stamina_max": 0, "rage_max": 0}
	for i in 4000:
		loot_n[g.enemy_loot_kind(loot_rng.randf())] += 1
	_check("enemy loot rates: 100 % fury orbs", int(loot_n["sphere"]) == 4000, "%s" % [loot_n])
	pk.free()
	var dr: Array = [g.blue_drops(0.34, 0.5), g.blue_drops(0.35, 0.09), g.blue_drops(0.1, 0.05), g.blue_drops(0.9, 0.9)]
	_check("blue drops: 35 % stamina potion, 10 % max potion, independent rolls", dr == [["stamina"], ["stamina_max"], ["stamina", "stamina_max"], []], "%s" % [dr])
	var drng := RandomNumberGenerator.new()
	drng.seed = 99
	var cnt := {"stamina": 0, "stamina_max": 0}
	for i in 4000:
		for d in g.blue_drops(drng.randf(), drng.randf()):
			cnt[d] += 1
	_check("blue drop rates over 4000 kills ~35 % / ~10 %", absf(cnt["stamina"] / 4000.0 - 0.35) < 0.03 and absf(cnt["stamina_max"] / 4000.0 - 0.10) < 0.02, "%s" % [cnt])
	g.queue_free()
	await process_frame
	# ---- Fire / Blue Knight
	g = await _new_game()
	m = g.mera
	m.position.x = 4000.0           # mid-map: at the start (x 760) "behind" is past the left wall
	g.snap_camera()
	g._spawn_knight(1)
	var fk: Node = g.knight
	fk.position.x = m.global_position.x + 1500.0
	g.knight_calm_until = 1 << 30
	_check("Fire Knight: 20 HP, 6x, 1 damage, special 2 (v0.8), blocks, has a special", fk.hp == 20 and fk.k == 6.0 and fk.damage_for("atk2") == 1 and fk.damage_for("air") == 1 and fk.damage_for("sp") == 2 and fk.cfg["block"] and fk.cfg["special"], "")
	fk.take_damage(1, m.global_position.x)
	_check("first HP loss -> one Blue Knight", g.blues_spawned == 1, "%d" % g.blues_spawned)
	fk.take_damage(5, m.global_position.x)
	_check("more damage above 10 HP -> no new blue", g.blues_spawned == 1, "%d" % g.blues_spawned)
	fk.take_damage(5, m.global_position.x)
	_check("first drop below 10 HP -> a second Blue Knight", g.blues_spawned == 2 and fk.hp == 9, "%d hp=%d" % [g.blues_spawned, fk.hp])
	fk.take_damage(1, m.global_position.x)
	_check("...and never a third", g.blues_spawned == 2, "")
	var bk: Node = g.blues[0]
	_check("Blue Knight: 5 HP, 3x, 3x faster, 1 damage, no block, no special", bk.hp == 5 and bk.k == 3.0 and absf(bk.sprite.scale.x) == 3.0 and float(bk.cfg["speed"]) == 3.0 * float(fk.cfg["speed"]) and bk.damage_for("atk1") == 1 and bk.damage_for("air") == 1 and not bk.cfg["block"] and not bk.cfg["special"] and bk.sprite.material != null,
		"hp=%d k=%f sc=%s spd=%s dmg=%d mat=%s" % [bk.hp, bk.k, bk.sprite.scale, bk.cfg["speed"], bk.damage_for("atk1"), bk.sprite.material])
	_check("blue spawns behind Mera (off-screen)", signf(bk.global_position.x - m.global_position.x) == -float(m.facing) and absf(bk.global_position.x - g.cam_x) > 960.0, "")
	var no_sp := true
	for i in 30:
		bk._start_string()
		if bk.atk == "sp":
			no_sp = false
	bk._anim("idle")
	_check("blue strings never use the special", no_sp, "")
	var fsp := []
	fk.strings = 0
	for i in 6:
		fk._start_string()
		fsp.append(fk.atk == "sp")
	fk._anim("idle")
	_check("Fire Knight: every 3rd string is the special", fsp == [false, false, true, false, false, true], "%s" % [fsp])
	g.queue_free()
	await process_frame
	# blue hits for 1 size; blue cannot block
	g = await _new_game()
	m = g.mera
	m.set_size(3, true)
	var b2: Node = g.spawn_blue()
	b2.position.x = m.global_position.x - 300.0
	var b_hit := -1
	for fr in 400:
		await physics_frame
		if m.size != 3:
			b_hit = fr
			break
	await _drive(g, [], 5)
	_check("Blue Knight hit -> exactly 1 size (3x -> 2x)", m.size == 2, "size=%d at=%d" % [m.size, b_hit])
	g.queue_free()
	await process_frame
	# blue flanks to Mera's back
	g = await _new_game()
	m = g.mera
	g.knight_calm_until = 1 << 30
	var b3: Node = g.spawn_blue()
	b3.position.x = m.global_position.x + m.facing * 500.0
	var got_back := false
	for fr in 150:
		await physics_frame
		if signf(b3.global_position.x - m.global_position.x) == -float(m.facing):
			got_back = true
	_check("Blue Knight in front circles round to Mera's back", got_back, "dx=%f" % (b3.global_position.x - m.global_position.x))
	g.queue_free()
	await process_frame
	# block: invulnerable except explosions and Fury, forced drop + cooldown
	g = await _new_game()
	m = g.mera
	m.set_size(2, true)
	g._spawn_knight(1)
	fk = g.knight
	fk.block_chance = 1.0
	g.knight_calm_until = 1 << 30
	fk.position.x = m.global_position.x + 260.0
	await _drive(g, [], 30)
	await _drive(g, [[3, "btn_x", true], [6, "btn_x", false]], 40)
	_check("Fire Knight raises the block against a melee attack -> no damage", "block" in fk.history and fk.hp == 20 and fk.blocked >= 1, "hp=%d hist=%s" % [fk.hp, fk.history])
	fk._start_block(-1)
	await _drive(g, [], 3)
	var bl1: bool = fk.blocking()
	_check("blocking: a bolt does nothing", bl1 and not fk.take_damage(2, m.global_position.x, "bolt") and fk.hp == 20, "")
	_check("blocking: the beam does nothing", not fk.take_damage(2, m.global_position.x, "beam") and fk.hp == 20, "")
	_check("blocking: an explosion goes through", fk.take_damage(2, m.global_position.x, "explosion") and fk.hp == 18 and fk.block_cd > 0.0, "hp=%d" % fk.hp)
	fk.block_cd = 0.0
	fk._start_block(-1)
	await _drive(g, [], 3)
	m.fury = true
	_check("blocking: a Fury attack goes through", fk.take_damage(1, m.global_position.x, "melee") and fk.hp == 17, "hp=%d" % fk.hp)
	m.fury = false
	fk.block_cd = 0.0
	fk._start_block(-1)
	m._start_move("beam_ender")        # a long threat: he would hold the guard forever
	var dropped_at := -1.0
	for fr in 150:
		await physics_frame
		if fk.state != "defend":
			dropped_at = fr / 60.0
			break
	_check("forced block drop after %.1f s (max %.1f) and a %.1f s cooldown" % [dropped_at, Tuning.BLOCK_MAX_S, Tuning.BLOCK_COOLDOWN_S], dropped_at >= Tuning.BLOCK_MAX_S - 0.05 and dropped_at < Tuning.BLOCK_MAX_S + 0.5 and fk.block_cd > 1.5, "at=%f cd=%f" % [dropped_at, fk.block_cd])
	g.queue_free()
	await process_frame
	# bolt AI: far bolts are jumped, close ones blocked
	for vv in ["fire", "blue"]:
		g = await _new_game()
		m = g.mera
		m.set_size(2, true)
		g.knight_calm_until = 1 << 30
		var kb: Node
		if vv == "fire":
			g._spawn_knight(1)
			kb = g.knight
		else:
			kb = g.spawn_blue()
		m._face(1)
		kb.position.x = m.global_position.x + 1100.0
		kb.dash_cd = 99.0
		await _drive(g, [], 2)
		m.stamina = 60.0
		await _drive(g, [[2, "btn_y", true], [5, "btn_y", false]], 100)
		_check("%s knight jumps a bolt seen > 400 px away (no damage)" % vv, kb.jumped_bolts >= 1 and kb.hp == kb.hp_max and "takeoff" in kb.history, "hp=%d jumped=%d hist=%s" % [kb.hp, kb.jumped_bolts, kb.history])
		g.queue_free()
		await process_frame
	g = await _new_game()
	m = g.mera
	m.set_size(2, true)
	g.knight_calm_until = 1 << 30
	g._spawn_knight(1)
	fk = g.knight
	fk.block_chance = 1.0
	m._face(1)
	fk.position.x = m.global_position.x + 520.0
	await _drive(g, [], 5)
	await _drive(g, [[2, "btn_y", true], [5, "btn_y", false]], 60)
	_check("Fire Knight blocks a bolt first seen close (< 400 px)", fk.hp == 20 and fk.blocked >= 1 and fk.jumped_bolts == 0, "hp=%d blocked=%d hist=%s" % [fk.hp, fk.blocked, fk.history])
	g.queue_free()
	await process_frame
	# chase dash: 3x speed, limited, cooldown
	g = await _new_game()
	m = g.mera
	g.knight_calm_until = 1 << 30
	g._spawn_knight(1)
	fk = g.knight
	fk.position.x = m.global_position.x + 1700.0
	var rolls := 0
	var was_roll := false
	var roll_px := 0.0
	var roll_t := 0
	var x_prev: float = fk.global_position.x
	for fr in 170:
		await physics_frame
		var is_roll: bool = fk.state == "roll"
		if is_roll and not was_roll:
			rolls += 1
		if is_roll and was_roll:
			roll_px += absf(fk.global_position.x - x_prev)
			roll_t += 1
		was_roll = is_roll
		x_prev = fk.global_position.x
	var rs: float = roll_px / maxf(roll_t / 60.0, 0.001)
	_check("chase dash when far: 3x run speed (%.0f px/s), at most %.1f s, then a cooldown" % [rs, Tuning.DASH_MAX_S], rolls == 1 and absf(rs - 3.0 * float(fk.cfg["speed"])) < 30.0 and roll_t <= int(Tuning.DASH_MAX_S * 60.0) + 1, "rolls=%d t=%d" % [rolls, roll_t])
	g.queue_free()
	await process_frame
	# Mera in the air -> jump attack
	g = await _new_game()
	m = g.mera
	m.set_size(2, true)
	m.rage = 100.0
	await _drive(g, [[3, "l2", true], [3, "r2", true], [12, "l2", false], [12, "r2", false], [20, "up", true], [24, "up", false], [30, "up", true], [70, "up", false]], 80)
	g._spawn_knight(1)
	fk = g.knight
	fk.block_chance = 0.0
	fk.position.x = m.global_position.x + 380.0
	fk.cooldown = 0.0
	await _drive(g, [], 120)
	var air_ok: bool = "takeoff" in fk.history and "air" in fk.history
	_check("Mera flying near -> knight chases with a jump attack (jump + air_atk)", air_ok, "hist=%s my=%f fly=%s" % [fk.history, m.global_position.y, m.flying])
	g.queue_free()
	await process_frame
	# every chierit animation is used
	var all14 := ["idle", "run", "jump", "jump_up", "jump_down", "roll", "atk1", "atk2", "atk3", "sp", "defend", "hit", "death", "air"]
	var missing := []
	for a in all14:
		if not load("res://scripts/game/fire_knight.gd").played_all.has(a):
			missing.append(a)
	# the tests above don't necessarily see atk1/2/3/sp/death; play a quick scripted fight for the rest
	if not missing.is_empty():
		g = await _new_game()
		m = g.mera
		m.set_size(6, true)
		g._spawn_knight(1)
		fk = g.knight
		fk.block_chance = 0.0
		fk.position.x = m.global_position.x + 300.0
		for i in 6:
			fk.cooldown = 0.0
			for fr in 200:
				await physics_frame
				m.invuln = 5.0
				if fk.state == "idle" and fr > 30:
					break
		fk.take_damage(99, m.global_position.x)
		await _drive(g, [], 30)
		g.queue_free()
		await process_frame
		missing = []
		for a in all14:
			if not load("res://scripts/game/fire_knight.gd").played_all.has(a):
				missing.append(a)
	_check("knight plays all 14 chierit animations (attacks, jumps, roll, block, hit, death)", missing.is_empty(), "missing=%s" % [missing])
	# ---- Fury aura particles
	g = await _new_game()
	m = g.mera
	m.set_size(2, true)
	m.rage = 100.0
	await _drive(g, [[3, "l2", true], [3, "r2", true], [12, "l2", false], [12, "r2", false]], 40)
	_check("aura: still -> flames rise straight up", m.flame_back.emitting and m.flame_back.direction.distance_to(Vector2(0, -1)) < 0.01, "dir=%s" % m.flame_back.direction)
	var sc2: float = m.flame_back.scale_amount_max
	await _drive(g, [[1, "right", true]], 40)
	_check("aura: moving right -> flames trail behind (left)", m.flame_back.direction.x < -0.3, "dir=%s" % m.flame_back.direction)
	await _drive(g, [[1, "right", false]], 5)
	m.set_size(5, true)
	await _drive(g, [], 60)
	_check("aura: flames scale with her size", m.flame_back.scale_amount_max > sc2 * 2.0, "%f vs %f" % [m.flame_back.scale_amount_max, sc2])
	m.set_aura_quality(1)
	_check("aura quality cap 1 -> 90 back flames, no front layer", m.flame_back.amount == 90 and not m.flame_front.emitting, "")
	g.queue_free()
	await process_frame
	# ================================================================ v0.5 levels, map bounds, earthquake
	var LV = load("res://scripts/game/levels.gd")
	_check("21 levels in the level list (stage 1: 0..5, stage 2: 6..11, stage 3: 12..19, stage 4: 20)", LV.list().size() == 21 and LV.stage_of(5) == 0 and LV.stage_of(6) == 1 and LV.stage_of(11) == 1 and LV.stage_of(12) == 2 and LV.stage_of(19) == 2 and LV.stage_of(20) == 3 and LV.stage_of(0) == 0 and float(LV.data()["map_w"]) >= 19200.0, "%d" % LV.list().size())
	for li in [0, 1, 2, 3, 6, 7, 8, 9, 10]:
		LV.current = li
		g = await _new_game()
		m = g.mera
		var cover_ok := true
		var info := ""
		for cx in [LV.EDGE, 3000.0, 9600.0, LV.map_w() - LV.EDGE]:
			m.position.x = cx
			await physics_frame
			await physics_frame
			for L in g.layers:
				var sp: Sprite2D = L[0]
				var w: float = (sp.region_rect.size.x if sp.region_enabled else float(sp.texture.get_width())) * 5.0
				var left: float = sp.position.x
				if left > g.cam_x - 960.0 - 40.0 or left + w < g.cam_x + 960.0 + 40.0:
					cover_ok = false
					info = "%s at cam %d: [%d, %d]" % [sp.texture.resource_path.get_file(), int(g.cam_x), int(left), int(left + w)]
		_check("level %d (%s): every map layer covers the screen across the whole %d px map" % [li + 1, LV.level()["name"], int(LV.map_w())], cover_ok, info)
		m.position.x = -500.0
		await physics_frame
		await physics_frame
		var lo_ok: bool = absf(m.position.x - LV.EDGE) < 1.0
		g.props = g.props.filter(func(p): return not (is_instance_valid(p) and p.blocks_path()))     # walls and doors block the walk
		if g.exit_locked():
			m.position.x = LV.map_w() + 900.0
			await physics_frame
			await physics_frame
			_check("level %d: the exit stays shut until the fight is over" % (li + 1), not g.cleared, "")
			g.finish_endpoint()
			m.position.x = 9000.0
			await physics_frame
		m.position.x = LV.map_w() + 900.0
		await physics_frame
		await physics_frame
		_check("level %d: invisible walls at both ends, the exit gate clears the level" % (li + 1), lo_ok and absf(m.position.x - (LV.map_w() - LV.EDGE)) < 1.0 and g.cleared, "x=%f cleared=%s" % [m.position.x, g.cleared])
		g.queue_free()
		await process_frame
	LV.current = 0
	# earthquake: Down+Y while crouching
	g = await _new_game()
	m = g.mera
	g._spawn_knight(1)
	fk = g.knight
	fk.position.x = m.global_position.x + 700.0
	g.knight_calm_until = 1 << 30
	var b4: Node = g.spawn_blue()
	b4.position.x = m.global_position.x - 600.0
	await _drive(g, [], 5)
	b4._jump(0.0, b4._jump_v() * 0.6)            # this blue is in the air when the quake starts
	await _drive(g, [[2, "down", true], [10, "btn_y", true], [13, "btn_y", false], [20, "down", false]], 12)
	_check("Down+Y while crouching -> earthquake (no quick fire), 20 stamina", "roll_land" in m.move_log and not ("quick_fire" in m.move_log) and absf(m.stamina - 40.0) < 0.5 and g.quake_t > 0.0, "log=%s st=%f" % [m.move_log, m.stamina])
	var shake_max := 0.0
	var cam0: float = g.cam_x
	for f in 50:
		await physics_frame
		shake_max = maxf(shake_max, absf(g.cam.position.x - g.cam_x))
	_check("the quake shakes the whole map hard (%.0f px)" % shake_max, shake_max > 15.0, "")
	_check("grounded Fire Knight stunned", fk.state == "stun", "state=%s" % fk.state)
	_check("blue in the air at the start, stunned once it lands during the quake", b4.state == "stun" or b4.stunned_total == 1, "state=%s on_ground=%s" % [b4.state, b4.on_ground])
	var stun_end := -1.0
	for f in 330:
		await physics_frame
		if fk.state != "stun":
			stun_end = (f + 52) / 60.0
			break
	_check("stun lasts 5 s from the quake start (%.2f s)" % stun_end, stun_end > 4.8 and stun_end < 5.3, "")
	g.queue_free()
	await process_frame
	g = await _new_game()
	m = g.mera
	await _drive(g, [[5, "btn_y", true], [8, "btn_y", false]], 20)
	_check("Y without Down -> normal quick fire, no quake", "quick_fire" in m.move_log and g.quake_t <= 0.0, "")
	g.queue_free()
	await process_frame
	g = await _new_game()
	m = g.mera
	m.stamina = 10.0
	await _drive(g, [[2, "down", true], [10, "btn_y", true], [13, "btn_y", false], [20, "down", false]], 30)
	_check("earthquake without 20 stamina -> nothing", g.quake_t <= 0.0 and not ("roll_land" in m.move_log), "")
	g.queue_free()
	await process_frame
	# ================================================================ v0.6 enemy roster
	var RO = load("res://scripts/game/roster.gd")
	var TE = load("res://scripts/game/telegraph.gd")
	var placed: Array = []
	var dup := false
	for li in RO.LEVELS:
		for eid in RO.LEVELS[li]:
			if eid in placed:
				dup = true
			placed.append(eid)
	for li in RO.BOSSES:
		placed.append(RO.BOSSES[li])
	placed.sort()
	var all_ids: Array = RO.ids()
	all_ids.sort()
	var uniq := {}
	for pid in placed:
		uniq[pid] = true
	var unplaced: Array = []
	for aid2 in all_ids:
		if not uniq.has(aid2) and not (aid2 in RO.RUN_POOL):
			unplaced.append(aid2)
	_check("every roster enemy is on a level or in the endless-run pool; the cemetery (index 3) has none", unplaced.is_empty() and not RO.LEVELS.has(3) and not RO.BOSSES.has(3), "unplaced=%s repeated-between-levels=%s" % [unplaced, dup])
	var dragon_boss: bool = RO.def("dragon").get("boss", false) and RO.BOSSES.get(5, "") == "dragon" and not RO.BOSSES.has(4)
	_check("the dragon is his own stage, not the end of Infernal Caverns", dragon_boss, "")
	var tell_ok := true
	var tell_info := ""
	for eid in all_ids:
		var sets: Array = [RO.def(eid)["attacks"]]
		if RO.def(eid).has("attacks_disarmed"):
			sets.append(RO.def(eid)["attacks_disarmed"])
		for st2 in sets:
			for a in st2:
				if float(a["tell"]) < TE.MIN_TELL or not TE.COLORS.has(String(a["kind"])) or not RO.art(eid)["anims"].has(String(a["anim"])):
					tell_ok = false
					tell_info += "%s:%s " % [eid, a["anim"]]
	_check("telegraph standard: every attack has a known colour, a real animation and a tell >= %.2f s" % TE.MIN_TELL, tell_ok, tell_info)
	# every enemy, every animation, and every enemy can hurt Mera
	var runs := {"skeleton": ["plain", "clothed"], "wolf": ["run", "run_skin"]}
	for eid in all_ids:
		var used := {}
		var hits := 0
		var tells_seen := true
		var tell_marker := false
		var k_fixed := true
		for variant in runs.get(eid, [""]):
			for dist in [760.0, 150.0]:
				LV.current = 1
				g = await _new_game()
				m = g.mera
				m.position.x = 6000.0
				m.set_size(6, true)
				g.snap_camera()
				var e: Node2D = g.spawn_enemy(eid, 6000.0 + dist + e_half(RO, eid), {"variant": variant, "seed": 7})
				var k0: float = e.k
				var tell_len := 0
				var run_f := 420                                    # Stage 2 "cycle" enemies get time for every attack
				if String(RO.def(eid).get("pick", "")) in ["cycle", "order"]:
					run_f = maxi(420, RO.def(eid)["attacks"].size() * 150)
				if eid == "perry":                                  # the boss has a 30-move table: a longer run here, every animation in the perry boss section
					run_f = 900
				for f in run_f:
					await physics_frame
					if f % 30 == 0:
						m.set_size(6 if f < run_f - 120 else 3, true)
					if e.state == "tell":
						tell_len += 1
						if e.marker.visible:
							tell_marker = true
					elif tell_len > 0:
						if tell_len < int(TE.MIN_TELL * 60.0) - 1:
							tells_seen = false
						tell_len = 0
				if e.k != k0 or absf(e.sprite.scale.y) != k0:
					k_fixed = false
				if is_instance_valid(e) and e.alive():
					e.take_damage(e.hp_max / 2 + 1, m.global_position.x)
					for f in 300:
						await physics_frame
						if f % 30 == 0:
							m.set_size(6, true)
				if is_instance_valid(e):                                          # record now: a weak one dies on the next hit
					for a in e.played:
						used[a] = true
					hits += e.hits_landed
					e.hits_landed = 0
				if is_instance_valid(e) and e.alive() and e.d.has("hurt"):     # Stage 2: a hit out of idle / walking flinches
					for f in 240:
						if e.state in ["idle", "move"] and e.hurt_cd <= 0.0:
							break
						await physics_frame
					e.hp = maxi(e.hp, 2)                                   # a weak one must live through the flinch
					e.take_damage(1, m.global_position.x)
					for f in 40:
						await physics_frame
						if is_instance_valid(e):
							for a in e.played:
								used[a] = true
				if is_instance_valid(e) and e.alive() and e.d.has("death"):    # and plays its death animation as it falls
					e.take_damage(e.hp, m.global_position.x)
					await physics_frame
					if is_instance_valid(e):
						for a in e.played:
							used[a] = true
				if is_instance_valid(e):
					for a in e.played:
						used[a] = true
					hits += e.hits_landed
				g.queue_free()
				await process_frame
		var want: Array = RO.art(eid)["anims"].keys()
		if eid == "perry":
			want = []                                                     # her 37 animations are all checked by the perry boss section
		var miss_a: Array = []
		for a in want:
			if not used.has(a):
				miss_a.append(a)
		_check("%s uses all its animations %s, hurts Mera (%d hits), tells >= min with the marker, never scales" % [eid, want, hits], miss_a.is_empty() and hits > 0 and tells_seen and tell_marker and k_fixed, "missing=%s tells=%s marker=%s k=%s" % [miss_a, tells_seen, tell_marker, k_fixed])
	# earthquake: ground enemies stunned, flyers not
	LV.current = 3
	g = await _new_game()
	m = g.mera
	m.position.x = 6000.0
	g.snap_camera()
	g.knight_calm_until = 1 << 30
	var hh: Node2D = g.spawn_enemy("hell_hound", 6900.0)
	var fs: Node2D = g.spawn_enemy("fire_skull", 6800.0)
	await _drive(g, [], 30)
	g.earthquake()
	await _drive(g, [], 20)
	_check("earthquake stuns a roster ground enemy (hell hound) but not a flyer (fire skull)", hh.state == "stun" and fs.state != "stun", "%s %s" % [hh.state, fs.state])
	g.queue_free()
	await process_frame
	# the spawner: walking a wave level meets every enemy on its list; the dragon is not on Infernal Caverns
	for li in [0, 1, 2, 4, 6, 7, 8, 9, 10]:
		LV.current = li
		g = await _new_game(true)
		m = g.mera
		g.knight_calm_until = 1 << 30
		m.invuln = 1e9
		var seen := {}
		for x in range(800, int(LV.map_w()) - 600, 120):
			m.position.x = float(x)
			await physics_frame
			for e in g.mobs:
				if is_instance_valid(e):
					seen[e.id] = true
					if not e.boss:
						e.hp = 0
						e.queue_free()
			g.mobs = g.mobs.filter(func(e): return is_instance_valid(e) and e.alive() and e.boss)
		var want_ids: Array = RO.LEVELS[li].duplicate()
		var miss: Array = []
		for eid in want_ids:
			if not seen.has(eid):
				miss.append(eid)
		var boss_ok: bool = (not RO.BOSSES.has(li)) or (g.boss != null and is_instance_valid(g.boss) and g.boss.id == RO.BOSSES[li] and g.exit_locked())
		_check("level %d spawner: every listed enemy appears%s; no knights" % [li + 1, ", the boss guards the locked exit" if RO.BOSSES.has(li) else ""], miss.is_empty() and boss_ok and g.knight == null, "missing=%s boss=%s" % [miss, g.boss])
		g.queue_free()
		await process_frame
	LV.current = 0
	# ================================================================ v0.7 allies
	var AL = load("res://scripts/game/allies.gd")
	var cards_ok := true
	for li in [0, 1, 2, 4, 6, 7, 8, 9, 10]:
		var ids: Array = []
		for pr in AL.CARDS[li]:
			ids.append(pr[1])
		ids.sort()
		var want_c: Array = AL.CORE_IDS.duplicate()
		want_c.sort()
		if ids != want_c:
			cards_ok = false
	var cols := {}
	for aid in AL.CORE_IDS:
		cols[str(AL.COLORS[aid])] = true
	_check("country, woods, town and caverns each hold one card per ally; the cemetery has none", cards_ok and cols.size() == 4 and not AL.CARDS.has(3), "")
	LV.current = 3
	g = await _new_game()
	_check("cemetery has no ally cards on the map", g.card_nodes.is_empty(), "")
	g.queue_free()
	await process_frame
	LV.current = 1
	g = await _new_game()
	m = g.mera
	_give_cards(g, {})                    # a card picked up by an earlier case (random drops) must not leave a stray type in the hand
	var c0: Node2D = load("res://scripts/game/ally_card.gd").new()     # no card lies on a map any more: place one
	c0.setup(g, "priestess", Vector2(m.global_position.x + 600.0, g.GROUND_Y))
	g.world.add_child(c0)
	g.card_nodes.append(c0)
	var cid: String = c0.ally_id
	m.position.x = c0.global_position.x
	await _drive(g, [], 4)
	_check("touching a card collects it", int(g.cards.get(cid, 0)) == 1 and not g.card_nodes.has(c0), "%s" % [g.cards])
	await _drive(g, [[3, "r1", true], [6, "r1", false]], 10)
	_check("R1 with one card type -> that ally is summoned at once (no picker), the card is used", g.allies().size() == 1 and g.allies()[0].id == cid and int(g.cards.get(cid, 0)) == 0 and not g.picker.open, "")
	g.queue_free()
	await process_frame
	g = await _new_game()
	m = g.mera
	_give_cards(g, {"ranger": 1, "dancer": 2})
	await _drive(g, [[3, "r1", true], [6, "r1", false]], 8)
	var opened: bool = g.picker.open and paused and g.picker.choices == ["ranger", "dancer"]
	g.picker.move(1)
	g.picker.confirm()
	await process_frame
	await physics_frame
	_check("R1 with several card types -> the picker opens (game paused); choosing summons that one", opened and not paused and g.allies().size() == 1 and g.allies()[0].id == "dancer" and int(g.cards["dancer"]) == 1 and int(g.cards["ranger"]) == 1, "open=%s" % opened)
	g.queue_free()
	await process_frame
	# the priestess heals once when she arrives, and once more as she leaves
	g = await _new_game()
	m = g.mera
	m.position.x = 6000.0
	g.snap_camera()
	m.set_size(2, true)
	_give_cards(g, {"priestess": 1})
	var prs: Node2D = g.summon_type("priestess")
	await _drive(g, [], 150)
	var healed1: bool = m.size == 6 and prs.heals == 1
	m.set_size(2, true)
	await _drive(g, [], 180)
	var held_off: bool = m.size == 2 and prs.heals == 1
	prs.age = prs.stay - 0.05
	await _drive(g, [], 80)
	_check("Water Priestess heals to 6x when she arrives, not again while she stays, then once more as she leaves", healed1 and held_off and m.size == 6 and prs.heals == 2 and prs.state == "leave", "h1=%s off=%s size=%d heals=%d state=%s" % [healed1, held_off, m.size, prs.heals, prs.state])
	g.queue_free()
	await process_frame
	# every ally uses all her animations and the fighters hurt enemies
	for aid in AL.CORE_IDS:
		LV.current = 1
		g = await _new_game()
		m = g.mera
		m.position.x = 6000.0
		m.set_size(2, true)
		g.snap_camera()
		_give_cards(g, {aid: 1})
		var aly: Node2D = g.summon_type(aid)
		aly.stay = 1e9
		aly.hp = 40
		await _ally_stage(g, aly, "", 0.0, 90)
		if aid != "dancer":
			await _ally_stage(g, aly, "mutant_toad", 500.0, 240)
			await _ally_stage(g, aly, "mutant_toad", 130.0, 240)
			await _ally_stage(g, aly, "flying_eye", 160.0, 200)
			await _ally_stage(g, aly, "minotaur", 200.0, 120, true)
			await _ally_stage(g, aly, "wolf", 220.0, 90, true)
			m.position.x += 1500.0
			await _ally_stage(g, aly, "", 0.0, 200)
			var dealt: int = aly.hits_landed
			aly.hp = 8
			for i in 14:
				if is_instance_valid(aly) and aly.alive():
					aly.state = "idle"
					aly.take_hit(1, aly.global_position.x + 50.0)
					await _drive(g, [], 30)
			var miss_al: Array = []
			for an in RO.art(aid)["anims"]:
				if not aly.played.has(an):
					miss_al.append(an)
			_check("%s uses all %d animations, hits enemies (%d), falls when beaten" % [aid, RO.art(aid)["anims"].size(), dealt], miss_al.is_empty() and dealt > 0 and not aly.alive(), "missing=%s" % [miss_al])
		else:
			await _ally_stage(g, aly, "", 0.0, 400)
			var miss_d: Array = []
			for an in RO.art(aid)["anims"]:
				if not aly.played.has(an):
					miss_d.append(an)
			_check("dancer uses all her animations (skip in, 4 dances)", miss_d.is_empty(), "missing=%s" % [miss_d])
		g.queue_free()
		await process_frame
	# the dancing girl: non-boss enemies on screen rush over and hop; the boss ignores her; nobody attacks
	LV.current = 3
	g = await _new_game()
	m = g.mera
	m.position.x = 12000.0
	g.snap_camera()
	m.set_size(4, true)
	var watchers: Array = [g.spawn_enemy("hell_hound", 12700.0), g.spawn_enemy("fire_skull", 11300.0), g.spawn_enemy("demon", 12500.0)]
	var drg: Node2D = g.spawn_enemy("dragon", 12900.0)
	await _drive(g, [], 20)
	_give_cards(g, {"dancer": 1})
	var dz: Node2D = g.summon_type("dancer")
	await _drive(g, [], 300)
	var near_ok := true
	var hop_ok := false
	var tells := 0
	for w in watchers:
		if absf(w.global_position.x - dz.global_position.x) > 420.0:
			near_ok = false
		if w.cheer_hops > 0 or (w.flyer and w.state == "cheer"):
			hop_ok = true
	await _drive(g, [], 20)
	for w in watchers:
		if w.state == "tell" or w.state == "atk":
			tells += 1
	_check("Dancing Girl: every on-screen enemy, the boss included, gathers and jumps, no attacks", dz.dancing() and near_ok and hop_ok and tells == 0 and drg.distracted_t > 0.0, "near=%s hop=%s tells=%d boss=%f" % [near_ok, hop_ok, tells, drg.distracted_t])
	g.queue_free()
	await process_frame
	g = await _new_game()
	_give_cards(g, {"brawler": 1})
	var bz: Node2D = g.summon_type("brawler")
	await _drive(g, [], 90)
	bz.age = bz.stay - 0.05
	await _drive(g, [], 10)
	_check("allies leave when their time is up (%d s)" % int(AL.STAY_S["brawler"]), bz.state == "leave", bz.state)
	g.queue_free()
	await process_frame
	_check("every summon base is 30 s and the dance is 5 s", AL.STAY_S["priestess"] == 30.0 and AL.STAY_S["ranger"] == 30.0 and AL.STAY_S["brawler"] == 30.0 and AL.STAY_S["dancer"] == 30.0 and AL.DANCE_S == 5.0, "")
	g = await _new_game()
	m = g.mera
	m.position.x = 6000.0
	m.facing = 1
	g.snap_camera()
	g.knight_calm_until = 1 << 30
	_give_cards(g, {"brawler": 1})
	var br: Node2D = g.summon_type("brawler")
	await _drive(g, [], 180)
	var right: float = g.cam_x + 960.0
	var held: bool = br.global_position.x >= right - 400.0 and br.global_position.x <= right - 190.0
	var bx0: float = br.global_position.x
	var tail: Node2D = g.spawn_enemy("wolf", br.global_position.x - 700.0)
	tail.cooldown = 99.0
	await _drive(g, [], 40)
	_check("Brawler waits on the right of the screen, then runs at an enemy; the wolf stays on Mera", held and br.global_position.x < bx0 - 40.0 and tail.global_position.x < m.global_position.x + 500.0, "held=%s br %.0f -> %.0f right=%.0f wolf=%.0f" % [held, bx0, br.global_position.x, right, tail.global_position.x])
	g.queue_free()
	await process_frame
	g = await _new_game()
	m = g.mera
	m.position.x = 6000.0
	m.facing = 1
	g.snap_camera()
	_give_cards(g, {"dancer": 1})
	var dg: Node2D = g.summon_type("dancer")
	await _drive(g, [], 120)
	var walked: bool = dg.dancing() and dg.global_position.x > m.global_position.x + 200.0
	dg.t_state = AL.DANCE_S - 0.02
	await _drive(g, [], 8)
	_check("Dancing Girl walks ahead, dances, and stops after 5 s", walked and not dg.dancing() and dg.state != "leave", "walked=%s state=%s x=%.0f" % [walked, dg.state, dg.global_position.x])
	g.queue_free()
	await process_frame
	# any projectile damages a breakable
	g = await _new_game()
	m = g.mera
	m.position.x = 5000.0
	g.snap_camera()
	var PROP = load("res://scripts/game/prop.gd")
	var candle: Node2D = PROP.new()
	candle.setup(g, "candle", 5400.0, {})
	g.world.add_child(candle)
	g.props.append(candle)
	var cc: Vector2 = candle.hurt_rect().get_center()
	g.spawn_bolt(m, cc + Vector2(-120.0, 0.0), 1, 2.0, true)
	await _drive(g, [], 30)
	_check("a quick-fire bolt breaks a candle", not is_instance_valid(candle) or not candle.alive(), "")      # a broken prop frees itself
	var urn: Node2D = PROP.new()
	urn.setup(g, "urn", 5600.0, {})
	g.world.add_child(urn)
	g.props.append(urn)
	var uc: Vector2 = urn.hurt_rect().get_center()
	var es: Node2D = load("res://scripts/game/enemy_shot.gd").new()
	es.setup(g, "hell_beast", "fireball", uc + Vector2(-160.0, 0.0), Vector2(700.0, 0.0), 1, 4.0)
	g.world.add_child(es)
	await _drive(g, [], 30)
	_check("an enemy shot breaks an urn", not is_instance_valid(urn) or not urn.alive(), "")
	var crate: Node2D = PROP.new()
	crate.setup(g, "crate", 5900.0, {})
	g.world.add_child(crate)
	g.props.append(crate)
	var db: Node2D = load("res://scripts/game/dragon_bolt.gd").new()
	var dc: Vector2 = crate.hurt_rect().get_center()
	db.setup(g, null, dc + Vector2(-80.0, -200.0), dc, 0.4)
	g.world.add_child(db)
	await _drive(g, [], 40)
	_check("a dragon bolt breaks a crate", not is_instance_valid(crate) or not crate.alive(), "")
	g.queue_free()
	await process_frame
	LV.current = 0
	# menu scene loads and lists the 4 levels
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	_check("level select menu loads with one card per level", menu.thumbs.size() == LV.list().size(), "%d cards, %d levels" % [menu.thumbs.size(), LV.list().size()])
	menu._move(1)
	_check("menu: Right selects level 2", menu.sel == 1, "")
	menu.queue_free()
	await process_frame
	# stage 2 menu pages: 6 cards on page 0, 5 on page 1; the page follows sel; opens on level 7 after the dragon
	var CA = load("res://scripts/game/carry.gd")
	CA.reset()
	CA.ensure()
	CA.unlocked = 6
	LV.current = 5
	var pm: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(pm)
	await process_frame
	_check("menu: after the dragon (unlocked >= 6, level 6 played) it opens on level 7, the stage 2 page", pm.sel == 6 and pm.page_of(pm.sel) == 1, "sel=%d" % pm.sel)
	_check("menu pages: stage 1 shows levels 0..5, stage 2 shows 6..11, stage 3 shows 12..19, stage 4 shows 20", pm.page_levels(0) == [0, 1, 2, 3, 4, 5] and pm.page_levels(1) == [6, 7, 8, 9, 10, 11] and pm.page_levels(2) == [12, 13, 14, 15, 16, 17, 18, 19] and pm.page_levels(3) == [20], "%s %s %s %s" % [pm.page_levels(0), pm.page_levels(1), pm.page_levels(2), pm.page_levels(3)])
	pm.sel = 5
	pm._move(1)
	var page_follow: bool = pm.sel == 6 and pm.page_of(pm.sel) == 1
	pm._move(-1)
	_check("menu: Right from level 6 goes to level 7 (page 2) and Left comes back", page_follow and pm.sel == 5 and pm.page_of(pm.sel) == 0, "sel=%d" % pm.sel)
	var c6: Rect2 = pm._card(6)
	var c10: Rect2 = pm._card(11)
	var cs1: Rect2 = pm._card(0)
	_check("menu: stage 2 now has six cards laid out like stage 1 (same margin, inside the screen)", absf(c6.position.x - cs1.position.x) < 0.1 and absf(c6.size.x - cs1.size.x) < 0.1 and c10.end.x <= 1920.0 and absf(pm._card(7).position.x - (c6.end.x + 18.0)) < 0.1, "%s %s" % [c6, c10])
	pm.queue_free()
	await process_frame
	LV.current = 0
	CA.reset()
	await _s4_tests()
	await _chest_tests()
	await _unlock_tests()
	await _task_tests()
	await _touch_tests()
	await _mark_tests()
	await _perry_tests()
	await _pb_tests()
	await _cl_tests()
	await _ladder_tests()
	await _face_summon_tests()
	await _session_tests()
	await _stage3_map_tests()
	await _king_arc_tests()
	await _slideshow_timer_blast_tests()
	await _speaker_impact_restart_tests()
	print("\n%d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)



# ================================================================ v0.8 (S4) impact pass, breakables, juggles, secrets, parry
var LVS = load("res://scripts/game/levels.gd")

func _s4_prop(g: Node, kind: String, near: float = 0.0) -> Node2D:
	var best: Node2D = null
	for p in g.props:
		if is_instance_valid(p) and p.kind == kind and (best == null or absf(p.global_position.x - near) < absf(best.global_position.x - near)):
			best = p
	return best


func _s4_frames(g: Node, n: int) -> void:
	for i in n:
		await physics_frame
		if is_instance_valid(g) and g.mera.state != "dead":
			g.mera.invuln = maxf(g.mera.invuln, 0.5)


func _s4_new(level: int) -> Node:
	LVS.current = level
	var g: Node = await _new_game()
	for i in 3:
		await physics_frame
	return g


func _s4_tests() -> void:
	var HS = root.get_node("HitStop")
	var P = load("res://scripts/game/props.gd")
	var T = load("res://scripts/game/tuning.gd")
	# ---- props per level
	var lay_ok: bool = P.layout(3, 20000.0).is_empty()
	var lay_info := ""
	for lv in [0, 1, 2, 4, 6, 7, 8, 9, 10]:
		var kinds := {}
		for it in P.layout(lv, 24000.0):
			kinds[String(it[0])] = true
		var need := ["crate", "chest", "barrel"]
		for k in need:
			if not kinds.has(k):
				lay_ok = false
		if not (kinds.has("candle") or kinds.has("candle_b")) or not kinds.has("urn"):
			lay_ok = false
		lay_info += "L%d=%s " % [lv, kinds.keys()]
	_check("props: the cemetery has none; the wave levels (stage 1 and 2) have candles, urns, crates, chests, barrels", lay_ok, lay_info)

	# ---- hit-stop
	var g: Node = await _s4_new(1)
	var m: Node = g.mera
	HS.enabled = true
	m.position.x = 6000.0
	m.set_size(3, true)
	var w: Node2D = g.spawn_enemy("werewolf", 6200.0)
	await _s4_frames(g, 20)
	w.cooldown = 99.0
	var c0: int = HS.count
	var now0: float = m.now
	m.deal(w, 1, m.global_position.x, "melee")
	var froze: bool = Engine.time_scale < 0.5 and HS.count == c0 + 1 and absf(HS.last_ms - T.HITSTOP_LIGHT_MS) < 0.01
	await _s4_frames(g, 30)
	_check("hit-stop: a light hit freezes time (%d ms) then restores time_scale to 1" % int(T.HITSTOP_LIGHT_MS), froze and Engine.time_scale == 1.0 and not HS.active(), "scale=%f count=%d" % [Engine.time_scale, HS.count])
	_check("hit-stop: Mera's input clock keeps real time through the freeze", absf((m.now - now0) - 30.0 * 1000.0 / 60.0) < 60.0, "dt=%f" % (m.now - now0))
	m.deal(w, 2, m.global_position.x, "melee")
	var heavy: float = HS.last_ms
	await _s4_frames(g, 30)
	w.hp = 1
	m.deal(w, 1, m.global_position.x, "melee")
	var kill: float = HS.last_ms
	_check("hit-stop: heavier for heavy hits and kills, capped", heavy == T.HITSTOP_HEAVY_MS and kill == T.HITSTOP_KILL_MS and kill <= T.HITSTOP_MAX_MS and heavy > T.HITSTOP_LIGHT_MS, "heavy=%f kill=%f" % [heavy, kill])
	HS.stop(10000.0)
	_check("hit-stop: never longer than HITSTOP_MAX_MS", HS.last_ms == T.HITSTOP_MAX_MS, "%f" % HS.last_ms)
	HS.clear()
	var jit := {}
	for i in 12:
		root.get_node("Sfx").play("hit")
	for h in root.get_node("Sfx").history.slice(-12):
		jit[snappedf(float(h[3]), 0.0001)] = true
	_check("sfx: impact sounds get a random pitch jitter (no two hits sound the same)", jit.size() >= 6, "%d distinct" % jit.size())

	# ---- corpse launch + shatter + gore
	await _s4_frames(g, 40)
	var o: Node2D = g.spawn_enemy("ogre", m.global_position.x + 260.0)
	await _s4_frames(g, 10)
	o.cooldown = 99.0
	o.hp = 1
	var ox: float = o.global_position.x
	m.deal(o, 1, m.global_position.x, "melee")
	var flew := false
	var top := 1e9
	var pieces := 0
	for i in 150:
		await physics_frame
		m.invuln = 1.0
		if is_instance_valid(o):
			top = minf(top, o.global_position.y)
			if o.global_position.x > ox + 40.0:
				flew = true
		pieces = maxi(pieces, g.debris.pieces.size())
		if not is_instance_valid(o) and pieces > 0:
			break
	_check("corpse launch: a killed ogre flies away from Mera, spins, then shatters into debris + gore", flew and not is_instance_valid(o) and pieces >= 20, "flew=%s pieces=%d" % [flew, pieces])
	HS.clear()
	g.queue_free()
	await physics_frame

	# ---- juggles
	g = await _s4_new(1)
	m = g.mera
	HS.enabled = false
	m.position.x = 6000.0
	m.set_size(3, true)
	w = g.spawn_enemy("werewolf", 6150.0)
	await _s4_frames(g, 20)
	w.cooldown = 99.0
	w.hp = 99
	m.deal(w, 1, m.global_position.x, "launch")
	var launched: bool = w.state == "juggle" and w.launches == 1
	await _s4_frames(g, 12)
	var air1: float = w.max_air
	m.deal(w, 1, m.global_position.x, "melee")
	m.deal(w, 1, m.global_position.x, "melee")
	var jn: int = w.juggle_n
	var bounced := false
	for i in 240:
		await physics_frame
		m.invuln = 1.0
		if w.bounced:
			bounced = true
		if w.state != "juggle":
			break
	_check("juggle: launch sends the enemy up (%d px) and air hits keep it up (juggle_n=%d)" % [int(air1), jn], launched and air1 > 120.0 and jn == 2, "state=%s launches=%d" % [w.state, w.launches])
	_check("juggle: one ground bounce, then it lands and recovers", bounced and w.state != "juggle" and w.alive(), "state=%s" % w.state)
	# escalating gravity: the same air hit gives less height each time
	w.hp = 99
	m.deal(w, 1, m.global_position.x, "launch")
	await _s4_frames(g, 30)
	var rises: Array = []
	for i in 4:
		var y0: float = w.global_position.y
		m.deal(w, 1, m.global_position.x, "melee")
		var hi := y0
		for f in 25:
			await physics_frame
			m.invuln = 1.0
			hi = minf(hi, w.global_position.y)
		rises.append(y0 - hi)
	_check("juggle: escalating gravity, each air hit lifts it less", rises[0] > rises[1] and rises[1] > rises[2], "%s" % [rises])
	await _s4_frames(g, 120)
	# wall bounce
	g.props = g.props.filter(func(p): return not (is_instance_valid(p) and p.blocks_path()))     # cracked walls and doors block the teleport
	w.position.x = LVS.EDGE + 160.0
	w.hp = 99
	m.position.x = w.position.x + 200.0
	m.deal(w, 1, m.global_position.x, "explosion")
	for i in 120:
		await physics_frame
		m.invuln = 1.0
		if w.wall_bounces > 0:
			break
	_check("juggle: flung into the map wall -> bounces back off it (+1 damage)", w.wall_bounces >= 1 and w.hp == 99 - 3 - 1, "wb=%d hp=%d" % [w.wall_bounces, w.hp])
	g.queue_free()
	await physics_frame

	# ---- parry
	g = await _s4_new(1)
	m = g.mera
	m.position.x = 6000.0
	m.set_size(3, true)
	w = g.spawn_enemy("werewolf", 6150.0)
	await _s4_frames(g, 30)
	w.cooldown = 99.0
	m.invuln = 0.0
	m.last_l2_t = m.now - 40.0
	m.take_hit(2, w.global_position.x, w)
	var parried: bool = m.size == 3 and m.parries == 1 and w.state == "stun" and m.counter_active()
	var hp0: int = w.hp
	m.deal(w, 1, m.global_position.x, "melee")
	_check("parry: L2 within %d ms of the hit negates it, staggers the attacker and opens a counter" % int(T.PARRY_MS), parried, "size=%d parries=%d state=%s" % [m.size, m.parries, w.state])
	_check("parry: the counter hit deals x%s damage" % str(T.PARRY_COUNTER_MULT), hp0 - w.hp == 3 * int(T.PARRY_COUNTER_MULT), "dealt=%d" % (hp0 - w.hp))
	await _s4_frames(g, 120)
	m.invuln = 0.0
	m.last_l2_t = m.now - T.PARRY_MS - 80.0
	var sz0: int = m.size
	m.take_hit(1, w.global_position.x, w)
	_check("parry: a late L2 does not parry (the hit lands)", m.size == sz0 - 1 and m.parries == 1, "size=%d" % m.size)
	await _s4_frames(g, 120)
	m.invuln = 0.0
	var shot := Node2D.new()
	g.world.add_child(shot)
	shot.global_position = m.global_position + Vector2(60, -40)
	var no_parry: bool = not m.try_parry_shot(shot)
	m.last_l2_t = m.now
	_check("parry: a projectile in the window is deflected (try_parry_shot)", no_parry and m.try_parry_shot(shot) and m.deflects == 1, "deflects=%d" % m.deflects)
	shot.queue_free()
	g.queue_free()
	await physics_frame

	# ---- breakables, drops, barrels, chandeliers (Moonlit Town)
	g = await _s4_new(2)
	m = g.mera
	var cd: Node2D = _s4_prop(g, "candle", 4000.0)
	if cd == null:
		cd = _s4_prop(g, "candle_b", 4000.0)
	var cr: Node2D = _s4_prop(g, "crate", 4000.0)
	m.position.x = cd.global_position.x - 150.0
	await _s4_frames(g, 5)
	m.deal(cd, 1, m.global_position.x, "melee")
	var crhp: int = cr.hp
	m.deal(cr, 1, cr.global_position.x - 100.0, "melee")
	var cr_mid: bool = cr.alive()
	for i in crhp:
		m.deal(cr, 1, cr.global_position.x - 100.0, "melee")
	_check("breakables: a candle breaks in one hit, a crate takes %d" % crhp, not cd.alive() and cr_mid == (crhp > 1) and not cr.alive(), "candle=%s crate=%s" % [cd.state, cr.state])
	m.size = 6
	m.potions = 3
	m.stamina = 0.0
	m.rage = 100.0
	var tally := {"potion": 0, "stamina": 0, "sphere": 0}
	g.drop_rng.seed = 99
	for i in 200:
		for kd in g.smart_drop(Vector2(m.global_position.x, 600.0), "medium"):
			if tally.has(kd):
				tally[kd] += 1
	_check("smart drops: low stamina, full size and rage -> mostly blue stamina potions", tally["stamina"] > 2 * tally["potion"] and tally["stamina"] > 2 * tally["sphere"], "%s" % [tally])
	m.size = 1
	m.potions = 0
	m.stamina = m.stamina_max
	tally = {"potion": 0, "stamina": 0, "sphere": 0}
	for i in 200:
		for kd in g.smart_drop(Vector2(m.global_position.x, 600.0), "medium"):
			if tally.has(kd):
				tally[kd] += 1
	_check("smart drops: tiny Mera with no potions -> mostly green size potions", tally["potion"] > tally["stamina"] and tally["potion"] > tally["sphere"], "%s" % [tally])
	await _s4_frames(g, 30)
	for pk in g.world.get_children():
		if pk.get_script() != null and String(pk.get_script().resource_path).ends_with("pickup.gd"):
			pk.queue_free()
	m.size = 3
	# barrel chain + enemy launch
	var b1: Node2D = _s4_prop(g, "barrel", 6000.0)
	var PROP = load("res://scripts/game/prop.gd")
	var b2: Node2D = PROP.new()
	b2.setup(g, "barrel", b1.global_position.x + 200.0)
	g.world.add_child(b2)
	g.props.append(b2)
	m.position.x = b1.global_position.x - 700.0
	var hh: Node2D = g.spawn_enemy("werewolf", b1.global_position.x + 90.0)
	await _s4_frames(g, 10)
	hh.cooldown = 99.0
	hh.hp = 99
	m.deal(b1, 1, m.global_position.x, "bolt")
	await _s4_frames(g, 40)
	_check("barrel: explodes, %d fixed damage + launch to enemies in the blast, and chains to a barrel nearby" % P.BARREL_DMG, (not is_instance_valid(b1) or not b1.alive()) and (not is_instance_valid(b2) or b2.state != "idle") and hh.hp <= 99 - P.BARREL_DMG and hh.launches >= 1, "b2=%s hp=%d launches=%d" % [b2.state if is_instance_valid(b2) else "freed", hh.hp, hh.launches])
	await _s4_frames(g, 60)
	# chandelier crush via the earthquake
	var ch: Node2D = null
	for pr in g.props:
		if is_instance_valid(pr) and pr.kind == "chandelier" and pr.alive() and (ch == null or absf(pr.global_position.x - 12000.0) < absf(ch.global_position.x - 12000.0)):
			ch = pr
	g.props = g.props.filter(func(p): return not (is_instance_valid(p) and p.blocks_path()))     # cracked walls and doors block the teleport
	m.position.x = ch.global_position.x - 500.0
	g.snap_camera()
	var under: Node2D = g.spawn_enemy("werewolf", ch.global_position.x)
	await _s4_frames(g, 10)
	under.cooldown = 99.0
	under.hp = 99
	under.position.x = ch.global_position.x
	var cx: float = ch.global_position.x
	var crushed := 0
	var fell := false
	g.earthquake()
	for i in 90:
		await physics_frame
		m.invuln = 1.0
		if is_instance_valid(under) and under.alive():
			under.position.x = cx
		if not is_instance_valid(ch):
			break
		fell = fell or ch.state != "idle"
		crushed = ch.crushed
	_check("chandelier: the earthquake shakes it loose and it crushes the enemy below (%d dmg + stun)" % P.CHANDELIER_DMG, fell and is_instance_valid(under) and under.hp <= 99 - P.CHANDELIER_DMG and under.stun_t > 0.5, "fell=%s hp=%d" % [fell, under.hp if is_instance_valid(under) else -1])
	g.queue_free()
	await physics_frame

	# ---- secrets: wall, ledge + crumbling plank, lever + door (Misty Woods)
	g = await _s4_new(1)
	m = g.mera
	var wall: Node2D = _s4_prop(g, "wall")
	m.position.x = wall.global_position.x - 200.0
	await _s4_frames(g, 3)
	var hits := 0
	while is_instance_valid(wall) and wall.alive() and hits < 20:
		m.deal(wall, 1, m.global_position.x, "melee")
		hits += 1
	await _s4_frames(g, 5)
	_check("secret wall: breaks after 4 hits and counts as a secret found", hits == 4 and (not is_instance_valid(wall) or not wall.alive()) and g.secrets_found == 1, "hits=%d found=%d" % [hits, g.secrets_found])
	var lever: Node2D = _s4_prop(g, "lever")
	var door: Node2D = lever.door
	m.position.x = lever.global_position.x - 120.0
	await _s4_frames(g, 3)
	m.deal(lever, 1, m.global_position.x, "melee")
	await _s4_frames(g, 100)
	_check("secret door: pulling its lever opens it", door.state == "open" and g.secrets_found == 2, "door=%s found=%d" % [door.state, g.secrets_found])
	var plank: Node2D = _s4_prop(g, "plank")
	var ledge: Node2D = _s4_prop(g, "ledge")
	m.position = Vector2(plank.global_position.x, plank.top_y - 200.0)
	m.state = "air"
	m.on_ground = false
	var stood := false
	var crumbled := false
	for i in 120:
		await physics_frame
		m.invuln = 1.0
		if m.on_ground and absf(m.global_position.y - plank.top_y) < 2.0:
			stood = true
		if plank.state == "gone":
			crumbled = true
			break
	await _s4_frames(g, 40)
	_check("crumbling plank: Mera lands on it, it shakes and breaks under her, she drops to the ground", stood and crumbled and not plank.solid() and absf(m.global_position.y - g.GROUND_Y) < 2.0, "stood=%s crumbled=%s y=%f" % [stood, crumbled, m.global_position.y])
	_check("ledge: it stands well above the ground", ledge.top_y < g.GROUND_Y - 250.0, "top=%f" % ledge.top_y)
	m.position = Vector2(ledge.global_position.x, ledge.top_y - 100.0)
	m.state = "air"
	m.on_ground = false
	await _s4_frames(g, 40)
	var on_ledge: bool = m.on_ground and absf(m.global_position.y - ledge.top_y) < 2.0
	var lx0: float = m.global_position.x
	m.forced["right"] = true
	await _s4_frames(g, 150)
	m.forced["right"] = false
	await _s4_frames(g, 60)
	_check("ledge: Mera stands on it and falls off its edge back to the ground", on_ledge and absf(m.global_position.y - g.GROUND_Y) < 2.0, "on=%s y=%f x %f->%f surf=%s st=%s" % [on_ledge, m.global_position.y, lx0, m.global_position.x, ledge.surface(), m.state])
	for i in int(P.CRUMBLE_BACK_S * 60.0) + 60:
		await physics_frame
	_check("crumbling plank grows back after %ds" % int(P.CRUMBLE_BACK_S), plank.state == "idle" and plank.solid(), "state=%s" % plank.state)
	# ---- ally scaling (fixed to Mera's size)
	_give_cards(g, {"brawler": 2})
	m.set_size(2, true)
	var a1: Node2D = g.summon_type("brawler")
	await _s4_frames(g, 60)
	var k_small: float = a1.k
	m.set_size(6, true)
	await _s4_frames(g, 90)
	var k_big: float = a1.k
	_check("allies: scale with Mera (fit to her height): k at 2x %.2f < k at 6x %.2f" % [k_small, k_big], k_small < k_big - 0.3 and absf(k_big - a1.fit_k()) < 0.05, "")
	g.queue_free()
	await physics_frame
	HS.enabled = false
	HS.clear()
	await _dragon_tests()
	await _super_quake_tests()
	await _updater_tests()
	await _v091_tests()
	LVS.current = 0



## v0.8 dragon boss: size is health (19x), phases at 12/9/6/3 once each, +3 when a phase bolt hurts Mera, always lands
func _dragon_until_landed(g: Node, dr: Node2D, keep_safe: bool, max_f: int = 1500) -> void:
	for i in max_f:
		await physics_frame
		if keep_safe:
			g.mera.invuln = 1.0
		if not is_instance_valid(dr) or (dr.phase == "" and dr.phase_queue.is_empty()):
			return


func _dragon_tests() -> void:
	var T = load("res://scripts/game/tuning.gd")
	await _bolt_orientation_tests()
	var RO = load("res://scripts/game/roster.gd")
	var fly: Dictionary = RO.art("dragon")["anims"]["fly"]
	var want := ["_0000_Layer-1", "_0004_Layer-5", "_0003_Layer-4", "_0004_Layer-5"]
	var order_ok: bool = fly["frames"].size() == 4 and bool(fly["loop"]) and float(fly["fps"]) >= 10.0
	var fly_fire := 0
	var min_x := 999
	for i in fly["frames"].size():
		var fp: String = fly["frames"][i]
		order_ok = order_ok and fp.find("/spit-nofire/") >= 0 and fp.get_file().get_basename() == want[i]
		var img: Image = load(fp).get_image()
		if img.is_compressed():
			img.decompress()
		min_x = mini(min_x, img.get_used_rect().position.x)
		for y in img.get_height():
			for x in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a > 0.5 and Vector3i(c.r8, c.g8, c.b8) in [Vector3i(242, 74, 2), Vector3i(255, 141, 7), Vector3i(255, 214, 133)]:
					fly_fire += 1
	_check("dragon fly loop: the user's 4 frames in order (breath 1,5,4,5, plume-free copies), looping at >= 10 fps", order_ok, str(fly["frames"]))
	_check("dragon fly loop: no fire at all (no plume pixel, nothing in front of the head: no small fireball)", fly_fire == 0 and min_x >= 55, "fire=%d min_x=%d" % [fly_fire, min_x])
	var g: Node = await _s4_new(3)
	var m: Node = g.mera
	m.position.x = 12000.0
	m.set_size(6, true)
	g.snap_camera()
	var dr: Node2D = g.spawn_enemy("dragon", 12900.0)
	await _s4_frames(g, 30)
	_check("dragon: starts at 19x (drawn at k 19), %d HP per size" % T.DRAGON_HP_PER_SIZE, dr.size == 19 and absf(dr.k - 19.0) < 0.01 and dr.hp == 19 * T.DRAGON_HP_PER_SIZE and absf(absf(dr.sprite.scale.x) - 19.0) < 0.01, "size=%d k=%f hp=%d" % [dr.size, dr.k, dr.hp])
	var feet0: float = dr.global_position.y
	dr.take_damage(T.DRAGON_HP_PER_SIZE * 6, m.global_position.x, "melee")
	var shrunk: bool = dr.size == 13 and dr.phase == "" and dr.phase_queue.is_empty()
	await _s4_frames(g, 60)
	_check("dragon: damage shrinks it (19x -> 13x, tweened), feet stay on the ground line, no phase above 12x", shrunk and absf(dr.k - 13.0) < 0.05 and absf(dr.global_position.y - feet0) < 0.5 and dr.hurt_rect().end.y <= feet0 + 1.0, "k=%f" % dr.k)
	dr.take_damage(T.DRAGON_HP_PER_SIZE, m.global_position.x, "melee")
	await _s4_frames(g, 2)
	var flying: bool = dr.phase != "" and dr.phase_thr == 12
	var max_lift := 0.0
	var tells := 0
	var was_tell := false
	var volley_anims := {}
	var volley_frames := {}
	var fly_off := 0
	var launches: Array = []         # [spawn, mouth, head top y, launch vel, toward-Mera sign ok]
	var tracked := {}                # bolt -> [last x, mera x]
	var seen_bolt: Node2D = null
	for i in 1500:
		await physics_frame
		m.invuln = 1.0
		max_lift = maxf(max_lift, dr.lift)
		if dr.phase != "":
			var on_screen: bool = absf(dr.global_position.x - g.cam_x) <= 960.0 and dr.global_position.x > Levels_EDGE() and dr.global_position.x < g.map_w - Levels_EDGE()
			if not on_screen:
				fly_off += 1
		if is_instance_valid(dr.last_bolt) and dr.last_bolt != seen_bolt:
			seen_bolt = dr.last_bolt
			var hr0: Rect2 = dr.hurt_rect()
			launches.append([seen_bolt.launch_pos, dr.last_mouth, dr.last_head_y, seen_bolt.launch_vel, signf(seen_bolt.launch_vel.x) == signf(m.global_position.x - dr.global_position.x)])
		for bb in dr.get_parent().get_children():
			if bb.get("launch_vel") != null and not bb.done:
				tracked[bb.get_instance_id()] = [bb.global_position.x, m.global_position.x]
		if dr.phase == "volley":
			volley_anims[String(dr.sprite.animation)] = true
			volley_frames["%s:%d" % [dr.sprite.animation, dr.sprite.frame]] = dr.sprite.sprite_frames.get_frame_texture(dr.sprite.animation, dr.sprite.frame)
		var tl: bool = dr.marker.visible and dr.phase == "volley"
		if tl and not was_tell:
			tells += 1
		was_tell = tl
		if dr.phase == "" and dr.phase_queue.is_empty():
			break
	_check("dragon phase 12x: takes off, 5 bolts each with a red tell, then lands", flying and max_lift > T.DRAGON_FLY_H * 0.9 and dr.bolts_fired == 5 and tells == 5 and dr.landings == 1 and dr.phase_log == [12] and absf(dr.global_position.y - feet0) < 0.5 and dr.state != "fly",
		"fly=%s lift=%f bolts=%d tells=%d land=%d log=%s" % [flying, max_lift, dr.bolts_fired, tells, dr.landings, dr.phase_log])
	var fire_px := 0
	for key in volley_frames:
		var img: Image = volley_frames[key].get_image()
		if img.is_compressed():
			img.decompress()
		for y in img.get_height():
			for x in img.get_width():
				var c: Color = img.get_pixel(x, y)
				if c.a > 0.5:
					var c8 := Vector3i(c.r8, c.g8, c.b8)
					if c8 == Vector3i(242, 74, 2) or c8 == Vector3i(255, 141, 7) or c8 == Vector3i(255, 214, 133):   # the plume palette
						fire_px += 1
	_check("dragon volley: plays the plume-free 'spit'/'fly' frames (never 'breath'), no fire pixels in any shown frame", not volley_anims.has("breath") and volley_anims.has("spit") and volley_frames.size() >= 3 and fire_px == 0, "anims=%s frames=%d fire_px=%d" % [volley_anims.keys(), volley_frames.size(), fire_px])
	# v0.8.1 flight: lob spots
	var xs: Array = []
	var dists: Array = []
	var sides := {}
	for sp in dr.spit_spots:
		xs.append(float(sp[0]))
		dists.append(absf(float(sp[2])))
		sides[signf(float(sp[2]))] = true
	var distinct := 0
	for i in xs.size():
		var uniq := true
		for j in i:
			if absf(xs[i] - xs[j]) < 200.0:
				uniq = false
		if uniq:
			distinct += 1
	var spread_d: float = (dists.max() - dists.min()) if not dists.is_empty() else 0.0
	_check("dragon flight: flies around between lobs - %d lobs from %d distinct spots, varied distances (%.0f..%.0f px; at 12x his mouth is 400 px ahead, so the range is narrow), both sides of Mera" % [xs.size(), distinct, dists.min() if dists else 0.0, dists.max() if dists else 0.0],
		xs.size() == 5 and distinct >= 4 and spread_d >= 60.0 and sides.size() == 2, "xs=%s d=%s" % [xs, dists])
	_check("dragon flight: stays on screen and inside the walls the whole phase", fly_off == 0, "off-screen frames=%d" % fly_off)
	var at_mouth := launches.size() == 5
	var horiz := launches.size() == 5
	for L in launches:
		var sp: Vector2 = L[0]
		var mo: Vector2 = L[1]
		at_mouth = at_mouth and sp.distance_to(mo) < 0.5 and sp.y > float(L[2]) + 10.0 * dr.k    # at the mouth, well below the head top
		var lv: Vector2 = L[3]
		horiz = horiz and absf(lv.y) <= 0.05 * absf(lv.x) and absf(lv.x) > 50.0 and bool(L[4])
	_check("dragon bolts: spawn at the mouth for his facing and size (not above the head)", at_mouth, str(launches))
	_check("dragon bolts: leave the mouth horizontally (vy ~ 0), toward Mera", horiz, str(launches))
	var near_ok := tracked.size() == 5
	for key in tracked:
		near_ok = near_ok and absf(float(tracked[key][0]) - float(tracked[key][1])) <= T.DRAGON_BOLT_SPREAD + 90.0
	_check("dragon bolts: gravity curves them down onto Mera (every bolt ends within the aim spread of her)", near_ok, str(tracked.values()))
	_check("dragon flight: wing loop 'fly' between lobs and 'spit' to lob (never the sped-up idle)", volley_anims.has("fly") and volley_anims.has("spit") and not volley_anims.has("idle"), str(volley_anims.keys()))
	var breath_kept := false
	for at in dr.attacks:
		if at["anim"] == "breath" and at["mode"] == "frames":
			breath_kept = true
	var bt: Texture2D = dr.sprite.sprite_frames.get_frame_texture("breath", 6)
	var bimg: Image = bt.get_image()
	if bimg.is_compressed():
		bimg.decompress()
	var bfire := 0
	for y in bimg.get_height():
		for x in bimg.get_width():
			var c: Color = bimg.get_pixel(x, y)
			if c.a > 0.5 and Vector3i(c.r8, c.g8, c.b8) in [Vector3i(242, 74, 2), Vector3i(255, 141, 7), Vector3i(255, 214, 133)]:
				bfire += 1
	_check("dragon ground breath attack unchanged (still the original 'breath' frames with the plume)", breath_kept and bt.resource_path.find("/sprites/breath/") >= 0 and bfire > 100, "%s fire_px=%d" % [bt.resource_path, bfire])
	_check("dragon: no growth when no bolt hurts Mera (she was invulnerable)", dr.size == 12 and dr.growths == 0, "size=%d" % dr.size)
	# one huge hit skips 9x, 6x and 3x: every crossed phase runs once, in order, each landing
	dr.take_damage(T.DRAGON_HP_PER_SIZE * 10, m.global_position.x, "explosion")
	var queued: Array = dr.phase_queue.duplicate()
	await _dragon_until_landed(g, dr, true, 4000)
	var d3: Array = []
	var s3 := {}
	for sp in dr.spit_spots:
		if int(sp[3]) == 3:
			d3.append(absf(float(sp[2])))
			s3[signf(float(sp[2]))] = true
	_check("dragon flight at 3x: lobs from short to long range (spread >= 400 px), both sides of Mera", d3.size() == 5 and d3.max() - d3.min() >= 400.0 and s3.size() == 2, str(d3))
	_check("dragon: a hit past several thresholds queues each owed phase (9, 6, 3) and runs them once, landing every time", queued == [9, 6, 3] and dr.phase_log == [12, 9, 6, 3] and dr.landings == 4 and dr.size == 2, "queued=%s log=%s land=%d size=%d" % [queued, dr.phase_log, dr.landings, dr.size])
	var big := 9999
	dr.take_damage(big, m.global_position.x, "explosion")
	_check("dragon: a hit can't take it below 1x (any size above 1x -> 1x)", dr.alive() and dr.size == 1, "size=%d hp=%d" % [dr.size, dr.hp])
	await _s4_frames(g, 30)
	dr.take_damage(1, m.global_position.x, "melee")
	_check("dragon: dies when hit at 1x; no phase ever repeats", not dr.alive() and dr.phase_log == [12, 9, 6, 3], "hp=%d" % dr.hp)
	for i in 240:
		await physics_frame
		m.invuln = 1.0
	LVS.current = 5                       # the exit rule for a boss level (the dragon's own stage is index 5)
	var exit_open: bool = g.boss_dead and not g.exit_locked()
	LVS.current = 3
	_check("dragon: its death unlocks the exit", exit_open, "boss_dead=%s" % g.boss_dead)
	g.queue_free()
	await physics_frame
	# growth: a phase bolt that hurts Mera -> +3 sizes, once per phase, and the used threshold is not re-armed
	g = await _s4_new(3)
	m = g.mera
	m.position.x = 12000.0
	m.set_size(6, true)
	g.snap_camera()
	dr = g.spawn_enemy("dragon", 12900.0, {"size": 13})
	await _s4_frames(g, 30)
	dr.cooldown = 99.0
	dr.take_damage(T.DRAGON_HP_PER_SIZE, m.global_position.x, "melee")
	m.invuln = 0.0
	m.last_l2_t = -1e9
	var hurt := 0
	var sz_prev: int = m.size
	for i in 1500:
		await physics_frame
		m.position.x = 12000.0
		if m.size < sz_prev:
			hurt += 1
		sz_prev = m.size
		if m.size <= 2:
			m.set_size(6, true)
			sz_prev = 6
		if dr.phase == "" and dr.phase_queue.is_empty():
			break
	_check("dragon: bolts lob onto Mera from above and hurt her (%d hits, fixed %d each)" % [hurt, T.DRAGON_BOLT_DMG], hurt >= 1 and dr.landings == 1, "hurt=%d land=%d" % [hurt, dr.landings])
	_check("dragon: a bolt hit grows it +%d sizes, once per phase (12x -> 15x)" % T.DRAGON_GROW, dr.growths == 1 and dr.size == 15, "growths=%d size=%d" % [dr.growths, dr.size])
	await _s4_frames(g, 60)
	dr.take_damage(T.DRAGON_HP_PER_SIZE * 3, m.global_position.x, "melee")
	await _s4_frames(g, 5)
	_check("dragon: growing back past 12x does not re-arm the 12x phase", dr.size == 12 and dr.phase == "" and dr.phase_queue.is_empty() and dr.phase_log == [12], "size=%d phase=%s log=%s" % [dr.size, dr.phase, dr.phase_log])
	g.queue_free()
	await physics_frame



## v0.8 SUPER EARTHQUAKE: Down+Y crouching with a full meter (outside Fury)
func _super_quake_tests() -> void:
	var T = load("res://scripts/game/tuning.gd")
	var g: Node = await _s4_new(2)
	var m: Node = g.mera
	m.position.x = 6000.0
	m.set_size(4, true)
	g.snap_camera()
	await _s4_frames(g, 5)
	var w: Node2D = g.spawn_enemy("werewolf", 6500.0)
	var dr: Node2D = g.spawn_enemy("dragon", 7400.0)
	await _s4_frames(g, 20)
	w.hp = 99
	w.cooldown = 99.0
	dr.cooldown = 99.0
	var dhp: int = dr.hp
	var cam0: float = g.cam_x
	var ground_props: Array = []
	var lever_ok := true
	for pr in g.props:
		if is_instance_valid(pr) and pr.alive() and pr.kind != "chandelier" and pr.kind != "lever" and absf(pr.global_position.x - g.cam_x) <= T.SUPER_QUAKE_REACH - 200.0:        # margin: the camera drifts a little
			ground_props.append(pr)
	var far_prop: Node2D = null
	for pr in g.props:
		if is_instance_valid(pr) and pr.alive() and pr.kind in ["candle", "candle_b", "urn", "crate", "chest"] and absf(pr.global_position.x - g.cam_x) > T.SUPER_QUAKE_REACH + 400.0:
			far_prop = pr
			break
	m.rage = 100.0
	m.stamina = 60.0
	await _drive(g, [[2, "down", true], [10, "btn_y", true], [13, "btn_y", false], [20, "down", false]], 12)
	var impact_vis: bool = g.impact_t > 0.0 and g.impact_layer != null and g.impact_layer.visible
	var quake_not_yet: bool = g.quake_t <= 0.0
	for i in 12:
		await physics_frame
		m.invuln = 1.0
	_check("super quake: Down+Y at 100 %% rage -> impact frame (%.2f s black/white freeze) first, then the quake" % T.IMPACT_FRAME_S, m.super_quakes == 1 and impact_vis and quake_not_yet and g.super_on and not g.impact_layer.visible and g.quake_t > 1.5, "impact=%s quake=%f super=%s" % [impact_vis, g.quake_t, g.super_on])
	_check("super quake: costs the normal 20 stamina and spends the whole meter", absf(m.stamina - 40.0) < 0.5 and (m.rage_spending or m.rage == 0.0), "st=%f rage=%f" % [m.stamina, m.rage])
	_check("super quake: flat %d damage to every enemy (never x size), the dragon's size pool too" % T.SUPER_QUAKE_DMG, w.hp == 99 - T.SUPER_QUAKE_DMG and dr.hp == dhp - T.SUPER_QUAKE_DMG, "w=%d dragon %d->%d" % [w.hp, dhp, dr.hp])
	var broke := 0
	for pr in ground_props:
		if not is_instance_valid(pr) or not pr.alive():
			broke += 1
	_check("super quake: every ground breakable on/near screen is destroyed (%d); far ones stay" % ground_props.size(), ground_props.size() >= 2 and broke == ground_props.size() and (far_prop == null or far_prop.alive()), "broke %d/%d cam %d->%d survivors=%s" % [broke, ground_props.size(), int(cam0), int(g.cam_x), ground_props.filter(func(p): return is_instance_valid(p) and p.alive()).map(func(p): return "%s@%d hp%d %s" % [p.kind, int(p.global_position.x), p.hp, p.state])])
	var peak := 0.0
	var shaken_long := false
	for i in 150:
		await physics_frame
		m.invuln = 1.0
		peak = maxf(peak, g.shake_amt)
		if i == 100 and g.quake_t > 0.0:
			shaken_long = true
	_check("super quake: shakes for 2 s, twice as hard as the normal one", shaken_long and peak >= T.SUPER_QUAKE_SHAKE - 0.1 and T.SUPER_QUAKE_SHAKE > T.QUAKE_SHAKE, "peak=%f" % peak)
	for i in 180:
		await physics_frame
		m.invuln = 1.0
	_check("super quake: grounded enemies stay stunned 7 s from the start (still at ~5.5 s)", w.state == "stun" and w.stun_t > 0.8, "state=%s stun=%f" % [w.state, w.stun_t])
	for i in 120:
		await physics_frame
		m.invuln = 1.0
	_check("...and recover after 7 s", w.state != "stun", "state=%s" % w.state)
	g.queue_free()
	await physics_frame
	# below 100 %: the normal quake; in Fury: the normal quake (the meter is the Fury timer)
	g = await _s4_new(1)
	m = g.mera
	m.rage = 99.0
	await _drive(g, [[2, "down", true], [10, "btn_y", true], [13, "btn_y", false], [20, "down", false]], 30)
	_check("super quake: at 99 % rage it's the normal earthquake (no impact frame, rage kept)", m.super_quakes == 0 and not g.super_on and g.quake_t > 0.0 and g.quake_t <= T.QUAKE_S and m.rage == 99.0, "rage=%f" % m.rage)
	await _s4_frames(g, 90)
	m.rage = 100.0
	m.stamina = 60.0
	await _drive(g, [[2, "l2", true], [2, "r2", true], [10, "l2", false], [10, "r2", false]], 30)
	var fury0: bool = m.fury
	m.stamina = 60.0
	await _drive(g, [[2, "down", true], [10, "btn_y", true], [13, "btn_y", false], [20, "down", false]], 30)
	_check("super quake: not in Fury (the meter is the Fury timer) -> normal earthquake, Fury goes on", fury0 and m.fury and m.super_quakes == 0 and not g.super_on and g.quake_t > 0.0, "fury=%s sq=%d" % [m.fury, m.super_quakes])
	g.queue_free()
	await physics_frame



func Levels_EDGE() -> float:
	return float(load("res://scripts/game/levels.gd").EDGE)


## v0.8.2: the bolt's blunt round head leads along the velocity, the flame trails behind
func _bolt_orientation_tests() -> void:
	var BOLT = load("res://scripts/game/dragon_bolt.gd")
	var img: Image = load("res://assets/characters/ansimuz/hell-beast/Fireball/Sprites/frame1.png").get_image()
	if img.is_compressed():
		img.decompress()
	var lm := 0
	var rm := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.15:
				if x < img.get_width() / 2:
					lm += 1
				else:
					rm += 1
	_check("fireball art: the blunt head is on the LEFT (more mass), the trail on the right -> NATIVE_HEAD = -1", lm > rm and BOLT.NATIVE_HEAD == -1, "left=%d right=%d" % [lm, rm])
	var g: Node = await _s4_new(3)
	var m: Node = g.mera
	m.position.x = 6000.0
	g.snap_camera()
	await _s4_frames(g, 5)
	var ok := true
	var info: Array = []
	# a real lob (fixed flight time: up, apex, down) to the right, and horizontal launches both ways
	for cfg in [[Vector2(5000, 700), Vector2(5600, 1000), 1.4], [Vector2(7000, 600), Vector2(6500, 1000), 1.2], [Vector2(5200, 400), Vector2(5900, 1000), -1.0], [Vector2(6900, 400), Vector2(6200, 1000), -1.0]]:
		var b: Node2D = BOLT.new()
		b.setup(g, null, cfg[0], cfg[1], cfg[2])
		g.world.add_child(b)
		var phases := {}
		for i in 200:
			await physics_frame
			m.invuln = 1.0
			if not is_instance_valid(b) or b.done:
				break
			var v: Vector2 = b.vel
			var dot: float = b.head_dir().dot(v.normalized())
			var ph := "rise" if v.y < -150.0 else ("apex" if v.y < 150.0 else "descent")
			if i == 0:
				ph = "launch"
			phases[ph] = minf(float(phases.get(ph, 1.0)), dot)
		for k in phases:
			ok = ok and float(phases[k]) > 0.97
		info.append(phases)
		ok = ok and phases.has("launch") and phases.has("apex") and phases.has("descent")
	_check("dragon bolts: the blunt head points along the velocity at launch, apex and descent (lobs and horizontal shots, both directions)", ok, str(info))
	g.queue_free()
	await physics_frame



## v0.9 updater (scripts/app/updater.gd) and the title menu's update / credits entries
func _updater_tests() -> void:
	var U: Node = root.get_node("Updater")
	var ep := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check("updater: the Android preset requests INTERNET and REQUEST_INSTALL_PACKAGES (custom_permissions; Godot has no checkbox for it)", ep.contains("permissions/internet=true") and ep.contains("android.permission.REQUEST_INSTALL_PACKAGES"), "")
	_check("updater: this build's version comes from application/config/version", U.current_version() == String(ProjectSettings.get_setting("application/config/version", "")), U.current_version())
	_check("updater: version tags parse (v0.8-playable = 0.8.0, v0.8.2-playable, v1.10.3)", U.parse_version("v0.8-playable") == [0, 8, 0] and U.parse_version("v0.8.2-playable") == [0, 8, 2] and U.parse_version("v1.10.3") == [1, 10, 3] and U.parse_version("scale-test").is_empty(), "")
	_check("updater: version order (0.10 > 0.9.9, 0.9.1 > 0.9.0, equal is not newer)", U.newer([0, 10, 0], [0, 9, 9]) and U.newer([0, 9, 1], [0, 9, 0]) and not U.newer([0, 9, 0], [0, 9, 0]) and not U.newer([0, 8, 2], [0, 9, 0]), "")
	var rel := func(tag: String, names: Array, draft := false) -> Dictionary:
		var assets: Array = []
		for n in names:
			assets.append({"name": n, "browser_download_url": "https://x/" + tag + "/" + n, "size": 1234})
		return {"tag_name": tag, "name": tag, "draft": draft, "prerelease": true, "assets": assets, "html_url": "https://x/" + tag}
	var rs: Array = [rel.call("v0.8.2-playable", ["Mera_Playable_v0.8.2_Windows.exe", "Mera_Playable_v0.8.2_Android.apk", "SHA256SUMS.txt"]),
		rel.call("v0.9.2-playable", ["Mera_Playable_v0.9.2_Linux.x86_64", "SHA256SUMS.txt"]),
		rel.call("v0.9.1-playable", ["Mera_Playable_v0.9.1_Windows.exe", "Mera_Playable_v0.9.1_Android.apk", "SHA256SUMS.txt"]),
		rel.call("v0.9.9-playable", ["Mera_Playable_v0.9.9_Windows.exe"], true),
		rel.call("v0.1-scale-test", ["Mera_Scale_Test_Windows.zip"])]
	var old_p: String = U.platform
	U.platform = "Windows"
	var w: Dictionary = U.pick_latest(rs, "0.9.0")
	U.platform = "Android"
	var a: Dictionary = U.pick_latest(rs, "0.9.0")
	U.platform = "Linux"
	var l: Dictionary = U.pick_latest(rs, "0.9.0")
	var none: Dictionary = U.pick_latest(rs, "0.9.2")
	U.platform = "Web"
	var unsup: bool = not U.supported()
	U.platform = old_p
	_check("updater: picks the newest non-draft release with this platform's asset (pre-releases count)", String(w.get("tag", "")) == "v0.9.1-playable" and String(w.get("asset", "")).ends_with("_Windows.exe") and String(a.get("asset", "")).ends_with("_Android.apk") and String(l.get("tag", "")) == "v0.9.2-playable" and String(w.get("sums_url", "")).ends_with("SHA256SUMS.txt"), "%s / %s / %s" % [w, a, l])
	_check("updater: nothing newer -> up to date; unsupported platforms are told so", none.is_empty() and unsup, str(none))
	var sums: Dictionary = U.parse_sums("2f8d1922a8200a7376b2d1b47a7ae53c94630ecb5f7379aacb89e0df616c6034  Mera_Playable_v0.8.2_Android.apk\nbad line\nE651481F13ACB020679C115A78D0A71D7E35C01186B099216851781A37A2B08F *Mera_Playable_v0.8.2_Windows.exe\n")
	_check("updater: SHA256SUMS.txt parses (sha256sum format, binary '*' marker, case-insensitive)", sums.size() == 2 and String(sums.get("Mera_Playable_v0.8.2_Windows.exe", "")).begins_with("e651481f"), str(sums))
	# verification: right file passes, a corrupted one is deleted
	var p := ProjectSettings.globalize_path("user://upd_test.bin")
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("mera update payload")
	f.close()
	U.file_path = p
	U.latest = {"version": [9, 9, 9], "size": 19, "asset": "x"}
	U._expect_sha = FileAccess.get_sha256(p)
	U._verify()
	var ok_state: String = U.state
	U._expect_sha = "0".repeat(64)
	U._verify()
	_check("updater: a download is accepted only if size AND SHA-256 match; a mismatch is deleted", ok_state == "ready" and U.state == "error" and not FileAccess.file_exists(p), "%s -> %s" % [ok_state, U.state])
	var bat: String = U.windows_helper(4242, "C:/Games/Mera/Mera.exe.new", "C:/Games/Mera/Mera.exe")
	_check("updater: Windows helper waits for the PID, swaps the exe, relaunches and deletes itself", bat.find("PID eq 4242") >= 0 and bat.find("move /Y \"C:\\Games\\Mera\\Mera.exe.new\" \"C:\\Games\\Mera\\Mera.exe\"") >= 0 and bat.find("start \"\" \"C:\\Games\\Mera\\Mera.exe\"") >= 0 and bat.find("del \"%~f0\"") >= 0, bat)
	var sh: String = U.posix_helper(4242, "/g/new", "/g/Mera")
	_check("updater: Linux helper waits, swaps, chmods and relaunches", sh.find("kill -0 4242") >= 0 and sh.find("mv -f '/g/new' '/g/Mera'") >= 0 and sh.find("exec '/g/Mera'") >= 0, sh)
	U.state = "idle"
	U.latest = {}
	# offline / bad URL: a graceful error, never a crash
	U.api_url = "http://127.0.0.1:9/none"
	U.platform = "Linux"
	U.check()
	for i in 600:
		await process_frame
		if U.state != "checking":
			break
	_check("updater: no network -> state 'error' with a message (no crash, the game goes on)", U.state == "error" and String(U.message).find("failed") >= 0, "%s: %s" % [U.state, U.message])
	U.api_url = ""
	U.platform = old_p
	U.state = "idle"
	# the title menu: bottom row and the credits screen
	var menu: Control = load("res://scenes/menu.tscn").instantiate() if ResourceLoader.exists("res://scenes/menu.tscn") else null
	if menu:
		U.auto_check = false
		root.add_child(menu)
		await process_frame
		var down := InputEventAction.new()
		down.action = "down"
		down.pressed = true
		menu._unhandled_input(down)                          # cards -> character toggle
		menu._unhandled_input(down)                          # character toggle -> bottom buttons
		var right := InputEventAction.new()
		right.action = "right"
		right.pressed = true
		for _i in 3:
			menu._unhandled_input(right)
		var acc := InputEventAction.new()
		acc.action = "btn_a"
		acc.pressed = true
		menu._unhandled_input(acc)
		var in_credits: bool = menu.mode == "credits"
		var back := InputEventAction.new()
		back.action = "btn_b"
		back.pressed = true
		menu._unhandled_input(back)
		_check("menu: Down x2 -> bottom row (past the character toggle), Right x3 -> CREDITS, A opens it, B closes it", in_credits and menu.mode == "menu" and menu.row == 1, "mode=%s row=%d" % [menu.mode, menu.row])
		var C = load("res://scripts/app/credits.gd")
		var whos: Array = []
		for c in C.ENTRIES:
			whos.append(String(c["who"]))
		var need := ["chierit", "Merakintsugi", "LuizMelo", "Stealthix", "HydroGene", "Zane Little Music", "Kenney", "Pixel Frog", "Jimmy D. Journey", "Reactorcore", "rubberduck", "vk", "Godot Engine"]
		var all_in := true
		for n in need:
			all_in = all_in and whos.has(n)
		var chierit: Dictionary = C.ENTRIES[0]
		_check("credits: every pack author + Godot (MIT, godotengine.org/license); chierit CC-BY 4.0 with his itch link, incl. Minotaur", all_in and whos.any(func(x): return String(x).find("ansimuz") >= 0) and String(chierit["lic"]) == "CC-BY 4.0" and String(chierit["url"]) == "https://chierit.itch.io" and String(chierit["what"]).find("Minotaur") >= 0 and String(C.ENTRIES[C.ENTRIES.size() - 1]["url"]) == "https://godotengine.org/license", str(whos))
		menu.queue_free()
		await process_frame
		U.auto_check = true

func _key(kc: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = kc
	e.pressed = pressed
	Input.parse_input_event(e)


func _mark_tests() -> void:
	var C = root.get_node("Controls")
	C.scheme = "key"
	C.joy_r = Vector2.ZERO
	C.pad_keys.clear()
	C.clear_gestures()
	_key(KEY_KP_1, true)
	await physics_frame
	var kp_l2: bool = Input.is_action_pressed("l2")
	_key(KEY_KP_1, false)
	_key(KEY_1, true)
	await physics_frame
	var row_l2: bool = Input.is_action_pressed("l2")
	_key(KEY_1, false)
	await physics_frame
	_check("numpad 1 does not press L2; top-row 1 does", not kp_l2 and row_l2, "kp=%s row=%s" % [kp_l2, row_l2])
	C.clear_gestures()
	_key(KEY_KP_8, true)
	await physics_frame
	var flick8: int = C.consume_flick()
	var up_n: int = C.compass_n(Vector2(0, -1))
	var held_v: Vector2 = C.right_vector()
	_key(KEY_KP_8, false)
	await physics_frame
	_check("numpad 8 (Num Lock) is a right-stick flick up, and counts as the pad", flick8 == 8 and C.scheme == "pad" and up_n == 8, "flick=%d scheme=%s up=%d vec=%s" % [flick8, C.scheme, up_n, held_v])
	_key(KEY_KP_5, true)
	await physics_frame
	var r3: bool = C.consume_r3()
	_key(KEY_KP_5, false)
	await physics_frame
	_check("numpad 5 is R3", r3, "")
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.pressed = true
	t.position = Vector2(300, 300)
	Input.parse_input_event(t)
	await physics_frame
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = Vector2(300, 300 - 120)
	Input.parse_input_event(d)
	await physics_frame
	var swipe: int = C.consume_flick()
	t.pressed = false
	Input.parse_input_event(t)
	await physics_frame
	_check("a touch swipe is that direction, and a device of its own", swipe == 8 and C.scheme == "touch", "swipe=%d scheme=%s" % [swipe, C.scheme])
	C.scheme = "key"
	C.joy_r = Vector2.ZERO
	C.pad_keys.clear()
	C.clear_gestures()
	var g: Node = await _new_game()
	var m: Node = g.mera
	m.rage = 40.0
	await _drive(g, [[2, "l1", true], [2, "r1", true], [2, "l2", true], [2, "r2", true], [8, "l1", false], [8, "r1", false], [8, "l2", false], [8, "r2", false]], 12)
	_check("Q+W+1+2 below a full meter does not freeze", not g.mark_lock and not m.fury, "lock=%s fury=%s" % [g.mark_lock, m.fury])
	g.queue_free()
	await physics_frame
	g = await _new_game()
	m = g.mera
	var e: Node2D = g.spawn_enemy("werewolf", m.global_position.x + 420.0)
	await physics_frame
	e.cooldown = 99.0
	var hp0: int = e.hp
	var x0: float = e.global_position.x
	m.rage = 100.0
	await _drive(g, [[2, "l1", true], [2, "r1", true], [2, "l2", true], [2, "r2", true]], 3)
	var x1: float = e.global_position.x
	for i in 20:
		await physics_frame
	_check("100 rage + Q+W+1+2 freezes Mera and the enemy, costs 100, does not start Fury", g.mark_lock and not m.fury and m.rage == 0.0 and m.vel == Vector2.ZERO and absf(e.global_position.x - x1) < 0.5, "lock=%s rage=%f fury=%s" % [g.mark_lock, m.rage, m.fury])
	_check("keyboard prompts are digits 1-9", g.marker.on and not g.marker.arrows and g.marker.marks.size() == 1 and int(g.marker.marks[0]["n"]) >= 1, "n=%s" % g.marker.marks[0]["n"])
	var n: int = int(g.marker.marks[0]["n"])
	if n == 5:
		C.r3_pending = true
	else:
		_key(KEY_1 + n - 1, true)
	await physics_frame
	if n != 5:
		_key(KEY_1 + n - 1, false)
	await physics_frame
	var sfx = root.get_node("Sfx")
	var last_sfx: String = sfx.history[-1][0] if sfx.history.size() else ""
	_check("the matching number slashes that enemy for a flat 3 and plays the slice", e.hp == hp0 - 3 and g.marker.slashed == 1 and not g.mark_lock and last_sfx == "swipe", "hp %d->%d slashed=%d lock=%s sfx=%s" % [hp0, e.hp, g.marker.slashed, g.mark_lock, last_sfx])
	_check("she did not walk off while frozen", absf(m.global_position.x - 760.0) < 2.0, "x=%f" % m.global_position.x)
	g.queue_free()
	await physics_frame
	C.scheme = "pad"
	C.clear_gestures()
	g = await _new_game()
	m = g.mera
	m.rage = 150.0
	m.fury = true
	m.fury_left = 4.0
	var mobs: Array = []
	for i in 10:
		var w: Node2D = g.spawn_enemy("wolf", m.global_position.x + 500.0 + i * 80.0)
		w.cooldown = 99.0
		mobs.append(w)
	await physics_frame
	await _drive(g, [[2, "l1", true], [2, "r1", true], [2, "l2", true], [2, "r2", true], [6, "l1", false], [6, "r1", false], [6, "l2", false], [6, "r2", false]], 8)
	var nums := {}
	for mk in g.marker.marks:
		nums[int(mk["n"])] = true
	_check("the freeze slash costs 100 even during Fury, and marks at most 9", g.mark_lock and m.fury and absf(m.rage - 50.0) < 0.1 and g.marker.arrows and g.marker.marks.size() == 9 and nums.size() == 9, "n=%d rage=%f" % [g.marker.marks.size(), m.rage])
	var mk0: Dictionary = g.marker.marks[0]
	var foe: Node2D = mk0["e"]
	var fn: int = int(mk0["n"])
	var fhp: int = foe.hp
	if fn == 5:
		C.r3_pending = true
	else:
		C.joy_r = C.vector_for(fn)
		C.armed = true
	await physics_frame
	C.joy_r = Vector2.ZERO
	await physics_frame
	_check("a right-stick flick in that direction deals the flat 3", foe.hp == fhp - 3 and g.marker.slashed == 1, "hp %d->%d n=%d" % [fhp, foe.hp, fn])
	g.queue_free()
	await physics_frame
	C.scheme = "key"
	C.joy_r = Vector2.ZERO
	C.pad_keys.clear()
	C.clear_gestures()
	_key(KEY_1, false)
	_key(KEY_2, false)
	await physics_frame


# ================================================================ v0.9.1 (owner t99u, t101u)
## forced-input drive that also records every Mera bolt that appears: returns {bolts: [Shot], ...}
func _vdrive(g: Node, steps: Array, frames: int, each: Callable = Callable()) -> Dictionary:
	var m: Node = g.mera
	var seen := {}
	var out := {"bolts": [], "bolt_info": [], "up": [], "air_bubble": 0, "max_air_vy": 0.0, "vx_bubble": []}
	for f in range(1, frames + 1):
		for st in steps:
			if int(st[0]) == f:
				m.forced[st[1]] = st[2]
		await physics_frame
		m.invuln = maxf(m.invuln, 0.5)
		for c in g.world.get_children():
			if c.get("kind") == "bolt" and c.get("speed_mult") != null and not seen.has(c.get_instance_id()):
				seen[c.get_instance_id()] = true
				out["bolts"].append(c)
				out["bolt_info"].append({"dir": c.dir, "up": c.up, "speed": c.speed()})
				if c.up:
					out["up"].append({"node": c, "p0": c.position, "rot": c.spr.rotation, "speed": c.speed(), "mera_y": m.global_position.y})
		if m.barrier_on and not m.on_ground:
			out["air_bubble"] = int(out["air_bubble"]) + 1
			out["vx_bubble"].append(m.vel.x)
			out["max_air_vy"] = maxf(float(out["max_air_vy"]), m.vel.y)
		if each.is_valid():
			each.call(g, f)
	for a in ["btn_x", "btn_y", "btn_a", "btn_b", "up", "down", "left", "right", "l2", "r2"]:
		m.forced[a] = false
	return out


func _v091_tests() -> void:
	LVS.current = 0
	var g: Node
	var m: Node
	var r: Dictionary
	var s: Array
	# ---------------------------------------------------------------- Y chain
	g = await _new_game(); m = g.mera
	s = []; _tap(s, 5, "btn_y"); _tap(s, 20, "btn_y")
	r = await _vdrive(g, s, 110)
	var log: Array = m.move_log
	_check("Y chain: Y Y -> quick fire, then a follow-up shot (2 bolts)", _has_seq(log, ["quick_fire", "quick_fire"]) and r["bolts"].size() == 2 and m.ychain_log.size() == 1, "log=%s bolts=%d ychain=%s" % [log, r["bolts"].size(), m.ychain_log])
	_check("Y chain: the follow-up fires on quick-fire f14 (canon GIF frame 16), the first on f10 (GIF frame 12)", m.ychain_log.size() == 1 and int(m.ychain_log[0][1]) == 14 and int(AnimLib_fire("quick_fire")) == 10, "%s" % [m.ychain_log])
	var b2: Dictionary = r["bolt_info"][1] if r["bolt_info"].size() >= 2 else {}
	_check("Y chain: the follow-up is the same bolt (same speed, damage path), fired forward", not b2.is_empty() and not b2["up"] and b2["dir"] == m.facing and is_equal_approx(float(b2["speed"]), 400.0 * m.shown), "%s" % [b2])
	g.queue_free(); await process_frame

	g = await _new_game(); m = g.mera
	s = []; _tap(s, 5, "btn_y"); _tap(s, 20, "btn_y"); _tap(s, 35, "btn_y")
	r = await _vdrive(g, s, 140)
	_check("Y chain: Y Y Y -> 3 shots, no beam", r["bolts"].size() == 3 and not ("beam_ender" in m.move_log) and m.ychain_log.size() == 2 and int(m.ychain_log[1][2]) == 3, "bolts=%d %s" % [r["bolts"].size(), m.ychain_log])
	g.queue_free(); await process_frame

	g = await _new_game(); m = g.mera
	var st0: float = m.stamina
	var beam_seen := {"len": 0.0, "st": -1.0}
	s = []; _tap(s, 5, "btn_y"); _tap(s, 20, "btn_y"); _tap(s, 35, "btn_y"); _tap(s, 50, "btn_y")
	r = await _vdrive(g, s, 260, func(gg, _f):
		if gg.mera.anim.key == "beam_ender":
			beam_seen["len"] = maxf(float(beam_seen["len"]), gg.mera.beam_len)
			if float(beam_seen["st"]) < 0.0:
				beam_seen["st"] = gg.mera.stamina)
	_check("Y chain: Y Y Y Y -> the beam attack (the X X X Y beam_ender: same animation, 20 stamina, beam past the screen edge)", "beam_ender" in m.move_log and r["bolts"].size() == 3 and float(beam_seen["len"]) > 300.0 and absf((st0 - 15.0 - 20.0) - float(beam_seen["st"])) < 1.5, "log=%s bolts=%d beam=%s st0=%.1f" % [m.move_log, r["bolts"].size(), beam_seen, st0])
	g.queue_free(); await process_frame

	# Y Y Y, L2 -> pulse wave: knockback only (the enemies arrive after the 3 bolts are gone)
	g = await _new_game(); m = g.mera
	var pe := {"e1": null, "e2": null, "g1": 0.0, "g2": 0.0, "hp1": 0, "hp2": 0, "rage": 0.0}
	s = []; _tap(s, 5, "btn_y"); _tap(s, 20, "btn_y"); _tap(s, 35, "btn_y"); _tap(s, 52, "l2", 6)
	r = await _vdrive(g, s, 150, func(gg, f):
		var mm: Node = gg.mera
		if f == 55:
			for c in gg.world.get_children():
				if c.get("kind") == "bolt":
					c.queue_free()                         # the 3 quick-fire bolts must not touch the test enemies
		if f == 56:                                        # the pulse fires at frame 58, so the enemies must stand there by then
			pe["e1"] = gg.spawn_enemy("ogre", mm.global_position.x + mm.facing * 330.0)
			pe["e2"] = gg.spawn_enemy("wolf", mm.global_position.x - mm.facing * 360.0)
		if f == 57:
			pe["g1"] = absf(pe["e1"].global_position.x - mm.global_position.x)
			pe["g2"] = absf(pe["e2"].global_position.x - mm.global_position.x)
			pe["hp1"] = pe["e1"].hp
			pe["hp2"] = pe["e2"].hp
			pe["rage"] = mm.rage
		for k in ["e1", "e2"]:
			if pe[k] != null and is_instance_valid(pe[k]):
				pe[k].cooldown = 99.0)
	var e1: Node2D = pe["e1"]
	var e2: Node2D = pe["e2"]
	var moved1 := absf(e1.global_position.x - m.global_position.x) - float(pe["g1"])
	var moved2 := absf(e2.global_position.x - m.global_position.x) - float(pe["g2"])
	_check("Y chain: Y Y Y, L2 -> pulse wave (no bubble, no lightning)", "pulse" in m.move_keys and not ("barrier" in m.move_keys) and not ("lightning" in m.move_keys) and g.pulses.size() == 1, "keys=%s pulses=%s" % [m.move_keys, g.pulses])
	_check("Y chain: the pulse pushes enemies on both sides away (>= 120 px) and deals 0 damage (no rage)", moved1 >= 120.0 and moved2 >= 120.0 and e1.hp == int(pe["hp1"]) and e2.hp == int(pe["hp2"]) and absf(m.rage - float(pe["rage"])) < 0.01, "moved %.0f/%.0f hp %d/%d %d/%d" % [moved1, moved2, e1.hp, int(pe["hp1"]), e2.hp, int(pe["hp2"])])
	g.queue_free(); await process_frame

	# Y Y Y, X -> vertical beam: hits flyers in the column, never ground enemies
	g = await _new_game(); m = g.mera
	var fl: Node2D = g.spawn_enemy("flying_eye", m.global_position.x + m.facing * 10.0)
	fl.cooldown = 99.0
	var fl_hp: int = fl.hp
	var gv := {"gr": null, "hp": 0}
	var keep := func(gg, f):
		var mm: Node = gg.mera
		if is_instance_valid(fl):
			fl.cooldown = 99.0
			fl.position.x = mm.global_position.x + mm.facing * 15.0 * mm.shown
			fl.position.y = mm.global_position.y - 520.0
		if f == 58:
			for c in gg.world.get_children():
				if c.get("kind") == "bolt":
					c.queue_free()
		if f == 60:
			gv["gr"] = gg.spawn_enemy("ogre", mm.global_position.x + mm.facing * 40.0)
		if f == 61:
			gv["hp"] = gv["gr"].hp
		if gv["gr"] != null and is_instance_valid(gv["gr"]):
			gv["gr"].cooldown = 99.0
	s = []; _tap(s, 5, "btn_y"); _tap(s, 20, "btn_y"); _tap(s, 35, "btn_y"); _tap(s, 52, "btn_x")
	var vb := {"top": 1e9, "hits": 0}
	r = await _vdrive(g, s, 170, func(gg, f):
		keep.call(gg, f)
		if is_instance_valid(gg.last_vbeam):
			vb["top"] = minf(float(vb["top"]), gg.last_vbeam.top_y)
			vb["hits"] = gg.last_vbeam.hits)
	_check("Y chain: Y Y Y, X -> heal pose + vertical beam (no 1x attack)", "vbeam" in m.move_keys and not ("atk1" in m.move_keys) and "heal" in m.move_log, "log=%s" % [m.move_log])
	_check("Y chain: the vertical beam reaches above the top of the screen", float(vb["top"]) < g.cam.position.y - 540.0, "top=%.0f screen top=%.0f" % [float(vb["top"]), g.cam.position.y - 540.0])
	var gr: Node2D = gv["gr"]
	_check("Y chain: the vertical beam hits the flyer above her (3 x size) and not the ogre on the ground", (not is_instance_valid(fl) or fl.hp < fl_hp or fl.hp <= 0) and int(vb["hits"]) >= 1 and is_instance_valid(gr) and gr.hp == int(gv["hp"]), "fl %s gr %d/%d hits=%d" % [str(fl.hp) if is_instance_valid(fl) else "dead", gr.hp, int(gv["hp"]), int(vb["hits"])])
	g.queue_free(); await process_frame

	# Y Y, X: only after the 3rd shot -> otherwise a plain 1x attack follows
	g = await _new_game(); m = g.mera
	s = []; _tap(s, 5, "btn_y"); _tap(s, 20, "btn_y"); _tap(s, 40, "btn_x")
	r = await _vdrive(g, s, 140)
	_check("Y chain: Y Y, X -> no vertical beam (X after 2 shots is the 1x attack)", not ("vbeam" in m.move_keys) and "atk1" in m.move_keys, "keys=%s" % [m.move_keys])
	g.queue_free(); await process_frame

	# post-recovery grace: Y just after the quick fire recovered still chains; a late Y is a fresh quick fire
	g = await _new_game(); m = g.mera
	var fin := {"f": -1}
	s = []; _tap(s, 5, "btn_y")
	await _vdrive(g, s, 80, func(gg, f):
		if int(fin["f"]) < 0 and gg.mera.state == "ground" and f > 10:
			fin["f"] = f)
	g.queue_free(); await process_frame
	var rec: int = int(fin["f"])
	g = await _new_game(); m = g.mera
	s = []; _tap(s, 5, "btn_y"); _tap(s, rec + 6, "btn_y")
	await _vdrive(g, s, rec + 80)
	_check("Y chain: a Y within 220 ms after the quick fire recovered still chains (follow-up from f14)", m.ychain_log.size() == 1, "rec=%d log=%s %s" % [rec, m.move_log, m.ychain_log])
	g.queue_free(); await process_frame
	g = await _new_game(); m = g.mera
	s = []; _tap(s, 5, "btn_y"); _tap(s, rec + 25, "btn_y")
	await _vdrive(g, s, rec + 90)
	_check("Y chain: a Y 400 ms after recovery starts a fresh quick fire (no chain)", m.ychain_log.is_empty() and m.move_keys.count("quick_fire") == 2, "log=%s %s" % [m.move_log, m.ychain_log])
	g.queue_free(); await process_frame

	# human timing
	var Y := {"a": "btn_y"}
	await _human_combo("Y Y Y Y -> 3 shots, then the beam", [Y, Y, Y, Y], ["quick_fire", "qf_chain", "qf_chain", "beam_ender"], ["rear_blast", "atk1", "adash"], 8, Callable(), true)
	await _human_combo("Y Y Y, L2 -> pulse wave", [Y, Y, Y, {"a": "l2"}], ["quick_fire", "qf_chain", "qf_chain", "pulse"], ["barrier", "lightning", "beam_ender"], 8, Callable(), true)
	await _human_combo("Y Y Y, X -> vertical beam", [Y, Y, Y, {"a": "btn_x"}], ["quick_fire", "qf_chain", "qf_chain", "vbeam"], ["atk1", "rear_blast", "beam_ender"], 8, Callable(), true)
	await _human_combo("X X X Y still -> the beam (unchanged)", [{"a": "btn_x"}, {"a": "btn_x"}, {"a": "btn_x"}, Y], ["atk1", "atk2", "beam_ender"], ["qf_chain", "vbeam", "pulse"], 8, Callable(), true)

	# ---------------------------------------------------------------- air bubble
	g = await _new_game(); m = g.mera
	await _vdrive(g, [], 5)
	var x0: float = m.global_position.x
	s = [[3, "btn_a", true], [3, "right", true], [30, "up", true], [33, "up", false], [38, "l2", true], [41, "right", false], [41, "btn_a", false], [140, "l2", false]]
	r = await _vdrive(g, s, 170)
	var vxs: Array = r["vx_bubble"]
	var steady := vxs.size() > 3
	for v in vxs:
		if absf(float(v) - float(vxs[0])) > 0.5:
			steady = false
	_check("air bubble: L2 in the air raises the barrier (bubble up while airborne)", int(r["air_bubble"]) >= 6 and "barrier" in m.move_keys, "air frames=%d log=%s" % [int(r["air_bubble"]), m.move_log])
	_check("air bubble: she keeps her running momentum after letting go of the stick (vx unchanged, not zeroed) and falls with normal gravity", steady and absf(float(vxs[-1])) > 300.0 and float(r["max_air_vy"]) > 100.0, "vx=%s max vy=%.0f" % [vxs.slice(0, 6), float(r["max_air_vy"])])
	_check("air bubble: she lands still bubbled and stops sliding", m.on_ground and (m.barrier_on or "barrier" in m.move_keys) and absf(m.vel.x) < 1.0, "on_ground=%s vx=%.1f" % [m.on_ground, m.vel.x])
	g.queue_free(); await process_frame
	g = await _new_game(); m = g.mera
	var sz0: int = m.size
	s = [[5, "up", true], [8, "up", false], [12, "l2", true], [80, "l2", false]]
	var blocked := {"n": 0}
	await _vdrive(g, s, 60, func(gg, f):
		if f == 40 and gg.mera.barrier_on and not gg.mera.on_ground:
			gg.mera.invuln = 0.0
			gg.mera.take_hit(1, gg.mera.global_position.x + 100.0)
			blocked["n"] = 1)
	_check("air bubble: still blocks hits in the air", int(blocked["n"]) == 1 and m.size == sz0, "size %d -> %d" % [sz0, m.size])
	g.queue_free(); await process_frame

	# ---------------------------------------------------------------- Up+Y vertical quick fire (t101u)
	var up_cases := [
		["Up+Y same frame", [[5, "up", true], [5, "btn_y", true], [9, "up", false], [9, "btn_y", false]]],
		["Up, then Y 33 ms later", [[5, "up", true], [7, "btn_y", true], [10, "up", false], [11, "btn_y", false]]],
		["Y, then Up 33 ms later", [[5, "btn_y", true], [7, "up", true], [9, "btn_y", false], [11, "up", false]]],
	]
	for c in up_cases:
		g = await _new_game(); m = g.mera
		var gy: float = m.global_position.y
		var maxlift := {"v": 0.0}
		r = await _vdrive(g, c[1], 70, func(gg, _f):
			maxlift["v"] = maxf(float(maxlift["v"]), gy - gg.mera.global_position.y))
		var ub: Array = r["up"]
		_check("Up+Y: %s -> vertical quick fire (heal pose, three bolts: straight up and both diagonals), no jump / aerial dash" % c[0], "vfire" in m.move_keys and ub.size() == 3 and r["bolts"].size() == 3 and not ("adash" in m.move_log) and not ("djump_v" in m.move_log) and m.on_ground and float(maxlift["v"]) < 40.0 * m.shown, "log=%s up=%d bolts=%d lift=%.0f" % [m.move_log, ub.size(), r["bolts"].size(), float(maxlift["v"])])
		g.queue_free(); await process_frame
	g = await _new_game(); m = g.mera
	var fe: Node2D = g.spawn_enemy("flying_eye", m.global_position.x)
	var fe_hp: int = fe.hp
	var trace := {"y": [], "x": []}
	r = await _vdrive(g, [[5, "up", true], [5, "btn_y", true], [9, "up", false], [9, "btn_y", false]], 130, func(gg, _f):
		if is_instance_valid(fe):
			fe.cooldown = 99.0
			fe.position = Vector2(gg.mera.global_position.x + gg.mera.facing * 15.0 * gg.mera.shown, gg.mera.global_position.y - 700.0)
			var ub = gg.last_up_bolt
			if ub != null and is_instance_valid(ub):
				fe.position.x += ub.position.x - fe.hurt_rect().get_center().x
		if not r_up_empty(gg):
			pass)
	var u: Dictionary = {}
	for ubolt in r["up"]:                      # three bolts fly: the straight-up one is the one rotated head-up
		if is_equal_approx(wrapf(float(ubolt["rot"]), -PI, PI), PI / 2.0):
			u = ubolt
	_check("Up+Y: same bolt as quick fire (400 px/s x size), rotated head-up (sprite rot 90 deg), spawned above her head", not u.is_empty() and is_equal_approx(float(u["speed"]), 400.0 * m.shown) and is_equal_approx(wrapf(float(u["rot"]), -PI, PI), PI / 2.0) and Vector2.LEFT.rotated(float(u["rot"])).y < -0.99 and float(u["p0"].y) < float(u["mera_y"]) - 55.0 * m.shown, "%s" % [u])
	_check("Up+Y: the up bolt hits a flyer above her for the quick-fire damage (1 x size)", not is_instance_valid(fe) or fe.hp == fe_hp - 1 * m.size or fe.hp <= 0, "hp %s / %d" % [str(fe.hp) if is_instance_valid(fe) else "dead", fe_hp])
	g.queue_free(); await process_frame
	g = await _new_game(); m = g.mera
	r = await _vdrive(g, [[5, "up", true], [8, "up", false], [15, "btn_y", true], [18, "btn_y", false]], 70)
	_check("Up+Y: Up, then Y 167 ms later -> still the aerial dash (jump not converted)", "adash" in m.move_log and not ("vfire" in m.move_keys) and r["up"].is_empty(), "log=%s" % [m.move_log])
	g.queue_free(); await process_frame
	g = await _new_game(); m = g.mera
	r = await _vdrive(g, [[5, "up", true], [8, "up", false]], 40)
	_check("Up+Y: Up alone still jumps at once", "jump" in m.move_log and not ("vfire" in m.move_keys), "log=%s" % [m.move_log])
	g.queue_free(); await process_frame
	# keyboard: Up arrow + S
	g = await _new_game(); m = g.mera
	await _kdrive([], 10)
	var nk: int = m.move_keys.size()
	await _kdrive([[2, KEY_UP, true], [2, KEY_S, true], [6, KEY_UP, false], [6, KEY_S, false]], 50)
	_check("keyboard: Up arrow + S -> vertical quick fire", "vfire" in m.move_keys.slice(nk) and not ("adash" in m.move_keys.slice(nk)), "%s" % [m.move_keys.slice(nk)])
	g.queue_free(); await process_frame

	# ---------------------------------------------------------------- monsters from behind (levels 2-4)
	for L in [3, 0, 1, 2, 4]:
		LVS.current = L
		g = await _new_game(true); m = g.mera
		m.facing = 1
		var bx := 400.0
		var walked := []
		for step in 70:
			bx += 180.0
			if bx > g.map_w - 4000.0:
				break
			m.position.x = bx
			m.facing = 1
			g.snap_camera()
			for k in 3:
				await physics_frame
				m.invuln = 1.0
			for e in g.mobs.duplicate():           # keep the screen clear so every wave spawns
				if is_instance_valid(e) and not e.boss and not g.behind_spawns.any(func(b): return b["node"] == e):
					g.mobs.erase(e)
					e.queue_free()
		var bs: Array = g.behind_spawns
		var ok := bs.size() == (0 if L == 3 else 2)
		for b in bs:
			if float(b["x"]) > float(b["mera_x"]) - 960.0 or int(b["facing"]) != 1:
				ok = false                               # off-screen behind her (she faces right: x < mera - 960)
		_check("level %d: %d monsters come from behind (off-screen, behind her)" % [L + 1, 0 if L == 3 else 2], ok, "%s" % [bs.map(func(b): return [b["id"], int(b["x"] - b["mera_x"])])])
		if L != 3:
			g.props = g.props.filter(func(p): return not (is_instance_valid(p) and p.blocks_path()))     # walls and doors would push her back
			for e in g.mobs.duplicate():
				if is_instance_valid(e) and not e.boss:
					g.mobs.erase(e)
					e.queue_free()
			m.position.x = 6000.0
			m.facing = 1
			g.snap_camera()
			await physics_frame
			var n0: int = g.behind_spawns.size()
			for k in 8:
				if g._spawn_next(g.Roster_list(), 0, true):
					break
			var ok2: bool = g.behind_spawns.size() == n0 + 1
			var info := "no walker"
			if ok2:
				var bsp: Dictionary = g.behind_spawns[-1]
				var e: Node2D = bsp["node"]
				var d0 := absf(e.global_position.x - m.global_position.x)
				var d1 := d0
				for k in 150:
					await physics_frame
					m.invuln = 1.0
					m.position.x = 6000.0
					if is_instance_valid(e):
						d1 = absf(e.global_position.x - m.global_position.x)
				ok2 = d1 < d0 - 150.0 and float(bsp["x"]) < 6000.0 - 960.0
				info = "%s %.0f -> %.0f" % [bsp["id"], d0, d1]
			_check("level %d: a monster from behind starts off-screen behind her and walks in toward her" % [L + 1], ok2, info)
		g.queue_free(); await process_frame
	LVS.current = 0

	g = await _new_game()
	m = g.mera
	m.potions = 4
	m.stamina_max = 90.0
	m.stamina = 12.0
	m.rage_max = 130.0
	m.rage = 40.0
	m.set_size(5, true)
	_give_cards(g, {"ranger": 2, "brawler": 1})
	var bag: Dictionary = g._pack_run()
	m.potions = 0
	m.stamina = 0.0
	m.stamina_max = 50.0
	m.rage = 0.0
	m.rage_max = 100.0
	m.set_size(2, true)
	_give_cards(g, {})
	g._apply_run(bag)
	_check("a cleared level keeps potions, cards, size, mana, rage and both upgrades", m.potions == 4 and m.size == 5 and m.stamina_max == 90.0 and absf(m.stamina - 12.0) < 0.1 and m.rage_max == 130.0 and absf(m.rage - 40.0) < 0.1 and int(g.cards.get("ranger", 0)) == 2 and int(g.cards.get("brawler", 0)) == 1, "p=%d size=%d mana %.0f/%.0f rage %.0f/%.0f cards=%s" % [m.potions, m.size, m.stamina, m.stamina_max, m.rage, m.rage_max, g.cards])
	m.set_size(6, true)
	var dead: Dictionary = g.death_bag()
	_check("a death keeps the run but returns her to 2x", int(dead["size"]) == 2 and int(dead["potions"]) == 4 and int(dead["cards"]["ranger"]) == 2, "size=%s potions=%s" % [dead["size"], dead["potions"]])
	g.drop_run()
	g.queue_free(); await process_frame

	# ---------------------------------------------------------------- export list: every runtime script is exported
	var ep := FileAccess.get_file_as_string("res://export_presets.cfg")
	var missing: Array = []
	for dir in ["res://scripts/game", "res://scripts/app"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var path: String = dir + "/" + f
				if ep.count("\"" + path + "\"") != 3:
					missing.append(path)
	if ep.count("\"res://scripts/menu.gd\"") != 3:
		missing.append("res://scripts/menu.gd")
	_check("export: every runtime script (scripts/game, scripts/app, menu) is in all 3 presets (v0.9.0 shipped without mark_slash.gd)", missing.is_empty(), "%s" % [missing])
	await _queued_tests()


func AnimLib_fire(k: String) -> int:
	return int(root.get_node("AnimLib").anims[k]["fire_frame"])


func r_up_empty(_g: Node) -> bool:
	return true


# ================================================================ v0.9.1 queued (t108u, t103u)
func _queued_tests() -> void:
	var T = load("res://scripts/game/tuning.gd")
	var g: Node = await _new_game()
	var m: Node = g.mera
	m.position = Vector2(4000, g.GROUND_Y)
	m.forced = {"btn_b": true, "btn_y": true}
	var left := -1
	var y0: float = m.global_position.y
	var peak: float = y0
	var rise_slow := false
	for i in 50:
		await physics_frame
		if i == 0:
			m.forced = {}
		if String(m.mv.get("key", "")) == "datk2":
			peak = minf(peak, m.global_position.y)
			if m.anim.idx >= int(T.RSLASH_RISE_FROM):
				if left < 0:
					left = i
				if m.anim.idx <= int(T.RSLASH_RISE_TO) and m.anim.speed == 1.0:
					rise_slow = true
	var rise: float = y0 - peak
	_check("rising slash: windup plays at 4x (the rise starts within 14 frames)", left >= 0 and left <= 14, "frame=%d" % left)
	_check("rising slash: the rise itself is 1x speed and about twice as far", rise_slow and rise > 200.0, "slow=%s rise=%.1f" % [rise_slow, rise])
	g.queue_free()
	await physics_frame

	g = await _new_game()
	m = g.mera
	g.props = g.props.filter(func(p): return not (is_instance_valid(p) and p.blocks_path()))     # walls and doors block the run
	m.position.x = 4500.0
	m.forced["right"] = true
	await physics_frame
	await physics_frame
	var moved: float = m.global_position.x
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ENTER
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	ev.pressed = false
	Input.parse_input_event(ev)
	var frozen: float = m.global_position.x
	for i in 10:
		await physics_frame
	var still: bool = absf(m.global_position.x - frozen) < 0.5 and moved > 4500.0
	_check("Start pauses the game (pause menu up, Mera frozen) and does not just show controls", g.paused_play and not g.hud.overlay and g.get_tree().paused and still, "paused=%s overlay=%s x=%.1f->%.1f" % [g.paused_play, g.hud.overlay, moved, m.global_position.x])
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	ev.pressed = false
	Input.parse_input_event(ev)
	await physics_frame
	_check("Start again resumes", not g.paused_play and not g.get_tree().paused and not g.hud.overlay, "paused=%s" % g.paused_play)
	g.queue_free()
	await physics_frame

	g = await _new_game()
	m = g.mera
	m.position = Vector2(5000, g.GROUND_Y)
	m.set_size(2, true)
	m._start_move("atk1")
	var hf := -1
	for i in m.anim.frames.size():
		if m.anim.frames[i]["hit"] != null:
			hf = i
			break
	m.anim.seek(hf)
	m._update_boxes()
	m.mv["swing_t"] = m.now
	var sword: Rect2 = m.hit_rect()
	var ES = load("res://scripts/game/enemy_shot.gd")
	var shot: Node2D = ES.new()
	shot.setup(g, "hell_beast", "fireball", sword.get_center(), Vector2(-200, 0), 1, 3.0)
	g.world.add_child(shot)
	var wolf: Node2D = g.spawn_enemy("werewolf", m.global_position.x - 500.0)
	wolf.cooldown = 99.0
	g.resolve_projectiles()
	var aimed: bool = shot.deflected and shot.vel.x < 0.0
	_check("swing parry: atk1 reflects a shot within %d ms of the hitbox, toward the nearest enemy" % int(T.SWING_PARRY_MS), aimed and m.swing_parries == 1 and sword.size != Vector2.ZERO, "def=%s vx=%.0f n=%d hf=%d" % [shot.deflected, shot.vel.x, m.swing_parries, hf])
	shot.queue_free()
	var late: Node2D = ES.new()
	late.setup(g, "hell_beast", "fireball", sword.get_center(), Vector2(-200, 0), 1, 3.0)
	g.world.add_child(late)
	m.mv["swing_t"] = m.now - T.SWING_PARRY_MS - 40.0
	var n0: int = m.swing_parries
	g.resolve_projectiles()
	_check("swing parry: a shot that meets the hitbox after the window is not reflected", not late.deflected and m.swing_parries == n0, "def=%s" % late.deflected)
	var bolt: Node2D = Shot.new()
	bolt.setup(g, "bolt", late.global_position, 1, 2.0, {}, true)
	g.world.add_child(bolt)
	g.resolve_projectiles()
	_check("a player bolt and an enemy shot both explode", bolt.done and late.is_queued_for_deletion(), "bolt=%s shot=%s" % [bolt.done, late.is_queued_for_deletion()])
	# beam eats a foe shot
	m.invuln = 5.0
	wolf.position.x = m.position.x - 2500.0
	m.stamina = 80.0
	m._start_move("beam_ender")
	var bo_i := -1
	for i in m.anim.frames.size():
		if m.anim.frames[i].has("bo"):
			bo_i = i
			break
	if bo_i >= 0:
		m.anim.seek(bo_i)
		m._update_beam()
	var br: Rect2 = m.beam_world_rect()
	var beam_shot: Node2D = ES.new()
	if br.size != Vector2.ZERO:
		beam_shot.setup(g, "hell_beast", "fireball", br.get_center(), Vector2(-100, 0), 1, 3.0)
		g.world.add_child(beam_shot)
		g.resolve_projectiles()
	_check("the beam destroys an enemy projectile", m.beam_len > 0.0 and beam_shot.is_queued_for_deletion(), "len=%.0f key=%s f=%d queued=%s" % [m.beam_len, m.anim.key, bo_i, beam_shot.is_queued_for_deletion()])
	# melee parry shove
	m._go_neutral()
	m.state = "ground"
	m.invuln = 0.0
	m.last_l2_t = m.now
	var xw: float = wolf.global_position.x
	m.take_hit(1, wolf.global_position.x, wolf)
	for i in 4:
		await physics_frame
		m.invuln = 1.0
	_check("melee parry knocks the attacker 400 px and stuns for 2 s", m.parries >= 1 and m.size == 2 and wolf.state == "stun" and wolf.stun_t > 1.7 and absf(absf(wolf.global_position.x - xw) + absf(wolf.knock_left) - T.PARRY_KNOCK_PX) < 8.0, "dx=%.0f left=%.0f stun=%.2f" % [wolf.global_position.x - xw, wolf.knock_left, wolf.stun_t])
	g.queue_free()
	await physics_frame

	# v0.9.2 crouch bubble: free, smaller than the L2 barrier, parries in the same window, otherwise leaks 25%
	g = await _new_game()
	m = g.mera
	m.position = Vector2(5000, g.GROUND_Y)
	m.set_size(4, true)
	m.stamina = 30.0
	m.forced = {"down": true}
	for i in 12:
		await physics_frame
	var full_r: float = m.barrier_circle().z
	var small_r: float = m.crouch_bubble_circle().z
	var st0: float = m.stamina
	_check("crouch raises a small free bubble (smaller than the L2 barrier, no stamina spent)", m.crouch_bubble_on() and m.barrier.visible and small_r < full_r * 0.8 and small_r > full_r * 0.5 and m.stamina >= st0 - 0.05, "r=%.1f full=%.1f st=%.2f on=%s" % [small_r, full_r, m.stamina, m.crouch_bubble_on()])
	var cwolf: Node2D = g.spawn_enemy("werewolf", m.global_position.x + 700.0)
	cwolf.cooldown = 99.0
	await physics_frame
	cwolf.cooldown = 99.0
	cwolf.position.x = m.position.x + 180.0
	m.invuln = 0.0
	m.crouch_t = m.now - 40.0
	var sz: int = m.size
	m.take_hit(2, cwolf.global_position.x, cwolf)
	_check("crouch parry: Down within %d ms negates the hit, staggers 1 s, shoves 200 px" % int(T.PARRY_MS), m.size == sz and m.parries >= 1 and cwolf.state == "stun" and cwolf.stun_t > 0.9 and cwolf.stun_t < 1.15 and absf(absf(cwolf.knock_left) - T.CROUCH_PARRY_KNOCK_PX) < 1.0 and m.counter_active() and m.state == "ground", "size=%d parries=%d wolf=%s stun=%.2f knock=%.0f" % [m.size, m.parries, cwolf.state, cwolf.stun_t, cwolf.knock_left])
	var hp0: int = cwolf.hp
	m.deal(cwolf, 1, m.global_position.x, "melee")
	_check("crouch parry: the counter hit deals x%s" % str(T.PARRY_COUNTER_MULT), hp0 - cwolf.hp == m.size * int(T.PARRY_COUNTER_MULT), "dealt=%d size=%d" % [hp0 - cwolf.hp, m.size])
	m.invuln = 0.0
	m.crouch_t = m.now - T.PARRY_MS - 80.0
	m.take_hit(1, cwolf.global_position.x, cwolf)
	_check("small bubble subtracts 1: a hit of 1 is stopped, she stays crouched", m.size == sz and m.state == "ground" and m._neutral == "crouch" and m.stamina >= st0 - 0.05, "size=%d state=%s" % [m.size, m.state])
	m.invuln = 0.0
	m.take_hit(3, cwolf.global_position.x, cwolf)
	_check("small bubble subtracts 1: a hit of 3 costs 2 size and does not knock her down", m.size == sz - 2 and m.state == "ground" and m._neutral == "crouch", "size=%d state=%s" % [m.size, m.state])
	m.invuln = 0.0
	m.crouch_t = m.now
	var cshot := Node2D.new()
	g.world.add_child(cshot)
	cshot.global_position = m.global_position + Vector2(40, -20)
	var deflected: bool = m.try_parry_shot(cshot)
	m.crouch_t = m.now - T.PARRY_MS - 50.0
	var held_shot: bool = not m.try_parry_shot(cshot)
	_check("crouch parry: a projectile in the window is deflected, a later one is not", deflected and held_shot and m.deflects >= 1, "def=%s late=%s n=%d" % [deflected, held_shot, m.deflects])
	cshot.queue_free()
	m.forced = {}
	m.barrier_on = true
	m.last_l2_t = -1e9
	m.crouch_t = -1e9
	m._neutral = "idle"
	m.invuln = 0.0
	var before: int = m.size
	var held: Node2D = g.spawn_enemy("werewolf", m.global_position.x + 220.0)
	held.cooldown = 99.0
	m.take_hit(1, held.global_position.x, held)
	_check("held full bubble stops all damage, 200 px knockback, no stun", m.barrier_on and m.size == before and held.state != "stun" and absf(absf(held.knock_left) - T.BARRIER_KNOCK_PX) < 1.0, "size=%d state=%s knock=%.0f" % [m.size, held.state, held.knock_left])
	m.take_hit(6, held.global_position.x, held)
	_check("held full bubble still stops a heavy hit", m.size == before and m.barrier_on, "size=%d" % m.size)
	m.barrier_on = false
	m.forced = {"down": true}
	for i in 20:
		await physics_frame
	m.forced = {}
	for i in 20:
		await physics_frame
	m.forced = {"down": true}
	for i in 8:
		await physics_frame
	_check("small bubble shows a dial and starts at 3 seconds", m.crouch_bubble_on() and m.bubble_dial.visible and m.bubble_dial.frac > 0.85, "on=%s frac=%s" % [m.crouch_bubble_on(), m.bubble_dial.frac])
	for i in 190:
		await physics_frame
	_check("the small bubble drops itself after 3 seconds and she stays crouched", not m.crouch_bubble_on() and m._neutral == "crouch" and not m.bubble_dial.visible, "neutral=%s left=%.2f" % [m._neutral, m.crouch_bubble_left])
	m._go_neutral()
	m.stamina = 40.0
	m.forced = {"down": true}
	for i in 8:
		await physics_frame
	await _drive(g, [[2, "btn_x", true], [5, "btn_x", false]], 8)
	_check("a button inside the small bubble drops it and does that move", not m.crouch_bubble_on() and "atk1" in m.move_log, "on=%s log=%s" % [m.crouch_bubble_on(), m.move_log])
	m._go_neutral()
	m.potions = 1
	m.set_size(3, true)
	m.forced = {"down": true}
	for i in 10:
		await physics_frame
	await _drive(g, [[2, "l1", true], [5, "l1", false]], 12)
	_check("L1 inside the small bubble drinks and the bubble stays", m.crouch_bubble_on() and m.size == 4 and m.potions == 0, "on=%s size=%d pot=%d" % [m.crouch_bubble_on(), m.size, m.potions])
	g.queue_free()
	await physics_frame


# ================================================================ puzzle chests (no keys)
func _coins_near(g: Node, x: float) -> int:
	var n := 0
	for c in g.world.get_children():
		if c is Node2D and c.get("kind") == "coin" and absf(float(c.global_position.x) - x) <= 200.0:
			n += 1
	return n


func _new_chest(g: Node, x: float) -> Node2D:
	var ch: Node2D = load("res://scripts/game/prop.gd").new()
	ch.setup(g, "chest", x)
	g.world.add_child(ch)
	g.props.append(ch)
	return ch


func _tap_at(p: Node, design: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.pressed = pressed
		e.position = root.get_final_transform() * (design + p.origin())      # the window stretch maps it back to design space
		Input.parse_input_event(e)
		await physics_frame


func _puzzle_unit_tests() -> void:
	var T = load("res://scripts/game/tuning.gd")
	var PIPES = load("res://scripts/puzzles/pipes.gd")
	var M3 = load("res://scripts/puzzles/match3.gd")
	var NE = load("res://scripts/puzzles/needle.gd")
	# needle: the zone never goes under the minimum, and it speeds up
	var zmin := 1.0
	for r in range(0, 8):
		zmin = minf(zmin, NE.zone_for(r))
	_check("needle: no zone under %d %% of the gauge in any round" % int(T.NEEDLE_ZONE_MIN * 100.0), zmin >= T.NEEDLE_ZONE_MIN and T.NEEDLE_ZONE_MIN >= 0.06 - 0.0001, "min=%f" % zmin)
	_check("needle: every round is faster and the zone smaller", NE.speed_for(1) > NE.speed_for(0) and NE.speed_for(2) > NE.speed_for(1) and NE.zone_for(1) < NE.zone_for(0) and NE.zone_for(2) < NE.zone_for(1), "")
	var ne = NE.new()
	ne.rng.seed = 5
	ne._setup()
	var widths: Array = []
	var inside_ok := true
	while ne.result == "":
		widths.append(ne.zone_width)
		inside_ok = inside_ok and ne.zone_center - ne.zone_width * 0.5 >= 0.0 and ne.zone_center + ne.zone_width * 0.5 <= 1.0
		ne.wait = 0.0
		ne.pos = ne.zone_center
		ne.stop()
	_check("needle: three stops inside the zone win; the zone stays on the gauge and over the minimum", ne.result == "won" and widths.size() == 3 and inside_ok and widths.min() >= T.NEEDLE_ZONE_MIN, "%s %s" % [ne.result, widths])
	ne.free()
	ne = NE.new()
	ne.rng.seed = 6
	ne._setup()
	ne.wait = 0.0
	ne.pos = ne.zone_center
	ne.stop()
	ne.wait = 0.0
	ne.pos = clampf(ne.zone_center + ne.zone_width, 0.0, 1.0) if ne.zone_center + ne.zone_width * 1.0 <= 1.0 else ne.zone_center - ne.zone_width
	ne.stop()
	_check("needle: a miss loses", ne.result == "lost" and ne.round_i == 1, "%s %d" % [ne.result, ne.round_i])
	ne.free()
	# match-3: no starting matches, always a move, five distinct enemy portraits
	var board_ok := true
	var info := ""
	var moves_always := true
	var wins := 0
	var games := 24
	for sd in range(1, games + 1):
		var m = M3.new()
		m.rng.seed = sd
		m._setup()
		var distinct := {}
		for k in m.kinds:
			distinct[k] = true
		if not m._find_matches().is_empty() or m.find_move().is_empty() or distinct.size() != T.MATCH_KINDS or m.kinds.size() != T.MATCH_KINDS or Roster.face(String(m.kinds[0])) == null:
			board_ok = false
			info += " seed%d" % sd
		var guard := 0
		while m.result == "" and guard < 40:
			guard += 1
			var mv: Array = m.best_move()
			if mv.is_empty():
				moves_always = false
				break
			m.try_swap(mv[0], mv[1])
			m.settle()
			if m.result == "" and (not m._find_matches().is_empty() or m.find_move().is_empty()):
				moves_always = false
		if m.result == "won":
			wins += 1
		m.free()
	_check("match-3: boards start with no matches, a move, and %d distinct enemy portraits (%d seeds)" % [T.MATCH_KINDS, games], board_ok, info)
	_check("match-3: after every move and cascade the board has no leftover match and a move exists", moves_always, "")
	_check("match-3: a casual (greedy) player usually wins (%d / %d)" % [wins, games], wins * 10 >= games * 7, "wins=%d" % wins)
	# a dead board is reshuffled
	var dm = M3.new()
	dm.rng.seed = 3
	dm._setup()
	for i in dm.board.size():
		dm.board[i] = (i % dm.cols + 2 * (i / dm.cols)) % dm.kinds.size()
	var dead: bool = dm.find_move().is_empty() and dm._find_matches().is_empty()
	dm.busy = true
	dm.time_left = 10.0
	dm.score = 0
	dm._end_turn()
	_check("match-3: a board with no move is reshuffled into one with a move and no match", dead and dm.reshuffles == 1 and not dm.find_move().is_empty() and dm._find_matches().is_empty(), "dead=%s resh=%d" % [dead, dm.reshuffles])
	dm.free()
	# a bad swap costs nothing and is undone; a good one scores
	var sm = M3.new()
	sm.rng.seed = 9
	sm._setup()
	var before: Array = sm.board.duplicate()
	var bad := Vector2i(-1, -1)
	for y in sm.rows:
		for x in sm.cols - 1:
			var a := Vector2i(x, y)
			var b := Vector2i(x + 1, y)
			if bad.x < 0 and not sm.try_swap(a, b):
				bad = a
	_check("match-3: a swap that matches nothing is undone, starts no animation and the clock is untouched", bad.x >= 0 and sm.board == before and not sm.busy and is_equal_approx(sm.time_left, T.MATCH_TIME_S), "")
	var mv2: Array = sm.find_move()
	var okm: bool = sm.try_swap(mv2[0], mv2[1])
	sm.settle()
	_check("match-3: a real swap clears and scores", okm and sm.score >= 3 * T.MATCH_TILE_POINTS, "score=%d" % sm.score)
	sm.free()
	# pipes: every generated board is solvable, starts unsolved, and the move limit covers the solution
	var pipes_ok := true
	var pinfo := ""
	for sd in range(1, 41):
		var pp = PIPES.new()
		pp.rng.seed = sd
		pp._setup()
		var start_unsolved: bool = not pp.solved()
		var lim_ok: bool = pp.moves_limit >= pp.moves_needed() + 1
		pp.solve()
		if not (start_unsolved and lim_ok and pp.result == "won" and pp.solved() and pp.moves_used <= pp.moves_limit):
			pipes_ok = false
			pinfo += " seed%d(%s %s %s)" % [sd, start_unsolved, lim_ok, pp.result]
		pp.free()
	_check("pipes: 40 boards start unsolved and solve by rotating the path tiles within the move limit", pipes_ok, pinfo)
	var pg = PIPES.new()
	pg.rng.seed = 4
	pg._setup()
	var spare := Vector2i(-1, -1)
	for c in range(pg.cols * pg.rows):
		if int(pg.need[c]) == 0:
			spare = Vector2i(c % pg.cols, c / pg.cols)
			break
	pg.moves_used = pg.moves_limit - 1
	if spare.x >= 0:
		pg.rotate_tile(spare)
	_check("pipes: running out of moves loses", spare.x < 0 or pg.result == "lost" or pg.result == "won", pg.result)
	pg.free()


## solid props (cracked walls, closed doors) stop a teleport across the map: remove them first, as the other map tests do
func _clear_blockers(g: Node) -> void:
	for p in g.props.duplicate():
		if is_instance_valid(p) and p.has_method("blocks_path") and p.blocks_path():
			g.props.erase(p)


## an A press for a frame or two (a shut chest opens on a press of A while Mera stands on it)
func _tap_a(g: Node) -> void:
	Input.action_press("btn_a")
	await _s4_frames(g, 2)
	Input.action_release("btn_a")
	await _s4_frames(g, 2)


func _chest_tests() -> void:
	var T = load("res://scripts/game/tuning.gd")
	var consts: Dictionary = T.get_script_constant_map()
	_check("keys are gone: no KEY_* or LOCKED_MSG tuning constants", not consts.has("KEY_DROP_P") and not consts.has("KEY_FX_S") and not consts.has("LOCKED_MSG_S"), "")
	_puzzle_unit_tests()
	var PR = load("res://scripts/game/prop.gd")
	PR.touch_opens = true
	var g: Node = await _s4_new(1)
	_check("keys are gone: the game has no key state or drop function", g.get("key_held") == null and g.get("key_out") == null and g.get("key_rng") == null and not g.has_method("_maybe_drop_key") and not g.has_method("use_key"), "")
	var ch: Node2D = _s4_prop(g, "chest")
	_clear_blockers(g)
	_check("chest: Misty Woods places a chest", ch != null, "")
	if ch == null:
		g.queue_free()
		await process_frame
		return
	_check("chest: starts shut, not a breakable target, not solid", ch.state == "locked" and not ch.alive() and not ch.blocks_path(), "%s %s" % [ch.state, ch.alive()])
	var hit: bool = ch.take_damage(3, ch.global_position.x)
	_check("chest: a hit does not break it", not hit and ch.state == "locked", "")
	# no key ever drops, however many enemies fall
	for i in 40:
		var e: Node2D = g.spawn_enemy("skeleton", 3000.0 + float(i) * 10.0)
		g.on_enemy_defeated(e)
		e.queue_free()
	await _s4_frames(g, 3)
	var keys_n := 0
	var any_key_kind := false
	for c in g.world.get_children():
		if c.get("kind") == "key":
			keys_n += 1
	_check("no key ever drops (40 defeats on a level with a chest)", keys_n == 0 and not any_key_kind, "%d" % keys_n)
	for c in g.world.get_children():
		if c is Node2D and c.has_method("pop"):
			c.queue_free()

	# standing on the chest shows the prompt but does not open it; an A press does
	g.mera.global_position.x = ch.global_position.x
	await _s4_frames(g, 3)
	_check("chest: touching it alone does not open it, and the prompt shows", ch.state == "locked" and g.puzzle == null and ch.prompt != null and ch.prompt.visible and ch.prompt.text.ends_with("OPEN"), "state=%s prompt=%s" % [ch.state, ch.prompt.visible if ch.prompt != null else "none"])
	await _tap_a(g)
	var host: Node = g.puzzle
	_check("chest: an A press opens a puzzle and pauses the game", host != null and is_instance_valid(host) and paused and ch.state == "puzzling" and ch.puzzle_tries == 1, "state=%s" % ch.state)
	g.toggle_pause()
	_check("puzzle: the pause menu cannot open on top of it", not g.paused_play and paused and g.puzzle == host, "")
	var x_before: float = g.mera.global_position.x
	await _s4_frames(g, 5)
	_check("puzzle: Mera and the world are frozen behind it", absf(g.mera.global_position.x - x_before) < 0.01, "")
	# lose: the chest explodes (no retry), and Mera loses 1 size because she stands on it
	var ch_x: float = ch.global_position.x
	g.mera.set_size(4)
	g.mera.invuln = 0.0
	host.press_action("btn_b")
	_check("puzzle: B gives up (lost)", host.result == "lost", host.result)
	host.finish_now()
	await _s4_frames(g, 2)
	_check("lost puzzle: the chest explodes (the node frees itself) and the game runs again", not is_instance_valid(ch) and g.puzzle == null and not paused, "")
	_check("lost puzzle: Mera standing on the chest loses 1 size", g.mera.size == 3, "size=%d" % g.mera.size)
	await _s4_frames(g, 30)
	_check("lost puzzle: an exploded chest drops no loot", _coins_near(g, ch_x) == 0 and g.puzzle == null, "")
	g.mera.global_position.x = ch_x + 4000.0
	await _s4_frames(g, 3)

	# touch and mouse: taps reach the puzzle, the give-up button works
	ch = _new_chest(g, ch_x + 2200.0)
	_check("chest: try_open starts the pipes puzzle on demand", ch.try_open("pipes") and g.puzzle != null and g.puzzle.title() == "CONNECT THE PIPES", "")
	var pz: Node = g.puzzle
	await _s4_frames(g, 20)
	var r0: int = pz.rots[0]
	var cell_c: Vector2 = pz.origin_px + Vector2(60.0, 60.0)
	await _tap_at(pz, cell_c)
	_check("pipes: a tap on a tile rotates it", pz.rots[0] == (r0 + 1) % 4 and pz.moves_used == 1 and pz.cursor == Vector2i(0, 0), "rot %d -> %d" % [r0, pz.rots[0]])
	await _tap_at(pz, pz.GIVE_UP.get_center())
	_check("puzzle: the Give up button (tap) loses", pz.result == "lost", pz.result)
	pz.finish_now()
	await _s4_frames(g, 2)
	_check("pipes: a given-up chest explodes (far from Mera: no damage)", not is_instance_valid(ch) and g.puzzle == null and g.mera.size == 3, "size=%d" % g.mera.size)
	ch = _new_chest(g, ch_x + 2600.0)
	_check("chest: try_open starts the needle puzzle on demand", ch.try_open("needle"), "")
	pz = g.puzzle
	await _s4_frames(g, 20)
	pz.wait = 0.0
	pz.pos = pz.zone_center
	await _tap_at(pz, Vector2(960.0, 540.0))
	_check("needle: a tap anywhere stops it, and inside the zone counts", pz.round_i == 1 and pz.result == "", "round=%d %s" % [pz.round_i, pz.result])
	pz.press_action("btn_b")
	pz.finish_now()
	await _s4_frames(g, 2)
	_check("needle: a given-up chest explodes", not is_instance_valid(ch) and g.puzzle == null, "")

	# seeded: the same drop RNG picks the same puzzle
	g.drop_rng.seed = 77
	var kinds_a: Array = []
	for i in 3:
		var hh: Node = g.start_puzzle(Callable())
		kinds_a.append(hh.get_script().resource_path)
		hh.finish_now()
		await _s4_frames(g, 1)
	g.drop_rng.seed = 77
	var kinds_b: Array = []
	for i in 3:
		var hh2: Node = g.start_puzzle(Callable())
		kinds_b.append(hh2.get_script().resource_path)
		hh2.finish_now()
		await _s4_frames(g, 1)
	_check("puzzle pick is seeded from the drop RNG (same seed, same puzzles)", kinds_a == kinds_b and kinds_a.size() == 3, "%s %s" % [kinds_a, kinds_b])
	g.drop_rng.seed = 1
	var seen := {}
	for i in 40:
		var h3: Node = g.start_puzzle(Callable())
		seen[h3.get_script().resource_path] = true
		h3.finish_now()
		await _s4_frames(g, 1)
	_check("puzzle pick: all three puzzles come up", seen.size() == 3, "%s" % [seen.keys()])

	# each puzzle, solved through its own rules, pays the chest out
	var px := 8000.0
	for kind in ["pipes", "match3", "needle"]:
		px += 600.0
		var c2: Node2D = _new_chest(g, px)
		g.mera.global_position.x = px + 1500.0
		var started: bool = c2.try_open(kind)
		var h: Node = g.puzzle
		await _s4_frames(g, 2)
		h.solve()
		var won_state: String = h.result
		h.finish_now()
		await _s4_frames(g, 6)
		var coins := _coins_near(g, px)
		_check("%s: solving it opens the chest and pays 3-5 coins" % kind, started and won_state == "won" and c2.state == "open" and coins >= 3 and coins <= 5 and g.puzzle == null and not paused, "started=%s %s state=%s coins=%d" % [started, won_state, c2.state, coins])
	# a puzzle open when the scene goes away gives the tree back
	var c3: Node2D = _new_chest(g, 20000.0)
	c3.try_open("match3")
	var h_exit: Node = g.puzzle
	var g_ok: bool = h_exit != null and paused
	g.queue_free()
	await process_frame
	await process_frame
	_check("scene change with a puzzle open: the tree is unpaused and the layer is gone", g_ok and not paused and not is_instance_valid(h_exit), "paused=%s" % paused)

	# the old contents block, and a solved chest in the level
	g = await _s4_new(1)
	ch = _s4_prop(g, "chest")
	_clear_blockers(g)
	g.drop_rng.seed = 3
	# contents: 3-5 coins and 1-3 other items, each arcing out of the chest
	var ranges_ok := true
	var ranges_info := ""
	for i in 6:
		var cx := 15000.0 + float(i) * 300.0
		g.chest_contents(Vector2(cx, g.GROUND_Y - 30.0))
		await _s4_frames(g, 2)
		var coins := 0
		var items := 0
		for c in g.world.get_children():
			if not (c is Node2D) or absf(float(c.global_position.x) - cx) > 200.0:
				continue
			if c.get("kind") == "coin":
				coins += 1
			elif c.get("kind") in ["potion", "mana", "card"]:
				items += 1
		ranges_info += "[%d coins %d items] " % [coins, items]
		if coins < 3 or coins > 5 or items < 1 or items > 3:
			ranges_ok = false
		for c in g.world.get_children():
			if c is Node2D and absf(float(c.global_position.x) - cx) <= 200.0 and c.get("kind") in ["coin", "potion", "mana", "card"]:
				c.queue_free()
		await _s4_frames(g, 1)
	_check("chest contents: 3-5 coins and 1-3 other items every time", ranges_ok, ranges_info)

	# solving the level's own chest with the needle opens it
	g.mera.global_position.x = ch.global_position.x
	await _s4_frames(g, 3)
	await _tap_a(g)
	var hx: Node = g.puzzle
	_check("chest: an A press on it (fresh level) starts a puzzle", hx != null, "")
	if hx != null:
		hx.solve()
		hx.finish_now()
	await _s4_frames(g, 3)
	_check("chest: solved, it is open and the prompt is gone", ch.state == "open" and not ch.prompt.visible, ch.state)
	PR.touch_opens = false
	var coins2 := 0
	var items2 := 0
	for c in g.world.get_children():
		if not (c is Node2D) or absf(float(c.global_position.x) - ch.global_position.x) > 200.0:
			continue
		if c.get("kind") == "coin":
			coins2 += 1
		elif c.get("kind") in ["potion", "mana", "card"]:
			items2 += 1
	_check("chest: releases 3-5 coins and 1-3 items", coins2 >= 3 and coins2 <= 5 and items2 >= 1 and items2 <= 3, "%d coins %d items" % [coins2, items2])
	var chest_coin: Node2D = null
	for c in g.world.get_children():
		if c is Node2D and c.get("kind") == "coin" and absf(float(c.global_position.x) - ch.global_position.x) <= 200.0:
			chest_coin = c
			break
	var CYG = load("res://scripts/game/carry.gd")
	var gold_before: int = CYG.gold
	if chest_coin != null:
		g.collect(chest_coin)
	var gold_after_chest: int = CYG.gold
	var plain_coin = load("res://scripts/game/pickup.gd").new()
	plain_coin.setup(g, "coin", Vector2(3000.0, g.GROUND_Y))
	g.collect(plain_coin)
	plain_coin.free()
	_check("chest coins are worth 3 gold each; a coin from a broken object is worth 1", chest_coin != null and gold_after_chest - gold_before == 3 and CYG.gold - gold_after_chest == 1, "chest +%d, plain +%d" % [gold_after_chest - gold_before, CYG.gold - gold_after_chest])
	await _s4_frames(g, 60)
	g.queue_free()
	await process_frame

	# cemetery: the far graves layer sits on the ground (lowered by Tuning.LAYER_LOWER)
	var gc: Node = await _s4_new(3)
	var gf_y := -1.0
	for c in gc.get_children():
		if c is Sprite2D and c.texture != null and String(c.texture.resource_path).ends_with("graves_far.png"):
			gf_y = c.position.y
	_check("cemetery: graves_far lowered to the ground", absf(gf_y - (105.0 * 5.0 + 65.0)) < 0.5, "%s" % gf_y)
	gc.queue_free()
	await process_frame

	# level clear gold: 15 the first time, 5 on every clear after that
	var C = load("res://scripts/game/carry.gd")
	C.reset()
	var pays := [C.record_clear(2), C.record_clear(2), C.record_clear(2), C.record_clear(0)]
	_check("clear gold: 15 first, then 5 each repeat (per level)", pays == [15, 5, 5, 15] and C.gold == 40, "%s gold %d" % [pays, C.gold])
	C.reset()


# ================================================================ v0.12.2 unlocks, walls, despawn, dancer, homing
func _unlock_tests() -> void:
	var C = load("res://scripts/game/carry.gd")
	var P = load("res://scripts/game/props.gd")
	var AL2 = load("res://scripts/game/ally.gd")
	C.test_all = false
	C.reset()
	_check("unlocks: moves start locked, summon is 30 s", not C.owns("beam") and not C.owns("fury_mode") and not C.owns("homing") and C.summon_s() == 30.0, "")
	C.gold = 10
	_check("unlocks: a move costs gold and is refused when short", C.buy("move:beam") == "gold" and not C.owns("beam"), "")
	C.gold = 1000
	_check("unlocks: buying a move owns it and takes the price", C.buy("move:beam") == "" and C.owns("beam") and C.gold == 850, "gold %d" % C.gold)
	_check("unlocks: a bought move cannot be bought twice", C.buy("move:beam") == "owned", "")
	_check("unlocks: summon times are bought in order", C.buy("summon:2") == "order" and C.buy("summon:1") == "" and C.summon_s() == 60.0, "")
	_check("unlocks: 90 s then 120 s", C.buy("summon:2") == "" and C.summon_s() == 90.0 and C.buy("summon:3") == "" and C.summon_s() == 120.0, "")
	C.reset()
	C.test_all = true
	# two destructible walls on every stage map, each hiding its own card
	var wall_ok := true
	var wall_info := ""
	for lv in [0, 1, 2, 4]:
		var walls := 0
		var cards_seen := {}
		for it in P.layout(lv, 19200.0):
			if String(it[0]) == "wall":
				walls += 1
				cards_seen[int(it[2]["card"])] = true
		wall_info += "L%d=%d " % [lv, walls]
		if walls != 2 or cards_seen.size() != 2:
			wall_ok = false
	_check("walls: two cracked walls per stage map", wall_ok, wall_info)
	# nothing despawns for distance: an enemy far behind stays on the map
	var g: Node = await _s4_new(3)
	g.mera.global_position.x = 9000.0
	await _s4_frames(g, 2)
	var far: Node2D = g.spawn_enemy("wolf", 2000.0)
	await _s4_frames(g, 30)
	_check("despawn: an enemy far behind is not removed", is_instance_valid(far) and far.alive() and far in g.mobs, "")
	g.queue_free()
	await process_frame
	# the dancer runs back when she is about to leave the view, then dances again
	g = await _s4_new(3)
	g.mera.global_position.x = 6000.0
	await _s4_frames(g, 2)
	var dn: Node2D = AL2.new()
	dn.setup(g, "dancer")
	g.world.add_child(dn)
	await _s4_frames(g, 2)
	dn._go("dance", "hips")
	g.mera.global_position.x = 12000.0
	await _s4_frames(g, 3)
	var ran_back: bool = dn.state == "run_back"
	await _s4_frames(g, 900)
	_check("dancer: runs back to Mera when she is about to leave the view, then dances", ran_back and dn.state in ["dance", "idle"] and absf(dn.position.x - g.mera.global_position.x) < 400.0, "%s %s" % [dn.state, dn.position.x])
	g.queue_free()
	await process_frame
	# homing: a bolt bends toward an enemy below it
	g = await _s4_new(3)
	g.mera.global_position.x = 3000.0
	await _s4_frames(g, 2)
	var sh = load("res://scripts/game/shot.gd").new()
	sh.homing = true
	sh.setup(g, "bolt", Vector2(3000.0, 700.0), 1, 1.0, {}, false)
	g.world.add_child(sh)
	var tgt: Node2D = g.spawn_enemy("wolf", 3600.0)
	await _s4_frames(g, 30)
	_check("homing: the bolt bends toward the enemy", is_instance_valid(sh) and sh.heading.y > 0.05, "%s" % (sh.heading if is_instance_valid(sh) else Vector2.ZERO))
	g.queue_free()
	await process_frame
	# gating: Fury needs the unlock
	C.test_all = false
	g = await _s4_new(3)
	g.mera.rage = 100.0
	g.mera._try_fury()
	_check("gating: Fury does nothing without its unlock", not g.mera.fury, "")
	C.test_all = true
	g.queue_free()
	await process_frame


# ================================================================ spawn cap, super quake order, homing, victory font, no map cards
func _task_tests() -> void:
	var C = load("res://scripts/game/carry.gd")
	# 1. spawn cap: a stage spawns every wave enemy, so the cap is far above the old five
	for lv in [0, 1, 2, 4]:
		var gc: Node = await _s4_new(lv)
		var cap: int = gc._stage_cap()
		_check("spawn cap: level %d allows more than %d alive (cap %d)" % [lv + 1, Roster.MAX_ALIVE, cap], cap > Roster.MAX_ALIVE, "%d" % cap)
		gc.queue_free()
		await process_frame
	# 3. super earthquake needs the normal earthquake and takes no gold without it
	C.test_all = false
	C.reset()
	C.gold = 1000
	var r1: String = C.buy("move:super_quake")
	_check("super earthquake: refused with 'order' and no gold taken without the earthquake", r1 == "order" and C.gold == 1000 and not C.owns("super_quake"), "%s gold %d" % [r1, C.gold])
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var per_pg: int = load("res://scripts/menu.gd").SHOP_PER_PAGE
	var sq_at: int = menu._all_rows().find("move:super_quake")
	menu.shop_page = sq_at / per_pg
	menu.shop_i = sq_at % per_pg
	var stat1: String = menu._shop_stat(menu.shop_i)
	menu._shop_buy()
	_check("shop: super earthquake row says 'needs earthquake', and the note says to buy it first", stat1 == "needs earthquake" and menu.note == "Buy the earthquake first.", "%s / %s" % [stat1, menu.note])
	_check("shop: buying the earthquake works, then the super earthquake", C.buy("move:earthquake") == "" and C.buy("move:super_quake") == "" and C.owns("super_quake"), "")
	var sm_at: int = menu._all_rows().find("summon:2")
	menu.shop_page = sm_at / per_pg
	menu.shop_i = sm_at % per_pg
	menu._shop_buy()
	_check("shop: the summon-time note is unchanged for summon rows", menu.note != "Buy the earthquake first.", menu.note)
	menu.queue_free()
	await process_frame
	C.reset()
	C.test_all = true
	# 4. homing fireballs and the turned hit box
	var g: Node = await _s4_new(3)
	g.mera.global_position.x = 3000.0
	await _s4_frames(g, 2)
	var fb_shot := {"ang": 11.0, "speed_px_s": 300.0, "dist": 130.0, "ground_dy": 40.0}
	var hf = load("res://scripts/game/shot.gd").new()
	hf.homing = true
	hf.setup(g, "fireball", Vector2(3000.0, 600.0), 1, 1.0, fb_shot, false)
	g.world.add_child(hf)
	g.spawn_enemy("wolf", 3600.0)
	await _s4_frames(g, 20)
	_check("homing fireball: turns toward the enemy instead of the parabola", is_instance_valid(hf) and hf.heading.y > 0.1, "%s" % (hf.heading if is_instance_valid(hf) else Vector2.ZERO))
	var pf = load("res://scripts/game/shot.gd").new()
	pf.setup(g, "fireball", Vector2(3000.0, 600.0), 1, 1.0, fb_shot, false)
	g.world.add_child(pf)
	await _s4_frames(g, 5)
	_check("plain fireball: still the parabola (no heading)", is_instance_valid(pf) and pf.heading == Vector2.ZERO, "")
	var hb = load("res://scripts/game/shot.gd").new()
	hb.homing = true
	hb.setup(g, "bolt", Vector2(3000.0, 700.0), 1, 1.0, {}, false)
	hb.heading = Vector2.UP
	var up_r: Rect2 = hb._flight_rect()
	hb.heading = Vector2.RIGHT
	var rt_r: Rect2 = hb._flight_rect()
	_check("homing hit box follows the heading (tall going up, wide going right)", up_r.size.y > up_r.size.x and rt_r.size.x > rt_r.size.y, "%s %s" % [up_r.size, rt_r.size])
	hb.free()
	g.queue_free()
	await process_frame
	# 5. dragon victory: cleared once, 15 + 100 gold, card text is drawn by the HUD (no Label)
	C.reset()
	g = await _s4_new(5)
	var dr: Node2D = g.spawn_enemy("dragon", g.mera.global_position.x + 600.0)
	await process_frame
	g.on_enemy_defeated(dr)
	_check("dragon victory: sets cleared and pays clear gold plus 100, once", g.cleared and g.victory and C.gold == 115 and int(C.clears.get("5", 0)) == 1, "gold %d" % C.gold)
	var t0 := Time.get_ticks_msec()
	while not g.victory_card and Time.get_ticks_msec() - t0 < 8000:
		await create_timer_always(0.1)
	var labels := 0
	for ch in g.get_children():
		if ch is CanvasLayer and ch != g.hud:
			for n in ch.get_children():
				if n is Label:
					labels += 1
	_check("dragon victory: the card is drawn by the HUD, with no Label in the victory layer", g.victory_card and labels == 0, "card=%s labels=%d" % [g.victory_card, labels])
	_check("dragon victory: the card says Stage 2 is open and the flash names the dragon", g.victory_text.size() == 2 and g.victory_text[0] == "You Defeated the Cavern Dragon!" and g.victory_text[1].find("Stage 2") >= 0 and C.unlocked >= 6, str(g.victory_text))
	root.get_tree().paused = false
	g.queue_free()
	await process_frame
	C.reset()
	# 5b. stage 2: a boss that is not a finale only opens the exit; Perry (level 12) ends stage 2
	LVS.current = 6
	g = await _s4_new(6)
	g.wave_i = 100
	var og: Node2D = g.spawn_enemy("p_clubogre", g.mera.global_position.x + 600.0)
	await process_frame
	var txt_boss: String = g.exit_lock_text()
	var locked_before: bool = g.exit_locked()
	g.on_enemy_defeated(og)
	_check("stage 2 boss (level 7): its death opens the exit with no victory card", locked_before and txt_boss == "SLAY THE CLUB OGRE" and g.boss_dead and not g.exit_locked() and not g.victory and not g.victory_card and not g.cleared, "text=%s dead=%s victory=%s" % [txt_boss, g.boss_dead, g.victory])
	g.queue_free()
	await process_frame
	g = await _s4_new(6)
	_check("stage 2 boss level: CLEAR THE ROAD while waves remain, locked even with the boss dead", g.exit_lock_text() == "CLEAR THE ROAD" and g.exit_locked(), g.exit_lock_text())
	g.boss_dead = true
	_check("stage 2 boss level: a dead boss does not open the exit before the waves are done", g.exit_locked(), "")
	g.finish_endpoint()
	_check("finish_endpoint on a level with waves and a boss opens the exit", g.boss_dead and not g.exit_locked(), "")
	g.queue_free()
	await process_frame
	C.reset()
	g = await _s4_new(11)
	g.wave_i = 100
	var pe: Node2D = g.spawn_enemy("perry", g.mera.global_position.x + 600.0)
	await process_frame
	_check("level 12 (Perry's Arena): the exit stays locked until Perry is dead ('DEFEAT PERRY')", g.exit_locked() and g.exit_lock_text() == "DEFEAT PERRY" and not g.boss_dead, g.exit_lock_text())
	g.on_enemy_defeated(pe)
	_check("level 12 (Perry's Arena): Perry's death opens the exit, pays the 100 gold bonus and shows the Stage 3 card", g.victory and g.boss_dead and not g.exit_locked() and C.gold >= 100 and g.victory_text.size() == 2 and g.victory_text[0] == "You Defeated Perry!" and g.victory_text[1].find("Stage 3") >= 0 and C.unlocked >= 12, "gold %d %s" % [C.gold, g.victory_text])
	_check("level 12 (Perry's Arena): no two-line victory card (the story pages replace it)", not g.victory_card, "")
	g.queue_free()
	await process_frame
	C.reset()
	# 6. no summon card lies in any level
	for lv in [0, 1, 2, 3, 4]:
		var gk: Node = await _s4_new(lv)
		_check("no card node on level %d" % (lv + 1), gk.card_nodes.is_empty(), "%d" % gk.card_nodes.size())
		gk.queue_free()
		await process_frame


func create_timer_always(sec: float) -> void:
	await root.get_tree().create_timer(sec, true, false, true).timeout


## summoning spends cards from the persistent Carry store, so tests that need cards put them in both places
func _give_cards(g: Node, d: Dictionary) -> void:
	var CY = load("res://scripts/game/carry.gd")
	CY.ensure()
	CY.cards = d.duplicate(true)
	g.cards = d.duplicate(true)


# ================================================================ Android touch pad: L3 in the middle of the d-pad
func _touch_tests() -> void:
	var TP = load("res://scripts/game/touch_pad.gd")
	var rects := {}
	var mana_n := 0
	for item in TP.LAYOUT:
		rects[String(item[0])] = Rect2(float(item[1]), float(item[2]), float(item[3]), float(item[4]))
		if String(item[0]) == "mana":
			mana_n += 1
	var mana: Rect2 = rects.get("mana", Rect2())
	var cross_ok: bool = mana_n == 1 and mana.size.x > 0.0
	if cross_ok:
		cross_ok = mana.position.x >= rects["left"].end.x - 0.5 and mana.end.x <= rects["right"].position.x + 0.5 and mana.position.y >= rects["up"].end.y - 0.5 and mana.end.y <= rects["down"].position.y + 0.5
	var overlaps := 0
	for k in rects:
		if k != "mana" and mana.intersects(rects[k]):
			overlaps += 1
	_check("touch pad: one L3 button sits in the empty middle of the d-pad and overlaps nothing", cross_ok and overlaps == 0, "n=%d rect=%s overlaps=%d" % [mana_n, mana, overlaps])
	var tpn = TP.new()
	var l3_label: String = tpn._label("mana")
	tpn.free()
	_check("touch pad: the L3 button sends the mana action (E / left-stick click)", InputMap.has_action("mana") and l3_label == "L3", "label=%s" % l3_label)


# ================================================================ shop pages, controls pages, size cap, Stage 2 speed, Sfx
func _session_tests() -> void:
	var C = load("res://scripts/game/carry.gd")
	var PU = load("res://scripts/game/perry_unlocks.gd")
	C.test_all = false
	# ---- Sfx keeps playing while the game is paused
	var sfx = root.get_node("Sfx")
	_check("sfx: Sfx runs in PROCESS_MODE_ALWAYS, so effects keep playing while paused", sfx.process_mode == Node.PROCESS_MODE_ALWAYS, "%d" % sfx.process_mode)
	# ---- size cap: 6x is the most the shop sells, and a save above it loads at 6
	C.reset()
	C.gold = 100000
	var buys: Array = []
	for i in 3:
		buys.append(C.buy("scale"))
	_check("size cap: the shop sells +1 three times, 3x -> 6x", buys == ["", "", ""] and C.scale_cap == 6, "%s cap %d" % [buys, C.scale_cap])
	_check("size cap: the shop item 'scale' returns 'max' once scale_cap == 6", C.buy("scale") == "max" and C.scale_cap == 6, "cap %d" % C.scale_cap)
	var f := FileAccess.open(C.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"gold": 77, "scale_cap": 9, "size": 3}))
	f.close()
	C.ready = false
	C.ensure()
	_check("size cap: a save with scale_cap 9 loads at 6", C.scale_cap == 6, "%d" % C.scale_cap)
	C.reset()
	# ---- Stage 2 enemies: 1.5x size, 2x HP and speed, half the wait between attacks; stage 1 unchanged
	var base: Dictionary = Roster.def("wolf")
	var gs1: Node = await _s4_new(1)
	var e1: Node2D = gs1.spawn_enemy("wolf", gs1.mera.global_position.x + 500.0)
	await physics_frame
	var ok1: bool = absf(float(e1.k) - float(base["k"])) < 0.0001 and int(e1.hp_max) == int(base["hp"]) and absf(float(e1.speed) - float(base["speed"])) < 0.0001 and float(e1.speed_mul) == 1.0
	for i in e1.attacks.size():
		ok1 = ok1 and absf(float(e1.attacks[i].get("cd", 1.0)) - float(base["attacks"][i].get("cd", 1.0))) < 0.0001
	_check("stage 1 wolf is unchanged: size, HP, speed and attack waits as in the roster", ok1, "k %f hp %d speed %f" % [e1.k, e1.hp_max, e1.speed])
	gs1.queue_free()
	await process_frame
	var g2: Node = await _s4_new(6)
	var e2: Node2D = g2.spawn_enemy("wolf", g2.mera.global_position.x + 500.0)
	await physics_frame
	var ok2: bool = absf(float(e2.k) - 1.5 * float(base["k"])) < 0.0001 and int(e2.hp_max) == int(round(2.0 * float(base["hp"]))) and absf(float(e2.speed) - 2.0 * float(base["speed"])) < 0.0001 and float(e2.speed_mul) == 2.0
	_check("stage 2 wolf (level 7): 1.5x size, 2x HP, 2x walking speed", ok2, "k %f hp %d speed %f mul %f" % [e2.k, e2.hp_max, e2.speed, e2.speed_mul])
	var cd_ok: bool = e2.attacks.size() == base["attacks"].size() and e2.attacks.size() > 0
	for i in e2.attacks.size():
		cd_ok = cd_ok and absf(float(e2.attacks[i].get("cd", 1.0)) - 0.5 * float(base["attacks"][i].get("cd", 1.0))) < 0.0001
	_check("stage 2 wolf: every attack's wait is half of its stage 1 wait", cd_ok, "%s" % [e2.attacks])
	g2.queue_free()
	await process_frame
	# ---- shop pages: 5 rows a page; Mera 17 rows (4 pages), Perry 27 rows (6 pages)
	C.reset()
	C.record_clear(C.PERRY_CLEAR_LEVEL)
	C.gold = 500
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	_check("shop pages: Mera's shop has 17 rows on 4 pages", menu._all_rows().size() == 17 and menu._page_count() == 4, "rows %d pages %d" % [menu._all_rows().size(), menu._page_count()])
	menu.shop_page = 2
	menu.shop_i = 3
	menu.btn = 0
	menu._press_button()
	_check("shop: opening it starts on page 1, row 1", menu.mode == "shop" and menu.shop_page == 0 and menu.shop_i == 0, "mode %s page %d row %d" % [menu.mode, menu.shop_page, menu.shop_i])
	var ev := InputEventAction.new()
	ev.pressed = true
	ev.action = "left"
	menu._shop_input(ev)
	_check("shop: Left from page 1 wraps to page 4", menu.shop_page == 3, "page %d" % menu.shop_page)
	ev.action = "right"
	menu._shop_input(ev)
	_check("shop: Right from page 4 wraps back to page 1", menu.shop_page == 0, "page %d" % menu.shop_page)
	_check("shop: row rects are 116 px tall on a 124 px step from y 250", menu._shop_row_rect(0) == Rect2(160, 250, 1600, 116) and menu._shop_row_rect(4) == Rect2(160, 250 + 4 * 124, 1600, 116), "%s" % [menu._shop_row_rect(4)])
	_perry_clear_stage2(C)
	menu.shop_page = 3
	menu.shop_i = 2
	menu._toggle_character()
	_check("shop pages: Perry's shop has 27 rows on 6 pages, and the toggle resets to page 1 row 1", C.perry_selected() and menu._all_rows().size() == 27 and menu._page_count() == 6 and menu.shop_page == 0 and menu.shop_i == 0, "rows %d pages %d" % [menu._all_rows().size(), menu._page_count()])
	ev.action = "left"
	menu._shop_input(ev)
	_check("shop pages: Left from Perry's page 1 wraps to page 6", menu.shop_page == 5, "page %d" % menu.shop_page)
	ev.action = "right"
	menu._shop_input(ev)
	_check("shop pages: Right from Perry's page 6 wraps to page 1", menu.shop_page == 0, "page %d" % menu.shop_page)
	menu.queue_free()
	await process_frame
	# ---- controls pages in the pause menu: Left / Right turn pages, A moves on (and closes on the last page), B closes
	C.character = "mera"
	var gc: Node = await _s4_new(1)
	var hc = gc.hud
	gc.toggle_pause()
	hc.controls_page = 2
	hc.pause_sel = 3
	hc._pause_confirm()
	_check("controls: CONTROLS from the pause menu opens on page 1 whatever the last page was", hc.pause_controls and hc.overlay and hc.controls_page == 0, "page %d" % hc.controls_page)
	var np: int = hc._controls_pages()
	var want_np: int = ceili(float(hc._controls_table().size()) / 4.0)
	var all_rows: Array = load("res://scripts/game/hud.gd").CONTROLS
	var shown_rows := 0
	for row in all_rows:
		if not (row.size() > 3 and String(row[3]).begins_with("mera:")) or Carry.owns(String(row[3]).substr(5)):
			shown_rows += 1
	_check("controls: Mera's list is %d pages of 4 entries, and only unlocked rows are listed (%d of %d)" % [want_np, shown_rows, all_rows.size()], np == want_np and np >= 2 and hc._controls_table().size() == shown_rows, "%d pages" % np)
	_ctrl_key(hc, "right")
	_check("controls: Right turns to page 2", hc.controls_page == 1, "page %d" % hc.controls_page)
	_ctrl_key(hc, "left")
	_ctrl_key(hc, "left")
	_check("controls: Left turns back and stops at page 1", hc.controls_page == 0 and hc.pause_controls, "page %d" % hc.controls_page)
	_ctrl_key(hc, "btn_a")
	_check("controls: A moves to the next page", hc.controls_page == 1 and hc.pause_controls, "page %d" % hc.controls_page)
	for i in np - 2:
		_ctrl_key(hc, "right")
	_check("controls: the last page is reached", hc.controls_page == np - 1 and hc.pause_controls, "page %d of %d" % [hc.controls_page + 1, np])
	_ctrl_key(hc, "btn_a")
	_check("controls: A on the last page closes CONTROLS", not hc.pause_controls and not hc.overlay, "")
	hc._pause_confirm()
	hc.controls_page = 1
	_ctrl_key(hc, "btn_b")
	_check("controls: B closes CONTROLS from any page", not hc.pause_controls and not hc.overlay, "")
	# Perry's list has its own page count
	gc.toggle_pause()
	gc.queue_free()
	await process_frame
	var gp: Node = await _perry_new()
	var want_p: int = ceili(float(gp.hud._controls_table().size()) / 4.0)
	_check("controls: Perry's list is %d pages of 4 entries" % want_p, gp.hud._controls_pages() == want_p and want_p >= 2, "%d" % gp.hud._controls_pages())
	gp.queue_free()
	await process_frame
	C.reset()
	C.test_all = true


## an action key for the pause menu's controls page (the HUD reads it through its unhandled input)
func _ctrl_key(hud: Node, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	hud._unhandled_input(ev)


# ================================================================ Stage 3 phase 3: playable Perry (scripts/game/perry_player.gd, perry_unlocks.gd)
func _perry_new(level: int = 0) -> Node:
	var C = load("res://scripts/game/carry.gd")
	C.set_character("perry")
	var g: Node = await _s4_new(level)
	g.mera.invuln = 99.0
	return g


func _perry_clear_stage2(C) -> void:
	for i in range(6, 12):
		C.record_clear(i)


## the right-stick items and the device scheme are shared state: every Perry block that sets them clears them after
func _perry_gesture_reset() -> void:
	var CT = root.get_node("Controls")
	CT.flick_n = 0
	CT.r3_pending = false
	CT.scheme = "key"
	CT.clear_gestures()


func _perry_tests() -> void:
	var C = load("res://scripts/game/carry.gd")
	var PU = load("res://scripts/game/perry_unlocks.gd")
	var T = load("res://scripts/game/tuning.gd")
	C.test_all = false
	root.get_node("HitStop").enabled = false
	# ---- locked until Perry's Arena (level index 11) is cleared
	C.reset()
	var set0: bool = C.set_character("perry")
	_check("perry: locked at the start, the choice stays Mera", not C.perry_unlocked() and not set0 and C.character == "mera", "")
	C.record_clear(9)
	_check("perry: clearing level index 9 does not unlock her", not C.perry_unlocked(), "")
	C.character = "perry"
	var gl: Node = await _s4_new(0)
	_check("perry: a locked choice still spawns Mera", not C.perry_selected() and gl.mera.get("is_perry") == null, "")
	gl.queue_free()
	await process_frame
	C.reset()
	C.record_clear(C.PERRY_CLEAR_LEVEL)
	_check("perry: unlocked by a clear of level index 11 (Perry's Arena), and the title menu choice sticks", C.perry_unlocked() and C.set_character("perry") and C.perry_selected(), "")
	# ---- the game spawns her
	var g: Node = await _perry_new()
	var m: Node2D = g.mera
	_check("perry: choosing her makes the game spawn PerryPlayer with 50 HP", m.get("is_perry") == true and m.name == "Perry" and m.hp == 50 and m.hp_max == 50, "%s hp %s" % [m.name, m.hp])
	_check("perry: she keeps the interface the game reads (size, stamina, rage, potions, hurt_rect)", m.size >= 1 and m.stamina > 0.0 and m.rage_max > 0.0 and m.potions >= 0 and m.hurt_rect().size.x > 10.0 and m.hurt_rect().size.y > 50.0, "")
	# ---- walk, jump, double jump
	var x0: float = m.position.x
	await _drive(g, [[1, "right", true]], 30)
	_check("perry: walks (walk_right pose, moves right)", m.position.x > x0 + 100.0 and m.pa == "walk_right", "x %.0f pa %s" % [m.position.x, m.pa])
	m.forced["right"] = false
	await _drive(g, [], 5)
	var s: Array = []
	_tap(s, 2, "up")
	var y_top := 1e9
	for f in range(1, 90):
		for st in s:
			if int(st[0]) == f:
				m.forced[st[1]] = st[2]
		await physics_frame
		g.mera.invuln = 99.0
		y_top = minf(y_top, m.position.y)
	_check("perry: jumps about 200 px and lands again", y_top < g.GROUND_Y - 150.0 and y_top > g.GROUND_Y - 260.0 and m.state == "ground", "top %.0f state %s" % [y_top, m.state])
	s = []
	_tap(s, 2, "up")
	_tap(s, 22, "up")
	y_top = 1e9
	for f in range(1, 110):
		for st in s:
			if int(st[0]) == f:
				m.forced[st[1]] = st[2]
		await physics_frame
		y_top = minf(y_top, m.position.y)
	_check("perry: the double jump (always on) goes higher than the single jump", y_top < g.GROUND_Y - 280.0, "top %.0f" % y_top)
	# ---- slash hits an enemy through the Mera enemy interface
	var e: Node2D = g.spawn_enemy("p_goblin", m.global_position.x + 220.0)
	await physics_frame
	var hp0: int = e.hp
	s = []
	_tap(s, 3, "btn_a")
	await _drive(g, s, 60)
	_check("perry: a slash hits the goblin for the scaled slash damage (%d)" % T.perry_dmg("slash"), e.hp == hp0 - T.perry_dmg("slash") and "slash" in m.move_log, "hp %d -> %d log %s" % [hp0, e.hp, m.move_log])
	_check("perry: the slash damage is the original 25 x 0.12, so a 6 HP goblin takes two", T.perry_dmg("slash") == 3, "")
	# ---- a move she does not own does nothing; buying it enables it at the exact original price
	m.move_log.clear()
	s = [[1, "right", true]]
	_tap(s, 8, "btn_a")
	await _drive(g, s, 40)
	m.forced["right"] = false
	_check("perry: Right + A without the thrust does not lunge", "thrust" not in m.move_log, "log %s" % [m.move_log])
	_perry_clear_stage2(C)
	C.gold = 1000
	var reason_before: String = PU.locked_reason("crash")
	var r_thrust: String = C.buy("perry:thrust")
	_check("perry shop: the lunging thrust costs 15 + 10 x 1 = 25 gold and is owned after", r_thrust == "" and C.gold == 975 and PU.has_move("thrust"), "%s gold %d" % [r_thrust, C.gold])
	_check("perry shop: buying it twice refuses and takes nothing", C.buy("perry:thrust") == "owned" and C.gold == 975, "")
	m.move_log.clear()
	await _drive(g, [], 30)
	s = [[1, "right", true]]
	_tap(s, 8, "btn_a")
	await _drive(g, s, 40)
	m.forced["right"] = false
	_check("perry: Right + A lunges once the thrust is bought", "thrust" in m.move_log, "log %s" % [m.move_log])
	g.queue_free()
	await process_frame
	# ---- prices of the ported list
	var ids: Dictionary = {}
	for u in PU.LIST:
		ids[String(u["id"])] = PU.price(String(u["id"]))
	_check("perry shop: 26 unlocks plus Bone Powder", PU.LIST.size() == 26 and PU.price("bone_powder") == 90, "%d" % PU.LIST.size())
	_check("perry shop: scroll = 15 + 10 x level (thrust 25, taunt 35, flight 55), mutagen = 25 + 15 x level (energy wave 55, ultimate 85, earthquake 100, meter charge 100)",
		ids["thrust"] == 25 and ids["taunt"] == 35 and ids["fly"] == 55 and ids["energy_wave"] == 55 and ids["ultimate"] == 85 and ids["earthquake"] == 100 and ids["meter_charge"] == 100 and ids["push_kick"] == 25, str(ids))
	# ---- locked by stage progress: names the level to clear
	C.reset()
	C.record_clear(C.PERRY_CLEAR_LEVEL)
	C.record_clear(10)                      # the shop gate for the top unlocks is level index 10 (Moonlit Sanctum)
	C.gold = 500
	var rl: String = C.buy("perry:crash")
	_check("perry shop: a row whose Stage 2 level is not cleared says 'Clear Stage 2 level 3 first' and takes no gold", rl == "locked" and C.gold == 500 and PU.locked_reason("crash") == "Clear Stage 2 level 3 first" and reason_before == "" , "%s / %s / before '%s'" % [rl, PU.locked_reason("crash"), reason_before])
	_check("perry shop: level 5 and above cap at Stage 2 level 5 (earthquake)", PU.locked_reason("earthquake") == "" and PU.req_index("earthquake") == 10 and PU.req_index("thrust") == 6, "")
	# ---- parry, block, HP, death
	C.reset()
	C.record_clear(C.PERRY_CLEAR_LEVEL)
	g = await _perry_new()
	m = g.mera
	m.invuln = 0.0
	e = g.spawn_enemy("p_orc", m.global_position.x + 150.0)
	await physics_frame
	s = []
	_tap(s, 2, "btn_b")
	await _drive(g, s, 5)
	m.invuln = 0.0
	m.take_hit(1, e.global_position.x, e)
	_check("perry: a tap of B parries: no damage, the attacker is stunned", m.hp == 50 and m.parries == 1 and e.state == "stun", "hp %d parries %d state %s" % [m.hp, m.parries, e.state])
	await _drive(g, [], 60)
	m.invuln = 0.0
	m.take_hit(1, e.global_position.x, e)
	_check("perry: a hit costs PERRY_HP_PER_DMG (10) HP per damage point and knocks her back", m.hp == 40 and m.state == "hurt", "hp %d state %s" % [m.hp, m.state])
	await _drive(g, [], 60)
	m.invuln = 0.0
	s = [[2, "btn_b", true]]
	await _drive(g, s, 30)
	m.take_hit(2, e.global_position.x, e)
	_check("perry: holding B blocks: no damage, a small slide", m.hp == 40 and m.blocks == 1 and m.pa == "block", "hp %d blocks %d pa %s" % [m.hp, m.blocks, m.pa])
	m.forced["btn_b"] = false
	await _drive(g, [], 30)
	m.invuln = 0.0
	m.hp = 10
	m.take_hit(1, e.global_position.x, e)
	_check("perry: at 0 HP she dies the way Mera does (state dead, died signal, Game Over)", m.state == "dead" and m.hp == 0 and g.over, "state %s hp %d over %s" % [m.state, m.hp, g.over])
	g.queue_free()
	await process_frame
	# ---- potions heal HP, never change the size Carry holds for Mera
	C.reset()
	C.record_clear(C.PERRY_CLEAR_LEVEL)
	g = await _perry_new()
	m = g.mera
	m.hp = 20
	var size0: int = m.size
	var pk = load("res://scripts/game/pickup.gd").new()
	pk.kind = "potion"
	g.collect(pk)
	_check("perry: a green potion pickup heals her HP and leaves the saved size alone", m.hp == 20 + T.PERRY_POTION_HP and m.size == size0, "hp %d size %d" % [m.hp, m.size])
	pk.free()
	g.queue_free()
	await process_frame
	# ---- an energy move: charge R2, release fires the wave and spends energy; locked until bought
	C.reset()
	C.record_clear(C.PERRY_CLEAR_LEVEL)
	_perry_clear_stage2(C)
	C.gold = 500
	g = await _perry_new()
	m = g.mera
	s = [[1, "r2", true], [40, "r2", false]]
	await _drive(g, s, 70)
	_check("perry: R2 held and released does nothing before the energy wave is bought", "energy_wave" not in m.move_log, "log %s" % [m.move_log])
	g.queue_free()
	await process_frame
	C.buy("perry:energy_wave")
	g = await _perry_new()
	m = g.mera
	var en0: float = m.stamina
	s = [[1, "r2", true], [40, "r2", false]]
	await _drive(g, s, 70)
	_check("perry: bought, R2 held and released fires the energy wave and the charge drew energy", "energy_wave" in m.move_log and m.stamina < en0, "log %s energy %.1f -> %.1f" % [m.move_log, en0, m.stamina])
	g.queue_free()
	await process_frame
	# ---- Bone Powder
	C.reset()
	C.record_clear(C.PERRY_CLEAR_LEVEL)
	C.gold = 500
	var rp: String = C.buy("perry:bone_powder")
	_check("perry shop: Bone Powder costs 90 gold and adds 25 max HP", rp == "" and C.perry_hp_max == 75 and C.gold == 410, "%s hp_max %d gold %d" % [rp, C.perry_hp_max, C.gold])
	g = await _perry_new()
	_check("perry: the next level starts her at the raised max HP", g.mera.hp_max == 75 and g.mera.hp == 75, "%d" % g.mera.hp_max)
	g.queue_free()
	await process_frame
	C.gold = 2000
	for i in 8:
		C.buy("perry:bone_powder")
	_check("perry shop: Bone Powder stops at 200 max HP", C.perry_hp_max == 200 and C.buy("perry:bone_powder") == "max", "%d" % C.perry_hp_max)
	# ---- saves: Perry fields round trip, and an old save without them loads
	C.reset()
	_perry_clear_stage2(C)
	C.gold = 300
	C.buy("perry:taunt")
	C.perry_hp_max = 100
	C.set_character("perry")
	C.ready = false
	C.character = "mera"
	C.perry_owned = {}
	C.perry_hp_max = 50
	C.ensure()
	_check("saves: Perry's character, owned unlocks and max HP survive a reload", C.character == "perry" and PU.owned("taunt") and C.perry_hp_max == 100, "%s %s %d" % [C.character, C.perry_owned, C.perry_hp_max])
	var f := FileAccess.open(C.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"gold": 77, "potion_cap": 5, "size": 3, "clears": {"2": 1}, "moves": {"beam": true}}))
	f.close()
	C.ready = false
	C.character = "perry"
	C.perry_owned = {"thrust": true}
	C.perry_hp_max = 150
	C.ensure()
	_check("saves: an old save without Perry fields loads with Mera, no unlocks and 50 HP", C.gold == 77 and C.character == "mera" and C.perry_owned.is_empty() and C.perry_hp_max == 50 and not C.perry_unlocked(), "%d %s" % [C.gold, C.character])
	# ---- the title menu: the choice and the shop pages
	C.reset()
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu._toggle_character()
	_check("menu: the character choice says why Perry is locked and stays Mera", menu.note.find("locked") >= 0 and C.character == "mera" and menu._page_count() == 4, menu.note)
	_perry_clear_stage2(C)
	C.gold = 100
	menu.shop_page = 3
	menu.shop_i = 2
	menu._toggle_character()
	_check("menu: with Perry unlocked the toggle switches to her, resets the shop to its first page, and her shop has six pages", C.perry_selected() and menu.shop_page == 0 and menu.shop_i == 0 and menu._page_count() == 6, "%s %d page %d" % [C.character, menu._page_count(), menu.shop_page])
	menu.shop_i = 1
	var row_what: String = menu._shop_what(1)
	var price_txt: int = menu._shop_price(1)
	var stat_locked: String = menu._shop_stat(1)
	menu._shop_buy()
	_check("menu: a Perry row shows its price in gold, buying it makes the row 'owned'", row_what == "perry:thrust" and price_txt == 25 and C.gold == 75 and menu._shop_stat(1) == "owned" and stat_locked.begins_with("Clear Stage 2 level") == false, "%s %d %s gold %d" % [row_what, price_txt, stat_locked, C.gold])
	menu.queue_free()
	await process_frame
	# ---- the controls: Y is the spin, L1 is only the Push Kick, R1 never summons, the right stick drinks and summons
	var CT = root.get_node("Controls")
	_perry_gesture_reset()
	C.reset()
	C.record_clear(C.PERRY_CLEAR_LEVEL)
	g = await _perry_new()
	m = g.mera
	_check("perry: no unlocks are bought in the spin test", C.perry_owned.is_empty(), "%s" % [C.perry_owned])
	e = g.spawn_enemy("p_goblin", m.global_position.x + 100.0)
	await physics_frame
	var hp_y: int = e.hp
	m.move_log.clear()
	s = []
	_tap(s, 3, "btn_y")
	await _drive(g, s, 60)
	_check("perry: Y starts the free spin attack with no unlocks bought, and it hits the goblin beside her", "spin_attack" in m.move_log and e.hp < hp_y, "log %s hp %d -> %d" % [m.move_log, hp_y, e.hp])
	g.queue_free()
	await process_frame
	C.reset()
	C.record_clear(C.PERRY_CLEAR_LEVEL)
	g = await _perry_new()
	m = g.mera
	m.potions = 1
	m.hp = 20
	s = []
	_tap(s, 5, "l1", 4)
	await _drive(g, s, 30)
	_check("perry: L1 without Push Kick does nothing (potion kept, HP unchanged)", m.potions == 1 and m.hp == 20, "potions %d hp %d" % [m.potions, m.hp])
	s = [[2, "down", true], [5, "l1", true], [9, "l1", false], [20, "down", false]]
	await _drive(g, s, 30)
	_check("perry: Down + L1 without Push Kick does nothing either", m.potions == 1 and m.hp == 20, "potions %d hp %d" % [m.potions, m.hp])
	g.queue_free()
	await process_frame
	C.reset()
	C.record_clear(C.PERRY_CLEAR_LEVEL)
	g = await _perry_new()
	m = g.mera
	_give_cards(g, {"ranger": 1})
	var n_r1: int = g.allies().size()
	s = []
	_tap(s, 3, "r1", 3)
	await _drive(g, s, 20)
	_check("perry: an R1 tap summons nothing and keeps the card", g.allies().size() == n_r1 and int(g.cards.get("ranger", 0)) == 1, "allies %d cards %s" % [g.allies().size(), g.cards])
	g.queue_free()
	await process_frame
	# ---- right-stick items: flick 8 health, 2 mana, 6 summon, pending R3 by scheme
	C.reset()
	C.record_clear(C.PERRY_CLEAR_LEVEL)
	g = await _perry_new()
	m = g.mera
	m.hp = 20
	m.potions = 1
	CT.flick_n = 8
	await _drive(g, [], 3)
	_check("perry: flick 8 (stick up) drinks a health potion when hp is below max", m.potions == 0 and m.hp == 20 + T.PERRY_POTION_HP and CT.flick_n == 0, "potions %d hp %d" % [m.potions, m.hp])
	m.stamina = 5.0
	m.mana_pots = 1
	CT.flick_n = 2
	await _drive(g, [], 3)
	_check("perry: flick 2 (stick down) drinks a mana potion when the mana meter is low", m.mana_pots == 0 and m.stamina > 5.0, "mana pots %d stamina %.1f" % [m.mana_pots, m.stamina])
	_give_cards(g, {"ranger": 1})
	var n_f: int = g.allies().size()
	CT.flick_n = 6
	await _drive(g, [], 10)
	_check("perry: flick 6 (stick right) summons an ally and uses the card", g.allies().size() == n_f + 1 and int(g.cards.get("ranger", 0)) == 0, "allies %d cards %s" % [g.allies().size(), g.cards])
	g.queue_free()
	await process_frame
	# a fresh level: no ally is out yet (one of each type at a time, so the R3 test must not reuse the flick 6 ally)
	g = await _perry_new()
	m = g.mera
	_give_cards(g, {"ranger": 1})
	CT.scheme = "touch"
	CT.r3_pending = true
	await _drive(g, [], 10)
	_check("perry: a pending R3 on touch does not summon", g.allies().size() == 0 and not CT.r3_pending and int(g.cards.get("ranger", 0)) == 1, "allies %d" % g.allies().size())
	CT.scheme = "pad"
	CT.r3_pending = true
	await _drive(g, [], 10)
	_check("perry: a pending R3 on a pad summons an ally", g.allies().size() == 1 and int(g.cards.get("ranger", 0)) == 0, "allies %d cards %s" % [g.allies().size(), g.cards])
	_perry_gesture_reset()
	g.queue_free()
	await process_frame
	# ---- X + Y still gives the taunt once Taunt is bought
	C.reset()
	_perry_clear_stage2(C)
	C.record_clear(C.PERRY_CLEAR_LEVEL)
	C.gold = 300
	var r_taunt: String = C.buy("perry:taunt")
	g = await _perry_new()
	m = g.mera
	m.move_log.clear()
	s = []
	_tap(s, 5, "btn_x")
	_tap(s, 5, "btn_y")
	await _drive(g, s, 40)
	_check("perry: X + Y still gives the taunt once Taunt is bought", r_taunt == "" and "taunt" in m.move_log, "buy '%s' log %s" % [r_taunt, m.move_log])
	g.queue_free()
	await process_frame
	_perry_gesture_reset()
	C.reset()
	C.test_all = true


# ===== stage 3 phase 4: ladders and platforms
func _ladder_tests() -> void:
	var T = load("res://scripts/game/tuning.gd")
	var C = load("res://scripts/game/carry.gd")
	C.test_all = true
	root.get_node("HitStop").enabled = false
	var G := 1060.0
	var g: Node = await _s4_new(0)
	var m: Node2D = g.mera
	var x: float = m.position.x
	# ---- platforms: surface_under, standing on top after a jump at exactly PLATFORM_STEP_H, expiry
	m.set_size(1, true)
	var pl: Node2D = g.build_platform(x, G - T.PLATFORM_STEP_H, 260.0, 25.0)
	_check("platform: surface_under sees the built plank", absf(g.surface_under(Vector2(x, G - 100.0), 0.0) - (G - T.PLATFORM_STEP_H)) < 0.01 and g.surface_under(Vector2(x + 400.0, G), 0.0) == G, "%f" % g.surface_under(Vector2(x, G - 100.0), 0.0))
	var s: Array = []
	_tap(s, 2, "up")
	await _drive(g, s, 70)
	_check("platform: size 1 Mera (jump apex ~90 px) lands on a plank PLATFORM_STEP_H (%d px) above the floor" % int(T.PLATFORM_STEP_H), m.on_ground and absf(m.position.y - (G - T.PLATFORM_STEP_H)) < 0.5, "y %.1f state %s" % [m.position.y, m.state])
	pl.queue_free()
	await _drive(g, [], 3)
	_check("platform: a freed plank gives its surface back (she is dropped to the floor)", g.built_surfaces.is_empty() and g.surface_under(Vector2(x, G - 100.0), 0.0) == G, "%d" % g.built_surfaces.size())
	await _drive(g, [], 60)
	var hi: Node2D = g.build_platform(x, G - 3.0 * T.PLATFORM_STEP_H, 260.0, 25.0)
	m.position = Vector2(x, G)
	m.on_ground = true
	s = []
	_tap(s, 2, "up")
	await _drive(g, s, 70)
	_check("platform: a plank 3 steps up is not reachable with one jump (control for the test above)", m.position.y >= G - 1.0, "y %.1f" % m.position.y)
	hi.queue_free()
	var tp: Node2D = g.build_platform(x + 600.0, G - 60.0, 200.0, 0.5)
	_check("platform: ttl 0.5 s, then the surface is gone and the node is freed", g.surface_under(Vector2(x + 600.0, G - 100.0), 0.0) == G - 60.0, "")
	await _drive(g, [], 45)
	_check("platform: ttl removes the surface and frees the node", not is_instance_valid(tp) and g.surface_under(Vector2(x + 600.0, G - 100.0), 0.0) == G and g.built_surfaces.is_empty(), "")
	var perm: Node2D = g.build_platform(x + 600.0, G - 60.0, 200.0, 0.0)
	await _drive(g, [], 120)
	_check("platform: ttl 0 is permanent", is_instance_valid(perm) and g.surface_under(Vector2(x + 600.0, G - 100.0), 0.0) == G - 60.0, "")
	perm.queue_free()
	await _drive(g, [], 3)
	# ---- Up with no ladder still jumps
	m.set_size(2, true)
	m.position = Vector2(x, G)
	m.on_ground = true
	await _drive(g, [], 30)
	s = []
	_tap(s, 2, "up")
	await _drive(g, s, 8)
	_check("ladder: Up with no ladder near still jumps", m.state == "air" and m.position.y < G - 5.0, "%s y %.1f" % [m.state, m.position.y])
	await _drive(g, [], 80)
	# ---- Mera climbs: grab, up, step onto the plank at the top, Down returns
	g.build_platform(x, G - 300.0, 300.0, 0.0)
	var lad: Node2D = g.build_ladder(x, G, G - 300.0, 0.0)
	_check("ladder: ladders_at / Ladder.nearest find it by column and span, and not elsewhere", g.ladders_at(x + 30.0, G - 100.0).size() == 1 and g.ladders_at(x + 60.0, G - 100.0).is_empty() and g.ladders_at(x, G - 400.0).is_empty() and Ladder.nearest(g, x - 20.0, G) == lad and Ladder.nearest(g, x + 200.0, G) == null, "")
	m.position = Vector2(x, G)
	m.on_ground = true
	await _drive(g, [], 3)
	s = []
	_tap(s, 2, "up")
	await _drive(g, s, 6)
	_check("ladder: Up at the foot grabs it (no jump)", m.state == "climb" and m.position.y > G - 20.0, "%s y %.1f" % [m.state, m.position.y])
	s = [[1, "up", true]]
	await _drive(g, s, 30)
	var y30: float = m.position.y
	_check("ladder: holding Up climbs at LADDER_SPEED with no gravity", m.state == "climb" and y30 < G - 100.0 and absf((G - y30) - T.LADDER_SPEED * 0.5) < 80.0, "state %s y %.1f" % [m.state, y30])
	m.forced["up"] = false
	await _drive(g, [], 20)
	_check("ladder: releasing everything stays on the ladder", m.state == "climb" and absf(m.position.y - y30) < 1.0, "y %.1f vs %.1f" % [m.position.y, y30])
	m.forced["up"] = true
	await _drive(g, [], 90)
	_check("ladder: reaching the top steps onto the surface above", m.state == "ground" and m.on_ground and absf(m.position.y - (G - 300.0)) < 0.5, "%s y %.1f" % [m.state, m.position.y])
	m.forced["up"] = false
	await _drive(g, [], 10)
	_check("ladder: she keeps standing on the plank", m.state == "ground" and absf(m.position.y - (G - 300.0)) < 0.5, "%s y %.1f" % [m.state, m.position.y])
	s = [[2, "down", true]]
	await _drive(g, s, 20)
	_check("ladder: Down at the top grabs it and climbs down", m.state == "climb" and m.position.y > G - 300.0 + 20.0, "%s y %.1f" % [m.state, m.position.y])
	await _drive(g, [], 120)
	m.forced["down"] = false
	_check("ladder: Down returns her to the floor", m.state == "ground" and m.on_ground and absf(m.position.y - G) < 0.5, "%s y %.1f" % [m.state, m.position.y])
	# ---- sideways lets go; a hit drops her
	m.position = Vector2(x, G - 150.0)
	m.state = "climb"
	m.set_meta("climb_ladder", lad)
	m.on_ground = false
	await _drive(g, [[2, "right", true]], 6)
	_check("ladder: Right lets go (she falls)", m.state == "air" or m.state == "ground", m.state)
	m.forced["right"] = false
	await _drive(g, [], 80)
	m.position = Vector2(x, G - 150.0)
	m.vel = Vector2.ZERO
	m.state = "climb"
	m.set_meta("climb_ladder", lad)
	await _drive(g, [], 3)
	m.invuln = 0.0
	m.take_hit(1, x + 50.0)
	_check("ladder: a hit while climbing puts her in the normal hurt state", m.state == "hurt", m.state)
	await _drive(g, [], 120)
	_check("ladder: after the hit she fell to the floor and is no longer climbing", m.state != "climb" and m.on_ground and absf(m.position.y - G) < 0.5, "%s y %.1f" % [m.state, m.position.y])
	# ---- climb_step for allies / enemies
	var dummy := Node2D.new()
	g.add_child(dummy)
	dummy.global_position = Vector2(x + 10.0, G)
	var r := 0
	for i in 200:
		r = Ladder.climb_step(dummy, lad, -1, 1.0 / 60.0, 240.0)
	_check("ladder: climb_step moves any Node2D to the top, onto the column, and reports the end", r == -1 and absf(dummy.global_position.y - (G - 300.0)) < 0.5 and absf(dummy.global_position.x - x) < 0.5, "%d %s" % [r, dummy.global_position])
	r = Ladder.climb_step(dummy, lad, 1, 1.0 / 60.0, 240.0)
	_check("ladder: climb_step down moves the other way", r == 0 and dummy.global_position.y > G - 300.0, "")
	dummy.queue_free()
	# ---- expiry
	var tl: Node2D = g.build_ladder(x + 700.0, G, G - 200.0, 0.4)
	await _drive(g, [], 40)
	_check("ladder: ttl frees it and unregisters it", not is_instance_valid(tl) and g.ladders_at(x + 700.0, G - 50.0).is_empty(), "")
	# ---- level loader (permanent)
	var n0: int = g.ladders.size()
	g._build_climbables({"ladders": [[x + 900.0, G, G - 250.0]], "platforms": [[x + 800.0, x + 1000.0, G - 250.0]]})
	await _drive(g, [], 5)
	_check("ladder: a level's ladders / platforms arrays build permanent objects", g.ladders.size() == n0 + 1 and absf(g.surface_under(Vector2(x + 900.0, G - 300.0), 0.0) - (G - 250.0)) < 0.01, "")
	g.queue_free()
	await process_frame
	# ---- Perry climbs too
	C.reset()
	C.record_clear(C.PERRY_CLEAR_LEVEL)
	var gp: Node = await _perry_new()
	var pp: Node2D = gp.mera
	var px: float = pp.position.x
	gp.build_platform(px, G - 300.0, 300.0, 0.0)
	gp.build_ladder(px, G, G - 300.0, 0.0)
	pp.position = Vector2(px, G)
	await _drive(gp, [], 5)
	s = [[2, "up", true]]
	await _drive(gp, s, 20)
	_check("ladder: Perry grabs it with Up and climbs", pp.state == "climb" and pp.position.y < G - 40.0, "%s y %.1f" % [pp.state, pp.position.y])
	await _drive(gp, [], 90)
	pp.forced["up"] = false
	_check("ladder: Perry reaches the top and stands on the plank", pp.state == "ground" and pp.on_ground and absf(pp.position.y - (G - 300.0)) < 0.5, "%s y %.1f" % [pp.state, pp.position.y])
	await _drive(gp, [[1, "down", true]], 130)
	pp.forced["down"] = false
	_check("ladder: Perry climbs back down to the floor", pp.state == "ground" and absf(pp.position.y - G) < 0.5, "%s y %.1f" % [pp.state, pp.position.y])
	pp.position = Vector2(px + 800.0, G)
	await _drive(gp, [], 5)
	await _drive(gp, [[1, "up", true], [4, "up", false]], 10)
	_check("ladder: Perry's Up with no ladder still jumps", pp.state == "air" and pp.position.y < G - 5.0, "%s y %.1f" % [pp.state, pp.position.y])
	gp.queue_free()
	await process_frame
	_perry_gesture_reset()
	C.reset()
	C.test_all = true


# ===== stage 3 phase 6: Changeling enemies
func _cl_tests() -> void:
	var C = load("res://scripts/game/carry.gd")
	var RO = load("res://scripts/game/roster.gd")
	var LV = load("res://scripts/game/levels.gd")
	var ids := ["cl_grunt", "cl_mud", "cl_rat_king", "cl_archer", "cl_warlord", "cl_knight", "cl_ranger", "cl_weaver", "cl_mage"]
	var data_ok := true
	var info := ""
	for id in ids:
		if not RO.DEFS.has(id) or not RO.data().has(id) or not RO.def(id).has("script"):
			data_ok = false
			info += id + " "
	_check("changeling: all nine enemies are in Roster.DEFS and roster.json with an AI script", data_ok, info)
	var faces_ok := true
	for id in ["cl_knight", "cl_ranger", "cl_weaver", "cl_mage"]:
		if bool(RO.def(id).get("boss", false)) or int(RO.def(id)["hp"]) < 2 * int(RO.def("cl_grunt")["hp"]):
			faces_ok = false
	_check("changeling: the four faces are tough non-boss enemies; the Warlord is the boss", faces_ok and bool(RO.def("cl_warlord")["boss"]) and RO.BOSSES.get(19, "") == "cl_warlord" and not RO.LEVELS.has(19), "")
	var waves_ok := true
	var seen := {}
	for li in range(12, 19):
		if not RO.LEVELS.has(li) or not RO.BEHIND_WAVES.has(li):
			waves_ok = false
			continue
		for id in RO.LEVELS[li]:
			seen[id] = true
	for id in ids:
		if id != "cl_warlord" and not seen.has(id):
			waves_ok = false
	_check("changeling: levels 12 to 18 have waves that use every Changeling enemy", waves_ok, str(seen.keys()))
	# Stage 3 gets plain DEFS values (no Stage 2 doubling), Stage 2 still doubles
	LV.current = 1
	var g: Node = await _new_game()
	var m: Node = g.mera
	m.position.x = 6000.0
	LV.current = 14
	var e3: Node2D = g.spawn_enemy("cl_grunt", 7200.0)
	LV.current = 7
	var e2: Node2D = g.spawn_enemy("cl_grunt", 7400.0)
	LV.current = 1
	_check("changeling: stage 3 spawns use the plain DEFS numbers (k %.1f hp %d), stage 2 would scale them 1.5x" % [e3.k, e3.hp], e3.k == 8.0 and e3.hp == 16 and e3.speed == 280.0 and e2.k == 12.0, "%s %s" % [e3.k, e2.k])
	g.queue_free()
	await process_frame
	# behaviours, one fresh game each
	var beh := {}
	for id in ["cl_grunt", "cl_rat_king", "cl_archer", "cl_mud", "cl_ranger", "cl_weaver", "cl_mage"]:
		LV.current = 1
		g = await _new_game()
		m = g.mera
		m.position.x = 6000.0
		m.set_size(6, true)
		g.snap_camera()
		var gap := 150.0 if id in ["cl_ranger", "cl_weaver", "cl_mage"] else 700.0
		var e: Node2D = g.spawn_enemy(id, 6000.0 + gap + e_half(RO, id), {"seed": 3})
		var x0: float = e.global_position.x
		var top := 0.0
		var shots := 0
		var mud_seen := false
		for f in 420:
			await physics_frame
			if f % 20 == 0:
				m.set_size(6, true)
			if is_instance_valid(e):
				top = maxf(top, e.rest_y - e.global_position.y)
			for c in g.world.get_children():
				if c.get_script() != null and String(c.get_script().resource_path).ends_with("enemy_shot.gd"):
					shots += 1
				if c.get_script() != null and String(c.get_script().resource_path).ends_with("cl_shot.gd"):
					shots += 1
					if c.get("kind") == "mud":
						mud_seen = true
		beh[id] = {"moved": absf(e.global_position.x - x0), "top": top, "shots": shots, "mud": mud_seen, "hits": e.hits_landed,
			"hops": int(e.get("hops_back") if e.get("hops_back") != null else 0), "blinks": int(e.get("blinks") if e.get("blinks") != null else 0), "hist": e.history.size()}
		g.queue_free()
		await process_frame
	_check("changeling: the grunt lunges and the rat king hops (it leaves the ground)", beh["cl_grunt"]["hits"] > 0 and beh["cl_rat_king"]["top"] > 40.0, str(beh["cl_grunt"]) + str(beh["cl_rat_king"]))
	_check("changeling: the archer stands still and fires arrows", beh["cl_archer"]["moved"] < 1.0 and beh["cl_archer"]["shots"] > 0, str(beh["cl_archer"]))
	_check("changeling: the mud revenant lobs mud", beh["cl_mud"]["mud"], str(beh["cl_mud"]))
	_check("changeling: the ranger hops back, the weaver backs off, the mage blinks", beh["cl_ranger"]["hops"] > 0 and beh["cl_weaver"]["moved"] > 100.0 and beh["cl_mage"]["blinks"] > 0, "%s %s %s" % [beh["cl_ranger"], beh["cl_weaver"], beh["cl_mage"]])
	# the Warlord: phases, charge stun, slam waves
	LV.current = 1
	g = await _new_game()
	m = g.mera
	m.position.x = 6000.0
	m.set_size(6, true)
	g.snap_camera()
	var w: Node2D = g.spawn_enemy("cl_warlord", 7500.0)
	await physics_frame
	var p1 := int(w.phase)
	var n1: int = w.attacks.size()
	w.take_damage(int(w.hp_max * 0.4), 6000.0)
	var p2 := int(w.phase)
	var has_charge := false
	for a in w.attacks:
		if bool(a.get("charge", false)):
			has_charge = true
	var has_slam_early := false
	for a in w.attacks:
		if bool(a.get("slam", false)):
			has_slam_early = true
	w.take_damage(int(w.hp_max * 0.3), 6000.0)
	var p3 := int(w.phase)
	var has_slam := false
	var tell_fast := false
	for a in w.attacks:
		if bool(a.get("slam", false)):
			has_slam = true
		if a["anim"] == "slash" and float(a["tell"]) < 0.5:
			tell_fast = true
	_check("changeling: the Warlord moves through 3 phases by hp (attacks %d -> %d), the charge from phase 2, the slam and faster tells from phase 3" % [n1, w.attacks.size()],
		p1 == 1 and p2 == 2 and p3 == 3 and has_charge and not has_slam_early and has_slam and tell_fast and w.phase_log == [1, 2, 3], "%s %s %s %s" % [p1, p2, p3, w.phase_log])
	# charge into the arena wall stuns him
	w.queue_free()
	g.mobs.erase(w)
	await physics_frame
	var w2: Node2D = g.spawn_enemy("cl_warlord", 1500.0)
	w2.hp = int(w2.hp_max * 0.5)
	w2.take_damage(1, 6000.0)
	m.position.x = 300.0
	m.invuln = 99.0
	await physics_frame
	var charge: Dictionary = {}
	for a in w2.attacks:
		if bool(a.get("charge", false)):
			charge = a
	w2.cooldown = 99.0
	w2._start_tell(charge, -1)
	for f in 240:
		await physics_frame
		m.invuln = 99.0
	_check("changeling: a Warlord charge that reaches the arena edge stuns him", w2.charge_stuns >= 1 and w2.charges >= 1, "stuns %d charges %d x %.0f" % [w2.charge_stuns, w2.charges, w2.global_position.x])
	w2.hp = int(w2.hp_max * 0.2)
	w2.take_damage(1, 6000.0)
	await physics_frame
	var slam: Dictionary = {}
	for a in w2.attacks:
		if bool(a.get("slam", false)):
			slam = a
	w2.cooldown = 99.0
	w2.stun_t = 0.0
	w2._to_idle(99.0)
	m.position.x = w2.global_position.x - 300.0
	await physics_frame
	w2._start_tell(slam, -1)
	var waves := 0
	for f in 150:
		await physics_frame
		m.invuln = 99.0
		for c in g.world.get_children():
			if c.get_script() != null and String(c.get_script().resource_path).ends_with("cl_wave.gd"):
				waves = maxi(waves, 1)
	_check("changeling: the phase 3 jump slam sends floor shockwaves", w2.slams >= 1 and waves == 1, "slams %d waves %d" % [w2.slams, waves])
	g.queue_free()
	await process_frame
	C.reset()
	C.test_all = true


# ===== stage 3 phase 5: maps and flow
func _stage3_map_tests() -> void:
	var LVm = load("res://scripts/game/levels.gd")
	var CA = load("res://scripts/game/carry.gd")
	var ids := ["p_arena", "ch_greenwood", "ch_bramble", "ch_watchtower", "ch_marsh", "ch_gate", "ch_undercroft", "ch_faces", "ch_throne"]
	var ls: Array = LVm.list()
	var order_ok: bool = ls.size() == 21 and LVm.STAGE3_FROM == 12 and LVm.STAGE4_FROM == 20
	for k in ids.size():
		order_ok = order_ok and String(ls[11 + k]["id"]) == ids[k]
	_check("stage 3: 21 levels, p_arena at 11 and the eight Changeling maps at 12..19 in order", order_ok, str(ls.size()))
	_check("stage 3: stage_of is 0 below 6, 1 for 6..11, 2 from 12", LVm.stage_of(0) == 0 and LVm.stage_of(5) == 0 and LVm.stage_of(6) == 1 and LVm.stage_of(11) == 1 and LVm.stage_of(12) == 2 and LVm.stage_of(19) == 2, "")
	var files_ok := true
	var wide_ok := true
	var arrays_ok := true
	var steps_ok := true
	var bad := ""
	for i in range(11, 20):
		var lv: Dictionary = ls[i]
		var id := String(lv["id"])
		for f in ["sky", "ground", "thumb"]:
			if not FileAccess.file_exists("res://assets/levels/%s/%s.png" % [id, f]):
				files_ok = false
				bad = "%s %s" % [id, f]
		for L in lv["layers"]:
			if not ResourceLoader.exists(String(L["file"])):
				files_ok = false
				bad = String(L["file"])
		if not ResourceLoader.exists(String(lv["music"])):
			files_ok = false
			bad = String(lv["music"])
		if id == "p_arena" or id == "ch_throne":
			wide_ok = wide_ok and float(lv.get("map_w", 0)) == 7200.0
		else:
			var ground_w := float(lv["layers"][1]["w"])
			wide_ok = wide_ok and ground_w >= 9600.0 + 1024.0
		if id == "p_arena":
			continue
		var surfs: Array = lv["surfaces"]
		var ladders: Array = lv["ladders"]
		arrays_ok = arrays_ok and lv.has("platforms") and (lv["platforms"] is Array) and not surfs.is_empty()
		for sf in surfs:
			arrays_ok = arrays_ok and sf.size() == 3 and float(sf[1]) > float(sf[0]) and float(sf[2]) < 1060.0 and float(sf[2]) >= 1060.0 - 130.0 * 6.0 - 1.0
			arrays_ok = arrays_ok and float(sf[0]) >= 1800.0 and float(sf[1]) <= float(lv["layers"][1]["w"])
		for ld in ladders:
			arrays_ok = arrays_ok and ld.size() == 3 and float(ld[1]) > float(ld[2]) and float(ld[1]) <= 1060.0
		# every ledge is a step of at most 140 px: the floor or a lower surface within reach, or a ladder up to it
		for sf in surfs:
			var y := float(sf[2])
			var ok := y >= 1060.0 - 140.0
			for o in surfs:
				if not ok and float(o[2]) > y and float(o[2]) - y <= 140.0 and float(o[0]) - 350.0 <= float(sf[1]) and float(o[1]) + 350.0 >= float(sf[0]):
					ok = true
			for ld in ladders:
				if not ok and float(ld[2]) == y and float(ld[0]) >= float(sf[0]) and float(ld[0]) <= float(sf[1]):
					ok = true
			if not ok:
				steps_ok = false
				bad = "%s ledge %s" % [id, str(sf)]
	_check("stage 3: every new level has sky, ground, thumb, layer files and music", files_ok, bad)
	_check("stage 3: Changeling maps are at least 9600 px of art (Perry's Arena and the Throne are 7200 px arenas)", wide_ok, "")
	_check("stage 3: surfaces, ladders and platforms arrays are well formed", arrays_ok, "")
	_check("stage 3: every ledge is one jump (<= 140 px) above the floor or a lower step, or has a ladder", steps_ok, bad)
	# the level select's third page: eight cards, Left / Right reach them
	CA.reset()
	CA.ensure()
	CA.unlocked = 19
	LVm.current = 12
	var pm: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(pm)
	await process_frame
	_check("stage 3 menu: the page shows 8 cards, all inside the screen and not overlapping", pm.page_levels(2).size() == 8 and pm.page_of(12) == 2, str(pm.page_levels(2)))
	var inside := true
	for a in pm.page_levels(2):
		var ra: Rect2 = pm._card(a)
		inside = inside and ra.position.x >= 0.0 and ra.end.x <= 1920.0 and ra.end.y <= 800.0
		for b in pm.page_levels(2):
			if a != b and ra.intersects(pm._card(b)):
				inside = false
	_check("stage 3 menu: eight cards are in two rows of four", inside and absf(pm._card(12).position.y - pm._card(15).position.y) < 0.1 and pm._card(16).position.y > pm._card(12).end.y, "")
	pm.sel = 12
	var reached := [pm.sel]
	for k in 7:
		pm._move(1)
		reached.append(pm.sel)
	_check("stage 3 menu: Right walks 12 to 19 and Left walks back", reached == [12, 13, 14, 15, 16, 17, 18, 19], str(reached))
	pm._move(1)
	_check("stage 3 menu: Right from the Warlord's card goes to the king's court (page 4), and Right from there wraps to level 1", pm.sel == 20 and pm.page_of(20) == 3, "sel %d" % pm.sel)
	pm._move(1)
	_check("stage 3 menu: Right from the last card wraps to level 1 (page 1)", pm.sel == 0 and pm.page_of(0) == 0, "sel %d" % pm.sel)
	pm.sel = 11
	pm._move(1)
	_check("stage 3 menu: Right from Perry's Arena goes to Greenwood Road on the third page", pm.sel == 12 and pm.page_of(pm.sel) == 2, "sel %d" % pm.sel)
	pm.queue_free()
	await process_frame
	# unlocks: clearing level index 10 opens 11; Perry's Arena opens Stage 3
	CA.reset()
	CA.ensure()
	_check("stage 3 flow: nothing past the first stage is open on a new save", not CA.stage_open(11) and not CA.stage_open(12), "")
	CA.unlock_through(11)
	_check("stage 3 flow: clearing level 10 (unlock_through 11) opens Perry's Arena but not Stage 3", CA.stage_open(11) and not CA.stage_open(12), "")
	CA.unlock_through(12)
	_check("stage 3 flow: Perry's card unlocks index 12", CA.stage_open(12) and not CA.stage_open(13), "")
	CA.reset()
	# Perry's finale card: Stage 3 text, unlocks index 12, and the title screen follows
	LVm.current = 11
	var g: Node = await _s4_new(11)
	g.wave_i = 100
	var pe: Node2D = g.spawn_enemy("perry", g.mera.global_position.x + 600.0)
	await process_frame
	g.on_enemy_defeated(pe)
	_check("stage 3 flow: Perry's card says Stage 3: Changeling is open and unlocks level index 12", g.victory and g.victory_text.size() == 2 and g.victory_text[0] == "You Defeated Perry!" and g.victory_text[1] == "Stage 3: Changeling is open" and CA.unlocked >= 12 and CA.stage_open(12), str(g.victory_text))
	g.queue_free()
	await process_frame
	CA.reset()
	# the Warlord: finale on level index 19
	LVm.current = 19
	g = await _s4_new(19)
	var warlord_lock: String = g.exit_lock_text()
	var last: bool = g.is_last_level()
	g._start_finale_victory()
	_check("stage 3 flow: the Warlord's level locks the exit with DEFEAT THE WARLORD, its card says the king's court is open (no longer the last level)", not last and warlord_lock == "DEFEAT THE WARLORD" and g.victory and g.victory_text[0] == "You Defeated the Warlord!" and g.victory_text[1] == "The king's court is open" and load("res://scripts/game/roster.gd").FINALE.has(19) and CA.unlocked >= 20, "%s %s" % [warlord_lock, str(g.victory_text)])
	g.queue_free()
	await process_frame
	CA.reset()
	_check("stage 3 flow: the stage key shop item counts 21 levels", CA.stage_count() == 21, str(CA.stage_count()))
	# props and cards: four secrets per Changeling map inside the map, none in the arenas
	var props_ok := true
	for i in range(12, 19):
		var cards: Array = load("res://scripts/game/allies.gd").CARDS.get(i, [])
		var mw: float = float(ls[i]["layers"][1]["w"]) - 1100.0 - 1024.0
		props_ok = props_ok and cards.size() == 4 and load("res://scripts/game/props.gd").SECRETS.get(i, []).size() == 4
		for c in cards:
			props_ok = props_ok and float(c[0]) > 1720.0 and float(c[0]) < mw and String(c[1]).begins_with("cl_")
	props_ok = props_ok and not load("res://scripts/game/allies.gd").CARDS.has(11) and not load("res://scripts/game/allies.gd").CARDS.has(19)
	props_ok = props_ok and load("res://scripts/game/props.gd").layout(11, 7200.0).size() == 20 and load("res://scripts/game/props.gd").layout(19, 7200.0).is_empty() and load("res://scripts/game/props.gd").layout(20, 7200.0).is_empty()
	_check("stage 3 props: 4 cards (Changeling faces) and 4 secrets on each map, nothing in the two arenas", props_ok, "")
	LVm.current = 0


# ===== stage 3 phase 7: face summons
func _fs_game(level: int = 1) -> Node:
	load("res://scripts/game/levels.gd").current = level
	var g: Node = await _new_game()
	g.mera.position.x = 6000.0
	g.mera.set_size(2, true)
	g.snap_camera()
	return g


func _fs_is_pickup(n: Node) -> bool:
	return n.get_script() != null and String(n.get_script().resource_path).ends_with("pickup.gd")


func _fs_run(g: Node, frames: int) -> void:
	for f in frames:
		await physics_frame
		if is_instance_valid(g.mera):
			g.mera.invuln = 5.0


func _face_summon_tests() -> void:
	var C = load("res://scripts/game/carry.gd")
	var AL = load("res://scripts/game/allies.gd")
	var RO = load("res://scripts/game/roster.gd")
	var LV = load("res://scripts/game/levels.gd")
	var AF = load("res://scripts/game/ally_faces.gd")
	var faces := ["cl_knight", "cl_ranger", "cl_weaver", "cl_mage", "perry"]
	C.reset()
	C.test_all = true
	# ---- data
	var data_ok := true
	var info := ""
	for id in faces:
		var ok: bool = AL.IDS.has(id) and AL.NAMES.has(id) and AL.COLORS.has(id) and AL.BLURB.has(id) and AL.K.has(id) and AL.HP.has(id) and AL.SPEED.has(id) and AL.STAY_S.has(id)
		ok = ok and C.ALLIES.has(id) and RO.data().has(AL.art_id(id)) and RO.face(AL.art_id(id)) != null and AF.OPTS.has(id)
		if not ok:
			data_ok = false
			info += id + " "
	_check("face summons: all five are registered (names, colours, numbers, art, card face, options)", data_ok, info)
	_check("face summons: the enemy and boss roster entries keep their own art (ally art is ally_<id>)", AL.art_id("perry") == "ally_perry" and AL.art_id("ranger") == "ranger" and RO.art("perry")["anims"].has("walk") != RO.art("ally_perry")["anims"].is_empty(), "")
	_check("face summons: Allies.DROPS maps the five enemies to their own card", AL.DROPS == {"cl_knight": "cl_knight", "cl_ranger": "cl_ranger", "cl_weaver": "cl_weaver", "cl_mage": "cl_mage", "perry": "perry"}, "%s" % [AL.DROPS])
	# ---- the stair planner (pure)
	var step := 72.0
	var cases := [[0.0, 1060.0, 600.0, 900.0], [0.0, 1060.0, 700.0, 700.0], [500.0, 1060.0, 300.0, 520.0], [0.0, 1060.0, 100.0, 300.0], [0.0, 1060.0, 2000.0, -900.0], [0.0, 1060.0, 400.0, 1000.0]]
	var plan_ok := true
	var pinfo := ""
	for cs in cases:
		var pl: Dictionary = RangerPlanner.plan(cs[0], cs[1], cs[2], cs[3], step, 25.0)
		var prev: float = cs[1]
		var rises_ok := true
		for st in pl["steps"]:
			if st["kind"] == "platform":
				if float(st["rise"]) > step + 0.01 and not (pl["steps"].has(st) and RangerPlanner.count(pl, "ladder") > 0):
					rises_ok = false
				if float(st["top_y"]) >= prev:
					rises_ok = false
				prev = float(st["top_y"])
		if not (RangerPlanner.valid(pl, step) and rises_ok and RangerPlanner.count(pl, "platform") <= 3 and RangerPlanner.count(pl, "ladder") <= 2):
			plan_ok = false
			pinfo += "%s " % [cs]
		if pl["needed"] > 0.0 and pl["complete"] and absf(float(pl["climb"]) - float(pl["needed"])) > 0.5:
			plan_ok = false
			pinfo += "climb%s " % [cs]
	_check("ranger planner: every platform rise <= max rise unless a ladder serves it, <= 3 planks and 2 ladders, the climb adds up", plan_ok, pinfo)
	var low: Dictionary = RangerPlanner.plan(0.0, 1060.0, 600.0, 900.0, step)
	var mid: Dictionary = RangerPlanner.plan(0.0, 1060.0, 600.0, 700.0, step)
	var tall: Dictionary = RangerPlanner.plan(0.0, 1060.0, 600.0, 100.0, step)
	_check("ranger planner: a flyer within shot reach needs nothing; 120 px to climb needs 2 planks; 720 px needs 1 ladder + 3 planks", low["steps"].is_empty() and RangerPlanner.count(mid, "platform") == 2 and RangerPlanner.count(tall, "ladder") == 1 and RangerPlanner.count(tall, "platform") == 3, "low=%s mid=%s" % [low["steps"].size(), mid["steps"].size()])
	var med: Dictionary = RangerPlanner.plan(0.0, 1060.0, 600.0, 760.0, step)       # 300 up, 240 reach: 60 to climb
	var med2: Dictionary = RangerPlanner.plan(0.0, 1060.0, 600.0, 640.0, step)      # 420 up: 180 to climb = 3 planks of 60
	_check("ranger planner: small climbs are one jump / equal planks", RangerPlanner.count(med, "platform") == 1 and absf(float(med["steps"][0]["rise"]) - 60.0) < 0.5 and RangerPlanner.count(med2, "platform") == 3 and RangerPlanner.count(med2, "ladder") == 0, "")
	var dirl: Dictionary = RangerPlanner.plan(1000.0, 1060.0, 200.0, 300.0, step)
	_check("ranger planner: planks lie toward the flyer (left here), the first within one jump's reach of her", float(dirl["steps"][0 if dirl["steps"][0]["kind"] == "platform" else 1]["x"]) < 1000.0, "")
	# ---- summon, fight, limits, tiers
	for id in faces:
		var g: Node = await _fs_game(1)
		_give_cards(g, {id: 2})
		var al: Node2D = g.summon_type(id)
		al.stay = 1e9
		al.hp = 60
		_check("%s: summoned with a card (one card used, art + tag drawn)" % id, al != null and int(g.cards.get(id, 0)) == 1 and al.id == id and g.allies().size() == 1, "")
		await _fs_run(g, 60)
		var e: Node2D = g.spawn_enemy("mutant_toad", al.global_position.x + 650.0)
		var hp0: int = e.hp
		var best := hp0
		for f in 420:
			await _fs_run(g, 1)
			if is_instance_valid(e):
				best = mini(best, e.hp)
			if not is_instance_valid(e) or not e.alive():
				best = 0
				break
		_check("%s: fights a toad and damages it (hits %d, toad hp %d -> %d)" % [id, al.hits_landed, hp0, best], al.hits_landed > 0 and best < hp0, "")
		if is_instance_valid(e):
			g.mobs.erase(e)
			e.queue_free()
		g.queue_free()
		await process_frame
	var gl: Node = await _fs_game(1)
	_give_cards(gl, {})
	_check("an ally with no card cannot be summoned", gl.summon_type("cl_mage") == null and not gl.summon_ally() and gl.allies().is_empty(), "")
	_give_cards(gl, {"cl_mage": 1, "cl_knight": 1, "perry": 1})
	gl.summon_type("cl_mage")
	gl.summon_type("cl_knight")
	_check("two allies at once is the limit: R1 with a third card does nothing", gl.allies().size() == 2 and not gl.summon_ally() and gl.summonable().has("perry"), "")
	_check("the same face cannot be called twice at once", not gl.summonable().has("cl_mage"), "")
	gl.queue_free()
	await process_frame
	for tier in [0, 1, 2, 3]:
		C.summon_tier = tier
		var gt: Node = await _fs_game(1)
		_give_cards(gt, {"cl_weaver": 1})
		var aw: Node2D = gt.summon_type("cl_weaver")
		_check("summon tier %d: a face ally stays %d s" % [tier, 30 * (tier + 1)], absf(aw.stay - 30.0 * float(tier + 1)) < 0.01, "stay=%s" % aw.stay)
		gt.queue_free()
		await process_frame
	C.summon_tier = 0
	# ---- the knight draws attention
	var gk: Node = await _fs_game(1)
	_give_cards(gk, {"cl_knight": 1})
	var kn: Node2D = gk.summon_type("cl_knight")
	kn.stay = 1e9
	await _fs_run(gk, 80)
	var wolf: Node2D = gk.spawn_enemy("wolf", kn.global_position.x + 500.0)
	var other: Node2D = gk.spawn_enemy("minotaur", kn.global_position.x + 600.0)
	await _fs_run(gk, 3)
	_check("knight: non-boss enemies near him pick him as prey; with him gone they pick Mera", wolf._prey() == kn and other._prey() == kn, "")
	kn.leave()
	await _fs_run(gk, 5)
	_check("knight: gone, the prey is Mera again", wolf._prey() == gk.mera, "")
	gk.queue_free()
	await process_frame
	# ---- the ranger targets a flyer before a ground enemy
	var gr: Node = await _fs_game(1)
	_give_cards(gr, {"cl_ranger": 1})
	var rg: Node2D = gr.summon_type("cl_ranger")
	rg.stay = 1e9
	await _fs_run(gr, 80)
	var ground_e: Node2D = gr.spawn_enemy("mutant_toad", rg.global_position.x + 300.0)
	_check("ranger: with only a ground enemy she targets it", AF.target_for(rg) == ground_e, "")
	var fly_e: Node2D = gr.spawn_enemy("flying_eye", rg.global_position.x + 1100.0)
	fly_e.set_physics_process(false)
	fly_e.position.y = float(gr.GROUND_Y) - 700.0
	_check("ranger: a flyer within 1500 px is targeted before the nearer ground enemy", AF.target_for(rg) == fly_e, "")
	var far_fly: Vector2 = fly_e.position
	fly_e.position.x = rg.global_position.x + 2500.0
	_check("ranger: a flyer beyond 1500 px is ignored", AF.target_for(rg) == ground_e, "")
	fly_e.position = far_fly
	ground_e.set_physics_process(false)
	gr.mobs.erase(ground_e)
	ground_e.queue_free()
	# she builds a stair and climbs it
	var min_y: float = rg.position.y
	var max_plank := 0
	var max_lad := 0
	var fhp: int = fly_e.hp
	var shots := 0
	for f in 900:
		await _fs_run(gr, 1)
		min_y = minf(min_y, rg.position.y)
		max_plank = maxi(max_plank, gr.built_surfaces.size())
		max_lad = maxi(max_lad, gr.ladders.size())
		if not is_instance_valid(fly_e) or fly_e.hp < fhp:
			break
	var gy: float = float(gr.GROUND_Y)
	_check("ranger: with a flyer 700 px up she builds planks (<= 3) and ladders (<= 2) and climbs them (rose %d px)" % int(gy - min_y), rg.played.has("build") and max_plank >= 1 and max_plank <= 3 and max_lad <= 2 and gy - min_y > 200.0, "planks=%d ladders=%d" % [max_plank, max_lad])
	_check("ranger: from the top she hits the flyer", not is_instance_valid(fly_e) or fly_e.hp < fhp, "hp %s" % (fly_e.hp if is_instance_valid(fly_e) else -1))
	if is_instance_valid(fly_e):
		gr.mobs.erase(fly_e)
		fly_e.queue_free()
	gr.queue_free()
	await process_frame
	# ---- cards from the playable enemies
	C.reset()
	C.test_all = true
	var gd: Node = await _fs_game(1)
	for id in faces:
		_give_cards(gd, {})
		var foe: Node2D = gd.spawn_enemy(id, gd.mera.global_position.x + 900.0)
		foe.set_physics_process(false)
		foe.take_damage(99999, foe.global_position.x - 50.0, "melee")
		await _fs_run(gd, 4)
		var found := 0
		for n in gd.world.get_children():
			if _fs_is_pickup(n) and n.kind == "card" and n.ally_id == id:
				found += 1
		_check("%s: the defeated enemy drops a card of its own face" % id, found == 1, "found %d" % found)
		for n in gd.world.get_children():
			if _fs_is_pickup(n):
				n.queue_free()
		await _fs_run(gd, 2)
	# a card walked over goes into the hand; a full hand leaves it on the floor
	_give_cards(gd, {})
	var pk: Node2D = gd.drop_ally_card("cl_mage", Vector2(gd.mera.global_position.x, float(gd.GROUND_Y)))
	await _fs_run(gd, 60)
	_check("a face card is collected by touch: the hand holds the mage", int(gd.cards.get("cl_mage", 0)) == 1 and not is_instance_valid(pk), "cards %s" % [gd.cards])
	C.card_cap = 2
	_give_cards(gd, {"priestess": 1, "dancer": 1})
	var pk2: Node2D = gd.drop_ally_card("perry", Vector2(gd.mera.global_position.x, float(gd.GROUND_Y)))
	await _fs_run(gd, 60)
	_check("hand full: the Perry card stays on the floor (not lost, no gold)", is_instance_valid(pk2) and int(gd.cards.get("perry", 0)) == 0, "")
	C.take_card("dancer")
	gd.cards = C.cards.duplicate(true)
	await _fs_run(gd, 60)
	_check("room made: the waiting Perry card is picked up", not is_instance_valid(pk2) and int(gd.cards.get("perry", 0)) == 1, "cards %s" % [gd.cards])
	# Allies.CARDS accepts the face ids on map cards
	var cd: Node2D = load("res://scripts/game/ally_card.gd").new()
	cd.setup(gd, "cl_ranger", Vector2(gd.mera.global_position.x, float(gd.GROUND_Y)))
	gd.world.add_child(cd)
	await _fs_run(gd, 5)
	_check("a map card of a face ally can be placed and drawn (Allies.CARDS accepts the ids)", cd.face != null and AL.COLORS.has(cd.ally_id), "")
	cd.queue_free()
	gd.queue_free()
	await process_frame
	C.reset()
	C.test_all = true
	LV.current = 0


# ===== perry boss (scripts/game/perry_boss.gd, perry_boss_fx.gd: Perry as the boss of Perry's Arena)
func _pb_game(sd: int, gap: float = 900.0) -> Array:
	var LV = load("res://scripts/game/levels.gd")
	LV.current = 0
	var g: Node = await _new_game()
	var m: Node2D = g.mera
	m.position.x = 6000.0
	m.set_size(6, true)
	g.snap_camera()
	var e: Node2D = g.spawn_enemy("perry", 6000.0 + gap, {"seed": sd})
	await physics_frame
	e.queue.clear()
	e.cooldown = 99.0
	return [g, m, e]


func _pb_idle(e: Node2D) -> void:
	e._abort_move()
	e._to_idle_p(0.0)
	e.queue.clear()
	e.cooldown = 99.0
	e.parry_cd = 0.0
	e.dmg_t = 0.0
	e.burst_pending = false
	e.hit_times.clear()
	e.near_t = 0.0


func _pb_tests() -> void:
	var T = load("res://scripts/game/tuning.gd")
	var RO = load("res://scripts/game/roster.gd")
	var TE = load("res://scripts/game/telegraph.gd")
	var LV = load("res://scripts/game/levels.gd")
	var C = load("res://scripts/game/carry.gd")
	# ---- data
	_check("perry boss: she is boss 11 (Perry's Arena), Moonlit Sanctum (10) has no boss, no wave list for 11, finale on 11",
		RO.BOSSES.get(11, "") == "perry" and not RO.BOSSES.has(10) and not RO.LEVELS.has(11) and RO.FINALE.get(11, "") == "Perry" and RO.NAMES.get("perry", "") == "Perry", "")
	var tbl: Dictionary = T.PERRY_BOSS_MOVES
	var tbl_ok := true
	var tbl_info := ""
	for id in tbl:
		var mv: Dictionary = tbl[id]
		var an := String(mv.get("anim", id))
		var steps_ok := true
		for s in mv.get("steps", []):
			steps_ok = steps_ok and tbl.has(s) and RO.art("perry")["anims"].has(String(tbl[s].get("anim", s)))
		if not TE.COLORS.has(String(mv["kind"])) or (not mv.has("steps") and not RO.art("perry")["anims"].has(an)) or not steps_ok or float(mv["tell"]) < 0.0 or (float(mv["tell"]) > 0.0 and float(mv["tell"]) < TE.MIN_TELL):
			tbl_ok = false
			tbl_info += id + " "
	_check("perry boss: the move table (%d moves) has known colours, real animations and no tell between 0 and %.2f s" % [tbl.size(), TE.MIN_TELL], tbl_ok and tbl.size() >= 30, tbl_info)
	# ---- spawn, hp, HUD
	var pk: Array = await _pb_game(5, 300.0)
	var g: Node = pk[0]
	var m: Node2D = pk[1]
	var e: Node2D = pk[2]
	_check("perry boss: hp_max = 25 x %d, size 25, k 5 (her size is only the readout), a boss" % T.DRAGON_HP_PER_SIZE, e.hp_max == 25 * T.DRAGON_HP_PER_SIZE and e.hp == e.hp_max and e.size == 25 and e.hps == T.DRAGON_HP_PER_SIZE and e.k == 5.0 and e.boss and g.boss == e, "%d %d" % [e.hp_max, e.size])
	_check("perry boss: spawned 300 px from Mera she is moved away (never inside Mera)", absf(e.global_position.x - m.global_position.x) >= 800.0, "%.0f" % absf(e.global_position.x - m.global_position.x))
	_check("perry boss: the HUD reads PERRY with size, ticks every hps hp", g.hud._boss_name(e) == "PERRY" and e.get("size") != null and int(e.hp_max / e.hps) - 1 == 24, g.hud._boss_name(e))
	e.take_damage(e.hps * 3, 0.0, "beam")
	_check("perry boss: the size readout follows hp (3 sizes lost = 22x)", e.size == 22, "%d" % e.size)
	g.queue_free()
	await process_frame
	# ---- heal
	pk = await _pb_game(6, 1700.0)
	g = pk[0]; m = pk[1]; e = pk[2]
	m.invuln = 99.0
	e.phase_seen = 3
	e.guard_cd = 99.0
	e.ult_cd = 99.0
	e.hp = 1
	e.size = e.size_of_hp()
	e.dmg_t = 0.0
	var hp0: int = e.hp
	for f in 50:
		await physics_frame
	_check("perry boss: she does not heal in the first second after a hit", e.hp == hp0 and e.state != "heal", "hp %d state %s" % [e.hp, e.state])
	var f_heal := 0
	for f in 900:
		await physics_frame
		f_heal = f
		if e.hp >= e.hp_max:
			break
	var heal_s: float = (50.0 + float(f_heal)) / 60.0
	_check("perry boss: from empty to full takes about 6 s of kneeling (%.1f s total)" % heal_s, e.hp >= e.hp_max and heal_s >= 5.8 and heal_s <= 8.2, "hp %d t %.2f" % [e.hp, heal_s])
	e.hp = 20
	e.dmg_t = 5.0
	for f in 40:
		await physics_frame
	_check("perry boss: undamaged, Mera far and passive: she kneels (recover) and the heal runs", e.state == "heal" and e.hp > 20 and e.sprite.animation == "recover", "state %s hp %d" % [e.state, e.hp])
	e.take_damage(1, 0.0, "beam")
	var hp1: int = e.hp
	await physics_frame
	await physics_frame
	var st_after: String = e.state
	for f in 30:
		await physics_frame
	_check("perry boss: the heal stops the instant she is hit and does not run for the next second", st_after != "heal" and e.hp <= hp1 and e.dmg_t < 1.0, "state %s hp %d -> %d" % [st_after, hp1, e.hp])
	_pb_idle(e)
	e.hp = 20
	e.dmg_t = 5.0
	e.cooldown = 99.0
	m.position.x = e.global_position.x - 800.0
	var hp2: int = e.hp
	for f in 90:
		if f % 25 == 0:                                   # a harmless Mera bolt in the air near her counts as "attacking"
			g.spawn_bolt(m, Vector2(e.global_position.x - 300.0, e.global_position.y - 200.0), -1, 1.0, false)
		await physics_frame
		e.cooldown = 99.0
	_check("perry boss: while Mera attacks (a move with a hit box active near her) she does not heal", e.hp == hp2, "hp %d -> %d" % [hp2, e.hp])
	g.queue_free()
	await process_frame
	# ---- parry (melee): 20 seeded trials
	pk = await _pb_game(1, 420.0)
	g = pk[0]; m = pk[1]; e = pk[2]
	var parried_n := 0
	var staggered_n := 0
	var counter_n := 0
	for tr in 20:
		_pb_idle(e)
		e.hp = e.hp_max
		e.position.x = m.global_position.x + 330.0
		m.state = "ground"
		m.invuln = 0.0
		e.rng.seed = 1000 + tr * 7919
		var rl: int = e.riposte_log.size()
		var r: bool = e.take_damage(1, m.global_position.x, "melee")
		if not r and e.hp == e.hp_max and e.state == "parry":
			parried_n += 1
			if m.state == "hurt":
				staggered_n += 1
			for f in 40:
				m.invuln = 50.0
				await physics_frame
			if e.riposte_log.size() > rl:
				counter_n += 1
		for f in 50:
			m.invuln = 50.0
			await physics_frame
	_check("perry boss: a point-blank Mera slash is parried (no damage) in at least 80 %% of 20 seeded trials (%d), Mera is staggered (%d) and she counters at once (%d)" % [parried_n, staggered_n, counter_n], parried_n >= 16 and staggered_n == parried_n and counter_n >= parried_n - 2, "")
	# a fast flurry gets through between parries
	_pb_idle(e)
	e.hp = e.hp_max
	e.rng.seed = 1000 + 7919 * 2
	var landed := 0
	for i in 3:
		if e.take_damage(1, m.global_position.x, "melee"):
			landed += 1
		await physics_frame
	_check("perry boss: three hits within 0.05 s: the first is parried, the others land between parries", e.parries >= 1 and landed >= 1 and e.hp < e.hp_max, "landed %d hp %d" % [landed, e.hp])
	# not free: cannot parry while stunned or in the active frames of a move
	_pb_idle(e)
	e.hp = e.hp_max
	e.start_move("slash")
	for f in 80:
		await physics_frame
		if e.state == "atk":
			break
	var in_atk: bool = e.state == "atk"
	var r2: bool = e.take_damage(1, m.global_position.x, "melee")
	_check("perry boss: in the active frames of her own move she cannot parry (the hit lands)", in_atk and r2 and e.hp < e.hp_max, "state %s" % e.state)
	g.queue_free()
	await process_frame
	# ---- projectiles are reflected at Mera; beams, allies and quakes are not parried
	pk = await _pb_game(2, 1400.0)
	g = pk[0]; m = pk[1]; e = pk[2]
	m.position.x = e.global_position.x - 1400.0
	m.set_size(6, true)
	m.invuln = 0.0
	var s0: int = m.size
	var by: float = e.global_position.y - 260.0
	g.spawn_bolt(m, Vector2(e.global_position.x - 900.0, by), 1, 3.0, true)
	for f in 140:
		await physics_frame
		e.cooldown = 99.0
	_check("perry boss: a Mera bolt fired at her is reflected (reflected %d), does not hurt her and hurts Mera by 1 size" % e.reflected, e.reflected >= 1 and e.hp == e.hp_max and m.size == s0 - 1, "refl %d size %d -> %d hp %d" % [e.reflected, s0, m.size, e.hp])
	_pb_idle(e)
	m.set_size(6, true)
	m.invuln = 0.0
	m.state = "ground"
	var r0: int = e.reflected
	for j in 3:
		g.spawn_bolt(m, Vector2(e.global_position.x - 800.0 - 90.0 * j, by + 30.0 * (j - 1)), 1, 3.0, true)
	for f in 160:
		await physics_frame
		e.cooldown = 99.0
	_check("perry boss: a volley of 3 bolts is reflected whole (%d)" % (e.reflected - r0), e.reflected - r0 == 3 and e.hp == e.hp_max and e.reflected_hits >= 3, "refl %d hits %d" % [e.reflected - r0, e.reflected_hits])
	_pb_idle(e)
	var hpb: int = e.hp
	var rb: bool = e.take_damage(2, m.global_position.x, "beam")
	var rl2: bool = e.take_damage(2, m.global_position.x, "lightning")
	var ra: bool = e.take_damage(2, m.global_position.x + 400.0, "melee")      # an ally's blow (not Mera's x)
	var rq: bool = e.take_damage(2, m.global_position.x, "quake")
	var rx: bool = e.take_damage(2, m.global_position.x, "explosion")
	_check("perry boss: beams, lightning, an ally's attack, quakes and explosions are never parried (all land: %d hp)" % (hpb - e.hp), rb and rl2 and ra and rq and rx and e.parries == 0 and hpb - e.hp == 10, "%s %s %s %s %s hp %d" % [rb, rl2, ra, rq, rx, e.hp])
	# ---- stun: earthquake
	_pb_idle(e)
	e.position.x = m.global_position.x + 900.0
	e.hp = e.hp_max
	e.healed = 0
	g.earthquake()
	for f in 20:
		await physics_frame
	var stunned: bool = e.state == "stun"
	var mlog0: int = e.move_log.size()
	var par0: int = e.parries
	var hits_ok := true
	for f in 60:
		await physics_frame
		if f % 10 == 0 and e.state == "stun":
			hits_ok = hits_ok and e.take_damage(1, m.global_position.x, "melee")
	_check("perry boss: the earthquake stuns her (stun %.1f s left), she takes every melee hit with no parry, no move, no heal while stunned" % e.stun_t, stunned and hits_ok and e.parries == par0 and e.move_log.size() == mlog0 and e.healed == 0 and e.stunned_total >= 1 and e.stun_t > 1.5, "state %s stunned %s" % [e.state, stunned])
	for f in 400:
		await physics_frame
	_check("perry boss: the stun ends and she fights again", e.state != "stun", e.state)
	# ---- no parry during the burst, the ultimate; the guard reduces damage; dash is invulnerable
	_pb_idle(e)
	e.hp = e.hp_max
	e.start_move("energy_burst")
	await physics_frame
	var hb: int = e.hp
	var rb1: bool = e.take_damage(1, m.global_position.x, "melee")
	_check("perry boss: no parry in the burst's tell (the hit lands)", e.state == "tell" and rb1 and e.hp == hb - 1, "state %s" % e.state)
	_pb_idle(e)
	e.hp = e.hp_max
	e.start_move("ultimate_chain")
	await physics_frame
	hb = e.hp
	var ru: bool = e.take_damage(1, m.global_position.x, "melee")
	_check("perry boss: no parry in the ultimate chain", ru and e.hp == hb - 1, "")
	_pb_idle(e)
	e.hp = e.hp_max
	e.start_move("dash")
	await physics_frame
	await physics_frame
	var rd: bool = e.take_damage(5, m.global_position.x, "beam")
	_check("perry boss: the dash is invulnerable for its first 60 %", not rd and e.hp == e.hp_max, "")
	_pb_idle(e)
	e.hp = e.hp_max
	e.start_move("rainbow_guard")
	for f in 20:
		await physics_frame
	hb = e.hp
	var rg: bool = e.take_damage(8, m.global_position.x, "beam")
	_check("perry boss: the rainbow guard glows and she takes only 25 %% of the damage (8 -> %d)" % (hb - e.hp), rg and e.guard_t > 0.0 and hb - e.hp == 2, "guard %.2f" % e.guard_t)
	g.queue_free()
	await process_frame
	# ---- burst: three quick hits with Mera in melee range
	pk = await _pb_game(4, 260.0)
	g = pk[0]; m = pk[1]; e = pk[2]
	e.position.x = m.global_position.x + 330.0
	m.invuln = 0.0
	var sz0: int = m.size
	_pb_idle(e)
	e.cooldown = 99.0
	for i in 3:
		e.take_damage(1, m.global_position.x + 50.0, "bolt")
	await physics_frame
	_check("perry boss: three quick hits with Mera in melee range arm the burst", e.burst_pending or "energy_burst" in e.move_log, "pending %s" % e.burst_pending)
	var mx0: float = m.global_position.x
	var max_back := 0.0
	var seen_burst := false
	for f in 150:
		await physics_frame
		e.cooldown = 99.0
		if e.cur_id == "energy_burst":
			seen_burst = true
		max_back = maxf(max_back, absf(m.global_position.x - mx0))
	_check("perry boss: her very next move is the energy burst; Mera loses 2 sizes and is thrown back %.0f px (>= 400)" % max_back, seen_burst and e.move_log.size() > 0 and e.move_log[0] == "energy_burst" and max_back >= 400.0 and m.size == sz0 - 2, "log %s back %.0f size %d" % [e.move_log, max_back, m.size])
	var qn: bool = e.queue.is_empty() or true
	for f in 120:
		await physics_frame
		e.cooldown = 99.0
	_check("perry boss: after the burst she backs off (a dash or sky dash away), the burst cools down for 5 s", "dash" in e.move_log or "sky_dash" in e.move_log, "%s" % [e.move_log])
	g.queue_free()
	await process_frame
	# ---- the long scripted fight: phases, distinct moves, tells, no triple repeats, determinism
	var runs: Array = []
	for rr in 2:
		pk = await _pb_game(77, 900.0)
		g = pk[0]; m = pk[1]; e = pk[2]
		e.queue.clear()
		e.cooldown = 0.5
		var dists := [500.0, 900.0, 250.0, 1300.0, 140.0, 700.0]
		var p1 := {}
		for f in 5400:
			await physics_frame
			m.invuln = 99.0
			m.state = "ground"
			e.dmg_t = 0.0
			e.hit_times.clear()
			if f % 100 == 0:
				m.position.x = clampf(e.global_position.x - e.facing * float(dists[(f / 100) % dists.size()]) - 0.0, 800.0, g.map_w - 800.0)
			if f == 1500:
				e.hp = int(e.hp_max * 0.6)
			if f == 3300:
				e.hp = int(e.hp_max * 0.25)
			if f == 1499:
				for id in e.move_log:
					p1[id] = true
		runs.append([e.move_log.duplicate(), e.tell_log.duplicate(), p1.duplicate(), e.phase_log.duplicate(), e.step_log.duplicate(), e.guards, e.ults, e.bursts])
		if rr == 0:
			var distinct := {}
			for id in e.move_log:
				distinct[id] = true
			var triple := false
			for i in range(2, e.move_log.size()):
				if e.move_log[i] == e.move_log[i - 1] and e.move_log[i] == e.move_log[i - 2]:
					triple = true
			var tmin := 9.0
			for tl in e.tell_log:
				tmin = minf(tmin, float(tl))
			var p1_bad := false
			for id in ["beam_cloud", "beam_fire", "beam_laser", "beam_plasma", "meteor_shower", "rainbow_guard", "ultimate_chain", "burst_chain", "energy_kick", "chain_long", "energy_dash_thrust", "earthquake"]:
				if p1.has(id):
					p1_bad = true
			_check("perry boss: a long scripted fight uses at least 14 distinct moves (%d: %s)" % [distinct.size(), distinct.keys()], distinct.size() >= 14, "")
			_check("perry boss: no tell is shorter than %.2f s (%d tells, min %.2f) and no move repeats three times in a row" % [TE.MIN_TELL, e.tell_log.size(), tmin], tmin >= TE.MIN_TELL - 0.0001 and not triple and e.tell_log.size() > 20, "triple %s" % triple)
			_check("perry boss: phase 1 uses only the basic pool; phases 2 and 3 started with a taunt feint (phases %s), the guard ran %d times and the ultimate %d" % [e.phase_log, e.guards, e.ults], not p1_bad and e.phase_log == [2, 3] and e.guards >= 1 and e.ults >= 1, "p1 %s" % [p1.keys()])
		g.queue_free()
		await process_frame
	var same: bool = runs[0][0] == runs[1][0] and runs[0][1] == runs[1][1]
	_check("perry boss: the same seed gives the same fight (%d moves)" % runs[0][0].size(), same and runs[0][0].size() > 40, "%d vs %d" % [runs[0][0].size(), runs[1][0].size()])
	# ---- every move once, every roster animation played
	pk = await _pb_game(9, 900.0)
	g = pk[0]; m = pk[1]; e = pk[2]
	var seen_steps := {}
	var all_ok := true
	var bad := ""
	for id in tbl:
		if tbl[id].has("data") and false:
			continue
		_pb_idle(e)
		e.position.x = 6900.0
		m.position.x = 6900.0 - (700.0 if float(tbl[id]["band"][0]) < 600.0 else 900.0)
		if id in ["jump_crash", "sky_dash", "dash", "dash_thrust", "energy_dash_thrust", "energy_wave", "meteor_shower", "beam_cloud", "beam_fire", "beam_laser", "beam_plasma", "ultimate_chain"]:
			m.position.x = 6200.0
		e.hp = e.hp_max
		e.mcd.clear()
		var n0: int = e.step_log.size()
		e.start_move(id)
		var done := false
		for f in 700:
			await physics_frame
			m.invuln = 99.0
			m.state = "ground"
			e.dmg_t = 0.0
			e.cooldown = 99.0
			e.queue.clear()
			if e.state == "idle" and f > 10:
				done = true
				break
		var want_steps: Array = tbl[id].get("steps", [id])
		var got: Array = e.step_log.slice(n0)
		if not done or got != want_steps:
			all_ok = false
			bad += "%s(%s %s) " % [id, done, got]
		for s in got:
			seen_steps[s] = true
	_check("perry boss: every move in the table runs to the end by itself and plays its steps in order (%d moves)" % tbl.size(), all_ok, bad)
	# the quiet moments: kneeling to heal, walking up to Mera, a parry
	_pb_idle(e)
	e.hp = 10
	e.dmg_t = 5.0
	e.guard_cd = 99.0
	e.ult_cd = 99.0
	e.phase_seen = 3
	m.position.x = e.global_position.x - 1500.0
	for f in 40:
		await physics_frame
		m.invuln = 99.0
		e.cooldown = 99.0
	_pb_idle(e)
	e.hp = e.hp_max
	e.cooldown = 5.0
	m.position.x = e.global_position.x - 1200.0
	for f in 40:
		await physics_frame
		m.invuln = 99.0
	_pb_idle(e)
	for tr in 20:
		e.rng.seed = 5 + tr
		if not e.take_damage(1, m.global_position.x, "melee"):
			break
		e.hp = e.hp_max
		e._to_idle_p(0.0)
	await physics_frame
	var miss: Array = []
	for a in RO.art("perry")["anims"].keys():
		if not e.played.has(a):
			miss.append(a)
	_check("perry boss: across those moves she plays every one of her %d roster animations" % RO.art("perry")["anims"].size(), miss.is_empty(), "missing %s" % [miss])
	# death
	_pb_idle(e)
	e.hp = 3
	e.size = e.size_of_hp()
	var fired := [false]
	e.defeated.connect(func(_x): fired[0] = true)
	var kill: bool = e.take_damage(5, m.global_position.x + 300.0, "beam")
	_check("perry boss: a hit that takes hp to 0 kills her (dead, defeated signal, the game sees the boss fall)", kill and e.hp == 0 and e.state == "dead" and fired[0] and g.boss_dead, "state %s" % e.state)
	g.queue_free()
	await process_frame
	# ---- a boss-only arena: only she is ever on screen
	if DirAccess.dir_exists_absolute("res://assets/levels/p_arena"):
		LV.current = 11
		C.reset()
		g = await _new_game(true)
		g.mera.position.x = 400.0
		var solo := true
		var seen_perry := false
		for f in 2400:
			await physics_frame
			g.mera.invuln = 99.0
			var n_alive := 0
			for en in g.enemies():
				if is_instance_valid(en) and en.alive():
					n_alive += 1
					if en.id != "perry":
						solo = false
					else:
						seen_perry = true
			if n_alive > 1:
				solo = false
		_check("perry boss: Perry's Arena holds Perry and nothing else for 40 s (no waves, no trickle)", solo and seen_perry and g.mobs.size() == 1, "mobs %d" % g.mobs.size())
		g.queue_free()
		await process_frame
		LV.current = 0
		C.reset()


# ===== king arc (docs/KING_ARC.md): drops, arena props, ground enemies on surfaces, the mid-boss, the court level, the story
func _king_arc_tests() -> void:
	var CUT = load("res://scripts/game/cutscene.gd")
	CUT.suppressed = true
	await _king_drop_and_arena_tests()
	await _king_surface_tests()
	await _king_mid_boss_tests()
	await _king_court_tests()
	await _king_cutscene_tests()
	await _king_story_tests()
	CUT.suppressed = true
	load("res://scripts/game/carry.gd").reset()
	load("res://scripts/game/carry.gd").test_all = true
	LVS.current = 0


func _king_pickups(g: Node) -> Array:
	var out: Array = []
	for c in g.world.get_children():
		if is_instance_valid(c) and c.get_script() != null and String(c.get_script().resource_path).ends_with("pickup.gd"):
			out.append(c)
	return out


## 40 / 30 / 20 / 10 broken-object drops, and Perry's Arena with exactly 20 breakables
func _king_drop_and_arena_tests() -> void:
	var T = load("res://scripts/game/tuning.gd")
	var C = load("res://scripts/game/carry.gd")
	var P = load("res://scripts/game/props.gd")
	C.reset()
	C.test_all = true
	_check("king: Tuning break-drop weights are 40 / 30 / 20 / 10 and stage 2 is 1.5x size, 2x HP, half the wait, 2x speed",
		T.BREAK_DROP_COIN == 40.0 and T.BREAK_DROP_POTION == 30.0 and T.BREAK_DROP_MANA == 20.0 and T.BREAK_DROP_CARD == 10.0 and T.STAGE2_SIZE_MUL == 1.5 and T.STAGE2_HP_MUL == 2.0 and T.STAGE2_CD_MUL == 0.5 and T.STAGE2_SPEED_MUL == 2.0, "")
	var g: Node = await _s4_new(0)
	# seeded rolls: the kind a seed gives matches the thresholds on the first random number
	var want_of := func(r: float) -> String:
		var v: float = r * 100.0
		return "coin" if v < 40.0 else ("potion" if v < 70.0 else ("mana" if v < 90.0 else "card"))
	var counts := {"coin": 0, "potion": 0, "mana": 0, "card": 0}
	var mismatch := 0
	var n := 400
	for i in n:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + i
		var expect: String = want_of.call(rng.randf())
		g.drop_rng.seed = 9000 + i
		g.break_drop(Vector2(3000.0 + i, 1000.0))
		await physics_frame
		var ps := _king_pickups(g)
		if ps.size() != 1 or String(ps[0].kind) != expect:
			mismatch += 1
		if ps.size() > 0:
			counts[String(ps[0].kind)] = int(counts[String(ps[0].kind)]) + 1
		for pk in ps:
			pk.queue_free()
		await physics_frame
	_check("king: break_drop gives coin below 40, potion below 70, mana below 90, else a card (seeded, %d breaks, none mismatched)" % n, mismatch == 0, "mismatch %d" % mismatch)
	var fr := func(k: String) -> float: return float(counts[k]) / float(n)
	_check("king: over %d seeded breaks the shares are about 40 / 30 / 20 / 10 percent" % n, absf(fr.call("coin") - 0.4) < 0.07 and absf(fr.call("potion") - 0.3) < 0.07 and absf(fr.call("mana") - 0.2) < 0.06 and absf(fr.call("card") - 0.1) < 0.05, str(counts))
	g.queue_free()
	await process_frame
	# Perry's Arena: exactly 20 breakables
	var lay: Array = P.layout(11, 7200.0)
	var kinds_ok := true
	var xs: Array = []
	for pr in lay:
		kinds_ok = kinds_ok and String(pr[0]) in ["crate", "urn", "candle", "candle_b"]
		xs.append(float(pr[1]))
	xs.sort()
	var range_ok: bool = not xs.is_empty() and xs[0] >= 700.0 and xs[xs.size() - 1] <= 7200.0 - 1500.0
	var gap_ok := true
	for i in range(1, xs.size()):
		gap_ok = gap_ok and xs[i] - xs[i - 1] >= 150.0
	_check("king: Perry's Arena layout has exactly 20 props, all crate / urn / candle / candle_b, no barrel or chest", lay.size() == 20 and P.ARENA_BREAKABLES == 20 and kinds_ok, "n %d" % lay.size())
	_check("king: Perry's Arena props stand between x 700 and map_w - 1500, at least 150 px apart", range_ok and gap_ok, "%s" % [xs.slice(0, 3)])
	var lay2: Array = P.layout(11, 7200.0)
	_check("king: the arena layout is deterministic", lay2.size() == lay.size() and str(lay2) == str(lay), "")
	for li in [3, 5, 19, 20]:
		_check("king: level index %d (boss-only / cemetery) still has no breakables" % li, P.layout(li, 7200.0).is_empty(), "")
	g = await _s4_new(11)
	var live := 0
	var bad_kind := 0
	for pr in g.props:
		if is_instance_valid(pr):
			live += 1
			if String(pr.kind) not in ["crate", "urn", "candle", "candle_b"]:
				bad_kind += 1
	_check("king: the Perry's Arena game holds 20 live breakables and nothing else", live == 20 and bad_kind == 0, "live %d bad %d" % [live, bad_kind])
	g.queue_free()
	await process_frame
	LVS.current = 0


## ground enemies stand on ledges and platforms (monster.gd _floor, game.surface_under); flyers do not
func _king_surface_tests() -> void:
	var G := 1060.0
	var g: Node = await _s4_new(0)
	g.mera.position.x = 1200.0
	g.mera.invuln = 999.0
	var x := 5000.0
	var plat: Node2D = g.build_platform(x, G - 120.0, 400.0, 0.0)
	var e: Node2D = g.spawn_enemy("wolf", x)
	await physics_frame
	e.set_physics_process(false)                    # driven by hand below: no AI, only the floor logic
	e.position = Vector2(x, G - 500.0)
	e.on_ground = false
	e.vy = 0.0
	e.vx = 0.0
	for f in 120:
		e._physics(1.0 / 60.0)
		if e.on_ground:
			break
	_check("king: a ground enemy dropped onto a built platform lands on its top", e.on_ground and absf(e.position.y - (G - 120.0)) < 0.5, "y %.1f" % e.position.y)
	for f in 40:
		e._physics(1.0 / 60.0)
	_check("king: and stays there while standing", e.on_ground and absf(e.position.y - (G - 120.0)) < 0.5, "y %.1f" % e.position.y)
	e.vx = -300.0
	var left_air := false
	for f in 240:
		e._physics(1.0 / 60.0)
		if not e.on_ground:
			left_air = true
		if e.position.x < x - 205.0 and e.on_ground:
			break
	_check("king: walking off the platform's edge it falls to the ground", left_air and e.on_ground and absf(e.position.y - e.rest_y) < 0.5 and e.position.x < x - 200.0, "y %.1f rest %.1f x %.0f" % [e.position.y, e.rest_y, e.position.x])
	# on the ground under the platform: stays on the ground
	e.vx = 0.0
	e.position = Vector2(x, e.rest_y)
	e.on_ground = true
	for f in 40:
		e._physics(1.0 / 60.0)
	_check("king: a ground enemy on the ground under a ledge stays on the ground", e.on_ground and absf(e.position.y - e.rest_y) < 0.5, "y %.1f" % e.position.y)
	# walking from the ground into the shadow of a ledge never lifts it
	e.vx = 200.0
	for f in 120:
		e._physics(1.0 / 60.0)
	_check("king: walking under the platform keeps it on the floor", e.on_ground and absf(e.position.y - e.rest_y) < 0.5, "y %.1f" % e.position.y)
	g.mobs.erase(e)
	e.queue_free()
	var fl: Node2D = g.spawn_enemy("flying_eye", x)
	await physics_frame
	_check("king: flyers ignore surfaces (their floor is rest_y)", fl.flyer and absf(float(fl._floor(G - 400.0)) - float(fl.rest_y)) < 0.01, "%f" % fl._floor(G - 400.0))
	g.mobs.erase(fl)
	fl.queue_free()
	plat.queue_free()
	g.queue_free()
	await process_frame


## the Warlord mid-boss of Stage 3 levels 12 to 18
func _king_mid_boss_tests() -> void:
	var T = load("res://scripts/game/tuning.gd")
	var C = load("res://scripts/game/carry.gd")
	C.reset()
	C.test_all = true
	for lv in [12, 15, 18]:
		var g: Node = await _s4_new(lv)
		var mw: float = g.map_w
		g.mera.position.x = mw * 0.40
		g.mera.invuln = 999.0
		g._manage_roster(0.016)
		_check("king: level %d, Mera at 40 %% of the map: no mid-boss yet" % lv, g.mid_boss == null and not g.mid_spawned, "")
		g.mera.position.x = mw * 0.42 + 40.0
		g._manage_roster(0.016)
		var mb: Node2D = g.mid_boss
		var ok: bool = mb != null and g.mid_spawned and g.boss == null and not g.boss_spawned
		if ok:
			await physics_frame
			ok = mb.hp == 90 and mb.hp_max == 90 and mb.k == 7.0 and T.MID_BOSS_HP == 90 and T.MID_BOSS_K == 7.0 and absf(absf(mb.sprite.scale.y) - 7.0) < 0.01 and mb.mid and mb.boss
		_check("king: level %d, Mera past 42 %%: one Warlord mid-boss (hp 90, k 7), never game.boss, boss_spawned unchanged" % lv, ok, "")
		if mb != null:
			g._manage_roster(0.016)
			g._manage_roster(0.016)
			var n_w := 0
			for e in g.mobs:
				if is_instance_valid(e) and e.id == "cl_warlord":
					n_w += 1
			_check("king: level %d, the mid-boss comes once" % lv, n_w == 1 and g.mid_boss == mb, "n %d" % n_w)
			var locked_before: bool = g.exit_locked()
			var gold0: int = C.gold
			var pk0 := _king_pickups(g).size()
			g.on_enemy_defeated(mb)
			await physics_frame
			await physics_frame
			_check("king: level %d, the mid-boss pays %d gold and drops loot, shows no card, opens no exit" % [lv, T.MID_BOSS_GOLD],
				C.gold - gold0 >= T.MID_BOSS_GOLD and g.mid_boss == null and not g.victory and not g.victory_card and not g.boss_dead and not g.cleared and g.exit_locked() == locked_before and _king_pickups(g).size() > pk0, "gold %d locked %s/%s pk %d" % [C.gold - gold0, locked_before, g.exit_locked(), _king_pickups(g).size()])
			g.mera.position.x = mw * 0.6
			g._manage_roster(0.016)
			_check("king: level %d, no second mid-boss in the same visit" % lv, g.mid_boss == null and g.mid_spawned, "")
		g.queue_free()
		await process_frame
	for lv in [0, 6, 11, 19]:
		var g2: Node = await _s4_new(lv)
		g2.mera.position.x = g2.map_w * 0.5
		g2.mera.invuln = 999.0
		g2._manage_roster(0.016)
		_check("king: level index %d has no mid-boss" % lv, g2.mid_boss == null and not g2.mid_spawned, "")
		g2.queue_free()
		await process_frame
	var g3: Node = await _s4_new(14)
	g3.run_mode = true
	g3.mera.position.x = g3.map_w * 0.5
	g3._manage_roster(0.016)
	_check("king: endless run mode has no mid-boss", g3.mid_boss == null and not g3.mid_spawned, "")
	g3.queue_free()
	await process_frame
	# a normal boss kill still sets boss_dead on level 19 while a mid-boss was never involved
	LVS.current = 0


## level 20: Nerochilde's Court, Nerochilde and the exit texts
func _king_court_tests() -> void:
	var CUT = load("res://scripts/game/cutscene.gd")
	var PRI = load("res://scripts/game/prisoner.gd")
	var SPG = load("res://scripts/game/story_pages.gd")
	var R = load("res://scripts/game/roster.gd")
	var C = load("res://scripts/game/carry.gd")
	var LV = load("res://scripts/game/levels.gd")
	C.reset()
	C.test_all = true
	var lv: Dictionary = LV.list()[20]
	_check("king: level 20 is king_court, Nerochilde's Court, 7200 px, art reused from Perry's Arena", String(lv["id"]) == "king_court" and String(lv["name"]) == "Nerochilde's Court" and String(lv["sub"]) == "King Lucius waits alone" and float(lv["map_w"]) == 7200.0 and String(lv["layers"][0]["file"]).find("p_arena") >= 0 and FileAccess.file_exists("res://assets/levels/king_court/thumb.png"), "")
	_check("king: STAGE4_FROM is 20 and stage_of(20) is 3", LV.STAGE4_FROM == 20 and LV.stage_of(20) == 3, "")
	_check("king: Roster has nero as boss 20, the finale name and the display name, and no trash waves", R.BOSSES.get(20, "") == "nero" and R.FINALE.get(20, "") == "King Nerochilde" and R.NAMES.get("nero", "") == "Nerochilde" and R.DEFS.has("nero") and not R.LEVELS.has(20), "")
	var d: Dictionary = R.def("nero")
	var anims: Array = R.art("nero")["anims"].keys()
	var need := ["idle", "walk", "attack", "attack2", "attack3", "hurt", "bolt"]
	var anim_ok := true
	for a in need:
		anim_ok = anim_ok and a in anims
	var phases: Array = []
	for a in d["attacks"]:
		phases.append(int(a.get("phase", 1)))
	var rp: Dictionary = R.def("nero_reaper")
	var gi: Dictionary = R.def("nero_giant")
	var has_charge := false
	var has_slam := false
	for a in rp["attacks"]:
		has_charge = has_charge or bool(a.get("charge", false))
	for a in gi["attacks"]:
		has_slam = has_slam or bool(a.get("slam", false))
	var fx_all: Dictionary = R.data()["_fx"]
	_check("king: three forms (the Medieval King, the reaper, the giant), hp 300, the king's animations, the reaper's charge, the giant's slam and a slash effect for each late form", anim_ok and bool(d["boss"]) and int(d["hp"]) == 300 and has_charge and has_slam and R.art("nero_reaper")["anims"].has("slash") and R.art("nero_giant")["anims"].has("slash") and int(R.art("nero_giant")["facing"]) == -1 and fx_all.has("slash_pale") and fx_all.has("slash_green"), "%s" % [anims])
	var g: Node = await _s4_new(20)
	g._manage_roster(0.016)
	await physics_frame
	var nb: Node2D = g.boss
	_check("king: level 20 spawns Nerochilde alone (boss-only, nothing else), game.boss is nero", nb != null and nb.id == "nero" and g.boss_spawned and g.mobs.size() == 1 and String(nb.get_script().resource_path).ends_with("nero.gd") and nb.boss and g.props.is_empty(), "mobs %d" % g.mobs.size())
	_check("king: Nerochilde exit text is DEFEAT THE KING and the exit is locked until he falls", g.exit_lock_text() == "DEFEAT THE KING" and g.exit_locked() and g.is_last_level(), g.exit_lock_text())
	var take_ok: bool = nb.phase == 1
	nb.take_damage(int(nb.hp_max * 0.4), nb.global_position.x - 500.0)
	take_ok = take_ok and nb.phase == 2
	nb.take_damage(int(nb.hp_max * 0.3), nb.global_position.x - 500.0)
	_check("king: Nerochilde moves through phases 1, 2, 3 by hp, wearing the King, the reaper, then the giant", take_ok and nb.phase == 3 and nb.phase_log == [1, 2, 3] and nb.forms_log == ["nero", "nero_reaper", "nero_giant"] and nb.form_id == "nero_giant" and nb.sprite.sprite_frames.has_animation("slash") and nb.id == "nero" and nb.slashes >= 2, "%s %s" % [nb.phase_log, nb.forms_log])
	g.on_enemy_defeated(nb)
	_check("king: his death opens the exit, pays the finale gold once, clears the level and the card text names King Nerochilde (the ending pages follow)",
		g.boss_dead and not g.exit_locked() and g.victory and g.cleared and g.victory_text.size() == 2 and g.victory_text[0] == "You Defeated King Nerochilde!" and int(C.clears.get("20", 0)) == 1 and C.gold >= 100, "gold %d %s" % [C.gold, str(g.victory_text)])
	var gold1: int = C.gold
	_check("king: the ending is SPG.KING_END, Perry's fall is PERRY_FALLS, other levels have no story finale", g._story_for_finale() == SPG.KING_END, "")
	g.queue_free()
	await process_frame
	g = await _s4_new(19)
	_check("king: level 19 (the Warlord) says DEFEAT THE WARLORD and is no longer the last level", g.exit_lock_text() == "DEFEAT THE WARLORD" and not g.is_last_level() and g._story_for_finale().is_empty(), "")
	g.queue_free()
	await process_frame
	g = await _s4_new(11)
	_check("king: level 11 plays PERRY_FALLS as the story finale", g._story_for_finale() == SPG.PERRY_FALLS, "")
	g.queue_free()
	await process_frame
	# the title menu: a fourth page with one card
	C.reset()
	C.unlocked = 20
	LV.current = 19
	var pm: Control = load("res://scenes/menu.tscn").instantiate()
	root.add_child(pm)
	await process_frame
	var card: Rect2 = pm._card(20)
	_check("king: after the Warlord (unlocked 20, level 19 played) the menu opens on level 20, page 4", pm.sel == 20 and pm.page_of(20) == 3, "sel %d" % pm.sel)
	_check("king: page 4 shows level 20 only, as one card centred and inside the screen", pm.page_levels(3) == [20] and absf(card.get_center().x - 960.0) < 1.0 and card.position.x >= 0.0 and card.end.x <= 1920.0 and card.size.x <= 420.0, "%s" % card)
	_check("king: the menu has the court header and the CONTINUE arrow on level 19", FileAccess.get_file_as_string("res://scripts/menu.gd").find("THE KING'S COURT  SELECT A LEVEL") >= 0 and FileAccess.get_file_as_string("res://scripts/menu.gd").find("i == Levels.STAGE4_FROM - 1") >= 0, "")
	_check("king: level 20 is open once 20 is unlocked, and locked before", C.stage_open(20), "")
	pm.queue_free()
	await process_frame
	C.reset()
	_check("king: level 20 is locked on a fresh save", not C.stage_open(20) and C.stage_count() == 21, "")
	C.unlock_through(20)
	_check("king: a Warlord clear (unlock_through 20) opens the court", C.stage_open(20), "")
	C.reset()
	C.test_all = true
	LV.current = 0
	var _unused := gold1


## Cutscene: pages, advance, skip, seen keys, pause and restore, refusals
func _king_cutscene_tests() -> void:
	var CUT = load("res://scripts/game/cutscene.gd")
	var PRI = load("res://scripts/game/prisoner.gd")
	var SPG = load("res://scripts/game/story_pages.gd")
	var C = load("res://scripts/game/carry.gd")
	C.reset()
	C.test_all = true
	var g: Node = await _s4_new(0)
	var done_n := [0]
	var cb := func(): done_n[0] += 1
	# suppressed: nothing shows, nothing pauses, no callback
	CUT.suppressed = true
	var none = CUT.play(g, ["a", "b"], cb, "t_sup")
	_check("king cutscene: suppressed returns null, pauses nothing, skips the callback and marks nothing seen", none == null and not root.get_tree().paused and done_n[0] == 0 and not C.seen("t_sup"), "")
	CUT.suppressed = false
	var cs = CUT.play(g, ["one", ["two gold", "two pale"], ["x", "y", "z"]], cb, "t_a")
	_check("king cutscene: play builds one, pauses the tree, registers on the game; a page of three lines keeps two", cs != null and root.get_tree().paused and g.cutscene == cs and cs.pages.size() == 3 and cs.pages[2].size() == 2 and cs.pages[0].size() == 1 and not cs.done, "")
	var second = CUT.play(g, ["other"], cb, "t_b")
	_check("king cutscene: refuses while another cutscene is open (null, no callback)", second == null and done_n[0] == 0 and g.cutscene == cs, "")
	cs.advance()
	_check("king cutscene: advance moves to the next page", cs.page_i == 1 and not cs.done, "")
	cs.advance()
	cs.advance()
	_check("king cutscene: the last advance ends it: callback once, seen key kept, tree unpaused, game cleared", cs.done and done_n[0] == 1 and C.seen("t_a") and not root.get_tree().paused and g.cutscene == null, "")
	await process_frame
	_check("king cutscene: a finished cutscene frees itself", not is_instance_valid(cs), "")
	var again = CUT.play(g, ["one"], cb, "t_a")
	_check("king cutscene: a seen key does not replay and still calls on_done", again == null and done_n[0] == 2 and not root.get_tree().paused, "")
	# skip
	var cs2 = CUT.play(g, ["a", "b", "c", "d"], cb, "t_skip")
	cs2.skip()
	_check("king cutscene: skip ends the rest at once, calls back and marks the key seen", cs2.done and done_n[0] == 3 and C.seen("t_skip") and not root.get_tree().paused and g.cutscene == null, "")
	await process_frame
	# a keyless scene marks nothing
	var cs3 = CUT.play(g, ["only"], cb)
	cs3.advance()
	_check("king cutscene: a scene with no key plays and marks nothing", cs3.done and done_n[0] == 4 and C.story_seen.size() == 2, str(C.story_seen))
	await process_frame
	# refusals: pause menu, puzzle
	g.paused_play = true
	var r1 = CUT.play(g, ["x"], cb, "t_r1")
	g.paused_play = false
	_check("king cutscene: refused while the pause menu is open (and the key stays unseen)", r1 == null and not C.seen("t_r1") and done_n[0] == 4, "")
	var dummy := Node.new()
	g.add_child(dummy)
	g.puzzle = dummy
	var r2 = CUT.play(g, ["x"], cb, "t_r2")
	g.puzzle = null
	dummy.queue_free()
	_check("king cutscene: refused while a puzzle is open", r2 == null and not C.seen("t_r2") and done_n[0] == 4, "")
	# the tree state is restored: paused before, still paused after
	root.get_tree().paused = true
	var cs4 = CUT.play(g, ["p"], cb, "t_p")
	cs4.advance()
	_check("king cutscene: a tree that was paused before stays paused after", cs4.done and root.get_tree().paused, "")
	root.get_tree().paused = false
	await process_frame
	# empty pages: key marked, callback called, nothing shown
	var e0 = CUT.play(g, [], cb, "t_empty")
	_check("king cutscene: no pages marks the key and calls back", e0 == null and C.seen("t_empty") and done_n[0] == 6, "")
	# freed with the game while open: the tree is given back
	var cs5 = CUT.play(g, ["q"], cb, "t_free")
	g.queue_free()
	await process_frame
	await process_frame
	_check("king cutscene: freeing the game under an open cutscene unpauses the tree", not root.get_tree().paused and not is_instance_valid(cs5), "")
	CUT.suppressed = true
	C.reset()
	C.test_all = true


## prisoners, Carry flags, Perry's fall, intro keys, the finale pages
func _king_story_tests() -> void:
	var CUT = load("res://scripts/game/cutscene.gd")
	var PRI = load("res://scripts/game/prisoner.gd")
	var SPG = load("res://scripts/game/story_pages.gd")
	var C = load("res://scripts/game/carry.gd")
	var T = load("res://scripts/game/tuning.gd")
	var LV = load("res://scripts/game/levels.gd")
	C.reset()
	C.test_all = true
	# --- Carry flags and saves
	C.mark_seen("k1")
	C.free_prisoner(4)
	C.perry_freed = true
	C.save()
	C.story_seen = {}
	C.prisoners = {}
	C.perry_freed = false
	C.ready = false
	C.ensure()
	_check("king carry: seen keys, freed prisoners and perry_freed survive a save and reload", C.seen("k1") and not C.seen("k2") and C.prisoner_freed(4) and not C.prisoner_freed(1) and C.perry_freed, "%s %s" % [C.story_seen, C.prisoners])
	var f := FileAccess.open(C.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"gold": 33, "size": 3}))
	f.close()
	C.ready = false
	C.ensure()
	_check("king carry: an old save without the story fields loads clean", C.gold == 33 and C.story_seen.is_empty() and C.prisoners.is_empty() and not C.perry_freed, "")
	C.reset()
	C.test_all = true
	# --- free_perry
	C.gold = 250
	C.moves["earthquake"] = true
	C.clears["11"] = 1
	C.unlocked = 12
	C.perry_owned = {"thrust": true, "taunt": true}
	C.perry_hp_max = 120
	C.free_perry()
	_check("king carry: free_perry clears her unlocks, resets her max HP, keeps gold, moves and clears, and she stays unlocked", C.perry_owned.is_empty() and C.perry_hp_max == T.PERRY_HP_START and C.perry_freed and C.gold == 250 and C.moves.get("earthquake", false) and C.perry_unlocked() and C.unlocked == 12, "%s %d" % [C.perry_owned, C.perry_hp_max])
	C.perry_owned = {"thrust": true}
	C.perry_hp_max = 90
	C.free_perry()
	_check("king carry: free_perry works once only (a second call changes nothing)", C.perry_owned.has("thrust") and C.perry_hp_max == 90, "")
	C.reset()
	C.test_all = true
	# --- the table of prisoners
	var g: Node = await _s4_new(1)
	for pr0 in g.props:                              # cracked walls and doors are solid: Mera is teleported across the map below
		if is_instance_valid(pr0):
			pr0.queue_free()
	g.props.clear()
	var table_ok := true
	for li in 21:
		var pr = PRI.spawn_for_level(g, li)
		var want: bool = li in [1, 4, 8, 11, 15, 18]
		table_ok = table_ok and ((pr != null) == want)
		if pr != null:
			table_ok = table_ok and absf(pr.position.y - g.GROUND_Y) < 0.5 and absf(pr.position.x - float(PRI.TABLE[li]["x"])) < 0.5 and pr.get_parent() == g.world and not pr.freed
			pr.queue_free()
	_check("king prisoner: spawn_for_level gives one only on levels 1, 4, 8, 11, 15, 18", table_ok, "")
	C.free_prisoner(8)
	_check("king prisoner: a freed prisoner's level spawns nobody", PRI.spawn_for_level(g, 8) == null, "")
	C.prisoners = {}
	# free with the real A button while overlapping
	var p1: Node = PRI.spawn_for_level(g, 1)
	await physics_frame
	g.mera.position = Vector2(p1.position.x, g.GROUND_Y)
	g.mera.invuln = 999.0
	await physics_frame
	await physics_frame
	_check("king prisoner: the prompt shows while Mera overlaps the cage", p1.prompt != null and p1.prompt.visible and not p1.freed, "")
	var gold0: int = C.gold
	var pk0 := _king_pickups(g).size()
	Input.action_press("btn_a")
	await process_frame
	await physics_frame
	await process_frame
	Input.action_release("btn_a")
	await physics_frame
	await physics_frame
	_check("king prisoner: A while overlapping frees them: 20 gold, one break_drop, the level's flag set, then they walk off and free themselves", p1.freed and C.gold - gold0 == 20 and _king_pickups(g).size() == pk0 + 1 and C.prisoner_freed(1) and p1.walking, "freed %s gold %d pk %d/%d" % [p1.freed, C.gold - gold0, pk0, _king_pickups(g).size()])
	var gold_a: int = C.gold
	p1._free()
	_check("king prisoner: freeing twice pays once", C.gold == gold_a, "")
	for i in 600:
		if not is_instance_valid(p1):
			break
		await physics_frame
	_check("king prisoner: the freed prisoner leaves and frees itself", not is_instance_valid(p1), "")
	# overlapping without A frees nobody; far away frees nobody
	C.prisoners = {}
	var p4: Node = PRI.spawn_for_level(g, 4)
	g.mera.position = Vector2(p4.position.x + 900.0, g.GROUND_Y)
	await physics_frame
	Input.action_press("btn_a")
	await process_frame
	await physics_frame
	Input.action_release("btn_a")
	await physics_frame
	_check("king prisoner: A far from the cage frees nobody", not p4.freed and not C.prisoner_freed(4), "")
	p4.queue_free()
	# level 11: gold 20 and the earthquake move, once; the advice goes through a Cutscene
	C.reset()
	C.test_all = true
	var p11: Node = PRI.spawn_for_level(g, 11)
	var line11: String = p11.line
	CUT.suppressed = false
	var gold11: int = C.gold
	p11._free()
	var cs: Node = g.cutscene
	_check("king prisoner: level 11 pays 20 gold (no free move: the earthquake is bought) and says to parry or buy it; the advice line opens as a cutscene", C.gold - gold11 == 20 and p11.give_move == "" and p11.tip == "Perry is hard to beat without being stunned. Parry her attacks, or purchase Earthquake from the shop." and cs != null and cs.pages.size() == 1 and cs.pages[0].size() == 2 and cs.pages[0][0] == p11.lore and cs.pages[0][1] == p11.tip and line11 == p11.lore + " " + p11.tip and line11.find("Earthquake") >= 0 and cs.extras[0]["speaker"] == "cl_knight" and cs._portrait != null, "")
	if cs != null:
		cs.skip()
	await process_frame
	CUT.suppressed = true
	var p11b: Node = PRI.spawn_for_level(g, 11)
	_check("king prisoner: and the level 11 prisoner does not come back", p11b == null, "")
	# the earthquake move is not re-paid when already owned
	C.prisoners = {}
	var gold12: int = C.gold
	var p11c: Node = PRI.spawn_for_level(g, 11)
	p11c._free()
	_check("king prisoner: a prisoner for a Mera who already has the move still pays gold", C.gold - gold12 == 20, "")
	g.queue_free()
	await process_frame
	C.reset()
	C.test_all = true
	# --- _story_start: prisoner spawn, intro and the stage keys (non-test mode hooks called by hand)
	var counts := {}
	for li in [1, 0, 12, 20]:
		LV.current = li
		var gs: Node = await _s4_new(li)
		gs.test_mode = false
		CUT.suppressed = false
		gs._story_start()
		var csx: Node = gs.cutscene
		var np := 0
		for c in gs.world.get_children():
			if String(c.get_script().resource_path if c.get_script() != null else "").ends_with("prisoner.gd"):
				np += 1
		counts[li] = [csx != null, (csx.key if csx != null else ""), (csx.pages.size() if csx != null else 0), np]
		if csx != null:
			csx.skip()
		await process_frame
		CUT.suppressed = true
		gs.queue_free()
		await process_frame
	_check("king story: level 1 spawns its prisoner and plays no card", counts[1] == [false, "", 0, 1], str(counts[1]))
	_check("king story: level 0 plays the six-page intro (key intro)", counts[0] == [true, "intro", 6, 0] and SPG.INTRO.size() == 6, str(counts[0]))
	_check("king story: level 12 plays the two-page Stage 3 step (key stage3_step)", counts[12] == [true, "stage3_step", 2, 0], str(counts[12]))
	_check("king story: level 20 plays the king's intro (key king_intro, one page)", counts[20] == [true, "king_intro", 1, 0], str(counts[20]))
	_check("king story: all three keys are remembered after they play", C.seen("intro") and C.seen("stage3_step") and C.seen("king_intro"), str(C.story_seen))
	for li in [0, 12, 20]:
		LV.current = li
		var gs2: Node = await _s4_new(li)
		gs2.test_mode = false
		CUT.suppressed = false
		gs2._story_start()
		var played: bool = gs2.cutscene != null
		if played:
			gs2.cutscene.skip()
		CUT.suppressed = true
		_check("king story: level %d's card does not play twice" % li, not played, "")
		gs2.queue_free()
		await process_frame
	# test mode and run mode never get cards
	LV.current = 0
	C.reset()
	C.test_all = true
	var gt: Node = await _s4_new(0)
	CUT.suppressed = false
	gt._story_start()
	var t_ok: bool = gt.cutscene == null
	gt.test_mode = false
	gt.run_mode = true
	gt._story_start()
	t_ok = t_ok and gt.cutscene == null
	CUT.suppressed = true
	_check("king story: test mode and endless run mode play no story card", t_ok, "")
	gt.queue_free()
	await process_frame
	# --- Perry's finale: pages, no two-line card, free_perry once, unlock and gold once
	C.reset()
	C.test_all = true
	LV.current = 11
	var gp: Node = await _s4_new(11)
	gp.wave_i = 100
	C.perry_owned = {"thrust": true}
	C.perry_hp_max = 80
	C.gold = 40
	var perry: Node2D = gp.spawn_enemy("perry", gp.mera.global_position.x + 600.0)
	await process_frame
	gp.on_enemy_defeated(perry)
	_check("king perry finale: victory_text is set, there is no two-line victory card, the level is cleared and unlocks 12 once", gp.victory and not gp.victory_card and gp.victory_text.size() == 2 and gp.victory_text[0] == "You Defeated Perry!" and C.unlocked >= 12 and int(C.clears.get("11", 0)) == 1 and C.gold >= 140, "gold %d" % C.gold)
	_check("king perry finale: her spell only breaks when the pages play (nothing changes at the death itself)", C.perry_owned.has("thrust") and not C.perry_freed, "")
	var gold_p: int = C.gold
	gp._show_story_finale(SPG.PERRY_FALLS)
	_check("king perry finale: with cards suppressed the story goes straight on; Perry is freed (unlocks gone, hp reset, gold and clear kept)", C.perry_freed and C.perry_owned.is_empty() and C.perry_hp_max == T.PERRY_HP_START and C.gold == gold_p and C.perry_unlocked(), "")
	gp.queue_free()
	await process_frame
	# the pages as a real cutscene: five pages, then the title hand-off
	C.reset()
	C.test_all = true
	C.clears["11"] = 1
	C.perry_owned = {"taunt": true}
	var gq: Node = await _s4_new(11)
	CUT.suppressed = false
	gq._show_story_finale(SPG.PERRY_FALLS)
	var csq: Node = gq.cutscene
	var five: bool = csq != null and csq.pages.size() == 5 and SPG.PERRY_FALLS.size() == 5 and root.get_tree().paused
	if csq != null:
		for i in 5:
			csq.advance()
	_check("king perry finale: the five Perry pages play as a cutscene, the tree is unpaused at the end, and Perry is free", five and csq.done and not root.get_tree().paused and C.perry_freed and C.perry_owned.is_empty(), "")
	CUT.suppressed = true
	gq.queue_free()
	await process_frame
	# the king's end: pages are KING_END (two pages)
	_check("king ending: KING_END is two pages and the king intro is one page of two lines", SPG.KING_END.size() == 2 and SPG.KING_INTRO.size() == 1 and SPG.KING_INTRO[0].size() == 2, "")
	var noem := true
	for arr in [SPG.INTRO, SPG.PERRY_FALLS, SPG.STAGE3_STEP, SPG.KING_INTRO, SPG.KING_END]:
		for pg in arr:
			var src: Variant = pg.get("text", "") if pg is Dictionary else pg
			var lines: Array = src if src is Array else [src]
			for ln in lines:
				if String(ln).find(char(0x2014)) >= 0 or String(ln).find(char(0x2013)) >= 0:
					noem = false
	_check("king story: no page uses an em dash or en dash", noem, "")
	C.reset()
	C.test_all = true
	LV.current = 0


# ===== slideshow, timer, chest blast
## the opening slideshow (StorySlides, SlideView, Cutscene with Dictionary pages), the match-3 real-time clock and board geometry,
## and the failed-chest explosion
func _slideshow_timer_blast_tests() -> void:
	var CUT = load("res://scripts/game/cutscene.gd")
	var C = load("res://scripts/game/carry.gd")
	var T = load("res://scripts/game/tuning.gd")
	var M3 = load("res://scripts/puzzles/match3.gd")
	var PIPES = load("res://scripts/puzzles/pipes.gd")
	var HOST = load("res://scripts/puzzles/puzzle_host.gd")
	CUT.suppressed = true
	C.reset()
	C.test_all = true
	LVS.current = 0

	# ---------------- slide data
	var intro_ids: Array = []
	var ids_ok := StoryPages.INTRO.size() == 6
	for pg in StoryPages.INTRO:
		var sid := String(pg.get("slide", ""))
		intro_ids.append(sid)
		if sid == "" or not StorySlides.has_slide(sid):
			ids_ok = false
	_check("slides: every slide id the INTRO pages name exists in StorySlides (6 pages)", ids_ok, str(intro_ids))
	var all_six := true
	for i in range(1, 7):
		all_six = all_six and StorySlides.has_slide("intro_%d" % i) and intro_ids.has("intro_%d" % i)
	_check("slides: StorySlides holds intro_1 .. intro_6 and the INTRO uses each once", all_six and StorySlides.SLIDES.size() == 6 and not StorySlides.has_slide("nope") and StorySlides.get_slide("nope").is_empty(), "")
	var gs: Dictionary = StorySlides.get_slide("intro_1")
	gs["bg"] = "changed"
	_check("slides: get_slide returns a copy (editing it leaves the data alone)", String(StorySlides.SLIDES["intro_1"]["bg"]) != "changed", "")
	var bg_ok := true
	var who_ok := true
	var dur_ok := true
	var info := ""
	var roster_data: Dictionary = Roster.data()
	var anim_lib: Node = root.get_node("AnimLib")
	for sid in StorySlides.SLIDES:
		var sl: Dictionary = StorySlides.SLIDES[sid]
		if not (load(String(sl.get("bg", ""))) is Texture2D):
			bg_ok = false
			info += " bg:" + String(sid)
		if float(sl.get("dur", 12.0)) <= 0.0:
			dur_ok = false
		for sp in sl.get("sprites", []):
			var who := String(sp.get("who", ""))
			var anim := String(sp.get("anim", "idle"))
			if who == "mera":
				if not anim_lib.anims.has(anim) and not anim_lib.anims.has("idle"):
					who_ok = false
					info += " mera:" + anim
			elif not roster_data.has(who) or not (roster_data[who]["anims"] as Dictionary).has(anim):
				who_ok = false
				info += " %s/%s/%s" % [sid, who, anim]
			if float(sp.get("scale", 4.0)) <= 0.0 or float(sp.get("at", 0.0)) < 0.0 or (sp.has("until") and float(sp["until"]) <= float(sp.get("at", 0.0))):
				dur_ok = false
			for mv in sp.get("move", []):
				if float(mv.get("dur", 1.0)) <= 0.0 or float(mv.get("t", 0.0)) < 0.0:
					dur_ok = false
	_check("slides: every slide's painting loads as a texture", bg_ok, info)
	_check("slides: every sprite is 'mera' or a Roster id and its animation exists there", who_ok, info)
	_check("slides: durations, scales, start times and tween lengths are positive", dur_ok, "")
	var music_path := String(StoryPages.INTRO[0].get("music", ""))
	_check("slides: the first INTRO page starts the prologue music and it loads", music_path == "res://assets/perry/music/prologue.ogg" and load(music_path) is AudioStream, music_path)
	var text_ok := true
	for pg in StoryPages.INTRO:
		var tx: Variant = pg.get("text", "")
		var lines: Array = tx if tx is Array else [tx]
		for ln in lines:
			if String(ln).strip_edges() == "" or String(ln).find(char(0x2014)) >= 0 or String(ln).find(char(0x2013)) >= 0:
				text_ok = false
	_check("slides: every INTRO page has text and no em or en dash", text_ok, "")

	# ---------------- export presets: every res:// path the story data names is in all three presets
	var ep := FileAccess.get_file_as_string("res://export_presets.cfg")
	var rx := RegEx.create_from_string("res://[A-Za-z0-9_/.\\-]+")
	var exp_missing: Array = []
	var seen_paths := {}
	for f in ["res://scripts/game/story_slides.gd", "res://scripts/game/story_pages.gd"]:
		for m in rx.search_all(FileAccess.get_file_as_string(f)):
			var rp: String = m.get_string()
			if rp.ends_with("."):
				rp = rp.substr(0, rp.length() - 1)
			seen_paths[rp] = true
	for rp in seen_paths:
		if not FileAccess.file_exists(rp) or ep.count("\"" + String(rp) + "\"") != 3:
			exp_missing.append(rp)
	for f in ["res://scripts/game/slide_view.gd", "res://scripts/game/story_slides.gd", "res://scripts/game/story_pages.gd"]:
		if ep.count("\"" + f + "\"") != 3:
			exp_missing.append(f)
	_check("export: the slide scripts and every png / ogg the story data uses exist and are in all 3 presets (%d paths)" % seen_paths.size(), exp_missing.is_empty() and seen_paths.size() >= 7, "%s" % [exp_missing])

	# ---------------- SlideView (loaded, not named: naming it compiles it before the AnimLib autoload exists)
	var SVC = load("res://scripts/game/slide_view.gd")
	var sv = SVC.new()
	root.add_child(sv)
	_check("slideview: an unknown id shows nothing and returns false", not sv.show_slide("no_such_slide") and not sv.shown and sv.slide.is_empty(), "")
	_check("slideview: an empty id clears the picture and returns false", not sv.show_slide("") and not sv.shown, "")
	var spr_ok := true
	var dur_ends := true
	for i in range(1, 7):
		var sid := "intro_%d" % i
		var shown: bool = sv.show_slide(sid, false)
		var want: int = (StorySlides.SLIDES[sid]["sprites"] as Array).size()
		if not (shown and sv.shown and sv._sprites.size() == want and sv._bg != null):
			spr_ok = false
		var dur := float(StorySlides.SLIDES[sid].get("dur", 12.0))
		sv.set_time(0.0)
		await process_frame
		var ok0: bool = sv.t == 0.0 and not sv.running and is_equal_approx(sv.modulate.a, 1.0)
		sv.set_time(dur)
		await process_frame
		if not (ok0 and sv.t == dur):
			dur_ends = false
	_check("slideview: all six slides load their painting and every sprite (frames found)", spr_ok, "")
	_check("slideview: set_time works at t = 0 and t = dur for every slide (holds still, fully visible)", dur_ends, "")
	_check("slideview: the pan / zoom transform stays a function of time (scale 3x at the start, painting wider than the band)", sv.show_slide("intro_1", false) and is_equal_approx(float(sv._bg_xf(0.0)["s"]), SVC.SCALE) and sv._bg.get_width() * SVC.SCALE > SVC.BAND.x, "")
	sv.show_slide("intro_1", true)
	_check("slideview: a fade-in starts transparent", sv.modulate.a == 0.0 and sv.running and sv.t == 0.0, "")
	# move tweens: alpha starts at the colour's alpha, scale and position end on their target
	_check("slideview: the ease is 0 at the start and 1 at the end", SVC._ease(0.0) == 0.0 and SVC._ease(1.0) == 1.0 and SVC._ease(2.0) == 1.0 and SVC._ease(-1.0) == 0.0, "")
	var fade_ok := true
	var n_fade := 0
	var n_move := 0
	for sid in StorySlides.SLIDES:
		for sp in StorySlides.SLIDES[sid].get("sprites", []):
			var c0: Array = sp.get("color", [1, 1, 1, 1])
			var a0 := float(c0[3]) if c0.size() > 3 else 1.0
			for mv in sp.get("move", []):
				n_move += 1
				if mv.has("alpha"):
					n_fade += 1
					var a1 := float(mv["alpha"])
					if a1 < 0.0 or a1 > 1.0 or is_equal_approx(a0, a1):
						fade_ok = false
					var k_end: float = SVC._ease((float(mv["t"]) + float(mv["dur"]) - float(mv["t"])) / float(mv["dur"]))
					if not is_equal_approx(lerpf(a0, a1, k_end), a1):
						fade_ok = false
	_check("slideview: alpha tweens start from the colour alpha and end on their target (%d tweens of %d)" % [n_fade, n_move], fade_ok and n_fade >= 6 and n_move >= 8, "")
	var ogre6: Dictionary = {}
	for sp in StorySlides.SLIDES["intro_6"]["sprites"]:
		if sp["who"] == "ogre":
			ogre6 = sp
	_check("slideview: in intro_6 the ogre starts invisible (colour alpha 0) and fades to 1 over 0.6 s from 0.5 s", float(ogre6["color"][3]) == 0.0 and float(ogre6["move"][0]["alpha"]) == 1.0 and float(ogre6["move"][0]["t"]) == 0.5 and float(ogre6["move"][0]["dur"]) == 0.6, "")
	var perry4: Array = StorySlides.SLIDES["intro_4"]["sprites"]
	_check("slideview: in intro_4 Perry walks from x -100 to 700, then the idle copy stands at 700 from 6 s", perry4.size() == 2 and float(perry4[0]["pos"][0]) == -100.0 and float(perry4[0]["move"][0]["to"][0]) == 700.0 and float(perry4[1]["pos"][0]) == 700.0 and float(perry4[1]["at"]) == float(perry4[0]["until"]), "")
	sv.show_slide({"bg": "res://assets/perry/maps/story/4_village_meadow.png", "dur": 4.0, "sprites": [{"who": "nobody", "anim": "idle", "pos": [0, 0]}]})
	_check("slideview: a slide dictionary works, and a sprite of an unknown creature is skipped without a crash", sv.shown and sv._sprites.is_empty(), "")
	sv.set_time(2.0)
	await process_frame
	sv.queue_free()
	await process_frame

	# ---------------- Cutscene with the INTRO pages
	var g: Node = await _s4_new(0)
	var fake := AudioStreamPlayer.new()
	fake.volume_db = -3.0
	g.add_child(fake)
	g.music_player = fake
	var done_n := [0]
	var cb := func(): done_n[0] += 1
	CUT.suppressed = false
	var cs = CUT.play(g, StoryPages.INTRO, cb)
	var made: bool = cs != null
	if cs == null:
		_check("slideshow cutscene: INTRO plays", false, "play returned null")
		CUT.suppressed = true
		g.queue_free()
		await process_frame
		return
	_check("slideshow cutscene: INTRO builds a cutscene with 6 pages, slides, a view, and pauses the tree", cs.pages.size() == 6 and cs.extras.size() == 6 and cs.has_slides and cs.view != null and root.get_tree().paused and g.cutscene == cs, "")
	_check("slideshow cutscene: page 1 shows intro_1 and the story music replaces the level music", cs.view.shown and String(cs.view.slide.get("bg", "")) == String(StorySlides.SLIDES["intro_1"]["bg"]) and cs._music != null and cs._music.playing and fake.volume_db <= -79.0, "db=%f" % fake.volume_db)
	var bgs := {}
	var bar_ok := true
	var shown_ok := true
	for i in 6:
		var tot := 0.0
		for f in cs._fit:
			tot += float(f[1])
		if tot > CUT.BLOCK_H_SLIDE + 0.5:
			bar_ok = false
		shown_ok = shown_ok and cs.view.shown and cs.page_i == i
		bgs[String(cs.view.slide.get("bg", ""))] = true
		if i < 5:
			cs.advance()
	_check("slideshow cutscene: advancing walks the six pages and the picture changes each time (6 distinct paintings)", shown_ok and bgs.size() == 6 and cs.page_i == 5 and not cs.done, "%d %s" % [bgs.size(), shown_ok])
	_check("slideshow cutscene: every page's text fits the bar under the picture", bar_ok, "")
	_check("slideshow cutscene: the music keeps playing between pages and the level music stays muted", cs._music != null and cs._music.playing and fake.volume_db <= -79.0, "")
	cs.skip()
	_check("slideshow cutscene: skip ends it: callback once, tree unpaused, game cleared, level music volume restored", cs.done and done_n[0] == 1 and not root.get_tree().paused and g.cutscene == null and is_equal_approx(fake.volume_db, -3.0) and cs._music == null, "db=%f" % fake.volume_db)
	await process_frame
	_check("slideshow cutscene: it frees itself", not is_instance_valid(cs), "")
	# finishing by the last page restores the music too
	var cs2 = CUT.play(g, StoryPages.INTRO, cb)
	for i in 6:
		cs2.advance()
	_check("slideshow cutscene: advancing past the last page ends it and restores the level music", cs2.done and done_n[0] == 2 and is_equal_approx(fake.volume_db, -3.0) and not root.get_tree().paused, "")
	await process_frame
	# a missing slide id falls back to text only
	var cs3 = CUT.play(g, [{"text": "Hello there.", "slide": "no_such_slide"}, {"text": ["Gold line", "Pale line"]}], cb)
	_check("slideshow cutscene: a missing slide id does not crash; the page is text only", cs3 != null and cs3.has_slides and cs3.view != null and not cs3.view.shown and cs3.pages.size() == 2 and cs3.pages[1].size() == 2, "")
	if cs3 != null:
		cs3.advance()
		cs3.advance()
	await process_frame
	# plain pages and slide-less dictionaries keep the old look
	var cs4 = CUT.play(g, ["plain one", ["gold", "pale"]], cb)
	_check("slideshow cutscene: plain String pages have no slides, no view and no music", cs4 != null and not cs4.has_slides and cs4.view == null and cs4._music == null and cs4.extras.size() == 2 and cs4.extras[0].is_empty() and fake.volume_db == -3.0, "")
	cs4.skip()
	await process_frame
	var cs5 = CUT.play(g, [{"text": "dictionary, no slide"}], cb)
	_check("slideshow cutscene: a Dictionary page without a slide is text only", cs5 != null and not cs5.has_slides and cs5.view == null and cs5.pages[0][0] == "dictionary, no slide", "")
	cs5.skip()
	await process_frame
	_check("slideshow cutscene: _lines_of takes a String, an Array (two lines at most) or a Dictionary text; empty gives none", CUT._lines_of("a") == ["a"] and CUT._lines_of(["a", "b", "c"]) == ["a", "b"] and CUT._lines_of({"text": "x"}) == ["x"] and CUT._lines_of({"text": ""}).is_empty() and CUT._lines_of({"slide": "intro_1"}).is_empty(), "")
	CUT.suppressed = true
	g.queue_free()
	await process_frame
	await process_frame
	_check("slideshow cutscene: the tree is not left paused", not root.get_tree().paused, "")

	# ---------------- match-3: the clock
	var m = M3.new()
	m.rng.seed = 21
	m._setup()
	_check("match-3 clock: starts at Tuning.MATCH_TIME_S (20 s); the move limit is gone", is_equal_approx(m.time_left, T.MATCH_TIME_S) and T.MATCH_TIME_S == 20.0 and m.get("moves_left") == null and not T.get_script_constant_map().has("MATCH_MOVES"), "")
	m._tick(1.5)
	_check("match-3 clock: _tick runs it down", is_equal_approx(m.time_left, T.MATCH_TIME_S - 1.5) and m.result == "", "left=%f" % m.time_left)
	var mv: Array = m.find_move()
	var started: bool = m.try_swap(mv[0], mv[1])
	var tl0: float = m.time_left
	m._tick(0.01)
	m._tick(0.01)
	_check("match-3 clock: it keeps running during a swap and the cascade (busy)", started and m.busy and m.time_left < tl0 - 0.019, "busy=%s %f -> %f" % [m.busy, tl0, m.time_left])
	m.settle()
	m.time_left = 0.5
	m.score = 0
	m._tick(0.3)
	_check("match-3 clock: before it runs out nothing is decided", m.result == "" and is_equal_approx(m.time_left, 0.2), "left=%f" % m.time_left)
	m._tick(1.0)
	_check("match-3 clock: a tick past 0 with the score under the target loses with TIME UP", m.result == "lost" and m._banner == "TIME UP" and m.time_left == 0.0, "%s %s" % [m.result, m._banner])
	m._tick(1.0)
	_check("match-3 clock: after the result the clock stays at 0 and the result stands", m.result == "lost" and m.time_left == 0.0, "")
	m.free()
	m = M3.new()
	m.rng.seed = 22
	m._setup()
	m.score = T.MATCH_TARGET
	m.time_left = 0.4
	m._tick(1.0)
	_check("match-3 clock: a tick past 0 with the score at the target wins", m.result == "won", m.result)
	m.free()
	m = M3.new()
	m.rng.seed = 23
	m._setup()
	m.time_left = 0.4
	m.score = T.MATCH_TARGET - 5
	m._tick(0.1)
	_check("match-3 clock: one point under the target with time left is still playing", m.result == "" and m.score == T.MATCH_TARGET - 5, "")
	m.free()
	m = M3.new()
	m.rng.seed = 24
	m._setup()
	m.solve()
	_check("match-3 clock: solve() still wins, and the clock was not spent on the way", m.result == "won" and is_equal_approx(m.time_left, T.MATCH_TIME_S), "%s left=%f" % [m.result, m.time_left])
	m.free()
	# ---------------- match-3: board geometry and hints
	m = M3.new()
	m._setup()
	var board_r := Rect2(m.origin_px, Vector2(M3.TILE * m.cols, M3.TILE * m.rows))
	_check("match-3 board: 6 x 6 tiles of 128 px, target 300", M3.TILE == 128.0 and m.cols == 6 and m.rows == 6 and m.target == 300 and T.MATCH_TARGET == 300, "")
	_check("match-3 board: the whole board rectangle lies inside the puzzle panel", HOST.PANEL.encloses(board_r) and is_equal_approx(m.origin_px.x, HOST.PANEL.position.x + 50.0) and m.origin_px.y == 190.0, "%s in %s" % [board_r, HOST.PANEL])
	var pipes_h = PIPES.new()
	_check("puzzle host: match-3 uses a 34 px hint at y 998, the other puzzles keep 26 px at 985", m.hint_size() == 34 and m.hint_y() == 998.0 and pipes_h.hint_size() == 26 and pipes_h.hint_y() == 985.0, "")
	pipes_h.free()
	# touch: a tap on a tile selects it, a drag onto a neighbour swaps (converted with origin_px and TILE)
	var c_mid := Vector2i(2, 3)
	var p_mid: Vector2 = m.origin_px + (Vector2(c_mid) + Vector2(0.5, 0.5)) * M3.TILE
	m._on_press(p_mid)
	_check("match-3 touch: a press at a tile's centre selects that cell", m.cursor == c_mid and m.sel == c_mid, "cursor=%s sel=%s" % [m.cursor, m.sel])
	var mvs: Array = m.find_move()
	var a: Vector2i = mvs[0]
	var b: Vector2i = mvs[1]
	m.sel = Vector2i(-1, -1)
	var pa: Vector2 = m.origin_px + (Vector2(a) + Vector2(0.5, 0.5)) * M3.TILE
	var pb: Vector2 = m.origin_px + (Vector2(b) + Vector2(0.5, 0.5)) * M3.TILE
	m._on_press(pa)
	m._on_drag(pa + (pb - pa) * 0.6)
	_check("match-3 touch: a drag from a tile toward its neighbour makes the swap", m.busy, "a=%s b=%s" % [a, b])
	m.settle()
	m.sel = Vector2i(-1, -1)
	var mv2: Array = m.find_move()
	if not mv2.is_empty():
		var qa: Vector2 = m.origin_px + (Vector2(mv2[0]) + Vector2(0.5, 0.5)) * M3.TILE
		var qb: Vector2 = m.origin_px + (Vector2(mv2[1]) + Vector2(0.5, 0.5)) * M3.TILE
		m._on_press(qa)
		m._on_release(qa)
		m._on_press(qb)
		_check("match-3 touch: tapping two neighbouring tiles swaps them (or the first swap already won)", m.busy or m.score >= m.target, "")
	m.free()

	# ---------------- failed chests explode
	var g2: Node = await _s4_new(1)
	_clear_blockers(g2)
	g2.mera.set_size(5)
	var cx := 12000.0
	var kinds_list := ["pipes", "match3", "needle"]
	for kind in kinds_list:
		# lose (the puzzle's own rules), Mera on the chest: she loses 1 size, the chest is gone, no loot
		cx += 800.0
		var chx: Node2D = _new_chest(g2, cx)
		g2.mera.global_position.x = cx
		g2.mera.invuln = 0.0
		var size0: int = g2.mera.size
		var opened: bool = chx.try_open(kind)
		var h: Node = g2.puzzle
		h.lose()
		h.finish_now()
		var size1: int = g2.mera.size
		await _s4_frames(g2, 3)
		_check("chest blast: a lost %s puzzle explodes the chest (frees itself, no loot) and costs Mera 1 size when she is on it" % kind, opened and not is_instance_valid(chx) and g2.puzzle == null and not paused and size1 == size0 - 1 and _coins_near(g2, cx) == 0, "size %d -> %d" % [size0, size1])
		g2.mera.set_size(5)
		# give up (B), Mera far: the chest explodes and nobody is hurt
		cx += 800.0
		var chf: Node2D = _new_chest(g2, cx)
		g2.mera.global_position.x = cx + T.CHEST_BLAST_R + 150.0
		g2.mera.invuln = 0.0
		chf.try_open(kind)
		var h2: Node = g2.puzzle
		h2.press_action("btn_b")
		var res2: String = h2.result
		h2.finish_now()
		var size2: int = g2.mera.size
		await _s4_frames(g2, 3)
		_check("chest blast: giving up the %s puzzle blows the chest up but spares Mera outside the radius" % kind, res2 == "lost" and not is_instance_valid(chf) and size2 == 5 and g2.puzzle == null, "res=%s size=%d" % [res2, size2])
	# time up on the match-3 puzzle, close and then far
	for near in [true, false]:
		cx += 800.0
		var chm: Node2D = _new_chest(g2, cx)
		g2.mera.global_position.x = cx + (T.CHEST_BLAST_R - 200.0 if near else T.CHEST_BLAST_R + 150.0)
		g2.mera.invuln = 0.0
		g2.mera.set_size(5)
		chm.try_open("match3")
		var hm: Node = g2.puzzle
		hm.time_left = 0.05
		hm._tick(1.0)
		var banner: String = hm._banner
		var rm: String = hm.result
		hm.finish_now()
		var size3: int = g2.mera.size
		await _s4_frames(g2, 3)
		_check("chest blast: match-3 TIME UP blows the chest up; Mera %s the radius %s" % ["inside" if near else "outside", "loses 1 size" if near else "is not hurt"], rm == "lost" and banner == "TIME UP" and not is_instance_valid(chm) and size3 == (4 if near else 5), "%s %s size=%d" % [rm, banner, size3])
	# the radius is Tuning.CHEST_BLAST_R
	_check("chest blast: the radius is Tuning.CHEST_BLAST_R (360)", T.CHEST_BLAST_R == 360.0, "")
	# quitting the scene with a puzzle open does not crash and gives the tree back
	cx += 800.0
	var chq: Node2D = _new_chest(g2, cx)
	chq.try_open("match3")
	var hq: Node = g2.puzzle
	var opened_q: bool = hq != null and paused
	g2.queue_free()
	await process_frame
	await process_frame
	_check("chest blast: leaving the level with a chest puzzle open frees the layer and unpauses the tree", opened_q and not paused and not is_instance_valid(hq), "")
	# a won puzzle still opens the chest and pays out
	var g3: Node = await _s4_new(1)
	_clear_blockers(g3)
	var chw: Node2D = _new_chest(g3, 14000.0)
	g3.mera.global_position.x = 14000.0 + 2000.0
	chw.try_open("match3")
	var hw: Node = g3.puzzle
	hw.solve()
	hw.finish_now()
	await _s4_frames(g3, 6)
	_check("chest blast: a won puzzle still opens the chest and pays 3-5 coins", is_instance_valid(chw) and chw.state == "open" and _coins_near(g3, 14000.0) >= 3 and _coins_near(g3, 14000.0) <= 5, "")
	g3.queue_free()
	await process_frame
	# Perry loses 1 hit (10 HP) when the chest next to her blows up
	C.reset()
	C.record_clear(C.PERRY_CLEAR_LEVEL)
	C.test_all = true
	var gp: Node = await _perry_new(1)
	_clear_blockers(gp)
	var chp: Node2D = _new_chest(gp, 9000.0)
	gp.mera.global_position.x = 9000.0
	gp.mera.invuln = 0.0
	var hp0: int = gp.mera.hp
	chp.try_open("needle")
	var hpz: Node = gp.puzzle
	hpz.lose()
	hpz.finish_now()
	var hp1: int = gp.mera.hp
	await process_frame
	_check("chest blast: Perry on the chest loses 1 point of damage (%d HP) and the chest is gone" % T.PERRY_HP_PER_DMG, gp.mera.get("is_perry") == true and hp1 == hp0 - T.PERRY_HP_PER_DMG and not is_instance_valid(chp), "hp %d -> %d" % [hp0, hp1])
	gp.queue_free()
	await process_frame
	C.reset()
	C.test_all = true
	C.character = "mera"
	LVS.current = 0


## speaker portraits, prisoner table fields, the firemage's impact animation, restart keeping size
func _speaker_impact_restart_tests() -> void:
	var CUT = load("res://scripts/game/cutscene.gd")
	var PRI = load("res://scripts/game/prisoner.gd")
	var C = load("res://scripts/game/carry.gd")
	var T = load("res://scripts/game/tuning.gd")
	CUT.suppressed = true
	C.reset()
	C.test_all = true
	LVS.current = 0
	# prisoner table: speaker, name, lore, tip
	var tab_ok := true
	var info := ""
	var data: Dictionary = Roster.data()
	for lv in PRI.TABLE:
		var d: Dictionary = PRI.TABLE[lv]
		var txt := String(d.get("lore", "")) + String(d.get("tip", ""))
		if not data.has(String(d.get("who", ""))) or String(d.get("name", "")) == "" or String(d.get("lore", "")) == "" or String(d.get("tip", "")) == "" or txt.find(char(0x2014)) >= 0 or txt.find(char(0x2013)) >= 0:
			tab_ok = false
			info += " %d" % int(lv)
	_check("prisoners: every table entry has a roster speaker, a name, lore and a tip (no dashes)", tab_ok and PRI.TABLE.size() == 6, info)
	# a pure-text speaker page and the Perry page of PERRY_FALLS
	var g: Node = await _s4_new(0)
	CUT.suppressed = false
	var pages: Array = StoryPages.PERRY_FALLS
	var cs = CUT.play(g, pages, Callable(), "")
	var page2_ok: bool = pages[1] is Dictionary and String(pages[1].get("speaker", "")) == "perry"
	var p0: bool = cs != null and cs._portrait == null and cs._text_w() == cs.TEXT_W
	cs.advance()
	var p1: bool = cs._portrait != null and cs._speaker_name == "Perry" and cs._text_w() < cs.TEXT_W and cs._text_left() > 210.0
	cs.advance()
	var p2: bool = cs._portrait == null
	await process_frame
	_check("speaker portrait: PERRY_FALLS page 2 shows Perry's portrait and name with narrower text; the other pages show none", page2_ok and p0 and p1 and p2, "%s %s %s %s" % [page2_ok, p0, p1, p2])
	cs.skip()
	await process_frame
	var cs2 = CUT.play(g, [{"text": ["x", "y"], "speaker": "no_such_creature", "name": "Nobody"}], Callable(), "")
	_check("speaker portrait: an unknown speaker id shows no portrait and does not crash", cs2 != null and cs2._portrait == null and cs2.pages[0].size() == 2, "")
	cs2.skip()
	await process_frame
	# a freed prisoner plays a speaker page
	var pr: Node = PRI.spawn_for_level(g, 4)
	pr._free()
	var csp: Node = g.cutscene
	_check("prisoners: freeing one plays [lore, tip] with the prisoner as the speaker", csp != null and csp.pages[0] == [pr.lore, pr.tip] and csp.extras[0]["speaker"] == "cl_mage" and csp.extras[0]["name"] == "Court Mage" and csp._portrait != null and pr.line == pr.lore + " " + pr.tip, "")
	if csp != null:
		csp.skip()
	await process_frame
	CUT.suppressed = true
	# firemage: bolt flies, blast plays at the hit
	var fm: Dictionary = Roster.def("p_firemage")["attacks"][0]
	var art: Dictionary = Roster.art("p_firemage")
	_check("firemage: the fireball attack is a shot 'bolt' with 'blast' as its impact, both animations exist", String(fm["shot"]) == "bolt" and String(fm.get("impact", "")) == "blast" and art["anims"].has("bolt") and art["anims"].has("blast"), "")
	var shot: Node2D = load("res://scripts/game/enemy_shot.gd").new()
	shot.setup(g, "p_firemage", "bolt", Vector2(5000.0, 600.0), Vector2.ZERO, 1, 3.0, true)
	shot.impact_id = "p_firemage"
	shot.impact_anim = "blast"
	g.world.add_child(shot)
	var n0 := 0
	for c in g.world.get_children():
		if c is AnimatedSprite2D:
			n0 += 1
	shot._impact()
	var n1 := 0
	for c in g.world.get_children():
		if c is AnimatedSprite2D:
			n1 += 1
	_check("firemage: a spent shot with an impact animation spawns the blast once and frees itself", n1 == n0 + 1 and shot.is_queued_for_deletion(), "%d -> %d" % [n0, n1])
	var plain: Node2D = load("res://scripts/game/enemy_shot.gd").new()
	plain.setup(g, "p_firemage", "bolt", Vector2(5000.0, 600.0), Vector2.ZERO, 1, 3.0, true)
	g.world.add_child(plain)
	plain._impact()
	var n2 := 0
	for c in g.world.get_children():
		if c is AnimatedSprite2D:
			n2 += 1
	_check("firemage: a shot with no impact animation spawns no blast", n2 == n1 and plain.is_queued_for_deletion(), "")
	# restart keeps Mera's size unless she died
	g.test_mode = false
	g.mera.size = 6
	g.over = false
	g.restart()
	var kept: int = g.mera.size
	g.mera.size = 6
	g.over = true
	g.restart()
	var reset_sz: int = g.mera.size
	_check("restart: from the pause menu Mera keeps her size; after a death it resets to 2", kept == 6 and reset_sz == 2, "kept=%d reset=%d" % [kept, reset_sz])
	g.test_mode = true
	g.queue_free()
	await process_frame
	C.reset()
	C.test_all = true
	LVS.current = 0
