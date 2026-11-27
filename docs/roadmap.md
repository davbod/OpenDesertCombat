# OpenDesertCombat — Development Roadmap

> Sprints are prioritised against the pillars in [Design Goals](design_goals.md).

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

## Sprint 3: Air Superiority, Maps & Atmosphere
- [x] `JetController` fixed-wing flight model — lift ∝ v² × AoA with stall, parasitic + induced drag, fly-by-wire rate command, AoA limiter, stick-free auto-trim
- [x] Jet weapons: hitscan 20 mm cannon with tracers, free-fall bombs (4, rearming)
- [x] Crash damage from impact speed; destroyed vehicles kill their occupants
- [x] `HealthComponent` added to Helicopter (300) and Humvee (200) — previously documented but missing
- [x] Map enlarged to 8 × 8 km with a 900 m runway; jet spawns at the threshold
- [x] Headless flight-model test (`tests/jet_flight_test.gd`)
- [ ] Mobile AA vehicle + fixed AA emplacements, guided SAM projectile
- [ ] Wire `VehicleSpawnManager` into the map (wrecks + respawn for all vehicles)
- [ ] Heightmap desert terrain with dunes and elevation
- [ ] Particle effects (rocket smoke trails, impact dust, helicopter rotor downwash)
- [ ] Audio pass (rotor loop, engine spool, weapon fire, explosions)
- [ ] Minimap displaying capture points, player heading, and vehicles

## Sprint 4: Multiplayer & Linux Release
- [ ] Headless dedicated server mode (`--headless`)
- [ ] Server-authoritative vehicle ownership, hit registration, and `MultiplayerSynchronizer` replication
- [ ] Team/kit selection screen and server direct-connect UI
- [ ] Standalone Linux binary export
