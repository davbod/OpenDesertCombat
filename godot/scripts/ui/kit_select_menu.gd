## KitSelectMenu — full-screen deploy menu shown on death: team → kit → spawn point.
## It only *asks*: deploy_requested(team, kit_id, spawn_point) goes to the PlayerController, which
## forwards it to MatchManager. The owner calls close() on success or report_spawn_failed(reason).
## Pressing DEPLOY during the respawn timer queues the deploy for when the timer runs out.
## Interim screen until the Sprint 4.3 deploy screen with a map overview.

extends Control
class_name KitSelectMenu

signal deploy_requested(team: int, kit_id: int, spawn_point: SpawnPoint)

const SPAWN_REFRESH_INTERVAL: float = 0.5
const MESSAGE_TIME: float = 2.5
const ACCENT: Color = Color(1.0, 0.8, 0.3)

var selected_team: int = Teams.USMC
var selected_kit: int = 0
var selected_spawn: SpawnPoint = null

var _match: MatchManager = null
var _participant: Participant = null
var _deploy_queued: bool = false
var _refresh_in: float = 0.0
var _message: String = ""
var _message_left: float = 0.0
var _team_buttons: Dictionary = {}  # team id -> Button
var _kit_buttons: Array[Button] = []
var _spawn_buttons: Dictionary = {}  # SpawnPoint -> Button

@onready var title_label: Label = %TitleLabel
@onready var team_buttons: HBoxContainer = %TeamButtons
@onready var kit_buttons: HBoxContainer = %KitButtons
@onready var spawn_buttons: HBoxContainer = %SpawnButtons
@onready var kit_name_label: Label = %KitNameLabel
@onready var kit_weapon_label: Label = %KitWeaponLabel
@onready var countdown_label: Label = %CountdownLabel
@onready var confirm_button: Button = %ConfirmButton


func _ready() -> void:
	hide()
	_populate_team_buttons()
	_populate_kit_buttons()


func show_menu(match_manager: MatchManager, participant: Participant) -> void:
	_match = match_manager
	_participant = participant
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_deploy_queued = false
	_message = ""
	confirm_button.disabled = false
	countdown_label.text = ""
	var team := participant.team if participant and participant.team in Teams.PLAYABLE else Teams.USMC
	select_team(team)
	select_kit(participant.kit_id if participant else 0)


func close() -> void:
	_deploy_queued = false
	hide()


func report_spawn_failed(reason: String) -> void:
	_deploy_queued = false
	confirm_button.disabled = false
	_show_message(reason)
	_refresh_in = 0.0


## --- Selection ---

func select_team(team: int) -> void:
	if team != selected_team:
		selected_spawn = null
	selected_team = team
	_show_pressed(_team_buttons.values(), _team_buttons.get(team))
	title_label.text = "DEPLOY — %s" % Teams.name_of(team)
	title_label.add_theme_color_override("font_color", Teams.ui_color_of(team))
	_refresh_spawn_buttons()


func select_kit(kit_id: int) -> void:
	selected_kit = kit_id if Kits.is_valid(kit_id) else 0
	_show_pressed(_kit_buttons, _kit_buttons[selected_kit] if selected_kit < _kit_buttons.size() else null)
	var kit := Kits.get_kit(selected_kit)
	kit_name_label.text = kit["name"] as String
	kit_weapon_label.text = "Weapon: %s" % (kit["weapon"] as String)


func select_spawn(spawn: SpawnPoint) -> void:
	selected_spawn = spawn
	_show_pressed(_spawn_buttons.values(), _spawn_buttons.get(spawn))


func get_available_spawns() -> Array[SpawnPoint]:
	if _match:
		return _match.get_spawn_points(selected_team)
	return []


## --- Deploy ---

func _on_confirm_pressed() -> void:
	if not selected_spawn:
		_show_message("Pick a spawn point")
		return
	_deploy_queued = true
	confirm_button.disabled = true
	_try_deploy()


