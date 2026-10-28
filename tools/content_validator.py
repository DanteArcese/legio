"""Validate game content in game/content/.

Checks each file's structure and every cross-reference between files (drop
tables point at real items, Slayer tasks at real monsters, and so on).

Usage: uv run python tools/content_validator.py [content_dir]
"""

import json
import re
import sys
from pathlib import Path

CONTENT_DIR = Path(__file__).resolve().parent.parent / "game" / "content"
FILES = ("items", "monsters", "drops", "slayer", "player", "skilling", "shops", "pietas", "quests", "thieving", "athletics", "hunter", "farming", "mercatura", "villa", "collection", "pets", "arena", "tasks", "circus")

SKILLS = {"attack", "strength", "defence", "vitality", "ranged", "ritus", "pietas", "slayer", "mining", "smithing", "cooking", "woodcutting", "fishing", "fletching", "thieving", "crafting", "athletics", "hunter", "farming", "medicina", "mercatura", "engineering"}
COMBAT_STATS = {"attack", "strength", "defence", "vitality"}
EQUIP_SLOTS = {"head", "body", "weapon", "shield", "neck", "ammo"}
BONUSES = {"attack", "strength", "defence", "ranged_attack", "ranged_strength", "ritus_attack", "ritus_strength", "ranged_defence", "ritus_defence"}
AMMO_TYPES = {"arrow", "sling_bullet", "javelin", "tablet"}
CURSES = {"binding", "withering", "silencing", "manes"}
# Must match SPECIAL_EFFECTS in game/scripts/sim/combat.gd.
SPECIAL_EFFECTS = {"twin", "strong", "heavy", "sure", "volley"}
UNWARDED_EFFECTS = {"drain_vitality", "no_damage", "entrance", "petrify", "gorgon_gaze"}
RECIPE_KINDS = {"smelt", "smith", "cook", "inscribe", "fletch", "tan", "leatherwork", "garum", "medicina", "saw", "throw", "kiln", "jewelcraft",
                "press_oil", "press_wine", "mill"}
ROCK_KEYS = {"name", "ore", "level", "xp", "difficulty", "respawn_ticks", "color", "examine"}
TREE_KEYS = {"name", "log", "level", "xp", "difficulty", "fell_chance", "respawn_ticks", "model", "examine"}
SPOT_KEYS = {"name", "tool", "catches", "examine"}
CATCH_KEYS = {"fish", "level", "xp"}
RECIPE_KEYS = {"id", "inputs", "output", "quantity", "level", "xp", "success", "tool", "burnt", "stop_burning", "requires_quest", "requires_unlock"}
ID_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")

ITEM_KEYS = {"name", "value", "examine", "stackable", "heals", "equip", "requirements", "tool", "tool_tier", "remedy", "pet", "quest_item", "throwable"}
MONSTER_KEYS = {"name", "plural", "level", "stats", "attack_speed", "aggressive", "respawn_ticks", "drops", "examine", "slayer", "boss", "appearance", "regenerate"}
BOSS_KEYS = {"throw_every", "throw_delay", "throw_radius", "throw_damage", "enrage_below", "enrage_speed"}
COLOR_PATTERN = re.compile(r"^#[0-9a-fA-F]{6}$")
# Must match what game/scripts/world/creature_model.gd knows how to build.
MODEL_FEATURES = {
    "kaykit": set(),
    "quadruped": {"ears", "round_ears", "long_snout", "tusks", "bristles", "tail", "lizard", "many_heads"},
    "humanoid": {"hood", "helmet", "glowing_eyes", "ghostly", "bare_legs", "one_eye", "snakes", "green_skin"},
    "bird": {"ear_tufts", "woman_face"},
}


def load_content(content_dir: Path = CONTENT_DIR) -> dict:
    return {name: json.loads((content_dir / f"{name}.json").read_text()) for name in FILES}


def validate(content: dict) -> list[str]:
    errors: list[str] = []
    items = content.get("items", {})
    monsters = content.get("monsters", {})
    drops = content.get("drops", {})

    for item_id, item in items.items():
        _check_item(f"items.{item_id}", item_id, item, items, errors)
    for monster_id, monster in monsters.items():
        _check_monster(f"monsters.{monster_id}", monster_id, monster, items, drops, errors)
    for table_id, table in drops.items():
        _check_drop_table(f"drops.{table_id}", table, items, errors)
    for venator_id, venator in content.get("slayer", {}).get("venatores", {}).items():
        _check_venator(f"slayer.venatores.{venator_id}", venator, monsters, items, errors)
    _check_slayer_rewards(content.get("slayer", {}).get("rewards", {}), errors)
    _check_skilling(content.get("skilling", {}), items, errors)
    _check_pietas(content.get("pietas", {}), items, errors)
    quests = content.get("quests", {})
    _check_quests(quests, items, monsters, errors)
    for kind, entries in content.get("skilling", {}).get("recipes", {}).items():
        for i, recipe in enumerate(entries):
            if "requires_quest" in recipe and recipe["requires_quest"] not in quests.get("quests", {}):
                errors.append(f"skilling.recipes.{kind}[{i}].requires_quest: unknown quest {recipe['requires_quest']!r}")
            unlocks = content.get("slayer", {}).get("rewards", {}).get("unlocks", {})
            if "requires_unlock" in recipe and recipe["requires_unlock"] not in unlocks:
                errors.append(f"skilling.recipes.{kind}[{i}].requires_unlock: unknown Slayer unlock {recipe['requires_unlock']!r}")
    _check_thieving(content.get("thieving", {}), items, errors)
    _check_strongboxes(content.get("thieving", {}).get("strongboxes", {}), set(content.get("drops", {})), errors)
    _check_athletics(content.get("athletics", {}), errors)
    _check_hunter(content.get("hunter", {}), items, errors)
    _check_farming(content.get("farming", {}), items, errors)
    _check_mercatura(content.get("mercatura", {}), items, set(content.get("shops", {})), errors)
    _check_arena(content.get("arena", {}), items, monsters, set(content.get("shops", {})), errors)
    _check_circus(content.get("circus", {}), items, errors)
    _check_tasks(content.get("tasks", {}), items, monsters, set(quests.get("quests", {})), errors)
    _check_villa(content.get("villa", {}), items, quests, content.get("farming", {}), errors)
    _check_collection(content.get("collection", {}), items, errors)
    _check_pets(content.get("pets", {}), items, monsters, errors)
    for shop_id, shop in content.get("shops", {}).items():
        _check_shop(f"shops.{shop_id}", shop, items, errors)
        if "requires_quest" in shop and shop["requires_quest"] not in quests.get("quests", {}):
            errors.append(f"shops.{shop_id}.requires_quest: unknown quest {shop['requires_quest']!r}")
        for i, offer in enumerate(shop.get("offers", [])):
            if "requires_quest" in offer and offer["requires_quest"] not in quests.get("quests", {}):
                errors.append(f"shops.{shop_id}.offers[{i}].requires_quest: unknown quest {offer['requires_quest']!r}")
    player = content.get("player", {})
    _check_keys("player", player, {"starting_kit"}, {"starting_kit"}, errors)
    kit = player.get("starting_kit", [])
    for i, entry in enumerate(kit):
        _check_drop(f"player.starting_kit[{i}]", entry, items, errors, nothing_allowed=False, multiples_allowed=True)
    slots = sum(1 if items.get(e.get("item"), {}).get("stackable") else e.get("quantity", 1) for e in kit if _is_int(e.get("quantity", 1)))
    if slots > 28:
        errors.append(f"player.starting_kit: needs {slots} inventory slots, more than 28")
    return errors


