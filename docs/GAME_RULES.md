# Mera: The Baby Giant: test-level game rules

## Size is health
- A green potion (L1) plays the heal at one rendered frame per drawing: +1 size on frame 7, about **0.12 s** after the press, and she is free again in about **0.3 s**. Inside either bubble the drink is instant and the bubble stays up.
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
| Beam (beam combo, shop page 2) | 1 per tick (every 5 frames while the beam is on) |
| Dodge attack (B, X) | 1 |
| Rising slash (B+Y) / slam (Y after it) | 1 / 2 |
| Jump attack 1 / 2 | 1 / 2 |
| Slide | 1 |
| Quick-fire bolt | 1 |
| Rear explosion (slash 1, explosion AOE 3; shop page 2) | 1 + 3 |
| L2-tap lightning (AOE) | 3 |
| Earthquake (Down+Y, shop page 2) | 0 (5 s stun) |
| **Super earthquake** (Down+Y at 100 % rage, v0.8, shop page 2) | flat 2 to every enemy (7 s stun) |
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
  - **R2 alone: lightning.** One bolt per enemy on screen, left to right, 0.08 s apart. Costs 100 rage. With nobody on screen, one bolt lands in front of her.
  - **L2+R2: Fury** (bought in the shop, page 2) for 12 s. The red bar during Fury is the timer, not the leftover rage. She cannot be hit while it lasts.
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
- A defeated enemy drops a **fury orb** (the red sphere). It flies to Mera and adds rage based on the enemy's difficulty.
  The Fire Knight's sphere gives **+10 %**.
