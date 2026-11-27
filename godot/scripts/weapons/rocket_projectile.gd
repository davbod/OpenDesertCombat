## Rocket projectile (helicopter rockets, RPG, jet bombs)
## Moves forward with optional gravity drop and sweeps a ray each tick for hits.
## On impact it detonates an Explosion: the body it struck takes full damage once, everything
## else in the blast radius takes splash damage with falloff.
##
## The attacker is fixed at launch: a vehicle's occupant, otherwise whoever fired it. A pilot
## who bails out (or whose vehicle is destroyed) before impact still gets the kill, and friendly
## fire stays off.

extends Node3D
class_name RocketProjectile

const HIT_MASK: int = 7  ## World (1) + Players (2) + Vehicles (4)

@export var speed: float = 95.0
@export var gravity_drop: float = 2.5
@export var lifetime: float = 6.0
@export var blast_radius: float = 8.0
@export var blast_impulse: float = 12000.0
@export var vehicle_damage: float = 120.0  ## Direct hit on a vehicle; splash falls off from this
@export var infantry_damage: float = 80.0  ## Direct hit on a soldier; splash falls off from this

var velocity: Vector3 = Vector3.ZERO
var shooter: Node3D = null  ## Fired it (soldier or vehicle); excluded from the flight ray
var attacker: Node3D = null  ## Credited for the damage: the shooter's occupant at launch, else the shooter
var age: float = 0.0
var has_exploded: bool = false


func launch(forward_dir: Vector3, inherited_velocity: Vector3 = Vector3.ZERO, owner_node: Node3D = null) -> void:
	velocity = forward_dir.normalized() * speed + inherited_velocity
	shooter = owner_node
	attacker = owner_node
	if owner_node and "occupant" in owner_node:
		var crew := owner_node.get("occupant") as Node3D
		if crew:
			attacker = crew
	_face_velocity()


func _physics_process(delta: float) -> void:
	if has_exploded:
		return

	age += delta
	if age >= lifetime:
		queue_free()
		return

	velocity.y -= gravity_drop * delta
	var next_pos := global_position + velocity * delta

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, next_pos, HIT_MASK)
	if is_instance_valid(shooter) and shooter is CollisionObject3D:
		query.exclude = [(shooter as CollisionObject3D).get_rid()]

	var result := space_state.intersect_ray(query)
	if result:
		_explode(result.position, result.get("collider") as Object)
	else:
		global_position = next_pos
		_face_velocity()


## Points the projectile along its velocity (a bomb dropped at a standstill falls straight down,
## so pick an up vector that isn't parallel to it).
func _face_velocity() -> void:
	if velocity.length_squared() < 0.01:
		return
	var dir := velocity.normalized()
	look_at(global_position + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.BACK)


func _explode(hit_pos: Vector3, hit_body: Object = null) -> void:
	has_exploded = true
	global_position = hit_pos
	var credited: Node3D = attacker if is_instance_valid(attacker) else null
	Explosion.detonate(self, hit_pos, blast_radius, vehicle_damage, infantry_damage, blast_impulse, credited, hit_body)
	queue_free()
