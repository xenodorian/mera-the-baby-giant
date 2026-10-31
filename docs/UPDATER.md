# In-game updater (v0.9)

`scripts/app/updater.gd` (autoload `Updater`) plus the title menu (`scripts/menu.gd`).

## What the player sees
- The title menu quietly checks once at launch. If a newer build exists, a gold banner appears under the level cards ("Update available: vX.Y.Z").
- Press **Down** to reach the bottom row: **CHECK FOR UPDATES** (it reads **UPDATE TO vX.Y.Z** when one is found) and **CREDITS**. Press **A** (Enter/Z, or a click) to open it.
- In the update panel: **A** downloads, then **A** again installs. **B** (Esc/X) closes it. A progress bar shows the download.
- With no network, a GitHub rate limit, or any HTTP error, the panel only shows a message ("Update check failed (no connection)."). The game never blocks or crashes.

## How it decides
- It calls `GET https://api.github.com/repos/xenodorian/mera-the-baby-giant/releases` with no token (public repo; 60 requests per hour per IP).
- It skips drafts but counts pre-releases. It takes the highest tag `vX.Y[.Z]-…` newer than `application/config/version` in `project.godot` that has an asset for this platform: `_Windows.exe`, `_Android.apk` or `_Linux.x86_64`.
- **Every release must attach `SHA256SUMS.txt`** (`sha256sum` format). The updater refuses a release without one. A download is accepted only if its byte size equals the release asset's size **and** its SHA-256 matches. Otherwise the file is deleted.

## How it installs
| Platform | Where the download goes | Install |
|---|---|---|
| Windows | `<exe name>.new` next to the running exe (falls back to `user://update/` if the folder isn't writable) | It writes `mera_update.bat` next to the exe and starts it with `cmd /c`, then the game quits. The .bat waits for the game's PID to exit, moves the new exe over the old one (copy+delete if move fails), relaunches it, and deletes itself. |
| Linux | same, `mera_update.sh` | same with `sh`: wait for the PID, `mv`, `chmod +x`, `exec` the new build. |
| Android | `user://update/<apk>` (app-internal files dir) | `OS.shell_open(path)`. Godot's Android template turns a file path into a `content://` URI with its own FileProvider (`<package>.fileprovider`, `files-path /` covers the app's files dir) and sends `ACTION_VIEW` with the APK mime type, so the system package installer opens. The preset sets `REQUEST_INSTALL_PACKAGES` + `INTERNET`. All releases are signed with the same keystore (`AI_HANDOFF` → Tools), so the APK **updates in place** and keeps the save. |

The first time, Android asks to allow "Install unknown apps" for the game. Allow it, go back, and press install again.

The plan was a custom Gradle plugin for the Android install. It wasn't needed: the stock template already ships the FileProvider and the ACTION_VIEW path (`GodotIO.openURI`), so the build stays on the prebuilt template (no Gradle).

## Testing
- Unit and E2E in `tests/run_tests.gd`, section `updater`: version parsing and ordering, release picking, SHA256SUMS parsing, the size+checksum gate deleting bad files, both helper scripts, offline handling, menu navigation, and the credits list.
- `tools/updater_e2e.sh` runs the **real exported Linux build** against a local fake releases API:
  - a bad checksum is refused and the old binary is kept;
  - a good one is swapped in after exit and relaunched;
  - offline gives a graceful error.
- `--update-selftest` (user arg) runs check → download → apply headless, printing `UPDATE-SELFTEST …`. `MERA_UPDATE_API=<url>` points the check at any releases JSON.
- **Manual (real releases):** install the previous version (v0.9.0 or later; v0.8.x has no updater), launch it, and use the banner or CHECK FOR UPDATES → A → A.
  - Windows: the game closes and reopens as the new version (the title menu shows the version bottom-right).
  - Android: the system installer opens and shows "Update"; the app keeps its data.
