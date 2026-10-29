# legio

An RPG inspired by Old School RuneScape, set in a low-fantasy Roman world. Single-player for now, with controller support.

See [docs/design.md](docs/design.md) for the design and [docs/roadmap.md](docs/roadmap.md) for what comes next.

## Playing

On Windows, download `Legio.exe` from the latest [release](../../releases) and run it. It is a single file with the game inside; saves and settings go to `%APPDATA%\Godot\app_userdata\Legio`.

To build the exe yourself, run `scripts/export-windows.sh` (it writes `build/windows/Legio.exe`). To run from source instead, with Godot 4.7 on your PATH:

```bash
godot --path game
```

You start as a peregrinus in Castra Ferrea, a fort town on the frontier. A yellow **!** over an NPC means they have a quest for you; Optio Gaius by the forum is the place to begin.

### Controls

| Action | Keyboard and mouse | Controller |
|---|---|---|
| Move | W A S D, or left-click the ground | Left stick |
| Turn and tilt the camera | Arrow keys | Right stick |
| Zoom | Mouse wheel | D-pad up / down |
| Interact with the nearest thing (talk, fight, mine, chop, fish, steal, ...) | E | A |
| Options for what's under the cursor or nearby | Right-click | Y |
| Next / previous target | Tab / Q | Right / left shoulder |
| Combat style | C | X |
| Special attack (spends Impetus on your next attack) | F | B |
| Run on / off | R | Left stick click |
| Inventory and equipment | I | Back |
| Quest log | J | D-pad right |
| Tabularium (collection log) | L | Right trigger |
| Skills | K | Left trigger |
| Blessings (Pietas) | P | D-pad left |
| Hide roofs | H | Right stick click |
| World map | M | Share |
| Pause menu (graphics, volume, controls, quit) | Esc | Start |
| Choose / back out in menus | Enter / Esc | A / B |
| Leave a note for the developers (saved to `feedback.md` in the save folder) | F8 | Pause menu, then Leave a note |

### What's in the game

- **Five regions, two dungeons and two estates**: Castra Ferrea, the frontier fort town; Portus Salis, a harbour on the coast; Beyond the Limes, the danger zone past the palisade; Vipasca, the silver mines of Hispania, with the deep gallery under them; and Seriphos, a Greek island across the sea. The barrow of the lemures lies under the woods, the circus is a road east of the fort, and citizens can own a villa. M shows the world map, with ! wherever a quest is waiting.
- **Combat** in three styles (melee; ranged with bows, slings and javelins; and Ritus curse tablets, with foci and robes in tiers), with weapon special attacks (F / B), Pietas blessings, and five bosses: Hrodgar the War-chief, Regulus the basilisk king, Euryale the gorgon queen and the Hydra on Seriphos, plus the barrow's own. Monster levels are coloured green to red by how dangerous they are to you.
- **Slayer** from two venatores, Aulus in the fort and Ursa beyond the Limes, with gear checks (whitethorn against the strix, earplugs against sirens, a mirror shield against basilisks and gorgons), points to spend, and a venator's helm. **Arena contracts** from Lanista Marcia: net beasts alive for the games. **The munera**: ten waves of beasts and raiders on the circus sands, and the rudis for surviving them all.
- **Quests**: starter quests for the baker, the smith and the sacerdos, the auxilia career from tiro to citizen, the legion after it (*Sacramentum* and *Optio*), and quests at the harbour, the limes, the mines (including *The Mountain-Copper*) and on Seriphos. The quest log says what a locked quest still needs. **Region tasks** give each region a list worth working through.
- **22 skills**: Attack, Strength, Defence, Vitality, Ranged, Ritus, Pietas, Slayer, Mining, Smithing (bronze, iron, Noric steel and orichalcum), Cooking (bread from the fort's wheat, garum, and oil and wine from your presses), Woodcutting (up to yew), Fishing (eels and tuna among them), Fletching (up to the yew longbow), Crafting (leather, pottery, glass, jewellery and marble mosaics), Thieving (stalls, pockets and strongboxes), Athletics (a training course, the Portus beach run, wall shortcuts and **chariot racing** in the circus), Hunter (hares, foxes and dormice for honeyed dormouse), Farming (herbs, vegetables, grain, vines and an olive orchard), Medicina, Mercatura (trade contracts and regional prices) and Engineering (your villa, its presses, and a steward who works while you're away).
- **Shops buy and sell**, a shared bank with search and sort, return tablets to carry you home, an XP tracker in the skills panel, gear stats on examine, a collection log (the Tabularium), pets, Solitarius (ironman) and Hardcore Solitarius (one life) modes, first-time hints (including help when you're hurt or out of your depth), fullscreen (F11), music composed as you play (a lyre or aulos in each region's own mode, with drums for fights and the circus), and saves with a backup. The pause menu lists every control.

## Development

See [CLAUDE.md](CLAUDE.md) for the commands: Godot unit tests, scripted playtests, and content validation.
