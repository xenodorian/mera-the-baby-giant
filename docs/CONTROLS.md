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
| **Down + Y** | **earthquake** (v0.5), 20 stamina. Holding Down is enough, including the same press as Y: she does not have to already be crouched. The ground shakes for 1 s (very fast, violent shake of the whole map). Every enemy touching the ground during the quake is stunned until 5 s after it started (enemies in the air are stunned if they land while it lasts). **At 100 % rage (not in Fury): SUPER EARTHQUAKE** (v0.8): impact frame, then a 2 s quake, 7 s stun, flat 2 damage to every enemy, every ground breakable on screen destroyed; spends the whole meter + 20 stamina (see GAME_RULES) |
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
| **Y while the L2 bubble is up** | drops the bubble and does Y (quick fire, or a chord). Lightning is R2, not Y |
| **L2 + R2** together (within 67 ms, either order, or R2 while the L2 bubble is up) at 100 rage or more, outside Fury | **Fury** for 12 s. Costs **100 rage** (a bigger meter keeps the rest). She cannot be hit while it lasts. The bubble drops if it was up. Below 100 rage: fail cue |
| **R2** alone | **lightning**: costs **100 rage**. One bolt per enemy on screen, in a quick row. Nobody on screen: one bolt in front of her. In Fury: take off / land |
| **R1** (v0.7) | **summon an ally** with a collected card. One card type: she comes at once. Several types: a picker (game paused; Left/Right, R1/A summon, B cancel). No usable card: fail cue + HUD note |
| **R1** | **summon an ally** (from v0.7: needs a collected ally card; with several card types a picker opens). No card: fail cue |
| Fury flight | Up in the air takes off. 8-way movement; Mera tilts head-first toward where she flies and eases upright when hovering. Raised-arms pose while moving, tucked hover while idle. Down at ground level, or R2, lands |
| Start | **pause menu** (v0.11.4): Continue, Restart level, Back to title, Controls, Quit game. Up/Down choose, A confirms, B or Start continues. On Android the on-screen PAUSE button does this (the volume keys do not). If Respawn with minigame is owned, dying opens Ambidex or Soul Maze instead of a restart |
| Back (Share) | nothing. The animation gallery is not bound to any key or button |

**Chest puzzles.** Touching a chest pauses the game on a puzzle (see `docs/GAME_RULES.md`, Puzzle chests). Start and the PAUSE button do nothing while it is open. The on-screen pad is hidden on Android so taps reach the puzzle; a **GIVE UP** button sits at the top right of every puzzle.

| Puzzle | Keyboard / pad | Touch |
|---|---|---|
| All | **B (X)** gives up; Esc gives up | tap **GIVE UP** |
| Connect the pipes | arrows move the cursor, **A (Z)** rotates the tile | tap a tile to rotate it |
| Match the foes | arrows move the cursor; **A** picks a tile, then an arrow swaps it with that neighbour (or move the cursor to a neighbour and press A again) | drag a face onto a neighbour, or tap two neighbours |
| Stop the needle | **A (Z)** stops the needle | tap anywhere |

Buttons held when the chest opens are ignored for the first 0.25 s, so an attack in progress does not act on the puzzle.