def _check_item(where, item_id, item, items, errors):
    _check_id(where, item_id, errors)
    _check_keys(where, item, ITEM_KEYS, {"name", "value", "examine"}, errors)
    _check_type(where, "name", item.get("name"), str, errors)
    _check_type(where, "examine", item.get("examine"), str, errors)
    _check_int(where, "value", item.get("value"), 0, errors)
    if "stackable" in item:
        _check_type(where, "stackable", item["stackable"], bool, errors)
    if "heals" in item:
        _check_int(where, "heals", item["heals"], 1, errors)
    if "remedy" in item:
        remedy = item["remedy"]
        if "heals" in remedy:
            _check_keys(f"{where}.remedy", remedy, {"heals"}, {"heals"}, errors)
            _check_int(f"{where}.remedy", "heals", remedy["heals"], 1, errors)
        else:
            _check_keys(f"{where}.remedy", remedy, {"skill", "flat", "percent"}, {"skill", "flat", "percent"}, errors)
            if remedy.get("skill") not in SKILLS:
                errors.append(f"{where}.remedy.skill: unknown skill {remedy.get('skill')!r}")
            _check_int(f"{where}.remedy", "flat", remedy.get("flat"), 0, errors, 20)
            _check_number(f"{where}.remedy", "percent", remedy.get("percent"), 0, 0.5, errors)
    if "throwable" in item:
        throwable = item["throwable"]
        _check_keys(f"{where}.throwable", throwable, {"range", "damage", "sear_ticks"}, {"range", "damage", "sear_ticks"}, errors)
        _check_number(f"{where}.throwable", "range", throwable.get("range"), 1, 15, errors)
        _check_int(f"{where}.throwable", "sear_ticks", throwable.get("sear_ticks"), 1, errors)
        damage = throwable.get("damage")
        if not (isinstance(damage, list) and len(damage) == 2 and all(_is_int(d) and d >= 0 for d in damage) and damage[0] <= damage[1]):
            errors.append(f"{where}.throwable.damage: expected [min, max]")
    if "pet" in item:
        look = item["pet"]
        _check_keys(f"{where}.pet", look, {"model", "color", "accent", "size", "features"}, {"model", "color", "size"}, errors)
        if look.get("model") not in MODEL_FEATURES or look.get("model") == "kaykit":
            errors.append(f"{where}.pet.model: must be one of {sorted(set(MODEL_FEATURES) - {'kaykit'})}")
        else:
            for feature in look.get("features", []):
                if feature not in MODEL_FEATURES[look["model"]]:
                    errors.append(f"{where}.pet.features: {look['model']} has no feature {feature!r}")
        for key in ("color", "accent"):
            if key in look and not COLOR_PATTERN.match(str(look[key])):
                errors.append(f"{where}.pet.{key}: expected a #rrggbb colour")
    if "tool" in item:
        _check_type(where, "tool", item["tool"], str, errors)
        _check_int(where, "tool_tier", item.get("tool_tier"), 1, errors)
    if "requirements" in item:
        _check_levels(f"{where}.requirements", item["requirements"], SKILLS, errors)
    if "equip" in item:
        equip = item["equip"]
        _check_keys(f"{where}.equip", equip, {"slot", "bonuses", "attack_speed", "style", "range", "ammo", "ammo_type", "curse", "wards", "slayer_boost", "special"}, {"slot", "bonuses"}, errors)
        if "special" in equip:
            special = equip["special"]
            _check_keys(f"{where}.equip.special", special, {"name", "cost", "effect"}, {"name", "cost", "effect"}, errors)
            _check_int(f"{where}.equip.special", "cost", special.get("cost"), 5, errors, 100)
            if special.get("effect") not in SPECIAL_EFFECTS:
                errors.append(f"{where}.equip.special.effect: must be one of {sorted(SPECIAL_EFFECTS)}")
            if equip.get("slot") != "weapon":
                errors.append(f"{where}.equip.special: only weapons have specials")
        for ward in equip.get("wards", []):
            if ward not in items:
                errors.append(f"{where}.equip.wards: unknown item {ward!r}")
        if "slayer_boost" in equip:
            _check_number(f"{where}.equip", "slayer_boost", equip["slayer_boost"], 0, 0.5, errors)
        if equip.get("slot") not in EQUIP_SLOTS:
            errors.append(f"{where}.equip.slot: unknown slot {equip.get('slot')!r}")
        bonuses = equip.get("bonuses", {})
        for key in sorted(set(bonuses) - BONUSES):
            errors.append(f"{where}.equip.bonuses.{key}: unknown bonus (expected some of {sorted(BONUSES)})")
        for key, value in bonuses.items():
            _check_int(f"{where}.equip.bonuses", key, value, -100, errors)
        if equip.get("slot") == "weapon":
            _check_int(f"{where}.equip", "attack_speed", equip.get("attack_speed"), 1, errors)
        elif "attack_speed" in equip:
            errors.append(f"{where}.equip.attack_speed: only weapons have an attack speed")
        if equip.get("style", "melee") not in ("melee", "ranged", "ritus"):
            errors.append(f"{where}.equip.style: must be melee, ranged, or ritus")
        if equip.get("style") in ("ranged", "ritus"):
            _check_number(f"{where}.equip", "range", equip.get("range"), 1, 20, errors)
            if equip.get("ammo") not in AMMO_TYPES:
                errors.append(f"{where}.equip.ammo: must be one of {sorted(AMMO_TYPES)}")
        elif "range" in equip or "ammo" in equip:
            errors.append(f"{where}.equip: only ranged and ritus weapons have range and ammo")
        if equip.get("style") == "ritus" and equip.get("ammo") != "tablet":
            errors.append(f"{where}.equip.ammo: ritus weapons use tablets")
        if (equip.get("ammo_type") == "tablet") != ("curse" in equip):
            errors.append(f"{where}.equip.curse: tablets, and only tablets, have a curse")
        elif "curse" in equip and equip["curse"] not in CURSES:
            errors.append(f"{where}.equip.curse: must be one of {sorted(CURSES)}")
        if equip.get("slot") == "ammo":
            if equip.get("ammo_type") not in AMMO_TYPES:
                errors.append(f"{where}.equip.ammo_type: must be one of {sorted(AMMO_TYPES)}")
            if not item.get("stackable"):
                errors.append(f"{where}: ammunition must be stackable")
        elif "ammo_type" in equip:
            errors.append(f"{where}.equip.ammo_type: only ammo-slot items have an ammo type")


def _check_boss(where, boss, attack_speed, errors):
    _check_keys(where, boss, BOSS_KEYS | {"throw_kind"}, BOSS_KEYS, errors)
    if boss.get("throw_kind", "spear") not in ("spear", "venom", "boulder"):
        errors.append(f"{where}.throw_kind: must be spear, venom or boulder")
    _check_int(where, "throw_every", boss.get("throw_every"), 2, errors)
    _check_int(where, "throw_delay", boss.get("throw_delay"), 1, errors)
    _check_int(where, "enrage_speed", boss.get("enrage_speed"), 1, errors)
    radius = boss.get("throw_radius")
    if not isinstance(radius, (int, float)) or isinstance(radius, bool) or radius <= 0:
        errors.append(f"{where}.throw_radius: expected a positive number")
    below = boss.get("enrage_below")
    if not isinstance(below, (int, float)) or isinstance(below, bool) or not 0 < below < 1:
        errors.append(f"{where}.enrage_below: expected a fraction between 0 and 1")
    damage = boss.get("throw_damage")
    if not (isinstance(damage, list) and len(damage) == 2 and all(isinstance(x, int) and not isinstance(x, bool) for x in damage)
            and 0 <= damage[0] <= damage[1]):
        errors.append(f"{where}.throw_damage: expected [min, max] integers")
    if isinstance(attack_speed, int) and isinstance(boss.get("enrage_speed"), int) and boss["enrage_speed"] >= attack_speed:
        errors.append(f"{where}.enrage_speed: must be faster (lower) than attack_speed")


