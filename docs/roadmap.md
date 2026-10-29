# Legio: roadmap

The plan for the next few weeks, written on 2026-10-28. It covers what to build and in what order. [design.md](design.md) still holds the design itself; this file only orders the work. Each milestone is a GitHub milestone of the same name, and its issues are filed when it's next up (M1 and M2 have theirs now).

## Where things stand

The game has five regions, two dungeons, the circus and the villa, 22 skills, five bosses, Slayer from two venatores, the auxilia career and the first two legion ranks. All of it is tested by about 430 unit tests and 84 scripted playtests.

Three gaps matter most:

1. **The skills stop around level 60.** Skills are meant to go to 99 (design.md, *Grind*), but every skill's content ends between 30 and 60: Athletics, Mercatura and Pietas at 30, Farming at 36, Fishing and Hunter at 40, Crafting and Engineering at 45, the rest at 50 to 60. Only Slayer (75) and the bosses go higher. The long grind is the first pillar, and past 60 there's nothing left to unlock.
2. **Citizenship has no capital to unlock.** The auxilia career ends in citizenship, which design.md says opens Rome, the forum market and higher-level venatores. Only the villa exists so far, so the career's reward is half there.
3. **Boss fights lack the decisions the design asks for.** Bosses are meant to be fought with protection blessings switched in response to what the boss does, and with gear swaps on the D-pad. Neither is built, so a boss fight comes down to stats, eating and stepping out of rings.

There's also no music, and no way yet for you to report what you notice while playing.

## Order

| Milestone | Size | Why it comes here |
|---|---|---|
| **M1 Feel and feedback** | about 1 session | It's cheap, and everything after it is easier once you can report problems from inside the game. |
| **M2 Combat depth** | about 1 session | The bosses already exist; protection blessings and loadouts make them fights rather than stat checks, and later bosses are designed around both. |
| **M3 Rome** | about 2 sessions | It finishes the career's reward, and most of the 60-to-99 content belongs in the capital, so it has to come first. |
| **M4 Levels 60-99** | about 2 sessions | The biggest gap, spread across Rome and the existing regions. |
| **M5 Travel and trade** | about 1 session | Once there are seven places to go, walking gets old, and Mercatura's carts and ships are still unbuilt. |
| **M6 Aegyptus and the Labyrinth** | about 2 sessions | Endgame: a new region, the Minotaur, and long-term goals. |

A session is one of the long autonomous runs (8 to 12 hours, usually 12 to 20 merged PRs), so the whole plan is about 9 sessions. Each milestone ends with a fresh exe and a short summary. If what you see while playing points somewhere else, the order changes.

## M1 Feel and feedback

