extends RefCounted
## Colours a monster's level by how it compares with the player's combat
## level, so a glance says whether a fight is safe: green when it's far
## below you, yellow for an even match, orange and red as it climbs above.

const FAR_BELOW := Color(0.45, 0.9, 0.4)
const BELOW := Color(0.7, 0.92, 0.45)
const EVEN := Color(1.0, 0.92, 0.45)
const ABOVE := Color(1.0, 0.65, 0.3)
const FAR_ABOVE := Color(1.0, 0.38, 0.32)


static func color_for(their_level: int, my_level: int) -> Color:
	var gap := their_level - my_level
	if gap >= 10:
		return FAR_ABOVE
	if gap >= 3:
		return ABOVE
	if gap > -3:
		return EVEN
	if gap > -10:
		return BELOW
	return FAR_BELOW
