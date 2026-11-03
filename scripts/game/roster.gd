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
##           shot    = spawns a projectile ("shot" anim) on frame "shot_frame"; "shot_k" scales it, "shot_tight" sizes its hit box
##                     from the opaque pixels instead of the whole frame

const JSON_PATH := "res://assets/enemies/roster.json"
static var _data: Dictionary = {}

const DEFS := {
	"minotaur": {"k": 4.0, "hp": 26, "speed": 110.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 10.0,
		"attacks": [{"anim": "atk", "kind": "heavy", "dmg": 2, "tell": 0.55, "near": -999.0, "far": 150.0, "cd": 1.6, "mode": "frames"}]},
	"ogre": {"k": 10.0, "hp": 20, "speed": 120.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 8.0,
		"disarm": {"idle": "idle_unarmed", "move": "walk_unarmed", "speed": 170.0},
		"attacks": [{"anim": "atk", "kind": "heavy", "dmg": 2, "tell": 0.5, "near": -999.0, "far": 110.0, "cd": 5.0, "mode": "frames", "chain": 2}],
		"attacks_disarmed": [{"anim": "walk_unarmed", "kind": "rush", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 220.0, "cd": 5.0, "mode": "contact", "vx": 700.0, "dur": 0.45, "chain": 2}]},
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
	# v0.10 itch.io CC0. Every one of these has 2 HP. A normal attack costs 1. Attack2 is the special and costs 2.
	"lm_goblin": {"k": 4.0, "hp": 6, "speed": 150.0, "ai": "walker", "idle": "idle", "move": "move", "rage": 3.0,
		"attacks": [{"anim": "atk", "kind": "melee", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 90.0, "cd": 1.2, "mode": "frames", "active": [2, 6]},
			{"anim": "atk2", "kind": "heavy", "dmg": 1, "tell": 0.55, "near": 60.0, "far": 160.0, "cd": 1.8, "mode": "frames", "active": [2, 6]}]},
	"lm_mushroom": {"k": 4.0, "hp": 7, "speed": 130.0, "ai": "walker", "idle": "idle", "move": "move", "rage": 3.0,
		"attacks": [{"anim": "atk", "kind": "melee", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 90.0, "cd": 1.2, "mode": "frames", "active": [2, 6]},
			{"anim": "atk2", "kind": "heavy", "dmg": 2, "tell": 0.55, "near": 60.0, "far": 160.0, "cd": 1.8, "mode": "frames", "active": [2, 6]}]},
	"lm_skeleton": {"k": 4.0, "hp": 8, "speed": 110.0, "ai": "walker", "idle": "idle", "move": "move", "rage": 4.0,
		"attacks": [{"anim": "atk", "kind": "melee", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 100.0, "cd": 1.2, "mode": "frames", "active": [2, 6]},
			{"anim": "atk2", "kind": "heavy", "dmg": 2, "tell": 0.55, "near": 70.0, "far": 170.0, "cd": 1.8, "mode": "frames", "active": [2, 6]}]},
	"lm_eye": {"k": 4.0, "hp": 5, "speed": 180.0, "ai": "flyer", "hover": 260.0, "pick": "cycle", "idle": "fly", "move": "fly", "rage": 3.0,
		"attacks": [{"anim": "atk", "kind": "melee", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 300.0, "cd": 1.3, "mode": "contact", "vx": 640.0, "dur": 0.7},
			{"anim": "atk2", "kind": "heavy", "dmg": 2, "tell": 0.5, "near": -999.0, "far": 400.0, "cd": 1.8, "mode": "contact", "vx": 720.0, "dur": 0.8}]},
	"sx_zombie": {"k": 8.0, "hp": 6, "speed": 80.0, "ai": "walker", "idle": "idle", "move": "move", "rage": 3.0,
		"attacks": [{"anim": "atk", "kind": "melee", "dmg": 1, "tell": 0.35, "near": -999.0, "far": 70.0, "cd": 1.1, "mode": "contact", "vx": 240.0, "dur": 0.4}]},
	"sx_skeleton": {"k": 8.0, "hp": 4, "speed": 100.0, "ai": "walker", "idle": "idle", "move": "move", "rage": 2.0,
		"attacks": [{"anim": "atk", "kind": "melee", "dmg": 1, "tell": 0.35, "near": -999.0, "far": 70.0, "cd": 1.1, "mode": "contact", "vx": 260.0, "dur": 0.4}]},
	"sx_witch": {"k": 6.0, "hp": 9, "speed": 90.0, "ai": "walker", "idle": "idle", "move": "move", "rage": 4.0,
		"attacks": [{"anim": "atk", "kind": "melee", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 80.0, "cd": 1.2, "mode": "contact", "vx": 184.0, "dur": 0.38},
			{"anim": "atk2", "kind": "heavy", "dmg": 2, "tell": 0.55, "near": 40.0, "far": 160.0, "cd": 1.8, "mode": "contact", "vx": 180.0, "dur": 0.45}]},
	# Stage 2: frame-animated creatures from Perry Riposte (xenodorian/BibooSGBA, the owner's art). Frames: tools/build_perry.py.
	# "active" ranges are the frames Perry Riposte marks with a hit box.
	"p_goblin": {"k": 3.0, "hp": 6, "speed": 170.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 3.0,
		"pick": "cycle",
		"attacks": [{"anim": "slash", "kind": "melee", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 110.0, "cd": 1.2, "mode": "frames", "active": [2, 7]},
			{"anim": "dive", "kind": "rush", "dmg": 1, "tell": 0.45, "near": 60.0, "far": 260.0, "cd": 1.6, "mode": "frames", "active": [3, 6]},
			{"anim": "combo", "kind": "heavy", "dmg": 2, "tell": 0.55, "near": -999.0, "far": 140.0, "cd": 2.2, "mode": "frames", "active": [4, 14]}]},
	"p_orc": {"k": 3.0, "hp": 12, "speed": 120.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 5.0,
		"pick": "cycle", "hurt": "hurt", "death": "death",
		"attacks": [{"anim": "attack", "kind": "heavy", "dmg": 2, "tell": 0.5, "near": -999.0, "far": 150.0, "cd": 1.5, "mode": "frames", "active": [2, 3]}]},
	# The three Craftpix free wizards (tools/build_wizards.py). The Fire Wizard replaces Perry Riposte's fire mage (same sprite, original version).
	# Each walks up and mixes a close swing, a projectile (a bolt that explodes where it lands) and a long attack that hits by its frames' boxes.
	"p_firemage": {"k": 3.5, "hp": 10, "speed": 130.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 5.0,
		"hurt": "hurt", "death": "death", "pick": "cycle",
		"attacks": [{"anim": "slash", "kind": "melee", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 140.0, "cd": 1.0, "mode": "frames", "active": [2, 3]},
			{"anim": "spark", "kind": "melee", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 170.0, "cd": 1.0, "mode": "frames", "active": [2, 3]},
			{"anim": "fireball", "kind": "ranged", "dmg": 1, "tell": 0.5, "near": 160.0, "far": 1100.0, "cd": 2.4, "mode": "shot", "shot": "bolt", "impact": "blast", "shot_frame": 5, "shot_speed": 700.0, "shot_k": 1.0, "shot_tight": true},
			{"anim": "flame", "kind": "heavy", "dmg": 2, "tell": 0.55, "near": -999.0, "far": 280.0, "cd": 2.2, "mode": "frames", "active": [4, 12]}]},
	"x_lightning_mage": {"k": 3.5, "hp": 12, "speed": 140.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 6.0,
		"hurt": "hurt", "death": "death", "pick": "cycle",
		"attacks": [{"anim": "spark", "kind": "melee", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 170.0, "cd": 1.0, "mode": "frames", "active": [2, 3]},
			{"anim": "ball", "kind": "ranged", "dmg": 1, "tell": 0.5, "near": 160.0, "far": 1100.0, "cd": 2.2, "mode": "shot", "shot": "bolt", "impact": "blast", "shot_frame": 2, "shot_speed": 900.0, "shot_k": 1.0, "shot_tight": true},
			{"anim": "strike", "kind": "heavy", "dmg": 2, "tell": 0.55, "near": -999.0, "far": 240.0, "cd": 1.6, "mode": "frames", "active": [4, 9]},
			{"anim": "beam", "kind": "heavy", "dmg": 2, "tell": 0.6, "near": -999.0, "far": 280.0, "cd": 2.4, "mode": "frames", "active": [4, 12]}]},
	"x_wanderer_mage": {"k": 3.5, "hp": 14, "speed": 120.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 6.0,
		"hurt": "hurt", "death": "death", "pick": "cycle",
		"attacks": [{"anim": "sparkle", "kind": "melee", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 170.0, "cd": 1.0, "mode": "frames", "active": [2, 5]},
			{"anim": "star", "kind": "ranged", "dmg": 1, "tell": 0.5, "near": 150.0, "far": 1100.0, "cd": 2.2, "mode": "shot", "shot": "bolt", "impact": "blast", "shot_frame": 6, "shot_speed": 800.0, "shot_k": 1.0, "shot_tight": true},
			{"anim": "arrow", "kind": "ranged", "dmg": 1, "tell": 0.45, "near": -999.0, "far": 1200.0, "cd": 2.0, "mode": "shot", "shot": "bolt", "impact": "blast", "shot_frame": 3, "shot_speed": 1200.0, "shot_k": 0.8, "shot_tight": true},
			{"anim": "frost", "kind": "heavy", "dmg": 2, "tell": 0.6, "near": -999.0, "far": 130.0, "cd": 2.4, "mode": "frames", "active": [5, 12]}]},
	# Stage 3 mini-boss (Fellor's Black Knight, owner supplied; tools/build_black_knight.py). scripts/game/black_knight.gd documents each animation's use.
	"black_knight": {"k": 8.0, "hp": 220, "speed": 250.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 30.0, "boss": true,
		"pick": "cycle", "hurt": "hurt", "death": "death", "spawn": "draw", "script": "res://scripts/game/black_knight.gd",
		"attacks": [{"anim": "attack1", "kind": "melee", "dmg": 1, "tell": 0.35, "near": -999.0, "far": 300.0, "cd": 0.25, "mode": "frames"},
			{"anim": "attack2", "kind": "melee", "dmg": 1, "tell": 0.35, "near": -999.0, "far": 300.0, "cd": 0.25, "mode": "frames"},
			{"anim": "attack3", "kind": "melee", "dmg": 2, "tell": 0.35, "near": -999.0, "far": 300.0, "cd": 0.3, "mode": "frames"},
			{"anim": "attack4", "kind": "heavy", "dmg": 2, "tell": 0.45, "near": -999.0, "far": 460.0, "cd": 0.9, "mode": "frames"},
			{"anim": "roll", "kind": "rush", "dmg": 1, "tell": 0.4, "near": 380.0, "far": 1100.0, "cd": 1.2, "mode": "contact", "vx": 950.0, "dur": 0.6},
			{"anim": "heavy1", "kind": "heavy", "dmg": 3, "tell": 0.6, "near": -999.0, "far": 320.0, "cd": 1.2, "mode": "frames"},
			{"anim": "jump", "kind": "rush", "dmg": 1, "tell": 0.4, "near": 260.0, "far": 760.0, "cd": 1.0, "mode": "contact", "vx": 380.0, "jump": 800.0, "fall": "fall_light"},
			{"anim": "heavy2", "kind": "heavy", "dmg": 3, "tell": 0.6, "near": -999.0, "far": 320.0, "cd": 1.2, "mode": "frames"},
			{"anim": "jump", "kind": "heavy", "dmg": 2, "tell": 0.5, "near": 380.0, "far": 1000.0, "cd": 1.6, "mode": "contact", "vx": 520.0, "jump": 1300.0, "fall": "fall_heavy"},
			{"anim": "heavy3", "kind": "heavy", "dmg": 3, "tell": 0.7, "near": -999.0, "far": 420.0, "cd": 1.4, "mode": "frames"},
			{"anim": "art", "kind": "heavy", "dmg": 3, "tell": 0.8, "near": -999.0, "far": 700.0, "cd": 2.4, "mode": "frames"}]},
	"p_clubogre": {"k": 3.0, "hp": 48, "speed": 90.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 20.0, "boss": true,
		"pick": "cycle", "hurt": "hurt", "death": "death",
		"attacks": [{"anim": "smash", "kind": "heavy", "dmg": 3, "tell": 0.6, "near": -999.0, "far": 230.0, "cd": 1.6, "mode": "frames", "active": [4, 5]},
			{"anim": "walk", "kind": "rush", "dmg": 2, "tell": 0.5, "near": 240.0, "far": 700.0, "cd": 2.4, "mode": "contact", "vx": 650.0, "dur": 0.6}]},
	"p_mirrormax": {"k": 4.0, "hp": 60, "speed": 190.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 24.0, "boss": true,
		"pick": "cycle", "hurt": "hurt", "death": "death",
		"attacks": [{"anim": "slash", "kind": "melee", "dmg": 1, "tell": 0.35, "near": -999.0, "far": 150.0, "cd": 0.9, "mode": "frames", "active": [2, 3]},
			{"anim": "thrust", "kind": "melee", "dmg": 1, "tell": 0.35, "near": -999.0, "far": 190.0, "cd": 0.9, "mode": "frames", "active": [2, 3]},
			{"anim": "upswing", "kind": "melee", "dmg": 2, "tell": 0.4, "near": -999.0, "far": 150.0, "cd": 1.1, "mode": "frames", "active": [2, 3]},
			{"anim": "push_kick", "kind": "melee", "dmg": 1, "tell": 0.35, "near": -999.0, "far": 110.0, "cd": 0.9, "mode": "frames", "active": [1, 2]},
			{"anim": "spin", "kind": "heavy", "dmg": 2, "tell": 0.45, "near": -999.0, "far": 170.0, "cd": 1.3, "mode": "frames", "active": [1, 4]},
			{"anim": "heavy", "kind": "heavy", "dmg": 3, "tell": 0.6, "near": -999.0, "far": 200.0, "cd": 1.8, "mode": "frames", "active": [4, 4]}]},
	"p_percy": {"k": 1.75, "hp": 70, "speed": 150.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 26.0, "boss": true,
		"pick": "cycle", "hurt": "blockIn", "death": "blockIn", "spawn": "up",
		"attacks": [{"anim": "slash", "kind": "melee", "dmg": 2, "tell": 0.4, "near": -999.0, "far": 130.0, "cd": 1.0, "mode": "frames", "active": [1, 2]},
			{"anim": "up", "kind": "ranged", "dmg": 2, "tell": 0.6, "near": 200.0, "far": 1100.0, "cd": 2.4, "mode": "shot", "shot": "energy", "shot_frame": 2, "shot_speed": 900.0, "shot_tight": true, "shot_k": 0.5, "shot_y": 78.0},
			{"anim": "up", "kind": "ranged", "dmg": 1, "tell": 0.6, "near": 0.0, "far": 1400.0, "cd": 2.8, "mode": "shot", "shot": "energy", "shot_frame": 2, "shot_speed": 520.0, "shot_tight": true, "shot_k": 0.3, "shot_y": 78.0, "home": 2.4}]},
	# Stage 2: free frame-animated creatures (Luiz Melo CC0, chierit CC-BY 4.0). Frames: assets/characters/itch/.
	"x_fire_worm": {"k": 4.0, "hp": 8, "speed": 90.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 4.0, "hurt": "hurt", "death": "death",
		"attacks": [{"anim": "attack", "kind": "ranged", "dmg": 1, "tell": 0.45, "near": -999.0, "far": 900.0, "cd": 2.2, "mode": "shot", "shot": "fireball", "shot_frame": 11, "shot_speed": 640.0, "shot_tight": true}]},
	"x_bat": {"k": 4.0, "hp": 4, "speed": 240.0, "ai": "flyer", "hover": 300.0, "idle": "fly", "move": "fly", "rage": 3.0, "hurt": "hurt", "death": "death",
		"attacks": [{"anim": "attack", "kind": "rush", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 500.0, "cd": 1.5, "mode": "contact", "vx": 760.0, "dur": 0.8}]},
	"x_slime": {"k": 6.0, "hp": 6, "speed": 90.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 3.0, "hurt": "hurt", "death": "death",
		"attacks": [{"anim": "attack", "kind": "melee", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 130.0, "cd": 1.4, "mode": "frames", "active": [10, 14]}]},
	"x_mimic": {"k": 5.0, "hp": 10, "speed": 150.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 5.0, "hurt": "hurt", "death": "death",
		"attacks": [{"anim": "attack", "kind": "heavy", "dmg": 2, "tell": 0.5, "near": -999.0, "far": 150.0, "cd": 1.6, "mode": "frames", "active": [11, 13]}]},
	"x_rat": {"k": 5.0, "hp": 4, "speed": 340.0, "ai": "charger", "idle": "idle", "move": "run", "rage": 3.0, "hurt": "hurt", "death": "death",
		"attacks": [{"anim": "attack", "kind": "rush", "dmg": 1, "tell": 0.35, "near": -999.0, "far": 260.0, "cd": 1.1, "mode": "contact", "vx": 460.0, "dur": 0.54}]},
	"x_dark_wizard": {"k": 4.0, "hp": 9, "speed": 80.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 5.0, "hurt": "hurt", "death": "death",
		"attacks": [{"anim": "attack", "kind": "ranged", "dmg": 2, "tell": 0.5, "near": 150.0, "far": 1000.0, "cd": 2.4, "mode": "shot", "shot": "bolt", "shot_frame": 8, "shot_speed": 820.0, "shot_tight": true}]},
	"x_frost_guardian": {"k": 4.0, "hp": 24, "speed": 80.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 10.0, "hurt": "hurt", "death": "death", "death_hold": true,
		"attacks": [{"anim": "attack", "kind": "heavy", "dmg": 2, "tell": 0.55, "near": -999.0, "far": 230.0, "cd": 1.8, "mode": "frames", "active": [6, 8]}]},
	"x_demon_slime": {"k": 4.0, "hp": 60, "speed": 110.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 22.0, "boss": true, "hurt": "hurt", "death": "death", "death_hold": true,
		"attacks": [{"anim": "attack", "kind": "heavy", "dmg": 3, "tell": 0.6, "near": -999.0, "far": 290.0, "cd": 1.5, "mode": "frames", "active": [9, 11]},
			{"anim": "walk", "kind": "rush", "dmg": 2, "tell": 0.5, "near": 300.0, "far": 800.0, "cd": 2.2, "mode": "contact", "vx": 700.0, "dur": 0.6}]},
	# the boss of Perry's Arena (level index 11): Perry herself, at her boss scale. perry_boss.gd plays her whole move table
	# (Tuning.PERRY_BOSS_MOVES); "attacks" lists the basics for the generic checks. hp is replaced by 25 sizes of Tuning.DRAGON_HP_PER_SIZE.
	"perry": {"k": 5.0, "hp": 200, "speed": 460.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 40.0, "boss": true,
		"script": "res://scripts/game/perry_boss.gd",
		"attacks": [{"anim": "slash", "kind": "melee", "dmg": 1, "tell": 0.35, "near": -999.0, "far": 380.0, "cd": 0.5, "mode": "frames", "active": [2, 3]},
			{"anim": "thrust", "kind": "melee", "dmg": 1, "tell": 0.35, "near": 80.0, "far": 440.0, "cd": 0.5, "mode": "frames", "active": [2, 3]},
			{"anim": "heavy", "kind": "heavy", "dmg": 3, "tell": 0.6, "near": -999.0, "far": 330.0, "cd": 1.0, "mode": "frames", "active": [4, 4]},
			{"anim": "energy_wave", "kind": "ranged", "dmg": 2, "tell": 0.55, "near": 350.0, "far": 1500.0, "cd": 1.0, "mode": "shot", "shot": "wave_fx", "shot_frame": 2}]},
	# Stage 3: the Changeling enemies (LPC art, tools/build_roster.py "cl_*"). Stage 3 levels do NOT get the Stage 2 doubling
	# (game.gd spawn_enemy), so these numbers are final: about 2x the Stage 1 style hp / speed and 0.25x the cds, then a
	# little tougher than the Stage 2 equivalents, because Mera arrives strong. "script" = the AI script (script_for).
	# "style" (cl_enemy.gd): ranger = hops back, weaver = walks back, mage = blinks away; "lo"/"hi" = the gap band it keeps.
	"cl_grunt": {"k": 8.0, "hp": 16, "speed": 280.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 4.0,
		"hurt": "hurt", "death": "hurt", "script": "res://scripts/game/cl_enemy.gd",
		"attacks": [{"anim": "slash", "kind": "melee", "dmg": 1, "tell": 0.36, "near": -999.0, "far": 130.0, "cd": 0.45, "mode": "frames", "active": [3, 5]},
			{"anim": "thrust", "kind": "rush", "dmg": 1, "tell": 0.4, "near": 160.0, "far": 440.0, "cd": 0.6, "mode": "contact", "vx": 545.0, "dur": 0.42}]},
	"cl_mud": {"k": 8.0, "hp": 26, "speed": 120.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 5.0,
		"hurt": "hurt", "death": "hurt", "script": "res://scripts/game/cl_enemy.gd",
		"attacks": [{"anim": "slash", "kind": "melee", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 120.0, "cd": 0.6, "mode": "frames", "active": [3, 5]},
			{"anim": "spellcast", "kind": "ranged", "dmg": 1, "tell": 0.5, "near": 260.0, "far": 1100.0, "cd": 1.5, "mode": "shot", "shot": "mud", "shot_frame": 4, "shot_speed": 0.0}]},
	"cl_rat_king": {"k": 6.5, "hp": 15, "speed": 190.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 4.0,
		"hurt": "hurt", "death": "hurt", "script": "res://scripts/game/cl_enemy.gd",
		"attacks": [{"anim": "slash", "kind": "melee", "dmg": 1, "tell": 0.36, "near": -999.0, "far": 110.0, "cd": 0.45, "mode": "frames", "active": [3, 5]},
			{"anim": "jump", "kind": "rush", "dmg": 1, "tell": 0.36, "near": 130.0, "far": 560.0, "cd": 0.55, "mode": "contact", "vx": 560.0, "jump": 1050.0, "anim_speed": 0.6}]},
	"cl_archer": {"k": 8.0, "hp": 16, "speed": 0.0, "ai": "turret", "idle": "idle", "move": "idle", "rage": 4.0,
		"hurt": "hurt", "death": "hurt", "script": "res://scripts/game/cl_enemy.gd",
		"attacks": [{"anim": "shoot", "kind": "ranged", "dmg": 1, "tell": 0.45, "near": -999.0, "far": 1200.0, "cd": 0.8, "mode": "shot", "shot": "arrow", "shot_frame": 9, "shot_speed": 1100.0, "shot_k": 0.7, "shot_tight": true}]},
	"cl_knight": {"k": 9.0, "hp": 44, "speed": 230.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 10.0,
		"hurt": "hurt", "death": "hurt", "script": "res://scripts/game/cl_enemy.gd",
		"attacks": [{"anim": "slash", "kind": "heavy", "dmg": 2, "tell": 0.5, "near": -999.0, "far": 160.0, "cd": 0.6, "mode": "frames", "active": [3, 5]},
			{"anim": "thrust", "kind": "rush", "dmg": 2, "tell": 0.45, "near": 180.0, "far": 480.0, "cd": 0.8, "mode": "contact", "vx": 820.0, "dur": 0.3}]},
	"cl_ranger": {"k": 8.0, "hp": 38, "speed": 260.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 8.0, "style": "ranger", "lo": 460.0, "hi": 720.0,
		"hurt": "hurt", "death": "hurt", "script": "res://scripts/game/cl_enemy.gd",
		"attacks": [{"anim": "shoot", "kind": "ranged", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 950.0, "cd": 0.5, "mode": "shot", "shot": "arrow", "shot_frame": 9, "shot_speed": 1200.0, "shot_k": 0.7, "shot_tight": true}]},
	"cl_weaver": {"k": 8.0, "hp": 42, "speed": 200.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 8.0, "style": "weaver", "lo": 520.0, "hi": 820.0,
		"hurt": "hurt", "death": "hurt", "script": "res://scripts/game/cl_enemy.gd",
		"attacks": [{"anim": "shoot", "kind": "ranged", "dmg": 2, "tell": 0.5, "near": -999.0, "far": 1300.0, "cd": 1.0, "mode": "shot", "shot": "bone", "shot_frame": 9, "shot_speed": 1050.0}]},
	# the Warlord (boss of Warlord's Throne): scripts/game/cl_warlord.gd. "phase" = the first of his 3 phases (hp 2/3 and 1/3) that uses the attack
	"cl_warlord": {"k": 12.0, "hp": 240, "speed": 190.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 40.0, "boss": true,
		"pick": "cycle", "hurt": "hurt", "death": "hurt", "script": "res://scripts/game/cl_warlord.gd",
		"attacks": [{"anim": "slash", "kind": "heavy", "dmg": 2, "tell": 0.5, "near": -999.0, "far": 230.0, "cd": 0.7, "mode": "frames", "active": [3, 5], "phase": 1},
			{"anim": "shoot", "kind": "ranged", "dmg": 1, "tell": 0.5, "near": 320.0, "far": 1300.0, "cd": 1.1, "mode": "shot", "shot": "arrow", "shot_frame": 9, "shot_speed": 1250.0, "shot_k": 0.8, "shot_tight": true, "phase": 1},
			{"anim": "thrust", "kind": "rush", "dmg": 1, "tell": 0.4, "near": 200.0, "far": 440.0, "cd": 1.0, "mode": "contact", "vx": 720.0, "dur": 0.3, "phase": 1},
			{"anim": "jump", "kind": "rush", "dmg": 1, "tell": 0.4, "near": 440.0, "far": 900.0, "cd": 1.2, "mode": "contact", "vx": 620.0, "jump": 1000.0, "phase": 1},
			{"anim": "thrust", "kind": "rush", "dmg": 2, "tell": 0.5, "near": 350.0, "far": 1300.0, "cd": 1.4, "mode": "contact", "vx": 1050.0, "dur": 1.7, "charge": true, "phase": 2},
			{"anim": "jump", "kind": "heavy", "dmg": 2, "tell": 0.5, "near": -999.0, "far": 460.0, "cd": 1.4, "mode": "contact", "vx": 360.0, "jump": 1500.0, "slam": true, "phase": 3}]},
	# Stage 4, the final boss: King Lucius Nerochilde, in three forms on one health pool (scripts/game/nero.gd swaps them at 2/3 and 1/3 hp):
	#   nero         the Medieval King (Luiz Melo's Medieval King Pack 2, bought by the owner): sword swings, a spin, an overhead chop, dark bolts, a lunge
	#   nero_reaper  the skull-cloak reaper (owner's art): scythe slashes with slash arcs, a charge that stuns him on the wall, bolts, the energy beam
	#   nero_giant   the skull giant (owner's art): wide green slashes, the charge, a jump slam with floor shockwaves, the zigzag bolt
	# The two later forms are only ever worn by the nero node (they have no spawn of their own). He does not parry. His damage does not scale.
	"nero": {"k": 9.0, "hp": 300, "speed": 190.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 40.0, "boss": true,
		"pick": "cycle", "hurt": "hurt", "script": "res://scripts/game/nero.gd",
		"attacks": [{"anim": "attack", "kind": "heavy", "dmg": 2, "tell": 0.5, "near": -999.0, "far": 330.0, "cd": 0.7, "mode": "frames", "active": [2, 2], "phase": 1},
			{"anim": "attack", "kind": "ranged", "dmg": 1, "tell": 0.55, "near": 380.0, "far": 1500.0, "cd": 1.3, "mode": "shot", "shot": "bolt", "shot_frame": 2, "shot_speed": 1000.0, "shot_k": 0.35, "shot_tight": true, "chain": 3, "phase": 1},
			{"anim": "attack3", "kind": "heavy", "dmg": 2, "tell": 0.55, "near": -999.0, "far": 330.0, "cd": 1.0, "mode": "frames", "active": [2, 2], "phase": 1},
			{"anim": "attack2", "kind": "melee", "dmg": 1, "tell": 0.4, "near": -999.0, "far": 260.0, "cd": 0.9, "mode": "frames", "active": [2, 2], "phase": 1},
			{"anim": "walk", "kind": "rush", "dmg": 1, "tell": 0.4, "near": 200.0, "far": 520.0, "cd": 1.0, "mode": "contact", "vx": 700.0, "dur": 0.35, "phase": 1}]},
	"nero_reaper": {"k": 6.7, "hp": 300, "speed": 210.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 40.0, "boss": true,
		"pick": "cycle", "hurt": "hurt",
		"attacks": [{"anim": "slash", "kind": "heavy", "dmg": 2, "tell": 0.5, "near": -999.0, "far": 380.0, "cd": 0.8, "mode": "frames", "active": [1, 3], "arc": true, "reach": 150.0, "fx": "slash_pale", "phase": 1},
			{"anim": "slash", "kind": "ranged", "dmg": 1, "tell": 0.55, "near": 400.0, "far": 1500.0, "cd": 1.3, "mode": "shot", "shot": "bolt", "shot_frame": 2, "shot_speed": 1000.0, "shot_k": 0.35, "shot_tight": true, "chain": 3, "fx": "slash_pale", "phase": 1},
			{"anim": "walk", "kind": "rush", "dmg": 2, "tell": 0.5, "near": 350.0, "far": 1300.0, "cd": 1.4, "mode": "contact", "vx": 1050.0, "dur": 1.7, "charge": true, "fx": "slash_pale", "phase": 1},
			{"anim": "slash", "kind": "ranged", "dmg": 2, "tell": 0.8, "near": -999.0, "far": 2600.0, "cd": 2.6, "mode": "frames", "active": [1, 3], "beam": "energy", "phase": 1}]},
	"nero_giant": {"k": 6.0, "hp": 300, "speed": 170.0, "ai": "walker", "idle": "idle", "move": "walk", "rage": 40.0, "boss": true,
		"pick": "cycle", "hurt": "hurt",
		"attacks": [{"anim": "slash", "kind": "heavy", "dmg": 2, "tell": 0.5, "near": -999.0, "far": 460.0, "cd": 0.8, "mode": "frames", "active": [8, 14], "arc": true, "reach": 190.0, "fx": "slash_green", "phase": 1},
			{"anim": "walk", "kind": "rush", "dmg": 2, "tell": 0.5, "near": 350.0, "far": 1300.0, "cd": 1.4, "mode": "contact", "vx": 1050.0, "dur": 1.7, "charge": true, "fx": "slash_green", "phase": 1},
			{"anim": "walk", "kind": "heavy", "dmg": 2, "tell": 0.5, "near": -999.0, "far": 460.0, "cd": 1.4, "mode": "contact", "vx": 360.0, "jump": 1500.0, "slam": true, "fx": "slash_green", "phase": 1},
			{"anim": "slash", "kind": "ranged", "dmg": 2, "tell": 0.8, "near": -999.0, "far": 2600.0, "cd": 2.6, "mode": "frames", "active": [8, 14], "beam": "zigzag", "phase": 1}]},
}

