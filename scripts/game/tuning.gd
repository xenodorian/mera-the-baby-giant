class_name Tuning
extends RefCounted
## v0.4: every gameplay number that is meant to be tuned, in one place (docs/GAME_RULES.md, docs/CONTROLS.md).

# ---------------------------------------------------------------- input / combo windows (ms, Mera's physics clock)
const CHORD_MS := 67.0            # X+Y, A+Y, B+Y: one chord when both land within this (4 frames: a 50 ms gap can read as 67 ms at 60 Hz)
const BUFFER_MS := 450.0          # a press made in neutral stays usable this long
const KEEP_MS := 1500.0           # presses made during a move are kept this long for its chain (never expire mid-move)
const COMBO_GRACE_MS := 220.0     # after a combo hit recovers to idle, the next press still continues the combo
const HOLD_MS := 170.0            # X X, hold X: the third X held this long -> 2x-1 (otherwise 2x-2)
const UPGRADE_FRAMES := 4         # ... a hold that completes in 2x-2's first 4 frames still switches to 2x-1
const BEAM_GRACE_MS := 250.0      # X X X Y: the Y counts any time during the third hit and this long after it
const CHAIN_1X := 9               # 1x atk cancels into 2x atk from this frame (canon chain point f9/f10)
const FAST_FIRE_FRAME := 8       # B, Y: the dodge cuts into the fast quick fire from this frame (B, X: from f12)
const DODGE_GRACE_MS := 220.0     # B, Y / B, X still work this long after the dodge ends
const FAST_FIRE_ANIM := 2.0       # B, Y fast quick fire: animation playback rate ...
const FAST_FIRE_BOLT := 2.0       # ... and bolt speed multiplier (800 px/s x size)
const SLAM_GRACE_MS := 350.0      # rising slash (B+Y): Y during it (any frame) or this long after it -> slam
const CHAIN_2X := 9               # 2x atk resolves its branch (2x-1 / 2x-2 / 3x / beam) from this frame

# ---------------------------------------------------------------- stamina
const STAMINA_START := 60.0
const STAMINA_MAX_CAP := 120.0    # +5 max potions stop here
const STAMINA_REGEN := 1.0        # per second
const STAMINA_COST := {
	"quick_fire": 5.0,
	"gdash": 6.0,
	"adash": 6.0,
	"rear_blast": 12.0,
	"beam_ender": 20.0,
	"barrier": 3.0,               # to raise the bubble ...
}
const BUBBLE_DRAIN := 4.0         # ... then this much per second while it is held (it drops at 0)
const STAMINA_POTION := 30.0      # blue potion
const STAMINA_MAX_POTION := 5.0   # blue-and-white potion: +5 max (and +5 now)

# ---------------------------------------------------------------- knights
const FIRE := {
	"scale": 6.0, "hp": 20, "speed": 192.0, "dmg": 2, "sp_dmg": 3, "block": true, "special": true,
	"anim_speed": 1.0, "rage": 10.0, "tell": 0.4, "sp_tell": 0.7,
}
const BLUE := {
	"scale": 3.0, "hp": 5, "speed": 576.0, "dmg": 1, "sp_dmg": 0, "block": false, "special": false,
	"anim_speed": 1.5, "rage": 4.0, "tell": 0.3, "sp_tell": 0.0,
}
const DASH_MULT := 3.0            # chase dash (04_roll) = 3x the knight's own walk speed
const DASH_TRIGGER := 760.0       # ... when Mera is farther than this (px, edge to edge)
const DASH_MAX_S := 0.6           # ... for at most this long
const DASH_COOLDOWN_S := 3.0      # ... then not again for this long
const BLOCK_MAX_S := 1.4          # 09_defend: held at most this long, then forced down ...
const BLOCK_COOLDOWN_S := 2.5     # ... and unavailable for this long
const BOLT_SEE_PX := 400.0        # a quick-fire bolt first seen farther than this is jumped over
const BOLT_LOOK_PX := 1500.0      # how far ahead he watches for bolts
const JUMP_V := 1500.0            # knight jump take-off speed (px/s, 6x); scaled by scale/6
const KNIGHT_GRAVITY := 3000.0
const AIR_CHASE_PX := 620.0       # Mera airborne within this horizontal gap -> jump attack (air_atk)
const AIR_CHASE_COOLDOWN_S := 1.6
const SPECIAL_EVERY := 3          # the Fire Knight's special replaces every 3rd attack string
const BLUE_STAMINA_P := 0.35      # blue knight drops: +30 stamina potion ...
const BLUE_MAX_P := 0.10          # ... and, rolled independently, a +5 max-stamina potion
