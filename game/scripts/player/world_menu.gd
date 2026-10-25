extends RefCounted
## Builds right-click / Y-button menus for things in the world. Each option
## is [label, Callable], and the first option is what a left-click does.

const ContentDB := preload("res://scripts/content/content_db.gd")

## How far the controller menu looks for things.
const NEARBY_MONSTER_RANGE := 8.0
const NEARBY_OBJECT_RANGE := 3.0
const NEARBY_LOOT_RANGE := 2.5
const MAX_NEARBY_MONSTERS := 3
## Ground clicks this close to loot or a grave include their options.
const GROUND_CLICK_RADIUS := 1.5


## Options for a raycast hit: the clicked object, or loot and graves next
## to a clicked spot on the ground.
static func options_for_hit(player: Node3D, hit: Dictionary) -> Array:
	var collider: Node = hit["collider"]
	if not is_ground(collider):
		return options_for(player, collider)
	var options := []
	for node in player.get_tree().get_nodes_in_group("loot_piles") + player.get_tree().get_nodes_in_group("graves"):
		if _flat(node.global_position - hit["position"]).length() < GROUND_CLICK_RADIUS:
			options.append_array(options_for(player, node))
	return options


## Whether a clicked collider is plain terrain rather than something usable.
static func is_ground(collider: Node) -> bool:
	return options_kind(collider).is_empty()


static func options_kind(node: Node) -> String:
	var entity: Node = node.get_node_or_null("SimEntity")
	if entity and entity.attackable and entity.combatant and entity.combatant.is_alive():
		return "monster"
	for group in ["rocks", "stations", "banks", "libitinarii", "venatores", "transitions", "loot_piles", "graves"]:
		if node.is_in_group(group):
			return group
	return ""


static func options_for(player: Node3D, node: Node) -> Array:
	var options := _options_by_kind(player, node)
	if node.has_meta("shop_id"):
		# Shop entries go just before Examine (always last for shopkeepers).
		var examine: Array = options.pop_back() if not options.is_empty() else []
		for offer in ContentDB.shop(node.get_meta("shop_id")).get("offers", []):
			var item_name: String = ContentDB.item(offer["item"])["name"].to_lower()
			if offer.get("quantity", 1) > 1:
				item_name += " x%d" % offer["quantity"]
			options.append(["Buy %s (%d denarii)" % [item_name, offer["price"]], player.buy.bind(node, offer["item"])])
		if not examine.is_empty():
			options.append(examine)
	return options


static func _options_by_kind(player: Node3D, node: Node) -> Array:
	match options_kind(node):
		"monster":
			var entity: Node = node.get_node("SimEntity")
			var name := "%s (level %d)" % [entity.display_name(), entity.combatant.display_level]
			var monster: Dictionary = ContentDB.monster(entity.monster_id)
			return [["Attack " + name, player.attack.bind(entity.entity_id)],
				["Examine " + entity.display_name(), player.examine.bind(monster.get("examine", ""))]]
		"rocks":
			var rock: Dictionary = ContentDB.rock(node.rock_type)
			return [["Mine " + rock["name"], player.mine.bind(node)],
				["Examine " + rock["name"], player.examine.bind(rock["examine"])]]
		"stations":
			return [["Use " + node.display_name(), player.use_station.bind(node)],
				["Examine " + node.display_name(), player.examine.bind(node.examine_text())]]
		"banks":
			return [["Open bank", player.open_bank.bind(node)],
				["Examine bank chest", player.examine.bind(node.get_meta("examine", ""))]]
		"libitinarii":
			return [["Reclaim items", player.reclaim.bind(node)],
				["Examine libitinarius", player.examine.bind(node.get_meta("examine", ""))]]
		"venatores":
			return [["Ask for a contract", player.ask_for_contract.bind(node)],
				["Examine " + node.get_meta("display_name", "venator"), player.examine.bind(node.get_meta("examine", ""))]]
		"transitions":
			return [[node.verb, player.travel.bind(node)], ["Examine " + node.title.to_lower(), player.examine.bind(node.examine_text)]]
		"loot_piles":
			var options := []
			if node.items.size() > 1:
				options.append(["Take all", player.take.bind(node, "")])
			for entry in node.items:
				var item: Dictionary = ContentDB.item(entry["item"])
				var label: String = item["name"] if entry["quantity"] == 1 else "%s x%d" % [item["name"], entry["quantity"]]
				options.append(["Take " + label, player.take.bind(node, entry["item"])])
			return options
		"graves":
			return [["Loot your grave", player.loot_grave.bind(node)]]
	return []


## Everything usable around the player, nearest first: up to a few monsters
## in fighting range, then objects, loot, and graves within reach.
static func options_nearby(player: Node3D) -> Array:
	var candidates := []
	for group in ["rocks", "stations", "banks", "libitinarii", "venatores", "transitions", "loot_piles", "graves"]:
		for node in player.get_tree().get_nodes_in_group(group):
			var range := NEARBY_LOOT_RANGE if group in ["loot_piles", "graves"] else NEARBY_OBJECT_RANGE
			var distance := _flat(node.global_position - player.global_position).length()
			if distance <= range:
				candidates.append([distance, node])
	var monsters := []
	for entity in player.get_tree().get_nodes_in_group("sim_entities"):
		if entity.monster_id.is_empty() or not entity.combatant or not entity.combatant.is_alive():
			continue
		var distance := _flat(entity.body().global_position - player.global_position).length()
		if distance <= NEARBY_MONSTER_RANGE:
			monsters.append([distance, entity.body()])
	monsters.sort_custom(func(a, b): return a[0] < b[0])
	candidates.append_array(monsters.slice(0, MAX_NEARBY_MONSTERS))
	candidates.sort_custom(func(a, b): return a[0] < b[0])
	var options := []
	for candidate in candidates:
		options.append_array(options_for(player, candidate[1]))
	return options


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
