## Teams — single source of truth for team ids, names, colours and the friendly-fire rule.
## Team ids are plain ints so they serialise cleanly for bots and network peers later.
## Any actor with a `team: int` property takes part: players report their own team,
## vehicles report their crew's team (NONE when empty).

class_name Teams
extends RefCounted

const NONE: int = 0
const USMC: int = 1  ## Blue
const OPFOR: int = 2  ## Red
const PLAYABLE: Array[int] = [USMC, OPFOR]

## When false, damage between two members of the same team is ignored.
## Self-damage (including to the vehicle you're in) and damage with no attacker (crashes,
## falls) always apply.
static var friendly_fire: bool = false


static func name_of(team: int) -> String:
	match team:
		USMC:
			return "USMC"
		OPFOR:
			return "OPFOR"
	return "NEUTRAL"


static func color_of(team: int) -> Color:
	match team:
		USMC:
			return Color(0.2, 0.45, 0.9)
		OPFOR:
			return Color(0.85, 0.2, 0.2)
	return Color(0.9, 0.9, 0.9)


## Lighter tint of the team colour, readable as text on dark UI.
static func ui_color_of(team: int) -> Color:
	match team:
		USMC:
			return Color(0.35, 0.65, 1.0)
		OPFOR:
			return Color(1.0, 0.35, 0.35)
	return Color(0.9, 0.9, 0.9)


static func enemy_of(team: int) -> int:
	match team:
		USMC:
			return OPFOR
		OPFOR:
			return USMC
	return NONE


## Team of any actor, or NONE if it has no team / is freed / is null.
static func of(node: Object) -> int:
	if node == null or not is_instance_valid(node):
		return NONE
	if "team" in node:
		return int(node.get("team"))
	return NONE


## True when this hit should be ignored because both sides are on the same team.
## A vehicle counts as its occupant, so your own rockets or bombs still hurt the vehicle you're in.
static func is_friendly_fire(attacker: Object, victim: Object) -> bool:
	if friendly_fire or attacker == null or victim == null or attacker == victim:
		return false
	if is_instance_valid(victim) and "occupant" in victim and victim.get("occupant") == attacker:
		return false
	var attacker_team := of(attacker)
	return attacker_team != NONE and attacker_team == of(victim)
