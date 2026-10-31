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
func _human_combo(name: String, steps: Array, want: Array, forbid: Array, trials: int = 8, check: Callable = Callable()) -> void:
	var rng := RandomNumberGenerator.new()
	var bad := []
	for n in trials:
		rng.seed = 4000 + n * 7919 + name.hash() % 1000
		var g: Node = await _new_game()
		var ev := _human_events(rng, steps)
		var r: Dictionary = await _replay(g, ev, 2200.0, String(want[0]) if want.size() > 0 else "")
		var log: Array = g.mera.move_log
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
	# ---- specials (v0.5 remap: L2 tap = lightning, L2 hold = barrier, L2+R2 = Fury, R1 = ally)
	s = []; _tap(s, 5, "l2")
	await _combo("L2 tap with a full meter -> lightning (heal pose)", s, 70, ["heal"], [], func(g): g.mera.rage = 100.0)
	await _combo("L2 tap with 99 % rage -> no lightning", s, 70, [], [], func(g): g.mera.rage = 99.0)
	var gr: Node = await _new_game()
	gr.mera.rage = 100.0
	var struck := false
	await _drive(gr, [[5, "l2", true], [8, "l2", false]], 10)
	for _f in 80:
		await physics_frame
		if is_instance_valid(gr.last_strike):
			struck = true
	_check("L2 tap spends the whole meter (drains to 0) and strikes", gr.mera.rage == 0.0 and not gr.mera.rage_spending and struck, "rage=%f struck=%s" % [gr.mera.rage, struck])
	gr.mera.rage = 100.0
	await _drive(gr, [[5, "l2", true], [5, "r2", true], [8, "l2", false], [8, "r2", false]], 20)
	_check("L2+R2 together -> Fury", gr.mera.fury, "")
	var before: int = gr.mera.move_log.size()
	gr.last_strike = null
	await _drive(gr, [[5, "l2", true], [8, "l2", false]], 40)
	_check("L2 tap during Fury (meter already spent) -> no lightning", gr.mera.fury and gr.last_strike == null, "log=%s" % [gr.mera.move_log.slice(before)])
	gr.queue_free()
	await process_frame
	for order in [["l2", "r2"], ["r2", "l2"]]:
		for gap in [0, 2, 3]:
			gr = await _new_game()
			gr.mera.rage = 100.0
			await _drive(gr, [[5, order[0], true], [5 + gap, order[1], true], [10, order[0], false], [10 + gap, order[1], false]], 30)
			_check("%s then %s %d ms later -> Fury, no lightning" % [order[0], order[1], int(gap * 16.7)], gr.mera.fury and gr.last_strike == null and not gr.mera.rage_spending, "")
			gr.queue_free()
			await process_frame
	gr = await _new_game()
	gr.mera.rage = 100.0
	await _drive(gr, [[5, "l2", true], [60, "r2", true], [64, "r2", false], [70, "l2", false]], 80)
	_check("R2 while holding the L2 bubble -> Fury", gr.mera.fury and not gr.mera.barrier_on, "")
	gr.queue_free()
	await process_frame
	gr = await _new_game()
	gr.mera.rage = 100.0
	await _drive(gr, [[5, "r2", true], [8, "r2", false]], 30)
	_check("R2 alone -> no Fury (it's L2+R2 now)", not gr.mera.fury and gr.mera.rage == 100.0, "")
	await _drive(gr, [[5, "r1", true], [8, "r1", false]], 30)
	var fails := 0
	for h in root.get_node("Sfx").history:
		if h[0] == "fail":
			fails += 1
	_check("R1 without ally cards -> fail cue, no lightning", fails > 0 and gr.last_strike == null and gr.mera.rage == 100.0, "")
	await _drive(gr, [[5, "l2", true]], 100)
	_check("L2 held with a full meter -> barrier, no lightning", gr.mera.barrier_on and gr.mera.rage == 100.0 and gr.last_strike == null, "")
	await _drive(gr, [[3, "btn_y", true], [6, "btn_y", false]], 12)
	_check("v0.6: Y inside the bubble with a full meter -> lightning, the bubble stays up", gr.last_strike != null and gr.mera.barrier_on and gr.mera.rage_spending and not ("quick_fire" in gr.mera.move_log), "")
	gr.last_strike = null
	await _drive(gr, [[3, "btn_y", true], [6, "btn_y", false]], 12)
	_check("v0.6: Y inside the bubble with the meter spent -> fail cue, no strike, still shielded", gr.last_strike == null and gr.mera.barrier_on, "")
	await _drive(gr, [[2, "l2", false]], 30)
	gr.queue_free()
	await process_frame
	gr = await _new_game()
	gr.mera.rage = 100.0
	await _drive(gr, [[5, "up", true], [9, "up", false], [20, "l2", true], [21, "r2", true], [25, "l2", false], [25, "r2", false]], 40)
	_check("L2+R2 in the air -> Fury", gr.mera.fury, "")
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
	k1.take_damage(20, m.global_position.x)
	_check("Fire Knight with 20 HP dies to 20 damage", not k1.alive(), "hp=%d" % k1.hp)
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
	await _drive(g, [[5, "r2", true], [5, "l2", true], [8, "r2", false], [8, "l2", false], [20, "up", true], [24, "up", false], [30, "up", true], [34, "up", false], [40, "up", true]], 65)
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
	await _drive(g, [[5, "r2", true], [5, "l2", true], [8, "r2", false], [8, "l2", false], [20, "up", true], [24, "up", false], [30, "up", true], [34, "up", false], [40, "up", true], [60, "up", false], [60, "right", true]], 90)
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
	_check("blue potion: +30 stamina", absf(m.stamina - 40.0) < 0.01, "st=%f" % m.stamina)
	g.collect(pk)
	_check("...capped at the max", m.stamina == m.stamina_max, "")
	pk.kind = "stamina_max"
	g.collect(pk)
	_check("blue-and-white potion: +5 max stamina (65)", m.stamina_max == 65.0, "max=%f" % m.stamina_max)
	for i in 20:
		g.collect(pk)
	_check("max stamina caps at 120", m.stamina_max == 120.0, "max=%f" % m.stamina_max)
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
	await _drive(g, [[3, "r2", true], [3, "l2", true], [6, "r2", false], [6, "l2", false], [20, "up", true], [24, "up", false], [30, "up", true], [70, "up", false]], 80)
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
	await _drive(g, [[3, "r2", true], [3, "l2", true], [6, "r2", false], [6, "l2", false]], 40)
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
		if g.exit_locked():                    # v0.6: Infernal Caverns' exit stays shut while the dragon lives
			m.position.x = LV.map_w() + 900.0
			await physics_frame
			await physics_frame
			_check("level %d: the exit is locked while the boss lives" % (li + 1), not g.cleared, "")
			g.boss_dead = true
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
	# the priestess heals Mera up to 6x, with a cooldown
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
	await _drive(g, [], 600)
	var held_off: bool = m.size == 2 and prs.heals == 1
	prs.heal_cd = 0.0
	await _drive(g, [], 120)
	_check("Water Priestess heals Mera to 6x, then waits out the %d s cooldown before healing again" % int(AL.HEAL_CD), healed1 and held_off and m.size == 6 and prs.heals == 2, "h1=%s off=%s size=%d heals=%d" % [healed1, held_off, m.size, prs.heals])
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
	await _drive(g, [], 60)
	for w in watchers:
		if w.state == "tell" or w.state == "atk":
			tells += 1
	_check("Dancing Girl: on-screen non-boss enemies gather at her side and jump up and down, no attacks", dz.dancing() and near_ok and hop_ok and tells == 0, "near=%s hop=%s tells=%d" % [near_ok, hop_ok, tells])
	_check("...the boss is not distracted", drg.distracted_t == 0.0, "")
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
	LVS.current = 0
