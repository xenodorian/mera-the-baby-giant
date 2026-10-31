# Mera: The Baby Giant: test-level game rules

## Size is health
- Mera starts at **2x**. Her size is her HP (HUD: six size pips).
- Each hit costs as many sizes as its damage: Fire Knight 2 (special 3), Blue Knight 1.
  The size change animates one step at a time.
- A hit that would take her below 1x (any hit while she is at 1x) kills her. **Game Over**: Start / Enter restarts.
- After a hit she gets **1.2 s of invulnerability** (she blinks).
- The L2 barrier blocks every hit while it is held.
  - The bubble is sized by `tools/fit_barrier.py`, from every opaque pixel of the held pose (heal f5-8: body, raised hand and energy ball), plus a 3 px margin. Result: centre (-3, -38) art px, radius 44.5 art px, scaled by size and mirrored by facing.
  - While it is up, Mera's hurtbox is the bubble's bounding square, so the blocking area matches what you see.
  - v0.5: the lightning can no longer be cast from inside the bubble (L2 is busy holding it). R2 inside the bubble starts Fury.
- Movement speed and hit/hurt boxes scale with size. At 1x: walk 50, run 200, ground/aerial dash 1600, and back dodge 800 px/s.
  - The dashes and the dodge play their animations at 2x speed, so every key frame is kept, and leave a pooled afterimage trail (up to 8 ghosts).

## Damage
Damage dealt = base damage × Mera's current size (1x does 1×, 3x does 3×).

| Move | Base |
|---|---|
| 1x, 2x | 1 |
| 2x-1, 2x-2, 3x | 2 |
| Beam (beam combo) | 1 per tick (every 5 frames while the beam is on) |
| Dodge attack (B, X) | 1 |
| Rising slash (B+Y) / slam (Y after it) | 1 / 2 |
| Jump attack 1 / 2 | 1 / 2 |
| Slide | 1 |
| Quick-fire bolt | 1 |
| Rear explosion (slash 1, explosion AOE 3) | 1 + 3 |
| L2-tap lightning (AOE) | 3 |
| Earthquake (Down+Y) | 0 (5 s stun) |

## Potions
- Green potions lie on the ground. Walk over one to carry it (HUD: POTIONS count). She starts with 1.
- L1 drinks one: +1 size, up to **6x**. With no potions, or already at 6x, L1 plays a fail cue and nothing is used.
- Where potions come from:
  - a defeated Fire Knight drops one 35 % of the time;
  - one appears on the ground ahead for every 2600 px of new ground explored;
  - at most 2 potions lie in the world at once.
- Free size changes (1x–19x) exist only in debug mode (F2).

## Rage and Fury
- **Lightning (L2 tap, v0.5) costs the whole meter.** It works only at 100 % rage and outside Fury. The meter then drains visibly to 0 (about 0.45 s) and refills normally afterwards.
  - Below 100 %: a fail cue plus a HUD hint, and nothing happens.
  - During Fury the meter is the Fury timer, which L2+R2 already spent, so the lightning is unavailable until Fury ends and the meter refills.
  - With a full meter, choose: L2+R2 = Fury, or tap L2 = one lightning strike.
- **Fury aura (v0.4: particles):**
  - Two CPU particle layers of pixel flame tongues (`CPUParticles2D`, world space, so emitted flames stay where they were born):
    - a back layer of 160 flames, dark red → red → orange;
    - a front additive layer of 70 thinner tongues over her outline;
  - plus 60 additive embers and the outline aura on her body.
  - **Standing:** the flames are emitted over her whole body and rise straight up, like a fire on the ground.
  - **Moving** (walking, dashing, flying): they are emitted backwards along her velocity, faster the faster she moves, so they **trail behind her**.
  - Flame size, speed and the emission area scale with her size.
  - Quality cap `aura_quality` (`--aura-quality=0..2`): 2 = 160 + 70 + 60 embers, 1 = 90 back flames + 30 embers, 0 = outline + 20 embers. The CPU particles are the deliberate choice, since GPU particles are unreliable on the Compatibility renderer.
