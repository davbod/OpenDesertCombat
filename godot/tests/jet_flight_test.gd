## Headless flight-model smoke test for JetController.
## Run with godot/tests/run_all.sh, or alone from the repository root (after an --import pass):
##   <godot> --headless --path godot/ --script res://tests/jet_flight_test.gd
## Flies the jet through takeoff, climb, cruise, a hard turn and a stall attempt,
## prints telemetry, and exits non-zero if any phase misses its envelope.
## Helpers live in test_base.gd.

extends "res://tests/test_base.gd"

var jet: JetController


func _run() -> void:
	if not _load_map(TEST_DESERT):
		_finish()
		return
	jet = _find("Jet") as JetController
	if not jet:
		_fail("Jet not found in test_desert.tscn")
		_finish()
		return
	await _ticks(60)  # settle on the gear
	_log("settled")
	_check(jet.on_ground, "jet should rest on its gear")
	_check(jet.linear_velocity.length() < 1.0, "jet should be stationary on the runway")

	jet.enter_vehicle(null)
	var start_z: float = jet.global_position.z

	# --- Takeoff roll: full throttle, rotate at 70 m/s ---
	Input.action_press("move_forward")
	var liftoff_dist: float = -1.0
	for i in range(60 * 25):
		# Rotate at 70 m/s to a 12° climb attitude, then let go of the stick
		if jet.airspeed > 70.0 and _pitch_deg() < 12.0:
			jet.stick_pitch = 0.45
		await _ticks(1)
		if liftoff_dist < 0.0 and jet.altitude_agl > 5.0:
			liftoff_dist = start_z - jet.global_position.z
			_log("liftoff after %.0f m" % liftoff_dist)
		if jet.altitude_agl > 300.0:
			break
	_log("climb done")
	_check(liftoff_dist > 0.0 and liftoff_dist < 900.0, "should lift off within the 900 m runway (got %.0f m)" % liftoff_dist)
	_check(jet.altitude_agl > 300.0, "should climb past 300 m within 25 s (alt %.0f)" % jet.altitude_agl)
	_check(jet.health_component.current_health >= jet.health_component.max_health, "takeoff should cause no damage")

	# --- Cruise: 40% throttle, hands off for 10 s, should stay controllable ---
	Input.action_release("move_forward")
	jet.throttle = 0.4
	var alt_before: float = jet.global_position.y
	await _ticks(600)
	_log("cruise 10 s")
	_check(not jet.is_stalled, "should not stall in hands-off cruise")
	_check(jet.airspeed > 60.0, "should hold flying speed in cruise (got %.0f m/s)" % jet.airspeed)
	print("  INFO  altitude change in hands-off cruise: %+.0f m" % (jet.global_position.y - alt_before))

	# --- Hard turn: bank ~80° then full aft stick for 6 s, expect energy bleed ---
	jet.throttle = 0.6
	for i in range(90):
		jet.stick_roll = -0.6 if _bank_deg() < 80.0 else 0.0
		await _ticks(1)
	var speed_before_turn: float = jet.airspeed
	var last_heading: float = _heading_deg()
	var turned: float = 0.0  # accumulated per tick so turns > 180° don't wrap
	var max_aoa: float = 0.0
	for i in range(360):
		jet.stick_pitch = 1.0
		jet.stick_roll = clampf((_bank_deg() - 80.0) * 0.02, -1.0, 1.0)
		max_aoa = maxf(max_aoa, jet.angle_of_attack)
		await _ticks(1)
		var h: float = _heading_deg()
		turned += absf(wrapf(h - last_heading, -180.0, 180.0))
		last_heading = h
	jet.stick_pitch = 0.0
	_log("hard turn")
	print("  INFO  turned %.0f°, speed %.0f -> %.0f m/s, max AoA %.1f°" % [turned, speed_before_turn, jet.airspeed, rad_to_deg(max_aoa)])
	_check(turned > 120.0, "hard turn should exceed 20°/s (120° in 6 s) for dogfighting")
	_check(jet.airspeed < speed_before_turn, "a hard turn should bleed airspeed")
	_check(max_aoa < jet.stall_aoa, "AoA limiter should keep the jet out of the stall in a hard turn")

	# --- Level the wings, then stall attempt: idle + limiter off + full aft stick ---
	for i in range(240):
		jet.stick_roll = clampf(_bank_deg() * 0.03, -1.0, 1.0)
		jet.stick_pitch = 0.0
		await _ticks(1)
	_log("wings level")
	jet.aoa_limiter = false
	var saw_stall: bool = false
	for i in range(60 * 20):
		jet.throttle = 0.0
		jet.stick_pitch = 1.0
		await _ticks(1)
		if jet.is_stalled:
			saw_stall = true
			break
	_log("stall attempt")
	_check(saw_stall, "pulling at idle with the limiter off should eventually stall")

	# --- Crash: put the real Player in the seat and fly into the ground ---
	var player := _find("Player") as PlayerController
	jet.exit_vehicle(null)
	jet.aoa_limiter = true
	jet.global_position = Vector3(300.0, 40.0, -200.0)
	jet.global_transform.basis = Basis(Vector3.RIGHT, deg_to_rad(-45.0))  # nose 45° down
	jet.linear_velocity = -jet.global_transform.basis.z * 120.0
	jet.angular_velocity = Vector3.ZERO
	player._enter_vehicle(jet)
	await _ticks(120)
	_log("crash")
	_check(jet.is_destroyed, "a 120 m/s ground impact should destroy the jet")
	_check(player.health_component.current_health <= 0.0, "the pilot should die with the jet")
	_check(not player.is_in_vehicle, "the dead pilot should be ejected from the vehicle state")
	_check(player.camera_pivot.get_parent() == player, "the camera should be returned to the player")

	_finish()


func _pitch_deg() -> float:
	return rad_to_deg(asin(clampf(-jet.global_transform.basis.z.y, -1.0, 1.0)))


## Bank angle in degrees, positive = right wing down.
func _bank_deg() -> float:
	return rad_to_deg(asin(clampf(-jet.global_transform.basis.x.y, -1.0, 1.0)))


## Flight-path heading (track) in degrees — independent of nose attitude.
func _heading_deg() -> float:
	var v: Vector3 = jet.linear_velocity
	return rad_to_deg(atan2(v.x, -v.z))


func _log(label: String) -> void:
	print("[%5.1fs] %-22s alt=%6.0f m  ias=%5.0f m/s  aoa=%5.1f°  bank=%5.0f°  thr=%3d%%  stalled=%s  hp=%.0f" % [
		_elapsed(), label, jet.altitude_agl, jet.airspeed, rad_to_deg(jet.angle_of_attack), _bank_deg(),
		int(jet.throttle * 100.0), jet.is_stalled, jet.health_component.current_health])
