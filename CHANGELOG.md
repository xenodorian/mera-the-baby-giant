# Changelog

All releases are GitHub pre-releases/releases of `xenodorian/mera-the-baby-giant` (public since 2026-10-31; art packs in the private `mera-assets` submodule). Engine: Godot 4.7.2, Compatibility renderer, native 1920×1080.

## v0.9.9-playable (2026-10-31)
Windows build only. Linux and Android are not attached. `SHA256SUMS.txt` covers the exe.
- Download: https://github.com/xenodorian/mera-the-baby-giant/releases/download/v0.9.9-playable/Mera_Playable_v0.9.9_Windows.exe
- **The run is not wiped.** Potions, ally cards, mana, rage, max mana and max rage stay across levels, deaths, the level select, and quitting the game. It is saved on this computer.
- **A death puts Mera back at 2x.** Clearing a level keeps her current size.
- Android `versionCode` 20, `versionName` 0.9.9 (APK not published).

## v0.9.8-playable (2026-10-31)
Windows build only. Linux and Android are not attached. `SHA256SUMS.txt` covers the exe.
- Download: https://github.com/xenodorian/mera-the-baby-giant/releases/download/v0.9.8-playable/Mera_Playable_v0.9.8_Windows.exe
- **Clearing a level keeps the run.** Potions, ally cards, size, mana, rage, max mana and max rage come with you. Dying retries that level with what you had when you entered it. Going back to the level select starts over.
- Android `versionCode` 19, `versionName` 0.9.8 (APK not published).

## v0.9.7-playable (2026-10-31)
Windows build only. Linux and Android are not attached. `SHA256SUMS.txt` covers the exe.
- Download: https://github.com/xenodorian/mera-the-baby-giant/releases/download/v0.9.7-playable/Mera_Playable_v0.9.7_Windows.exe
- **Every enemy chases and attacks Mera.** The brawler no longer pulls them off her.
- **While the Dancing Girl is dancing, every enemy, bosses included, runs to her and jumps.** They go back to Mera when the dance ends.
- **Three rage attacks, each costs 100:**
  - **R2** — Fury for 12 s.
  - **L2+R2** — lightning. Does not empty a raised meter.
  - **L1+R1+L2+R2** — freeze slash. Marks up to 9 enemies; cut each for 3. Does not start Fury.
- Android `versionCode` 18, `versionName` 0.9.7 (APK not published).

## v0.9.6-playable (2026-10-31)
Windows build only. Linux and Android are not attached. `SHA256SUMS.txt` covers the exe.
- Download: https://github.com/xenodorian/mera-the-baby-giant/releases/download/v0.9.6-playable/Mera_Playable_v0.9.6_Windows.exe
- Every summon lasts **20 seconds**.
- **Brawler Girl** lands in front of Mera and runs right until she leaves. She stops only to fight, or when a wall or a closed door is in front of her. Non-boss enemies chase her. Bosses still come for Mera.
- **Dancing Girl** walks out in front of Mera, stops, and dances for **5 seconds**. Then she waits out the rest of the 20.
- **Water Priestess** heals Mera to 6x when she arrives, and once more just before she leaves.
- **L1 inside either bubble drinks a potion and the bubble stays up.** Every other button still drops the bubble and does that move.
- **Summon picker:** portraits are cropped to the character. The blank white sheet is gone.
- **L2 alone is the full bubble.** It is not a lightning tap.
- **L2+R2 drops lightning** (needs 100 rage, spends the bar). R2 while the bubble is up drops the strike and the bubble stays.
- **R2 alone starts Fury**, and Fury spends **100 rage** only. A raised meter keeps the rest. The red bar during Fury is the 12 s timer.
- **Drinking a potion is four times as fast.** The heal plays at 4×.
- **Any projectile damages objects:** bolts, fireballs, ranger arrows, enemy shots, and the dragon's bolts.
- Android `versionCode` 17, `versionName` 0.9.6 (APK not published).

## v0.9.5-playable (2026-10-31)
Windows build only. Linux and Android are not attached. `SHA256SUMS.txt` covers the exe.
- Download: https://github.com/xenodorian/mera-the-baby-giant/releases/download/v0.9.5-playable/Mera_Playable_v0.9.5_Windows.exe
- Every level now ends. The exit stays shut until that level's fight is over, then the gate at the right edge clears it.
- **Moonlit Cemetery** no longer sends Fire Knights forever. Five of them, then the gate opens ("SLAY THE KNIGHT" until the last one and his Blue Knights are dead).
- **Misty Woods** and **Moonlit Town** stop calling enemies once their waves are done and the field is clear ("CLEAR THE ROAD").
- **Infernal Caverns** is unchanged: the gate stays shut until the dragon falls. Clearing the last level returns to the level select instead of wrapping back to the cemetery.
- Android `versionCode` 16, `versionName` 0.9.5 (APK not published).

