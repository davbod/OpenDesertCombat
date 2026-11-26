# OpenDesertCombat — Architecture Overview

## 1. Engine & Design Philosophy

OpenDesertCombat targets a **gameplay-first, standalone Linux game** built on **Godot 4.4.1** with the built-in **Jolt Physics 3D** engine (`3d/physics_engine="JoltPhysics3D"` at 60 Hz) and **Vulkan Forward+** rendering.

### Why Godot 4.4 + Jolt

- **Built-in Jolt Physics**: Godot 4.4 integrates Jolt natively as an engine module — no third-party GDExtensions needed. This provides stable rigid-body simulation for helicopters (`RigidBody3D`), tracked tanks (`RigidBody3D`), wheeled vehicles (`VehicleBody3D`), and high-speed projectiles.
- **Rapid Iteration**: Modular `.tscn` prefabs, typed GDScript, built-in scene editor, and headless CLI validation (`--headless --path godot/ --import --quit`) keep development focused on vehicle feel, combat, and multiplayer rather than engine boilerplate.
- **Legacy Asset Tools Decoupled**: The C++20 `tools/odc-converter` CLI skeleton and [Refractor format notes](formats/refractor_formats.md) remain in the repository as an optional companion utility for studying/extracting BF1942 `.rfa` archives. They are off the critical path for the standalone game.

---

## 2. Physics Layers & Collision Masks

Defined in `godot/project.godot`:

| Layer | Name | Bitmask | Used By |
|---|---|---|---|
| `1` | `World` | `1` | Ground, Helipad, Bunkers (`StaticBody3D`) |
| `2` | `Players` | `2` | `PlayerController` (`CharacterBody3D`) |
| `3` | `Vehicles` | `4` | `HelicopterController`, `TankController` (`RigidBody3D`), `HumveeController` (`VehicleBody3D`) |
| `4` | `Projectiles` | `8` | Reserved for future projectile collision bodies |

### Mask Rules

| Actor | `collision_layer` | `collision_mask` | Explanation |
|---|---|---|---|
| Player | `2` | `5` (World + Vehicles) | Player lands on ground, is blocked by vehicles |
| `InteractionRay` | — | `5` | Vehicle interaction; walls block it, vehicles pass through |
| Helicopter / Humvee / Tank | `4` | `5` | Vehicles land on ground, collide with other vehicles |
| CapturePoint (`Area3D`) | `0` | `6` (Players + Vehicles) | Detects infantry and occupied vehicles entering the zone |
| Rocket hitscan ray | — | `5` | Hits world geometry and vehicles |
| Rocket splash query (`SphereShape3D`) | — | `6` (Players + Vehicles) | Blast radius damages infantry and vehicles |
| Cannon hitscan ray | — | `5` | AP round hits world geometry and vehicles |

---

## 3. Scene & Node Hierarchy

`res://scenes/maps/test_desert.tscn` is the main scene (`run/main_scene` in `project.godot`):

```
TestDesertMap (Node3D — test_desert.gd)
├── WorldEnvironment          ProceduralSkyMaterial, ACES tonemap, SSAO, distance fog
├── Sun                       DirectionalLight3D with shadow cascades
├── Ground                    StaticBody3D — 2000×2000 m, desert_terrain.gdshader
├── Helipad                   StaticBody3D — 18×18 m landing pad
├── Bunker1 / Bunker2         StaticBody3D cover blocks (12×8×12 m)
│
├── Player                    ← player.tscn (CharacterBody3D + HealthComponent)
├── Helicopter                ← helicopter.tscn (RigidBody3D + HealthComponent)
├── Humvee                    ← humvee.tscn (VehicleBody3D + HealthComponent)
├── Tank                      ← tank.tscn (RigidBody3D + HealthComponent)
│
├── SpawnUSMC                 Node3D — USMC team respawn point (0, 1.5, 20)
├── SpawnOPFOR                Node3D — OPFOR team respawn point (0, 1.5, -80)
│
├── ConquestManager           Node — conquest_manager.gd
├── CapturePointAlpha         ← capture_point.tscn (point_name="Alpha", at -50, 0, -50)
├── CapturePointBravo         ← capture_point.tscn (point_name="Bravo", at 50, 0, 50)
│
├── GameHUD                   ← game_hud.tscn (CanvasLayer)
└── KitSelectMenu             ← kit_select.tscn (Control, hidden until player death)
```

