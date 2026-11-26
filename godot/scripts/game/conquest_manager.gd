## Conquest Game Mode Manager
## Manages capture points, team tickets, and win/loss conditions.

extends Node
class_name ConquestManager

signal ticket_updated(team: int, tickets: int)
signal point_captured(point_name: String, team: int)
signal game_over(winning_team: int)

## --- Configuration ---
@export var starting_tickets: int = 300
@export var bleed_rate: float = 1.0  ## Tickets lost per second when enemy holds majority
@export var kill_ticket_cost: int = 1  ## Tickets lost per kill

## --- Teams ---
enum Team { NONE = 0, USMC = 1, OPFOR = 2 }

## --- State ---
var tickets: Dictionary = { Team.USMC: 300, Team.OPFOR: 300 }
var capture_points: Array[CapturePoint] = []
var bleed_timer: float = 0.0
var game_active: bool = true


func _ready() -> void:
	tickets[Team.USMC] = starting_tickets
	tickets[Team.OPFOR] = starting_tickets
	# Find all capture points in the scene
	_find_capture_points(get_tree().root)


func _find_capture_points(node: Node) -> void:
	if node is CapturePoint:
		capture_points.append(node)
		node.captured.connect(_on_point_captured)
	for child in node.get_children():
		_find_capture_points(child)


func _process(delta: float) -> void:
	if not game_active:
		return

	bleed_timer += delta
	if bleed_timer >= 1.0:
		bleed_timer -= 1.0
		_apply_ticket_bleed()
		_check_game_over()


func _apply_ticket_bleed() -> void:
	var usmc_points = 0
	var opfor_points = 0
	for point in capture_points:
		if point.owning_team == Team.USMC:
			usmc_points += 1
		elif point.owning_team == Team.OPFOR:
			opfor_points += 1

	var total = capture_points.size()
	if total == 0:
		return

	# Team with fewer points bleeds tickets
	if usmc_points > opfor_points:
		var bleed = ceili(bleed_rate * (float(usmc_points - opfor_points) / total))
		tickets[Team.OPFOR] = maxi(0, tickets[Team.OPFOR] - bleed)
		ticket_updated.emit(Team.OPFOR, tickets[Team.OPFOR])
	elif opfor_points > usmc_points:
		var bleed = ceili(bleed_rate * (float(opfor_points - usmc_points) / total))
		tickets[Team.USMC] = maxi(0, tickets[Team.USMC] - bleed)
		ticket_updated.emit(Team.USMC, tickets[Team.USMC])


func on_player_killed(victim_team: int) -> void:
	if victim_team in tickets:
		tickets[victim_team] = maxi(0, tickets[victim_team] - kill_ticket_cost)
		ticket_updated.emit(victim_team, tickets[victim_team])
		_check_game_over()


func _check_game_over() -> void:
	if tickets[Team.USMC] <= 0:
		game_active = false
		game_over.emit(Team.OPFOR)
	elif tickets[Team.OPFOR] <= 0:
		game_active = false
		game_over.emit(Team.USMC)


func _on_point_captured(point_name: String, team: int) -> void:
	point_captured.emit(point_name, team)
