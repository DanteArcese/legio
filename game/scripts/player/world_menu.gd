extends RefCounted
## Builds right-click / Y-button menus for things in the world. Each option
## is [label, Callable], and the first option is what a left-click does.

const ContentDB := preload("res://scripts/content/content_db.gd")
const Pietas := preload("res://scripts/sim/pietas.gd")
const Mercatura := preload("res://scripts/sim/mercatura.gd")
const Villa := preload("res://scripts/sim/villa.gd")
const Slayer := preload("res://scripts/sim/slayer.gd")
const Items := preload("res://scripts/sim/items.gd")
const Arena := preload("res://scripts/sim/arena.gd")

## How far the controller menu looks for things.
## Menus longer than this fold a shopkeeper's wares into a Trade submenu.
const MAX_MENU_ENTRIES := 8
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
	for group in ["rocks", "trees", "fishing_spots", "stations", "banks", "libitinarii", "venatores", "transitions", "altars", "springs", "loot_piles", "graves", "quest_npcs", "marks", "stalls", "strongboxes", "obstacles", "hunt_spots", "patches", "trade_boards", "surveyors", "waystones", "villa_hotspots", "shopkeepers", "pets"]:
		if node.is_in_group(group):
			return group
	return ""


static func options_for(player: Node3D, node: Node) -> Array:
	var options := _options_by_kind(player, node)
	if node.get_meta("shop_id", "") == Arena.data()["lanista"]:
		options = _arena_options(player, node) + options
	# A trade contract's cargo goes to this shopkeeper.
	var trade: Dictionary = player.get_node("SimEntity").combatant.trade_contract
	if node.has_meta("shop_id") and not trade.is_empty() and ContentDB.contract(trade["id"])["to"] == node.get_meta("shop_id"):
		options.push_front(["Deliver contract cargo", player.deliver_contract.bind(node)])
	if node.has_meta("shop_id") and _shop_open_to(player, node.get_meta("shop_id")):
		# Shop entries go just before Examine (always last for shopkeepers).
		var examine: Array = options.pop_back() if not options.is_empty() else []
		var wares := []
		for offer in ContentDB.shop(node.get_meta("shop_id")).get("offers", []):
			if offer.has("requires_quest") and not _quest_done(player, offer["requires_quest"]):
				continue
			var item_name: String = ContentDB.item(offer["item"])["name"].to_lower()
			if offer.get("quantity", 1) > 1:
				item_name += " x%d" % offer["quantity"]
			wares.append(["Buy %s (%d denarii)" % [item_name, offer["price"]], player.buy.bind(node, offer["item"])])
		# A long list folds into its own menu, so it's quick to get past
		# on a controller.
		if options.size() + wares.size() + 1 > MAX_MENU_ENTRIES:
			options.append(["Trade (%d wares)" % wares.size(), player.show_options.bind(wares)])
		else:
			options.append_array(wares)
		var sales := sales_for(player, node)
		if not sales.is_empty():
			options.append(["Sell (%d)" % sales.size(), player.show_options.bind(sales)])
		if not examine.is_empty():
			options.append(examine)
	return options


## A Sell entry for each kind of item in the pack this shopkeeper buys.
static func sales_for(player: Node3D, node: Node) -> Array:
	var shop_id: String = node.get_meta("shop_id", "")
	var inventory: RefCounted = player.get_node("SimEntity").combatant.inventory
	var seen := {}
	var sales := []
	for slot in inventory.slots:
		if slot == null or seen.has(slot["item"]):
			continue
		seen[slot["item"]] = true
		var price: int = Items.sell_price(shop_id, slot["item"])
		if price == 0:
			continue
		var count: int = inventory.count(slot["item"])
		var item_name: String = ContentDB.item(slot["item"])["name"].to_lower()
		if count > 1:
			item_name += " x%d" % count
		sales.append(["Sell %s (%d denarii)" % [item_name, price * count], player.sell.bind(node, slot["item"])])
	return sales


## Every Buy entry for a shopkeeper, whether listed directly or folded
## into its Trade submenu.
static func wares_for(player: Node3D, node: Node) -> Array:
	var wares := []
	for option in options_for(player, node):
		if option[0].begins_with("Buy "):
			wares.append(option)
		elif option[0].begins_with("Trade ("):
			wares.append_array(option[1].get_bound_arguments()[0])
	return wares


