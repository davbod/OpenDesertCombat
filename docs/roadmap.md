# OpenDesertCombat — Development Roadmap

## Sprint 1: Core Flight & Sandbox — Complete
- [x] Godot 4.4.1 project with `JoltPhysics3D` and Vulkan Forward+
- [x] `HelicopterController` 6-DOF flight model + prototype gunship mesh & spinning rotors
- [x] `PlayerController` FPS movement, vehicle enter/exit (`E`), camera toggle (`V`)
- [x] `ConquestManager`, `CapturePoint` (Alpha/Bravo), and `GameHUD`
- [x] Procedural desert terrain shader (`desert_terrain.gdshader`), helipad, and bunkers in `test_desert.tscn`
- [x] Headless `--import` and physics smoke test verified with zero errors

## Sprint 2: Ground Vehicles & Combat — ✅ Complete
- [x] `HumveeController` 4-wheel `VehicleBody3D`
- [x] `RocketProjectile` ballistic sweep + splash impulse (Hydra 70 pods + RPG-7) and hitscan rifle
- [x] `HealthComponent` reusable node — signals `damaged`, `healed`, `died`, `health_changed`; wired to Player, Helicopter, Humvee, Tank
- [x] `VehicleSpawnManager` — registers vehicle + spawn point, auto-respawns after 30 s on death
- [x] `TankController` — `RigidBody3D` tracks tank: drive/steer forces, anti-slip, turret yaw (mouse X), barrel pitch clamped −5°/+15°, AP cannon hitscan + `CannonShell` tracer
- [x] `CannonShell` tracer scene and script
- [x] `KitSelectMenu` (Assault / Engineer / Medic / Sniper) — kit picker with confirm countdown, applies kit health to `HealthComponent`
- [x] Player death → `KitSelectMenu` shown → kit applied → respawn at `SpawnUSMC`
- [x] `SpawnUSMC` and `SpawnOPFOR` markers added to `test_desert.tscn`
- [x] All 7 `class_name` declarations registered; headless import + scene load — exit 0, zero errors

## Sprint 3: Maps & Atmosphere
- [ ] Heightmap desert terrain with dunes and elevation
- [ ] Particle effects (rocket smoke trails, impact dust, helicopter rotor downwash)
- [ ] Audio pass (rotor loop, engine spool, weapon fire, explosions)
- [ ] Minimap displaying capture points, player heading, and vehicles

## Sprint 4: Multiplayer & Linux Release
- [ ] Headless dedicated server mode (`--headless`)
- [ ] Server-authoritative vehicle ownership, hit registration, and `MultiplayerSynchronizer` replication
- [ ] Team/kit selection screen and server direct-connect UI
- [ ] Standalone Linux binary export
