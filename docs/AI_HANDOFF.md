# AI handoff: Mera, The Baby Giant

Dying on a level opens a death minigame only if `Carry.has_respawn()` (shop row "Respawn with minigame", 200 gold, saved as `respawn`). Otherwise `_death_bank()` shows game over and retries the stage from the start. A death never calls `Carry.reset()` or `_wipe_run()`. The minigame is picked at random: the Ambidex duel (`scripts/game/ambidex.gd`) or Soul Maze (`scenes/soul_maze.tscn`, `embedded` set before it enters the tree). Both sit on a CanvasLayer at layer 25 (`game._open_ambidex`), skipped when `test_mode` or headless. Win (`finished(true)`) calls `revive_here` at the death spot (Mera at 2x, Perry at a third of `hp_max`, 1.8 s invulnerable) and unpauses. Loss sets `over` and calls `to_menu()` (title screen, save kept). `duel.as_perry` is set from `mera.is_perry` before the node enters the tree, and then the duel draws `ambidex/art/perry-idle.png` and `perry-slash.png` instead of Mera. Esc pauses the duel only. In Soul Maze, B or Esc is a loss. Do not spawn either minigame from tests. Prompt names are `Controls.prompt_style()` (`user://prompt_style.txt`, not cleared by `Carry.reset()`): keyboard / Xbox / PlayStation on desktop, touchscreen / Xbox / PlayStation on Android. `Controls.faces()` and `Controls.button()` rewrite HUD, menu, chest, cutscene, puzzle and duel text. `Controls.scheme` is still the last real device and is not the prompt style. The duel does not ask Xbox or PlayStation.

## Stable fallback

`soul-maze-stable` is v0.26.6, commit `397321a`. That is the last build the player approved: the bench maze (or its mirror), Esc and B return to the title, and the game boots. If a later Soul Maze change fails, put `scripts/soul_maze/maze.gd` back to that tag and stop. Do not keep a rejected generator in the game. A shape packer was tried after that tag and rejected: the best connected boards still had 23 or more open 2×2 rooms. It is not in the game.

## Soul Maze
Soul Maze is a Godot scene: `scenes/soul_maze.tscn`, `scripts/soul_maze/game.gd`, maze generator `scripts/soul_maze/maze.gd` (`class_name SoulMazeBoard`). It is not on the title menu. With the respawn unlock, a death picks it or the Ambidex duel at random. Movement is the `left` / `right` / `up` / `down` actions, so arrows, the Android touch pad, the d-pad and the left stick all move. Start or `ui_accept` begins a run. Collecting every soul wins. A catch, or B or Esc, loses. One life. Fright lasts 3 seconds. Four soul fragments. The live maze is one of the six wall-bench drawings (or its horizontal mirror). A floor tile on the border is a tunnel to the floor tile straight across on the opposite edge (same column for top and bottom, same row for the sides). The ghost pen is stamped in the middle. Reapers are the full idle body in `soul_maze/art/reaper_0.png` through `reaper_7.png` (192×224). Mera's walk frames in that folder face left, the same as the idle, jump, and crouch rects from `assets/characters/merakintsugi/game/`. `_paint` mirrors her only when `face_right` is set, with `draw_texture_rect_region`. Never `get_image()` (null in an export). It is not an HTML page. `docs/soul-maze.html` is leftover and is not the game.

For any agent that picks this project up. Keep this file updated at the end of every stage.
_Stage 2 (levels index 6..10, see docs/STAGE2_PLAN.md): `Levels.STAGE2_FROM` = 6, `Levels.stage_of(i)`, `Roster.FINALE` ({5, 10}: the only bosses that end a stage with a victory card, `game._start_finale_victory`, text in `game.victory_text`), `Roster.NAMES` for the exit lock text; a level in both `Roster.LEVELS` and `Roster.BOSSES` locks its exit until waves are done, no trash lives and the boss is dead. The title menu has two pages (`menu.gd page_levels / page_of`). Cards and secrets for 6..10 are in `allies.gd` / `props.gd`. Stage 2 art: `tools/build_perry.py` (Perry Riposte creatures and Perry, from `assets/perry/source/`, into `assets/characters/perry/`), `tools/build_stage2.py` (the five maps; never run `tools/build_levels.py` without restoring levels.json after). Enemy AI options in `Roster.DEFS`: `pick` cycle / order, `hurt`, `death`, `shot_k`, `shot_tight`._

