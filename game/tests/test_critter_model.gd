extends "res://tests/test_case.gd"

const CritterModel := preload("res://scripts/world/critter_model.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")


func test_every_animal_builds() -> void:
	for id in ContentDB.data()["monsters"]:
		var look: Dictionary = ContentDB.monster(id)["appearance"]
		if look["model"] in ["quadruped", "bird"]:
			var critter: Node3D = CritterModel.create(look)
			check(critter.find_children("*", "MeshInstance3D", true, false).size() > 8, "%s has a body" % id)
			critter.free()


func test_quadrupeds_have_four_legs_and_birds_two() -> void:
	var wolf: Node3D = CritterModel.create(ContentDB.monster("wolf")["appearance"])
	var strix: Node3D = CritterModel.create(ContentDB.monster("strix")["appearance"])
	check_eq(wolf._legs.size(), 4, "wolf legs")
	check_eq(strix._legs.size(), 2, "strix legs")
	check_eq(strix._wings.size(), 2, "strix wings")
	wolf.free()
	strix.free()


func test_death_and_revive_flags() -> void:
	var rat: Node3D = CritterModel.create(ContentDB.monster("rat")["appearance"])
	check(not rat.is_dead(), "alive")
	rat._dead = true
	rat.animate(0.1, 3.0)
	check(rat.is_dead(), "stays dead while animating")
	rat.revive()
	check(not rat.is_dead() and rat._rig.rotation == Vector3.ZERO, "revived upright")
	rat.free()
