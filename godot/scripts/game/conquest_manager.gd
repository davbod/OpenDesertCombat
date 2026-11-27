## Conquest Game Mode Manager
## Manages capture points, team tickets, and win/loss conditions.
## Team ids come from `Teams` (USMC = 1, OPFOR = 2).

extends Node
class_name ConquestManager

signal ticket_updated(team: int, tickets: int)
signal point_captured(point_name: String, team: int)
signal game_over(winning_team: int)

## --- Configuration ---
@export var starting_tickets: int = 300
@export var bleed_rate: float = 1.0  ## Tickets lost per second when the enemy holds every flag
@export var kill_ticket_cost: int = 1  ## Tickets a team loses each time one of its soldiers dies

## --- State ---
var tickets: Dictionary = { Teams.USMC: 300, Teams.OPFOR: 300 }
var capture_points: Array[CapturePoint] = []
var bleed_timer: float = 0.0
var game_active: bool = true


func _ready() -> void:
	tickets[Teams.USMC] = starting_tickets
	tickets[Teams.OPFOR] = starting_tickets
	for node in get_tree().get_nodes_in_group(CapturePoint.GROUP):
		var point := node as CapturePoint
		if point:
			capture_points.append(point)
			point.captured.connect(_on_point_captured)


func _process(delta: float) -> void:
	if not game_active:
		return

	bleed_timer += delta
	if bleed_timer >= 1.0:
		bleed_timer -= 1.0
		_apply_ticket_bleed()
		_check_game_over()


func count_points(team: int) -> int:
	var n := 0
	for point in capture_points:
		if point.owning_team == team:
			n += 1
	return n


func _apply_ticket_bleed() -> void:
	var total := capture_points.size()
	if total == 0:
		return
	var usmc_points := count_points(Teams.USMC)
	var opfor_points := count_points(Teams.OPFOR)

	# The team holding fewer flags bleeds, faster the bigger the gap
	if usmc_points > opfor_points:
		_remove_tickets(Teams.OPFOR, ceili(bleed_rate * float(usmc_points - opfor_points) / total))
	elif opfor_points > usmc_points:
		_remove_tickets(Teams.USMC, ceili(bleed_rate * float(opfor_points - usmc_points) / total))


## Called whenever a soldier dies (any cause). Costs their team a ticket.
func on_player_killed(victim_team: int) -> void:
	if not game_active or not tickets.has(victim_team):
		return
	_remove_tickets(victim_team, kill_ticket_cost)
	_check_game_over()


func _remove_tickets(team: int, amount: int) -> void:
	tickets[team] = maxi(0, int(tickets[team]) - amount)
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