static func _options_by_kind(player: Node3D, node: Node) -> Array:
	match options_kind(node):
		"monster":
			var entity: Node = node.get_node("SimEntity")
			var name := "%s (level %d)" % [entity.display_name(), entity.combatant.display_level]
			var monster: Dictionary = ContentDB.monster(entity.monster_id)
			var options := [["Attack " + name, player.attack.bind(entity.entity_id)]]
			var contract: Dictionary = player.get_node("SimEntity").combatant.arena_contract
			if not contract.is_empty() and Arena.data()["contracts"][contract["id"]]["monster"] == entity.monster_id:
				options.append(["Throw a net over the " + entity.display_name().to_lower(), player.capture.bind(entity)])
			options.append(["Examine " + entity.display_name(), player.examine.bind(monster.get("examine", ""))])
			return options
		"rocks":
			var rock: Dictionary = ContentDB.rock(node.rock_type)
			return [["Mine " + rock["name"], player.mine.bind(node)],
				["Examine " + rock["name"], player.examine.bind(rock["examine"])]]
		"trees":
			return [["Chop " + node.display_name(), player.chop.bind(node)],
				["Examine " + node.display_name(), player.examine.bind(node.examine_text())]]
		"fishing_spots":
			return [[node.verb() + " " + node.display_name(), player.fish.bind(node)],
				["Examine fishing spot", player.examine.bind(node.examine_text())]]
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
			return _venator_options(player, node)
		"surveyors":
			var combatant: RefCounted = player.get_node("SimEntity").combatant
			var options := []
			if not combatant.villa_owned:
				options.append(["Buy a villa (%d denarii)" % ContentDB.data()["villa"]["price"], player.buy_villa.bind(node)])
			options.append(["Examine " + node.get_meta("display_name", "surveyor"), player.examine.bind(node.get_meta("examine", ""))])
			return options
		"waystones":
			return [["Travel to Portus Salis", player.use_waystone.bind(node)]]
		"villa_hotspots":
			var combatant: RefCounted = player.get_node("SimEntity").combatant
			var options := []
			if node.furniture.is_empty():
				for furniture_id in Villa.options_for(node.hotspot_type):
					var furniture := ContentDB.furniture(furniture_id)
					var materials := ", ".join(furniture["materials"].map(func(m): return "%d %s" % [m["quantity"], ContentDB.item(m["item"])["name"].to_lower()]))
					options.append(["Build %s (Engineering %d: %s)" % [furniture["name"].to_lower(), furniture["level"], materials],
						player.build_furniture.bind(node, furniture_id)])
			else:
				options.append(["Remove the %s" % ContentDB.furniture(node.furniture)["name"].to_lower(), player.remove_furniture.bind(node)])
			options.append(["Examine " + node.display_name().to_lower(), player.examine.bind(node.examine_text())])
			return options
		"trade_boards":
			var combatant: RefCounted = player.get_node("SimEntity").combatant
			var options := []
			if combatant.trade_contract.is_empty():
				for contract_id in Mercatura.contracts_on(node.board_id, combatant.skills.level("mercatura")):
					var contract := ContentDB.contract(contract_id)
					options.append(["Take: %s (%d %s to the %s, %d denarii)" % [contract["name"], contract["quantity"],
						ContentDB.item(contract["item"])["name"].to_lower(), ContentDB.shop(contract["to"])["name"].to_lower(), contract["coins"]],
						player.take_contract.bind(node, contract_id)])
			else:
				options.append(["Abandon your contract", player.abandon_contract])
			options.append(["Examine " + node.display_name().to_lower(), player.examine.bind(node.examine_text())])
			return options
		"patches":
			var options := []
			if node.crop.is_empty():
				for seed in player.sim_driver.sim.farming.plantable_seeds(player.get_node("SimEntity").combatant, node.patch_id):
					options.append(["Plant " + ContentDB.item(seed)["name"].to_lower(), player.farm.bind(node, seed)])
			elif node.grown:
				options.append(["Harvest " + ContentDB.crop(node.crop)["name"].to_lower(), player.farm.bind(node)])
			else:
				options.append(["Inspect " + node.display_name().to_lower(), player.farm.bind(node)])
			options.append(["Examine " + node.display_name().to_lower(), player.examine.bind(node.examine_text())])
			return options
		"hunt_spots":
			var trap: Dictionary = player.sim_driver.sim.hunter.spots.get(node.spot_id, {}).get("trap", {})
			var verb := "Set a box trap at" if trap.is_empty() else "Check the trap at"
			return [["%s the %s" % [verb, node.display_name().to_lower()], player.use_trap_spot.bind(node)],
				["Examine " + node.display_name().to_lower(), player.examine.bind(node.examine_text())]]
		"obstacles":
			return [[node.verb() + " " + node.display_name().to_lower(), player.cross.bind(node)]]
		"strongboxes":
			return [["Crack " + node.display_name(), player.crack.bind(node)],
				["Examine " + node.display_name().to_lower(), player.examine.bind(node.examine_text())]]
		"stalls":
			return [["Steal from " + node.display_name(), player.steal.bind(node)],
				["Examine " + node.display_name(), player.examine.bind(node.examine_text())]]
		"marks":
			var mark: Dictionary = ContentDB.mark(node.get_meta("mark_type"))
			return [["Pickpocket " + mark["name"], player.pickpocket.bind(node)],
				["Examine " + mark["name"], player.examine.bind(mark["examine"])]]
		"quest_npcs":
			var options := [["Talk to " + node.get_meta("display_name", "them"), player.talk.bind(node)]]
			if node.is_in_group("marks"):
				options.append(["Pickpocket " + node.get_meta("display_name", "them"), player.pickpocket.bind(node)])
			if node.get_meta("shop_id", "") == "sacerdos":
				options.append(["Ask for a cleansing (%d denarii)" % Pietas.CLEANSING_FEE, player.cleanse.bind(node)])
			options.append(["Examine " + node.get_meta("display_name", "them"), player.examine.bind(node.get_meta("examine", ""))])
			return options
		"shopkeepers":
			var options := []
			if node.get_meta("shop_id") == "sacerdos":
				options.append(["Ask for a cleansing (%d denarii)" % Pietas.CLEANSING_FEE, player.cleanse.bind(node)])
			options.append(["Examine " + node.get_meta("display_name", "shopkeeper"), player.examine.bind(node.get_meta("examine", ""))])
			return options
		"springs":
			return [["Wash in the sacred spring", player.wash.bind(node)],
				["Examine the spring", player.examine.bind("Cold, clear water. It washes away the taint of the underworld.")]]
		"altars":
			var options := [["Pray at the " + node.title, player.pray.bind(node)]]
			var inventory: RefCounted = player.get_node("SimEntity").combatant.inventory
			var offered := []
			for slot in inventory.slots:
				if slot and not offered.has(slot["item"]) and not ContentDB.offering(slot["item"]).is_empty():
					offered.append(slot["item"])
					options.append(["Offer " + ContentDB.item(slot["item"])["name"].to_lower(), player.offer.bind(node, slot["item"])])
			options.append(["Examine " + node.title.to_lower(), player.examine.bind("Pray here to restore favour, or make offerings to the gods.")])
			return options
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
		"pets":
			return [["Pick up " + node.title().to_lower(), player.pick_up_pet], ["Examine " + node.title().to_lower(), player.examine.bind(ContentDB.item(node.pet_id)["examine"])]]
	return []


