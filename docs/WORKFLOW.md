# Workflow: the v0.5+ staged plan

This is the working plan for the big request of 2026-10-31: level select, 4 large maps, input remap, earthquake, allies, enemy roster, and research-driven mechanics.
Every stage ends with a tested build, a Windows exe published as a GitHub **pre-release**, CHANGELOG notes, and an update to `docs/AI_HANDOFF.md`.

## Stages
| Stage | Content | Release |
|---|---|---|
| **S0** | This file and `docs/AI_HANDOFF.md` | docs only, merged to `main` |
| **S1** | Title/level-select menu with 4 levels; 4 large native maps (no looping strip, no blurred seams); input remap (lightning L2, Fury R2+L2, R1 freed for allies, barrier relocated); Down+Y earthquake (1 s quake, 5 s stun of grounded enemies, violent map-wide shake) | **v0.5-playable** ✅ |
| **S2** | Enemy roster, each using all its animations: minotaur (chierit), ogre, werewolf, wolf, hell hound, hell beast, demon, flying eye demon, death, nightmare, enemy ghost, fire skull, mutant toad, hell gato, skeleton, plus the boss dragon (all ansimuz). Distributed across levels 2-4. Enemies never scale in size or damage | **v0.6-playable** ✅ (+ telegraph standard, Y-in-bubble lightning) |
| **S3** | Colour-coded ally cards on levels 2-4 (Water Priestess, Leaf Ranger, Brawler Girl skin-recolor, Dancing Girl); R1 summon, with a picker when you hold several card types; priestess heal to 6x on a cooldown; ranger/brawler fight alongside; dancing girl distracts all non-boss enemies on screen | **v0.7-playable** |
| **S4** | From `docs/RESEARCH.md` (top-8 list): **(1)** impact pass: hit-stop, hit flash, sparks, SFX variance; **(3)** breakables (candles, urns, crates, chests) with drop tables; **(4)** explosive barrels (they pierce the Fire Knight's block) and falling chandeliers; **(5)** juggle rules: gravity scaling, wall/ground bounce, corpse toss; **(7)** a consistent telegraph standard (`AttackData`) across all enemies, folded into S2; **(8)** secret breakable walls hiding ally cards. #2 (input buffer/cancels) is done in v0.4. **(6)** parry = perfectly timed L2 barrier raise → counter window and bolt deflect (approved by the user); plus gore/gibs (CC0) and a shatter/debris sim for objects and enemies | **v0.8-playable** |

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

   Then smoke-test the Linux build under xvfb.
9. Commit, `git push -u origin <branch>`, `git lfs push origin <branch>`, `gh pr create --base main`, and `gh pr merge N --merge` (merge commit, never squash, never force-push).
10. Check again that the release does not exist, then:
    `gh release create vX.Y-playable --target main --prerelease --notes-file ... Mera_Playable_vX.Y_Windows.exe Mera_Playable_vX.Y_Linux.x86_64`
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

## Hard rules (from the user)
- Work on **copies** of assets. Never modify, move or delete originals or user uploads (`assets/_source`, `assets/_incoming`, scratch folders).
- Pixel art uses nearest-neighbour, integer scales.
- Canon animations stay; changed versions are new copies.
- Don't use zips for frames. No videos are required; screenshots are enough.
- Combos must stay responsive: every button commits on the frame it is read, chords convert retroactively (see `docs/CONTROLS.md`, Timing windows).
- Enemies don't scale with Mera, in size or in damage.
- The Windows exe is the deliverable (the web build was dropped).
