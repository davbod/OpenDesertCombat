# OpenDesertCombat (ODC)

An open-source modern military combined-arms FPS inspired by *Battlefield 1942: Desert Combat*, built with **Godot 4.4** + **Jolt Physics** and targeting Linux natively.

## Quick Start

```bash
# Run the game from the repository root:
./Godot_v4.4.1-stable_linux.x86_64 --path godot/

# Open in the Godot 4.4 editor:
./Godot_v4.4.1-stable_linux.x86_64 --editor --path godot/

# Run a headless scene/script validation check:
./Godot_v4.4.1-stable_linux.x86_64 --headless --path godot/ --quit
```

## Controls

| Context | Action | Key / Input |
|---|---|---|
| **Infantry** | Move | `W` `A` `S` `D` |
| | Sprint / Crouch / Jump | `Left Shift` / `Left Ctrl` / `Space` |
| | Fire Rifle / RPG-7 | `Left Mouse` |
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
| **System** | Toggle Mouse Capture | `Esc` |

## Project Structure

```
OpenDesertCombat/
├── Godot_v4.4.1-stable_linux.x86_64       # Godot 4.4.1 Linux binary (gitignored)
├── godot/                                  # Godot project root
│   ├── project.godot                       # Project config, inputs, JoltPhysics3D, layers
│   ├── icon.svg                            # Project icon
│   ├── assets/
│   │   └── materials/
│   │       └── desert_terrain.gdshader     # Procedural desert dune & tactical grid shader
│   ├── scenes/
│   │   ├── game/capture_point.tscn         # Capture zone + flagpole/banner
│   │   ├── infantry/player.tscn            # FPS player prefab
│   │   ├── maps/test_desert.tscn           # Playable desert sandbox map
│   │   ├── ui/game_hud.tscn                # HUD (tickets, crosshair, vehicle telemetry)
│   │   ├── vehicles/
│   │   │   ├── helicopter.tscn             # Prototype AH-64 gunship
│   │   │   └── humvee.tscn                 # Prototype 4x4 HMMWV
│   │   └── weapons/
│   │       └── rocket_projectile.tscn      # Hydra 70 / RPG-7 projectile
│   └── scripts/
│       ├── game/
│       │   ├── capture_point.gd            # Zone capture state & flag color updates
│       │   └── conquest_manager.gd         # Team tickets, bleed & win condition
│       ├── maps/
│       │   └── test_desert.gd              # Map startup script
│       ├── player/
│       │   └── player_controller.gd        # FPS movement, vehicle interaction, weapons
│       ├── ui/
│       │   └── game_hud.gd                 # HUD signals & vehicle display
│       ├── vehicles/
│       │   ├── helicopter_controller.gd    # 6-DOF flight physics + Hydra pods
│       │   └── humvee_controller.gd        # VehicleBody3D wheeled driving
│       └── weapons/
│           └── rocket_projectile.gd        # Raycast-swept ballistic rocket + splash impulse
├── docs/
│   ├── architecture.md                     # Engine architecture, physics layers, scene design
│   ├── gameplay_systems.md                 # Vehicle, weapon, infantry & conquest specs
│   ├── roadmap.md                          # Sprint progress & milestones
│   └── formats/
│       └── refractor_formats.md            # Legacy Refractor 1 (.rfa/.sm) research notes
└── tools/
    └── odc-converter/                      # Companion C++20 BF1942 RFA/mesh CLI skeleton
```

## Documentation

- [Architecture Overview](docs/architecture.md)
- [Gameplay Systems Reference](docs/gameplay_systems.md)
- [Development Roadmap](docs/roadmap.md)
- [Refractor Engine Format Notes](docs/formats/refractor_formats.md)

## Tech Stack

- **Engine**: Godot 4.4.1 (MIT)
- **Physics**: Built-in `JoltPhysics3D` (60 Hz tick rate)
- **Renderer**: Vulkan Forward+ with MSAA 3D (`2x`)
- **Target**: Native Linux (`x86_64`)

## License

GPL-3.0 (game code and original assets)
