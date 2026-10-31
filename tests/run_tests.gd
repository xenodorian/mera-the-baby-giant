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
	_check("plain joypad Start (no trigger) still toggles the controls overlay", g.hud.overlay != ov0, "overlay=%s" % g.hud.overlay)
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
	var struck := false
	await _kdrive([[2, KEY_1, true], [2, KEY_2, true], [6, KEY_1, false], [6, KEY_2, false]], 10)
	for i in 80:
		await physics_frame
		if is_instance_valid(g.last_strike):
			struck = true
	_check("keyboard: 1+2 at full rage -> lightning", struck and m.rage == 0.0, "rage=%f" % m.rage)
	m.rage = 100.0
	await _kdrive([[2, KEY_2, true], [8, KEY_2, false]], 24)
	_check("keyboard: 2 alone -> Fury (costs 100)", m.fury and m.rage == 0.0, "rage=%f" % m.rage)
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
	# ---- specials: L2 = bubble, L2+R2 = lightning, R2 alone = Fury (costs 100)
	s = []; _tap(s, 5, "l2")
	await _combo("L2 tap -> bubble pose, not a separate move", s, 40, ["heal"], [])
	var gr: Node = await _new_game()
	gr.mera.rage = 100.0
	gr.last_strike = null
	await _drive(gr, [[5, "l2", true], [8, "l2", false]], 30)
	_check("L2 tap does not spend rage or strike", gr.last_strike == null and gr.mera.rage == 100.0 and not gr.mera.fury, "rage=%f" % gr.mera.rage)
	var struck := false
	await _drive(gr, [[5, "l2", true], [5, "r2", true], [8, "l2", false], [8, "r2", false]], 10)
	for _f in 80:
		await physics_frame
		if is_instance_valid(gr.last_strike):
			struck = true
	_check("L2+R2 spends the meter and strikes", gr.mera.rage == 0.0 and not gr.mera.rage_spending and struck and not gr.mera.fury, "rage=%f struck=%s" % [gr.mera.rage, struck])
	gr.mera.rage = 180.0
	gr.mera.rage_max = 200.0
	await _drive(gr, [[5, "r2", true], [12, "r2", false]], 24)
	_check("R2 alone starts Fury and spends only 100 rage", gr.mera.fury and absf(gr.mera.rage - 80.0) < 0.1, "rage=%f fury=%s" % [gr.mera.rage, gr.mera.fury])
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
			_check("%s then %s %d ms later -> lightning, not Fury" % [order[0], order[1], int(gap * 16.7)], "lightning" in gr.mera.move_keys and not gr.mera.fury, "keys=%s fury=%s" % [gr.mera.move_keys, gr.mera.fury])
			gr.queue_free()
			await process_frame
	gr = await _new_game()
	gr.mera.rage = 100.0
	await _drive(gr, [[5, "l2", true]], 80)
	gr.last_strike = null
	await _drive(gr, [[3, "r2", true], [6, "r2", false]], 50)
	_check("R2 while holding the L2 bubble -> lightning, bubble stays", gr.mera.barrier_on and gr.last_strike != null and not gr.mera.fury, "on=%s strike=%s" % [gr.mera.barrier_on, gr.last_strike])
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
	_check("L2+R2 in the air -> lightning, not Fury", "lightning" in gr.mera.move_keys and not gr.mera.fury, "keys=%s" % [gr.mera.move_keys])
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
	_check("a potion lands within 0.2 s (the drink plays at 4x)", mt.size == 3 and mt.potions == 0 and waited <= 10 and is_equal_approx(float(mt.anim.speed), 4.0), "frames=%d speed=%s size=%d" % [waited, mt.anim.speed, mt.size])
	gt.queue_free()
	await process_frame
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
		g.knight.block_chance = 0.0
		await _drive(g, [[3, "btn_x", true], [6, "btn_x", false]], 30)
		_check("1x attack at %dx deals %d damage" % [sz, sz], g.knight.hp == 20 - sz, "hp=%d" % g.knight.hp)
		g.queue_free()
		await process_frame
	# knight: 10 HP, sphere +10 % rage, only one at a time, respawn after death
	g = await _new_game(true)
	m = g.mera
	await _drive(g, [], 90)
	_check("a Fire Knight spawns off-screen ahead", g.knight != null and absf(g.knight.global_position.x - g.cam_x) > 960.0, "")
	var k1: Node = g.knight
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
	if sphere:
		sphere.position = m.global_position + Vector2(0, -40)
		await _drive(g, [], 40)
	_check("that rage sphere gives +10 rage", is_equal_approx(m.rage, 10.0), "rage=%f" % m.rage)
	_check("no second knight while one is dying", g.knight == null or g.knight == k1, "")
	await _drive(g, [], 200)
	_check("a new knight spawns after the previous one is defeated", g.knight != null and g.knight != k1 and g.knights_spawned == 2, "spawned=%d" % g.knights_spawned)
	var k2: Node = g.knight
	m.position.x += 6000.0
	await _drive(g, [], 30)
	_check("leaving the knight far behind replaces him ahead", g.knight != k2 and g.knight != null and g.knights_spawned >= 3, "spawned=%d" % g.knights_spawned)
	g.knights_spawned = Roster.KNIGHT_CAP
	var last: Node = g.knight
	last.take_damage(99, m.global_position.x)
	for b in g.blues.duplicate():
		if is_instance_valid(b) and b.alive():
			b.take_damage(99, m.global_position.x)
	await _drive(g, [], 200)
	_check("cemetery ends after %d knights: no further knight, and the exit opens" % Roster.KNIGHT_CAP, not g._knight_fight_live() and g.knights_spawned == Roster.KNIGHT_CAP and not g.exit_locked(), "spawned=%d locked=%s knight=%s" % [g.knights_spawned, g.exit_locked(), g.knight])
	g.queue_free()
	await process_frame
	# fury
	g = await _new_game()
	m = g.mera
	m.rage = 100.0
	await _drive(g, [[5, "r2", true], [12, "r2", false], [20, "up", true], [24, "up", false], [30, "up", true], [34, "up", false], [40, "up", true]], 65)
	_check("R2 at 100 rage -> Fury (red effects)", m.fury and root.get_node("AnimLib").fury, "")
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
	await _drive(g, [[5, "r2", true], [12, "r2", false], [20, "up", true], [24, "up", false], [30, "up", true], [34, "up", false], [40, "up", true], [60, "up", false], [60, "right", true]], 90)
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
	_check("bubble: 3 to raise + 4 per second held", m.barrier_on and absf(m.stamina - (60.0 - 3.0 - 4.0 * 2.0 + 2.0)) < 1.2, "st=%f" % m.stamina)
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
	_check("enemy loot: one of five, meter upgrades are the rare rows", g.enemy_loot_kind(0.1) == "sphere" and g.enemy_loot_kind(0.4) == "potion" and g.enemy_loot_kind(0.7) == "stamina" and g.enemy_loot_kind(0.9) == "stamina_max" and g.enemy_loot_kind(0.97) == "rage_max", "%s %s %s %s %s" % [g.enemy_loot_kind(0.1), g.enemy_loot_kind(0.4), g.enemy_loot_kind(0.7), g.enemy_loot_kind(0.9), g.enemy_loot_kind(0.97)])
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.seed = 3
	var loot_n := {"sphere": 0, "potion": 0, "stamina": 0, "stamina_max": 0, "rage_max": 0}
	for i in 4000:
		loot_n[g.enemy_loot_kind(loot_rng.randf())] += 1
	_check("enemy loot rates: commons over 20%, meter upgrades under 12%", loot_n["sphere"] > 800 and loot_n["potion"] > 800 and loot_n["stamina"] > 800 and loot_n["stamina_max"] < 480 and loot_n["rage_max"] < 480 and loot_n["stamina_max"] > 80, "%s" % [loot_n])
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
	await _drive(g, [[3, "r2", true], [12, "r2", false], [20, "up", true], [24, "up", false], [30, "up", true], [70, "up", false]], 80)
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
	await _drive(g, [[3, "r2", true], [12, "r2", false]], 40)
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
	_check("4 levels in the level list", LV.list().size() == 4 and LV.map_w() >= 19200.0, "%d" % LV.list().size())
	for li in 4:
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
	_check("all 16 roster enemies are placed on levels 2-4, each once; level 1 has none", placed == all_ids and all_ids.size() == 16 and not dup and not RO.LEVELS.has(0) and not RO.BOSSES.has(0), "%s" % [placed])
	var dragon_boss: bool = RO.def("dragon").get("boss", false) and RO.BOSSES.get(3, "") == "dragon"
	_check("the dragon is the boss of Infernal Caverns", dragon_boss, "")
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
				for f in 420:
					await physics_frame
					if f % 30 == 0:
						m.set_size(6 if f < 300 else 3, true)
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
				if is_instance_valid(e):
					for a in e.played:
						used[a] = true
					hits += e.hits_landed
				g.queue_free()
				await process_frame
		var want: Array = RO.art(eid)["anims"].keys()
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
	# the spawner: walking through Misty Woods meets every enemy on its list; the dragon guards Infernal Caverns' exit
	for li in [1, 2, 3]:
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
	for li in [1, 2, 3]:
		var ids: Array = []
		for pr in AL.CARDS[li]:
			ids.append(pr[1])
		ids.sort()
		var want_c: Array = AL.IDS.duplicate()
		want_c.sort()
		if ids != want_c:
			cards_ok = false
	var cols := {}
	for aid in AL.IDS:
		cols[str(AL.COLORS[aid])] = true
	_check("levels 2-4 each hold one colour-coded card per ally (4 distinct colours); level 1 has none", cards_ok and cols.size() == 4 and not AL.CARDS.has(0), "")
	LV.current = 0
	g = await _new_game()
	_check("level 1 (cemetery) is left as is: no ally cards on the map", g.card_nodes.is_empty(), "")
	g.queue_free()
	await process_frame
	LV.current = 1
	g = await _new_game()
	m = g.mera
	var c0: Node2D = g.card_nodes[0]
	for cn in g.card_nodes:                # v0.8: some cards are hidden (secrets); take the first one in the open
		if not cn.hidden() and cn.base_y < 0.0:
			c0 = cn
			break
	var cid: String = c0.ally_id
	m.position.x = c0.global_position.x
	await _drive(g, [], 4)
	_check("touching a card collects it", int(g.cards.get(cid, 0)) == 1 and not g.card_nodes.has(c0), "%s" % [g.cards])
	await _drive(g, [[3, "r1", true], [6, "r1", false]], 10)
	_check("R1 with one card type -> that ally is summoned at once (no picker), the card is used", g.allies().size() == 1 and g.allies()[0].id == cid and int(g.cards[cid]) == 0 and not g.picker.open, "")
	g.queue_free()
	await process_frame
	g = await _new_game()
	m = g.mera
	g.cards = {"ranger": 1, "dancer": 2}
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
	g.cards = {"priestess": 1}
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
	for aid in AL.IDS:
		LV.current = 1
		g = await _new_game()
		m = g.mera
		m.position.x = 6000.0
		m.set_size(2, true)
		g.snap_camera()
		g.cards[aid] = 1
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
	g.cards = {"dancer": 1}
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
	g.cards = {"brawler": 1}
	var bz: Node2D = g.summon_type("brawler")
	await _drive(g, [], 90)
	bz.age = bz.stay - 0.05
	await _drive(g, [], 10)
	_check("allies leave when their time is up (%d s)" % int(AL.STAY_S["brawler"]), bz.state == "leave", bz.state)
	g.queue_free()
	await process_frame
	_check("every summon lasts 20 s and the dance is 5 s", AL.STAY_S["priestess"] == 20.0 and AL.STAY_S["ranger"] == 20.0 and AL.STAY_S["brawler"] == 20.0 and AL.STAY_S["dancer"] == 20.0 and AL.DANCE_S == 5.0, "")
	g = await _new_game()
	m = g.mera
	m.position.x = 6000.0
	m.facing = 1
	g.snap_camera()
	g.knight_calm_until = 1 << 30
	g.cards = {"brawler": 1}
	var br: Node2D = g.summon_type("brawler")
	await _drive(g, [], 100)
	var bx: float = br.global_position.x
	await _drive(g, [], 40)
	var ran: bool = br.global_position.x > bx + 60.0 and br.global_position.x > m.global_position.x
	var tail: Node2D = g.spawn_enemy("wolf", br.global_position.x - 650.0)
	tail.cooldown = 99.0
	var tx: float = tail.global_position.x
	await _drive(g, [], 90)
	_check("Brawler Girl runs right, and enemies still chase Mera", ran and tail.global_position.x < br.global_position.x - 80.0, "br=%.0f mera=%.0f wolf %.0f -> %.0f" % [br.global_position.x, m.global_position.x, tx, tail.global_position.x])
	g.queue_free()
	await process_frame
	g = await _new_game()
	m = g.mera
	m.position.x = 6000.0
	m.facing = 1
	g.snap_camera()
	g.cards = {"dancer": 1}
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
	_check("a quick-fire bolt breaks a candle", not candle.alive(), "hp=%d" % candle.hp)
	var urn: Node2D = PROP.new()
	urn.setup(g, "urn", 5600.0, {})
	g.world.add_child(urn)
	g.props.append(urn)
	var uc: Vector2 = urn.hurt_rect().get_center()
	var es: Node2D = load("res://scripts/game/enemy_shot.gd").new()
	es.setup(g, "hell_beast", "fireball", uc + Vector2(-160.0, 0.0), Vector2(700.0, 0.0), 1, 4.0)
	g.world.add_child(es)
	await _drive(g, [], 30)
	_check("an enemy shot breaks an urn", not urn.alive(), "hp=%d" % urn.hp)
	var crate: Node2D = PROP.new()
	crate.setup(g, "crate", 5900.0, {})
	g.world.add_child(crate)
	g.props.append(crate)
	var db: Node2D = load("res://scripts/game/dragon_bolt.gd").new()
	var dc: Vector2 = crate.hurt_rect().get_center()
	db.setup(g, null, dc + Vector2(-80.0, -200.0), dc, 0.4)
	g.world.add_child(db)
	await _drive(g, [], 40)
	_check("a dragon bolt breaks a crate", not crate.alive(), "hp=%d state=%s" % [crate.hp, crate.state])
	g.queue_free()
	await process_frame
	LV.current = 0
	# menu scene loads and lists the 4 levels
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	_check("level select menu loads with 4 level cards", menu.thumbs.size() == 4, "")
	menu._move(1)
	_check("menu: Right selects level 2", menu.sel == 1, "")
	menu.queue_free()
	await process_frame
	await _s4_tests()
	await _mark_tests()
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
	var lay_ok: bool = P.layout(0, 20000.0).is_empty()
	var lay_info := ""
	for lv in [1, 2, 3]:
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
	_check("props: level 1 untouched; levels 2-4 have candles, urns, crates, chests, barrels", lay_ok, lay_info)

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
	var wcard: Node2D = wall.card
	var hidden_ok: bool = wcard != null and wcard.hidden_by == wall and not wcard.visible
	m.position.x = wall.global_position.x - 200.0
	await _s4_frames(g, 3)
	var hits := 0
	while is_instance_valid(wall) and wall.alive() and hits < 20:
		m.deal(wall, 1, m.global_position.x, "melee")
		hits += 1
	await _s4_frames(g, 5)
	_check("secret wall: hides its card until broken (%d hits), then the card can be taken" % hits, hidden_ok and (not is_instance_valid(wall) or not wall.alive()) and wcard.hidden_by == null and g.secrets_found == 1 and hits > 1, "hidden=%s hits=%d" % [hidden_ok, hits])
	var lever: Node2D = _s4_prop(g, "lever")
	var door: Node2D = lever.door
	var dcard: Node2D = door.card
	m.position.x = lever.global_position.x - 120.0
	await _s4_frames(g, 3)
	m.deal(lever, 1, m.global_position.x, "melee")
	await _s4_frames(g, 100)
	_check("secret door: pulling its lever opens it and frees the card", door.state == "open" and dcard.hidden_by == null and g.secrets_found == 2, "door=%s" % door.state)
	var plank: Node2D = _s4_prop(g, "plank")
	var ledge: Node2D = _s4_prop(g, "ledge")
	var lcard: Node2D = ledge.card
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
	_check("ledge: the card floats on top of the ledge", absf(lcard.base_y - (ledge.top_y - 40.0)) < 0.1 and ledge.top_y < g.GROUND_Y - 250.0, "base=%f top=%f" % [lcard.base_y, ledge.top_y])
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
	g.cards["brawler"] = 2
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
	_check("dragon: its death unlocks the exit", not g.exit_locked(), "")
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
	var ground_props: Array = []
	var lever_ok := true
	for pr in g.props:
		if is_instance_valid(pr) and pr.alive() and pr.kind != "chandelier" and pr.kind != "lever" and absf(pr.global_position.x - g.cam_x) <= T.SUPER_QUAKE_REACH:
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
	_check("super quake: every ground breakable on/near screen is destroyed (%d); far ones stay" % ground_props.size(), ground_props.size() >= 2 and broke == ground_props.size() and (far_prop == null or far_prop.alive()), "broke %d/%d" % [broke, ground_props.size()])
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
	await _drive(g, [[2, "r2", true], [10, "r2", false]], 30)
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
	_check("updater: this build's version comes from application/config/version (0.9.6)", U.current_version() == "0.9.6", U.current_version())
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
		menu._unhandled_input(down)
		var right := InputEventAction.new()
		right.action = "right"
		right.pressed = true
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
		_check("menu: Down -> bottom row, Right -> CREDITS, A opens it, B closes it", in_credits and menu.mode == "menu" and menu.row == 1, "mode=%s row=%d" % [menu.mode, menu.row])
		var C = load("res://scripts/app/credits.gd")
		var whos: Array = []
		for c in C.ENTRIES:
			whos.append(String(c["who"]))
		var need := ["chierit", "Merakintsugi", "Kenney", "Pixel Frog", "Jimmy D. Journey", "Reactorcore", "rubberduck", "vk", "Godot Engine"]
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
	var out := {"bolts": [], "up": [], "air_bubble": 0, "max_air_vy": 0.0, "vx_bubble": []}
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
	var b2: Node = r["bolts"][1] if r["bolts"].size() >= 2 else null
	_check("Y chain: the follow-up is the same bolt (same speed, damage path), fired forward", b2 != null and is_instance_valid(b2) and not b2.up and b2.dir == m.facing and is_equal_approx(b2.speed(), 400.0 * m.shown), "")
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
		if f == 58:
			for c in gg.world.get_children():
				if c.get("kind") == "bolt":
					c.queue_free()                         # the 3 quick-fire bolts must not touch the test enemies
		if f == 60:
			pe["e1"] = gg.spawn_enemy("ogre", mm.global_position.x + mm.facing * 330.0)
			pe["e2"] = gg.spawn_enemy("wolf", mm.global_position.x - mm.facing * 360.0)
		if f == 61:
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
		_check("Up+Y: %s -> vertical quick fire (heal pose, one bolt straight up), no jump / aerial dash" % c[0], "vfire" in m.move_keys and ub.size() == 1 and r["bolts"].size() == 1 and not ("adash" in m.move_log) and not ("djump_v" in m.move_log) and m.on_ground and float(maxlift["v"]) < 40.0 * m.shown, "log=%s up=%d bolts=%d lift=%.0f" % [m.move_log, ub.size(), r["bolts"].size(), float(maxlift["v"])])
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
	var u: Dictionary = r["up"][0] if r["up"].size() > 0 else {}
	_check("Up+Y: same bolt as quick fire (400 px/s x size), rotated head-up (sprite rot 90 deg), spawned above her head", not u.is_empty() and is_equal_approx(float(u["speed"]), 400.0 * m.shown) and is_equal_approx(float(u["rot"]), PI / 2.0) and Vector2.LEFT.rotated(float(u["rot"])).y < -0.99 and float(u["p0"].y) < float(u["mera_y"]) - 55.0 * m.shown, "%s" % [u])
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
	for L in [0, 1, 2, 3]:
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
		var ok := bs.size() == (0 if L == 0 else 2)
		for b in bs:
			if float(b["x"]) > float(b["mera_x"]) - 960.0 or int(b["facing"]) != 1:
				ok = false                               # off-screen behind her (she faces right: x < mera - 960)
		_check("level %d: %d monsters come from behind (off-screen, behind her)" % [L + 1, 0 if L == 0 else 2], ok, "%s" % [bs.map(func(b): return [b["id"], int(b["x"] - b["mera_x"])])])
		if L > 0:
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
	g.cards = {"ranger": 2, "brawler": 1}
	var bag: Dictionary = g._pack_run()
	m.potions = 0
	m.stamina = 0.0
	m.stamina_max = 50.0
	m.rage = 0.0
	m.rage_max = 100.0
	m.set_size(2, true)
	g.cards = {}
	g._apply_run(bag)
	_check("a cleared level keeps potions, cards, size, mana, rage and both upgrades", m.potions == 4 and m.size == 5 and m.stamina_max == 90.0 and absf(m.stamina - 12.0) < 0.1 and m.rage_max == 130.0 and absf(m.rage - 40.0) < 0.1 and int(g.cards.get("ranger", 0)) == 2 and int(g.cards.get("brawler", 0)) == 1, "p=%d size=%d mana %.0f/%.0f rage %.0f/%.0f cards=%s" % [m.potions, m.size, m.stamina, m.stamina_max, m.rage, m.rage_max, g.cards])
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
	_check("Start pauses the game (overlay up, Mera frozen) and does not just show controls", g.paused_play and g.hud.overlay and g.get_tree().paused and still, "paused=%s overlay=%s x=%.1f->%.1f" % [g.paused_play, g.hud.overlay, moved, m.global_position.x])
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
