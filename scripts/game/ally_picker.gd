extends CanvasLayer
## v0.7 ally picker: R1 with cards of several types opens it. The game pauses; Left/Right choose, R1 / A summon,
## B cancels. Cards show the ally's colour, portrait, name, what she does and how many cards are held.

const AL := preload("res://scripts/game/allies.gd")
const ROSTER := preload("res://scripts/game/roster.gd")
var game: Node
var choices: Array = []
var sel := 0
var open := false
var ui: Control
var opened_at := 0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.draw.connect(_draw_ui)
	add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func show_choices(list: Array) -> void:
	choices = list
	sel = 0
	open = true
	visible = true
	opened_at = Engine.get_process_frames()
	get_tree().paused = true
	ui.queue_redraw()


func move(d: int) -> void:
	sel = posmod(sel + d, choices.size())
	Sfx.play("dash", 1.6, -10.0)
	ui.queue_redraw()


func confirm() -> void:
	var c: String = choices[sel]
	close()
	game.summon_type(c)


func close() -> void:
	open = false
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not open or event.is_echo() or not event.is_pressed():
		return
	if Engine.get_process_frames() - opened_at < 2:
		return
	if event.is_action("left"):
		move(-1)
	elif event.is_action("right"):
		move(1)
	elif event.is_action("r1") or event.is_action("btn_a"):
		confirm()
	elif event.is_action("btn_b"):
		close()
	get_viewport().set_input_as_handled()


func _draw_ui() -> void:
	if not open:
		return
	var f := ThemeDB.fallback_font
	var sz := ui.size
	var o := Vector2((sz.x - 1920.0) * 0.5, (sz.y - 1080.0) * 0.5)
	ui.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.01, 0.05, 0.72))
	ui.draw_set_transform(o, 0.0, Vector2.ONE)
	ui.draw_string(f, Vector2(0, 250), "SUMMON AN ALLY", HORIZONTAL_ALIGNMENT_CENTER, 1920, 64, Color(1, 0.9, 0.6))
	var n := choices.size()
	var w := 300.0
	var x0 := 960.0 - (n * w + (n - 1) * 40.0) / 2.0
	for i in n:
		var aid: String = choices[i]
		var c: Color = AL.COLORS[aid]
		var r := Rect2(x0 + i * (w + 40.0), 330, w, 420)
		if i == sel:
			ui.draw_rect(r.grow(14), Color(c.r, c.g, c.b, 0.5))
		ui.draw_rect(r, Color(0.07, 0.05, 0.1))
		_border(r, c, 8.0)
		var tx: Texture2D = ROSTER.face(aid)
		if tx != null:
			var inner := Rect2(r.position.x + 24.0, r.position.y + 16.0, w - 48.0, 250.0)
			var ts := tx.get_size()
			var fit := minf(inner.size.x / maxf(ts.x, 1.0), inner.size.y / maxf(ts.y, 1.0))
			var ds := ts * fit
			var dp := Vector2(inner.position.x + (inner.size.x - ds.x) * 0.5, inner.end.y - ds.y)
			ui.draw_texture_rect(tx, Rect2(dp, ds), false)
		ui.draw_string(f, Vector2(r.position.x, r.position.y + 320), AL.NAMES[aid], HORIZONTAL_ALIGNMENT_CENTER, w, 28, c)
		ui.draw_multiline_string(f, Vector2(r.position.x + 14, r.position.y + 352), AL.BLURB[aid], HORIZONTAL_ALIGNMENT_CENTER, w - 28, 18, 3, Color(0.9, 0.9, 0.95))
		ui.draw_string(f, Vector2(r.position.x, r.position.y + 405), "x%d" % int(game.cards.get(aid, 0)), HORIZONTAL_ALIGNMENT_CENTER, w, 30, Color(1, 1, 1))
	ui.draw_string(f, Vector2(0, 830), "Left / Right: choose     R1 / A: summon     B: cancel", HORIZONTAL_ALIGNMENT_CENTER, 1920, 30, Color(0.9, 0.85, 0.8))
	ui.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _border(r: Rect2, c: Color, t: float) -> void:
	ui.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, t), c)
	ui.draw_rect(Rect2(r.position.x, r.end.y - t, r.size.x, t), c)
	ui.draw_rect(Rect2(r.position.x, r.position.y, t, r.size.y), c)
	ui.draw_rect(Rect2(r.end.x - t, r.position.y, t, r.size.y), c)
