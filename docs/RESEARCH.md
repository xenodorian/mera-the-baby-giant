# Mera: The Baby Giant — Mechanics, Physics & Interactables Research

*† = site returns 403 to scripted checks (GameSpot, GameFAQs, Patreon, Reddit/OGA sometimes); confirmed via a fetch or search index on 2026-10-31 and opens normally in a browser. One Giant Bomb link that could not be verified was dropped.*

*Compiled 2026-10-31 for the Godot 4.7.2 (Compatibility renderer, 1080p) build. Every link below was checked live (HTTP 200, or a known bot-blocking site that opens in a normal browser — marked †) on the compile date.*

**Scope.** Part of the t78u update. This file covers:
- What fans love and hate in 2D action brawlers and metroidvanias.
- How to build the best-loved mechanics in Godot 4.
- Physics and "juice" add-ons.
- Interactable and destructible object packs.
- A prioritised top-8 build list.

**What the code already has** (from a read-only grep of `mera-play` today): screen shake, i-frames/invulnerability, launch on the rising slash and knockback. **What it doesn't have yet:** hit-stop, parry, breakables and physics props. The recommendations below assume that baseline.

---

## 1. Fan-review research — what players love and hate

### 1.1 Game by game

| Game | What fans praise | What fans complain about | Sources |
|---|---|---|---|
| **Dead Cells** | <ul><li>"Tight", "fast, fluid and slick" controls.</li><li>Assist tech that does what you *mean*: ledge-catch, coyote time and auto-climbing small steps.</li><li>Dodge-roll and parry instead of mashing.</li><li>Crits freeze the game for 1 frame, then slow it for a few tenths of a second, with a blood spray and a unique sound.</li><li>Doors you can roll through and smash into pieces.</li><li>Screen shake on slams.</li><li>Kill-streak bonuses.</li><li>Huge weapon and skill variety.</li></ul> | <ul><li>Some enemies (Golems) can stun-lock you.</li><li>i-frames after a hit are very short.</li></ul> | [r/deadcells "why does combat feel so good"](https://www.reddit.com/r/deadcells/comments/14kxls0/what_exactly_is_it_about_dead_cells_combat_that/)†, [r/deadcells "why do you love it"](https://www.reddit.com/r/deadcells/comments/9r6jy0/why_do_you_love_this_game/)†, [Game Developer: 50 weapons](https://www.gamedeveloper.com/design/designing-each-of-the-50-weapons-in-i-dead-cells-i-to-feel-distinctive), [80.lv dev interview](https://80.lv/articles/interview-with-the-developers-of-dead-cells), [Entertainium](https://entertainium.co/2018/10/19/dead-cells-is-great-because-it-feels-great/) |
| **Hollow Knight** | <ul><li>The "half second after you collide": both you and the enemy recoil on a nail hit.</li><li>Generous i-frames, so "HK always gives you a chance to recover".</li><li>The pogo (down-strike bounce) is a damage, mobility *and* survival tool, and it refreshes your dash.</li><li>Hit-pause plus a flash when *you* get hit.</li></ul> | <ul><li>Long run-backs to bosses.</li><li>Corpse-run money recovery feels anti-exploration.</li><li>The economy reads as a grind gate.</li></ul> | [r/HollowKnight Reason #1](https://www.reddit.com/r/HollowKnight/comments/ckcfjz/reason_1_the_combat_10_reasons_i_love_hollow/)†, [Atomic Bob-Omb on knockback](https://atomicbobomb.home.blog/2019/02/05/hollow-knight-knockback/), [teemo.dev systems breakdown](https://teemo.dev/game-design/hollow-knight/systems/combat-and-movement-abilities/), [r/metroidvania critical thoughts](https://www.reddit.com/r/metroidvania/comments/muooi8/some_critical_thoughts_on_hollow_knight/)† |
| **Blasphemous** | <ul><li>Every blow lands "with a hefty crunch".</li><li>Parries "clang with a resounding weight".</li><li>A successful parry on a weak hit triggers an automatic counter-execution.</li><li>Heavy parries push you back.</li><li>Dense secrets.</li></ul> | <ul><li>**Unclear telegraphs.**</li><li>**Inconsistent rules** about which attacks can be dodged or parried.</li><li>**Phantom or lingering hitboxes.**</li><li>**Excessive knockback** that flings you across rooms.</li><li>Stun-locks.</li></ul> | [Yestermade replay](https://yestermade.com/blasphemous-replay-3x-dlc-content-final-version/), [COGconnected](https://cogconnected.com/review/blasphemous-review/), [yujiri review](https://yujiri.xyz/reviews/blasphemous.gmi), [r/Blasphemous fixes](https://www.reddit.com/r/Blasphemous/comments/d596sm/things_ive_noticed_that_could_be_fixed/)†, [r/Blasphemous knockback](https://www.reddit.com/r/Blasphemous/comments/gnbtlh/the_knockback_from_enimes_are_just_ridiculous/)† |
| **Streets of Rage 4** | <ul><li>Frame-studied hit "stutter and shake".</li><li>**Juggles, wall-bounces and ground-bounces** that extend combos ("the best addition to the game").</li><li>Back-attack button for crowds.</li><li>Specials that cost health you can win back by continuing the combo.</li><li>A combo counter that awards score and lives.</li><li>Limited-use Star Moves (screen-clearing supers).</li><li>Throwable weapons that bounce back.</li><li>Roo's move "summons Bruce", an assist character.</li></ul> | <ul><li>No sprint, so walking gets tedious.</li><li>Basic-button repetition.</li><li>No progression.</li></ul> | [Digital Foundry](https://www.digitalfoundry.net/articles/digitalfoundry-2020-streets-of-rage-4-tech-analysis), [TwistedVoxel](https://twistedvoxel.com/streets-of-rage-4-review/), [GameFAQs "juggles are so satisfying"](https://gamefaqs.gamespot.com/boards/246602-streets-of-rage-4/78646684)†, [Use a Potion](https://www.useapotion.com/2020/05/streets-of-rage-4-review/), [GameFAQs Roo FAQ](https://gamefaqs.gamespot.com/switch/271564-streets-of-rage-4/faqs/79699)† |
| **Castlevania SotN / Bloodstained** | <ul><li>"A secret around every corner": breakable walls, hidden rooms and secret bookshelves.</li><li>**Breakable candles** that drop hearts, mana or money (Bloodstained gives MP if you're low, gold if full).</li><li>**Familiars**, AI companions with their own abilities.</li><li>Shards and souls taken from enemies.</li><li>The Inverted Castle surprise.</li></ul> | <ul><li>Uneven difficulty.</li><li>Repeated map (SotN).</li><li>Plainer visuals (Bloodstained).</li></ul> | [GameSpot SotN](https://www.gamespot.com/reviews/castlevania-symphony-of-the-night-review/1900-6167833/)†, [DualShockers: SotN mechanics](https://www.dualshockers.com/castlevania-symphony-of-the-night-mechanics-that-still-feel-surprisingly-modern/), [Game Informer: Inverted Castle](https://gameinformer.com/b/features/archive/2012/11/06/moments-entering-the-inverted-castle-in-castlevania-symphony-of-the-night), [The Verge: Bloodstained](https://www.theverge.com/2019/6/28/19102612/bloodstained-ritual-of-the-night-review-switch-ps4-xbox-pc-castlevania), [Hardcore Gamer: Bloodstained](https://hardcoregamer.com/reviews/review-bloodstained-ritual-of-the-night/350599/) |
| **Skul: The Hero Slayer** | <ul><li>**Form swapping**: two skulls held at once, each with its own moveset, and a *swap attack* fires on the transition.</li><li>Trade-offs between forms.</li><li>Synergy items.</li><li>Big, chaotic screens.</li></ul> | <ul><li>Harsh difficulty.</li><li>Visual clutter.</li><li>Linearity.</li></ul> | [Tech-Gaming](https://www.tech-gaming.com/skul-the-hero-slayer/), [Checkpoint Gaming](https://checkpointgaming.net/reviews/2021/01/skul-the-hero-slayer-review-bone-shatteringly-great-indie/), [GameCritics](https://gamecritics.com/mike-suskie/skul-the-hero-slayer-review/), [GameSkinny](https://www.gameskinny.com/reviews/skul-the-hero-slayer-review-end-the-tyranny-of-heroes/) |
| **Katana ZERO** | <ul><li>One-hit kills both ways.</li><li>**Deflecting bullets back** at shooters.</li><li>Limited slow-motion meter.</li><li>Chaining rolls, slashes and throws.</li></ul> | <ul><li>Trial-and-error repetition.</li><li>Slow-mo feels gimmicky to some.</li></ul> | [GameSpot](https://www.gamespot.com/reviews/katana-zero-review-slow-motion-for-me/1900-6417126/)†, [PC Gamer](https://www.pcgamer.com/katana-zero-review/), [Polygon](https://www.polygon.com/reviews/2019/4/18/18412782/katana-zero-review-a-game-about-death-death-death-and-life/) |
| **Guacamelee!** | <ul><li>Air juggles.</li><li>**Grab and throw enemies into other enemies, walls or the floor** for splash damage.</li><li>**Colour-coded shields** broken only by the matching special move.</li></ul> | Late-game shield fights get frantic. | [GameSpot](https://www.gamespot.com/reviews/guacamelee-review/1900-6406634/)†, [The Guardian](https://www.theguardian.com/technology/gamesblog/2013/may/14/guacamelee-video-game-review), [Play Critically](https://playcritically.com/2023/06/11/guacamelee-review/) |
| **Scott Pilgrim vs. the World** | <ul><li>**Summonable assist strikers.** Knives Chau's effect depends on who you're playing: a stun cloud, a healing coffee, or a line of knives.</li><li>A rarer assist *distracts* an enemy, which is a direct precedent for the Dancing Girl.</li></ul> | — | [GameRant](https://gamerant.com/scott-pilgrim-vs-world-unlock-knives-chau/), [Nintendo World Report](https://www.nintendoworldreport.com/review/55964/scott-pilgrim-vs-the-world-the-game-complete-edition-switch-review) |
| **Owlboy** | <ul><li>Instantly summon, carry and **swap companions** ("gunners"), each with its own weapon.</li><li>The companion is used for both combat and puzzles.</li></ul> | Swapping can be clumsy in busy fights. | [Destructoid](https://www.destructoid.com/reviews/review-owlboy/), [PC Gamer](https://www.pcgamer.com/owlboy-review/), [Nintendo World Report](https://www.nintendoworldreport.com/review/46413/owlboy-switch-review) |
| **Wonder Boy: The Dragon's Trap** | <ul><li>Five **transformation forms**, each with its own traversal and combat abilities.</li><li>Forms unlock secrets.</li><li>Instant art and music toggle.</li></ul> | — | [Nintendo Life](https://www.nintendolife.com/reviews/switch-eshop/wonder_boy_the_dragons_trap), [Destructoid](https://www.destructoid.com/reviews/review-wonder-boy-the-dragons-trap/), [TheGamer forms guide](https://www.thegamer.com/wonder-boy-the-dragons-trap-forms-transformations-explained-guide/) |

**Genre-wide pet peeves** (from r/BeatEmUps and others):
- Enemies hiding off-screen.
- Health-sponge enemies and bosses with few moves.
- Repetitive enemy waves.
- Cheap hits you can't read.

Sources: [r/BeatEmUps off-screen thread](https://www.reddit.com/r/BeatEmUps/comments/1fx416z/anyone_know_of_any_beat_em_ups_where_the_enemies/)†, [r/BeatEmUps small annoyances](https://www.reddit.com/r/BeatEmUps/comments/vbiach/whats_one_small_annoyance_you_hate_in_beat_em_ups/)†, [r/BeatEmUps dos and don'ts](https://www.reddit.com/r/BeatEmUps/comments/1oxcy0r/dos_and_donts_in_beatemup_design/)†, [Jiggeh: what makes a good beat 'em up](https://jiggeh.com/2022/06/03/so-what-makes-a-good-beat-em-up-anyway/).

**Classic game-feel talks:**
- [Jan Willem Nijman, "The Art of Screenshake"](https://www.youtube.com/watch?v=AJdEqssNZ-U)
- ["Juice It or Lose It"](https://gamedesign.gg/watch/juice-it-or-lose-it/)

### 1.2 Recurring liked mechanics, ranked by how often they come up

| # | Mechanic | Who praises it | Relevance to Mera |
|---|---|---|---|
| 1 | **Hit-stop / freeze frames + slow-mo on big hits** | Dead Cells, HK, SoR4, Blasphemous | Not in the code yet. Cheapest big win. |
| 2 | **Impact layering: flash, sparks, sound, shake** | everyone | Shake exists. A hit flash and spark/sound variation would complete the layering. |
| 3 | **Readable telegraphs + consistent rules** (the *absence* of this is the #1 complaint) | Blasphemous (negative), Dead Cells (fair) | The Fire Knight already has a 0.7 s tell. Standardise this across the 16 new enemies. |
| 4 | **Input buffering, cancels and "does what I mean" assists** (coyote time, ledge forgiveness) | Dead Cells | Directly addresses the user's "combos feel clunky" note (t69u). |
| 5 | **Juggles, launchers, wall and ground bounces** | SoR4, Guacamelee | The rising slash and slam already exist. Wall bounces off map edges would extend combos. |
| 6 | **Generous i-frames after a hit + bounded knockback** (anti-stun-lock) | HK (positive), Blasphemous and Dead Cells (negative) | Important now that a Fire Knight hit costs 2 sizes. |
| 7 | **Parry / perfect block → counter** | Blasphemous, Dead Cells, Katana ZERO | New verb for the B or L2 button. |
| 8 | **Projectile deflection** | Katana ZERO | A sword swat sends knight bolts back. |
| 9 | **Throws: enemy into enemy, wall or object** | Guacamelee, SoR4 | Big, a giant heroine throwing knights is on-theme. |
| 10 | **Breakable props that drop pickups** (candles, urns, crates) | Castlevania, Bloodstained, Dead Cells doors | Fills the bigger t78u maps. |
| 11 | **Secrets: breakable walls, hidden rooms** | SotN, Bloodstained, Blasphemous | Rewards exploring the bigger maps. |
| 12 | **Assist / summon allies with distinct roles; distraction assists** | Scott Pilgrim, SoR4 (Bruce), SotN familiars, Owlboy | Validates the t78u R1 ally cards. Note Owlboy's lesson: the swap UI must be quick. |
| 13 | **Form / size variety with trade-offs** | Skul, Wonder Boy | Mera's 1x–19x scaling is her form system. Make sizes play differently, not just bigger. |
| 14 | **Super meter / limited screen-clearers** | SoR4 Star Moves, Katana slow-mo | Fury, rage-gated lightning and the earthquake already fit this. |
| 15 | **Combo counter / style rank with rewards** | SoR4, Dead Cells kill streaks | Feeds the rage meter. Score and lives optional. |

---

## 2. Godot 4 implementation notes for the top mechanics

General Godot 4 references:
- [GDQuest hitbox/hurtbox (Godot 4)](https://www.gdquest.com/library/hitbox_hurtbox_godot4/) and [demo repo](https://github.com/gdquest-demos/godot-4-hitbox-hurtbox).
- [2D particle systems](https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html).
- [Renderer overview](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).
- [SceneTreeTimer](https://docs.godotengine.org/en/stable/classes/class_scenetreetimer.html).
- [Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html).
- [Camera2D](https://docs.godotengine.org/en/stable/classes/class_camera2d.html).

**1. Hit-stop / freeze frames**
- **Approach:** add a `HitStop` autoload.
  - Normal hits: `Engine.time_scale = 0.05` for 40–70 ms.
  - Crits and finishers: ~100 ms, then `time_scale = 0.4` for 0.2 s. This is the Dead Cells recipe.
  - Restore the scale with `get_tree().create_timer(d, true, false, true)`. The fourth argument is `ignore_time_scale`; without it the timer slows down too.
- **Pitfalls:**
  - Don't use 0.0, because physics, tweens and AnimationPlayers stall in odd ways. 0.02–0.05 is safer.
  - When freezes overlap, keep the longest and lowest one rather than resetting to 1.0 early.
  - The camera shake must run on real time, or it freezes along with everything else.
  - Fury's own slow-mo needs to survive: save and restore the previous scale rather than hard-coding 1.0.
- **Alternative:** per-node freeze. Pause only the attacker's and victim's AnimationPlayer (`speed_scale = 0`) so the rest of the world keeps moving. This suits multi-enemy brawls better.
- **Links:** [Coding Quests hit-stop lab](https://codingquests.io/labs/hit-stop), [Godot Forum hit-stop + trauma shake tutorial](https://forum.godotengine.org/t/tutorial-hit-stop-and-screen-shake-in-godot-4-autoload-trauma-camera-mit/145240), [CodingQuests game-feel-lab (MIT)](https://github.com/CodingQuests/godot-game-feel-lab).

**2. Hit flash + sparks + layered SFX**
- **Hit flash:** a `canvas_item` shader with `uniform float flash`, doing `COLOR.rgb = mix(c.rgb, flash_color, flash)` while keeping alpha. Tween `flash` from 1 to 0 over 0.12 s. See [godotshaders hit flash](https://godotshaders.com/shader/hit-flash-effect/).
  - Mera and the enemies already use runtime recolours (the Blue Knight), so put the flash into the *same* shader as a second uniform. Don't stack a second material.
- **Sparks:** pooled `AnimatedSprite2D` one-shots using the ansimuz **Hit**, **Warped shooting fx/hits 1–6**, **EnemyDeath** and **Explosions pack** sprites. All of these are already owned in `assets_survey/ansimuz/Legacy Collection/Assets/Explosions and Magic/`.
- **SFX:** `AudioStreamRandomizer` gives pitch and volume variance on Kenney impacts, so repeated hits don't sound machine-gunned.

**3. Telegraphs & consistent attack rules**
- **Data:** give each enemy attack a `Resource` (`AttackData`) with these fields:
  - `windup`, `active` and `recovery` times
  - `damage_sizes` and `knockback`
  - `blockable`, `parryable` and `dodgeable` flags
  - `tell_color`
- **Tells:** drive them from the AnimationPlayer with method tracks, so a tell flash, a sound and a weapon gleam fire at the same frame as the windup. Activate the hitbox (`monitoring = true`) only on active frames, also from a method track. That avoids Blasphemous's "phantom hitbox" complaint.
- **Colour language:** a single scheme, for example white-gold = parryable and red = unblockable. Document it in the controls screen.

**4. Input buffer + cancel windows (combo responsiveness)**
- **Buffer:** a ring buffer of `{action, time_msec}`. Each state's `can_accept(action)` consumes the newest unexpired entry.
  - Buffer life: 100–150 ms (6–9 frames).
  - Cancel windows: authored per attack as AnimationPlayer method-track calls, `open_cancel(["X","Y","B"])` and `close_cancel()`.
- **Platforming assists:** 0.1 s coyote time, a jump buffer, and a 4–6 px ledge-correction nudge.
- **Links:** [Hayao: combo strings and cancels](https://hayao.dev/docs/codex/mechanic-combo-string), [Demon Crush: buffering and canceling](https://www.revertingcastles.com/2022/09/05/buffering-and-canceling-the-core-of-combat/), [GDQuest coyote time](https://school.gdquest.com/courses/learn_2d_gamedev_godot_4/side_scroller_character/double_jump_and_coyote_time), [Game Design Jar: coyote time + jump buffer](https://gamedesignjar.com/articles/coyote-time-jump-buffering-godot-4/).
- **Pitfall:** `Input.is_action_just_pressed` in `_process` versus `_physics_process` can drop presses when the frame rate is high. Read inputs in `_unhandled_input` and push them into the buffer.

**5. Juggles, launchers, wall/ground bounce**
- **Airborne state:** enemies are `CharacterBody2D`. While airborne they apply their own gravity, and every hit sets `velocity = attack.launch_vector` instead of adding to it.
- **Gravity scaling:** gravity rises with `juggle_count` (for example `g *= 1 + 0.15*n`) so infinite juggles decay. This is the standard anti-infinite rule.
- **Wall bounce:** in `move_and_slide()`, if `is_on_wall()` while in a `WALL_BOUNCE` state, set `velocity.x = -velocity.x * 0.6`, apply a small hit-stop and a shake, and let it happen once per combo.
- **Ground bounce:** works the same way off `is_on_floor()`.
- **Mera's size:** knockback should scale with her size. At 19x everything should fly.

**6. Hurt i-frames + bounded knockback**
- **On hit:** Mera enters `HURT` with 0.6–1.0 s of invulnerability. Disable the hurtbox (`set_deferred("monitorable", false)`) and blink with a `modulate.a` tween.
- **Knockback:** cap it, and clamp it near ledges. Hollow Knight's model works well: a short, fixed-distance knockback plus a long i-frame window.
- **Pitfall:** toggle collision with `set_deferred` inside physics callbacks, or Godot errors with "Can't change this state while flushing queries".

**7. Parry / perfect block → counter**
- **Parry window:** pressing block opens a 0.12–0.18 s `PARRY` window (a one-shot Timer), then the normal `BLOCK` state.
- **Resolving a hit:** the hurtbox checks Mera's state first.
  - If she's in `PARRY` and `attack.parryable`: no damage, `attacker.stagger(0.8)`, a long hit-stop, a gold flash, and the next X press becomes a riposte.
  - Heavy attacks push Mera back instead, as in Blasphemous.
- **Balance:** because enemy damage now *shrinks* Mera, parry is the skill-expression counterweight.
- **Links:** [Godot Forum parry thread](https://forum.godotengine.org/t/any-suggestions-for-how-to-make-a-parrying-mechanic/111401), [CursoGame.dev parry/block in Godot 4 (PT)](https://cursogame.dev/blog/godot-parry-bloqueio-escudo).

**8. Projectile deflection**
- **Approach:** projectiles are `Area2D` with a `team` property. If Mera's sword hitbox overlaps one during active frames, it flips direction and team, speeds up 1.5x, plays a spark, and applies a small hit-stop.
- **Use in the game:** the Fire Knight's bolts and the new Fire Skull and demon projectiles become counter-play.

**9. Grab & throw**
- **Grab:** a short-range `ShapeCast2D` in front of Mera.
- **Hold:** reparent the enemy to a `Marker2D` hold point, or pin its position each frame and disable its AI.
- **Throw:** release with a velocity. While `THROWN`, the enemy's hitbox damages other enemies and breakables, and bounces off walls (see #5).
- **Pitfall:** use `call_deferred` for reparenting, and restore collision layers when the throw lands.

**10. Breakables that drop pickups** (detail in §4)
- **Base scene:** `Breakable.tscn` is a `StaticBody2D` or `Area2D` hurtbox plus an `AnimatedSprite2D` with `idle`, `hit` and `break` animations.
- **Data:** `hp`, a `drop_table: Array[DropEntry]`, and `debris_scene`.
- **On break:**
  - Spawn 4–8 debris `RigidBody2D` chips with random impulses.
  - The chips fade and `queue_free()` after 1.5 s. Pool them.
  - Roll the drop table. It can reuse the existing potion and rage-sphere pickup scenes.
- **Candles:** use the Bloodstained rule, smart drops that give what you're low on.

**11. Secrets: breakable walls**
- **Tiles:** put breakable tiles on their own `TileMapLayer` with a custom-data `hp`.
- **Breaking:** an `Area2D` over the region receives hits, then calls `erase_cell(coords)`, spawns debris and plays a reveal stinger.
- **Terrain tiles:** for terrain-connected tiles, use `set_cells_terrain_connect([coords], 0, -1)` so neighbours re-autotile.
- **Hint:** add a tell, a hairline crack or a slightly different tile.
- **Links:** [Godot Forum: erase_cell terrain refresh](https://forum.godotengine.org/t/tilemaplayer-not-updating-certain-terrain-cells-after-using-erase-cell-at-runtime/76344), [YouTube: Godot 4 secret areas](https://www.youtube.com/watch?v=Q3XdElHNw-Q), [YouTube: destructible tiles](https://www.youtube.com/watch?v=B0Ooy2dFW3A).

**12. Summon allies / distraction** (t78u)
- **Ally structure:** each ally is a scene with a `lifetime`, a `cooldown` resource and a tiny state machine.
- **AI tooling:** [LimboAI](https://github.com/limbonaut/limboai) (MIT; behaviour trees + HSM; GDExtension) or [Beehave](https://github.com/bitbrain/beehave) (MIT; pure GDScript). **Don't install both**, because their `Blackboard` classes clash ([issue](https://github.com/limbonaut/limboai/issues/72)).
  - For only ~20 enemy and ally types, a hand-written enum state machine is fine and avoids GDExtension export work.
- **Dancing Girl distraction:** an `Area2D` "lure" group. Each non-boss enemy's AI checks `get_tree().get_nodes_in_group("lure")` and switches to `DISTRACTED`: path to the lure's x, then a hop loop.
- **Ally menu:** pause with `get_tree().paused = true` and set the menu's `process_mode = PROCESS_MODE_ALWAYS`, or slow time to 0.2 like Owlboy. Keep it to a single radial or row so swapping is quick, since Owlboy players complained it wasn't.

**13. Particles in the Compatibility renderer** (Fury aura, debris, earthquake dust)
- **Prefer `CPUParticles2D`** for anything critical.
  - `GPUParticles2D` works in Compatibility, but there are open reports of invisible particles and crashes on some GPUs ([#94915](https://github.com/godotengine/godot/issues/94915)).
  - The editor's *Convert to CPUParticles2D* menu translates existing systems.
- **Pixel art:** set `texture_filter = NEAREST` on the particle node. Small square textures (Kenney Particle Pack) read as pixels when scaled.

**14. 2D lights**
- **Use:** `PointLight2D` on candles, torches and the beam give gothic atmosphere.
- **Limit:** a single CanvasItem gets **at most 16 lights**, hard-coded ([proposal #9336](https://github.com/godotengine/godot-proposals/discussions/9336)). Keep lights sparse per area, or fake glow with additive `Sprite2D` halos.

**15. Ragdoll / physics death**
- **Full ragdoll:** possible with `Skeleton2D` + `PhysicalBone2D` ([docs](https://docs.godotengine.org/en/stable/classes/class_physicalbone2d.html)), but frame-by-frame pixel sprites have no skeletons, and there are open bugs ([#78367](https://github.com/godotengine/godot/issues/78367)).
- **Recommended instead:** a "corpse toss". On death, swap the enemy to a `RigidBody2D` showing its death-animation last frame, apply an impulse and angular velocity, let it bounce twice, then fade. That gets 90% of the fun at 5% of the cost.

---

## 3. Physics / juice add-ons (Godot) and FX art packs

**License policy:**
- ✅ CC0, MIT or permissive.
- ⚠️ Restricted (no redistribution, attribution, or non-standard terms).
- ⛔ Avoid: bans AI use or training, or bans derivatives. Already struck: aamatniekss, LuizMelo, willYEE, CraftPix.

**Repo note:** the repo is private, so "no redistribution" packs are OK to commit there, but they must never be put in a public repo.

### 3.1 Godot plugins

| Add-on | What it adds | Godot ver. | License / price | Fit & notes |
|---|---|---|---|---|
| [Whumpkit Lite](https://www.godotengine.org/asset-library/asset/5526) | Trauma camera shake + **hit-stop** that preserves existing slow-mo and stacks freezes correctly | **tested on 4.7.1** | ✅ MIT, free | Best drop-in for #1. Shake runs on real time during freezes. |
| [Juicee](https://godotassetlibrary.com/asset/PxBBKq/juicee) ([GitHub](https://github.com/Kelpekk/Juicee)) | 117 effects: shake, hit-stop, squash/stretch, hit sparks, damage numbers, accessibility toggles | 4.3+, all renderers | ✅ MIT (GitHub; the store page also mentions AGPL, so confirm against the repo LICENSE), free | Larger dependency. Good if you want damage numbers and reduced-motion options. |
| [Trauma camera shake](https://godotengine.org/asset-library/asset/4933) ([itch](https://filipbasara.itch.io/trauma-gd)) | Minimal trauma shake for Camera2D with profiles | 4.0+ | ✅ MIT, free (AI-assisted code disclosed) | Lightweight. Useful for the violent earthquake shake. |
| [Almios Free Screen Shake](https://dimensionalmios.itch.io/almios-free-screen-shake) | 9 shake types, 10 presets | 4.3–4.7 | ✅ MIT, free | Alternative. |
| [Phantom Camera](https://github.com/ramokz/phantom-camera/) | Camera framing, follow modes, limits, tweened transitions | 4.x | ✅ MIT, free | Not a shake tool. Useful for boss-arena framing and ally-summon zoom. The current camera is locked on Mera by design. |
| [GlobalTweens](https://github.com/Rp-ics/Godot-Engine-GlobalTweens) | 70+ one-line tween animations (squash/stretch, pop, wobble) | 4.x | ✅ MIT, free | Pickups, card pop-ins. |
| [GDNative-Ropesim](https://godotengine.org/asset-library/asset/2334) ([GitHub](https://github.com/mphe/GDNative-Ropesim/)) | Fast C++ **Verlet rope**: anchors, collisions, Line2D rendering, grabbable | 4.3+ | ✅ MIT, free | **Swinging chains, hanging cages, chandelier ropes.** GDExtension, so check the Windows export ships the .dll. |
| [cuberact-library CRope2D](https://godotengine.org/asset-library/asset/4898) | Rope with wind, breaking, collisions | 4.5+ | check page, free | Alternative if breakable ropes are needed. |
| [godot-polygon2d-fracture](https://github.com/SoloByte/godot-polygon2d-fracture) ([releases](https://github.com/SoloByte/godot-polygon2d-fracture/releases)) | Fracture or cut textured `Polygon2D` into shards; fake-rigid shards | 4.2+ | ✅ MIT, free | **Shatter any sprite** (crates, statues, knight shields). Shards of pixel art can look non-pixel-y at large scale; snap shard vertices to the pixel grid and use NEAREST filtering. |
| [Godot-4-2D-Destructible-Objects](https://github.com/VSeryi/Godot-4-2D-Destructible-Objects) | Splits a sprite into a grid of RigidBody blocks | 4.x | ✅ MIT, free | **The most pixel-art-friendly shatter**, since blocks stay square. Simple to adapt. |
| [SmartShape2D](https://github.com/SirRamEsq/SmartShape2D) + [destructible-terrain demo](https://github.com/CortezSMz/godot-smartshape2d-destructible-terrain) | Carve and merge terrain polygons | 4.x | ✅ MIT, free | Crater terrain from earthquakes and explosions. Probably overkill; tilemap erase is enough. |
| [Rapier Physics 2D](https://github.com/appsinacup/godot-rapier-physics) ([fast](https://godotengine.org/asset-library/asset/2267) / [deterministic](https://godotengine.org/asset-library/asset/2815)) | Replacement 2D physics engine: more stable stacking, more bodies | 4.x | ✅ MIT, free | Only if piles of debris or props jitter in Godot Physics. Not needed initially. |
| [LimboAI](https://github.com/limbonaut/limboai/) / [Beehave](https://github.com/bitbrain/beehave/) | Behaviour trees + state machines | 4.x | ✅ MIT, free | For the 16 new enemies and allies. Pick one, not both. |
| ⚠️ [FLX Tools](https://by-estudi.itch.io/flx-tools) | Juice toolkit | 4.6+ | $7.49, proprietary; can't be in public repos | Free MIT options above cover it. Skip. |

### 3.2 FX / debris / gib art

| Pack | Contents | License / price | Gothicvania fit |
|---|---|---|---|
| **ansimuz Legacy Collection FX — already owned** (`assets_survey/ansimuz/Legacy Collection/Assets/Explosions and Magic/`) | Explosions pack (7 variants), Ground Explosion, EnemyDeath, Hit, Warped hits 1–6, sparks, Grotto-escape-2 FX (slash, energy field, fireball, energy smack), Water splash | ✅ CC0 (per the project's existing licensing notes) | **Perfect**, same artist. Use first. |
| **ansimuz misc props — already owned** (`gothicvania-misc-props`) | Rocks textures (debris source), fantasy weapons set, dagger, enemy projectile | ✅ CC0 | Rock textures can be cut into debris chips. |
| [Kenney Particle Pack](https://kenney.nl/assets/particle-pack) | 80+ particle sprites (smoke, flame, sparks, light shapes) | ✅ CC0, free | Not pixel art. Downscale to 8–16 px with NEAREST, or use only as particle masks. Good for the Fury flame aura. |
| [Kenney Smoke Particles](https://kenney.nl/assets/smoke-particles) | 77 smoke, explosion, flash and puff sprites | ✅ CC0, free | Same caveat. Dust for the earthquake and landings. |
| [OGA "Gore Blood Gibs Meat Chunks"](https://opengameart.org/content/gore-blood-gibs-meat-chunks)† | Blood spray pixels, meat and bone chunks, splash | ✅ CC0 (per listing), free | Optional; tone-dependent. Use only if the user wants gore. |
| [OGA "Bloodspatter and Gibs"](https://opengameart.org/content/bloodspatter-and-gibs)† | Gore particle sheet | ✅ CC0, free | Same as above. |
| [OGA "Pixel Explosion"](https://opengameart.org/content/pixel-explosion)† / [16x16 Explosion](https://opengameart.org/content/16x16-explosion)† | Metal Slug-style explosions | see listing (CC0/CC-BY), free | Backup to ansimuz explosions. |

---

## 4. Interactable & destructible objects

### 4.1 Object ideas (mapped to Godot nodes)

| Object | Behaviour | Godot build | Source sprites |
|---|---|---|---|
| **Candles / candelabras** | One hit breaks; drops rage, potion or stamina using the Bloodstained "give what you're low on" rule | `Breakable` (Area2D hurtbox + AnimatedSprite2D) + optional `PointLight2D` (watch the 16-light cap) | Gothicvania Interiors ⚠️ (candle, chandelier), Pozac ⚠️, ~~Cyangmou~~ ⛔ |
| **Urns / pots / crates** | 1–3 HP; debris chips; drop table; Mera stomping at large size auto-breaks them | `Breakable` + pooled `RigidBody2D` chips, or the grid-shatter plugin | Elthen ⛔/⚠️, Pixel Frog box ✅, THRESHOLD urn/barrel ⚠️ |
| **Explosive barrels** | Hit, then a 0.6 s fuse flash, then an AoE explosion that damages enemies and Mera. Because only explosions get through the Fire Knight's block, **barrels become a tactical anti-block tool** | `Breakable` + `Area2D` blast (one-frame `monitoring`) + shake + hit-stop | [Jimmy D. Journey exploding barrel](https://jimmydjourney.itch.io/oil-barrel-and-explosive-oil-barrel) ✅ CC0; Kings and Pigs bomb ✅ |
| **Falling chandeliers** | Hit the rope or chain, it drops, crushes and stuns enemies below, then breaks into debris | `RigidBody2D` chandelier + `PinJoint2D` or Ropesim chain; on break, `freeze=false` | Gothicvania Interiors chandelier ⚠️ |
| **Swinging chains / hanging cages** | Physics flavour; Mera can knock them, and they hit enemies | Ropesim rope + `RigidBody2D` weight | ansimuz tiles; THRESHOLD falling cage ⚠️ |
| **Levers / pressure plates** | Open doors, drop portcullises, trigger traps on enemy waves | `Area2D` + `signal activated`; doors are `AnimatableBody2D` | THRESHOLD ⚠️ (top-down perspective, check fit), Kings and Pigs door ✅ |
| **Crumbling platforms** | Shake 0.4 s after landing, fall, respawn after 3 s. Breaks instantly under Mera at large size | `AnimatableBody2D` + tween; one-way collision | [finalbossblues Pixel Platformer Pack](https://finalbossblues.itch.io/pixel-platformer-pack) ✅ CC0 (crumbling block); recolour to the Gothicvania palette |
| **Breakable secret walls** | Hidden rooms with ally cards or max-stamina potions | Separate `TileMapLayer` + `erase_cell` (see §2 #11) | Existing ansimuz tilesets + a crack overlay |
| **Spike / axe / saw traps** | Damage everyone. Throws (#9) send enemies into them | `Area2D` hazard, team-agnostic | [PixLeroy swinging axe](https://pixleroy.itch.io/pixel-traps-axe-trap) ⚠️ free, credit optional |
| **Treasure chests** | Hit to open; burst of pickups | `Breakable` with `open` animation instead of `break` | Kings and Pigs ✅, greatdocbrown ✅, ansimuz Interiors ⚠️ |
| **Pickups** (hearts, gems, potions) | Magnet towards Mera; bob tween | `Area2D` + tween | [Foozle Lucifer Pickups](https://foozlecc.itch.io/lucifer-pickups) ✅ CC0; [greatdocbrown coins/gems/chests](https://greatdocbrown.itch.io/coins-gems-etc) ✅ CC0; ansimuz gems (owned) ✅ |

### 4.2 Pack table (license-checked 2026-10-31)

| Pack | Contents | License | Price (today) | Style fit with Gothicvania |
|---|---|---|---|---|
| [ansimuz Gothicvania Interiors](https://ansimuz.itch.io/gothicvania-interiors) | Candle, **chandelier**, chest, crate, platform, tables, weapon racks, 3 NPCs, house tileset | ⚠️ commercial OK, modification OK, **no redistribution** (fine in the private repo) | $13.99 (sale, normally $19.99) | ★★★★★ same artist |
| [ansimuz Gothicvania Collection](https://ansimuz.itch.io/ultimate-gothicvania-collection) | Environments, props, items (potions, scrolls, food, crystals), FX, bosses (Dragon, Wendigo), music | ⚠️ same terms as above | $104.99 (sale, normally $149.99); bundle $299 | ★★★★★. Check overlap with the CC0 Legacy Collection already owned. Probably a superset with extra props and items. |
| [ansimuz Magic Castle](https://ansimuz.itch.io/magic-castle-tileset) | Castle tiles, doors, torches, props | ⚠️ same terms | $17.49 (sale) | ★★★★★ |
| [Pixel Frog — Kings and Pigs](https://pixelfrog-assets.itch.io/kings-and-pigs) | **Box, bomb + explosion, cannon, door, diamond, heart** | ✅ **CC0** | free | ★★★ cuter and brighter. Fine as placeholders or recoloured. |
| [Jimmy D. Journey — Exploding Oil Barrel](https://jimmydjourney.itch.io/oil-barrel-and-explosive-oil-barrel) | 32×32 barrel + 12-frame explosion | ✅ **CC0** | free | ★★★ (oil drum is modern; recolour as a powder keg) |
| [finalbossblues Pixel Platformer Pack](https://finalbossblues.itch.io/pixel-platformer-pack) | Crumbling block, spikes, platforms | ✅ CC0 (dedicated by the author in comments) | free (pay what you want) | ★★ recolour needed |
| [Foozle Lucifer Pickups](https://foozlecc.itch.io/lucifer-pickups) | Animated gems, gold, potions | ✅ **CC0** | free | ★★★★ |
| [Foozle Critters — Old Castle](https://foozlecc.itch.io/critters-old-castle) | Castle platformer tileset + parallax + pickups | ✅ **CC0** | free | ★★★ |
| [greatdocbrown Coins & Gems & Chests](https://greatdocbrown.itch.io/coins-gems-etc) | 16×16 coins, gems, chests, keys, hearts, potions, food | ✅ **CC0** | free | ★★★ |
| [Pozac Dark Castle Platformer](https://pozac.itch.io/cute-dark-castle-platformer-2d-pixel-art-asset-pack) | Animated candles and torches, **breakable crates**, collectibles, castle tiles (32×32) | ⚠️ commercial OK, no resale or redistribution; no AI clause seen | $2.49 (sale) | ★★★ "cute" dark castle |
| [PixLeroy Swinging Axe Trap](https://pixleroy.itch.io/pixel-traps-axe-trap) | 128×128 pendulum axe with chain | ⚠️ commercial OK, no redistribution as-is | free (pay what you want) | ★★★★ |
| [THRESHOLD — 47 Animated Interactables](https://godboyhappy.itch.io/threshold-animated-interactables) | Doors, chests (with mimic), levers, plates, chain pull, lights, portals, traps, breakable barrel and urn; **ships Godot 4 SpriteFrames** | ⚠️ commercial OK, no credit, no redistribution; scripts MIT | $2.49+ | ★★ **top-down perspective**, so many objects won't read in side view. Side-view-agnostic items (urn, barrel, torch, lever) might work. |
| ⛔ [Elthen Destructible Objects](https://elthen.itch.io/pixel-art-destructible-objects) | Crate, barrel, signs, pot with damage and destroy animations, chest | CC BY-NC + commercial exception; **newer license bans use for AI training** ([license](https://www.patreon.com/elthen/posts/licensing-27430241)†) | free | Nice, but avoid under the AI-clause policy. |
| ⛔ [Cyangmou 60 Animated Light Props](https://cyangmou.itch.io/pixel-side-scroller-animated-lights) / [Side-Scroller Dungeon Tileset](https://cyangmou.itch.io/pixel-side-scroller-dungeon-tileset) | Candles with burning, off and destroyed states + destruction particles; dungeon chains, saws, plates | **License forbids feeding the assets into any third-party AI model** ([agreement](https://docs.google.com/document/d/1tNBRxfKhTqwgsrTTRD-nMbe6zew1c-u7yMaOj6vOKrI/edit?usp=sharing)) | $7.49 / $3.74 | Great style fit, but **avoid**: an AI agent viewing or processing the art would breach it. |
| ⛔ [RGS_Dev Animated Traps](https://rgsdev.itch.io/animated-pixel-art-traps-for-2d-platformer-game-dungeon-castle-rgsdev) | Spikes, saws, axe pendulum, cannons | **CC BY-ND 4.0**, no derivatives (no recolours) | $1.30 | Avoid. |
| ⛔ [Seliel Animated Candles](https://seliel-the-shaper.itch.io/animatedcandles) (Mana Seed) | Candles and braziers | **License bans use in any project containing AI-generated content** ([license](https://selieltheshaper.weebly.com/user-license.html)) | paid | **Hard avoid.** Top-down anyway. |
| [Icarus Studios 24 Castle Interior Props](https://icarusstudios.itch.io/24-pixel-art-castle-interior-props) | Castle props | license not stated on page | $1.99 | Top-down; skip. |

**Bottom line on art:**
1. Use the owned ansimuz CC0 FX and props first.
2. Fill gaps with CC0 Pixel Frog, Jimmy D. Journey, Foozle, greatdocbrown and finalbossblues.
3. If budget allows, **ansimuz Gothicvania Interiors ($13.99)** is the single best paid buy. It's by the same artist and has the candle, chandelier, crate and chest needed for §4.1.

---

## 5. Prioritised recommendations — top 8

Effort assumes one agent familiar with the codebase. "S" is under half a day, "M" is about 1 day, "L" is 2–3 days.

| # | Feature | Why (evidence) | Effort | Dependencies / assets |
|---|---|---|---|---|
| **1** | **Hit-stop + hit flash + hit sparks + SFX variance** ("impact pass") | The #1 praised feel element (Dead Cells crit recipe, HK, SoR4). Mera has shake but no hit-stop. | **S** | Whumpkit Lite (MIT) or a ~40-line autoload; owned ansimuz Hit/Warped FX; Kenney SFX + `AudioStreamRandomizer` |
| **2** | **Input buffer + cancel windows + coyote/jump buffer** | The user's own "combos feel clunky" complaint; Dead Cells "does what you mean". | **M** | Pure GDScript; AnimationPlayer method tracks per attack |
| **3** | **Breakables with drop tables** (candles, urns, crates, chests) + smart drops | Castlevania/Bloodstained signature; fills the new large maps; gives potions and stamina a source besides knights. | **M** | Owned ansimuz rocks for debris; CC0 Pixel Frog / Foozle / greatdocbrown; optional Gothicvania Interiors $13.99 |
| **4** | **Explosive barrels + falling chandeliers** | Dynamic set pieces. **Synergy:** explosions pierce the Fire Knight's block, so barrels become tactics. Chandeliers are a gothic crowd-stun. | **M** | Jimmy D. Journey CC0 barrel; `RigidBody2D` + `PinJoint2D` (or GDNative-Ropesim, MIT) |
| **5** | **Juggle physics: gravity scaling, wall and ground bounce, corpse toss** | SoR4 / Guacamelee's most-loved addition; corpse toss gives cheap ragdoll fun. | **M** | CharacterBody2D states; RigidBody2D death proxy |
| **6** | **Parry / perfect block → riposte + projectile deflect** | Blasphemous, Katana ZERO and Dead Cells praise it. A skill counterweight to 2-size hits. Deflected bolts against the Fire Skull, demons and the dragon. | **M** | Needs a button: L2 is taken by lightning after t78u, so map it to B tap-timing or block-in-place. Ask the user. |
| **7** | **Telegraph and attack-rule standard (`AttackData` resource) for the 16 new enemies** | Blasphemous's top complaint is unclear tells and inconsistent rules. Doing this *while* building the t78u roster prevents rework. | **S–M** (framework S; per-enemy cost folds into roster work) | AnimationPlayer method tracks; colour-language doc in the controls screen |
| **8** | **Secret breakable walls + crumbling platforms + one lever/door puzzle per level** | Secrets are the most-cited exploration reward (SotN, Bloodstained, Blasphemous); good places to hide the t78u ally cards. | **M** | `TileMapLayer` erase; finalbossblues CC0 crumbling block recoloured; Kings and Pigs door |

**Also worth considering later:**
- Grab-and-throw (Guacamelee/SoR4; **L**).
- Combo counter feeding rage (S).
- Swinging-chain physics with Ropesim (M).
- Polygon-fracture shatter on the boss dragon's armour (M).
- Juicee's reduced-motion and flash accessibility toggles. These matter because the earthquake shake is "very fast and violent" by request.

### Pitfalls checklist for whoever implements this
- Restore `Engine.time_scale` with an `ignore_time_scale` timer, and keep Fury's slow-mo intact when doing so.
- Use `set_deferred` / `call_deferred` for collision and reparent changes inside physics callbacks.
- Use `CPUParticles2D` for important effects in Compatibility, and NEAREST filtering on all pixel FX.
- Keep lights to 16 or fewer per CanvasItem. Prefer additive-sprite glows for candle rows.
- GDExtension add-ons (Ropesim, LimboAI, Rapier) need their Windows binaries in the export. Test the `.exe`, not just the editor.
- Don't install Beehave and LimboAI together.
- Licenses:
  - ⚠️ packs can't be pushed to any public repo.
  - Never use ⛔ packs.
  - Log every new asset in the repo's credits/licence notes.


## 6. User decisions (2026-10-31, t79u)
- **Yes** to all of the top-8 recommendations, including #6. The parry is a perfectly timed barrier raise (L2 within about 0.15 s before a hit lands): parry, then a counter window and projectile deflect. No new button.
- **Yes** to gore and gibs, using free CC0 gib packs.
- **No paid packs.** Gothicvania Interiors is skipped; use free CC0 props instead.
- **Debris/shatter sim:** destroyed objects and enemies break into pieces, either sprite fracture into RigidBody2D shards or CPUParticles2D shards. It must be MIT/CC0, must work on the Compatibility renderer, and must be tested in the Windows exe.
