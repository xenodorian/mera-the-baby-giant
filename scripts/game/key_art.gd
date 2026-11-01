extends RefCounted
## v0.12.1 chest key, drawn in code (no art file): a gold ring, a shaft and two teeth, with a dark outline.
## Used by the floor pickup (pickup.gd) and the floating key that shows on unlock (prop.gd).

const W := 9
const H := 19
static var _tex: Texture2D = null


static func texture() -> Texture2D:
	if _tex != null:
		return _tex
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var gold := Color(1.0, 0.82, 0.25)
	var hi := Color(1.0, 0.95, 0.6)
	var dark := Color(0.32, 0.18, 0.04)
	var ring := Vector2(4.0, 4.0)
	var fill := {}
	for y in H:
		for x in W:
			var p := Vector2(x, y)
			var d := p.distance_to(ring)
			var on := (d >= 2.2 and d <= 4.4)                     # the bow
			on = on or (x >= 3 and x <= 4 and y >= 8 and y <= 17)  # the shaft
			on = on or (x >= 5 and x <= 6 and y >= 14 and y <= 15)  # upper tooth
			on = on or (x >= 5 and x <= 6 and y >= 17 and y <= 18)  # lower tooth
			if on:
				fill[Vector2i(x, y)] = true
	for k in fill:
		var c := gold
		if k.x <= 4 and k.y <= 4 and Vector2(k).distance_to(ring) <= 3.2 and k.x <= 3:
			c = hi                                                 # highlight on the bow's upper left
		img.set_pixel(k.x, k.y, c)
	for y in H:
		for x in W:
			if fill.has(Vector2i(x, y)):
				continue
			for n in [Vector2i(x + 1, y), Vector2i(x - 1, y), Vector2i(x, y + 1), Vector2i(x, y - 1)]:
				if fill.has(n):
					img.set_pixel(x, y, dark)                     # outline the filled pixels
					break
	_tex = ImageTexture.create_from_image(img)
	return _tex
