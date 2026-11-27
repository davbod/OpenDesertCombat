## Conquest Game Mode Manager
## Manages capture points, team tickets, and win/loss conditions.
## Team ids come from `Teams` (USMC = 1, OPFOR = 2).
##
## Ticket bleed: the team holding fewer flags loses
##   bleed_rate × flag_difference / total_flags   tickets per second,
## accumulated as a fraction per team; whole tickets come off as the fraction crosses 1.
## On the test map (4 flags, 2 of them uncapturable bases) the default bleed_rate of 2.0
## bleeds 1 ticket/s at full control (300 tickets ≈ 5 min) and 0.5 ticket/s with a
## one-flag lead (≈ 10 min).

extends Node
class_name ConquestManager

signal ticket_updated(team: int, tickets: int)  ## Only when a team's whole ticket count changes
signal point_captured(point_name: String, team: int)
signal game_over(winning_team: int)

## --- Configuration ---
@export var starting_tickets: int = 300
@export var bleed_rate: float = 2.0  ## Tickets per second lost while the enemy holds every flag; scaled by flag_difference / total_flags
@export var kill_ticket_cost: int = 1  ## Tickets a team loses each time one of its soldiers dies

## --- State ---
var tickets: Dictionary = { Teams.USMC: 300, Teams.OPFOR: 300 }
var capture_points: Array[CapturePoint] = []
var game_active: bool = true

var _bleed_accumulator: Dictionary = { Teams.USMC: 0.0, Teams.OPFOR: 0.0 }  ## Fraction of a ticket bled but not yet removed


func _ready() -> void:
	tickets[Teams.USMC] = starting_tickets
	tickets[Teams.OPFOR] = starting_tickets
	for node in get_tree().get_nodes_in_group(CapturePoint.GROUP):
		var point := node as CapturePoint
		if point:
			capture_points.append(point)
			point.captured.connect(_on_point_captured)


func _physics_process(delta: float) -> void:
	if not game_active:
		return
	_apply_ticket_bleed(delta)
	_check_game_over()


func count_points(team: int) -> int:
	var n := 0
	for point in capture_points:
		if point.owning_team == team:
			n += 1
	return n


## Tickets per second `team` is losing right now because the enemy holds more flags.
func get_bleed_per_second(team: int) -> float:
	var total := capture_points.size()
	var deficit := count_points(Teams.enemy_of(team)) - count_points(team)
	if total == 0 or deficit <= 0:
		return 0.0
	return bleed_rate * float(deficit) / float(total)


func _apply_ticket_bleed(delta: float) -> void:
	for team: int in Teams.PLAYABLE:
		var rate := get_bleed_per_second(team)
		if rate <= 0.0:
			continue
		var accumulated: float = _bleed_accumulator[team] + rate * delta
		var whole := floori(accumulated + 1e-6)  # so 120 × (1/120) s is a whole ticket, not 0.99999…
		_bleed_accumulator[team] = maxf(0.0, accumulated - whole)
		if whole > 0:
			_remove_tickets(team, whole)


## Called whenever a soldier dies (any cause). Costs their team a ticket.
func on_player_killed(victim_team: int) -> void:
	if not game_active or not tickets.has(victim_team):
		return
	_remove_tickets(victim_team, kill_ticket_cost)
	_check_game_over()


func _remove_tickets(team: int, amount: int) -> void:
	var before: int = tickets[team]
	tickets[team] = maxi(0, before - amount)
	if tickets[team] != before:
		ticket_updated.emit(team, tickets[team])


func _check_game_over() -> void:
	if not game_active:
		return
	if tickets[Teams.USMC] <= 0:
		game_active = false
		game_over.emit(Teams.OPFOR)
	elif tickets[Teams.OPFOR] <= 0:
		game_active = false
		game_over.emit(Teams.USMC)


func _on_point_captured(point_name: String, team: int) -> void:
	point_captured.emit(point_name, team)
