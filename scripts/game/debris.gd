class_name Debris
extends Node2D
## v0.8 (S4) shatter / debris sim (docs/GAME_RULES.md "Shatter, gibs and gore"). Plain GDScript, no add-ons, works
## on the Compatibility renderer: a destroyed sprite is cut into jittered triangle/quad shards of its own texture
## (the current animation frame, flipped and scaled as drawn), and every shard is a tiny rigid body integrated here
## (gravity, spin, bounces off the ground and the map walls, friction, fade). All shards are drawn by this one node
## with draw_polygon(), so 400 pieces cost one CanvasItem. Gibs (Reactorcore CC0 meat chunks) ride the same sim;
## blood is an animated splash (Reactorcore) + a CPUParticles2D spray. Hit sparks use a small pool of CPUParticles2D.

const GORE_DIR := "res://assets/vfx/gore/"
const GIB_N := 18
const BONE_GIBS := [14, 15, 16, 17]
const GROUND_BOUNCE := 0.32
const GRAVITY := 2600.0

var game: Node = null
var ground_y := 1060.0
var lo_x := -1e9
var hi_x := 1e9
var pieces: Array = []           # each: {tex, pts, uvs, pos, vel, rot, w, sc, life, age, col, rest}
var total_spawned := 0           # tests
var shatters := 0                # tests
var gib_bursts := 0              # tests
var _alpha_cache := {}           # texture rid -> Image (or null when it can't be read back)
var _gibs: Array = []
var _spark_pool: Array = []
var _spark_i := 0
var _blood_pool: Array = []
var _blood_i := 0
var _blast_frames: Array = []
static var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 8
	for i in GIB_N:
		_gibs.append(load(GORE_DIR + "gib_%02d.png" % i))
	var bb: Texture2D = load(GORE_DIR + "blood_blast.png")
	for i in 13:
		var at := AtlasTexture.new()
		at.atlas = bb
		at.region = Rect2(i * 34, 0, 34, 34)
		_blast_frames.append(at)
	for i in 6:
		_spark_pool.append(_make_spray(Color(1.0, 0.95, 0.7), Color(1.0, 0.55, 0.1), 14, 0.28, 3.0))
	for i in 4:
		_blood_pool.append(_make_spray(Color(0.75, 0.04, 0.04), Color(0.35, 0.0, 0.02), 40, 0.7, 4.0))


func _make_spray(c0: Color, c1: Color, n: int, life: float, px: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = n
	p.lifetime = life
	p.explosiveness = 0.95
	p.local_coords = false
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 260.0
	p.initial_velocity_max = 760.0
	p.gravity = Vector2(0, 1800.0)
	p.scale_amount_min = px
	p.scale_amount_max = px * 1.6
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, Color(c1.r, c1.g, c1.b, 0.0))
	p.color_ramp = g
	add_child(p)
	return p


# ---------------------------------------------------------------- shatter
## Shatter whatever `node` (Sprite2D or AnimatedSprite2D) is showing right now. `from` = world point the blow came
## from (pieces fly away from it), `power` px/s. opts: cols, rows, life, tint (Color), spin
func shatter_node(node: Node2D, from: Vector2, power: float, opts: Dictionary = {}) -> int:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return 0
	var tex: Texture2D = null
	var region := Rect2()
	var off := Vector2.ZERO
	if node is AnimatedSprite2D:
		var a := node as AnimatedSprite2D
		if a.sprite_frames == null:
			return 0
		tex = a.sprite_frames.get_frame_texture(a.animation, a.frame)
		if tex == null:
			return 0
		region = Rect2(Vector2.ZERO, tex.get_size())
		off = a.offset - (tex.get_size() / 2.0 if a.centered else Vector2.ZERO)
	elif node is Sprite2D:
		var s := node as Sprite2D
		tex = s.texture
		if tex == null:
			return 0
		if s.region_enabled:
			region = s.region_rect
		elif s.hframes > 1 or s.vframes > 1:
			var fw := tex.get_width() / float(s.hframes)
			var fh := tex.get_height() / float(s.vframes)
			region = Rect2((s.frame % s.hframes) * fw, (s.frame / s.hframes) * fh, fw, fh)
		else:
			region = Rect2(Vector2.ZERO, tex.get_size())
		off = s.offset - (region.size / 2.0 if s.centered else Vector2.ZERO)
	else:
		return 0
	var xf: Transform2D = node.get_global_transform() * Transform2D(0.0, off - region.position)
	var col: Color = opts.get("tint", Color(1, 1, 1)) * node.modulate * node.self_modulate
	col.a = 1.0
	return shatter_texture(tex, region, xf, from, power, opts, col)


