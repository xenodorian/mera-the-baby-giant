# AI handoff: Mera, The Baby Giant

For any agent that picks this project up. Keep this file updated at the end of every stage.
_Last updated: 2026-11-01, v0.12.0. Level order is Sunlit Country, Misty Woods, Moonlit Town, Moonlit Cemetery, Infernal Caverns, Dragon's Lair. Country is index 0. Cemetery is index 3 (knights). Caverns are index 4 and have no boss. The dragon is `BOSSES[5]` on a 7200 px arena that reuses the lava art. Down+Y earthquakes whenever Down is held, including the same frame. R2 alone is the lightning chain. L2+R2 is Fury, and she is invulnerable while it lasts. Stages after the first stay locked until the previous one is cleared or a 200 gold key is bought.


## TASKS FOR THE NEXT AGENT (do these, then stop)

You are implementing a short list. Do not invent extra features. Do not add branch or tag rulesets. Do not create a branch. Commit straight to `main` and push. Moves that start locked (beam, earthquake, super earthquake, rear explosion, Fury, homing) are intentional. Do not unlock them. Do not change shop prices.

Work from current `origin/main`. Read the function before you edit it. After each task, update the matching test in `tests/run_tests.gd` if one fails. Do not delete unrelated tests.

### 1. Spawn cap

`scripts/game/roster.gd` has `MAX_ALIVE := 5`. `scripts/game/game.gd` `_manage_roster` does `if alive >= Roster.MAX_ALIVE: break`, so a stage stops spawning once five enemies are alive anywhere, including ones left behind. That is the bug.

Replace the check with a per-stage cap equal to every wave enemy that stage will place. Add this on `game.gd` and call it instead of `Roster.MAX_ALIVE`:

```
func _stage_cap() -> int:
    var n := 0
    var i := 0
    var wx := Roster.WAVE_FIRST
    while wx < map_w - Roster.BOSS_AT:
        n += int(Roster.WAVE_SIZES[i % Roster.WAVE_SIZES.size()])
        i += 1
        wx = Roster.WAVE_FIRST + float(i) * Roster.WAVE_EVERY
    return maxi(n, 1)
```

In the wave loop, `break` only when `alive >= _stage_cap()`. Do not bring back distance despawn. Leave the line that only erases invalid mobs.

### 2. Cemetery knights at three fixed points

Level index 3 is the cemetery. It is not in `Roster.LEVELS`. Knights are spawned by `_spawn_knight` and `_manage_knight` in `game.gd`. Today there is one `var knight`, placed next to the camera, and a new call frees the previous knight.

Change it so three Fire Knights can exist at once, at fixed fractions of the walkable map, and later kills refill those same points until `Roster.KNIGHT_CAP` (5) have been spawned. The exit stays locked until that quota is met and none are alive (`exit_locked` already checks `knights_spawned < Roster.KNIGHT_CAP or _knight_fight_live()`).

Do this:

1. Add `var knights: Array = []` next to `var knight`.
2. Add:

```
func _knight_points() -> Array:
    var lo := Levels.EDGE
    var hi := map_w - Levels.EDGE
    var span := hi - lo
    return [lo + span * 0.25, lo + span * 0.50, lo + span * 0.75]
```

3. Replace `_spawn_knight` with `_spawn_knight_at(x: float, spot: int)`:
   - Do not `queue_free` any existing knight.
   - `FireKnight.new()`, `setup(self, "fire")`, `position = Vector2(x, GROUND_Y)`, `facing = -1 if x > mera.global_position.x else 1`.
   - `k.set_meta("spot", spot)`.
   - `world.add_child(k)`, `knights.append(k)`, `knights_spawned += 1`.
   - Set `knight = k` so old code that reads the single variable still sees one of them.
4. Rewrite `_manage_knight`:
   - Drop dead entries from `knights` (`not is_instance_valid` or `not alive()`).
   - If `knights_spawned == 0`, call `_spawn_knight_at` once for each of the three points, spots 0, 1 and 2.
   - If `knights_spawned < Roster.KNIGHT_CAP`, find any spot in 0, 1, 2 that has no living knight and spawn the replacement at `_knight_points()[spot]`.
   - Never place a knight from `cam_x`.
