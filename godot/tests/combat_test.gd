## Headless test for the Hardening combat fixes — the rifle and RPG hit soldiers, the tank's
## HE shell hurts infantry (direct hit and splash) and credits its crew, helicopter rockets and
## bombs credit the pilot who fired them (even one who bailed out), splash hits a multi-shape
## vehicle once, a bomb's direct hit counts once, and ticket bleed grows with the flag lead.
## Run with godot/tests/run_all.sh, or alone from the repository root (after an --import pass):
##   <godot> --headless --path godot/ --script res://tests/combat_test.gd
## Exits non-zero if any check fails. Shared helpers live in test_base.gd.

extends "res://tests/test_base.gd"

const INFANTRY_RANGE := Vector3(-300, 0, 200)  ## Empty desert, far from flags and buildings
const TANK_RANGE := Vector3(-500, 0, 200)
const BOMB_RANGE := Vector3(-700, 0, 200)
const HELI_RANGE := Vector3(-900, 0, 200)

var player: PlayerController
var match_mgr: MatchManager
var conquest: ConquestManager
var alpha: CapturePoint
var bravo: CapturePoint
var tank: TankController
var deaths_seen: Array = []  # [victim, killer] from participant_died


func _run() -> void:
	if not _load_map(TEST_DESERT):
		_finish()
		return
	player = _find("Player") as PlayerController
	match_mgr = _find("MatchManager") as MatchManager
	conquest = _find("ConquestManager") as ConquestManager
	alpha = _find("CapturePointAlpha") as CapturePoint
	bravo = _find("CapturePointBravo") as CapturePoint
	tank = _find("Tank") as TankController
	if not (player and match_mgr and conquest and alpha and bravo and tank and _find("Jet") and _find("OPFORTank")
			and _find("Helicopter")):
		_fail("test_desert.tscn is missing a required node")
		_finish()
		return
	match_mgr.participant_died.connect(func(v: Participant, k: Participant) -> void: deaths_seen.append([v, k]))
	await _ticks(10)

	await _test_rifle()
	await _test_rpg()
	await _test_tank_cannon()
	await _test_helicopter_rockets()
	await _test_vehicle_splash()
	await _test_bomb()
	await _test_ticket_bleed()
	_finish()


func _test_rifle() -> void:
	print("\n-- Rifle hits soldiers; friendly fire stays off")
	_teleport(player, INFANTRY_RANGE + Vector3(0, 0.9, 0))
	var enemy := _make_soldier(Teams.OPFOR, INFANTRY_RANGE + Vector3(0, 0, -20))
	var friend := _make_soldier(Teams.USMC, INFANTRY_RANGE + Vector3(4, 0, -20))
	await _ticks(5)

	var hc := _hc(enemy)
	_aim_player_at(enemy.global_position)
	for i in range(3):
		player._fire_rifle()
	_check(not hc.is_dead() and is_equal_approx(hc.current_health, 25.0), "3 rifle hits leave an enemy soldier at 25 hp (%.0f)" % hc.current_health)
	player._fire_rifle()
	_check(hc.is_dead(), "the 4th rifle hit kills the enemy soldier")
	_retire(enemy)

	var friend_hc := _hc(friend)
	_aim_player_at(friend.global_position)
	for i in range(4):
		player._fire_rifle()
	_check(is_equal_approx(friend_hc.current_health, friend_hc.max_health), "4 rifle hits don't hurt a teammate (%.0f hp)" % friend_hc.current_health)
	_retire(friend)


func _test_rpg() -> void:
	print("\n-- RPG: full damage on a direct hit; splash hurts enemies, not teammates")
	var rocket := player.rocket_scene.instantiate() as RocketProjectile
	var full_damage := rocket.infantry_damage
	rocket.free()

	var target := _make_soldier(Teams.OPFOR, INFANTRY_RANGE + Vector3(0, 0, -15))
	await _ticks(3)
	_aim_player_at(target.global_position)
	player._fire_rpg()
	await _seconds(0.5)
	var hc := _hc(target)
	var taken := hc.max_health - hc.current_health
	_check(is_equal_approx(taken, full_damage), "direct hit deals the full %.0f once, no splash on top (took %.0f)" % [full_damage, taken])
	_retire(target)

	var impact := INFANTRY_RANGE + Vector3(0, 0, -12)
	var enemy := _make_soldier(Teams.OPFOR, impact + Vector3(-2, 0, 0))
	var friend := _make_soldier(Teams.USMC, impact + Vector3(2, 0, 0))
	await _ticks(3)
	_aim_player_at(impact)
	player._fire_rpg()
	await _seconds(0.5)
	var enemy_hc := _hc(enemy)
	var friend_hc := _hc(friend)
	var splash := enemy_hc.max_health - enemy_hc.current_health
	_check(splash > 0.0 and splash < full_damage, "splash hurts an enemy 2 m from the impact, with falloff (took %.0f)" % splash)
	_check(is_equal_approx(friend_hc.current_health, friend_hc.max_health), "splash spares a teammate 2 m from the impact (%.0f hp)" % friend_hc.current_health)
	_check(is_equal_approx(player.health_component.current_health, player.health_component.max_health), "the shooter, 12 m away, is unhurt")
	_retire(enemy)
	_retire(friend)


