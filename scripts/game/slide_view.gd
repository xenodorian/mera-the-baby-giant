class_name SlideView
extends Control
## One story slide of the opening slideshow (data: scripts/game/story_slides.gd, played by scripts/game/cutscene.gd).
## A pixel-art painting drawn at an integer 3x scale (so it is wider than the 1920 x 804 band and PANS), optional zoom, a colour
## wash, vignette and effects (fire, flicker, shake, flashes), and animated sprites (roster creatures, Perry, Nero, Mera) that
## ride along with the painting. Everything is a function of the time `t`, so set_time(t) renders any moment (screenshots, tests).

const BAND := Vector2(1920.0, 804.0)
const SCALE := 3.0                      # paintings are drawn at this integer pixel scale
const FADE_IN_S := 0.6

var slide: Dictionary = {}
var t := 0.0
var running := true                     # false after set_time(): the picture then holds still
var shown := false                      # a slide with a picture is loaded
var _fade_t := 0.0
var _bg: Texture2D = null
var _sprites: Array = []                # [{def, frames: [{tex, src, off, ms}]}]
var _cache := {}


func _ready() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = BAND
	size = BAND


## id: a key of StorySlides.SLIDES, or a slide Dictionary. An empty id clears the picture. False when nothing was shown.
func show_slide(def: Variant, fade_in: bool = true) -> bool:
	slide = {}
	_bg = null
	_sprites = []
	shown = false
	var d: Dictionary = {}
	if def is Dictionary:
		d = def
	elif def is String and String(def) != "" and StorySlides.has_slide(String(def)):
		d = StorySlides.get_slide(String(def))
	if d.is_empty():
		queue_redraw()
		return false
	slide = d
	t = 0.0
	running = true
	_fade_t = 0.0 if fade_in else FADE_IN_S
	modulate.a = 0.0 if fade_in else 1.0
	if d.has("bg"):
		_bg = load(String(d["bg"])) as Texture2D
	for s in d.get("sprites", []):
		var sp := _make_sprite(s)
		if not sp.is_empty():
			_sprites.append(sp)
	shown = true
	queue_redraw()
	return true


## render exactly this moment (no more automatic advance)
func set_time(time: float) -> void:
	running = false
	t = time
	modulate.a = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if not shown or not running:
		return
	t += delta
	_fade_t += delta
	modulate.a = clampf(_fade_t / FADE_IN_S, 0.0, 1.0)
	queue_redraw()


# ---------------------------------------------------------------- data
func _tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


## a sprite def -> its frames. Roster creatures (who = a roster id; frames are whole images with a feet pivot) and Mera
## (who = "mera"; AnimLib's baked strips: each frame is a crop with an offset from her feet)
func _make_sprite(def: Dictionary) -> Dictionary:
	var who := String(def.get("who", ""))
	var anim := String(def.get("anim", "idle"))
	var frames: Array = []
	if who == "mera":
		if not AnimLib.anims.has(anim):
			anim = "idle"
		var sheet: Texture2D = AnimLib.sheet(anim)
		for f in AnimLib.frames(anim):
			var c = f.get("c")
			if c == null:
				continue
			frames.append({"tex": sheet, "src": Rect2(float(c[0]), float(c[1]), float(c[2]), float(c[3])),
				"off": Vector2(float(c[4]), float(c[5])), "ms": maxf(float(f.get("ms", 100)), 16.0)})
	else:
		var data := Roster.data()
		if not data.has(who):
			return {}
		var anims: Dictionary = data[who]["anims"]
		if not anims.has(anim):
			anim = String(anims.keys()[0])
		var an: Dictionary = anims[anim]
		var piv := Vector2(float(an["pivot"][0]), float(an["pivot"][1]))
		var fps := float(def.get("fps", 0.0))
		if fps <= 0.0:
			fps = maxf(float(an.get("fps", 8.0)), 1.0)
		for p in an["frames"]:
			var tx := _tex(String(p))
			if tx == null:
				continue
			frames.append({"tex": tx, "src": Rect2(Vector2.ZERO, tx.get_size()), "off": -piv, "ms": 1000.0 / fps})
	if frames.is_empty():
		return {}
	return {"def": def, "frames": frames}


static func _vec(a: Variant) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _col(a: Variant, fallback: Color = Color.WHITE) -> Color:
	if a == null or (a as Array).size() < 3:
		return fallback
	return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if (a as Array).size() > 3 else 1.0)


static func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


# ---------------------------------------------------------------- the painting's transform at time `time`
## {s: pixel scale, x: left edge, y: top edge} of the painting in the band
func _bg_xf(time: float) -> Dictionary:
	if _bg == null:
		return {"s": 1.0, "x": 0.0, "y": 0.0}
	var dur := maxf(float(slide.get("dur", 12.0)), 0.001)
	var k := _ease(time / dur)
	var zoom_a: Array = slide.get("zoom", [1.0, 1.0])
	var pan_a: Array = slide.get("pan", [0.5, 0.5])
	var z := lerpf(float(zoom_a[0]), float(zoom_a[1]), k)
	var p := lerpf(float(pan_a[0]), float(pan_a[1]), k)
	var s := SCALE * z
	var w := _bg.get_width() * s
	var h := _bg.get_height() * s
	var x := -(w - BAND.x) * p if w > BAND.x else (BAND.x - w) * 0.5
	var y := (BAND.y - h) * 0.5
	return {"s": s, "x": x, "y": y}


