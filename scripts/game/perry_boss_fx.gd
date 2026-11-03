extends RefCounted
## Effects of the Perry boss (scripts/game/perry_boss.gd): her four beams, the meteors, the floor shockwave and the
## projectiles she reflects. Each one hurts Mera through boss.hit_mera(), so the barrier, dodge and parry all apply.
## Beams are NOT projectiles: Mera's beams and vbeams pass through her parry, and hers are not reflected by anything.

const ROSTER := preload("res://scripts/game/roster.gd")


## a horizontal beam from the boss, tiled from the beam art. Grows quickly, holds, fades. Hurts Mera once.
class Beam extends Node2D:
	var game: Node
	var boss: Node
	var kind := "cloud"
	var dir := 1
	var t := 0.0
	var life := 0.6
	var reach := 0.0
	var dmg := 1
	var hit := false
	var hit_ids := {}
	var tile_w := 98.0
	var tile_h := 44.0
	var spr: Sprite2D

	func setup(g: Node, b: Node, k: String, x: float, d: int, life_s: float) -> void:
		game = g
		boss = b
		kind = k
		dir = d
		life = life_s
		dmg = int(Tuning.PERRY_BOSS_BEAM_DMG[k])
		var an: Dictionary = ROSTER.art("perry")["anims"]["beamtile_" + k]
		tile_w = float(an["size"][0])
		tile_h = float(an["size"][1])
		spr = Sprite2D.new()
		spr.centered = false
		spr.texture = load(String(an["frames"][0]))
		spr.region_enabled = true
		spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		spr.offset = Vector2(0, -tile_h / 2.0)
		spr.scale = Vector2(dir * Tuning.PERRY_BOSS_BEAM_SCALE, Tuning.PERRY_BOSS_BEAM_SCALE)
		add_child(spr)
		position = Vector2(x, float(g.GROUND_Y) - float(Tuning.PERRY_BOSS_BEAM_Y[k]))
		z_index = 5
		boss.played["beamtile_" + k] = true
		_shape()

	func rect() -> Rect2:
		var half := Tuning.PERRY_BOSS_BEAM_H / 2.0
		var x0 := position.x if dir > 0 else position.x - reach
		return Rect2(x0, position.y - half, reach, half * 2.0)

	func _shape() -> void:
		reach = minf(Tuning.PERRY_BOSS_BEAM_LEN, t * 7000.0)
		var scroll := fmod(t * 600.0, tile_w)
		spr.region_rect = Rect2(tile_w - scroll, 0.0, maxf(reach / Tuning.PERRY_BOSS_BEAM_SCALE, 1.0), tile_h)
		spr.modulate.a = clampf((life - t) / 0.15, 0.0, 1.0)

	func _physics_process(delta: float) -> void:
		t += delta
		if t >= life or not is_instance_valid(boss) or not boss.alive():
			queue_free()
			return
		_shape()
		var m: Node2D = game.mera
		if not hit and m.state != "dead" and rect().intersects(m.hurt_rect()):
			hit = true
			boss.hit_mera(dmg, position.x)
		boss.hit_allies_in(rect(), dmg, position.x, hit_ids)


## a meteor: a ring on the floor warns where it lands, then it falls and bursts
class Meteor extends Node2D:
	var game: Node
	var boss: Node
	var t := 0.0
	var warn := 0.75
	var fall := 0.3
	var done := false

	func setup(g: Node, b: Node, x: float, warn_s: float) -> void:
		game = g
		boss = b
		warn = warn_s
		position = Vector2(x, float(g.GROUND_Y))
		z_index = 4

	func _physics_process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t < warn + fall:
			return
		if not is_instance_valid(boss):
			queue_free()
			return
		game.explode(position + Vector2(0, -20), 1.4, false)
		var r := Tuning.PERRY_BOSS_METEOR_R
		var m: Node2D = game.mera
		if m.state != "dead" and Rect2(position.x - r, position.y - r * 1.6, r * 2.0, r * 1.6).intersects(m.hurt_rect()):
			boss.hit_mera(Tuning.PERRY_BOSS_METEOR_DMG, position.x)
		boss.hit_allies_in(Rect2(position.x - r, position.y - r * 1.6, r * 2.0, r * 1.6), Tuning.PERRY_BOSS_METEOR_DMG, position.x, {})
		queue_free()

	func _draw() -> void:
		var r := Tuning.PERRY_BOSS_METEOR_R
		if t < warn + fall:
			var q := clampf(t / warn, 0.0, 1.0)
			var a := 0.25 + 0.35 * absf(sin(t * 14.0))
			draw_arc(Vector2.ZERO, r * (0.4 + 0.6 * q), 0.0, TAU, 40, Color(1.0, 0.35, 0.1, a), 6.0)
			draw_circle(Vector2.ZERO, r * 0.25 * q, Color(1.0, 0.4, 0.1, 0.25))
		if t >= warn:
			var f := clampf((t - warn) / fall, 0.0, 1.0)
			var y := lerpf(-1100.0, -30.0, f * f)
			draw_circle(Vector2(0, y), 46.0, Color(1.0, 0.55, 0.12))
			draw_circle(Vector2(0, y), 26.0, Color(1.0, 0.95, 0.6))
			draw_line(Vector2(0, y), Vector2(0, y - 260.0), Color(1.0, 0.5, 0.1, 0.6), 30.0)


