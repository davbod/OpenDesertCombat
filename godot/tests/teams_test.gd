## Headless test for Sprint 4.1 — teams, friendly fire, tickets, team respawn and flag capture.
## Run with godot/tests/run_all.sh, or alone from the repository root (after an --import pass):
##   <godot> --headless --path godot/ --script res://tests/teams_test.gd
## Exits non-zero if any check fails. Helpers live in test_base.gd.

extends "res://tests/test_base.gd"

var events: Array = []  # [point_name, team] from ConquestManager.point_captured

var player: PlayerController
var conquest: ConquestManager
var match_mgr: MatchManager
var alpha: CapturePoint
var bravo: CapturePoint
var kit_menu: KitSelectMenu
var hud: GameHUD
var tank: Node3D


func _run() -> void:
	if not _load_map(TEST_DESERT):
		_finish()
		return
	player = _find("Player") as PlayerController
	conquest = _find("ConquestManager") as ConquestManager
	match_mgr = _find("MatchManager") as MatchManager
	alpha = _find("CapturePointAlpha") as CapturePoint
	bravo = _find("CapturePointBravo") as CapturePoint
	kit_menu = _find("KitSelectMenu") as KitSelectMenu
	hud = _find("GameHUD") as GameHUD
	tank = _find("Tank") as Node3D
	if not (player and conquest and match_mgr and alpha and bravo and kit_menu and hud and tank):
		_fail("test_desert.tscn is missing a required node")
		_finish()
		return
	# Speed things up: 2 s per capture swing, near-instant deploy
	alpha.capture_time = 2.0
	bravo.capture_time = 2.0
	match_mgr.respawn_time = 0.1
	conquest.point_captured.connect(func(n: String, t: int) -> void: events.append([n, t]))
	await _ticks(30)

	_test_team_basics()
	_test_friendly_fire()
	_test_vehicle_teams()
	await _test_death_and_team_respawn()
	await _test_capture_and_hold()
	await _test_vehicle_capture_and_contest()
	_test_game_over()
	_finish()


func _test_team_basics() -> void:
	print("\n-- Team basics")
	_check(conquest.capture_points.size() == 4, "ConquestManager finds 4 flags (2 bases + Alpha + Bravo)")
	_check(Teams.enemy_of(Teams.USMC) == Teams.OPFOR and Teams.enemy_of(Teams.OPFOR) == Teams.USMC, "enemy_of is symmetric")
	_check(Teams.of(null) == Teams.NONE, "Teams.of(null) is NONE")
	_check(player.team == Teams.USMC, "player starts on USMC")
	_check(alpha.owning_team == Teams.NONE and bravo.owning_team == Teams.NONE, "flags start neutral")


func _test_friendly_fire() -> void:
	print("\n-- Friendly fire")
	var friend := _make_actor(Teams.USMC)
	var enemy := _make_actor(Teams.OPFOR)
	var hc := player.health_component
	var hp := hc.current_health
	hc.take_damage(25.0, friend)
	_check(is_equal_approx(hc.current_health, hp), "teammate damage is ignored")
	hc.take_damage(25.0, enemy)
	_check(is_equal_approx(hc.current_health, hp - 25.0), "enemy damage applies")
	hc.take_damage(10.0, player)
	_check(is_equal_approx(hc.current_health, hp - 35.0), "self-damage applies")
	hc.take_damage(5.0, null)
	_check(is_equal_approx(hc.current_health, hp - 40.0), "damage with no attacker (crash/fall) applies")
	Teams.friendly_fire = true
	hc.take_damage(5.0, friend)
	Teams.friendly_fire = false
	_check(is_equal_approx(hc.current_health, hp - 45.0), "teammate damage applies when friendly fire is on")
	hc.reset()
	friend.queue_free()
	enemy.queue_free()


func _test_vehicle_teams() -> void:
	print("\n-- Vehicle teams")
	for vname: String in ["Tank", "Humvee", "Helicopter", "Jet"]:
		var v := _find(vname) as Node3D
		if not v:
			_fail("%s not found" % vname)
			continue
		v.call("enter_vehicle", player)
		_check(Teams.of(v) == Teams.USMC, "%s takes its crew's team" % vname)
		v.call("exit_vehicle", player)
		_check(Teams.of(v) == Teams.NONE, "%s is neutral when empty" % vname)

	var friend := _make_actor(Teams.USMC)
	var enemy := _make_actor(Teams.OPFOR)
	var thc := tank.find_child("HealthComponent", true, false) as HealthComponent
	player._enter_vehicle(tank)
	var hp := thc.current_health
	thc.take_damage(100.0, friend)
	_check(is_equal_approx(thc.current_health, hp), "teammate can't damage a crewed friendly vehicle")
	thc.take_damage(100.0, enemy)
	_check(is_equal_approx(thc.current_health, hp - 100.0), "enemy damages a crewed vehicle")
	player._exit_vehicle()
	thc.reset()
	friend.queue_free()
	enemy.queue_free()


