# OpenDesertCombat — Architecture Overview

> Last reviewed 2026-11-27 (end of Sprint 4.2, updated for Hardening). Gameplay numbers
> live in [Gameplay Systems](gameplay_systems.md); open problems in the
> [roadmap](roadmap.md#known-issues).

## 1. Engine & Platforms

| | Today | Planned |
|---|---|---|
| Engine | Godot **4.4.1** | Upgrade to 4.7.2 next, before Sprint 4.3 (needed for Terrain3D 1.1) |
| Physics | Built-in `JoltPhysics3D`, 60 ticks/s | — |
| Renderer | Forward+ — Vulkan on Linux/Windows, Metal on macOS | — |
| Language | Typed GDScript | — |
| Development | macOS and Linux | — |
| CI | GitHub Actions on Linux: headless import + all test suites ([§8](#8-testing)) | Release builds on version tags (Community track) |
| Release target | Linux `x86_64` first | macOS and Windows builds from CI (Community track) |

### Why Godot + Jolt

- **Built-in Jolt Physics:** stable rigid-body simulation for helicopters, jets and tanks
  (`RigidBody3D`), wheeled vehicles (`VehicleBody3D`) and fast projectiles, with no
  third-party GDExtension.
- **Rapid iteration:** modular `.tscn` prefabs, typed GDScript, the scene editor, and
  headless runs (`--headless`) for imports and automated tests keep the focus on vehicle
  feel, combat and multiplayer rather than engine plumbing.
- **Large terrain:** Terrain3D (MIT GDExtension) is the chosen route for large maps
  (Sprint 4.4).

---

## 2. Physics Layers & Collision Masks

Layers are named in `godot/project.godot`:

| Layer | Name | Bit | Used by |
|---|---|---|---|
| 1 | `World` | 1 | Ground, helipad, runway, bunkers (`StaticBody3D`) |
| 2 | `Players` | 2 | `PlayerController` (`CharacterBody3D`) |
| 3 | `Vehicles` | 4 | Helicopter, jet, tank (`RigidBody3D`), utility vehicle (`VehicleBody3D`) |
| 4 | `Projectiles` | 8 | Reserved — projectiles are ray-swept, not bodies |

| Actor / query | Layer | Mask | Notes |
|---|---|---|---|
| Player | 2 | 5 (World + Vehicles) | Collision is disabled while dead or seated in a vehicle |
| `InteractionRay` (6 m) | — | 5 | Finds vehicles; world geometry blocks it |
| Vehicles | 4 | 5 | Land on the world, collide with each other |
| `CapturePoint` (`Area3D`) | 0 | 6 (Players + Vehicles) | Tracks everyone inside; counts living soldiers and occupied vehicles |
| Rifle ray | — | 7 (World + Players + Vehicles) | Hits everything; excludes the shooter |
| Rocket / bomb flight ray | — | 7 | Excludes the shooter; detonates an `Explosion` on the first hit |
| Tank cannon ray | — | 7 | Excludes the tank; detonates an HE `Explosion` at the impact |
| Jet cannon ray | — | 7 | Hits everything |
| `Explosion` splash (sphere query) | — | 6 (Players + Vehicles) | Rockets, bombs, tank shells: damages soldiers and vehicles, pushes rigid bodies |
| Altitude rays (helicopter 500 m, jet 3 km) | — | 1 | Ground only |
| `SpawnPoint` ground snap | — | 1 | Places spawns on the ground |

---

## 3. Scene & Node Hierarchy

`res://scenes/maps/test_desert.tscn` is the main scene (`run/main_scene`):

```
TestDesertMap (Node3D — test_desert.gd)
├── WorldEnvironment          ProceduralSkyMaterial, ACES tonemap, SSAO, distance fog
├── Sun                       DirectionalLight3D with shadow cascades
├── Ground                    StaticBody3D — 8000×8000 m flat box, desert_terrain.gdshader
├── Helipad / Runway          StaticBody3D — 18×18 m pad, 900 m runway at x = 300
├── Bunker1 / Bunker2         StaticBody3D cover blocks (12×8×12 m)
│
├── ConquestManager           Node — tickets, bleed, win condition
├── MatchManager              Node — participants, spawn rules, score
│
├── BaseUSMC                  ← capture_point.tscn (USMC, capturable = false, at -12, 0, 24)
├── BaseOPFOR                 ← capture_point.tscn (OPFOR, capturable = false, at 12, 0, -404)
├── CapturePointAlpha         ← capture_point.tscn (neutral, at -50, 0, -50)
├── CapturePointBravo         ← capture_point.tscn (neutral, at 50, 0, 50)
│
├── SpawnUSMC / SpawnOPFOR    SpawnPoint → BaseUSMC / BaseOPFOR
├── SpawnAlpha / SpawnBravo   SpawnPoint → CapturePointAlpha / CapturePointBravo
│
├── Player                    ← player.tscn (CharacterBody3D + HealthComponent)
│
├── HelicopterSpawn           VehicleSpawn → BaseUSMC     spawns "Helicopter"
├── HumveeSpawn               VehicleSpawn → BaseUSMC     spawns "Humvee"
├── TankSpawn                 VehicleSpawn → BaseUSMC     spawns "Tank"
├── JetSpawn                  VehicleSpawn → BaseUSMC     spawns "Jet" (runway threshold)
├── OPFORTankSpawn            VehicleSpawn → BaseOPFOR    spawns "OPFORTank"
├── OPFORHumveeSpawn          VehicleSpawn → BaseOPFOR    spawns "OPFORHumvee"
├── AlphaHumveeSpawn          VehicleSpawn → Alpha        spawns "AlphaHumvee" once Alpha is held
│
└── GameHUD                   ← game_hud.tscn (CanvasLayer)
    └── KitSelectMenu         ← kit_select.tscn (deploy menu; last child so it draws on top)
```

Vehicles are spawned at runtime as children of their `VehicleSpawn` (with
`top_level = true`), so `find_child("Tank")` still finds them. The `Humvee` nodes and scene
are the utility vehicle (an internal name; players see "Utility Vehicle").

---

## 4. Game-State Layer

The match rules live in a few small scripts with one job each:

| Script | Kind | Responsibility |
|---|---|---|
| `Teams` | static class | Team ids, names, colours, `of(node)`, friendly-fire rule |
| `Kits` | static class | Kit definitions (health, speed, listed weapons) |
| `ConquestManager` | node | Tickets: bleed, death cost, win condition |
| `MatchManager` | node | Participants, spawn validation, respawn timer, kill credit, score |
| `Participant` | data (`RefCounted`) | One soldier's match state |
| `CapturePoint` | `Area3D` | Flag ownership and capture progress (also main bases) |
| `SpawnPoint` | `Marker3D` | Infantry spawn owned by a flag |
| `VehicleSpawn` | `Marker3D` | One vehicle per spot, owned by a flag; wreck, abandon, respawn |
| `HealthComponent` | node | Health, damage, death; applies the friendly-fire rule |

Ownership has one model: **everything belongs to a flag.** Main bases are flags that can't
be captured, so a spawn point or vehicle spawn at a base works exactly like one at a
captured flag.

**Server-authoritative in shape.** The player's side only *requests*; `MatchManager`
validates and acts. Bots (Sprint 5) and network peers (Sprint 6) will use the same calls.

```
HealthComponent.died(attacker)
    ├─→ MatchManager._on_actor_died()               (authority)
    │       ├─→ victim: alive = false, deaths += 1, death_time = now
    │       ├─→ killer = participant_for(attacker) (through a vehicle's occupant if needed):
    │       │       kills += 1, score += 10
    │       └─→ ConquestManager.on_player_killed(victim.team)   (−1 ticket)
    └─→ PlayerController._on_player_died()          (client)
            ├─→ hide player mesh, disable collision
            └─→ KitSelectMenu.show_menu(match, participant)
                    └─→ [team → kit → spawn point (only ones the team holds), DEPLOY]
                            └─→ (queued until MatchManager.time_until_spawn() == 0)
                                    └─→ deploy_requested(team, kit_id, spawn_point)
                                            └─→ PlayerController → MatchManager.request_spawn()
                                                    ├─→ rejected → menu shows the reason
                                                    └─→ approved → PlayerController.spawn_at(transform, team, kit)
                                                            ├─→ team tint, kit health + speed
                                                            └─→ placed at SpawnPoint.get_spawn_transform()
```

What is *not* authoritative yet: damage is applied by whoever fires (hitscan in the
shooter's script, explosions in `Explosion.detonate()` called by the projectile or tank),
and vehicles and the player read `Input` directly. Both need to change
before bots and multiplayer — see the roadmap.

---

## 5. Vehicle Contract & Camera

Vehicles implement a lightweight **duck-typed contract** (no shared base class, because
they extend different body types):

| Member | Type | Required | Notes |
|---|---|---|---|
| `enter_vehicle(player)` | `func → int` | ✅ | Returns the seat index (0 = driver); sets `is_occupied`, `team`, `occupant` |
| `exit_vehicle(player)` | `func → void` | ✅ | Clears `is_occupied`, `team`, `occupant` |
| `is_occupied` | `bool` | ✅ | Vehicle logic only reads input while occupied |
| `team` | `int` | ✅ | Crew's team while occupied, `Teams.NONE` when empty (capture counting, friendly fire) |
| `occupant` | `Node3D` | ✅ | Driver/pilot while occupied; `MatchManager` credits kills made with the vehicle |
| `vehicle_name` | `String` | optional | HUD prompt and vehicle panel |
| `seat_positions` | `Array[Vector3]` | optional | Local seat-camera positions |
| `chase_camera_offset` | `Vector3` | optional | Third-person camera offset |
| `altitude_agl` | `float` | optional | Shown as `ALT` on the vehicle panel |
| `get_hud_status()` | `func → String` | optional | Extra status line on the vehicle panel (jet) |

Every vehicle has a `HealthComponent` as a direct child. Vehicles currently seat one
person (the driver/pilot).

**Camera reparenting:** entering a vehicle disables `PlayerCollision`, hides the player
mesh, moves `CameraPivot` into the vehicle and places it at `chase_camera_offset` (third
person) or `seat_positions[seat]` (first person); `V` toggles between them. On exit the
pivot returns to the player, who is placed 3.5 m to the vehicle's right (global basis) and
1.5 m up. If the vehicle is destroyed with the player inside, the player is ejected and
killed.

---

## 6. Health & Death

`HealthComponent` is a plain `Node` added as a direct child of every actor that can take
damage — see [Gameplay Systems §6](gameplay_systems.md#6-health--damage) for members,
signals and damage sources.

| Actor | `max_health` | On death |
|---|---|---|
| Player | 100 (kit 75–110) | Deploy menu; respawn after the 10 s timer |
| Utility vehicle | 200 | Occupant killed and ejected; wreck stays 4 s; its `VehicleSpawn` respawns it after `respawn_delay` |
| Jet | 250 | As above; also loses thrust and controls, and takes crash damage from impact speed |
| Helicopter | 300 | As above |
| Tank | 500 | As above |

---

## 7. Code Conventions

- **Typed GDScript** for variables, parameters and return types — by convention. The
  project does not raise GDScript warnings to errors yet (engine defaults).
- **`class_name` on every game script**, so scenes and scripts refer to classes by name.
- **`@onready` for child node references** (`$Path`). Lookups of other scene nodes are done
  once in `_ready` with `get_tree().root.find_child("Name", true, false)`, so map layout can
  change without breaking scripts. This assumes one local player; bots and multiplayer
  need per-player wiring instead.
- **No autoloads for game state.** State lives in scene nodes (`ConquestManager`,
  `MatchManager`, `CapturePoint`, `VehicleSpawn`) so a map scene is self-contained and
  testable headlessly. Static helper classes (`Teams`, `Kits`) hold shared constants;
  `Teams.friendly_fire` is the one static setting and should move into per-match settings
  before multiplayer.
- **Tune with exports.** Gameplay numbers are `@export`s on the node so they can be tuned in
  the editor or overridden per instance on a map.
- **Every milestone ships a headless test** (see below).

---

## 8. Testing

Tests are headless Godot scripts in `godot/tests/`. Each suite loads the real map, drives
it from code (teleports, damage, menu calls), prints one `  PASS  ` or `  FAIL  ` line per
check and a `N failure(s)` summary, and exits with code 0 or 1.

| Test | Covers | Checks | Runtime |
|---|---|---|---|
| `teams_test.gd` | Friendly fire, vehicle teams, death → ticket, team respawn, capture, hold, bleed, contest, game over | 43 | ≈ 17 s |
| `match_test.gd` | Participants, kill credit, spawn rules, flag spawns, deploy menu, lost flags, main bases, vehicle wreck/abandon/respawn | 59 | ≈ 17 s |
| `jet_flight_test.gd` | Takeoff, climb, cruise, hard turn, stall, crash | 15 | ≈ 45 s |
| `combat_test.gd` | Rifle and RPG against soldiers, friendly fire, tank HE direct hit and splash with kill credit, bomb direct hit, ticket bleed rate | 23 | ≈ 23 s |

Tests run in real time (physics at 60 Hz).

**Shared base.** Every suite starts with `extends "res://tests/test_base.gd"` (a
`SceneTree` script, deliberately without a `class_name`) and overrides `_run()`, which the
base calls once the tree is up. The base holds the helpers:

| Helper | Does |
|---|---|
| `_check(cond, msg)`, `_fail(msg)` | Print `PASS` / `FAIL` and record failures |
| `_finish()` | Print the summary, release any pressed input actions, quit with 0 or 1 |
| `_ticks(n)`, `_seconds(s)`, `_frames(n)` | Wait physics ticks, seconds of physics time, or process frames |
| `_elapsed()` | Physics time waited so far (the jet test's telemetry clock) |
| `_load_map(path)`, `_find(name)` | Instance a map as the current scene; find a node in it |
| `_make_actor(team)` | A bare `Node3D` with a team, as an attacker |
| `_make_contester(team, pos)` | A body on the Vehicles layer that capture points count for `team` |
| `_teleport(body, pos)`, `_flat_dist(a, b)` | Move and stop a body; horizontal distance |

**Runner.** `godot/tests/run_all.sh` (bash 3.2+, any working directory) needs `GODOT` set.
It runs the headless import once, then every `*_test.gd` in alphabetical order (or only the
suites named as arguments), and prints each suite's output and a table of passes, failures
and seconds. A suite fails if it exits non-zero, prints a `SCRIPT ERROR` or `Parse Error`
line, never prints its summary, or runs longer than `SUITE_TIMEOUT` (default 180 s). A
runtime script error usually stops the suite's coroutine, so such a suite hangs until the
timeout and is reported with both reasons. A script error during the import fails the run
but the suites still run; any other import failure stops the run. The script exits 1 if
anything failed and 2 on usage errors.

```bash
GODOT=/path/to/godot godot/tests/run_all.sh               # all suites
GODOT=/path/to/godot godot/tests/run_all.sh match_test    # only the named ones
```

**CI.** [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs on every pull
request and every push to `master`. On `ubuntu-latest` it downloads the standard Godot
Linux build (cached by version) and runs `run_all.sh`, with a 20 min job timeout. The
Godot version is the single `GODOT_VERSION` variable at the top of the workflow, so an
engine upgrade is a one-line change there. Results show in the job log (one folded group
per suite), as annotations for failing checks, and on the run's summary page.

**Visual checks:** for UI and look-and-feel, a scripted *windowed* run (same `SceneTree`
pattern, without `--headless`) can save screenshots with
`root.get_texture().get_image().save_png()`. Disable the player's input processing in such
scripts, or keystrokes that reach the window will move the player.