**Locked moves.** The beam finisher (X X X then Y), the earthquake (Down+Y), the super earthquake (Down+Y at full rage, after the earthquake is bought), the rear explosion (X+Y) and Fury (L2+R2) start locked. They are bought on shop page 2 (Left/Right switches the pages). A locked input does nothing special: it falls back to the normal move.

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
| **E** | left-stick click | mana potion. On Android the round **L3** button in the middle of the on-screen d-pad does the same |
| **W** | R1 | summon an ally |
| **1** (top row only) | L2 | hold = full bubble, just before a hit = parry |
| **2** (top row only) | R2 | alone = lightning (costs 100 rage). **1 + 2** = Fury. Numpad 1 and 2 are not these |
| **Numpad 5** (keyboard), **R3** (pad) or a **tap on the screen** (mobile) at 100 rage or more | R3 | **freeze slash**: costs **100 rage**. Freezes Mera and every enemy. Every enemy on screen gets a mark, 1–9 (numbers repeat past 9; one input slashes all with that number). On a keyboard the mark is that digit; on a pad or a touchscreen it is the matching arrow (5 is a dot). Top-row number, numpad direction, right-stick flick, swipe, or tap / R3 / numpad 5 slashes for a flat 15 and plays the slice. The world unfreezes the moment every number shown is entered, or after 8 s. This does not start Fury |
| Enter or F1 | Start | pause menu (continue, restart level, title, controls, quit). B / Start / Esc continues. Owned respawn opens Ambidex or Soul Maze on death |
| Tab or G | (unbound; the gallery does not open) | |
| F2 | debug: hit/hurt boxes, and enables free size keys PageUp/PageDown (or + / −, or right stick up/down), 1x–19x | |
| F11 / Esc | fullscreen / leave fullscreen, then quit | |

