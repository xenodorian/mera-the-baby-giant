# King arc — task list (2026-11-03)

Live plan for the Nerochilde story, the two leftover ideas, and the Stage 2 correction.
Owner request, this session. Commit straight to `main`. Do not open branches or pull requests.
Do not bump `project.godot` or `export_presets.cfg` version fields (that publishes a release).
Do not run the test suite until the coordinator says the arc is complete.

## What shipped wrong, and the fix

Stage 2 multipliers in `scripts/game/tuning.gd`, applied in `monster.gd` `setup` when `opts.stage2` (levels 6 to 10 only):

| Constant | Was | Must be |
|---|---|---|
| `STAGE2_SIZE_MUL` | 2.0 | **1.5** |
| `STAGE2_HP_MUL` | 2.0 | **2.0** (leave it) |
| `STAGE2_CD_MUL` | 0.25 (waits quartered, attacks 4× as often) | **0.5** (attacks 2× as often as stage 1) |
| `STAGE2_SPEED_MUL` | 2.0 | **2.0** (leave it) |

History: [29368f5](https://github.com/xenodorian/mera-the-baby-giant/commit/29368f531a5c64fe7d661b3c1612afca1320d214) set size ×2, HP ×2, cooldown ×0.5. [cce1a02](https://github.com/xenodorian/mera-the-baby-giant/commit/cce1a02a1fc59fa926772d3c495d63432c5dd5a6) halved the wait again to 0.25. HP was not doubled twice. Only the attack wait was.

## Drop rates

`game.gd` `break_drop` is the destructible table. Change it to:

- 40% coin
- 30% health potion (`"potion"`)
- 20% mana potion (`"mana"`)
- 10% summon card (`"card"`)

That is the only table. Arena props use it. Do not touch enemy fury-orb loot (`Tuning.ENEMY_LOOT`).

## Perry's arena loot (do not nerf her AI)

`props.gd` `layout` returns nothing for `p_arena`. Stop doing that for this level only. Place **exactly 20** breakables (`crate`, `urn`, `candle`, `candle_b` — kinds whose break calls `break_drop`). Spread them across the 7200 px arena, clear of the boss stand (the right end, about `map_w - 1300`) and of x < 700 (a prisoner stands there). No barrels (they explode). No chests. Her moves, parry, heal and HP stay as they are.

## Two ideas from `docs/STAGE3_PLAN.md` (both required)

1. **Warlord-style mid-boss** on Stage 3 levels 12 to 18 (not 19, not 11). When Mera first crosses 42% of `map_w`, spawn one `cl_warlord` stored on `game.mid_boss`, not `game.boss`. After `setup`, if `opts.mid`: `hp_max = 90`, `hp = 90`, draw scale `k = 7` (re-apply the sprite scale the way `_face` does). Same attacks and phases. Dying does not show a victory card and does not lock the exit. It pays 30 gold and one `break_drop`. One spawn per visit.
2. **Enemies stand on surfaces.** `game.surface_under` already scans props, `tile_surfaces` and `built_surfaces`. Ground enemies in `monster.gd` (so Changeling enemies too, they extend it) must walk and land on that floor instead of only `rest_y`. Flyers, juggles and corpses stay as they are. Falling off a platform uses the existing gravity. Do not change Perry's boss script.

## Story

Short cards in the victory-card style (`hud.gd`: pixel font, dark shadow, gold first line, pale second line, centred on the 1920×1080 design). A new `scripts/game/story.gd` autoload is **not** required. A node `scripts/game/cutscene.gd` created by `game.gd` is enough: pages of one or two lines, A / Start advances, B skips the rest, the tree pauses the way a puzzle does (`PROCESS_MODE_ALWAYS`). Remember seen scenes on `Carry` so they play once.

Mera is a small child, daughter of two giants who could change their size. King **Lucius Nerochilde** feared that size and ordered them killed. The order was carried out by his daughter **Perry Nerochilde**, called Parry Perry because she parries almost every attack. Mera is here to kill him. He filled the road with summoned monsters. She frees prisoners. They pay gold, one item from `break_drop`, and a line of advice. After Perry falls, his mind-control breaks, and so does the spell that made her strong. She is unlocked and her shop starts empty. The two go on. The king waits on his own stage.

### Intro (once, start of level 0, before play)

1. Years ago, two giants lived beyond the hills.
2. They could grow until they blotted out the sun. Their child, Mera, was still small.
3. King Lucius Nerochilde feared that size. He called it a threat to his crown.
4. He sent his daughter, Perry Nerochilde. Fighters call her Parry Perry.
5. No blade could touch her. She parried every blow. The giants fell.
6. Mera lived. The road ahead is full of the monsters he summoned.

### Prisoners

A `scripts/game/prisoner.gd` node. Draw a simple cage (bars in `_draw`) over any existing idle texture you can `load` without new art (a Changeling knight frame is fine). Prompt `A: FREE` when Mera overlaps, same button as a chest (`btn_a`). One per level, once each (`Carry` flag). They then leave. Lines:

| Level index | Line | Extra |
|---|---|---|
| 1 Misty Woods | The king emptied the jails into these woods. Take this, and keep growing. | gold 20 + one `break_drop` |
| 4 Infernal Caverns | His soldiers wear his spell like a collar. Break the caster, not only the blade. | gold 25 + one drop |
| 8 Sunset Shore | Perry is his blood and his weapon. She does not fight like the others. | gold 25 + one drop |
| 11 Perry's Arena, x ≈ 480 | Parry Perry is nearly unbeatable unless you stun her first. Earthquake. Down and Y. | gold 20, and **grant `Carry.moves["earthquake"]`** if she does not already own it (add a small `give_move` if needed). Still one drop. |
| 15 Rotting Marsh | Past the changeling is his own court. He will not come out until the warlord falls. | gold 30 + one drop |
| 18 Hall of Faces | Free us and we will tell the others. The king waits alone. | gold 30 + one drop |

### Perry falls (level 11 finale)

Replace the two-line Perry card with these pages, then return to the title as the finale already does. Still call `unlock_through`, `record_clear`, and the finale gold **once**.

1. Perry drops her sword. The red glow leaves her eyes.
2. "Father. The spell. I could not stop my hands."
3. Breaking his mind control broke the magic that made her strong.
4. She starts again from nothing. Her shop is empty. She will walk with you.
5. Stage 3 is open. The mad king is still ahead.

`Carry.free_perry()` once: set `perry_freed`, clear `perry_owned`, set `perry_hp_max` back to `Tuning.PERRY_HP_START`. Do not clear Mera's gold, moves, or the level clear (she must stay unlocked). The title toggle and her shop already exist. Do not rebuild them.

### First step into Stage 3 (level 12, once)

1. Perry is with you. Only one of you can stand in the fight.
2. Switch on the title screen. Her strength must be bought again, in her own shop.

### The king

Append **one** level, index 20. Do not renumber 0..19.

- id `king_court`, name `Nerochilde's Court`, sub `King Lucius waits alone`.
- Solo arena, about 7200 px, no trash waves. Copy the dragon lair or Perry arena layer layout (reuse those PNGs by path; do not rebuild map art).
- `Levels.STAGE4_FROM := 20`. `stage_of` returns 3 for it. Menu header gains a fourth string: `THE KING'S COURT`. After the warlord, the menu opens on it the same way the dragon opens Stage 2 (`menu.gd` `_ready`).
- Warlord victory text becomes `You Defeated the Warlord!` / `The king's court is open`.
- Boss id `nero`. `Roster.BOSSES[20] = "nero"`. `Roster.FINALE[20] = "King Nerochilde"`. `Roster.NAMES["nero"] = "Nerochilde"`.
- His own script `scripts/game/nero.gd`, a `monster.gd` subclass or a small boss in the warlord's shape: ranged bolt, a slam, a tell before each swing. He does not parry. Damage does not scale. Beating him is the ending.
- Intro pages on that level, once: `King Lucius Nerochilde. He ordered your parents' death.` / `No army. No daughter. Only the dark lord he became.`
- Ending pages: `The mad king falls. The spell on the land breaks with him.` / `Mera stands. Perry stands free. The giants' daughter finished what they could not.`
- Then the title screen, with the clear and the finale gold.

### Art

`x_dark_wizard` already uses Luiz Melo's Evil Wizard 3. Do not reuse those frames for the king.

Download a **free** animated side-view dark lord / necromancer / evil overlord whose license is CC0 or CC-BY (commercial use allowed). Prefer:

- Foozle, Lucifer Necromancer, CC0: https://foozlecc.itch.io/lucifer-necromancer
- or Luiz Melo, Medieval King, CC0, only if no darker pack will download: https://luizmelo.itch.io/medieval-king-pack

Itch name-your-price means 0 is legal. Save the original zip under `assets/_source/king/`. Cut frames with the same approach as `tools/build_roster.py` (one PNG per frame, feet pivot, register in `ENT` or a small `tools/build_nero.py` that merges one key into `assets/enemies/roster.json`). Credit the author in `docs/CREDITS.md`. Run `python3 tools/add_export_files.py` on every new `res://` file the game loads. `git lfs` must track the PNGs and the zip (`.gitattributes` already does).

## Who does what

Work in parallel. Each agent clones the repo itself, touches only its files, and pushes to `main` when its step is done (`git pull --rebase origin main` first). If `game.gd` conflicts, keep both hunks.

| Step | Status | Files |
|---|---|---|
| 0. This plan | done | `docs/KING_ARC.md` |
| 1. Size 1.5×, attack wait 0.5, drop table 40/30/20/10, 20 arena props | todo | `tuning.gd`, `game.gd` `break_drop` only, `props.gd`, the stage-2 comment in `monster.gd` |
| 2. Prisoners, intro, Perry mind-control pages, Stage 3 pages, `Carry.free_perry` | todo | new `cutscene.gd`, `prisoner.gd`; hooks in `game.gd`; `carry.gd` |
| 3. Mid-boss on 12..18 and enemies on `surface_under` | todo | `monster.gd` floor, `game.gd` spawn, `cl_warlord.gd` only if `opts.mid` must live there |
| 4. Nero art, roster, court level, boss, ending pages, menu stage 4 | todo | `tools/build_nero.py`, `assets/`, `roster.gd`, `levels.json`, `levels.gd`, `menu.gd`, `nero.gd`, `CREDITS.md`, export list |

## Rules already in this repo

`AGENTS.md` and `docs/WORKFLOW.md`. In particular: pull before push, no force-push, no history rewrite, Git LFS, commit `*.import` if Godot writes them, never commit `.godot/`. New runtime files go on all three export presets via `tools/add_export_files.py`.

Coordinator runs the headless suite only after steps 1 to 4 are on `main`:

```
/workspace/tools/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tests/run_tests.gd
```
