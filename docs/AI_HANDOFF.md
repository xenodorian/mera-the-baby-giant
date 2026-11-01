# AI handoff: Mera, The Baby Giant

For any agent that picks this project up. Keep this file updated at the end of every stage.
_Last updated: 2026-11-01, v0.12.2. Level order is Sunlit Country, Misty Woods, Moonlit Town, Moonlit Cemetery, Infernal Caverns, Dragon's Lair. Country is index 0. Cemetery is index 3 (three Fire Knights on fixed points at 25, 50 and 75 % of the map, five in total). Caverns are index 4 and have no boss. The dragon is `BOSSES[5]` on a 7200 px arena: killing it clears the stage, pays the clear gold plus 100, shows the title card and returns to the title screen. Nothing despawns for distance. The beam finisher, earthquake, super earthquake (needs the earthquake), rear explosion, Fury and homing shots are bought in the shop (page 2) and start locked. Stages after the first stay locked until the previous one is cleared or a 200 gold key is bought. Summon cards come only from breaking objects._


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
| `mark_slash.gd` | Q+W+1+2 (L1+R1+L2+R2) at full meter or during Fury: freezes the world, marks up to 9 enemies, slash for a flat 3 |

- Level maps are built by `tools/build_levels.py` into `assets/levels/<id>/*.png`, `thumb.png` and `levels.json`. Re-run it after changing a level, then add any new PNG to the export list.
- Enemy art manifest: `python3 tools/build_roster.py` writes `assets/enemies/roster.json`: every frame path, its fps and loop, the pivot, and the opaque box of each frame. Hit boxes come from those boxes. Re-run it after changing an enemy pack, then add new frame paths to the export list.
- Mera's animation frames are baked by `tools/export_game_anims.py`. Spell segments: `tools/tess_spells.py`. Barrier fit: `tools/fit_barrier.py`.
- Docs: `docs/CONTROLS.md` (inputs and timing windows), `docs/GAME_RULES.md`, `docs/CREDITS.md`, `docs/WORKFLOW.md` (staged plan), and `CHANGELOG.md`.

## Releasing
- Every release ships a Windows exe **and** an Android ARM APK, plus `SHA256SUMS.txt` (plain file names, `sha256sum` over both binaries). The in-game updater refuses a release without it.
- Before exporting, bump `application/config/version` in `project.godot`, and `version/code` (it must increase) and `version/name` in `export_presets.cfg`. Add the entry to `CHANGELOG.md`.
- Windows: `$G --headless --path . --export-release "Windows Desktop" build/windows/Mera_Playable.exe`.
- Android: load the signing values, point the keystore path at the key file (first copy `_keys/android/` from the private `xenodorian/mera-assets` repo to `assets/_keys/android/`) (the path inside `release.env` is stale), then export:
  `set -a; . assets/_keys/android/release.env; set +a; export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$PWD/assets/_keys/android/mera-release.keystore; $G --headless --path . --export-release "Android" build/android/Mera_Playable.apk`
  Check the result with `aapt2 dump badging` and `apksigner verify`.
- Name the files `Mera_Playable_vX.Y.Z_Windows.exe` and `Mera_Playable_vX.Y.Z_Android.apk`, tag `vX.Y.Z-playable`, and attach both plus `SHA256SUMS.txt` to the GitHub release. Updater details: `docs/UPDATER.md` and `tools/updater_e2e.sh`.
- The keystore (alias `mera`) is the one file not in this repo: `assets/_keys/` is gitignored and the key lives in the private `xenodorian/mera-assets` repo under `_keys/android/`. A v0.9.0 install must be uninstalled once; later APKs signed with this key update in place.

## Repository layout (assets merged into this repo, 2026-11-01)
- This repo is public and holds everything except the Android keystore (art, audio and source packs under `assets/`, Git LFS). The private repo `xenodorian/mera-assets` now holds only the keystore (`_keys/android/`).
- History was rewritten once (2026-10-31) to strip `assets/` from old commits. Old clones and worktrees from before that date must be discarded and re-cloned.
- The app icon is `res://assets/_project/icon.png`.
- Tools that write into `assets/` (build_roster, build_props, recolor scripts) now write into this repo.

## Pitfalls (learned the hard way)
- **Don't name a method `_set`** on a Node: it overrides `Object._set()` (the property setter hook) and breaks every property assignment. The updater uses `_state()`.
- **The Android template already opens files through its FileProvider:** `OS.shell_open("/abs/path.apk")` → `content://` + ACTION_VIEW. There is no need for a Gradle plugin to install an APK. It does need `REQUEST_INSTALL_PACKAGES`, which Godot 4.7 has **no** `permissions/<name>` checkbox for (an unknown key is silently ignored). It goes in `permissions/custom_permissions=PackedStringArray("android.permission.REQUEST_INSTALL_PACKAGES")`. Check with `aapt2 dump badging <apk> | grep permission`.
- **`export_presets.cfg` uses an explicit file list** (textures load by path). Every new runtime file (`.gd`, `.gdshader`, `.png`, `.json`) must be added to **all three** presets (Windows, Linux, Android), or the exported game silently misses it.
  - Never `grep` the file with broad patterns: the list is one enormous line.
  - Add entries with `sed`/python right after `"res://scripts/game/cam_rig.gd", `.
- **Git LFS:** PNG/GIF/WAV/ZIP/etc. go through LFS. After pushing, also run `git lfs push origin main`. Commit `*.import` and `*.uid` files, but never `.godot/`.
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
- The art is in this repo under `assets/` (Git LFS): `git lfs install`, clone, then `--headless --import`. The Android signing key is not in git: copy `_keys/android/` from the private `xenodorian/mera-assets` repo to `assets/_keys/android/`.
- Screenshots need `xvfb-run` and the OpenGL driver (see Pitfalls). Python 3 with Pillow and numpy runs the `tools/` scripts.