## who appears where. 12 to 18 are Stage 3 (the Changeling levels, cl_* ids). 0 Sunlit Country, 1 Misty Woods, 2 Moonlit Town, 4 Infernal Caverns,
## 6 Mossy Falls, 7 Sunstone Canyon, 8 Sunset Shore, 9 Mire Wood, 10 Moonlit Sanctum (stage 2, the p_* ids).
## Index 3 is Moonlit Cemetery and is not listed: it keeps the Fire Knights.
## Index 5 is the Dragon's Lair: no trash waves, only the boss.
const LEVELS := {
	0: ["wolf", "lm_goblin", "mutant_toad", "flying_eye", "werewolf", "lm_mushroom"],
	1: ["wolf", "mutant_toad", "werewolf", "flying_eye", "ogre", "minotaur"],
	2: ["skeleton", "hell_gato", "ghost", "death", "nightmare"],
	4: ["hell_hound", "fire_skull", "hell_beast", "demon"],
	6: ["p_goblin", "p_orc", "x_slime", "x_bat", "x_rat"],
	7: ["p_orc", "x_fire_worm", "p_goblin", "x_mimic", "x_wanderer_mage", "x_rat"],
	8: ["p_goblin", "x_slime", "p_firemage", "x_bat", "x_mimic", "p_orc"],
	9: ["p_orc", "x_dark_wizard", "x_lightning_mage", "x_fire_worm", "x_frost_guardian", "x_slime", "p_goblin"],
	10: ["p_orc", "p_firemage", "x_dark_wizard", "x_frost_guardian", "x_mimic", "x_bat"],
	12: ["cl_grunt", "cl_rat_king", "cl_grunt", "cl_rat_king"],
	13: ["cl_grunt", "cl_rat_king", "cl_archer", "cl_grunt", "cl_archer"],
	14: ["cl_grunt", "cl_archer", "cl_mud", "cl_rat_king", "cl_mud"],
	15: ["cl_mud", "cl_rat_king", "cl_mud", "cl_grunt", "cl_archer", "cl_rat_king"],
	16: ["cl_grunt", "cl_archer", "cl_mud", "cl_rat_king", "cl_knight", "cl_ranger"],
	17: ["cl_knight", "cl_grunt", "cl_mud", "cl_ranger", "cl_archer", "cl_rat_king", "cl_knight"],
	18: ["cl_knight", "cl_ranger", "cl_weaver", "x_lightning_mage", "cl_grunt"],
}
## the end boss of a level. 5 has no waves (boss only); 6 to 10 are wave levels whose boss waits near the exit.
const BOSSES := {5: "dragon", 6: "p_clubogre", 7: "x_demon_slime", 8: "p_mirrormax", 9: "p_percy", 11: "perry", Levels.BLACK_KNIGHT: "black_knight", Levels.THRONE: "cl_warlord", Levels.COURT: "nero"}
## levels whose boss ends a stage with a victory card (level index -> what falls). Other bosses only open the exit.
const FINALE := {5: "the Cavern Dragon", 11: "Perry", Levels.THRONE: "the Warlord", Levels.COURT: "King Nerochilde"}
## display names of the bosses (exit lock text)
const NAMES := {"dragon": "Dragon", "p_clubogre": "Club Ogre", "p_mirrormax": "Mirror Max", "p_percy": "Percy", "perry": "Perry", "x_demon_slime": "Fire Demon", "cl_warlord": "Warlord", "nero": "Nerochilde", "black_knight": "Black Knight"}
## v0.10 endless run. New itch monsters are listed twice so they show up alongside the older roster.
const RUN_POOL := [
	"wolf", "mutant_toad", "werewolf", "flying_eye", "ogre", "minotaur",
	"skeleton", "hell_gato", "ghost", "death", "nightmare",
	"hell_hound", "fire_skull", "hell_beast", "demon",
	"lm_goblin", "lm_goblin", "lm_mushroom", "lm_mushroom", "lm_skeleton", "lm_skeleton", "lm_eye", "lm_eye",
	"sx_zombie", "sx_zombie", "sx_skeleton", "sx_skeleton", "sx_witch", "sx_witch",
	"p_goblin", "p_goblin", "p_orc", "p_orc", "p_firemage", "p_firemage", "x_lightning_mage", "x_wanderer_mage",
	"x_fire_worm", "x_bat", "x_slime", "x_mimic", "x_rat", "x_dark_wizard", "x_frost_guardian",
	"cl_grunt", "cl_grunt", "cl_rat_king", "cl_rat_king", "cl_archer", "cl_archer", "cl_mud", "cl_mud",
]
const RUN_START := 3           # enemies on the first map
const KNIGHT_CAP := 5          # Moonlit Cemetery: this many Fire Knights, then the exit opens. No more after that.
const WAVE_FIRST := 2200.0     # first wave trigger x
const WAVE_EVERY := 1500.0     # then one wave every this many px
const WAVE_SIZES := [1, 2, 2, 3]
## on every wave level, two monsters per level come from BEHIND Mera. Cemetery (index 3) is the knight fight.
const BEHIND_WAVES := {0: [1, 3], 1: [1, 3], 2: [1, 3], 4: [1, 3], 6: [1, 3], 7: [1, 3], 8: [1, 3], 9: [1, 3], 10: [1, 3],
	12: [1, 3], 13: [1, 3], 14: [1, 3], 15: [1, 3], 16: [1, 3], 17: [1, 3], 18: [1, 3],
	19: [1, 3], 20: [1, 3], 21: [1, 3], 22: [1, 3], 23: [1, 3], 24: [1, 3], 25: [1, 3], 26: [1, 3], 27: [1, 3]}   # stage 4 (19..27; 27 ends with the Black Knight)
