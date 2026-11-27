# OpenDesertCombat (ODC)

An open-source modern military combined-arms FPS inspired by *Battlefield 1942: Desert Combat*, built with **Godot 4.4** + **Jolt Physics** and targeting Linux natively.

> [!NOTE] This is an **early prototype** (Sprint 2 complete). Helicopter, F-16 jet, Humvee, and Tank are driveable; infantry FPS combat and Conquest mode are functional; kit selection and respawn are implemented. Multiplayer and heightmap terrain are Sprint 3–4 targets.

## Quick Start

```bash
# Run the game (from repository root):
./Godot_v4.4.1-stable_linux.x86_64 --path godot/

# Open in the Godot 4.4 editor:
./Godot_v4.4.1-stable_linux.x86_64 --editor --path godot/

# Headless validation (CI / no display):
./Godot_v4.4.1-stable_linux.x86_64 --headless --path godot/ --import --quit
./Godot_v4.4.1-stable_linux.x86_64 --headless --path godot/ --quit

# Jet flight-model test (takeoff, cruise, hard turn, stall, crash) — exits non-zero on failure:
./Godot_v4.4.1-stable_linux.x86_64 --headless --path godot/ --script res://tests/jet_flight_test.gd
```

> [!IMPORTANT] The Godot binary (`Godot_v4.4.1-stable_linux.x86_64`) is **not** committed. Download it from [godotengine.org](https://godotengine.org/download) or [GitHub releases](https://github.com/godotengine/godot/releases/tag/4.4.1-stable) and place it in the repository root.

## Controls

| Context | Action | Key / Input |
|---|---|---|
| **Infantry** | Move | `W` `A` `S` `D` |
| | Sprint / Crouch / Jump | `Left Shift` / `Left Ctrl` / `Space` |
| | Fire (Rifle or RPG-7) | `Left Mouse` |
| | Switch Weapon (Rifle / RPG-7) | `1` / `2` |
| | Enter / Exit Vehicle | `E` |
| **Helicopter** | Collective Up / Down | `W` / `S` |
| | Yaw Left / Right | `A` / `D` |
| | Cyclic Pitch / Roll | `Mouse` |
| | Fire Hydra 70 Rockets | `Left Mouse` |
| | Toggle Chase / Cockpit Camera | `V` |
| **Humvee** | Throttle / Reverse | `W` / `S` |
| | Steer Left / Right | `A` / `D` |
| | Handbrake | `Space` |
| | Toggle Chase / Cockpit Camera | `V` |
| **Tank** | Throttle / Reverse | `W` / `S` |
| | Turn Left / Right | `A` / `D` |
| | Rotate Turret | `Mouse X` |
| | Elevate Barrel | `Mouse Y` |
| | Fire Main Cannon | `Left Mouse` |
| | Toggle Chase / Cockpit Camera | `V` |
| **Jet** | Throttle Up / Down | `W` / `S` (hold) |
| | Rudder Left / Right | `A` / `D` |
| | Pitch / Roll | `Mouse` (virtual stick, self-centring) |
| | Fire 20 mm Cannon | `Left Mouse` |
| | Drop Bomb (4, rearm 10 s each) | `Right Mouse` |
| | Wheel Brake (on runway) | `Space` |
| | Toggle Chase / Cockpit Camera | `V` |
| **System** | Toggle Mouse Capture | `Esc` |

## Kits (shown at death/respawn)

| Kit | Weapon | Health | Speed |
|---|---|---|---|
| Assault | M4A1 + Grenades | 100 | 1.0× |
| Engineer | MP5 + AT Mines | 85 | 1.05× |
| Medic | M60 + Medkits | 110 | 0.9× |
| Sniper | M24 + C4 | 75 | 1.1× |

## Project Structure

```
OpenDesertCombat/
├── Godot_v4.4.1-stable_linux.x86_64       # Godot 4.4.1 Linux binary (gitignored)
├── godot/                                  # Godot project root
│   ├── project.godot                       # Project config, inputs, JoltPhysics3D, physics layers
│   ├── icon.svg                            # Project icon
│   ├── assets/
│   │   └── materials/
│   │       └── desert_terrain.gdshader     # Procedural desert dune & tactical grid shader
│   ├── scenes/
│   │   ├── game/
│   │   │   └── capture_point.tscn          # Conquest capture zone + flagpole/banner
│   │   ├── infantry/
│   │   │   └── player.tscn                 # FPS player (CharacterBody3D + HealthComponent)
│   │   ├── maps/
│   │   │   └── test_desert.tscn            # Playable desert sandbox map
│   │   ├── ui/
│   │   │   ├── game_hud.tscn               # HUD (tickets, crosshair, vehicle telemetry)
│   │   │   └── kit_select.tscn             # Full-screen kit picker shown on death
│   │   ├── vehicles/
│   │   │   ├── helicopter.tscn             # AH-64-style gunship (RigidBody3D)
│   │   │   ├── humvee.tscn                 # 4×4 HMMWV (VehicleBody3D)
│   │   │   ├── jet.tscn                    # F-16-style fighter (RigidBody3D + gear)
│   │   │   └── tank.tscn                   # M1A1-style MBT (RigidBody3D tracks)
│   │   └── weapons/
│   │       ├── cannon_shell.tscn           # Visual AP tracer round (tank cannon)
│   │       └── rocket_projectile.tscn      # Hydra 70 / RPG-7 ballistic projectile
│   └── scripts/
│       ├── game/
│       │   ├── capture_point.gd            # Zone capture state & flag color updates
│       │   ├── conquest_manager.gd         # Team tickets, bleed & win condition
│       │   ├── health_component.gd         # Reusable health/damage/die node
│       │   └── vehicle_spawn_manager.gd    # 30 s vehicle wreck + respawn system
│       ├── maps/
│       │   └── test_desert.gd              # Map startup script
│       ├── player/
│       │   └── player_controller.gd        # FPS movement, vehicle interaction, weapons, respawn
│       ├── ui/
│       │   ├── game_hud.gd                 # HUD signals & vehicle telemetry display
│       │   └── kit_select_menu.gd          # Kit picker logic & respawn countdown
│       ├── vehicles/
│       │   ├── helicopter_controller.gd    # 6-DOF flight physics + Hydra 70 pods
│       │   ├── jet_controller.gd           # Lift/stall/drag model, fly-by-wire, cannon + bombs
│       │   ├── humvee_controller.gd        # VehicleBody3D wheeled driving
│       │   └── tank_controller.gd          # RigidBody3D tracks, turret/barrel, AP cannon
│       └── weapons/
│           ├── cannon_shell.gd             # Fast AP tracer round (visual only)
│           └── rocket_projectile.gd        # Raycast-swept ballistic rocket + splash damage
├── docs/
│   ├── architecture.md                     # Engine choice, physics layers, scene hierarchy
│   ├── gameplay_systems.md                 # Full system specs (vehicles, weapons, health, kits)
│   ├── design_goals.md                     # Gameplay pillars, reference match, asset policy
│   ├── roadmap.md                          # Sprint progress & milestones
│   └── formats/
│       └── refractor_formats.md            # Legacy Refractor 1 (.rfa/.sm) research notes
└── tools/
    └── odc-converter/                      # Companion C++20 BF1942 RFA/mesh CLI skeleton
```

## Documentation

| Doc | Contents |
|---|---|
| [Design Goals](docs/design_goals.md) | Gameplay pillars, reference match, gap analysis, original-assets policy |
| [Architecture Overview](docs/architecture.md) | Engine rationale, physics layers, scene hierarchy, vehicle contract |
| [Gameplay Systems Reference](docs/gameplay_systems.md) | Detailed specs for all systems (helicopters, tank, health, kits, conquest) |
| [Development Roadmap](docs/roadmap.md) | Sprint tracker — what's done, what's next |
| [Refractor Format Notes](docs/formats/refractor_formats.md) | BF1942 `.rfa` archive reverse-engineering notes |

## Tech Stack

| Component | Choice | Notes |
|---|---|---|
| **Engine** | Godot 4.4.1 (MIT) | |
| **Physics** | Built-in `JoltPhysics3D` | 60 Hz, no GDExtension needed in 4.4+ |
| **Renderer** | Vulkan Forward+ | MSAA 3D `2×` |
| **Language** | GDScript (typed) | Warnings treated as errors |
| **Target platform** | Linux `x86_64` native | |

## License

GPL-3.0 — game code and original assets.
The Godot Engine itself is MIT-licensed. Jolt Physics is MIT-licensed.
