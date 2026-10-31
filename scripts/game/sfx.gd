extends Node
## Autoload "Sfx": Kenney CC0 sounds (assets/sfx/kenney). In Fury mode every sound plays lower (pitch x0.72)
## through the "Fury" bus (low-pass + overdrive), so it reads deeper and redder.

const K := "res://assets/sfx/kenney/"
const SOUNDS := {
	"swipe": ["rpg-audio/knifeSlice.ogg", -6.0, 1.15],
	"claw": ["rpg-audio/knifeSlice2.ogg", -5.0, 1.0],
	"cast": ["sci-fi-sounds/laserSmall_000.ogg", -9.0, 1.0],
	"charge": ["sci-fi-sounds/forceField_000.ogg", -16.0, 1.0],
	"beam": ["sci-fi-sounds/laserLarge_000.ogg", -6.0, 0.8],
	"boom": ["sci-fi-sounds/lowFrequency_explosion_001.ogg", -5.0, 1.0],
	"boom_big": ["sci-fi-sounds/lowFrequency_explosion_000.ogg", -4.0, 1.0],
	"thunder": ["sci-fi-sounds/explosionCrunch_000.ogg", -4.0, 0.85],
	"barrier": ["sci-fi-sounds/forceField_001.ogg", -8.0, 1.0],
	"block": ["impact-sounds/impactPlate_light_000.ogg", -6.0, 1.0],
	"heal": ["sci-fi-sounds/forceField_002.ogg", -8.0, 1.5],
	"fail": ["impact-sounds/impactSoft_heavy_000.ogg", -6.0, 0.6],
	"hit": ["impact-sounds/impactPunch_medium_000.ogg", -5.0, 1.0],
	"hit_heavy": ["impact-sounds/impactPunch_heavy_000.ogg", -4.0, 1.0],
	"hurt": ["impact-sounds/impactPunch_heavy_000.ogg", -3.0, 0.8],
	"potion": ["rpg-audio/handleCoins.ogg", -6.0, 1.3],
	"sphere": ["sci-fi-sounds/forceField_003.ogg", -8.0, 1.4],
	"fury": ["sci-fi-sounds/thrusterFire_000.ogg", -4.0, 0.7],
	"dash": ["rpg-audio/knifeSlice.ogg", -12.0, 0.6],
	# v0.8 (S4) impact pass: more Kenney CC0 impact sounds
	"parry": ["impact-sounds/impactBell_heavy_000.ogg", -6.0, 1.4],
	"clang": ["impact-sounds/impactPlate_heavy_000.ogg", -5.0, 1.0],
	"wood": ["impact-sounds/impactWood_heavy_000.ogg", -4.0, 1.0],
	"stone": ["impact-sounds/impactMining_000.ogg", -3.0, 0.9],
	"glass": ["impact-sounds/impactGlass_heavy_000.ogg", -6.0, 1.0],
	"metal": ["impact-sounds/impactMetal_heavy_000.ogg", -6.0, 0.9],
	"gore": ["impact-sounds/impactSoft_medium_000.ogg", -2.0, 0.8],
	"plank": ["impact-sounds/impactPlank_medium_000.ogg", -4.0, 1.0],
}
## v0.8: alternative takes picked at random (round-robin-free variety) for the busiest impact sounds
const VARIANTS := {
	"hit": ["impact-sounds/impactPunch_medium_001.ogg", "impact-sounds/impactPunch_medium_002.ogg"],
	"hit_heavy": ["impact-sounds/impactPunch_heavy_001.ogg", "impact-sounds/impactPunch_heavy_002.ogg"],
	"wood": ["impact-sounds/impactWood_heavy_001.ogg", "impact-sounds/impactWood_heavy_002.ogg"],
	"stone": ["impact-sounds/impactMining_001.ogg"],
	"glass": ["impact-sounds/impactGlass_heavy_001.ogg"],
	"clang": ["impact-sounds/impactPlate_heavy_001.ogg"],
	"gore": ["impact-sounds/impactSoft_medium_001.ogg"],
}
## sounds whose pitch is jittered by +-Tuning.SFX_JITTER on every play
const JITTER := ["hit", "hit_heavy", "block", "swipe", "claw", "boom", "wood", "stone", "glass", "metal", "gore", "plank", "clang", "hurt"]
var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var fury := false
var history: Array = []      # last sounds (name, bus, pitch) for tests


func _ready() -> void:
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "Fury")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 1600.0
	AudioServer.add_bus_effect(idx, lp)
	var dist := AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
	dist.drive = 0.35
	dist.post_gain = -4.0
	AudioServer.add_bus_effect(idx, dist)
	for n in SOUNDS:
		_streams[n] = [load(K + String(SOUNDS[n][0]))]
		for v in VARIANTS.get(n, []):
			_streams[n].append(load(K + String(v)))
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func play(name: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not _streams.has(name):
		return
	var p: AudioStreamPlayer = null
	for q in _pool:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _pool[0]
	var s: Array = SOUNDS[name]
	var takes: Array = _streams[name]
	p.stream = takes[randi() % takes.size()]
	p.volume_db = float(s[1]) + vol_db
	var jit := randf_range(1.0 - Tuning.SFX_JITTER, 1.0 + Tuning.SFX_JITTER) if name in JITTER else 1.0
	p.pitch_scale = float(s[2]) * pitch * jit * (0.72 if fury else 1.0)
	p.bus = "Fury" if fury else "Master"
	p.play()
	history.append([name, p.bus, p.pitch_scale, jit])
	if history.size() > 64:
		history.pop_front()
