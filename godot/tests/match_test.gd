## Headless test for Sprint 4.2 — MatchManager registry, kill credit, spawn rules, flag spawns,
## the deploy menu, and VehicleSpawn wreck / abandon / flag-ownership behaviour.
## Run with godot/tests/run_all.sh, or alone from the repository root (after an --import pass):
##   <godot> --headless --path godot/ --script res://tests/match_test.gd
## Exits non-zero if any check fails. Helpers live in test_base.gd.

extends "res://tests/test_base.gd"

var player: PlayerController
var match_mgr: MatchManager
var conquest: ConquestManager
var kit_menu: KitSelectMenu
var alpha: CapturePoint
var spawn_usmc: SpawnPoint
var spawn_opfor: SpawnPoint
var spawn_alpha: SpawnPoint

var enemy: Node3D
var enemy_p: Participant
var deaths_seen: Array = []  # [victim, killer] from participant_died


func _run() -> void:
	if not _load_map(TEST_DESERT):
		_finish()
		return
	player = _find("Player") as PlayerController
	match_mgr = _find("MatchManager") as MatchManager
	conquest = _find("ConquestManager") as ConquestManager
	kit_menu = _find("KitSelectMenu") as KitSelectMenu
	alpha = _find("CapturePointAlpha") as CapturePoint
	spawn_usmc = _find("SpawnUSMC") as SpawnPoint
	spawn_opfor = _find("SpawnOPFOR") as SpawnPoint
	spawn_alpha = _find("SpawnAlpha") as SpawnPoint
	if not (player and match_mgr and conquest and kit_menu and alpha and spawn_usmc and spawn_opfor and spawn_alpha):
		_fail("test_desert.tscn is missing a required node")
		_finish()
		return
	match_mgr.respawn_time = 1.0
	alpha.capture_time = 2.0
	match_mgr.participant_died.connect(func(v: Participant, k: Participant) -> void: deaths_seen.append([v, k]))
	await _ticks(10)

	_test_registry_and_start_state()
	_test_kill_credit()
	await _test_spawn_rules()
	await _test_flag_gives_spawns_vehicles_and_score()
	await _test_deploy_at_flag_through_menu()
	await _test_lost_flag()
	await _test_main_bases_cannot_be_captured()
	await _test_vehicle_wreck_and_respawn()
	await _test_abandoned_vehicle()
	_finish()


func _test_registry_and_start_state() -> void:
	print("\n-- Registry & start state")
	var p := player.participant
	_check(p != null and p.id == 1 and p.is_local, "local player registered as participant #1")
	_check(p != null and p.team == Teams.USMC and p.alive, "participant starts alive on USMC")
	_check(match_mgr.participant_for(player) == p, "participant_for(player) finds it")
	_check(match_mgr.get_spawn_points(Teams.USMC) == [spawn_usmc], "USMC can only spawn at its base at the start")
	_check(match_mgr.get_spawn_points(Teams.OPFOR) == [spawn_opfor], "OPFOR can only spawn at its base at the start")
	for vname: String in ["Tank", "Humvee", "Helicopter", "Jet", "OPFORTank", "OPFORHumvee"]:
		_check(_find(vname) != null, "%s spawned at its main base" % vname)
	_check(_find("AlphaHumvee") == null, "no vehicle at neutral Alpha")

	var tank := _find("Tank")
	tank.call("enter_vehicle", player)
	_check(match_mgr.participant_for(tank) == p, "participant_for(vehicle) resolves its driver")
	tank.call("exit_vehicle", player)
	_check(match_mgr.participant_for(tank) == null, "empty vehicle has no participant")


func _test_kill_credit() -> void:
	print("\n-- Kill credit & tickets")
	enemy = _make_actor(Teams.OPFOR)
	enemy_p = match_mgr.register(enemy, "Enemy", Teams.OPFOR)
	_check(enemy_p.id == 2, "a second participant can join")
	var p := player.participant
	var tickets_before: int = conquest.tickets[Teams.USMC]
	player.health_component.take_damage(1000.0, enemy)
	_check(not p.alive and p.deaths == 1, "victim marked dead, deaths = 1")
	_check(enemy_p.kills == 1 and enemy_p.score == MatchManager.SCORE_KILL, "killer credited (kills %d, score %d)" % [enemy_p.kills, enemy_p.score])
	_check(conquest.tickets[Teams.USMC] == tickets_before - 1, "USMC lost a ticket")
	_check(deaths_seen.size() == 1 and deaths_seen[0] == [p, enemy_p], "participant_died(victim, killer) emitted")
	_check(kit_menu.visible, "deploy menu opened")


