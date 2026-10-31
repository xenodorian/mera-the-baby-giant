# Mera: The Baby Giant: test-level game rules

## Size is health
- Mera starts at **2x**. Her size is her HP (HUD: six size pips).
- Each hit costs as many sizes as its damage: a normal hit = 1 size, big attacks = more.
  The size change animates one step at a time.
- A hit that would take her below 1x (any hit while she is at 1x) kills her. **Game Over**: Start / Enter restarts.
- After a hit she gets **1.2 s of invulnerability** (she blinks).
- The L2 barrier blocks every hit while it is held.
  - The bubble is sized by `tools/fit_barrier.py`, from every opaque pixel of the held pose (heal f5-8: body, raised hand and energy ball), plus a 3 px margin. Result: centre (-3, -38) art px, radius 44.5 art px, scaled by size and mirrored by facing.
  - While it is up, Mera's hurtbox is the bubble's bounding square, so the blocking area matches what you see.
  - **R1 works inside the bubble.** It needs and spends the full meter as usual, and the strike fires while she holds the pose and keeps blocking.
- Movement speed and hit/hurt boxes scale with size. At 1x: walk 50, run 200, ground/aerial dash 1600, and back dodge 800 px/s.
  - The dashes and the dodge play their animations at 2x speed, so every key frame is kept, and leave a pooled afterimage trail (up to 8 ghosts).

## Damage
Damage dealt = base damage × Mera's current size (1x does 1×, 3x does 3×).

| Move | Base |
|---|---|
| 1x, 2x | 1 |
| 2x-1, 2x-2, 3x | 2 |
| Beam (beam combo) | 1 per tick (every 5 frames while the beam is on) |
| Dodge attack 1 / 2 / 3 | 1 / 1 / 2 |
| Jump attack 1 / 2 | 1 / 2 |
| Slide | 1 |
| Quick-fire bolt | 1 |
| Rear explosion (slash 1, explosion AOE 3) | 1 + 3 |
| R1 lightning (AOE) | 3 |

## Potions
- Green potions lie on the ground. Walk over one to carry it (HUD: POTIONS count). She starts with 1.
- L1 drinks one: +1 size, up to **6x**. With no potions, or already at 6x, L1 plays a fail cue and nothing is used.
- Where potions come from:
  - a defeated Fire Knight drops one 35 % of the time;
  - one appears on the ground ahead for every 2600 px of new ground explored;
  - at most 2 potions lie in the world at once.
- Free size changes (1x–19x) exist only in debug mode (F2).

## Rage and Fury
- **R1 lightning costs the whole meter.** It works only at 100 % rage and outside Fury, also while the L2 bubble is up. The meter then drains visibly to 0 (about 0.45 s) and refills normally afterwards.
  - Below 100 %: a fail cue plus a HUD hint, and nothing happens.
  - During Fury the meter is the Fury timer, which R2 already spent, so R1 is unavailable until Fury ends and the meter refills.
  - With a full meter, choose: R2 = Fury, or R1 = one lightning strike.
- **Fury aura (Kaioken style):**
  - a pixel flame shell twice her width, drawn behind her, with rising tongues flickering at 12 fps and a dark-red → red → orange ramp hottest at the rim (`shaders/fury_flame.gdshader`);
  - thin additive tongues licking over her outline;
  - 90 additive embers;
  - the outline aura on her body.
  - It scales with her size, and tilts with her in flight.
  - Quality cap `aura_quality` (`--aura-quality=0..2`): 2 = everything, 1 = back flame + 45 embers, 0 = outline + 20 embers.
- **Fury flight faces the flight direction:** her head leads along the 8-way input (+90° flying right, −45° up-left, 180° diving), with left/right flips. The rotation pivots on her body centre and eases in at 12/s; in the idle hover she eases back upright. The raised-arms pose plays while moving and the tucked hover while idle. The hurtbox follows the tilt.
- A defeated enemy drops a **red sphere**. It flies to Mera and adds rage based on the enemy's difficulty.
  The Fire Knight's sphere gives **+10 %**.