def _check_monster(where, monster_id, monster, items, drops, errors):
    _check_id(where, monster_id, errors)
    _check_keys(where, monster, MONSTER_KEYS, MONSTER_KEYS - {"plural", "slayer", "boss", "regenerate"}, errors)
    if "regenerate" in monster:
        _check_keys(f"{where}.regenerate", monster["regenerate"], {"amount"}, {"amount"}, errors)
        _check_int(f"{where}.regenerate", "amount", monster["regenerate"].get("amount"), 1, errors, 10)
    if "boss" in monster:
        _check_boss(f"{where}.boss", monster["boss"], monster.get("attack_speed"), errors)
    _check_type(where, "name", monster.get("name"), str, errors)
    _check_type(where, "examine", monster.get("examine"), str, errors)
    _check_int(where, "level", monster.get("level"), 1, errors)
    _check_int(where, "attack_speed", monster.get("attack_speed"), 1, errors)
    _check_int(where, "respawn_ticks", monster.get("respawn_ticks"), 1, errors)
    _check_type(where, "aggressive", monster.get("aggressive"), bool, errors)
    stats = monster.get("stats", {})
    if set(stats) != COMBAT_STATS:
        errors.append(f"{where}.stats: expected keys {sorted(COMBAT_STATS)}")
    _check_levels(f"{where}.stats", stats, COMBAT_STATS, errors)
    appearance = monster.get("appearance", {})
    _check_keys(f"{where}.appearance", appearance, {"model", "color", "accent", "size", "features", "scene", "weapon", "shield", "attack"}, {"model", "color", "size"}, errors)
    if appearance.get("model") == "kaykit":
        for key in ("scene", "weapon", "shield"):
            path = appearance.get(key, "")
            ext = ".glb" if key == "scene" else ".gltf"
            if key == "scene" and not path:
                errors.append(f"{where}.appearance.scene: kaykit models need a scene")
            elif path and not path.startswith("proc:") and not (CONTENT_DIR.parent / "assets" / "kaykit" / (path + ext)).exists():
                errors.append(f"{where}.appearance.{key}: no asset at assets/kaykit/{path}{ext}")
    if appearance.get("model") not in MODEL_FEATURES:
        errors.append(f"{where}.appearance.model: must be one of {sorted(MODEL_FEATURES)}")
    for key in ("color", "accent"):
        if key in appearance and not COLOR_PATTERN.match(str(appearance[key])):
            errors.append(f"{where}.appearance.{key}: expected #rrggbb")
    size = appearance.get("size")
    if not isinstance(size, (int, float)) or isinstance(size, bool) or not 0.1 <= size <= 5:
        errors.append(f"{where}.appearance.size: expected a number in 0.1..5")
    allowed = MODEL_FEATURES.get(appearance.get("model"), set())
    for feature in appearance.get("features", []):
        if feature not in allowed:
            errors.append(f"{where}.appearance.features: {feature!r} isn't a {appearance.get('model')} feature")
    if monster.get("drops") not in drops:
        errors.append(f"{where}.drops: unknown drop table {monster.get('drops')!r}")
    if "slayer" in monster:
        slayer = monster["slayer"]
        _check_keys(f"{where}.slayer", slayer, {"level", "ward_item", "ward_carried", "unwarded_effect"}, {"level"}, errors)
        _check_int(f"{where}.slayer", "level", slayer.get("level"), 1, errors, 99)
        if "ward_item" in slayer:
            if slayer["ward_item"] not in items:
                errors.append(f"{where}.slayer.ward_item: unknown item {slayer['ward_item']!r}")
            if slayer.get("unwarded_effect") not in UNWARDED_EFFECTS:
                errors.append(f"{where}.slayer.unwarded_effect: must be one of {sorted(UNWARDED_EFFECTS)}")


def _check_drop_table(where, table, items, errors):
    _check_keys(where, table, {"always", "rolls", "table"}, {"always", "rolls", "table"}, errors)
    _check_int(where, "rolls", table.get("rolls"), 0, errors)
    for i, entry in enumerate(table.get("always", [])):
        _check_drop(f"{where}.always[{i}]", entry, items, errors, nothing_allowed=False)
        if "weight" in entry:
            errors.append(f"{where}.always[{i}]: guaranteed drops have no weight")
    if table.get("rolls", 0) > 0 and not table.get("table"):
        errors.append(f"{where}.table: rolls > 0 but the table is empty")
    for i, entry in enumerate(table.get("table", [])):
        _check_drop(f"{where}.table[{i}]", entry, items, errors, nothing_allowed=True)
        _check_int(f"{where}.table[{i}]", "weight", entry.get("weight"), 1, errors)


def _check_drop(where, entry, items, errors, nothing_allowed, multiples_allowed=False):
    item_id = entry.get("item")
    if item_id is None:
        if not nothing_allowed:
            errors.append(f"{where}.item: required")
        return
    if item_id not in items:
        errors.append(f"{where}.item: unknown item {item_id!r}")
        return
    quantity = entry.get("quantity")
    if isinstance(quantity, list):
        if len(quantity) != 2 or not all(_is_int(q) and q >= 1 for q in quantity) or quantity[0] > quantity[1]:
            errors.append(f"{where}.quantity: expected [min, max] with 1 <= min <= max")
        elif quantity[1] > 1 and not items[item_id].get("stackable") and not multiples_allowed:
            errors.append(f"{where}.quantity: {item_id} isn't stackable, so drop at most 1")
    else:
        _check_int(where, "quantity", quantity, 1, errors)
        if _is_int(quantity) and quantity > 1 and not items[item_id].get("stackable") and not multiples_allowed:
            errors.append(f"{where}.quantity: {item_id} isn't stackable, so drop at most 1")


def _check_arena(arena, items, monsters, shops, errors):
    _check_keys("arena", arena, {"lanista", "net", "capture_below", "contracts"}, {"lanista", "net", "capture_below", "contracts"}, errors)
    if arena.get("lanista") not in shops:
        errors.append(f"arena.lanista: unknown shop {arena.get('lanista')!r}")
    if arena.get("net") not in items:
        errors.append(f"arena.net: unknown item {arena.get('net')!r}")
    _check_number("arena", "capture_below", arena.get("capture_below"), 0.05, 0.9, errors)
    for contract_id, contract in arena.get("contracts", {}).items():
        where = f"arena.contracts.{contract_id}"
        _check_id(where, contract_id, errors)
        _check_keys(where, contract, {"name", "monster", "hunter", "count", "coins", "xp"}, {"name", "monster", "hunter", "count", "coins", "xp"}, errors)
        _check_type(where, "name", contract.get("name"), str, errors)
        if contract.get("monster") not in monsters:
            errors.append(f"{where}.monster: unknown monster {contract.get('monster')!r}")
        _check_int(where, "hunter", contract.get("hunter"), 1, errors, 99)
        for key in ("count", "coins", "xp"):
            _check_int(where, key, contract.get(key), 1, errors)
