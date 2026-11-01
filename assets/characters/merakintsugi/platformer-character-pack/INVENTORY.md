# merakintsugi Platformer Character Pack v1 — inventory

Purchased by the project owner ($15, itch.io, 2026-10-30). Source zip: `assets/_source/merakintsugi/platformer character pack_v1.zip` (SHA-1 4fe27a80…).
No license file, docs, hitbox/hurtbox data, JSON frame data or Godot resources are included — license text lives on the itch page (see `docs/CREDITS.md`).
All `.aseprite` files are 32-bit RGBA. Exported PNG sheets are **packed grids of trimmed cells with no metadata** (cell size differs from the .aseprite canvas and between sheets) — slice from the .aseprite sources (`tools/ase_render.py`) or re-export with Aseprite CLI + JSON.
Character faces **LEFT** natively (flip_h for right-facing). Timings below are the per-frame durations stored in the .aseprite files.

| Animation file | Frames | Canvas (px) | ms/frame (≈fps) | Total | Layers (frames) | Tags |
|---|---|---|---|---|---|---|
| `aerial dash/aerial dash.aseprite` | 6 | 443×160 | 70 (≈14) | 420 ms | 04 (5), 03 (2), 02 (2), 01 (2), aerial dash (6), smoke (6) | - |
| `aerial dash/aerial dash_pivoted.aseprite` | 6 | 224×160 | 70 (≈14) | 420 ms | 04 (5), 03 (2), 02 (2), 01 (2), aerial dash (6), smoke (6) | - |
| `atk/1x atk/1x atk_c.aseprite` | 17 | 160×64 | 40 (≈25) | 680 ms | 1x atk (10), to idle (7), 1x atk_fx (9) | - |
| `atk/2x atk/2x atk.aseprite` | 25 | 192×64 | 40 (≈25) | 1000 ms | 2x atk (10), to idle(long delay) (hidden) (15), to idle(short delay) (9), fx01 (11) | - |
| `atk/2x-1 atk/2x-1 atk.aseprite` | 6 | 192×86 | 40 (≈25) | 240 ms | 2x-1 atk (6), fx (6) | - |
| `atk/2x-2 atk/2x-2 atk.aseprite` | 10 | 192×86 | 40 (≈25) | 400 ms | 2x-2 atk (10), fx (6) | - |
| `atk/3x atk/3x atk.aseprite` | 34 | 222×94 | 35 (≈29) | 1190 ms | 3x atk (34), 3x atk_fx01 (9), 3x atk_fx02 (14), 3x atk_fx03 (10) | - |
| `back dodge/back dodge.aseprite` | 24 | 208×64 | 35 (≈29) | 840 ms | illusion_03 (8), illusion_02 (10), illusion_01 (12), back dodge (24) | to idle 21-23 |
| `back dodge/back dodge_pivoted.aseprite` | 24 | 208×64 | 35 (≈29) | 840 ms | illusion_03 (8), illusion_02 (10), illusion_01 (12), back dodge (24) | to idle 21-23 |
| `crouching/crouching.aseprite` | 13 | 56×50 | 70 (≈14) | 910 ms | crouching (6), to idle (4), crouching idle (3) | - |
| `dodge atk/dodge atk 1x/dodge atk 1x.aseprite` | 19 | 272×64 | 40 (≈25) | 760 ms | dodge atk 1x (16), to idle (3), fx01 (11), fx02 (5) | - |
| `dodge atk/dodge atk 1x/dodge atk 1x_pivoted.aseprite` | 19 | 368×64 | 40 (≈25) | 760 ms | dodge atk 1x (16), to idle (hidden) (3), fx01 (11), fx02 (5), smoke (8) | - |
| `dodge atk/dodge atk 2x/dodge atk 2x.aseprite` | 16 | 112×128 | 40 (≈25) | 640 ms | dodge atk 2x (16), fx (9) | from dodge atk 1 0-7, to jump status 14-15 |
| `dodge atk/dodge atk 2x/dodge atk 2x_pivoted.aseprite` | 16 | 144×144 | 40 (≈25) | 640 ms | dodge atk 2x (16), fx (9) | from dodge atk 1 0-7, to jump status 14-15 |
| `dodge atk/dodge atk 3x(vertical atk)/dodge atk 3x.aseprite` | 37 | 224×288 | 40 (≈25) | 1480 ms | smoke (24), vertical atk (26), fall fx_04 (hidden) (3), vertical atk fall loop (3), fall fx_03 (3), fall fx_02 (hidden) (3), fall fx_01 (3), fall fx_05 (3), fx_upper (26) | Tag 18-20 |
| `healing/healing.aseprite` | 18 | 97×81 | 60 (≈17) | 1080 ms | fx_02 (7), healing (18), fx_01 (17) | - |
| `hurt/hurt.aseprite` | 34 | 79×60 | 40 (≈25) | 1360 ms | hit (10), hard hit (hidden) (24), normal hit (12) | - |
| `idle/idle.aseprite` | 10 | 64×64 | 60 (≈17) | 600 ms | idle (10) | - |
| `jump attack/jump atk 1x/jump attack 1x.aseprite` | 9 | 144×72 | 40 (≈25) | 360 ms | jump atk 1x (9), fx (9) | - |
| `jump attack/jump atk 2x/jump atk 2x.aseprite` | 8 | 100×112 | 100 (≈10) | 800 ms | jump atk 2x (8), fx (8) | - |
| `jump/double jump_forward.aseprite` | 7 | 80×80 | 70 (≈14) | 490 ms | Sprite Sheet (7) | - |
| `jump/double jump_vertical.aseprite` | 7 | 80×80 | 70 (≈14) | 490 ms | double jump_vertical (7) | - |
| `jump/jump.aseprite` | 24 | 64×80 | 60 (≈17) | 1440 ms | jump (20), landing (4) | up loop 4-9, fall loop 16-18 |
| `jump/roll landing.aseprite` | 9 | 79×64 | 60 (≈17) | 540 ms | roll landing (9) | - |
| `ladder action/ladder action.aseprite` | 22 | 56×89 | 70 (≈14) | 1540 ms | slide end (3), slide loop (4), climb end (6), climb up (6), climb start (3) | - |
| `ledge action/ledge action.aseprite` | 14 | 108×111 | 70 (≈14) | 980 ms | up (8), hang (6), idle (hidden) (6) | - |
| `run/run.aseprite` | 20 | 72×52 | 35 (≈29) | 700 ms | sprint (20) | - |
| `run/run_start.aseprite` | 2 | 80×64 | 100 (≈10) | 200 ms | sprint_start (2) | - |
| `run/run_stop.aseprite` | 15 | 80×64 | 40 (≈25) | 600 ms | sprint stop (15) | - |
| `run/run_turn.aseprite` | 8 | 64×64 | 40 (≈25) | 320 ms | sprint_turn (8) | - |
| `slide/slide.aseprite` | 17 | 149×64 | 40 (≈25) | 680 ms | fx03 (6), fx02 (8), fx01 (10), slide (13), to (2), from (2), spark (9) | - |
| `walk/walk.aseprite` | 26 | 53×64 | 50 (≈20) | 1300 ms | walk (26) | from idle 0-1, walk cylcle 2-25 |
| `wall jump/wall jump.aseprite` | 6 | 57×73 | 70 (≈14) | 420 ms | wall slide (3), wall jump (3) | - |

