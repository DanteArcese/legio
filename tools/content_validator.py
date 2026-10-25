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
FILES = ("items", "monsters", "drops", "slayer", "player", "skilling", "shops", "pietas")

SKILLS = {"attack", "strength", "defence", "vitality", "ranged", "ritus", "pietas", "slayer", "mining", "smithing", "cooking"}
COMBAT_STATS = {"attack", "strength", "defence", "vitality"}
EQUIP_SLOTS = {"head", "body", "weapon", "shield", "neck", "ammo"}
BONUSES = {"attack", "strength", "defence", "ranged_attack", "ranged_strength", "ritus_attack", "ritus_strength", "ranged_defence", "ritus_defence"}
AMMO_TYPES = {"arrow", "sling_bullet", "tablet"}
CURSES = {"binding", "withering", "silencing", "manes"}
UNWARDED_EFFECTS = {"drain_vitality", "no_damage"}
RECIPE_KINDS = {"smelt", "smith", "cook", "inscribe"}
ROCK_KEYS = {"name", "ore", "level", "xp", "difficulty", "respawn_ticks", "color", "examine"}
RECIPE_KEYS = {"id", "inputs", "output", "quantity", "level", "xp", "success", "tool", "burnt", "stop_burning"}
ID_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")

ITEM_KEYS = {"name", "value", "examine", "stackable", "heals", "equip", "requirements", "tool", "tool_tier"}
MONSTER_KEYS = {"name", "level", "stats", "attack_speed", "aggressive", "respawn_ticks", "drops", "examine", "slayer", "appearance"}
COLOR_PATTERN = re.compile(r"^#[0-9a-fA-F]{6}$")
# Must match what game/scripts/world/creature_model.gd knows how to build.
MODEL_FEATURES = {
    "kaykit": set(),
    "quadruped": {"ears", "round_ears", "long_snout", "tusks", "bristles", "tail"},
    "humanoid": {"hood", "helmet", "glowing_eyes", "ghostly", "bare_legs"},
    "bird": {"ear_tufts"},
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
    _check_skilling(content.get("skilling", {}), items, errors)
    _check_pietas(content.get("pietas", {}), items, errors)
    for shop_id, shop in content.get("shops", {}).items():
        _check_shop(f"shops.{shop_id}", shop, items, errors)
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
    if "tool" in item:
        _check_type(where, "tool", item["tool"], str, errors)
        _check_int(where, "tool_tier", item.get("tool_tier"), 1, errors)
    if "requirements" in item:
        _check_levels(f"{where}.requirements", item["requirements"], SKILLS, errors)
    if "equip" in item:
        equip = item["equip"]
        _check_keys(f"{where}.equip", equip, {"slot", "bonuses", "attack_speed", "style", "range", "ammo", "ammo_type", "curse"}, {"slot", "bonuses"}, errors)
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


def _check_monster(where, monster_id, monster, items, drops, errors):
    _check_id(where, monster_id, errors)
    _check_keys(where, monster, MONSTER_KEYS, MONSTER_KEYS - {"slayer"}, errors)
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
        _check_keys(f"{where}.slayer", slayer, {"level", "ward_item", "unwarded_effect"}, {"level"}, errors)
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
    _check_keys("skilling", skilling, {"rocks", "recipes"}, {"rocks", "recipes"}, errors)
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
    _check_keys(where, shop, {"name", "offers"}, {"name", "offers"}, errors)
    for i, offer in enumerate(shop.get("offers", [])):
        _check_keys(f"{where}.offers[{i}]", offer, {"item", "price", "quantity"}, {"item", "price"}, errors)
        if offer.get("item") not in items:
            errors.append(f"{where}.offers[{i}].item: unknown item {offer.get('item')!r}")
        _check_int(f"{where}.offers[{i}]", "price", offer.get("price"), 1, errors)
        if "quantity" in offer:
            _check_int(f"{where}.offers[{i}]", "quantity", offer["quantity"], 1, errors)
            if offer["quantity"] > 1 and not items.get(offer.get("item"), {}).get("stackable"):
                errors.append(f"{where}.offers[{i}].quantity: only stackable items come in bundles")


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
