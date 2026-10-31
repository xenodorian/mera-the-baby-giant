# Asset decisions

_Last updated: 2026-10-30 18:45 (America/Chicago)._

## Art direction (decided 2026-10-30)
**Mera — the merakintsugi Platformer Character Pack hero — is the MAIN CHARACTER** of *Mera: The Baby Giant* (purchased by the owner, $15). Her signature mechanic is size-shifting (1x–19x).
Every other pack only supplies **shapeshifted alternate forms** (chierit Elementals), **enemies / bosses** and **side characters** (ansimuz).
Mixed packs are tuned toward the hero's look (pastel, chibi, coloured outlines) — see "Hero-anchored compatibility" below.

## Roles
| Pack | Author | License | Role |
|---|---|---|---|
| **Platformer Character Pack v1 (full, PURCHASED)** | merakintsugi | custom: commercial OK, no resale/redistribution, no AI training/NFT | **Main character.** `assets/characters/merakintsugi/platformer-character-pack/` (+ `INVENTORY.md`) |
| Elementals: Fire Knight, Water Priestess, Leaf Ranger (free) | chierit | CC-BY 4.0 | **Alternate (shapeshift) forms** of the hero |
| Minotaur (free) | chierit | verify on item page (assume credit "chierit") | Enemy / boss candidate |
| Legacy Collection (Gothicvania characters, environments, VFX) | ansimuz | CC0 | **Enemies, bosses, stages, VFX** (Ogre approved) |
| Gothicvania Cemetery | ansimuz | CC0 | Stage + enemies (skeleton, ghost, hell-gato) |
| Streets of Fight — Brawler Girl (**skin recolor**), Enemy Punk, stage | ansimuz | CC0 | **Side character** (Brawler Girl), enemy (Punk) |

Downloaded but not copied in: ansimuz Warped Caves; Legacy `TinyRPG/`, `Warped/`, `Misc/` (inside the Legacy source zip). Gothicvania Church: download failed, retry later.

## Rejected / struck
| Pack | Why |
|---|---|
| **Sprite Kitchen — Kira swordswoman** | **Rejected.** AI-assisted graphics (page disclosure); not palette pixel art (9,588 colours in one frame); ~3× too large (130–133 px body); idle drawn at 1.45× the scale of other animations; muddy when downscaled. Files kept in repo only as the evaluation record (`assets/characters/spritekitchen/`) — do not use. |
| CraftPix | Tengu sheathed-katana inconsistency; Vampire "dorky". |
| LuizMelo | Style disliked across characters. |
| willYEE | "Looks awful". |

## Main character — merakintsugi hero (full pack audit, 2026-10-30)
Source of truth = the `.aseprite` files (32-bit RGBA, layers + per-frame durations). Full table: `assets/characters/merakintsugi/platformer-character-pack/INVENTORY.md`.
Previews: `previews/merakintsugi/full/` (+ `audit.json`).

**Offensive / evasive animations** (frames · ms per frame · total)
| Group | Animation | Frames | Timing |
|---|---|---|---|
| 3-hit combo | 1x atk (10 atk + 7 to-idle) → 2x atk (10 atk + 9 short / 15 long recovery) → 3x atk | 17 · 25 · 34 | 40 / 40 / 35 ms (≈25–29 fps); chained 3-hit ≈2.0 s |
| 5-hit variation | 1x → 2x → 2x-1 (6) → 2x-2 (10) → vertical finisher (dodge atk 3x, 37) | 6 · 10 · 37 | 40 ms |
| Dodge-attack combo | back dodge → dodge atk 1x (16 + 3 to-idle) → dodge atk 2x (16; tags "from dodge atk 1" 0–7, "to jump status" 14–15) → vertical atk (dodge atk 3x, 37; fall loop 18–20) | 24 · 19 · 16 · 37 | 35 / 40 ms |
| Jump attacks | jump atk 1x · jump atk 2x | 9 · 8 | 40 ms · **100 ms** (deliberately heavy) |
| Mobility / evasive | back dodge (illusion trail) · aerial dash (+ `_pivoted`) · slide (spark + illusions) | 24 · 6 · 17 | 35 · 70 · 40 ms |
| Other | idle 10 (60 ms), walk 26 (2 from-idle + 24 cycle, 50 ms), run 20 + start 2 / stop 15 / turn 8, crouch 13, jump 24 (+ double jump fwd/vert 7+7, roll landing 9), hurt 34 (normal 12 / hard 24 hidden layer), healing 18, ladder 22, ledge 14, wall slide/jump 6, hit FX ×2 sheets | | 35–100 ms |