_Last updated: 2026-11-01, v0.12.2. Level order is Sunlit Country, Misty Woods, Moonlit Town, Moonlit Cemetery, Infernal Caverns, Dragon's Lair. Country is index 0. Cemetery is index 3 (three Fire Knights on fixed points at 25, 50 and 75 % of the map, five in total). Caverns are index 4 and have no boss. The dragon is `BOSSES[5]` on a 7200 px arena: killing it clears the stage, pays the clear gold plus 100, shows the title card and returns to the title screen. Nothing despawns for distance. The beam finisher, earthquake, super earthquake (needs the earthquake), rear explosion, Fury and homing shots are bought in the shop (page 2) and start locked. Stages after the first stay locked until the previous one is cleared or a 200 gold key is bought. Summon cards come only from breaking objects._


## Perry boss notes (Perry's Arena, index 11)
`perry_boss.gd` is a monster.gd subclass with its own `_physics_process`: states idle / move / tell / atk (a step of a move) / parry / heal / stun / dead, a move table in `Tuning.PERRY_BOSS_MOVES` (`h` handler: melee default, dash, sky, leap, burst, wave, meteor, quake, beam, taunt, guard; `steps` for strings of moves), frames and hit boxes read from `PerryPlayer.mdef(move)`. Her art is the roster `perry` entry (37 anims: the player frames under `assets/characters/perry/player/`); rebuild only that key with `python3 tools/build_perry_boss.py` (the extra anim list is `PERRY_BOSS_EXTRA` in `tools/build_roster.py`). Parry works inside `take_damage`: a melee kind whose `from_x` equals Mera's x is Mera's (allies pass their own x, so they are never parried); projectiles are caught by scanning `world` for `Shot` nodes each frame and swapping them for `perry_boss_fx.gd` `Reflect`. Mera has no stagger API, so `_stagger_mera` interrupts her and sets state hurt, and the knockback is a position slide done by the boss (`_shove_mera`). Tests may call `start_move(id)`, `_pb_idle`-style resets (`_abort_move`, `_to_idle_p`) and read `move_log`, `step_log`, `tell_log`, `phase_log`.

## Ally, bubble and Fury notes
Summoned allies stay `Carry.summon_s()` seconds: 30 s by default, or 60, 90 or 120 s once bought in the shop. The dancer walks to a point in front of Mera, dances for `DANCE_S` (5), then idles until the time is up. If she is about to leave the view she runs back to Mera and dances again. `dancing()` is only the dance, which is what `game.dancer()` reports, so the lure ends with the dance.
The brawler chases the nearest enemy at a run (`_brawler_run`: walk frames at 2.2×, she has no run sheet). With no enemies she holds the right side of the screen, 200–400 px from the edge (`_brawler_hold`), and does not walk off it. `game.brawler()` is her while she is alive and not leaving. Enemies still chase Mera.
The priestess heals on arrival and once more when `age >= stay` (`_begin_heal`), then leaves. No repeating heal cooldown.
L1 while either bubble is up calls `_sip`: the potion is drunk and the bubble stays. Other buttons still drop it.
The standing drink (`_start_move("heal")`) and every other heal-pose move play one authored frame per rendered frame (`frame_for_frame` in `layered_anim.gd`). The size still lands on heal frame 7, about 0.12 s after the press.
Any projectile damages breakables through `game.prop_at`: player bolts and fireballs, ranger arrows, enemy shots, dragon bolts (the blast is an explosion).
L2 alone starts the barrier (`no_tap`, a short press is not lightning). R2 alone is lightning (`_try_lightning`). L2+R2 is Fury (`_try_fury`), which needs the Fury unlock. `start_fury` subtracts `FURY_COST` (100) and does not clear the rest; `_fury_tick` no longer overwrites `rage`. The HUD bar during Fury is `fury_left / FURY_TIME`.
The ally picker and the map cards draw `Roster.frame_art`: the idle (or skip) pose cropped to the body box. That does not call `get_image()`, which is null in an export and used to fall back to the full sheet (a blank square). The HUD held-card icons use the same crop. Start no longer opens the controls list; it opens the pause menu in `hud.gd` (`pause_sel`). The controls list is only `--overlay`. Full-screen panels are drawn in a centered 1920×1080 design; the background and the dim cover `ui.size` / the menu control, so aspect `expand` does not leave a bare strip. The in-game bars stay at the top left so they do not sit on the touch pad.

