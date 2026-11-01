class_name LayeredAnim
extends Node2D
## Plays one baked animation from AnimLib: body (normal), effects (Fury-recolourable) and additive light layers,
## each frame with its own duration. The node's own scale does facing and size: (size * -facing, size), because
## the art faces LEFT. Positions are native art pixels relative to the feet pivot.

signal frame_changed(idx: int)
signal finished(key: String)

var key := ""
var frames: Array = []
var idx := 0
var t_ms := 0.0
var speed := 1.0
var paused := false
var frame_for_frame := false   # one authored frame per physics step; the step that started it already shows the first
var hold_step := false
var loop := false
var loop_from := -1
var loop_to := -1
var serial := 0
var body := Sprite2D.new()
var fx := Sprite2D.new()
var light := Sprite2D.new()


func _init() -> void:
	for s in [light, body, fx]:
		s.centered = false
		s.region_enabled = true
		add_child(s)


func _ready() -> void:
	fx.material = AnimLib.fx_mat
	light.material = AnimLib.light_mat


func play(k: String, start: int = 0) -> void:
	key = k
	frames = AnimLib.frames(k)
	loop = bool(AnimLib.anims[k]["loop"])
	loop_from = -1
	loop_to = -1
	idx = clampi(start, 0, frames.size() - 1)
	t_ms = 0.0
	paused = false
	speed = 1.0
	frame_for_frame = false
	hold_step = false
	serial += 1
	var tex := AnimLib.sheet(k)
	for s in [light, body, fx]:
		s.texture = tex
	_apply()
	frame_changed.emit(idx)


func section(a: int, b: int) -> void:
	loop_from = a
	loop_to = b


func seek(i: int) -> void:
	idx = clampi(i, 0, frames.size() - 1)
	t_ms = 0.0
	if frame_for_frame:
		hold_step = true
	_apply()
	frame_changed.emit(idx)


func cur() -> Dictionary:
	return frames[idx]


func frame_ms(i: int) -> float:
	return float(frames[i]["ms"])


func total_ms() -> float:
	var t := 0.0
	for f in frames:
		t += float(f["ms"])
	return t


func step(delta_ms: float) -> void:
	if paused or frames.is_empty():
		return
	if frame_for_frame:
		if hold_step:
			hold_step = false
			return
		_advance_one()
		return
	t_ms += delta_ms * speed
	var my := serial
	while t_ms >= frame_ms(idx):
		t_ms -= frame_ms(idx)
		if not _advance_one():
			return
		if serial != my:
			return


## false when the clip ended and stayed on its last frame
func _advance_one() -> bool:
	if loop_to >= 0 and idx >= loop_to:
		idx = loop_from
	elif idx + 1 < frames.size():
		idx += 1
	elif loop:
		idx = 0
	else:
		t_ms = 0.0
		paused = true
		finished.emit(key)
		return false
	_apply()
	frame_changed.emit(idx)
	return true


func _apply() -> void:
	var f: Dictionary = frames[idx]
	_put(body, f["c"])
	_put(fx, f["f"])
	_put(light, f["l"])


func _put(s: Sprite2D, e) -> void:
	if e == null:
		s.visible = false
		return
	s.visible = true
	s.region_rect = Rect2(e[0], e[1], e[2], e[3])
	s.position = Vector2(e[4], e[5])


## box [l, t, r, b] in art px -> Rect2 in this node's parent space (mirrored by facing, scaled by size)
static func box_to_rect(b, facing: int, size: float) -> Rect2:
	if b == null:
		return Rect2()
	var x0 := float(b[0]) * size
	var x1 := float(b[2]) * size
	if facing > 0:
		var t := -x1
		x1 = -x0
		x0 = t
	return Rect2(x0, float(b[1]) * size, x1 - x0, (float(b[3]) - float(b[1])) * size)
