class_name Roster
extends RefCounted
## v0.6 enemy roster (docs/GAME_RULES.md "Enemy roster"). Art + per-frame boxes: assets/enemies/roster.json
## (tools/build_roster.py). Behaviour: scripts/game/monster.gd. Enemies never scale with Mera (fixed k).
##
## AttackData (one Dictionary per attack; the telegraph standard in scripts/game/telegraph.gd):
##   anim    animation played for the attack
##   kind    telegraph colour: melee | heavy | ranged | rush
##   dmg     sizes Mera loses
##   tell    wind-up seconds (frozen on the anim's first frame, pulsing, "!" overhead); >= Telegraph.MIN_TELL
##   near/far  start the attack when the edge-to-edge gap to Mera is within [near, far] px
##   cd      seconds before the next attack
##   mode    frames  = hit box cut from the frames that reach out past the body (or the listed "active" frames)
##           contact = the body itself hurts while it lunges / charges / swoops ("vx" px/s, "dur" s, "jump" px/s up)
##           shot    = spawns a projectile ("shot" anim) on frame "shot_frame"

const JSON_PATH := "res://assets/enemies/roster.json"
static var _data: Dictionary = {}

const DEFS := {
	"minotaur": {"k": 4.0, "hp": 26, "speed": 110.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 10.0,
		"attacks": [{"anim": "atk", "kind": "heavy", "dmg": 2, "tell": 0.55, "near": -999.0, "far": 150.0, "cd": 1.6, "mode": "frames"}]},
	"ogre": {"k": 5.0, "hp": 18, "speed": 120.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 8.0,
		"disarm": {"idle": "idle_unarmed", "move": "walk_unarmed", "speed": 170.0},
		"attacks": [{"anim": "atk", "kind": "heavy", "dmg": 2, "tell": 0.5, "near": -999.0, "far": 110.0, "cd": 1.5, "mode": "frames"}],
		"attacks_disarmed": [{"anim": "walk_unarmed", "kind": "rush", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 220.0, "cd": 1.3, "mode": "contact", "vx": 700.0, "dur": 0.45}]},
	"werewolf": {"k": 5.0, "hp": 10, "speed": 300.0, "ai": "charger", "idle": "idle", "move": "run", "rage": 6.0,
		"attacks": [{"anim": "jump", "fall": "fall", "kind": "rush", "dmg": 1, "tell": 0.4, "near": 60.0, "far": 520.0, "cd": 1.4, "mode": "contact", "vx": 700.0, "jump": 1250.0}]},
	"wolf": {"k": 5.0, "hp": 4, "speed": 380.0, "ai": "charger", "idle": "run", "move": "run", "rage": 3.0, "skins": ["run", "run_skin"],
		"attacks": [{"anim": "run", "kind": "rush", "dmg": 1, "tell": 0.35, "near": -999.0, "far": 650.0, "cd": 1.2, "mode": "contact", "vx": 950.0, "dur": 0.8}]},
	"hell_hound": {"k": 5.0, "hp": 7, "speed": 150.0, "run_speed": 430.0, "ai": "charger", "idle": "idle", "move": "walk", "run": "run", "rage": 4.0,
		"attacks": [{"anim": "jump", "kind": "rush", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 380.0, "cd": 1.3, "mode": "contact", "vx": 650.0, "jump": 1050.0}]},
	"hell_beast": {"k": 5.0, "hp": 14, "speed": 40.0, "ai": "turret", "idle": "idle", "move": "idle", "rage": 8.0,
		"attacks": [{"anim": "burn", "kind": "heavy", "dmg": 2, "tell": 0.6, "near": -999.0, "far": 200.0, "cd": 2.4, "mode": "frames"},
			{"anim": "breath", "kind": "ranged", "dmg": 1, "tell": 0.5, "near": 120.0, "far": 1100.0, "cd": 2.8, "mode": "shot", "shot": "fireball", "shot_frame": 2, "shot_speed": 700.0}]},
	"demon": {"k": 3.0, "hp": 22, "speed": 100.0, "ai": "walker", "hover": 70.0, "idle": "idle", "move": "idle", "rage": 12.0,
		"attacks": [{"anim": "atk", "kind": "heavy", "dmg": 2, "tell": 0.5, "near": -999.0, "far": 130.0, "cd": 1.6, "mode": "frames", "active": [3, 5]},
			{"anim": "breath", "kind": "ranged", "dmg": 2, "tell": 0.6, "near": 130.0, "far": 400.0, "cd": 2.0, "mode": "frames"}]},
	"flying_eye": {"k": 4.0, "hp": 3, "speed": 230.0, "ai": "flyer", "hover": 330.0, "idle": "fly", "move": "fly", "rage": 3.0,
		"attacks": [{"anim": "fly", "kind": "rush", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 520.0, "cd": 1.6, "mode": "contact", "vx": 760.0, "dur": 0.9}]},
	"death": {"k": 6.0, "hp": 9, "speed": 120.0, "ai": "walker", "idle": "walk", "move": "walk", "spawn": "rise", "rage": 6.0,
		"lamp": {"idle": "walk_nolamp", "move": "walk_nolamp", "speed": 210.0},
		"attacks": [{"anim": "walk", "kind": "rush", "dmg": 1, "tell": 0.45, "near": -999.0, "far": 260.0, "cd": 1.4, "mode": "contact", "vx": 650.0, "dur": 0.5}]},
	"nightmare": {"k": 3.0, "hp": 14, "speed": 0.0, "ai": "charger", "idle": "idle", "move": "run", "rage": 8.0,
		"attacks": [{"anim": "run", "kind": "rush", "dmg": 2, "tell": 0.55, "near": -999.0, "far": 950.0, "cd": 1.6, "mode": "contact", "vx": 1150.0, "dur": 1.0}]},
	"ghost": {"k": 5.0, "hp": 5, "speed": 150.0, "ai": "flyer", "hover": 220.0, "idle": "float", "move": "float", "rage": 4.0, "fade": 0.6,
		"attacks": [{"anim": "haunt", "kind": "rush", "dmg": 1, "tell": 0.45, "near": -999.0, "far": 450.0, "cd": 1.8, "mode": "contact", "vx": 620.0, "dur": 0.9}]},
	"fire_skull": {"k": 2.0, "hp": 6, "speed": 200.0, "ai": "flyer", "hover": 180.0, "idle": "fire", "move": "fire", "rage": 4.0,
		"douse": {"idle": "nofire", "move": "nofire", "speed": 70.0, "t": 3.0},
		"attacks": [{"anim": "fire", "kind": "rush", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 480.0, "cd": 1.4, "mode": "contact", "vx": 800.0, "dur": 0.8}]},
	"mutant_toad": {"k": 5.0, "hp": 8, "speed": 0.0, "ai": "hopper", "idle": "idle", "move": "idle", "hop": "jump", "rage": 5.0,
		"attacks": [{"anim": "atk", "kind": "melee", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 160.0, "cd": 1.2, "mode": "frames"}]},
	"dragon": {"k": 19.0, "hp": 152, "speed": 70.0, "ai": "walker", "idle": "idle", "move": "idle", "rage": 40.0, "boss": true,
		"attacks": [{"anim": "tail", "kind": "heavy", "dmg": 3, "tell": 0.65, "near": -999.0, "far": 160.0, "cd": 1.6, "mode": "frames"},
			{"anim": "breath", "kind": "ranged", "dmg": 2, "tell": 0.7, "near": 160.0, "far": 650.0, "cd": 1.8, "mode": "frames"}]},
	"hell_gato": {"k": 4.0, "hp": 6, "speed": 300.0, "ai": "charger", "idle": "run", "move": "run", "rage": 4.0,
		"attacks": [{"anim": "run", "kind": "rush", "dmg": 1, "tell": 0.35, "near": -999.0, "far": 480.0, "cd": 1.2, "mode": "contact", "vx": 760.0, "jump": 760.0}]},
	"skeleton": {"k": 5.0, "hp": 6, "speed": 110.0, "ai": "walker", "idle": "walk", "move": "walk", "spawn": "rise", "rage": 3.0,
		"clothed": {"idle": "walk_clothed", "move": "walk_clothed", "spawn": "rise_clothed"},
		"attacks": [{"anim": "walk", "kind": "melee", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 140.0, "cd": 1.2, "mode": "contact", "vx": 380.0, "dur": 0.45}]},
}