func _test_spawn_rules() -> void:
	print("\n-- Server-side spawn rules")
	var p := player.participant
	var reason := match_mgr.request_spawn(p, Teams.USMC, 3, spawn_usmc)
	_check(reason.begins_with("Wait"), "can't respawn before the timer (\"%s\")" % reason)
	await _seconds(1.1)
	reason = match_mgr.request_spawn(p, Teams.USMC, 3, spawn_alpha)
	_check(reason.contains("not held"), "can't spawn at a flag your team doesn't hold (\"%s\")" % reason)
	reason = match_mgr.request_spawn(p, Teams.USMC, 3, spawn_opfor)
	_check(reason.contains("not held"), "can't spawn at the enemy base (\"%s\")" % reason)
	reason = match_mgr.request_spawn(p, Teams.USMC, 3, spawn_usmc)
	_check(reason.is_empty() and p.alive and player.is_alive(), "valid request spawns the soldier")
	_check(_flat_dist(player, spawn_usmc) <= spawn_usmc.spread_radius + 0.5, "placed at the USMC base (%.1f m)" % _flat_dist(player, spawn_usmc))
	_check(is_equal_approx(player.speed_multiplier, 1.1) and is_equal_approx(player.health_component.max_health, 75.0), "Sniper kit speed (1.1×) and health (75) applied")
	reason = match_mgr.request_spawn(p, Teams.USMC, 0, spawn_usmc)
	_check(reason == "Already deployed", "a living soldier can't spawn again")
	kit_menu.close()


func _test_flag_gives_spawns_vehicles_and_score() -> void:
	print("\n-- Capturing Alpha gives spawns, vehicles and score")
	var p := player.participant
	var score_before := p.score
	_teleport(player, alpha.global_position + Vector3(0, 1.0, 0))
	await _seconds(2.6)
	_check(alpha.owning_team == Teams.USMC, "USMC captured Alpha")
	_check(match_mgr.get_spawn_points(Teams.USMC).has(spawn_alpha), "SpawnAlpha now available to USMC")
	_check(p.score == score_before + MatchManager.SCORE_CAPTURE, "capturer scored %d (score %d)" % [MatchManager.SCORE_CAPTURE, p.score])
	await _ticks(3)
	_check(_find("AlphaHumvee") != null, "Alpha's Humvee spawns for the new owner")


func _test_deploy_at_flag_through_menu() -> void:
	print("\n-- Dying and deploying at Alpha through the menu")
	player.health_component.take_damage(1000.0, enemy)
	_check(kit_menu.visible, "deploy menu opened")
	_check(kit_menu.get_available_spawns().has(spawn_alpha), "menu offers Alpha")
	_check(kit_menu.selected_spawn == spawn_usmc, "menu defaults to the main base")
	kit_menu.select_kit(3)
	kit_menu.select_spawn(spawn_alpha)
	var pressed_kits := kit_menu._kit_buttons.filter(func(b: Button) -> bool: return b.button_pressed)
	var pressed_spawns := kit_menu._spawn_buttons.values().filter(func(b: Button) -> bool: return b.button_pressed)
	_check(pressed_kits.size() == 1 and pressed_kits[0] == kit_menu._kit_buttons[3], "only the chosen kit button shows as selected")
	_check(pressed_spawns.size() == 1 and pressed_spawns[0] == kit_menu._spawn_buttons[spawn_alpha], "only the chosen spawn button shows as selected")
	kit_menu._on_confirm_pressed()  # pressed during the respawn timer → queued
	await _ticks(2)
	_check(not player.is_alive() and kit_menu.countdown_label.text.begins_with("Deploying at Alpha"), "deploy queued during the timer (\"%s\")" % kit_menu.countdown_label.text)
	await _seconds(1.2)
	_check(player.is_alive() and not kit_menu.visible, "deployed automatically when the timer ran out")
	_check(_flat_dist(player, spawn_alpha) <= spawn_alpha.spread_radius + 0.5, "placed at Alpha (%.1f m)" % _flat_dist(player, spawn_alpha))


