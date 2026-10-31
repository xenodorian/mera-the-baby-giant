extends Node
## Autoload "HitStop" (v0.8 impact pass, docs/GAME_RULES.md "Impact"). A hit freezes the whole game for a few
## frames by dropping Engine.time_scale, then restores it from a timer that ignores time_scale (research pitfall).
##
## Coexisting with slow motion: anything that wants a lasting slow-mo (e.g. a future Fury slow-mo) calls
## set_base(scale) instead of writing Engine.time_scale. A hit-stop always restores to `base`, never to 1.0, and
## a slow-mo change during a hit-stop is applied when the freeze ends. Overlapping hit-stops extend, never stack.
##
## Timing (pitfall, see AI_HANDOFF): physics ticks keep coming at physics_ticks_per_second of REAL time whatever
## Engine.time_scale is, so the freeze counts down one real tick per physics frame (deterministic in --fixed-fps
## tests too, where the engine does not scale deltas at all). A hit landing mid-frame changes time_scale but not
## the delta already handed out for this frame, so the scale is sampled once at the start of each physics frame.

var enabled := true           # tests turn it off for the frame-counted legacy cases
var base := 1.0               # the "normal" time scale (slow-mo sets this)
var freeze_scale := 0.05      # time scale during the freeze (not 0, so physics keeps ticking for input)
var _left := 0.0              # seconds of freeze left (real time)
var count := 0                # hit-stops started (tests)
var last_ms := 0.0            # length of the last one (tests)
var frame_frozen := false     # was this physics frame's delta made under a freeze?


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -1000      # before anyone else's _physics_process


func _physics_process(_delta: float) -> void:
	frame_frozen = _left > 0.0
	if _left > 0.0:
		_left -= 1.0 / float(Engine.physics_ticks_per_second)
		if _left <= 0.0:
			_left = 0.0
			Engine.time_scale = base       # from the next frame on


## freeze for `ms` milliseconds of real time (capped at Tuning.HITSTOP_MAX_MS)
func stop(ms: float) -> void:
	if not enabled or ms <= 0.0:
		return
	ms = minf(ms, Tuning.HITSTOP_MAX_MS)
	count += 1
	last_ms = ms
	_left = maxf(_left, ms / 1000.0)
	Engine.time_scale = base * freeze_scale


func active() -> bool:
	return _left > 0.0


## Mera's input clock step for this physics frame (seconds): game time normally (so a base slow-mo still slows
## her), one real tick (x base) during a freeze, so input windows keep real time through hit-stops.
func input_dt(delta: float) -> float:
	return base / float(Engine.physics_ticks_per_second) if frame_frozen else delta


func set_base(s: float) -> void:
	base = s
	if not active():
		Engine.time_scale = base


## restore at once (scene changes, tests)
func clear() -> void:
	_left = 0.0
	frame_frozen = false
	Engine.time_scale = base
