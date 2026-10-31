extends SceneTree
## v0.4 preview screenshots (needs a display: xvfb-run godot --path . -s tests/shots_v04.gd)
const OUT := "res://previews/playable/v0.4/"


func _initialize() -> void:
	_run.call_deferred()


func _new() -> Node:
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
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + name))
	print("SHOT ", name)


func _press(m: Node, a: String, f: int = 4) -> void:
	m.forced[a] = true
	await _wait(f)
	m.forced[a] = false


func _run() -> void:
	# 1 particle aura, standing: flames rise like a fire on the ground
	var g: Node = await _new()
	var m: Node = g.mera
	m.set_size(4, true)
	m.rage = 100.0
	await _press(m, "r2")
	await _wait(70)
	await _shot("shot_aura_particles_standing.png")
	# 2 running: the flames trail behind her
	m.forced["right"] = true
	m.forced["btn_a"] = true
	await _wait(45)
	await _shot("shot_aura_particles_trailing.png")
	m.forced["right"] = false
	m.forced["btn_a"] = false
	g.queue_free()
	await _wait(2)
	# 3 Fire Knight blocking Mera's attack; the hit brought in a Blue Knight
	g = await _new()
	m = g.mera
	m.set_size(3, true)
	g._spawn_knight(1)
	var k: Node = g.knight
	k.position.x = m.global_position.x + 330.0
	k.block_chance = 0.0
	g.knight_calm_until = 1 << 30
	await _wait(10)
	k.take_damage(1, m.global_position.x)        # first HP loss -> a blue spawns behind her
	k.block_chance = 1.0
	await _wait(50)
	await _press(m, "btn_x")
	await _wait(14)
	await _shot("shot_fire_knight_block_blue_flanking.png")
	await _wait(60)
	await _shot("shot_blue_knight_behind_mera.png")
	g.queue_free()
	await _wait(2)
	# 4 fast quick fire (B then Y) at a far Fire Knight, who jumps it
	g = await _new()
	m = g.mera
	m.set_size(2, true)
	g._spawn_knight(1)
	k = g.knight
	k.position.x = m.global_position.x + 780.0
	k.dash_cd = 99.0
	g.knight_calm_until = 1 << 30
	await _wait(5)
	await _press(m, "btn_b")
	await _wait(8)
	await _press(m, "btn_y")
	for i in 60:
		await process_frame
		if k.state == "air":
			break
	await _wait(4)
	await _shot("shot_fast_quick_fire_knight_jumps_bolt.png")
	g.queue_free()
	await _wait(2)
	# 5 stamina HUD: bubble draining stamina
	g = await _new()
	m = g.mera
	m.set_size(3, true)
	m.forced["l2"] = true
	await _wait(150)
	await _shot("shot_bubble_drains_stamina_hud.png")
	m.forced["l2"] = false
	g.hud.overlay = true
	await _wait(5)
	await _shot("shot_controls_overlay_v0.4.png")
	g.queue_free()
	await _wait(2)
	quit()
