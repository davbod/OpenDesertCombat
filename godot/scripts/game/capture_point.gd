## Capture Point (Flag)
## An Area3D that tracks players and vehicles in its zone and moves ownership between teams.
## Progress runs from -1.0 (fully OPFOR) to +1.0 (fully USMC). Attackers must first drag an
## enemy flag back through 0 (neutralise it) before raising their own. Owned flags stay owned
## when nobody is near; a partly drained flag drifts back to its owner.

extends Area3D
class_name CapturePoint

signal captured(point_name: String, team: int)  ## team == Teams.NONE means neutralised

const GROUP: StringName = &"capture_points"

@export var point_name: String = "Alpha"
@export var capture_time: float = 10.0  ## Seconds for one soldier to swing progress by 1.0
@export var max_capture_multiplier: int = 4  ## Extra attackers speed capture up to this factor
@export_enum("Neutral", "USMC", "OPFOR") var initial_team: int = 0
@export var capturable: bool = true  ## false for main-base flags that can never change hands
@export var flag_mesh: MeshInstance3D  ## Flag banner mesh
@export var flag_low_height: float = 1.5  ## Banner height (local) when fully lowered

## State
var owning_team: int = Teams.NONE
var capture_progress: float = 0.0  ## -1.0 (OPFOR) to 1.0 (USMC)

var _bodies: Array[Node3D] = []
var _flag_material: StandardMaterial3D
var _flag_high_height: float = 9.0
var _shown_team: int = -1


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	owning_team = initial_team
	capture_progress = _rest_progress(owning_team)
	if flag_mesh:
		_flag_high_height = flag_mesh.position.y
		_flag_material = StandardMaterial3D.new()
		flag_mesh.material_override = _flag_material
	_update_flag_visual()


func _on_body_entered(body: Node3D) -> void:
	if (body is PlayerController or body.has_method("enter_vehicle")) and not _bodies.has(body):
		_bodies.append(body)


func _on_body_exited(body: Node3D) -> void:
	_bodies.erase(body)


func _physics_process(delta: float) -> void:
	if not capturable:
		return
	var counts := get_team_counts()
	var diff: int = clampi(counts[Teams.USMC] - counts[Teams.OPFOR], -max_capture_multiplier, max_capture_multiplier)
	var step := delta / capture_time
	if diff != 0:
		capture_progress = clampf(capture_progress + step * diff, -1.0, 1.0)
	elif counts[Teams.USMC] == 0:
		# Nobody here: drift back to the owner's full height (or to neutral)
		capture_progress = move_toward(capture_progress, _rest_progress(owning_team), step * 0.5)
	# else: equal numbers from both teams — contested, progress holds

	_update_owner()
	_update_flag_visual()


## Living soldiers per team inside the zone. Occupied vehicles count once for their crew's team;
## dead players and empty vehicles don't count.
func get_team_counts() -> Dictionary:
	var counts := {Teams.USMC: 0, Teams.OPFOR: 0}
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		if body is PlayerController and not (body as PlayerController).is_alive():
			continue
		var team := Teams.of(body)
		if counts.has(team):
			counts[team] += 1
	return counts


func has_body(body: Node3D) -> bool:
	return body != null and _bodies.has(body)


func _update_owner() -> void:
	var new_owner := owning_team
	if capture_progress >= 1.0:
		new_owner = Teams.USMC
	elif capture_progress <= -1.0:
		new_owner = Teams.OPFOR
	elif owning_team == Teams.USMC and capture_progress <= 0.0:
		new_owner = Teams.NONE
	elif owning_team == Teams.OPFOR and capture_progress >= 0.0:
		new_owner = Teams.NONE

	if new_owner != owning_team:
		owning_team = new_owner
		captured.emit(point_name, owning_team)


func _rest_progress(team: int) -> float:
	match team:
		Teams.USMC:
			return 1.0
		Teams.OPFOR:
			return -1.0
	return 0.0


## Banner height follows progress; colour is the owner's, or the team raising a neutral flag.
func _update_flag_visual() -> void:
	if not flag_mesh or not _flag_material:
		return
	flag_mesh.position.y = lerpf(flag_low_height, _flag_high_height, absf(capture_progress))
	var shown := owning_team
	if shown == Teams.NONE:
		if capture_progress > 0.0:
			shown = Teams.USMC
		elif capture_progress < 0.0:
			shown = Teams.OPFOR
	if shown != _shown_team:
		_shown_team = shown
		_flag_material.albedo_color = Teams.color_of(shown)
