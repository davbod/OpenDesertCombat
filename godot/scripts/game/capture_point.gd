## Capture Point (Flag)
## An Area3D that tracks players and vehicles in its zone and moves ownership between teams.
## Progress runs from -1.0 (fully OPFOR) to +1.0 (fully USMC). Attackers must first drag an
## enemy flag back through 0 (neutralise it) before raising their own. Owned flags stay owned
## when nobody is near; a partly drained flag drifts back to its owner.

extends Area3D
class_name CapturePoint

signal captured(point_name: String, team: int)  ## team == Teams.NONE means neutralised

const GROUP: StringName = &"capture_points"

@export var point_name: String = "Alpha"
@export var capture_time: float = 10.0  ## Seconds for one soldier to swing progress by 1.0
@export var max_capture_multiplier: int = 4  ## Extra attackers speed capture up to this factor
@export_enum("Neutral", "USMC", "OPFOR") var initial_team: int = 0
@export var capturable: bool = true  ## false for main-base flags that can never change hands
@export var flag_mesh: MeshInstance3D  ## Flag banner mesh
@export var flag_low_height: float = 1.5  ## Banner height (local) when fully lowered
@export var base_banner_scale: float = 1.6  ## Main-base flags fly a bigger banner

## State
var owning_team: int = Teams.NONE
var capture_progress: float = 0.0  ## -1.0 (OPFOR) to 1.0 (USMC)

var _bodies: Array[Node3D] = []
var _flag_material: StandardMaterial3D
var _flag_high_height: float = 9.0
var _shown_team: int = -1
var _initialised: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)
	# Set the starting owner before any _ready runs, so base spawns see it on load
	if not _initialised:
		_initialised = true
		owning_team = initial_team
		capture_progress = _rest_progress(owning_team)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if flag_mesh:
		_flag_high_height = flag_mesh.position.y
		_flag_material = StandardMaterial3D.new()
		flag_mesh.material_override = _flag_material
	if not capturable:
		_apply_main_base_look()
	_update_flag_visual()


## Main bases read differently from capturable flags: a bigger banner and a team-coloured
## ring around the pole.
func _apply_main_base_look() -> void:
	if flag_mesh:
		var half_height := 0.9  # banner mesh is 1.8 m tall
		flag_mesh.scale = Vector3(base_banner_scale, base_banner_scale, 1.0)
		flag_mesh.position.x *= base_banner_scale  # keep the banner's edge on the pole
		_flag_high_height -= half_height * (base_banner_scale - 1.0)  # keep its top below the pole tip
	var ring := MeshInstance3D.new()
	ring.name = "BaseRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 3.0
	torus.outer_radius = 3.6
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.35, 1.0)
	var mat := StandardMaterial3D.new()
	var color := Teams.color_of(owning_team)
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.35
	ring.material_override = mat
	add_child(ring)


func _on_body_entered(body: Node3D) -> void:
	if (body is PlayerController or body.has_method("enter_vehicle")) and not _bodies.has(body):
		_bodies.append(body)


func _on_body_exited(body: Node3D) -> void:
	_bodies.erase(body)


func _physics_process(delta: float) -> void:
	if not capturable:
		return
	var counts := get_team_counts()
	var diff: int = clampi(counts[Teams.USMC] - counts[Teams.OPFOR], -max_capture_multiplier, max_capture_multiplier)
	var step := delta / capture_time
	if diff != 0:
		capture_progress = clampf(capture_progress + step * diff, -1.0, 1.0)
	elif counts[Teams.USMC] == 0:
		# Nobody here: drift back to the owner's full height (or to neutral)
		capture_progress = move_toward(capture_progress, _rest_progress(owning_team), step * 0.5)
	# else: equal numbers from both teams — contested, progress holds

	_update_owner()
	_update_flag_visual()


## Living soldiers per team inside the zone. Occupied vehicles count once for their crew's team;
## dead players and empty vehicles don't count.
func get_team_counts() -> Dictionary:
	var counts := {Teams.USMC: 0, Teams.OPFOR: 0}
	for body in _bodies:
		if not is_instance_valid(body):
			continue
		if body is PlayerController and not (body as PlayerController).is_alive():
			continue
		var team := Teams.of(body)
		if counts.has(team):
			counts[team] += 1
	return counts


func has_body(body: Node3D) -> bool:
	return body != null and _bodies.has(body)


## Players and vehicles currently inside the zone.
func get_bodies() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for body in _bodies:
		if is_instance_valid(body):
			result.append(body)
	return result


func _update_owner() -> void:
	var new_owner := owning_team
	if capture_progress >= 1.0:
		new_owner = Teams.USMC
	elif capture_progress <= -1.0:
		new_owner = Teams.OPFOR
	elif owning_team == Teams.USMC and capture_progress <= 0.0:
		new_owner = Teams.NONE
	elif owning_team == Teams.OPFOR and capture_progress >= 0.0:
		new_owner = Teams.NONE

	if new_owner != owning_team:
		owning_team = new_owner
		captured.emit(point_name, owning_team)


func _rest_progress(team: int) -> float:
	match team:
		Teams.USMC:
			return 1.0
		Teams.OPFOR:
			return -1.0
	return 0.0


## Banner height follows progress; colour is the owner's, or the team raising a neutral flag.
func _update_flag_visual() -> void:
	if not flag_mesh or not _flag_material:
		return
	flag_mesh.position.y = lerpf(flag_low_height, _flag_high_height, absf(capture_progress))
	var shown := owning_team
	if shown == Teams.NONE:
		if capture_progress > 0.0:
			shown = Teams.USMC
		elif capture_progress < 0.0:
			shown = Teams.OPFOR
	if shown != _shown_team:
		_shown_team = shown
		_flag_material.albedo_color = Teams.color_of(shown)