CIRCUS_KEYS = {"name", "level", "fee", "laps", "speed", "speed_per_level", "countdown_ticks", "time_limit_ticks", "lap_xp",
               "placing_xp", "prizes", "trophy", "rivals"}


def _check_circus(circus, items, errors):
    _check_keys("circus", circus, CIRCUS_KEYS, CIRCUS_KEYS, errors)
    _check_type("circus", "name", circus.get("name"), str, errors)
    _check_int("circus", "level", circus.get("level"), 1, errors, 99)
    for key in ("fee", "laps", "countdown_ticks", "time_limit_ticks", "lap_xp"):
        _check_int("circus", key, circus.get(key), 1, errors)
    _check_number("circus", "speed", circus.get("speed"), 1.0, 30.0, errors)
    _check_number("circus", "speed_per_level", circus.get("speed_per_level"), 0.0, 0.05, errors)
    if circus.get("trophy") not in items:
        errors.append(f"circus.trophy: unknown item {circus.get('trophy')!r}")
    rivals = circus.get("rivals", [])
    if not rivals:
        errors.append("circus.rivals: at least one rival required")
    for i, rival in enumerate(rivals):
        where = f"circus.rivals[{i}]"
        _check_keys(where, rival, {"name", "color", "speed"}, {"name", "color", "speed"}, errors)
        _check_type(where, "name", rival.get("name"), str, errors)
        if not (isinstance(rival.get("color"), str) and re.fullmatch(r"#[0-9a-fA-F]{6}", rival["color"])):
            errors.append(f"{where}.color: expected #rrggbb")
        _check_number(where, "speed", rival.get("speed"), 1.0, 30.0, errors)
    for key in ("placing_xp", "prizes"):
        values = circus.get(key)
        if not (isinstance(values, list) and len(values) == len(rivals) + 1 and all(isinstance(v, int) and v >= 0 for v in values)):
            errors.append(f"circus.{key}: expected one non-negative int per place ({len(rivals) + 1})")


TASK_FIELDS = {"obtain": {"item"}, "kill": {"monster"}, "quest": {"quest"}, "level": {"skill", "level"}, "visit": {"area"}}


def _check_tasks(tasks, items, monsters, quests, errors):
    _check_keys("tasks", tasks, {"regions"}, {"regions"}, errors)
    for region_id, region in tasks.get("regions", {}).items():
        where = f"tasks.regions.{region_id}"
        _check_id(where, region_id, errors)
        _check_keys(where, region, {"name", "reward", "tasks"}, {"name", "reward", "tasks"}, errors)
        _check_int(where, "reward", region.get("reward"), 1, errors)
        seen = set()
        for i, task in enumerate(region.get("tasks", [])):
            task_where = f"{where}.tasks[{i}]"
            kind = task.get("kind")
            if kind not in TASK_FIELDS:
                errors.append(f"{task_where}.kind: must be one of {sorted(TASK_FIELDS)}")
                continue
            _check_keys(task_where, task, {"id", "kind", "text"} | TASK_FIELDS[kind], {"id", "kind", "text"} | TASK_FIELDS[kind], errors)
            if task.get("id") in seen:
                errors.append(f"{task_where}.id: duplicate {task.get('id')!r}")
            seen.add(task.get("id"))
            if kind == "obtain" and task.get("item") not in items:
                errors.append(f"{task_where}.item: unknown item {task.get('item')!r}")
            if kind == "kill" and task.get("monster") not in monsters:
                errors.append(f"{task_where}.monster: unknown monster {task.get('monster')!r}")
            if kind == "quest" and task.get("quest") not in quests:
                errors.append(f"{task_where}.quest: unknown quest {task.get('quest')!r}")
            if kind == "level":
                if task.get("skill") not in SKILLS:
                    errors.append(f"{task_where}.skill: unknown skill {task.get('skill')!r}")
                _check_int(task_where, "level", task.get("level"), 2, errors, 99)
            if kind == "visit":
                area = task.get("area")
                if not (isinstance(area, list) and len(area) == 4 and all(isinstance(a, (int, float)) for a in area) and area[2] > 0 and area[3] > 0):
                    errors.append(f"{task_where}.area: expected [x, z, width, depth]")


def _check_slayer_rewards(rewards, errors):
    where = "slayer.rewards"
    _check_keys(where, rewards, {"cancel", "block", "max_blocks", "streaks", "unlocks"}, {"cancel", "block", "max_blocks", "streaks", "unlocks"}, errors)
    for key in ("cancel", "block", "max_blocks"):
        _check_int(where, key, rewards.get(key), 1, errors)
    for i, streak in enumerate(rewards.get("streaks", [])):
        _check_keys(f"{where}.streaks[{i}]", streak, {"every", "multiplier"}, {"every", "multiplier"}, errors)
        _check_int(f"{where}.streaks[{i}]", "every", streak.get("every"), 2, errors)
        _check_int(f"{where}.streaks[{i}]", "multiplier", streak.get("multiplier"), 2, errors)
    everies = [s.get("every", 0) for s in rewards.get("streaks", [])]
    if everies != sorted(everies, reverse=True):
        errors.append(f"{where}.streaks: list the longest streak first")
    for unlock_id, unlock in rewards.get("unlocks", {}).items():
        _check_id(f"{where}.unlocks.{unlock_id}", unlock_id, errors)
        _check_keys(f"{where}.unlocks.{unlock_id}", unlock, {"name", "cost", "teaches"}, {"name", "cost", "teaches"}, errors)
        _check_int(f"{where}.unlocks.{unlock_id}", "cost", unlock.get("cost"), 1, errors)


def _check_venator(where, venator, monsters, items, errors):
    _check_type(where, "name", venator.get("name"), str, errors)
    _check_int(where, "combat_level", venator.get("combat_level"), 1, errors)
    _check_int(where, "points_per_task", venator.get("points_per_task"), 0, errors)
    _check_keys(where, venator, {"name", "location", "combat_level", "points_per_task", "tasks"}, {"name", "combat_level", "points_per_task", "tasks"}, errors)
    if not venator.get("tasks"):
        errors.append(f"{where}.tasks: at least one task required")
    for i, task in enumerate(venator.get("tasks", [])):
        task_where = f"{where}.tasks[{i}]"
        _check_keys(task_where, task, {"monster", "weight", "amount", "slayer_level", "combat_level"}, {"monster", "weight", "amount"}, errors)
        if task.get("monster") not in monsters:
            errors.append(f"{task_where}.monster: unknown monster {task.get('monster')!r}")
        _check_int(task_where, "weight", task.get("weight"), 1, errors)
        amount = task.get("amount")
        if not (isinstance(amount, list) and len(amount) == 2 and all(_is_int(a) and a >= 1 for a in amount) and amount[0] <= amount[1]):
            errors.append(f"{task_where}.amount: expected [min, max] with 1 <= min <= max")
        for key in ("slayer_level", "combat_level"):
            if key in task:
                _check_int(task_where, key, task[key], 1, errors, 126)
        monster = monsters.get(task.get("monster"), {})
        needed = monster.get("slayer", {}).get("level", 1)
        if task.get("slayer_level", 1) < needed:
            errors.append(f"{task_where}.slayer_level: {task.get('monster')} needs Slayer {needed}")


