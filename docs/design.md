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

Decided (tentatively): **Greco-Roman Mediterranean.** We also considered Norse, feudal Japan, Bronze Age Mesopotamia, and Byzantium. Rome won because it gives the clearest contrast with OSRS's medieval fantasy, a deep public-domain bestiary for Slayer, real trades to build skills around, and a natural progression ladder in citizenship and military rank.

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
| Ranged | Bows (*arcus*), slings (*funda*, with lead *glandes*), and javelins thrown with an *amentum* (a leather throwing loop; Aulus sells it with bronze javelins, the quartermaster sells iron ones after Miles, and the smith makes five from a bar and a log, up to the steel *pilum* at Ranged 30). Javelins reach 5 m and throw every 5 ticks but hit hardest. The hand-held *manuballista* comes later. Styles: Aimed (+accuracy), Rapid (one tick faster), Longrange (+2 m range, XP split with Defence). About 75% of fired ammunition can be picked up again. |
| Pietas | Replaces Prayer. You make offerings at shrines and get buffs from patron gods. The heavenly gods are Mars (strength), Minerva (defence), Diana (ranged), and Mercury (movement and run energy). The underworld gods (Dis Pater, Proserpina, Hecate) favour Ritus. XP comes from offerings: incense, wine, votive objects, and hides and bones left at altars. See [Curses and Pietas](#curses-and-pietas). |
| Ritus | The third combat style: curse tablets. See [Ritus](#ritus). |

**Built (#179): special attacks.** Players have *impetus* (0 to 100, refilling 20 a minute, saved). F (B on a controller) arms the wielded weapon's special; the next attack spends it if there's enough. Pugiones: *twin thrust* (25, two hits). Gladii: *legion's thrust* (50, half again as accurate and a fifth harder). The spatha: *cavalry sweep* (50, half again as hard, a little less accurate). The framea: *hurled framea* (50, twice as accurate). Bows: *volley* (50, two arrows). The sling: *heavy glans* (25, half again as hard). The HUD shows impetus and when a special is ready; two hits in one tick show two numbers, offset.

### Slayer

Kept as a core skill and the center of progression.

- **Contracts** come from *venatores*, beast-hunters attached to provincial governors. Higher-level venatores live in more dangerous places.
- **The bestiary** draws on public-domain myth: harpies, lamiae, strix, centaurs, cyclopes, satyrs, lemures (restless dead), basilisks, the catoblepas, manticores, gorgons, hydras, and the Minotaur as a late boss.
- **Gear checks** tie each monster to a myth. You need a polished bronze mirror-shield against gorgons and basilisks, wax earplugs against sirens, fire to stop hydra heads growing back, and a thread to escape the Labyrinth.
- **Points** buy unlocks: extend or block tasks, harder contract types, and access to boss lairs.

**Built (#147): rewards.** Aulus pays 3 points a contract, 5× on every 10th in a row and 15× on every 50th. His menu spends them: cancel the current contract (15), never be sent after that monster again (50; up to four blocks, and unblocking is free), and learn the venator's helm (60). The helm is sewn (Crafting 30) from a wolfskin hood, a whitethorn charm, leather and thread; it wards off the strix like the charm and adds 15% accuracy and max hit against your current task monster. Monsters can now carry a proper plural ("wolves", "lemures") for contract text.

**Built (#148): sirens.** Four sirens (level 38, Slayer 30) sing on the rocks at the west end of Portus Salis's beach, by sea stacks and the wreck of a boat that listened. Without a ward their song always lands and holds you: you can't strike for 6 ticks after each one, longer than their attack speed, so you never get a blow in. Wax earplugs (Crafting 20: two beeswax, from the sacerdos in packs of ten, and linen) are the ward. The venator's helm can be sealed with earplugs (Crafting 35) to ward off both the strix and the sirens. Aulus assigns sirens at Slayer 30 and combat 35; they drop coins, tuna, beeswax, and sometimes a pearl.

**Built (#149): Ursa the Venatrix.** The second venator, a Germanic huntress in Roman pay, stands in the safe yard just inside the limes. She only works with hunters of combat 50 or more, pays 10 points a contract (streak bonuses apply), and hands out long contracts on the frontier and the hardest Slayer creatures: dire wolves and raiders (30 to 50), sirens, harpies, strix, lemures, and, at combat 75 and Slayer 50, three to six kills of Hrodgar himself. A venator's `combat_level` is now the minimum to get any contract from them.

**Built (#155): basilisks.** Four basilisks (level 52, Slayer 40) guard the mouth of Vipasca's deep gallery. Unwarded, their gaze always lands and drains Attack, Strength and Defence by a level a hit (eating into any remedy boost first), down to 30% below your level; the HUD shows it ("Atk 50-4") and it recovers a level a minute. A mirror shield wards it: three bronze bars and a silver bar polished at an anvil (Smithing 30), a weaker shield than steel, so it's a real trade. Both venatores assign basilisks at Slayer 40. They drop coins, steel bars, coal, silver ore, and rarely a basilisk eye.
- **Built (#188): arena contracts.** Lanista Marcia at Portus Salis buys beasts for the games in Rome. Her menu offers contracts by Hunter level: five wild boars (Hunter 20), five wolves (25), four harpies (35), four dire wolves (45), two basilisks (60). Beat the beast below a quarter of its health and throw a weighted net over it (she sells them; it's on the beast's menu): it's taken alive, with no drops but Hunter XP, and she pays 220 to 1,300 denarii when the contract is done. The HUD shows what's left to net.

### Gathering

| Skill | Roman flavor |
|---|---|
| Mining | Copper, tin, iron, silver, lead, gold, and marble quarrying (Parian marble on Seriphos, 45). |
| Woodcutting | Oak, pine, cedar, olive wood. |
| Fishing | Anchovy and mackerel feed garum production. Tuna is harpooned off Portus Salis's pier (40), and eels are trapped in an eel pot in the reed pool below Seriphos's olive grove (30; Nikias sells the pots). |
| Farming | Grain, olives, grapes, herbs. Patches take real time to grow. |

**Built (#117): herbs and vegetables.** Two herb patches and two allotments in the boar-free fields south of the fort. Herbs: mint (1), fennel (9), sage (18), wormwood (27), poppy (36); vegetables: cabbage (1) and broad beans (8). Plant with seeds and a trowel (the Gaulish merchant sells mint and cabbage seeds and trowels; the rest drop from rats, boars, lemurs, and the strix). Crops grow in four stages over a few minutes of game time, and keep growing while the game is closed: saves record the real time, and loading turns the time away into growth. Harvests give 3 to 5 herbs or 4 to 7 vegetables. Grain, olives, and grapes come with the villa.

**Built (#221): grain.** Two grain fields in the fort's farmland grow emmer wheat from seed wheat (Farming 10; the Gaulish merchant sells it, and rats sometimes drop it). A quern beside the fields grinds a sheaf into flour (Cooking 8), and flour bakes into bread on any range or fire (Cooking 10). *Bread for the Garrison* (#231), a starter quest from Sabina the baker beside her forum stall, walks a new player through it: five pots of flour, then three loaves, for Cooking and Farming XP, coins and seed wheat.

**Built (#249): more starter quests.** *The Smith's Apprentice*, from Tertius the smith by the anvil, walks a new player through Mining and Smithing: five copper and five tin, two bronze bars, then a bronze gladius (Smithing 5). The reward is XP, the gladius back, and a bronze scutum. *Gifts for the Gods*, from the sacerdos, asks for five bones and a wolf pelt, and teaches offering: Pietas XP and ten incense to offer at the altar.
| Hunter | Traps and nets. Live capture for the arena. |

**Built (#109): box traps.** Hare burrows south of the fields (Hunter 1) and fox dens at the wolf woods' edge (15). Set a box trap (from Aulus) at one; it springs by chance every few ticks, better with level. Checking a sprung trap gives raw meat and a pelt, XP, and the trap back. Traps left out when you save come back to your pack on load. Nets and live capture for the arena come later.

### Artisan

| Skill | Roman flavor |
|---|---|
| Smithing | Bronze to iron to Noric steel to orichalcum to meteoric iron (our own metal tiers). |

**Built (#154): Noric steel.** Coal (Mining 30) comes from the Vipasca pit. A steel bar is an iron ore and two coal (Smithing 30), and steel makes a pugio (30), axe (31), galea (32), pickaxe (33), gladius (34), arrowheads (35), scutum (36) and lorica (38), all needing level 20 to use. Steel tools are tier 3: as fast as iron, but they land more often. Silver bars smith into silver fibulae (32).

**Built (#233): orichalcum.** Three orichalcum veins at the bottom of the Vipasca pit (Mining 55). A bar is an orichalcum ore and four coal (Smithing 50), and orichalcum makes a pugio (50), axe (51), galea (52), pickaxe (53), gladius (54), arrowheads (55, fletched into arrows at 45), scutum (56) and lorica (58), all needing level 40 to use. Orichalcum tools are tier 4, a tick faster than steel.
| Cooking | Bread (from the fort's wheat), garum, roasts, *posca*, and pressing oil and wine at the villa. |

**Built (#103): garum.** A garum vat by the pond ferments 4 anchovies and 2 salt into garum (Cooking 15). Garum goes into better food: anchovy relish (16) and mackerel in garum (25, heals 11). The Gaulish merchant in the forum sells salt, linen, and thread.
| Crafting | Pottery and amphorae, glassblowing, leather, mosaics, jewelry. |

**Built (#97): leather first.** Boars always drop a hide; the tanning rack at the smithy turns hides into leather. With a needle and thread (from Aulus), leather is sewn anywhere (the inventory's Sew option) into a leather cap (1) and jerkin (7), and with wolf pelts into a wolfskin hood (15) and jerkin (22). All give ranged attack and more defence against arrows than blades: the ranger's armour line.

**Built (#185): pottery and glass.** A potter's yard by the pond, outside the east gate: three clay deposits on the water's edge (Mining 1), a kick-wheel and a brick kiln. Throw clay on the wheel into pots (Crafting 1), bowls (5), amphorae (12) and oil lamps (20), then fire them in the kiln. The kiln also melts sand (sold by Nikias on Seriphos and the fishmonger at Portus Salis) into glass with a blowpipe (Nikias): vials (25) and bowls (32). Everything sells, so it's an early earner; the Tabularium has a page for it.

**Built (#186): jewellery.** With jeweller's tools (the procurator sells them), silver and gold bars are worked anywhere (the inventory's Work option) into neck pieces: a silver pendant (Crafting 30; a crescent for Hecate, with Ritus bonuses), an amulet of Diana (38, two silver bars; ranged bonuses), and a gold bulla (45; the locket freeborn Roman children wore, with melee and defence bonuses, needing Defence 35).
| Fletching | Bows, arrows, javelin shafts, sling bullets (lead *glandes*). |
| Medicina | Replaces Herblore. Remedies drawn from Dioscorides and Galen. |

**Built (#118).** With a mortar and pestle (from the sacerdos, with honey; he already sold wine), herbs from Farming are mixed anywhere (the inventory's Mix option) into remedies: mint tonic (1, Attack), fennel draught (8, Strength), sage salve (16, Defence), wormwood bitters (25, Ranged), and poppy draught (34, heals 16). A boost adds flat levels plus a share of your level (fennel at Strength 50: +6), shows on the HUD as e.g. "Str 50+6", wears off a level a minute, and is lost on death.
| Engineering | Replaces Construction, with a bigger scope: your villa (the player-owned house), plus **roads, waystations, and aqueduct repairs** that change the world. |

**Built (#129): the villa.** Citizens (Decurio done) buy a villa from the land surveyor in the forum for 5000 denarii. A private road east of the fort leads to the villa grounds (a walled estate far east, past the barrow), closed to anyone without one. Logs are sawn into planks at the sawpit by the smithy (Engineering). Seven hotspots around the courtyard take furniture built from planks, nails, and iron with a hammer, and each piece is the real thing: the hearth holds a campfire (1) or a clay oven (20); the workshop a tanning rack (5) or an anvil (25); the shrine a lararium (10) to pray at; the strongroom a strongbox (30) that opens your bank; two garden beds take herb (1) or vegetable (8) beds that grow like any patch; and the road stone takes a waystone (40) that sends you straight to Portus Salis. Furniture can be removed and rebuilt, and the villa and everything in it are saved.

**Built (#210): the estate.** Two press-house floors on the west lawn take an olive press (Engineering 30) or a wine press (38), working stations where four olives press into an amphora of olive oil (Cooking 25) and five bunches of grapes into estate wine (35). Garden beds can also take a vine trellis (15), planted with vine cuttings from Nikias (Farming 20) and harvested for grapes. A steward's desk in the office (25; 4 oak planks and 1,000 denarii to hire him) puts a freedman steward in charge: he fills an amphora per press every two hours of real time, even with the game closed, and keeps at most a day's worth for you to collect. Oil and wine sell for little in shops, but Mercatura contracts want them: oil for the harbour lamps (Mercatura 20) and wine for the Gauls (30).

**Built (#219): marble and mosaics.** A small quarry in the hills south of Seriphos's town has outcrops of Parian marble (Mining 45). With a mason's chisel (Nikias sells one), a marble block carves into 25 tesserae anywhere (Crafting 40, the inventory's Carve option). The villa courtyard's centre takes a mosaic floor (Engineering 45; 150 tesserae and 2 oak planks), a rosette in a meander border. Resting on it leaves you rested: +5% XP in every skill for 30 minutes of play, shown on the HUD and kept in the save.

### Support

| Skill | Roman flavor |
|---|---|
| Athletics | Replaces Agility. Obstacle courses, plus chariot-racing laps in the circus. |

**Built (#98).** A training course east of the fort: log balance, palisade wall, rope swing over a ditch, and hurdles. Each obstacle is a timed crossing; whether you fall is rolled when you start, so the client plays a clean crossing or a stumble back to the start (a little damage, never lethal). Falls stop by about level 25 to 40. Running the four in order earns a lap bonus. Each Athletics level adds 0.2% run speed. Content lives in `game/content/athletics.json`.

**Built (#239): shortcuts.** A course of its own with no lap bonus: each shortcut is a single crossing, usable from either side. The first is a ladder over the fort's west wall to the grove (Athletics 10), which saves the walk round the south-west corner.

**Built (#217): chariot racing.** A road east from the fort leads to the circus: a sanded oval round a spina with turning posts and an obelisk, with stands along both straights. The Reds' factio agent enters you in a three-lap race (Athletics 20, 25 denarii) against the Blues and the Greens. After a short countdown you drive a two-horse chariot with the usual movement controls; it's faster with Athletics, but the corners are yours to take. The rivals hold a steady pace on their lanes. A lap counts only when you pass every quarter of the track in order, so cutting across doesn't help. Every lap gives XP, and your place adds more, plus prize money (250 and 80 denarii for first and second) and a victor's palm for a win. The HUD shows your lap and current place, and leaving the track forfeits the race.

**Built (#255): the munera.** The editor of the games at the circus's east end sends a fighter of combat 20 or more out onto the sand past the east turning post, for ten waves of beasts and raiders (wolves and boars, latrones, dire wolves, Germanic raiders, and finally a cyclops), with a short rest between each. Every wave cleared pays coins, rising to 400 for the last, and clearing all ten wins a *rudis*, the wooden sword of a freed gladiator, which is a good weapon in its own right (Attack 40). Falling in the arena isn't a death: the attendants carry you out, with no grave and nothing lost but the rest of the games. Running from the sand forfeits. The monsters come from the sim (reserved ids, no respawn and no drops), and the world builds and removes their bodies.
| Thieving | Pickpocket merchants and senators, crack strongboxes, run the Subura's underworld. |

**Built (#95).** In Castra Ferrea's forum: three market stalls (baker at 1, cloth at 12, silversmith at 25) that empty for a while after a theft, and two marks to pickpocket (a townsman at 1, a merchant at 18) for coins. Stallholders sometimes catch you; inside the walls the vigiles then warn and fine you, as they do for Ritus. A failed pickpocket stuns you for a few ticks (no walking, attacking, or thieving) and does a little damage, never lethal. Content lives in `game/content/thieving.json`.

**Built (#218): strongboxes.** Three strongboxes to crack with a lockpick (smithed five to an iron bar at Smithing 16, or bought from the Portus fishmonger, who asks no questions): a shipping agent's box in Portus Salis (Thieving 30), the Vipasca pay chest by the procurator (42), and Nikias's coffer on Seriphos (55). Working a lock takes a few ticks; a sprung needle trap hurts (never fatally) and snaps the pick half the time, and a cracked box pays out coins, silver, gold or pearls from its own table and stays empty for a while.
| Mercatura | Trade contracts between provinces. See [Mercatura](#mercatura). A later addition, not part of the first vertical slice. |

### Mercatura

Mercatura works like a skill rather than a menu over the market:

- **Training:** take contracts from a trade board, buy goods in one region, and deliver them to another. Examples are garum from the coast to the frontier, Hispanic silver to the capital, and Egyptian grain to anywhere. XP depends on distance, cargo value, and risk.
- **Risk:** bandits on the road and pirates at sea. You defend the cargo, hire guards, or take a safer, slower route.
- **Unlocks by level:** carts, then wagons, then merchant ships. Also larger cargo, warehouses in each province, more lucrative trade routes, lower fees at the forum market, and membership in a merchants' guild.
- **Links to other skills:** artisan products sell for more in the right region, so Mercatura rewards specialists.

**Built (#120): trade contracts.** Trade boards at Portus Salis (cargoes wanted inland: garum and salt for the quartermaster, grilled tuna for the Gaulish merchant) and in the fort's forum (cargoes wanted at the coast: iron bars, oak logs, and linen for the fishmonger's shipwrights). Take one contract at a time, source the goods yourself (the fishmonger sells garum cheaply at the coast), and deliver to the named shopkeeper for coins and Mercatura XP. Higher levels unlock bigger contracts. The quest log tracks the current contract. Carts, wagons, ships, regional prices, and risk on the road come later.

**Built (#237): regional prices.** Shops can want particular goods at their own price (`buys.prices`), above their usual rate and even when they don't otherwise trade in them. The Portus fishmonger pays well for olive oil, iron, oak and linen for the ships; the Gaulish merchant pays over the odds for estate wine (1.2× its value) and for garum; Nikias on Seriphos wants iron, steel and silver fibulae; and the procurator at Vipasca buys bread, meat and oil for the miners. Selling the same goods where they're wanted pays noticeably more than selling them anywhere.

## Replacing magic

OSRS magic does three jobs: a third combat style, teleportation, and utility spells such as alchemy and enchanting. Each needs a replacement.

### Third combat style

Decided: **A. Ritus.** The options we compared are kept below for reference.

| Option | How it works | Pros | Cons |
|---|---|---|---|
| **A. Ritus (curses and rites)** | Real Roman folk magic: *defixiones* (curse tablets), augury, charms. Low-fantasy debuffs and damage over time rather than fireballs. | Historically grounded and flavorful. Keeps a three-way combat triangle. | Still "magic", so it needs a light touch. |
| **B. Machina (siege and incendiaries)** | Hand-held artillery, incendiary pots, caltrops. | No supernatural elements at all. | Overlaps with Ranged, and the triangle gets muddy. |
| **C. Two styles only** | Melee and Ranged, with gods and Pietas giving the utility. | Simplest. | Loses the rock-paper-scissors depth that makes OSRS bossing interesting. |

The triangle is Melee beats Ranged, Ranged beats Ritus, and Ritus beats Melee.

### Ritus

Decided. Ritus is built on real Roman curse practice. People wrote curses on thin lead sheets (*defixiones*), rolled them up, nailed them, and left them in graves and wells for the underworld gods. Most curses asked for a rival to be *bound*, so Ritus hinders rather than blasts.

**In combat:**
- A **focus** goes in the weapon slot. The first is the *lituus*, an augur's curved staff. It casts from about 6 m.
- **Inscribed tablets** go in the ammo slot, and the tablet type decides the curse. Tablets are always used up; unlike arrows, none can be picked up again.
- **Styles:** Focused (+3 Ritus) and Warding (+3 Defence, XP split with Defence).

| Tablet | Ritus level | Effect |
|---|---|---|
| Binding | 1 | A light hit, and often a slowed target: it attacks 1 tick slower for a while |
| Withering | 15 | Damage over time: "may his limbs waste away" |
| Silencing | 30 | The target's next attack automatically misses |
| Calling the Manes | 50 | A shade of the dead fights your target for 30 ticks; its kills and XP are yours. Ghosts drift through walls. |

**The triangle comes from gear defence bonuses, as in OSRS:**
- Metal armour such as the lorica has a *negative* curse defence ("iron doesn't stop a curse"), so Ritus beats Melee.
- Ritual robes give good curse defence but poor Ranged defence, so Ranged beats Ritus.
- Ranged gear is light and offers little melee defence, so Melee beats Ranged.

**Supplies** tie existing skills together:
- **Mining:** galena, the ore Rome got its lead from.
- **Smithing:** galena smelts into lead sheets, and bars become nails.
- **Slayer drops:** grave ash from lemurs for Withering, and strix feathers for the later tiers.
- **Inscribing:** done with a stylus at the tomb in the Castra Ferrea cemetery, as the Romans buried their curses with the dead. Inscribing gives some Ritus XP.
- **The libitinarius** sells the stylus, the lituus, and ritual robes.

**Tone: eerie folk ritual, not dark fantasy.**
- Effects are subtle: the target shudders, stumbles, or falters under faint dark motes. There are no beams and no fireballs.
- Curses invoke the powers the real tablets name: Dis Pater, Proserpina, Hecate, and the Manes. Item descriptions quote real tablet wording, such as "I bind his tongue, his hands, his feet."

### Curses and Pietas

Decided (#48) and built in #69. Numbers: 4 pollution per curse, polluted at 30, wears off 1 point every 15 seconds; polluted heavenly blessings work at half strength and underworld ones at 1.5×; cleansing costs 20 denarii. Cursing wasn't impious to Romans: curse tablets were addressed *to* gods. What Romans feared was **ritual pollution** from dealings with death, and the law punished harmful magic. So the tension is about pollution and the law, not divine anger.

- **Two families of gods.** The heavenly gods (Mars, Minerva, Diana, Mercury) give the core combat prayers. The underworld gods (Dis Pater, Proserpina, Hecate) give prayers that favour Ritus.
- **Pollution.** Casting curses builds pollution, which wears off over time.
  - High pollution weakens heavenly prayers, and their temple priests refuse you service.
  - Underworld prayers grow *stronger* while you're polluted, so dedicated cursers lean in.
- **Purification.** Washing at a sacred spring or paying for a temple cleansing (*lustratio*) clears pollution. It's cheap and quick, so pollution is something to manage, not a punishment.
- **The law.** Casting curses inside town walls draws the town watch (the *vigiles*): first a warning, then a small fine (25 denarii, at most once a minute). In single-player this is mostly flavour. In the MMO it keeps curses out of town fights.
- Nothing is permanent, and mixed builds stay viable with a little planning.

### Travel

Without teleports, travel becomes a progression system:

- **Cursus publicus**: the state relay network. Waystations work as unlockable fast-travel points.
- **Roads** that you help build with Engineering speed up travel between regions.
- **Horses and carts** for overland travel, and **ships** for sea routes between provinces.
- Rare consumables, such as a blessed token from a temple, return you to a shrine.

### Utility

- Selling items: sell to merchants, or use the forum market.
- Enchanting: you consecrate jewelry at temples, using Pietas.

**Built (#235): later offerings.** Higher-level offerings come from newer content: dire wolf pelts (30 XP), pressed olive oil (40) and estate wine (65) at the heavenly altars; harpy feathers (55), basilisk eyes (85) and gorgon scales (115) at the underworld altars. As always, the wrong altar gives half.

## Combat

Decided: **OSRS-style tick combat**, adapted for free movement and controllers. Combat is decided by stats, gear, and decisions, not by reflexes such as dodge rolls with invincibility frames.

- **Auto-attack:** lock onto a target and your character attacks on its weapon's tick timing until you stop or the target dies.
- **Auto-retaliate:** a toggle, on by default. When it's on, you fight back automatically if attacked.
- **Skill through decisions:**
  - **Gear swaps.** Swap loadouts to exploit the Melee, Ranged, and Ritus triangle. You can save loadouts and switch them with the D-pad.
  - **Pietas buffs and protections**, switched in response to what a boss is doing.
  - **Movement** out of telegraphed attacks, such as ground areas that are about to be hit or charges.
  - **Special attacks** (working name *Impetus*). Weapons spend a regenerating bar on a strong special attack.
  - **Eating and potion timing.**
- **Why this model:** it keeps the AFK-friendly grind, it is easy to play on a controller, and it tolerates network latency well, which matters for the MMO later.

## Death

Decided: **follows OSRS's structure.**

**Outside the danger zone (PvM deaths):**
- You keep your 3 most valuable items.
- Everything else stays in a grave at the spot where you died for a limited time, and you can collect it for free.
- After that, the items pass to the *libitinarii* (Rome's undertakers' guild), who return them for a fee based on their value.

**Beyond the Limes (the danger zone), PvM:**
- You keep your 3 most valuable items.
- Everything else drops where you died. You can only get it back by fighting your way back to it in time. There is no fee-based recovery.
- In the MMO, other players can loot the dropped items after a short delay.

**Beyond the Limes, PvP (MMO only):**
- Attacking another player marks you as *sacer*, a Roman legal status meaning someone could be killed with no penalty to the killer.
- While marked you keep no items, and your killer gets everything.

## Controller-first input

OSRS is built on point-and-click. A controller needs a different interaction model:

- **Direct movement** with the left stick, and an **orbit camera** on the right stick. The camera only rotates when you move it; it never auto-follows (decided).
- **Context interaction:** face a target and press A for the default action, or press Y for a **radial menu** with the other options (this replaces right-click menus).
- **Soft target lock** in combat, with the bumpers cycling targets.
- **Radial or grid inventory** that you navigate with the D-pad.
- Mouse and keyboard keep click-to-move (left-click the ground, a monster, or anything usable). Right-clicking anything opens an OSRS-style menu of everything you can do with it.
- On a controller, Y opens the same kind of menu for everything nearby, nearest first.

Decided: **free movement.** It feels much better on a stick and is the norm for 3D action RPGs. Some notes on how it fits with the rest of the design:

- Free movement and tick-based logic work together. Movement is continuous, and actions (attacks, skilling attempts, XP) resolve on ticks. Inputs are queued so a tick never swallows a button press.
- Attack range is measured as a distance (melee reach, bow range) rather than in tiles. OSRS-style precise movement tricks such as safespotting and step-under come back as obstacles and line of sight.
- For a later MMO, the server owns the true positions and the client predicts its own movement, which is the standard approach for free-movement online games.

## Architecture

Decided: **Godot 4** client.

Principles that keep an MMO possible without building one now:

1. **Tick-based simulation.** Game logic advances in fixed ticks (OSRS uses 0.6 s) and stays separate from rendering. That makes the logic deterministic, testable, and easy to move server-side later.
2. **The simulation doesn't depend on rendering.** Combat math, XP, drops, and Slayer assignment live in plain logic classes that never touch scene nodes.
3. **Content is data.** Items, monsters, drop tables, Slayer tasks, and XP curves live in data files rather than code. The Python/uv tooling in this repo validates content with pytest.
4. **Saves are versioned.** Saves are serialized state that a server could store later.

Art direction (decided): **low-poly 3D** with a third-person orbit camera that can zoom out to an OSRS-like high angle. Use flat or vertex colors and very few textures, so one person can make art quickly and it stays readable from a distance.

## Progression

### Grind

Decided: **grindy, on the OSRS scale.** Skills go up to level 99, and maxing a skill should take hundreds of hours.

- The XP curve is exponential, so every level takes more XP than the one before. We write our own formula and table rather than copying OSRS's.
- Every few levels unlock something real: a new resource, item, area, or training method. That keeps the long climb from feeling empty.
- Each skill has at least one fast, attention-heavy training method and one slow, low-effort method, as in OSRS.
- Skilling outfits, pets, and log-style collections (like OSRS's collection log) give long-term goals.
  - **Built (#133): the Tabularium**, a collection log (L / right trigger). Pages by source (beasts, latrones, the barrow, Slayer creatures, seeds, fishing, the harvest, Hunter, thieving, and quest rewards) list notable items with how many you have obtained; missing ones are greyed out. Items count when they drop from your kills or come from skilling, thieving, or quests, not from shops or trades. The first of each is announced.
  - **Built (#137): pets.** Very rare companions listed in `content/pets.json`: a mole (Mining, 1 in 3,000 per XP drop), a magpie (Thieving, 1 in 2,500), a leveret (Hunter, 1 in 800), and a wolf cub (Hrodgar, 1 in 150 kills). A new pet follows you at once (or goes in your pack if one is already out). Use a pet to let it out, and pick it up from its menu. One follows at a time, a pet is never lost on death, and you can't get a second of the same pet. Pets have their own page in the Tabularium.

### Quests and career

Decided: **both.**

- **Auxilia career track.** This fits the history neatly. Non-citizens joined the auxilia, the non-citizen units of the Roman army, and earned citizenship when they were discharged. Your career runs from *tiro* (recruit) through *miles*, *duplicarius*, and *decurio*, and ends with your honorable discharge and **citizenship**. After that, the legions open up, up to *centurion*. Each rank is a multi-part quest, gated by skill and combat levels, and it unlocks equipment, areas, and the capital.
- **Standalone story quests** for side stories, region lore, and mythic adventures, with skill requirements and XP rewards in the OSRS style.
- Citizenship is the game's main mid-game milestone. It unlocks the capital's forum market, owning a villa, and higher-level venatores.

**Built (#83).** Quests live in `game/content/quests.json`: quest NPCs, and per quest a giver, requirements (skills, other quests), start and completion dialogue, items handed out at the start, ordered steps (`attack` a tagged target with a given combat style, `kill` monsters, `talk` to an NPC; the last step is always handing in), and rewards (XP, items, a rank, and a description of what it unlocks). Progress is per player and saved. Shops can require a finished quest (`requires_quest`). The quest log is on J / D-pad right.

The first rank is **Tiro**, given by Optio Gaius by the forum. He hands out a sling, lead, a lituus, and binding tablets; the recruit strikes the training dummy with a blade, a sling, and a curse, clears three granary rats, and reports back for combat XP, a *parma* (round auxiliary shield), the rank, and the quartermaster's iron stores.

The second rank is **Miles** (#92; needs Tiro and Defence 5): kill five wolves on the woods road, bring the optio 10 logs and 15 bronze nails for the palisade (`deliver` step), and scout the old barrow (`reach` step). The reward is XP, a *lorica hamata* (mail shirt, Defence 15), the rank, and mail and heavier arms from the quartermaster (shop offers can carry their own `requires_quest`). The third is **Duplicarius** (#102; needs Miles, Attack 15, and Thieving 5): silver is going missing from the strongroom. Ask the Gaulish merchant in the forum (also a pickpocket mark), kill the latro on the south-west road (the step grants the stolen pay chest), and hand it to the optio. The reward is XP, a *spatha* (cavalry long sword, Attack 20), the rank, and spathae from the quartermaster. The last is **Decurio** (#108; needs Duplicarius, Defence 25, and Slayer 15): a *larva* has woken in the barrow's depths. The sacerdos teaches the rite of the Lemuria and gives nine black beans; with them in your pack (a ward that works when carried, `ward_carried`), you can hurt the Larva, a level-40 boss in the deepest chamber that drops a *larval shroud* (Ritus neck item) now and then. Without the beans your blows pass through it. Reporting back ends the auxilia career: the rank of decurio, honourable discharge, a bronze diploma, and **citizenship**. The HUD shows quest titles (`rewards.title`), ending with *Civis Romanus*. The capital is for citizens and comes later.

**Built (#223): the legion.** A citizen can join the legion through Centurion Varro on the limes. *Sacramentum* (Decurio done; Attack, Strength and Defence 40) has you bring wine and five incense to the sacerdos for the oath's sacrifice, kill eight Germanic raiders, and report in a legionary's kit (a steel scutum and ten steel pila). The reward is XP, a *lorica segmentata* (Defence 40, the best body armour; the quartermaster sells more), the rank of *legionarius*, and the title *Miles legionis*. *Optio* (combat stats and Slayer 60) sends you to Seriphos, where a patrol came back as statues: Melissa points you to the ruins, and three gorgons later you bring Varro a gorgon's head in a sack. The reward is XP, *phalerae* (a neck piece for valour, Defence 50), and the rank of *optio*.

## IP guardrails

The game should feel like OSRS without copying it. Game mechanics such as skills, XP curves, and Slayer tasks are generally fine to borrow; specific expression is not. *(Not legal advice.)*

- No OSRS names: places, NPCs, items, monsters, metal tiers (for example rune, adamant, mithril), or skill icons.
- No copied art, sprites, music, sound effects, or UI layout. Our interface is designed for controllers anyway.
- Our own XP curve. It can have a similar exponential shape, but not the exact table.
- Use mythology and history, which are public domain, for monsters and lore.

## First vertical slice

Decided scope for the first playable build (#6). Numbers are first guesses to be tuned through playtesting.

**Place.** *Castra Ferrea*, a fictional fort town on the frontier, with:
- a bank, a general store, a smithy (furnace and anvil), a cooking range, and the venator's post
- the woods and fields outside the walls, with a copper/tin quarry and an iron outcrop
- the *Barrow of the Lemures*, a small torchlit dungeon north-west of town: lemurs in the upper halls, two strix in the depths. Aulus sells the whitethorn charm (150 denarii).

**Skills.** Attack, Strength, Defence, Vitality, Ranged, Ritus, Slayer, Mining, Smithing, Cooking, Woodcutting, Fishing, Fletching. (Ranged was added in #36, Ritus in #45 and #46, and the gathering skills in #82, after the first build.)

**Gathering (#82).** A grove west of the fort has common trees (fall after one log), oaks, and, at the edge of the wolf woods, pines; oaks and pines give several logs before they fall and regrow from the stump. The fort's pond has a net spot (sardines, then anchovies at 10) and a rod spot (mackerel at 20), with a campfire nearby for cooking. Fletching works anywhere with a knife: logs into arrow shafts, then shafts, feathers, and smithed arrowheads into arrows, and oak logs and a bowstring into a hunting bow. New players start with a bronze axe, a small net, and a knife.

**Monsters:**

| Monster | Level (approx.) | Where | Notes |
|---|---|---|---|
| Rat | 1 | Town drains | Tutorial-tier |
| Wolf | 5 | Woods | Aggressive to low levels |
| Wild boar | 8 | Fields | Drops raw meat |
| Latro (bandit) | 12 | Road | Drops coins and bronze gear |
| Lemur | 18 | Barrow | Restless dead |
| Strix | 22 | Barrow depths | Needs Slayer 10, plus a **whitethorn charm** (from Ovid, *Fasti* VI); without the charm, its hits drain your Vitality |

**Items.**
- Copper, tin, and iron ore. Bronze and iron bars.
- Bronze and iron *pugio* (dagger), *gladius*, *galea* (helmet), *lorica* (body armor), *scutum* (shield).
- Raw and cooked meat and fish, and bread.
- Coins (*denarii*). The whitethorn charm.

**Systems.** Inventory, equipment, the shared bank, death and graves, Slayer contracts, save and load, and controller plus mouse/keyboard input.

**Second region (#119): Portus Salis.** A salt-and-garum harbour on the coast, reached by the road south-west from Castra Ferrea (it lies far west of the fort, at x around -300). A beach slopes into the sea; a timber pier runs out to a harpoon spot for tuna (Fishing 40, cooked at Cooking 35); sardines can be netted from the beach. The harbour has three timber buildings (dressed like the fort's), a bank chest, the fishmonger (harpoons, nets, rods, salt), two garum vats, and a campfire. Rock crabs (level 3) potter on the beach; harpies (level 28, Slayer 20, and a new task from Aulus; birds with women's faces) roost on the eastern rocks and drop harpy feathers. It has its own ambience of surf and gulls. Harbourmaster Lucilla gives **Harpies at the Harbour** (#125; Slayer 20, Fishing 15): kill four harpies, bring three feathers as proof, bring the fishmonger linen to mend the nets, and learn to fletch **harpy arrows** (Fletching 30; recipes can require a quest). Boats bob at the pier, nets dry on poles, and fish cure on a rack.

**The danger zone (#132): Beyond the Limes.** A gate at the end of the north road crosses the limes, a timber palisade with Roman watchtowers, into Germanic forest (far north of the fort, at z around -400). The gate warns you the first time; use it again to cross. A small yard just inside the palisade is safe, and the HUD shows when you are past it. In the danger zone a PvM death keeps your 3 most valuable items as usual, but everything else drops on the ground where you fell for 3 minutes, then it is gone. There is no grave and no libitinarii, and an earlier grave elsewhere is left alone. The frontier holds Germanic raiders (level 36; coins, iron, gold ore, and the framea spear) at a camp, dire wolves (level 30; dire wolf pelts), and a gold seam under a ridge (Mining 40). Aulus gives Slayer tasks for dire wolves (combat 40) and raiders (combat 45), so Slayer can send you over the wall. Gold smelts into bars (Smithing 40), and two bars make a gold torc, a neck piece for Defence 30 (Smithing 45).

**Frontier boss (#134): Hrodgar the War-chief.** Level 75, in a clearing ringed with standing stones north of the raiders' camp. He fights in melee, but every fourth attack he hurls a framea at where you stand instead: the spot is marked with a red ring and the spear lands 3 ticks later for 14 to 28 damage on anyone still inside. Click away (or hold the stick away) until it lands. Below a third of his health he enrages and attacks every 3 ticks instead of 5. He drops coins, gold, the framea, sometimes the gold torc, and rarely the war-chief's helm (Defence 40), a head piece better than iron. Boss mechanics come from a `boss` block in monsters.json, so later bosses can reuse them.

**Frontier quest (#134): The Lost Eagle.** Centurion Varro holds the gate in the limes. Twenty years ago a cohort marched north and never came back, and Hrodgar keeps its eagle. Needs Attack, Strength and Defence 45 and *Duplicarius*. Scout the raiders' camp, kill four raiders, defeat Hrodgar to take back the eagle, and bring it to Varro. Rewards: combat, Slayer and Smithing XP, 2,500 denarii, the title "Bearer of the Eagle", and the gold torc recipe. The eagle is valued highly, so it is always among the items you keep on death.

**Third region (#153): Vipasca, the silver mines.** A mining town in the dry hills of Hispania, named for the real one in Lusitania, far south of the fort (z around 400). The road leaves the fort's fields to the south-east. Ochre earth, dry grass and olive scrub; a paved town yard with a bank chest, a furnace and an anvil, two miners' houses, and the procurator metallorum (pickaxes, a hammer, food) at his office door. A track runs south through a cutting in the red spoil heaps into an open-cast pit, where a Roman drainage wheel turns slowly, with silver (Mining 30, smelted at Smithing 30), coal (Mining 30, for Noric steel), iron and galena. Past the pit, the track ends at the timber mouth of the deep gallery under a hill. Its ambience is a hot wind, cicadas, and the echo of picks.

**Vipasca quest (#163): The Silent Gallery.** The procurator metallorum (Mining 30, Smithing 30, Slayer 40) sends you to Foreman Masculus by the pit, who came up from the deep gallery stiff as plaster: basilisks, and the old trick of polished bronze. Kill four basilisks at the gallery mouth and bring the procurator five silver bars for the treasury's quota. Rewards: Mining and Smithing XP (3,000 each), Slayer XP (2,500), 2,000 denarii, and the procurator's stores open: steel pickaxes and coal. Quest steps can now say something as they're handed in (`say`), for NPCs who explain things along the way.

**Selling (#165).** Shopkeepers buy as well as sell. A shop's `buys` lists the items it takes (or `"*"` for anything) and the share of value it pays. The Gaulish merchant in the forum buys anything at 40%; specialists pay more for their trade: Aulus 60% for pelts, hides, feathers and monster parts; the fishmonger 60% for fish; the procurator 60% for ores and bars; the quartermaster 50% for arms and armour. A shopkeeper's menu gets a Sell entry listing what they'd take from your pack, with prices; each entry sells all of that item. Coins, pets, worthless things and quest items (the legion's eagle) can't be sold.

**The deep gallery (#167).** Once The Silent Gallery is done, the timber mouth at the end of Vipasca's track opens (before that a procurator's chain hangs across it; doorways can now require a quest). Steps lead down into a winding tunnel cut through red rock, built at startup on a 1 m grid: rough rock walls, timber frames every six metres, and torches. Two more basilisks lurk in the tunnel; a side alcove holds two silver and two gold rocks, away from the crowds in the pit; the tunnel ends in a round chamber. It lies in the underground band, so it gets cave lighting and dripping ambience.

**Vipasca boss (#168): Regulus, the basilisk king.** Level 88, Slayer 50, in the round chamber at the end of the deep gallery ("basilisk" is Greek for "little king"; *regulus* is the Latin). His gaze petrifies like any basilisk's, so bring a mirror shield. Every third attack he spits venom at where you stand instead: a green ring marks it and the glob lands 3 ticks later for 12 to 26 damage; step out. Below 30% he enrages and attacks every 3 ticks. He drops coins, steel, silver, gold and basilisk eyes, and rarely the Crown of Regulus (Defence 45, Slayer 50): a head piece that wards the basilisk gaze, freeing the shield hand. One kill in 120 brings a basilisk hatchling pet. Ursa gives Regulus contracts (three to six kills) at combat 80 and Slayer 55. Boss throws now have a kind (`throw_kind`: spear or venom) with its own marker and warning.

**Seriphos boss (#243): Euryale, the gorgon queen.** Level 108, Slayer 70, in the middle of the gorgons' ruins. A mirror shield fools her sisters but not her: unwarded (anything short of the Aegis), her gaze lands every time for half again the damage and drains your combat stats. Every third attack she hurls venom at where you stand (a green ring; step out), and below 30% she enrages. She drops coins, gorgon scales, gold, pearls, now and then the Aegis itself, and rarely the *gorgoneion*, a gold gorgon-face amulet (Defence 55, Slayer 70) that wards her gaze in place of the Aegis. Ursa gives Euryale contracts (three to six kills) at combat 95 and Slayer 70.

**Fourth region (#171): Seriphos.** A Greek island far over the sea from Portus Salis (Perseus's island in the myth, fitting for gorgons and mirror shields), reached by a ferry from the end of the harbour pier for 25 denarii each way (doorways can now charge a fare). A sandy north shore and a pier where the boats tie up; a white harbour town with a bank chest and Nikias the merchant (olives, figs, wine and tuna; he buys anything at 45%, a little better than the Gauls); an olive grove to the west; the ruined temple of Athena to the east, a marble platform with standing and fallen columns; and rocky hills rising inland. The coast's surf ambience carries over. Room is left in the hills for cyclopes and in the south-west for the gorgons' ruins.

**Seriphos: cyclopes (#173).** Four cyclopes (level 62) graze a grassy hollow cut into the island's north-east hills, reached by a path up from the temple, with their cave in its far side. They hit hard and slowly, and every fourth attack one heaves a boulder at a spot marked with an amber ring (the boss throw, with a `boulder` kind; any monster with a `boss` block can throw). They drop coins, steel, olives, sometimes a steel scutum, and cyclops cheese, which heals 14 (Polyphemus was a shepherd). Aulus (combat 55) and Ursa assign them.

**Seriphos: gorgons (#174).** Four gorgons (level 70, Slayer 60) nest in broken marble ruins in the south-west of the island, among the stone figures of earlier visitors, caught with an arm flung up too late. Unwarded, the gaze always lands, drains Attack, Strength and Defence like a basilisk's, and the blow hits up to half again as hard. Any of three wards stops it: the mirror shield, the Crown of Regulus, or the gorgons' own rare drop, the Aegis (Athena's shield: Defence 20, the best shield, Defence 50 and Slayer 60 to wield). They also drop gorgon scales (Aulus buys them), steel and gold. Ursa assigns gorgons at Slayer 60.

**Seriphos boss (#193): the Hydra.** Level 98, Slayer 75, in a reedy marsh pool south of the cyclopes' hollow (Lerna was a marsh). Its wounds close by 2 every tick: the only answer is fire. Firepots (a clay pot packed with two olives, fired in the kiln at Crafting 30) are thrown from the inventory at your target (range 7): a little burning damage and the Hydra is seared for 25 ticks, its wounds staying open. It spits venom at marked spots every third attack and enrages below 30%. It drops coins, gold, gorgon scales, pearls, steel loricae, and rarely the hydra-scale lorica (Defence 28, the best body piece; Defence 60, Slayer 70). Ursa gives Hydra contracts at combat 90. Monsters can now `regenerate` and items can be `throwable`.

**Seriphos quest (#183): The Shepherd's Flock.** Melissa, a shepherd girl by the olive grove (Attack, Strength and Defence 45), has lost her father's flock to the cyclopes. Kill four in their hollow and bring her three cyclops cheeses (made from her father's ewes; she can taste the thyme). Rewards: 2,500 XP each in Attack, Strength and Defence, 1,200 denarii, five cheeses, and Nikias starts selling cyclops cheese.

**First-time hints (#199).** A tip card under the minimap the first time something becomes useful: where the controls are (on starting), a weapon's special attack (on the first blow with one), region tasks (on the first one done), the Tabularium (on the first new item), banking (when the pack fills), and Slayer points (on the first contract). Each shows once per machine, remembered in `user://hints.cfg`.

**Region tasks (#194).** Each region has a short list of things worth doing there, like achievement diaries: Castra Ferrea 10 (mine copper, fire a pot, finish Tiro, go down into the barrow...), Portus Salis 8, Beyond the Limes 6, Vipasca 8, Seriphos 7. A task is getting an item (not buying it), killing a monster, finishing a quest, reaching a level, or visiting a place; the simulation ticks them off and says so, and finishing a region's list pays 500 to 4,000 denarii. They're listed in the quest log under the quests, which a controller's d-pad now scrolls. Content in `tasks.json`.

**World map (#139).** M (or the controller's Share button) opens a parchment map of every region where it lies, with roads and doorways drawn as dashed links, danger zones tinted red, and a marker for you. Regions are scene nodes in the `map_regions` group with `map_name`, `map_rect` and optional `map_color` metadata.

**Out of scope for the slice:** quests, the villa, Mercatura, the danger zone, and the market (all since added except the market).

## Villa

Decided: **the villa is productive, not just a convenience hub.** You get the right to own one when you become a citizen, and you build and upgrade it with Engineering.

- **Convenience rooms**, as in OSRS: a bank chest, an altar for Pietas, travel links to unlocked waystations, a workshop, and a trophy hall for Slayer heads and boss trophies.
- **Production estate:**
  - The land adds farming patches, a vineyard, an olive grove, and fishponds.
  - Presses and workshops turn your harvest into wine, olive oil, and garum. These are worth more when sold through Mercatura.
  - Production runs on real time while you're away, at a modest rate, so it supports your active play rather than replacing it.
- **Staff:** you hire workers (freedmen and tenant farmers) who manage the estate. Higher Engineering and Farming levels mean more and better staff. *Content note:* Roman villas really ran on enslaved labor. The game won't turn slavery into a mechanic. Your staff are paid workers, and slavery can be acknowledged respectfully in lore.
- **Prestige:** frescoes, mosaics made with Crafting, and gardens. These are cosmetic, plus small comfort buffs, similar to OSRS rested bonuses.

## Account modes

Decided: **Ironman-style mode from day one** (working name ***Solitarius***).

- You choose the mode when you create a character. It is stored in the save, and you can leave the mode later but never re-enter it.
- Restrictions: you can't use the forum market, and you can't pick up items you didn't earn. In single-player, the restriction that matters is the market. You also can't buy materials from the trade contracts that Mercatura delivers.
- **Architecture impact:** every item-acquisition path (shops, market, drops, rewards) goes through one place that checks the account mode. Content data marks shop stock that a Solitarius character can't buy.
- **Built (#176): leaving.** A Solitarius can give the mode up from the pause menu ("Leave the Solitarius path", pressed twice to be sure); it's permanent. The new-character screen says plainly what each path means while there's no market yet.
- **Built (#209): Hardcore Solitarius.** A third choice on the new-character screen: a Solitarius with one life. The first death, anywhere, makes it a plain Solitarius for good (with a message), and the HUD shows which one you are. A hardcore character can also leave for the standard path from the pause menu.
- Possible later: group modes in the MMO.

## Other decisions

- **Banking:** one shared bank, accessible from every bank in the world, as in OSRS. Mercatura gets its value from trade contracts and regional prices, not from moving your own items around.
- **Start:** an open frontier town with an **optional** tutorial. New players get a guided starter questline that they can skip at any time.

- **Tick length:** 0.6 s, for now. The F3 toggle stays as a debug tool for comparison.
- **Early difficulty:** wolves and boars stay dangerous for fresh characters, in the OSRS style. New players train on rats and the training dummy first.

## Open questions

None right now.

Title: **Legio** (decided unless something better comes along).
