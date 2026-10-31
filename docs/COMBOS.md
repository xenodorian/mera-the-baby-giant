# Mera ground combos

Source animations are in `assets/characters/merakintsugi/platformer-character-pack/atk/`. Timing comes from the `.aseprite` files: 1x / 2x atk run at 40 ms per frame, 3x atk at 35 ms (shown at 40 ms in the previews). The game has no input map yet, so the inputs below are proposals: **A** = attack, **S** = spell/cast.

## Combo A: normal 3-hit (pack default)
| Input | Animation | Frames | Chains into the next hit |
|---|---|---|---|
| A | 1x atk | f0-9, then `to idle` f10-16 if no input | press A again before f9 ends → 2x atk f0 |
| A | 2x atk | f0-9, then short recovery (`to idle(short delay)`) | press A again before f9 ends → 3x atk f0 |
| A | 3x atk | f0-33: spin and lunge f0-7, crouch slide f8-19, wand swing f20-23, turn and follow-through f24-33 | ends → idle |

## Combo B: beam ender (alternate 3rd hit)
This is a variation of Combo A. Hits 1 and 2 and the opening of hit 3 are identical. **It branches after 3x atk f23**: instead of the normal f24 follow-through, she freezes on the f24 pose and fires the wand beam backwards (LEFT, behind her) from the left end of the hip-level wand shaft, tip (162,72) on the 3x atk canvas.

- **Input:** A, A, then on the 3rd hit **hold A** (or press **S**) at any point before 3x atk f23 ends. If the button is released or S isn't pressed, she plays Combo A's f24-33 as normal.
- **Frames** (preview `previews/beam/cast_sequences/pick1_3x_atk_f24_cast.gif`, 108 frames, 4.96 s, timeline in `pick1_3x_atk_f24_timeline.json`):

| Step | Frames | ms | Effect |
|---|---|---|---|
| idle | idle ×6 | 60 each | – |
| hit 1 | 1x atk f0-9 | 40 each | charge orb on the wand tip starts faint |
| hit 2 | 2x atk f0-9 | 40 each | charge builds (orb dimmed where the wand is hidden, 2x f8-9) |
| hit 3 opening | 3x atk f0-23 | 40 each | charge peaks; rune ring closes over f20-23 |
| **branch: beam hold** | 3x atk f24 held 23 frames | 40 each | fire 3 + sustain 14 + fade 6. Recoil pushes her right (away from the beam): 3 px kick, ease-out push to about 5 px, ±1 px shake, settle |
| recovery | 3x atk f25-33 | 40 each | beam dissolve particles hover where the beam was |
| idle | idle ×26 | 60 each | particles fade out |

- **Cost:** the hold adds 23 × 40 = 0.92 s over Combo A's ending, so it should cost meter or have a cooldown.
- The beam can hit anything behind her (a back-attack ender). The hitbox is a horizontal strip about 150 px long starting at the wand tip during fire and sustain.
- **Variant:** a single fireball that explodes (Ground Explosion) instead of the beam. It doesn't delay her: the fire pose plays 4 × 40 ms, then she recovers normally. The user's choice for the rear projectile is **pick2 v3** (`pick2_v3_projectile_cast.gif`, fired on 3x atk f4). pick1 v4 (`pick1_v4_projectile_cast.gif`, fired on f24) is the same idea on this ender.
- **Root motion:** the combo moves her about 15 px left over the whole string, measured idle to idle.

## Quick-fire ranged attack (dodge atk 1x bolt, pick3 v3)
A fast, cheap ranged poke: no explosion, the bolt simply crosses the screen.

- **Input (proposal):** S (cast), or back + A to reuse the dodge-attack motion. She steps back (f2-7), swings forward (f8-13) and fires on f14.
- **Preview:** `previews/beam/cast_sequences/pick3_v3_bolt_cast.gif`. It's 420 native px wide (1680 px at 4x), 2.08 s, with the timeline in `pick3_v3_bolt_timeline.json`.

| Step | Frames | ms | Effect |
|---|---|---|---|
| idle | idle f0, f1 | 60 each | – |
| wind-up | dodge atk 1x f0-13 | 40 each | charge orb on the wand tip ramps up (explosion palette); rune ring closes over f11-13 |
| fire | f14, f15 once each (no hold) | 40 each | bolt leaves the tip (94,22), with muzzle flash; recoil kick 2 → 1 px (away from the shot) |
| recovery | f16-18 → idle | 40 each, then idle at 60 | she's back in idle at 880 ms while the bolt is still flying |

- **Projectile:**
  - It flies perfectly level to the LEFT (y never changes) at a constant 16 px per 40 ms (400 px/s, native).
  - It leaves the 420 px screen about 0.9 s after firing.
  - No explosion and no pop.
  - It's a small elongated head (about 10×5 px) with a short 8-step trail and a subtle size/brightness flicker. Faint sparks fall off behind it.
- **Gameplay:** make it a hitscan-free projectile at about 400 px/s with a 6×4 px hitbox. Despawn it off-screen or on the first hit.

## Dodge-attack spell (pick3)
dodge atk 1x f14 fires LEFT (forwards) from tip (94,22).
- v1 (`pick3_dodge_atk_1x_f14_cast.gif`): the beam version.
- v2 (`pick3_v2_projectile_cast.gif`): a small quick bolt that pops in the air.
- v3 (`pick3_v3_bolt_cast.gif`): the quick-fire ranged attack above.