5. `_knight_fight_live` returns true if any entry in `knights` is alive, or any blue knight is alive.
6. `finish_endpoint` must `queue_free` every knight in `knights`, then `knights.clear()` and `knight = null`.
7. Search `game.gd` for other `knight.queue_free()` that assume there is only one. Point them at the array.
8. Do not despawn knights or blues for being far away.

### 3. Super earthquake requires the normal earthquake

In `scripts/game/carry.gd` `_buy_move`, before taking gold, if `id == "super_quake"` and not `owns("earthquake")`, `return "order"`.

In `scripts/menu.gd` `_shop_buy`, the `"order"` note currently always says to buy the shorter summon time. If `what == "move:super_quake"`, set the note to `Buy the earthquake first.` Keep the summon-time note for `summon:` rows.

In `_shop_stat`, when the row is `move:super_quake` and not `Carry.owns("earthquake")`, return `needs earthquake` instead of `locked`.

### 4. Homing

`Carry.owns("homing")` is the unlock. It must steer every player projectile that flies.

Already set in `game.gd`: `spawn_bolt` and `spawn_bolt_up`. Also set `sh.homing = Carry.owns("homing")` in `spawn_fireball`.

In `scripts/game/shot.gd`:

- Bolt movement already uses `_home` when `homing` is true. Keep that.
- The hit box is still flat. In the bolt branch of `_physics_process`, when `homing` is true, replace the rect with one that covers the bolt along `heading`:

```
var vis := size * bulk
var reach := 5.0 * vis
var half := Vector2(absf(heading.x) * reach + 3.0 * vis, absf(heading.y) * reach + 3.0 * vis)
var r := Rect2(position - half, half * 2.0)
```

  When `homing` is false, keep the old `up` / horizontal rect.
- Fireballs (`kind == "fireball"`) currently follow a parabola and ignore `homing`. If `homing` is true, do not use that parabola. Move the fireball with the same `_home(delta) * speed()` step the bolt uses, and test the same expanded rect against enemies. Still explode when it hits an enemy or a prop, or when it leaves the screen (`absf(position.x - game.camera_x()) > 2200`). If `homing` is false, leave the parabola exactly as it is.

Do not set `homing` on enemy shots (`enemy_shot.gd`) or dragon bolts (`dragon_bolt.gd`). Do not home the pulse wave or the vertical beam. Those are not flying projectiles.

### 5. Dragon victory marks the stage cleared, in the pixel font

In `game.gd` `_start_dragon_victory`, set `cleared = true` and `over_t = 0.0` before `Carry.record_clear`. `_clamp_to_map` only pays clear gold when `not cleared`, so this stops a second payment if Mera is already on the exit. Keep the existing `record_clear` and the extra `DRAGON_GOLD`. Do not call `record_clear` anywhere else in the victory path.

Delete the `Label` in `_show_victory_card`. A `Label` uses Godot's default font. The game's pixel text is `ThemeDB.fallback_font`, drawn by `scripts/game/hud.gd` (`font = ThemeDB.fallback_font` in `_ready`, drawn in `_draw_ui`). The HUD node is `PROCESS_MODE_ALWAYS`, so it still draws while the tree is paused.

Add a flag `var victory_card := false` on `game.gd`. Set it true at the start of `_show_victory_card`. In `hud.gd` `_draw_ui`, if `game.victory_card`, draw `You Defeated the Cavern Dragon!` centered with `ui.draw_string(font, ...)`, size 64, color `Color(1.0, 0.82, 0.35)`, and the same black shadow the other HUD strings use (draw the string again 4 px down and right in black first). Center it in the 1920x1080 HUD, around y = 500. Keep the dim `ColorRect` and the timer that calls `_to_title`.

### 6. No summon cards lying in the level

Cards come only from destroying an object. `game.gd` `break_drop` is already 40% coin, 25% health potion, 25% mana potion, 10% card (`roll >= 0.90`). Do not change those numbers. Do not drop cards from enemies. Enemy loot stays the fury orb.

`_place_cards` already begins with `return`, so map cards are not spawned. Keep that. Delete the unreachable lines under that `return` so a later edit cannot place `Allies.CARDS` again. Search for `CARD.new` and `card_nodes.append`. Nothing in a level may spawn a card node.

Walls, doors and ledges stay. Do not make breaking one spawn a card. `reveal_secret` may keep clearing `hidden_by` if a card exists, but `_place_props` will not find one. Do not add a new card spawn there.

