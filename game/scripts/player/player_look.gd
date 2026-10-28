extends RefCounted
## Turns what the player is wearing into a KayKit character appearance:
## body armour picks the outfit, headgear shows a helmet or hood, and the
## weapon and shield go in the hands.
##
## The pack has no bow or sling, so those are built in code (prop_models.gd).

const BODIES := {
	"": "adventurers/Rogue", "bronze_lorica": "adventurers/Knight", "iron_lorica": "adventurers/Knight", "steel_lorica": "adventurers/Knight", "lorica_hamata": "adventurers/Knight", "lorica_segmentata": "adventurers/Knight",
	"ritual_robe": "adventurers/Mage", "leather_jerkin": "adventurers/Rogue", "wolfskin_jerkin": "adventurers/Barbarian",
}
## item -> [model, attack style]
const WEAPONS := {
	"bronze_pugio": ["weapons/dagger", "stab"], "iron_pugio": ["weapons/dagger", "stab"], "steel_pugio": ["weapons/dagger", "stab"],
	"bronze_gladius": ["weapons/sword_1handed", "slash"], "iron_gladius": ["weapons/sword_1handed", "slash"],
	"steel_gladius": ["weapons/sword_1handed", "slash"],
	"spatha": ["weapons/sword_1handed", "slash"], "framea": ["proc:spear", "stab"],
	"hunting_bow": ["proc:bow", "bow"], "composite_bow": ["proc:bow_composite", "bow"],
	"sling": ["proc:sling", "throw"], "amentum": ["proc:spear", "throw"], "lituus": ["weapons/staff", "ritus"],
}
## Palette textures baked with tools/bake_palette.gd (green and blue to red).
const LEGION_TEXTURES := {
	"adventurers/Rogue": "res://assets/kaykit/adventurers/rogue_texture_legion.png",
	"adventurers/Knight": "res://assets/kaykit/adventurers/knight_texture_legion.png",
}
const SHIELDS := {"bronze_scutum": "weapons/shield_square", "iron_scutum": "weapons/shield_square", "steel_scutum": "weapons/shield_square", "parma": "weapons/shield_round",
	"mirror_shield": "weapons/shield_round", "aegis": "weapons/shield_round"}
## Meshes each outfit hides unless the matching headgear is worn.
const HEADGEAR := {
	"adventurers/Knight": ["Knight_Helmet", ["bronze_galea", "iron_galea", "steel_galea"]],
	"adventurers/Mage": ["Mage_Hat", ["ritual_hood"]],
	"adventurers/Barbarian": ["Barbarian_Hat", ["wolfskin_hood", "venators_helm"]],
}


static func appearance(worn: Dictionary) -> Dictionary:
	var body: String = BODIES.get(worn.get("body", ""), BODIES[""])
	var weapon: Array = WEAPONS.get(worn.get("weapon", ""), ["", "unarmed"])
	var look := {
		"scene": body, "size": 1.0, "weapon": weapon[0], "attack": weapon[1],
		"shield": SHIELDS.get(worn.get("shield", ""), ""), "hide": [], "show": [],
	}
	# Legionary red instead of the pack's green and blue cloth (robes stay dark).
	if LEGION_TEXTURES.has(body):
		look["texture"] = LEGION_TEXTURES[body]
	if HEADGEAR.has(body):
		var mesh: String = HEADGEAR[body][0]
		look["show" if worn.get("head", "") in HEADGEAR[body][1] else "hide"].append(mesh)
	return look


## A short key that changes whenever the look would.
static func key(worn: Dictionary) -> String:
	return "%s|%s|%s|%s" % [worn.get("body", ""), worn.get("head", ""), worn.get("weapon", ""), worn.get("shield", "")]
