# OpenDesertCombat — Gameplay Systems Reference

## 1. Helicopter Flight Model (`HelicopterController`)

Script: [helicopter_controller.gd](file:///home/dmb/OpenDesertCombat/godot/scripts/vehicles/helicopter_controller.gd)
Scene: [helicopter.tscn](file:///home/dmb/OpenDesertCombat/godot/scenes/vehicles/helicopter.tscn)

Simulated on a `RigidBody3D` (`mass = 5000.0 kg`) in `_physics_process(delta)`:

- **Collective & Engine Spool**:
  - `max_thrust = 85000.0 N` (~1.73 thrust-to-weight ratio), `idle_thrust_fraction = 0.42`, `engine_spool_rate = 1.2 /s`.
  - Holding `W` (`heli_collective_up`) spools power to `1.0`; `S` (`heli_collective_down`) drops collective to `-0.35` (`0.5 * idle_thrust_fraction`).
  - Thrust applies along local `+Y` (`transform.basis.y`).
- **Ground Effect**:
  - Raycasts down up to `500 m` against `World` (`Layer 1`) to compute `altitude_agl`.
  - Within `ground_effect_height` (`15.0 m`), thrust scales smoothly up to `ground_effect_multiplier` (`1.25x`).
- **Cyclic (Pitch & Roll)**:
  - Driven by `InputEventMouseMotion` (`cyclic_sensitivity = 0.015`, clamped to `[-1.0, 1.0]`), decaying toward `0` when mouse movement stops.
  - Applies local torques around `+X` (`pitch_torque = 65000.0 Nm`) and `+Z` (`roll_torque = 55000.0 Nm`).
- **Tail Rotor (Yaw)**:
  - `A` (`heli_yaw_left`) applies `+Y` torque; `D` (`heli_yaw_right`) applies `-Y` torque (`yaw_torque = 35000.0 Nm`).
- **Stability Augmentation (SAS) & Drag**:
  - Quadratic aerodynamic drag (`drag_coefficient = 0.35`).
  - Angular damping torque `-angular_velocity * angular_damping_factor * mass` (`angular_damping_factor = 1.4`).
  - Gentle auto-level torque (`auto_level_strength = 4500.0`) when cyclic input is near zero (`< 0.05`) and tilt exceeds `auto_level_deadzone` (`0.08 rad`).
- **Armament**:
  - Left-click (`fire`) launches `RocketProjectile` instances alternately from left/right stub wing pods (`(-2.1, -0.25, -1.2)` and `(2.1, -0.25, -1.2)`) every `0.22 s`, inheriting helicopter linear velocity.

---

## 2. Wheeled Ground Vehicle (`HumveeController`)

Script: [humvee_controller.gd](file:///home/dmb/OpenDesertCombat/godot/scripts/vehicles/humvee_controller.gd)
Scene: [humvee.tscn](file:///home/dmb/OpenDesertCombat/godot/scenes/vehicles/humvee.tscn)

Built on `VehicleBody3D` (`mass = 2400.0 kg`, lowered center of mass `(0, -0.35, 0)`) with four `VehicleWheel3D` nodes (`wheel_radius = 0.46`, `suspension_stiffness = 45.0`):
- `W` / `S`: forward (`max_engine_force = 3200.0`) and reverse (`-0.65x`).
- `A` / `D`: front-wheel steering up to `max_steer_angle = 0.45 rad`.
- `Space`: handbrake (`max_brake_force = 80.0`); unoccupied vehicles apply `15.0` resting brake force.

---

## 3. Infantry & Weapons (`PlayerController` & `RocketProjectile`)

Scripts:
- [player_controller.gd](file:///home/dmb/OpenDesertCombat/godot/scripts/player/player_controller.gd)
- [rocket_projectile.gd](file:///home/dmb/OpenDesertCombat/godot/scripts/weapons/rocket_projectile.gd)

### Player Movement & Interaction
- `CharacterBody3D` with `walk_speed = 5.0`, `sprint_speed = 8.5`, `crouch_speed = 2.5`, `jump_velocity = 4.5`.
- `InteractionRay` (`6 m` range) displays `[E] Enter <vehicle_name>` on the HUD when aimed at an enterable vehicle.
- Pressing `V` inside a vehicle toggles between 3rd-person chase camera and 1st-person cockpit/driver seat.

### Weapons
- **Slot `1` — Assault Rifle**: Raycast hitscan up to `300 m` (`0.11 s` cooldown) spawning a temporary impact spark at hit point.
- **Slot `2` — RPG-7**: Launches `RocketProjectile` (`1.1 s` cooldown).
- **`RocketProjectile`**: Moves at `speed = 95.0 m/s` with `gravity_drop = 2.5 m/s²` and `6.0 s` lifetime, swept each physics tick via `PhysicsRayQueryParameters3D`. On hit, spawns an expanding emissive explosion flash and applies radial `apply_central_impulse` (`blast_impulse = 12000.0`, `blast_radius = 8.0 m`) to nearby `RigidBody3D` vehicles.

---

## 4. Conquest Mode & HUD

Scripts:
- [conquest_manager.gd](file:///home/dmb/OpenDesertCombat/godot/scripts/game/conquest_manager.gd)
- [capture_point.gd](file:///home/dmb/OpenDesertCombat/godot/scripts/game/capture_point.gd)
- [game_hud.gd](file:///home/dmb/OpenDesertCombat/godot/scripts/ui/game_hud.gd)

- **Capture Points**: `Area3D` zones track both `PlayerController` on foot and occupied vehicles. `capture_progress` shifts in `[-1.0, 1.0]` (`capture_time = 10.0 s` for 1 unit), updating `owning_team` (`NONE = 0`, `USMC = 1`, `OPFOR = 2`), emitting `captured`, and recoloring the flag banner (white / blue / red).
- **Ticket Bleed**: `ConquestManager` starts both teams at `300` tickets. Every `1.0 s`, if one team holds more capture points, the losing team bleeds tickets proportional to `(majority_diff / total_points) * bleed_rate`. Reaching `0` tickets emits `game_over(winning_team)`.
- **Game HUD**: Subscribes to `ConquestManager` signals for live ticket labels and `3 s` capture banners, shows the vehicle telemetry panel (`VehicleIndicator`, `ALT` in meters, `SPD` in km/h), and displays contextual `[E]` prompts.


---

## 5. Health / Damage System (`HealthComponent`)

Script: [health_component.gd](file:///home/dmb/OpenDesertCombat/godot/scripts/game/health_component.gd)

A reusable `Node` added as a child of any actor (infantry or vehicle) that needs health.

| Property | Default | Notes |
|---|---|---|
| `max_health` | `100.0` | Exported; kit selection may override for infantry |
| `is_invincible` | `false` | Disables all `take_damage` calls when `true` |

**Signals:**

| Signal | Args | Emitted when |
|---|---|---|
| `damaged(amount, attacker)` | float, Node3D? | Any successful hit |
| `healed(amount)` | float | `heal()` called |
| `died(attacker)` | Node3D? | `current_health` reaches 0 |
| `health_changed(current, maximum)` | float, float | After any change |

**Usage:**
```gdscript
var hc: HealthComponent = target.find_child("HealthComponent", true, false) as HealthComponent
if hc:
    hc.take_damage(25.0, self)
```

**Damage sources wired:**
- **Rifle**: 25 hp, hitscan (player_controller → `_fire_rifle`)
- **Rocket splash on vehicles**: 120 × falloff (rocket_projectile → `_explode`)
- **Rocket splash on infantry**: 80 × falloff (rocket_projectile → `_explode`)
- **Cannon AP**: 250 hp, hitscan at hit body (tank_controller → `_fire_cannon`)

---

## 6. Tank Controller (`TankController`)

Script: [tank_controller.gd](file:///home/dmb/OpenDesertCombat/godot/scripts/vehicles/tank_controller.gd)
Scene: [tank.tscn](file:///home/dmb/OpenDesertCombat/godot/scenes/vehicles/tank.tscn)

Built on `RigidBody3D` (`mass = 62000.0 kg`, JoltPhysics3D):

| Parameter | Value | Notes |
|---|---|---|
| `drive_force` | 220 000 N | Applied along `-Z` (body forward) |
| `turn_torque` | 180 000 Nm | World `+Y` torque for steering |
| `brake_force` | 95 000 N | Counters longitudinal velocity on release |
| `max_speed` | 18 m/s (~65 km/h) | Enforced before applying drive force |
| `anti_slip_factor` | 8× mass | Lateral velocity projected onto `+X` cancelled each tick |
| `angular_damping_factor` | 4.5 | Prevents tumbling from impulses |
| `upright_torque` | 15× mass | Keeps Y-axis aligned with world UP |

**Turret/Barrel:**
- `TurretPivot.rotation.y` driven by `mouse.relative.x × turret_mouse_sensitivity` (0.0018)
- `BarrelPivot.rotation.x` clamped to `[−5°, +15°]` via mouse Y
- Neither is physically simulated — they are Node3D children that rotate freely

**Cannon:** Hitscan via `PhysicsRayQueryParameters3D` (range 1800 m, mask: World+Vehicles), 250 hp AP damage to `HealthComponent`, 3.5 s cooldown, `CannonShell` tracer scene spawned at `Muzzle` position.

**Vehicle Contract:** `enter_vehicle(player) → 0`, `exit_vehicle(player)`, `vehicle_name = "M1A1 Abrams"`, `seat_positions = [Vector3(0, 1.35, −0.4)]`, `chase_camera_offset = Vector3(0, 3.5, 9.0)`.

---

## 7. Kit Selection & Respawn Flow (`KitSelectMenu`)

Script: [kit_select_menu.gd](file:///home/dmb/OpenDesertCombat/godot/scripts/ui/kit_select_menu.gd)
Scene: [kit_select.tscn](file:///home/dmb/OpenDesertCombat/godot/scenes/ui/kit_select.tscn)

**Kits:**

| ID | Name | Weapon | Health | Speed |
|---|---|---|---|---|
| 0 | Assault | M4A1 + Grenades | 100 | 1.0× |
| 1 | Engineer | MP5 + AT Mines | 85 | 1.05× |
| 2 | Medic | M60 + Medkits | 110 | 0.9× |
| 3 | Sniper | M24 + C4 | 75 | 1.1× |

**Flow:**
1. `HealthComponent.died` fires → `PlayerController._on_player_died()` → `KitSelectMenu.show_menu()`
2. Player picks kit and clicks **DEPLOY**
3. 5-second countdown (`spawn_countdown`)
4. `kit_selected(kit_id)` signal → `PlayerController._on_kit_selected()` applies `max_health` from kit data, calls `HealthComponent.reset()`, teleports player to `SpawnUSMC`
5. Mouse recaptured, `_is_dead = false`

**Fallback:** If no `KitSelectMenu` node is found, `PlayerController` auto-respawns after 5 s.

---

## 8. Vehicle Spawn Manager (`VehicleSpawnManager`)

Script: [vehicle_spawn_manager.gd](file:///home/dmb/OpenDesertCombat/godot/scripts/game/vehicle_spawn_manager.gd)

Add as a node in any map scene. Call `register_vehicle(scene, spawn_node)` for each vehicle that should respawn.

**Lifecycle:**
1. Instances vehicle from `PackedScene`, places it at `spawn_node.global_transform`
2. Wires `HealthComponent.died` → `_on_vehicle_died`
3. On death: waits 4 s (wreck visible), then `queue_free`s the instance
4. Waits `respawn_delay` (30 s default), re-instances from scene, re-places and re-wires

> [!NOTE] `VehicleSpawnManager` is in the codebase and ready to use. It is not yet auto-wired in `test_desert.tscn` — add it as a child and call `register_vehicle()` from `test_desert.gd` in a future sprint when wreck/respawn is a priority.

---

## 9. Fixed-Wing Jet (`JetController`)

Script: `godot/scripts/vehicles/jet_controller.gd` · Scene: `godot/scenes/vehicles/jet.tscn` · Test: `godot/tests/jet_flight_test.gd`

Built on `RigidBody3D` (`mass = 12000 kg`, explicit `inertia = (60000, 80000, 20000)`), with three sphere colliders as landing gear and a zero-friction airframe material (tyre grip and braking are applied in code). Damping modes are set to **replace**, so the project-default 0.1/s damping does not add phantom drag.

**Aerodynamics** (per physics tick):

| Force | Model | Defaults |
|---|---|---|
| Thrust | `max_thrust × throttle` along `-Z` | 150 kN (TWR ≈ 1.27); `W`/`S` ramp throttle at 0.6/s |
| Lift | `lift_factor × v² × CL`, perpendicular to airflow | `CL = 5.0 × (AoA + 2°)`; stall at 16°, lift falls to 35 % past it |
| Drag | `2.6 × v²` + `0.12 × lift × CL` (induced) | Top speed ≈ 240 m/s; hard turns bleed energy |
| Sideslip | Lateral velocity decays at 2.5/s × (v / 110) | |

**Fly-by-wire (rate command):** mouse moves a self-centring virtual stick. The stick commands a body rotation *rate* (pitch 1.2, roll 3.0, yaw 0.45 rad/s at 110 m/s, scaled by `(v/110)²`). Torque = `inertia × (target − current) × 6`. On top of that:
- **AoA limiter** (arcade assist, on by default): pitch command is capped so AoA stays under 90 % of stall.
- **Auto-trim** (stick-free): holds the AoA needed for a straight flight path (`1 g × cos γ / cos bank`). When the jet is too slow to reach it, the nose falls through and it recovers speed on its own.
- **Weathervane** yaw stability and **nose-drop** when stalled.

**Measured envelope** (`jet_flight_test.gd`): liftoff ≈ 360 m / 9.5 s; 300 m AGL at 160 m/s after 20 s; hands-off cruise ≈ 140 m/s at 40 % throttle; sustained hard turn ≈ 23–29 °/s while bleeding ~40 m/s in 6 s.

**Weapons:** 20 mm hitscan cannon (`LMB`, 0.07 s, 18 dmg, 1.5 km, alternating barrels, tracer) and free-fall bombs (`RMB`, 4 carried, 1 rearms every 10 s; `RocketProjectile` with `speed = 0`, full gravity, 16 m blast, 450 vehicle / 200 infantry damage).

**Damage:** `HealthComponent` (250). Losing more than 22 m/s in a single tick counts as a crash (12 dmg per extra m/s + 40). On death the jet loses thrust and controls; any occupant is killed and ejected (`PlayerController._on_vehicle_destroyed`).

**HUD:** `get_hud_status()` adds a status line to the vehicle panel: `THR %`, bombs, `LOW SPEED` (< 55 m/s) and `!! STALL !!`.