func _try_deploy() -> void:
	if not selected_spawn:
		report_spawn_failed("Pick a spawn point")
		return
	if _match and _match.time_until_spawn(_participant) > 0.0:
		return  # still waiting; _process retries
	deploy_requested.emit(selected_team, selected_kit, selected_spawn)


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_in -= delta
	if _refresh_in <= 0.0:
		_refresh_in = SPAWN_REFRESH_INTERVAL
		_refresh_spawn_buttons()
	if _message_left > 0.0:
		_message_left -= delta

	var wait := _match.time_until_spawn(_participant) if _match else 0.0
	if _deploy_queued and wait <= 0.0:
		_try_deploy()
		if not visible:
			return

	if _message_left > 0.0:
		countdown_label.text = _message
	elif _deploy_queued:
		var where := selected_spawn.get_display_name() if selected_spawn else "?"
		countdown_label.text = "Deploying at %s in %d…" % [where, ceili(wait)]
	elif wait > 0.0:
		countdown_label.text = "Deploy available in %d s" % ceili(wait)
	else:
		countdown_label.text = "Ready to deploy"


func _show_message(text: String) -> void:
	_message = text
	_message_left = MESSAGE_TIME
	countdown_label.text = text


## --- Buttons ---

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
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		_style_toggle(btn, Teams.ui_color_of(team))
		btn.pressed.connect(select_team.bind(team))
		team_buttons.add_child(btn)
		_team_buttons[team] = btn


func _populate_kit_buttons() -> void:
	for child in kit_buttons.get_children():
		child.queue_free()
	_kit_buttons.clear()
	var group := ButtonGroup.new()
	for kit in Kits.ALL:
		var btn := Button.new()
		btn.text = kit["name"] as String
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(140, 60)
		_style_toggle(btn, ACCENT)
		btn.pressed.connect(select_kit.bind(kit["id"] as int))
		kit_buttons.add_child(btn)
		_kit_buttons.append(btn)


## Rebuilds the spawn buttons when the set of held spawn points changes (flags flip while you wait).
func _refresh_spawn_buttons() -> void:
	var spawns := get_available_spawns()
	var unchanged := spawns.size() == _spawn_buttons.size()
	for spawn in spawns:
		if not _spawn_buttons.has(spawn):
			unchanged = false
	if not unchanged:
		for child in spawn_buttons.get_children():
			child.queue_free()
		_spawn_buttons.clear()
		var group := ButtonGroup.new()
		for spawn in spawns:
			var btn := Button.new()
			btn.text = spawn.get_display_name()
			btn.toggle_mode = true
			btn.button_group = group
			btn.custom_minimum_size = Vector2(120, 40)
			_style_toggle(btn, ACCENT)
			btn.pressed.connect(select_spawn.bind(spawn))
			spawn_buttons.add_child(btn)
			_spawn_buttons[spawn] = btn

	if selected_spawn and not spawns.has(selected_spawn):
		_show_message("%s was lost" % selected_spawn.get_display_name())
		selected_spawn = null
	if not selected_spawn and not spawns.is_empty():
		select_spawn(_default_spawn(spawns))
	elif selected_spawn:
		select_spawn(selected_spawn)


## set_pressed_no_signal() bypasses the ButtonGroup, so release the others by hand.
func _show_pressed(buttons: Array, selected: Variant) -> void:
	for b: Button in buttons:
		b.set_pressed_no_signal(b == selected)


## Selected toggle buttons get a tinted fill and a bright border, so the choice is obvious.
func _style_toggle(btn: Button, accent: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.35)
	sb.border_color = accent
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("hover_pressed", sb)
	btn.add_theme_color_override("font_hover_pressed_color", Color.WHITE)


## Prefer the team's main base (an uncapturable flag), else the first spawn point.
func _default_spawn(spawns: Array[SpawnPoint]) -> SpawnPoint:
	for spawn in spawns:
		if spawn.capture_point and not spawn.capture_point.capturable:
			return spawn
	return spawns[0]
