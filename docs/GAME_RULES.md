# Mera: The Baby Giant: test-level game rules

## Size is health
- A green potion (L1) plays the heal at **4×** speed: +1 size on frame 7, about **0.1 s** after the press, and she is free again in about **0.25 s**. Inside either bubble the drink is instant and the bubble stays up.
- Each hit costs as many sizes as its damage: Fire Knight 1 (special 2; was 2/3 before v0.8), Blue Knight 1.
  The size change animates one step at a time.
- A hit that would take her below 1x (any hit while she is at 1x) kills her. **Game Over**: Start / Enter restarts.
- After a hit she gets **1.2 s of invulnerability** (she blinks).
- The L2 barrier blocks every hit while it is held.
  - The bubble is sized by `tools/fit_barrier.py`, from every opaque pixel of the held pose (heal f5-8: body, raised hand and energy ball), plus a 3 px margin. Result: centre (-3, -38) art px, radius 44.5 art px, scaled by size and mirrored by facing.
  - While it is up, Mera's hurtbox is the bubble's bounding square, so the blocking area matches what you see.
  - R2 while the bubble is up drops lightning (100 rage, spends the bar) and the bubble stays. L2 alone never taps into lightning.
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
| **Super earthquake** (Down+Y at 100 % rage, v0.8) | flat 2 to every enemy (7 s stun) |
| **Marked slash** (L1+R1+L2+R2, costs 100 rage) | flat 3 to each marked enemy |

## Potions
- Green potions lie on the ground. Walk over one to carry it (HUD: POTIONS count). She starts with 1.
- L1 drinks one: +1 size, up to **6x**. With no potions, or already at 6x, L1 plays a fail cue and nothing is used.
- Where potions come from:
  - a defeated Fire Knight drops one 35 % of the time;
  - one appears on the ground ahead for every 2600 px of new ground explored;
  - at most 2 potions lie in the world at once.
- Free size changes (1x–19x) exist only in debug mode (F2).

## Rage and Fury
- **Three rage attacks, each costs 100.** A meter raised past 100 keeps the rest.
  - **R2 alone: Fury** for 12 s. The red bar during Fury is the timer, not the leftover rage.
  - **L2+R2: lightning.** Needs 100 rage and you must not already be in Fury. Costs 100, not the whole bar.
  - **L1+R1+L2+R2: freeze slash.** Needs 100 rage (even during Fury). Costs 100. It does not start Fury. Up to 9 nearest enemies are marked; cut each for a flat 3.
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
- At **100 rage or more**, R2 alone starts **Fury** for 12 s and spends **100 rage**.
  - Red aura; all spell fx, beams, explosions and lightning turn deep red.
  - Sfx are pitched down (×0.72) through a low-pass + overdrive bus.
  - Flight: Up in the air takes off; R2 or Down at ground level lands.
- **Freeze slash:** L1+R1+L2+R2 together (keyboard Q+W+1+2, within 150 ms, all held) at **100 rage or more**. It costs **100 rage** and does **not** start Fury. Mera and the whole world stop for up to 8 s. Up to 9 nearest living enemies each get one unique mark from 1 to 9. A keyboard shows the digit; a gamepad or the touchscreen shows the arrow (numpad layout, 5 is a dot). The matching top-row number, numpad key, right-stick flick, swipe, or a tap / R3 cuts that enemy for a **flat 3** (not × size), with the knife-slice sound and a slash drawn on them. It ends when every mark is cut or the 8 s run out. Top-row 1 and 2 are still L2 and R2 outside the freeze; the numpad is only the right stick.

## Mana (v0.4, renamed v0.9.4)
- 60 / 60 at the start, regenerating 1 per second. HUD: the MANA bar under rage.
- Costs (all in `Tuning.STAMINA_COST`):

| Move | Mana |
|---|---|
| Quick fire (normal or fast B, Y) | 5 |
| Ground dash / aerial dash | 6 |
| Rear explosion | 12 |
| Beam combo (X X X Y) | 20 |
| Bubble (L2) | 3 to raise + 4 per second held. It drops at 0 |
| Everything else (attacks, dodge, rising slash, slam, heal, lightning, Fury) | 0 |

