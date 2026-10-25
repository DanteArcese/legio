extends RefCounted
## Turns what the player is wearing into a KayKit character appearance:
## body armour picks the outfit, headgear shows a helmet or hood, and the
## weapon and shield go in the hands.
##
## The pack has no bow or sling, so bows show the hand crossbow and slings
## leave the hand empty (thrown animation).

const BODIES := {
	"": "adventurers/Rogue", "bronze_lorica": "adventurers/Knight", "iron_lorica": "adventurers/Knight",
	"ritual_robe": "adventurers/Mage",
}
## item -> [model, attack style]
const WEAPONS := {
	"bronze_pugio": ["weapons/dagger", "stab"], "iron_pugio": ["weapons/dagger", "stab"],
	"bronze_gladius": ["weapons/sword_1handed", "slash"], "iron_gladius": ["weapons/sword_1handed", "slash"],
	"hunting_bow": ["weapons/crossbow_1handed", "ranged"], "composite_bow": ["weapons/crossbow_1handed", "ranged"],
	"sling": ["", "throw"], "lituus": ["weapons/staff", "ritus"],
}
const SHIELDS := {"bronze_scutum": "weapons/shield_square", "iron_scutum": "weapons/shield_square"}
## Meshes each outfit hides unless the matching headgear is worn.
const HEADGEAR := {
	"adventurers/Knight": ["Knight_Helmet", ["bronze_galea", "iron_galea"]],
	"adventurers/Mage": ["Mage_Hat", ["ritual_hood"]],
}


static func appearance(worn: Dictionary) -> Dictionary:
	var body: String = BODIES.get(worn.get("body", ""), BODIES[""])
	var weapon: Array = WEAPONS.get(worn.get("weapon", ""), ["", "unarmed"])
	var look := {
		"scene": body, "size": 1.0, "weapon": weapon[0], "attack": weapon[1],
		"shield": SHIELDS.get(worn.get("shield", ""), ""), "hide": [], "show": [],
	}
	# Legionary red instead of the pack's green and blue cloth (robes stay dark).
	if body != BODIES["ritual_robe"]:
		look["recolor"] = {"from": [0.15, 0.75], "to": 0.0}
	if HEADGEAR.has(body):
		var mesh: String = HEADGEAR[body][0]
		look["show" if worn.get("head", "") in HEADGEAR[body][1] else "hide"].append(mesh)
	return look


## A short key that changes whenever the look would.
static func key(worn: Dictionary) -> String:
	return "%s|%s|%s|%s" % [worn.get("body", ""), worn.get("head", ""), worn.get("weapon", ""), worn.get("shield", "")]
