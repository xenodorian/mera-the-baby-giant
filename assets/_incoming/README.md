# _incoming — asset drop zone

Drop newly found asset packs here (zips or folders), as-is.

- Don't unzip or rename; just drop the original download in.
- Add a line to `assets/_incoming/INBOX.md` (or tell an agent) with the source URL, price paid, and license.
- An agent will then: check the license, copy the pack into `assets/_source/` (pristine zip),
  extract a curated copy into `assets/characters|environments|vfx/<author>/<name>/`,
  add credits to `docs/CREDITS.md`, render previews into `previews/<author>/`, and remove nothing
  from here without your OK.

This folder has a `.gdignore`, so Godot won't import anything in it.
