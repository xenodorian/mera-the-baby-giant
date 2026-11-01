# Credits & licenses

## Art
| Asset | Author | License | Requirement |
|---|---|---|---|
| Elementals: Fire Knight, Water Priestess, Leaf Ranger (free) | **chierit** — https://chierit.itch.io | CC-BY 4.0 | **Credit "chierit"** in the game credits or link the itch page. Edits + commercial use OK. Author asks: don't resell. |
| Minotaur (free) | **chierit** | **CC-BY 4.0** (verified on the item page, https://chierit.itch.io) | Credit "chierit". |
| Legacy Collection (Gothicvania characters, environments, VFX) | **Luis Zuno (ansimuz)** — https://ansimuz.itch.io | CC0 | None (courtesy credit welcome). `docs/licenses/ansimuz-legacy-collection-CC0.pdf` |
| Monsters Creatures Fantasy (goblin, mushroom, skeleton, flying eye) — v0.10 | **LuizMelo** — https://luizmelo.itch.io/monsters-creatures-fantasy | CC0 | None (courtesy credit in the game) |
| Animated Monsters (zombie, skeleton, witch) — v0.10 | **Stealthix** — https://stealthix.itch.io/animated-monsters | CC0 | None (courtesy credit in the game) |
| Ground Explosion and Explosions Pack VFX (Mera's spell impacts) | **ansimuz**: from the Legacy Collection; Explosions Pack is also at https://opengameart.org/content/animated-explosions | CC0 | None. `docs/licenses/ansimuz-legacy-collection-CC0.pdf`, `assets/vfx/ansimuz/SOURCES.md` |
| Gothicvania Cemetery | **ansimuz** | CC0 | None. `docs/licenses/ansimuz-gothicvania-cemetery-CC0.pdf` |
| Streets of Fight (Brawler Girl, Enemy Punk, stage); Brawler Girl skin recolored by this project | **ansimuz** | CC0 | None. `docs/licenses/ansimuz-streets-of-fight-CC0.pdf` |
| Pixel Art Castle Tileset (parts 2/3: stone wall tiles, chandelier, chain, door, plank, flame) — v0.8 props | **rubberduck** — OpenGameArt | CC0 | None. Originals in `assets/_source/s4_free/`, cut by `tools/build_props.py` |
| Candles, oil lamp and eye with varied stands — v0.8 candles | **vk** — OpenGameArt | CC0 | None |
| Kings and Pigs (the box: crate, hit frame, 4 pieces; recoloured to wood brown) — v0.8 crate | **Pixel Frog** — https://pixelfrog-assets.itch.io/kings-and-pigs | CC0 | None |
| Red Oil Barrel and Exploding Red Oil Barrel — v0.8 explosive barrel | **Jimmy D. Journey** — itch.io | CC0 | None |
| Gore Blood Gibs Meat Chunks — v0.8 gibs and blood | **Reactorcore** — OpenGameArt | CC0 | None |
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

The v0.7 allies are copies of chierit's **Water Priestess** and **Leaf Ranger** (CC-BY 4.0: credit "chierit"), ansimuz's **Brawler Girl** (Streets of Fight, the skin-recolor version) and **Dancing Girl** (CC0). The cards and the picker are drawn in this project.

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

## Music
- **High Quality 8-bit / Chiptune Musics** by HydroGene — CC0. https://hydrogene.itch.io/high-quality-8-bit-musics
  Cemetery `07 MonsterVania #1`, mist `17 The Quiet Spy`, town `15 Rush Point`, caverns `02 Perilous Dungeon`.
- **Flowerbed Fields** by Zane Little Music — CC0. https://opengameart.org/content/flowerbed-fields-loop
  Sunlit Country. Credit is optional under CC0; the credits screen lists both packs.

**v0.8:** the urn, chest, lever and the cracks on the secret wall are drawn in this project (`tools/build_props.py`). The debris/shatter simulation (`scripts/game/debris.gd`) is written in this project (pure GDScript, no add-on). The **Dancing Girl** has a natural-skin recolour made in this project on copies (`tools/recolor_dancer_skin.py`: the exact 3-colour skin-ramp swap ansimuz used for the Brawler Girl skin-recolor version; the originals are untouched). The dragon's lobbed bolts reuse the ansimuz hell beast fireball (CC0), tinted. **v0.8.1:** the dragon's volley `spit` frames are copies of the ansimuz breath frames with the fire plume removed (`tools/build_dragon_spit.py`, `.../grotto-escape-2-boss-dragon/spit-nofire/`; the originals are untouched).



## In-game credits (v0.9)
The title menu has a CREDITS screen (`scripts/app/credits.gd`) listing every author above with license and link, plus Godot Engine (MIT, https://godotengine.org/license). Keep both lists in sync.