## v0.9.4-playable (2026-10-31)
Windows build only. Linux and Android are not attached. `SHA256SUMS.txt` covers the exe.
- Download: https://github.com/xenodorian/mera-the-baby-giant/releases/download/v0.9.4-playable/Mera_Playable_v0.9.4_Windows.exe
- The resource formerly called stamina is now **mana**. Same bar, same costs. Max mana potions cap at **200**.
- **Full bubble** stops all damage. **Small bubble** subtracts 1 from a hit (a hit of 1 is stopped; a hit of 3 costs 2 size) and does not knock her down.
- The small bubble lasts **3 seconds**. A dial around it empties, then the bubble drops even if she stays crouched. Crouch again for a new one.
- Any button while either bubble is up drops it immediately and does that move.
- A defeated enemy drops one thing: rage, a green potion, a blue mana potion, +5 max mana, or +5 max rage (cap 200). The two meter upgrades are the rare drops.
- Android `versionCode` 15, `versionName` 0.9.4 (APK not published).

## v0.9.3-playable (2026-10-31)
Windows build only. Linux and Android are not attached. `SHA256SUMS.txt` covers the exe.
- Download: https://github.com/xenodorian/mera-the-baby-giant/releases/download/v0.9.3-playable/Mera_Playable_v0.9.3_Windows.exe
- **Parry knockback** is a set distance, not a long shove. A timed full-bubble parry slides the attacker **400 px** and stuns them for **2 s**. A timed crouch-bubble parry slides them **200 px** and stuns them for **1 s**. Holding the full bubble, after the parry window, slides them **200 px** and does not stun. Bosses stay put.
- Android `versionCode` 14, `versionName` 0.9.3 (APK not published).

## v0.9.2-playable (2026-10-31)
Windows build only. Linux and Android are not attached (the release keystore is not in this checkout). `SHA256SUMS.txt` covers the exe.
- Download: https://github.com/xenodorian/mera-the-baby-giant/releases/download/v0.9.2-playable/Mera_Playable_v0.9.2_Windows.exe
- **Crouch bubble:** holding Down raises a small barrier for free (no stamina). It is smaller than the L2 bubble (radius 32 art px, around the crouch, versus ~46 for the full barrier).
- A crouch started within 150 ms of a hit **parries** like L2: no damage, the attacker is staggered and knocked back, projectiles fly back, and the counter window (hits ×2 for 0.9 s) opens.
- Holding the crouch past that window **cuts the damage by 75%** (a quarter gets through, and four hits of 1 drop one size). She stays crouched. It does not knock her down.
- Android `versionCode` 13, `versionName` 0.9.2 (APK not published).

## v0.9.1-playable (2026-10-31)
Windows build only, published as a full release (not a pre-release). Linux and Android are not attached (the release keystore is not in this checkout). `SHA256SUMS.txt` covers the exe.
- Download: https://github.com/xenodorian/mera-the-baby-giant/releases/download/v0.9.1-playable/Mera_Playable_v0.9.1_Windows.exe
- **Rising slash** (t108u): the windup plays at 4× (every frame kept). The rise is 2× faster (`RSLASH_VY` -760, was -380) over the same frames, so she goes about twice as high.
- **Pause** (t108u): Start / Enter / F1 freezes gameplay and opens the controls overlay. Start again resumes. After Game Over it still restarts. The ally picker is unchanged.
- **Swing parry** (t103u): X (`atk1` or `jatk1`) reflects an enemy projectile, including a dragon bolt, when the hitbox meets it within 150 ms of going live. The shot flies at its shooter, or the nearest enemy, and damages them.
- **Melee parry** (t103u): an L2 parry still staggers and opens the counter, and now also knocks the attacker back hard (bosses stay put).
- **Projectile clashes:** a player shot and an enemy shot both explode. The combo beam and the vertical beam destroy enemy projectiles.
- Carried from the merged Y-chain branch: Y follow-ups, YYYY beam, YYY+L2 pulse, YYY+X vertical beam, Up+Y vertical quick fire, air bubble, two monsters from behind on levels 2–4, and the `mark_slash.gd` export fix.
- Android `versionCode` 12, `versionName` 0.9.1 (APK not published).
- Tests: **406 pass, 0 fail**.

## v0.9.0-playable (2026-10-31)
First release from the new **public** repo. Pre-release with Windows, Linux and Android (ARM) builds, plus `SHA256SUMS.txt`.
- **In-game updater** (`docs/UPDATER.md`):
  - the title menu checks the public GitHub releases at launch (no token) and shows a banner when a newer build exists;
  - **CHECK FOR UPDATES** downloads it, verifies its size and SHA-256 against the release's `SHA256SUMS.txt`, and installs it;
  - Windows/Linux: a helper swaps the exe after the game exits and relaunches it;
  - Android: opens the system installer, signed with the same key, so it updates in place;
  - no network or other errors only show a message.
