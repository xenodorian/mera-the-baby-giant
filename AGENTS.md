# Working on this repo (humans and agents)

Multiple agents share this repo. Keep it safe and mergeable.

1. **Never delete, move or overwrite the user's files.** Work on copies. Originals stay in `assets/_source/`
   and `assets/_incoming/`; recolors/edits go in a sibling folder (e.g. `brawler-girl/skin-recolor/`).
2. **Commit straight to `main`.** Do not create branches, open pull requests, or add branch or tag rulesets.
3. **Pull before you push**: `git pull --rebase origin main`, then `git push origin main`.
4. **Small, logical commits** with clear messages (`assets: add X`, `combat: input buffer`, `docs: ...`).
5. **Never rewrite shared history**: no `push --force` to `main`, no rebasing pushed commits, no `reset --hard` on shared branches.
6. **Nothing is private** (owner decision, 2026-11-01): assets, purchased packs, receipts and the Android signing key (`assets/_keys/`) are all committed. Still do not commit GitHub or other service access tokens, or payment card details.
7. **Git LFS** is required (`git lfs install`). PNG/GIF/ZIP/audio/aseprite/PSD/PDF go through LFS automatically (`.gitattributes`).
8. **Godot**: 4.7.2, Compatibility renderer. Commit `*.import` and `*.uid` files; never commit `.godot/`.
   Run `--headless --import` after adding assets and check for errors.
9. **New assets**: check the license first, add a row to `docs/CREDITS.md` and `docs/ASSET_DECISIONS.md`,
   keep the original zip in `assets/_source/<author>/`. Paid assets: never buy or sign up without the user's OK.
10. Keep assets at native 1:1 scale; scale the whole game by integers only.
11. **Notes for the next agent** go in `docs/AI_HANDOFF.md`, committed and pushed to `main` in the same turn. Keep it free of open tasks: finished work is recorded in `CHANGELOG.md`.
12. **A finished prompt is a release.** When you have completed everything the owner asked for in a prompt (and the test suite is green), bump the version in `project.godot` (`config/version`) and `export_presets.cfg` (`version/name` and `version/code`), add the `CHANGELOG.md` entry, update the README release line, and push to `main`: that builds and publishes the exe and APK through GitHub Actions. Then confirm the release exists. Owner rule, 2026-11-03.
13. **Games are Godot projects.** Do not ship a game as HTML, React, or another web app. Build it in this project (Godot 4.7) and use the Controls autoload for keyboard, touch, and gamepad. Owner rule, 2026-11-05.
