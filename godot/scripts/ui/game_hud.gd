## HUD for OpenDesertCombat
## Displays tickets, crosshair, interact prompt, and vehicle indicators.

extends CanvasLayer
class_name GameHUD

@onready var usmc_tickets_label: Label = $MarginContainer/TopBar/USMCTickets
@onready var opfor_tickets_label: Label = $MarginContainer/TopBar/OPFORTickets
@onready var center_message: Label = $CenterMessage
@onready var interact_prompt: Label = $InteractPrompt
@onready var crosshair: Label = $Crosshair
@onready var vehicle_indicator: Label = $VehiclePanel/VBox/VehicleIndicator
@onready var altitude_label: Label = $VehiclePanel/VBox/AltitudeDisplay
@onready var speed_label: Label = $VehiclePanel/VBox/SpeedDisplay
@onready var status_label: Label = $VehiclePanel/VBox/StatusDisplay if has_node("VehiclePanel/VBox/StatusDisplay") else null
@onready var vehicle_panel: PanelContainer = $VehiclePanel

var conquest_manager: ConquestManager


func _ready() -> void:
	conquest_manager = get_tree().root.find_child("ConquestManager", true, false) as ConquestManager
	if conquest_manager:
		conquest_manager.ticket_updated.connect(_on_tickets_updated)
		conquest_manager.game_over.connect(_on_game_over)
		conquest_manager.point_captured.connect(_on_point_captured)
		_on_tickets_updated(1, conquest_manager.tickets.get(1, 0))
		_on_tickets_updated(2, conquest_manager.tickets.get(2, 0))
	hide_vehicle_hud()


func _on_tickets_updated(team: int, tickets: int) -> void:
	if team == 1 and usmc_tickets_label:
		usmc_tickets_label.text = "USMC: %d" % tickets
	elif team == 2 and opfor_tickets_label:
		opfor_tickets_label.text = "OPFOR: %d" % tickets


func _on_point_captured(point_name: String, team: int) -> void:
	if center_message:
		var team_name := "NEUTRAL"
		if team == 1:
			team_name = "USMC"
		elif team == 2:
			team_name = "OPFOR"
		center_message.text = "%s CAPTURED BY %s" % [point_name.to_upper(), team_name]
		center_message.visible = true
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(center_message) and conquest_manager and conquest_manager.game_active:
				center_message.visible = false
		)


func _on_game_over(winning_team: int) -> void:
	if center_message:
		var team_name := "USMC" if winning_team == 1 else "OPFOR"
		center_message.text = "%s WINS" % team_name
		center_message.visible = true


func set_interact_prompt(text: String) -> void:
	if interact_prompt:
		interact_prompt.text = text
		interact_prompt.visible = not text.is_empty()


func update_vehicle_hud(vehicle_name: String, altitude: float, speed: float, status: String = "") -> void:
	if vehicle_panel:
		vehicle_panel.visible = true
	if vehicle_indicator:
		vehicle_indicator.text = vehicle_name
	if altitude_label:
		altitude_label.text = "ALT: %d m" % int(altitude)
	if speed_label:
		speed_label.text = "SPD: %d km/h" % int(speed * 3.6)
	if status_label:
		status_label.text = status
		status_label.visible = not status.is_empty()


func hide_vehicle_hud() -> void:
	if vehicle_panel:
		vehicle_panel.visible = false
