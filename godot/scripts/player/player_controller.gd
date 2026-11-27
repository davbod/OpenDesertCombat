## First-Person Player Controller
## CharacterBody3D-based FPS controller with vehicle enter/exit, health, and kit selection.

extends CharacterBody3D
class_name PlayerController

## --- Movement ---
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var crouch_speed: float = 2.5
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002

## --- Camera ---
@export var camera_pitch_min: float = -89.0
@export var camera_pitch_max: float = 89.0

## --- State ---
var is_in_vehicle: bool = false
var current_vehicle: Node3D = null
var current_seat: int = -1
var use_chase_camera: bool = false
var hud: GameHUD = null
var fire_cooldown: float = 0.0
var active_weapon: int = 1  # 1 = Rifle, 2 = RPG
var rocket_scene: PackedScene = preload("res://scenes/weapons/rocket_projectile.tscn")

## --- Team & Kit ---
@export_enum("Neutral", "USMC", "OPFOR") var team: int = Teams.USMC
var active_kit_id: int = 0  # 0=Assault, 1=Engineer, 2=Medic, 3=Sniper
var speed_multiplier: float = 1.0  ## From the kit
var participant: Participant = null  ## This soldier's entry in the MatchManager registry
var _is_dead: bool = false

## --- Nodes ---
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var interaction_ray: RayCast3D = $CameraPivot/InteractionRay
@onready var collision_shape: CollisionShape3D = $PlayerCollision
@onready var health_component: HealthComponent = $HealthComponent

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _kit_menu: KitSelectMenu = null
var _match: MatchManager = null
var _team_material: StandardMaterial3D = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud = get_tree().root.find_child("GameHUD", true, false) as GameHUD
	_kit_menu = get_tree().root.find_child("KitSelectMenu", true, false) as KitSelectMenu
	_match = get_tree().root.find_child("MatchManager", true, false) as MatchManager
	if _match:
		participant = _match.register(self, "Player", team, true)

	if health_component:
		health_component.died.connect(_on_player_died)
		health_component.health_changed.connect(_on_health_changed)

	if _kit_menu:
		_kit_menu.deploy_requested.connect(_on_deploy_requested)

	if hud:
		hud.set_local_player(self)
	_apply_team_visuals()


## --- Team ---

func is_alive() -> bool:
	return not _is_dead


## The body that represents this soldier in the world: their vehicle while seated, else themselves.
func get_presence_body() -> Node3D:
	return current_vehicle if is_in_vehicle and current_vehicle else self


func set_team(new_team: int) -> void:
	team = new_team
	_apply_team_visuals()


func _apply_team_visuals() -> void:
	var mesh := get_node_or_null("PlayerMesh") as MeshInstance3D
	if not mesh:
		return
	if not _team_material:
		_team_material = StandardMaterial3D.new()
		_team_material.roughness = 0.85
		mesh.material_override = _team_material
	# Desert tan uniform with a strong team tint, so sides read at a glance
	_team_material.albedo_color = Color(0.68, 0.6, 0.44).lerp(Teams.color_of(team), 0.55)


## Without a MatchManager (e.g. a bare test scene): any spawn point our team holds.
func _get_fallback_spawn() -> SpawnPoint:
	for node in get_tree().get_nodes_in_group(SpawnPoint.GROUP):
		var spawn := node as SpawnPoint
		if spawn and spawn.get_team() == team:
			return spawn
	return null


func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return

	# Mouse look (only when on foot)
	if event is InputEventMouseMotion and not is_in_vehicle:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x,
			deg_to_rad(camera_pitch_min),
			deg_to_rad(camera_pitch_max)
		)

	# Toggle mouse capture
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Vehicle interact
	if event.is_action_pressed("interact"):
		if is_in_vehicle:
			_exit_vehicle()
		else:
			_try_enter_vehicle()

	# Toggle 1st-person / 3rd-person camera in vehicle (V key)
	if is_in_vehicle and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_V:
			use_chase_camera = not use_chase_camera
			_apply_vehicle_camera_offset()

	# Dev shortcut until the 4.3 pause menu: K = respawn (die and open the deploy menu)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_K:
		if health_component:
			health_component.take_damage(health_component.current_health, self)
		return

	# Weapon switch (1 = Rifle, 2 = RPG)
	if not is_in_vehicle and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_1:
			active_weapon = 1
		elif event.physical_keycode == KEY_2:
			active_weapon = 2


