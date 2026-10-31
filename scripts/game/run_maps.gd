class_name RunMaps
extends RefCounted
## One side-scrolling map per unused Ansimuz tileset.
## The floor is a solid repeated band, and it starts left of the camera so the
## opening view is never a hole. Theme and platforms change with the run seed.

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
const LEFT := 1600.0


static func theme(stage: int, seed: int = 0) -> Dictionary:
	return THEMES[posmod(stage - 1 + seed, THEMES.size())]


static func build(game: Node) -> void:
	var th: Dictionary = theme(game.stage_n, int(game.run_seed))
	game.run_title = String(th["name"])
	var src_tex: Texture2D = load(String(th["file"]))
	var src := _rgba(src_tex.get_image())
	if src == null:
		return
	var tile := 16
	if src.get_width() % 16 != 0 or src.get_height() % 16 != 0:
		tile = 8
	var solid: Array = []
	var cols := src.get_width() / tile
	var rows := src.get_height() / tile
	for y in rows:
		for x in cols:
			if _cover(src, x * tile, y * tile, tile) > 0.92:
				solid.append(Vector2i(x, y))
	if solid.is_empty():
		solid.append(Vector2i(0, rows - 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(game.run_seed) * 10007 + game.stage_n * 97
	var fill: Vector2i = solid[rng.randi() % solid.size()]
	var lip: Vector2i = solid[(rng.randi() + 3) % solid.size()]
	var ink := src.get_pixel(fill.x * tile + tile / 2, fill.y * tile + tile / 2)
	if ink.a < 0.5:
		ink = Color(0.28, 0.24, 0.22, 1)
	var sky := Color(ink.r * 0.18 + 0.03, ink.g * 0.16 + 0.03, ink.b * 0.22 + 0.05, 1)
	RenderingServer.set_default_clear_color(sky)
	var art: float = game.ART
	var floor_y := int(game.GROUND_Y / art) - tile
	var chunk_h := int(ceilf(1080.0 / art)) + tile
	var chunk_w := tile * 20
	var img := Image.create(chunk_w, chunk_h, false, Image.FORMAT_RGBA8)
	img.fill(sky)
	for row in range(floor_y, chunk_h, tile):
		for x in range(0, chunk_w, tile):
			_blit(img, src, fill if row > floor_y else lip, tile, x, row)
	_seal(img, floor_y, ink)
	_span(game, img, art, -8)
	var x := 2200.0
	var n := 0
	while x < game.map_w - 900.0 and n < 14:
		var tiles_n := rng.randi_range(5, 12)
		var rise := 200.0 + float(rng.randi_range(0, 3)) * 140.0
		_platform(game, src, lip, fill, tile, art, x, game.GROUND_Y - rise, tiles_n, ink)
		x += float(tiles_n) * tile * art + rng.randf_range(520.0, 1100.0)
		n += 1
	x = 900.0
	while x < game.map_w - 500.0:
		var stack := rng.randi_range(2, 4)
		var col := Image.create(tile, tile * stack, false, Image.FORMAT_RGBA8)
		for i in stack:
			_blit(col, src, fill, tile, 0, i * tile)
		_seal(col, 0, ink)
		var sp := _sprite(col, art, -6)
		sp.position = Vector2(x, game.GROUND_Y - float(tile * stack) * art)
		game.add_child(sp)
		x += rng.randf_range(780.0, 1400.0)


static func _span(game: Node, img: Image, art: float, z: int) -> void:
	var sp := _sprite(img, art, z)
	var span: float = float(game.map_w) + LEFT + 800.0
	sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sp.region_enabled = true
	sp.region_rect = Rect2(0, 0, span / art, img.get_height())
	sp.position = Vector2(-LEFT, 0)
	game.add_child(sp)


static func _platform(game: Node, src: Image, lip: Vector2i, fill: Vector2i, tile: int, art: float, x: float, top: float, tiles_n: int, ink: Color) -> void:
	var img := Image.create(tile * tiles_n, tile * 2, false, Image.FORMAT_RGBA8)
	for i in tiles_n:
		_blit(img, src, lip, tile, i * tile, 0)
		_blit(img, src, fill, tile, i * tile, tile)
	_seal(img, 0, ink)
	var sp := _sprite(img, art, -4)
	sp.position = Vector2(x, top)
	game.add_child(sp)


static func _sprite(img: Image, art: float, z: int) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = ImageTexture.create_from_image(img)
	sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.scale = Vector2(art, art)
	sp.z_index = z
	return sp


static func _rgba(img: Image) -> Image:
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


static func _cover(img: Image, x: int, y: int, tile: int) -> float:
	var n := 0
	var hit := 0
	for yy in range(0, tile, 2):
		for xx in range(0, tile, 2):
			n += 1
			if img.get_pixel(x + xx, y + yy).a > 0.45:
				hit += 1
	return float(hit) / float(maxi(n, 1))


static func _blit(dst: Image, src: Image, cell: Vector2i, tile: int, dx: int, dy: int) -> void:
	if dx < 0 or dy < 0 or dx + tile > dst.get_width() or dy + tile > dst.get_height():
		return
	dst.blit_rect(src, Rect2i(cell.x * tile, cell.y * tile, tile, tile), Vector2i(dx, dy))


static func _seal(img: Image, y0: int, ink: Color) -> void:
	for y in range(maxi(y0, 0), img.get_height()):
		for x in img.get_width():
			if img.get_pixel(x, y).a < 0.9:
				img.set_pixel(x, y, ink)
