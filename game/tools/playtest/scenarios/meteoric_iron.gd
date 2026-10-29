extends "res://tools/playtest/scenario.gd"
## The star-iron crater beyond the Limes: a miner of 75 with a meteoric
## pickaxe walks in through the gap in the rim and mines meteoric ore.

const PLAYER := 1
const Skills := preload("res://scripts/sim/skills.gd")


func run() -> void:
	await seconds(0.3)
	var me: RefCounted = driver().sim.get_combatant(PLAYER)
	me.skills.xp["mining"] = Skills.xp_for_level(75)
	driver().sim.give_item(PLAYER, "meteoric_pickaxe", 1, "test", [])
	var frontier: Node = main.get_node("Frontier")
	player().destination = null
	player().global_position = Vector3(-30, frontier.height_at(-30, -388) + 1.0, -388)
	await seconds(1.0)
	await shot("crater")
	var rocks := get_tree().get_nodes_in_group("rocks").filter(func(r): return r.rock_type == "meteoric_rock")
	expect(rocks.size() == 3, "three lumps of star-iron (%d)" % rocks.size())
	var rock: Node3D = rocks[0]
	expect(await walk_to(rock.global_position + (player().global_position - rock.global_position).normalized() * 1.4, 0.4, 40.0), "into the crater")
	await press("interact")
	for i in 120:
		if me.inventory.count("meteoric_ore") > 0:
			break
		await seconds(0.5)
	expect(me.inventory.count("meteoric_ore") > 0, "mined meteoric ore")
	await shot("mining")
