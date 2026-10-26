# Balance: XP rates

XP per hour of game time for each training method, measured by running the
real simulation for 6000 ticks (an hour at 0.6 s a tick) with a diligent bot
that re-issues the action at once, keeps the pack supplied and emptied, and
never walks anywhere. Regenerate with:

```bash
godot --headless --path game --script res://tools/balance/xp_report.gd
```

| Skill | Method | Level | XP / hour |
|---|---|---|---|
| Mining | copper rock | 1 | 7,545 |
| Mining | copper rock | 30 | 9,180 |
| Mining | iron rock | 15 | 8,730 |
| Mining | iron rock | 40 | 12,180 |
| Mining | iron rock | 70 | 13,650 |
| Woodcutting | tree | 1 | 3,388 |
| Woodcutting | tree | 30 | 3,652 |
| Woodcutting | oak | 15 | 18,200 |
| Woodcutting | oak | 40 | 24,325 |
| Woodcutting | oak | 70 | 29,015 |
| Woodcutting | pine | 30 | 17,516 |
| Woodcutting | pine | 60 | 34,916 |
| Woodcutting | pine | 90 | 41,354 |
| Fishing | net spot | 1 | 17,496 |
| Fishing | net spot | 20 | 24,908 |
| Fishing | net spot | 40 | 29,152 |
| Fishing | rod spot (mackerel) | 20 | 25,380 |
| Fishing | rod spot (mackerel) | 40 | 34,785 |
| Fishing | rod spot (mackerel) | 70 | 51,030 |
| Fishing | harpoon spot (tuna) | 40 | 34,160 |
| Fishing | harpoon spot (tuna) | 60 | 59,120 |
| Fishing | harpoon spot (tuna) | 90 | 91,280 |
| Cooking | sardines (range) | 1 | 53,160 |
| Cooking | sardines (range) | 34 | 57,040 |
| Cooking | tuna (range) | 35 | 89,000 |
| Cooking | tuna (range) | 65 | 142,600 |
| Smithing | bronze pugio | 1 | 17,112 |
| Smithing | bronze pugio | 10 | 17,112 |
| Smithing | iron gladius | 19 | 67,900 |
| Smithing | iron gladius | 40 | 67,900 |
| Fletching | arrow shafts | 1 | 8,556 |
| Fletching | arrow shafts | 15 | 8,556 |
| Fletching | bronze arrows | 1 | 28,240 |
| Fletching | bronze arrows | 15 | 28,240 |
| Crafting | leather caps | 1 | 19,012 |
| Crafting | leather caps | 15 | 19,012 |
| Crafting | wolfskin jerkins | 22 | 101,530 |
| Crafting | wolfskin jerkins | 40 | 101,530 |
| Medicina | mint tonics | 1 | 27,160 |
| Medicina | mint tonics | 20 | 27,160 |
| Thieving | baker's stall | 1 | 10,448 |
| Thieving | baker's stall | 20 | 10,576 |
| Thieving | silversmith's stall | 25 | 16,912 |
| Thieving | silversmith's stall | 50 | 17,416 |
| Thieving | townsman | 1 | 16,497 |
| Thieving | townsman | 20 | 20,367 |
| Thieving | merchant | 18 | 38,388 |
| Thieving | merchant | 40 | 59,388 |
| Athletics | training course laps | 1 | 18,096 |
| Athletics | training course laps | 40 | 20,536 |
| Hunter | hare burrow (one trap) | 1 | 17,472 |
| Hunter | hare burrow (one trap) | 30 | 20,992 |
| Hunter | fox den (one trap) | 15 | 26,856 |
| Hunter | fox den (one trap) | 45 | 43,272 |
| Attack (accurate) | training dummy, bronze gladius | 1 | 4,772 |
| Attack (accurate) | training dummy, iron gladius | 30 | 18,308 |
| Attack (accurate) | training dummy, spatha | 60 | 32,080 |

## Reading the numbers

- **One resource only.** Each run uses a single rock, tree, spot, stall, or trap. Real players hop between several, so methods limited by respawns (common trees fall after one log; the stalls restock slowly; one box trap) run faster in play, roughly in proportion to how many nodes are nearby. Common trees in particular look slow here (one tree, 30-tick regrowth); the grove has four.
- **No walking, banking, or buying.** Artisan rates (cooking, smithing, fletching, crafting, medicina) assume inputs on hand; real rates are lower once banking and sourcing count, and the inputs are the real cost (pelts for wolfskin, harpy feathers for harpy arrows).
- **Combat** is on the training dummy (it never fights back or dies); real monsters are slower because they fight back and respawn.

## Tuning made from this report (#130)

- **Pine difficulty 0.4 to 0.3.** At Woodcutting 30, pine gave 6,300 XP/h, a third of oak at 15 (18,200); now 17,500.
- **Silversmith's stall restocks in 18 ticks, not 35.** At Thieving 25 it gave 9,100 XP/h, less than the baker's stall at level 1 (10,400); now 16,900.

## Open questions for the balance pass

- Cooking tuna (89,000 to 143,000 XP/h) and crafting wolfskin jerkins (102,000) are far above their gathering skills; that's OSRS-like for artisan skills, but fish and pelt supply should be the brake.
- Early melee on the dummy (4,800 XP/h at level 1 with a bronze gladius) is slow next to the first skilling methods (8,000 to 17,000).
- Smithing and fletching rates don't rise with level within a recipe (no failure chance), so the reason to level is new recipes only.
