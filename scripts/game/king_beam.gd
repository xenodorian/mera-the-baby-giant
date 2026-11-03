extends Node2D
## King Nerochilde's long attacks (docs/KING_ARC.md): a tiling beam that is built out to wherever the player stands.
##   kind "energy"  the blue energy beam (8 frames, 32 px tiles with a start and an end cap, pixel art, drawn at x3)
##   kind "zigzag"  the neon zigzag bolt (9 frames, 344 px segments that alternate up and down, additive glow)
## The attack has three beats. AIM: while he winds up (his "!" tell) a faint line follows the player and shows the path. FIRE: the
## line locks where it pointed; the beam is then built out along it, head first, to the player's distance and a little past, from any
## direction (above, below, either side). HOLD then FADE: it crackles, then dies. It hurts once, anything its drawn length touches:
## the player takes Mera.take_hit, so blocking (the bubble), a dodge or a parry works as against any attack.
## Art: assets/characters/king/fx/beam and zigzag (the owner's tiling assets, atlases unchanged).

const BEAM_TEX := "res://assets/characters/king/fx/beam/beam_atlas.png"
const ZIG_TEX := "res://assets/characters/king/fx/zigzag/zigzag_segments_atlas.png"
const CAP_TEX := "res://assets/characters/king/fx/zigzag/zigzag_caps_atlas.png"
const BEAM_S := 3.0                   # pixel scale of the energy beam (48 px tall at x3 = 144)
const BEAM_FRAME_S := 0.07
const BEAM_HIT_R := 46.0
const ZIG_FRAME_S := 0.055
const ZIG_SEG := Vector2(344.0, -106.0)    # one segment's vector
const ZIG_CELL := Vector2(472.0, 234.0)
const ZIG_START := Vector2(64.0, 170.0)    # the start tip inside a cell
const ZIG_START_FLIPPED := Vector2(64.0, 63.0)
const ZIG_HIT_R := 34.0
const EXTEND_S := 0.35
const HOLD_S := 0.5
const FADE_S := 0.25
const AIM_MAX_S := 2.0
const OVERSHOOT := 140.0

var game: Node = null
var owner_node: Node2D = null
var kind := "energy"
var dmg := 2
var phase := "aim"                    # aim | fire | done
var t := 0.0                          # seconds in the current phase
var angle := 0.0
var length := 800.0                   # the full length once fired
var head := 0.0                       # how far it has been built out
var hit_done := {}                    # target instance id -> true
var hits := 0                         # times it has hurt someone (tests)
var origin_off := Vector2.ZERO        # from the owner's feet to the emitter
var _tex: Texture2D = null
var _zig: Texture2D = null
var _caps: Texture2D = null


func setup(g: Node, who: Node2D, beam_kind: String, damage: int, emit: Vector2) -> void:
	game = g
	owner_node = who
	kind = beam_kind
	dmg = damage
	origin_off = emit
	z_index = 8
	if kind == "zigzag":
		_zig = load(ZIG_TEX)
		_caps = load(CAP_TEX)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
	else:
		_tex = load(BEAM_TEX)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_follow_owner()
	_aim_at_prey()


func _follow_owner() -> void:
	if is_instance_valid(owner_node):
		var f := float(owner_node.get("facing"))
		position = owner_node.global_position + Vector2(origin_off.x * f, origin_off.y)


func _prey_center() -> Vector2:
	if game != null and is_instance_valid(game.mera):
		return game.mera.hurt_rect().get_center()
	return position + Vector2(-600.0, 0.0)


func _aim_at_prey() -> void:
	angle = (_prey_center() - position).angle()


## the wind-up ends: lock the line and start building the beam out to where the player is now
func fire() -> void:
	if phase != "aim":
		return
	_follow_owner()
	_aim_at_prey()
	length = clampf(position.distance_to(_prey_center()) + OVERSHOOT, 420.0, 2600.0)
	phase = "fire"
	t = 0.0
	head = 0.0
	if game != null:
		game.shake(8.0, 0.25)
	Sfx.play("cast", 0.6, -2.0)


func _physics_process(delta: float) -> void:
	t += delta
	if phase == "aim":
		if not is_instance_valid(owner_node) or t > AIM_MAX_S or String(owner_node.get("state")) not in ["tell", "atk"]:
			queue_free()                       # the wind-up was broken (stunned, killed): nothing fires
			return
		_follow_owner()
		_aim_at_prey()
		queue_redraw()
		return
	head = length * clampf(t / EXTEND_S, 0.0, 1.0)
	if t > EXTEND_S + HOLD_S + FADE_S:
		queue_free()
		return
	if t <= EXTEND_S + HOLD_S:
		_hit_check()
	queue_redraw()


## world points along the built part of the beam (every 20 px)
func _path_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var dir := Vector2.from_angle(angle)
	var nrm := dir.orthogonal()
	var x := 0.0
	while x <= head:
		var off := 0.0
		if kind == "zigzag":
			off = _zig_offset(x)
		pts.append(position + dir * x - nrm * off)       # local y (down) is -orthogonal: the zigzag offset is a local y
		x += 20.0
	return pts


