# Mera: The Baby Giant: playable test level controls

Buttons use **Xbox names** (Godot/SDL maps a PS4 pad by position: A = Cross, B = Circle, X = Square, Y = Triangle,
LB/RB = L1/R1, LT/RT = L2/R2, Back = Share, Start = Options). The left stick works the same as the d-pad.
Speeds are given at 1x and scale with Mera's size (2x moves twice as fast). v0.3: walk 50, run 200, dashes 1600, back dodge 800 px/s.

v0.4: every button acts on the frame it is pressed. Moves marked with a **mana** cost need that much mana (see the Mana section). The resource used to be called stamina.

## Gamepad
| Input | Action |
|---|---|
| D-pad Left / Right | walk, 50 px/s |
| D-pad Up | jump, instantly (it never waits for another button). In the air: double jump. In Fury: take off and fly |
| D-pad Down | crouch. Down + A = slide: she breaks destructibles she passes through (not cracked walls) and takes the drop. **Holding crouch** raises a **small free bubble** for 3 seconds (a dial empties, then it drops). It subtracts 1 from a hit and **pulls every item on screen to her**. A crouch started within 150 ms of a hit parries: no damage, 200 px knockback, 1 s stun. Any button except L1 drops it and does that move. L1 drinks a potion and the bubble stays |
| **Down + Y** while crouching | **earthquake** (v0.5), 20 stamina: the ground shakes for 1 s (very fast, violent shake of the whole map). Every enemy touching the ground during the quake is stunned until 5 s after it started (enemies in the air are stunned if they land while it lasts). **At 100 % rage (not in Fury): SUPER EARTHQUAKE** (v0.8): impact frame, then a 2 s quake, 7 s stun, flat 2 damage to every enemy, every ground breakable on screen destroyed; spends the whole meter + 20 stamina (see GAME_RULES) |
| **A** (hold) + direction | run, 200 px/s |
| **B** | back dodge (free): same distance as v0.2 in half the time (800 px/s backwards, animation at 2x). Invulnerable for its first 70 %, as are the dashes |
| **B + Y** together (within 67 ms, either order, or one held when the other is pressed) | **rising slash** (free), in place: no dodge, no bolt. v0.9.1: the windup is 4× faster and the rise is twice as fast and twice as high |
| B + Y, then **Y** (during the rising slash or up to 350 ms after it) | **slam** (free) |
| **B, then Y** (Y more than 67 ms after B: during the dodge or up to 220 ms after it) | **fast quick fire**: animation at 2x and the bolt at 2x speed (800 px/s × size). 5 stamina, the same as a normal quick fire |
| **B, then X** (during the dodge or up to 220 ms after it) | dodge attack. It does not chain: more X presses never give the rising slash or the slam |
| **X** | 1x attack. v0.9.1: if the hitbox meets an enemy projectile within 150 ms of going live, the shot is **reflected** at its shooter (or the nearest enemy) and damages them. Same in the air (`jatk1`) |
| X X X (standing or walking forward) | 1x → 2x → 2x-2 (fast mashing works: a 3rd X pressed while 1x is still playing counts) |
| X X, then hold X (≥ 170 ms) | 1x → 2x → 2x-1 (2x-2 starts at once and upgrades to 2x-1 within 4 frames if the hold completes) |
| X X Y | 1x → 2x → 3x (with slash). X X Y Y is still 3x, never the beam |
| X X X Y (Y any time during the 3rd hit, or up to 250 ms after it) | 1x → 2x → **beam combo**, 20 stamina: the beam always runs off-screen; big recoil pushes Mera back and shakes the screen. Without 20 stamina the 3rd hit just plays out (fail cue) |
| **Y** | quick fire, 5 stamina (bolt flies forward at 400 px/s × size, damage × size) |
| **Up + Y** (within 67 ms, either order) | three bolts, 15 mana (three times a quick fire): straight up and both upward diagonals. Each bolt is twice the size of a quick fire. The orb in the raised hand matches the bolt's red-orange, at the old sphere's size. Up alone still jumps. A Y in the air more than 67 ms after the jump is still the aerial dash |
| **X + Y** together (within 67 ms, either order) | rear explosion, 12 stamina: the fireball lands behind her and the screen shakes when it detonates |
| **A + Y** together, or Y while A is held | ground dash, 6 stamina: 2x the v0.2 distance in half the time (1600 px/s, aerial-dash animation at 2x, afterimage trail) |
| X + A | plain 1x attack (no longer a dash) |
| In the air: **X** | jump attack. X again: second hit |
| In the air: **Y** (e.g. Up, then Y) | aerial dash (once per jump), 6 stamina, 1600 px/s, same timing as the ground dash. In Fury flight Y is a quick fire (5 stamina) |
| **L1** | heal: drink one carried green potion, +1 size, up to the size cap (3x until the shop raises it, 9x at most). Every heal-pose frame stays up for one rendered frame. The size lands on frame 7, about 0.12 s after the press. No potion = "fail" cue. **Inside either bubble, L1 drinks at once and the bubble stays up.** **E** or **left-stick click** drinks a blue mana potion (+30 mana) without leaving the bubble |
| **L2** | full bubble while held: 3 mana to raise, 4 / s. It **pulls every item on screen to her**. A press just before a hit still parries. Letting go before the bubble forms does nothing else (it is not lightning) |
| **L2 hold** | heal pose, then a spherical barrier that blocks every hit while held: 3 stamina to raise, 4 / s held. The bubble is fitted around the whole pose at every size and facing, and is her hurtbox while up |
| **L2 just before a hit** (pressed at most 150 ms before it lands) | **parry**: no damage, the attacker is staggered **2 s** and slid **400 px** (bosses stay), and for 0.9 s Mera's hits do ×2. Holding the full bubble after that window **stops all damage** and slides the attacker **200 px** with no stun. Any other button except L1 drops the bubble and does that move. **L1 drinks a potion and the bubble stays** |
| **Y while the L2 bubble is up** at 100 % rage, outside Fury (v0.6) | **lightning from inside the bubble**: the same strike and cost as the L2 tap, but Mera keeps the pose and keeps blocking. Below 100 % it's a fail cue and the bubble stays up |
| **L2 + R2** together (within 67 ms, either order, or R2 while the L2 bubble is up) at 100 rage or more, outside Fury | **lightning**: costs **100 rage** (a bigger meter keeps the rest). Heal pose, then a strike from above the screen. R2 while the bubble is already up drops the strike and the bubble stays. Below 100 rage: fail cue, bubble stays |
| **R1** (v0.7) | **summon an ally** with a collected card. One card type: she comes at once. Several types: a picker (game paused; Left/Right, R1/A summon, B cancel). No usable card: fail cue + HUD note |
| **R2** alone | at **100 rage or more**, outside Fury: **Fury** for 12 s. It spends **100 rage** and leaves the rest. In Fury: take off / land |
| **R1** | **summon an ally** (from v0.7: needs a collected ally card; with several card types a picker opens). No card: fail cue |
| Fury flight | Up in the air takes off. 8-way movement; Mera tilts head-first toward where she flies and eases upright when hovering. Raised-arms pose while moving, tucked hover while idle. Down at ground level, or R2, lands |
| Start | **pause menu** (v0.11.4): Continue, Restart level, Back to title, Controls, Quit game. Up/Down choose, A confirms, B or Start continues. Volume keys do this on Android. Restart after Game Over |
| Back (Share) | nothing. The animation gallery is not bound to any key or button |

