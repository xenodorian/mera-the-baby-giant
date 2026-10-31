# Mera: The Baby Giant: playable test level controls

Buttons use **Xbox names** (Godot/SDL maps a PS4 pad by position: A = Cross, B = Circle, X = Square, Y = Triangle,
LB/RB = L1/R1, LT/RT = L2/R2, Back = Share, Start = Options). The left stick works the same as the d-pad.
Speeds are given at 1x and scale with Mera's size (2x moves twice as fast). v0.3: walk 50, run 200, dashes 1600, back dodge 800 px/s.

## Gamepad
| Input | Action |
|---|---|
| D-pad Left / Right | walk, 50 px/s |
| D-pad Up | jump. In the air: double jump. In Fury: take off and fly |
| D-pad Down | crouch. Down + A = slide |
| **A** (hold) + direction | run, 200 px/s |
| **B** | back dodge: same distance as v0.2 in half the time (800 px/s backwards, animation at 2x). Invulnerable for its first 70 %, as are the dashes |
| **X** | 1x attack |
| X X X (standing or walking forward) | 1x → 2x → 2x-2 |
| X X, then hold X (≥ 180 ms) | 1x → 2x → 2x-1 |
| X X Y | 1x → 2x → 3x (with slash). X X Y Y is still 3x, never the beam |
| X X X Y (Y within 0.3 s of the 3rd X) | 1x → 2x → **beam combo**: the beam always runs off-screen; big recoil pushes Mera back and shakes the screen |
| **Y** | quick fire (bolt flies forward, damage × size) |
| **X + Y** together (within 50 ms) | rear explosion: the fireball lands behind her and the screen shakes when it detonates |
| **A + Y** together, or Y while A is held | ground dash: 2x the v0.2 distance in half the time (1600 px/s, aerial-dash animation at 2x, afterimage trail) |
| X + A | plain 1x attack (no longer a dash) |
| B then X (from dodge frame 12) | dodge attack. X again: rising slash. X again: slam |
| In the air: **X** | jump attack. X again: second hit |
| In the air: **Y** | aerial dash (once per jump), 1600 px/s, same timing as the ground dash |
| **L1** | heal: drink one carried green potion, +1 size (max 6x). No potion = "fail" cue, nothing happens |
| **R1** at 100 % rage, outside Fury | spends the **whole meter**: heal pose, then a lightning strike from above the top of the screen to the ground, on the nearest enemy or in front of Mera (AOE, damage 3 × size) |
| **L2** (hold) | heal pose, then a spherical barrier that blocks every hit while held. The bubble is fitted around the whole pose, raised hand and energy ball included, at every size and facing. It is also her hurtbox while it is up |
| **R1** while holding L2 | lightning strike from inside the bubble: same rule (100 % rage, spends it all). She stays in the bubble pose and keeps blocking |
| **R2** at 100 % rage | **Fury** for 12 s: red aura, deep-red spells and explosions, deeper sfx, flight |
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
| U / I / O / P | L1 / R1 / L2 / R2 |
| Enter or F1 | Start |
| Tab or G | Back (gallery) |
| F2 | debug: hit/hurt boxes, and enables free size keys PageUp/PageDown (or + / −, or right stick up/down), 1x–19x |
| F11 / Esc | fullscreen / leave fullscreen, then quit |

## Timing windows
- **Chords** (X+Y, A+Y): both buttons pressed within **50 ms**. A lone X or Y waits 50 ms for its partner before it acts.
- **Input buffer**: a press stays buffered for **450 ms**, so a combo button pressed early still chains.
- **Chain points**: atk1 → atk2 from frame 10 (grace until frame 12). The 2x branch (2x-1 / 2x-2 / 3x / beam) is picked at frame 9.
  Dodge attacks chain from frame 12 / 15 / 13.
- **Hold**: the third X held for at least **180 ms** gives 2x-1. Released sooner gives 2x-2.

## Interpretations
- "X modifies the jump into a jump attack" and "Y modifies the jump into an aerial dash": jump with Up, then press X or Y in the air.
- "A+Y dashes normally": a ground dash that reuses the aerial-dash animation and moves 1600 px/s × size. X+A was the old dash input and is now just a 1x attack.
- Up + X is not a separate move. Up jumps and X then does the jump attack.
- Ladder, ledge and wall-jump animations only appear in the gallery, because the test level has no ladders or walls.
