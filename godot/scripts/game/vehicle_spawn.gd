## VehicleSpawn — keeps one vehicle alive at this spot for whichever team holds its flag.
## Replaces the old central VehicleSpawnManager: each spawn is placed in the map and manages
## its own vehicle (spawn, wreck, respawn, abandoned-vehicle return).
##
## - Ownership follows `capture_point` (or a parent CapturePoint); with no flag, `team` is used.
##   Main-base vehicles point at the base's uncapturable flag.
## - Nothing spawns while the flag is neutral. When it is owned, the team's scene spawns
##   (`usmc_vehicle_scene` / `opfor_vehicle_scene`; either one is used for both if only one is set).
## - Destroyed: the wreck stays `wreck_time` s, then the vehicle respawns after `respawn_delay` s.
## - Abandoned: empty and farther than `abandon_distance` from here for `abandon_time` s →
##   removed and respawned here after `respawn_delay` s.
## - A vehicle already in the field is never taken away when its flag changes hands.

extends Marker3D
class_name VehicleSpawn

signal vehicle_spawned(vehicle: Node3D)
signal vehicle_removed(reason: String)  ## "destroyed" or "abandoned"

const GROUP: StringName = &"vehicle_spawns"

@export var usmc_vehicle_scene: PackedScene
@export var opfor_vehicle_scene: PackedScene
@export var vehicle_name: String = ""  ## Node name for the spawned vehicle (default: scene root name)
@export var capture_point: CapturePoint
@export_enum("Neutral", "USMC", "OPFOR") var team: int = 0  ## Used only when there is no flag
@export var spawn_at_start: bool = true
@export var respawn_delay: float = 30.0
@export var wreck_time: float = 4.0
@export var abandon_time: float = 60.0
@export var abandon_distance: float = 30.0

var vehicle: Node3D = null
var _respawn_timer: float = 0.0
var _abandoned_for: float = 0.0
var _wreck_left: float = -1.0  ## >= 0 while a destroyed vehicle's wreck is on show


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if not capture_point and get_parent() is CapturePoint:
		capture_point = get_parent() as CapturePoint
	if spawn_at_start:
		_try_spawn()
	else:
		_respawn_timer = respawn_delay


func get_team() -> int:
	return capture_point.owning_team if capture_point else team


func has_vehicle() -> bool:
	return vehicle != null and is_instance_valid(vehicle)


func _physics_process(delta: float) -> void:
	if _wreck_left >= 0.0:
		_wreck_left -= delta
		if _wreck_left < 0.0:
			_remove_vehicle("destroyed")
		return
	if not has_vehicle():
		vehicle = null
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_try_spawn()
		return
	_check_abandoned(delta)


func _try_spawn() -> void:
	var owner_team := get_team()
	if owner_team == Teams.NONE:
		return  # neutral flag: wait until someone holds it
	var scene := _scene_for(owner_team)
	if not scene:
		return
	var instance := scene.instantiate() as Node3D
	if not instance:
		return
	if not vehicle_name.is_empty():
		instance.name = vehicle_name
	# Vehicle scripts work in their own transform; keep it independent of this marker
	instance.top_level = true
	add_child(instance)
	instance.global_transform = global_transform
	vehicle = instance
	_abandoned_for = 0.0
	var hc := instance.find_child("HealthComponent", true, false) as HealthComponent
	if hc:
		hc.died.connect(_on_vehicle_died.bind(instance))
	vehicle_spawned.emit(instance)


func _scene_for(owner_team: int) -> PackedScene:
	if owner_team == Teams.OPFOR and opfor_vehicle_scene:
		return opfor_vehicle_scene
	if owner_team == Teams.USMC and usmc_vehicle_scene:
		return usmc_vehicle_scene
	return usmc_vehicle_scene if usmc_vehicle_scene else opfor_vehicle_scene


func _check_abandoned(delta: float) -> void:
	var occupied: bool = vehicle.get("is_occupied") == true
	var far := vehicle.global_position.distance_to(global_position) > abandon_distance
	if occupied or not far:
		_abandoned_for = 0.0
		return
	_abandoned_for += delta
	if _abandoned_for >= abandon_time:
		_remove_vehicle("abandoned")


func _on_vehicle_died(_attacker: Node3D, instance: Node3D) -> void:
	if instance == vehicle:
		_wreck_left = wreck_time


func _remove_vehicle(reason: String) -> void:
	if has_vehicle():
		vehicle.queue_free()
	vehicle = null
	_abandoned_for = 0.0
	_wreck_left = -1.0
	_respawn_timer = respawn_delay
	vehicle_removed.emit(reason)