- Not enough mana: fail cue + the bar flashes, and nothing starts (in X X X Y the third hit just plays out).
- **Blue potion:** +30 mana, up to the current max. **Blue-and-white potion:** +5 max mana, capped at **200**. Picking one up shows a HUD note.

## Fire Knight
- Always **6x** (264 px tall). **Enemies never scale**, in size or in damage, whatever Mera's size.
- **20 HP**, shown on a health bar over his head.
- Damage to Mera (no multiplier): **1 size** per normal hit, **2** for the special (v0.8 balance; was 2 and 3). Touching him does no damage. A 2x Mera dies to his special or to two normal hits, so dodge, block or drink.
- **He uses every chierit animation:**
  - attacks: `05_1_atk` (1 swing), `06_2_atk` (3-hit string), `07_3_atk` (4-hit string), and `08_sp_atk`, the special, every 3rd attack string. The special has a longer 0.7 s white-gold tell, a charge sound and 2 damage;
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
- **The cemetery ends (v0.9.5).** After **5** Fire Knights, no more spawn. The exit stays shut ("SLAY THE KNIGHT") until that last knight and his Blue Knights are dead. Then the gate opens.
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
- The **exit gate** (a pillar of light) stands near the right end of every level. It stays shut until that level's fight is over, then reaching it means **LEVEL CLEAR**. A / Start goes to the next level (on the last level, back to the level select). B always goes to the level select. **Potions, ally cards, size, mana, rage, max mana and max rage come with you.** Dying retries that level with what you had when you entered it. Going back to the level select starts a fresh run.
  - **Moonlit Cemetery:** shut until 5 Fire Knights (and the Blue Knights still with the last one) are dead.
  - **Misty Woods and Moonlit Town:** shut until every scheduled wave has spawned and no roster enemy is left alive ("CLEAR THE ROAD"). Standing still no longer calls in enemies forever.
  - **Infernal Caverns:** shut until the dragon falls ("SLAY THE DRAGON").

## Earthquake (v0.5)
- **Down + Y while crouching**, for 20 stamina.
- Mera stomps (`roll_land` pose). The ground shakes for **1 s**: a 34 px camera shake re-randomised every frame (very fast, violent, the whole map) and dust bursting out of the ground across the screen.
- Every enemy **touching the ground** at any moment of the quake is **stunned until 5 s after the quake started**. Enemies in the air when it starts are caught if they land before it ends.
- A stunned enemy wobbles in a dazed yellow tint. It can't act, block or flinch out of it, and takes damage normally.

