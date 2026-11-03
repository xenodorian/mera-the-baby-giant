class_name Prisoner
extends Node2D
## A caged prisoner the player frees (docs/KING_ARC.md, Prisoners). Standing in the cage and pressing A (Z on keyboard) frees them.
## Freeing pays through game.prisoner_freed(self) (gold and a break_drop, read from this node's fields), then the figure walks
## off to the left and frees itself. Each level's prisoner is spawned once ever: Carry remembers it.
##
## position = the feet centre on the ground (the caller passes game GROUND_Y as y).

const FIGURE_PATH := "res://assets/characters/changeling/knight/idle/idle_1.png"
const FIGURE_H := 150.0
const CAGE := Rect2(-120.0, -230.0, 240.0, 230.0)     # local to the feet: x from -120 to 120, top at -230
const WALK_SPEED := 400.0
const WALK_S := 1.2
const GROUND_FALLBACK := 1060.0
const IRON := Color(0.16, 0.16, 0.2)
const IRON_HI := Color(0.36, 0.36, 0.42)

## level index (Levels) -> the prisoner there. Copy of the king arc table; the lines are shown by the orchestrator.
const TABLE := {
	1: {"x": 4200.0, "line": "The king emptied the jails into these woods. Take this, and keep growing.", "gold": 20},
	4: {"x": 6100.0, "line": "His soldiers wear his spell like a collar. Break the caster, not only the blade.", "gold": 25},
	8: {"x": 3100.0, "line": "Perry is his blood and his weapon. She does not fight like the others.", "gold": 25},
	11: {"x": 480.0, "line": "Parry Perry is nearly unbeatable unless you stun her first. Earthquake. Down and Y.", "gold": 20, "give_move": "earthquake"},
	15: {"x": 7800.0, "line": "Past the changeling is his own court. He will not come out until the warlord falls.", "gold": 30},
	18: {"x": 2400.0, "line": "Free us and we will tell the others. The king waits alone.", "gold": 30},
}

var level_index := -1
var line := ""
var gold := 0
var give_move := ""                  # a move id to grant on free ("" = none)
var freed := false
var walking := false
var prompt: Label = null
var _walk_t := 0.0
var _tex: Texture2D = null
var _fig := Vector2.ZERO             # figure size on screen
var _game: Node = null


## Creates the prisoner for `level_index` under game.world, or null when there is none or it was already freed.
static func spawn_for_level(game: Node, index: int) -> Node:
	if game == null or not is_instance_valid(game):
		return null
	if not TABLE.has(index):
		return null
	if Carry.prisoner_freed(index):
		return null
	var world = game.get("world")
	if world == null or not is_instance_valid(world):
		return null
	var data: Dictionary = TABLE[index]
	var gy = game.get("GROUND_Y")
	var ground := float(gy) if gy != null else GROUND_FALLBACK
	var p := Prisoner.new()
	p.level_index = index
	p.line = String(data.get("line", ""))
	p.gold = int(data.get("gold", 0))
	p.give_move = String(data.get("give_move", ""))
	p._game = game
	p.position = Vector2(float(data.get("x", 4200.0)), ground)
	world.add_child(p)
	return p


func _ready() -> void:
	z_index = 2
	if ResourceLoader.exists(FIGURE_PATH):
		_tex = load(FIGURE_PATH) as Texture2D
	if _tex != null and _tex.get_height() > 0:
		var w := float(_tex.get_width()) * FIGURE_H / float(_tex.get_height())
		_fig = Vector2(w, FIGURE_H)
	else:
		_fig = Vector2(90.0, FIGURE_H)
	_make_prompt()


func _make_prompt() -> void:
	prompt = Label.new()
	prompt.add_theme_font_size_override("font_size", 52)
	prompt.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prompt.add_theme_constant_override("outline_size", 12)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(320, 64)
	prompt.position = Vector2(-160.0, CAGE.position.y - 80.0)
	prompt.z_index = 30
	prompt.visible = false
	add_child(prompt)


func _process(delta: float) -> void:
	if walking:
		position.x -= WALK_SPEED * delta
		_walk_t -= delta
		if _walk_t <= 0.0:
			queue_free()
		queue_redraw()
		return
	if freed:
		return
	var m = _mera()
	var touching := false
	if m != null and m.state != "dead":
		touching = _cage_world().intersects(m.hurt_rect())
	if prompt != null:
		prompt.text = "%s: FREE" % ("Z" if Controls.scheme == "key" else "A")
		prompt.visible = touching
	if touching and Input.is_action_just_pressed("btn_a"):
		_free()


func _mera():
	if _game == null or not is_instance_valid(_game):
		return null
	var m = _game.get("mera")
	return m if m != null and is_instance_valid(m) else null


func _cage_world() -> Rect2:
	return Rect2(global_position + CAGE.position, CAGE.size)


func _free() -> void:
	if freed:
		return
	freed = true
	Sfx.play("potion", 1.0)
	if level_index >= 0:
		Carry.free_prisoner(level_index)
	if _game != null and is_instance_valid(_game) and _game.has_method("prisoner_freed"):
		_game.prisoner_freed(self)
	if prompt != null:
		prompt.visible = false
	walking = true
	_walk_t = WALK_S
	queue_redraw()


func _draw() -> void:
	var fig := Rect2(-_fig.x * 0.5, -_fig.y, _fig.x, _fig.y)
	if _tex != null:
		draw_texture_rect(_tex, fig, false)
	else:
		# no texture: a plain body in the Changeling knight's colours
		draw_rect(Rect2(-22.0, -_fig.y, 44.0, _fig.y * 0.7), Color(0.55, 0.35, 0.3))
		draw_circle(Vector2(0.0, -_fig.y * 0.85), 18.0, Color(0.85, 0.7, 0.6))
	if walking:
		return
	# cage: floor plate, bars, top bar
	draw_rect(Rect2(CAGE.position.x - 8.0, -10.0, CAGE.size.x + 16.0, 12.0), IRON)
	var x := CAGE.position.x
	while x <= CAGE.end.x + 0.5:
		draw_rect(Rect2(x - 3.0, CAGE.position.y, 6.0, CAGE.size.y - 10.0), IRON)
		x += 24.0
	draw_rect(Rect2(CAGE.position.x - 8.0, CAGE.position.y - 8.0, CAGE.size.x + 16.0, 14.0), IRON)
	draw_rect(Rect2(CAGE.position.x - 8.0, CAGE.position.y - 8.0, CAGE.size.x + 16.0, 3.0), IRON_HI)
