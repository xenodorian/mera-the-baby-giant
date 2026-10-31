# Mera: The Baby Giant: test-level game rules

## Size is health
- Mera starts at **2x**. Her size is her HP (HUD: six size pips).
- Each hit costs as many sizes as its damage: a normal hit = 1 size, big attacks = more.
  The size change animates one step at a time.
- A hit that would take her below 1x (any hit while she is at 1x) kills her. **Game Over**: Start / Enter restarts.
- After a hit she gets **1.2 s of invulnerability** (she blinks).
- The L2 barrier blocks every hit while it is held.
- Movement speed and hit/hurt boxes scale with size.

## Damage
Damage dealt = base damage × Mera's current size (1x does 1×, 3x does 3×).

| Move | Base |
|---|---|
| 1x, 2x | 1 |
| 2x-1, 2x-2, 3x | 2 |
| Beam (beam combo) | 1 per tick (every 5 frames while the beam is on) |
| Dodge attack 1 / 2 / 3 | 1 / 1 / 2 |
| Jump attack 1 / 2 | 1 / 2 |
| Slide | 1 |
| Quick-fire bolt | 1 |
| Rear explosion (slash 1, explosion AOE 3) | 1 + 3 |
| R1 lightning (AOE) | 3 |

## Potions
- Green potions lie on the ground. Walk over one to carry it (HUD: POTIONS count). She starts with 1.
- L1 drinks one: +1 size, up to **6x**. With no potions, or already at 6x, L1 plays a fail cue and nothing is used.
- Where potions come from:
  - a defeated Fire Knight drops one 35 % of the time;
  - one appears on the ground ahead for every 2600 px of new ground explored;
  - at most 2 potions lie in the world at once.
- Free size changes (1x–19x) exist only in debug mode (F2).

## Rage and Fury
- A defeated enemy drops a **red sphere**. It flies to Mera and adds rage based on the enemy's difficulty.
  The Fire Knight's sphere gives **+10 %**.
- Each hit Mera lands also adds **+1 %**. Spheres are the main source; the small per-hit bonus keeps "dealing damage builds Fury".
- At 100 %, R2 starts **Fury** for 12 s and the meter drains to 0 over that time.
  - Red aura; all spell fx, beams, explosions and lightning turn deep red.
  - Sfx are pitched down (×0.72) through a low-pass + overdrive bus.
  - Flight: Up in the air takes off; R2 or Down at ground level lands.

## Fire Knight (only enemy in this demo)
- Drawn at 3x: a bit taller than a 2x Mera (132 px vs 110 px); she outgrows him from 3x.
  The scale test drew him at 6x purely as a size reference.
- **10 HP**, shown on a health bar over his head. He never changes size.
- He walks up to Mera, swings his sword (frames 4–6 of his attack), and each swing that connects deals **1 damage**. Touching him does no damage.
- Cooldowns: 1.4 s between swings, 0.9 s after he is hit (he flinches).
- On death he fades out, drops a red sphere (+10 % rage), and sometimes a potion.

## Spawning
- **Only one Fire Knight at a time.** A new one appears just off-screen ahead of Mera:
  - 2 s after the previous one is defeated, or
  - when Mera has moved too far away (he is off-screen and more than 2400 px behind). He is then removed and replaced ahead of her.
- The level loops forever: the cemetery background tiles every 1920 px, with blurred seams.
- The camera follows once Mera is within 480 px of either screen edge.