## the floor shockwave of the earthquake: runs along the ground, so Mera jumps it
class Quake extends Node2D:
	var game: Node
	var boss: Node
	var dir := 1
	var t := 0.0
	var hit := false
	var hit_ids := {}

	func setup(g: Node, b: Node, x: float, d: int) -> void:
		game = g
		boss = b
		dir = d
		position = Vector2(x, float(g.GROUND_Y))
		z_index = 4

	func rect() -> Rect2:
		return Rect2(position.x - 70.0, position.y - Tuning.PERRY_BOSS_QUAKE_H, 140.0, Tuning.PERRY_BOSS_QUAKE_H)

	func _physics_process(delta: float) -> void:
		t += delta
		position.x += dir * Tuning.PERRY_BOSS_QUAKE_SPEED * delta
		queue_redraw()
		if t > 2.4 or position.x < Levels.EDGE - 200.0 or position.x > game.map_w - Levels.EDGE + 200.0 or not is_instance_valid(boss):
			queue_free()
			return
		var m: Node2D = game.mera
		if not hit and m.state != "dead" and rect().intersects(m.hurt_rect()):
			hit = true
			boss.hit_mera(Tuning.PERRY_BOSS_QUAKE_DMG, position.x - dir * 60.0)
		boss.hit_allies_in(rect(), Tuning.PERRY_BOSS_QUAKE_DMG, position.x - dir * 60.0, hit_ids)

	func _draw() -> void:
		var h := Tuning.PERRY_BOSS_QUAKE_H
		var pts := PackedVector2Array([Vector2(-70, 0), Vector2(-40, -h * 0.7), Vector2(-10, -h * 0.3), Vector2(20, -h), Vector2(50, -h * 0.5), Vector2(70, 0)])
		draw_colored_polygon(pts, Color(0.95, 0.8, 0.45, 0.9))
		draw_polyline(pts, Color(0.4, 0.25, 0.1), 4.0)


## a projectile she reflected: flies at Mera's centre at 1.2 x its speed. Hurts Mera (1 size) and is consumed on contact.
class Reflect extends Node2D:
	var game: Node
	var boss: Node
	var vel := Vector2.ZERO
	var size_px := Vector2(40, 24)
	var spr: Node2D
	var t := 0.0
	var dmg := 1

	func setup(g: Node, b: Node, p: Vector2, v: Vector2, visual: Node2D, sz: Vector2) -> void:
		game = g
		boss = b
		position = p
		vel = v
		size_px = Vector2(maxf(sz.x, 24.0), maxf(sz.y, 20.0))
		z_index = 6
		if visual != null:
			spr = visual
			spr.position = Vector2.ZERO
			if spr is Sprite2D or spr is AnimatedSprite2D:
				spr.scale.x = absf(spr.scale.x) * (1.0 if v.x >= 0.0 else -1.0)
			add_child(spr)
			spr.modulate = Color(1.7, 1.5, 0.8)

	func rect() -> Rect2:
		return Rect2(global_position - size_px / 2.0, size_px)

	func _physics_process(delta: float) -> void:
		t += delta
		position += vel * delta
		if spr is Sprite2D and (spr as Sprite2D).hframes > 1:
			(spr as Sprite2D).frame = int(t * 25.0) % (spr as Sprite2D).hframes
		queue_redraw()
		if t > 3.0 or not is_instance_valid(boss):
			queue_free()
			return
		var m: Node2D = game.mera
		if boss.hit_allies_in(rect(), dmg, global_position.x - signf(vel.x) * 50.0, {}):
			queue_free()
			return
		if m.state != "dead" and rect().intersects(m.hurt_rect()):
			if m.has_method("try_parry_shot") and m.try_parry_shot(self):
				game.explode(global_position, 0.8, false)
			else:
				boss.hit_mera(dmg, global_position.x - signf(vel.x) * 50.0)
				boss.reflected_hits += 1
			queue_free()

	func _draw() -> void:
		if spr == null:
			draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.8, 0.3))
