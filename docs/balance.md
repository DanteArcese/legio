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
| Mining | copper rock | 1 | 7,725 |
| Mining | copper rock | 30 | 9,060 |
| Mining | iron rock | 15 | 8,940 |
| Mining | iron rock | 40 | 11,910 |
| Mining | iron rock | 70 | 13,620 |
| Mining | clay | 1 | 4,232 |
| Mining | clay | 20 | 4,816 |
| Mining | silver rock | 30 | 6,360 |
| Mining | silver rock | 50 | 7,560 |
| Mining | silver rock | 70 | 8,160 |
| Mining | coal rock | 30 | 6,930 |
| Mining | coal rock | 50 | 8,050 |
| Mining | coal rock | 70 | 8,610 |
| Mining | gold rock | 40 | 5,395 |
| Mining | gold rock | 60 | 6,825 |
| Mining | gold rock | 80 | 7,150 |
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
| Fishing | eel pool | 30 | 28,500 |
| Fishing | eel pool | 50 | 45,420 |
| Fishing | eel pool | 80 | 68,460 |
| Cooking | sardines (range) | 1 | 53,040 |
| Cooking | sardines (range) | 34 | 56,920 |
| Cooking | tuna (range) | 35 | 88,800 |
| Cooking | tuna (range) | 65 | 142,300 |
| Smithing | bronze pugio | 1 | 17,076 |
| Smithing | bronze pugio | 10 | 17,076 |
| Smithing | iron gladius | 19 | 67,350 |
| Smithing | iron gladius | 40 | 67,350 |
| Smithing | steel gladius | 34 | 102,372 |
| Smithing | steel gladius | 60 | 102,372 |
| Engineering | oak planks (sawpit) | 20 | 25,614 |
| Engineering | oak planks (sawpit) | 40 | 25,614 |
| Fletching | arrow shafts | 1 | 8,538 |
| Fletching | arrow shafts | 15 | 8,538 |
| Fletching | bronze arrows | 1 | 28,240 |
| Fletching | bronze arrows | 15 | 28,240 |
| Crafting | leather caps | 1 | 19,012 |
| Crafting | leather caps | 15 | 19,012 |
| Crafting | wolfskin jerkins | 22 | 101,530 |
| Crafting | wolfskin jerkins | 40 | 101,530 |
| Crafting | throwing pots | 1 | 8,538 |
| Crafting | throwing pots | 10 | 8,538 |
| Crafting | firing amphorae | 12 | 28,460 |
| Crafting | firing amphorae | 30 | 28,460 |
| Crafting | glass bowls | 32 | 77,660 |
| Crafting | glass bowls | 50 | 77,660 |
| Medicina | mint tonics | 1 | 26,940 |
| Medicina | mint tonics | 20 | 26,940 |
| Engineering | planks (sawpit) | 1 | 11,384 |
| Engineering | planks (sawpit) | 20 | 11,384 |
| Thieving | baker's stall | 1 | 10,400 |
| Thieving | baker's stall | 20 | 10,544 |
| Thieving | silversmith's stall | 25 | 16,912 |
| Thieving | silversmith's stall | 50 | 17,472 |
| Thieving | townsman | 1 | 16,452 |
| Thieving | townsman | 20 | 20,457 |
| Thieving | merchant | 18 | 41,748 |
| Thieving | merchant | 40 | 58,548 |
| Athletics | training course laps | 1 | 18,096 |
| Athletics | training course laps | 40 | 20,536 |
| Hunter | hare burrow (one trap) | 1 | 16,448 |
| Hunter | hare burrow (one trap) | 30 | 21,248 |
| Hunter | fox den (one trap) | 15 | 27,792 |
| Hunter | fox den (one trap) | 45 | 42,552 |
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

## Vipasca and Noric steel (#154)

- Silver (Mining 30), coal (30) and gold (40) give less XP an hour than iron at the same level (6,000 to 8,600 against 12,000 to 13,600) because they respawn slowly (25, 20 and 50 ticks) and sell for more. Iron stays the fast training rock, as in OSRS; the pit has four silver, three coal and two iron rocks, so real rates are higher.
- The steel pickaxe and axe (tier 3) are as fast as iron but land 10% more often.
- Steel gladii (Smithing 34) give about 103,000 XP an hour from bars on hand, up from 68,000 for iron. Each bar takes an iron ore and two coal, so coal is the brake.

## Pottery and glass (#185)

- Throwing pots gives about 8,500 Crafting XP an hour at level 1, under leather caps (19,000), but the clay is free: dig it by the pond (about 4,200 Mining XP an hour) and fire the pots for more XP and a little money. Amphorae at 12 give 28,000 and glass bowls at 32 give 78,000, with sand bought from Nikias or the fishmonger as the brake.

## Open questions for the balance pass

- Cooking tuna (89,000 to 143,000 XP/h) and crafting wolfskin jerkins (102,000) are far above their gathering skills; that's OSRS-like for artisan skills, but fish and pelt supply should be the brake.
- Early melee on the dummy (4,800 XP/h at level 1 with a bronze gladius) is slow next to the first skilling methods (8,000 to 17,000).
- Smithing and fletching rates don't rise with level within a recipe (no failure chance), so the reason to level is new recipes only.