## The project
- A Godot **4.7.2** 2D action game (Compatibility renderer, 1920×1080 native, nearest-neighbour pixel art). Repo: `xenodorian/mera-the-baby-giant` (public, Git LFS).
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
| `exit_gate.gd` | The exit pillar at the right end of each map (locked while a level boss lives) |
| `monster.gd` | v0.6: one data-driven script for all 16 roster enemies (duck-typed like the knights) |
| `roster.gd` | `Roster` class: enemy definitions, AttackData, which level gets which enemy, wave numbers |
| `telegraph.gd`, `tell_marker.gd` | `Telegraph` class: the tell colours, the pulse and the "!" marker, shared by every enemy |
| `enemy_shot.gd` | Enemy projectiles (the hell beast's fireball) |
| `allies.gd` | `Allies` class: ally numbers, colours, card spots per level, heal cooldown |
| `ally.gd`, `ally_arrow.gd` | v0.7 ally behaviour (all four) and the ranger's arrow |
| `ally_card.gd`, `ally_picker.gd` | The map cards and the R1 picker (a CanvasLayer that pauses the tree; `PROCESS_MODE_ALWAYS`) |
| `hit_stop.gd` | v0.8 autoload `HitStop`: freezes via `Engine.time_scale`, counts down per physics tick, `input_dt()` for Mera's clock |
| `debris.gd` | v0.8 shatter/debris sim (textured polygon shards in one `_draw`), spark and blood `CPUParticles2D` pools, gibs |
| `props.gd`, `prop.gd` | v0.8 prop kinds/numbers/layouts/secrets (`Props` data) and one prop node (breakables, barrel, chandelier, wall, lever, door, plank, ledge) |
| `dragon.gd`, `dragon_bolt.gd` | v0.8 Infernal Dragon boss (extends `monster.gd`): size = health, flight phases, lobbed bolts. The flight plays `fly` (4-frame wing loop) and lobs on `spit` (breath without the plume, `tools/build_dragon_spit.py`). Lob spots come from `_next_spot()` / `Tuning.DRAGON_FLY_SPOTS`. The ground breath is the roster attack and keeps the plume |
| `controls.gd` | autoload `Controls`: the input map in code, the Android trigger guard, and which device was used last (`scheme`: key / pad / touch). Numpad 1–9 is the right stick (5 = R3); only the top-row 1 and 2 are L2 and R2 |
| `mark_slash.gd` | R3 / numpad 5 / a screen tap at full meter or during Fury: freezes the world, marks every enemy on screen (1-9, repeated), one input slashes all with that number, unfreezes when all are entered |

- Level maps are built by `tools/build_levels.py` into `assets/levels/<id>/*.png`, `thumb.png` and `levels.json`. Re-run it after changing a level, then add any new PNG to the export list.
- Enemy art manifest: `python3 tools/build_roster.py` writes `assets/enemies/roster.json`: every frame path, its fps and loop, the pivot, and the opaque box of each frame. Hit boxes come from those boxes. Re-run it after changing an enemy pack, then add new frame paths to the export list.
- Mera's animation frames are baked by `tools/export_game_anims.py`. Spell segments: `tools/tess_spells.py`. Barrier fit: `tools/fit_barrier.py`.
- Docs: `docs/CONTROLS.md` (inputs and timing windows), `docs/GAME_RULES.md`, `docs/CREDITS.md`, `docs/WORKFLOW.md` (staged plan), and `CHANGELOG.md`.

## Releasing
- **GitHub builds and publishes the release.** `.github/workflows/build-release.yml` installs Godot 4.7.2, the export templates and the Android SDK, imports the project, exports the Windows exe and the Android APK, signs the APK with `assets/_keys/android/`, checks the APK version and signature, writes `SHA256SUMS.txt`, and creates the `vX.Y.Z-playable` release from the matching `CHANGELOG.md` section. It skips publishing when that release already exists. It runs on a push to `main` that changes `project.godot`, or by hand: Actions, build-release, Run workflow (untick `publish` to only build and keep the files as a 14-day artifact).
- To release: bump `application/config/version` in `project.godot`, and `version/code` (it must increase) and `version/name` in `export_presets.cfg` (the workflow fails if the two versions differ), add the `## vX.Y.Z-playable (date)` section to `CHANGELOG.md`, and push to `main`.
- The steps below are the same build done by hand, for a machine without GitHub Actions.
- Every release ships a Windows exe **and** an Android ARM APK, plus `SHA256SUMS.txt` (plain file names, `sha256sum` over both binaries). The in-game updater refuses a release without it.
- Before exporting, bump `application/config/version` in `project.godot`, and `version/code` (it must increase) and `version/name` in `export_presets.cfg`. Add the entry to `CHANGELOG.md`.
- Windows: `$G --headless --path . --export-release "Windows Desktop" build/windows/Mera_Playable.exe`.
- Android: load the signing values, point the keystore path at the key file in this repo (the path inside `release.env` is stale) (the path inside `release.env` is stale), then export:
  `set -a; . assets/_keys/android/release.env; set +a; export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$PWD/assets/_keys/android/mera-release.keystore; $G --headless --path . --export-release "Android" build/android/Mera_Playable.apk`
  Check the result with `aapt2 dump badging` and `apksigner verify`.
- Name the files `Mera_Playable_vX.Y.Z_Windows.exe` and `Mera_Playable_vX.Y.Z_Android.apk`, tag `vX.Y.Z-playable`, and attach both plus `SHA256SUMS.txt` to the GitHub release. Updater details: `docs/UPDATER.md` and `tools/updater_e2e.sh`.
- The keystore (alias `mera`) is in this repo at `assets/_keys/android/`, by the owner's decision. A v0.9.0 install must be uninstalled once; later APKs signed with this key update in place.

## Repository layout (assets merged into this repo, 2026-11-01)
- This repo is public and holds everything: the art, audio and source packs under `assets/` (Git LFS) and the Android keystore (`assets/_keys/android/`). The former private repo `xenodorian/mera-assets` is no longer used.
- History was rewritten once (2026-10-31) to strip `assets/` from old commits. Old clones and worktrees from before that date must be discarded and re-cloned.
- The app icon is `res://assets/_project/icon.png`.
- Tools that write into `assets/` (build_roster, build_props, recolor scripts) now write into this repo.

## Pitfalls (learned the hard way)
- The test suite reads `user://` saves. `_run` forces `Carry.character = "mera"` (in memory) so a saved Perry choice cannot change the Mera cases; `prop.gd touch_opens` is off except in the chest cases.
- **Don't name a method `_set`** on a Node: it overrides `Object._set()` (the property setter hook) and breaks every property assignment. The updater uses `_state()`.
- **The Android template already opens files through its FileProvider:** `OS.shell_open("/abs/path.apk")` → `content://` + ACTION_VIEW. There is no need for a Gradle plugin to install an APK. It does need `REQUEST_INSTALL_PACKAGES`, which Godot 4.7 has **no** `permissions/<name>` checkbox for (an unknown key is silently ignored). It goes in `permissions/custom_permissions=PackedStringArray("android.permission.REQUEST_INSTALL_PACKAGES")`. Check with `aapt2 dump badging <apk> | grep permission`.
- **`export_presets.cfg` uses an explicit file list** (textures load by path). Every new runtime file (`.gd`, `.gdshader`, `.png`, `.json`) must be added to **all three** presets (Windows, Linux, Android), or the exported game silently misses it.
  - Never `grep` the file with broad patterns: the list is one enormous line.
  - Add entries with `sed`/python right after `"res://scripts/game/cam_rig.gd", `.
- **Git LFS:** PNG/GIF/WAV/ZIP/etc. go through LFS. After pushing, also run `git lfs push origin main`. Commit `*.import` and `*.uid` files, but never `.godot/`.
- **`tools/build_levels.py` rewrites `assets/levels/levels.json` with only the four levels it builds** (cemetery, Misty Woods, Moonlit Town, Infernal Caverns) and drops Sunlit Country and the Dragon's Lair. After running it, `git checkout -- assets/levels/levels.json` and commit only the PNGs you meant to change.
- **Run `git lfs pull` before the first Godot import.** Importing while the art is still LFS pointer files makes Godot rewrite about 2,200 tracked `.import` files with `valid=false`, and every later import keeps them broken (audio and textures fail to load). Fix: `git checkout -- .`, delete `.godot/`, then `--headless --import` again.
- **Run headless tests with `--fixed-fps 60`.** The whole suite then takes about 10 s instead of about 15 min, because the game clock is game-time based (`Mera.now`).
  - Command: `$G --headless --fixed-fps 60 --path . -s tests/run_tests.gd`.
  - Without the flag, headless Godot runs physics in real time.
- **Don't name a method `_set`** (or `_get`): those are Object virtuals, and GDScript refuses the override. That's why `ally.gd` uses `_go()`.
- **Inferred types:** `var x := a if c else b` fails to parse when a branch is untyped (e.g. `-game.mera.facing`). Give it an explicit type.
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
- v0.8 balance: the Fire Knight deals **1** per normal hit and **2** for the special (user request t80u; was 2/3).
- **Android L2 bug (fixed in v0.8)**: on Android, Godot reports a digital L2/R2 as joypad **button 15/16** (`GodotInputHandler.java getGodotButton`: KEYCODE_BUTTON_L2 -> 15, R2 -> 16, SELECT/BACK -> 4, START/MENU -> 6) and analog axes **by device order** (`joystick.axes` sorted), then applies the SDL gamecontrollerdb mapping by GUID. A pad whose mapping puts L2 on Back/Start fired the shield and the gallery/controls overlay (text on screen). Fix: `controls.gd` binds 15/16 to l2/r2, a test asserts no two actions share a joypad button or axis direction and nothing else listens to a trigger, and `game.gd` defers joypad Start/Select by 6 physics frames and drops them when `Controls.trigger_near()` (trigger moved within +-6 frames or L2/R2 held). Keyboard is unaffected. Don't bind anything else to buttons 15/16 or axes 4/5.
- **Hit-stop vs `--fixed-fps`:** in fixed-fps runs the engine does NOT scale deltas by `Engine.time_scale`, and a hit landing mid-frame changes the scale after the frame's delta was handed out. So `HitStop` counts the freeze down per physics tick (real time) and samples "frozen" at the start of each physics frame (`process_physics_priority = -1000`); Mera's clock uses `HitStop.input_dt(delta)`. Don't go back to `delta / Engine.time_scale`.
- Props, the dragon and debris can `queue_free()` themselves in the same frame (chandelier on landing, broken walls, burst corpses): tests must `is_instance_valid()` before touching them. HUD code must not type a possibly-freed node (`var bs: Node2D = game.boss` crashed; now untyped).
- **Keyboard (v0.8, user t86u):** arrows/Z/X/A/S/Q/W/1/2 = d-pad/A/B/X/Y/L1/R1/L2/R2, all in `controls.gd MAP`. A, S, W, Q now mean pad buttons, so don't bring WASD movement back. Esc/F11 are read raw (`Controls.RAW_KEYS`); the input-map test fails if an action uses them or two actions share a key. The overlay table in `hud.gd CONTROLS` has [pad, keyboard, text] columns; keep them in sync.
- The dragon pack has no dedicated wing/flight animation. Since v0.8.1 the flight is the `fly` loop (breath frames 1,5,4,5 chosen by the user, plume-free copies, 11 fps) plus a lift tween and bob. Never fall back to the sped-up idle frames.
- `tools/make_loop_bg.py` created the old looping cemetery. It is superseded by large native maps from S1 on.

- **New `class_name` scripts** are only found after the global class cache is refreshed: run `$G --headless --path . --import` once after adding one. Otherwise you get "Identifier not declared".
- **Never `git stash -u` while the test suite is running.** It removes untracked assets (e.g. level PNGs) from disk for a moment, and the running tests can fail to load them.
- Add export entries with `python3 tools/add_export_files.py res://a res://b` (idempotent, every preset), or `--include "glob"` for the include filter.
- **Research constraints** (from `docs/RESEARCH.md`):
  - use `CPUParticles2D`, not GPU particles;
  - test the exported `.exe` when using GDExtension add-ons (Ropesim, LimboAI, Rapier);
  - never install LimboAI and Beehave together;
  - avoid Cyangmou, Elthen, Seliel/Mana Seed and RGS_Dev packs;
  - no paid packs (decided); the parry is approved as a timed L2 barrier raise;
  - restore `Engine.time_scale` after hit-stop with an `ignore_time_scale` timer.

- **Super earthquake (v0.8):** `mera._start_move("earthquake")` checks `can_lightning()` (full meter, not Fury, not draining). If true it calls `spend_rage()` + `game.super_earthquake()`, else `game.earthquake()`. The impact frame is counted per physics tick in `game._impact_tick()` (called at the top of `_physics_process`), *not* with timers, because `HitStop.impact()` sets `Engine.time_scale` near 0. When it ends, `_super_quake_go()` deals the damage, breaks the props and starts `quake_t` with `super_on`. `_quake_tick` reads `super_on` for the shake and stun totals. New damage kind `"quake"`: fire_knight lets it through the guard.

- **Baked-in effects in ansimuz frames:** the dragon `breath` frames contain the fire plume. Never reuse them for a different attack. Mask copies instead: the plume uses exactly 3 colours, (242,74,2), (255,141,7) and (255,214,133), found in no other dragon frame. After adding an anim in `tools/build_roster.py`, rebuild `roster.json`, run `--import` and add the PNGs to all three export presets.

- **Roster frame lists:** `tools/build_roster.py` accepts an explicit list of frame paths (repeats allowed) as well as a folder. The dragon `fly` loop uses this. The preview tool for the flight is `tests/shots_v081.gd`; pass `--gif=/abs/dir` to dump 960×540 frames at 20 fps, then assemble them with PIL. Run it with `--fixed-fps 60` so one rendered frame is one physics tick.

- **Check every sprite's native facing before rotating it to a velocity.** The ansimuz hell-beast fireball faces LEFT (blunt head at −x). `rotation = vel.angle()` alone flies it backwards. See `dragon_bolt.gd` `NATIVE_HEAD` / `_orient()`. The dragon also faces left natively (`native = -1`); world offsets measured on his art go through `facing == native` (see `mouth_pos()`).
- **Previews:** the Read tool can show a stale image for a reused path. Write review images to new file names.

## Tips
- Read `docs/CONTROLS.md` (Timing windows) before touching `mera.gd` input code. Run the human-timing replay tests after any input change.
- Add tunables to `tuning.gd`, not as magic numbers.
- For new enemies, copy the `FireKnight` pattern (AnimatedSprite2D frames built from PNG sheets at load, a per-frame reach table, hit windows, `take_damage(amount, from_x, kind) -> bool`). Use a shared base class from S2 on.
- Credit every new asset in `docs/CREDITS.md`. chierit is CC-BY 4.0 (credit "chierit"); ansimuz is CC0 but credited anyway.
- `MERA_TRACE=<frame>` env prints Mera animation changes. Game args after `--`: `--size=N --rage=N --potions=N --fury --no-knight --debug --overlay --gallery=ANIM --demo --shots=PREFIX --at=F1,F2 --quit=F`.

## Build tools
- Godot 4.7.2-stable (Linux binary) and the matching export templates in `~/.local/share/godot/export_templates/4.7.2.stable/` (from the official `Godot_v4.7.2-stable_export_templates.tpz`).
- Android export: OpenJDK 21 (the system Java works) and the Android SDK at `~/Android/Sdk` (`cmdline-tools/latest`, `platform-tools`, `build-tools;35.0.1` and `36.0.0`, `platforms;android-35` and `android-36`). `~/.config/godot/editor_settings-4.7.tres` points at both (`export/android/java_sdk_path`, `export/android/android_sdk_path`). The preset uses the prebuilt template (`gradle_build/use_gradle_build=false`), so no Gradle build is needed.
- The art is in this repo under `assets/` (Git LFS): `git lfs install`, clone, then `--headless --import`. The Android signing key is in `assets/_keys/android/`.
- Screenshots need `xvfb-run` and the OpenGL driver (see Pitfalls). Python 3 with Pillow and numpy runs the `tools/` scripts.

## Playable Perry (Stage 3 phase 3)
- **Switch:** `game.gd` creates `PerryPlayer` instead of `Mera` when `Carry.perry_selected()` (character "perry" and level index 10 cleared). `PerryPlayer extends Mera` and overrides `_ready`, `_physics_process`, `take_hit`, `hurt_rect`, `hit_rect`, `deal`, `set_size`, `scale_cap` and the Fury / bubble / mark stubs. Mera's input reading (`presses`, `held`, `forced`, `_find`) is reused, so tests drive her with `forced` like Mera. Never name `PerryPlayer` in `tests/run_tests.gd` code that compiles before the autoloads exist (it uses `Sfx` and `HitStop`): use `m.get("is_perry")`.
- **Art and data:** `tools/build_perry_player.py` cuts every move into `assets/characters/perry/player/<move>/<move>_<n>.png` and writes `assets/perry/perry_player.json` (per frame ms, root motion, `top`, attack boxes `hits` as pivot-relative pixel boxes, FX strips `*_fx`, beam tiles `beamtile_<kind>`). The chain moves come from `assets/perry/source/moves_extra.json`, the beams from `assets/perry/source/beams/`. Her runtime origin is the hurtbox centre (anchor + 35 px); `PerryPlayer._prepare` shifts the boxes to it. Scale is `Tuning.PERRY_SCALE` (2).
- **State machine:** `state` is Mera's (`ground`, `air`, `move`, `hurt`, `dead`); `pa` / `pk` / `pt` are the animation, frame and ms; a move is `mv` (`key`, `dmg`, `hits`). Chords are resolved by `_chords()` (also during the first 87 ms of a move, for retroactive conversion), single presses by `_single()`. A locked move never starts (`PerryUnlocks.has_move`).
- **Shop:** `menu.gd` shows two extra pages when Perry is unlocked; rows are `perry:<id>` and go through `Carry.buy` to `PerryUnlocks.buy`. The meteor shower has no attack boxes in the source data, so it (and the earthquake) hit every enemy on screen. The heavy kick is in the data but the original never sells it, so it is cut but unused.

## roster.json rebuilds
`tools/build_roster.py` rewrites `assets/enemies/roster.json` from scratch. After running it, re-run the merge tools in this order: `build_king_forms.py` (the three king forms; replaces build_nero.py), `build_ally_faces.py`, `build_perry_boss.py`, `build_wizards.py` (the three Craftpix wizards, p_firemage included; needs the git-ignored sheets in `assets/_source/craftpix_wizards/`). `build_firemage_bolt.py` is gone.

## State after v0.22.0 (2026-11-04)
Released v0.22.0: the nine Stage 4 painted levels (Levels.STAGE4_FROM 19..27, the Black Knight ends it at Levels.BLACK_KNIGHT = 27), the last stage (Warlord's Throne 28, Nerochilde's Court 29; `Levels.STAGE5_FROM`), the save migration (`Carry.LAYOUT_MIGRATIONS`), the menu pages, the Perry audit (jump crash and earthquake impact effects, kick boxes, 700 ms window, dash reach, taunt) and screen-filling supers drawn 2.5x (`Tuning.PERRY_SCREEN_FX_K`). 990 tests pass.

The tunnel map level (s4_tunnel, index 28, Levels.BLACK_KNIGHT) is built by `tools/build_tunnel.py` (source assets/_source/tunnel/tunnel_map.jpg): x15 nearest neighbour, a TALL level (levels.json "tall", "start", "exit", "boss_at", "spawns"; game.gd `tall`, `cam_y`, `_tall_spawns`; monster opts "floor_y"). Floors and ladders are derived from a brightness threshold, so they are approximate; the rock is a coarse grid in levels.json "solid" (90 px cells, "0" open / "1" rock) built by build_tunnel.py `collision_grid`; game.gd `solid_at`, `_hits_rock` and `_wall_body` push Mera, enemies and summons out of it each frame (v0.24.0). Hand-tune or add walls if the owner wants. Carry layout version is 2.

The Stage 4 floor rows (`floor_src` per scene in tools/build_stage4.py LEVELS) were fitted by eye against a thumb montage; scenes 6, 8 and 9 use x3. Enemy waves for 19..27 are in Roster.LEVELS, cards in Allies.CARDS.
The raw scenes are in assets/_source/stage4/ (the owner's art); tools that need git-ignored sources: build_wizards.py (assets/_source/craftpix_wizards), build_black_knight.py (assets/_source/black_knight), craft_kit.py (assets/_source/craftpix_platformer).
Disk in the scratchpad gets tight: delete old *_copy folders before running the suite.


## CRT filter (unreleased, 2026-11-12)
Optional full-screen CRT post effect, off by default. Shader: `shaders/crt.gdshader`, from https://www.spritecook.ai/blog/crt-shader-pixel-art (SpriteCook; the article states no explicit license). The game stays at 5× (1920×1080, native 384×216). `scripts/app/crt_overlay.gd` is a CanvasLayer at layer 8 (under victory cards at 10 and the HUD at 20) with a ColorRect sampling `hint_screen_texture`, treating each 5×5 screen block as one game pixel. Autoload `Settings` (`scripts/app/settings.gd`) persists `crt` in `user://mera_settings.json`; `Carry.reset` does not clear it. Toggle: pause menu row "CRT FILTER: ON/OFF" (clickable), and the title Options page (CONTROLS button) has a clickable / focusable CRT row. Android sets the shader `cheap` uniform (3×3 glow). Do not turn it on in tests that take screenshots unless that is the point; default is off. Preview shots: `previews/playable/crt/crt_off.png` and `crt_on.png` (xvfb, `tests/shots_crt.gd`).
