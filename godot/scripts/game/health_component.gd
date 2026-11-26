## HealthComponent — Reusable health/damage node.
## Attach as a child of any actor (Player, vehicle) to give it health.
## Emit signals for HUD, respawn systems, and scoring.

extends Node
class_name HealthComponent

@export var max_health: float = 100.0
@export var is_invincible: bool = false

signal damaged(amount: float, attacker: Node3D)
signal healed(amount: float)
signal died(attacker: Node3D)
signal health_changed(current: float, maximum: float)

var current_health: float = 0.0
var _is_dead: bool = false


func _ready() -> void:
	current_health = max_health


func take_damage(amount: float, attacker: Node3D = null) -> void:
	if _is_dead or is_invincible or amount <= 0.0:
		return
	current_health = clampf(current_health - amount, 0.0, max_health)
	emit_signal("damaged", amount, attacker)
	emit_signal("health_changed", current_health, max_health)
	if current_health <= 0.0:
		_on_death(attacker)


func heal(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	current_health = clampf(current_health + amount, 0.0, max_health)
	emit_signal("healed", amount)
	emit_signal("health_changed", current_health, max_health)


func reset() -> void:
	_is_dead = false
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)


func get_health_ratio() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0


func _on_death(attacker: Node3D) -> void:
	_is_dead = true
	emit_signal("died", attacker)
