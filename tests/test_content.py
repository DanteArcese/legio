import copy

import pytest

from content_validator import load_content, validate


@pytest.fixture(scope="module")
def content():
    return load_content()


def errors_after(content, mutate):
    changed = copy.deepcopy(content)
    mutate(changed)
    return validate(changed)


def test_shipped_content_is_valid(content):
    assert validate(content) == []


def test_unknown_drop_item_is_reported(content):
    errors = errors_after(content, lambda c: c["drops"]["rat"]["always"].append({"item": "gold_bar", "quantity": 1}))
    assert any("unknown item 'gold_bar'" in e for e in errors)


def test_monster_with_missing_drop_table_is_reported(content):
    errors = errors_after(content, lambda c: c["monsters"]["rat"].update(drops="nope"))
    assert any("monsters.rat.drops" in e for e in errors)


def test_slayer_task_for_unknown_monster_is_reported(content):
    def mutate(c):
        c["slayer"]["venatores"]["aulus"]["tasks"].append({"monster": "minotaur", "weight": 1, "amount": [1, 2]})

    assert any("unknown monster 'minotaur'" in e for e in errors_after(content, mutate))


def test_task_below_monster_slayer_requirement_is_reported(content):
    def mutate(c):
        for task in c["slayer"]["venatores"]["aulus"]["tasks"]:
            if task["monster"] == "strix":
                del task["slayer_level"]

    assert any("needs Slayer 10" in e for e in errors_after(content, mutate))


def test_multiple_unstackable_items_in_one_drop_is_reported(content):
    errors = errors_after(content, lambda c: c["drops"]["wolf"]["always"][0].update(quantity=3))
    assert any("isn't stackable" in e for e in errors)


def test_unknown_fields_and_bad_slots_are_reported(content):
    def mutate(c):
        c["items"]["bronze_galea"]["colour"] = "red"
        c["items"]["bronze_galea"]["equip"]["slot"] = "hat"

    errors = errors_after(content, mutate)
    assert any("colour: unknown field" in e for e in errors)
    assert any("unknown slot 'hat'" in e for e in errors)


def test_requirement_levels_must_be_in_range(content):
    errors = errors_after(content, lambda c: c["items"]["iron_gladius"]["requirements"].update(attack=150))
    assert any("iron_gladius.requirements.attack" in e for e in errors)


def test_non_weapons_cannot_have_attack_speed(content):
    errors = errors_after(content, lambda c: c["items"]["bronze_scutum"]["equip"].update(attack_speed=4))
    assert any("only weapons" in e for e in errors)


def test_monster_appearance_is_checked(content):
    errors = errors_after(content, lambda c: c["monsters"]["wolf"]["appearance"].update(color="grey"))
    assert any("appearance.color" in e for e in errors)


def test_features_must_suit_the_model(content):
    def mutate(c):
        c["monsters"]["wolf"]["appearance"]["features"].append("ear_tufts")
        c["monsters"]["rat"]["appearance"]["model"] = "dragon"

    errors = errors_after(content, mutate)
    assert any("'ear_tufts' isn't a quadruped feature" in e for e in errors)
    assert any("monsters.rat.appearance.model" in e for e in errors)


def test_starting_kit_items_must_exist(content):
    errors = errors_after(content, lambda c: c["player"]["starting_kit"].append({"item": "toga", "quantity": 1}))
    assert any("player.starting_kit" in e and "unknown item 'toga'" in e for e in errors)


def test_rock_ore_must_exist(content):
    errors = errors_after(content, lambda c: c["skilling"]["rocks"]["tin_rock"].update(ore="tin_nugget"))
    assert any("skilling.rocks.tin_rock.ore" in e for e in errors)


def test_recipe_tool_must_be_provided_by_an_item(content):
    errors = errors_after(content, lambda c: c["skilling"]["recipes"]["smith"][0].update(tool="tongs"))
    assert any("no item provides tool 'tongs'" in e for e in errors)


def test_cooking_recipe_needs_stop_burning_with_burnt(content):
    errors = errors_after(content, lambda c: c["skilling"]["recipes"]["cook"][0].pop("stop_burning"))
    assert any("burnt and stop_burning go together" in e for e in errors)


def test_shop_items_must_exist(content):
    errors = errors_after(content, lambda c: c["slayer"]["venatores"]["aulus"]["shop"].append({"item": "net", "price": 5}))
    assert any("shop[1].item: unknown item 'net'" in e for e in errors)
