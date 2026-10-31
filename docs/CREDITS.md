# Credits & licenses

## Art
| Asset | Author | License | Requirement |
|---|---|---|---|
| Elementals: Fire Knight, Water Priestess, Leaf Ranger (free) | **chierit** — https://chierit.itch.io | CC-BY 4.0 | **Credit "chierit"** in the game credits or link the itch page. Edits + commercial use OK. Author asks: don't resell. |
| Minotaur (free) | **chierit** | verify on item page (assume same: credit "chierit") | Credit "chierit". |
| Legacy Collection (Gothicvania characters, environments, VFX) | **Luis Zuno (ansimuz)** — https://ansimuz.itch.io | CC0 | None (courtesy credit welcome). `docs/licenses/ansimuz-legacy-collection-CC0.pdf` |
| Ground Explosion and Explosions Pack VFX (Mera's spell impacts) | **ansimuz**: from the Legacy Collection; Explosions Pack is also at https://opengameart.org/content/animated-explosions | CC0 | None. `docs/licenses/ansimuz-legacy-collection-CC0.pdf`, `assets/vfx/ansimuz/SOURCES.md` |
| Gothicvania Cemetery | **ansimuz** | CC0 | None. `docs/licenses/ansimuz-gothicvania-cemetery-CC0.pdf` |
| Streets of Fight (Brawler Girl, Enemy Punk, stage); Brawler Girl skin recolored by this project | **ansimuz** | CC0 | None. `docs/licenses/ansimuz-streets-of-fight-CC0.pdf` |
| **Platformer Character Pack v1 (full, purchased $15 on 2026-10-30) — MAIN CHARACTER** | **Merakintsugi** — https://merakintsugi.itch.io/platformer-character-pack · merakintsugi77@gmail.com · x.com/merakintsugi77 | Custom (item page; no license file in the zip). Verbatim: "Available for both commercial and non-commercial projects. Do not resell or redistribute as game assets. They must be used only as part of a project. Credit/ Attribution is optional. Feel free to modify the assets as needed. Play around with it however you like. Use of these assets for AI training or NFT conversion is strictly prohibited." | Attribution optional (we credit anyway). **No resale/redistribution as assets; no AI training; no NFTs.** Keep this repo private. |
| Kira – Animated Pixel Art Swordswoman — **REJECTED, not used in the game** | **Sprite Kitchen** — https://spritekitchen.itch.io/kira-animated-pixel-art-swordswoman-pack | Custom (item page) | Personal + commercial game use; edits OK; credit appreciated, not required; **no resale/redistribution/sharing/uploading of the original files as a standalone pack, even modified**; don't claim the art as your own. Page discloses **AI-assisted graphics**. |

## Audio
| Asset | Author | License | Requirement |
|---|---|---|---|
| RPG Audio, Sci-fi Sounds, Impact Sounds (files listed in SOURCES.md) | **Kenney** (kenney.nl): https://kenney.nl/assets/rpg-audio, https://kenney.nl/assets/sci-fi-sounds, https://kenney.nl/assets/impact-sounds | CC0 | None (credit appreciated). `assets/sfx/kenney/SOURCES.md` |

## Made in this project
Procedural pixel art drawn by `tools/export_game_anims.py` and `tools/tess_spells.py` in the hero/explosion palette: the tessellating beam and lightning segments, the spherical barrier, the green potion flask, the red rage sphere and the quick-fire bolt. Also the looping cemetery strips (`tools/make_loop_bg.py`, built from ansimuz Gothicvania Cemetery copies with blurred seams).
The playable level also uses ansimuz **Grotto Escape 2 FX** `electro-shock.png`, recoloured to the warm palette by a shader (CC0, Legacy Collection), for the lightning impact.
The Fury flame aura (v0.4: CPU particles with a procedural flame-tongue texture, `Mera._make_flame`), the dash afterimages and the blue/blue-and-white stamina potions are made in this project too.
The **Blue Knight** is chierit's Fire Knight (CC-BY 4.0) recoloured at runtime by `shaders/knight_blue.gdshader`; the original sheets are not modified. Credit: chierit.

The v0.5 level maps (`assets/levels/`, built by `tools/build_levels.py`) are composed from copies of the ansimuz CC0 packs: Gothicvania Cemetery, Mist Forest Background, Night Town Background and Lava Background. The cobbled street in Moonlit Town and the exit gate are made in this project.

The v0.6 enemies come from copies of: ansimuz (CC0) Ogre, Werewolf, Wolf running cycle, Hell Hound, Hell Beast, Demon, Flying Eye Demon, Death, Nightmare, Enemy Ghost, Fire Skull, Mutant Toad, Grotto Escape 2 boss dragon, Gothicvania Cemetery hell-gato, skeleton and enemy-death; and chierit's Minotaur. `tools/build_roster.py` only reads them; wolf frames are cut from its sprite sheets into `assets/enemies/wolf/`.

## Suggested credits text
> Main character art: Merakintsugi (merakintsugi.itch.io).
> Alternate-form character art: "Elementals" series by chierit (chierit.itch.io), CC-BY 4.0.
> Environments, enemies and effects: ansimuz (ansimuz.itch.io), CC0.
> Sound effects: Kenney (kenney.nl), CC0.

## Repo note
This repo is **private**. Merakintsugi and Sprite Kitchen forbid redistributing the original files; chierit asks not to resell.
Do **not** make this repo public with `assets/` inside — move raw assets to a private location/submodule first.

## Tools
- Godot Engine 4.7.2 — MIT license (https://godotengine.org/license).
