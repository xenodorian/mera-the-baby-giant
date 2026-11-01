class_name Tuning
extends RefCounted
## v0.4: every gameplay number that is meant to be tuned, in one place (docs/GAME_RULES.md, docs/CONTROLS.md).

# ---------------------------------------------------------------- input / combo windows (ms, Mera's physics clock)
const CHORD_MS := 67.0            # X+Y, A+Y, B+Y: one chord when both land within this (4 frames: a 50 ms gap can read as 67 ms at 60 Hz)
const MARK_CHORD_MS := 150.0      # Q+W+1+2 (L1+R1+L2+R2): all four presses, all held, land within this
const MARK_S := 8.0               # the marked-slash freeze lasts at most this long
const MARK_DMG := 3               # flat damage per marked slash (not multiplied by size)
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
# v0.9.1 Y chain (owner t99u): Y, Y, Y ... (docs/CONTROLS.md "Y chain")
const YCHAIN_FIRST_FRAME := 11    # the 1st quick fire (fires on f10 = canon GIF frame 12) takes the next Y from this frame
const YCHAIN_START := 12          # each follow-up replays quick fire from this frame ...
const YCHAIN_FIRE := 14           # ... and fires on f14 (canon GIF frame 16: the extended f14 pose) ...
const YCHAIN_NEXT_FRAME := 15     # ... and takes the next press from this frame
const YCHAIN_SPAWN := [-32.0, -41.0]   # wand tip on f14 (canon GIF tip (94,22) vs f10 (80,25))
const YCHAIN_GRACE_MS := 220.0    # after a chain shot recovers, the next press still continues the chain (= COMBO_GRACE_MS)
const PULSE_REACH := 900.0        # Y Y Y then L2: the pulse wave pushes every enemy within this (px, at 2x; scales with size) ...
const PULSE_PUSH := 340.0         # ... this far away from her (px, scales with size; bosses are not moved), 0 damage
const PULSE_S := 0.35             # ring expands over this long
const VBEAM_S := 0.7              # Y Y Y then X: the vertical beam lasts this long ...
const VBEAM_DMG := 3              # ... and hits every airborne / flying enemy in its column once, for this x size
const VBEAM_HALF_W := 34.0        # column half width, native px (x size)
const VFIRE_FRAME := 6            # Up+Y: bolts leave on heal frame 6. The pose is one rendered frame per drawing (~100 ms).
const VFIRE_SPAWN := [-15.0, -74.0]    # raised wand tip in the heal pose (native px)
const HEAL_POSE_END := 9          # vertical fire / pulse / vertical beam play heal frames 0-8 only (no heal burst)
const SLAM_GRACE_MS := 350.0      # rising slash (B+Y): Y during it (any frame) or this long after it -> slam
const CHAIN_2X := 9               # 2x atk resolves its branch (2x-1 / 2x-2 / 3x / beam) from this frame

# ---------------------------------------------------------------- stamina
const STAMINA_START := 60.0
const STAMINA_MAX_CAP := 200.0    # +5 max potions stop here
const STAMINA_REGEN := 1.0        # per second
const STAMINA_COST := {"earthquake": 20, 
	"quick_fire": 5.0,
	"gdash": 6.0,
	"adash": 6.0,
	"rear_blast": 12.0,
	"beam_ender": 20.0,
	"vfire": 15.0,                # Up+Y: three bolts, three times a quick fire
	"pulse": 3.0,                 # v0.9.1 Y Y Y, L2 pulse wave
	"vbeam": 12.0,                # v0.9.1 Y Y Y, X vertical beam
	"barrier": 3.0,               # to raise the bubble ...
}
const BUBBLE_DRAIN := 4.0         # ... then this much per second while it is held (it drops at 0)
const STAMINA_POTION := 30.0      # blue potion
const STAMINA_MAX_POTION := 5.0   # blue-and-white potion: +5 max (and +5 now)
const RAGE_MAX_START := 100.0
const RAGE_MAX_CAP := 200.0
const RAGE_MAX_POTION := 5.0       # +5 max rage (and +5 now)

