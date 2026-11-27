# OpenDesertCombat — Development Roadmap

> Sprints are prioritised against the pillars in [Design Goals](design_goals.md).
> **Current focus:** the **Community track** (build excitement from now until launch)
> runs alongside **Sprint 4**, the Conquest loop: large maps, red vs blue teams,
> respawn and menus. Bots follow in Sprint 5, then multiplayer; the rest of
> atmosphere and air defence after that.

## Community Track (runs alongside every sprint)

Every milestone should end with something people can watch, play or talk about.

### C0 — Before going public
- [x] Name check — **keeping OpenDesertCombat**; "Open" means open terrain and open battle (it also happens to be open source). The only "DESERT COMBAT" trademark found was DICE's US-only class 9 registration, dead since 2013–14. Describe the game as *inspired by* Desert Combat and never use EA/DICE/Desert Combat logos or assets
- [ ] Before an itch.io/Steam release: check the EU, UK and Swedish registers by hand on TMview (automated search couldn't reach them)
- [ ] Repo storefront: description, topics, social preview image, README hero GIF, "follow development" links
- [ ] Contributor-ready: `CONTRIBUTING.md`, issue/PR templates, `good first issue` labels, GitHub Discussions
- [ ] CI: headless import + tests on every pull request

### C1 — Shareable by default
- [ ] Capture rig: scripted camera paths + Godot Movie Maker (`--write-movie`) → MP4/GIF clips of any milestone, no manual recording
- [ ] Photo/spectator mode: free camera, hide HUD, screenshot key — so players make content too
- [ ] Release builds: CI exports Linux/macOS/Windows on version tags → GitHub Releases + itch.io (upload key in GitHub Actions secrets)
- [ ] Minimum "juice" pulled forward from Sprint 7: explosion/impact particles, muzzle flash, smoke trails, core weapon/engine sounds — clips without them don't travel

### C2 — Cadence (every milestone) — GitHub first
- [ ] Devlog post per milestone in `docs/devlog/`, announced in GitHub Discussions
- [ ] Public tech-demo build per sprint on GitHub Releases ("Jet demo", "Conquest alpha", "Bots alpha")
- [ ] Public project board mirroring this roadmap; `good first issue`s refreshed each milestone
- [ ] Bot-match demo before multiplayer; community playtests once multiplayer lands (Sprint 6)

### Later — when channels are chosen
- [ ] Discord server (#devlog, #playtest, #feedback), linked from the main menu and README
- [ ] itch.io page with automatic builds; clips for Reddit / YouTube / Bluesky / X
- [ ] Steam page for wishlists, once the game looks good enough to show
- [ ] Press kit (screenshots, logo, fact sheet) before the first big announcement

## Sprint 1: Core Flight & Sandbox — ✅ Complete
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
- [x] `VehicleSpawnManager` — registers vehicle + spawn point, auto-respawns after 30 s on death (replaced by `VehicleSpawn` nodes in 4.2)
- [x] `TankController` — `RigidBody3D` tracks tank: drive/steer forces, anti-slip, turret yaw (mouse X), barrel pitch clamped −5°/+15°, AP cannon hitscan + `CannonShell` tracer
- [x] `CannonShell` tracer scene and script
- [x] `KitSelectMenu` (Assault / Engineer / Medic / Sniper) — kit picker with confirm countdown, applies kit health to `HealthComponent`
- [x] Player death → `KitSelectMenu` shown → kit applied → respawn at `SpawnUSMC`
- [x] `SpawnUSMC` and `SpawnOPFOR` markers added to `test_desert.tscn`
- [x] All 7 `class_name` declarations registered; headless import + scene load — exit 0, zero errors

## Sprint 3: Fixed-Wing Air — ✅ Complete
- [x] `JetController` fixed-wing flight model — lift ∝ v² × AoA with stall, parasitic + induced drag, fly-by-wire rate command, AoA limiter, stick-free auto-trim
- [x] Jet weapons: hitscan 20 mm cannon with tracers, free-fall bombs (4, rearming)
- [x] Crash damage from impact speed; destroyed vehicles kill their occupants
- [x] `HealthComponent` added to Helicopter (300) and Humvee (200) — previously documented but missing
- [x] Map enlarged to 8 × 8 km with a 900 m runway; jet spawns at the threshold
- [x] Headless flight-model test (`tests/jet_flight_test.gd`)

## Sprint 4: Conquest Loop — Teams, Respawn, Menus & Large Maps (in progress)

The match layer is built server-authoritative in shape: players *request* a team,
kit or spawn and the match manager decides. Bots (Sprint 5) and network peers
(Sprint 6) plug into the same participant registry.

### 4.1 Teams (red vs blue) — ✅ Complete
- [x] `Teams` definitions in one place: names, colours, `enemy_of`, `of(node)`, friendly-fire rule
- [x] Player has a team; occupied vehicles take their crew's team
- [x] Capture points count real teams (previously everyone counted as USMC)
- [x] Owned flags stay owned when nobody is near (previously they decayed to neutral)
- [x] Friendly fire off by default; self-damage and crashes still apply
- [x] Deaths cost the victim's team a ticket (`on_player_killed` was never called)
- [x] Respawn at your own team's base; team picker on the death screen (interim, until 4.3)
- [x] HUD: own team highlighted, team-coloured tickets, flag capture progress bar
- [x] Capture points support `initial_team` and `capturable = false` (main-base flags)
- [x] Headless test (`tests/teams_test.gd`, 42 checks)

### 4.2 Match & spawning — ✅ Complete
- [x] `MatchManager` with a participant registry (id, name, team, kit, score, kills/deaths); kill credit through vehicle occupants
- [x] `SpawnPoint` nodes owned by a base or a flag; capturing a flag gives you its spawns; spawns spread out and snap to the ground
- [x] Main bases are uncapturable flags, so bases and captured flags share one ownership model
- [x] `VehicleSpawn` nodes (replacing the unused `VehicleSpawnManager`): one vehicle per spot, tied to base/flag ownership, wreck then respawn
- [x] Abandoned-vehicle respawn (empty and away from its spawn for N seconds)
- [x] Respawn timer with queued deploy; kit speed applied (only health was)
- [x] Deploy menu lists only the spawn points your team holds and falls back to the base if a flag is lost
- [x] Test map: OPFOR main base 400 m north with its own tank and Humvee; Humvee at Alpha for whoever holds it
- [x] Headless test (`tests/match_test.gd`, 52 checks)

### 4.3 Menus
- [ ] Main menu: Play (map select) / Settings / Quit, plus community links (Discord, GitHub, devlog) — game no longer boots straight into the test map
- [ ] Deploy screen replacing `KitSelectMenu`: team → kit → spawn point on a map overview
- [ ] `Esc` pause menu: Resume, Change team/kit, Suicide, Settings, Quit to menu
- [ ] Settings persisted to `user://settings.cfg`: mouse sensitivity, invert Y, FOV, volume, fullscreen
- [ ] `Tab` scoreboard; end-of-round screen with restart / back to menu

### 4.4 Large maps
- [ ] Upgrade to Godot 4.7.2 (own PR; re-check jet and vehicle handling under the newer Jolt)
- [ ] Terrain3D 1.1.x (MIT GDExtension): sculpted/painted heightmap terrain, `Full / Game` collision so far-off vehicles and bots don't fall through, ≥ 2 m vertex spacing; Git LFS for region data
- [ ] First original map: two main bases (airfield/helipad + armour) 3–4 km apart, 3–5 neutral flags 600–1,200 m apart
- [ ] Out-of-bounds zone with return-to-battle warning
- [ ] Map overview shared by the deploy screen and a HUD minimap (flags, own position/heading, friendly vehicles)

## Sprint 5: Bots
- [ ] Infantry bots: pick a flag your team doesn't hold, path there (Terrain3D navmesh), shoot visible enemies
- [ ] Bots use the same deploy/spawn rules as humans; fill teams to a configurable size
- [ ] IFF: team-coloured name tags / markers for friendlies, crosshair name on enemies
- [ ] Simple vehicle use (drive a Humvee/tank to a flag) — stretch

## Sprint 6: Multiplayer & Linux Release
- [ ] Headless dedicated server mode (`--headless`)
- [ ] Server-authoritative vehicle ownership, hit registration, and `MultiplayerSynchronizer` replication
- [ ] Server browser / direct-connect UI on top of the Sprint 4 menus
- [ ] Standalone Linux binary export

## Sprint 7: Atmosphere & Air Defence
- [ ] Mobile AA vehicle + fixed AA emplacements, guided SAM projectile
- [ ] Full particle pass beyond the Community-track basics (rotor downwash, vehicle dust trails, burning wrecks)
- [ ] Full audio pass (rotor loop, engine spool, distance/doppler, ambient desert wind)