func _test_tank_cannon() -> void:
	print("\n-- Tank: HE shell kills soldiers by direct hit and splash; the crew gets the kills")
	_place(tank, TANK_RANGE + Vector3(0, 1.0, 0))
	await _seconds(1.0)
	player._enter_vehicle(tank)
	var fwd := _flat(-tank.global_transform.basis.z)
	var side := _flat(tank.global_transform.basis.x)
	var ground := Vector3(tank.global_position.x, 0.0, tank.global_position.z)

	var direct := _make_soldier(Teams.OPFOR, ground + fwd * 16.0)
	var direct_p := match_mgr.register(direct, "Direct", Teams.OPFOR)
	var impact := ground + fwd * 30.0
	var near := _make_soldier(Teams.OPFOR, impact + side * 1.5)
	var near_p := match_mgr.register(near, "Near", Teams.OPFOR)
	var friend := _make_soldier(Teams.USMC, impact - side * 1.5)
	await _ticks(3)
	var crew := player.participant
	var kills_before := crew.kills

	_aim_tank_at(direct.global_position)
	tank._fire_cannon()
	_check(_hc(direct).is_dead(), "a direct hit kills a soldier (%.0f damage)" % tank.cannon_damage)
	_check(deaths_seen.size() > 0 and deaths_seen.back() == [direct_p, crew], "participant_died names the tank's occupant as the killer")
	_check(crew.kills == kills_before + 1, "occupant credited with the kill (kills %d)" % crew.kills)
	_retire(direct)
	await _ticks(2)

	tank._fire_cooldown = 0.0
	_aim_tank_at(impact)
	tank._fire_cannon()
	var near_hc := _hc(near)
	_check(near_hc.is_dead() or near_hc.current_health <= 40.0, "a shell landing 1.5 m from a soldier kills or badly hurts him (%.0f hp)" % near_hc.current_health)
	if near_hc.is_dead():
		_check(deaths_seen.back() == [near_p, crew] and crew.kills == kills_before + 2, "splash kill credited to the occupant (kills %d)" % crew.kills)
	var friend_hc := _hc(friend)
	_check(is_equal_approx(friend_hc.current_health, friend_hc.max_health), "splash spares a teammate 1.5 m from the impact (%.0f hp)" % friend_hc.current_health)
	_retire(near)
	_retire(friend)
	player._exit_vehicle()


func _test_helicopter_rockets() -> void:
	print("\n-- Helicopter rockets spare teammates and credit the pilot, even one who bailed out")
	var heli := _find("Helicopter") as HelicopterController
	heli.freeze = true  # hover in place
	player._enter_vehicle(heli)
	var crew := player.participant
	for bail_out: bool in [false, true]:
		var when := "after the pilot bails out" if bail_out else "with the pilot aboard"
		# Soldiers 1.5 m either side of the aim point, along the line of fire; the rocket comes
		# from a wing pod 2.1 m off the centre line, so both are in the splash, neither hit directly.
		var impact := HELI_RANGE + Vector3(30.0 if bail_out else 0.0, 0.0, 0.0)
		var enemy := _make_soldier(Teams.OPFOR, impact + Vector3(0, 0, -1.5))
		var enemy_p := match_mgr.register(enemy, "Heli target", Teams.OPFOR)
		var friend := _make_soldier(Teams.USMC, impact + Vector3(0, 0, 1.5))
		var from := impact + Vector3(0, 12, 20)
		heli.global_transform = Transform3D(Basis.looking_at(impact - from), from)
		await _ticks(3)
		_hc(enemy).current_health = 1.0  # any hit kills
		var kills_before := crew.kills

		heli._fire_hydra_rocket()
		if bail_out:
			player._exit_vehicle()
		await _seconds(0.5)
		_check(_hc(enemy).is_dead(), "a rocket kills an enemy %s" % when)
		_check(deaths_seen.size() > 0 and deaths_seen.back() == [enemy_p, crew] and crew.kills == kills_before + 1,
				"the pilot gets the kill %s (kills %d)" % [when, crew.kills])
		var friend_hc := _hc(friend)
		_check(is_equal_approx(friend_hc.current_health, friend_hc.max_health), "splash spares a teammate %s (%.0f hp)" % [when, friend_hc.current_health])
		_retire(enemy)
		_retire(friend)


