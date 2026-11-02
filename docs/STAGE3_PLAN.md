# Stage 3 plan: playable Perry, Changeling levels, puzzle chests

Owner request (2026-11-02):
1. Once Stage 2 is cleared, Perry (Parry Perry, from `xenodorian/BibooSGBA`) becomes a playable character, with her existing moves rebuilt and her own unlockables ported. Same prices, paid in gold instead of leaves.
2. Stage 3 comes from `xenodorian/GameOfGameBecauseGame` ("Changeling"): its levels, enemies and characters, rebuilt in Godot. All of its enemies are used, and its playable characters are enemies too.
3. Every playable character drops a card of itself and works as a normal summon. The ranger summon builds platforms and ladders on its own to reach flying targets first. The platforms sit at a height both the ranger and Mera can jump onto, and Mera can climb the ladders.
4. Chests no longer need keys. The key mechanic goes away. Opening a chest starts one of three puzzles: connect the pipes, a match-3 grid whose tiles are enemy portraits, or stop the needle (timing).

Work is pushed to `main` after each phase. Haiku takes bulk and mechanical work, Sonnet takes complex systems, and Opus plans, reviews, tests and releases.

## What the source games have

**Perry Riposte** (`web/progress.js`). Perry's unlocks are 26 entries: moves, buttons, meters and three special combos (Flight, Rainbow Guard, Ultimate Chain). Each has a `level` (the Perry level that sells it) and a shop kind. The prices are a scroll at `15 + 10 * level` and a mutagen at `25 + 15 * level`; anything that uses a meter is a mutagen. These are paid in Mera's gold one to one. Perry's meters are energy, empower and super. In Mera they use the meters Mera already has: energy is stamina (the blue bar), empower is mana and super is rage.

**Changeling** (`game/src/`, one HTML game, 32 px tiles):
- **Faces (playable):** knight (bashes cracked walls), ranger (bridges just under jump height, two at a time; Up plus build makes a 5-tile ladder), weaver (long bone bridges), mage (floats and blinks).
- **Enemies:**

| Enemy | Behaviour | Drops |
|---|---|---|
| grunt | lunges | ranger card |
| mud revenant | lobs mud | mage card |
| rat king | hops | knight card |
| archer (bone weaver sprite) | stationary shooter | weaver card |
| Warlord | 3-phase boss: swing, arrows, charge, jump slam with shockwaves | knight card |

- **Art:** LPC sheets of 13 x 8 cells of 64 px (and `_big` sheets of 192 px cells with separate weapon layers) under `game/assets/lpc/`, licences in `CREDITS.txt` (OGA-BY / CC-BY-SA / GPL; credit every author). The tiles are DCSS tiles (CC0).
- **Levels:** 8 ASCII tile maps in `levels.js`: Greenwood Road, Bramble Hollow, Old Watchtower, Rotting Marsh, Castle Gate, Undercroft, Hall of Faces and Warlord's Throne, in `field` and `dungeon` themes.

## Design decisions

- **Stage 3** is levels 12 to 19 (index 11 to 18), the eight Changeling maps in their order, unlocked by beating Perry. The Warlord is the boss of Warlord's Throne and a FINALE boss (victory card "You Defeated the Warlord!").
- **Changeling maps in Mera.** Mera's maps are wide side-scrollers at x5 native art. Each Changeling map is rendered from its tile grid into a ground layer. Its one-way ledges (`=`) become Mera `surfaces` (`tile_surfaces`, already used by Sunlit Country), its ladders become climbable ladders, and its walls and pits stay as art and floor. Tile rows are scaled so a ledge is reachable with Mera's base jump.
- **Ladders** are a new world object (`scripts/game/ladder.gd`). Mera climbs with Up/Down when overlapping one, and the ranger ally builds them.
- **Built platforms** use the same one-way surface code as map ledges. They are added at run time and expire after a while.
- **Perry as a player.** The title menu gets a character choice (Mera or Perry) once level index 10 is cleared. Perry is her own player script with the same interface `game.gd` uses for Mera. Her moves keep Perry Riposte's inputs, mapped to Mera's buttons. Mera's own shop stays. Perry gets her own shop page with her unlocks at her prices, in gold.
- **Summons.** The four Changeling faces (and Perry) become `Allies` entries. Their enemy versions drop their card like the existing ally cards.
- **Chests.** Keys, key drops and key text are removed. A chest opens a random puzzle of the three. Winning gives the chest's loot; losing leaves the chest shut, and it can be tried again.

## Map conversion rule
Mera's camera only scrolls sideways (it stays at y 540), so a Changeling map is flattened into one screen height:
- **Columns become x.** Each column is a fixed width, and a map is at least 9600 px wide. Warlord's Throne (40 columns) is an arena, like the Dragon's Lair.
- **The floor becomes Mera's ground.** The floor row (the top of the bottom solid run) is GROUND_Y 1060.
- **Ledges become surfaces in tiers.** A ledge (`=` or `_` with air above) becomes a one-way surface. Its height above the floor is counted in rows and clamped into a few tiers, each one comfortable jump apart for Mera at her starting size. That keeps the whole route on screen and reachable.
- **Pits and spikes** become floor with a hazard strip. Walls `#` taller than one tier become scenery. Cracked walls `x` become Mera's cracked-wall props.
- **Ladders** are added wherever a ledge tier is more than one jump above the tier below it.
- **Signs** become the level-start subtitle. The enemy letters spawn that enemy type in the waves, in the order they appear.

## Phases

| Phase | Work | Who | Status |
|---|---|---|---|
| 0 | This plan | Opus | done |
| 1 | Puzzle chests: remove keys; pipes, enemy-portrait match-3 and stop-the-needle mini games (`scripts/puzzles/`), touch and pad controls, tests | Sonnet, reviewed by Opus | done (565 pass) |
| 2 | Changeling art: copy the LPC sheets, tiles and credits; cut the frames into `assets/characters/changeling/<id>/<anim>/` (`tools/build_changeling.py`) | Haiku, reviewed by Opus | done |
| 3 | Playable Perry: character select, `perry_player.gd`, her moves and inputs, Perry shop page with her unlocks in gold, tests | Sonnet, reviewed by Opus | done (599 pass) |
| 4 | Ladders and run-time platforms (world objects, Mera climbing, one-way landing) | Sonnet | |
| 5 | Stage 3 maps: `tools/build_stage3.py` renders the 8 tile grids into level art, surfaces and ladders; levels.json and thumbs; menu page 3 | Haiku (art), Sonnet (conversion rules) | |
| 6 | Stage 3 enemies (grunt, mud revenant, rat king, archer, Warlord, and the four faces as enemies) in `Roster.DEFS`, waves, bosses | Opus | |
| 7 | Face summons and cards; the ranger ally builds platforms and ladders to reach flyers first | Sonnet | |
| 8 | Full tests, export list, credits, docs, release | Opus | |

## Resume notes (for the next session)
- Phase 3 is done (v0.14.0). Earlier note: the move frames are pushed (`tools/build_perry_player.py`, `assets/perry/perry_player.json`), along with `scripts/game/perry_player.gd`, `perry_unlocks.gd` and `perry_hud.gd`. None of it is wired into the game yet. The wiring (the player switch in `game.gd`, the character choice and Perry shop page in `menu.gd`, the Perry fields in `carry.gd`, `hud.gd`) and the tests were in progress when this note was written. If they are not on main, redo them from the Phase 3 spec above.
- Phases 4 to 8 are not started. The Changeling art for them is on main.
- Open design question for the owner: should a chest need a button press (Up) to open its puzzle, instead of opening when Mera walks into it?
