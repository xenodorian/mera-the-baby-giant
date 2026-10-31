class_name SegStrip
extends Node2D
## A run of tessellating spell segments (beam, lightning) drawn from a sheet with pooled Sprite2Ds.
## Call begin(), put() once per segment, then end(). Sprites come from one shared free list with a hard cap, so a
## long beam costs a few dozen sprites (one batched draw per sheet) and nothing is allocated per frame after warm-up.

const POOL_CAP := 384          # sprites alive across every strip in the game
const STRIP_CAP := 96          # segments one strip may use (a 1x beam across 1920 px + margin needs ~36)
static var _free: Array = []
static var _alive := 0

var used: Array = []
var n := 0
var dropped := 0               # put() calls refused by the caps (tests check this stays 0)


static func pool_stats() -> Dictionary:
	return {"alive": _alive, "free": _free.size()}


## free the pooled sprites (game exit)
static func drain() -> void:
	for s in _free:
		s.free()
	_alive -= _free.size()
	_free.clear()


func begin() -> void:
	n = 0


func put(tex: Texture2D, region: Rect2, pos: Vector2, mat: Material, z: int = 0) -> bool:
	if n >= STRIP_CAP:
		dropped += 1
		return false
	var s: Sprite2D
	if n < used.size():
		s = used[n]
	else:
		if not _free.is_empty():
			s = _free.pop_back()
		elif _alive < POOL_CAP:
			s = Sprite2D.new()
			s.centered = false
			s.region_enabled = true
			_alive += 1
		else:
			dropped += 1
			return false
		add_child(s)
		used.append(s)
	s.texture = tex
	s.region_rect = region
	s.position = pos
	s.material = mat
	s.z_index = z
	s.visible = true
	n += 1
	return true


func end() -> void:
	for i in range(n, used.size()):
		used[i].visible = false


func clear() -> void:
	begin()
	end()


## give every sprite back to the shared pool (called automatically when the strip leaves the tree)
func release() -> void:
	for s in used:
		remove_child(s)
		s.visible = false
		_free.append(s)
	used.clear()
	n = 0


func _exit_tree() -> void:
	release()