## Keyboard (v0.8 PC layout, user request t86u)
Every key is just another binding of the same action, so combos, chords (67 ms window), L2 tap vs hold and the parry window behave exactly as on a pad. No key is shared between two actions (test "input map: no key is shared").

| Key | Pad equivalent | Examples |
|---|---|---|
| Arrows | d-pad (move, Up = jump, Down = crouch) | Down + S = earthquake (super at 100 % rage) |
| **Z** (or Space) | A | Z (hold) + arrow = run, Z+S = ground dash |
| **X** | B | X = back dodge, X+S = rising slash |
| **A** | X | A A A = 1x 2x 2x-2, A+S = rear explosion |
| **S** | Y | S = quick fire |
| **Q** | L1 | health potion |
| **E** | left-stick click | mana potion |
| **W** | R1 | summon an ally |
| **1** (top row only) | L2 | hold = full bubble, just before a hit = parry |
| **2** (top row only) | R2 | alone = Fury (costs 100 rage). **1 + 2** = lightning. Numpad 1 and 2 are not these |
| **Q+W+1+2** together (within 150 ms, all held) at 100 rage or more | L1+R1+L2+R2 | **freeze slash**: costs **100 rage**. Freezes Mera and every enemy. Up to 9 nearest enemies get a unique mark, 1–9. On a keyboard the mark is that digit; on a pad or a touchscreen it is the matching arrow (5 is a dot). Top-row number, numpad direction, right-stick flick, swipe, or tap / R3 / numpad 5 slashes that enemy for a flat 3 and plays the slice. Lasts until every mark is cut or 8 s. This does not start Fury |
| Enter or F1 | Start | pause menu (continue, restart level, title, controls, quit). B / Start / Esc continues. Restarts after Game Over |
| Tab or G | (unbound; the gallery does not open) | |
| F2 | debug: hit/hurt boxes, and enables free size keys PageUp/PageDown (or + / −, or right stick up/down), 1x–19x | |
| F11 / Esc | fullscreen / leave fullscreen, then quit | |

