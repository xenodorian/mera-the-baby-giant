extends SceneTree
## v0.8 preview screenshots: breakables + chandelier, a shatter with gore, a barrel blast, a parry, the secrets
## xvfb-run -a -s "-screen 0 1920x1080x24" $G --path . --rendering-driver opengl3 --resolution 1920x1080 -s tests/shots_v08.gd
const OUT := "res://previews/playable/v0.8/"
var LV = load("res://scripts/game/levels.gd")
var only := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.get_slice("=", 1)
	_run.call_deferred()


func _new(level: int) -> Node:
	LV.current = level
	var g: Node = load("res://scenes/game.tscn").instantiate()
	g.test_mode = true
	root.add_child(g)
	await physics_frame
	return g


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _phys(g: Node, n: int) -> void:
	for i in n:
		await physics_frame
		g.mera.invuln = 1.0


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name))
	print("SHOT ", name)


func _prop(g: Node, kind: String, near: float) -> Node2D:
	var best: Node2D = null
	for p in g.props:
		if is_instance_valid(p) and p.kind == kind and (best == null or absf(p.global_position.x - near) < absf(best.global_position.x - near)):
			best = p
	return best


func _go(name: String) -> bool:
	return only == "" or only == name


func _run() -> void:
	var g: Node
	var m: Node
	if _go("props"):
		# Moonlit Town: breakables and a chandelier on screen
		g = await _new(2)
		m = g.mera
		var ch: Node2D = _prop(g, "chandelier", 0.0)
		m.position.x = ch.global_position.x - 300.0
		m.set_size(3, true)
		g.snap_camera()
		await _phys(g, 30)
		await _shot("shot_breakables.png")
		g.queue_free()
		await _wait(3)
	if _go("shatter"):
		# a launched ogre shattering into debris + gore
		g = await _new(1)
		m = g.mera
		m.position.x = 6000.0
		m.set_size(4, true)
		g.snap_camera()
		var o: Node2D = g.spawn_enemy("ogre", 6450.0)
		var w: Node2D = g.spawn_enemy("werewolf", 6300.0)
		await _phys(g, 20)
		o.cooldown = 99.0
		w.cooldown = 99.0
		m.deal(w, 1, m.global_position.x, "launch")
		await _phys(g, 14)
		await _shot("shot_juggle.png")
		o.hp = 1
		m.deal(o, 1, m.global_position.x, "launch")
		var saw := false
		for i in 90:
			await physics_frame
			m.invuln = 1.0
			if g.debris.pieces.size() > 40 and not saw:
				saw = true
				for j in 5:
					await physics_frame
				break
		await _shot("shot_shatter_gore.png")
		g.queue_free()
		await _wait(3)
	if _go("barrel"):
		g = await _new(3)
		m = g.mera
		var b: Node2D = _prop(g, "barrel", 6000.0)
		m.position.x = b.global_position.x - 520.0
		m.set_size(3, true)
		g.snap_camera()
		var e1: Node2D = g.spawn_enemy("hell_hound", b.global_position.x + 120.0)
		var e2: Node2D = g.spawn_enemy("demon", b.global_position.x + 260.0)
		await _phys(g, 20)
		e1.cooldown = 99.0
		e2.cooldown = 99.0
		m.deal(b, 1, m.global_position.x, "bolt")
		await _phys(g, 9)
		await _shot("shot_barrel_blast.png")
		g.queue_free()
		await _wait(3)
	if _go("parry"):
		g = await _new(3)
		m = g.mera
		m.position.x = 5000.0
		m.set_size(3, true)
		g.snap_camera()
		var hb: Node2D = g.spawn_enemy("hell_beast", 5900.0)
		await _phys(g, 10)
		hb.cooldown = 0.0
		var fired := false
		for i in 300:
			await physics_frame
			for c in g.world.get_children():
				if c.get("deflected") != null and not c.deflected and absf(c.global_position.x - m.global_position.x) < 260.0:
					m.forced["l2"] = true
					fired = true
			if m.deflects > 0:
				m.forced["l2"] = false
				for j in 8:
					await physics_frame
				break
		await _shot("shot_parry.png")
		g.queue_free()
		await _wait(3)
	if _go("secrets"):
		g = await _new(1)
		m = g.mera
		var ledge: Node2D = _prop(g, "ledge", 0.0)
		m.position.x = ledge.global_position.x - 420.0
		m.set_size(2, true)
		g.snap_camera()
		await _phys(g, 30)
		await _shot("shot_secret_ledge.png")
		var wall: Node2D = _prop(g, "wall", 0.0)
		m.position.x = wall.global_position.x - 260.0
		g.snap_camera()
		await _phys(g, 10)
		for i in 3:
			m.deal(wall, 1, m.global_position.x, "melee")
			await _phys(g, 6)
		await _shot("shot_secret_wall.png")
		m.deal(wall, 1, m.global_position.x, "melee")
		await _phys(g, 12)
		await _shot("shot_secret_wall_broken.png")
		g.queue_free()
		await _wait(3)
	if _go("dragon"):
		# v0.8 dragon boss: a 12x phase, in the air, bolts lobbing down onto Mera
		g = await _new(3)
		m = g.mera
		m.position.x = 12000.0
		m.set_size(4, true)
		g.snap_camera()
		var dr: Node2D = g.spawn_enemy("dragon", 12750.0)
		await _phys(g, 30)
		await _shot("shot_dragon_19x.png")
		dr.take_damage(8 * 7, m.global_position.x, "melee")
		var shot_n := 0
		for i in 900:
			await physics_frame
			m.invuln = 1.0
			m.position.x = 12000.0
			var bolts := 0
			for c in g.world.get_children():
				if c.get("warn") != null:
					bolts += 1
			if dr.phase == "volley" and bolts >= 2 and shot_n == 0:
				await _shot("shot_dragon_flying_bolts.png")
				shot_n += 1
			if dr.phase == "volley" and shot_n == 1 and dr.bolt_i >= 2 and dr.sprite.animation == "spit" and dr.sprite.frame >= 4:
				await _shot("shot_dragon_volley_no_plume.png")      # v0.8.1: mouth open on the spit frame, no breath plume
				shot_n += 1
			if dr.phase == "" and dr.landings > 0:
				break
		g.queue_free()
		await _wait(3)
	if _go("dancer"):
		g = await _new(2)
		m = g.mera
		m.position.x = 6000.0
		m.set_size(3, true)
		g.snap_camera()
		g.cards = {"dancer": 1}
		g.summon_type("dancer")
		await _phys(g, 150)
		await _shot("shot_dancer_skin.png")
		g.queue_free()
		await _wait(3)
	if _go("superquake"):
		g = await _new(2)
		m = g.mera
		var cr: Node2D = _prop(g, "crate", 6000.0)
		m.position.x = cr.global_position.x - 500.0
		m.set_size(3, true)
		g.snap_camera()
		var e1: Node2D = g.spawn_enemy("skeleton", m.position.x + 420.0)
		var e2: Node2D = g.spawn_enemy("hell_gato", m.position.x - 380.0)
		await _phys(g, 40)
		e1.cooldown = 99.0
		e2.cooldown = 99.0
		m.rage = 100.0
		m.forced["down"] = true
		await _phys(g, 8)
		m.forced["btn_y"] = true
		for i in 30:
			await physics_frame
			m.invuln = 1.0
			if g.impact_t > 0.0 and g.impact_t < 0.15:
				break
		m.forced["btn_y"] = false
		await _shot("shot_super_quake_impact_frame.png")
		for i in 40:
			await physics_frame
			m.invuln = 1.0
			if g.super_on and g.quake_age > 0.25:
				break
		m.forced["down"] = false
		await _shot("shot_super_quake.png")
		g.queue_free()
		await _wait(3)
	if _go("overlay"):
		g = await _new(0)
		g.hud.overlay = true
		await _phys(g, 10)
		await _shot("shot_controls_keyboard.png")
		g.queue_free()
		await _wait(3)
	quit()
