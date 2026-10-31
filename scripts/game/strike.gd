class_name Strike
extends SegStrip
## R1 lightning strike built from tessellating segments (tools/tess_spells.py): a ground-impact cap at the bottom,
## as many mid segments as it takes to pass the top of the screen (plus a margin), and a fading fork cap on top
## (off-screen). Rebuilt every frame from the camera, so it reaches off the top at any Mera size and camera shake.

const MARGIN := 160.0
var game: Node
var s := 1.0
var t := 0.0
var top_y := 0.0               # world y the strike reached (top of the topmost segment), for tests
var segs := 0


func setup(g: Node, p: Vector2, size: float) -> void:
	game = g
	position = p
	s = size
	scale = Vector2(s, s)
	_build()


func screen_top() -> float:
	if game != null and game.get("cam") != null:
		return game.cam.position.y - 540.0
	return 0.0


func _build() -> void:
	var info: Dictionary = AnimLib.spells["lightning_seg"]
	var tex := AnimLib.spell_tex("lightning_seg")
	var w := float(info["w"])
	var h := float(info["h"])
	var gy := float(info["ground"])
	var nf := int(info["rows"]["mid"][2])
	var f := mini(int(t * 1000.0 / float(info["ms"])), nf - 1)
	var rows: Dictionary = info["rows"]
	begin()
	# bottom cap: its ground row sits on our origin
	var y := -gy
	put(tex, Rect2(f * w, int(rows["bottom"][0]) * h, w, h), Vector2(-w / 2.0, y), AnimLib.fx_mat)
	var need := (position.y - (screen_top() - MARGIN)) / s      # native px from the ground to above the screen top
	var i := 0
	while -y < need:
		y -= h
		var v := (i * 7 + 1) % int(rows["mid"][1])
		if not put(tex, Rect2(f * w, (int(rows["mid"][0]) + v) * h, w, h), Vector2(-w / 2.0, y), AnimLib.fx_mat):
			break
		i += 1
	put(tex, Rect2(f * w, int(rows["top"][0]) * h, w, h), Vector2(-w / 2.0, y - h), AnimLib.fx_mat)
	end()
	segs = i
	top_y = position.y + y * s


func _process(delta: float) -> void:
	t += delta
	var info: Dictionary = AnimLib.spells["lightning_seg"]
	if t * 1000.0 >= float(info["ms"]) * int(info["rows"]["mid"][2]):
		queue_free()
		return
	_build()
