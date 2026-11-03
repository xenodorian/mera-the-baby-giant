# Craft kit (Craftpix platformer art for Stage 3)

`tools/craft_kit.py` renders the ground layer and the parallax layers of four Stage 3 map looks from the free
Craftpix platformer pack (`assets/_source/craftpix_platformer/PNG/`). Python only (PIL, numpy), no Godot.

## Contract

```python
import craft_kit as K
rows = ...                                   # ASCII grid, same legend as build_stage3
info = build_stage3.analyse(rows, K.COLW)    # COLW = 160
wpx  = (info["nc"] * K.COLW + 1024 + 1100) // 5 + 1
ground = K.draw_ground_craft("cave", rows, info, K.COLW, wpx)   # PIL RGBA, wpx x 216, caller saves ground.png
layers = K.make_layers("cave", dest_dir, level_id)               # saves sky.png + 3 more, returns layer dicts
```

* `COLW = 160`: one ASCII column is one 32 px native tile, so no tile is ever resampled (nearest only, none needed).
* `draw_ground_craft(variant, rows, info, colw, wpx)`: same contract as `build_stage3.draw_ground`. World x of image
  pixel i is `5 * (i - IMG_X0)`, `IMG_X0 = 205`. The walking line of the floor is native row 212 (GROUND_Y 1060).
  A ledge sits at `GROUND_Y - 130 * tier`; the art's solid grass line is exactly on that y (leaf tips poke 4 rows above).
  `colw` must be 160 (asserted).
* `make_layers(variant, dest_dir, level_id)`: writes `sky.png` (always, lowest layer, z -40) and three more PNGs,
  returns dicts shaped like `build_stage3.layer()`: `{"file": "res://assets/levels/<id>/<name>.png", "scroll", "y", "z",
  "period", "w", "modulate": null}`, lowest z first. All have z between -40 and -24 (ground is -10). The caller saves
  `ground.png` and adds the ground layer dict. Per level the extra PNGs total 50 to 220 KB.
* `BG[variant]`: a fitting clear colour (`bg` in levels.json). `VARIANTS = ("meadow", "cave", "sky_isles", "jungle")`.
* Layer textures are native pixels: the game draws every layer sprite at x5, so a 960 px wide texture has
  `period = w = 4800`. The pack's 1920x1080 backdrops are drawn at 2 px per art pixel; the half size versions
  (`Background/1920x1080/÷2`, 960x540) are the 1:1 art and are what is used. They tile horizontally (checked).
* Preview/self test: `python3 tools/craft_kit.py` renders a 40 column test map for each variant into the scratchpad
  `craft/` folder, plus 1920x1080 composites (`preview_<variant>_start.png` at cam x 760, `preview_<variant>_mid.png`
  at cam x 3600) with Mera stand-ins (pink boxes 150 px and 60 px tall, white outline 300 px).

## ASCII legend as drawn

| char | art |
|---|---|
| `.` | air |
| `#` below the floor row | solid ground body (never visible beyond 4 rows) |
| `#` above the floor | scenery wall: columns that touch the floor and sit under a ledge become a plateau with a grass top; other runs are floating stone blocks (rows are 8.67 native px, no grass) |
| `=` `_` | floating platform strip (grass top, rock underside) at the tier height; plateaus (`=` over `#` down to the floor) become grass topped cliffs. Neighbouring columns join, runs get left/mid/right caps, a lone column gets a small island |
| `^` | pack spikes (Spikes.png) on the floor strip; in the jungle a predator plant stands at each end of a spike run |
| `x` | on the floor row: a few crack pixels on the grass tile; elsewhere as `#` |
| `i` | wooden sign; `T` tree (round tree, tall tree in the jungle, big crystal in the cave) near the floor |
| pit | columns with nothing solid from the floor row down: dark gap (meadow), swamp water (jungle), spikes in the dark (cave), nothing so the cloud sea shows (sky_isles) |
| `S F g m j a W c k p` | marks only, nothing drawn (cave: the stone gate of two jambs stands round `S`) |

## Variants

| variant | look | layers (scroll) |
|---|---|---|
| meadow | pack colours, sunny sky, grass and dirt cliffs, mushrooms, bushes | sky .06, clouds .16, flora_far .32, flora_near .55 |
| cave | grass tinted teal moss on blue-grey stone, ceiling band with stalactites over the whole map, start gate, crystals, spikes in pits | sky (cave wall) .08, fog .16, stalactites_far .28, stalagmites .5 |
| sky_isles | pale lavender stone, mint grass, hanging rock under isles (stalactite sprites), crystals, pits show clouds, cloud puffs round the floor edge | sky .05, clouds .14, far_isles .26, cloud_sea .5 |
| jungle | saturated leaf green, mossy rock, tall trees, predator plants beside spikes, swamp water pits, dark green backdrop | sky .06, mist .14, flora_far .30, flora_near .58 |

Recolouring (`recolor`) maps grass pixels (yellow green) and rock pixels separately per variant, so every variant is
a consistent grade of the same pack art.

## Tile catalog (`TILE`, Tileset.png is 17 columns x 12 rows of 32 px; name: row, col)

| name | row,col | use |
|---|---|---|
| grass_top_l / m / r | 0,6 / 0,7 / 0,8 | grass top of a ground block (surface line at tile row 5) |
| wall_l / m / r | 8,9 / 8,10 / 8,11 | block body: left edge, flat dark fill, right edge |
| base_l / m / r | 9,9 / 9,10 / 9,11 | rounded bottom (flipped as top cap of floating stone blocks; grass wings cleaned off) |
| fill | 1,7 | flat dark fill |
| pillar_top / body / base | 0,1 / 2,1 / 4,1 | one tile wide column |
| plat_l, plat_m1..m3, plat_r | 7,8 / 7,9 7,10 7,11 / 7,12 | floating platform strip |
| plat_one | 8,7 | one tile island |
| ceil_jag | 8,1 | cave ceiling lower edge |
| ceil_flat_l/m/r, ceil_cone_l/r | 10,0 10,1 10,2, 9,0 9,2 | other ceiling pieces (not used yet) |
| cave_wall_a..d, cave_edge_l/r | cave_entrance.png 1,1 1,2 2,3 0,3, 1,0 1,5 | cave interior and jambs |

Sprites (`SPR`, bounding boxes cut out of the sheets): tree_round, tree_spooky, tree_tall, sign, bush_a/b/big,
shroom_house, shroom_pair, crystal_big/small, flower (Objects.png); plant_big, plant_mid (Objects.png), plant_small,
plant_alt (Predator_plant.png); stal_s/m/l/xl (stalactites.png, grow stages); spike_a (frame 4, 26 px tall), spike_b
(frame 5, 38 px tall; base row 50 of the 64 px cell); cave_entrance, entrance_mid; chest, key.

## Limits and notes

* The ground layer shows only 4 native rows under the walking line (GROUND_Y 1060, screen ends at 1080), so the floor
  reads as a grass strip; the rock bodies show on plateaus, floating blocks and ledge undersides.
* `Flying_stone.png` is an animated crystal (6 frames of 160x128), not platform pieces; it is not used. Ledges are the
  Tileset row 7 strips.
* Backdrop windows are chosen so no hard cut edge is on screen (the images are cropped from rows that start in
  transparency); do not move layer `y` values without looking at a preview.
* Every ledge or wall height is a multiple of 26 native px (tier) or 8.67 native px (wall rows) as in build_stage3; tile
  rows of a plateau start at its own top, so adjacent plateaus of different heights can show a tile seam in the dark fill.
* Randomness (decor, hanging rock) is seeded by column count and variant, so a rerun gives identical PNGs.