---

## 4. Vehicle Ownership & Camera Pattern

All vehicles implement a lightweight **duck-typed contract** checked by `PlayerController` via `has_method`:

| Property / Method | Type | Required | Notes |
|---|---|---|---|
| `enter_vehicle(player)` | `func → int` | ✅ | Returns seat index (0 = driver) |
| `exit_vehicle(player)` | `func → void` | ✅ | |
| `vehicle_name` | `String` | optional | Shown in HUD interact prompt |
| `seat_positions` | `Array[Vector3]` | optional | Local position of each seat (cockpit / turret) |
| `chase_camera_offset` | `Vector3` | optional | 3rd-person camera offset |
| `is_occupied` | `bool` | optional | Vehicle logic gates input on this |

**Camera reparenting:** When entering a vehicle, `PlayerController`:
1. Disables `PlayerCollision` and hides player mesh
2. Removes `CameraPivot` from itself, adds it to the vehicle node
3. Positions `CameraPivot` at `chase_camera_offset` (3rd-person) or `seat_positions[seat]` (1st-person)
4. `V` toggles between the two

**On exit:** `CameraPivot` is re-parented back to the player, player is placed `3.5 m` to the side of the vehicle at `+1.5 m` height, velocity zeroed.

---

## 5. Health & Damage System

`HealthComponent` (`scripts/game/health_component.gd`) is a plain `Node` added as a child of any actor that needs health. It is fully decoupled — no actor inherits from it. See [gameplay_systems.md](gameplay_systems.md#5-health--damage-system-healthcomponent) for the full signal table and damage values.

**Actors with HealthComponent:**

| Actor | `max_health` | Death consequence |
|---|---|---|
| Player | 100 (kit-adjustable) | `KitSelectMenu` shown → respawn |
| Helicopter | 300 | (wreck + respawn via `VehicleSpawnManager` — wired in future sprint) |
| Humvee | 200 | (same) |
| Tank | 500 | (same) |

---

## 6. Respawn & Kit Flow

```
Player killed
    └─→ PlayerController._on_player_died()
            ├─→ hide player mesh, disable collision
            └─→ KitSelectMenu.show_menu()
                    └─→ [player selects kit + clicks DEPLOY]
                            └─→ 5 s countdown
                                    └─→ kit_selected(kit_id) signal
                                            └─→ PlayerController._on_kit_selected()
                                                    ├─→ HealthComponent.max_health = kit.health
                                                    ├─→ HealthComponent.reset()
                                                    └─→ global_position = SpawnUSMC.global_position
```

---

## 7. Code Conventions

- **Typed GDScript**: All variables, parameters, and return types are explicitly typed. `@warning_ignore` is used sparingly; Godot's warnings-as-errors policy is enforced.
- **`class_name` on every script**: Required for Godot's global class registry so `.tscn` files can reference scripts by name without path strings.
- **`@onready` for node refs**: Node references are declared as `@onready var foo: Type = $Path` and never cached in `_ready` manually.
- **No static autoloads for game state**: Game state lives in scene nodes (`ConquestManager`, `VehicleSpawnManager`) rather than autoloaded singletons, to keep scenes self-contained and testable headlessly.
- **`find_child` for loose coupling**: Systems that need a sibling (e.g. `PlayerController` finding `GameHUD`) use `get_tree().root.find_child("Name", true, false)` rather than hard `$Path` references, so scene layout can change without breaking scripts.
