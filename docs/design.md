# Legio: design brainstorm

Status: early brainstorm. Nothing here is decided unless it says so. Items marked **Open** need a decision.

## Pitch

A slow-burn, skill-driven RPG in a low-fantasy Roman world. You start as a *peregrinus* (a free non-citizen) in a frontier province and work your way up through skills, Slayer contracts, and quests until you are a citizen with a villa of your own. The world takes its monsters from Greco-Roman myth and Pliny's *Natural History*, so the fantasy comes from the bestiary, not from spellcasting.

It is single-player first. The architecture should still leave room for an MMO later (see [Architecture](#architecture)).

### Pillars

1. **The grind feels good.** Long-term skill goals, satisfying XP drops, meaningful unlocks every few levels.
2. **Slayer at the center.** Combat progression runs through contracts against mythological beasts, each with its own mechanic.
3. **Rome, lived in.** Skills come from real Roman trades: garum fishing, marble quarrying, road building, wine making.
4. **Play with a controller from the couch.** Every action works on a gamepad. Mouse and keyboard are supported too.

## Setting

A fictionalized Roman world, around the early Empire, with history used loosely. A fictional province (working name **Provincia Ulterior**) gives us freedom to invent towns and factions, while real places can appear as distant destinations.

| Region (idea) | Inspired by | Role |
|---|---|---|
| Frontier province (starting area) | Britannia, Germania | Tutorial, early skills, low-level Slayer |
| The capital | Rome | Banks, Grand Exchange-style forum market, arena, high-end artisans |
| Mining country | Hispania (Rio Tinto) | Mining, smithing |
| River delta | Aegyptus | Desert dungeons, farming, trade |
| Greek isles | Achaea | Mythic monsters, temples |
| **Beyond the Limes** | Lands past the frontier wall | The high-risk zone with the best rewards (the Wilderness equivalent) |

## Skills

A first pass at Roman-themed skills. Names are working names.

### Combat

| Skill | Notes |
|---|---|
| Attack, Strength, Defence | Kept as-is. Gladius, spatha, pilum, scutum. |
| Vitality | Hitpoints. |
| Ranged | Bows, slings (*funditores*), throwing javelins, later the hand-held *manuballista*. |
| Pietas | Replaces Prayer. You make offerings at shrines and get buffs from patron gods: Mars (strength), Minerva (defence), Diana (ranged), Mercury (movement and run energy). XP comes from offerings: incense, wine, votive objects, and hides and bones left at altars. |
| Third style | **Open.** See [Replacing magic](#replacing-magic). |

### Slayer

Kept as a core skill and the center of progression.

- **Contracts** come from *venatores*, beast-hunters attached to provincial governors. Higher-level venatores live in more dangerous places.
- **The bestiary** draws on public-domain myth: harpies, lamiae, strix, centaurs, cyclopes, satyrs, lemures (restless dead), basilisks, the catoblepas, manticores, gorgons, hydras, and the Minotaur as a late boss.
- **Gear checks** tie each monster to a myth. You need a polished bronze mirror-shield against gorgons and basilisks, wax earplugs against sirens, fire to stop hydra heads growing back, and a thread to escape the Labyrinth.
- **Points** buy unlocks: extend or block tasks, harder contract types, and access to boss lairs.
- **Twist (idea):** "Arena contracts." You capture rather than kill certain beasts and ship them to the capital's arena, which ties Slayer to Hunter.

### Gathering

| Skill | Roman flavor |
|---|---|
| Mining | Copper, tin, iron, silver, lead, gold, and marble quarrying. |
| Woodcutting | Oak, pine, cedar, olive wood. |
| Fishing | Anchovy and mackerel feed garum production; tuna and eels come later. |
| Farming | Grain, olives, grapes, herbs. Patches take real time to grow. |
| Hunter | Traps and nets. Live capture for the arena. |

### Artisan

| Skill | Roman flavor |
|---|---|
| Smithing | Bronze to iron to Noric steel to orichalcum to meteoric iron (our own metal tiers). |
| Cooking | Bread, garum, roasts, *posca*. Wine making could live here or under Farming. |
| Crafting | Pottery and amphorae, glassblowing, leather, mosaics, jewelry. |
| Fletching | Bows, arrows, javelin shafts, sling bullets (lead *glandes*). |
| Medicina | Replaces Herblore. Remedies drawn from Dioscorides and Galen. |
| Engineering | Replaces Construction, with a bigger scope: your villa (the player-owned house), plus **roads, waystations, and aqueduct repairs** that change the world. |

### Support

| Skill | Roman flavor |
|---|---|
| Athletics | Replaces Agility. Obstacle courses, plus chariot-racing laps in the circus. |
| Thieving | Pickpocket merchants and senators, crack strongboxes, run the Subura's underworld. |
| Mercatura (idea) | Trading caravans and ships between provinces. An original skill that fits a later MMO economy well. |

## Replacing magic

OSRS magic does three jobs: a third combat style, teleportation, and utility spells such as alchemy and enchanting. Each needs a replacement.

### Third combat style (**Open**)

| Option | How it works | Pros | Cons |
|---|---|---|---|
| **A. Ritus (curses and rites)** | Real Roman folk magic: *defixiones* (curse tablets), augury, charms. Low-fantasy debuffs and damage over time rather than fireballs. | Historically grounded and flavorful. Keeps a three-way combat triangle. | Still "magic", so it needs a light touch. |
| **B. Machina (siege and incendiaries)** | Hand-held artillery, incendiary pots, caltrops. | No supernatural elements at all. | Overlaps with Ranged, and the triangle gets muddy. |
| **C. Two styles only** | Melee and Ranged, with gods and Pietas giving the utility. | Simplest. | Loses the rock-paper-scissors depth that makes OSRS bossing interesting. |

**Recommendation:** A. Ritus. The triangle becomes Melee beats Ranged, Ranged beats Ritus, and Ritus beats Melee. It keeps the depth and is still true to Roman beliefs.

### Travel

Without teleports, travel becomes a progression system:

- **Cursus publicus**: the state relay network. Waystations work as unlockable fast-travel points.
- **Roads** that you help build with Engineering speed up travel between regions.
- **Horses and carts** for overland travel, and **ships** for sea routes between provinces.
- Rare consumables, such as a blessed token from a temple, return you to a shrine.

### Utility

- Selling items: sell to merchants, or use the forum market.
- Enchanting: you consecrate jewelry at temples, using Pietas.

## Controller-first input

OSRS is built on point-and-click. A controller needs a different interaction model:

- **Direct movement** with the left stick, and an **orbit camera** on the right stick.
- **Context interaction:** face a target and press A for the default action, or hold for a **radial menu** with the other options (this replaces right-click menus).
- **Soft target lock** in combat, with the bumpers cycling targets.
- **Radial or grid inventory** that you navigate with the D-pad.
- Mouse and keyboard keep click-to-move and right-click menus.

**Open:** should movement be tile-based, like OSRS, or free? Free movement feels better on a stick. The simulation could still snap to a grid for pathing and server authority.

## Architecture

Decided: **Godot 4** client.

Principles that keep an MMO possible without building one now:

1. **Tick-based simulation.** Game logic advances in fixed ticks (OSRS uses 0.6 s) and stays separate from rendering. That makes the logic deterministic, testable, and easy to move server-side later.
2. **The simulation doesn't depend on rendering.** Combat math, XP, drops, and Slayer assignment live in plain logic classes that never touch scene nodes.
3. **Content is data.** Items, monsters, drop tables, Slayer tasks, and XP curves live in data files rather than code. The Python/uv tooling in this repo validates content with pytest.
4. **Saves are versioned.** Saves are serialized state that a server could store later.

Art direction (**Open**): low-poly 3D from a fixed-pitch, rotatable camera, which is closest to the OSRS feel and cheap to produce. The alternative is 2D isometric.

## IP guardrails

The game should feel like OSRS without copying it. Game mechanics such as skills, XP curves, and Slayer tasks are generally fine to borrow; specific expression is not. *(Not legal advice.)*

- No OSRS names: places, NPCs, items, monsters, metal tiers (for example rune, adamant, mithril), or skill icons.
- No copied art, sprites, music, sound effects, or UI layout. Our interface is designed for controllers anyway.
- Our own XP curve. It can have a similar exponential shape, but not the exact table.
- Use mythology and history, which are public domain, for monsters and lore.

## First vertical slice (proposal)

The smallest build that proves the core loop:

- One frontier town plus one nearby wilderness area and a small dungeon.
- Skills: Attack, Strength, Defence, Vitality, **Slayer**, Mining, Smithing, Cooking.
- One venator with five or six task monsters, including one that needs a gear check.
- A bank, a shop, and a smithy.
- Controller and mouse/keyboard input, save and load.

## Open questions

1. Rome: are you committed, or keeping other settings on the table?
2. The third combat style: Ritus, Machina, or two styles only?
3. Tile-based or free movement?
4. Low-poly 3D or 2D isometric?
5. How grindy should it be? OSRS-level (99s take hundreds of hours) or compressed for single-player?
6. Quests: OSRS-style story quests, or a legion-rank career track (*tiro* to *centurion*), or both?