def _check_skilling(skilling, items, errors):
    sections = {"rocks", "trees", "fishing_spots", "recipes"}
    _check_keys("skilling", skilling, sections, sections, errors)
    for rock_id, rock in skilling.get("rocks", {}).items():
        where = f"skilling.rocks.{rock_id}"
        _check_id(where, rock_id, errors)
        _check_keys(where, rock, ROCK_KEYS, ROCK_KEYS, errors)
        if rock.get("ore") not in items:
            errors.append(f"{where}.ore: unknown item {rock.get('ore')!r}")
        _check_int(where, "level", rock.get("level"), 1, errors, 99)
        _check_number(where, "xp", rock.get("xp"), 0.1, 10000, errors)
        _check_number(where, "difficulty", rock.get("difficulty"), 0, 1, errors)
        _check_int(where, "respawn_ticks", rock.get("respawn_ticks"), 1, errors)
        if not COLOR_PATTERN.match(str(rock.get("color", ""))):
            errors.append(f"{where}.color: expected #rrggbb")
    tools = {item.get("tool") for item in items.values() if "tool" in item}
    for tree_id, tree in skilling.get("trees", {}).items():
        where = f"skilling.trees.{tree_id}"
        _check_id(where, tree_id, errors)
        _check_keys(where, tree, TREE_KEYS, TREE_KEYS, errors)
        if tree.get("log") not in items:
            errors.append(f"{where}.log: unknown item {tree.get('log')!r}")
        _check_int(where, "level", tree.get("level"), 1, errors, 99)
        _check_number(where, "xp", tree.get("xp"), 0.1, 10000, errors)
        _check_number(where, "difficulty", tree.get("difficulty"), 0, 1, errors)
        _check_number(where, "fell_chance", tree.get("fell_chance"), 0.01, 1, errors)
        _check_int(where, "respawn_ticks", tree.get("respawn_ticks"), 1, errors)
    for spot_id, spot in skilling.get("fishing_spots", {}).items():
        where = f"skilling.fishing_spots.{spot_id}"
        _check_id(where, spot_id, errors)
        _check_keys(where, spot, SPOT_KEYS, SPOT_KEYS, errors)
        if spot.get("tool") not in tools:
            errors.append(f"{where}.tool: no item provides tool {spot.get('tool')!r}")
        if not spot.get("catches"):
            errors.append(f"{where}.catches: at least one catch required")
        for i, catch in enumerate(spot.get("catches", [])):
            catch_where = f"{where}.catches[{i}]"
            _check_keys(catch_where, catch, CATCH_KEYS, CATCH_KEYS, errors)
            if catch.get("fish") not in items:
                errors.append(f"{catch_where}.fish: unknown item {catch.get('fish')!r}")
            _check_int(catch_where, "level", catch.get("level"), 1, errors, 99)
            _check_number(catch_where, "xp", catch.get("xp"), 0.1, 10000, errors)
    recipes = skilling.get("recipes", {})
    for kind in sorted(set(recipes) - RECIPE_KINDS):
        errors.append(f"skilling.recipes.{kind}: unknown recipe kind")
    for kind, entries in recipes.items():
        seen = set()
        for i, recipe in enumerate(entries):
            where = f"skilling.recipes.{kind}[{i}]"
            _check_keys(where, recipe, RECIPE_KEYS, {"id", "inputs", "output", "level", "xp"}, errors)
            if recipe.get("id") in seen:
                errors.append(f"{where}.id: duplicate {recipe.get('id')!r}")
            seen.add(recipe.get("id"))
            if not recipe.get("inputs"):
                errors.append(f"{where}.inputs: at least one input required")
            for j, entry in enumerate(recipe.get("inputs", [])):
                _check_drop(f"{where}.inputs[{j}]", entry, items, errors, nothing_allowed=False, multiples_allowed=True)
            for key in ("output", "burnt"):
                if key in recipe and recipe[key] not in items:
                    errors.append(f"{where}.{key}: unknown item {recipe[key]!r}")
            _check_int(where, "level", recipe.get("level"), 1, errors, 99)
            _check_number(where, "xp", recipe.get("xp"), 0.1, 10000, errors)
            if "quantity" in recipe:
                _check_int(where, "quantity", recipe["quantity"], 1, errors)
                if recipe["quantity"] > 1 and not items.get(recipe.get("output"), {}).get("stackable"):
                    errors.append(f"{where}.quantity: only stackable outputs can be made in batches")
            if "success" in recipe:
                _check_number(where, "success", recipe["success"], 0.01, 1, errors)
            if "tool" in recipe and recipe["tool"] not in tools:
                errors.append(f"{where}.tool: no item provides tool {recipe['tool']!r}")
            if ("burnt" in recipe) != ("stop_burning" in recipe):
                errors.append(f"{where}: burnt and stop_burning go together")
            if "stop_burning" in recipe:
                _check_int(where, "stop_burning", recipe["stop_burning"], recipe.get("level", 1), errors, 99)


BOOSTS = {"strength", "defence", "ranged", "ritus", "run_speed", "withering_damage", "binding_chance"}
ALTAR_KINDS = {"heavenly", "underworld"}


def _check_pietas(pietas, items, errors):
    _check_keys("pietas", pietas, {"blessings", "offerings", "altars"}, {"blessings", "offerings", "altars"}, errors)
    if set(pietas.get("altars", {})) != ALTAR_KINDS:
        errors.append(f"pietas.altars: expected {sorted(ALTAR_KINDS)}")
    for blessing_id, blessing in pietas.get("blessings", {}).items():
        where = f"pietas.blessings.{blessing_id}"
        _check_id(where, blessing_id, errors)
        _check_keys(where, blessing, {"name", "god", "family", "aspect", "level", "drain_ticks", "boost"}, {"name", "god", "family", "aspect", "level", "drain_ticks", "boost"}, errors)
        if blessing.get("family") not in ALTAR_KINDS:
            errors.append(f"{where}.family: must be one of {sorted(ALTAR_KINDS)}")
        _check_int(where, "level", blessing.get("level"), 1, errors, 99)
        _check_int(where, "drain_ticks", blessing.get("drain_ticks"), 1, errors)
        for key, value in blessing.get("boost", {}).items():
            if key not in BOOSTS:
                errors.append(f"{where}.boost.{key}: unknown boost")
            _check_number(f"{where}.boost", key, value, 0.01, 10, errors)
    for item_id, offering in pietas.get("offerings", {}).items():
        where = f"pietas.offerings.{item_id}"
        if item_id not in items:
            errors.append(f"{where}: unknown item")
        _check_keys(where, offering, {"xp", "altar"}, {"xp", "altar"}, errors)
        _check_number(where, "xp", offering.get("xp"), 0.1, 10000, errors)
        if offering.get("altar") not in ALTAR_KINDS:
            errors.append(f"{where}.altar: must be one of {sorted(ALTAR_KINDS)}")


def _check_shop(where, shop, items, errors):
    _check_keys(where, shop, {"name", "offers", "requires_quest", "buys"}, {"name", "offers"}, errors)
    if "buys" in shop:
        buys = shop["buys"]
        _check_keys(f"{where}.buys", buys, {"items", "rate"}, {"items", "rate"}, errors)
        _check_number(f"{where}.buys", "rate", buys.get("rate"), 0.05, 1.0, errors)
        wanted = buys.get("items")
        if wanted != "*":
            if not isinstance(wanted, list) or not wanted:
                errors.append(f"{where}.buys.items: expected \"*\" or a list of items")
            else:
                for item_id in wanted:
                    if item_id not in items:
                        errors.append(f"{where}.buys.items: unknown item {item_id!r}")
    for i, offer in enumerate(shop.get("offers", [])):
        _check_keys(f"{where}.offers[{i}]", offer, {"item", "price", "quantity", "requires_quest"}, {"item", "price"}, errors)
        if offer.get("item") not in items:
            errors.append(f"{where}.offers[{i}].item: unknown item {offer.get('item')!r}")
        _check_int(f"{where}.offers[{i}]", "price", offer.get("price"), 1, errors)
        if "quantity" in offer:
            _check_int(f"{where}.offers[{i}]", "quantity", offer["quantity"], 1, errors)
            if offer["quantity"] > 1 and not items.get(offer.get("item"), {}).get("stackable"):
                errors.append(f"{where}.offers[{i}].quantity: only stackable items come in bundles")