- **Fury flight faces the flight direction:** her head leads along the 8-way input (+90° flying right, −45° up-left, 180° diving), with left/right flips. The rotation pivots on her body centre and eases in at 12/s; in the idle hover she eases back upright. The raised-arms pose plays while moving and the tucked hover while idle. The hurtbox follows the tilt.
- A defeated enemy drops a **red sphere**. It flies to Mera and adds rage based on the enemy's difficulty.
  The Fire Knight's sphere gives **+10 %**.
- Each hit Mera lands also adds **+1 %**. Spheres are the main source; the small per-hit bonus keeps "dealing damage builds Fury".
- At 100 %, L2+R2 starts **Fury** for 12 s and the meter drains to 0 over that time.
  - Red aura; all spell fx, beams, explosions and lightning turn deep red.
  - Sfx are pitched down (×0.72) through a low-pass + overdrive bus.
  - Flight: Up in the air takes off; R2 or Down at ground level lands.

## Stamina (v0.4)
- 60 / 60 at the start, regenerating 1 per second. HUD: the STAMINA bar under rage.
- Costs (all in `Tuning.STAMINA_COST`):

| Move | Stamina |
|---|---|
| Quick fire (normal or fast B, Y) | 5 |
| Ground dash / aerial dash | 6 |
| Rear explosion | 12 |
| Beam combo (X X X Y) | 20 |
| Bubble (L2) | 3 to raise + 4 per second held. It drops at 0 |
| Everything else (attacks, dodge, rising slash, slam, heal, lightning, Fury) | 0 |

- Not enough stamina: fail cue + the bar flashes, and nothing starts (in X X X Y the third hit just plays out).
- **Blue potion:** +30 stamina, up to the current max. **Blue-and-white potion:** +5 max stamina, capped at **120**. Picking one up shows a HUD note.

## Fire Knight
- Always **6x** (264 px tall). **Enemies never scale**, in size or in damage, whatever Mera's size.
- **20 HP**, shown on a health bar over his head.
- Damage to Mera (no multiplier): **2 sizes** per normal hit, **3** for the special. Touching him does no damage. A 2x Mera dies to one hit, so dodge, block or drink.
- **He uses every chierit animation:**
  - attacks: `05_1_atk` (1 swing), `06_2_atk` (3-hit string), `07_3_atk` (4-hit string), and `08_sp_atk`, the special, every 3rd attack string. The special has a longer 0.7 s white-gold tell, a charge sound and 3 damage;
  - `air_atk`: the jump attack;
  - `03_jump` (take-off) / `jump_up` / `jump_down` (fall + landing);
  - `04_roll`: the chase dash;
  - `09_defend`: the block;
  - `10_take_hit` and `11_death`.
- **Chase dash:** when Mera is more than 760 px away he rolls toward her at **3x** his run speed (576 px/s). It lasts at most 0.6 s and stops when he reaches her, then has a 3 s cooldown.
- **Block:**
  - when Mera starts a damaging attack, facing him and in reach, he raises his guard (55 % per attack, and also when one of her bolts gets close);
  - while the guard is up he is **invulnerable to everything except explosions (the rear explosion) and Fury attacks** (any damage while Fury is on);
  - he holds it while the threat lasts, but at most **1.4 s**. Then he is **forced to drop it**, with a **2.5 s** cooldown before he can block again. An explosion or Fury hit through the guard also starts the cooldown.
