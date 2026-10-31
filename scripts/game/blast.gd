class_name Blast
extends Node2D
## Plays a one-shot sprite effect: ansimuz Ground Explosion (rear explosion), ansimuz electro-shock (lightning
## impact, remapped to Mera's spell palette), Mera's own pack hit fx (hit sparks), or Mera's lightning bolt.

var frames: Array = []        # [Texture2D, region Rect2 or null]
var ms := 70.0
var t := 0.0
var spr := Sprite2D.new()


func setup(kind: String, p: Vector2, s: float) -> void:
	position = p
	spr.centered = false
	spr.scale = Vector2(s, s)
	spr.material = AnimLib.fx_mat
	add_child(spr)
	match kind:
		"explosion":
			for i in range(1, 10):
				frames.append([load("res://assets/vfx/ansimuz/ground-explosion/sprites/explosion-animation%d.png" % i), null])
			spr.offset = Vector2(-56, -101)
			ms = 70.0
		"electro":
			var tx: Texture2D = load("res://assets/vfx/ansimuz/grotto-escape-2-fx/spritesheets/electro-shock.png")
			for i in range(2, 9):                         # the sheet is 9 frames of 128x96 (0 = dark dot, 1 = flash)
				frames.append([tx, Rect2(i * 128, 0, 128, 96)])
			spr.offset = Vector2(-64, -92)
			spr.material = AnimLib.remap_mat
			ms = 60.0
		"spark":
			var tx2: Texture2D = load("res://assets/characters/merakintsugi/platformer-character-pack/hit fx/hit fx_01.png")
			for i in 5:
				frames.append([tx2, Rect2(i * 125, 0, 125, 87)])
			spr.offset = Vector2(-62, -44)
			spr.scale = Vector2(s, s) * 0.6
			ms = 45.0
		"lightning":
			var tl := AnimLib.spell_tex("lightning")
			var c: Array = AnimLib.spell_cell("lightning")
			for i in int(c[2]):
				frames.append([tl, Rect2(i * float(c[0]), 0, float(c[0]), float(c[1]))])
			spr.offset = Vector2(-float(c[0]) / 2.0, -float(c[1]) + 4.0)
			ms = 50.0
	_show(0)


func _show(i: int) -> void:
	var f: Array = frames[i]
	spr.texture = f[0]
	spr.region_enabled = f[1] != null
	if f[1] != null:
		spr.region_rect = f[1]


func _process(delta: float) -> void:
	t += delta * 1000.0
	var i := int(t / ms)
	if i >= frames.size():
		queue_free()
		return
	_show(i)