func _test_death_and_team_respawn() -> void:
	print("\n-- Death costs a ticket; respawn on the chosen team")
	var enemy := _make_actor(Teams.OPFOR)
	var usmc_before: int = conquest.tickets[Teams.USMC]
	player.health_component.take_damage(1000.0, enemy)
	_check(not player.is_alive(), "player is dead")
	_check(conquest.tickets[Teams.USMC] == usmc_before - 1, "USMC lost one ticket for the death (%d → %d)" % [usmc_before, conquest.tickets[Teams.USMC]])
	_check(kit_menu.visible, "deploy menu is shown on death")

	kit_menu.select_team(Teams.OPFOR)
	kit_menu.select_kit(3)  # Sniper, 75 hp
	var spawn := _find("SpawnOPFOR") as SpawnPoint
	_check(kit_menu.selected_spawn == spawn, "deploy menu defaults to the OPFOR main base")
	kit_menu._on_confirm_pressed()
	await _ticks(30)
	var flat := _flat_dist(player, spawn)
	_check(player.is_alive(), "player respawned")
	_check(player.team == Teams.OPFOR, "player switched to OPFOR")
	_check(flat <= spawn.spread_radius + 0.5, "respawned at SpawnOPFOR (%.1f m away)" % flat)
	_check(is_equal_approx(player.health_component.max_health, 75.0) and is_equal_approx(player.health_component.current_health, 75.0), "Sniper kit health applied")
	enemy.queue_free()


func _test_capture_and_hold() -> void:
	print("\n-- OPFOR soldier captures Alpha; it stays owned when empty; USMC bleeds")
	_teleport(player, alpha.global_position + Vector3(0, 1.0, 0))
	await _ticks(60)
	_check(hud.capture_panel.visible and hud.capture_label.text.begins_with("ALPHA"), "HUD shows capture progress (%s)" % hud.capture_label.text)
	await _ticks(90)
	_check(alpha.owning_team == Teams.OPFOR, "Alpha captured by OPFOR (progress %.2f)" % alpha.capture_progress)
	_check(events.has(["Alpha", Teams.OPFOR]), "point_captured(Alpha, OPFOR) emitted")

	_teleport(player, Vector3(0, 1.0, 150))
	var usmc_before: int = conquest.tickets[Teams.USMC]
	var opfor_before: int = conquest.tickets[Teams.OPFOR]
	await _ticks(300)
	_check(not hud.capture_panel.visible, "HUD capture panel hides after leaving the zone")
	_check(alpha.owning_team == Teams.OPFOR and is_equal_approx(alpha.capture_progress, -1.0), "Alpha stays OPFOR with nobody near (progress %.2f)" % alpha.capture_progress)
	var bled: int = usmc_before - conquest.tickets[Teams.USMC]
	_check(bled >= 2, "USMC bleeds while OPFOR holds the majority (-%d in 5 s at 0.5 ticket/s)" % bled)
	_check(conquest.tickets[Teams.OPFOR] == opfor_before, "OPFOR does not bleed")


func _test_vehicle_capture_and_contest() -> void:
	print("\n-- USMC tank neutralises and recaptures Alpha; equal numbers hold the flag")
	# Direct team switch for the test (the real flow is death → deploy menu)
	player.set_team(Teams.USMC)
	player.participant.team = Teams.USMC
	player._enter_vehicle(tank)
	_teleport(tank, alpha.global_position + Vector3(0, 1.5, 0))
	await _ticks(300)
	var alpha_events: Array = events.filter(func(e: Array) -> bool: return e[0] == "Alpha")
	_check(alpha_events.has(["Alpha", Teams.NONE]), "Alpha neutralised on the way")
	_check(alpha.owning_team == Teams.USMC, "occupied tank captured Alpha for USMC (progress %.2f)" % alpha.capture_progress)
	_check(hud.capture_panel.visible, "HUD capture panel shows while seated in a vehicle")

	var intruder := _make_contester(Teams.OPFOR, alpha.global_position + Vector3(6, 1.0, 0))
	await _ticks(120)
	_check(is_equal_approx(alpha.capture_progress, 1.0), "1 v 1 is contested: progress holds (%.2f)" % alpha.capture_progress)
	_check(hud.capture_label.text.ends_with("CONTESTED"), "HUD says CONTESTED (%s)" % hud.capture_label.text)
	intruder.queue_free()
	player._exit_vehicle()


func _test_game_over() -> void:
	print("\n-- Running out of tickets ends the round")
	var winner: Array = []
	conquest.game_over.connect(func(t: int) -> void: winner.append(t))
	conquest.tickets[Teams.OPFOR] = 1
	conquest.on_player_killed(Teams.OPFOR)
	_check(winner == [Teams.USMC], "USMC wins when OPFOR hits 0 tickets")
	_check(not conquest.game_active, "round is no longer active")
	_check(hud.center_message.visible and hud.center_message.text == "USMC WINS", "HUD shows the winner")
