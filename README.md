# OpenDesertCombat (ODC)

An open-source, modern-military combined-arms shooter inspired by *Desert Combat*, built
with **Godot 4.4** and **Jolt Physics**. The *Open* in the name is about open terrain and
long-range battles — it also happens to be open source.

> [!NOTE] **Early prototype — Sprint 4 (the Conquest loop) is in progress.** Red vs blue
> teams, flag capture, spawning at captured flags, vehicles that belong to flags and the
> deploy menu all work. The attack helicopter, multirole fighter jet, utility vehicle and
> main battle tank are driveable. There are no opponents yet: bots arrive in Sprint 5,
> multiplayer in Sprint 6. See the [roadmap](docs/roadmap.md).

ODC is an independent, original game. It is not affiliated with or endorsed by Electronic
Arts, DICE or the original *Desert Combat* team, and contains no assets from their games
(see the [asset policy](docs/design_goals.md)).

## Quick Start

You need **Godot 4.4.1** (standard build, not .NET) from
[godotengine.org](https://godotengine.org/download/archive/4.4.1-stable/) or
[GitHub releases](https://github.com/godotengine/godot/releases/tag/4.4.1-stable).
The binary is not committed.

```bash
# Point GODOT at your Godot 4.4.1 binary, for example:
export GODOT=./Godot_v4.4.1-stable_linux.x86_64             # Linux (repo root, gitignored)
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot   # macOS

"$GODOT" --path godot/                   # play
"$GODOT" --editor --path godot/          # open in the editor
"$GODOT" --headless --path godot/ --import --quit   # import once after pulling
```

### Tests

Headless test suites, run in real time (about 100 s in total). The runner does the import,
runs every suite, prints a pass/fail table and exits non-zero if anything failed. It works
from any directory; [CI](.github/workflows/ci.yml) runs the same script on every pull
request and push to `master`.

```bash
godot/tests/run_all.sh              # all suites
godot/tests/run_all.sh match_test   # just one
```

A single suite can also run directly (exit code 0 = pass):
`"$GODOT" --headless --path godot/ --script res://tests/match_test.gd`. New suites are picked
up automatically: name them `*_test.gd` and extend `res://tests/test_base.gd` (see
[Architecture § Testing](docs/architecture.md#8-testing)).

| Suite | Covers |
|---|---|
| `teams_test.gd` | Friendly fire, vehicle teams, tickets, team respawn, flag capture / hold / contest, game over |
| `match_test.gd` | Participants, kill credit, spawn rules, flag spawns, deploy menu, main bases, vehicle wreck / abandon / respawn |
| `jet_flight_test.gd` | Jet takeoff, climb, cruise, hard turn, stall, crash |
| `combat_test.gd` | Rifle and RPG against soldiers, friendly fire, tank HE direct hit and splash, bomb direct hit, ticket bleed rate |

## Controls

| Context | Action | Key / Input |
|---|---|---|
| **Infantry** | Move | `W` `A` `S` `D` |
| | Sprint / Crouch / Jump | `Left Shift` / `Left Ctrl` / `Space` |
| | Fire (rifle or RPG) | `Left Mouse` |
| | Switch weapon (rifle / RPG) | `1` / `2` |
| | Enter / exit vehicle | `E` |
| **Helicopter** | Collective up / down | `W` / `S` |
| | Yaw left / right | `A` / `D` |
| | Cyclic pitch / roll | `Mouse` |
| | Fire rockets | `Left Mouse` |
| | Toggle chase / cockpit camera | `V` |
| **Utility vehicle** | Throttle / reverse | `W` / `S` |
| | Steer left / right | `A` / `D` |
| | Handbrake | `Space` |
| | Toggle chase / cockpit camera | `V` |
| **Tank** | Throttle / reverse | `W` / `S` |
| | Turn left / right | `A` / `D` |
| | Rotate turret / elevate barrel | `Mouse X` / `Mouse Y` |
| | Fire main cannon | `Left Mouse` |
| | Toggle chase / cockpit camera | `V` |
| **Jet** | Throttle up / down | `W` / `S` (hold) |
| | Rudder left / right | `A` / `D` |
| | Pitch / roll | `Mouse` (virtual stick, self-centring) |
| | Fire 20 mm cannon | `Left Mouse` |
| | Drop bomb (4, one rearms every 10 s) | `Right Mouse` |
| | Wheel brake (on the runway) | `Space` |
| | Toggle chase / cockpit camera | `V` |
| **Deploy menu** | Pick team, kit and spawn point, then DEPLOY | `Mouse` |
| **System** | Toggle mouse capture | `Esc` |
| | Respawn (die → deploy menu; temporary until the pause menu) | `K` |

## How a Match Works

- Two teams: **USMC** (blue) and **OPFOR** (red), 300 tickets each.
- **Flags:** stand on a flag (or drive onto it) to capture it. An enemy flag lowers and turns
  neutral first, then rises in your colour. Capturing takes 10 s alone, faster with more
  soldiers; equal numbers contest it.
- **Main bases** (bigger flag with a ring) can't be captured — they're each team's
  guaranteed spawn.
- **Tickets:** the team holding fewer flags bleeds tickets, faster the bigger the lead, and
  every death costs a ticket. First to 0 loses. On the test map, holding both middle flags
  drains the enemy's 300 tickets in about 5 minutes; a one-flag lead takes about 10.
- **Respawn:** after a 10 s timer, pick a team, a kit and a spawn point — your main base or
  any flag your team holds. Capturing a flag also gives your team the vehicles parked there.
- Friendly fire is off.

| Kit | Listed weapon | Health | Speed |
|---|---|---|---|
| Assault | Assault Rifle + Grenades | 100 | 1.0× |
| Engineer | SMG + AT Mines | 85 | 1.05× |
| Medic | LMG + Medkits | 110 | 0.9× |
| Sniper | Sniper Rifle + C4 | 75 | 1.1× |

Kits only change health and speed so far; every kit carries the rifle and RPG.

## Project Structure

```
OpenDesertCombat/
├── .github/workflows/ci.yml                # CI: headless import + all suites on Linux
├── godot/                                  # Godot project root
│   ├── project.godot                       # Project config, input map, JoltPhysics3D, physics layers
│   ├── assets/materials/
│   │   └── desert_terrain.gdshader         # Procedural desert dune & tactical grid shader
│   ├── scenes/
│   │   ├── game/capture_point.tscn         # Flag zone + flagpole/banner (also main bases)
│   │   ├── infantry/player.tscn            # FPS soldier (CharacterBody3D + HealthComponent)
│   │   ├── maps/test_desert.tscn           # Test map: two bases, Alpha/Bravo, vehicle spawns
│   │   ├── ui/
│   │   │   ├── game_hud.tscn               # HUD: tickets, capture panel, banners, vehicle panel
│   │   │   └── kit_select.tscn             # Deploy menu: team, kit, spawn point, respawn timer
│   │   ├── vehicles/
│   │   │   ├── helicopter.tscn             # Attack helicopter (RigidBody3D)
│   │   │   ├── humvee.tscn                 # 4×4 utility vehicle (VehicleBody3D)
│   │   │   ├── jet.tscn                    # Multirole fighter (RigidBody3D + gear)
│   │   │   └── tank.tscn                   # Main battle tank (RigidBody3D)
│   │   └── weapons/
│   │       ├── cannon_shell.tscn           # Visual tank-cannon tracer
│   │       └── rocket_projectile.tscn      # Rocket / RPG / bomb projectile
│   ├── scripts/
│   │   ├── game/
│   │   │   ├── capture_point.gd            # Flag ownership, capture progress, banner
│   │   │   ├── conquest_manager.gd         # Tickets: bleed, death cost, win condition
│   │   │   ├── health_component.gd         # Health, damage, death (+ friendly-fire rule)
│   │   │   ├── kits.gd                     # Kit definitions
│   │   │   ├── match_manager.gd            # Participants, spawn rules, kill credit, score
│   │   │   ├── participant.gd              # One soldier's match data
│   │   │   ├── spawn_point.gd              # Infantry spawn owned by a flag
│   │   │   ├── teams.gd                    # Team ids, names, colours, friendly fire
│   │   │   └── vehicle_spawn.gd            # One vehicle per spot: flag ownership, wreck, abandon, respawn
│   │   ├── maps/test_desert.gd             # Map startup script
│   │   ├── player/player_controller.gd     # Movement, weapons, vehicles, death and respawn
│   │   ├── ui/
│   │   │   ├── game_hud.gd                 # HUD logic
│   │   │   └── kit_select_menu.gd          # Deploy menu logic
│   │   ├── vehicles/
│   │   │   ├── helicopter_controller.gd    # 6-DOF flight model + rocket pods
│   │   │   ├── humvee_controller.gd        # Wheeled driving
│   │   │   ├── jet_controller.gd           # Lift/stall/drag model, fly-by-wire, cannon + bombs
│   │   │   └── tank_controller.gd          # Tracks, turret/barrel, HE cannon
│   │   └── weapons/
│   │       ├── cannon_shell.gd             # Tracer (visual only)
│   │       ├── explosion.gd                # Shared blast: direct hit, splash, push, flash
│   │       └── rocket_projectile.gd        # Ray-swept rocket / bomb that detonates an Explosion
│   └── tests/
│       ├── run_all.sh                      # Import + every suite + summary table (used by CI)
│       ├── test_base.gd                    # Shared base: checks, waits, map loading, test actors
│       ├── teams_test.gd                   # Sprint 4.1 headless test
│       ├── match_test.gd                   # Sprint 4.2 headless test
│       ├── jet_flight_test.gd              # Jet flight-model test
│       └── combat_test.gd                  # Weapons vs soldiers, tank HE, ticket bleed
└── docs/
    ├── design_goals.md                     # Pillars, reference match, gap analysis, asset policy
    ├── architecture.md                     # Engine, physics layers, scene tree, game-state layer, testing
    ├── gameplay_systems.md                 # Every system with its tuning numbers
    └── roadmap.md                          # Sprints, community track, known issues
```

## Documentation

| Doc | Contents |
|---|---|
| [Design Goals](docs/design_goals.md) | Gameplay pillars, reference match, gap analysis, original-content policy |
| [Architecture](docs/architecture.md) | Engine and platforms, physics layers, scene tree, game-state layer, vehicle contract, testing |
| [Gameplay Systems](docs/gameplay_systems.md) | Teams, match & spawning, flags & tickets, deploy menu, HUD, damage, infantry, every vehicle |
| [Roadmap](docs/roadmap.md) | Community track, sprint progress, known issues |

## Tech Stack

| Component | Choice | Notes |
|---|---|---|
| Engine | Godot 4.4.1 (MIT) | Upgrade to 4.7.2 planned before Sprint 4.3 |
| Physics | Built-in `JoltPhysics3D` | 60 ticks/s |
| Renderer | Forward+ | Vulkan on Linux/Windows, Metal on macOS; MSAA 2× |
| Language | GDScript | Typed by convention |
| Platforms | Linux `x86_64` first | Developed on macOS and Linux; macOS/Windows builds planned |

## License

GPL-3.0 — game code and original assets.
The Godot Engine and Jolt Physics are MIT-licensed.
