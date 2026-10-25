extends Node3D
## An animated KayKit (CC0) character: idle, walk, run, attacks, hit
## reactions, death, and looping work animations, plus weapons and shields
## attached to the hand bones. Shares the procedural creature model's API
## (create, animate) so monsters and the player can use either.

const ROOT := "res://assets/kaykit/"
const PropModels := preload("res://scripts/world/prop_models.gd")
## KayKit characters stand about 2.5 units tall; this makes them about 1.9 m.
const BASE_SCALE := 0.75
const BLEND := 0.15
const RUN_SPEED := 4.0
## Built-in props in the KayKit rigs; we attach our own instead.
const HAND_SLOTS := ["handslot_l", "handslot_r"]

## Attack animation by combat kind or weapon style.
const ATTACKS := {
	"stab": "1H_Melee_Attack_Stab", "slash": "1H_Melee_Attack_Slice_Diagonal",
	"unarmed": "Unarmed_Melee_Attack_Punch_A", "ranged": "1H_Ranged_Shoot", "bow": "2H_Ranged_Shoot", "throw": "Throw",
	"ritus": "Spellcast_Shoot",
}
## Looping work animations by skilling action.
const WORK := {"mine": "1H_Melee_Attack_Chop", "smelt": "Interact", "smith": "1H_Melee_Attack_Chop",
	"cook": "Interact", "inscribe": "Use_Item", "offer": "Interact"}

var kind := "kaykit"
var attack_style := "unarmed"
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _busy_until := 0.0
var _dead := false
var _work := ""
var _attachments := {}

## Loaded palette textures, shared between characters.
static var _textures := {}


## appearance: {"scene": "adventurers/Knight", "size": 1.0, "show": [...],
## "hide": [...], "weapon": "weapons/dagger", "shield": "weapons/shield_round",
## "attack": "stab"}. Meshes not listed keep the pack's default visibility,
## except hand-slot props, which are always replaced.
static func create(appearance: Dictionary) -> Node3D:
	var character := new()
	var model: Node3D = load(ROOT + appearance["scene"] + ".glb").instantiate()
	# KayKit models face +Z (glTF's convention); the game's forward is -Z.
	model.rotation.y = PI
	character.add_child(model)
	character.scale = Vector3.ONE * BASE_SCALE * float(appearance.get("size", 1.0))
	character._player = model.find_children("*", "AnimationPlayer", true, false)[0]
	character._skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	for slot in HAND_SLOTS:
		var holder := character._skeleton.get_node_or_null(slot)
		if holder:
			for prop in holder.get_children():
				prop.visible = false
	for name in appearance.get("hide", []):
		character.set_mesh_visible(name, false)
	for name in appearance.get("show", []):
		character.set_mesh_visible(name, true)
	character.attach("handslot_r", appearance.get("weapon", ""))
	character.attach("handslot_l", appearance.get("shield", ""))
	character.attack_style = appearance.get("attack", "unarmed")
	if appearance.has("texture"):
		character.use_texture(appearance["texture"])
	character._loop("Idle")
	return character


## Swaps the outfit's palette texture for a baked recolour (see
## tools/bake_palette.gd), e.g. the legion-red tunic.
func use_texture(path: String) -> void:
	if not _textures.has(path):
		_textures[path] = load(path)
	for mesh in _skeleton.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if material == null or material.albedo_texture == null:
				continue
			var copy := material.duplicate() as StandardMaterial3D
			copy.albedo_texture = _textures[path]
			mesh.set_surface_override_material(i, copy)


func set_mesh_visible(mesh_name: String, shown: bool) -> void:
	var mesh := _skeleton.find_child(mesh_name, true, false)
	if mesh:
		mesh.visible = shown


## Puts a weapon or shield model ("" for none) in a hand slot.
func attach(slot: String, model_path: String) -> void:
	if _attachments.has(slot):
		_attachments[slot].queue_free()
		_attachments.erase(slot)
	if model_path.is_empty():
		return
	var holder := _skeleton.get_node_or_null(slot)
	if holder == null:
		return
	# "proc:<name>" props are built in code (bow, sling); the rest are files.
	var prop: Node3D = PropModels.build(model_path.trim_prefix("proc:")) if model_path.begins_with("proc:") \
		else load(ROOT + model_path + ".gltf").instantiate()
	holder.add_child(prop)
	_attachments[slot] = prop


## Called every frame with the body's horizontal speed.
func animate(_delta: float, speed: float) -> void:
	if _dead or Time.get_ticks_msec() / 1000.0 < _busy_until:
		return
	if speed > RUN_SPEED:
		_loop("Running_A")
	elif speed > 0.15:
		_loop("Walking_A")
	elif not _work.is_empty():
		_loop(_work)
	else:
		_loop("Idle")


func attack(kind_or_style := "") -> void:
	var style := kind_or_style if ATTACKS.has(kind_or_style) else attack_style
	_play_once(ATTACKS.get(style, ATTACKS["unarmed"]))
	if style == "throw" and _attachments.has("handslot_r"):
		# Whirl the sling twice before the release.
		var sling: Node3D = _attachments["handslot_r"]
		var spin := sling.create_tween()
		spin.tween_property(sling, "rotation:x", TAU * 2.0, 0.5).from(0.0)


func hurt() -> void:
	if Time.get_ticks_msec() / 1000.0 >= _busy_until:
		_play_once("Hit_A")


func die() -> void:
	_dead = true
	_work = ""
	_player.play("Death_A", BLEND)


func revive() -> void:
	_dead = false
	_busy_until = 0.0
	_loop("Idle")


func is_dead() -> bool:
	return _dead


## A looping work animation ("" to stop), e.g. "mine".
func set_work(action: String) -> void:
	_work = WORK.get(action, "")


func current_animation() -> String:
	return _player.current_animation


func _play_once(name: String) -> void:
	if _dead or not _player.has_animation(name):
		return
	_player.play(name, BLEND)
	_busy_until = Time.get_ticks_msec() / 1000.0 + _player.get_animation(name).length * 0.9


func _loop(name: String) -> void:
	if not _player.has_animation(name):
		return
	var animation := _player.get_animation(name)
	animation.loop_mode = Animation.LOOP_LINEAR
	if _player.current_animation != name:
		_player.play(name, BLEND)