QUEST_KEYS = {"name", "summary", "giver", "requirements", "start", "start_items", "steps", "complete", "rewards"}
STEP_KINDS = {"attack": {"tag", "combat", "count"}, "kill": {"monster", "count"}, "talk": {"npc"},
              "deliver": {"npc", "items"}, "reach": {"at", "radius"}}
COMBAT_KINDS = {"melee", "ranged", "ritus"}
REWARD_KEYS = {"xp", "items", "rank", "title", "unlocks"}


def _check_quests(content, items, monsters, errors):
    _check_keys("quests", content, {"npcs", "quests"}, {"npcs", "quests"}, errors)
    npcs = content.get("npcs", {})
    quests = content.get("quests", {})
    for npc_id, npc in npcs.items():
        where = f"quests.npcs.{npc_id}"
        _check_id(where, npc_id, errors)
        _check_keys(where, npc, {"name", "examine", "idle"}, {"name", "examine", "idle"}, errors)
        _check_lines(where, "idle", npc.get("idle"), errors)
    for quest_id, quest in quests.items():
        where = f"quests.quests.{quest_id}"
        _check_id(where, quest_id, errors)
        _check_keys(where, quest, QUEST_KEYS, QUEST_KEYS - {"start_items"}, errors)
        if quest.get("giver") not in npcs:
            errors.append(f"{where}.giver: unknown npc {quest.get('giver')!r}")
        requirements = quest.get("requirements", {})
        _check_keys(f"{where}.requirements", requirements, {"skills", "quests"}, set(), errors)
        for skill, level in requirements.get("skills", {}).items():
            if skill not in SKILLS:
                errors.append(f"{where}.requirements.skills: unknown skill {skill!r}")
            _check_int(f"{where}.requirements.skills", skill, level, 1, errors, 99)
        for needed in requirements.get("quests", []):
            if needed not in quests or needed == quest_id:
                errors.append(f"{where}.requirements.quests: unknown quest {needed!r}")
        for key in ("start", "complete"):
            _check_lines(where, key, quest.get(key), errors)
        for i, entry in enumerate(quest.get("start_items", [])):
            _check_drop(f"{where}.start_items[{i}]", entry, items, errors, nothing_allowed=False, multiples_allowed=True)
        steps = quest.get("steps", [])
        if not steps:
            errors.append(f"{where}.steps: at least one step required")
        for i, step in enumerate(steps):
            step_where = f"{where}.steps[{i}]"
            kind = step.get("kind")
            if kind not in STEP_KINDS:
                errors.append(f"{step_where}.kind: must be one of {sorted(STEP_KINDS)}")
                continue
            _check_keys(step_where, step, {"kind", "log", "remind", "grants", "say"} | STEP_KINDS[kind], {"kind", "log", "remind"} | STEP_KINDS[kind], errors)
            for j, entry in enumerate(step.get("grants", [])):
                _check_drop(f"{step_where}.grants[{j}]", entry, items, errors, nothing_allowed=False, multiples_allowed=True)
            if "count" in step:
                _check_int(step_where, "count", step["count"], 1, errors)
            if kind == "attack" and step.get("combat") not in COMBAT_KINDS:
                errors.append(f"{step_where}.combat: must be one of {sorted(COMBAT_KINDS)}")
            if kind == "kill" and step.get("monster") not in monsters:
                errors.append(f"{step_where}.monster: unknown monster {step.get('monster')!r}")
            if kind == "deliver":
                if not step.get("items"):
                    errors.append(f"{step_where}.items: at least one item required")
                for j, entry in enumerate(step.get("items", [])):
                    _check_drop(f"{step_where}.items[{j}]", entry, items, errors, nothing_allowed=False, multiples_allowed=True)
            if kind == "reach":
                at = step.get("at")
                if not (isinstance(at, list) and len(at) == 2 and all(isinstance(v, (int, float)) for v in at)):
                    errors.append(f"{step_where}.at: expected [x, z]")
                _check_number(step_where, "radius", step.get("radius"), 0.5, 100, errors)
            if kind in ("talk", "deliver") and step.get("npc") not in npcs:
                errors.append(f"{step_where}.npc: unknown npc {step.get('npc')!r}")
            if not isinstance(step.get("log"), str) or not step.get("log"):
                errors.append(f"{step_where}.log: expected text")
            if "say" in step and (kind not in ("talk", "deliver") or not isinstance(step["say"], list) or not step["say"]):
                errors.append(f"{step_where}.say: only talk and deliver steps speak, as a non-empty list of lines")
            if not isinstance(step.get("remind"), list):
                errors.append(f"{step_where}.remind: expected a list of lines")
        if steps and steps[-1].get("kind") not in ("talk", "deliver"):
            errors.append(f"{where}.steps: the last step must be talking to someone, to hand in the quest")
        rewards = quest.get("rewards", {})
        _check_keys(f"{where}.rewards", rewards, REWARD_KEYS, set(), errors)
        for skill, amount in rewards.get("xp", {}).items():
            if skill not in SKILLS:
                errors.append(f"{where}.rewards.xp: unknown skill {skill!r}")
            _check_number(f"{where}.rewards.xp", skill, amount, 1, 1_000_000, errors)
        for i, entry in enumerate(rewards.get("items", [])):
            _check_drop(f"{where}.rewards.items[{i}]", entry, items, errors, nothing_allowed=False, multiples_allowed=True)


STALL_KEYS = {"name", "level", "xp", "loot", "restock_ticks", "caught_chance", "model", "examine"}
MARK_KEYS = {"name", "level", "xp", "coins", "stun_ticks", "damage", "examine"}
STALL_MODELS = {"stall-red", "stall-green"}


STRONGBOX_KEYS = {"name", "level", "xp", "crack_ticks", "trap_chance", "damage", "relock_ticks", "drop_table", "examine"}


def _check_strongboxes(strongboxes, drop_tables, errors):
    for box_id, box in strongboxes.items():
        where = f"thieving.strongboxes.{box_id}"
        _check_id(where, box_id, errors)
        _check_keys(where, box, STRONGBOX_KEYS, STRONGBOX_KEYS, errors)
        _check_int(where, "level", box.get("level"), 1, errors, 99)
        _check_number(where, "xp", box.get("xp"), 0.1, 10000, errors)
        _check_int(where, "crack_ticks", box.get("crack_ticks"), 1, errors, 50)
        _check_int(where, "relock_ticks", box.get("relock_ticks"), 1, errors)
        _check_number(where, "trap_chance", box.get("trap_chance"), 0, 1, errors)
        pair = box.get("damage")
        if not (isinstance(pair, list) and len(pair) == 2 and all(_is_int(v) for v in pair) and 0 <= pair[0] <= pair[1]):
            errors.append(f"{where}.damage: expected [min, max] whole numbers")
        if box.get("drop_table") not in drop_tables:
            errors.append(f"{where}.drop_table: unknown drop table {box.get('drop_table')!r}")