The test name `country, woods, town and caverns each hold one card per ally` only checks the `Allies.CARDS` table. Leave the table. Do not start calling `_place_cards` to satisfy it.

### Done when

- A wave still spawns while more than five enemies are alive, until `_stage_cap()` is reached.
- Cemetery starts with three Fire Knights at 25%, 50% and 75% of the walkable width, and a death respawns on that same point until five have spawned in total.
- Buying super earthquake with no earthquake returns `order` and does not take gold.
- With homing owned, bolts and fireballs turn toward an enemy and their hit box covers that turned shape. Without it, fireballs still arc.
- Killing the dragon sets `cleared` and the victory words use `ThemeDB.fallback_font` through the HUD.
- No card node is placed on a map. A broken crate can still roll a card at 10%.



## v0.9.6 status (2026-10-31)
All four allies stay `Allies.STAY_S` 60 s. The dancer walks to a point in front of Mera, dances for `DANCE_S` (5), then idles until the 60 s. `dancing()` is only that 5 s, which is what `game.dancer()` reports, so the lure ends with the dance.
The brawler chases the nearest enemy at a run (`_brawler_run`: walk frames at 2.2×, she has no run sheet). With no enemies she holds the right side of the screen, 200–400 px from the edge (`_brawler_hold`), and does not walk off it. `game.brawler()` is her while she is alive and not leaving. Enemies still chase Mera.
The priestess heals on arrival and once more when `age >= stay` (`_begin_heal`), then leaves. No repeating heal cooldown.
L1 while either bubble is up calls `_sip`: the potion is drunk and the bubble stays. Other buttons still drop it.
The standing drink (`_start_move("heal")`) and every other heal-pose move play one authored frame per rendered frame (`frame_for_frame` in `layered_anim.gd`). The size still lands on heal frame 7, about 0.12 s after the press.
Any projectile damages breakables through `game.prop_at`: player bolts and fireballs, ranger arrows, enemy shots, dragon bolts (the blast is an explosion).
L2 alone starts the barrier (`no_tap`, a short press is not lightning). L2+R2 calls `_try_lightning`. R2 alone, after `CHORD_MS`, calls `_try_fury`. `start_fury` subtracts `FURY_COST` (100) and does not clear the rest; `_fury_tick` no longer overwrites `rage`. The HUD bar during Fury is `fury_left / FURY_TIME`.
The ally picker and the map cards draw `Roster.frame_art`: the idle (or skip) pose cropped to the body box. That does not call `get_image()`, which is null in an export and used to fall back to the full sheet (a blank square). The HUD held-card icons use the same crop. Start no longer opens the controls list; it opens the pause menu in `hud.gd` (`pause_sel`). The controls list is only `--overlay`. Full-screen panels are drawn in a centered 1920×1080 design; the background and the dim cover `ui.size` / the menu control, so aspect `expand` does not leave a bare strip. The in-game bars stay at the top left so they do not sit on the touch pad.
**Between updates:** notate (`CHANGELOG.md`, this file, `README.md` if the current release changed) and push before the next change.
There are no branch or tag rulesets. Do not add any. Push to `main`. Do not create branches.

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

