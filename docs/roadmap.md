# OpenDesertCombat — Development Roadmap

> Sprints are prioritised against the pillars in [Design Goals](design_goals.md).
> *Last updated 2026-11-27 — Sprints 1–3, 4.1 and 4.2 done. **Next: Hardening**, then the
> Godot 4.7.2 upgrade, then 4.3 (menus).* Known problems are tracked under
> [Known issues](#known-issues), each with the milestone that fixes it.
>
> **Current focus:** the **Community track** (build excitement from now until launch)
> runs alongside **Sprint 4**, the Conquest loop: large maps, red vs blue teams,
> respawn and menus. Bots follow in Sprint 5, then multiplayer; the rest of
> atmosphere and air defence after that.

## Order of Work

1. **Hardening** (Sprint 4) — combat fixes, ticket bleed, CI, repo hygiene, pre-public clean-up
2. **Godot 4.7.2 upgrade** — its own PR, with CI green
3. **4.3 Menus** — then the first devlog, once the visual baseline (C1) is in
4. **4.4 Large maps** — graybox on flat ground first, then Terrain3D
5. **Sprint 5** — starts with 5.0 (controls & soldier split), then bots and kit loadouts
6. **Sprint 6** multiplayer, **Sprint 7** atmosphere & air defence

## Definition of Done (every milestone)

- Code with a headless test; all suites green (on CI once it exists)
- Docs updated: README, [Gameplay Systems](gameplay_systems.md), [Architecture](architecture.md), this roadmap
- Play-tested in a window against a short checklist: what changed, what to try, what felt off
- A screenshot or clip saved for the next devlog

## Community Track (runs alongside every sprint)

Every milestone should end with something people can watch, play or talk about.

### C0 — Before going public
- [x] Name check — **keeping OpenDesertCombat**; "Open" means open terrain and open battle (it also happens to be open source). The only "DESERT COMBAT" trademark found was DICE's US-only class 9 registration, dead since 2013–14. Describe the game as *inspired by* Desert Combat and never use EA/DICE/Desert Combat logos or assets
- [ ] Before an itch.io/Steam release: check the EU, UK and Swedish registers by hand on TMview (automated search couldn't reach them)
- [x] Remove `tools/odc-converter`, the root `CMakeLists.txt` and the Refractor format notes from this repo — an extractor for *Battlefield 1942* archives contradicts the original-content policy. Removed in Hardening; they stay in git history if ever wanted for a separate repo
- [ ] Generic or invented in-game names instead of real products ("M1A1 Abrams", "F-16 Fighting Falcon", "AH-64 Apache", "HMMWV", real weapon names) — vehicle makers have taken shooters to court over this before — *in Hardening*
- [ ] CI: headless import + all test suites on every pull request — *in Hardening*
- [ ] Repo storefront: description, topics, social preview image, README hero GIF, "follow development" links
- [ ] Contributor-ready: `CONTRIBUTING.md`, issue/PR templates, `good first issue` labels, GitHub Discussions

### C1 — Shareable by default
- [ ] Visual baseline before the first devlog: CC0 low-poly soldier and vehicle models (e.g. Kenney, Quaternius) with an `ASSETS.md` credits file — grey boxes don't travel
- [ ] Minimum "juice" pulled forward from Sprint 7: explosion/impact particles, muzzle flash, smoke trails, core weapon/engine sounds — clips without them don't travel
- [ ] Capture rig: scripted camera paths + Godot Movie Maker (`--write-movie`) → MP4/GIF clips of any milestone, no manual recording
- [ ] Photo/spectator mode: free camera, hide HUD, screenshot key — so players make content too
- [ ] Release builds: CI exports Linux/macOS/Windows on version tags → GitHub Releases + itch.io (upload key in GitHub Actions secrets)

### C2 — Cadence (every milestone) — GitHub first
- [ ] First devlog after 4.3 (menus, flags, jet), once the C1 visual baseline and basic juice are in
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
- [x] Headless test (`tests/teams_test.gd`, 43 checks)

### 4.2 Match & spawning — ✅ Complete
- [x] `MatchManager` with a participant registry (id, name, team, kit, score, kills/deaths); kill credit through vehicle occupants
- [x] `SpawnPoint` nodes owned by a base or a flag; capturing a flag gives you its spawns; spawns spread out and snap to the ground
- [x] Main bases are uncapturable flags, so bases and captured flags share one ownership model
- [x] `VehicleSpawn` nodes (replacing the unused `VehicleSpawnManager`): one vehicle per spot, tied to base/flag ownership, wreck then respawn
- [x] Abandoned-vehicle respawn (empty and away from its spawn for N seconds)
- [x] Respawn timer with queued deploy; kit speed applied (only health was)
- [x] Deploy menu lists only the spawn points your team holds and falls back to the base if a flag is lost
- [x] Test map: OPFOR main base 400 m north with its own tank and Humvee; Humvee at Alpha for whoever holds it
- [x] Main-base flags look different (bigger banner, team-coloured ring) and the HUD says `HOME BASE` / `CANNOT BE CAPTURED` — from the first play-test
- [x] Deploy menu drawn above the HUD; clear selected state on team / kit / spawn buttons
- [x] Headless test (`tests/match_test.gd`, 59 checks)

### Hardening — next, before 4.3
From the 2026-11-27 review; fixes the [Known issues](#known-issues) marked *Hardening*.
- [ ] Combat fixes: rifle and rocket/bomb flight rays hit soldiers (World + Players + Vehicles, excluding the shooter); tank shells get HE splash so armour can hurt infantry
- [ ] Ticket bleed grows with the flag lead (fractional accumulator instead of `ceil()`), with a test
- [ ] CI: GitHub Actions runs the headless import and all test suites on every pull request
- [ ] Shared test helpers and one runner script instead of copy-pasted helpers in each suite
- [ ] Repo hygiene: commit `*.import` files; raise key GDScript warnings (start with untyped declarations); tidy `test_desert.gd`; remove unused tank exports; delete merged branches and the old worktree
- [ ] Pre-public clean-up from C0: remove the converter tool and Refractor notes; generic in-game vehicle and weapon names

### Engine upgrade: Godot 4.7.2 — before 4.3
- [ ] Godot 4.4.1 → 4.7.2 in its own PR with CI green: re-check the jet envelope and vehicle handling under the newer Jolt; update the README and CI to the new binary. Needed for Terrain3D 1.1; cheapest while the codebase is small

### 4.3 Menus
- [ ] Main menu: Play (map select) / Settings / Quit, plus community links (Discord, GitHub, devlog) — game no longer boots straight into the test map
- [ ] Match options when starting a game: tickets, respawn time, friendly fire (moves `Teams.friendly_fire` into per-match settings)
- [ ] Deploy screen replacing `KitSelectMenu`: team → kit → spawn point on a map overview (the overview is reused by the 4.4 minimap)
- [ ] `Esc` pause menu: Resume, Change team/kit, Suicide (replaces the temporary `K` key), Settings, Quit to menu
- [ ] Settings persisted to `user://settings.cfg`: mouse sensitivity, invert Y, FOV, volume, fullscreen
- [ ] `Tab` scoreboard (MatchManager already tracks kills, deaths and score); end-of-round screen with restart / back to menu

### 4.4 Large maps
- [ ] Graybox first: lay out the first original map on the flat 8 km ground — two main bases (airfield/helipad + armour) 3–4 km apart, 3–5 neutral flags 600–1,200 m apart — and tune distances, flag count and vehicle mix in play-tests before any sculpting
- [ ] Terrain3D 1.1.x (MIT GDExtension): sculpted/painted heightmap terrain, `Full / Game` collision so far-off vehicles and bots don't fall through, ≥ 2 m vertex spacing; Git LFS for region data
- [ ] Sculpt and paint the grayboxed layout: dunes and wadis for cover, a few dense points of interest (town, airfield, bunkers)
- [ ] Out-of-bounds zone with return-to-battle warning
- [ ] HUD minimap built on the 4.3 map overview (flags, own position/heading, friendly vehicles)

### Sprint 4 wrap-up
- [ ] v0.2.0: git tag and `CHANGELOG.md` entry the devlog can point to; README status updated

## Sprint 5: Bots

### 5.0 Controls & soldier split — first
- [ ] Vehicles and soldiers read a controls object (move, look, throttle, steer, fire…) filled by local input, a bot brain or, later, the network — instead of reading `Input` directly
- [ ] Split `PlayerController` into a soldier body (movement, weapons, health, vehicles) and a local-player layer (camera, HUD, menus), wired per player by `MatchManager` instead of `find_child`
- [ ] All suites stay green; a new test drives a soldier and a vehicle through the controls object

### 5.1 Bots
- [ ] Infantry bots: pick a flag your team doesn't hold, path there (Terrain3D navmesh), shoot visible enemies
- [ ] Bots use the same deploy/spawn rules as humans; fill teams to a configurable size
- [ ] Kit loadouts: real weapons and gadgets per kit (sniper rifle, LMG, SMG, AT mines, C4, medkits, grenades), so kits — and bots — play different roles
- [ ] IFF: team-coloured name tags / markers for friendlies, crosshair name on enemies
- [ ] Simple vehicle use (drive a Humvee/tank to a flag) — stretch

## Sprint 6: Multiplayer & Linux Release
- [ ] Headless dedicated server mode (`--headless`)
- [ ] Server-authoritative vehicle ownership, hit registration (damage applied by the server, not the shooter), and `MultiplayerSynchronizer` replication
- [ ] Server browser / direct-connect UI on top of the Sprint 4 menus
- [ ] Standalone Linux binary export

## Sprint 7: Atmosphere & Air Defence
- [ ] Mobile AA vehicle + fixed AA emplacements, guided SAM projectile
- [ ] Full particle pass beyond the Community-track basics (rotor downwash, vehicle dust trails, burning wrecks)
- [ ] Full audio pass (rotor loop, engine spool, distance/doppler, ambient desert wind)

## Known issues

*From the 2026-11-27 review. Each item is a verified fact about the code or repo today; the
italic note says which milestone fixes it.*

### Gameplay
- [ ] **Rifle can't hit soldiers** — its ray mask is World + Vehicles (5); infantry are on Players (2). Infantry-vs-infantry combat doesn't work. *Hardening*
- [ ] **Tank can't hurt infantry** — the cannon ray ignores Players and the shell has no splash. *Hardening*
- [ ] **Rockets and bombs fly through soldiers** — the flight ray ignores Players; only the splash hurts them. *Hardening*
- [ ] **Ticket bleed is flat** — `ceil(bleed_rate × difference / total)` is 1 ticket/s for *any* flag deficit, so a bigger lead doesn't bleed faster. *Hardening*
- [ ] **Kits are health and speed only** — every kit carries the same rifle + RPG-7; the listed weapons and gadgets aren't implemented. *5.1 kit loadouts*

### Architecture (blocks bots and multiplayer)
- [ ] **Vehicles and the player read `Input` directly** (5 scripts), so only the local keyboard can drive anything. Bots and network clients need a controls abstraction that local input, a bot brain or the network can fill. *5.0*
- [ ] **`PlayerController` is soldier and local player in one** — body, weapons and health are mixed with camera, HUD and menu wiring (found with `find_child`). A second soldier (bot) would take over the local HUD and menu. *5.0*
- [ ] **Damage is applied by whoever fires** (hitscan in the shooter's script) — fine single-player, not authoritative for multiplayer. *Sprint 6*
- [ ] `Teams.friendly_fire` is a static, global setting; it belongs in per-match settings. *4.3 match options*
- [ ] Unused tank exports `linear_damping_ground` and `turret_turn_speed`. *Hardening*
- [ ] The helicopter's second seat position is defined but unused. *When multi-seat vehicles arrive*

### Repo & tooling
- [ ] **No CI** — three headless suites (~80 s) only run by hand; test helpers are copy-pasted between suites. *Hardening*
- [ ] `.gitignore` excludes `*.import` files; Godot 4 expects them committed, which matters once real textures and models arrive. *Hardening*
- [ ] GDScript warnings aren't raised to errors (the docs used to claim they were). *Hardening*
- [ ] `test_desert.gd` has stale comments and hard-codes "v0.1.0"; the project version is still 0.1.0. *Hardening; v0.2.0 at Sprint 4 wrap-up*
- [ ] Merged branches (`feat/fixed-wing-jet`, `docs/design-goals`, `worktree-design-goals`) and the old `.claude/worktrees/design-goals` worktree are still around. *Hardening*

### Before going public
- [x] **`tools/odc-converter` and the Refractor format notes** — an extractor for *Battlefield 1942* archives contradicted the original-content policy. Removed, with the root `CMakeLists.txt` and the converter's `.gitignore` entries. *Done in Hardening*
- [ ] **Real product names in game** — "M1A1 Abrams", "F-16 Fighting Falcon", "AH-64 Apache", "HMMWV" versus the "original vehicle and weapon designs" pillar. Decision: generic or invented names. *C0, in Hardening*
