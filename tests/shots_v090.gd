extends SceneTree
## v0.9.0 title menu: update banner / panel and Credits screen -> previews/playable/v0.9.0/
## xvfb-run -a -s "-screen 0 1920x1080x24" $G --path . --rendering-driver opengl3 --resolution 1920x1080 -s tests/shots_v090.gd
const OUT := "res://previews/playable/v0.9.0/"


func _initialize() -> void:
	_run.call_deferred()


func _snap(name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name))
	print("SHOT ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var U: Node = root.get_node("Updater")
	U.auto_check = false
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await _snap("shot_title_menu.png")
	# a found update (fake data: what a player on v0.9.0 sees once v0.9.1 is out)
	U.latest = {"tag": "v0.9.1-playable", "name": "v0.9.1-playable", "version": [0, 9, 1], "url": "", "asset": "Mera_Playable_v0.9.1_Windows.exe", "size": 98000000, "sums_url": "x", "page": ""}
	U._state("available", "Update available: v0.9.1 (93.5 MB).")
	menu.row = 1
	menu.btn = 0
	menu.queue_redraw()
	await _snap("shot_title_update_banner.png")
	menu.mode = "update"
	U.state = "downloading"
	U.message = "Downloading Mera_Playable_v0.9.1_Windows.exe..."
	U.progress = 0.62
	menu.queue_redraw()
	await _snap("shot_update_downloading.png")
	U.state = "available"
	menu.mode = "credits"
	menu.credit_sel = 0
	menu.queue_redraw()
	await _snap("shot_credits.png")
	quit()
