## KitSelectMenu — Full-screen kit selection UI shown on player death.
## Signals kit_selected(kit_id) after the player picks and confirms a kit.
## Caller (PlayerController or GameManager) handles the actual respawn.

extends Control
class_name KitSelectMenu

signal kit_selected(kit_id: int)

## Kit definitions: id, display name, weapon, health multiplier
const KITS: Array[Dictionary] = [
	{"id": 0, "name": "Assault",   "weapon": "M4A1 + Grenades",   "health": 100.0, "speed": 1.0,  "color": Color(0.2, 0.6, 1.0)},
	{"id": 1, "name": "Engineer",  "weapon": "MP5 + AT Mines",     "health": 85.0,  "speed": 1.05, "color": Color(0.9, 0.7, 0.1)},
	{"id": 2, "name": "Medic",     "weapon": "M60 + Medkits",      "health": 110.0, "speed": 0.9,  "color": Color(0.2, 0.85, 0.3)},
	{"id": 3, "name": "Sniper",    "weapon": "M24 + C4",           "health": 75.0,  "speed": 1.1,  "color": Color(0.7, 0.3, 0.9)},
]

@export var spawn_countdown: float = 5.0

var _selected_kit: int = 0
var _countdown: float = 0.0
var _counting_down: bool = false

@onready var kit_buttons: HBoxContainer = %KitButtons
@onready var kit_name_label: Label = %KitNameLabel
@onready var kit_weapon_label: Label = %KitWeaponLabel
@onready var countdown_label: Label = %CountdownLabel
@onready var confirm_button: Button = %ConfirmButton


func _ready() -> void:
	hide()
	_populate_kit_buttons()


func show_menu() -> void:
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_counting_down = false
	_countdown = 0.0
	countdown_label.text = ""
	confirm_button.disabled = false
	_select_kit(0)


func _populate_kit_buttons() -> void:
	for child in kit_buttons.get_children():
		child.queue_free()
	for kit in KITS:
		var btn := Button.new()
		btn.text = kit["name"] as String
		btn.custom_minimum_size = Vector2(140, 60)
		btn.pressed.connect(_select_kit.bind(kit["id"] as int))
		kit_buttons.add_child(btn)


func _select_kit(kit_id: int) -> void:
	_selected_kit = kit_id
	var kit: Dictionary = KITS[kit_id]
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
		emit_signal("kit_selected", _selected_kit)


func get_kit_data(kit_id: int) -> Dictionary:
	return KITS[kit_id] if kit_id >= 0 and kit_id < KITS.size() else KITS[0]
