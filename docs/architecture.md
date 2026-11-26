# OpenDesertCombat — Architecture Overview

## 1. Engine & Design Philosophy

OpenDesertCombat targets a **gameplay-first, standalone Linux game** built on **Godot 4.4.1** with the built-in **Jolt Physics 3D** engine (`3d/physics_engine="JoltPhysics3D"` at 60 Hz) and **Vulkan Forward+** rendering.

### Why Godot 4.4 + Jolt
- **Built-in Jolt Physics**: Godot 4.4 integrates Jolt natively as an engine module without third-party GDExtensions, providing stable rigid-body and vehicle-wheel simulation for helicopters, wheeled vehicles, and high-speed projectiles.
- **Rapid Iteration**: Modular `.tscn` prefabs, GDScript iteration, built-in scene editor, and headless CLI validation (`--headless`) keep development focused on vehicle feel, combat, and multiplayer rather than engine boilerplate.
- **Legacy Asset Tools Decoupled**: The C++20 `tools/odc-converter` CLI skeleton and [Refractor format notes](formats/refractor_formats.md) remain in the repository as an optional companion utility for studying/extracting legacy BF1942 `.rfa` archives, kept off the critical path of the standalone game.

---

## 2. Physics Layers & Collision Masks

Defined in `godot/project.godot`:

| Layer | Name | Used By |
|---|---|---|
| `1` (bitmask `1`) | `World` | Ground, Helipad, Bunkers (`StaticBody3D`) |
| `2` (bitmask `2`) | `Players` | `PlayerController` (`CharacterBody3D`) |
| `3` (bitmask `4`) | `Vehicles` | `HelicopterController` (`RigidBody3D`), `HumveeController` (`VehicleBody3D`) |
| `4` (bitmask `8`) | `Projectiles` | Reserved for projectile bodies/areas |

### Mask Rules
- **`Player` (`collision_layer = 2`)**: `collision_mask = 5` (collides with `World` + `Vehicles`). `InteractionRay` uses `collision_mask = 5` so walls block interaction and vehicles are directly targetable.
- **`Helicopter` & `Humvee` (`collision_layer = 4`)**: `collision_mask = 5` (collide with `World` + `Vehicles`).
- **`CapturePoint` (`collision_layer = 0`)**: `collision_mask = 6` (detects `Players` + `Vehicles`).
- **`RocketProjectile` & Hitscan Rifle**: Raycast sweep against `collision_mask = 5` (`World` + `Vehicles`), excluding the shooter's own `RID`. Explosion splash queries `SphereShape3D` against `collision_mask = 4` (`Vehicles`).

---

## 3. Scene & Node Hierarchy

`res://scenes/maps/test_desert.tscn` is the main sandbox scene (`run/main_scene` in `project.godot`):

```
TestDesertMap (Node3D, test_desert.gd)
├── WorldEnvironment      (ProceduralSkyMaterial, ACES/filmic tonemap, SSAO, distance fog)
├── Sun                   (DirectionalLight3D with shadows)
├── Ground                (StaticBody3D, 2000x2000m, desert_terrain.gdshader)
├── Helipad               (StaticBody3D, 18x18m landing pad)
├── Bunker1 / Bunker2     (StaticBody3D cover blocks)
├── Player                (instanced player.tscn)
├── Helicopter            (instanced helicopter.tscn)
├── Humvee                (instanced humvee.tscn)
├── ConquestManager       (Node, conquest_manager.gd)
├── CapturePointAlpha     (instanced capture_point.tscn, point_name="Alpha")
├── CapturePointBravo     (instanced capture_point.tscn, point_name="Bravo")
└── GameHUD               (instanced game_hud.tscn)
```

---

## 4. Vehicle Ownership & Camera Pattern

Vehicles implement a lightweight duck-typed contract expected by `PlayerController`:
- `enter_vehicle(player: Node3D) -> int` (returns assigned seat index)
- `exit_vehicle(player: Node3D) -> void`
- Optional properties: `vehicle_name: String`, `seat_positions: Array[Vector3]`, `chase_camera_offset: Vector3`, `is_occupied: bool`

When entering a vehicle, `PlayerController` disables its own `CollisionShape3D`, hides its mesh, and reparents `CameraPivot` onto the vehicle node (defaulting to chase view, toggleable to cockpit view with `V`). Exiting restores `CameraPivot` to the player, places the player safely beside the vehicle, and re-enables player collision.