func _physics_process(delta: float) -> void:
	if is_in_vehicle or _is_dead:
		return

	# Check interactable vehicle prompt
	if hud and interaction_ray:
		var target_vehicle := _get_targeted_vehicle()
		if target_vehicle:
			hud.set_interact_prompt("[E] Enter %s" % target_vehicle.vehicle_name)
		else:
			hud.set_interact_prompt("")

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Movement speed
	var speed := walk_speed
	if Input.is_action_pressed("sprint"):
		speed = sprint_speed
	elif Input.is_action_pressed("crouch"):
		speed = crouch_speed
	speed *= speed_multiplier

	# Input direction
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()


func _process(delta: float) -> void:
	if _is_dead:
		return

	if fire_cooldown > 0.0:
		fire_cooldown -= delta

	if is_in_vehicle and current_vehicle and hud:
		var v_name: String = current_vehicle.vehicle_name if "vehicle_name" in current_vehicle else "Vehicle"
		var alt: float = current_vehicle.altitude_agl if "altitude_agl" in current_vehicle else 0.0
		var spd: float = current_vehicle.linear_velocity.length() if current_vehicle is RigidBody3D else 0.0
		var status: String = current_vehicle.call("get_hud_status") if current_vehicle.has_method("get_hud_status") else ""
		hud.update_vehicle_hud(v_name, alt, spd, status)
	elif not is_in_vehicle and Input.is_action_pressed("fire") and fire_cooldown <= 0.0:
		if active_weapon == 1:
			_fire_rifle()
			fire_cooldown = 0.11
		else:
			_fire_rpg()
			fire_cooldown = 1.1


func _fire_rifle() -> void:
	var space_state := get_world_3d().direct_space_state
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * 300.0, 7)  # World + Players + Vehicles
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	if result:
		# Apply rifle damage (25) to any HealthComponent on hit body
		var body: Object = result.get("collider")
		if body is Node:
			var hc: HealthComponent = (body as Node).find_child("HealthComponent", true, false) as HealthComponent
			if hc:
				hc.take_damage(25.0, self)

		# Spark VFX
		var spark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * 0.18
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.7, 0.2)
		box.material = mat
		spark.mesh = box
		var scene_root: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
		scene_root.add_child(spark)
		spark.global_position = result.position
		get_tree().create_timer(0.18).timeout.connect(spark.queue_free)


func _fire_rpg() -> void:
	var rocket := rocket_scene.instantiate() as RocketProjectile
	var scene_root: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	scene_root.add_child(rocket)
	var forward := -camera.global_transform.basis.z
	rocket.global_position = camera.global_position + forward * 1.4
	rocket.launch(forward, velocity, self)


func _get_targeted_vehicle() -> Node3D:
	if not interaction_ray:
		return null
	interaction_ray.force_raycast_update()
	if interaction_ray.is_colliding():
		var node: Node = interaction_ray.get_collider()
		while node:
			if node.has_method("enter_vehicle"):
				return node as Node3D
			node = node.get_parent()
	return null


func _try_enter_vehicle() -> void:
	var vehicle := _get_targeted_vehicle()
	if vehicle:
		_enter_vehicle(vehicle)


func _enter_vehicle(vehicle: Node3D) -> void:
	is_in_vehicle = true
	current_vehicle = vehicle
	current_seat = vehicle.enter_vehicle(self)
	use_chase_camera = true

	visible = false
	if collision_shape:
		collision_shape.disabled = true

	camera_pivot.get_parent().remove_child(camera_pivot)
	vehicle.add_child(camera_pivot)
	_apply_vehicle_camera_offset()

	# If the vehicle is destroyed while we're inside, we go down with it
	var vehicle_hc := _find_health_component(vehicle)
	if vehicle_hc and not vehicle_hc.died.is_connected(_on_vehicle_destroyed):
		vehicle_hc.died.connect(_on_vehicle_destroyed)

	if hud:
		hud.set_interact_prompt("")


