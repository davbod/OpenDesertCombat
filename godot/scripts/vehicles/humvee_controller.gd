## Ground Wheeled Vehicle Controller (Humvee / Desert Recon)
## Uses Godot's VehicleBody3D with Jolt Physics.

extends VehicleBody3D
class_name HumveeController

@export var vehicle_name: String = "HMMWV Desert Recon"
@export var max_engine_force: float = 3200.0
@export var max_brake_force: float = 80.0
@export var max_steer_angle: float = 0.45
@export var steer_speed: float = 3.5
@export var seat_positions: Array[Vector3] = [Vector3(-0.45, 0.65, -0.2)]
@export var chase_camera_offset: Vector3 = Vector3(0.0, 2.8, 7.5)

var is_occupied: bool = false
var team: int = Teams.NONE  ## Crew's team while occupied, NONE when empty
var occupant: Node3D = null  ## Driver/pilot while occupied
var current_steer: float = 0.0


func _physics_process(delta: float) -> void:
	if not is_occupied:
		engine_force = 0.0
		brake = 15.0
		steering = move_toward(steering, 0.0, steer_speed * delta)
		return

	var throttle := 0.0
	if Input.is_action_pressed("move_forward"):
		throttle = 1.0
	elif Input.is_action_pressed("move_backward"):
		throttle = -0.65

	var target_steer := 0.0
	if Input.is_action_pressed("move_left"):
		target_steer = max_steer_angle
	elif Input.is_action_pressed("move_right"):
		target_steer = -max_steer_angle

	current_steer = move_toward(current_steer, target_steer, steer_speed * delta)
	steering = current_steer

	if Input.is_action_pressed("jump"):
		engine_force = 0.0
		brake = max_brake_force
	else:
		brake = 0.0
		engine_force = throttle * max_engine_force


func enter_vehicle(player: Node3D) -> int:
	is_occupied = true
	team = Teams.of(player)
	occupant = player
	return 0


func exit_vehicle(_player: Node3D) -> void:
	is_occupied = false
	team = Teams.NONE
	occupant = null
	engine_force = 0.0
	brake = 15.0
