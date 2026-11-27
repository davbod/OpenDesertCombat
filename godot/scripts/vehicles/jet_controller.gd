## Fixed-Wing Jet Flight Controller
## Attached to a RigidBody3D representing the jet airframe.
## Arcade-first flight model with real energy behaviour:
##   - Lift scales with airspeed² × angle of attack, and collapses past the stall angle
##   - Parasitic + induced drag, so hard turns bleed speed
##   - Fly-by-wire rate command: the stick asks for a rotation rate, scaled by airspeed
##   - AoA limiter (arcade assist), weathervane yaw stability, nose-drop in a stall
## Weapons: hitscan 20 mm cannon (LMB) and free-fall bombs (RMB).

extends RigidBody3D
class_name JetController

## --- Tuning Parameters ---

@export_group("Engine")
@export var max_thrust: float = 150000.0  ## N at full throttle (~1.27 TWR at 12 t)
@export var throttle_rate: float = 0.6  ## Throttle change per second while W/S held

@export_group("Lift")
@export var lift_factor: float = 40.0  ## Lift = lift_factor × v² × CL
@export var lift_slope: float = 5.0  ## CL per radian of angle of attack
@export var stall_aoa: float = 0.28  ## Radians (~16°) — beyond this, lift collapses
@export var post_stall_lift_fraction: float = 0.35  ## CL multiplier when fully stalled
@export var zero_lift_aoa: float = -0.035  ## Wing incidence: produces a little lift at 0° body AoA

@export_group("Drag")
@export var parasitic_drag: float = 2.6  ## Drag = k × v² (sets top speed ~240 m/s)
@export var induced_drag: float = 0.12  ## Fraction of lift × CL lost as drag (turn bleed)
@export var sideslip_damping: float = 2.5  ## 1/s decay of sideways velocity at reference speed

@export_group("Fly-By-Wire (rate command)")
@export var max_pitch_rate: float = 1.2  ## rad/s at full stick, reference speed
@export var max_roll_rate: float = 3.0  ## rad/s
@export var max_yaw_rate: float = 0.45  ## rad/s
@export var rate_response: float = 6.0  ## 1/s — how hard the FBW chases the commanded rate
@export var control_reference_speed: float = 110.0  ## m/s at which authority = 1.0
@export var min_control_authority: float = 0.08  ## Authority on the ground / at very low speed
@export var max_control_authority: float = 1.3
@export var aoa_limiter: bool = true  ## Arcade assist: stops pull-ups short of the stall
@export var aoa_limit_fraction: float = 0.9  ## Fraction of stall_aoa the limiter allows
@export var aoa_limiter_gain: float = 18.0  ## 1/s — stiffer = holds closer to the limit in hard turns
@export var yaw_stability: float = 2.0  ## Nose follows the airflow sideways (weathervane)
@export var auto_trim_gain: float = 2.0  ## Stick-free: steer AoA toward straight-path (1 g × cos γ) trim
@export var stall_nose_drop: float = 3.0  ## Nose falls through when stalled
@export var mouse_sensitivity: float = 0.012
@export var stick_return_rate: float = 4.0  ## How fast the virtual stick re-centres
@export var airframe_inertia: Vector3 = Vector3(60000.0, 80000.0, 20000.0)  ## kg·m² (pitch, yaw, roll)

@export_group("Ground")
@export var wheel_brake_force: float = 60000.0
@export var ground_check_distance: float = 2.6

@export_group("Weapons")
@export var gun_damage: float = 18.0
@export var gun_range: float = 1500.0
@export var gun_interval: float = 0.07
@export var gun_spread: float = 0.006  ## Radians
@export var bomb_capacity: int = 4
@export var bomb_rearm_time: float = 10.0  ## Seconds per bomb
@export var bomb_interval: float = 0.6

@export_group("Damage")
@export var crash_speed_loss: float = 22.0  ## m/s lost in one tick that counts as a crash
@export var crash_damage_per_ms: float = 12.0  ## Damage per m/s beyond the threshold

@export_group("Vehicle")
@export var vehicle_name: String = "F-16 Fighting Falcon (Prototype)"
@export var seat_positions: Array[Vector3] = [Vector3(0.0, 1.05, -3.2)]
@export var chase_camera_offset: Vector3 = Vector3(0.0, 5.0, 20.0)
@export var is_occupied: bool = false
var team: int = Teams.NONE  ## Crew's team while occupied, NONE when empty

## --- State ---

var throttle: float = 0.0
var stick_pitch: float = 0.0
var stick_roll: float = 0.0
var rudder: float = 0.0
var altitude_agl: float = 0.0
var airspeed: float = 0.0  ## Forward airspeed (m/s)
var angle_of_attack: float = 0.0  ## Radians
var is_stalled: bool = false
var on_ground: bool = false
var bombs_loaded: int = 0
var is_destroyed: bool = false