def _check_thieving(thieving, items, errors):
    _check_keys("thieving", thieving, {"stalls", "marks", "strongboxes"}, {"stalls", "marks"}, errors)
    for stall_id, stall in thieving.get("stalls", {}).items():
        where = f"thieving.stalls.{stall_id}"
        _check_id(where, stall_id, errors)
        _check_keys(where, stall, STALL_KEYS, STALL_KEYS, errors)
        _check_int(where, "level", stall.get("level"), 1, errors, 99)
        _check_number(where, "xp", stall.get("xp"), 0.1, 10000, errors)
        _check_drop(f"{where}.loot", stall.get("loot", {}), items, errors, nothing_allowed=False, multiples_allowed=True)
        _check_int(where, "restock_ticks", stall.get("restock_ticks"), 1, errors)
        _check_number(where, "caught_chance", stall.get("caught_chance"), 0, 1, errors)
        if stall.get("model") not in STALL_MODELS:
            errors.append(f"{where}.model: must be one of {sorted(STALL_MODELS)}")
    for mark_id, mark in thieving.get("marks", {}).items():
        where = f"thieving.marks.{mark_id}"
        _check_id(where, mark_id, errors)
        _check_keys(where, mark, MARK_KEYS, MARK_KEYS, errors)
        _check_int(where, "level", mark.get("level"), 1, errors, 99)
        _check_number(where, "xp", mark.get("xp"), 0.1, 10000, errors)
        _check_int(where, "stun_ticks", mark.get("stun_ticks"), 1, errors, 50)
        for key in ("coins", "damage"):
            pair = mark.get(key)
            if not (isinstance(pair, list) and len(pair) == 2 and all(_is_int(v) for v in pair) and 0 <= pair[0] <= pair[1]):
                errors.append(f"{where}.{key}: expected [min, max] whole numbers")


OBSTACLE_KEYS = {"name", "verb", "kind", "level", "xp", "ticks", "fail_chance", "damage"}
OBSTACLE_KINDS = {"log", "wall", "rope", "hurdles"}


def _check_athletics(athletics, errors):
    _check_keys("athletics", athletics, {"courses"}, {"courses"}, errors)
    for course_id, course in athletics.get("courses", {}).items():
        where = f"athletics.courses.{course_id}"
        _check_id(where, course_id, errors)
        _check_keys(where, course, {"name", "lap_xp", "obstacles"}, {"name", "lap_xp", "obstacles"}, errors)
        _check_number(where, "lap_xp", course.get("lap_xp"), 0, 100000, errors)
        if not course.get("obstacles"):
            errors.append(f"{where}.obstacles: at least one obstacle required")
        for i, obstacle in enumerate(course.get("obstacles", [])):
            ow = f"{where}.obstacles[{i}]"
            _check_keys(ow, obstacle, OBSTACLE_KEYS, OBSTACLE_KEYS, errors)
            if obstacle.get("kind") not in OBSTACLE_KINDS:
                errors.append(f"{ow}.kind: must be one of {sorted(OBSTACLE_KINDS)}")
            _check_int(ow, "level", obstacle.get("level"), 1, errors, 99)
            _check_number(ow, "xp", obstacle.get("xp"), 0.1, 10000, errors)
            _check_int(ow, "ticks", obstacle.get("ticks"), 1, errors, 50)
            _check_number(ow, "fail_chance", obstacle.get("fail_chance"), 0, 0.9, errors)
            pair = obstacle.get("damage")
            if not (isinstance(pair, list) and len(pair) == 2 and all(_is_int(v) for v in pair) and 0 <= pair[0] <= pair[1]):
                errors.append(f"{ow}.damage: expected [min, max] whole numbers")


HUNT_SPOT_KEYS = {"name", "level", "xp", "catch_chance", "loot", "examine"}


def _check_hunter(hunter, items, errors):
    _check_keys("hunter", hunter, {"spots"}, {"spots"}, errors)
    for spot_id, spot in hunter.get("spots", {}).items():
        where = f"hunter.spots.{spot_id}"
        _check_id(where, spot_id, errors)
        _check_keys(where, spot, HUNT_SPOT_KEYS, HUNT_SPOT_KEYS, errors)
        _check_int(where, "level", spot.get("level"), 1, errors, 99)
        _check_number(where, "xp", spot.get("xp"), 0.1, 10000, errors)
        _check_number(where, "catch_chance", spot.get("catch_chance"), 0.01, 1, errors)
        if not spot.get("loot"):
            errors.append(f"{where}.loot: at least one item required")
        for i, entry in enumerate(spot.get("loot", [])):
            _check_drop(f"{where}.loot[{i}]", entry, items, errors, nothing_allowed=False, multiples_allowed=True)


PATCH_KEYS = {"name", "kind", "examine"}
CROP_KEYS = {"name", "kind", "seed", "level", "plant_xp", "harvest_xp", "produce", "yield", "stage_ticks", "stages", "color"}


def _check_farming(farming, items, errors):
    _check_keys("farming", farming, {"patches", "crops"}, {"patches", "crops"}, errors)
    kinds = set()
    for patch_id, patch in farming.get("patches", {}).items():
        where = f"farming.patches.{patch_id}"
        _check_id(where, patch_id, errors)
        _check_keys(where, patch, PATCH_KEYS, PATCH_KEYS, errors)
        kinds.add(patch.get("kind"))
    seeds = set()
    for crop_id, crop in farming.get("crops", {}).items():
        where = f"farming.crops.{crop_id}"
        _check_id(where, crop_id, errors)
        _check_keys(where, crop, CROP_KEYS, CROP_KEYS, errors)
        if crop.get("kind") not in kinds:
            errors.append(f"{where}.kind: no patch grows {crop.get('kind')!r}")
        for key in ("seed", "produce"):
            if crop.get(key) not in items:
                errors.append(f"{where}.{key}: unknown item {crop.get(key)!r}")
        if crop.get("seed") in seeds:
            errors.append(f"{where}.seed: {crop.get('seed')!r} already grows another crop")
        seeds.add(crop.get("seed"))
        _check_int(where, "level", crop.get("level"), 1, errors, 99)
        for key in ("plant_xp", "harvest_xp"):
            _check_number(where, key, crop.get(key), 0.1, 10000, errors)
        _check_int(where, "stage_ticks", crop.get("stage_ticks"), 1, errors)
        _check_int(where, "stages", crop.get("stages"), 1, errors, 10)
        pair = crop.get("yield")
        if not (isinstance(pair, list) and len(pair) == 2 and all(_is_int(v) for v in pair) and 1 <= pair[0] <= pair[1]):
            errors.append(f"{where}.yield: expected [min, max] whole numbers")
        if not COLOR_PATTERN.match(str(crop.get("color", ""))):
            errors.append(f"{where}.color: expected #rrggbb")


CONTRACT_KEYS = {"name", "board", "level", "item", "quantity", "to", "coins", "xp", "summary"}


COLLECTION_CATEGORIES = {"Combat", "Slayer", "Skilling", "Quests", "Frontier", "Other"}


