# Stage 2: The Island (Perry Riposte port)

Owner request (2026-11-02): copy every animated creature and character from `xenodorian/BibooSGBA` (Perry Riposte) into Mera, Perry herself included, copy its maps, and add a second stage after the dragon: 5 new maps full of enemies, with Perry as the final boss. Reuse Mera's existing map and enemy logic. The owner holds the rights to the BibooSGBA art and music.

Progress is pushed to `main` after each step below. The status column is updated as steps land.

## How the two games store things

| | Perry Riposte (BibooSGBA, web JS) | Mera (Godot) |
|---|---|---|
| Enemy art | One PNG strip per creature, fixed cell size, one row. `creatures.js` lists `cell`, `anchor`, `frames[{src, ms, hurt, hit}]` and `anims{name: {frames: [frame indices], loop}}`. Creatures are drawn facing left. | One PNG per frame under `assets/characters/...`. `tools/build_roster.py` writes `assets/enemies/roster.json` (frames, fps, loop, pivot at the feet, opaque boxes per frame). |
| Enemy behaviour | `ai{speed, reach, attacks, hp, dmg, atk}` read by `game/11_enemies.js` and `13_enemy_attacks.js`. | `Roster.DEFS` in `scripts/game/roster.gd` (k scale, hp, speed, ai type, idle/move anims, attack list with tell, range, mode) read by `scripts/game/monster.gd`. |
| Perry | Player moves in `data.js` (`moves.<name>`: sheet, cell, anchor, frames), faces right. | New boss entry `perry` built from her move sheets, facing right. |
| Maps | `bgs/<theme>_{sky,ground,fringe}.png`, 384 x 232, tileable, ground top at row 191. Also `arenas/` (4 parallax layers), `arenas512/`, `layers/`, and 640 x 512 scene paintings. | `assets/levels/<id>/*.png` drawn at x5, 384 x 216 native per screen, ground at GROUND_Y 1060. `levels.json` lists layers `{file, scroll, y, z, period, w}`; `period > 0` tiles. |

A Perry 384 x 232 layer drawn at x5 is 1920 x 1160, exactly one Mera screen plus margin. Sky layers go at y -40. Ground layers go at y 100 so the ground top (row 191) lands on Mera's feet line.

## Design

* Stage 1 is unchanged: levels 1 to 6, ending with the Dragon's Lair.
* Beating the dragon shows "You Defeated the Cavern Dragon!" and then "Stage 2: The Island", and unlocks level 7.
* Stage 2, levels 7 to 11, built from Perry's five story maps:

Only creatures with real frame animation are ported (owner, 2026-11-02): the goblin, the orc, the club ogre, Mirror Max, Percy, the fire mage and Perry. Perry Riposte's other creatures (hobgoblin, skull raider, dusksaur, dark knight, ogre, wyrm slug, ooze wraith, horned dread, ogre chief, boar lord) are single still images moved by code, so they are left out. The waves mix the Perry creatures with Mera's own animated enemies.

| # | Index | id | Name | Waves (Roster.LEVELS) | End boss (Roster.BOSSES) |
|---|---|---|---|---|---|
| 7 | 6 | `p_falls` | Mossy Falls | p_goblin, p_orc, lm_goblin, lm_mushroom, lm_eye | Club Ogre |
| 8 | 7 | `p_canyon` | Sunstone Canyon | see `Roster.LEVELS` | Fire Demon |
| 9 | 8 | `p_shore` | Sunset Shore | p_goblin, p_orc, p_firemage, werewolf, mutant_toad, lm_skeleton | Mirror Max |
| 10 | 9 | `p_mire` | Mire Wood | p_orc, p_firemage, p_goblin, sx_zombie, sx_witch, ghost | Percy |
| 11 | 10 | `p_sanctum` | Moonlit Sanctum | p_orc, p_firemage, p_goblin, demon, death, lm_skeleton | **Perry** (final boss) |

* Stage 2 bosses use the existing "boss shares a stage" path in `game.gd` (`BOSS_AT`, `BOSS_X`, exit locked until the boss falls). Only the dragon and Perry end a stage with a victory card (`Roster.FINALE`).
* Beating Perry shows "You Defeated Perry!" and returns to the title. It pays the same 100 gold bonus as the dragon.
* The level select gets two pages: Stage 1 (6 cards) and Stage 2 (5 cards). Left / Right moves across the pages.
* The goblin, the orc and the fire mage join the endless run pool.

## Steps

| Step | Who | Status |
|---|---|---|
| 1. This plan | Opus | done |
| 2. Copy the Perry art and music into `assets/perry/` (originals stay untouched in BibooSGBA) | Haiku | done |
| 3. `tools/build_perry.py`: cut every Perry strip into per-frame PNGs under `assets/characters/perry/<id>/<anim>/`, register them in `tools/build_roster.py`, rebuild `roster.json` | Haiku, reviewed by Opus | done |
| 4. `tools/build_stage2.py`: the 5 level folders, thumbs and `levels.json` entries | Haiku, reviewed by Opus | done |
| 5. `Roster.DEFS` for the new enemies and the Perry boss, `LEVELS`, `BOSSES`, `FINALE`, `RUN_POOL` | Opus | done |
| 6. Game flow: generic boss victory, dragon to stage 2, Perry ending, menu pages, props and cards on the new maps | Sonnet | done |
| 7. Tests, export file list, credits, docs, release | Opus | done |

## Outcome (v0.13.0)
* The waves use only frame-animated creatures: the Perry Riposte goblin, orc and fire mage plus eight free creatures found online (Luiz Melo CC0, chierit CC-BY 4.0; `docs/CREDITS.md`). The live lists are `Roster.LEVELS` 6 to 10; the table above shows the first draft.
* Bosses: Club Ogre, Fire Demon (chierit's demon), Mirror Max, Percy, Perry.
