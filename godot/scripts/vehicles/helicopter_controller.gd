## Helicopter Flight Controller
## Attached to a RigidBody3D representing the helicopter fuselage.
## Implements 6-DOF flight: collective (thrust), cyclic (pitch/roll via mouse),
## tail rotor (yaw), with drag, ground effect, and stability augmentation.

extends RigidBody3D
class_name HelicopterController

## --- Tuning Parameters ---

@export_group("Engine")
@export var max_thrust: float = 85000.0  ## Maximum upward force in Newtons (~1.73 TWR at 5000 kg)
@export var engine_spool_rate: float = 1.2  ## How fast engine RPM responds (0-1 per second)
@export var idle_thrust_fraction: float = 0.42  ## Fraction of max thrust at idle collective

@export_group("Cyclic (Pitch & Roll)")
@export var pitch_torque: float = 65000.0  ## Nm of torque for pitch
@export var roll_torque: float = 55000.0  ## Nm of torque for roll
@export var cyclic_sensitivity: float = 0.015  ## Mouse sensitivity for cyclic input
@export var max_cyclic_deflection: float = 1.0  ## Max normalized cyclic input (-1 to 1)

@export_group("Tail Rotor (Yaw)")
@export var yaw_torque: float = 35000.0  ## Nm of torque for yaw

@export_group("Stability")
@export var angular_damping_factor: float = 1.4  ## Extra angular damping multiplier
@export var auto_level_strength: float = 4500.0  ## Torque applied to return to level flight
@export var auto_level_deadzone: float = 0.08  ## Radians before auto-level kicks in

@export_group("Aerodynamics")
@export var drag_coefficient: float = 0.35  ## Translational drag
@export var ground_effect_height: float = 15.0  ## Height at which ground effect applies
@export var ground_effect_multiplier: float = 1.25  ## Thrust multiplier at ground level

@export_group("Vehicle")
@export var vehicle_name: String = "Attack Helicopter"
@export var seat_positions: Array[Vector3] = [Vector3(0.0, 0.55, -1.6), Vector3(0.0, 0.8, -2.5)]
@export var chase_camera_offset: Vector3 = Vector3(0.0, 4.0, 13.0)
@export var is_occupied: bool = false
var team: int = Teams.NONE  ## Crew's team while occupied, NONE when empty
var occupant: Node3D = null  ## Driver/pilot while occupied

## --- State ---

var engine_power: float = 0.0  ## Current engine power (0.0 - 1.0)
var collective_input: float = 0.0  ## Current collective (-0.3 - 1.0)
var cyclic_pitch: float = 0.0  ## Current cyclic pitch input (-1 to 1)
var cyclic_roll: float = 0.0  ## Current cyclic roll input (-1 to 1)
var yaw_input: float = 0.0  ## Current yaw input (-1 to 1)
var altitude_agl: float = 0.0  ## Height above ground level

## Rotor & weapon visuals
var rotor_speed: float = 0.0
var fire_cooldown: float = 0.0
var next_pod_side: float = 1.0
var rocket_scene: PackedScene = preload("res://scenes/weapons/rocket_projectile.tscn")
@onready var rotor_node: Node3D = $RotorPivot if has_node("RotorPivot") else null
@onready var tail_rotor_node: Node3D = $TailRotorPivot if has_node("TailRotorPivot") else null


func _ready() -> void:
	mass = 5000.0
	gravity_scale = 1.0
	linear_damp = 0.1
	angular_damp = 0.5


func _unhandled_input(event: InputEvent) -> void:
	if not is_occupied:
		return

	# Mouse controls cyclic (pitch and roll)
	if event is InputEventMouseMotion:
		cyclic_pitch = clampf(cyclic_pitch + event.relative.y * cyclic_sensitivity, -max_cyclic_deflection, max_cyclic_deflection)
		cyclic_roll = clampf(cyclic_roll - event.relative.x * cyclic_sensitivity, -max_cyclic_deflection, max_cyclic_deflection)


