extends SceneTree
## v0.5 preview screenshots (xvfb-run godot --path . -s tests/shots_v05.gd)
const OUT := "res://previews/playable/v0.5/"
var LV = load("res://scripts/game/levels.gd")


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
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name))
	print("SHOT ", name)


func _run() -> void:
	var names := ["cemetery", "misty_woods", "moonlit_town", "infernal_caverns"]
	for li in 4:
		var g: Node = await _new(li)
		var m: Node = g.mera
		m.position.x = 6000.0 + li * 1500.0
		m.set_size(3, true)
		g._spawn_knight(1)
		g.knight.position.x = m.position.x + 700.0
		g.knight_calm_until = 1 << 30
		await _wait(40)
		await _shot("shot_level%d_%s.png" % [li + 1, names[li]])
		if li == 0:
			# earthquake: crouch + Y, a knight stunned mid-quake
			m.forced["down"] = true
			await _wait(8)
			m.forced["btn_y"] = true
			await _wait(4)
			m.forced["btn_y"] = false
			await _wait(24)
			await _shot("shot_earthquake_stun.png")
			m.forced["down"] = false
		if li == 3:
			m.position.x = LV.map_w() - 900.0
			await _wait(20)
			await _shot("shot_exit_gate.png")
		g.queue_free()
		await _wait(3)
	quit()
