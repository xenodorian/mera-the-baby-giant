extends Node2D
## Banded pixel-art energy beam, drawn procedurally in 1x source pixels.
## Port of the wizard-beam method (GameOfGameBecauseGame reference/wizard_beam_pixel_art.zip, src/render.py):
## a smooth energy value is cut into flat colour bands (0.30 / 0.50 / 0.66 / 0.80 / 0.92) so the glow stays
## crisp pixel art at any integer scale. The parent Rig node carries Mera's size scale and facing, so this
## node only ever draws "to the right" in local pixels starting at (0, 0) = the wand tip.

# Mera's own slash-fx teal ramp, edge to core (thresholds match the source method)
const BANDS := [
	[0.30, Color8(0x28, 0xc0, 0x90)],
	[0.50, Color8(0x48, 0xe0, 0xb0)],
	[0.66, Color8(0x88, 0xf8, 0xd0)],
	[0.80, Color8(0xc8, 0xf8, 0xe8)],
	[0.92, Color8(0xff, 0xff, 0xff)],
]
const HALO := [[0.18, Color8(0x28, 0xc0, 0x90, 102)], [0.06, Color8(0x28, 0xc0, 0x90, 51)]]

enum Phase { OFF, CHARGE, FIRE, SUSTAIN, FADE }
var phase: int = Phase.OFF
var k: int = 0                 # frame index inside the phase
var t: int = 0                 # global animation frame (drives wobble / pulse)
var length: float = 0.0        # current beam length in local px (head position)
var full_length: float = 150.0 # length when fully extended (max range or first hit)
var floor_y: float = 24.0      # ground line relative to the wand tip (for ground strikes)
var charge_frames := 6
var fade_frames := 6

var _rng := RandomNumberGenerator.new()
var _parts: Array = []         # [x, y, vx, vy, life, max, e, g]


func step(p: int, pk: int, frame_t: int, head_len: float, full_len: float) -> void:
	phase = p; k = pk; t = frame_t; length = head_len; full_length = full_len
	_rng.seed = 7919 * frame_t + 17
	_update_particles()
	queue_redraw()


func _env() -> float:
	if phase == Phase.FADE:
		return 1.0 - float(k + 1) / float(fade_frames + 1)
	if phase == Phase.FIRE and k == 0:
		return 0.7
	return 1.0


func _col(e: float) -> Color:
	for i in range(BANDS.size() - 1, -1, -1):
		if e >= BANDS[i][0]:
			return BANDS[i][1]
	for h in HALO:
		if e >= h[0]:
			return h[1]
	return Color(0, 0, 0, 0)


func _px(x: float, y: float, e: float) -> void:
	var c := _col(e)
	if c.a > 0.0:
		draw_rect(Rect2(floorf(x), floorf(y), 1, 1), c)


## Banded disc: energy = clamp(peak - d / r, 0, 1.1). Draws outer band first.
func _disc(cx: float, cy: float, r: float, peak: float, scale_e: float = 1.0) -> void:
	if r <= 0.3:
		return
	var levels := [[0.06, HALO[1][1]], [0.18, HALO[0][1]]]
	for b in BANDS:
		levels.append(b)
	for lv in levels:
		var th: float = lv[0] / scale_e
		var rad := r * (peak - th)
		if rad <= 0.0:
			continue
		var ri := int(ceil(rad))
		for dy in range(-ri, ri + 1):
			var hw := sqrt(maxf(rad * rad - dy * dy, 0.0))
			if hw <= 0.0 and dy != 0:
				continue
			var x0 := floorf(cx - hw + 0.5)
			var x1 := floorf(cx + hw + 0.5)
			draw_rect(Rect2(x0, floorf(cy) + dy, x1 - x0 + 1, 1), lv[1])


