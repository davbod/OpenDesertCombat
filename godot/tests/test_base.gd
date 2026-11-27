## Shared base for the headless test suites in this folder.
##
## A suite starts with `extends "res://tests/test_base.gd"`, overrides `_run()` and ends
## it with `_finish()`. The base calls `_run()` once the SceneTree is up, so suites can
## `await` physics ticks. Output contract (read by run_all.sh): one `  PASS  ` or
## `  FAIL  ` line per check, then a `N failure(s)` summary; exit code 0 = all passed.
##
## Run every suite with godot/tests/run_all.sh, or one directly from the repository root
## (after an --import pass):
##   <godot> --headless --path godot/ --script res://tests/<suite>.gd

extends SceneTree

const TEST_DESERT := "res://scenes/maps/test_desert.tscn"

var failures: PackedStringArray = []
## The map loaded by _load_map(); _find() searches it and test actors are added to it.
var map: Node
## Physics ticks waited through _ticks() / _seconds() since the suite started.
var ticks_waited: int = 0


func _initialize() -> void:
	_run.call_deferred()


## The suite body. Override it, and call _finish() at the end.
func _run() -> void:
	_fail("suite does not override _run()")
	_finish()


# --- Checks and exit ---

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  " + msg)
	else:
		print("  FAIL  " + msg)
		failures.append(msg)


func _fail(msg: String) -> void:
	failures.append(msg)
	print("  FAIL  " + msg)


## Prints the summary and quits with exit code 1 if any check failed. Call it once,
## then return from _run().
func _finish() -> void:
	print("\n%d failure(s)" % failures.size())
	# Don't leave simulated key presses behind (e.g. a held throttle)
	for action: StringName in InputMap.get_actions():
		if Input.is_action_pressed(action):
			Input.action_release(action)
	quit(1 if failures.size() > 0 else 0)


# --- Waiting (suites run in real time, physics at 60 Hz) ---

func _ticks(n: int) -> void:
	for i in range(n):
		await physics_frame
		ticks_waited += 1


func _seconds(s: float) -> void:
	await _ticks(ceili(s * Engine.physics_ticks_per_second))


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


## Seconds of physics time waited so far (ticks_waited at the project's tick rate).
func _elapsed() -> float:
	return float(ticks_waited) / Engine.physics_ticks_per_second


# --- Scene setup ---

## Instances a map scene as the current scene and remembers it in `map`.
func _load_map(path: String) -> Node:
	var scene := load(path) as PackedScene
	if not scene:
		_fail("could not load %s" % path)
		return null
	map = scene.instantiate()
	root.add_child(map)
	current_scene = map
	return map


## Finds a node by name anywhere in the loaded map (or the whole tree before one is loaded).
func _find(node_name: String) -> Node:
	return (map if map else root).find_child(node_name, true, false)


## A bare Node3D with a team, standing in for an attacker.
func _make_actor(team: int) -> Node3D:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar team: int = 0\n"
	script.reload()
	var node := Node3D.new()
	node.set_script(script)
	node.set("team", team)
	(map if map else root).add_child(node)
	return node


## A kinematic body on the Vehicles layer that capture points count for `team`.
func _make_contester(team: int, pos: Vector3) -> CharacterBody3D:
	var script := GDScript.new()
	script.source_code = "extends CharacterBody3D\nvar team: int = 0\nvar is_occupied: bool = true\nfunc enter_vehicle(_p: Node3D) -> int:\n\treturn 0\n"
	script.reload()
	var body := CharacterBody3D.new()
	body.set_script(script)
	body.set("team", team)
	body.collision_layer = 4
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 2, 2)
	shape.shape = box
	body.add_child(shape)
	(map if map else root).add_child(body)
	body.global_position = pos
	return body


## Moves a body and stops it (character velocity, or rigid linear and angular velocity).
func _teleport(body: Node3D, pos: Vector3) -> void:
	body.global_position = pos
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
	if body is RigidBody3D:
		(body as RigidBody3D).linear_velocity = Vector3.ZERO
		(body as RigidBody3D).angular_velocity = Vector3.ZERO


## Horizontal (XZ) distance between two nodes.
func _flat_dist(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()