func _draw() -> void:
	if not shown:
		return
	draw_rect(Rect2(Vector2.ZERO, BAND), Color.BLACK)
	var fx: Array = slide.get("fx", [])
	var shake := Vector2.ZERO
	if "shake" in fx:
		shake = Vector2(sin(t * 53.0) * 3.0 + sin(t * 31.0) * 2.0, cos(t * 47.0) * 3.0)
	var xf := _bg_xf(t)
	var xf0 := _bg_xf(0.0)
	if _bg != null:
		var s: float = xf["s"]
		draw_texture_rect(_bg, Rect2(Vector2(float(xf["x"]), float(xf["y"])) + shake, _bg.get_size() * s), false)
	for sp in _sprites:
		_draw_sprite(sp, xf, xf0, shake)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tint := _col(slide.get("tint"), Color(0, 0, 0, 0))
	if tint.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, BAND), tint)
	if "fire" in fx:
		var a := 0.20 + 0.10 * sin(t * 6.3) + 0.06 * sin(t * 13.1)
		var warm := Color(1.0, 0.42, 0.08, a)
		draw_polygon(PackedVector2Array([Vector2(0, BAND.y * 0.35), Vector2(BAND.x, BAND.y * 0.35), Vector2(BAND.x, BAND.y), Vector2(0, BAND.y)]),
			PackedColorArray([Color(warm.r, warm.g, warm.b, 0.0), Color(warm.r, warm.g, warm.b, 0.0), warm, warm]))
	if "flicker" in fx:
		var f := 0.5 + 0.5 * sin(t * 17.0) * sin(t * 5.3 + 1.3)
		draw_rect(Rect2(Vector2.ZERO, BAND), Color(0, 0, 0, 0.03 + 0.10 * f))
	var vig := float(slide.get("vignette", 0.0))
	if vig > 0.0:
		_draw_vignette(vig)
	var dark := float(slide.get("dark", 0.0))
	if dark > 0.0:
		draw_rect(Rect2(Vector2.ZERO, BAND), Color(0, 0, 0, clampf(dark, 0.0, 1.0)))
	for ft in slide.get("flashes", []):
		var age := t - float(ft)
		if age >= 0.0 and age < 0.4:
			draw_rect(Rect2(Vector2.ZERO, BAND), Color(1, 1, 1, 0.75 * (1.0 - age / 0.4)))


func _draw_vignette(v: float) -> void:
	var edge := Color(0, 0, 0, clampf(v, 0.0, 1.0) * 0.85)
	var none := Color(0, 0, 0, 0)
	var d := 260.0
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(BAND.x, 0), Vector2(BAND.x, d), Vector2(0, d)]), PackedColorArray([edge, edge, none, none]))
	draw_polygon(PackedVector2Array([Vector2(0, BAND.y - d), Vector2(BAND.x, BAND.y - d), Vector2(BAND.x, BAND.y), Vector2(0, BAND.y)]), PackedColorArray([none, none, edge, edge]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(d, 0), Vector2(d, BAND.y), Vector2(0, BAND.y)]), PackedColorArray([edge, none, none, edge]))
	draw_polygon(PackedVector2Array([Vector2(BAND.x - d, 0), Vector2(BAND.x, 0), Vector2(BAND.x, BAND.y), Vector2(BAND.x - d, BAND.y)]), PackedColorArray([none, edge, edge, none]))


func _draw_sprite(sp: Dictionary, xf: Dictionary, xf0: Dictionary, shake: Vector2) -> void:
	var d: Dictionary = sp["def"]
	var at := float(d.get("at", 0.0))
	if t < at or t > float(d.get("until", 1e9)):
		return
	var pos := _vec(d.get("pos", [0, 0]))
	var scl := float(d.get("scale", 4.0))
	var base_a := _col(d.get("color"), Color.WHITE)
	var alpha := base_a.a                                   # the colour's alpha is where alpha tweens start from
	var rot := 0.0
	for mv in d.get("move", []):
		var k := _ease((t - float(mv.get("t", 0.0))) / maxf(float(mv.get("dur", 1.0)), 0.001))
		if mv.has("to"):
			pos = pos.lerp(_vec(mv["to"]), k)
		if mv.has("scale"):
			scl = lerpf(scl, float(mv["scale"]), k)
		if mv.has("alpha"):
			alpha = lerpf(alpha, float(mv["alpha"]), k)
		if mv.has("rot"):
			rot = lerpf(rot, float(mv["rot"]), k)
	if at > 0.0:
		alpha *= clampf((t - at) / 0.4, 0.0, 1.0)                         # appears with a short fade
	# the sprite is glued to the painting: its position is where it stood when the slide began
	var s0: float = xf0["s"]
	var s1: float = xf["s"]
	var q := (pos - Vector2(float(xf0["x"]), float(xf0["y"]))) / s0
	var screen := Vector2(float(xf["x"]) + q.x * s1, float(xf["y"]) + q.y * s1) + shake
	var zoom_ratio := s1 / s0
	var frames: Array = sp["frames"]
	var clock := t * 1000.0
	var total := 0.0
	for f in frames:
		total += float(f["ms"])
	var tm := fposmod(clock, maxf(total, 1.0))
	var fr: Dictionary = frames[0]
	var acc := 0.0
	for f in frames:
		acc += float(f["ms"])
		if tm < acc:
			fr = f
			break
	var sx := scl * zoom_ratio * (-1.0 if bool(d.get("flip", false)) else 1.0)
	var sy := scl * zoom_ratio
	draw_set_transform(screen, deg_to_rad(rot), Vector2(sx, sy))
	var mod := Color(base_a.r, base_a.g, base_a.b, clampf(alpha, 0.0, 1.0))
	var src: Rect2 = fr["src"]
	draw_texture_rect_region(fr["tex"], Rect2(fr["off"], src.size), src, mod)