- Each hit Mera lands also adds **+1 %**. Spheres are the main source; the small per-hit bonus keeps "dealing damage builds Fury".
- At **100 rage or more**, **L2+R2** starts **Fury** for 12 s and spends **100 rage**. She cannot be hit until it ends.
  - Red aura; all spell fx, beams, explosions and lightning turn deep red.
  - Sfx are pitched down (×0.72) through a low-pass + overdrive bus.
  - Flight: Up in the air takes off; R2 or Down at ground level lands. **R2 alone is lightning**, not Fury.
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
- **Spawning:** one comes in from off-screen behind Mera when the Fire Knight **first loses HP**, and one more when the Fire Knight **first drops below 10 HP**. So that is at most 2 per Fire Knight. Blues are never removed for distance; they stay until beaten.
- **Drops**, as two independent rolls: **35 %** a blue +30 stamina potion, **10 %** a blue-and-white +5 max stamina potion. Plus a red sphere for **+4 % rage** (my choice: he is easier than the Fire Knight's +10 %).

## Beam and lightning reach
- The combo beam is locked until bought in the shop (page 2). Lightning is always available.
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
- **Three Fire Knights stand at 25 %, 50 % and 75 % of the Moonlit Cemetery map** (plus the Blue Knights they call). A death refills that same point about 2 s later, until five have spawned in total.
- **Nothing despawns for distance:** enemies, Blue Knights and Fire Knights stay until beaten.
- **The cemetery ends (v0.9.5).** After **5** Fire Knights, no more spawn. The exit stays shut ("SLAY THE KNIGHT") until that last knight and his Blue Knights are dead. Then the gate opens.
- **Camera (v0.3.1):** hard-locked horizontally on Mera's feet pivot, so she is always at the exact screen centre.
  - There is no look-ahead and no smoothing. Turning around never shifts the view, and dashes never drift.
  - It updates after all physics each frame (`scripts/game/cam_rig.gd`), so there is no one-frame lag.
  - Vertical is fixed (the level is one screen tall), apart from screen shake.
  - Beam and lightning lengths are computed against this camera every frame.

## Levels
- The level select, and a clear, go in this order:

| # | Level | Art | Enemies |
|---|---|---|---|
| 1 | **Sunlit Country** | ansimuz day platform | wolf, goblin, mushroom, mutant toad, flying eye, werewolf |
| 2 | **Misty Woods** | ansimuz Mist Forest | wolf, werewolf, ogre, minotaur, mutant toad, flying eye |
| 3 | **Moonlit Town** | ansimuz Night Town | ghosts, skeletons, death, nightmare, hell gato |
| 4 | **Moonlit Cemetery** | ansimuz Gothicvania Cemetery | Fire Knight + Blue Knights |
| 5 | **Infernal Caverns** | ansimuz Lava background | demons, hell hounds, hell beast, fire skulls |
| 6 | **Dragon's Lair** | the same lava cavern, a short arena | the boss dragon, alone |

- The first five maps are **19,200 px wide (10 screens)**. **Dragon's Lair is 7,200 px**, the same cavern art cut short so the fight starts immediately. Built natively by `tools/build_levels.py`. Nothing loops as a single strip any more:
  - the playable layer is one long unique strip: ground tiles, plus graves, trees, houses, rocks and pillars placed by a seeded RNG with random spacing and flips;
  - distant layers either tile seamlessly by design, or are mirrored pairs (seamless by construction, no blur);
  - each layer has its own parallax factor.
- **Invisible walls** stop Mera and the enemies 120 px from each end. The camera stays locked on her, and the art continues past the walls.
- **Stage 2: The Island** (levels 7 to 11, indices 6 to 10, opens when the dragon falls): Mossy Falls, Sunstone Canyon, Sunset Shore, Mire Wood and Moonlit Sanctum. They are 19,200 px wave levels (stage 1 enemies mixed with the Perry Riposte creatures `p_*`), two monsters per level come from behind, and they hold four ally-card secrets each (the Sanctum also has chandeliers). Levels 7, 9, 10 and 11 end with a boss who waits near the exit (Club Ogre, Mirror Max, Percy, and Perry); level 8 has none. The exit is locked ("CLEAR THE ROAD", then "SLAY THE <BOSS>") until the waves are done, no other enemy is alive and the boss is dead. Only the dragon and Perry end a stage with a victory card (`Roster.FINALE`); the other bosses just open the exit.
- **Stage 3: Changeling** (levels 13 to 20, indices 12 to 19, opens when Perry falls): the eight maps of the Changeling game (`GameOfGameBecauseGame`), flattened by `tools/build_stage3.py` into one screen height. Greenwood Road, Bramble Hollow, Old Watchtower and Rotting Marsh are field maps; Castle Gate, Undercroft, Hall of Faces and Warlord's Throne are dungeon maps. Each map column is 135 px wide (every map is at least 9,600 px; the 40 column Warlord's Throne is a 7,200 px arena, 180 px a column). The floor is the usual ground. Ledges are one-way surfaces in tiers 130 px apart (a ledge `h` map rows above the floor goes to tier ceil(h / 3), at most 6), so each step is a jump; a ledge with no lower step near it has a ladder up to it. Walls are scenery; pits and spikes are floor with a hazard strip (art only). Each map has four ally-card secrets with the Changeling faces (knight, ranger, weaver, mage). Perry's Arena (level 12) and the Warlord's Throne are bare boss arenas with no props or cards. Indices 11 (Perry's Arena) and 19 (the Warlord) are finale bosses.
- The **exit gate** (a pillar of light) stands near the right end of every level. It stays shut until that level's fight is over, then reaching it means **LEVEL CLEAR**. A / Start goes to the next level (after the last level, the Warlord's Throne, back to the title screen). B always goes to the level select. **The run is never wiped.** Potions, ally cards, mana, rage, max mana and max rage stay across levels, deaths, the level select, and quitting the game. Size stays when you clear a level. **A death puts her back at 2x.**
  - **Moonlit Cemetery:** shut until 5 Fire Knights (and the Blue Knights still with the last one) are dead.
  - **Misty Woods and Moonlit Town:** shut until every scheduled wave has spawned and no roster enemy is left alive ("CLEAR THE ROAD"). Standing still no longer calls in enemies forever.
  - **Infernal Caverns:** shut until the waves are dead ("CLEAR THE ROAD"). The dragon is not on this map.
  - **Dragon's Lair:** a short arena. The dragon is waiting in front of the gate ("SLAY THE DRAGON"). No other enemies.
