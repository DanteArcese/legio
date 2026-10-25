extends "res://tests/test_case.gd"

const ContentDB := preload("res://scripts/content/content_db.gd")
const Drops := preload("res://scripts/sim/drops.gd")


func test_loads_items_with_integer_fields() -> void:
	var gladius := ContentDB.item("bronze_gladius")
	check_eq(gladius["name"], "Bronze gladius", "name")
	check_eq(typeof(gladius["value"]), TYPE_INT, "value type")
	check_eq(typeof(gladius["equip"]["bonuses"]["attack"]), TYPE_INT, "bonus type")


func test_every_monster_drop_table_exists() -> void:
	for id in ContentDB.data()["monsters"]:
		check(not ContentDB.drop_table(ContentDB.monster(id)["drops"]).is_empty(), "%s drop table" % id)


func test_unknown_ids_return_empty() -> void:
	check(ContentDB.item("nope").is_empty(), "unknown item")
	check(not ContentDB.has_item("nope"), "has_item")


func test_guaranteed_drops_always_appear() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 50:
		var drops := Drops.roll(ContentDB.drop_table("wolf"), rng)
		check_eq(drops[0], {"item": "wolf_pelt", "quantity": 1}, "wolf pelt")


func test_drop_quantities_stay_in_range_and_items_exist() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 200:
		for drop in Drops.roll(ContentDB.drop_table("latro"), rng):
			check(ContentDB.has_item(drop["item"]), "item %s exists" % drop["item"])
			if drop["item"] == "coins":
				check(drop["quantity"] >= 10 and drop["quantity"] <= 40, "coins %d" % drop["quantity"])


func test_weights_shape_drop_rates() -> void:
	# Rat: nothing 6, coins 4 -> roughly 40% coins.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var coins := 0
	for i in 2000:
		for drop in Drops.roll(ContentDB.drop_table("rat"), rng):
			if drop["item"] == "coins":
				coins += 1
	check(coins > 700 and coins < 900, "coin drops %d / 2000" % coins)


func test_same_seed_same_drops() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	for i in 20:
		check_eq(Drops.roll(ContentDB.drop_table("strix"), a), Drops.roll(ContentDB.drop_table("strix"), b), "roll %d" % i)