**Menus** (level select, ally picker, Level Clear): arrows choose, confirm and back follow the prompt style picked on the title screen (Keyboard Z / X, Xbox A / B, PlayStation × / ○, or the touch pad's A / B). The title **OPTIONS** button changes those names, and also has the CRT filter toggle. It does not remap the buttons, and Reset does not clear it. The in-game controls list shows that one style.

**Death is a minigame, once you buy it.** Respawn with minigame costs 200 gold in the title shop. Without it, a death retries the stage from the start and the save stays. With it, dying pauses the level, stops its song, and picks either the Ambidex duel or Soul Maze. The duel asks first: Fight plays the 21 second duel track and the reaper minigame, Title goes back to the title screen. Left hand: WASD, the d-pad, or the on-screen pad's arrows, catches the falling letters. Right hand: IJKL, the face buttons, or the on-screen A B X Y, taps the letter that flashes. The letters on screen follow the title prompt style (keyboard letters, touch or Xbox A B X Y, or PlayStation symbols). Survive 30 seconds and you get up where you fell. Soul Maze uses the same arrows, pad, or stick. Collect the four souls to get up. A catch, or B or Esc, sends you to the title screen. The save is never wiped by a death. On a Perry run the duel uses her sprite. M mutes the duel. Esc pauses the duel. In Soul Maze, Esc leaves and counts as a loss.
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


## Ladders (Stage 3)
Both characters climb. **Up** next to a ladder (within 40 px of its column, anywhere along it) grabs it; with no ladder near, Up still jumps. **Up / Down** climb at 240 px/s, with no gravity and no attacks; letting go of everything stays on the ladder. **Left / Right** lets go and you fall (at the top you step off onto the platform). Reaching the top steps onto the surface there; **Down** while standing at a ladder top climbs down, and reaching the floor stands you up. A hit while climbing drops you through the normal hurt flow.

## Perry (Stage 3, playable once Stage 2 is cleared)
On the title screen, the large **MERA | PERRY** toggle sits under the level cards. Down from the cards reaches it, then A, Start or a click switches the character. There is no X shortcut. The shop shows the selected character's pages (Left / Right in the shop). Perry is locked until Moonlit Sanctum (level 11, index 10) is cleared; the line under the cards says why. The choice is saved. She plays every level like Mera: same pickups, chests, allies and exit.

Perry's buttons are Mera's buttons of the same name (Xbox names; the keyboard key is in brackets: A = Z, B = X key, X = A key, Y = S, L1 = Q, R1 = W, L2 = 1, R2 = 2, L3 = E; the right stick is the numpad: 8, 2, 4, 6, and 5 for a click). Her base moves are free; everything else must be bought first, and a move she has not bought does nothing. Walk, double jump (always on), duck, block, parry and dash are free.

| Input | Move | Needs |
|---|---|---|
| Left / Right | walk (300 px/s) | |
| Up | jump (about 200 px). Up again in the air: double jump (to 400 px) | |
| Down | duck | |
| Down, then Up | sky dash | Sky Dash |
| **A** (Z) | slash | |
| A + the way she faces | lunging thrust | Lunging Thrust |
| A + the other way | turns and lunges (the thrust; the plain slash without it). The spin is Y only | Lunging Thrust |
| Down + A | ducking upswing | Ducking Upswing |
| A, A, A, A, A | attack chain: slash, three chain strikes, then the chop (20 energy) | Attack Chain |
| A, A, A, A, then B | energy burst (Burst Chain) | Attack Chain, Burst Chain |
| Hold A after a slash, release | charge, release: heavy overhead chop | Heavy Overhead Chop |
| A in the air, 180+ px up | jumping crash (30 energy): black and white impact frame, rumble, and a ground shock that hurts every enemy within 496 px of where she lands | Jumping Crash |
| **Y** (S) | spin attack (hits both sides) | |
| **X** (A key) | dash (free, invulnerable for most of it) | |
| X + A (A key + Z) | dash thrust. Double tap forward, then hold X + A and let go: energy dash thrust | Dash Thrust, Energy Dash Thrust |
| X + Y (A key + S) | taunt | Taunt |
| **B** (X key) tap | **parry**: a hit within 0.26 s does no damage and stuns the attacker for 2 s (it takes a little damage and slides back) | |
| **B** (X key) hold | **block**: no damage, a small slide | |
| Hold B + A | heavy horizontal (steps forward 50) | Heavy Horizontal |
| B x5 (taps) | meteor shower (full super: 100 rage, all of it spent) | Meteor Shower |
| Down x4, then A | earthquake (full super) | Earthquake |
| A, B, A, B, A, B | rainbow guard (5 s invulnerable). A, B, A, B, then Up: flight | Rainbow Guard, Flight |
| A x4, then all four shoulders (L1 + L2 + R1 + R2) | ultimate chain: taunt, then the four beams | Ultimate Chain |
| L1 (Q) | push kick. A + L1 = laser beam | Push Kick |
| Hold B + L1, release | energy kick | Energy Kick |
| Hold L2 (1), release | energy burst. A + L2 = cloud beam | Energy Burst |
| Hold R2 (2), release | energy wave. A + R2 = fire beam | Energy Wave |
| A + L2 / A + L1 / A + R2 | cloud beam / laser beam / fire beam (energy per tick; the cloud beam repeats while A is held) | Cloud, Laser, Fire Beam |
| A + R1 (W) | empowerment beam (empower per tick) | Empowerment Beam |
| Hold R1 (W) | kneel and heal (empower) | Recover |
| Hold L1 + R1 (Q + W) | meter charge: every meter she owns fills slowly | Meter Charge |
| Right stick flick up (numpad 8) | drink a health potion | |
| Right stick flick down (numpad 2) | drink a mana potion | |
| Right stick flick left or right, or click (numpad 4 / 6, numpad 5) | summon an ally (a picker if several cards). No usable card: fail cue | |
| L3 (E) | drink a mana potion (+30 energy and +30 empower) | |
| Start (Enter / F1) | pause. On Android the on-screen PAUSE button also pauses; the phone's volume buttons do not | |

On touch screens the right-stick flicks are swipes; an empty-screen tap does nothing for Perry.

A charged move (energy kick, burst, wave, energy dash thrust, chop) draws 20 energy per second of charge, up to 1 s; a release before 0.25 s does nothing, and a partial charge hits at 50 % to 100 % power. Chord moves (X + A, A + shoulder, X + Y, hold B + A) use Mera's 67 ms chord window and convert the first move retroactively, so every button still acts on the frame it is pressed. Perry has no Fury, lightning, bubbles or freeze slash (L2 / R2 alone are her energy burst / wave, or nothing).

**Why this layout.** Perry Riposte had no potions or summons, so every button was an attack. Mera's L1 (potion) and R1 (summon) landed on Perry's push kick, recover and empower beam, and Y had lost its original job (the spin). Items therefore moved to the right stick, which Perry never uses, and Y got the spin back. R1 tap no longer summons and L1 no longer drinks.
