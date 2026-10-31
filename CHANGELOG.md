# Changelog

All releases are GitHub pre-releases/releases of `xenodorian/mera-the-baby-giant` (private). Engine: Godot 4.7.2, Compatibility renderer, native 1920×1080.

## v0.3-playable (2026-10-31)
Branch `playable-level`, merged into `main`. Windows and Linux builds.

### Enemies
- **The Fire Knight is always 6x** (264 px tall), and every swing that connects costs Mera exactly 1 size. Enemies never scale with her size, in size or in damage.
- His AI is retuned for the 6x reach:
  - 0.4 s orange tell (he holds his first frame);
  - committed swings (frame 3 on) don't flinch;
  - approach at 192 px/s, swing range 336 px, bigger health bar.

### Spells
- **The beam (X X X Y) and the R1 lightning always reach off-screen**, at any size, from any position and facing.
  - Both are built from tessellating segments (`tools/tess_spells.py`, `scripts/game/seg_strip.gd`, `strike.gd`) drawn from a shared sprite pool.
  - Their hitboxes cover the full length.
- **Beam input is X X X Y.** The Y may come up to 0.3 s after the third X. X X Y is always 1x → 2x → 3x, and X X Y Y is never the beam.
- **R1 lightning costs 100 % rage.** The meter drains visibly to 0. Below 100 % you get a fail cue and a HUD hint. It's unavailable during Fury.
- **R1 works while L2 is held.** Mera stays in the bubble pose, keeps blocking, and the strike fires (full meter required, all of it spent).
- **The L2 bubble encloses the whole pose.** It is fitted by `tools/fit_barrier.py` around every opaque pixel of the held barrier frames, raised hand and energy ball included, plus a margin. It scales with size and mirrors with facing.
  - While it is up, the bubble is her hurtbox, so the blocking area matches the visual.

### Fury
- **Fury flight rotation:** she tilts head-first toward her 8-way flight direction, flips for left/right, and eases back upright in the hover. The hurtbox follows the tilt.
- **Kaioken-style Fury aura:**
  - a layered procedural flame shell behind her and additive tongues over her (`shaders/fury_flame*.gdshader`);
  - embers;
  - a dark-red → orange ramp.
  - It scales with size and has an `--aura-quality=0..2` cap.

### Camera
- **The camera always follows Mera** horizontally, smoothly, with a small look-ahead and velocity feed-forward. The dead zone is gone.

### Movement
- **Walk is 50 px/s at 1x.**
- **The ground and aerial dashes cover 2x the distance in half the time** (1600 px/s; animation at 2x).
- **The back dodge covers the same distance in half the time** (800 px/s; animation and i-frame window compressed 2x).
- The dashes and the dodge leave a pooled afterimage trail.

### Fixes
- **2x atk without a follow-up** no longer makes Mera vanish for 6 frames and then teleport 343 px × size. The pack's blank "short delay" tail now holds her last pose, and the idle hand-off is -19 px.

### Tests, docs and capture
- Headless tests went from 82 to 122. They cover:
  - the knight's size and damage invariance, and beam/lightning reach;
  - the R1 cost, R1 in Fury and R1 in the bubble, and bubble enclosure at 1x–9x in both facings;
  - combo disambiguation, flight tilt, aura, camera follow, and dash/dodge/walk speeds.
- Docs: `CHANGELOG.md`, README, `docs/CONTROLS.md`, `GAME_RULES.md`, `COMBOS.md` and `CREDITS.md` are updated.
- Gameplay capture and screenshots are in `previews/playable/v0.3/`.

## v0.2-playable (2026-10-30)
The first playable test level (`scenes/game.tscn`), with Windows and Linux builds.

### Level and player
- An endless looping cemetery (parallax, blurred seams), with Fire Knights one at a time.
- All of Mera's pack animations, plus the canon casts, baked by `tools/export_game_anims.py` into layered atlases:
  - quick fire (pick3 v4);
  - rear explosion (pick2 v4);
  - beam combo (pick1).
- Moves:
  - walk, run, jump, double jump, crouch and slide;
  - 1x/2x/3x combos with the input buffer;
  - jump attacks, aerial and ground dashes, back dodge and dodge attacks;
  - L1 potion, L2 barrier, R1 lightning, R2 Fury with flight.

### Rules
- **Size = HP.** She starts at 2x, a hit costs sizes, and a hit at 1x is death. Damage dealt = base × size.
- Potions add +1 size, up to 6x. Red spheres fill the rage meter.

### Controls, enemy and presentation
- Xbox/PS4 controller and keyboard mapping (`docs/CONTROLS.md`).
- The Fire Knight (10 HP) drops a sphere and sometimes a potion, and respawns.
- HUD, Kenney CC0 sfx with a Fury audio bus, and Fury recolour shaders.
- Headless test suite (82 tests), demo capture mode.

## v0.1-scale-test (2026-10-30)
- Mera scale test: `scenes/stage.tscn` on a 1920×1080 ansimuz Cemetery at 5x.
- Mera runs and size-shifts 1x–19x, pivoting at her feet, next to the 6x Fire Knight reference.
- Hurtbox debug, Windows/Linux/Web export presets.
- Asset survey and licensing docs, plus the beam/projectile cast previews that became the canon moves.
