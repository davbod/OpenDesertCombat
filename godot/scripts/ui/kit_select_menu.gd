## KitSelectMenu — Full-screen deploy menu shown on player death: pick a team and a kit.
## Emits deploy_confirmed(team, kit_id) after the countdown; the caller handles the respawn.
## Interim screen until the Sprint 4.3 deploy screen (team → kit → spawn point on a map).

extends Control
class_name KitSelectMenu

signal deploy_confirmed(team: int, kit_id: int)

## Kit definitions: id, display name, weapon, health multiplier
const KITS: Array[Dictionary] = [
	{"id": 0, "name": "Assault",   "weapon": "M4A1 + Grenades",   "health": 100.0, "speed": 1.0,  "color": Color(0.2, 0.6, 1.0)},
	{"id": 1, "name": "Engineer",  "weapon": "MP5 + AT Mines",     "health": 85.0,  "speed": 1.05, "color": Color(0.9, 0.7, 0.1)},
	{"id": 2, "name": "Medic",     "weapon": "M60 + Medkits",      "health": 110.0, "speed": 0.9,  "color": Color(0.2, 0.85, 0.3)},
	{"id": 3, "name": "Sniper",    "weapon": "M24 + C4",           "health": 75.0,  "speed": 1.1,  "color": Color(0.7, 0.3, 0.9)},
]

@export var spawn_countdown: float = 5.0

var selected_team: int = Teams.USMC
var selected_kit: int = 0
var _countdown: float = 0.0
var _counting_down: bool = false
var _team_buttons: Dictionary = {}  # team id -> Button
var _kit_buttons: Array[Button] = []

@onready var title_label: Label = %TitleLabel
@onready var team_buttons: HBoxContainer = %TeamButtons
@onready var kit_buttons: HBoxContainer = %KitButtons
@onready var kit_name_label: Label = %KitNameLabel
@onready var kit_weapon_label: Label = %KitWeaponLabel
@onready var countdown_label: Label = %CountdownLabel
@onready var confirm_button: Button = %ConfirmButton


func _ready() -> void:
	hide()
	_populate_team_buttons()
	_populate_kit_buttons()


func show_menu(current_team: int = Teams.USMC, current_kit: int = 0) -> void:
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_counting_down = false
	_countdown = 0.0
	countdown_label.text = ""
	confirm_button.disabled = false
	select_team(current_team if current_team in Teams.PLAYABLE else Teams.USMC)
	select_kit(current_kit)


func _populate_team_buttons() -> void:
	for child in team_buttons.get_children():
		child.queue_free()
	var group := ButtonGroup.new()
	for team in Teams.PLAYABLE:
		var btn := Button.new()
		btn.text = Teams.name_of(team)
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(180, 48)
		btn.add_theme_color_override("font_color", Teams.ui_color_of(team))
		btn.add_theme_color_override("font_pressed_color", Teams.ui_color_of(team))
		btn.pressed.connect(select_team.bind(team))
		team_buttons.add_child(btn)
		_team_buttons[team] = btn


func _populate_kit_buttons() -> void:
	for child in kit_buttons.get_children():
		child.queue_free()
	_kit_buttons.clear()
	var group := ButtonGroup.new()
	for kit in KITS:
		var btn := Button.new()
		btn.text = kit["name"] as String
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(140, 60)
		btn.pressed.connect(select_kit.bind(kit["id"] as int))
		kit_buttons.add_child(btn)
		_kit_buttons.append(btn)


func select_team(team: int) -> void:
	selected_team = team
	var btn: Button = _team_buttons.get(team)
	if btn:
		btn.set_pressed_no_signal(true)
	title_label.text = "DEPLOY — %s" % Teams.name_of(team)
	title_label.add_theme_color_override("font_color", Teams.ui_color_of(team))


func select_kit(kit_id: int) -> void:
	selected_kit = clampi(kit_id, 0, KITS.size() - 1)
	if selected_kit < _kit_buttons.size():
		_kit_buttons[selected_kit].set_pressed_no_signal(true)
	var kit: Dictionary = KITS[selected_kit]
	kit_name_label.text = kit["name"] as String
	kit_weapon_label.text = "Weapon: %s" % (kit["weapon"] as String)


func _on_confirm_pressed() -> void:
	confirm_button.disabled = true
	_counting_down = true
	_countdown = spawn_countdown


func _process(delta: float) -> void:
	if not _counting_down:
		return
	_countdown -= delta
	countdown_label.text = "Spawning in %d…" % ceili(_countdown)
	if _countdown <= 0.0:
		_counting_down = false
		hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		deploy_confirmed.emit(selected_team, selected_kit)


func get_kit_data(kit_id: int) -> Dictionary:
	return KITS[kit_id] if kit_id >= 0 and kit_id < KITS.size() else KITS[0]
