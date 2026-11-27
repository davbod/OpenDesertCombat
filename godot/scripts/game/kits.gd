## Kits — infantry kit definitions shared by the deploy menu, MatchManager and PlayerController.

class_name Kits
extends RefCounted

const ALL: Array[Dictionary] = [
	{"id": 0, "name": "Assault",  "weapon": "Assault Rifle + Grenades", "health": 100.0, "speed": 1.0,  "color": Color(0.2, 0.6, 1.0)},
	{"id": 1, "name": "Engineer", "weapon": "SMG + AT Mines",           "health": 85.0,  "speed": 1.05, "color": Color(0.9, 0.7, 0.1)},
	{"id": 2, "name": "Medic",    "weapon": "LMG + Medkits",            "health": 110.0, "speed": 0.9,  "color": Color(0.2, 0.85, 0.3)},
	{"id": 3, "name": "Sniper",   "weapon": "Sniper Rifle + C4",        "health": 75.0,  "speed": 1.1,  "color": Color(0.7, 0.3, 0.9)},
]


static func is_valid(kit_id: int) -> bool:
	return kit_id >= 0 and kit_id < ALL.size()


static func get_kit(kit_id: int) -> Dictionary:
	return ALL[kit_id] if is_valid(kit_id) else ALL[0]