## Super earthquake (v0.8)
- The same input (**Down + Y while crouching**, keyboard **Down + S**) with the **rage meter at 100 %** and **not in Fury**.
- **Cost:** the usual **20 stamina** plus **the whole rage meter** (it drains to 0 like a lightning spend). Without 20 stamina nothing happens, as for the normal quake.
- **Impact frame:** the game freezes for **0.16 s** (`IMPACT_FRAME_S`) while the screen turns into a hard black/white silhouette: inverted first (white screen, black shapes), plain black/white for the last 40 %. It is a `HitStop.impact()` freeze (not capped at 120 ms) plus `shaders/impact_frame.gdshader` on a full-screen layer. It is skipped if hit-stop is off, but the overlay still shows.
- **Then a 2 s quake** (`SUPER_QUAKE_S`) with a **70 px** shake (twice the normal) and twice the dust:
  - every enemy touching the ground during it is **stunned until 7 s after the quake started** (`SUPER_QUAKE_STUN_S`; flyers are not, as with the normal quake);
  - **every enemy** on the map takes **a flat 2 damage** (`SUPER_QUAKE_DMG`, never multiplied by Mera's size). It pierces the Fire Knight's guard. For the Infernal Dragon it is 2 toward its size pool;
  - **every destructible ground object within 1920 px of the screen centre** is destroyed: candles, urns, crates, chests, cracked walls, and barrels, which explode and chain. Chandeliers on screen fall. Levers, planks and doors aren't destructible and stay.
- **Fury:** during Fury the meter is the Fury timer, so it is never "full rage" and Down+Y is the **normal** quake; Fury keeps going. While the meter is still draining after a spend, it's the normal quake too.
- Below 100 % rage nothing changes: the normal 1 s quake, rage kept.


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
- Each defeated enemy drops **one** thing (v0.9.4): a rage sphere (30%), a green size potion (28%), a blue +30 mana potion (28%), a +5 max mana potion (7%, cap 200), or a +5 max rage sphere (7%, cap 200). A rage sphere still grants that enemy's rage value.
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
| | **Infernal Dragon (boss)** | 19 sizes × 8 (v0.8, see below) | 3 / 2 | idle crawl, tail sweep (heavy, 3), fire breath (ranged, 2). Appears in front of the exit; **the exit is locked ("SLAY THE DRAGON") until he falls**. Boss HP bar at the bottom of the screen; he never flinches |

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
  - Allies stay **20 s**, then leave. The dancer dances for **5 s** of that.
  - Enemy attacks hurt allies too, and allies can be beaten.
- **Level 1** has no cards.

| Ally | Colour | What she does (every animation is used) |
|---|---|---|
| **Water Priestess** (chierit) | blue | Surfs in and **heals Mera back up to 6x** as soon as she arrives, then once more just before she leaves. Water attacks 1/2/3 (3-4 damage) and the special (6) every 4th attack; jump + air attack against flyers. Guards (defend) against wind-ups and tumbles away from rushes. Walks, surfs long distances, take-hit, death |
| **Leaf Ranger** (chierit) | green | Leaps in (jump). Shoots arrows (1st/2nd attack, chierit arrow + arrow-hit sprites) from range, kicks (3rd attack) up close, leaf beam (special) every 4th attack; jump-up/air attack/jump-down against flyers. Guard pose during an enemy wind-up, then the defend block. Rolls away from rushes and when crowded, runs, slides (slide + slide loop) to catch up, take-hit, death |
| **Brawler Girl** (ansimuz, skin recolour) | orange | Lands in front of Mera and **runs right** until her time is up. She stops only to fight something in reach, or when a wall or a closed door is in the way. Enemies do **not** chase her; they stay on Mera |
| **Dancing Girl** (ansimuz; v0.8 natural-skin recolour, `tools/recolor_dancer_skin.py`) | pink | Walks out **in front of Mera**, stops, and dances for **5 s** (hips, snap, balancing, slide). **Every enemy on screen, bosses included, drops what it is doing, rushes to her side and jumps up and down**; flyers bob in place. Nobody attacks while she dances. After the 5 s she stops, and she leaves with the others at 20 s |

## Impact (v0.8)
- **Hit-stop:** a landed hit freezes the whole game for a moment (real time): **45 ms** normal, **80 ms** heavy (2+ base damage, launchers, explosions, lightning, counter hits), **100 ms** a kill, **120 ms** a parry; never more than 120 ms (overlaps extend, never stack). Beam ticks only stop on a kill. `scripts/game/hit_stop.gd` (autoload `HitStop`) drops `Engine.time_scale` and restores it per physics tick; Mera's input clock keeps real time through it, so combo windows don't change.
- **Flash + sparks** on every hit (props too), **SFX variance**: impact sounds pick a random take and a random pitch within ±8 %.
- Damage to Mera's targets is unchanged.

## Breakables, barrels, chandeliers (v0.8)
Levels 2-4 only (level 1 is untouched). Free CC0 art, see `docs/CREDITS.md`.

| Prop | Hits | Drops |
|---|---|---|
| Candle (2 looks) | 1 | small: 70 % chance of one item (rarely a size potion; small stamina +12, small sphere +4 %) |
| Urn | 1 | medium: 90 %, one item |
| Crate | 2 | medium |
| Chest | 3 | big: always two different items, 15 % a +5 max-stamina potion |
| Explosive barrel | 1 | none: explodes |
| Chandelier (Moonlit Town, Infernal Caverns) | 1 | none: falls |

- **Any projectile breaks what it hits** (v0.9.6): Mera's bolts and fireballs, the ranger's arrows, enemy shots, and the dragon's bolts. A candle, urn or barrel goes in one hit. A crate, chest or wall loses one hit, the same as a swing. A dragon bolt's blast breaks everything in the burst.
- **Explosive barrel:** **8 damage** (fixed, never × size) and a launch to every enemy within **300 px**; it pierces the Fire Knight's block (kind "explosion"); other barrels in the blast go off 0.14 s later (chains); chandeliers in range (1.8 × radius) drop; breakables in range break. Mera is not hurt.
- **Chandelier:** hit it, blast it, or **earthquake** (Down+Y shakes loose every chandelier on screen). It falls and crushes enemies under it: **6 damage + 2.5 s stun**.
- Destroyed props **shatter** into textured shards (`scripts/game/debris.gd`, pure GDScript, one draw call); crates also throw their 4 plank pieces.

## Juggles and corpses (v0.8)
- **Launchers:** `atk3` (3x), `atk2_1` (2x-1) and `datk2` throw ground enemies up; `datk3` is a slam (small hop on the ground, spikes an airborne enemy down); explosions (barrels, the rear blast) launch hardest. Heavier enemies fly less (mass from body height). Flyers and bosses are never launched (`Mera.LAUNCH_KINDS`, `monster.gd _juggle_hit`).
- **Air hits** pop them up again, less each time; gravity grows **×(1 + 0.3 per air hit)**; after 8 air hits they just fall.
- **Ground bounce:** landing fast bounces once (42 %), one more chance to juggle. **Wall bounce:** flung into a map wall they bounce back (60 %) and take **1 damage**.
- **Corpse launch:** a defeated enemy is flung away from the killing blow (harder for explosions and launchers), spinning, and **bursts into shards + gibs and blood** where it lands (at most 1.4 s). Gore is CC0 (Reactorcore); flame and ghost enemies burst into glowing mist instead of blood.

## Parry (v0.8)
- **Press L2 at most 150 ms before a hit lands** = parry: no damage, 0.25 s i-frames, the attacker is **staggered 2 s** (bosses are not) and **slid back 400 px** (v0.9.3; bosses stay put), and Mera gets a **0.9 s counter window: her hits do ×2** (she glows gold). A 120 ms hit-stop and a clang sell it.
- **Crouch bubble (v0.9.4):** holding Down raises a small bubble for free (radius 32 art px). A dial around it empties over **3 seconds**, then the bubble drops even if she stays crouched. Crouching again starts a new one. Starting the crouch within 150 ms **parries** (200 px, 1 s stun). After that window the bubble **subtracts 1** from the hit and does not knock her down, so a hit of 1 is stopped and a hit of 3 costs 2 size. Any button except L1 drops it and does that move. **L1 drinks a potion and the bubble stays.**
- **Full bubble (L2 hold):** stops **all** damage. Any button except L1 and the L2 hold itself drops it immediately and does that move. **L1 drinks a potion and the bubble stays.** Holding it, with no parry window, still slides the attacker 200 px with no stun.
- **Projectiles** (the hell beast's fireball, and a dragon bolt) parried with L2 in the window fly back 1.6× faster and hit the first enemy for 3. A dragon bolt popped by L2 still bursts harmlessly.
- **Swing parry (v0.9.1):** X (`atk1` or the air `jatk1`) reflects a projectile when the hitbox meets it within **150 ms of the hitbox going live**. It flies at its shooter, or the nearest living enemy, and damages them. No counter window.
- A player shot that touches an enemy shot: **both explode** (the blast does not also hurt Mera). The combo beam and the vertical beam **destroy** enemy projectiles.
- A later L2 is just the barrier as before (blocks while held, costs stamina).

## Secrets (v0.8)
Each of levels 2-4 hides **3 of its 4 ally cards**:
- **Cracked wall:** the card is behind it; **4 hits** (or one explosion) break it.
- **Lever + door:** hit the lever (620 px before the door) and the door slides up.
- **Ledge:** the card floats on a ledge **300 px** up, reached from a **crumbling plank** 150 px up (double jump at 1x). The plank shakes 0.45 s after Mera stands on it, breaks 0.3 s later, and grows back after 6 s. A big Mera or flight also reaches the ledge.
- A found secret shows "secret found!".

## Allies scale with Mera (v0.8)
- Allies are drawn at **1.1 × Mera's current height** (never bigger than their full 4x art, never below 35 % of it) and follow her size changes smoothly.


## Infernal Dragon (v0.8 rework)
`scripts/game/dragon.gd` (extends `monster.gd`), bolts `scripts/game/dragon_bolt.gd`, numbers `tuning.gd` `DRAGON_*`.
- **Size is health, like Mera's.** He starts at **19x** (drawn at k = 19) and loses **one size per 8 damage** (`DRAGON_HP_PER_SIZE`; a 2x Mera combo takes about one size), down to **1x**. A hit can never take him below 1x; **any hit at 1x kills him**. The size change is tweened; his feet stay on the ground line and his hit boxes scale with him.
- **His damage never scales with his size** (tail 3, breath 2, bolts 2).
- **Phases at 12x, 9x, 6x, 3x**, each **exactly once**, when his size first drops to or past it. **Choice for big hits:** a hit that skips several thresholds **queues every owed phase**, and they run back to back, each once (not just the highest).
- **A phase (v0.8.1):** he takes off (0.9 s up to 380 px) on the **fly** wing loop: the 4 frames the user picked (ansimuz breath 1, 5, 4, 5, plume-free copies, no fire at all) looped at 11 fps, with a 26 px bob at 1.6 Hz.
  - Then, **5 times:** he **flies to a new lob spot** (0.8 s eased glide) and lobs one bolt.
    - The spots are short (~300 px), mid (~560–700 px) and long (~1000 px) from Mera, in front of her and behind (he crosses over her), at 250–470 px high, shuffled every phase.
    - Spots stay inside the walls and within reach of the screen centre (960 px minus 20 % of his width (v0.8.2), so at least about 2/3 of his body stays visible). A spot that doesn't fit on one side is mirrored to the other, and he never lobs twice from the same place.
  - **Each lob:** a **red (ranged) tell**: he pulses red with the "!" for 0.5 s on the plume-free **spit** frames (no breath plume; a small muzzle spark at launch).
    - **v0.8.2:** he turns to face Mera and the bolt **leaves his mouth horizontally**. It spawns at the mouth (measured on the spit frame: native (−33.5, −12) px from his feet, × his size, mirrored with his facing), with no upward leap. Gravity alone curves it down onto the target: flight time = √(2·drop / 1900), vx = dx / time, so it lands exactly where aimed (the first bolt at Mera, the rest within ±140 px). The blunt round head of the fireball leads along the velocity and the flame trails behind for the whole flight.
    - So that the shot is never backwards or straight down, the target is always at least 160 px in front of his mouth. His lob spots also stay at least mouth reach + 160 px from Mera; when he is big (12x), they spread over the room left between that and the screen edge.
    - A red ring on the ground shows where it lands. It explodes on touching Mera or the ground (**170 px** blast, **2 damage**, fixed). Then he **lands, always** (0.8 s, wherever he is), and goes back to the ground fight.
- **If any bolt hurts Mera during a phase, he grows +3 sizes** (once per phase, not per bolt; capped at 19x). Growing back never re-arms a threshold he has already used.
- The barrier blocks bolts; a parry (L2 in the window) pops one harmlessly. The earthquake can't stun him while he flies. The Dancing Girl pulls him over to hop with everyone else.
- His **ground fire breath** attack is unchanged: it still plays the original breath frames with the plume (a separate code path, the roster attack).
- **Boss bar:** "INFERNAL DRAGON 12x" plus a bar with one notch per size.