## Everything usable around the player, nearest first: up to a few monsters
## in fighting range, then objects, loot, and graves within reach.
static func options_nearby(player: Node3D) -> Array:
	var candidates := []
	for group in ["rocks", "trees", "fishing_spots", "stations", "banks", "libitinarii", "venatores", "transitions", "altars", "loot_piles", "graves", "quest_npcs", "marks", "stalls", "strongboxes", "obstacles", "hunt_spots", "patches", "trade_boards", "surveyors", "waystones", "villa_hotspots", "shopkeepers"]:
		for node in player.get_tree().get_nodes_in_group(group):
			if candidates.any(func(c): return c[1] == node):
				continue
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


## The lanista's arena contracts: take one, hand it in, or give it up.
static func _arena_options(player: Node3D, node: Node) -> Array:
	var combatant: RefCounted = player.get_node("SimEntity").combatant
	var contract: Dictionary = combatant.arena_contract
	var options := []
	if contract.is_empty():
		for contract_id in Arena.contracts_for(combatant.skills.level("hunter")):
			var spec: Dictionary = Arena.data()["contracts"][contract_id]
			options.append(["Take: %s (%d %s alive, %d denarii)" % [spec["name"], spec["count"],
				Slayer.plural_name(spec["monster"]), spec["coins"]], player.take_arena.bind(node, contract_id)])
	elif contract["remaining"] == 0:
		options.append(["Hand in the beasts", player.hand_in_arena.bind(node)])
	else:
		options.append(["Give up the contract", player.abandon_arena])
	return options


## A contract, plus what Slayer points buy here.
static func _venator_options(player: Node3D, node: Node) -> Array:
	var combatant: RefCounted = player.get_node("SimEntity").combatant
	var rewards := ContentDB.slayer_rewards()
	var options := [["Ask for a contract", player.ask_for_contract.bind(node)]]
	var task: Dictionary = combatant.slayer_task
	if not task.is_empty():
		var monsters := Slayer.plural_name(task["monster"])
		options.append(["Cancel the %s contract (%d points)" % [monsters, rewards["cancel"]],
			player.slayer_reward.bind(node, "cancel")])
		if combatant.slayer_blocked.size() < rewards["max_blocks"]:
			options.append(["Never hunt %s again (%d points)" % [monsters, rewards["block"]],
				player.slayer_reward.bind(node, "block")])
	for monster_id in combatant.slayer_blocked:
		options.append(["Hunt %s again" % Slayer.plural_name(monster_id), player.slayer_reward.bind(node, "unblock", {"monster": monster_id})])
	for unlock_id in rewards["unlocks"]:
		if not combatant.slayer_unlocks.has(unlock_id):
			var unlock: Dictionary = rewards["unlocks"][unlock_id]
			options.append(["Learn %s (%d points)" % [unlock["name"], unlock["cost"]],
				player.slayer_reward.bind(node, "unlock", {"unlock": unlock_id})])
	options.append(["Examine " + node.get_meta("display_name", "venator"), player.examine.bind(node.get_meta("examine", ""))])
	return options


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Shops behind a quest stay hidden until the player has finished it.
static func _shop_open_to(player: Node3D, shop_id: String) -> bool:
	var quest_id: String = ContentDB.shop(shop_id).get("requires_quest", "")
	return quest_id.is_empty() or _quest_done(player, quest_id)


static func _quest_done(player: Node3D, quest_id: String) -> bool:
	return player.get_node("SimEntity").combatant.quests.get(quest_id, {}).get("done", false)
