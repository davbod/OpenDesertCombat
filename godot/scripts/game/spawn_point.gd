## SpawnPoint — where soldiers can deploy. Belongs to whichever team holds its capture point
## (a main base is an uncapturable CapturePoint), or to a fixed `team` if it has no flag.
## Place it near its flag; spawns are spread over `spread_radius` and snapped to the ground.

extends Marker3D
class_name SpawnPoint

const GROUP: StringName = &"spawn_points"

@export var spawn_name: String = ""  ## Shown on the deploy screen; defaults to the flag's name
@export var capture_point: CapturePoint  ## Ownership follows this flag (falls back to parent flag)
@export_enum("Neutral", "USMC", "OPFOR") var team: int = 0  ## Used only when there is no flag
@export var spread_radius: float = 4.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if not capture_point and get_parent() is CapturePoint:
		capture_point = get_parent() as CapturePoint


func get_team() -> int:
	return capture_point.owning_team if capture_point else team


func get_display_name() -> String:
	if not spawn_name.is_empty():
		return spawn_name
	if capture_point:
		return capture_point.point_name
	return String(name)


## A spawn transform spread around this point, standing on the ground.
func get_spawn_transform() -> Transform3D:
	var xform := global_transform
	var angle := randf() * TAU
	var dist := sqrt(randf()) * spread_radius
	xform.origin += Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	if is_inside_tree():
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(xform.origin + Vector3.UP * 50.0, xform.origin + Vector3.DOWN * 50.0, 1)
		var hit := space.intersect_ray(query)
		if hit:
			xform.origin.y = (hit.position as Vector3).y + 1.0
	return xform
