class_name Cutscene
extends CanvasLayer
## Story cards in the victory-card style (hud.gd): a dim backdrop, a shadowed gold first line and a pale second line,
## centred on the 1920x1080 design. A page is one String, or an Array of one or two Strings.
##
## Cutscene.play(game, pages, on_done, key) builds one, pauses the tree the way a chest puzzle does, and frees itself at the end.
## A / Start / Space / a tap advances. B or Esc skips the rest. Input is ignored for the first 0.3 s of each page.
## With a `key`, a scene already seen (Carry.seen) does not play: play() then calls on_done at once and returns null.
## play() also returns null, without calling on_done, while a puzzle, the pause menu or another cutscene is open.

const W := 1920.0
const H := 1080.0
const TEXT_W := 1500.0
const PAGE_GUARD_S := 0.3              # a button held over from the last page must not skip the next one
const BLOCK_H := 320.0                 # the most vertical space one page's text may take
const BLOCK_H_SLIDE := 170.0           # ... on a slide page: the text sits in the bar under the picture
const BAND_Y := 40.0                   # the picture band (1920 x 804) starts here; black bars above and below
const BAND_BOTTOM := 844.0
const GOLD := Color(1.0, 0.82, 0.35)
const PALE := Color(0.9, 0.92, 1.0)

var game: Node = null
var pages: Array = []                  # each entry: Array of 1 or 2 Strings
var page_i := 0
var done := false
var on_done: Callable = Callable()
var key := ""
var font: Font
var ui: Control
var _closed := false
var _was_paused := false
var _page_age := 0.0
var _fit: Array = []                   # per line: [font size, line height] for the current page
var extras: Array = []                 # per page: {slide: id, music: path}, from Dictionary pages (slideshow)
var has_slides := false
var view: SlideView = null
var _black: ColorRect = null
var _cur_slide := "<none>"
var _music: AudioStreamPlayer = null
var _level_db := 0.0
var _muted_level := false


## Builds the cutscene under `game`, pauses the tree, and returns it. Null when nothing is shown (see the file header).
## tests set this so story cards never pause a game that is not under test (the suite turns it off for its own cutscene cases)
static var suppressed := false


static func play(game: Node, pages_in: Array, on_done_cb: Callable = Callable(), key_name: String = "") -> Cutscene:
	if suppressed or game == null or not is_instance_valid(game):
		return null
	if key_name != "" and Carry.seen(key_name):
		if on_done_cb.is_valid():
			on_done_cb.call()
		return null
	if _busy(game):
		return null
	var norm := _normalise(pages_in)
	if norm.is_empty():
		if key_name != "":
			Carry.mark_seen(key_name)
		if on_done_cb.is_valid():
			on_done_cb.call()
		return null
	var c := Cutscene.new()
	c.game = game
	c.pages = norm
	c.extras = _extras(pages_in)
	c.on_done = on_done_cb
	c.key = key_name
	c._begin()
	return c


static func _busy(game: Node) -> bool:
	var pp = game.get("paused_play")
	if pp != null and bool(pp):
		return true
	var pz = game.get("puzzle")
	if pz != null and is_instance_valid(pz):
		return true
	var cs = game.get("cutscene")
	return cs != null and is_instance_valid(cs)


## a plain String is one line; an Array is one page of one or two lines
static func _normalise(pages_in: Array) -> Array:
	var out: Array = []
	for p in pages_in:
		var lines := _lines_of(p)
		if not lines.is_empty():
			out.append(lines)
	return out


## the text lines of one page (a String, an Array of Strings, or a Dictionary with "text")
static func _lines_of(p: Variant) -> Array:
	var src: Variant = p.get("text", "") if p is Dictionary else p
	var lines: Array = []
	if src is Array:
		for s in src:
			lines.append(String(s))
	else:
		lines.append(String(src))
	return lines.slice(0, 2) if not String("".join(lines)).is_empty() else []


## per page (aligned with _normalise): {"slide": id, "music": path} for Dictionary pages, {} otherwise
static func _extras(pages_in: Array) -> Array:
	var out: Array = []
	for p in pages_in:
		if _lines_of(p).is_empty():
			continue
		var e := {}
		if p is Dictionary:
			e = {"slide": String(p.get("slide", "")), "music": String(p.get("music", ""))}
		out.append(e)
	return out


func _begin() -> void:
	layer = 25                                              # over the HUD (20), under the touch pad (30)
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = ThemeDB.fallback_font
	for e in extras:
		if String(e.get("slide", "")) != "":
			has_slides = true
	if has_slides:
		_black = ColorRect.new()
		_black.color = Color.BLACK
		_black.set_anchors_preset(Control.PRESET_FULL_RECT)
		_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_black)
		view = SlideView.new()
		view.position = Vector2(0.0, BAND_Y)
		view.size = SlideView.BAND
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(view)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ui.draw.connect(_paint)
	add_child(ui)
	game.add_child(self)
	var tree := get_tree()
	_was_paused = tree.paused
	tree.paused = true
	game.set("cutscene", self)
	_pad_hidden(true)
	_layout_page()
	Sfx.play("swipe", 1.0, -8.0)


# ---------------------------------------------------------------- flow
func _process(delta: float) -> void:
	if _closed:
		return
	_page_age += delta
	if ui:
		ui.queue_redraw()


func _input(event: InputEvent) -> void:
	if _closed:
		return
	var act := ""                                           # "next" or "skip"
	if event.is_action_pressed("btn_a") or event.is_action_pressed("start") or event.is_action_pressed("select") or event.is_action_pressed("ui_accept"):
		act = "next"
	elif event.is_action_pressed("btn_b"):
		act = "skip"
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		act = "skip"
	elif event is InputEventScreenTouch and event.pressed:
		act = "next"
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		act = "next"
	if act == "":
		return
	get_viewport().set_input_as_handled()
	if _page_age < PAGE_GUARD_S:
		return
	if act == "skip":
		skip()
	else:
		advance()


