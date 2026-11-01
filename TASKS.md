# Tasks

This file is on `main`. If you cannot see it, you are not on the live repo.
Repo: https://github.com/xenodorian/mera-the-baby-giant
Same text is in `docs/AI_HANDOFF.md` under the same heading.

## TASKS FOR THE NEXT AGENT (do these, then stop)

You are implementing a short list. Do not invent extra features. Do not add branch or tag rulesets. Do not create a branch. Commit straight to `main` and push. Moves that start locked (beam, earthquake, super earthquake, rear explosion, Fury, homing) are intentional. Do not unlock them. Do not change shop prices.

Work from current `origin/main`. Read the function before you edit it. After each task, update the matching test in `tests/run_tests.gd` if one fails. Do not delete unrelated tests.

### 1. Spawn cap

`scripts/game/roster.gd` has `MAX_ALIVE := 5`. `scripts/game/game.gd` `_manage_roster` does `if alive >= Roster.MAX_ALIVE: break`, so a stage stops spawning once five enemies are alive anywhere, including ones left behind. That is the bug.

Replace the check with a per-stage cap equal to every wave enemy that stage will place. Add this on `game.gd` and call it instead of `Roster.MAX_ALIVE`:

```
func _stage_cap() -> int:
    var n := 0
    var i := 0
    var wx := Roster.WAVE_FIRST
    while wx < map_w - Roster.BOSS_AT:
        n += int(Roster.WAVE_SIZES[i % Roster.WAVE_SIZES.size()])
        i += 1
        wx = Roster.WAVE_FIRST + float(i) * Roster.WAVE_EVERY
    return maxi(n, 1)
```

In the wave loop, `break` only when `alive >= _stage_cap()`. Do not bring back distance despawn. Leave the line that only erases invalid mobs.

### 2. Cemetery knights at three fixed points

Level index 3 is the cemetery. It is not in `Roster.LEVELS`. Knights are spawned by `_spawn_knight` and `_manage_knight` in `game.gd`. Today there is one `var knight`, placed next to the camera, and a new call frees the previous knight.

Change it so three Fire Knights can exist at once, at fixed fractions of the walkable map, and later kills refill those same points until `Roster.KNIGHT_CAP` (5) have been spawned. The exit stays locked until that quota is met and none are alive (`exit_locked` already checks `knights_spawned < Roster.KNIGHT_CAP or _knight_fight_live()`).

Do this:

1. Add `var knights: Array = []` next to `var knight`.
2. Add:

```
func _knight_points() -> Array:
    var lo := Levels.EDGE
    var hi := map_w - Levels.EDGE
    var span := hi - lo
    return [lo + span * 0.25, lo + span * 0.50, lo + span * 0.75]
```

3. Replace `_spawn_knight` with `_spawn_knight_at(x: float, spot: int)`:
   - Do not `queue_free` any existing knight.
   - `FireKnight.new()`, `setup(self, "fire")`, `position = Vector2(x, GROUND_Y)`, `facing = -1 if x > mera.global_position.x else 1`.
   - `k.set_meta("spot", spot)`.
   - `world.add_child(k)`, `knights.append(k)`, `knights_spawned += 1`.
   - Set `knight = k` so old code that reads the single variable still sees one of them.
4. Rewrite `_manage_knight`:
   - Drop dead entries from `knights` (`not is_instance_valid` or `not alive()`).
   - If `knights_spawned == 0`, call `_spawn_knight_at` once for each of the three points, spots 0, 1 and 2.
   - If `knights_spawned < Roster.KNIGHT_CAP`, find any spot in 0, 1, 2 that has no living knight and spawn the replacement at `_knight_points()[spot]`.
   - Never place a knight from `cam_x`.
5. `_knight_fight_live` returns true if any entry in `knights` is alive, or any blue knight is alive.
6. `finish_endpoint` must `queue_free` every knight in `knights`, then `knights.clear()` and `knight = null`.
7. Search `game.gd` for other `knight.queue_free()` that assume there is only one. Point them at the array.
8. Do not despawn knights or blues for being far away.

### 3. Super earthquake requires the normal earthquake

In `scripts/game/carry.gd` `_buy_move`, before taking gold, if `id == "super_quake"` and not `owns("earthquake")`, `return "order"`.

In `scripts/menu.gd` `_shop_buy`, the `"order"` note currently always says to buy the shorter summon time. If `what == "move:super_quake"`, set the note to `Buy the earthquake first.` Keep the summon-time note for `summon:` rows.