## who appears where (level index 1-3 = Misty Woods, Moonlit Town, Infernal Caverns). Level 0 keeps the knights.
const LEVELS := {
	1: ["wolf", "mutant_toad", "werewolf", "flying_eye", "ogre", "minotaur"],
	2: ["skeleton", "hell_gato", "ghost", "death", "nightmare"],
	3: ["hell_hound", "fire_skull", "hell_beast", "demon"],
}
const BOSSES := {3: "dragon"}
const WAVE_FIRST := 2200.0     # first wave trigger x
const WAVE_EVERY := 1500.0     # then one wave every this many px
const WAVE_SIZES := [1, 2, 2, 3]
## v0.9.1 (owner t99u): on levels 2-4 (index 1-3) two monsters per level come from BEHIND Mera (off-screen behind
## her, walking in) instead of ahead: the first walker of these waves (0-based; risers and turrets are skipped: risers
## climb out on screen, turrets barely move).
const BEHIND_WAVES := {1: [1, 3], 2: [1, 3], 3: [1, 3]}
const MAX_ALIVE := 5
const BOSS_AT := 3400.0        # the boss appears when Mera gets this close to the map end ...
const BOSS_X := 1300.0         # ... standing this far from the end, in front of the exit (locked until he falls)


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(JSON_PATH, FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data


static func ids() -> Array:
	return DEFS.keys()


static func def(id: String) -> Dictionary:
	return DEFS[id]


static func art(id: String) -> Dictionary:
	return data()[id]
