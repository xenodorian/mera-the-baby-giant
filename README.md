# Sorcery Brawler

A 2D **sword-and-sorcery action game with fighting-game mechanics**: chainable combos,
an input buffer, a super meter and supers, built in **Godot 4.7.2** with mostly free pixel-art assets.

## Vision
- Hack-and-slash in dark-fantasy stages (cemeteries, castles, haunted forests).
- Fighting-game feel: 3-hit strings, specials, air attacks, cancels, input buffer (≈6–10 frames),
  hit-stop, meter built on hit/damage, supers that spend meter.
- Heroes from **chierit Elementals** (Fire Knight, Water Priestess, Leaf Ranger, ...),
  enemies/bosses/backgrounds mainly from **ansimuz Gothicvania**.
- Lower priority: dynamic 2D lighting (Light2D / normal maps) and physics-driven props.

## Tech
| Item | Value |
|---|---|
| Engine | Godot **4.7.2** stable. On the shared box: `/workspace/tools/Godot_v4.7.2-stable_linux.x86_64` (export templates: `/workspace/tools/templates.tpz`) |
| Renderer | **Compatibility** (`gl_compatibility`) |
| Base resolution | 384×216 viewport → 1920×1080 window, stretch `viewport`, scale mode **integer** |
| Pixel art | default canvas texture filter **Nearest**, 2D transform/vertex snapping on |
| Sprite scale | All packs used at **native 1:1** (see `docs/ASSET_DECISIONS.md`) |

Headless check:
```bash
/workspace/tools/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --import
/workspace/tools/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --quit-after 5
```

## Layout
```
project.godot            Godot project (Compatibility renderer, pixel-art settings)
scenes/, scripts/        Game code (main.tscn is a placeholder)
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
git clone https://github.com/xenodorian/sorcery-brawler.git
```
Read `AGENTS.md` before committing. Credits: `docs/CREDITS.md`.
