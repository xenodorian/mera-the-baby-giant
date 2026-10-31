# Mera: Wand Beam attack (prototype, branch `beam-attack`)

## Source of the beam
- The user's wizard beam animation and its build instructions are in **xenodorian/GameOfGameBecauseGame**:
  `reference/wizard_beam_pixel_art.zip` (added in commit f12fc02, 2026-10-29). Inside: `PROCESS.txt`
  (the "how it was made / how to adapt" guide), `src/render.py` (procedural Pillow+numpy renderer),
  `src/export.py`, 60 frames at 192x100 (1x) and 4x, sprite sheet, GIF/APNG.
- How that game uses it: `CLAUDE.md` section 5 "Effects system", `game/src/glow.js` (`Glow` bands, star, disc,
  bolt, light) and `game/src/abilities.js` (mage `spell_bolt` = "Beam", `BEAM` constants).
- Method (procedural, no sprite frames): every effect writes into one float energy field E (combined with max),
  then E is cut into flat colour bands at 0.92 / 0.80 / 0.66 / 0.50 / 0.30 (white core -> edge) plus a faint
  halo below 0.30. Beam profile per column `1.08 * (1 - (d / (w + 2.5)) ^ 1.6)` with separate upper/lower
  jittered half-widths, two sine wobbles, a travelling sin^6 pulse and a taper at the staff. Plus: charge orb
  with spiralling motes and rune ring, 3-frame head race-out, muzzle flare with a 4-ray star alternating 0/45 deg,
  midpoint-displacement lightning arcs, ground strikes, sparks, impact disc + rays, noisy dissipation,
  light on the environment through a 4x4 Bayer dither, and a rim light on the caster.

## Mera version
- Colours: Mera's own slash-fx teal ramp from `1x atk_fx`: #28c090, #48e0b0, #88f8d0, #c8f8e8, #ffffff.
- Width scaled down a bit for Mera's thin wand (base half-width 3.6 instead of 4.6).
- Animation: `atk/1x atk/1x atk_c.aseprite`, character layers only (`1x atk`, `to idle`); the `1x atk_fx`
  slash layer is dropped (the beam replaces it).
- Held pose: atk frame 6 (index 5; identical to frame 5), the fully extended lunge. Wand tip pixel (149, 39) in
  the 160x64 canvas. **In this pose the wand points behind her** (the art faces left, the wand points right),
  so a beam "out of the wand" fires backwards. The test scene has both: J/X = out of the wand, K = toward facing
  (she turns her back to cast).

### Timeline (25 fps, 40 ms per frame, like the pack)
| Frames | Source | Beam |
|---|---|---|
| 0-4 | atk frames 1-5 (wind-up) | - |
| 5-10 | held frame 6 | charge: orb at the tip, motes spiral in, rune ring closes |
| 11-13 | held frame 6 | fire: flash, head races out (30% / 62% / 88%) |
| 14-27 | held frame 6 | sustain: full beam, arcs, ground strikes, impact |
| 28-33 | held frame 6 | fade: beam breaks into rising particles |
| 34-37 | atk frames 7-10 (settle) | leftover particles |
| 38-44 | `to idle` frames 11-17 | - |
Hold = 29 frames = 1.16 s. Whole cast 45 frames = 1.8 s (the preview GIF adds 6 idle frames before looping).

## Files
- `tools/mera_wand_beam.py` - preview renderer (Python port of the energy-field method) -> `previews/beam/`.
- `tools/export_mera_beam_cast.py` - exports `assets/characters/merakintsugi/derived/beam_cast/mera_beam_cast_strip17.png`
  (+ `.json` with pivot (139, 63) aligned to the idle export, held frame, wand tip, beam origin relative to the feet (11, -24)).
- `scripts/attacks/mera_beam_attack.gd` - the attack: child of Mera, one `Rig` node scaled by (size x direction, size)
  holding the cast AnimatedSprite2D, the beam drawing, the Area2D hitbox and a RayCast2D for range. The beam runs to
  150 px (1x) or the first hurtbox the ray hits; the hitbox is the beam rectangle (10 px tall at 1x), active from the
  2nd fire frame to the end of sustain, damage tick every 3 frames (0.12 s). No per-size data: it scales 1x-19x with Mera.
- `scripts/attacks/beam_fx.gd` - GDScript port of the banded beam, drawn with `draw_rect` in 1x pixels.
- `scenes/tests/beam_test.tscn` + `scripts/tests/beam_test.gd`, `scripts/tests/beam_target.gd`, `shaders/hit_flash.gdshader`.
  Keys: J/X beam out of the wand, K beam toward facing, Left/Right run, Up/Down size, H hitboxes.
  CLI after `--`: `--cast[=K]`, `--scale=N`, `--boxes`, `--shot=PATH --wait=N`, `--autotest` (exit 0 if the knight was hit).

## Not ported yet (Godot)
Environment light / Bayer dither, rim light on Mera and the white screen flash are in the GIF only.
