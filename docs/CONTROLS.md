# Mera: The Baby Giant: playable test level controls

Buttons use **Xbox names** (Godot/SDL maps a PS4 pad by position: A = Cross, B = Circle, X = Square, Y = Triangle,
LB/RB = L1/R1, LT/RT = L2/R2, Back = Share, Start = Options). The left stick works the same as the d-pad.
Speeds are given at 1x and scale with Mera's size (2x moves twice as fast). v0.3: walk 50, run 200, dashes 1600, back dodge 800 px/s.

v0.4: every button acts on the frame it is pressed. Moves marked with a **stamina** cost need that much stamina (see the Stamina section).

## Gamepad
| Input | Action |
|---|---|
| D-pad Left / Right | walk, 50 px/s |
| D-pad Up | jump, instantly (it never waits for another button). In the air: double jump. In Fury: take off and fly |
| D-pad Down | crouch. Down + A = slide |
| **Down + Y** while crouching | **earthquake** (v0.5), 20 stamina: the ground shakes for 1 s (very fast, violent shake of the whole map). Every enemy touching the ground during the quake is stunned until 5 s after it started (enemies in the air are stunned if they land while it lasts) |
| **A** (hold) + direction | run, 200 px/s |
| **B** | back dodge (free): same distance as v0.2 in half the time (800 px/s backwards, animation at 2x). Invulnerable for its first 70 %, as are the dashes |
| **B + Y** together (within 67 ms, either order, or one held when the other is pressed) | **rising slash** (free), in place: no dodge, no bolt |
| B + Y, then **Y** (during the rising slash or up to 350 ms after it) | **slam** (free) |
| **B, then Y** (Y more than 67 ms after B: during the dodge or up to 220 ms after it) | **fast quick fire**: animation at 2x and the bolt at 2x speed (800 px/s × size). 5 stamina, the same as a normal quick fire |
| **B, then X** (during the dodge or up to 220 ms after it) | dodge attack. It does not chain: more X presses never give the rising slash or the slam |
| **X** | 1x attack |
| X X X (standing or walking forward) | 1x → 2x → 2x-2 (fast mashing works: a 3rd X pressed while 1x is still playing counts) |
| X X, then hold X (≥ 170 ms) | 1x → 2x → 2x-1 (2x-2 starts at once and upgrades to 2x-1 within 4 frames if the hold completes) |
| X X Y | 1x → 2x → 3x (with slash). X X Y Y is still 3x, never the beam |
| X X X Y (Y any time during the 3rd hit, or up to 250 ms after it) | 1x → 2x → **beam combo**, 20 stamina: the beam always runs off-screen; big recoil pushes Mera back and shakes the screen. Without 20 stamina the 3rd hit just plays out (fail cue) |
| **Y** | quick fire, 5 stamina (bolt flies forward at 400 px/s × size, damage × size) |
| **X + Y** together (within 67 ms, either order) | rear explosion, 12 stamina: the fireball lands behind her and the screen shakes when it detonates |
| **A + Y** together, or Y while A is held | ground dash, 6 stamina: 2x the v0.2 distance in half the time (1600 px/s, aerial-dash animation at 2x, afterimage trail) |
| X + A | plain 1x attack (no longer a dash) |
| In the air: **X** | jump attack. X again: second hit |
| In the air: **Y** (e.g. Up, then Y) | aerial dash (once per jump), 6 stamina, 1600 px/s, same timing as the ground dash. In Fury flight Y is a quick fire (5 stamina) |
| **L1** | heal: drink one carried green potion, +1 size (max 6x). No potion = "fail" cue, nothing happens |
| **L2 tap** (released within 300 ms) at 100 % rage, outside Fury | **lightning**: spends the **whole meter**; heal pose, then a strike from above the top of the screen to the ground, on the nearest enemy or in front of Mera (AOE, damage 3 × size). Below 100 % a tap does nothing (HUD hint) |
| **L2 hold** | heal pose, then a spherical barrier that blocks every hit while held: 3 stamina to raise, 4 / s held. The bubble is fitted around the whole pose at every size and facing, and is her hurtbox while up |
| **L2 + R2** together (within 67 ms, either order, or R2 while the L2 bubble is up) at 100 % rage | **Fury** for 12 s: red aura, deep-red spells and explosions, deeper sfx, flight. Works on the ground and in the air |
| **R2** alone | in Fury: take off / land. Outside Fury: nothing (HUD hint "Fury is L2 + R2") |
| **R1** | **summon an ally** (from v0.7: needs a collected ally card; with several card types a picker opens). No card: fail cue |
| Fury flight | Up in the air takes off. 8-way movement; Mera tilts head-first toward where she flies and eases upright when hovering. Raised-arms pose while moving, tucked hover while idle. Down at ground level, or R2, lands |
| Start | controls overlay. Restart after Game Over |
| Back (Share) | animation gallery (every baked animation). Left/Right = previous/next, A = replay |