var _gun_cooldown: float = 0.0
var _bomb_cooldown: float = 0.0
var _rearm_timer: float = 0.0
var _next_gun_side: float = 1.0
var _prev_speed: float = 0.0
var occupant: Node3D = null  ## Driver/pilot while occupied

var _bomb_scene: PackedScene = preload("res://scenes/weapons/rocket_projectile.tscn")
var _tracer_scene: PackedScene = preload("res://scenes/weapons/cannon_shell.tscn")

@onready var health_component: HealthComponent = $HealthComponent if has_node("HealthComponent") else null
@onready var afterburner: MeshInstance3D = $Afterburner if has_node("Afterburner") else null


func _ready() -> void:
	gravity_scale = 1.0
	# Replace (not combine with) the project's default damping: drag is modelled
	# explicitly in _apply_aerodynamics(), and the default 0.1/s would add ~100 kN
	# of phantom drag at cruise speed.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	inertia = airframe_inertia
	bombs_loaded = bomb_capacity
	if health_component:
		health_component.died.connect(_on_destroyed)


func _unhandled_input(event: InputEvent) -> void:
	if not is_occupied or is_destroyed:
		return
	# Mouse is a virtual stick: Y = pitch (pull back = nose up), X = roll
	if event is InputEventMouseMotion:
		stick_pitch = clampf(stick_pitch + event.relative.y * mouse_sensitivity, -1.0, 1.0)
		stick_roll = clampf(stick_roll - event.relative.x * mouse_sensitivity, -1.0, 1.0)


func _physics_process(delta: float) -> void:
	_update_ground_state()
	_update_aero_state()
	_check_crash()

	if is_occupied and not is_destroyed:
		_read_inputs(delta)
	else:
		throttle = move_toward(throttle, 0.0, throttle_rate * delta)
		stick_pitch = 0.0
		stick_roll = 0.0
		rudder = 0.0

	_apply_thrust()
	_apply_aerodynamics()
	_apply_controls()
	_apply_ground_handling()
	_update_weapons(delta)
	_update_visuals()

	stick_pitch = move_toward(stick_pitch, 0.0, stick_return_rate * delta)
	stick_roll = move_toward(stick_roll, 0.0, stick_return_rate * delta)


## ---- Inputs ------------------------------------------------------------

func _read_inputs(delta: float) -> void:
	if Input.is_action_pressed("move_forward"):
		throttle = minf(throttle + throttle_rate * delta, 1.0)
	elif Input.is_action_pressed("move_backward"):
		throttle = maxf(throttle - throttle_rate * delta, 0.0)

	# Right-handed Y-up: +Y torque yaws nose left
	rudder = 0.0
	if Input.is_action_pressed("move_left"):
		rudder = 1.0
	elif Input.is_action_pressed("move_right"):
		rudder = -1.0


## ---- Flight model -------------------------------------------------------

func _update_aero_state() -> void:
	var local_vel: Vector3 = global_transform.basis.inverse() * linear_velocity
	airspeed = maxf(-local_vel.z, 0.0)
	# Positive AoA when the nose is above the flight path (air hits the belly)
	angle_of_attack = atan2(-local_vel.y, maxf(airspeed, 1.0))
	is_stalled = not on_ground and absf(angle_of_attack) > stall_aoa and airspeed > 5.0


func _lift_coefficient() -> float:
	var effective_aoa: float = angle_of_attack - zero_lift_aoa
	var abs_aoa: float = absf(effective_aoa)
	if abs_aoa <= stall_aoa:
		return lift_slope * effective_aoa
	# Past the stall: lift drops off quickly toward a small residual value
	var cl_max: float = lift_slope * stall_aoa
	var over: float = clampf((abs_aoa - stall_aoa) / 0.2, 0.0, 1.0)
	return signf(effective_aoa) * cl_max * lerpf(1.0, post_stall_lift_fraction, over)


func _apply_thrust() -> void:
	apply_central_force(-global_transform.basis.z * max_thrust * throttle)


func _apply_aerodynamics() -> void:
	var speed_sq: float = linear_velocity.length_squared()
	if speed_sq < 1.0:
		return
	var vel_dir: Vector3 = linear_velocity.normalized()
	var right: Vector3 = global_transform.basis.x

	# Lift acts perpendicular to the airflow, in the plane of the wings' up vector
	var cl: float = _lift_coefficient()
	var forward_sq: float = airspeed * airspeed
	var lift_magnitude: float = lift_factor * forward_sq * cl
	var lift_dir: Vector3 = right.cross(vel_dir).normalized()
	apply_central_force(lift_dir * lift_magnitude)

	# Drag: parasitic (v²) + induced (proportional to lift × CL) — turning costs energy
	var drag_magnitude: float = parasitic_drag * speed_sq + absf(lift_magnitude * cl) * induced_drag
	apply_central_force(-vel_dir * drag_magnitude)

	# Side force: the fuselage resists sliding sideways through the air
	var lateral: float = linear_velocity.dot(right)
	var sideslip_gain: float = sideslip_damping * clampf(airspeed / control_reference_speed, 0.0, 2.0)
	apply_central_force(-right * lateral * mass * sideslip_gain)


