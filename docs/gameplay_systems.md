# OpenDesertCombat — Gameplay Systems Reference

How each system works today, with the numbers that matter for tuning. Values are code
defaults unless noted; the test map can override them per node.

> Last reviewed 2026-11-27 (end of Sprint 4.2). Known gaps are listed in the
> [roadmap](roadmap.md#known-issues) and flagged ⚠ below.

## Contents

1. [Teams](#1-teams)
2. [Match, participants & spawning](#2-match-participants--spawning)
3. [Conquest: flags & tickets](#3-conquest-flags--tickets)
4. [Deploy menu & kits](#4-deploy-menu--kits)
5. [HUD](#5-hud)
6. [Health & damage](#6-health--damage)
7. [Infantry](#7-infantry)
8. [Vehicle spawns](#8-vehicle-spawns)
9. [Helicopter](#9-helicopter)
10. [Utility vehicle](#10-utility-vehicle)
11. [Tank](#11-tank)
12. [Jet](#12-jet)

---

## 1. Teams

Script: [`teams.gd`](../godot/scripts/game/teams.gd) · Test: [`teams_test.gd`](../godot/tests/teams_test.gd)

A static helper class (no node, no autoload) that is the single source of truth for teams.
Team ids are plain `int`s so they serialise cleanly for bots and network peers later.

| Id | Constant | Name | Colour |
|---|---|---|---|
| 0 | `Teams.NONE` | NEUTRAL | white |
| 1 | `Teams.USMC` | USMC | blue |
| 2 | `Teams.OPFOR` | OPFOR | red |

| Function | Notes |
|---|---|
| `name_of(team)`, `color_of(team)`, `ui_color_of(team)` | Display name, world colour (flags, uniforms), lighter text colour for UI |
| `enemy_of(team)` | `USMC ↔ OPFOR`, `NONE → NONE` |
| `of(node)` | Team of any actor with a `team: int` property; `NONE` for null, freed or teamless nodes |
| `is_friendly_fire(attacker, victim)` | True when both are on the same non-neutral team and are different actors |

**Who has a team:** `PlayerController.team` (exported, default USMC, chosen on the deploy
menu). Every vehicle's `team` is its crew's team while occupied and `NONE` when empty.

**Friendly fire:** `HealthComponent.take_damage()` ignores hits where
`Teams.is_friendly_fire(attacker, get_parent())` is true. `Teams.friendly_fire` (static,
default `false`) turns it on. Self-damage and damage with no attacker (crashes) always
apply. Empty vehicles are neutral, so anyone can damage them.

---

## 2. Match, participants & spawning

Scripts: [`match_manager.gd`](../godot/scripts/game/match_manager.gd),
[`participant.gd`](../godot/scripts/game/participant.gd),
[`spawn_point.gd`](../godot/scripts/game/spawn_point.gd) ·
Test: [`match_test.gd`](../godot/tests/match_test.gd)

`MatchManager` is the authority for who is in the match, where they may spawn, and the
score. Clients *request*; it validates and acts. Today the only client is the local
`PlayerController`; bots (Sprint 5) and network peers (Sprint 6) will use the same calls.

**Participants** (`Participant`, plain data): `id`, `display_name`, `team`, `kit_id`,
`actor`, `is_local`, `is_bot`, `alive`, `death_time`, `kills`, `deaths`, `score`.
`register(actor, name, team)` adds one and listens to the actor's `HealthComponent.died`.
`participant_for(node)` resolves a soldier from their body or from a vehicle's `occupant`.

**Deaths & score:**

| Event | Effect |
|---|---|
| Death (any cause, including crashes and the `K` dev key) | victim `deaths += 1`, `alive = false`, −1 team ticket via `ConquestManager.on_player_killed()` |
| Enemy kill | killer `kills += 1`, `score += SCORE_KILL` (10) |
| Teamkill (only possible with friendly fire on) | killer `score += SCORE_TEAMKILL` (−20) |
| Flag captured | each living soldier of the new owner on the flag `score += SCORE_CAPTURE` (20) |
| Flag neutralised | each attacker on the flag `score += SCORE_NEUTRALISE` (10) |

Signals: `participant_joined`, `participant_spawned`, `participant_died(victim, killer)`,
`score_changed`. Nothing displays the score yet (the scoreboard is Sprint 4.3).

**Spawning:** `request_spawn(participant, team, kit_id, spawn_point)` returns `""` on
success or a reason: not in the match, already deployed, invalid team/kit/spawn, spawn
point not held by that team, or respawn timer still running (`respawn_time`, 10 s). On
success it calls the actor's `spawn_at(transform, team, kit_id)`.

**`SpawnPoint`** (`Marker3D`, group `spawn_points`): owned by its `capture_point` (or a
parent flag), else a fixed `team`. `get_spawn_transform()` picks a random spot within
`spread_radius` (4 m) and snaps it to the ground with a downward ray against the World
layer, so it already works on heightmap terrain. `get_display_name()` uses `spawn_name` or
the flag's name.

**Main bases** are ordinary `CapturePoint`s with `initial_team` set and
`capturable = false`. Their spawn points and vehicle spawns point at them, so a base and a
captured flag work the same way.

---

## 3. Conquest: flags & tickets

Scripts: [`capture_point.gd`](../godot/scripts/game/capture_point.gd),
[`conquest_manager.gd`](../godot/scripts/game/conquest_manager.gd) ·
Scene: [`capture_point.tscn`](../godot/scenes/game/capture_point.tscn)

**Capture points** are `Area3D` zones (12 m radius, 8 m tall, mask Players + Vehicles,
group `capture_points`). Each physics tick they count living soldiers per team: a player on
foot counts for their team, an occupied vehicle counts once for its crew's team, and dead
players and empty vehicles don't count.

- `capture_progress` runs from `-1.0` (fully OPFOR) to `+1.0` (fully USMC). The side with
  more soldiers moves it by `delta / capture_time × difference` (`capture_time = 10 s`;
  difference capped at `max_capture_multiplier = 4`).
- An enemy flag must be dragged back through `0` first. Crossing `0` neutralises it
  (`captured(name, Teams.NONE)`); reaching `±1` hands it over (`captured(name, team)`).
- Equal numbers from both teams means **contested**: progress holds. With nobody present,
  progress drifts back to the owner's full height (or to `0` if neutral), so **owned flags
  stay owned**.
- The banner rises and lowers with `|capture_progress|` and shows the owner's colour, or
  the raising team's colour on a neutral flag.
- `initial_team` pre-owns a flag. `capturable = false` locks it (main bases): it flies a
  bigger banner (`base_banner_scale = 1.6`) with a team-coloured ring around the pole, and
  the HUD says `HOME BASE` or `CANNOT BE CAPTURED`.

**Tickets** (`ConquestManager`): both teams start with `300`.

- **Bleed:** every 1 s, the team holding fewer flags loses
  `ceil(bleed_rate × flag_difference / total_flags)` tickets. Base flags count toward both
  totals. ⚠ With the default `bleed_rate = 1` this always rounds up to **1 ticket per
  second for any deficit**: holding more flags doesn't bleed the enemy faster yet.
- **Deaths:** `MatchManager` calls `on_player_killed(team)` for every death
  (`kill_ticket_cost = 1`).
- **End:** the first team to reach `0` loses; `game_over(winning_team)` fires once and the
  HUD shows `<TEAM> WINS`. There is no end-of-round screen or restart yet (Sprint 4.3).

---

## 4. Deploy menu & kits

Scripts: [`kit_select_menu.gd`](../godot/scripts/ui/kit_select_menu.gd),
[`kits.gd`](../godot/scripts/game/kits.gd) ·
Scene: [`kit_select.tscn`](../godot/scenes/ui/kit_select.tscn), instanced under `GameHUD`
so it draws above the HUD.

**Kits** (`Kits.ALL`, shared by the menu, `MatchManager` and `PlayerController`):

| ID | Name | Listed weapon | Health | Speed |
|---|---|---|---|---|
| 0 | Assault | Assault Rifle + Grenades | 100 | 1.0× |
| 1 | Engineer | SMG + AT Mines | 85 | 1.05× |
| 2 | Medic | LMG + Medkits | 110 | 0.9× |
| 3 | Sniper | Sniper Rifle + C4 | 75 | 1.1× |

⚠ Kits only change health and movement speed so far. Every kit carries the same rifle and
RPG; the listed weapons and gadgets are placeholders.

**Flow:**

1. On death, `MatchManager` records it (ticket, kill credit, respawn timer) and
   `PlayerController` opens `show_menu(match, participant)` with the current team, last kit
   and last spawn point preselected.
2. Pick a **team**, a **kit** and a **spawn point**. Only spawn points the chosen team holds
   are listed (main base + captured flags). The list refreshes every 0.5 s; if the chosen
   flag is lost, the menu says so and falls back to the main base. Selected buttons get a
   tinted fill and bright border.
3. **DEPLOY** during the 10 s respawn timer queues the deploy ("Deploying at Alpha in 3…");
   after the timer it deploys at once.
4. `deploy_requested(team, kit_id, spawn_point)` → `PlayerController` →
   `MatchManager.request_spawn()`, which re-validates everything. Rejected: the menu shows
   the reason. Approved: `PlayerController.spawn_at()` applies team tint, kit health and
   kit speed, and places the player at `SpawnPoint.get_spawn_transform()`.

> [!NOTE] Interim screen. Sprint 4.3 replaces it with a deploy screen on a map overview.

---

## 5. HUD

Script: [`game_hud.gd`](../godot/scripts/ui/game_hud.gd) ·
Scene: [`game_hud.tscn`](../godot/scenes/ui/game_hud.tscn) (`CanvasLayer`)

- **Tickets:** team-coloured counters, `»` marks your own team.
- **Capture panel** (top centre) while you or your vehicle are in a zone: flag name and
  state — `CAPTURING`, `NEUTRALISING`, `SECURING`, `SECURED`, `CONTESTED`, `OUTNUMBERED` —
  plus a progress bar in the leading team's colour. On main bases: `HOME BASE` or
  `CANNOT BE CAPTURED`, without a bar.
- **Banners:** team-coloured "ALPHA CAPTURED BY USMC" / "ALPHA NEUTRALISED" for 3 s, and a
  persistent `<TEAM> WINS`.
- **Vehicle panel:** vehicle name, `ALT` (from the vehicle's `altitude_agl`, if any), `SPD`
  in km/h, and a status line from `get_hud_status()` (jet: throttle, bombs, `LOW SPEED`,
  `!! STALL !!`).
- **Prompts:** `[E] Enter <vehicle_name>` when the 6 m interaction ray finds a vehicle; a
  controls hint bottom-left.

---

## 6. Health & damage

Script: [`health_component.gd`](../godot/scripts/game/health_component.gd)

`HealthComponent` is a plain `Node` added as a direct child of any actor that needs
health; the actor is its parent (used for the friendly-fire check).

| Member | Notes |
|---|---|
| `max_health` (export, 100) | Kits override it for infantry |
| `is_invincible` (export, false) | Ignores all damage |
| `take_damage(amount, attacker)` | Ignored when dead, invincible, `amount <= 0` or friendly fire |
| `heal(amount)`, `reset()`, `is_dead()`, `get_health_ratio()` | |

Signals: `damaged(amount, attacker)`, `healed(amount)`, `died(attacker)`,
`health_changed(current, maximum)`.

**Health pools:** Player 100 (kit 75–110), utility vehicle 200, jet 250, helicopter 300, tank 500.

**Damage sources:**

| Source | Damage | Delivery | Can hit |
|---|---|---|---|
| Rifle | 25 per shot, every 0.11 s | Hitscan 300 m, ray mask World + Vehicles | ⚠ Vehicles and world only — **can't hit soldiers** |
| RPG | 120 to vehicles / 80 to infantry × linear falloff over 8 m | `RocketProjectile`, 95 m/s, 2.5 m/s² drop | ⚠ Direct ray ignores soldiers; the splash hits Players + Vehicles |
| Helicopter rockets | as RPG | Alternate wing pods every 0.22 s | as RPG |
| Tank cannon | 250 | Hitscan 1,800 m, ray mask World + Vehicles, every 3.5 s | ⚠ Vehicles only, no splash — **can't hurt infantry** |
| Jet 20 mm | 18 per round, every 0.07 s | Hitscan 1.5 km, ray mask World + Players + Vehicles | Everything |
| Jet bomb | 450 to vehicles / 200 to infantry, 16 m blast | `RocketProjectile` with `speed = 0` and full gravity | Splash: Players + Vehicles |
| Jet crash | 12 per m/s lost beyond 22 m/s in one tick, + 40 | `JetController` | The jet |
| Vehicle destroyed | Kills the occupant (credited to the vehicle's attacker) | `PlayerController._on_vehicle_destroyed` | Occupant |
| `K` dev key | All remaining health, attacker = self | `PlayerController` | Self (counts as a death) |

Explosions also push `RigidBody3D`s in the blast radius (`blast_impulse = 12000`).

---

## 7. Infantry

Script: [`player_controller.gd`](../godot/scripts/player/player_controller.gd) ·
Scene: [`player.tscn`](../godot/scenes/infantry/player.tscn)
(`CharacterBody3D`, layer Players, mask World + Vehicles)

- **Movement:** walk 5.0, sprint 8.5 (`Shift`), crouch 2.5 m/s (`Ctrl`), all × the kit's
  speed; jump 4.5 m/s (`Space`); mouse sensitivity 0.002, pitch clamped to ±89°.
- **Weapons:** slot `1` rifle, slot `2` RPG (fired from 1.4 m in front of the camera,
  inheriting the player's velocity, 1.1 s cooldown). See [Health & damage](#6-health--damage).
- **Team look:** the capsule's tan uniform is tinted 55 % toward the team colour.
- **Vehicles:** the 6 m `InteractionRay` finds anything with `enter_vehicle()`. Entering
  hides the player, disables its collision and moves `CameraPivot` into the vehicle (chase
  camera, `V` for the seat camera). Exiting puts the player 3.5 m to the vehicle's right and
  1.5 m up.
- **Match:** registers itself with `MatchManager` as participant `"Player"`;
  `spawn_at(transform, team, kit)` is how the match puts it back in the world.
- **Dev key:** `K` kills the player to open the deploy menu (until the 4.3 pause menu).
- **Fallback:** in a scene without `MatchManager` / deploy menu, it respawns after 5 s at a
  spawn point its team holds.

---

## 8. Vehicle spawns

Script: [`vehicle_spawn.gd`](../godot/scripts/game/vehicle_spawn.gd) ·
Test: [`match_test.gd`](../godot/tests/match_test.gd)

A `Marker3D` placed in the map that keeps **one vehicle alive at that spot for whichever
team holds its flag**. It replaced the unused central `VehicleSpawnManager` in Sprint 4.2.

| Export | Default | Notes |
|---|---|---|
| `usmc_vehicle_scene` / `opfor_vehicle_scene` | — | Scene per owning team; if only one is set it is used for both |
| `vehicle_name` | scene name | Node name of the spawned vehicle (e.g. `Tank`, `OPFORTank`) |
| `capture_point` | parent flag | Ownership follows this flag; main-base vehicles point at the base flag |
| `team` | Neutral | Fixed owner, used only when there is no flag |
| `spawn_at_start` | `true` | Spawn on load if the flag is already owned |
| `respawn_delay` | 30 s | After the wreck is removed or an abandoned vehicle is returned |
| `wreck_time` | 4 s | How long a destroyed vehicle stays on show |
| `abandon_time` / `abandon_distance` | 60 s / 30 m | Empty and farther than this from its spawn for this long → returned |

**Rules:**

- Nothing spawns while the flag is neutral; once a team holds it, that team's vehicle
  appears.
- A vehicle already in the field is never taken away when its flag changes hands; only the
  *next* spawn follows the new owner.
- Occupied vehicles are never treated as abandoned.
- The vehicle is added as the marker's child with `top_level = true`, so vehicle scripts
  that use `transform.basis` keep working in world space.
- Signals: `vehicle_spawned(vehicle)`, `vehicle_removed(reason)` with `"destroyed"` or
  `"abandoned"`.

**On the test map** (both teams use the same vehicle scenes for now; the `Humvee` nodes are
the utility vehicle):

| Spawn | Vehicle | Owner | `respawn_delay` |
|---|---|---|---|
| `HelicopterSpawn` | `Helicopter` | USMC base | 45 s |
| `HumveeSpawn` | `Humvee` | USMC base | 30 s |
| `TankSpawn` | `Tank` | USMC base | 60 s |
| `JetSpawn` | `Jet` (runway threshold) | USMC base | 45 s |
| `OPFORTankSpawn` | `OPFORTank` | OPFOR base | 60 s |
| `OPFORHumveeSpawn` | `OPFORHumvee` | OPFOR base | 30 s |
| `AlphaHumveeSpawn` | `AlphaHumvee` | Alpha (whoever holds it) | 30 s |

---

## 9. Helicopter

Script: [`helicopter_controller.gd`](../godot/scripts/vehicles/helicopter_controller.gd) ·
Scene: [`helicopter.tscn`](../godot/scenes/vehicles/helicopter.tscn)

`RigidBody3D`, 5,000 kg, health 300. Shown in game as "Attack Helicopter".

- **Collective & engine spool:** `max_thrust = 85 kN` (≈1.73 thrust-to-weight),
  `idle_thrust_fraction = 0.42`, `engine_spool_rate = 1.2/s`. Holding `W` spools power to
  1.0; `S` sets the collective to −0.35, which drops target power to half of idle (0.21).
  Thrust acts along the body's +Y.
- **Ground effect:** a 500 m downward ray (World layer) gives `altitude_agl`; below 15 m,
  thrust scales up to 1.25×.
- **Cyclic (pitch & roll):** mouse motion (`cyclic_sensitivity = 0.015`, clamped ±1, decays
  to 0 when the mouse stops) → torques of 65 kNm (pitch) and 55 kNm (roll).
- **Tail rotor:** `A` / `D` → 35 kNm yaw torque.
- **Stability & drag:** quadratic drag (0.35); angular damping
  `−angular_velocity × 1.4 × mass`; gentle auto-level (4,500) when the cyclic is centred and
  tilt exceeds 0.08 rad.
- **Weapons:** `LMB` fires unguided rockets (`RocketProjectile`) alternately from the wing
  pods at (±2.1, −0.25, −1.2) every 0.22 s, inheriting the helicopter's velocity.
- **Seats & camera:** two seat positions are defined but only the pilot seat is used; chase
  camera at (0, 4, 13).

---

## 10. Utility vehicle

Script: [`humvee_controller.gd`](../godot/scripts/vehicles/humvee_controller.gd) ·
Scene: [`humvee.tscn`](../godot/scenes/vehicles/humvee.tscn)

`VehicleBody3D`, 2,400 kg with the centre of mass lowered to (0, −0.35, 0), health 200,
four `VehicleWheel3D`s (radius 0.46 m, suspension stiffness 45). Shown in game as
"Utility Vehicle" (the script and scene still use the internal name `Humvee`).

- `W` / `S`: engine force 3,200 forward, 0.65× in reverse.
- `A` / `D`: front-wheel steering up to 0.45 rad, eased at 3.5 rad/s.
- `Space`: handbrake (80). Empty utility vehicles hold a resting brake of 15.
- No weapons; one seat (driver); chase camera at (0, 2.8, 7.5).

---

## 11. Tank

Script: [`tank_controller.gd`](../godot/scripts/vehicles/tank_controller.gd) ·
Scene: [`tank.tscn`](../godot/scenes/vehicles/tank.tscn)

`RigidBody3D`, 62,000 kg, health 500. Shown in game as "Main Battle Tank".

| Parameter | Value | Notes |
|---|---|---|
| `drive_force` | 220,000 N | Along the hull's forward axis |
| `turn_torque` | 180,000 Nm | Yaw torque for steering |
| `brake_force` | 95,000 × speed | Opposes longitudinal velocity when no throttle |
| `max_speed` | 18 m/s (≈65 km/h) | No drive force above it |
| Anti-slip | 8 × mass × lateral speed | Cancels sideways sliding each tick |
| `angular_damping_factor` | 4.5 | Resists tumbling from impulses |
| Upright torque | 15 × mass | Keeps the hull upright |

`linear_damping_ground` and `turret_turn_speed` are exported but not used yet.

**Turret & barrel:** mouse X turns `TurretPivot` (`turret_mouse_sensitivity = 0.0018`);
mouse Y elevates `BarrelPivot` within −5°…+15°. Both are plain `Node3D`s, not simulated.

**Cannon:** hitscan from `Muzzle`, 1,800 m, 250 damage, every 3.5 s, with a visual
`CannonShell` tracer at 580 m/s. ⚠ The ray ignores soldiers and there is no splash, so the
tank can't hurt infantry yet.

**Seat & camera:** driver seat at (0, 1.35, −0.4); chase camera at (0, 3.5, 9).

---

## 12. Jet

Script: [`jet_controller.gd`](../godot/scripts/vehicles/jet_controller.gd) ·
Scene: [`jet.tscn`](../godot/scenes/vehicles/jet.tscn) ·
Test: [`jet_flight_test.gd`](../godot/tests/jet_flight_test.gd)

`RigidBody3D`, 12,000 kg with explicit `inertia = (60000, 80000, 20000)`, health 250. Three
sphere colliders act as landing gear, with a zero-friction airframe material (tyre grip and
braking are applied in code). Damping modes are set to **replace**, so the project-default
0.1/s damping does not add phantom drag. Shown in game as "Multirole Fighter".

**Aerodynamics** (per physics tick):

| Force | Model | Defaults |
|---|---|---|
| Thrust | `max_thrust × throttle` along −Z | 150 kN (TWR ≈ 1.27); `W` / `S` ramp throttle at 0.6/s |
| Lift | `lift_factor × v² × CL`, perpendicular to airflow | `CL = 5.0 × (AoA + 2°)`; stall at 16°, lift falls to 35 % past it |
| Drag | `2.6 × v²` + `0.12 × lift × CL` (induced) | Top speed ≈ 240 m/s; hard turns bleed energy |
| Sideslip | Lateral velocity decays at 2.5/s × (v / 110) | |

**Fly-by-wire (rate command):** the mouse moves a self-centring virtual stick. The stick
commands a body rotation *rate* (pitch 1.2, roll 3.0, yaw 0.45 rad/s at 110 m/s, scaled by
`(v/110)²`). Torque = `inertia × (target − current) × 6`. On top of that:

- **AoA limiter** (arcade assist, on by default): pitch command is capped so AoA stays under
  90 % of stall.
- **Auto-trim** (stick-free): holds the AoA needed for a straight flight path
  (`1 g × cos γ / cos bank`). When the jet is too slow to reach it, the nose falls through
  and it recovers speed on its own.
- **Weathervane** yaw stability and **nose-drop** when stalled.

**Measured envelope** (`jet_flight_test.gd`): liftoff ≈ 363 m / 9.5 s; 300 m AGL at 160 m/s
after 20 s; hands-off cruise ≈ 139 m/s at 40 % throttle; hard turn ≈ 137° in 6 s while
bleeding ≈ 40 m/s.

**Weapons:** 20 mm hitscan cannon (`LMB`, alternating barrels, tracers) and free-fall bombs
(`RMB`, 4 carried, one rearms every 10 s) — damage in [Health & damage](#6-health--damage).

**Ground:** `Space` applies the wheel brakes (60 kN).

**Damage:** losing more than 22 m/s in one tick counts as a crash. On death the jet loses
thrust and controls; any occupant is killed and ejected.