func _physics_process(delta: float) -> void:
	_update_altitude()

	if not is_occupied:
		engine_power = move_toward(engine_power, 0.0, engine_spool_rate * 0.3 * delta)
		_update_rotor(delta)
		return

	# --- Read Inputs ---
	collective_input = 0.0
	if Input.is_action_pressed("heli_collective_up"):
		collective_input = 1.0
	elif Input.is_action_pressed("heli_collective_down"):
		collective_input = -0.35

	# Right-handed Y-up: +Y torque yaws nose left (-Z toward -X), -Y torque yaws nose right
	yaw_input = 0.0
	if Input.is_action_pressed("heli_yaw_left"):
		yaw_input = 1.0
	elif Input.is_action_pressed("heli_yaw_right"):
		yaw_input = -1.0

	# --- Engine Power ---
	var target_power: float = idle_thrust_fraction + (1.0 - idle_thrust_fraction) * maxf(collective_input, 0.0)
	if collective_input < 0.0:
		target_power = idle_thrust_fraction * 0.5
	engine_power = move_toward(engine_power, target_power, engine_spool_rate * delta)

	# --- Ground Effect ---
	var ground_effect: float = 1.0
	if altitude_agl < ground_effect_height:
		var factor: float = 1.0 - (altitude_agl / ground_effect_height)
		ground_effect = lerpf(1.0, ground_effect_multiplier, factor * factor)

	# --- Thrust (Collective along local +Y) ---
	var thrust_magnitude: float = max_thrust * engine_power * ground_effect
	var thrust_direction: Vector3 = transform.basis.y
	apply_central_force(thrust_direction * thrust_magnitude)

	# --- Cyclic (Pitch around local X, Roll around local Z) ---
	apply_torque(transform.basis.x * cyclic_pitch * pitch_torque)
	apply_torque(transform.basis.z * cyclic_roll * roll_torque)

	# --- Yaw (Tail Rotor around local Y) ---
	apply_torque(transform.basis.y * yaw_input * yaw_torque)

	# --- Aerodynamic Drag ---
	var velocity_sq: float = linear_velocity.length_squared()
	if velocity_sq > 0.1:
		var drag_force: Vector3 = -linear_velocity.normalized() * velocity_sq * drag_coefficient
		apply_central_force(drag_force)

	# --- Angular Damping (Stability Augmentation) ---
	apply_torque(-angular_velocity * angular_damping_factor * mass)

	# --- Auto-Level (gentle return toward level when no cyclic input) ---
	if absf(cyclic_pitch) < 0.05 and absf(cyclic_roll) < 0.05:
		_apply_auto_level()

	# --- Decay cyclic input smoothly ---
	cyclic_pitch = move_toward(cyclic_pitch, 0.0, 6.0 * delta)
	cyclic_roll = move_toward(cyclic_roll, 0.0, 6.0 * delta)

	_update_rotor(delta)

	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	if Input.is_action_pressed("fire") and fire_cooldown <= 0.0:
		_fire_hydra_rocket()
		fire_cooldown = 0.22


func _fire_hydra_rocket() -> void:
	var rocket := rocket_scene.instantiate() as RocketProjectile
	var scene_root: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	scene_root.add_child(rocket)
	var pod_offset := Vector3(next_pod_side * 2.1, -0.25, -1.2)
	next_pod_side *= -1.0
	rocket.global_position = to_global(pod_offset)
	var forward_dir := -transform.basis.z
	rocket.launch(forward_dir, linear_velocity, self)


func _update_altitude() -> void:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.DOWN * 500.0,
		1  # Layer 1 = World
	)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	if result:
		altitude_agl = maxf(0.0, global_position.y - result.position.y)
	else:
		altitude_agl = 500.0


func _apply_auto_level() -> void:
	var current_up: Vector3 = transform.basis.y
	var world_up := Vector3.UP
	var cross := current_up.cross(world_up)
	var dot := clampf(current_up.dot(world_up), -1.0, 1.0)

	if cross.length() > auto_level_deadzone:
		var correction_torque := cross.normalized() * auto_level_strength * (1.0 - dot)
		apply_torque(correction_torque)


func _update_rotor(delta: float) -> void:
	var target_rotor_speed: float = engine_power * 2000.0
	rotor_speed = move_toward(rotor_speed, target_rotor_speed, 800.0 * delta)
	if rotor_node:
		rotor_node.rotate_y(deg_to_rad(rotor_speed * delta))
	if tail_rotor_node:
		tail_rotor_node.rotate_x(deg_to_rad(rotor_speed * 1.5 * delta))


func enter_vehicle(player: Node3D) -> int:
	is_occupied = true
	team = Teams.of(player)
	occupant = player
	engine_power = maxf(engine_power, idle_thrust_fraction)
	return 0


func exit_vehicle(_player: Node3D) -> void:
	is_occupied = false
	team = Teams.NONE
	occupant = null
	collective_input = 0.0
	cyclic_pitch = 0.0
	cyclic_roll = 0.0
	yaw_input = 0.0
