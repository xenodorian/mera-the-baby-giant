# Workflow: the v0.5+ staged plan

This is the working plan for the big request of 2026-10-31: level select, 4 large maps, input remap, earthquake, allies, enemy roster, and research-driven mechanics.
Every stage ends with a tested build, a Windows exe **and an Android APK (from v0.8)** published as a GitHub **pre-release**, CHANGELOG notes, and an update to `docs/AI_HANDOFF.md`.


## PAUSED 2026-10-31 14:25 CDT (owner t107u: low usage). Branch `wip/v0.9.1-ychain`, NOT merged, NOT released
**Shipped already:** v0.9.0-playable (PR #3 merged). It has the in-game updater and the Credits screen. It is the full **Latest** release, so `v0.1-scale-test` is no longer Latest.
- Updater: done and tested.
  - 360 unit/E2E tests, plus `tools/updater_e2e.sh` against the real Linux export (bad checksum refused, swap+relaunch, offline).
  - Live check against the public API: "up to date".
  - **Untested on real Windows / Android devices.** The APK has REQUEST_INSTALL_PACKAGES and the same signer (versionCode 11).
- Credits: done.
- **Known v0.9.0 bug:** the export lists lacked `scripts/game/mark_slash.gd` (from PR #2), so the **marked slash is broken in the v0.9.0 builds**: `game.gd` load() fails ("rp_child null"). Fixed on this branch: added to all 3 presets, plus a test that every runtime script is exported. Ship v0.9.1 soon; v0.9.0 players get it through the updater.

**Done on this branch (commit 3fea497, 397 tests pass, 0 fail). Not yet in CONTROLS/GAME_RULES/CHANGELOG:**
- t99u-1: levels 2-4 each send 2 monsters from BEHIND, off-screen, walking in.
  - `Roster.BEHIND_WAVES = {1:[1,3],2:[1,3],3:[1,3]}`: the first walker of waves 1 and 3. Risers and turrets are skipped.
  - Code: `game._spawn_next(.., behind)`.
- t99u-2: the L2 bubble works in the air (`_special_air`). She keeps gravity and her vx momentum, stops on landing, and still blocks.
- t99u-3: Y chain (`mera._ychain_next`, `qf_chain` move, Tuning `YCHAIN_*`).
  - Y again fires a follow-up that replays quick fire from f12 and fires on f14 (= canon GIF frame 16; the first fires on f10 = GIF 12).
  - Window: presses since the Y that started the current shot, plus 220 ms grace after recovery.
  - YYYY = `beam_ender`, 20 stamina, exactly like XXXY.
  - YYY, L2 = pulse wave (`pulse_wave.gd`): knockback only, 3 stamina.
  - YYY, X = heal pose + vertical beam (`vbeam.gd`): 3 x size to airborne/flying enemies in the column, 12 stamina.
- t101u: Up+Y vertical quick fire, as a 67 ms chord in either order.
  - Y then Up: `_chord_convert`.
  - Up then Y: `_air_tick` undoes the fresh jump.
  - It plays the heal pose and fires the same bolt straight up (`Shot.up`).
  - Up, then Y more than 67 ms later = jump + aerial dash as before. Keyboard Up+S is tested.
- Still to do for these: screenshots/GIF of the Y chain, doc updates (CONTROLS, GAME_RULES, CHANGELOG), and a visual check of the f14 spawn point (-32,-41), the heal-pose tip (-15,-74) and the vbeam look.

**QUEUED, not started:**
- (t108u) Rising slash: make the windup 4x faster, and the vertical rise 2x faster and 2x the distance.
- (t108u) Start/Enter must actually PAUSE the game (freeze gameplay), not just bring up the controls.
- t103u (1) projectile parry. A timed basic attack (X, `atk1`/`jatk1`) whose hitbox meets an enemy projectile within about 150 ms of the hitbox going live reflects it at its shooter (or the nearest enemy), friendly and damaging. This includes dragon bolts, which need a `deflect()` like `enemy_shot.gd`.
- t103u (2) an L2 bubble parry of a melee attack also knocks the attacker back hard (plus the existing parry effects).
- Player/enemy projectile collisions: both explode, and beams destroy enemy projectiles.
- Then:
  - tests and docs for all of it;
  - bump `application/config/version` to 0.9.1 and Android `version/code` to 12;
  - export the 3 builds plus SHA256SUMS.txt;
  - release v0.9.1-playable as Latest (not pre-release, so v0.1 never becomes Latest again).
- Repo rulesets 26282516 (branches) and 26282517 (tags) block creating branches and tags. Disabling one briefly needs the owner's approval; re-enable it right after.

## Stages
| Stage | Content | Release |
|---|---|---|
| **S0** | This file and `docs/AI_HANDOFF.md` | docs only, merged to `main` |
| **S1** | Title/level-select menu with 4 levels; 4 large native maps (no looping strip, no blurred seams); input remap (lightning L2, Fury R2+L2, R1 freed for allies, barrier relocated); Down+Y earthquake (1 s quake, 5 s stun of grounded enemies, violent map-wide shake) | **v0.5-playable** ✅ |
| **S2** | Enemy roster, each using all its animations: minotaur (chierit), ogre, werewolf, wolf, hell hound, hell beast, demon, flying eye demon, death, nightmare, enemy ghost, fire skull, mutant toad, hell gato, skeleton, plus the boss dragon (all ansimuz). Distributed across levels 2-4. Enemies never scale in size or damage | **v0.6-playable** ✅ (+ telegraph standard, Y-in-bubble lightning) |
| **S3** | Colour-coded ally cards on levels 2-4 (Water Priestess, Leaf Ranger, Brawler Girl skin-recolor, Dancing Girl); R1 summon, with a picker when you hold several card types; priestess heal to 6x on a cooldown; ranger/brawler fight alongside; dancing girl distracts all non-boss enemies on screen | **v0.7-playable** ✅ |
| **S4** | From `docs/RESEARCH.md` (top-8 list): **(1)** impact pass: hit-stop, hit flash, sparks, SFX variance; **(3)** breakables (candles, urns, crates, chests) with drop tables; **(4)** explosive barrels (they pierce the Fire Knight's block) and falling chandeliers; **(5)** juggle rules: gravity scaling, wall/ground bounce, corpse toss; **(7)** a consistent telegraph standard (`AttackData`) across all enemies, folded into S2; **(8)** secret breakable walls hiding ally cards. #2 (input buffer/cancels) is done in v0.4. **(6)** parry = perfectly timed L2 barrier raise → counter window and bolt deflect (approved by the user); plus gore/gibs (CC0) and a shatter/debris sim for objects and enemies; Android APK builds; dragon boss rework (size = health, flight phases) | **v0.8-playable** ✅ |

Level 1 (cemetery, Fire Knight + Blue Knights, no ally cards) stays as it is, apart from being rebuilt as a large native map.

## Stage checklist
1. `git fetch`, then `git status`, `gh pr list --state all`, `gh release list`. Another worker may share `/workspace/mera-play`. **Never duplicate a publish.**
2. Branch from fresh `origin/main`: `git switch -c sN-topic origin/main`. Local `main` is checked out in another worktree, so don't `git switch main`.
3. Implement. Keep tunables in `scripts/game/tuning.gd`. Copy new runtime files into **both** presets' explicit file lists in `export_presets.cfg`.
4. Add or adjust tests in `tests/run_tests.gd`. Combo responsiveness tests (the human-timing replays) must stay green.
5. Run the full suite **in the background** (about 12-15 min), then poll the log:
   `(timeout 1800 $G --headless --fixed-fps 60 --path . -s tests/run_tests.gd > /tmp/t.log 2>&1; echo "EXIT $?" >> /tmp/t.log) &`
6. Take screenshots under xvfb into `previews/playable/vX.Y/` with a capture script (see `tests/shots_v04.gd`).
7. Update `CHANGELOG.md`, `README.md` (current release), `docs/CONTROLS.md`, `docs/GAME_RULES.md`, `docs/CREDITS.md` (new assets), and `docs/AI_HANDOFF.md`.
8. Export:
   - `$G --headless --path . --export-release "Windows Desktop" build/windows/Mera_Playable.exe`
   - `$G --headless --path . --export-release "Linux" build/linux/Mera_Playable.x86_64`
   - **Android (every version from v0.8):** `source /home/box/.android-keys/release.env && $G --headless --path . --export-release "Android" build/android/Mera_Playable.apk` (ARM only; bump `version/code` and `version/name` in the Android preset first). Check it with `aapt2 dump badging` (native-code must be only `arm64-v8a` `armeabi-v7a`).

   Then smoke-test the Linux build under xvfb.
9. Commit, `git push -u origin <branch>`, `git lfs push origin <branch>`, `gh pr create --base main`, and `gh pr merge N --merge` (merge commit, never squash, never force-push).
10. Check again that the release does not exist, then:
    `gh release create vX.Y-playable --target main --prerelease --notes-file ... Mera_Playable_vX.Y_Windows.exe Mera_Playable_vX.Y_Linux.x86_64 Mera_Playable_vX.Y_Android.apk`
11. Report: what shipped, release and exe links, screenshots, decisions, known issues.

## S4 constraints (from the research)
- Effects use `CPUParticles2D`, not GPU particles, on Compatibility, with NEAREST filtering.
- With native-code (GDExtension) add-ons, test the exported `.exe` too, not just the editor.
- Never install LimboAI and Beehave together.
- Avoid packs by Cyangmou, Elthen, Seliel/Mana Seed and RGS_Dev.
- **User decisions for S4 (t79u, 2026-10-31):**
  - **Yes** to all research recommendations, including the parry.
  - **Parry** = a perfectly timed barrier raise (L2 pressed within about 0.15 s before a hit lands): parry, then a counter window, and projectiles are deflected. No new button.
  - **Yes** to gore and gibs, using free CC0 gib packs.
  - **No paid packs:** skip Gothicvania Interiors and use free CC0 props.
  - **Shatter:** add a free (MIT/CC0) Godot 4 debris/fracture sim, so destroyed objects and enemies (for gore) shatter into pieces. Either sprite fracture into RigidBody2D shards or CPUParticles2D shards. It must work on the Compatibility renderer and in the Windows exe; prefer pure GDScript.
- Restore `Engine.time_scale` after hit-stop with an `ignore_time_scale` timer.

## Repository layout since 2026-10-31 (public code, private assets)
- `xenodorian/mera-the-baby-giant` is **public**: code, scenes, shaders, tests, tools, docs and gameplay screenshots (`previews/playable/`).
- `xenodorian/mera-assets` is **private**: everything under `assets/` (all art, audio and source packs, plus the app icon `_project/icon.png`) and the raw sprite-sheet previews (`_previews/`). It is a git submodule at `assets/`.
- **Changing an asset:** commit and push inside `assets/` first (to `mera-assets`), then commit the updated submodule pointer in the game repo.
- **Never** add art, audio or packs to the public repo, and never paste the purchased Merakintsugi sprites anywhere public. Screenshots and gameplay GIFs in `previews/playable/` are fine. Release binaries contain the packed art, which is a normal game distribution.
- The history was rewritten with `git filter-repo` to strip `assets/`, `icon.png` and the sprite-sheet previews from every commit. **Re-clone** after that date.

## Hard rules (from the user)
- Work on **copies** of assets. Never modify, move or delete originals or user uploads (`assets/_source`, `assets/_incoming`, scratch folders).
- Pixel art uses nearest-neighbour, integer scales.
- Canon animations stay; changed versions are new copies.
- Don't use zips for frames. No videos are required; screenshots are enough.
- Combos must stay responsive: every button commits on the frame it is read, chords convert retroactively (see `docs/CONTROLS.md`, Timing windows).
- Enemies don't scale with Mera, in size or in damage.
- The Windows exe is the deliverable (the web build was dropped).
