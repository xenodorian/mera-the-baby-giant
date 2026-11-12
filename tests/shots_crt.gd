extends SceneTree
## Before / after CRT shots of level 1 (Misty Woods).
## xvfb-run -a -s "-screen 0 1920x1080x24" $G --path . --rendering-driver opengl3 --resolution 1920x1080 -s tests/shots_crt.gd
const OUT_REPO := "res://previews/playable/crt/"
const OUT_EXT := "/workspace/previews_chars/"
var LV = load("res://scripts/game/levels.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ST: Node = root.get_node_or_null("Settings")
	if ST:
		ST.set_crt(false)
	LV.current = 0
	var g: Node = load("res://scenes/game.tscn").instantiate()
	g.test_mode = true
	root.add_child(g)
	await physics_frame
	var m: Node = g.mera
	m.position.x = 1400.0
	m.set_size(3, true)
	m.invuln = 10.0
	g.snap_camera()
	for i in 40:
		await physics_frame
		m.invuln = 10.0
	await RenderingServer.frame_post_draw
	_save("crt_off.png")
	if ST:
		ST.set_crt(true)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	_save("crt_on.png")
	if ST:
		ST.set_crt(false)
	print("SHOTS DONE")
	quit()


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_REPO))
	DirAccess.make_dir_recursive_absolute(OUT_EXT)
	var repo_path := ProjectSettings.globalize_path(OUT_REPO + name)
	img.save_png(repo_path)
	img.save_png(OUT_EXT + name)
	print("SHOT ", repo_path, " and ", OUT_EXT + name)
