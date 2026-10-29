extends Node3D
## The rival chariots during the player's race, at whichever circus it's run:
## each holds its pace on its own lane from the start tick, smoothed between
## ticks, and stops at the finish.

const Circus := preload("res://scripts/sim/circus.gd")
const ChariotModel := preload("res://scripts/world/chariot_model.gd")
const KaykitCharacter := preload("res://scripts/world/kaykit_character.gd")

@export var driver: Node
@export var player_entity: Node

## [{"node", "speed", "lane", "figure"}] while a race is on.
var _rivals := []
var _race_start := -1
var _circus := "castra"


func _ready() -> void:
	if driver:
		driver.sim_event.connect(_on_sim_event)


func _on_sim_event(event: Dictionary) -> void:
	if player_entity == null or event.get("id") != player_entity.entity_id:
		return
	match event["type"]:
		"race_started":
			_spawn_rivals(event["start"], player_entity.combatant.race.get("circus", "castra"))
		"race_ended":
			_clear_rivals()


func _spawn_rivals(start: int, circus_id: String) -> void:
	_clear_rivals()
	_race_start = start
	_circus = circus_id
	var rules := Circus.data(circus_id)
	var rivals: Array = rules["rivals"]
	for i in rivals.size():
		var rival: Dictionary = rivals[i]
		var node := Node3D.new()
		node.name = "Rival%d" % i
		node.add_child(ChariotModel.build(Color(rival["color"]), rules.get("horses", 2)))
		var figure := KaykitCharacter.create({"scene": "adventurers/Rogue"})
		figure.position.y = 0.45
		node.add_child(figure)
		var label := Label3D.new()
		label.text = String(rival["name"]).capitalize()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 32
		label.outline_size = 8
		label.position.y = 2.6
		node.add_child(label)
		add_child(node)
		var lane := Circus.LANE_WIDTH * (-1.0 if i % 2 == 0 else 1.0) * (1 + i / 2)
		_rivals.append({"node": node, "speed": rival["speed"], "lane": lane, "figure": figure})
	_place_rivals()


func _clear_rivals() -> void:
	for rival in _rivals:
		rival["node"].queue_free()
	_rivals.clear()
	_race_start = -1


func _process(_delta: float) -> void:
	if not _rivals.is_empty():
		_place_rivals()


func _place_rivals() -> void:
	var sim: RefCounted = driver.sim
	var ticks := maxf(0.0, sim.tick - _race_start + driver.clock.progress())
	var track: Dictionary = sim.circus.tracks[_circus]
	var finish_s: float = Circus.START_PROGRESS + Circus.data(_circus)["laps"] * Circus.lap_length(track)
	for rival in _rivals:
		var s: float = minf(Circus.START_PROGRESS + rival["speed"] * ticks * Circus.TICK_SECONDS, finish_s)
		var here := Circus.point_at(track, s, rival["lane"])
		var ahead := Circus.point_at(track, s + 1.0, rival["lane"])
		var node: Node3D = rival["node"]
		node.global_position = here
		node.look_at(ahead, Vector3.UP)
		rival["figure"].animate(0.0, 0.0)