- **Stage 1 is open.** Every later stage, including ones added after this, starts locked. It opens when the stage before it is cleared, or when a **200 gold stage key** is bought in the title shop. The key opens the next locked stage. Reset locks them again.

## Earthquake (v0.5)
- Locked until bought in the shop (page 2).
- **Down + Y** (keyboard **Down + S**), including pressing them together, for 20 stamina. She does not have to already be in the crouch pose.
- Mera stomps (`roll_land` pose). The ground shakes for **1 s**: a 34 px camera shake re-randomised every frame (very fast, violent, the whole map) and dust bursting out of the ground across the screen.
- Every enemy **touching the ground** at any moment of the quake is **stunned until 5 s after the quake started**. Enemies in the air when it starts are caught if they land before it ends.
- A stunned enemy wobbles in a dazed yellow tint. It can't act, block or flinch out of it, and takes damage normally.

## Super earthquake (v0.8)
- Locked until bought in the shop (page 2). It needs the earthquake bought first.
- The same input (**Down + Y while crouching**, keyboard **Down + S**) with the **rage meter at 100 %** and **not in Fury**.
- **Cost:** the usual **20 stamina** plus **the whole rage meter** (it drains to 0 like a lightning spend). Without 20 stamina nothing happens, as for the normal quake.
- **Impact frame:** the game freezes for **0.16 s** (`IMPACT_FRAME_S`) while the screen turns into a hard black/white silhouette: inverted first (white screen, black shapes), plain black/white for the last 40 %. It is a `HitStop.impact()` freeze (not capped at 120 ms) plus `shaders/impact_frame.gdshader` on a full-screen layer. It is skipped if hit-stop is off, but the overlay still shows.
- **Then a 2 s quake** (`SUPER_QUAKE_S`) with a **70 px** shake (twice the normal) and twice the dust:
  - every enemy touching the ground during it is **stunned until 7 s after the quake started** (`SUPER_QUAKE_STUN_S`; flyers are not, as with the normal quake);
  - **every enemy** on the map takes **a flat 2 damage** (`SUPER_QUAKE_DMG`, never multiplied by Mera's size). It pierces the Fire Knight's guard. For the Infernal Dragon it is 2 toward its size pool;
  - **every destructible ground object within 1920 px of the screen centre** is destroyed: candles, urns, crates, cracked walls, and barrels (chests are not destroyed), which explode and chain. Chandeliers on screen fall. Levers, planks and doors aren't destructible and stay.
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
- Sixteen enemies on the four wave levels (Sunlit Country, Misty Woods, Moonlit Town, Infernal Caverns), built from the ansimuz and chierit packs. **Every one of their animations is used.**
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
| 5 Infernal Caverns | Hell Hound | 7 | 1 | idle, walks when far, runs when near, jump pounce (rush) |
| | Fire Skull | 6 | 1 | burning flight and swoop (rush). **Doused by any hit:** the no-fire skull drifts slowly for 3 s, then re-ignites |
| | Hell Beast | 14 | 1 / 2 | idle; breath spits fireballs (ranged, 1; the fireball sprite); burn = a pillar of fire when close (heavy, 2) |
| | Demon | 22 | 2 | hovering idle; claw attack (heavy) up close, blue fire breath (ranged) at mid range |
| 6 Dragon's Lair | **Infernal Dragon (boss)** | 19 sizes × 8 (v0.8, see below) | 3 / 2 | idle crawl, tail sweep (heavy, 3), fire breath (ranged, 2). His own stage: he stands in front of the exit; **the exit is locked ("SLAY THE DRAGON") until he falls**. Boss HP bar at the bottom of the screen; he never flinches |

- Every enemy dies in the ansimuz enemy-death fire puff.

### Spawning on the wave levels (1, 2, 3 and 5)
- **Waves:** the first wave triggers at x 2200, then one every 1500 px. Wave sizes run 1, 2, 2, 3, ... and each wave cycles through the level's list, so every type shows up.
- No cap of five alive: the spawner places every wave of the stage (the cap is the stage's whole wave total).
- **Spawn points:** off-screen ahead of Mera. Risers (skeleton, Death) instead climb out of the ground on screen, ahead of her.
- **Trickle:** an empty screen for 8 s brings one more.
- Enemies are never removed for distance; they stay until beaten.
- The Moonlit Cemetery (level 4) keeps the Fire Knights and Blue Knights, and the Dragon's Lair has the dragon alone.


## Allies (v0.7)
- **Cards:** no cards lie on the maps. They come from broken objects (see the drop roll under Breakables), from chests, and from the cracked walls (see Secrets). Touch a card to collect it; the HUD shows the cards held.
- **Summoning:** **R1** summons. One card type held → that ally comes at once. Several types → a **picker** opens and the game pauses:
  - Left/Right to choose;
  - R1 or A to summon;
  - B to cancel.
- **Rules:**
  - A summon uses one card.
  - At most 2 allies at once, one of each type.
  - Allies stay **30 s** by default, then leave. The shop sells longer times: 60 s, 90 s and 120 s, bought in that order. The dancer still dances **5 s** of that time.
  - Enemy attacks hurt allies too, and allies can be beaten.

| Ally | Colour | What she does (every animation is used) |
|---|---|---|
| **Water Priestess** (chierit) | blue | Surfs in and **heals Mera back up to 6x** as soon as she arrives, then once more just before she leaves. Water attacks 1/2/3 (3-4 damage) and the special (6) every 4th attack; jump + air attack against flyers. Guards (defend) against wind-ups and tumbles away from rushes. Walks, surfs long distances, take-hit, death |
| **Leaf Ranger** (chierit) | green | Leaps in (jump). Shoots arrows (1st/2nd attack, chierit arrow + arrow-hit sprites) from range, kicks (3rd attack) up close, leaf beam (special) every 4th attack; jump-up/air attack/jump-down against flyers. Guard pose during an enemy wind-up, then the defend block. Rolls away from rushes and when crowded, runs, slides (slide + slide loop) to catch up, take-hit, death |
| **Brawler Girl** (ansimuz, skin recolour) | orange | Chases the nearest enemy at a run (the walk cycle sped up; the pack has no run). With nobody to fight she goes to the right side of the screen and waits between 200 and 400 px from the edge. She does not walk off it. Enemies stay on Mera |
| **Dancing Girl** (ansimuz; v0.8 natural-skin recolour, `tools/recolor_dancer_skin.py`) | pink | Walks out **in front of Mera**, stops, and dances for **5 s** (hips, snap, balancing, slide). **Every enemy on screen, bosses included, drops what it is doing, rushes to her side and jumps up and down**; flyers bob in place. Nobody attacks while she dances. After the 5 s she stops, and she leaves with the others when the ally's time runs out. If she is about to leave the view she runs back to Mera and dances again |

### Ally summons: the playable faces (Stage 3)
Five more allies, one for every playable character that was not one yet. Cards work like the others (R1 summons, the 30/60/90/120 s tiers, two allies out at most, one of each type, a picker when several types are held). Numbers are in `allies.gd` and `ally_faces.gd`.
- **Knight** (22 hp): melee tank, slash 4 and thrust 5. Non-boss enemies near him pick him as their target instead of Mera.
- **Mage** (8 hp): stays 260 to 1000 px away and casts a bolt (4) that hurts the first enemy it meets.
- **Weaver** (10 hp): spinning bone shot (3) from 220 to 900 px, a slash (2) when cornered.
- **Perry** (16 hp): fast melee: slash 3, thrust 3, spin 4, and every 4th attack an energy wave (5) that passes through enemies. Her hit frames are her real ones.
- **Changeling Ranger** (10 hp): arrows (3). A flyer within 1500 px is her target before any ground enemy. If it hangs more than 240 px above her feet she builds a stair (at most 3 planks and 2 ladders, each plank at most `Tuning.PLATFORM_STEP_H` above the last, a ladder for any taller rise, 25 s) and climbs it before shooting. Mera and Perry can use the stair too. The planner is `ranger_planner.gd`.
- **Cards**: the enemies Knight, Ranger, Weaver, Mage and the boss Perry always drop a card of their own face (`Allies.DROPS`). With a full hand the card stays on the floor until there is room. The face cards can also come from chests and the shop, and lie on Stage 3 maps (`Allies.CARDS`).

## Impact (v0.8)
- **Hit-stop:** a landed hit freezes the whole game for a moment (real time): **45 ms** normal, **80 ms** heavy (2+ base damage, launchers, explosions, lightning, counter hits), **100 ms** a kill, **120 ms** a parry; never more than 120 ms (overlaps extend, never stack). Beam ticks only stop on a kill. `scripts/game/hit_stop.gd` (autoload `HitStop`) drops `Engine.time_scale` and restores it per physics tick; Mera's input clock keeps real time through it, so combo windows don't change.
- **Flash + sparks** on every hit (props too), **SFX variance**: impact sounds pick a random take and a random pitch within ±8 %.
- Damage to Mera's targets is unchanged.

## Breakables, barrels, chandeliers (v0.8)
The four wave levels (1, 2, 3 and 5); the Moonlit Cemetery and the Dragon's Lair have none. Free CC0 art, see `docs/CREDITS.md`.

| Prop | Hits | Drops |
|---|---|---|
| Candle (2 looks) | 1 | the drop roll below |
| Urn | 1 | the drop roll below |
| Crate | 1 | the drop roll below |
| Chest | a puzzle (see Chests below) | 3 to 5 coins (3 gold each) and 1 to 3 other items |
| Explosive barrel | 1 | the drop roll below; explodes |
| Chandelier (Moonlit Town, Infernal Caverns) | 1 | none: falls |

- **Drop roll** (candle, urn, crate and barrel; `Tuning.BREAK_DROP_*`, `game.break_drop`): 40 % coin, 30 % health potion, 20 % mana potion, 10 % summon card. A full card hand gives 1 gold instead. Chests: see Puzzle chests.
- **Perry's Arena** (level index 11) has exactly **20 breakables** (crates, urns and candles only, no barrels or chests), spread from x 700 to the last 1500 px, at least 150 px apart (`Props.ARENA_BREAKABLES`).
- **Any projectile breaks what it hits** (v0.9.6): Mera's bolts and fireballs, the ranger's arrows, enemy shots, and the dragon's bolts. Every destructible except the cracked wall and the chest breaks in one hit. A chest opens only by solving a puzzle. A wall loses one hit per blow. A dragon bolt's blast breaks everything in the burst.
- **Slide (Down+A):** her body breaks every destructible she passes through except a cracked wall and a chest, and she **takes the drop immediately** instead of leaving it behind. Walls still block her and still take one hit per kick.
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
- **Crouch bubble (v0.9.4):** holding Down raises a small bubble for free (radius 32 art px). A dial around it empties over **3 seconds**, then the bubble drops even if she stays crouched. Crouching again starts a new one. Starting the crouch within 150 ms **parries** (200 px, 1 s stun). After that window the bubble **subtracts 1** from the hit and does not knock her down, so a hit of 1 is stopped and a hit of 3 costs 2 size. Any button except L1 drops it and does that move. **L1 drinks a potion and the bubble stays.** While it is up, **every item on screen is pulled to her**.
- **Full bubble (L2 hold):** stops **all** damage. Any button except L1 and the L2 hold itself drops it immediately and does that move. **L1 drinks a potion and the bubble stays.** Holding it, with no parry window, still slides the attacker 200 px with no stun. While it is up, **every item on screen is pulled to her** (same as the small bubble).
- **Projectiles** (the hell beast's fireball, and a dragon bolt) parried with L2 in the window fly back 1.6× faster and hit the first enemy for 3. A dragon bolt popped by L2 still bursts harmlessly.
- **Swing parry (v0.9.1):** X (`atk1` or the air `jatk1`) reflects a projectile when the hitbox meets it within **150 ms of the hitbox going live**. It flies at its shooter, or the nearest living enemy, and damages them. No counter window.
- A player shot that touches an enemy shot: **both explode** (the blast does not also hurt Mera). The combo beam and the vertical beam **destroy** enemy projectiles.
- A later L2 is just the barrier as before (blocks while held, costs stamina).

## Secrets (v0.8)
Summon cards are **not lying on the maps**. Each of the four stage maps (Sunlit Country, Misty Woods, Moonlit Town, Infernal Caverns) has **two cracked walls**, each hiding one summon card:
- **Cracked wall:** the card is behind it; **4 hits** (or one explosion) break it.
- **Lever + door:** hit the lever (620 px before the door) and the door slides up. No card is behind it now.
- **Ledge:** a ledge **300 px** up (no card on it now), reached from a **crumbling plank** 150 px up (double jump at 1x). The plank shakes 0.45 s after Mera stands on it, breaks 0.3 s later, and grows back after 6 s. A big Mera or flight also reaches the ledge.
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

## Puzzle chests
Chests need no key. Mera stands on a shut chest and presses A (Z on the keyboard; an "A: OPEN" prompt shows) and the game pauses on one of three puzzles, picked at random from the game's drop RNG. The pause menu cannot open on top of a puzzle. **Win:** the chest opens and 3 to 5 coins (each worth 3 gold; a coin from a broken object is worth 1) and 1 to 3 other items (health potion, mana potion or a summon card) pop out. **Lose, time out, give up or quit:** the chest **explodes** and is gone (no loot), and Mera loses 1 (a size, or 1 HP for Perry) if she is within 360 px. All numbers are in `scripts/game/tuning.gd`.
- **Connect the pipes:** a 5 x 5 board of straight, corner and tee pipes. Water enters on the left edge and the drain is on the right. Rotate tiles clockwise; the board is built from a random path and then scrambled, so it is always solvable. You win when water reaches the drain. You lose when you run out of rotations (the rotations the cheapest solution needs, plus 14) or give up.
- **Match the foes:** a 6 x 6 board of portraits of 5 distinct random enemies. Swap two neighbours to make a run of 3 or more; runs clear, tiles fall, new ones drop in, and cascades pay 75 % more per step (refilled tiles often copy the tile below, so chains are common). A swap that matches nothing is undone. The board never starts with a match and is reshuffled if no move is left. Reach **300 points** (5 per cleared tile) before the **20 second real-time clock** runs out. There is no move limit; time up loses.
- **Stop the needle:** a needle sweeps a gauge with a green zone. Stop it inside the zone three times in a row. Zones are 24 %, 17 % and 12 % of the gauge (never under 6 %) and the needle runs at 0.6, 0.8 and 1.0 gauge widths per second. A miss loses.

## Shop unlocks and clear gold
- **Shop page 2** (Left/Right switches between the two shop pages) sells these moves. They start **locked**:
  - the beam finisher (X X X then Y);
  - the earthquake (Down+Y);
  - the super earthquake (Down+Y at full rage; the earthquake must be bought first);
  - the rear explosion (X+Y);
  - Fury mode (L2+R2).
- **Homing shots** are a sixth unlock: once bought, quick-fire bolts and rear-explosion fireballs steer toward the nearest enemy.
- A locked move does nothing: the input falls back to the normal move.
- **Level clear gold:** the first clear of a level pays 15 gold, each later clear 5 gold. Killing the Infernal Dragon at the end clears its stage, pays that clear gold plus 100, shows "You Defeated the Cavern Dragon!" with "Stage 2: The Island is open" and returns to the title screen (the level select then opens on Stage 2). Perry, the boss of level 12 (Perry's Arena), does the same with "You Defeated Perry!" and "Stage 3: Changeling is open", and also pays the 100 gold bonus. The Warlord, the last boss (level 20), shows "You Defeated the Warlord!" and "The Changeling is free". The level select has three pages: Stage 1 (levels 1 to 6), Stage 2 (7 to 12) and Stage 3 (13 to 20, two rows of four cards).


## Ladders and platforms (Stage 3)
- A **platform** is a one-way plank (`scripts/game/platform.gd`): you jump up through it, land on top, like a map ledge. Its top is a surface in `Game.built_surfaces`, which `surface_under` reads next to the level's `surfaces`. `Game.build_platform(center_x, top_y, width = 260, ttl = 25)`; it fades and shrinks for its last second, then vanishes (ttl 0 is permanent).
- A **ladder** (`scripts/game/ladder.gd`) is climbable by Mera and Perry (`scripts/game/climb.gd`, state `climb`); `Game.build_ladder(x, bottom_y, top_y, ttl = 25)`, `Game.ladders_at(x, y)`, `Ladder.nearest(game, x, y)`, and `Ladder.climb_step(body, ladder, dir, delta, speed)` for allies and enemies. Climb speed is `Tuning.LADDER_SPEED` (240 px/s).
- `Tuning.PLATFORM_STEP_H` (72 px) is the highest a built platform may sit above the surface under it: 80 % of the apex of the weakest jump (Mera at size 1, 90 px), so one jump always reaches it. Callers pick the heights; nothing is clamped.
- A level may declare permanent `"platforms": [[x0, x1, y]]` and `"ladders": [[x, bottom_y, top_y]]` in `levels.json`.

## Perry (Stage 3: playable character)
- **Unlock and choice.** Clearing level index 10 (Moonlit Sanctum) unlocks her. The level select switches Mera / Perry (saved in `Carry.character`; a locked choice falls back to Mera). The game spawns `PerryPlayer` (`scripts/game/perry_player.gd`, a subclass of Mera, so everything that reads the player works) instead of `Mera`.
- **HP, not size.** She starts with **50 max HP** (HUD: HP bar). **1 enemy damage point = 10 HP** (`PERRY_HP_PER_DMG`), so a normal 1-point hit is 10 HP. 1.2 s of invulnerability after a hit. At 0 HP she dies like Mera (Game Over). Green potions heal 15 HP (pickups heal at once while HP is not full; L1 drinks a stored one). Bone Powder (shop, 90 gold) adds 25 max HP, up to 200. She never grows; `size` just carries Mera's saved size.
- **Meters.** Energy is the blue MANA bar (renamed ENERGY), super is the RAGE bar (renamed SUPER; earthquake and meteor shower need 100 and spend it all), empower is her own small orange bar (1 / s regen, +30 from a mana potion) shown once she owns an unlock that uses it. Mera's pickups feed the same meters.
- **Defence.** Tap B: parry (0.26 s window): no damage, the attacker is stunned 2 s, takes 1 damage and slides 200 px, her hits do x2 for 0.9 s. Hold B: block (no damage, 40 px slide). Dash is invulnerable for 60 % of it. Rainbow guard: 5 s of invulnerability.
- **Damage** is Perry Riposte's number x `PERRY_DMG_SCALE` (0.12), at least 1, so she kills at about a 3x Mera's pace: slash 3, thrust / upswing / spin 2, heavy horizontal 6, dash thrust 3, chain 2 / 2 / 3, heavy chop 24, jumping crash 36, energy kick 4, energy burst 6, wave blast 6 (radius 75), push kick 1, beams 1 / 2 / 2 per tick (cloud / fire / laser), plasma 0 (an enemy it touches drops +10 energy once). Earthquake and meteor shower (x0.3 again) hit every enemy on screen every 250 / 300 ms. All numbers are in `Tuning` (`PERRY_*`).
- **Unlocks** (`scripts/game/perry_unlocks.gd`, ported from BibooSGBA `progress.js`): 26 entries plus Bone Powder, paid in gold. **Scroll = 15 + 10 x level, mutagen = 25 + 15 x level** (an unlock that uses a meter, or meter charge, is a mutagen), e.g. Lunging Thrust 25, Taunt 35, Flight 55, Energy Wave 55, Ultimate Chain 85, Earthquake 100. An unlock opens once Stage 2 level (5 + level, at most 10, as an index) is cleared; otherwise the shop row says "Clear Stage 2 level N first". Her base moves: idle, walk, jump, double jump, duck, slash, spin attack, parry, block, dash. Owned unlocks and max HP are saved in `Carry` (old saves load with none).

## Perry, the boss of Perry's Arena (level index 11)
Boss-only level like the Dragon's Lair: no waves, no other creature ever on screen. `Roster.BOSSES[11] = "perry"` (Moonlit Sanctum, index 10, is a normal wave level with no boss). AI: `scripts/game/perry_boss.gd` (extends monster.gd, picked by `game.PERRY_BOSS`), effects in `perry_boss_fx.gd`, every number in `Tuning.PERRY_BOSS_*`, the move table is `Tuning.PERRY_BOSS_MOVES` (frames, timing, root motion and hit boxes come from `assets/perry/perry_player.json`, her own player moves).
- **HP is size, like the dragon.** 25x, `Tuning.DRAGON_HP_PER_SIZE` (8) hp per size, so 200 hp. The HUD reads "PERRY   25x" with a tick per size. She is always drawn at k 5; size is only the readout. Any hit that takes hp to 0 kills her (normal boss death, the finale card "You Defeated Perry!"). Her moves cost Mera 1 to 3 sizes.
- **Fast.** Walks 460 px/s, pauses of 0.25 to 0.6 s (x0.75 in phase 2, x0.5 in phase 3), chains of up to 3 moves with no pause, gap closers (dash, sky dash, dash thrust, jump crash) when Mera is more than 350 px away. Every attack has a tell of at least 0.35 s; to be faster she chains and cuts recovery. A move is picked by distance band and weight, with a history penalty, and never the same move more than twice in a row.
- **Phases by hp:** above 66 % the basic pool (slash, thrust, upswing, spin, heavy horizontal, heavy chop, heavy and push kick, chain, dash thrust, sky dash, dash, jump crash, energy wave); 33 to 66 % adds the four beams (cloud 1, fire 2, laser 2, plasma 2 damage; low beams you jump, high ones you duck or dash), meteor shower (7 meteors, each with a ring on the floor 0.75 s ahead), earthquake (two floor waves, jump them), energy kick, energy dash thrust, the 4-hit chain; below 33 % adds rainbow guard (below 40 % hp, 2.5 s, she glows and takes 25 % damage, every 20 s), the burst chain and the ULTIMATE CHAIN (below 30 % hp, every 25 s: taunt, then plasma, cloud, fire and laser beams in a row, each with its own 0.4 s tell). Each new phase opens with a taunt feint followed by a quick strike.
- **Parry.** While free (idle, walking, healing, in a tell) she parries Mera's melee 9 times in 10 (seeded roll): no damage to her, Mera is staggered 0.4 s and slides 260 px, and she counters at once with a slash or thrust (the parry was the warning, so the counter has only a 0.12 s wind-up). Parry cooldown 0.35 s (a fast flurry lands between parries); she also blocks (30 % of the damage, at least 1) when she is caught idle between parries. She parries and REFLECTS every real projectile within 450 px that flies at her (Mera's bolts, fireballs, volleys): it flies back at Mera at 1.2 x its speed and hurts her by 1 size. She cannot parry while stunned, in the energy burst, the rainbow guard, the ultimate chain, or in the active and recovery frames of any move (the heavy chop and jump crash leave long openings). **What beats her:** beams (Mera's beam, vbeam, lightning), explosions, quakes, every ally attack and ally arrow, and stuns. The earthquake stuns her on the ground for the full 5 s (at least 3 s for any stun): no parry, no heal, no attack.
- **Heal.** Undamaged for 1 s, nobody attacking her (no Mera move with a hit box within about 1000 px, no Mera projectile or beam within 600 px) and Mera at least 450 px away: she kneels (recover, green flash and sparkles) and regains `hp_max / 6` per second, so empty to full in 6 s. It stops the instant she is damaged, parries, is stunned or starts a move, or when Mera comes within 260 px.
- **Pressure and the energy burst.** Hits on her (parried ones too) are counted over 2.5 s. 3 hits in 2.5 s with Mera within 260 px, or Mera staying within 260 px for 3 s, make her next move the ENERGY BURST: a ring of energy with a 640 px half width and 430 px height (jump high, dodge, or parry it yourself), 2 damage, Mera is thrown back 600 px. Then she backs off with a dash or sky dash, and heals if left alone. Burst cooldown 5 s. At point blank she also shoves with the push kick (small knockback).
- **Never alone with others.** She spawns at least 900 px from Mera. The tests: `_pb_tests` in `tests/run_tests.gd` ("perry boss").