func _control_authority() -> float:
	var ratio: float = airspeed / control_reference_speed
	return clampf(ratio * ratio, min_control_authority, max_control_authority)


## AoA that produces exactly enough lift for straight flight along the current path.
func _trim_aoa() -> float:
	var speed_sq: float = maxf(airspeed * airspeed, 1.0)
	var path_dir: Vector3 = linear_velocity.normalized()
	var cos_gamma: float = sqrt(maxf(1.0 - path_dir.y * path_dir.y, 0.0))
	var weight: float = mass * float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	# Only the component of lift in the vertical plane holds the jet up
	var bank_cos: float = maxf(global_transform.basis.y.dot(Vector3.UP), 0.2)
	var cl_needed: float = weight * cos_gamma / (lift_factor * speed_sq * bank_cos)
	var trim: float = cl_needed / lift_slope + zero_lift_aoa
	return clampf(trim, -stall_aoa * aoa_limit_fraction, stall_aoa * aoa_limit_fraction)


func _apply_controls() -> void:
	var authority: float = _control_authority()
	var b: Basis = global_transform.basis
	var local_rate: Vector3 = b.inverse() * angular_velocity  # x = pitch, y = yaw, z = roll

	# --- Commanded rates from the stick ---
	var target_pitch: float = stick_pitch * max_pitch_rate * authority
	var target_roll: float = stick_roll * max_roll_rate * authority
	var yaw_authority: float = maxf(authority, 0.35) if on_ground else authority
	var target_yaw: float = rudder * max_yaw_rate * yaw_authority

	if not on_ground and airspeed > 10.0:
		# AoA limiter: never command a pitch rate that drives AoA past the limit
		if aoa_limiter:
			var aoa_limit: float = stall_aoa * aoa_limit_fraction
			var headroom: float = aoa_limit - angle_of_attack
			target_pitch = minf(target_pitch, headroom * aoa_limiter_gain)
			target_pitch = maxf(target_pitch, (-aoa_limit - angle_of_attack) * aoa_limiter_gain)
		# Auto-trim (stick-free): hold the AoA needed to fly a straight flight path.
		# When too slow to reach it, the limiter wins, gravity bends the path down,
		# and the nose follows — a gentle, self-recovering energy loss.
		var stick_free: float = 1.0 - clampf(absf(stick_pitch) * 4.0, 0.0, 1.0)
		if stick_free > 0.0:
			target_pitch += (_trim_aoa() - angle_of_attack) * auto_trim_gain * stick_free
		# Stall: nose drops through regardless of stick
		if is_stalled:
			var excess: float = angle_of_attack - signf(angle_of_attack) * stall_aoa
			target_pitch -= excess * stall_nose_drop
		# Weathervane: yaw the nose toward the airflow
		var local_vel: Vector3 = b.inverse() * linear_velocity
		var sideslip: float = atan2(local_vel.x, maxf(airspeed, 1.0))
		target_yaw -= sideslip * yaw_stability

	# --- Torque = inertia × rate error × response (per axis, body frame) ---
	var rate_error := Vector3(target_pitch, target_yaw, target_roll) - local_rate
	var local_torque := Vector3(
		airframe_inertia.x * rate_error.x,
		airframe_inertia.y * rate_error.y,
		airframe_inertia.z * rate_error.z
	) * rate_response
	if on_ground:
		local_torque.z *= 0.2  # wheels on the runway: don't fight the ground in roll
	apply_torque(b * local_torque)


func _apply_ground_handling() -> void:
	if not on_ground:
		return
	var horizontal := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var braking: bool = (is_occupied and Input.is_action_pressed("jump")) or (not is_occupied and throttle < 0.05)
	if braking and horizontal.length_squared() > 0.04:
		apply_central_force(-horizontal.normalized() * minf(wheel_brake_force, horizontal.length() * mass * 2.0))
	# Tyres resist sideways skidding
	var right: Vector3 = global_transform.basis.x
	var lateral: float = linear_velocity.dot(right)
	apply_central_force(-right * lateral * mass * 3.0)


func _update_ground_state() -> void:
	var space_state := get_world_3d().direct_space_state
	var down_query := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 3000.0, 1)
	down_query.exclude = [get_rid()]
	var result := space_state.intersect_ray(down_query)
	if result:
		altitude_agl = maxf(0.0, global_position.y - result.position.y)
	else:
		altitude_agl = 3000.0
	on_ground = altitude_agl < ground_check_distance


