## Cannon Shell — Fast AP tracer round fired by the tank.
## High speed, minimal gravity, single-hit high damage (handled by TankController hitscan).
## This node is purely a visual tracer that moves forward and disappears on impact.

extends Node3D
class_name CannonShell

@export var lifetime: float = 2.5

var velocity: Vector3 = Vector3.ZERO
var age: float = 0.0


func launch(forward_vel: Vector3, _inherited: Vector3 = Vector3.ZERO, _owner_node: Node3D = null) -> void:
	velocity = forward_vel
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity.normalized(), Vector3.UP)


func _physics_process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	# Slight gravity
	velocity.y -= 2.5 * delta
	global_position += velocity * delta
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity.normalized(), Vector3.UP)
