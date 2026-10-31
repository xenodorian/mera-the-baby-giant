# AI handoff: Mera, The Baby Giant

For any agent that picks this project up. Keep this file updated at the end of every stage.
_Last updated: S1 (2026-10-31), v0.5-playable._

## The project
- A Godot **4.7.2** 2D action game (Compatibility renderer, 1920×1080 native, nearest-neighbour pixel art). Repo: `xenodorian/mera-the-baby-giant` (private, Git LFS).
- Main scene: `scenes/menu.tscn` (level select, `scripts/menu.gd`), which loads `scenes/game.tscn`. Any command-line user args skip the menu and go straight to the game. Key scripts in `scripts/game/`:

| File | What it does |
|---|---|
| `mera.gd` | Player: input buffer, combos, moves, stamina, Fury, flight, aura |
| `fire_knight.gd` | `FireKnight` class: the Fire and Blue variants and their AI |
| `game.gd` | Level, camera, spawning, pickups, spells, demo/capture args |
| `tuning.gd` | Every tunable: input windows, stamina, knight numbers |
| `hud.gd` | HUD bars and the controls overlay |
| `shot.gd`, `blast.gd`, `strike.gd`, `seg_strip.gd` | Spells |
| `layered_anim.gd` | Mera's layered animation player. `AnimLib` autoload loads `assets/characters/merakintsugi/game/anims.json` |
| `cam_rig.gd` | Camera X hard-locked on Mera, run after physics |
| `levels.gd` | `Levels` class: the level list from `assets/levels/levels.json`, the current level, map width, edges |
| `exit_gate.gd` | The exit pillar at the right end of each map |

- Level maps are built by `tools/build_levels.py` into `assets/levels/<id>/*.png`, `thumb.png` and `levels.json`. Re-run it after changing a level, then add any new PNG to the export list.
- Mera's animation frames are baked by `tools/export_game_anims.py`. Spell segments: `tools/tess_spells.py`. Barrier fit: `tools/fit_barrier.py`.
- Docs: `docs/CONTROLS.md` (inputs and timing windows), `docs/GAME_RULES.md`, `docs/CREDITS.md`, `docs/WORKFLOW.md` (staged plan), and `CHANGELOG.md`.

## Done
| Release | Content |
|---|---|
| v0.1-scale-test | Mera scale test |
| v0.2-playable | First playable cemetery level |
| v0.3 | 6x Fire Knight, off-screen tessellated beam/lightning, Fury flight tilt, bubble fit |
| v0.3.1 | Camera hard lock |
| **v0.5-playable** (S1) | Level select + 4 large native maps (Cemetery, Misty Woods, Moonlit Town, Infernal Caverns; 19,200 px each, walls + exit gate), remap (L2 tap = lightning, L2 hold = barrier, L2+R2 = Fury, R1 = allies), Down+Y earthquake (1 s shake, 5 s ground stun) |
| **v0.4-playable** | Responsive combos (instant commit + retroactive chords), B+Y rising slash / B then Y fast quick fire, stamina, Fire Knight overhaul (all 14 anims, chase dash, block, bolt jumps, air chase), Blue Knights, particle Fury aura, human-timing input-replay tests (197 tests) |

## Left (see `docs/WORKFLOW.md`)
- **S2:** enemy roster (16 enemies incl. the boss dragon, all animations) → v0.6.
- **S3:** ally cards + R1 summon picker + 4 allies → v0.7.
- **S4:** from `docs/RESEARCH.md` (top-8):
  - impact pass (hit-stop, flash, sparks, SFX variance);
  - breakables with drop tables;
  - explosive barrels and chandeliers;
  - juggle rules;
  - consistent enemy telegraphs (do it together with S2);
  - secret walls hiding ally cards.

  → v0.8.
- **User decisions for S4 (t79u, 2026-10-31):**
  - **Yes** to all research recommendations, including the parry.
  - **Parry** = a perfectly timed barrier raise (L2 pressed within about 0.15 s before a hit lands): parry, then a counter window, and projectiles are deflected. No new button.
  - **Yes** to gore and gibs, using free CC0 gib packs.
  - **No paid packs:** skip Gothicvania Interiors and use free CC0 props.
  - **Shatter:** add a free (MIT/CC0) Godot 4 debris/fracture sim, so destroyed objects and enemies (for gore) shatter into pieces. Either sprite fracture into RigidBody2D shards or CPUParticles2D shards. It must work on the Compatibility renderer and in the Windows exe; prefer pure GDScript.
- Levels 2-4 still spawn the Fire Knight until S2 adds the roster.

## Pitfalls (learned the hard way)
- **`export_presets.cfg` uses an explicit file list** (textures load by path). Every new runtime file (`.gd`, `.gdshader`, `.png`, `.json`) must be added to **both** presets, or the exported game silently misses it.
  - Never `grep` the file with broad patterns: the list is one enormous line.
  - Add entries with `sed`/python right after `"res://scripts/game/cam_rig.gd", `.