# ---------------------------------------------------------------- knights
const FIRE := {
	"scale": 6.0, "hp": 20, "speed": 192.0, "dmg": 1, "sp_dmg": 2, "block": true, "special": true,
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

# ---------------------------------------------------------------- v0.5 earthquake (Down+Y while crouching)
const QUAKE_S := 1.0            # the ground shakes this long
const QUAKE_STUN_S := 5.0       # enemies touching the ground are stunned until this long after the quake started
const QUAKE_SHAKE := 34.0       # px, re-randomised every frame (very fast, violent)
# v0.8 SUPER EARTHQUAKE: Down+Y while crouching with a FULL rage meter, outside Fury (docs/GAME_RULES.md)
const IMPACT_FRAME_S := 0.16     # anime impact frame: the game freezes, the screen turns to a black/white silhouette
const SUPER_QUAKE_S := 2.0       # then the ground shakes this long ...
const SUPER_QUAKE_STUN_S := 7.0  # ... enemies touching the ground are stunned until this long after it started ...
const SUPER_QUAKE_SHAKE := 70.0  # ... twice the normal shake ...
const SUPER_QUAKE_DMG := 2       # ... every enemy takes this, flat (never x Mera's size) ...
const SUPER_QUAKE_REACH := 1920.0  # ... and every ground breakable within this of the camera centre is destroyed
# ---------------------------------------------------------------- v0.5 L2 / R2 remap
const L2_TAP_FRAMES := 5        # L2 released before the bubble forms (heal frame 5, one rendered frame each, ~83 ms) drops the pose
const LIGHTNING_CHAIN_S := 0.08  # R2: one bolt per on-screen enemy, this far apart

# ---------------------------------------------------------------- v0.8 (S4) impact pass (scripts/game/hit_stop.gd)
const HITSTOP_LIGHT_MS := 45.0    # a normal hit freezes the game this long (real time) ...
const HITSTOP_HEAVY_MS := 80.0    # ... a heavy hit (2+ base damage, explosions, lightning) ...
const HITSTOP_KILL_MS := 100.0    # ... a killing blow ...
const HITSTOP_PARRY_MS := 120.0   # ... a parry
const HITSTOP_MAX_MS := 120.0     # never longer than this, however hits overlap
const SFX_JITTER := 0.08          # impact sounds play at a random pitch within +-8 % (and pick a random variant)
# ---------------------------------------------------------------- v0.8 parry (L2 pressed just before a hit lands)
const PARRY_MS := 150.0           # L2 pressed at most this long before the hit = parry (no damage)
const PARRY_COUNTER_S := 0.9      # ... then Mera's hits do PARRY_COUNTER_MULT damage for this long ...
const PARRY_COUNTER_MULT := 2
const PARRY_STUN_S := 2.0         # full-bubble parry: the attacker is staggered this long
const CROUCH_PARRY_STUN_S := 1.0  # small-bubble parry: staggered this long
const PARRY_IFRAMES_S := 0.25
const DEFLECT_SPEED := 1.6        # a parried projectile flies back this much faster ...
const DEFLECT_DMG := 3            # ... and deals this much (fixed) to the first enemy it meets
const PARRY_KNOCK_PX := 400.0     # full-bubble parry: slide this far (px), then the stun holds them
const CROUCH_PARRY_KNOCK_PX := 200.0  # small-bubble parry
const BARRIER_KNOCK_PX := 200.0   # full bubble held, with no parry window: this far, no stun
const PARRY_KNOCK_SPEED := 800.0  # how fast that slide plays (px/s). The distance above is what they travel.
const SWING_PARRY_MS := 150.0     # v0.9.1: X (atk1 / jatk1) reflects a projectile if the hitbox meets it within this of going live
# ---------------------------------------------------------------- v0.9.4 crouch bubble: free, 3 s, subtracts 1 damage. A fresh crouch still parries.
const CROUCH_BUBBLE_R := 32.0
const CROUCH_BUBBLE_S := 3.0
const BUBBLE_PULL := 2200.0    # both bubbles vacuum every item on screen toward Mera (px/s)
## one defeated enemy drops a fury orb. Potions, coins, and cards come from breakables.
const ENEMY_LOOT := [["sphere", 100.0]]
# ---------------------------------------------------------------- keys and locked chests
const KEY_DROP_P := 0.25          # an enemy death drops a key on its fury orb with this chance ...
                                  # ... but only while no key is out (on the floor or held). Keys are used on chests.
const CHEST_COINS := [3, 5]       # a chest releases this many coins (inclusive) ...
const CHEST_COIN_GOLD := 3        # ... and each of those coins is worth this much gold (a coin from a broken object is worth 1)
const CHEST_ITEMS := [1, 3]       # ... and this many other items (potion, mana or card)
const KEY_FX_S := 0.6             # the floating key shown when a chest unlocks
const LOCKED_MSG_S := 1.5         # "a key opens it" is shown at most this often
## level art lowered to the ground (game px, added to the layer's y). Cemetery graves_far stood about 65 px high.
const LAYER_LOWER := {"res://assets/levels/cemetery/graves_far.png": 65.0}
# ---------------------------------------------------------------- v0.9.1 rising slash (datk2): windup 4x, rise 2x speed and 2x distance
const RSLASH_WINDUP_SPEED := 4.0  # frames before the rise play at 4x (every frame is kept)
const RSLASH_RISE_FROM := 7       # the upward burst is these frames ...
const RSLASH_RISE_TO := 11
const RSLASH_VY := -760.0         # was -380: 2x, and the frame window stays 1x, so she rises twice as far
# ---------------------------------------------------------------- v0.8 juggles (monster.gd)
const LAUNCH_VY := 1150.0         # launchers (rising slash, slam, 3x, explosions) throw ground enemies up ...
const LAUNCH_VX := 240.0
const JUGGLE_HIT_VY := 520.0      # ... a hit in the air pops them up again, but less each time:
const JUGGLE_GRAVITY_STEP := 0.3  # gravity x(1 + 0.3 per juggle hit) so a juggle can't go on forever
const JUGGLE_MAX := 8             # after this many air hits they just fall
const GROUND_BOUNCE := 0.42       # landing faster than BOUNCE_MIN_VY bounces once at this fraction
const BOUNCE_MIN_VY := 650.0
const WALL_BOUNCE := 0.6          # flung into a map wall: bounce back at this fraction (1 damage)
const CORPSE_VY := 950.0          # a defeated enemy is flung (corpse launch), then shatters on landing
const CORPSE_VX := 620.0
const CORPSE_MAX_S := 1.4
# ---------------------------------------------------------------- v0.8 debris / gore
const SHARDS_MAX := 420           # live debris pieces at most (oldest are recycled)
const GORE := true                # gibs + blood on enemy deaths (props only shatter)

# ---------------------------------------------------------------- v0.8 dragon boss (docs/GAME_RULES.md "Infernal Dragon")
const DRAGON_START_SIZE := 19      # drawn at k = its size; its size IS its health, like Mera's
const DRAGON_HP_PER_SIZE := 8      # damage that costs one size (a 2x Mera combo ~ 1 size)
const DRAGON_PHASES := [12, 9, 6, 3]   # each fires once, when its size first drops to or past it
const DRAGON_GROW := 3             # sizes regained when a phase bolt hits Mera (once per phase)
const DRAGON_SIZE_RATE := 3.0      # size tween speed (x the gap, per second; at least 1 size/s)
const DRAGON_FLY_H := 380.0        # take-off height (px above the ground line)
const DRAGON_TAKEOFF_S := 0.9
const DRAGON_LAND_S := 0.8
const DRAGON_BOLTS := 5            # explosive fire bolts per phase ...
const DRAGON_BOLT_TELL_S := 0.5    # ... each with a red (ranged) tell ...
const DRAGON_BOLT_GAP_S := 0.45    # ... then this pause before the next tell
const DRAGON_BOLT_FLIGHT_S := 1.15 # default lob time from the mouth to the ground (v0.8.1: per lob, see DRAGON_BOLT_T)
const DRAGON_BOLT_G := 1900.0      # bolt gravity (ballistic arc)
const DRAGON_BOLT_SPREAD := 140.0  # aim spread around Mera (the first bolt is aimed straight at her)
# v0.8.1 flight: the dragon flies around between lobs (docs/GAME_RULES.md "Infernal Dragon")
const DRAGON_FLY_FPS := 11.0       # the user-picked 4-frame wing loop (breath 1,5,4,5 without fire)
const DRAGON_FLY_BOB := 26.0       # px, bob amplitude ...
const DRAGON_FLY_BOB_HZ := 1.6     # ... and speed (one bob per ~0.6 s)
const DRAGON_FLY_MOVE_S := 0.8     # flight time between two lob spots (eased)
const DRAGON_FLY_LIFT := [250.0, 470.0]   # height range of the lob spots (px above the ground line)
# lob spots: [side, distance from Mera] in her facing frame (+1 = in front of her, -1 = behind), shuffled per phase:
# short, mid and long, from both sides (he crosses over her to reach them)
const DRAGON_FLY_SPOTS := [[1, 320.0], [-1, 560.0], [1, 1000.0], [-1, 300.0], [1, 700.0]]
const DRAGON_FLY_SPOT_JITTER := 70.0
const DRAGON_FLY_SPOT_GAP := 220.0  # v0.9: lob spots in one phase are at least this far apart when there is room
const DRAGON_FLY_SCREEN := 860.0   # spots stay within this of the camera centre (the screen is +-960), inside the walls
                                   # (v0.8.2: minus 20 % of his body width, and never closer to Mera than mouth + MIN_DX)
# v0.8.2: bolts leave the mouth HORIZONTALLY (vy0 = 0) and gravity curves them down onto the target:
# flight time = sqrt(2 * drop / G), vx = dx / time (exact landing). The mouth is measured on the art (spit frame 4).
const DRAGON_MOUTH := Vector2(-33.5, -12.0)  # native px from the feet pivot, as the art faces (left)
const DRAGON_BOLT_MIN_DX := 160.0  # the target is at least this far in front of the mouth (lob spots keep the room)
const DRAGON_BOLT_DMG := 2         # never scales with the dragon's size (enemies never scale damage)
const DRAGON_BOLT_R := 170.0       # explosion radius