- Each hit Mera lands also adds **+1 %**. Spheres are the main source; the small per-hit bonus keeps "dealing damage builds Fury".
- At 100 %, R2 starts **Fury** for 12 s and the meter drains to 0 over that time.
  - Red aura; all spell fx, beams, explosions and lightning turn deep red.
  - Sfx are pitched down (×0.72) through a low-pass + overdrive bus.
  - Flight: Up in the air takes off; R2 or Down at ground level lands.

## Fire Knight (only enemy in this demo)
- Always drawn at **6x** (264 px tall), the scale-test reference size. **Enemies never scale**, in size or in damage, whatever Mera's size.
- **10 HP**, shown on a health bar over his head.
- Every swing that connects costs Mera exactly **1 size**, with no multiplier. Touching him does no damage.
- AI, tuned for his 6x reach (his sword arc covers 14–68 native px in front of him = 84–408 screen px):
  - he walks up at 192 px/s and stops 96 px from Mera's body;
  - a swing starts when she is within 336 px. He holds his first frame and glows orange for **0.4 s** (the tell), then swings at 11 fps, so the sword is out about 0.7 s after the tell begins;
  - 1.4 s cooldown after a swing, 0.9 s after a flinch. Mera's hits make him flinch (pushed back 24 px), except once his swing is committed (frame 3 on): then he takes the damage and keeps swinging.
- Ways out: back dodge, ground dash and aerial dash are **invulnerable for their first 70 %**. The L2 barrier blocks. Or back off past his reach. After any hit Mera also gets 1.2 s of i-frames.
- On death he fades out, drops a red sphere (+10 % rage) and sometimes a potion.

## Beam and lightning reach
- The combo beam (X X X Y, normal and Fury red) and the R1 lightning always reach **off-screen**, at any size, from any position, in either facing, and while the camera scrolls.
- **Combo input:** the beam needs X X X Y. The Y may come up to 0.3 s after the third X, even if that X already started 2x-1 or 2x-2.
  - X X Y is always 1x → 2x → 3x. A second Y after it (X X Y Y) is swallowed, never the beam.
- Both are built from **tessellating segments** (`tools/tess_spells.py`, sheets in `assets/characters/merakintsugi/game/spell_beam*.png` and `spell_lightning_seg.png`):
  - **Beam:** a start cap (the canon cast frame, cut 24 px past the wand), then 64 px mid segments. The waves, pulse and halo are periodic over 64 px, so the seams are invisible; three variants carry the crackle, sparks and dissolve particles. The end is a front head while firing and an impact cap during the sustain, which sits off-screen.
  - **Lightning:** a ground-impact cap, then 64 px mid segments whose bolt enters and leaves each segment at the centre, then a fork cap above the top of the screen.
- The segment count is recomputed every frame from the camera: viewport edge + 160 px margin.
- The hitboxes cover the full length: the beam from the wand to its far end, the lightning from above the screen top to the ground.
- Segments come from a shared sprite pool: at most 96 per strip and 384 in total. A 1x beam across the whole screen needs about 36.
- The lightning lands on the nearest enemy within 1100 px, otherwise in front of Mera, and is kept on screen.

## Spawning
- **Only one Fire Knight at a time.** A new one appears just off-screen ahead of Mera:
  - 2 s after the previous one is defeated, or
  - when Mera has moved too far away (he is off-screen and more than 2400 px behind). He is then removed and replaced ahead of her.
- The level loops forever: the cemetery background tiles every 1920 px, with blurred seams.
- **Camera (v0.3.1):** hard-locked horizontally on Mera's feet pivot, so she is always at the exact screen centre.
  - There is no look-ahead and no smoothing. Turning around never shifts the view, and dashes never drift.
  - It updates after all physics each frame (`scripts/game/cam_rig.gd`), so there is no one-frame lag.
  - Vertical is fixed (the level is one screen tall), apart from screen shake.
  - Beam and lightning lengths are computed against this camera every frame.
