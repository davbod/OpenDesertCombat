## HUD for OpenDesertCombat
## Displays team tickets, flag capture progress, crosshair, interact prompt, and vehicle telemetry.

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
@onready var capture_panel: Control = $CapturePanel if has_node("CapturePanel") else null
@onready var capture_label: Label = $CapturePanel/CaptureLabel if has_node("CapturePanel/CaptureLabel") else null
@onready var capture_bar: ProgressBar = $CapturePanel/CaptureBar if has_node("CapturePanel/CaptureBar") else null

var conquest_manager: ConquestManager
var local_player: PlayerController = null

var _tickets: Dictionary = { Teams.USMC: 0, Teams.OPFOR: 0 }
var _shown_local_team: int = -1
var _capture_fill: StyleBoxFlat


func _ready() -> void:
	conquest_manager = get_tree().root.find_child("ConquestManager", true, false) as ConquestManager
	if conquest_manager:
		conquest_manager.ticket_updated.connect(_on_tickets_updated)
		conquest_manager.game_over.connect(_on_game_over)
		conquest_manager.point_captured.connect(_on_point_captured)
		for team in Teams.PLAYABLE:
			_tickets[team] = conquest_manager.tickets.get(team, 0)
	if capture_bar:
		_capture_fill = StyleBoxFlat.new()
		_capture_fill.bg_color = Teams.color_of(Teams.NONE)
		capture_bar.add_theme_stylebox_override("fill", _capture_fill)
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0, 0, 0, 0.55)
		capture_bar.add_theme_stylebox_override("background", back)
	if capture_panel:
		capture_panel.visible = false
	_refresh_ticket_labels()
	hide_vehicle_hud()


## Called by the PlayerController this HUD belongs to (may run before this node's _ready).
func set_local_player(player: PlayerController) -> void:
	local_player = player
	_shown_local_team = -1


func _get_local_team() -> int:
	return local_player.team if local_player and is_instance_valid(local_player) else Teams.NONE


func _process(_delta: float) -> void:
	if _get_local_team() != _shown_local_team:
		_refresh_ticket_labels()
	_update_capture_panel()


## --- Tickets ---

func _on_tickets_updated(team: int, tickets: int) -> void:
	_tickets[team] = tickets
	_refresh_ticket_labels()


func _refresh_ticket_labels() -> void:
	if not usmc_tickets_label or not opfor_tickets_label:
		return
	_shown_local_team = _get_local_team()
	for team in Teams.PLAYABLE:
		var label: Label = usmc_tickets_label if team == Teams.USMC else opfor_tickets_label
		var marker := "» " if team == _shown_local_team else ""
		label.text = "%s%s: %d" % [marker, Teams.name_of(team), _tickets.get(team, 0)]
		label.add_theme_color_override("font_color", Teams.ui_color_of(team))


## --- Flag capture ---

func _current_capture_point() -> CapturePoint:
	if not conquest_manager or not local_player or not is_instance_valid(local_player):
		return null
	if not local_player.is_alive():
		return null
	var body := local_player.get_presence_body()
	for point in conquest_manager.capture_points:
		if point.has_body(body):
			return point
	return null


func _update_capture_panel() -> void:
	if not capture_panel or not capture_label or not capture_bar:
		return
	var point := _current_capture_point()
	if point == null:
		capture_panel.visible = false
		return
	capture_panel.visible = true

	var my_team := _get_local_team()
	var counts := point.get_team_counts()
	var own: int = counts.get(my_team, 0)
	var enemy: int = counts.get(Teams.enemy_of(my_team), 0)
	var state := "CAPTURING"
	capture_bar.visible = point.capturable
	if not point.capturable:
		state = "HOME BASE" if point.owning_team == my_team else "CANNOT BE CAPTURED"
	elif own == enemy:
		state = "CONTESTED"
	elif own < enemy:
		state = "OUTNUMBERED"
	elif point.owning_team == my_team:
		state = "SECURED" if absf(point.capture_progress) >= 1.0 else "SECURING"
	elif point.owning_team != Teams.NONE:
		state = "NEUTRALISING"
	capture_label.text = "%s — %s" % [point.point_name.to_upper(), state]
	capture_bar.value = absf(point.capture_progress)

	var shown := point.owning_team
	if shown == Teams.NONE:
		if point.capture_progress > 0.0:
			shown = Teams.USMC
		elif point.capture_progress < 0.0:
			shown = Teams.OPFOR
	_capture_fill.bg_color = Teams.color_of(shown)


func _on_point_captured(point_name: String, team: int) -> void:
	if team == Teams.NONE:
		_show_message("%s NEUTRALISED" % point_name.to_upper(), Teams.ui_color_of(Teams.NONE), 3.0)
	else:
		_show_message("%s CAPTURED BY %s" % [point_name.to_upper(), Teams.name_of(team)], Teams.ui_color_of(team), 3.0)


func _on_game_over(winning_team: int) -> void:
	_show_message("%s WINS" % Teams.name_of(winning_team), Teams.ui_color_of(winning_team), 0.0)


## Shows a centred banner; duration <= 0 keeps it up.
func _show_message(text: String, color: Color, duration: float) -> void:
	if not center_message:
		return
	center_message.text = text
	center_message.add_theme_color_override("font_color", color)
	center_message.visible = true
	if duration > 0.0:
		get_tree().create_timer(duration).timeout.connect(func() -> void:
			if is_instance_valid(center_message) and center_message.text == text \
					and conquest_manager and conquest_manager.game_active:
				center_message.visible = false
		)


## --- Prompts & vehicle telemetry ---

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