## the zigzag's centre line: vertices alternate between +53 and -53 around the aim axis, one every 344 px
func _zig_offset(x: float) -> float:
	var k := int(floor(x / ZIG_SEG.x))
	var u := (x - float(k) * ZIG_SEG.x) / ZIG_SEG.x
	var a := 53.0 if k % 2 == 0 else -53.0
	var b := -a
	# local y grows downward: an even segment climbs from y +53 to y -53
	return lerpf(a, b, u)


func _hit_check() -> void:
	var r := BEAM_HIT_R if kind == "energy" else ZIG_HIT_R
	var pts := _path_points()
	var m = game.mera if game != null else null
	if m != null and is_instance_valid(m) and m.state != "dead" and not hit_done.has(m.get_instance_id()):
		var box: Rect2 = m.hurt_rect().grow(r)
		for p in pts:
			if box.has_point(p):
				hit_done[m.get_instance_id()] = true
				hits += 1
				m.take_hit(dmg, global_position.x, owner_node if is_instance_valid(owner_node) else null)
				break
	if game != null and game.has_method("allies"):
		for a in game.allies():
			if not is_instance_valid(a) or not a.alive() or hit_done.has(a.get_instance_id()):
				continue
			var abox: Rect2 = a.hurt_rect().grow(r)
			for p in pts:
				if abox.has_point(p):
					hit_done[a.get_instance_id()] = true
					a.take_hit(dmg, global_position.x)
					break


# ---------------------------------------------------------------- drawing (local space: x along the beam, rotated by `angle`)
func _draw() -> void:
	if phase == "aim":
		_draw_aim()
		return
	if phase != "fire":
		return
	draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
	var fade := 1.0
	if t > EXTEND_S + HOLD_S:
		fade = clampf(1.0 - (t - EXTEND_S - HOLD_S) / FADE_S, 0.0, 1.0)
	var col := Color(1, 1, 1, fade)
	if kind == "energy":
		_draw_energy(col)
	else:
		_draw_zigzag(col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_aim() -> void:
	var a := 0.25 + 0.2 * sin(t * 24.0)
	var blen := minf(position.distance_to(_prey_center()) + OVERSHOOT, 2600.0)
	draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
	if kind == "energy":
		draw_line(Vector2.ZERO, Vector2(blen, 0.0), Color(0.5, 0.8, 1.0, a), 6.0)
	else:
		var pts := PackedVector2Array()
		var x := 0.0
		while x <= blen:
			pts.append(Vector2(x, _zig_offset(x)))
			x += 20.0
		if pts.size() >= 2:
			draw_polyline(pts, Color(1.0, 0.35, 0.95, a), 5.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_energy(col: Color) -> void:
	var f := int(t / BEAM_FRAME_S) % 8
	var s := BEAM_S
	var x := 0.0
	while x < head:
		var w := minf(32.0 * s, head - x)
		draw_texture_rect_region(_tex, Rect2(x, -24.0 * s, w, 48.0 * s), Rect2(f * 32, 48, w / s, 48), col)
		x += 32.0 * s
	draw_texture_rect_region(_tex, Rect2(-16.0 * s, -24.0 * s, 32.0 * s, 48.0 * s), Rect2(f * 32, 0, 32, 48), col)
	draw_texture_rect_region(_tex, Rect2(head - 24.0 * s, -24.0 * s, 48.0 * s, 48.0 * s), Rect2(f * 48, 96, 48, 48), col)


func _draw_zigzag(col: Color) -> void:
	var f := int(t / ZIG_FRAME_S)
	var n := int(ceil(head / ZIG_SEG.x)) + 1
	for k in n:
		var vx := float(k) * ZIG_SEG.x
		if vx >= head:
			break
		var up := k % 2 == 0
		var vy := 53.0 if up else -53.0                 # the vertex this segment starts on (offset about the aim axis)
		# local y grows downward: an upward segment runs from y +53 to y -53
		var idx := (f + 4 * k) % 9
		var src_x := float(idx % 3) * ZIG_CELL.x
		var src_y := float(idx / 3) * ZIG_CELL.y
		var clip_w := clampf((head - vx) + ZIG_START.x, 0.0, ZIG_CELL.x)
		var src := Rect2(src_x, src_y, clip_w, ZIG_CELL.y)
		if up:
			draw_texture_rect_region(_zig, Rect2(vx - ZIG_START.x, vy - ZIG_START.y, clip_w, ZIG_CELL.y), src, col)
		else:
			# flipped vertically: a negative height mirrors the cell, its start tip lands on ZIG_START_FLIPPED
			draw_texture_rect_region(_zig, Rect2(vx - ZIG_START_FLIPPED.x, vy - ZIG_START_FLIPPED.y + ZIG_CELL.y, clip_w, -ZIG_CELL.y), src, col)
	# glow pieces: the start flare, a joint flare on each finished corner, the impact flare on the head
	var cf := int(t / ZIG_FRAME_S) % 9
	_cap(0, cf, Vector2(0.0, 53.0), col)
	for k in range(1, n):
		var cx := float(k) * ZIG_SEG.x
		if cx < head:
			_cap(1, cf, Vector2(cx, -53.0 if k % 2 == 1 else 53.0), col)
	_cap(2, cf, Vector2(head, _zig_offset(head)), col)


func _cap(row: int, frame: int, at: Vector2, col: Color) -> void:
	draw_texture_rect_region(_caps, Rect2(at - Vector2(96, 96), Vector2(192, 192)), Rect2(frame * 192, row * 192, 192, 192), col)
