## Capture Point (Flag)
## An Area3D that tracks nearby players/vehicles and transitions ownership between teams.

extends Area3D
class_name CapturePoint

signal captured(point_name: String, team: int)

@export var point_name: String = "Alpha"
@export var capture_time: float = 10.0  ## Seconds to capture with one player
@export var flag_mesh: MeshInstance3D  ## Flag banner mesh

## State
var owning_team: int = 0  # ConquestManager.Team.NONE
var capture_progress: float = 0.0  ## -1.0 (OPFOR) to 1.0 (USMC)
var bodies_in_zone: Dictionary = {}  # node -> team


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_flag_visual()


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		bodies_in_zone[body] = 1  # Default to USMC for now
	elif "is_occupied" in body and body.is_occupied:
		bodies_in_zone[body] = 1


func _on_body_exited(body: Node3D) -> void:
	bodies_in_zone.erase(body)


func _process(delta: float) -> void:
	var usmc_count := 0
	var opfor_count := 0
	for body in bodies_in_zone:
		if "is_occupied" in body and not body.is_occupied:
			continue
		if bodies_in_zone[body] == 1:
			usmc_count += 1
		elif bodies_in_zone[body] == 2:
			opfor_count += 1

	var capture_speed := delta / capture_time
	if usmc_count > opfor_count:
		capture_progress = minf(capture_progress + capture_speed * (usmc_count - opfor_count), 1.0)
	elif opfor_count > usmc_count:
		capture_progress = maxf(capture_progress - capture_speed * (opfor_count - usmc_count), -1.0)
	else:
		capture_progress = move_toward(capture_progress, 0.0, capture_speed * 0.5)

	var new_owner := owning_team
	if capture_progress >= 1.0:
		new_owner = 1  # USMC
	elif capture_progress <= -1.0:
		new_owner = 2  # OPFOR
	elif absf(capture_progress) < 0.1:
		new_owner = 0  # Neutral

	if new_owner != owning_team:
		owning_team = new_owner
		captured.emit(point_name, owning_team)
		_update_flag_visual()


func _update_flag_visual() -> void:
	if not flag_mesh:
		return
	var mat := StandardMaterial3D.new()
	match owning_team:
		0: mat.albedo_color = Color(0.9, 0.9, 0.9)
		1: mat.albedo_color = Color(0.2, 0.45, 0.9)  # Blue for USMC
		2: mat.albedo_color = Color(0.85, 0.2, 0.2)  # Red for OPFOR
	flag_mesh.material_override = mat