## Exported PNG sheets

| Sheet | Size (px) |
|---|---|
| `aerial dash/sprite sheets/aerial dash.png` | 624×100 |
| `aerial dash/sprite sheets/aerial dash_fx.png` | 305×47 |
| `aerial dash/sprite sheets/aerial dash_smoke.png` | 240×314 |
| `aerial dash/sprite sheets/aerial dash_without illusion.png` | 672×64 |
| `atk/1x atk/sprite sheets/1x atk_char.png` | 640×320 |
| `atk/1x atk/sprite sheets/1x atk_fx.png` | 640×192 |
| `atk/1x atk/sprite sheets/1x atk_merged.png` | 640×320 |
| `atk/2x atk/sprite sheets/2x atk_char(long).png` | 768×448 |
| `atk/2x atk/sprite sheets/2x atk_char(short).png` | 768×320 |
| `atk/2x atk/sprite sheets/2x atk_fx.png` | 768×192 |
| `atk/2x atk/sprite sheets/2x atk_merged(long).png` | 768×448 |
| `atk/2x atk/sprite sheets/2x atk_merged(short).png` | 768×320 |
| `atk/2x-1 atk/sprite sheets/2x-1 atk_char.png` | 336×118 |
| `atk/2x-1 atk/sprite sheets/2x-1 atk_fx.png` | 384×122 |
| `atk/2x-1 atk/sprite sheets/2x-1 atk_merged.png` | 417×150 |
| `atk/2x-2 atk/sprite sheets/2x-2 atk_char.png` | 336×236 |
| `atk/2x-2 atk/sprite sheets/2x-2 atk_fx.png` | 384×122 |
| `atk/2x-2 atk/sprite sheets/2x-2 atk_merged.png` | 417×300 |
| `atk/3x atk/sprite sheets/3x atk_char.png` | 504×558 |
| `atk/3x atk/sprite sheets/3x atk_fx01.png` | 888×282 |
| `atk/3x atk/sprite sheets/3x atk_fx02.png` | 888×376 |
| `atk/3x atk/sprite sheets/3x atk_fx03.png` | 888×282 |
| `atk/3x atk/sprite sheets/3x atk_merged.png` | 888×846 |
| `back dodge/sprite sheets/back dodge(fx included).png` | 568×366 |
| `back dodge/sprite sheets/back dodge.png` | 384×384 |
| `crouching/sprite sheets/crouching.png` | 159×250 |
| `dodge atk/dodge atk 1x/sprite sheets/dodge atk 1x_char.png` | 348×280 |
| `dodge atk/dodge atk 1x/sprite sheets/dodge atk 1x_fx01.png` | 1088×192 |
| `dodge atk/dodge atk 1x/sprite sheets/dodge atk 1x_fx02.png` | 1360×64 |
| `dodge atk/dodge atk 1x/sprite sheets/dodge atk 1x_merged.png` | 1040×280 |
| `dodge atk/dodge atk 1x/sprite sheets/dodge atk 1x_merged2.png` | 620×280 |
| `dodge atk/dodge atk 1x/sprite sheets/dodge atk 1x_smoke.png` | 384×96 |
| `dodge atk/dodge atk 2x/sprite sheets/dodge atk 2x_char.png` | 448×512 |
| `dodge atk/dodge atk 2x/sprite sheets/dodge atk 2x_fx.png` | 448×384 |
| `dodge atk/dodge atk 2x/sprite sheets/dodge atk 2x_merged.png` | 448×512 |
| `dodge atk/dodge atk 3x(vertical atk)/sprite sheets/dodge atk 3x_char.png` | 256×1152 |
| `dodge atk/dodge atk 3x(vertical atk)/sprite sheets/dodge atk 3x_fall loop.png` | 414×241 |
| `dodge atk/dodge atk 3x(vertical atk)/sprite sheets/dodge atk 3x_fall loop1.png` | 204×241 |
| `dodge atk/dodge atk 3x(vertical atk)/sprite sheets/dodge atk 3x_fx01.png` | 1218×1345 |
| `dodge atk/dodge atk 3x(vertical atk)/sprite sheets/dodge atk 3x_fx02.png` | 1218×420 |
| `dodge atk/dodge atk 3x(vertical atk)/sprite sheets/dodge atk 3x_merged.png` | 1218×1883 |
| `healing/sprite sheets/healing_char.png` | 141×384 |
| `healing/sprite sheets/healing_fx01.png` | 291×468 |
| `healing/sprite sheets/healing_fx02.png` | 228×480 |
| `healing/sprite sheets/healing_merged.png` | 291×486 |
| `hit fx/hit fx_01.png` | 625×87 |
| `hit fx/hit fx_02.png` | 625×87 |
| `hurt/sprite sheets/hard hit.png` | 474×360 |
| `hurt/sprite sheets/normal hit.png` | 280×360 |
| `idle/sprite sheets/idle.png` | 460×55 |
| `jump attack/jump atk 1x/sprite sheets/jump attack 1x_char.png` | 328×189 |
| `jump attack/jump atk 1x/sprite sheets/jump attack 1x_fx.png` | 496×207 |
| `jump attack/jump atk 1x/sprite sheets/jump attack 1x_merged.png` | 512×207 |
| `jump attack/jump atk 2x/sprite sheets/jump atk 2x_char.png` | 308×150 |
| `jump attack/jump atk 2x/sprite sheets/jump atk 2x_fx.png` | 400×224 |
| `jump attack/jump atk 2x/sprite sheets/jump atk 2x_merged.png` | 400×224 |
| `jump/sprite sheets/double jump_forward.png` | 560×80 |
| `jump/sprite sheets/double jump_vertical.png` | 560×80 |
| `jump/sprite sheets/jump.png` | 256×480 |
| `jump/sprite sheets/roll landing.png` | 304×132 |
| `ladder action/sprite sheets/01_ladder climb start.png` | 117×61 |
| `ladder action/sprite sheets/02_ladder climb up.png` | 141×124 |
| `ladder action/sprite sheets/03_ladder climb end.png` | 168×172 |
| `ladder action/sprite sheets/04_ladder slide loop_char.png` | 224×68 |
| `ladder action/sprite sheets/04_ladder slide loop_fx.png` | 160×46 |
| `ladder action/sprite sheets/04_ladder slide loop_merged.png` | 224×78 |
| `ladder action/sprite sheets/05_ladder slide end.png` | 168×50 |
| `ledge action/sprite sheets/hang idle.png` | 176×130 |
| `ledge action/sprite sheets/hang.png` | 208×132 |
| `ledge action/sprite sheets/up.png` | 352×222 |
| `run/sprite sheets/run.png` | 260×240 |
| `run/sprite sheets/run_start.png` | 118×53 |
| `run/sprite sheets/run_stop.png` | 252×212 |
| `run/sprite sheets/run_turn.png` | 236×102 |
| `slide/sprite sheets/slide_char.png` | 288×384 |
| `slide/sprite sheets/slide_merged.png` | 432×384 |
| `walk/sprite sheets/from idle.png` | 90×58 |
| `walk/sprite sheets/walk.png` | 180×348 |
| `wall jump/sprite sheets/wall jump.png` | 153×58 |
| `wall jump/sprite sheets/wall slide.png` | 132×73 |