## Moves to the next page, or ends the cutscene after the last one.
func advance() -> void:
	if done:
		return
	page_i += 1
	if page_i >= pages.size():
		_finish()
		return
	_page_age = 0.0
	_layout_page()
	Sfx.play("swipe", 1.2, -10.0)


## Ends the cutscene at once (B / Esc, and the test hook).
func skip() -> void:
	if done:
		return
	_finish()


func _finish() -> void:
	if done:
		return
	done = true
	if key != "":
		Carry.mark_seen(key)
	_release()
	var cb := on_done
	if cb.is_valid():
		cb.call()
	queue_free()


## the tree goes back to its state before play(); the cutscene is cleared from the game
func _release() -> void:
	if _closed:
		return
	_closed = true
	_stop_music()
	if game != null and is_instance_valid(game) and game.get("cutscene") == self:
		game.set("cutscene", null)
	_pad_hidden(false)
	if is_inside_tree():
		get_tree().paused = _was_paused


## also runs when the scene changes under an open cutscene: give the tree back
func _exit_tree() -> void:
	if not _closed:
		done = true
		_closed = true
		_stop_music()
		if game != null and is_instance_valid(game) and game.get("cutscene") == self:
			game.set("cutscene", null)
		_pad_hidden(false)
		var tr := get_tree() if is_inside_tree() else null
		if tr != null:
			tr.paused = false


func _pad_hidden(on: bool) -> void:
	var main := Engine.get_main_loop()
	if main is SceneTree:
		var tp: Node = main.root.get_node_or_null("TouchPad")
		if tp != null:
			tp.set("suppressed", on)


# ---------------------------------------------------------------- layout and drawing
## picks the largest sizes for this page's two lines that keep the block within BLOCK_H (64 / 44 / 36 px)
func _layout_page() -> void:
	_fit = []
	if page_i >= pages.size() or font == null:
		return
	var lines: Array = pages[page_i]
	var candidates := [[64, 44], [44, 44], [44, 36], [36, 36]]
	var chosen: Array = candidates[candidates.size() - 1]
	for cand in candidates:
		var total := 0.0
		for li in lines.size():
			var sz: int = cand[li] if li < 2 else cand[1]
			total += font.get_multiline_string_size(String(lines[li]), HORIZONTAL_ALIGNMENT_CENTER, TEXT_W, sz).y
		if total <= (BLOCK_H_SLIDE if has_slides else BLOCK_H):
			chosen = cand
			break
	for li in lines.size():
		var sz: int = chosen[li] if li < 2 else chosen[1]
		var h := font.get_multiline_string_size(String(lines[li]), HORIZONTAL_ALIGNMENT_CENTER, TEXT_W, sz).y
		_fit.append([sz, h])
	_apply_slide()


## the picture and music of the current page
func _apply_slide() -> void:
	if not has_slides or view == null or page_i >= extras.size():
		return
	var ex: Dictionary = extras[page_i]
	var sid := String(ex.get("slide", ""))
	if sid != _cur_slide:
		_cur_slide = sid
		view.show_slide(sid)
	var mus := String(ex.get("music", ""))
	if mus != "" and _music == null:
		_start_music(mus)


## the story's own music replaces the level music until the cutscene ends
func _start_music(path: String) -> void:
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = -6.0
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music)
	_music.play()
	var lp = game.get("music_player") if game != null else null
	if lp != null and is_instance_valid(lp):
		_level_db = lp.volume_db
		lp.volume_db = -80.0
		_muted_level = true


func _stop_music() -> void:
	if _music != null and is_instance_valid(_music):
		_music.stop()
		_music.queue_free()
		_music = null
	if _muted_level and game != null and is_instance_valid(game):
		var lp = game.get("music_player")
		if lp != null and is_instance_valid(lp):
			lp.volume_db = _level_db
	_muted_level = false


func _paint() -> void:
	if page_i >= pages.size() or font == null:
		return
	var sz := ui.size if ui.size.x > 0.0 else Vector2(W, H)
	if not has_slides:
		ui.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.0, 0.0, 0.02, 0.8))
	var lines: Array = pages[page_i]
	var total := 0.0
	for f in _fit:
		total += float(f[1])
	var y := H * 0.5 - total * 0.5 - 20.0
	if has_slides:                                          # the text sits in the bar under the picture
		y = (BAND_BOTTOM + (H - 30.0 - BAND_BOTTOM) * 0.5) - total * 0.5 - 12.0
	for li in lines.size():
		var fsz: int = int(_fit[li][0])
		var lh: float = float(_fit[li][1])
		var col := GOLD if li == 0 else PALE
		var base := Vector2(210.0, y + font.get_ascent(fsz))
		ui.draw_multiline_string(font, base + Vector2(4, 4), String(lines[li]), HORIZONTAL_ALIGNMENT_CENTER, TEXT_W, fsz, -1, Color(0, 0, 0, 0.55))
		ui.draw_multiline_string(font, base, String(lines[li]), HORIZONTAL_ALIGNMENT_CENTER, TEXT_W, fsz, -1, col)
		y += lh + 24.0
	var next_key := "Z" if Controls.scheme == "key" else "A"
	var skip_key := "X" if Controls.scheme == "key" else "B"
	var hint := "%s: next    %s: skip" % [next_key, skip_key]
	var hint_y := 1068.0 if has_slides else 1010.0
	ui.draw_string(font, Vector2(2, hint_y + 2), hint, HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(0, 0, 0, 0.7))
	ui.draw_string(font, Vector2(0, hint_y), hint, HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(0.85, 0.85, 0.9))
