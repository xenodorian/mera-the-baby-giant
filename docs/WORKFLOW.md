# Workflow

The rules for humans and agents are in `AGENTS.md`. This file is the process for a change and a pointer to the release steps. Release history is in `CHANGELOG.md`.

## Making a change
1. `git pull --rebase origin main`.
2. Implement. Keep tunables in `scripts/game/tuning.gd`. Copy every new runtime file (`.gd`, `.gdshader`, `.png`, `.json`) into all three presets in `export_presets.cfg` with `python3 tools/add_export_files.py res://path/to/file`.
3. Add or adjust tests in `tests/run_tests.gd`. The human-timing combo replays must stay green.
4. Run the tests in the background and poll the log, because the full suite is long:
   `(timeout 1800 $G --headless --fixed-fps 60 --path . -s tests/run_tests.gd > /tmp/t.log 2>&1 &)`
   The full suite is not clean today: it fails about two dozen older checks (size-cap defaults, the loot table, exit-walk tests that run into cracked walls and doors, the roster list, some bubble and Fury input checks) and stops at a script error near the end (around `tests/run_tests.gd` line 1465). Run the sections you touched on their own, and compare with a clean checkout before blaming your change.
5. Screenshots, when a change is visual: run under `xvfb-run` and save into `previews/playable/vX.Y/` (see `tests/shots_v04.gd`).
6. Update `CHANGELOG.md`, `README.md` (when the current release changes), `docs/CONTROLS.md`, `docs/GAME_RULES.md`, `docs/CREDITS.md` (new assets) and `docs/AI_HANDOFF.md`.
7. Commit in small logical steps, then `git push origin main` (and `git lfs push origin main` when LFS files changed). Do not leave work only on the machine.

## Releasing
The steps (version bump, Windows exe, Android APK, `SHA256SUMS.txt`, tag and GitHub release) are in the "Releasing" section of `docs/AI_HANDOFF.md`. A build is not finished until its GitHub release exists and the download links are in `CHANGELOG.md`.

## Technical constraints (from the research)
- Effects use `CPUParticles2D`, not GPU particles, on the Compatibility renderer, with nearest-neighbour filtering.
- With native-code (GDExtension) add-ons, test the exported exe as well as the editor.
- Never install LimboAI and Beehave together.
- Avoid packs by Cyangmou, Elthen, Seliel/Mana Seed and RGS_Dev. No paid packs.
- Restore `Engine.time_scale` after hit-stop with an `ignore_time_scale` timer.

## Hard rules (from the user)
- Work on **copies** of assets. Never modify, move or delete originals or user uploads (`assets/_source`, `assets/_incoming`, scratch folders).
- Pixel art uses nearest-neighbour and integer scales.
- Canon animations stay; changed versions are new copies.
- Do not use zips for frames. Screenshots are enough; videos are not required.
- Combos stay responsive: every button commits on the frame it is read, and chords convert retroactively (see `docs/CONTROLS.md`, Timing windows).
- Enemies do not scale with Mera, in size or in damage.
- The Windows exe and the Android APK are the deliverables.

## Repository layout
- `xenodorian/mera-the-baby-giant` is **public** and holds everything: code, scenes, shaders, tests, tools, docs, gameplay screenshots, and all art, audio and source packs under `assets/` (binary files in Git LFS).
- `xenodorian/mera-assets` is **private** and holds only the Android release keystore and its env file (`_keys/android/`). Never commit those, or any key, password or receipt, to this repo (`assets/_keys/` is gitignored).
- Do not add the rejected Sprite Kitchen pack (gitignored; its licence forbids redistribution).
- Changing an asset is a normal commit in this repo. Run `--headless --import` afterwards.