func _bolt(xa: float, ya: float, xb: float, yb: float, amp: float, depth: int = 4) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(xa, ya), Vector2(xb, yb)])
	for _d in depth:
		var nw := PackedVector2Array([pts[0]])
		for i in pts.size() - 1:
			var m := (pts[i] + pts[i + 1]) * 0.5
			nw.append(Vector2(m.x + _rng.randf_range(-amp, amp) * 0.4, m.y + _rng.randf_range(-amp, amp)))
			nw.append(pts[i + 1])
		pts = nw
		amp *= 0.55
	return pts


func _raster_bolt(pts: PackedVector2Array, core := 0.97, glow := 0.52) -> void:
	var glow_c := _col(glow)
	var core_c := _col(core)
	var cells: Array = []
	for i in pts.size() - 1:
		var a := pts[i].round()
		var b := pts[i + 1].round()
		var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
		for s in n + 1:
			cells.append(a.lerp(b, float(s) / maxf(n, 1)).round())
	for c in cells:
		draw_rect(Rect2(c.x - 1, c.y, 3, 1), glow_c)
		draw_rect(Rect2(c.x, c.y - 1, 1, 3), glow_c)
	for c in cells:
		draw_rect(Rect2(c.x, c.y, 1, 1), core_c)


func _spawn(x: float, y: float, vx: float, vy: float, life: int, e: float, g: float = 0.0) -> void:
	_parts.append([x, y, vx, vy, life, life, e, g])


func _update_particles() -> void:
	var keep: Array = []
	for p in _parts:
		p[0] += p[2]; p[1] += p[3]; p[3] += p[7]; p[4] -= 1
		if p[1] >= floor_y and p[7] > 0.0:
			p[1] = floor_y - 1; p[3] *= -0.4; p[2] *= 0.6
		if p[4] > 0:
			keep.append(p)
	_parts = keep
	if phase == Phase.OFF:
		return
	var env := _env()
	if phase == Phase.CHARGE:
		return
	if not (phase == Phase.FADE and k > 1):
		for _i in 4:
			var sg := 1.0 if _rng.randf() < 0.5 else -1.0
			_spawn(_rng.randf_range(5, maxf(6, length)), sg * 3 * env, _rng.randf_range(0.3, 1.8), sg * _rng.randf_range(0.4, 1.4), _rng.randi_range(5, 10), _rng.randf_range(0.6, 1.0))
	if length >= full_length - 0.5 and not (phase == Phase.FADE and k > 2):
		for _i in 3:
			_spawn(length - 1, _rng.randf_range(-3, 3), _rng.randf_range(-2.8, -0.8), _rng.randf_range(-2.2, 1.0), _rng.randi_range(7, 14), _rng.randf_range(0.7, 1.0), 0.18)
	if phase == Phase.FADE:
		for _i in 6:
			_spawn(_rng.randf_range(0, length), _rng.randf_range(-2, 2), _rng.randf_range(-0.3, 0.6), _rng.randf_range(-1.0, -0.2), _rng.randi_range(6, 12), _rng.randf_range(0.5, 0.9))