func _test_vehicle_splash() -> void:
	print("\n-- Splash hits a vehicle with several collision shapes once")
	var target := _find("OPFORTank") as RigidBody3D
	_place(target, BOMB_RANGE + Vector3(0, 1.0, 0))
	await _seconds(1.0)
	var rocket := player.rocket_scene.instantiate() as RocketProjectile
	var radius := rocket.blast_radius
	var full_damage := rocket.vehicle_damage
	rocket.free()

	# A rocket blast half its radius beside the empty tank, level with its origin: falloff 0.5
	var origin := target.global_position + _flat(target.global_transform.basis.x) * radius * 0.5
	var shapes := _shapes_in_blast(target, origin, radius)
	_check(shapes > 1, "the blast touches several of the tank's collision shapes (%d)" % shapes)
	var hc := _hc(target)
	Explosion.detonate(target, origin, radius, full_damage, 0.0, 0.0, null)
	var taken := hc.max_health - hc.current_health
	_check(is_equal_approx(taken, full_damage * 0.5), "the tank takes the splash once: %.0f × 0.5 falloff (took %.0f)" % [full_damage, taken])
	hc.reset()


func _test_bomb() -> void:
	print("\n-- Jet bomb: a direct hit on a vehicle counts once; the pilot is credited after bailing out")
	var jet := _find("Jet") as JetController
	var target := _find("OPFORTank") as RigidBody3D
	_place(target, BOMB_RANGE + Vector3(0, 1.0, 0))
	var friend := _make_soldier(Teams.USMC, BOMB_RANGE + Vector3(6, 0, 0))
	await _seconds(1.0)
	jet.freeze = true  # hold the jet in the air above the target
	jet.global_transform = Transform3D(Basis(), target.global_position + Vector3(0, 40, 0))
	player._enter_vehicle(jet)
	await _ticks(2)
	var hc := _hc(target)
	var attackers: Array[Node3D] = []
	hc.damaged.connect(func(_amount: float, attacker: Node3D) -> void: attackers.append(attacker))

	jet._drop_bomb()
	var bomb := map.get_child(map.get_child_count() - 1) as RocketProjectile
	_check(bomb != null, "the jet dropped a bomb")
	var bomb_damage := bomb.vehicle_damage if bomb else -1.0
	player._exit_vehicle()
	_teleport(player, INFANTRY_RANGE + Vector3(0, 0.9, 0))  # well clear of the blast
	await _seconds(3.5)
	var taken := hc.max_health - hc.current_health
	_check(is_equal_approx(taken, bomb_damage), "empty tank took the bomb's %.0f exactly once, no splash on top (took %.0f)" % [bomb_damage, taken])
	_check(attackers == [player], "the bomb's damage is credited to the pilot who dropped it, not the empty jet")
	var friend_hc := _hc(friend)
	_check(is_equal_approx(friend_hc.current_health, friend_hc.max_health), "splash spares a teammate 6 m away after the pilot bailed out (%.0f hp)" % friend_hc.current_health)
	_retire(friend)


func _test_ticket_bleed() -> void:
	print("\n-- Ticket bleed grows with the flag lead")
	var updates := {Teams.USMC: [], Teams.OPFOR: []}
	var drop_frames: Array[int] = []  # physics frame of each USMC ticket drop
	conquest.ticket_updated.connect(func(team: int, value: int) -> void:
		updates[team].append(value)
		if team == Teams.USMC:
			drop_frames.append(Engine.get_physics_frames())
	)
	_check(conquest.get_bleed_per_second(Teams.USMC) == 0.0 and conquest.get_bleed_per_second(Teams.OPFOR) == 0.0, "no bleed while both teams hold only their base")

	var usmc_start: int = conquest.tickets[Teams.USMC]
	var opfor_start: int = conquest.tickets[Teams.OPFOR]
	_set_owner(alpha, Teams.OPFOR)
	_check(is_equal_approx(conquest.get_bleed_per_second(Teams.USMC), 0.5), "1-flag lead on 4 flags: USMC bleeds %.2f ticket/s" % conquest.get_bleed_per_second(Teams.USMC))
	await _seconds(8.0)
	var bled_one: int = usmc_start - conquest.tickets[Teams.USMC]
	var gap_one := _mean_gap(drop_frames)
	_check(absi(bled_one - 4) <= 1, "1-flag lead bleeds ≈ 4 tickets in 8 s (%d)" % bled_one)

	var usmc_mid: int = conquest.tickets[Teams.USMC]
	_set_owner(bravo, Teams.OPFOR)
	_check(is_equal_approx(conquest.get_bleed_per_second(Teams.USMC), 1.0), "2-flag lead: USMC bleeds %.2f ticket/s" % conquest.get_bleed_per_second(Teams.USMC))
	drop_frames.clear()
	await _seconds(8.0)
	var bled_two: int = usmc_mid - conquest.tickets[Teams.USMC]
	var gap_two := _mean_gap(drop_frames)
	_check(absi(bled_two - 8) <= 1, "2-flag lead bleeds ≈ 8 tickets in 8 s (%d)" % bled_two)
	# Whole-ticket counts over a window are ±1; the time between drops measures the rate exactly
	_check(gap_two > 0.0 and absf(gap_one / gap_two - 2.0) < 0.1, "a 1-flag lead bleeds half as fast as a 2-flag lead (a ticket every %.2f s vs %.2f s)" % [gap_one, gap_two])
	_check(conquest.tickets[Teams.OPFOR] == opfor_start and updates[Teams.OPFOR].is_empty(), "the leading team doesn't bleed")

	var usmc_updates: Array = updates[Teams.USMC]
	var whole_steps := typeof(conquest.tickets[Teams.USMC]) == TYPE_INT
	var previous := usmc_start
	for value: int in usmc_updates:
		whole_steps = whole_steps and value == previous - 1
		previous = value
	_check(whole_steps and usmc_updates.size() == bled_one + bled_two, "tickets drop one whole ticket at a time, one ticket_updated each (%d updates for %d tickets)" % [usmc_updates.size(), bled_one + bled_two])


