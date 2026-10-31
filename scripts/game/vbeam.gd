extends SegStrip
## v0.9.1 Y Y Y, then X: a vertical beam from Mera's raised wand straight up past the top of the screen, built from
## the same tessellating beam segments as the X X X Y beam (rotated 90 deg). It grows over 3 frames, sustains, then
## fades, VBEAM_S in all. Every airborne or flying enemy in its column takes VBEAM_DMG x size once.

var game: Node
var s := 1.0
var t := 0.0
var top_y := 0.0           # world y the beam reached (tests)
var hit_ids := {}
var hits := 0


func setup(g: Node, p: Vector2, size: float) -> void:
	game = g
	position = p
	s = size
	scale = Vector2(s, s)
	rotation = PI / 2.0     # the art's beam runs toward -x: turned 90 deg clockwise it runs up
	_build()


func column() -> Rect2:
	var hw := Tuning.VBEAM_HALF_W * s
	return Rect2(position.x - hw, top_y, hw * 2.0, position.y - top_y)


func _build() -> void:
	var info: Dictionary = AnimLib.spells["beam"]
	var rows: Dictionary = info["rows"]
	var tw := float(info["tw"])
	var th := float(info["th"])
	var cy := float(info["cy"])
	var tex := AnimLib.spell_tex("beam")
	var ltex := AnimLib.spell_tex_field("beam", "light")
	var top: float = (game.cam.position.y - 540.0 - 160.0) if game != null else position.y - 1300.0
	var total := maxf((position.y - top) / s, tw)
	var ms := float(info["ms"])
	var tick := int(t * 1000.0 / ms)
	var fade_n := int(rows["fade"][2])
	var fade_t := Tuning.VBEAM_S - fade_n * ms / 1000.0
	var row := "sustain"
	var fi := tick % int(rows["sustain"][2])
	var reach := total
	var end_row := "impact"
	if tick < 3:
		reach = total * [0.3, 0.62, 0.88][tick]
		end_row = "front"
	elif t >= fade_t:
		row = "fade"
		fi = clampi(int((t - fade_t) * 1000.0 / ms), 0, fade_n - 1)
		end_row = "" if fi > 2 else "impact"
	begin()
	var x := 0.0
	var i := 0
	var left := reach
	while left > 0.0:
		var w := minf(tw, left)
		var v := (i * 7 + 1) % int(rows[row][1])
		var r0 := Rect2(fi * tw + tw - w, (int(rows[row][0]) + v) * th, w, th)
		var p := Vector2(x - w, -cy)
		if not put(tex, r0, p, AnimLib.fx_mat, 1):
			break
		put(ltex, r0, p, AnimLib.light_mat, 0)
		x -= w
		left -= w
		i += 1
	if end_row != "":
		var rr := Rect2((tick % int(rows["sustain"][2])) * tw, int(rows[end_row][0]) * th, tw, th)
		put(tex, rr, Vector2(x - tw / 2.0, -cy), AnimLib.fx_mat, 1)
	end()
	top_y = position.y + x * s


func _physics_process(delta: float) -> void:
	t += delta
	if t >= Tuning.VBEAM_S:
		clear()
		queue_free()
		return
	_build()
	if game == null or tick_ok() == false:
		return
	var r := column()
	for e in game.targets():
		var id: int = e.get_instance_id()
		if hit_ids.has(id) or not e.alive() or e.get("is_prop"):
			continue
		if not (bool(e.get("flyer")) or e.get("on_ground") == false):
			continue                         # only airborne / flying enemies: it's an anti-air beam
		if r.intersects(e.hurt_rect()):
			hit_ids[id] = true
			hits += 1
			game.mera.deal(e, Tuning.VBEAM_DMG, position.x, "lightning")


func tick_ok() -> bool:
	return t >= 0.04                         # the column is live from its 2nd frame