func _apply_vehicle_camera_offset() -> void:
	if not current_vehicle:
		return
	if use_chase_camera and "chase_camera_offset" in current_vehicle:
		camera_pivot.position = current_vehicle.chase_camera_offset
		camera_pivot.rotation = Vector3(deg_to_rad(-10.0), 0.0, 0.0)
	else:
		var seat_pos: Vector3 = Vector3.ZERO
		if current_seat >= 0 and current_seat < current_vehicle.seat_positions.size():
			seat_pos = current_vehicle.seat_positions[current_seat]
		camera_pivot.position = seat_pos
		camera_pivot.rotation = Vector3.ZERO


func _exit_vehicle() -> void:
	if not current_vehicle:
		return

	var vehicle_hc := _find_health_component(current_vehicle)
	if vehicle_hc and vehicle_hc.died.is_connected(_on_vehicle_destroyed):
		vehicle_hc.died.disconnect(_on_vehicle_destroyed)

	camera_pivot.get_parent().remove_child(camera_pivot)
	add_child(camera_pivot)
	camera_pivot.position = Vector3(0, 0.6, 0)
	camera_pivot.rotation = Vector3.ZERO

	# Place player safely beside vehicle
	var side_offset: Vector3 = current_vehicle.global_transform.basis.x * 3.5
	side_offset.y = 0.0
	global_position = current_vehicle.global_position + side_offset + Vector3.UP * 1.5
	velocity = Vector3.ZERO

	current_vehicle.exit_vehicle(self)
	current_vehicle = null
	current_seat = -1
	is_in_vehicle = false
	visible = true
	if collision_shape:
		collision_shape.disabled = false

	if hud:
		hud.hide_vehicle_hud()


## --- Health / Death / Respawn ---

func _find_health_component(node: Node) -> HealthComponent:
	return node.find_child("HealthComponent", true, false) as HealthComponent if node else null


func _on_vehicle_destroyed(attacker: Node3D) -> void:
	_exit_vehicle()
	if health_component:
		health_component.take_damage(health_component.current_health, attacker)

func _on_player_died(_attacker: Node3D) -> void:
	if is_in_vehicle:
		_exit_vehicle()
	_is_dead = true
	visible = false
	if collision_shape:
		collision_shape.disabled = true
	velocity = Vector3.ZERO

	# MatchManager listens to the same signal: it records the death, tickets and score.
	if _kit_menu and _match and participant:
		_kit_menu.show_menu(_match, participant)
	else:
		# Fallback without a match: respawn at a spawn our team holds after 5 s
		await get_tree().create_timer(5.0).timeout
		var spawn := _get_fallback_spawn()
		var xform := spawn.get_spawn_transform() if spawn else Transform3D(Basis(), Vector3(0.0, 2.0, 14.0))
		spawn_at(xform, team, active_kit_id)


## Deploy menu → ask the match to spawn us. The match validates and calls spawn_at().
func _on_deploy_requested(new_team: int, kit_id: int, spawn: SpawnPoint) -> void:
	if not _is_dead or not _match or not participant:
		return
	var reason := _match.request_spawn(participant, new_team, kit_id, spawn)
	if _kit_menu:
		if reason.is_empty():
			_kit_menu.close()
		else:
			_kit_menu.report_spawn_failed(reason)


## Puts this soldier back in the world. Called by MatchManager once a spawn is approved.
func spawn_at(xform: Transform3D, new_team: int, kit_id: int) -> void:
	set_team(new_team)
	active_kit_id = kit_id
	var kit := Kits.get_kit(kit_id)
	speed_multiplier = kit.get("speed", 1.0) as float
	if health_component:
		health_component.max_health = kit.get("health", 100.0) as float
		health_component.reset()
	_is_dead = false
	visible = true
	if collision_shape:
		collision_shape.disabled = false
	global_position = xform.origin
	rotation = Vector3(0.0, xform.basis.get_euler().y, 0.0)
	camera_pivot.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_health_changed(current: float, maximum: float) -> void:
	# Forward to HUD if it has a health bar (Sprint 3 feature — guard with has_method)
	if hud and hud.has_method("update_health"):
		hud.call("update_health", current, maximum)
