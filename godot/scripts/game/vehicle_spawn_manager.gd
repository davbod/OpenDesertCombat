## VehicleSpawnManager — Tracks vehicle spawn points and respawns destroyed vehicles.
## Add this as a node in the map scene and register vehicles via register_vehicle().
## On vehicle death the manager waits respawn_delay seconds then re-instances the vehicle.

extends Node
class_name VehicleSpawnManager

@export var respawn_delay: float = 30.0

## Registered entries: { "scene": PackedScene, "spawn_node": Node3D, "current_instance": Node3D or null }
var _entries: Array[Dictionary] = []


func register_vehicle(scene: PackedScene, spawn_node: Node3D) -> void:
	var instance: Node3D = scene.instantiate() as Node3D
	var entry: Dictionary = {
		"scene": scene,
		"spawn_node": spawn_node,
		"current_instance": instance,
	}
	_entries.append(entry)
	_place_instance(instance, spawn_node)

	# Wire up death signal if the vehicle has a HealthComponent
	var hc: HealthComponent = instance.find_child("HealthComponent", true, false) as HealthComponent
	if hc:
		hc.died.connect(_on_vehicle_died.bind(entry))


func _place_instance(instance: Node3D, spawn_node: Node3D) -> void:
	get_tree().current_scene.add_child(instance)
	instance.global_transform = spawn_node.global_transform


func _on_vehicle_died(_attacker: Node3D, entry: Dictionary) -> void:
	var instance: Node3D = entry["current_instance"] as Node3D
	# Wreck: hide after a short delay, then queue_free
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(instance):
		instance.queue_free()
	entry["current_instance"] = null

	# Wait respawn countdown
	await get_tree().create_timer(respawn_delay).timeout
	_respawn_vehicle(entry)


func _respawn_vehicle(entry: Dictionary) -> void:
	var scene: PackedScene = entry["scene"] as PackedScene
	var spawn_node: Node3D = entry["spawn_node"] as Node3D
	var new_instance: Node3D = scene.instantiate() as Node3D
	entry["current_instance"] = new_instance
	_place_instance(new_instance, spawn_node)

	var hc: HealthComponent = new_instance.find_child("HealthComponent", true, false) as HealthComponent
	if hc:
		hc.died.connect(_on_vehicle_died.bind(entry))