## the core: texel `region` of `tex`, drawn by `xf` (texel -> world), cut into shards
func shatter_texture(tex: Texture2D, region: Rect2, xf: Transform2D, from: Vector2, power: float, opts: Dictionary = {}, col: Color = Color(1, 1, 1)) -> int:
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		region = Rect2(region.position + at.region.position, region.size)
		xf = xf * Transform2D(0.0, -at.region.position)
		tex = at.atlas
	var tsize := tex.get_size()
	var cols := int(opts.get("cols", 6))
	var rows := int(opts.get("rows", 6))
	var life := float(opts.get("life", 1.6))
	var img: Image = _alpha_image(tex)
	# jittered grid of texel points over the region
	var grid: Array = []
	for r in rows + 1:
		var line: Array = []
		for c in cols + 1:
			var p := region.position + Vector2(region.size.x * c / cols, region.size.y * r / rows)
			if r > 0 and r < rows and c > 0 and c < cols:
				p += Vector2(_rng.randf_range(-0.3, 0.3) * region.size.x / cols, _rng.randf_range(-0.3, 0.3) * region.size.y / rows)
			line.append(p)
		grid.append(line)
	var n := 0
	shatters += 1
	for r in rows:
		for c in cols:
			var a: Vector2 = grid[r][c]
			var b: Vector2 = grid[r][c + 1]
			var cc: Vector2 = grid[r + 1][c + 1]
			var d: Vector2 = grid[r + 1][c]
			var polys: Array = []
			if _rng.randf() < 0.35:
				polys.append([a, b, cc, d])                       # some quads, mostly triangles: varied shard shapes
			elif _rng.randf() < 0.5:
				polys.append([a, b, cc]); polys.append([a, cc, d])
			else:
				polys.append([a, b, d]); polys.append([b, cc, d])
			for poly in polys:
				if img != null and not _opaque(img, poly):
					continue
				_add_shard(tex, tsize, poly, xf, from, power, life, col, opts)
				n += 1
	return n


func _alpha_image(tex: Texture2D) -> Image:
	var key := tex.get_rid()
	if _alpha_cache.has(key):
		return _alpha_cache[key]
	var img: Image = null
	if DisplayServer.get_name() != "headless":
		img = tex.get_image()
		if img != null and img.is_compressed():
			img = null
	_alpha_cache[key] = img
	return img


func _opaque(img: Image, poly: Array) -> bool:
	var cen := Vector2.ZERO
	for p in poly:
		cen += p
	cen /= float(poly.size())
	var probes: Array = [cen]
	for p in poly:
		probes.append(cen.lerp(p, 0.6))
	for q in probes:
		var x := clampi(int(q.x), 0, img.get_width() - 1)
		var y := clampi(int(q.y), 0, img.get_height() - 1)
		if img.get_pixel(x, y).a > 0.1:
			return true
	return false


func _add_shard(tex: Texture2D, tsize: Vector2, poly: Array, xf: Transform2D, from: Vector2, power: float, life: float, col: Color, opts: Dictionary) -> void:
	var cen := Vector2.ZERO
	for p in poly:
		cen += p
	cen /= float(poly.size())
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for p in poly:
		pts.append(p - cen)
		uvs.append(p / tsize)
	var wc: Vector2 = xf * cen
	var dir := (wc - from)
	dir = dir.normalized() if dir.length() > 1.0 else Vector2(_rng.randf_range(-1, 1), -1).normalized()
	var v := dir * power * _rng.randf_range(0.45, 1.15) + Vector2(_rng.randf_range(-0.25, 0.25) * power, -power * _rng.randf_range(0.25, 0.75))
	var basis := Transform2D(xf.x, xf.y, Vector2.ZERO)
	_push({"tex": tex, "pts": pts, "uvs": uvs, "pos": wc, "vel": v, "rot": 0.0, "w": _rng.randf_range(-12.0, 12.0) * float(opts.get("spin", 1.0)),
		"basis": basis, "life": life * _rng.randf_range(0.8, 1.2), "age": 0.0, "col": col, "rest": false, "half": _half(pts, basis)})


## half the shard's on-screen height (it rests on the ground with its centre this far up)
func _half(pts: PackedVector2Array, basis: Transform2D) -> float:
	var m := 0.0
	for p in pts:
		m = maxf(m, (basis * p).length())
	return m * 0.5


func _push(pc: Dictionary) -> void:
	if pieces.size() >= Tuning.SHARDS_MAX:
		pieces.pop_front()
	pieces.append(pc)
	total_spawned += 1