- **Credits screen** on the title menu (bottom row → CREDITS): every pack author with license and link (chierit CC-BY 4.0 for Fire Knight, Water Priestess, Leaf Ranger and Minotaur; ansimuz; Merakintsugi; Kenney; Pixel Frog; Jimmy D. Journey; Reactorcore; rubberduck; vk) and Godot's MIT notice (godotengine.org/license). A selects an entry and opens its page.
- The title menu shows the build version (bottom right). `project.godot` now holds `application/config/version`; the Android version code is 11.
- **Marked slash** (other agent's PR, carried over): L1+R1+L2+R2 (keyboard Q+W+1+2) with Fury on or a full meter freezes the world for up to 8 s and marks up to 9 enemies 1–9. The matching key, numpad, right-stick flick, swipe or tap cuts each for a flat 3. The numpad is the right stick.
- Fix: the dragon never reuses a lob spot in a phase, and cramped sides spread near/far/middle (fixes a flaky 12x test).
- Repo: code and docs are public at `xenodorian/mera-the-baby-giant`; the art packs live in the private `mera-assets` submodule; the old history is archived privately. See `docs/WORKFLOW.md`.
- Tests: **360 pass, 0 fail**, plus `tools/updater_e2e.sh` (real Linux export: bad checksum refused, swap + relaunch, offline).

## v0.8.2-playable (2026-10-31)
Dragon bolt fix (user feedback t91u). Pre-release with Windows, Linux and Android (ARM) builds.
- **Bolts no longer fly backwards.** The ansimuz fireball art faces **left**: blunt round head on the left, flame trail on the right. The bolt used to rotate it as if it faced right. Now it mirrors the art (`flip_h`), rotates it to the velocity, and uses `flip_v` when flying left so the flame curl stays on top. The blunt head leads and the flame trails for the whole arc (`dragon_bolt.gd` `_orient()`, `NATIVE_HEAD`).
- **Horizontal launch out of the mouth.**
  - He faces Mera and spits from his mouth (the open-mouth spit frame; mouth measured on the art, scaled and mirrored), with no upward leap from his head.
  - The bolt leaves horizontally (vy = 0) and gravity curves it down onto the target. The arc is re-solved: flight time = √(2·drop/G), vx = dx/time.
  - Lob spots keep Mera at least mouth reach + 160 px in front of him; at large sizes they spread across the remaining room (he may now show about 80 % of his body at the screen edge).
- Tests: **336 pass, 0 fail**. New checks:
  - the fireball art faces left;
  - the blunt head points along the velocity at launch, apex and descent (a real lob and horizontal shots, both directions);
  - every bolt spawns at the mouth, below the head top;
  - launch vy ≈ 0 and toward Mera;
  - every bolt ends within the aim spread of Mera;
  - at 3x the lobs span ≥ 400 px, from both sides.

## v0.8.1-playable (2026-10-31)
Infernal Dragon flight fix. Pre-release with Windows, Linux and Android (ARM) builds.

### Dragon flight
- **Wing loop:** while flying he plays a new looping **`fly`** animation. These are the 4 frames the user picked from the ansimuz breath frames, in their order (breath 1, 5, 4, 5), at **11 fps**. They use the plume-free copies, so there's no fire at all, including the small fireball in breath frame 4. This replaces the old trick of playing the idle frames 2.2x faster. The bob is snappier: 26 px at 1.6 Hz.
- **He flies around the map between lobs.** In each phase (12x, 9x, 6x, 3x) he flies to a new spot before each of the 5 bolts:
  - the spots are short, mid and long from Mera, in front of her and behind (he crosses over her), at heights of 250–470 px, in a new order every phase;
  - he glides there in 0.8 s, gives the red tell, then lobs one bolt on the `spit` frames;
  - he stays inside the walls and mostly on screen: the bigger he is, the closer he stays to the screen centre;
  - each lob's arc is solved for its distance, with a flight time of 0.8 s + 1 s per 1000 px (0.85–1.6 s). The first bolt is aimed at Mera; the others land within ±140 px of her (was ±220).
- **Unchanged:** each phase runs once per threshold; any bolt hit gives +3 sizes, once per phase; he always lands afterwards (now wherever he is); the ground fire breath keeps its plume.

### Dragon volley: no breath plume
- The ansimuz breath frames have the fire plume drawn in, and the volley played them, so every lobbed bolt came out with a full breath. The volley now uses **`spit`** frames: copies of the breath frames with the plume's 3 colours made transparent (`tools/build_dragon_spit.py`; the originals are untouched). A small muzzle spark marks each launch. The ground fire breath attack is unchanged (separate code path).

### Tests
- **331 pass, 0 fail** (`--fixed-fps 60`). New checks:
  - the fly loop's frames and order, and no fire in it;
  - the volley never shows `breath` or the idle frames, and no plume pixel in any frame shown;
  - 5 lobs from at least 3 distinct spots, with distances spread over at least 400 px, from both sides of Mera;
  - on screen and inside the walls the whole phase;
  - flight time grows with distance;
  - the ground breath keeps its plume.

## v0.8-playable (2026-10-31)
Stage S4 of `docs/WORKFLOW.md`. Pre-release with **Windows, Linux and Android (ARM) builds**. From now on every version ships a Windows `.exe` **and** an Android APK.

### Impact pass
- **Hit-stop** on every landed hit (45 ms normal, 80 ms heavy, 100 ms kill, 120 ms parry, capped at 120 ms; `HitStop` autoload). It restores `Engine.time_scale` per physics tick, and Mera's input clock keeps real time, so combo windows are unchanged.
- **Sparks + flash** on every hit (props too); **SFX variance**: random take + ±8 % pitch on impacts.
- **Shatter/debris sim** (`scripts/game/debris.gd`, pure GDScript, one draw call, works on Compatibility): props and dead enemies break into textured shards that fly, spin, bounce and fade.
- **Gore** (CC0 Reactorcore gibs + blood); undead burst into bones, ghosts and flame enemies into glowing mist.

### Breakables, barrels, chandeliers (levels 2-4; level 1 untouched)
- Candles (1 hit), urns (1), crates (2), chests (3) with **smart drops** weighted by what Mera needs (size, stamina, rage).
- **Explosive barrels:** 8 fixed damage + launch in 300 px, pierce the Fire Knight's block, **chain** to other barrels, drop chandeliers.
- **Chandeliers** (Moonlit Town, Infernal Caverns): hit, blast or **earthquake** them down; they crush enemies below (6 damage + 2.5 s stun).

### Super earthquake (t87u)
- **Down+Y crouching with a full rage meter (outside Fury):** an anime **impact frame** (0.16 s freeze, black/white inverted silhouette, `shaders/impact_frame.gdshader`), then a **2 s** quake with a 70 px shake: grounded enemies are stunned **7 s** from its start, **every enemy takes a flat 2** (the dragon's size pool too, the Fire Knight's guard doesn't stop it), and **every ground breakable on screen** is destroyed (barrels chain, chandeliers fall).
- Costs 20 stamina (unchanged) plus the whole meter. In Fury, or below 100 %, Down+Y is the normal quake.

### Juggles
- Launchers (`atk3`, `atk2_1`, `datk2`, explosions) throw ground enemies up; air hits keep them up with **escalating gravity** (max 8); one **ground bounce**; **wall bounce** (+1 damage).
- **Corpse launch:** defeated enemies fly away from the killing blow, spin, and shatter where they land.

### Parry (L2, no new button)
- L2 pressed within **150 ms** before a hit: no damage, the attacker staggers 1.2 s, **0.9 s counter window (×2 damage)**; projectiles are **deflected** back.

### Secrets
- 3 of the 4 ally cards on each of levels 2-4 are hidden: behind a **cracked wall** (4 hits), behind a **door opened by a lever**, or on a **ledge** reached from a **crumbling plank** (breaks under Mera, grows back after 6 s). One-way platforms: Mera stands on them and falls off their edges.

### Infernal Dragon rework (t85u)
- **Size is health:** starts at **19x**, one size per 8 damage, down to 1x; dies when hit at 1x. Smooth size tween, feet on the ground, hit boxes scale. Damage never scales.
- **Phases at 12x / 9x / 6x / 3x, once each** (a big hit queues every crossed one): takes off (faked flight: no wing frames in the pack), spits **5 lobbed explosive fire bolts** onto Mera (red tell + ground ring each), then **always lands**. If any bolt hurts Mera, he **grows +3 sizes** (once per phase; used thresholds stay used).
- Boss bar shows his size ("12x") with a notch per size.

### PC keyboard controls (t86u)
- **Arrows** = d-pad, **Z** = A (Space too), **X** = B, **A** = X, **S** = Y, **Q** = L1, **W** = R1, **1** = L2, **2** = R2 (keypad 1/2 too); Enter/F1 = Start, Tab/G = Back, F2 debug, F11/Esc unchanged. The old WASD/Shift/J/K/L/U/I/O/P keys are gone.
- Same actions as the pad, so chords (A+S, X+S, Z+S, 1+2, Down+S), L2 tap vs hold and the parry window behave identically (replayed with real key events in the tests). Menus: arrows + Z (confirm) / X (back); Z also restarts after Game Over.
- The controls overlay shows a keyboard column next to every pad button (`previews/playable/v0.8/shot_controls_keyboard.png`). A test checks that no key is shared by two actions and none uses Esc/F11.

### Balance and fixes
- **Fire Knight:** normal hits **1** size (was 2), special **2** (was 3).
- **Allies scale with Mera** (1.1 × her height, smoothly) instead of a fixed 4x.
- **Dancing Girl:** natural skin tone (same 3-colour skin-ramp swap as ansimuz's Brawler Girl recolor, on copies; her yellow/olive dress is untouched). `previews/playable/v0.8/dancer_skin_before_after.png`.
- Crate art recoloured to wood brown.
- **Android L2 bug** (user report on v0.4 with a mobile pad: L2 raised the shield *and* fired another action with on-screen text): Android sends a digital L2/R2 as joypad buttons 15/16 and some pads' SDL mappings also put L2 onto Back/Start (gallery / controls overlay). L2/R2 now also listen to 15/16, nothing else shares a trigger axis or those buttons, and joypad Start/Select are ignored when they arrive together with trigger activity. See `docs/CONTROLS.md` "Gamepads on Android".
- HUD: no error when the boss is freed.

### Builds
- New **Android** export preset: ARM only (arm64-v8a + armeabi-v7a, no x86), Compatibility renderer, landscape (sensor), immersive, gamepad-ready (`isGame`), package `com.merakintsugi.mera`, versionCode 8. Release-signed with a keystore kept on the build box (never in the repo).
- A **v0.7 APK** was also built (from the v0.7 tag, unchanged gameplay) and attached to the v0.7 release.

### Tests
- **323 pass, 0 fail** (`--fixed-fps 60`): S4 adds input-map collision checks (no two actions share a joypad button/axis or a key; phantom Start/Back with L2 is dropped), keyboard replays (chords, 1 tap/hold, 1+2, Down+S, Z restart), hit-stop timing and restore, SFX jitter, corpse launch + shatter, juggles (launch, air hits, escalating gravity, ground and wall bounce), parry (timing, counter ×2, late L2, projectile), breakables, smart drops, barrel chains, chandelier crush, secret wall / door / ledge / crumbling plank, ally scaling, and the dragon (19x start, phases once each at 12/9/6/3, queued phases, +3 on a bolt hit, no re-arm, always lands, dies at 1x), and the super earthquake (impact frame before the quake, 2 s / 7 s, flat 2 to all incl. the dragon, ground props destroyed, whole meter + 20 stamina, normal quake below 100 % and in Fury).

## v0.7-playable (2026-10-31)
Stage S3 of `docs/WORKFLOW.md`. Pre-release with Windows and Linux builds.

### Allies, cards and the R1 picker
- **Cards:** levels 2-4 each have 4 colour-coded ally cards: blue Water Priestess, green Leaf Ranger, orange Brawler Girl (ansimuz skin-recolor version), pink Dancing Girl. Level 1 is unchanged.
- **R1 summons:** one card type is summoned at once; with several types a **picker** opens (the game pauses).
- **Limits:** at most 2 allies at once, one of each type. They stay 25 s (the dancer 12 s).
- **Water Priestess:** heals Mera **up to 6x** at most every **30 s**, plus water attacks 1-3, the special, air attacks, guard, tumble and surf.
- **Leaf Ranger:** arrows (with hit sprites), kicks, leaf beam, air attack, guard pose + block, roll, slide.
- **Brawler Girl:** jab/punch/kick combo, jump kick and dive kick.
- **Dancing Girl:** dances. Every non-boss enemy on screen rushes to her side and jumps up and down without attacking. Bosses ignore her.
- Every ally uses every animation in her pack (tested). Enemy attacks hurt allies, and allies can be beaten.
- New files: `scripts/game/allies.gd` (numbers, card spots), `ally.gd`, `ally_card.gd`, `ally_picker.gd`, `ally_arrow.gd`. Ally art goes into the same `assets/enemies/roster.json` manifest.

### Tests
- 261 pass. The ally checks:
  - cards per level, collecting, R1 single summon, the picker;
  - the heal and its cooldown;
  - each ally uses all her animations, hits enemies and can be beaten;
  - the dance gathers non-boss enemies but not the boss;
  - allies leave when their time is up.

## v0.6-playable (2026-10-31)
Stage S2 of `docs/WORKFLOW.md`. Pre-release with Windows and Linux builds.

### Enemy roster: 16 enemies on levels 2-4, using all their animations
- **Misty Woods:** wolf (2 skins), mutant toad, werewolf, flying eye demon, ogre (disarmed below half HP), minotaur.
- **Moonlit Town:** skeleton (rises; plain or clothed), hell gato, ghost, Death (rises; loses his lamp), nightmare.
- **Infernal Caverns:** hell hound, fire skull (doused by hits), hell beast (fireballs + fire pillar), demon (claw + breath), and the **Infernal Dragon boss**.
  - The dragon has 160 HP, a boss bar, a tail sweep and fire breath.
  - The exit stays locked until he falls.
- How it's built:
  - One data-driven enemy script (`scripts/game/monster.gd`) plus definitions (`scripts/game/roster.gd`).
  - A manifest of every frame and its opaque box (`assets/enemies/roster.json`, made by `tools/build_roster.py`). Hit boxes are cut from the frames that reach past the body.
- Enemies never scale, are stunned by the earthquake on the ground (flyers aren't), drop rage spheres and potions, and die in the ansimuz fire puff.
- Waves cycle through each level's list so every type appears. Level 1 keeps the knights.
- Full table: `docs/GAME_RULES.md`, "Enemy roster".

### Telegraph standard (research #7)
- Every enemy attack, knights included, starts with a tell of at least 0.35 s: a frozen wind-up, a colour pulse and a "!" overhead.
- The colours: orange = melee, white-gold = heavy, red = ranged / fire, purple = rush.
- See `docs/GAME_RULES.md`, "Telegraphs".

### Lightning inside the bubble is back
- **Y while the L2 bubble is up** (100 % rage) calls the lightning. Mera stays shielded.
- The v0.3 behaviour, on a free button. See `docs/CONTROLS.md`.

### Other
- `scripts/game/demo.gd` now uses the current controls.
- **Tests:** 248 pass, adding the roster checks:
  - each enemy uses every animation, hurts Mera, telegraphs at least 0.35 s with the marker, and never scales;
  - all 16 are placed once each, and the dragon is the boss;
  - the earthquake stuns ground enemies but not flyers;
  - each level's spawner meets its whole list, and the boss locks the exit;
  - lightning works inside the bubble.
- **Tests now run in ~10 s** with `--fixed-fps 60` (was ~15 min). See `docs/AI_HANDOFF.md`.

## v0.5-playable (2026-10-31)
Stage S1 of the plan in `docs/WORKFLOW.md`. Pre-release with Windows and Linux builds.

### Level select and 4 large native maps
- The game now opens on a level select (`scenes/menu.tscn`):
  1. **Moonlit Cemetery**
  2. **Misty Woods**
  3. **Moonlit Town**
  4. **Infernal Caverns**
- Each map is **19,200 px (10 screens)** wide, built natively by `tools/build_levels.py` from copies of the ansimuz packs:
  - one long unique playable strip, with graves, trees, statues, houses, lamps, rocks and pillars placed by a seeded RNG;
  - seamless or mirrored distant layers with their own parallax. No looping strip, no blurred seams.
- Invisible walls stop Mera and the enemies at both ends, and an **exit gate** waits at the right end.
  - **LEVEL CLEAR:** A goes to the next level, B to the level select.
  - **Game Over:** B goes to the level select.
- Level 1 plays as before (Fire Knight + Blue Knights). Levels 2-4 use the Fire Knight until the v0.6 enemy roster.
- Test/capture arg: `--level=N`.

### Button remap
- **L2 tap** (full meter) = lightning. **L2 hold** = barrier. Both start with the same heal pose, so neither waits.
- **L2 + R2** together (67 ms chord, either order, or R2 while in the bubble) = Fury. R2 alone = Fury-flight take off / land.
- **R1** is freed for allies (v0.7); for now it gives a fail cue and a HUD note.
- The v0.3 "lightning from inside the bubble" is gone, because L2 is busy holding the bubble.
- Details: `docs/CONTROLS.md`, "v0.5 button remap: the decision".

### Earthquake
- **Down + Y while crouching**, 20 stamina.
- A 1 s quake with a 34 px camera shake re-randomised every frame, across the whole map, plus ground dust.
- Every enemy touching the ground during it is **stunned until 5 s after the quake started**. Stunned knights wobble, can't act or block, and take damage normally.

### Docs
- New: `docs/WORKFLOW.md` (staged plan), `docs/AI_HANDOFF.md` (for other agents) and `docs/RESEARCH.md` (fan-review mechanics, physics/FX packs and destructibles research; it drives S4).

### Tests
- New tests cover:
  - the remap (L2 tap / hold, L2+R2 in both orders with sloppy timing, R2 alone, R1, Fury in the air);
  - for every level, all layers cover the screen across the whole map, the walls hold, and the exit clears;
  - the earthquake (cost, shake, ground-only stun, landing during the quake, the 5 s total, no quake without Down, no quake without stamina);
  - the menu.
- 222 tests pass.

## v0.4-playable (2026-10-31)
Pre-release with Windows and Linux builds. All tunables are in `scripts/game/tuning.gd`.

### Combos: responsive input
Root causes of the "clunky" feel in v0.3.x, and the fixes:
- **A lone X or Y waited 50 ms** for a possible chord partner before acting. Now every button commits on the frame it is read, and a chord partner that lands within 67 ms converts the move that already started, in its first frames (X+Y → rear explosion, A+Y → ground dash, B+Y → rising slash).
- **1x → 2x chained only on 1x frames 10-12**, and a later X restarted 1x, which reset the combo. Now any X from frame 9 to the end of 1x chains, and so does one pressed earlier during 1x, which stays buffered for the whole move.
- **2x froze for up to 180 ms (+60 ms)** to measure whether the 3rd X was held. Now 2x-2 starts at once and upgrades to 2x-1 within 4 frames if the hold reaches 170 ms.
- **The 450 ms buffer expired early mash presses** before the chain point. Presses are now kept for the whole move, and fast mashing (a 3rd X pressed while 1x is still playing) counts.
- **The X X X Y beam only accepted Y within 300 ms** and in the first frames of the 3rd hit. Now the Y can come any time during the 3rd hit or up to 250 ms after it.
- **No grace after recovery.** A combo hit that just returned to idle now accepts its follow-up for 220 ms.
- Input polling itself was not late; the delay was the rules above.
- The windows are documented in `docs/CONTROLS.md`.

### Dodge chain
- **B+Y chord** (within 67 ms, either order) = rising slash, in place. **Y again** = slam. Both free.
- **B, then Y** = fast quick fire (2x animation, bolt at 2x speed, 5 stamina).
- **B, then X** = dodge attack (no longer chains into the rising slash or slam).
- **Up** always jumps instantly. Y in the air is the aerial dash.

### Stamina
- A new STAMINA bar: 60 max, +1 per second.
- Costs: quick fire 5, ground/aerial dash 6, rear explosion 12, beam combo 20, bubble 3 + 4/s. Not enough stamina gives a fail cue and a bar flash.
- Blue potion +30 stamina. Blue-and-white potion +5 max stamina (cap 120).

### Fire Knight overhaul
- **20 HP**. Hits do **2** sizes, the special **3**.
- He uses **all 14 chierit animations**:
  - the 1/3/4-hit strings, plus the special every 3rd string with a white-gold tell;
  - the jump attack, take-off, rise and fall;
  - the roll, the block, the hit and the death.
- **Chase dash:** a roll at 3x speed when Mera is more than 760 px away, for at most 0.6 s, then a 3 s cooldown.
- **Block:**
  - he is invulnerable except to explosions and Fury attacks;
  - he holds it for at most 1.4 s, then is forced to drop it, with a 2.5 s cooldown.
- **Bolt AI:** he jumps quick-fire bolts first seen more than 400 px away and blocks closer ones.
- **Air chase:** jump attacks when Mera jumps or flies near him.

### Blue Knight (new)
- A runtime blue palette swap of the Fire Knight (chierit, CC-BY 4.0).
- 3x scale, 5 HP, 3x faster, 1 damage, no block and no special. He circles round and attacks from behind.
- One spawns when the Fire Knight first loses HP, and one more when the Fire Knight first drops below 10 HP.
- Drops: 35 % stamina potion and 10 % max-stamina potion (independent rolls), plus a +4 % rage sphere.

### Fury aura
- **Particles:** CPU particle flame tongues in world space, back layer + faint additive front layer + embers.
- They rise like a ground fire when she stands still and trail behind her when she moves. They scale with her size, with the same quality caps.

### Tests
- **Human-timing input replays:** seeded trials with presses 80-250 ms apart, holds 45-110 ms and sloppy chords 0-50 ms. They cover X X X (also mashed), X X hold-X, X X Y, X X X Y (also a late Y), X X Y Y, X+Y, A+Y, Y, B+Y, B+Y Y, B then Y, B then X, B X X X, Up, and Up then Y.
- Plus knight, Blue Knight, stamina, drop and aura tests.

### Known issues
- With the requested numbers, a Fire Knight hit (2) kills a 2x Mera outright, and the special (3) kills a 3x Mera. Drink potions early.
- The built-in `--demo` capture script is still the v0.3 one, so in v0.4 Mera dies in it.
- The knight's guard isn't up on the first frame of `09_defend`, so a bolt fired point-blank can still hit him.
- `shaders/fury_flame*.gdshader` are no longer used (the aura is particles now). They're kept for reference.
- The full headless test suite takes about 12 minutes because of the seeded human-timing replays.

## v0.3.1-playable (2026-10-31)
Pre-release with Windows and Linux builds. v0.3-playable stays as it was.

- **The camera stays centred on Mera and no longer swaps view when she turns around.**
  - It's hard-locked on her X every frame, with no facing look-ahead and no smoothing, so there's no lag or drift.
  - It runs after all physics (`scripts/game/cam_rig.gd`). Vertical is unchanged.
- The beam and lightning off-screen length logic is unchanged and re-verified against the locked camera (all reach tests pass).
- Tests: 128 pass. New ones check that:
  - the camera stays locked while walking;
  - turning in place at 1x, 2x and 6x never moves the camera X;
  - a pure turn leaves the camera X unchanged;
  - the camera follows a position jump on the same frame;
  - the camera stays locked during a ground dash at 1x and 6x.

## v0.3-playable (2026-10-31)
Branch `playable-level`, merged into `main`. Windows and Linux builds.

### Enemies
- **The Fire Knight is always 6x** (264 px tall), and every swing that connects costs Mera exactly 1 size. Enemies never scale with her size, in size or in damage.
- His AI is retuned for the 6x reach:
  - 0.4 s orange tell (he holds his first frame);
  - committed swings (frame 3 on) don't flinch;
  - approach at 192 px/s, swing range 336 px, bigger health bar.

### Spells
- **The beam (X X X Y) and the R1 lightning always reach off-screen**, at any size, from any position and facing.
  - Both are built from tessellating segments (`tools/tess_spells.py`, `scripts/game/seg_strip.gd`, `strike.gd`) drawn from a shared sprite pool.
  - Their hitboxes cover the full length.
- **Beam input is X X X Y.** The Y may come up to 0.3 s after the third X. X X Y is always 1x → 2x → 3x, and X X Y Y is never the beam.
- **R1 lightning costs 100 % rage.** The meter drains visibly to 0. Below 100 % you get a fail cue and a HUD hint. It's unavailable during Fury.
- **R1 works while L2 is held.** Mera stays in the bubble pose, keeps blocking, and the strike fires (full meter required, all of it spent).
- **The L2 bubble encloses the whole pose.** It is fitted by `tools/fit_barrier.py` around every opaque pixel of the held barrier frames, raised hand and energy ball included, plus a margin. It scales with size and mirrors with facing.
  - While it is up, the bubble is her hurtbox, so the blocking area matches the visual.

### Fury
- **Fury flight rotation:** she tilts head-first toward her 8-way flight direction, flips for left/right, and eases back upright in the hover. The hurtbox follows the tilt.
- **Kaioken-style Fury aura:**
  - a layered procedural flame shell behind her and additive tongues over her (`shaders/fury_flame*.gdshader`);
  - embers;
  - a dark-red → orange ramp.
  - It scales with size and has an `--aura-quality=0..2` cap.

### Camera
- **The camera always follows Mera** horizontally, smoothly, with a small look-ahead and velocity feed-forward. The dead zone is gone.

### Movement
- **Walk is 50 px/s at 1x.**
- **The ground and aerial dashes cover 2x the distance in half the time** (1600 px/s; animation at 2x).
- **The back dodge covers the same distance in half the time** (800 px/s; animation and i-frame window compressed 2x).
- The dashes and the dodge leave a pooled afterimage trail.

### Fixes
- **2x atk without a follow-up** no longer makes Mera vanish for 6 frames and then teleport 343 px × size. The pack's blank "short delay" tail now holds her last pose, and the idle hand-off is -19 px.

### Tests, docs and capture
- Headless tests went from 82 to 122. They cover:
  - the knight's size and damage invariance, and beam/lightning reach;
  - the R1 cost, R1 in Fury and R1 in the bubble, and bubble enclosure at 1x–9x in both facings;
  - combo disambiguation, flight tilt, aura, camera follow, and dash/dodge/walk speeds.
- Docs: `CHANGELOG.md`, README, `docs/CONTROLS.md`, `GAME_RULES.md`, `COMBOS.md` and `CREDITS.md` are updated.
- Gameplay capture and screenshots are in `previews/playable/v0.3/`.

## v0.2-playable (2026-10-30)
The first playable test level (`scenes/game.tscn`), with Windows and Linux builds.

### Level and player
- An endless looping cemetery (parallax, blurred seams), with Fire Knights one at a time.
- All of Mera's pack animations, plus the canon casts, baked by `tools/export_game_anims.py` into layered atlases:
  - quick fire (pick3 v4);
  - rear explosion (pick2 v4);
  - beam combo (pick1).
- Moves:
  - walk, run, jump, double jump, crouch and slide;
  - 1x/2x/3x combos with the input buffer;
  - jump attacks, aerial and ground dashes, back dodge and dodge attacks;
  - L1 potion, L2 barrier, R1 lightning, R2 Fury with flight.

### Rules
- **Size = HP.** She starts at 2x, a hit costs sizes, and a hit at 1x is death. Damage dealt = base × size.
- Potions add +1 size, up to 6x. Red spheres fill the rage meter.

### Controls, enemy and presentation
- Xbox/PS4 controller and keyboard mapping (`docs/CONTROLS.md`).
- The Fire Knight (10 HP) drops a sphere and sometimes a potion, and respawns.
- HUD, Kenney CC0 sfx with a Fury audio bus, and Fury recolour shaders.
- Headless test suite (82 tests), demo capture mode.

## v0.1-scale-test (2026-10-30)
- Mera scale test: `scenes/stage.tscn` on a 1920×1080 ansimuz Cemetery at 5x.
- Mera runs and size-shifts 1x–19x, pivoting at her feet, next to the 6x Fire Knight reference.
- Hurtbox debug, Windows/Linux/Web export presets.
- Asset survey and licensing docs, plus the beam/projectile cast previews that became the canon moves.
