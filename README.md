# legio

An RPG inspired by Old School RuneScape, set in a low-fantasy Roman world. Single-player for now, with controller support.

See [docs/design.md](docs/design.md) for the design.

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

### What's in the game

- **Five regions and two dungeons**: Castra Ferrea, the frontier fort town; Portus Salis, a harbour on the coast; Beyond the Limes, the danger zone past the palisade; Vipasca, the silver mines of Hispania, with the deep gallery under them; and Seriphos, a Greek island across the sea. The barrow of the lemures lies under the woods. M shows the world map.
- **Combat** in three styles (melee, ranged with bows and slings, and Ritus curse tablets), with weapon special attacks (F / B), Pietas blessings, and four bosses: Hrodgar the War-chief, Regulus the basilisk king, and the Hydra on Seriphos, plus the barrow's own.
- **Slayer** from two venatores, Aulus in the fort and Ursa beyond the Limes, with gear checks (whitethorn against the strix, earplugs against sirens, a mirror shield against basilisks and gorgons), points to spend, and a venator's helm. **Arena contracts** from Lanista Marcia: net beasts alive for the games.
- **Quests**: the auxilia career from tiro to citizen, and quests at the harbour, the limes, the mines and on Seriphos. **Region tasks** in the quest log give each region a list worth working through.
- **22 skills**: Attack, Strength, Defence, Vitality, Ranged, Ritus, Pietas, Slayer, Mining, Smithing (bronze, iron and Noric steel), Cooking, Woodcutting, Fishing, Fletching, Crafting (leather, pottery, glass and jewellery), Thieving, Athletics, Hunter, Farming, Medicina, Mercatura (trade contracts) and Engineering (your villa).
- **Shops buy and sell**, a shared bank, a collection log (the Tabularium), pets, a Solitarius (ironman) mode, first-time hints, and saving. The pause menu lists every control.

## Development

See [CLAUDE.md](CLAUDE.md) for the commands: Godot unit tests, scripted playtests, and content validation.