# ---------------------------------------------------------------- gore
## gibs (meat chunks, or bones), a blood splash and a red pixel spray at `p`; s = size of the creature (its scale)
func gore(p: Vector2, s: float, from: Vector2, kind: String = "flesh", n: int = 10) -> void:
	if not Tuning.GORE:
		return
	gib_bursts += 1
	if kind == "ghost":
		_splash(p, s, Color(0.7, 0.85, 1.0, 0.8))
		return
	if kind == "fire":
		spark(p, s * 1.5)
		return
	var pool: Array = BONE_GIBS if kind == "bone" else range(0, 14)
	for i in n:
		var tex: Texture2D = _gibs[pool[_rng.randi() % pool.size()]]
		var hs := tex.get_size() / 2.0
		var pts := PackedVector2Array([Vector2(-hs.x, -hs.y), Vector2(hs.x, -hs.y), Vector2(hs.x, hs.y), Vector2(-hs.x, hs.y)])
		var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		var dir := (p - from).normalized() if (p - from).length() > 1.0 else Vector2.UP
		var v := (dir * 0.6 + Vector2(_rng.randf_range(-1, 1), -_rng.randf_range(0.6, 1.4))).normalized() * _rng.randf_range(500.0, 1100.0)
		var gs := clampf(s * 0.9, 2.0, 7.0)
		_push({"tex": tex, "pts": pts, "uvs": uvs, "pos": p + Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-20, 20)), "vel": v,
			"rot": _rng.randf() * TAU, "w": _rng.randf_range(-14.0, 14.0), "basis": Transform2D(0.0, Vector2(gs, gs), 0.0, Vector2.ZERO),
			"life": _rng.randf_range(2.0, 3.2), "age": 0.0, "col": Color(1, 1, 1), "rest": false, "half": hs.y * gs * 0.5})
	if kind != "bone":
		_splash(p, s, Color(1, 1, 1))
		var sp: CPUParticles2D = _blood_pool[_blood_i % _blood_pool.size()]
		_blood_i += 1
		sp.global_position = p
		sp.scale_amount_min = clampf(s, 3.0, 8.0)
		sp.scale_amount_max = clampf(s, 3.0, 8.0) * 1.5
		sp.restart()
		sp.emitting = true


func _splash(p: Vector2, s: float, tint: Color) -> void:
	var a := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_loop("default", false)
	sf.set_animation_speed("default", 24.0)
	for f in _blast_frames:
		sf.add_frame("default", f)
	a.sprite_frames = sf
	a.scale = Vector2.ONE * clampf(s * 1.6, 4.0, 14.0)
	a.global_position = p
	a.modulate = tint
	a.animation_finished.connect(a.queue_free)
	add_child(a)
	a.play("default")


## hit sparks: a short burst of hot pixels (pooled CPUParticles2D)
func spark(p: Vector2, s: float) -> void:
	var sp: CPUParticles2D = _spark_pool[_spark_i % _spark_pool.size()]
	_spark_i += 1
	sp.global_position = p
	sp.scale_amount_min = clampf(s * 1.5, 2.0, 9.0)
	sp.scale_amount_max = clampf(s * 2.5, 3.0, 14.0)
	sp.initial_velocity_max = 500.0 + 120.0 * s
	sp.restart()
	sp.emitting = true


# ---------------------------------------------------------------- sim
func _physics_process(delta: float) -> void:
	if pieces.is_empty():
		return
	var keep: Array = []
	for pc in pieces:
		pc["age"] = float(pc["age"]) + delta
		if float(pc["age"]) >= float(pc["life"]):
			continue
		if not pc["rest"]:
			var v: Vector2 = pc["vel"]
			v.y += GRAVITY * delta
			var p: Vector2 = pc["pos"] + v * delta
			var floor_y := ground_y - float(pc["half"])
			if p.y >= floor_y:
				p.y = floor_y
				if v.y > 220.0:
					v.y = -v.y * GROUND_BOUNCE
					v.x *= 0.7
					pc["w"] = float(pc["w"]) * 0.6
				else:
					v = Vector2.ZERO
					pc["w"] = 0.0
					pc["rest"] = true
			if p.x < lo_x or p.x > hi_x:
				p.x = clampf(p.x, lo_x, hi_x)
				v.x = -v.x * 0.5
			pc["vel"] = v
			pc["pos"] = p
			pc["rot"] = float(pc["rot"]) + float(pc["w"]) * delta
		keep.append(pc)
	pieces = keep
	queue_redraw()


func _draw() -> void:
	var gp := global_position
	for pc in pieces:
		var c: Color = pc["col"]
		var left := float(pc["life"]) - float(pc["age"])
		if left < 0.4:
			c.a *= left / 0.4
		draw_set_transform_matrix(Transform2D(float(pc["rot"]), pc["pos"] - gp) * (pc["basis"] as Transform2D))
		draw_polygon(pc["pts"], PackedColorArray([c]), pc["uvs"], pc["tex"])
	draw_set_transform_matrix(Transform2D.IDENTITY)
