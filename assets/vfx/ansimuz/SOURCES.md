# ansimuz VFX: sources and licences

All files here are by Luis Zuno (ansimuz) and are **CC0**: commercial use OK, no attribution required (we credit anyway).
The originals are copied unmodified from `assets/_source/ansimuz/Legacy Collection.zip`, whose licence is in
`docs/licenses/ansimuz-legacy-collection-CC0.pdf`. Effects built from them recolour copies in memory; the files here are never edited.

| Folder | Original in the Legacy Collection | Standalone release | Used by |
|---|---|---|---|
| `ground-explosion/` | `Assets/Explosions and Magic/Ground Explosion/` (9 frames, 112×128, 70 ms each per the Aseprite JSON) | the Legacy Collection itself: https://ansimuz.itch.io/legacy-collection | Mera's rear projectile impact, `tools/projectile_cast.py` (pick1 v4) |
| `explosions-pack/` (explosion-1-a … g) | `Assets/Explosions and Magic/Explosions Pack/` | https://opengameart.org/content/animated-explosions (CC0, `explosions-pack.zip`, downloaded 2026-10-30; its `license.txt` is saved as `explosions-pack/LICENSE-opengameart.txt`. Its spritesheets are pixel-identical to ours, e.g. `explosion-3.png` = `explosion-1-c/spritesheet.png`) and https://ansimuz.itch.io/explosion-animations-pack (CC0) | `explosion-1-a` (32×32 pop): Mera's small dodge-attack bolt impact, `tools/projectile_cast.py` (pick3 v2) |
| `enemydeath/`, `grotto-escape-2-fx/`, `hit/`, `warped-shooting-fx/`, `water-splash/` | Legacy Collection | — | not used yet |
