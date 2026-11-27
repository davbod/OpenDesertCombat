## Explosion — one high-explosive detonation, shared by rockets, bombs and the tank cannon:
## splash damage with linear falloff, a push for rigid bodies in the blast, and a flash.
##
## The body a projectile struck directly takes its direct-hit damage once and no splash on top.
## Every hit goes through HealthComponent.take_damage() with `attacker`, so the friendly-fire
## rule and kill credit work exactly as for any other weapon.

class_name Explosion
extends RefCounted

const PLAYERS_LAYER: int = 2
const SPLASH_MASK: int = 6  ## Players (2) + Vehicles (4)
const MAX_SPLASH_SHAPES: int = 64  ## The query returns shapes; a vehicle can return several
const MIN_DISTANCE: float = 0.5  ## Closer than this counts as point blank
const LIFT: float = 0.35  ## Upward share of the blast push, so vehicles hop rather than slide
const FLASH_RADIUS_PER_METRE: float = 0.1875  ## Flash size per metre of blast (8 m rocket → 1.5 m)


## Detonates at `origin`.
## - `vehicle_damage` / `infantry_damage`: splash at the centre of the blast, falling off
##   linearly to 0 at `radius` (measured to each body's origin).
## - `impulse`: push for every RigidBody3D in the blast, with the same falloff.
## - `attacker`: who is credited for the damage (the shooter, or a vehicle's occupant).
## - `direct_hit_body`: the body the projectile struck, or null. It takes `direct_damage`
##   (when negative: the full vehicle or infantry damage, no falloff) and no splash damage.
## - `source`: any node in the world; gives the physics space and the scene for the flash.
static func detonate(source: Node3D, origin: Vector3, radius: float, vehicle_damage: float,
		infantry_damage: float, impulse: float, attacker: Node3D,
		direct_hit_body: Object = null, direct_damage: float = -1.0) -> void:
	if direct_hit_body and is_instance_valid(direct_hit_body):
		var amount := direct_damage
		if amount < 0.0:
			amount = infantry_damage if is_infantry(direct_hit_body) else vehicle_damage
		_damage(direct_hit_body, amount, attacker)

	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	params.shape = sphere
	params.transform = Transform3D(Basis(), origin)
	params.collision_mask = SPLASH_MASK

	var seen := {}
	for hit in source.get_world_3d().direct_space_state.intersect_shape(params, MAX_SPLASH_SHAPES):
		var body := hit.get("collider") as Node3D
		if body == null or seen.has(body.get_instance_id()):
			continue
		seen[body.get_instance_id()] = true

		var offset := body.global_position - origin
		var falloff := clampf(1.0 - maxf(MIN_DISTANCE, offset.length()) / radius, 0.0, 1.0)
		if body is RigidBody3D and impulse > 0.0:
			var dir := offset.normalized() if offset.length_squared() > 0.01 else Vector3.UP
			(body as RigidBody3D).apply_central_impulse((dir + Vector3.UP * LIFT).normalized() * impulse * falloff)
		if body != direct_hit_body:
			_damage(body, (infantry_damage if is_infantry(body) else vehicle_damage) * falloff, attacker)

	_spawn_flash(source, origin, radius * FLASH_RADIUS_PER_METRE)


## Soldiers are on the Players layer; everything else that takes damage counts as a vehicle.
static func is_infantry(body: Object) -> bool:
	return body is CollisionObject3D and ((body as CollisionObject3D).collision_layer & PLAYERS_LAYER) != 0


static func _damage(body: Object, amount: float, attacker: Node3D) -> void:
	if not (body is Node):
		return
	var hc := (body as Node).find_child("HealthComponent", true, false) as HealthComponent
	if hc:
		hc.take_damage(amount, attacker)


## An expanding sphere that fades out. Placeholder until the particle pass.
static func _spawn_flash(source: Node3D, origin: Vector3, flash_radius: float) -> void:
	var tree := source.get_tree()
	if tree == null:
		return
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = flash_radius
	sphere.height = flash_radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.15, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.05)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = mat
	flash.mesh = sphere
	var scene_root: Node = tree.current_scene if tree.current_scene else tree.root
	scene_root.add_child(flash)
	flash.global_position = origin

	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 3.5, 0.25)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tween.chain().tween_callback(flash.queue_free)
