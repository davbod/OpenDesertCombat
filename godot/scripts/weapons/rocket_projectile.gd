## Rocket Projectile (Hydra 70 / RPG-7)
## Moves forward with optional gravity drop, detects hits via raycast sweep,
## and applies impulse/splash effect on impact.

extends Node3D
class_name RocketProjectile

@export var speed: float = 95.0
@export var gravity_drop: float = 2.5
@export var lifetime: float = 6.0
@export var blast_radius: float = 8.0
@export var blast_impulse: float = 12000.0
@export var vehicle_damage: float = 120.0  ## Max splash damage to vehicles (falls off with distance)
@export var infantry_damage: float = 80.0  ## Max splash damage to infantry

var velocity: Vector3 = Vector3.ZERO
var shooter: Node3D = null
var age: float = 0.0
var has_exploded: bool = false


func launch(forward_dir: Vector3, inherited_velocity: Vector3 = Vector3.ZERO, owner_node: Node3D = null) -> void:
	velocity = forward_dir.normalized() * speed + inherited_velocity
	shooter = owner_node
	look_at(global_position + velocity.normalized(), Vector3.UP)


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
	var query := PhysicsRayQueryParameters3D.create(global_position, next_pos, 5)  # World (1) + Vehicles (4)
	if shooter and shooter is CollisionObject3D:
		query.exclude = [(shooter as CollisionObject3D).get_rid()]

	var result := space_state.intersect_ray(query)
	if result:
		_explode(result.position)
	else:
		global_position = next_pos
		if velocity.length_squared() > 0.1:
			look_at(global_position + velocity.normalized(), Vector3.UP)


func _explode(hit_pos: Vector3) -> void:
	has_exploded = true
	global_position = hit_pos

	# Apply radial physics impulse to nearby RigidBody3D vehicles/objects
	var space_state := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = blast_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), hit_pos)
	params.collision_mask = 6  # Players (2) + Vehicles (4)

	for hit in space_state.intersect_shape(params, 16):
		var body: Object = hit.get("collider")
		if body is RigidBody3D:
			var offset: Vector3 = (body as RigidBody3D).global_position - hit_pos
			var dist := maxf(0.5, offset.length())
			var falloff := clampf(1.0 - (dist / blast_radius), 0.0, 1.0)
			var dir := offset.normalized() if offset.length_squared() > 0.01 else Vector3.UP
			(body as RigidBody3D).apply_central_impulse((dir + Vector3.UP * 0.35).normalized() * blast_impulse * falloff)
			# Apply splash damage to HealthComponent if present
			var hc: HealthComponent = (body as Node).find_child("HealthComponent", true, false) as HealthComponent
			if hc:
				hc.take_damage(vehicle_damage * falloff, shooter)
		elif body is CharacterBody3D:
			# Infantry splash damage
			var offset: Vector3 = (body as CharacterBody3D).global_position - hit_pos
			var dist := maxf(0.5, offset.length())
			var falloff := clampf(1.0 - (dist / blast_radius), 0.0, 1.0)
			var hc: HealthComponent = (body as Node).find_child("HealthComponent", true, false) as HealthComponent
			if hc:
				hc.take_damage(infantry_damage * falloff, shooter)

	# Visual flash sphere that expands and fades out
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 3.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.15, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.05)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = mat
	flash.mesh = sphere
	var scene_root: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	scene_root.add_child(flash)
	flash.global_position = hit_pos

	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 3.5, 0.25)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tween.chain().tween_callback(flash.queue_free)

	queue_free()