## Keyboard
| Key | Pad equivalent |
|---|---|
| Arrows / WASD | d-pad |
| Shift or Space | A |
| L | B |
| J | X |
| K | Y |
| U / I / O / P | L1 / R1 / L2 / R2 (so Fury = O + P) |
| Enter or F1 | Start |
| Tab or G | Back (gallery) |
| F2 | debug: hit/hurt boxes, and enables free size keys PageUp/PageDown (or + / −, or right stick up/down), 1x–19x |
| F11 / Esc | fullscreen / leave fullscreen, then quit |

## v0.5 button remap: the decision
- The user asked for lightning on L2, Fury on R2+L2, and R1 freed for allies. The barrier also lived on L2, so **L2 now does both, split by press length**:
  - a **tap** gives the lightning (it needs the full meter);
  - a **hold** gives the barrier.
- This works without any input delay, because both moves start with the same heal pose. L2 commits at once. If you let go before the bubble forms (heal frame 5, 300 ms), the pose carries on into the lightning. If you're still holding, the bubble forms.
- With less than 100 % rage a tap just drops the pose.
- **Lightning from inside the bubble (the v0.3 R1-in-bubble) is gone**, because L2 is already held. R2 while in the bubble now gives Fury.
- **Fury = L2 + R2** as a chord (67 ms, either order). L2 pressed first starts the barrier pose, and the R2 converts it into Fury (no stamina spent). R2 alone keeps its Fury-flight role (take off / land).

## Timing windows (v0.4, all in `scripts/game/tuning.gd`)
| Window | Value | What it does |
|---|---|---|
| Commit | 0 ms | X, Y, B and Up start their move on the frame they are read. Nothing waits to see whether a chord follows |
| Chord (X+Y, A+Y, B+Y) | 67 ms (4 frames) | If the partner lands within 67 ms, in either order, the move that already started converts in its first frames (retroactive). A 50 ms human gap can read as 67 ms at 60 Hz, which is why it is 4 frames. Stamina for a converted quick fire is refunded |
| Buffer | whole move + 450 ms | A press made at any point during a move is kept until that move's chain point. Presses are kept for 1.5 s of history |
| 1x → 2x | from 1x frame 9 to its end | X anywhere during 1x (mashing included) chains. Before v0.4 only frames 10-12 counted, and a later X restarted 1x |
| 2x branch | from 2x frame 9 | Y → 3x, X → 2x-2 (or 2x-1 if held ≥ 170 ms). No freeze: 2x-2 upgrades to 2x-1 within 4 frames when the hold completes |
| Beam Y | the whole 3rd hit + 250 ms | Y after the 3rd X, any time while 2x-1 / 2x-2 plays or up to 250 ms after it |
| Combo grace | 220 ms | A combo hit that just recovered to idle still accepts its follow-up for 220 ms |
| Back dodge follow-ups | the dodge + 220 ms | Y → fast quick fire (from dodge frame 8), X → dodge attack (from frame 12) |
| Slam | the rising slash + 350 ms | Y after B+Y gives the slam |

## Stamina
- A **STAMINA** bar on the HUD, under rage. It starts at 60 / 60 and regenerates 1 per second.
- Costs: quick fire 5 (the fast quick fire too), ground dash 6, aerial dash 6, rear explosion 12, beam combo 20, bubble 3 to raise + 4 / s held.
- Free: attacks, back dodge, dodge attack, rising slash, slam, jumps, heal and lightning (rage), Fury.
- Not enough stamina: the fail cue plays, the STAMINA bar flashes, and the move doesn't start.
- Blue potions: +30 stamina. Blue-and-white potions: +5 max stamina, up to 120. The bar grows with the max.

## Interpretations
- "X modifies the jump into a jump attack" and "Y modifies the jump into an aerial dash": jump with Up, then press X or Y in the air.
- "A+Y dashes normally": a ground dash that reuses the aerial-dash animation and moves 1600 px/s × size. X+A was the old dash input and is now just a 1x attack.
- Up + X is not a separate move. Up jumps and X then does the jump attack. Up + Y is not a ground move either: Up jumps at once, and Y in the air is the aerial dash.
- v0.4 dodge chain (final steering): the rising slash is the **B + Y chord**, Y again gives the slam. **B, then Y** is the fast quick fire. **B, then X** is the dodge attack. The split between the two B + Y forms is the 67 ms chord window: within it you get the rising slash, after it the dodge plays and Y gives the fast quick fire.
- Ladder, ledge and wall-jump animations only appear in the gallery, because the test level has no ladders or walls.
