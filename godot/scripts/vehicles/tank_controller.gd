## TankController — Tracks-based tank using RigidBody3D + Jolt physics.
## Turret yaw is driven by mouse X; barrel pitch by mouse Y (clamped).
## Left-click fires the main cannon (hitscan HE shell: direct hit + splash via Explosion);
## passengers supported via enter/exit contract.

extends RigidBody3D
class_name TankController

## --- Vehicle Contract ---
var vehicle_name: String = "Main Battle Tank"
var seat_positions: Array[Vector3] = [Vector3(0.0, 1.35, -0.4)]
var chase_camera_offset: Vector3 = Vector3(0.0, 3.5, 9.0)
var is_occupied: bool = false
var team: int = Teams.NONE  ## Crew's team while occupied, NONE when empty

## --- Drive ---
@export var drive_force: float = 220000.0
@export var turn_torque: float = 180000.0
@export var brake_force: float = 95000.0
@export var max_speed: float = 18.0        ## m/s (~65 km/h)
@export var linear_damping_ground: float = 1.8
@export var angular_damping_factor: float = 4.5

## --- Turret ---
@export var turret_turn_speed: float = 1.4   ## rad/s
@export var barrel_pitch_min: float = -5.0   ## degrees, below horizontal
@export var barrel_pitch_max: float = 15.0   ## degrees, above horizontal
@export var turret_mouse_sensitivity: float = 0.0018

## --- Cannon ---
# Hitscan high-explosive shell: the body it hits takes cannon_damage, and a blast around the
# impact hurts infantry (and, a little, vehicles) nearby. The tracer is visual only.
const CANNON_HIT_MASK: int = 7  ## World (1) + Players (2) + Vehicles (4)

@export var cannon_damage: float = 250.0  ## Direct hit on a soldier or vehicle
@export var cannon_speed: float = 580.0  ## Tracer speed
@export var cannon_range: float = 1800.0
@export var fire_cooldown_time: float = 3.5
@export var splash_radius: float = 6.0
@export var splash_infantry_damage: float = 150.0  ## At the impact; falls off to 0 at splash_radius
@export var splash_vehicle_damage: float = 40.0  ## At the impact; falls off to 0 at splash_radius
@export var splash_impulse: float = 15000.0

var _fire_cooldown: float = 0.0
var _turret_yaw: float = 0.0
var _barrel_pitch: float = 0.0
var occupant: Node3D = null  ## Driver/pilot while occupied
var _cannon_scene: PackedScene = preload("res://scenes/weapons/cannon_shell.tscn")

@onready var turret_pivot: Node3D = $TurretPivot
@onready var barrel_pivot: Node3D = $TurretPivot/BarrelPivot
@onready var muzzle: Node3D = $TurretPivot/BarrelPivot/Muzzle


## ---- Vehicle Contract ------------------------------------------------

func enter_vehicle(player: Node3D) -> int:
	is_occupied = true
	team = Teams.of(player)
	occupant = player
	return 0  # driver seat


func exit_vehicle(_player: Node3D) -> void:
	is_occupied = false
	team = Teams.NONE
	occupant = null


## ---- Input -----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_occupied:
		return

	if event is InputEventMouseMotion:
		_turret_yaw -= (event as InputEventMouseMotion).relative.x * turret_mouse_sensitivity
		_barrel_pitch -= (event as InputEventMouseMotion).relative.y * turret_mouse_sensitivity
		_barrel_pitch = clampf(
			_barrel_pitch,
			deg_to_rad(barrel_pitch_min),
			deg_to_rad(barrel_pitch_max)
		)
		if turret_pivot:
			turret_pivot.rotation.y = _turret_yaw
		if barrel_pivot:
			barrel_pivot.rotation.x = _barrel_pitch

	if event.is_action_pressed("fire") and _fire_cooldown <= 0.0:
		_fire_cannon()


## ---- Physics Process -------------------------------------------------

func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)

	if not is_occupied:
		# Apply extra angular damping when unoccupied to prevent drift
		angular_velocity = angular_velocity.lerp(Vector3.ZERO, angular_damping_factor * delta)
		return

	var throttle: float = Input.get_axis("move_backward", "move_forward")
	var steer: float = Input.get_axis("move_right", "move_left")

	var speed_along_z: float = (global_transform.basis.z.dot(linear_velocity))
	var can_accelerate: bool = absf(speed_along_z) < max_speed

	# Drive force along body -Z (forward)
	if absf(throttle) > 0.01 and can_accelerate:
		apply_central_force(-global_transform.basis.z * throttle * drive_force)

	# Steering torque around world Y
	if absf(steer) > 0.01:
		apply_torque(Vector3.UP * steer * turn_torque)

	# Braking — counter longitudinal velocity
	if throttle == 0.0:
		var braking_force: Vector3 = -linear_velocity.project(global_transform.basis.z) * brake_force
		apply_central_force(braking_force)

	# Damp lateral slip (simulate track grip)
	var lateral: Vector3 = linear_velocity.project(global_transform.basis.x)
	apply_central_force(-lateral * mass * 8.0)

	# Angular damping
	angular_velocity = angular_velocity.lerp(Vector3.ZERO, angular_damping_factor * delta)

	# Keep tank upright (prevent tumbling)
	var up_error: Vector3 = global_transform.basis.y.cross(Vector3.UP)
	apply_torque(up_error * mass * 15.0)


## ---- Cannon Fire -----------------------------------------------------

func _fire_cannon() -> void:
	_fire_cooldown = fire_cooldown_time
	if not muzzle:
		return

	# Hitscan with fast projectile visualization
	var space_state := get_world_3d().direct_space_state
	var origin: Vector3 = muzzle.global_position
	var forward: Vector3 = -muzzle.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * cannon_range, CANNON_HIT_MASK)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)

	var hit_pos: Vector3 = result.position if result else origin + forward * cannon_range

	# HE detonation: direct hit takes cannon_damage, the rest of the blast takes splash.
	# The occupant is the attacker, for friendly fire and kill credit.
	if result:
		Explosion.detonate(self, hit_pos, splash_radius, splash_vehicle_damage, splash_infantry_damage,
				splash_impulse, occupant, result.get("collider") as Object, cannon_damage)

	# Visual tracer that stops at the impact point
	var shell := _cannon_scene.instantiate() as CannonShell
	var scene_root: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	scene_root.add_child(shell)
	shell.global_position = origin
	shell.max_distance = origin.distance_to(hit_pos)
	shell.launch(forward * cannon_speed, Vector3.ZERO, self)

	# Muzzle flash
	_spawn_muzzle_flash(origin)


func _spawn_muzzle_flash(pos: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.2
	sphere.height = 2.4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.75, 0.2, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.1)
	mat.emission_energy_multiplier = 6.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = mat
	flash.mesh = sphere
	var scene_root: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	scene_root.add_child(flash)
	flash.global_position = pos
	var tween: Tween = flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 2.5, 0.12)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.12)
	tween.chain().tween_callback(flash.queue_free)
