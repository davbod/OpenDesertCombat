## MatchManager — the authority for who is in the match, where they may spawn, and the score.
## Clients *request* (join, spawn); MatchManager validates and acts. Today the only client is
## the local PlayerController; bots (Sprint 5) and network peers (Sprint 6) use the same calls.
##
## - Participant registry: id, name, team, kit, kills, deaths, score.
## - Deaths: costs the victim's team a ticket (ConquestManager), credits the killer.
## - Spawning: respawn timer per participant, spawn points owned by the requested team only.
## - Flags: soldiers on a flag when it is captured or neutralised score for it.

extends Node
class_name MatchManager

signal participant_joined(participant: Participant)
signal participant_spawned(participant: Participant)
signal participant_died(participant: Participant, killer: Participant)
signal score_changed(participant: Participant)

const SCORE_KILL: int = 10
const SCORE_TEAMKILL: int = -20
const SCORE_CAPTURE: int = 20
const SCORE_NEUTRALISE: int = 10

@export var respawn_time: float = 10.0  ## Seconds after death before a soldier may deploy again

var participants: Dictionary = {}  # id -> Participant
var match_time: float = 0.0  ## Seconds since the match started (physics clock)

var _next_id: int = 1
var _conquest: ConquestManager = null


func _ready() -> void:
	_conquest = get_tree().root.find_child("ConquestManager", true, false) as ConquestManager
	for node in get_tree().get_nodes_in_group(CapturePoint.GROUP):
		var point := node as CapturePoint
		if point:
			point.captured.connect(_on_flag_changed.bind(point))


func _physics_process(delta: float) -> void:
	match_time += delta


## --- Registry ---

## Adds a soldier to the match. The actor is assumed alive and already placed in the world.
func register(actor: Node3D, display_name: String, team: int, is_local: bool = false) -> Participant:
	var existing := participant_for(actor)
	if existing:
		return existing
	var p := Participant.new()
	p.id = _next_id
	_next_id += 1
	p.display_name = display_name
	p.team = team
	p.actor = actor
	p.is_local = is_local
	p.kit_id = int(actor.get("active_kit_id")) if "active_kit_id" in actor else 0
	participants[p.id] = p
	var hc := actor.find_child("HealthComponent", true, false) as HealthComponent
	if hc:
		hc.died.connect(_on_actor_died.bind(p))
	participant_joined.emit(p)
	return p


func get_participant(id: int) -> Participant:
	return participants.get(id)


## The participant behind any node: their own actor, or the crew of a vehicle.
func participant_for(node: Object) -> Participant:
	if node == null or not is_instance_valid(node):
		return null
	for p: Participant in participants.values():
		if p.actor == node:
			return p
	if "occupant" in node:
		var occupant: Object = node.get("occupant")
		if occupant and occupant != node:
			return participant_for(occupant)
	return null


func get_team_participants(team: int) -> Array[Participant]:
	var result: Array[Participant] = []
	for p: Participant in participants.values():
		if p.team == team:
			result.append(p)
	return result


## --- Spawning ---

func get_spawn_points(team: int) -> Array[SpawnPoint]:
	var result: Array[SpawnPoint] = []
	if team == Teams.NONE:
		return result
	for node in get_tree().get_nodes_in_group(SpawnPoint.GROUP):
		var spawn := node as SpawnPoint
		if spawn and spawn.get_team() == team:
			result.append(spawn)
	return result


func time_until_spawn(p: Participant) -> float:
	if p == null or p.alive:
		return 0.0
	return maxf(0.0, p.death_time + respawn_time - match_time)


## Why a spawn request would fail right now, or "" if it would succeed.
func validate_spawn(p: Participant, team: int, kit_id: int, spawn: SpawnPoint) -> String:
	if p == null or not participants.has(p.id):
		return "Not in the match"
	if p.alive:
		return "Already deployed"
	if not (team in Teams.PLAYABLE):
		return "Pick a team"
	if not Kits.is_valid(kit_id):
		return "Pick a kit"
	if spawn == null or not is_instance_valid(spawn):
		return "Pick a spawn point"
	if spawn.get_team() != team:
		return "%s is not held by %s" % [spawn.get_display_name(), Teams.name_of(team)]
	if time_until_spawn(p) > 0.0:
		return "Wait %d s" % ceili(time_until_spawn(p))
	return ""


## Deploys a dead participant if the request is valid. Returns "" on success, else the reason.
func request_spawn(p: Participant, team: int, kit_id: int, spawn: SpawnPoint) -> String:
	var reason := validate_spawn(p, team, kit_id, spawn)
	if not reason.is_empty():
		return reason
	p.team = team
	p.kit_id = kit_id
	p.alive = true
	if p.actor and is_instance_valid(p.actor) and p.actor.has_method("spawn_at"):
		p.actor.call("spawn_at", spawn.get_spawn_transform(), team, kit_id)
	participant_spawned.emit(p)
	return ""


## --- Deaths & score ---

func _on_actor_died(attacker: Node3D, victim: Participant) -> void:
	if not victim.alive:
		return
	victim.alive = false
	victim.deaths += 1
	victim.death_time = match_time

	var killer := participant_for(attacker)
	if killer and killer != victim:
		if killer.team != victim.team:
			killer.kills += 1
			_add_score(killer, SCORE_KILL)
		else:
			_add_score(killer, SCORE_TEAMKILL)
	else:
		killer = null  # suicide, crash or unknown
	score_changed.emit(victim)

	if _conquest:
		_conquest.on_player_killed(victim.team)
	participant_died.emit(victim, killer)


func _on_flag_changed(_point_name: String, new_team: int, point: CapturePoint) -> void:
	# Captured → the new owner's soldiers on the flag score; neutralised → the attackers score
	var points := SCORE_CAPTURE
	var scoring_team := new_team
	if new_team == Teams.NONE:
		points = SCORE_NEUTRALISE
		var counts := point.get_team_counts()
		scoring_team = Teams.USMC if counts[Teams.USMC] > counts[Teams.OPFOR] else Teams.OPFOR
	for body in point.get_bodies():
		if Teams.of(body) != scoring_team:
			continue
		var p := participant_for(body)
		if p and p.alive:
			_add_score(p, points)


func _add_score(p: Participant, amount: int) -> void:
	p.score += amount
	score_changed.emit(p)
