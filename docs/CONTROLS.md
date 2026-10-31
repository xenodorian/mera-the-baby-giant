# Mera: The Baby Giant: playable test level controls

Buttons use **Xbox names** (Godot/SDL maps a PS4 pad by position: A = Cross, B = Circle, X = Square, Y = Triangle,
LB/RB = L1/R1, LT/RT = L2/R2, Back = Share, Start = Options). The left stick works the same as the d-pad.
Speeds are given at 1x and scale with Mera's size (2x moves twice as fast).

## Gamepad
| Input | Action |
|---|---|
| D-pad Left / Right | walk, 100 px/s |
| D-pad Up | jump. In the air: double jump. In Fury: take off and fly |
| D-pad Down | crouch. Down + A = slide |
| **A** (hold) + direction | run, 200 px/s |
| **B** | back dodge, 400 px/s backwards |
| **X** | 1x attack |
| X X X (standing or walking forward) | 1x → 2x → 2x-2 |
| X X, then hold X (≥ 180 ms) | 1x → 2x → 2x-1 |
| X X Y | 1x → 2x → 3x (with slash) |
| X X X Y | 1x → 2x → **beam combo**: big recoil pushes Mera back and shakes the screen |
| **Y** | quick fire (bolt flies forward, damage × size) |
| **X + Y** together (within 50 ms) | rear explosion: the fireball lands behind her and the screen shakes when it detonates |
| **A + Y** together, or Y while A is held | ground dash, 400 px/s (aerial-dash animation on the ground) |
| X + A | plain 1x attack (no longer a dash) |
| B then X (from dodge frame 12) | dodge attack. X again: rising slash. X again: slam |
| In the air: **X** | jump attack. X again: second hit |
| In the air: **Y** | aerial dash (once per jump) |
| **L1** | heal: drink one carried green potion, +1 size (max 6x). No potion = "fail" cue, nothing happens |
| **R1** | heal pose, then a lightning strike in front of Mera (AOE, damage 3 × size) |
| **L2** (hold) | heal pose, then a spherical barrier that blocks every hit while held |
| **R2** at 100 % rage | **Fury** for 12 s: red aura, deep-red spells and explosions, deeper sfx, flight |
| Fury flight | Up in the air takes off. 8-way movement. Raised-arms pose while moving, tucked hover while idle. Down at ground level, or R2, lands |
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
- "A+Y dashes normally": a ground dash that reuses the aerial-dash animation and moves 400 px/s × size. X+A was the old dash input and is now just a 1x attack.
- Up + X is not a separate move. Up jumps and X then does the jump attack.
- Ladder, ledge and wall-jump animations only appear in the gallery, because the test level has no ladders or walls.
