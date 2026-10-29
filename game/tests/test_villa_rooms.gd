extends "res://tests/test_case.gd"
## Villa rooms past Engineering 60: the bath house (heals and cleanses), the
## library's scriptorium (inscribe curses at home), and the peristyle garden
## (rest there for twice the mosaic's XP bonus).

const Simulation := preload("res://scripts/sim/simulation.gd")
const Skills := preload("res://scripts/sim/skills.gd")
const ContentDB := preload("res://scripts/content/content_db.gd")

const PLAYER := 1


func _make_sim() -> Simulation:
	var sim := Simulation.new(17)
	var player := sim.add_player(PLAYER)
	player.quests["decurio"] = {"step": 3, "progress": 0, "done": true}
	player.villa_owned = true
	player.skills.xp["engineering"] = Skills.xp_for_level(90)
	for spec in [["bath", "bath"], ["library", "library"], ["peristyle", "peristyle"]]:
		sim.villa.add_hotspot(spec[0], spec[1], Vector3(0, 0, 1))
	sim.give_item(PLAYER, "hammer", 1, "test", [])
	return sim


func _do(sim: Simulation, action: String, args := {}) -> Array:
	sim.queue_item_action(PLAYER, action, args)
	return sim.step()


func _build(sim: Simulation, hotspot: String, furniture_id: String) -> void:
	for m in ContentDB.furniture(furniture_id)["materials"]:
		sim.give_item(PLAYER, m["item"], m["quantity"], "test", [])
	_do(sim, "build", {"hotspot": hotspot, "furniture": furniture_id})


func test_the_bath_heals_and_cleanses() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	_build(sim, "bath", "bath_house")
	check_eq(player.villa_furniture.get("bath", ""), "bath_house", "built")
	player.hp = 2
	player.pollution = 40.0
	_do(sim, "bathe", {"hotspot": "bath"})
	check_eq(player.hp, player.max_hp, "healed")
	check_eq(player.pollution, 0.0, "and clean")


func test_the_peristyle_rests_you_twice_as_well() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	_build(sim, "peristyle", "peristyle_garden")
	_do(sim, "rest", {"hotspot": "peristyle"})
	check(is_equal_approx(player.rested_bonus, 0.1), "+10 percent XP (%s)" % player.rested_bonus)
	var before: float = player.skills.xp["mining"]
	sim.award_xp(player, "mining", 100.0, [])
	check(is_equal_approx(player.skills.xp["mining"] - before, 110.0), "100 XP becomes 110")


func test_the_library_is_a_scriptorium() -> void:
	var sim := _make_sim()
	var player: RefCounted = sim.get_combatant(PLAYER)
	_build(sim, "library", "library")
	sim.give_item(PLAYER, "stylus", 1, "test", [])
	sim.give_item(PLAYER, "lead_sheet", 1, "test", [])
	sim.give_item(PLAYER, "bronze_nails", 1, "test", [])
	_do(sim, "craft", {"kind": "inscribe", "recipe": "binding_tablet", "count": 1})
	for i in 10:
		sim.step()
	check_eq(player.inventory.count("binding_tablet"), 5, "tablets inscribed at home")