func _draw() -> void:
	if phase == Phase.OFF and _parts.is_empty():
		return
	_rng.seed = 7919 * t + 31   # draw stays read-only and repeatable
	var env := _env()
	if phase == Phase.CHARGE:
		var c := 0.35 + 0.65 * float(k) / float(maxi(charge_frames - 1, 1))
		_disc(0, 0, 1.5 + 2.6 * c + 0.4 * sin(k * 1.3), 1.0, 0.75 + 0.35 * c)
		# motes spiralling in
		for i in 3 + k:
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(4.0, 16.0) * (1.0 - 0.1 * k)
			_px(r * cos(a + r * 0.15), r * sin(a + r * 0.15), _rng.randf_range(0.55, 0.9))
		if k >= 3:  # rune ring closing in
			var rr := 6.0 + (charge_frames - 1 - k)
			for j in 8:
				var a2 := j * TAU / 8.0 + k * 0.35
				_px(round(rr * cos(a2)), round(rr * sin(a2)), 0.85 if j % 2 else 0.6)
	elif phase != Phase.OFF:
		var e_scale := 0.6 + 0.4 * env
		var n := int(length)
		for x in n + 1:
			var rel := float(x)
			if phase == Phase.FADE:
				var thr := float(k + 1) / float(fade_frames)
				var nz := _rng.randf() * 0.6 + 0.4 * (sin(rel * 0.11 + t) * 0.5 + 0.5)
				if nz <= thr * 0.95:
					continue
			var pulse := pow(maxf(0.0, sin(rel * 0.22 - t * 1.9)), 6)
			var base := 3.6 * env * (1 + 0.18 * sin(rel * 0.45 - t * 3.1) + 0.12 * sin(rel * 0.13 + t * 1.3) + 0.35 * pulse)
			base *= 0.45 + 0.55 * clampf(rel / 10.0, 0, 1)
			var wu := base * (1 + _rng.randf_range(-0.22, 0.22))
			var wl := base * (1 + _rng.randf_range(-0.22, 0.22))
			# outer halo first, then each band inward: distance where the profile hits the threshold
			var levels := [[0.06, HALO[1][1]], [0.18, HALO[0][1]]]
			for b in BANDS:
				levels.append(b)
			for lv in levels:
				var q: float = (lv[0] / e_scale - 0.08 * pulse) / 1.08
				if q >= 1.0:
					continue
				var f := pow(1.0 - maxf(q, 0.0), 1.0 / 1.6)
				var du := floorf((wu + 2.0) * f)
				var dl := floorf((wl + 2.0) * f)
				draw_rect(Rect2(x, -du, 1, du + dl + 1), lv[1])
		# muzzle flare + 4-ray star alternating 0 / 45 degrees
		_disc(0, 0, 5.5 + sin(t * 2.1), 1.2, env)
		var a0 := (t % 2) * PI / 4.0
		for j in 4:
			var ang := a0 + j * PI / 2.0
			var ln := 6 + 3 * ((t + j) % 3)
			for r in range(3, int(ln * env) + 1):
				_px(round(r * cos(ang)), round(r * sin(ang)), 0.95 - float(r) / ln * 0.55)
		# crackling arcs
		if not (phase == Phase.FADE and k > 1) and length > 10:
			for _i in _rng.randi_range(2, 4):
				var xa := _rng.randf_range(4, maxf(5, length - 8))
				var xb := minf(xa + _rng.randf_range(10, 28), length)
				var sa := 1.0 if _rng.randf() < 0.5 else -1.0
				var sb := 1.0 if _rng.randf() < 0.5 else -1.0
				var pts := _bolt(xa, sa * (3 * env + _rng.randf_range(1, 6)), xb, sb * (3 * env + _rng.randf_range(1, 6)), 5)
				_raster_bolt(pts)
			if phase == Phase.SUSTAIN and _rng.randf() < 0.3 and length > 30:
				var gx := _rng.randf_range(16, length - 8)
				_raster_bolt(_bolt(gx, 3, gx + _rng.randf_range(-6, 6), floor_y, 4))
		# head / impact
		if length < full_length - 0.5:
			_disc(length, 0, 4.5, 1.15)
		elif not (phase == Phase.FADE and k > 2):
			_disc(length, 0, (5 + 2 * sin(t * 2.7) + _rng.randf_range(-1, 1)) * env, 1.2)
			for j in 7:
				var ang2 := PI / 2 + (j / 6.0) * PI + _rng.randf_range(-0.2, 0.2)
				var ln2 := _rng.randf_range(5, 12) * env
				_raster_bolt(_bolt(length, 0, length + ln2 * cos(ang2), ln2 * sin(ang2), 3, 2), 0.9, 0.45)
	for p in _parts:
		var kk: float = float(p[4]) / float(p[5])
		_px(round(p[0]), round(p[1]), p[6] * (0.45 + 0.55 * kk))
