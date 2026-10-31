extends SceneTree
## v0.6 preview screenshots: each level's roster lined up facing Mera, a telegraph, the boss
const OUT := "res://previews/playable/v0.6/"
var LV = load("res://scripts/game/levels.gd")
var RO = load("res://scripts/game/roster.gd")


func _initialize() -> void:
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


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name))
	print("SHOT ", name)


func _run() -> void:
	var names := {1: "misty_woods", 2: "moonlit_town", 3: "infernal_caverns"}
	for li in [1, 2, 3]:
		var g: Node = await _new(li)
		var m: Node = g.mera
		m.position.x = 5000.0
		m.set_size(3, true)
		g.snap_camera()
		g.knight_calm_until = 1 << 30
		var list: Array = RO.LEVELS[li]
		var xs := [5230.0, 4700.0, 5520.0, 4330.0, 5800.0, 4050.0]
		var i := 0
		for eid in list:
			var e: Node2D = g.spawn_enemy(eid, xs[i])
			i += 1
			e.set_physics_process(false)
		await _wait(30)
		await _shot("shot_roster_%s.png" % names[li])
		g.queue_free()
		await _wait(3)
	# a telegraph: the minotaur winding up (heavy, white-gold) and a wolf (rush, purple)
	var g2: Node = await _new(1)
	var m2: Node = g2.mera
	m2.position.x = 5000.0
	m2.set_size(3, true)
	g2.snap_camera()
	var mi: Node2D = g2.spawn_enemy("minotaur", 5330.0)
	var wo: Node2D = g2.spawn_enemy("wolf", 4500.0)
	for i in 240:
		await physics_frame
		if mi.state == "tell" and mi.tell_t > 0.2:
			break
	await _shot("shot_telegraph.png")
	g2.queue_free()
	await _wait(3)
	# the boss
	var g3: Node = await _new(3)
	var m3: Node = g3.mera
	m3.position.x = 17000.0
	m3.set_size(4, true)
	g3.snap_camera()
	var dr: Node2D = g3.spawn_enemy("dragon", 17900.0)
	for i in 300:
		await physics_frame
		m3.set_size(4, true)
		if dr.state == "atk" and dr.atk.get("anim", "") == "breath" and dr.sprite.frame >= 5:
			break
	await _shot("shot_boss_dragon.png")
	quit()
