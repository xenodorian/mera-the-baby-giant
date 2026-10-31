# Mera: The Baby Giant

A 2D **sword-and-sorcery action game with fighting-game mechanics**: chainable combos,
an input buffer, a super meter and supers, built in **Godot 4.7.2** with mostly free pixel-art assets.

## Vision
- Hack-and-slash in dark-fantasy stages (cemeteries, castles, haunted forests).
- Fighting-game feel: 3-hit strings, specials, air attacks, cancels, input buffer (≈6–10 frames),
  hit-stop, meter built on hit/damage, supers that spend meter.
- **Main character: Mera**, the merakintsugi Platformer Character Pack hero (purchased) — pastel, chibi, 3-hit/5-hit/dodge/vertical/jump attack sets.
- She **shapeshifts** into alternate forms drawn from **chierit Elementals** (Fire Knight, Water Priestess, Leaf Ranger, ...).
- Enemies, bosses, side characters, stages and VFX mainly from **ansimuz Gothicvania / Streets of Fight**, palette-tuned toward the hero.
- Lower priority: dynamic 2D lighting (Light2D / normal maps) and physics-driven props.

## Tech
| Item | Value |
|---|---|
| Engine | Godot **4.7.2** stable. On the shared box: `/workspace/tools/Godot_v4.7.2-stable_linux.x86_64` (export templates: `/workspace/tools/templates.tpz`) |
| Renderer | **Compatibility** (`gl_compatibility`) |
| Resolution | **native 1920×1080** viewport (1 game px = 1 screen px at 1080p), stretch `canvas_items`, aspect `keep`; sprites are scaled by whole integers in-scene |
| Pixel art | default canvas texture filter **Nearest**, 2D transform/vertex snapping on |
| Sprite scale | Mera is 55 px tall at 1x and size-shifts 1x–19x; Fire Knight reference at 6x; stage art at 5x; harmonise palettes toward the hero (see `docs/ASSET_DECISIONS.md`) |

Headless check:
```bash
/workspace/tools/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import
/workspace/tools/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --quit-after 5
```

## Mera scale test (current playable)
`scenes/stage.tscn`: ansimuz Cemetery at 5x, chierit Fire Knight idling at 6x as the size reference, and Mera
(idle / run_start / run / run_stop / run_turn, frames from `tools/export_mera_frames.py`).

| Key | Action |
|---|---|
| ←/→ or A/D | run (speed = 150 px/s × size) |
| ↑/↓ or W/S | Mera size 1x … 19x (pivots at her feet; 19x = 1045 px) |
| H | hurtbox / pivot debug outlines (hurtbox turns red on overlap) |
| F11 / Esc | fullscreen toggle / leave fullscreen, then quit (desktop) |

Export (templates in `~/.local/share/godot/export_templates/4.7.2.stable/`):
```bash
G=/workspace/tools/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path . --export-release "Windows Desktop" build/windows/Mera_Scale_Test.exe
$G --headless --path . --export-release "Web" build/web/index.html     # serve over http, e.g. python -m http.server
$G --headless --path . --export-release "Linux" build/linux/Mera_Scale_Test.x86_64
```
Test hooks (after `--`): `--scale=N --run=left|right --debug --shot=PATH --wait=FRAMES --autotest`.
The export filter lists the needed files explicitly (textures are loaded by path), so add new assets to
`export_files` in `export_presets.cfg` (or switch to preload) or they will be missing from builds.

## Layout
```
project.godot            Godot project (Compatibility renderer, pixel-art settings)
scenes/, scripts/        Game code (stage.tscn = Mera scale test, main scene)
export_presets.cfg       Windows (embedded pck), Web (no-threads), Linux presets
build/                   Export output (git-ignored)
assets/characters/<author>/<name>/   Working copies of character packs
assets/environments/<author>/<name>/ Backgrounds / tilesets
assets/vfx/<author>/     Effects
assets/sfx/, assets/music/
assets/_source/          Pristine original zips (Godot-ignored)
assets/_incoming/        Drop zone for newly found packs (Godot-ignored)
previews/                Review GIFs/sheets/lineups (Godot-ignored)
tools/                   Python preview/compat scripts (Godot-ignored)
docs/                    Decisions, credits, licenses (Godot-ignored)
```

## Getting started (any agent / machine)
```bash
git lfs install                # binary assets are in Git LFS — required!
git clone https://github.com/xenodorian/mera-the-baby-giant.git
```
Read `AGENTS.md` before committing. Credits: `docs/CREDITS.md`.
