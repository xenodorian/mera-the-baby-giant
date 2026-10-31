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
- **Variant:** pick1 v4 (`pick1_v4_projectile_cast.gif`) swaps the beam for a single rear fireball that explodes (ground explosion). That version doesn't delay her: f24 plays 4 × 40 ms and recovers normally. Use it if the beam's hold feels too long for a combo ender.
- **Root motion:** the combo moves her about 15 px left over the whole string, measured idle to idle.

## Dodge-attack spell (pick3)
dodge atk 1x f14 fires LEFT (forwards) from tip (94,22).
- v1 (`pick3_dodge_atk_1x_f14_cast.gif`): the beam version.
- v2 (`pick3_v2_projectile_cast.gif`): a small quick bolt that pops in the air.
