extends "res://tests/shots_v08.gd"
## v0.8.1 dragon flight: screenshots to previews/playable/v0.8.1/ and GIF frames (960x540, every 3rd 60 fps frame = 20 fps)
## xvfb-run -a -s "-screen 0 1920x1080x24" $G --path . --fixed-fps 60 --rendering-driver opengl3 --resolution 1920x1080 -s tests/shots_v081.gd -- [--gif=/abs/dir]
const OUT81 := "res://previews/playable/v0.8.1/"
var gif_dir := ""


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gif="):
			gif_dir = a.get_slice("=", 1)
	var g: Node = await _new(3)
	var m: Node = g.mera
	m.position.x = 12000.0
	m.set_size(3, true)
	g.snap_camera()
	var dr: Node2D = g.spawn_enemy("dragon", 12800.0, {"size": 13})
	await _phys(g, 40)
	dr.cooldown = 99.0
	dr.take_damage(8, m.global_position.x, "melee")       # 13x -> 12x: the 12x flight phase
	var n := 0
	var shots := {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT81))
	for i in 1200:
		await process_frame
		m.invuln = 1.0
		if gif_dir != "" and i % 3 == 0 and (dr.phase != "" or i < 30) and n < 400:
			var img: Image = root.get_texture().get_image()
			img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
			img.save_png("%s/f%04d.png" % [gif_dir, n])
			n += 1
		if dr.phase == "volley" and dr.fly_sub == "move" and dr.bolt_i == 2 and dr.bolt_t > 0.4 and not shots.has("move"):
			shots["move"] = true
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT81 + "shot_dragon_flight_move.png"))
			print("SHOT move")
		if dr.phase == "volley" and dr.fly_sub == "after" and dr.bolt_i == 3 and dr.bolt_t > 0.2 and not shots.has("lob"):
			shots["lob"] = true
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT81 + "shot_dragon_flight_lob.png"))
			print("SHOT lob")
		if dr.landings > 0 and dr.phase == "":
			if gif_dir != "":
				for k in 10:
					await process_frame
					if k % 3 == 0:
						var img2: Image = root.get_texture().get_image()
						img2.resize(960, 540, Image.INTERPOLATE_BILINEAR)
						img2.save_png("%s/f%04d.png" % [gif_dir, n])
						n += 1
			break
	print("GIF frames ", n, " spots ", dr.spit_spots)
	quit()