# --- Helpers (the shared ones are in test_base.gd) ---

## A stand-in soldier: a capsule like the player's on the Players layer, with a team and a
## HealthComponent (100 hp). `ground_pos` is where its feet are.
func _make_soldier(team: int, ground_pos: Vector3) -> CharacterBody3D:
	var script := GDScript.new()
	script.source_code = "extends CharacterBody3D\nvar team: int = 0\n"
	script.reload()
	var body := CharacterBody3D.new()
	body.set_script(script)
	body.set("team", team)
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	body.add_child(shape)
	var hc := (load("res://scripts/game/health_component.gd") as GDScript).new() as HealthComponent
	hc.name = "HealthComponent"
	body.add_child(hc)
	map.add_child(body)
	body.global_position = ground_pos + Vector3(0, 0.9, 0)
	return body


## Takes a stand-in out of play without freeing it (MatchManager may still reference it).
func _retire(body: CollisionObject3D) -> void:
	body.collision_layer = 0
	body.visible = false


func _hc(body: Node) -> HealthComponent:
	return body.find_child("HealthComponent", true, false) as HealthComponent


## Turns the player (yaw) and the camera pivot (pitch) so the camera looks at `target`.
func _aim_player_at(target: Vector3) -> void:
	var to := target - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.camera_pivot.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


## Turns the turret (yaw) and elevates the barrel (pitch, within its limits) at `target`.
func _aim_tank_at(target: Vector3) -> void:
	var from_turret := tank.to_local(target) - tank.turret_pivot.position
	var yaw := atan2(-from_turret.x, -from_turret.z)
	tank.turret_pivot.rotation.y = yaw
	var from_barrel := tank.turret_pivot.global_transform.affine_inverse() * target - tank.barrel_pivot.position
	var pitch := clampf(atan2(from_barrel.y, Vector2(from_barrel.x, from_barrel.z).length()),
			deg_to_rad(tank.barrel_pitch_min), deg_to_rad(tank.barrel_pitch_max))
	tank.barrel_pivot.rotation.x = pitch
	tank._turret_yaw = yaw
	tank._barrel_pitch = pitch


## Hands a flag to `team` outright, as if it had just been captured.
func _set_owner(point: CapturePoint, team: int) -> void:
	point.owning_team = team
	point.capture_progress = 1.0 if team == Teams.USMC else -1.0


## How many of `body`'s collision shapes a blast of `radius` at `origin` touches (the same
## query Explosion.detonate() makes).
func _shapes_in_blast(body: CollisionObject3D, origin: Vector3, radius: float) -> int:
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	params.shape = sphere
	params.transform = Transform3D(Basis(), origin)
	params.collision_mask = Explosion.SPLASH_MASK
	var count := 0
	for hit: Dictionary in body.get_world_3d().direct_space_state.intersect_shape(params, Explosion.MAX_SPLASH_SHAPES):
		if hit.get("collider") == body:
			count += 1
	return count


## Like _teleport(), but also stands the body upright with no rotation.
func _place(body: RigidBody3D, pos: Vector3) -> void:
	body.global_basis = Basis()
	_teleport(body, pos)


## Horizontal unit vector of `v`.
func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()


## Mean time in seconds between consecutive events, from their physics frame numbers.
func _mean_gap(frames: Array[int]) -> float:
	if frames.size() < 2:
		return 0.0
	return float(frames.back() - frames.front()) / float(frames.size() - 1) / Engine.physics_ticks_per_second