## Done
| Release | Content |
|---|---|
| v0.1-scale-test | Mera scale test |
| v0.2-playable | First playable cemetery level |
| v0.3 | 6x Fire Knight, off-screen tessellated beam/lightning, Fury flight tilt, bubble fit |
| v0.3.1 | Camera hard lock |
| **v0.9.0-playable** | First public-repo release. In-game updater (`scripts/app/updater.gd`, `docs/UPDATER.md`: GitHub releases API, size + SHA-256 from `SHA256SUMS.txt`, Windows/Linux swap-and-relaunch helper, Android system installer via the template's FileProvider), Credits screen + version on the title menu, marked slash (other agent's PR #2) (360 tests + `tools/updater_e2e.sh`) |
| **v0.8.2-playable** | Dragon bolts: fireball art mirrored so the blunt head leads (art faces left), horizontal launch from the measured mouth, gravity-only arc solve, lob spots keep Mera in front of the mouth (336 tests) |
| **v0.8.1-playable** | Dragon flight: user-picked 4-frame `fly` wing loop (breath 1,5,4,5 without fire, 11 fps), flies to 5 lob spots per phase (short/mid/long, both sides, on screen), arcs solved per distance; volley `spit` frames without the breath plume (331 tests) |
| **v0.8-playable** (S4) | Hit-stop/sparks/SFX variance, shatter + gore, breakables with smart drops, barrels + chandeliers, juggles + corpse launch, parry (timed L2), secrets (wall, lever door, ledge + crumbling plank), allies scale with Mera, dragon rework (19x size = health, 12/9/6/3 flight phases with lobbed bolts, +3 on a hit), Fire Knight 1/2 damage, dancer skin recolour, Android L2 fix, **Android APK builds**, PC keyboard layout, super earthquake (Down+Y at 100 % rage: impact frame, 2 s quake, 7 s stun, flat 2 to all, ground props destroyed) (323 tests) |
| **v0.7-playable** (S3) | Ally cards on levels 2-4, R1 summon + picker, Water Priestess (heal to 6x, 30 s cooldown), Leaf Ranger, Brawler Girl, Dancing Girl (non-boss enemies gather and hop), all ally animations used |
| **v0.6-playable** (S2) | 16-enemy roster on levels 2-4 with all animations, Infernal Dragon boss + locked exit, telegraph standard (knights too), Y-in-bubble lightning, demo on current controls |
| **v0.5-playable** (S1) | Level select + 4 large native maps (Cemetery, Misty Woods, Moonlit Town, Infernal Caverns; 19,200 px each, walls + exit gate), remap (L2 tap = lightning, L2 hold = barrier, L2+R2 = Fury, R1 = allies), Down+Y earthquake (1 s shake, 5 s ground stun) |
| **v0.4-playable** | Responsive combos (instant commit + retroactive chords), B+Y rising slash / B then Y fast quick fire, stamina, Fire Knight overhaul (all 14 anims, chase dash, block, bolt jumps, air chase), Blue Knights, particle Fury aura, human-timing input-replay tests (197 tests) |

## Left (see `docs/WORKFLOW.md`)
- v0.9.2 crouch bubble (free, 75% damage reduction, parries like L2 in the first 150 ms) is the current change. v0.9.1 gameplay is on `main` and in the Windows release `v0.9.1-playable`. Linux and Android builds are still outstanding. Ideas not yet requested: more props on level 1 (the user said leave it as is), a real-device check of the Android build with a gamepad (no ARM emulator on the box), touch controls (none yet: the APK needs a gamepad or keyboard).
- **Every new version must ship a Windows exe AND an Android ARM APK** (user rule since t80u).
- **Every release must also attach `SHA256SUMS.txt`** (`sha256sum` over all binaries); the in-game updater refuses a release without it. Before exporting:
  - bump `application/config/version` in `project.godot`;
  - bump the Android `version/code` (must increase, or Android refuses the update) and `version/name` in `export_presets.cfg`;
  - sign the APK with the same release keystore.
- Updater: `docs/UPDATER.md`. Test with `tools/updater_e2e.sh` (real Linux export against a fake API) and `MERA_UPDATE_API=<json url> <game> -- --update-selftest`.

## Repo split (2026-10-31): public code, private assets
- The game repo is public. `assets/` is the **private submodule** `xenodorian/mera-assets` (LFS). Clone with `--recurse-submodules`, then run `git submodule foreach git lfs pull`.
- History was rewritten (`git filter-repo --invert-paths --path assets/ --path icon.png --path icon.png.import --path previews/{merakintsugi,spritekitchen,chierit,ansimuz,beam,compat}/`). **Old clones and worktrees must be discarded and re-cloned.** A pre-rewrite mirror (all refs and LFS objects) is kept on the build box at `/workspace/backups/mera-pre-public-2026-10-31/`. Never delete it.
- The app icon moved to `res://assets/_project/icon.png` (project.godot and all three export presets).
- Asset edits: commit and push in `assets/` first, then commit the submodule bump. Tools that write into `assets/` (build_roster, build_props, recolor scripts) write into the submodule.
- `git-filter-repo` is installed on the box at `/workspace/tools/bin/git-filter-repo`.

## Pitfalls (learned the hard way)
- **Don't name a method `_set`** on a Node: it overrides `Object._set()` (the property setter hook) and breaks every property assignment. The updater uses `_state()`.
- **The Android template already opens files through its FileProvider:** `OS.shell_open("/abs/path.apk")` → `content://` + ACTION_VIEW. There is no need for a Gradle plugin to install an APK. It does need `REQUEST_INSTALL_PACKAGES`, which Godot 4.7 has **no** `permissions/<name>` checkbox for (an unknown key is silently ignored). It goes in `permissions/custom_permissions=PackedStringArray("android.permission.REQUEST_INSTALL_PACKAGES")`. Check with `aapt2 dump badging <apk> | grep permission`.
- **`export_presets.cfg` uses an explicit file list** (textures load by path). Every new runtime file (`.gd`, `.gdshader`, `.png`, `.json`) must be added to **all three** presets (Windows, Linux, Android), or the exported game silently misses it.
  - Never `grep` the file with broad patterns: the list is one enormous line.
  - Add entries with `sed`/python right after `"res://scripts/game/cam_rig.gd", `.
- **Git LFS:** PNG/GIF/WAV/ZIP/etc. go through LFS. After pushing, also run `git lfs push origin <branch>`. Commit `*.import` and `*.uid` files, but never `.godot/`.
- **Parallel workers** share `/workspace/mera-play`. One has committed and published from this working tree before.
  - Always `git fetch`, then check `git status`, `gh pr list --state all` and `gh release list` before publishing.
  - Never publish a release that already exists. Never force-push.
- **Local `main` is checked out in another worktree** (`/workspace/sorcery-brawler`; don't touch it). Branch with `git switch -c name origin/main`.
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
- **Concurrent agents:** others may push to this repo. Before branching and again before merging, run `git fetch` and check `gh pr list` and the recent branches, merge `origin/main` into your branch if it moved, and rerun the full suite on the merged result.
- **Previews:** the Read tool can show a stale image for a reused path. Write review images to new file names.

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
| git-filter-repo | a40bce548d2c (v2.47.0 script) at `/workspace/tools/bin/git-filter-repo` (used for the 2026-10-31 public split) |
| Godot export templates | `~/.local/share/godot/export_templates/4.7.2.stable/` (from `/workspace/tools/templates.tpz`) |
| git | system `/usr/bin/git` |
| git-lfs | 3.8.1, `/usr/local/bin/git-lfs` |
| gh (GitHub CLI) | 2.103.0, `/usr/local/bin/gh`, authenticated as `xenodorian` |
| Python | 3.13.5, with Pillow 13.0.0, numpy 2.5.4, scipy 1.18.1, imageio 2.38.1 |
| Xvfb / xvfb-run | 21.1.16 (screenshots and smoke tests) |
| ffmpeg | 7.1.5 (videos/GIFs, no longer required) |
| unzip | 6.0 |
| Aseprite | not installed; `tools/ase_info.py` and `tools/ase_render.py` read `.aseprite` files in Python |
| **OpenJDK 17** (Android export) | Eclipse Temurin 17 at `/workspace/tools/jdk17` (tarball `/workspace/tools/jdk17.tar.gz`, from api.adoptium.net). Debian trixie has no openjdk-17 package; don't use the system 21 |
| **Android SDK** (Android export) | `/workspace/tools/android`: cmdline-tools `latest` (commandlinetools-linux-13114758, zip `/workspace/tools/cmdtools.zip`), `platform-tools`, `build-tools;35.0.1` and `36.0.0`, `platforms;android-35` and `android-36` (Godot 4.7.2 targets SDK 36). Licences accepted. Install more with `JAVA_HOME=/workspace/tools/jdk17 /workspace/tools/android/cmdline-tools/latest/bin/sdkmanager --sdk_root=/workspace/tools/android "<pkg>"` |
| Godot Android templates | already in the 4.7.2 templates dir (`android_debug.apk`, `android_release.apk`, `android_source.zip`); the preset uses the prebuilt template (`gradle_build/use_gradle_build=false`), so no Gradle build is needed |
| Godot editor settings | `~/.config/godot/editor_settings-4.7.tres`: `export/android/java_sdk_path`, `android_sdk_path`, `debug_keystore` (+ user/pass) point at the paths here |
| **Keystores** (never commit to the public repo) | The v0.9.0 release keystore was not in this checkout. v0.10.0 is signed with a new key, alias `mera`, kept in the private `mera-assets` repo at `_keys/android/` (`mera-release.keystore` and `release.env`). Use those `GODOT_ANDROID_KEYSTORE_RELEASE_*` values for `--export-release "Android"`. A v0.9.0 install must be uninstalled once; later APKs signed with this key update in place. |
