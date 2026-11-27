## Cannon Shell — visual tracer for the tank cannon and the jet's 20 mm gun.
## The hit itself is hitscan, handled by the firing vehicle (the tank's HE blast is an
## Explosion). This node only flies forward and disappears at the impact point or after
## its lifetime.

extends Node3D
class_name CannonShell

@export var lifetime: float = 2.5

var velocity: Vector3 = Vector3.ZERO
var age: float = 0.0
var max_distance: float = INF  ## Set by the shooter to the hitscan impact distance
var _travelled: float = 0.0


func launch(forward_vel: Vector3, _inherited: Vector3 = Vector3.ZERO, _owner_node: Node3D = null) -> void:
	velocity = forward_vel
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity.normalized(), Vector3.UP)


func _physics_process(delta: float) -> void:
	age += delta
	# Slight gravity
	velocity.y -= 2.5 * delta
	var step := velocity * delta
	_travelled += step.length()
	if age >= lifetime or _travelled >= max_distance:
		queue_free()
		return
	global_position += step
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity.normalized(), Vector3.UP)