**Audit**
- ✅ **Baseline**: every grounded attack sits exactly on the idle foot line in every frame (0 px jitter) once canvases are aligned; 3x atk has an intentional −3…+1 px crouch/lunge.
- ✅ **Palette** consistent across animations (26-colour idle ramp; `#321d70` dark purple appears in all non-idle animations — part of the master palette). Only a stray blue `#2c42b2` (~205 px total) in 1x atk. FX use their own teal/white ramp.
- ✅ **Weapon** (short dark blade) consistent through all combos; no sheathed-weapon duplication.
- ⚠️ **FX clipped at canvas edges**: 3x atk fx01 cut flat at the bottom edge (frames 9–12, up to 17 px); jump atk 2x white arc cut at top/left (frames 1–8); aerial dash smoke 1 px at bottom (f6). Character pixels touch the right edge in 1x atk f3/f15/f16 (1–2 px, hair). Cosmetic; extend canvases in Aseprite if noticeable.
- ⚠️ **Canvases differ per animation** (64×64 idle … 224×288 vertical atk) and exported PNG sheets are **trimmed packed grids with no JSON** → you cannot slice them reliably by size. Use the `.aseprite` files (or `tools/ase_render.py`) and give every animation a feet-anchored pivot (offsets solved in `tools/mk_full.py`).
- ⚠️ **Root motion is baked into the canvases**: the body drifts forward (to the left) up to ~33 px (1x), ~58 (2x), ~78 (2x-2), ~74 (3x). Either keep it as visual lunge with a fixed collider or extract it into code-driven movement.
- ⚠️ 2x atk ships two recovery variants on separate layers (short delay visible, long delay hidden); hurt has normal (visible) vs hard hit (hidden) — export them separately.
- ℹ️ Faces **left** natively; no hitbox/hurtbox data, no docs, no license file in the zip; the free 64×96 portrait mentioned on the page is not in the zip.

## Hero-anchored compatibility — verdict: compatible with tweaks
Proofs: `previews/merakintsugi/full/hero_lineup_cemetery_viewport_x4_raw.png`, `…_harmonized.png`, `hero_vs_altforms_closeup_x4.png`, `hero_mock_fight_3hit_vs_ogre_cemetery.gif`.

| | Body px | Colours | Dark-outline share | Sat / Val (pixel-weighted) | Outline darks |
|---|---|---|---|---|---|
| **merakintsugi hero** | **55** (chibi, head+hair ≈ 1/3 of height) | 26 | 49 % | **0.63 / 0.65** | coloured: deep red `#580303`, purple `#2f1850`, navy `#1c154d` |
| chierit Fire Knight | 44 (realistic) | 10 | 54 % | 0.78 / 0.49 | dark red `#300f0a` |
| chierit Water Priestess | 37 | 9 | 34 % | 0.73 / 0.60 | navy `#1e1573` |
| chierit Leaf Ranger | 44 | 17 | 28 % | 0.70 / 0.49 | teal-black `#04303e` |
| ansimuz Brawler Girl (recolor) | 46 | 10 | 0 % | 0.62 / 0.65 | none (plum edge) |
| ansimuz Ogre | 58 | 8 | 34 % | 0.65 / 0.42 | **pure black `#000000`** |
| ansimuz Terrible Knight | 39 | 15 | 27 % | 0.66 / 0.50 | mixed |
| ansimuz Demon (boss) | 124 | 9 | 90 % | 0.64 / 0.24 | near-black purple |

**Tweaks (in priority order)**
1. **Keep everything at native 1:1** and integer-scale the 384×216 view (×5 = 1080p). No integer alternative exists (chierit ×2 = 88 px is double the hero; the hero can't go ×0.5). At 1:1 the hero (55 px) is the tallest humanoid, which suits a lead; Ogre (58) and Demon (124) still read as big threats.
2. **Palette harmonisation toward the hero** (palette-level remap, colour count unchanged, so pixels stay crisp): pull chierit forms to the hero's S/V — Fire Knight S ×0.88 / V ×1.19, Water Priestess S ×0.91 / V ×1.05, Leaf Ranger similar to Fire Knight; brighten ansimuz enemies (Ogre V ×1.33). Implemented in `tools/hero_lineup.py` (`palette_map`, 60 % blend). Brawler Girl recolor already matches the hero (0.62/0.65) — no change.
3. **Outlines**: the hero uses coloured selective outlines (deep red / purple / navy). Replace pure-black outlines (Ogre `#000000`, other ansimuz enemies) with the hero's navy `#151037`; chierit's dark-red/navy outlines already match the approach.
4. **Shapeshift transitions** should mask the proportion jump (chibi 55 px → realistic 37–44 px): use a 6–10 frame flash/smoke transform built from the hero's own FX (teal/white slash ramp, `hit fx`, slide smoke) so it reads as the hero's power, and keep the alt forms' palettes nudged toward the hero (step 2) plus one shared accent (e.g. the hero's teal FX colour on their slash trails).
5. **Timing**: the hero animates at 35–40 ms (≈25–29 fps), chierit at 100 ms (10 fps), ansimuz 100–500 ms holds. Keep each pack's native timing (proven in the mock fight), but consider playing chierit alt forms at 1.25–1.5× speed so they don't feel sluggish next to the hero.
6. Rim-light Water Priestess or brighten stage back layers on dark-purple nights (navy robe low contrast).
7. Let chibi-adjacent ansimuz pieces (Brawler Girl, Cemetery hero proportions) be the human side cast; keep realistic-proportion ansimuz monsters as enemies, where a proportion difference reads as "other".

## chierit × ansimuz compatibility (pre-hero baseline; still valid)
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

## Evaluation record: merakintsugi free sample (superseded by the purchase)
Free $0 tier = idle + walk sample only (kept in `assets/_source/merakintsugi/sample(idle&walk).zip`, previews in `previews/merakintsugi/sample/`).

## Evaluation record: Sprite Kitchen — Kira (REJECTED)
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
