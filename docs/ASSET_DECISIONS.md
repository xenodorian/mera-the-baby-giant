# Asset decisions

_Last updated: 2026-10-30 (America/Chicago)._

## Approved
| Pack | Author | License | Why / content |
|---|---|---|---|
| Elementals: Fire Knight (free) | chierit | CC-BY 4.0 | User favourite. 1_atk 11, 2_atk 19, 3_atk 28, sp_atk 18, air_atk 8 frames (288×128 canvas, ~44 px body). |
| Elementals: Water Priestess (free) | chierit | CC-BY 4.0 | "Phenomenal". 1_atk 7, 2_atk 21, 3_atk 27, sp_atk 32, air_atk 8 (~37 px body). |
| Elementals: Leaf Ranger (free) | chierit | CC-BY 4.0 | Same series, bow + melee. 1_atk 10, 2_atk 15, 3_atk 12, sp_atk 17, air_atk 10 (~44 px body). Not yet reviewed by user. |
| Minotaur (free) | chierit | verify on item page (assume credit "chierit") | Same author; enemy/boss candidate. Not yet reviewed. |
| Legacy Collection — Gothicvania characters, environments, VFX | ansimuz | CC0 | Large enemy/boss/background library. User liked the Ogre. |
| Gothicvania Cemetery | ansimuz | CC0 | Cemetery stage + hero + skeleton / ghost / hell-gato. |
| Streets of Fight (Brawler Girl, Enemy Punk, stage) | ansimuz | CC0 | Brawler Girl: "extremely fluid"; approved **with the skin recolor** (`characters/ansimuz/brawler-girl/skin-recolor/`). |

Downloaded but not copied in: ansimuz Warped Caves (gun-only sci-fi), and the Legacy `TinyRPG/`, `Warped/`, `Misc/`
sub-collections (still inside `assets/_source/ansimuz/Legacy Collection.zip`). Gothicvania Church: download failed (itch SSL errors), retry later.

## Under evaluation (user to decide)
| Pack | Author | Status |
|---|---|---|
| Platformer Character Pack | merakintsugi | Free tier = **sample only** (idle + walk). Full pack needs **$15+**. Chibi proportions → weak style fit. |
| Kira – Animated Pixel Art Swordswoman | Sprite Kitchen | Free ($0 NYOP, full pack). **AI-assisted graphics** per the page. ~3× too large, not palette pixel art, idle drawn at a different scale. **Not recommended.** |

## Struck (do not use)
| Pack | Why |
|---|---|
| CraftPix | Tengu: sheathed katana stays visible while a short blade is swung. Vampire: "dorky". |
| LuizMelo | User disliked the style across Martial Hero / Hero Knight / Huntress. |
| willYEE | "Looks awful". |

## chierit × ansimuz compatibility — verdict: compatible with tweaks
Proofs: `previews/compat/`.

- **Scale**: same pixel scale. Body heights at native 1:1: Fire Knight 44, Leaf Ranger 44, Water Priestess 37 |
  Brawler Girl 46, Cemetery Hero 45, Terrible Knight 39, Skeleton 40, WereWolf 39, Mutant Toad 36, Hell Hound 24, Ogre 58, Demon 124 (boss).
  → **1:1 for both**, integer-scale the whole game (384×216 ×5 = 1080p). No ×1.25-type scaling (`previews/compat/noninteger_scaling_demo.png`).
  chierit frames are 288×128 with effect padding — anchor at the feet.
- **Style**: no anti-aliasing (0 semi-transparent px), small palettes (chierit 9–17, ansimuz 7–15 colours), 1 px selective coloured
  outlines (dark-edge share chierit 28–54 %, ansimuz 27–43 %), flat 2–3-step shading. chierit slightly more saturated (S 0.70–0.80 vs 0.60–0.66).
