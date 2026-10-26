import copy
import re

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
    errors = errors_after(content, lambda c: c["drops"]["rat"]["always"].append({"item": "golden_fleece", "quantity": 1}))
    assert any("unknown item 'golden_fleece'" in e for e in errors)


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
    errors = errors_after(content, lambda c: c["shops"]["aulus"]["offers"].append({"item": "net", "price": 5}))
    assert any("unknown item 'net'" in e for e in errors)


def test_ranged_weapons_need_range_and_ammo_type(content):
    def mutate(c):
        del c["items"]["hunting_bow"]["equip"]["range"]
        c["items"]["bronze_arrow"]["equip"]["ammo_type"] = "bolt"

    errors = errors_after(content, mutate)
    assert any("hunting_bow.equip.range" in e for e in errors)
    assert any("bronze_arrow.equip.ammo_type" in e for e in errors)


def test_melee_weapons_cannot_have_range(content):
    errors = errors_after(content, lambda c: c["items"]["bronze_gladius"]["equip"].update(range=3.0))
    assert any("only ranged and ritus weapons have range" in e for e in errors)


def test_batch_recipes_need_stackable_output(content):
    errors = errors_after(content, lambda c: c["skilling"]["recipes"]["smith"][2].update(quantity=3))
    assert any("only stackable outputs" in e for e in errors)


def test_tablets_need_a_known_curse(content):
    def mutate(c):
        c["items"]["binding_tablet"]["equip"]["curse"] = "hexing"
        del c["items"]["withering_tablet"]["equip"]["curse"]

    errors = errors_after(content, mutate)
    assert any("binding_tablet.equip.curse: must be one of" in e for e in errors)
    assert any("withering_tablet.equip.curse: tablets, and only tablets" in e for e in errors)


def test_blessings_and_offerings_are_checked(content):
    def mutate(c):
        c["pietas"]["blessings"]["mars_vigour"]["boost"] = {"flying": 1}
        c["pietas"]["offerings"]["unicorn_horn"] = {"xp": 5, "altar": "heavenly"}

    errors = errors_after(content, mutate)
    assert any("boost.flying: unknown boost" in e for e in errors)
    assert any("unicorn_horn: unknown item" in e for e in errors)


def test_trees_must_drop_real_logs(content):
    errors = errors_after(content, lambda c: c["skilling"]["trees"]["oak_tree"].update(log="oak_planks"))
    assert any("skilling.trees.oak_tree.log" in e for e in errors)


def test_fishing_spots_need_a_real_tool_and_fish(content):
    def break_spot(c):
        c["skilling"]["fishing_spots"]["net_spot"]["tool"] = "trident"
        c["skilling"]["fishing_spots"]["net_spot"]["catches"][0]["fish"] = "raw_whale"

    errors = errors_after(content, break_spot)
    assert any("skilling.fishing_spots.net_spot.tool" in e for e in errors)
    assert any("net_spot.catches[0].fish" in e for e in errors)


def test_fell_chance_is_a_probability(content):
    errors = errors_after(content, lambda c: c["skilling"]["trees"]["tree"].update(fell_chance=1.5))
    assert any("skilling.trees.tree" in e and "fell_chance" in e for e in errors)


def test_quest_steps_reference_real_monsters_and_npcs(content):
    def break_quest(c):
        steps = c["quests"]["quests"]["tiro"]["steps"]
        steps[3]["monster"] = "dragon"
        steps[-1]["npc"] = "nobody"

    errors = errors_after(content, break_quest)
    assert any("steps[3].monster" in e for e in errors)
    assert any("steps[4].npc" in e for e in errors)


def test_quests_end_by_handing_in(content):
    errors = errors_after(content, lambda c: c["quests"]["quests"]["tiro"]["steps"].pop())
    assert any("last step must be talking" in e for e in errors)


def test_shop_quest_gate_must_name_a_real_quest(content):
    errors = errors_after(content, lambda c: c["shops"]["quartermaster"].update(requires_quest="centurio"))
    assert any("shops.quartermaster.requires_quest" in e for e in errors)


def test_examine_text_uses_an_before_vowels():
    content = load_content()
    bad = []
    for section in ("items", "monsters"):
        for entry_id, entry in content[section].items():
            text = entry.get("examine", "")
            if re.search(r"\bA [aeiouAEIOU]", text):
                bad.append(f"{section}.{entry_id}: {text}")
    assert not bad, bad


def test_stall_loot_must_exist(content):
    errors = errors_after(content, lambda c: c["thieving"]["stalls"]["cloth_stall"]["loot"].update(item="silk"))
    assert any("thieving.stalls.cloth_stall.loot" in e for e in errors)


def test_mark_coin_range_must_be_ordered(content):
    errors = errors_after(content, lambda c: c["thieving"]["marks"]["merchant"].update(coins=[30, 10]))
    assert any("thieving.marks.merchant.coins" in e for e in errors)


def test_obstacle_kinds_must_be_known(content):
    errors = errors_after(content, lambda c: c["athletics"]["courses"]["fort_course"]["obstacles"][0].update(kind="trampoline"))
    assert any("fort_course.obstacles[0].kind" in e for e in errors)


def test_crops_need_a_patch_that_grows_them(content):
    errors = errors_after(content, lambda c: c["farming"]["crops"]["mint"].update(kind="tree"))
    assert any("farming.crops.mint.kind" in e for e in errors)


def test_each_seed_grows_one_crop(content):
    errors = errors_after(content, lambda c: c["farming"]["crops"]["sage"].update(seed="mint_seed"))
    assert any("already grows another crop" in e for e in errors)


def test_remedies_boost_real_skills(content):
    errors = errors_after(content, lambda c: c["items"]["mint_tonic"]["remedy"].update(skill="charisma"))
    assert any("items.mint_tonic.remedy.skill" in e for e in errors)


def test_contracts_deliver_to_real_shopkeepers(content):
    errors = errors_after(content, lambda c: c["mercatura"]["contracts"]["salt_for_the_fort"].update(to="nobody"))
    assert any("salt_for_the_fort.to" in e for e in errors)