func _check_crash() -> void:
	var speed: float = linear_velocity.length()
	var speed_loss: float = _prev_speed - speed
	_prev_speed = speed
	if speed_loss > crash_speed_loss and health_component:
		health_component.take_damage((speed_loss - crash_speed_loss) * crash_damage_per_ms + 40.0, null)


## ---- Weapons --------------------------------------------------------------

func _update_weapons(delta: float) -> void:
	_gun_cooldown = maxf(_gun_cooldown - delta, 0.0)
	_bomb_cooldown = maxf(_bomb_cooldown - delta, 0.0)

	if bombs_loaded < bomb_capacity:
		_rearm_timer += delta
		if _rearm_timer >= bomb_rearm_time:
			_rearm_timer = 0.0
			bombs_loaded += 1

	if not is_occupied or is_destroyed:
		return
	if Input.is_action_pressed("fire") and _gun_cooldown <= 0.0:
		_fire_gun()
		_gun_cooldown = gun_interval
	if Input.is_action_pressed("aim") and _bomb_cooldown <= 0.0 and bombs_loaded > 0:
		_drop_bomb()
		_bomb_cooldown = bomb_interval


func _fire_gun() -> void:
	var b: Basis = global_transform.basis
	var origin: Vector3 = to_global(Vector3(_next_gun_side * 0.6, 0.2, -6.0))
	_next_gun_side *= -1.0
	var forward: Vector3 = -b.z
	forward = forward.rotated(b.x, randf_range(-gun_spread, gun_spread))
	forward = forward.rotated(b.y, randf_range(-gun_spread, gun_spread))

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * gun_range, 7)  # World + Players + Vehicles
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	if result:
		var body: Object = result.get("collider")
		if body is Node:
			var hc: HealthComponent = (body as Node).find_child("HealthComponent", true, false) as HealthComponent
			if hc:
				hc.take_damage(gun_damage, occupant if occupant else self)

	var tracer := _tracer_scene.instantiate() as Node3D
	var scene_root: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	scene_root.add_child(tracer)
	tracer.global_position = origin
	if tracer.has_method("launch"):
		tracer.call("launch", forward * 900.0 + linear_velocity, Vector3.ZERO, self)


func _drop_bomb() -> void:
	bombs_loaded -= 1
	var bomb := _bomb_scene.instantiate() as RocketProjectile
	# Free-fall bomb: no motor, full gravity, big blast
	bomb.speed = 0.0
	bomb.gravity_drop = 9.8
	bomb.lifetime = 30.0
	bomb.blast_radius = 16.0
	bomb.blast_impulse = 60000.0
	bomb.vehicle_damage = 450.0
	bomb.infantry_damage = 200.0
	var scene_root: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	scene_root.add_child(bomb)
	bomb.global_position = to_global(Vector3(0.0, -1.4, 0.0))
	var drop_dir: Vector3 = linear_velocity.normalized() if linear_velocity.length_squared() > 1.0 else Vector3.DOWN
	bomb.launch(drop_dir, linear_velocity, self)


## ---- Visuals / HUD ------------------------------------------------------

func _update_visuals() -> void:
	if afterburner:
		afterburner.visible = throttle > 0.85 and not is_destroyed
		afterburner.scale = Vector3.ONE * lerpf(0.6, 1.2, clampf((throttle - 0.85) / 0.15, 0.0, 1.0))


## Status line shown in the vehicle HUD panel (read duck-typed by PlayerController).
func get_hud_status() -> String:
	var parts := PackedStringArray(["THR %d%%" % int(throttle * 100.0), "BOMBS %d" % bombs_loaded])
	if is_stalled:
		parts.append("!! STALL !!")
	elif airspeed > 5.0 and not on_ground and airspeed < 55.0:
		parts.append("LOW SPEED")
	return "   ".join(parts)


## ---- Vehicle contract ---------------------------------------------------

func enter_vehicle(player: Node3D) -> int:
	is_occupied = true
	team = Teams.of(player)
	occupant = player
	return 0


func exit_vehicle(_player: Node3D) -> void:
	is_occupied = false
	team = Teams.NONE
	occupant = null
	stick_pitch = 0.0
	stick_roll = 0.0
	rudder = 0.0


func _on_destroyed(_attacker: Node3D) -> void:
	is_destroyed = true
	throttle = 0.0
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 4.0
	sphere.height = 8.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.1, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.05)
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = mat
	flash.mesh = sphere
	var scene_root: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	scene_root.add_child(flash)
	flash.global_position = global_position
	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 3.0, 0.4)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(flash.queue_free)