**Menus** (level select, ally picker, Level Clear / Game Over): arrows choose, **Z** = confirm (A), **X** = back/cancel (B); Enter also confirms. The controls overlay (Start / Enter / F1) lists the keyboard key next to every pad button.
Until v0.7 the keys were WASD/Shift/L/J/K/U/I/O/P; those are gone (A, S, W and Q now mean pad buttons).
Numpad digits (Num Lock on) are the right stick: 8 up, 2 down, 4 left, 6 right, corners for the diagonals, 5 = R3. They never press L2 or R2. A finger swipe is that same stick; a tap with no swipe is R3. The game remembers whether the last real input was the keyboard, a pad (numpad included) or the touchscreen.

## v0.5 button remap: the decision
- The user asked for lightning on L2, Fury on R2+L2, and R1 freed for allies. The barrier also lived on L2, so **L2 now does both, split by press length**:
  - a **tap** gives the lightning (it needs the full meter);
  - a **hold** gives the barrier.
- This works without any input delay, because both moves start with the same heal pose. L2 commits at once. If you let go before the bubble forms (heal frame 5, about 83 ms, one rendered frame per drawing), the pose drops. If you're still holding, the bubble forms.
- With less than 100 % rage a tap just drops the pose.
- **Lightning from inside the bubble (the v0.3 R1-in-bubble) is back in v0.6, on Y.** v0.5 dropped it because L2 is already held and R1 is now for allies. **Y while the bubble is up** (100 % rage) is the strike.
  - It's unambiguous: Y never did anything inside the bubble, the earthquake needs a crouch, and quick fire can't start while shielded.
  - R2 while in the bubble still gives Fury.
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

## Mana
- A **MANA** bar on the HUD, under rage. It starts at 60 / 60 and regenerates 1 per second.
- Not enough mana: the fail cue plays, the MANA bar flashes, and the move doesn't start.
- Blue potions: +30 mana. Blue-and-white potions: +5 max mana, up to 200. A gold sphere: +5 max rage, up to 200.
- Costs: quick fire 5 (the fast quick fire too), Up + Y triple bolt 15, ground dash 6, aerial dash 6, rear explosion 12, beam combo 20, bubble 3 to raise + 4 / s held.
- Free: attacks, back dodge, dodge attack, rising slash, slam, jumps, heal and lightning (rage), Fury.

## Interpretations
- "X modifies the jump into a jump attack" and "Y modifies the jump into an aerial dash": jump with Up, then press X or Y in the air.
- "A+Y dashes normally": a ground dash that reuses the aerial-dash animation and moves 1600 px/s × size. X+A was the old dash input and is now just a 1x attack.
- Up + X is not a separate move. Up jumps and X then does the jump attack. **Up + Y** (within 67 ms) is the triple bolt above, not a jump. Up alone still jumps at once, and Y in the air after that is the aerial dash.
- v0.4 dodge chain (final steering): the rising slash is the **B + Y chord**, Y again gives the slam. **B, then Y** is the fast quick fire. **B, then X** is the dodge attack. The split between the two B + Y forms is the 67 ms chord window: within it you get the rising slash, after it the dodge plays and Y gives the fast quick fire.
- Ladder, ledge and wall-jump animations only appear in the gallery, because the test level has no ladders or walls.


## Gamepads on Android (v0.8 fix)
- Godot's Android backend reports a **digital** L2/R2 (`KEYCODE_BUTTON_L2/R2`) as joypad **button 15/16** and the analog trigger as a **raw axis by device order**; the SDL mapping database then remaps known pads. Some cheap pads come out with L2 also mapped onto **Back** or **Start**, so one press fired the shield *and* opened the gallery or the controls overlay (the on-screen text the user saw on v0.4).
- From v0.8: L2/R2 = trigger axes 4/5 **or** buttons 15/16, and nothing else may use those (a test checks that no two actions share a joypad button or axis direction). Joypad **Start/Select** are acted on ~100 ms (6 physics frames) later and **dropped if a trigger moved at the same moment** (`Controls.trigger_near`, `game.gd _menu_guard_tick`). Keyboard Enter/Tab are unaffected; Start on the Game Over screen restarts at once.
