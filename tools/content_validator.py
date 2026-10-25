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
FILES = ("items", "monsters", "drops", "slayer")

SKILLS = {"attack", "strength", "defence", "vitality", "slayer", "mining", "smithing", "cooking"}
COMBAT_STATS = {"attack", "strength", "defence", "vitality"}
EQUIP_SLOTS = {"head", "body", "weapon", "shield", "neck"}
BONUSES = {"attack", "strength", "defence"}
UNWARDED_EFFECTS = {"drain_vitality", "no_damage"}
ID_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")

ITEM_KEYS = {"name", "value", "examine", "stackable", "heals", "equip", "requirements", "tool", "tool_tier"}
MONSTER_KEYS = {"name", "level", "stats", "attack_speed", "aggressive", "respawn_ticks", "drops", "examine", "slayer", "appearance"}
COLOR_PATTERN = re.compile(r"^#[0-9a-fA-F]{6}$")


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
        _check_venator(f"slayer.venatores.{venator_id}", venator, monsters, errors)
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
        _check_keys(f"{where}.equip", equip, {"slot", "bonuses", "attack_speed"}, {"slot", "bonuses"}, errors)
        if equip.get("slot") not in EQUIP_SLOTS:
            errors.append(f"{where}.equip.slot: unknown slot {equip.get('slot')!r}")
        bonuses = equip.get("bonuses", {})
        if set(bonuses) != BONUSES:
            errors.append(f"{where}.equip.bonuses: expected keys {sorted(BONUSES)}")
        for key, value in bonuses.items():
            _check_int(f"{where}.equip.bonuses", key, value, -100, errors)
        if equip.get("slot") == "weapon":
            _check_int(f"{where}.equip", "attack_speed", equip.get("attack_speed"), 1, errors)
        elif "attack_speed" in equip:
            errors.append(f"{where}.equip.attack_speed: only weapons have an attack speed")


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
    _check_keys(f"{where}.appearance", appearance, {"color", "size"}, {"color", "size"}, errors)
    if not COLOR_PATTERN.match(str(appearance.get("color", ""))):
        errors.append(f"{where}.appearance.color: expected #rrggbb")
    size = appearance.get("size")
    if not isinstance(size, (int, float)) or isinstance(size, bool) or not 0.1 <= size <= 5:
        errors.append(f"{where}.appearance.size: expected a number in 0.1..5")
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


def _check_drop(where, entry, items, errors, nothing_allowed):
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
        elif quantity[1] > 1 and not items[item_id].get("stackable"):
            errors.append(f"{where}.quantity: {item_id} isn't stackable, so drop at most 1")
    else:
        _check_int(where, "quantity", quantity, 1, errors)
        if _is_int(quantity) and quantity > 1 and not items[item_id].get("stackable"):
            errors.append(f"{where}.quantity: {item_id} isn't stackable, so drop at most 1")


def _check_venator(where, venator, monsters, errors):
    _check_type(where, "name", venator.get("name"), str, errors)
    _check_int(where, "combat_level", venator.get("combat_level"), 1, errors)
    _check_int(where, "points_per_task", venator.get("points_per_task"), 0, errors)
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
