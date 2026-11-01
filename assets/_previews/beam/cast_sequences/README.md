# Mera beam cast sequences

Made by `tools/beam_cast_sequences.py` (run it from the repo root). The GIFs are 4x nearest-neighbour on a plain dark background.
Frame times: 40 ms for attack frames (the pack uses 35-40 ms) and 60 ms for idle frames. The beam pipeline and the teal ramp are the same as in `previews/beam/user_picks/` (approved).

How a sequence runs:

1. An idle beat.
2. The pack's own lead-in frames. The charge orb follows the wand tip every frame and grows brighter as she nears the pose. A rune ring closes in over the last 4 frames.
3. She fires on the first in-position frame and holds the pose for fire (3), sustain (14) and fade (6).
4. Recoil pushes her rigidly away from the beam: a 3 px kick, an ease-out push to about 5 px, a ±1 px shake during sustain, then a settle back to 0 by the end of the fade. The beam origin stays on the tip.
5. The animation's own follow-through and recovery frames play, then idle. The end idle is placed by silhouette match to the last recovery frame, so there is no pop.
6. Particles from the beam's dissolve are released into world space. They hover and drift slowly (under 0.15 px per frame) and fade out by the end of the idle beat.

| pick | GIF | size | frames | length | lead-in | hold | recovery |
|---|---|---|---|---|---|---|---|
| pick1_3x_atk_f24 | `pick1_3x_atk_f24_cast.gif` | 976×344 | 108 | 4.96 s | idle×6 → 1x atk f0-9 → 2x atk f0-9 → 3x atk f0-23 | 3x atk f24, fires LEFT from the left end of the hip shaft | 3x atk f25-33 → idle + 26 idle |
| pick2_3x_atk_f4 | `pick2_3x_atk_f4_cast.gif` | 1032×344 | 108 | 4.96 s | idle×6 → 1x atk f0-9 → 2x atk f0-9 → 3x atk f0-3 | 3x atk f4, fires right, 11° down | 3x atk f5-33 (full slide follow-through) → idle + 26 idle |
| pick3_dodge_atk_1x_f14 | `pick3_dodge_atk_1x_f14_cast.gif` | 1004×320 | 72 | 3.52 s | idle×6 → dodge atk 1x f0-13 | dodge atk 1x f14/15 (alternating 3+3), fires LEFT | dodge atk 1x f16-18 → idle + 26 idle |

Each `*_timeline.json` lists every output frame: source animation and frame, phase, recoil offset, ms, the tracked tip and the number of live hover particles. Each `*_keyframes.png` is a 2x strip of 10 moments.

Phase timing (frames @ 40 ms): lead-in = all source frames listed above | fire 3 | sustain 14 | fade 6 | recovery | idle 26 @ 60 ms.

## pick1 v2 (user request: charge on idle 1, crouch 1 and the matched attack frame)

`pick1_v2_3x_atk_f24_cast.gif` is 936×320, 88 frames, 4.04 s. The 1x/2x combo lead-in is dropped.

**Lead-in (each held 10 frames × 40 ms = 0.4 s, charge 30 → 100 % linear, rune ring over the last 4 frames):**