- **Bolt AI:** a quick-fire bolt he first sees more than **400 px** away is **jumped** (timed from the bolt's speed, so fast bolts are jumped earlier). A bolt first seen closer is blocked (Fire) or taken (Blue).
- **Air chase:** when Mera jumps or flies near him he jumps after her (1.6 s cooldown) and swings `air_atk` near the top of his jump.
- Tells: he glows orange for 0.4 s before a normal string. Committed swings (frame 3 on) don't flinch. Cooldown is 1.3 s after a string and 1.8 s after the special.
- On death he fades out, drops a red sphere (+10 % rage) and sometimes (35 %) a green potion.

## Blue Knight (v0.4)
- A blue palette swap of the Fire Knight (`shaders/knight_blue.gdshader` hue-rotates his flame colours at runtime; the original chierit art is untouched). Credit stays chierit, CC-BY 4.0.
- **3x** scale, **5 HP**, **3x faster** (576 px/s run, 1728 px/s chase dash), animations at 1.5x, a 0.3 s tell.
- Every hit does **1** size. He **can't block** and has **no special**. Everything else is the same: chase dash, bolt jumping, air chase jump attacks, and the full attack set (atk1/2/3, air).
- **Attacks from behind:** he circles to Mera's back before he swings (he gives up after 2.5 s if she keeps turning).
- **Spawning:** one comes in from off-screen behind Mera when the Fire Knight **first loses HP**, and one more when the Fire Knight **first drops below 10 HP**. So that is at most 2 per Fire Knight. Blues left more than 2880 px behind are removed.
- **Drops**, as two independent rolls: **35 %** a blue +30 stamina potion, **10 %** a blue-and-white +5 max stamina potion. Plus a red sphere for **+4 % rage** (my choice: he is easier than the Fire Knight's +10 %).

## Beam and lightning reach
- The combo beam (X X X Y, normal and Fury red) and the lightning always reach **off-screen**, at any size, from any position, in either facing, and while the camera scrolls.
- **Combo input:** the beam needs X X X Y. The Y may come at any time during the third hit (2x-1 or 2x-2) or up to 250 ms after it.
  - X X Y is always 1x → 2x → 3x. A second Y after it (X X Y Y) is swallowed, never the beam.
- Both are built from **tessellating segments** (`tools/tess_spells.py`, sheets in `assets/characters/merakintsugi/game/spell_beam*.png` and `spell_lightning_seg.png`):
  - **Beam:** a start cap (the canon cast frame, cut 24 px past the wand), then 64 px mid segments. The waves, pulse and halo are periodic over 64 px, so the seams are invisible; three variants carry the crackle, sparks and dissolve particles. The end is a front head while firing and an impact cap during the sustain, which sits off-screen.
  - **Lightning:** a ground-impact cap, then 64 px mid segments whose bolt enters and leaves each segment at the centre, then a fork cap above the top of the screen.
- The segment count is recomputed every frame from the camera: viewport edge + 160 px margin.
- The hitboxes cover the full length: the beam from the wand to its far end, the lightning from above the screen top to the ground.
- Segments come from a shared sprite pool: at most 96 per strip and 384 in total. A 1x beam across the whole screen needs about 36.
- The lightning lands on the nearest enemy within 1100 px, otherwise in front of Mera, and is kept on screen.

## Spawning
- **Only one Fire Knight at a time** (plus the Blue Knights he calls). A new one appears just off-screen ahead of Mera:
  - 2 s after the previous one is defeated, or
  - when Mera has moved too far away (he is off-screen and more than 2400 px behind). He is then removed and replaced ahead of her.
- v0.5: no more looping. See **Levels** below.
- **Camera (v0.3.1):** hard-locked horizontally on Mera's feet pivot, so she is always at the exact screen centre.
  - There is no look-ahead and no smoothing. Turning around never shifts the view, and dashes never drift.
  - It updates after all physics each frame (`scripts/game/cam_rig.gd`), so there is no one-frame lag.
  - Vertical is fixed (the level is one screen tall), apart from screen shake.
  - Beam and lightning lengths are computed against this camera every frame.

## Levels (v0.5)
- The game opens on a **level select** with four levels:

| # | Level | Art | Enemies |
|---|---|---|---|
| 1 | **Moonlit Cemetery** | ansimuz Gothicvania Cemetery | Fire Knight + Blue Knights, no ally cards |
| 2 | **Misty Woods** | ansimuz Mist Forest | wolf, werewolf, ogre, minotaur (from v0.6; (v0.6: the roster below)) |
| 3 | **Moonlit Town** | ansimuz Night Town + a procedural cobbled street | ghosts, skeletons, death, nightmare (v0.6) |
| 4 | **Infernal Caverns** | ansimuz Lava background | demons, hell hounds, hell beast, fire skulls, the boss dragon (v0.6) |

- Every map is **19,200 px wide (10 screens)** and built natively by `tools/build_levels.py`. Nothing loops as a single strip any more:
  - the playable layer is one long unique strip: ground tiles, plus graves, trees, houses, rocks and pillars placed by a seeded RNG with random spacing and flips;
  - distant layers either tile seamlessly by design, or are mirrored pairs (seamless by construction, no blur);
  - each layer has its own parallax factor.
- **Invisible walls** stop Mera and the enemies 120 px from each end. The camera stays locked on her, and the art continues past the walls.
- The **exit gate** (a pillar of light) stands near the right end. Reaching it means **LEVEL CLEAR**: A / Start goes to the next level, B to the level select. On Game Over, Start restarts and B goes back to the level select.

## Earthquake (v0.5)
- **Down + Y while crouching**, for 20 stamina.
- Mera stomps (`roll_land` pose). The ground shakes for **1 s**: a 34 px camera shake re-randomised every frame (very fast, violent, the whole map) and dust bursting out of the ground across the screen.
- Every enemy **touching the ground** at any moment of the quake is **stunned until 5 s after the quake started**. Enemies in the air when it starts are caught if they land before it ends.
- A stunned enemy wobbles in a dazed yellow tint. It can't act, block or flinch out of it, and takes damage normally.


## Telegraphs (v0.6): one standard for every enemy
Every enemy attack, the knights' included, starts with a **tell**:
- the attacker freezes on its wind-up frame;
- its sprite pulses in the attack's colour;
- a "!" of the same colour pops up over its head.

A tell never lasts less than **0.35 s**. A hit during a tell (or during a ground lunge) cancels the attack; bosses don't flinch. The colour tells you how to answer it:

| Colour | Kind | Answer |
|---|---|---|
| Orange | **melee**: a normal strike | step back, dodge (B) or hold the barrier (L2) |
| White-gold | **heavy**: a special or long-reach strike | get out of range or dodge through it |
| Red | **ranged**: fire, breath or a projectile | barrier (L2 hold) or jump it |
| Purple | **rush**: a charge, pounce or swoop with the whole body | jump over it or dodge |

The data lives in `scripts/game/roster.gd` (AttackData) and the colours in `scripts/game/telegraph.gd`.

## Enemy roster (v0.6)
- Sixteen enemies on levels 2-4, built from the ansimuz and chierit packs. **Every one of their animations is used.**
- Enemies never scale with Mera (fixed size).
- Each drops a rage sphere (the value is its "rage" %), plus a 20 % chance of a potion and a 25 % chance of a +30 stamina potion.
- Damage dealt by Mera = base × her size, as for the knights.

| Level | Enemy | HP | Hits cost | Animations and what they do |
|---|---|---|---|---|
| 2 Misty Woods | Wolf | 4 | 1 | run cycle, two skins (plain / skinned); charges across (rush) |
| | Mutant Toad | 8 | 1 | idle, jump (hops toward Mera), attack (tongue, melee) |
| | Werewolf | 10 | 1 | idle, run, jump (rising) + fall (falling) pounce (rush) |
| | Flying Eye Demon | 3 | 1 | 8-frame flight; hovers high and swoops (rush) |
| | Ogre | 18 | 2 | idle, walk, club attack (heavy). **Disarmed below half HP:** unarmed idle / walk and a shoulder shove (rush, 1) |
| | Minotaur | 26 | 2 | idle, walk, double axe swing (heavy) |
| 3 Moonlit Town | Skeleton | 6 | 1 | climbs out of the ground (rise), walk, lunge (melee); 50 % come clothed (rise-clothed / walk-clothed) |
| | Hell Gato | 6 | 1 | run cycle; leaping pounce (rush) |
| | Ghost | 5 | 1 | drifts half-transparent (no-particles), turns solid with particles to haunt-swoop (rush) |
| | Death | 9 | 1 | rises with his lamp, lamp walk, reaping glide (rush). **Loses the lamp on the first hit:** lamp-less walk, faster |
| | Nightmare | 14 | 2 | idle, then a full-screen gallop (run, rush) |
| 4 Infernal Caverns | Hell Hound | 7 | 1 | idle, walks when far, runs when near, jump pounce (rush) |
| | Fire Skull | 6 | 1 | burning flight and swoop (rush). **Doused by any hit:** the no-fire skull drifts slowly for 3 s, then re-ignites |
| | Hell Beast | 14 | 1 / 2 | idle; breath spits fireballs (ranged, 1; the fireball sprite); burn = a pillar of fire when close (heavy, 2) |
| | Demon | 22 | 2 | hovering idle; claw attack (heavy) up close, blue fire breath (ranged) at mid range |
| | **Infernal Dragon (boss)** | 160 | 3 / 2 | idle crawl, tail sweep (heavy, 3), fire breath (ranged, 2). Appears in front of the exit; **the exit is locked ("SLAY THE DRAGON") until he falls**. Boss HP bar at the bottom of the screen; he never flinches |

- Every enemy dies in the ansimuz enemy-death fire puff.

### Spawning on levels 2-4
- **Waves:** the first wave triggers at x 2200, then one every 1500 px. Wave sizes run 1, 2, 2, 3, ... and each wave cycles through the level's list, so every type shows up.
- At most 5 enemies are alive at once.
- **Spawn points:** off-screen ahead of Mera. Risers (skeleton, Death) instead climb out of the ground on screen, ahead of her.
- **Trickle:** an empty screen for 8 s brings one more.
- Enemies left 1.6 screens behind are removed.
- Level 1 keeps the Fire Knight and Blue Knights.


## Allies (v0.7)
- **Cards:** levels 2-4 each have one colour-coded ally card per ally (4 per level, at fixed spots). Touch a card to collect it; the HUD shows the cards held.
- **Summoning:** **R1** summons. One card type held → that ally comes at once. Several types → a **picker** opens and the game pauses:
  - Left/Right to choose;
  - R1 or A to summon;
  - B to cancel.
- **Rules:**
  - A summon uses one card.
  - At most 2 allies at once, one of each type.
  - Allies stay 25 s (the dancer 12 s), then leave.
  - Enemy attacks hurt allies too, and allies can be beaten.
- **Level 1** has no cards.

| Ally | Colour | What she does (every animation is used) |
|---|---|---|
| **Water Priestess** (chierit) | blue | Surfs in. **Heals Mera back up to 6x** when she is smaller (heal animation), at most once every **30 s**. Water attacks 1/2/3 (3-4 damage) and the special (6) every 4th attack; jump + air attack against flyers. Guards (defend) against wind-ups and tumbles away from rushes. Walks, surfs long distances, take-hit, death |
| **Leaf Ranger** (chierit) | green | Leaps in (jump). Shoots arrows (1st/2nd attack, chierit arrow + arrow-hit sprites) from range, kicks (3rd attack) up close, leaf beam (special) every 4th attack; jump-up/air attack/jump-down against flyers. Guard pose during an enemy wind-up, then the defend block. Rolls away from rushes and when crowded, runs, slides (slide + slide loop) to catch up, take-hit, death |
| **Brawler Girl** (ansimuz, skin recolour) | orange | Jumps in. Jab → punch → kick combo; jump → jump kick → dive kick to close in or hit flyers; jumps out of rushes; hurt (also her knock-out) |
| **Dancing Girl** (ansimuz) | pink | Skips in and dances (hips, snap, balancing, slide). **Every non-boss enemy on screen drops what it is doing, rushes to her side and jumps up and down**; flyers bob in place. Nobody attacks while she dances. **Bosses ignore her** |