const MAX_ALIVE := 5
const BOSS_AT := 3400.0        # the boss appears when Mera gets this close to the map end ...
const BOSS_X := 1300.0         # ... standing this far from the end, in front of the exit (locked until he falls)


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(JSON_PATH, FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data


## the later bodies of King Nerochilde: worn by the nero node (nero.gd), never spawned on their own
const FORM_ONLY := ["nero_reaper", "nero_giant"]


static func ids() -> Array:
	var out: Array = []
	for k in DEFS.keys():
		if k not in FORM_ONLY:
			out.append(k)
	return out


static func def(id: String) -> Dictionary:
	return DEFS[id]


## the AI script that runs this enemy: DEFS "script" (Stage 3 cl_* enemies), else the one shared monster.gd
static func script_for(id: String) -> GDScript:
	var sp := String(DEFS[id].get("script", "res://scripts/game/monster.gd"))
	return load(sp)


static func art(id: String) -> Dictionary:
	return data()[id]


## The frame to draw on a card. Cropped to the body (the opaque pixels of the pose) so the
## big empty canvas is not drawn. Does not call get_image(), which is null in an export.
static func frame_art(id: String) -> Dictionary:
	var a := art(id)
	var anims: Dictionary = a["anims"]
	var key := ""
	for want in ["idle", "skip", "walk"]:
		if anims.has(want):
			key = want
			break
	if key == "":
		key = String(anims.keys()[0])
	var e: Dictionary = anims[key]
	var piv := Vector2(float(e["pivot"][0]), float(e["pivot"][1]))
	var b: Array = a["body"]
	var src := Rect2(piv.x + float(b[0]) - 1.0, piv.y + float(b[1]) - 1.0, float(b[2]) - float(b[0]) + 2.0, float(b[3]) - float(b[1]) + 2.0)
	var tex: Texture2D = load(String(e["frames"][0]))
	if tex != null:
		src.position.x = clampf(src.position.x, 0.0, tex.get_width() - 1.0)
		src.position.y = clampf(src.position.y, 0.0, tex.get_height() - 1.0)
		src.size.x = clampf(src.size.x, 1.0, tex.get_width() - src.position.x)
		src.size.y = clampf(src.size.y, 1.0, tex.get_height() - src.position.y)
	return {"tex": tex, "src": src, "pivot": piv}


static var _faces: Dictionary = {}


## A small opaque portrait. The big frame sheets are mostly empty, and on some devices those
## empty pixels come out white. This bakes just the character onto the card colour, so the
## picture itself has no blank canvas to turn into a white box.
static func face(id: String) -> Texture2D:
	if _faces.has(id):
		return _faces[id]
	var baked_path := "res://assets/ui/faces/%s.png" % id
	var baked: Texture2D = load(baked_path) if ResourceLoader.exists(baked_path) else null
	if baked != null:
		_faces[id] = baked
		return baked
	var pic := frame_art(id)
	var tex: Texture2D = pic["tex"]
	if tex == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = pic["src"]
	_faces[id] = atlas
	return atlas
