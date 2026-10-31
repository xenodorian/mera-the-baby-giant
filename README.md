# Mera: The Baby Giant

A 2D **sword-and-sorcery action game with fighting-game mechanics**: chainable combos,
an input buffer, a super meter and supers, built in **Godot 4.7.2** with mostly free pixel-art assets.

## Current release: **v0.8.2-playable** (dragon bolts fly head-first and leave his mouth horizontally; v0.8.1: wing loop, flies around between lobs, no breath plume in the volley; on top of v0.8: impact pass, breakables, barrels, chandeliers, juggles, parry, secrets, dragon boss rework, first Android build)
- Download: GitHub → Releases → `v0.8.2-playable` (Windows `.exe`, Linux `.x86_64`, **Android `.apk`**, ARM phones/tablets, play with a gamepad). Notes: `CHANGELOG.md`. Plan: `docs/WORKFLOW.md`. For agents: `docs/AI_HANDOFF.md`.
- Branches:
  - `main` = the current playable game (v0.8).
  - `playable-level` = the playable-level development branch.
  - `beam-attack` = the canon beam/projectile cast work (already in `playable-level`/`main`).
  - `mera-scale-test` = v0.1.
- Controls: see `docs/CONTROLS.md` for the full table. In short (Xbox names, PS4 in brackets):
  - D-pad / left stick: move. Up: jump (in Fury: fly). Down: crouch.
  - A [✕] hold: run. **X [□]: attack**. **Y [△]: special**.
  - B [○]: back dodge (B then X: dodge attack, B then Y: fast quick fire). **B+Y: rising slash** (Y again: slam). A+Y: ground dash. In the air, X: jump attack, Y: aerial dash.
  - L1: potion. **L2 tap: lightning** (100 % rage), **L2 hold: barrier**. **Y in the bubble: lightning.** **L2+R2: Fury.** R1: summon an ally (cards). **Down+Y crouching: earthquake.**
  - Combos: X X X, X X hold X, X X Y, and **X X X Y beam**. Spells, dashes, the bubble and the beam use **stamina** (60, +1/s).
  - Keyboard (v0.8): arrows = d-pad, Z=A, X=B, A=X, S=Y, Q=L1, W=R1, 1=L2, 2=R2 (Fury = 1+2), Enter/F1 = Start.

### Clone and open
The code, scenes, tests, tools and docs are public. **The art, audio and source packs are not**: they live in the private repo `xenodorian/mera-assets`, mounted as a git submodule at `assets/`. That includes the main character, a purchased pack with a custom licence that may not be redistributed.
```bash
git lfs install                # binary files are in Git LFS: required!
# owner / collaborators with access to the private assets repo:
git clone --recurse-submodules https://github.com/xenodorian/mera-the-baby-giant.git
cd mera-the-baby-giant && git submodule foreach git lfs pull
```
Without access to `mera-assets`, the project opens but has no art or sound, so it can't run. Play the release builds instead: GitHub → Releases.
Open in **Godot 4.7.2 stable** (standard build, not .NET):
1. Project Manager → Import → choose `project.godot`.
2. Let it import.
3. Press F5 to play `scenes/game.tscn`.

Exporting needs the 4.7.2 export templates.

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

## Playable test level (current; releases v0.2-playable, v0.3-playable, v0.3.1-playable, v0.4-playable)
`scenes/game.tscn` (main scene): an endless looping cemetery where Mera fights Fire Knights one at a time; each one calls in up to two small Blue Knights. It uses all of her pack animations and the canon moves (quick fire, rear explosion, beam combo), plus potions, rage/Fury and flight.
Controls: `docs/CONTROLS.md`. Rules: `docs/GAME_RULES.md`. Mera's frames are baked by `tools/export_game_anims.py`.
```bash
G=/workspace/tools/Godot_v4.7.2-stable_linux.x86_64
$G --headless --path . -s tests/run_tests.gd                       # headless gameplay tests (v0.4: human-timing input replays, knights, stamina, aura)
$G --headless --path . --export-release "Windows Desktop" build/windows/Mera_Playable.exe
$G --headless --path . --export-release "Linux" build/linux/Mera_Playable.x86_64
source /home/box/.android-keys/release.env && $G --headless --path . --export-release "Android" build/android/Mera_Playable.apk   # see docs/AI_HANDOFF.md
```
Test/capture args (after `--`): `--size=N --rage=N --potions=N --fury --no-knight --debug --overlay --gallery=ANIM --demo --shots=PREFIX --at=F1,F2 --quit=F`.
The export list in `export_presets.cfg` is explicit (textures are loaded by path), plus the include filter for `anims.json`. Add new assets there.
Previews: `previews/playable/` (v0.2 screenshots, gameplay_demo.mp4/.gif) `previews/playable/v0.3/` (6x knight fight, off-screen beams and lightning, Fury flight/aura, dash/dodge, bubble + lightning in the bubble; `gameplay_v0.3.mp4`) and `previews/playable/v0.4/` (Blue Knights, block, particle aura, stamina HUD).
All tunables (input windows, stamina, knight numbers) live in `scripts/game/tuning.gd`.
Beams and lightning are tessellated at runtime (`scripts/game/seg_strip.gd`, `strike.gd`, `Mera._update_beam`).

## Mera scale test (v0.1, `scenes/stage.tscn`)
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
git lfs install                # binary files are in Git LFS: required!
git clone --recurse-submodules https://github.com/xenodorian/mera-the-baby-giant.git   # assets/ = private submodule
```
**History was rewritten on 2026-10-31** (the repo went public and the asset packs were moved out). Any clone made before that must be **re-cloned**: don't pull or push from an old clone, because it still contains the asset history.
Read `AGENTS.md` before committing. Credits: `docs/CREDITS.md`.
