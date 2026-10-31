# Workflow: the v0.5+ staged plan

This is the working plan for the big request of 2026-10-31: level select, 4 large maps, input remap, earthquake, allies, enemy roster, and research-driven mechanics.
Every stage ends with a tested build, a Windows exe **and an Android APK (from v0.8)** published as a GitHub **pre-release**, CHANGELOG notes, and an update to `docs/AI_HANDOFF.md`.


## v0.9.7 (2026-10-31): three 100-rage attacks, enemies stay on Mera
R2 is Fury, L2+R2 is lightning, L1+R1+L2+R2 is the freeze slash (`_try_mark`). Each spends `FURY_COST` (100) through `start_fury` or `pay_rage`. The slash does not call `start_fury`. `monster._prey` is always Mera. `_distracted` includes bosses, and the dragon and the Fire Knight honor it too. Windows exe is `v0.9.7-playable`.

## v0.9.6 (2026-10-31): summons, controls, Windows exe
Brawler lands ahead of Mera and runs right (`march` is always +1). She stops to fight or at a wall / closed door. Non-bosses chase `game.brawler()`. Dancer walks ahead and dances for `DANCE_S` (5). Priestess heals on arrival and once as she leaves. L2 is the full bubble, L2+R2 is lightning, R2 alone is Fury and spends 100 rage. Summon portraits are cropped. Bolts damage breakables via `game.prop_at`. Potions play the heal at 4×. Windows exe is `v0.9.6-playable`.

## v0.9.5 (2026-10-31): every level ends
Cemetery stops after `Roster.KNIGHT_CAP` (5) Fire Knights. Woods and Town stop the empty-screen trickle once the waves are done, and the gate waits for a clear field. Caverns still waits on the dragon. The last clear returns to the menu. Windows exe is `v0.9.5-playable`.

## v0.9.4 (2026-10-31): mana, bubble timer, flat soak, one drop
Stamina is shown as mana. Small bubble lasts `CROUCH_BUBBLE_S` (3) with `bubble_dial.gd`, then drops. It subtracts 1 damage. The full bubble stops all damage. A button drops either bubble and performs the move. `enemy_loot_kind` rolls one drop; max mana and max rage are the 7% rows, both cap at 200. Windows exe is `v0.9.4-playable`.

## v0.9.3 (2026-10-31): parry knockback distances
Timed full-bubble parry: `PARRY_KNOCK_PX` 400 and `PARRY_STUN_S` 2. Timed crouch parry: `CROUCH_PARRY_KNOCK_PX` 200 and `CROUCH_PARRY_STUN_S` 1. Held full bubble, no parry window: `BARRIER_KNOCK_PX` 200, no stun. The slide is `shove()` / `knock_left` at `PARRY_KNOCK_SPEED`, not a velocity that lasts the whole stun. Bosses are not shoved. Windows exe is `v0.9.3-playable`.

## v0.9.2 (2026-10-31): crouch bubble
Holding Down raises a small free bubble. Within `PARRY_MS` of the crouch it parries like L2. After that it keeps 25% of each hit (`chip`) and does not knock her down. Windows exe is `v0.9.2-playable`. Linux and Android are still outstanding. Android `version/code` is 13. Tests: 411 pass.

## v0.9.1 (2026-10-31): queued list implemented, Windows exe published
PR #4 merged the Y-chain branch onto `main`. PR #5 merged the combat queue. The Windows exe is the GitHub release `v0.9.1-playable` (full release, not a pre-release), with `SHA256SUMS.txt`.
- t108u rising slash: windup 4× (`RSLASH_WINDUP_SPEED`), rise 2× speed and distance (`RSLASH_VY` -760, frames 7–11 still at 1×).
- t108u Start/Enter/F1 pauses the tree (`game.paused_play`); the HUD stays `PROCESS_MODE_ALWAYS` so Start resumes. Game Over still restarts.
- t103u swing parry: `atk1` / `jatk1`, `Tuning.SWING_PARRY_MS` 150. `enemy_shot.deflect` and `dragon_bolt.deflect` aim at the shooter or the nearest enemy.
- t103u melee parry slides the attacker `PARRY_KNOCK_PX` (400) via `shove()`, and stuns for `PARRY_STUN_S` (2 s). Bosses stay put.
- Player shot vs foe shot: both `explode` with damage off. Combo beam (`beam_world_rect`) and vertical beam destroy foe shots.
- Still not done: screenshots, Linux binary, Android APK. Android `version/code` is already 12. The release keystore is not in this checkout, so do not publish an APK signed with a different key.
- Y-chain (t99u / t101u) is on `main` via PR #4, including the `mark_slash.gd` export fix. Docs for those moves are in CONTROLS / GAME_RULES / CHANGELOG as of v0.9.1. Screenshots of the Y chain are still outstanding.
- Repo rulesets 26282516 (branches: creation, non-fast-forward, deletion) and 26282517 (tags: non-fast-forward, deletion, update) are active. Pushing to an existing branch is allowed. Creating a **new** tag is allowed. Do not move or delete a tag. Disabling a ruleset needs the owner's approval; re-enable it right after.

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
0. **Between updates:** after each change, update `CHANGELOG.md` and `docs/AI_HANDOFF.md` (and `README.md` when the current release changes), commit, and push before starting the next change. Do not leave work only on the machine. A published build is not done until its GitHub release exists and the download link is in those notes.
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