func _test_lost_flag() -> void:
	print("\n-- Losing Alpha removes the spawn but not the vehicle in the field")
	var humvee := _find("AlphaHumvee")
	_teleport(player, Vector3(0, 1.0, 150))
	# An OPFOR soldier (not a participant) takes the flag the normal way: neutralise, then capture
	var attacker := _make_contester(Teams.OPFOR, alpha.global_position + Vector3(0, 1.0, 0))
	await _seconds(4.5)
	attacker.queue_free()
	await _ticks(3)
	_check(alpha.owning_team == Teams.OPFOR, "Alpha now OPFOR (progress %.2f)" % alpha.capture_progress)
	_check(not match_mgr.get_spawn_points(Teams.USMC).has(spawn_alpha), "USMC lost the Alpha spawn")
	_check(match_mgr.get_spawn_points(Teams.OPFOR).has(spawn_alpha), "OPFOR gained the Alpha spawn")
	_check(is_instance_valid(humvee) and _find("AlphaHumvee") == humvee, "Humvee already at Alpha is not taken away")

	player.health_component.take_damage(1000.0, enemy)
	await _seconds(1.1)
	var reason := match_mgr.request_spawn(player.participant, Teams.USMC, 0, spawn_alpha)
	_check(reason.contains("not held"), "server rejects a stale Alpha spawn request (\"%s\")" % reason)
	_check(kit_menu.selected_spawn == spawn_usmc, "menu fell back to the main base")
	kit_menu._on_confirm_pressed()
	await _ticks(3)
	_check(player.is_alive(), "redeployed at the base")


func _test_main_bases_cannot_be_captured() -> void:
	print("\n-- Main bases can't be captured, and the HUD says so")
	var hud := _find("GameHUD") as GameHUD
	var base_opfor := _find("BaseOPFOR") as CapturePoint
	_teleport(player, base_opfor.global_position + Vector3(0, 1.0, 6))
	await _seconds(1.5)
	_check(base_opfor.owning_team == Teams.OPFOR and is_equal_approx(base_opfor.capture_progress, -1.0), "USMC soldier on the OPFOR base changes nothing")
	_check(hud.capture_label.text == "OPFOR BASE — CANNOT BE CAPTURED" and not hud.capture_bar.visible, "HUD: \"%s\", no progress bar" % hud.capture_label.text)
	_check(base_opfor.get_node_or_null("BaseRing") != null and base_opfor.flag_mesh.scale.x > 1.0, "base flag has a ring and a bigger banner")
	var base_usmc := _find("BaseUSMC") as CapturePoint
	_teleport(player, base_usmc.global_position + Vector3(0, 1.0, 6))
	await _ticks(10)
	_check(hud.capture_label.text == "USMC BASE — HOME BASE", "HUD on your own base: \"%s\"" % hud.capture_label.text)
	var alpha_point := alpha
	_teleport(player, alpha_point.global_position + Vector3(0, 1.0, 0))
	await _ticks(10)
	_check(hud.capture_bar.visible, "progress bar is back on a normal flag")
	_teleport(player, Vector3(0, 1.0, 150))


func _test_vehicle_wreck_and_respawn() -> void:
	print("\n-- Destroyed vehicle: wreck, then respawn")
	var spawn := _find("OPFORTankSpawn") as VehicleSpawn
	spawn.wreck_time = 0.5
	spawn.respawn_delay = 0.5
	var old := spawn.vehicle
	var hc := old.find_child("HealthComponent", true, false) as HealthComponent
	hc.take_damage(99999.0, null)
	await _seconds(0.3)
	_check(is_instance_valid(old) and spawn.vehicle == old, "wreck stays for wreck_time")
	await _seconds(0.4)
	_check(not spawn.has_vehicle(), "wreck removed")
	await _seconds(0.6)
	var fresh := spawn.vehicle
	_check(spawn.has_vehicle() and fresh != old, "new vehicle spawned after respawn_delay")
	if spawn.has_vehicle():
		var fresh_hc := fresh.find_child("HealthComponent", true, false) as HealthComponent
		_check(fresh_hc.current_health >= fresh_hc.max_health, "new vehicle at full health")
		_check(fresh.global_position.distance_to(spawn.global_position) < 2.0, "new vehicle at its spawn")


func _test_abandoned_vehicle() -> void:
	print("\n-- Abandoned vehicle returns; an occupied one far away does not")
	var spawn := _find("HumveeSpawn") as VehicleSpawn
	spawn.abandon_time = 0.5
	spawn.abandon_distance = 10.0
	spawn.respawn_delay = 0.3
	var removed: Array = []
	spawn.vehicle_removed.connect(func(r: String) -> void: removed.append(r))
	var old := spawn.vehicle
	_teleport(old, spawn.global_position + Vector3(60, 0.5, 0))
	await _seconds(0.8)
	_check(removed == ["abandoned"] and not is_instance_valid(old), "empty Humvee 60 m away removed as abandoned")
	await _seconds(0.5)
	_check(spawn.has_vehicle(), "Humvee respawned at its spawn")

	var humvee := spawn.vehicle
	player._enter_vehicle(humvee)
	_teleport(humvee, spawn.global_position + Vector3(60, 0.5, 0))
	await _seconds(1.0)
	_check(spawn.vehicle == humvee and is_instance_valid(humvee), "occupied Humvee far away is kept")
	player._exit_vehicle()