def _check_collection(collection, items, errors):
    _check_keys("collection", collection, {"pages"}, {"pages"}, errors)
    for page_id, page in collection.get("pages", {}).items():
        where = f"collection.pages.{page_id}"
        _check_id(where, page_id, errors)
        _check_keys(where, page, {"name", "category", "items"}, {"name", "category", "items"}, errors)
        if page.get("category") not in COLLECTION_CATEGORIES:
            errors.append(f"{where}.category: unknown category {page.get('category')!r}")
        page_items = page.get("items", [])
        if not page_items:
            errors.append(f"{where}.items: a page needs at least one item")
        for item_id in page_items:
            if item_id not in items:
                errors.append(f"{where}.items: unknown item {item_id!r}")
        if len(set(page_items)) != len(page_items):
            errors.append(f"{where}.items: an item is listed twice")


def _check_pets(pets, items, monsters, errors):
    _check_keys("pets", pets, {"pets"}, {"pets"}, errors)
    listed = pets.get("pets", {})
    for pet_id, pet in listed.items():
        where = f"pets.pets.{pet_id}"
        if "pet" not in items.get(pet_id, {}):
            errors.append(f"{where}: {pet_id!r} must be an item with a pet block")
        source = pet.get("source")
        if source == "skill":
            _check_keys(where, pet, {"source", "skill", "one_in"}, {"source", "skill", "one_in"}, errors)
            if pet.get("skill") not in SKILLS:
                errors.append(f"{where}.skill: unknown skill {pet.get('skill')!r}")
        elif source == "monster":
            _check_keys(where, pet, {"source", "monster", "one_in"}, {"source", "monster", "one_in"}, errors)
            if pet.get("monster") not in monsters:
                errors.append(f"{where}.monster: unknown monster {pet.get('monster')!r}")
        else:
            errors.append(f"{where}.source: must be 'skill' or 'monster'")
        _check_int(where, "one_in", pet.get("one_in"), 1, errors)
    for item_id, item in items.items():
        if "pet" in item and item_id not in listed:
            errors.append(f"items.{item_id}.pet: no source in pets.json")


def _check_mercatura(mercatura, items, shops, errors):
    _check_keys("mercatura", mercatura, {"boards", "contracts"}, {"boards", "contracts"}, errors)
    boards = mercatura.get("boards", {})
    for board_id, board in boards.items():
        _check_id(f"mercatura.boards.{board_id}", board_id, errors)
        _check_keys(f"mercatura.boards.{board_id}", board, {"name", "examine"}, {"name", "examine"}, errors)
    for contract_id, contract in mercatura.get("contracts", {}).items():
        where = f"mercatura.contracts.{contract_id}"
        _check_id(where, contract_id, errors)
        _check_keys(where, contract, CONTRACT_KEYS, CONTRACT_KEYS, errors)
        if contract.get("board") not in boards:
            errors.append(f"{where}.board: unknown board {contract.get('board')!r}")
        if contract.get("item") not in items:
            errors.append(f"{where}.item: unknown item {contract.get('item')!r}")
        if contract.get("to") not in shops:
            errors.append(f"{where}.to: deliveries go to a shopkeeper; unknown shop {contract.get('to')!r}")
        _check_int(where, "level", contract.get("level"), 1, errors, 99)
        _check_int(where, "quantity", contract.get("quantity"), 1, errors, 1000)
        _check_int(where, "coins", contract.get("coins"), 1, errors)
        _check_number(where, "xp", contract.get("xp"), 0.1, 100000, errors)


FURNITURE_KEYS = {"name", "hotspot", "level", "xp", "materials", "provides"}
PROVIDES = {"station": {"fire", "range", "anvil", "tanning_rack", "furnace", "olive_press", "wine_press"}, "altar": {"heavenly", "underworld"},
            "bank": {True}, "patch": None, "travel": {"portus_salis"}, "steward": {True}}


def _check_villa(villa, items, quests, farming, errors):
    _check_keys("villa", villa, {"price", "requires_quest", "hotspots", "furniture"}, {"price", "hotspots", "furniture"}, errors)
    _check_int("villa", "price", villa.get("price"), 1, errors)
    if "requires_quest" in villa and villa["requires_quest"] not in quests.get("quests", {}):
        errors.append(f"villa.requires_quest: unknown quest {villa['requires_quest']!r}")
    hotspots = villa.get("hotspots", {})
    for hotspot_id, hotspot in hotspots.items():
        _check_id(f"villa.hotspots.{hotspot_id}", hotspot_id, errors)
        _check_keys(f"villa.hotspots.{hotspot_id}", hotspot, {"name", "examine"}, {"name", "examine"}, errors)
    for furniture_id, furniture in villa.get("furniture", {}).items():
        where = f"villa.furniture.{furniture_id}"
        _check_id(where, furniture_id, errors)
        _check_keys(where, furniture, FURNITURE_KEYS, FURNITURE_KEYS, errors)
        if furniture.get("hotspot") not in hotspots:
            errors.append(f"{where}.hotspot: unknown hotspot {furniture.get('hotspot')!r}")
        _check_int(where, "level", furniture.get("level"), 1, errors, 99)
        _check_number(where, "xp", furniture.get("xp"), 0.1, 100000, errors)
        if not furniture.get("materials"):
            errors.append(f"{where}.materials: at least one material required")
        for i, entry in enumerate(furniture.get("materials", [])):
            _check_drop(f"{where}.materials[{i}]", entry, items, errors, nothing_allowed=False, multiples_allowed=True)
        provides = furniture.get("provides", {})
        if len(provides) != 1 or next(iter(provides), None) not in PROVIDES:
            errors.append(f"{where}.provides: expected one of {sorted(PROVIDES)}")
            continue
        kind, value = next(iter(provides.items()))
        allowed = set(farming.get("patches", {})) if kind == "patch" else PROVIDES[kind]
        if value not in allowed:
            errors.append(f"{where}.provides.{kind}: unexpected {value!r}")


def _check_lines(where, key, lines, errors):
    if not isinstance(lines, list) or not lines or not all(isinstance(line, str) and line for line in lines):
        errors.append(f"{where}.{key}: expected a non-empty list of lines")


def _check_number(where, key, value, minimum, maximum, errors):
    if not isinstance(value, (int, float)) or isinstance(value, bool) or not minimum <= value <= maximum:
        errors.append(f"{where}.{key}: expected a number in {minimum}..{maximum}, got {value!r}")


def _check_id(where, value, errors):
    if not ID_PATTERN.match(value):
        errors.append(f"{where}: id must be snake_case")


def _check_keys(where, obj, allowed, required, errors):
    if not isinstance(obj, dict):
        errors.append(f"{where}: expected an object")
        return
    for key in sorted(set(obj) - allowed):
        errors.append(f"{where}.{key}: unknown field")
    for key in sorted(required - set(obj)):
        errors.append(f"{where}.{key}: required")


def _check_levels(where, levels, skills, errors):
    for skill, level in levels.items():
        if skill not in skills:
            errors.append(f"{where}.{skill}: unknown skill")
        _check_int(where, skill, level, 1, errors, 99)


def _is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def _check_int(where, key, value, minimum, errors, maximum=None):
    if not _is_int(value) or value < minimum or (maximum is not None and value > maximum):
        bound = f">= {minimum}" if maximum is None else f"in {minimum}..{maximum}"
        errors.append(f"{where}.{key}: expected an integer {bound}, got {value!r}")


def _check_type(where, key, value, expected, errors):
    if not isinstance(value, expected):
        errors.append(f"{where}.{key}: expected {expected.__name__}, got {value!r}")


def main() -> int:
    content_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else CONTENT_DIR
    errors = validate(load_content(content_dir))
    for error in errors:
        print(error, file=sys.stderr)
    print(f"{len(errors)} content error(s)" if errors else "Content OK")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