- **Motion**: both on 100 ms frames. chierit = uniform timing, 7–32 frames per attack; ansimuz = few frames with holds
  (Ogre attack 7 frames ≈1.5 s; Brawler kick 5 frames ≈1.1 s). Similar durations: fluid heroes vs heavy, telegraphed enemies.
- **Backgrounds**: chierit heroes sit well on Cemetery and Gothic Castle; Water Priestess's navy robe is low-contrast on dark-purple night.
- **Tweaks**: (1) native 1:1 + integer scaling; (2) optional −10 % saturation on chierit; (3) lighter rim for Water Priestess or brighter
  backdrops; (4) hit-flash/impact VFX + hit-stop on ansimuz enemy attacks; (5) Demon = boss tier.

## merakintsugi — Platformer Character Pack (evaluated 2026-10-30)
- https://merakintsugi.itch.io/platformer-character-pack — "Name your own price", min $0, suggested $2. The $0 tier gives only
  `sample(idle&walk).zip` (57 kB). Full `platformer character pack_v1.zip` (1.8 MB) requires **$15 USD or more** (not bought).
- One character (white-haired horned girl, short blade). Full pack: 3-hit + 5-hit combos (basic 1, 2, 2-1, 2-2, 3), jump attacks 1–2,
  dodge attacks 1–2, vertical attack, air dash, slide, back dodge, wall/ledge/ladder, hurt, heal, FX; aseprite with FX layers;
  promised free updates: parry, upward attack, pogo, death. "No generative AI was used."
- Free sample: idle 10 frames (46×55), idle→walk 2, walk 24 (45×58). **No attacks in the free tier.**
- Measured: 55 px tall, 26 colours, 49 % dark edge, S 0.63 / V 0.66, no anti-aliasing.
- Verdict: same pixel grid (1:1 works, outline/AA match) but **chibi/anime proportions** (head ≈ 1/3 of height) and a brighter pastel
  palette → **technically compatible, stylistically a weak fit**. Proofs: `previews/merakintsugi/`.

## Sprite Kitchen — Kira swordswoman (evaluated 2026-10-30)
- https://spritekitchen.itch.io/kira-animated-pixel-art-swordswoman-pack — "Name your own price", min $0 (suggested $5); the full
  `kira.zip` (8.1 MB) is free. Status "In development". **AI disclosure on the page: "AI Assisted — Graphics"** (tags include ai-generated).
- License: personal + commercial game use, edits/recolours OK, multiple projects OK, credit appreciated not required;
  **may not resell, redistribute, share or upload the original files as a standalone asset pack, even modified**. No AI-use ban.
- Content: 7 left-facing horizontal strips, 256×256 cells: idle 24, walk 24, run 16, jump 80, **sword attack/combo ("hit") 86**, hurt 77, death 64 (371 frames).
- Findings:
  - **Not palette pixel art**: 9,588 unique colours in a single idle frame (chierit/ansimuz: 7–17), painterly noise, no clean clusters (`kira_pixel_zoom_x8.png`).
  - **Size**: 130–133 px body in walk/run/attack/hurt/jump/death = **~3× chierit/ansimuz** (44 px).
  - **Idle drawn at a different scale**: 191 px body with feet 24 px lower than every other animation — she'd visibly "grow" when returning to idle (`kira_idle_vs_attack_scale_mismatch.png`). Needs idle rescaled/redrawn.
  - Attack frames touch the right cell edge (x=256) → slash effect may be clipped.
  - Strips up to 22,016 px wide; Godot 4.7 imports them, but wide textures may hit GPU limits (16,384) on some hardware — re-slice into grids before use.
  - Positives: long, flashy 86-frame combo with big slash arcs and an impact burst.
- Verdict: **not compatible** without a full redraw. Downscaling 1/3 gives the right height (42 px) but turns to mush
  (`style_closeup_kira_downscaled_x6.png`); at native size she's a giant. Only plausible as a separate HD-sprite game.
  Proofs: `previews/spritekitchen/`.