In `_shop_stat`, when the row is `move:super_quake` and not `Carry.owns("earthquake")`, return `needs earthquake` instead of `locked`.

### 4. Homing

`Carry.owns("homing")` is the unlock. It must steer every player projectile that flies.

Already set in `game.gd`: `spawn_bolt` and `spawn_bolt_up`. Also set `sh.homing = Carry.owns("homing")` in `spawn_fireball`.

In `scripts/game/shot.gd`:

- Bolt movement already uses `_home` when `homing` is true. Keep that.
- The hit box is still flat. In the bolt branch of `_physics_process`, when `homing` is true, replace the rect with one that covers the bolt along `heading`:

```
var vis := size * bulk
var reach := 5.0 * vis
var half := Vector2(absf(heading.x) * reach + 3.0 * vis, absf(heading.y) * reach + 3.0 * vis)
var r := Rect2(position - half, half * 2.0)
```

  When `homing` is false, keep the old `up` / horizontal rect.
- Fireballs (`kind == "fireball"`) currently follow a parabola and ignore `homing`. If `homing` is true, do not use that parabola. Move the fireball with the same `_home(delta) * speed()` step the bolt uses, and test the same expanded rect against enemies. Still explode when it hits an enemy or a prop, or when it leaves the screen (`absf(position.x - game.camera_x()) > 2200`). If `homing` is false, leave the parabola exactly as it is.

Do not set `homing` on enemy shots (`enemy_shot.gd`) or dragon bolts (`dragon_bolt.gd`). Do not home the pulse wave or the vertical beam. Those are not flying projectiles.

### 5. Dragon victory marks the stage cleared, in the pixel font

In `game.gd` `_start_dragon_victory`, set `cleared = true` and `over_t = 0.0` before `Carry.record_clear`. `_clamp_to_map` only pays clear gold when `not cleared`, so this stops a second payment if Mera is already on the exit. Keep the existing `record_clear` and the extra `DRAGON_GOLD`. Do not call `record_clear` anywhere else in the victory path.

Delete the `Label` in `_show_victory_card`. A `Label` uses Godot's default font. The game's pixel text is `ThemeDB.fallback_font`, drawn by `scripts/game/hud.gd` (`font = ThemeDB.fallback_font` in `_ready`, drawn in `_draw_ui`). The HUD node is `PROCESS_MODE_ALWAYS`, so it still draws while the tree is paused.

Add a flag `var victory_card := false` on `game.gd`. Set it true at the start of `_show_victory_card`. In `hud.gd` `_draw_ui`, if `game.victory_card`, draw `You Defeated the Cavern Dragon!` centered with `ui.draw_string(font, ...)`, size 64, color `Color(1.0, 0.82, 0.35)`, and the same black shadow the other HUD strings use (draw the string again 4 px down and right in black first). Center it in the 1920x1080 HUD, around y = 500. Keep the dim `ColorRect` and the timer that calls `_to_title`.

### 6. No summon cards lying in the level

Cards come only from destroying an object. `game.gd` `break_drop` is already 40% coin, 25% health potion, 25% mana potion, 10% card (`roll >= 0.90`). Do not change those numbers. Do not drop cards from enemies. Enemy loot stays the fury orb.

`_place_cards` already begins with `return`, so map cards are not spawned. Keep that. Delete the unreachable lines under that `return` so a later edit cannot place `Allies.CARDS` again. Search for `CARD.new` and `card_nodes.append`. Nothing in a level may spawn a card node.

Walls, doors and ledges stay. Do not make breaking one spawn a card. `reveal_secret` may keep clearing `hidden_by` if a card exists, but `_place_props` will not find one. Do not add a new card spawn there.

The test name `country, woods, town and caverns each hold one card per ally` only checks the `Allies.CARDS` table. Leave the table. Do not start calling `_place_cards` to satisfy it.

### Done when

- A wave still spawns while more than five enemies are alive, until `_stage_cap()` is reached.
- Cemetery starts with three Fire Knights at 25%, 50% and 75% of the walkable width, and a death respawns on that same point until five have spawned in total.
- Buying super earthquake with no earthquake returns `order` and does not take gold.
- With homing owned, bolts and fireballs turn toward an enemy and their hit box covers that turned shape. Without it, fireballs still arc.
- Killing the dragon sets `cleared` and the victory words use `ThemeDB.fallback_font` through the HUD.
- No card node is placed on a map. A broken crate can still roll a card at 10%.