- **In-game feedback note** (#287): F8 writes a note to a file in the save folder, along with where you were and what you were doing. The next session reads it and turns notes into issues. This only works if you play between sessions, even briefly.
- **Music** (#288): a CC0 ambient track for each region, credited, with a slider.
- **First-hour pass** (#289): a playtest that plays a fresh character's first hour and reports friction, followed by fixes.
- **Controller audit** (#290): everything playable with only a controller.
- **Performance pass on the exe** (#291): frame time per region, and fixes.
- **Monster separation** (#205): finish a cheap version or close it.

Done when: you can play an evening on a controller, with music, and leave notes.

## M2 Combat depth

- **Protection blessings** (#293) against melee, ranged and Ritus.
- **Bosses switch styles** (#294) with visible tells, so the protections matter. Retune all five fights.
- **Gear loadouts** (#295): four saved sets, swapped from the D-pad.
- **Pietas to 70** (#296).
- **Lamiae and centaurs** (#297) to fill the 40 to 60 Slayer gap.
- **More Slayer point rewards** (#298): longer contracts and more block slots.

Done when: every boss rewards switching blessings and gear, and a level-50 character has Slayer tasks that aren't the same four monsters.

## M3 Rome

The capital is for citizens. You reach it by ship from Portus Salis to Ostia and then the road up the Tiber.

- **The forum and Ostia**: the region itself, with a bank, shops and the venatores' guild (higher-level contracts).
- **The forum market**: an exchange for buying and selling with prices that move. In single-player it's backed by NPC traders. Solitarius characters can't use it, which finally gives that mode its main restriction.
- **The Subura**: Thieving from 55 to 85 (senators' houses, gambling dens, an underworld guild).
- **High-end artisans**: a goldsmith, a glassworks and a fresco painter, which give Crafting content past 60.
- **Centurion**: the last legion rank, ending the career that design.md planned.
- **The Circus Maximus**: four-horse chariot races (Athletics 50+).

## M4 Levels 60-99

One sweep through every skill, so each has unlocks every few levels up to 99, with at least one fast method and one slow one. First ideas:

| Skill | Ends at now | Ideas past it |
|---|---|---|
| Mining and Smithing | 55 / 58 | Meteoric iron from a fallen star (70 to 90), the top metal tier |
| Woodcutting and Fletching | 60 | Cedar (70) and olive wood (80); the manuballista and its bolts |
| Fishing and Cooking | 40 / 50 | Moray eels for Roman fishponds (60), sturgeon (75); feast dishes |
| Hunter | 40 (arena 60) | Leopards and lions for the arena (70 to 90) |
| Farming | 36 | Fig and cedar trees, vineyard tiers |
| Crafting | 45 | Cameo glass (85), frescoes, gold work in Rome |
| Medicina | 34 | Theriac, Galen's famous cure-all (80) |
| Athletics | 30 | Rooftop runs in Rome (50, 70), the Circus Maximus |
| Thieving | 55 | The Subura (from M3) |
| Engineering | 45 | Villa rooms past 60, and world projects (M5) |
| Mercatura | 30 | Carts, wagons and ships (M5) |
| Ritus | 50 | Tablets for 65 and 80; an underworld focus |
| Pietas | 30 (70 after M2) | The last blessings, and consecrating jewellery at temples |

## M5 Travel and trade

- **Cursus publicus**: waystations you unlock by visiting, as fast travel between them.
- **Horses** for the roads.
- **Mercatura vehicles**: carts, then wagons, then ships, each carrying more, with bandits on the road and pirates at sea.
- **Engineering world projects**: repairing a road or an aqueduct changes the world for good, with shorter routes and a working fountain.

## M6 Aegyptus and the Labyrinth

- **Aegyptus**, the river delta: a grain port, desert dungeons, crocodiles, and from Pliny the catoblepas (whose gaze kills, so it's a gear check) and the manticore.
- **The Labyrinth on Crete and the Minotaur**: the late boss design.md names, with Ariadne's thread as the gear check that lets you find the way out.
- **Long-term goals**: skilling outfits, a villa trophy hall for boss heads, and villa fishponds.

## Every milestone

- New content keeps its tests and a playtest, as it does now.
- Saves keep loading. Each milestone checks your current save on the new build before the exe is replaced.
- CI stays under its time budget; playtest shards are rebalanced when they drift.

## Not in these weeks

- **The MMO.** The simulation stays separate from rendering, as it is now, so it can move to a server later. A server prototype is worth doing only once the single-player game is deep enough that people would play it together.
- **New art direction.** Free low-poly assets stay the plan.

## Open decisions

Each has a recommendation. The plan follows it unless you say otherwise.

- **The market in single-player.** Recommended: NPC traders with prices that drift and react to what you sell. The alternative is to leave the market out until the MMO.
- **Rome before the high levels.** Recommended, because much of the 60-to-99 content lives in Rome. If you'd rather deepen the existing regions first, M4 can go ahead of M3.
- **How to get there.** Recommended: a ship from Portus Salis to Ostia, like the Seriphos ferry. The alternative is a long road north-east of the fort.
