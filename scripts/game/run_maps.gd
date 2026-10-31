class_name RunMaps
extends RefCounted
## v0.10: one side-scrolling map per unused Ansimuz tileset. The sheet is the backdrop,
## a solid tile from it is the ground, and the sparser tiles stand along the lane.

const THEMES := [
	{"id": "caverns", "name": "Caverns", "file": "res://assets/environments/ansimuz/caverns-web/layers/tiles.png"},
	{"id": "country", "name": "Country Platform", "file": "res://assets/environments/ansimuz/country-platform/layers/country-platform-tileset.png"},
	{"id": "day", "name": "Day Platform", "file": "res://assets/environments/ansimuz/day-platformer/PNG/tileset.png"},
	{"id": "gothic_castle", "name": "Gothic Castle", "file": "res://assets/environments/ansimuz/gothic-castle/PNG/layers/gothic-castle-tileset.png"},
	{"id": "gothic_horror", "name": "Gothic Horror", "file": "res://assets/environments/ansimuz/gothic-horror/PNG/layers/tiles.png"},
	{"id": "cemetery_tiles", "name": "Cemetery Tiles", "file": "res://assets/environments/ansimuz/gothicvania-cemetery/tileset.png"},
	{"id": "grunge", "name": "Grunge", "file": "res://assets/environments/ansimuz/grunge-tileset-web/grunge-tileset.png"},
	{"id": "haunted", "name": "Haunted Forest", "file": "res://assets/environments/ansimuz/hauntedforest/Layers/tileset.png"},
	{"id": "junk", "name": "Junk Wastelands", "file": "res://assets/environments/ansimuz/junk-wastelands/layers/tileset.png"},
	{"id": "tissue", "name": "Living Tissue", "file": "res://assets/environments/ansimuz/living-tissue-platform/PNG/layers/tileset.png"},
	{"id": "mist_tiles", "name": "Mist Tiles", "file": "res://assets/environments/ansimuz/mist-forest-background/layers/mist-forest-background-tiles.png"},
	{"id": "modular", "name": "Modular", "file": "res://assets/environments/ansimuz/modular-tileset/layers/modular-tileset.png"},
	{"id": "dark_castle", "name": "Old Dark Castle", "file": "res://assets/environments/ansimuz/old-dark-castle-tileset/PNG/old-dark-castle-interior-tileset.png"},
	{"id": "beach", "name": "Rocky Beach", "file": "res://assets/environments/ansimuz/rocky-beach-environment/layers/tileset.png"},
	{"id": "pass", "name": "Rocky Pass", "file": "res://assets/environments/ansimuz/rocky-pass/PNG/tileset.png"},
	{"id": "rocky", "name": "Rocky", "file": "res://assets/environments/ansimuz/rocky-tileset/PNG/layers/rocky-tileset.png"},
	{"id": "streets", "name": "Streets of Fight", "file": "res://assets/environments/ansimuz/streets-of-fight-stage/tileset.png"},
]


static func theme(stage: int) -> Dictionary:
	return THEMES[posmod(stage - 1, THEMES.size())]


static func build(game: Node) -> void:
	var th: Dictionary = theme(game.stage_n)
	game.run_title = String(th["name"])
	var src_tex: Texture2D = load(String(th["file"]))
	var src := src_tex.get_image()
	if src == null:
		return
	var tile := 16
	if src.get_width() % 16 != 0 or src.get_height() % 16 != 0:
		tile = 8
	var ground: Array = []
	var decor: Array = []
	var cols := src.get_width() / tile
	var rows := src.get_height() / tile
	for y in rows:
		for x in cols:
			var cover := _cover(src, x * tile, y * tile, tile)
			if cover > 0.72:
				ground.append(Vector2i(x, y))
			elif cover > 0.18:
				decor.append(Vector2i(x, y))
	if ground.is_empty():
		ground.append(Vector2i(0, rows - 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(th["id"])) + game.stage_n * 17
	var gtile: Vector2i = ground[rng.randi() % ground.size()]
	var art: float = game.ART
	var native_w := int(game.map_w / art)
	var gh := tile * 3
	var img := Image.create(native_w, gh, false, Image.FORMAT_RGBA8)
	for x in range(0, native_w, tile):
		for row in 3:
			_blit(img, src, gtile, tile, x, row * tile)
	var gtex := ImageTexture.create_from_image(img)
	var ground_sp := Sprite2D.new()
	ground_sp.texture = gtex
	ground_sp.centered = false
	ground_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground_sp.scale = Vector2(art, art)
	ground_sp.position = Vector2(0, game.GROUND_Y - gh * art)
	ground_sp.z_index = -8
	game.add_child(ground_sp)
	var back := Sprite2D.new()
	back.texture = src_tex
	back.centered = false
	back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	back.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	back.region_enabled = true
	back.region_rect = Rect2(0, 0, native_w / 3.0 + src.get_width(), src.get_height())
	back.scale = Vector2(3, 3)
	back.position = Vector2(0, 80)
	back.modulate = Color(0.45, 0.42, 0.5)
	back.z_index = -36
	game.add_child(back)
	var c: Color = src.get_pixel(0, 0)
	RenderingServer.set_default_clear_color(Color(c.r * 0.35, c.g * 0.35, c.b * 0.4))
	if decor.is_empty():
		return
	var step := 460.0
	var x := 900.0
	while x < game.map_w - 400.0:
		var cell: Vector2i = decor[rng.randi() % decor.size()]
		var at := AtlasTexture.new()
		at.atlas = src_tex
		at.region = Rect2(cell.x * tile, cell.y * tile, tile, tile)
		var sp := Sprite2D.new()
		sp.texture = at
		sp.centered = false
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.scale = Vector2(art, art)
		sp.position = Vector2(x, game.GROUND_Y - tile * art)
		sp.z_index = -12
		game.add_child(sp)
		x += step


static func _cover(img: Image, x: int, y: int, tile: int) -> float:
	var n := 0
	var hit := 0
	for yy in range(0, tile, 2):
		for xx in range(0, tile, 2):
			n += 1
			if img.get_pixel(x + xx, y + yy).a > 0.4:
				hit += 1
	return float(hit) / float(maxi(n, 1))


static func _blit(dst: Image, src: Image, cell: Vector2i, tile: int, dx: int, dy: int) -> void:
	dst.blit_rect(src, Rect2i(cell.x * tile, cell.y * tile, tile, tile), Vector2i(dx, dy))