| frames | source | tip |
|---|---|---|
| 0-9 | idle f0 (the first idle frame; Aseprite frame 1) | (57,34) |
| 10-19 | crouching f0 (first frame of the `crouching` layer; Aseprite frame 1) | (49,36) |
| 20-29 | 3x atk f23 (pixel-exact match to the user's screenshot, frame 49 of the v1 GIF) | (151,86) |

**Then, as in v1:**
- 30-52: 3x atk f24 held for fire 3, sustain 14 and fade 6, with recoil.
- 53-61: 3x atk f25-33 recovery.
- 62-87: idle ×26 at 60 ms, with the hover particles.

**Placement:**
- Crouching is ground-pinned and matched to idle by silhouette, offset (+4, +13).
- 3x atk f23 is matched to crouching f0 by silhouette, offset (-102, -28). The front foot lands within 2 px.

## pick1 v3 (user: don't delay pose advancement for the charge)

`pick1_v3_3x_atk_f24_cast.gif` is 936×320, 61 frames, 3.01 s. There are no lead-in holds: each lead-in frame plays once at its normal duration.

**Lead-in:**

| frame | source | duration | charge |
|---|---|---|---|
| 0 | idle f0 | 60 ms (the .aseprite value) | 63 % |
| 1 | crouching f0 | 70 ms (the .aseprite value) | 82 % |
| 2 | 3x atk f24's lead-in frame, f23 | 40 ms (35 ms in the file, shown at 40 ms like all of 3x atk here) | 100 %, peak |

- The charge ramps 45 % → 100 % over these 3 frames.
- Motes spawn at 2.5× the normal rate.
- The rune ring closes on all three frames.

**Then, unchanged from v2:**
- 3x atk f24: fire 3, sustain 14 and fade 6, with recoil.
- 3x atk f25-33: recovery.
- Idle ×26 at 60 ms, with the hover particles.

## pick2 v2 (user [pt32u]: her three chosen frames lead into the blast)

`pick2_v2_3x_atk_f4_cast.gif` is 1032×344, 83 frames, 3.88 s.

Her three screenshots were pixel-exact matches for frames 16, 26 and 28 of the v1 pick1 GIF, which plays the same combo lead-in as v1 pick2.

**Lead-in:**

| frame | source | duration | charge |
|---|---|---|---|
| 0-1 | idle f0, f1 | 60 ms each | none |
| 2 | 2x atk f0 | 40 ms | 63 % |
| 3 | 3x atk f0 | 40 ms (35 ms in the file) | 82 %, dimmed |
| 4 | 3x atk f2 | 40 ms (35 ms in the file) | 100 %, peak |

- On 3x atk f0 the wand is hidden in the back view. What sticks out up-left there is her horn. The orb is interpolated between the neighbouring tips and drawn dimmer.
- 3x atk f3 is skipped, because she listed f2 followed by the f4 fire pose.

**Then, unchanged from v1:**
- 3x atk f4: fires right, 11° down, for fire 3, sustain 14 and fade 6, with recoil.
- 3x atk f5-33: recovery.
- Idle ×26 at 60 ms, with the hover particles.

**Placement:**
- 2x atk f0 is matched to idle f0 by silhouette, offset (-98, 0).
- 3x atk f0 is matched to 2x atk f0, offset (-124, -28), using the same ground y as v1.
- When the GIF loops she jumps about 23 px (v1 was about 15 px).

## Projectile versions (`tools/projectile_cast.py`)
These use the explosion palette, the same for both shots: cream #fff8e6, peach #faa953, orange #cf5638, red #a32121, wine #691b2b, deep #4a1427, mauve smoke #825861. The GIFs are event-driven: a frame is emitted when Mera, the shot or the explosion changes, so each plays at its own rate. The palette is exact and checked on read-back.

### pick1 v4: rear projectile (`pick1_v4_projectile_cast.gif`, 956×440, 52 frames, 2.31 s)
| Time | What happens |
|---|---|
| 0-170 ms | Lead-in as v3: idle f0 (60 ms) → crouching f0 (70 ms) → 3x atk f23 (40 ms), with the charge in the explosion palette |
| 170 ms | **Fire** on 3x atk f24, with muzzle flash at the tip (162,72) |
| 170-330 ms | f24 held 4 × 40 ms; recoil kicks her right 3 → 2 → 1 → 0 px |
| 330-690 ms | Recovery f25-33 at 40 ms, then idle |
| 170-650 ms | Fireball flies LEFT 120 px at 10 px per 40 ms, dropping on an arc to the ground |
| 650-1280 ms | ansimuz Ground Explosion at 1:1, 9 frames × 70 ms |
| until 2.3 s | Embers and smoke hang and fade |

### pick3 v2: small dodge-attack bolt (`pick3_v2_projectile_cast.gif`, 748×272, 52 frames, 2.14 s)
| Time | What happens |
|---|---|
| 0-120 ms | Idle ×2 |
| 120-680 ms | dodge atk 1x f0-13 at 40 ms; the charge ramps up on the tip |
| 680 ms | **Fire** on f14: a small bolt (head radius 2.3 vs 3.6, 9-step trail vs 16) |
| 680-760 ms | f14 and f15 play once each (40 ms); recoil kicks her 2 → 1 px |
| 760-880 ms | f16-18 → idle |
| 680-980 ms | Bolt flies 90 px LEFT, nearly straight, at 12 px per 40 ms |
| 980-1400 ms | It pops in mid-air with ansimuz explosion-1-a (32×32, 7 non-empty frames × 60 ms), recoloured to cream, peach and orange |
| until 2.1 s | A few embers linger |

> **Correction (user [pt39u]):** the "rear blast" that should become the projectile was **pick2 v2**, not pick1. The rear projectile now belongs to pick2 (`pick2_v3_projectile_cast.gif` below). pick1 v4 is kept as an unrequested variant, and the pick1 v3 beam is unchanged.

### pick2 v3: rear projectile (`pick2_v3_projectile_cast.gif`, 1092×440, 63 frames, 2.76 s)
| Time | What happens |
|---|---|
| 0-240 ms | pick2 v2's lead-in, unchanged: idle f0, f1 (60 ms each) → 2x atk f0 → 3x atk f0 → 3x atk f2 (40 ms each), charge in the explosion palette peaking on f2 |
| 240 ms | **Fire** on 3x atk f4, with muzzle flash at the tip (160,36) |
| 240-400 ms | f4 held 4 × 40 ms; recoil kicks her left (away from the shot) 3 → 2 → 1 → 0 px |
| 400-1560 ms | Normal f5-33 recovery at 40 ms, then idle |
| 240-760 ms | Fireball leaves along the wand, to the right and 11° down, then curves down to land 130 px away (10 px per 40 ms) |
| 760-1390 ms | ansimuz Ground Explosion at 1:1, 9 frames × 70 ms |
| until 2.76 s | Embers and smoke hang and fade |

On 3x atk f0 the wand is hidden, so the orb sits midway between the neighbouring tips and is drawn dimmer, as in v2.

### pick1 v4 with sound: deleted at the user's request (Oct 30). The final rear explosion is pick2 v3 (`pick2_v3_projectile_cast.gif`). The generator `tools/cast_sfx_mp4.py` and the Kenney sounds remain.

| Sound | Synced to | Level |
|---|---|---|
| **Melee:** `knifeSlice2` slash (first 180 ms) | Transient on 3x atk f26 (370 ms, and 2680 ms in loop 2), the first frame of the claw-hand swipe smear. f25 raises the claw, f27 follows through. | 0 dB (the loudest sound) |
| Cast: `forceField_000` swell | Peaks on the f24 fire frame (170 ms) | -15 dB |
| Impact: `lowFrequency_explosion_001` | Starts at the impact (650 ms), on explosion frame 0 | -9 dB |

The mix is normalised to a -1 dBFS peak, so it doesn't clip.

### pick3 v3: quick-fire bolt (`pick3_v3_bolt_cast.gif`, 1680×272 at 4x = 420×68 native, 54 frames, 2.08 s)
The lead-in, fire frame and recovery are the same as pick3 v2.

| Time | What happens |
|---|---|
| 0-120 ms | Idle f0, f1 |
| 120-680 ms | dodge atk 1x f0-13, with the charge |
| 680 ms | Fire on f14 |
| 680-760 ms | f14 and f15 play once each, with a 2 → 1 px kick |
| 760-880 ms | f16-18, then idle |
| 680-1583 ms | Bolt flies perfectly level LEFT from the tip (94,22) at a constant 16 px per 40 ms, then leaves the screen |
| until 2.08 s | Idle |

No explosion or pop. The bolt is an elongated head (about 10×5 px) with a short trail and a subtle flicker, in the explosion palette.

## With the pack's own slash effects (user [pt51u] "Show me with the slash effect")
Each effect layer from the `.aseprite` file is composited over the body on every frame where it has pixels. The pixels and colours are the originals, at the same canvas offset as the body, and they move with her during the recoil. The GIFs use exact palettes.

| Animation | Effect layer | Frames with pixels | What it is |
|---|---|---|---|
| 1x atk | `1x atk_fx` | f3-11 (the combo uses f3-9) | horizontal slash sweep |
| 2x atk | `fx01` | f3-13 (the combo uses f3-9) | thrust slash |
| 3x atk | `3x atk_fx02` | f4-17 | spin/wind trails |
| 3x atk | `3x atk_fx01` | f8-16 | big crescent slash on the lunge |
| 3x atk | `3x atk_fx03` | f24-33 | claw-swing swirl (f25-27 swing, f26 contact) |

- **`pick2_v4_projectile_slash_cast.gif`**: pick2 v3 (the rear explosion), plus the 3x atk effects on the f4 fire hold (fx02 f4, held with the recoil) and on the f5-33 recovery (fx02, fx01, fx03). The canvas is widened to 1444×456 so the crescent isn't clipped.
- **`pick1_combo_beam_slash_cast.gif`**: the combo into beam (pick1 v1), rebuilt with the same timing and random seed, plus every effect layer above. That's 1x f3-9, 2x f3-9, 3x f4-23, the f24 beam hold (fx03 f24 frozen with the recoil) and f25-33. The canvas is 984×488.

### pick3 v4: quick fire on f10 with a dimming freeze (`pick3_v4_bolt_cast.gif`, 1680×272, 50 frames, 2.16 s). Current quick-fire version.
The user asked for: "fire the bolt at frame 12, and freeze the pose at frame 16 for a total of 4 frames that animate the light dimming".

| GIF frames | What plays |
|---|---|
| 0-1 | Idle |
| 2-11 | dodge atk 1x f0-9, charging |
| **12** | f10: **fire** from the f10 tip (80,25), with muzzle flash and a 2 px kick |
| 13-15 | f11-13, with recoil 1 → 0 px and the tip afterglow |
| **16-19** | f14 **frozen**; tip glow, halo and rim light at 100 / 66 / 33 / 0 % |
| 20-22 | f16-18 |
| 23-49 | Idle |

The bolt flies level at y = 25 at a constant 16 px per 40 ms and leaves the screen at 1.39 s. v3 is unchanged.
