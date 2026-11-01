## Current tasks

Read [TASKS.md](TASKS.md) on `main` before doing anything else. The same list is in `docs/AI_HANDOFF.md` under `TASKS FOR THE NEXT AGENT`. If that section is missing, you are not on live `main`.
Any note for another agent must be committed and pushed to `main` in the same turn. A local file does not count.

# Working on this repo (humans and agents)

Multiple agents share this repo. Keep it safe and mergeable.

1. **Never delete, move or overwrite the user's files.** Work on copies. Originals stay in `assets/_source/`
   and `assets/_incoming/`; recolors/edits go in a sibling folder (e.g. `brawler-girl/skin-recolor/`).
2. **Branch per task**: `git switch -c <agent-or-topic>/<short-task>` off up-to-date `main`. Open a PR, or
   fast-forward merge small doc/asset-only changes. Always commit straight to `main`.
3. **Pull before you push**: `git pull --rebase origin main` on your branch before pushing.
4. **Small, logical commits** with clear messages (`assets: add X`, `combat: input buffer`, `docs: ...`).
5. **Never rewrite shared history**: no `push --force` to `main`, no rebasing pushed commits, no `reset --hard` on shared branches.
6. **Never commit secrets** (tokens, `.env`, keys, passwords, purchase receipts). `.gitignore` blocks common ones.
7. **Git LFS** is required (`git lfs install`). PNG/GIF/ZIP/audio/aseprite/PSD/PDF go through LFS automatically (`.gitattributes`).
8. **Godot**: 4.7.2, Compatibility renderer. Commit `*.import` and `*.uid` files; never commit `.godot/`.
   Run `--headless --import` after adding assets and check for errors.
9. **New assets**: check the license first, add a row to `docs/CREDITS.md` and `docs/ASSET_DECISIONS.md`,
   keep the original zip in `assets/_source/<author>/`. Paid assets: never buy or sign up without the user's OK.
10. Keep assets at native 1:1 scale; scale the whole game by integers only.