- **Git LFS:** PNG/GIF/WAV/ZIP/etc. go through LFS. After pushing, also run `git lfs push origin <branch>`. Commit `*.import` and `*.uid` files, but never `.godot/`.
- **Parallel workers** share `/workspace/mera-play`. One has committed and published from this working tree before.
  - Always `git fetch`, then check `git status`, `gh pr list --state all` and `gh release list` before publishing.
  - Never publish a release that already exists. Never force-push.
- **Local `main` is checked out in another worktree** (`/workspace/sorcery-brawler`; don't touch it). Branch with `git switch -c name origin/main`.
- **Headless test quirks:**
  - Long foreground runs get interrupted. Always run the suite in the background with output to a log, and poll it.
  - Test scripts must not reference `class_name`s whose scripts use autoloads (`Shot`, `Pickup`, `FireKnight`). The test script compiles before the autoloads exist, which breaks those classes for the whole run ("Nonexistent function 'new'"). Use `load("res://...").new()` and duck typing instead.
  - `--check-only` always reports missing autoloads; ignore that. Compile-check with `--headless --path . --quit-after 120`.
  - A member named `log` clashes with the builtin; use another name.
- **Input chord timing:** at 60 Hz a 50 ms human gap can read as 67 ms, so `CHORD_MS` = 67.
  - Chords must never delay the first button. Commit the move instantly and convert it within the window ("retroactive chord").
  - Record press **release times** (`presses[i]["rel"]`), so a hold that finished before the branch point still counts.
- **Test harness:** the human-timing generator must not press a button again while it is still held (it cuts the earlier hold 20 ms before the next press). Otherwise it fakes dropped inputs.
- **Screenshots** need a real GL context: `xvfb-run -a -s "-screen 0 1920x1080x24" $G --path . --rendering-driver opengl3 --resolution 1920x1080 -s tests/shots_vXX.gd`. Headless rendering is blank.
- **Particles:** use `CPUParticles2D` (GPU particles are unreliable on Compatibility). Set `local_coords = false` for world-space trails.
- With the requested numbers, a Fire Knight hit (2) kills a 2x Mera. This is intended, so don't "fix" it.
- `tools/make_loop_bg.py` created the old looping cemetery. It is superseded by large native maps from S1 on.

- **New `class_name` scripts** are only found after the global class cache is refreshed: run `$G --headless --path . --import` once after adding one. Otherwise you get "Identifier not declared".
- **Never `git stash -u` while the test suite is running.** It removes untracked assets (e.g. level PNGs) from disk for a moment, and the running tests can fail to load them.
- Add export entries with `python3 tools/add_export_files.py res://a res://b` (idempotent, both presets), or `--include "glob"` for the include filter.
- **Research constraints** (from `docs/RESEARCH.md`):
  - use `CPUParticles2D`, not GPU particles;
  - test the exported `.exe` when using GDExtension add-ons (Ropesim, LimboAI, Rapier);
  - never install LimboAI and Beehave together;
  - avoid Cyangmou, Elthen, Seliel/Mana Seed and RGS_Dev packs;
  - no paid packs (decided); the parry is approved as a timed L2 barrier raise;
  - restore `Engine.time_scale` after hit-stop with an `ignore_time_scale` timer.

## Tips
- Read `docs/CONTROLS.md` (Timing windows) before touching `mera.gd` input code. Run the human-timing replay tests after any input change.
- Add tunables to `tuning.gd`, not as magic numbers.
- For new enemies, copy the `FireKnight` pattern (AnimatedSprite2D frames built from PNG sheets at load, a per-frame reach table, hit windows, `take_damage(amount, from_x, kind) -> bool`). Use a shared base class from S2 on.
- Credit every new asset in `docs/CREDITS.md`. chierit is CC-BY 4.0 (credit "chierit"); ansimuz is CC0 but credited anyway.
- `MERA_TRACE=<frame>` env prints Mera animation changes. Game args after `--`: `--size=N --rage=N --potions=N --fury --no-knight --debug --overlay --gallery=ANIM --demo --shots=PREFIX --at=F1,F2 --quit=F`.

## Tools on the box (verified 2026-10-31)
| Tool | Version / path |
|---|---|
| Godot | **4.7.2-stable** Linux binary at `/workspace/tools/Godot_v4.7.2-stable_linux.x86_64` (download: `/workspace/tools/godot.zip`) |
| Godot export templates | `~/.local/share/godot/export_templates/4.7.2.stable/` (from `/workspace/tools/templates.tpz`) |
| git | system `/usr/bin/git` |
| git-lfs | 3.8.1, `/usr/local/bin/git-lfs` |
| gh (GitHub CLI) | 2.103.0, `/usr/local/bin/gh`, authenticated as `xenodorian` |
| Python | 3.13.5, with Pillow 13.0.0, numpy 2.5.4, scipy 1.18.1, imageio 2.38.1 |
| Xvfb / xvfb-run | 21.1.16 (screenshots and smoke tests) |
| ffmpeg | 7.1.5 (videos/GIFs, no longer required) |
| unzip | 6.0 |
| Aseprite | not installed; `tools/ase_info.py` and `tools/ase_render.py` read `.aseprite` files in Python |
