extends "res://tests/test_case.gd"

const PlayerLook := preload("res://scripts/player/player_look.gd")


func test_body_armour_picks_the_outfit() -> void:
	check_eq(PlayerLook.appearance({})["scene"], "adventurers/Rogue", "no armour")
	check_eq(PlayerLook.appearance({"body": "iron_lorica"})["scene"], "adventurers/Knight", "lorica")
	check_eq(PlayerLook.appearance({"body": "ritual_robe"})["scene"], "adventurers/Mage", "robe")


func test_weapons_and_shields_go_in_the_hands() -> void:
	var look := PlayerLook.appearance({"weapon": "bronze_gladius", "shield": "bronze_scutum"})
	check_eq(look["weapon"], "weapons/sword_1handed", "gladius")
	check_eq(look["attack"], "slash", "slashes")
	check_eq(look["shield"], "weapons/shield_square", "scutum")
	check_eq(PlayerLook.appearance({"weapon": "lituus"})["attack"], "ritus", "lituus casts")
	check_eq(PlayerLook.appearance({})["attack"], "unarmed", "punches unarmed")


func test_helmet_shows_only_with_a_galea() -> void:
	check(PlayerLook.appearance({"body": "bronze_lorica"})["hide"].has("Knight_Helmet"), "no galea, no helmet")
	check(PlayerLook.appearance({"body": "bronze_lorica", "head": "bronze_galea"})["show"].has("Knight_Helmet"), "galea shows helmet")
	check(PlayerLook.appearance({"body": "ritual_robe", "head": "ritual_hood"})["show"].has("Mage_Hat"), "hood shows hat")


func test_every_equippable_weapon_and_shield_has_a_look() -> void:
	var ContentDB := preload("res://scripts/content/content_db.gd")
	for id in ContentDB.data()["items"]:
		var slot: String = ContentDB.item(id).get("equip", {}).get("slot", "")
		if slot == "weapon":
			check(PlayerLook.WEAPONS.has(id), "%s has a weapon look" % id)
		elif slot == "shield":
			check(PlayerLook.SHIELDS.has(id), "%s has a shield look" % id)


func test_legion_textures_exist() -> void:
	for body in PlayerLook.LEGION_TEXTURES:
		check(ResourceLoader.exists(PlayerLook.LEGION_TEXTURES[body]), "%s texture" % body)
	check(PlayerLook.appearance({}).has("texture"), "the starting tunic is recoloured")
	check(not PlayerLook.appearance({"body": "ritual_robe"}).has("texture"), "robes stay dark")
