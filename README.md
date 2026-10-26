# legio

An RPG inspired by Old School RuneScape, set in a low-fantasy Roman world. Single-player for now, with controller support.

See [docs/design.md](docs/design.md) for the design.

## Playing

You need Godot 4.7 on your PATH. Then:

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
| Run on / off | R | Left stick click |
| Inventory and equipment | I | Back |
| Quest log | J | D-pad right |
| Tabularium (collection log) | L | Right trigger |
| Skills | K | Left trigger |
| Blessings (Pietas) | P | D-pad left |
| Hide roofs | H | Right stick click |
| World map | M | Share |
| Pause menu (graphics, volume, quit) | Esc | Start |

### What's in the game

- **Combat** in three styles: melee, ranged (bows and slings), and Ritus (curse tablets with a lituus), with Slayer contracts from Aulus the venator and a barrow dungeon of lemures, strix, and a boss.
- **The auxilia career**: four ranked quests from Optio Gaius, from tiro to decurio and Roman citizenship.
- **Skills**: Attack, Strength, Defence, Vitality, Ranged, Ritus, Pietas, Slayer, Mining, Smithing, Cooking, Woodcutting, Fishing, Fletching, Crafting, Thieving, Athletics, and Hunter.
- **The town**: a bank, shops, a smithy, an altar and sacred spring, market stalls (mind the vigiles), a garum vat, and a training course.
- A minimap, a quest log, a skills panel, a collection log, sound, a day and night cycle, and saving.

## Development

See [CLAUDE.md](CLAUDE.md) for the commands: Godot unit tests, scripted playtests, and content validation.
