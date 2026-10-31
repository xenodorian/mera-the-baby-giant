extends SceneTree
## v0.7 preview screenshots: an ally card, the picker, the allies fighting, the priestess heal, the dance
const OUT := "res://previews/playable/v0.7/"
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name))
	print("SHOT ", name)


func _run() -> void:
	# a card on the map
	var g: Node = await _new(1)
	var m: Node = g.mera
	var c: Node2D = g.card_nodes[0]
	m.position.x = c.global_position.x - 420.0
	m.set_size(3, true)
	g.snap_camera()
	g.cards = {"ranger": 1}
	await _wait(30)
	await _shot("shot_ally_card.png")
	# the picker
	g.cards = {"priestess": 1, "ranger": 1, "brawler": 2, "dancer": 1}
	g.summon_ally()
	g.picker.move(1)
	await _wait(5)
	await _shot("shot_ally_picker.png")
	g.picker.close()
	g.queue_free()
	await _wait(3)
	# allies fighting
	g = await _new(1)
	m = g.mera
	m.position.x = 6000.0
	m.set_size(3, true)
	g.snap_camera()
	g.cards = {"ranger": 1, "brawler": 1}
	g.summon_type("ranger")
	g.summon_type("brawler")
	g.spawn_enemy("ogre", 6650.0)
	g.spawn_enemy("mutant_toad", 6450.0)
	for i in 200:
		await physics_frame
		m.invuln = 1.0
	await _shot("shot_allies_fight.png")
	g.queue_free()
	await _wait(3)
	# priestess heal
	g = await _new(2)
	m = g.mera
	m.position.x = 6000.0
	m.set_size(2, true)
	g.snap_camera()
	g.cards = {"priestess": 1}
	var p: Node2D = g.summon_type("priestess")
	for i in 200:
		await physics_frame
		if p.state == "heal" and p.sprite.frame >= 8:
			break
	await _shot("shot_priestess_heal.png")
	g.queue_free()
	await _wait(3)
	# the dance
	g = await _new(2)
	m = g.mera
	m.position.x = 8000.0
	m.set_size(3, true)
	g.snap_camera()
	for e in [["skeleton", 8700.0], ["hell_gato", 8500.0], ["ghost", 7400.0], ["death", 8900.0], ["nightmare", 7200.0]]:
		g.spawn_enemy(e[0], e[1], {"variant": "plain"} if e[0] == "skeleton" else {})
	await _wait(60)
	g.cards = {"dancer": 1}
	g.summon_type("dancer")
	for i in 220:
		await physics_frame
		m.invuln = 1.0
	await _shot("shot_dancing_girl.png")
	quit()
