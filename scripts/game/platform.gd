class_name Platform
extends Node2D
## A one-way plank (Stage 3 phase 4). Its top is a surface entry [x0, x1, y] in Game.built_surfaces, which
## Game.surface_under() scans next to the level's tile_surfaces, so it behaves exactly like a map ledge. ttl <= 0 is permanent.

const THICK := 18.0

var game: Node = null
var surf: Array = []
var full_w := 260.0
var ttl := 25.0
var age := 0.0


static func make(g: Node, cx: float, top: float, width: float, life: float) -> Platform:
	var p := Platform.new()
	p.game = g
	p.full_w = width
	p.ttl = life
	p.position = Vector2(cx, top)
	p.z_index = -1
	p.surf = [cx - width * 0.5, cx + width * 0.5, top]
	g.built_surfaces.append(p.surf)
	g.add_child(p)
	return p


func _physics_process(delta: float) -> void:
	if ttl <= 0.0:
		return
	age += delta
	var left := ttl - age
	if left <= 0.0:
		_drop_surface()
		queue_free()
	elif left < Tuning.PLATFORM_FADE_S:
		var k := left / Tuning.PLATFORM_FADE_S
		modulate.a = k
		scale.x = lerpf(0.55, 1.0, k)
		surf[0] = position.x - full_w * 0.5 * scale.x
		surf[1] = position.x + full_w * 0.5 * scale.x


func _drop_surface() -> void:
	if game != null and is_instance_valid(game) and game.get("built_surfaces") != null:
		for i in range(game.built_surfaces.size() - 1, -1, -1):
			if is_same(game.built_surfaces[i], surf):
				game.built_surfaces.remove_at(i)


func _exit_tree() -> void:
	_drop_surface()


func _draw() -> void:
	var w := full_w
	var wood := Color8(176, 128, 74)
	var dark := Color8(98, 62, 32)
	draw_rect(Rect2(-w * 0.5, 0.0, w, THICK), wood)
	draw_rect(Rect2(-w * 0.5, 0.0, w, 3.0), Color8(214, 168, 106))
	draw_rect(Rect2(-w * 0.5, THICK - 4.0, w, 4.0), dark)
	var x := -w * 0.5 + 40.0
	while x < w * 0.5:
		draw_rect(Rect2(x, 3.0, 2.0, THICK - 7.0), dark)
		x += 56.0
