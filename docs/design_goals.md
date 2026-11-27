# OpenDesertCombat — Design Goals

## Gameplay Reference

**[Desert Combat v0.8 Final — El-Alamein, lots of air fights](https://www.youtube.com/watch?v=qPH3r4tAJjw)**

This match shows everything that made the genre great. ODC aims to capture the
same **feel**: the pacing, the vehicle-driven sandbox, and the moment-to-moment
tension. It is a gameplay target, not a blueprint.

> [!IMPORTANT] **Original content only.** Every map, model, texture, sound and
> layout in ODC is created for this project or comes from a properly licensed
> source (CC0 / CC-BY / GPL-compatible). No assets, map layouts or data are
> extracted or copied from *Battlefield 1942*, *Desert Combat* or any other
> commercial game, even from legally owned copies. This keeps the GPL-3.0
> repository clean and free to redistribute.

## Pillars

### 1. Combined arms where every role matters
- Infantry, ground vehicles, helicopters and jets all have a reason to exist on
  the same map at the same time.
- A clear counter-loop: **AA beats air → air beats armour → armour beats
  infantry → infantry (AT kits, mines, C4) beats armour**. No vehicle is safe
  on its own.
- Transport matters: Humvees and transport helicopters move squads between
  distant flags.

### 2. Air superiority is a battle of its own
- Jets dogfight above the ground war. Winning the sky opens up strafing and
  bombing runs on the ground.
- Losing the air is a real problem, but fixed and mobile AA give the ground team
  a way back.
- Flight models are **arcade-first**: easy to take off and fly, with a skill
  ceiling in energy management, turn fights and gunnery.

### 3. Big, open desert maps
- Large maps with long sight lines, dunes and wadis for cover, and a few
  dense points of interest (towns, airfields, bunkers).
- Flags are far enough apart that you need vehicles to reach them, but
  close enough that infantry can still fight over them.
- Each side has a main base with an airfield or helipad and an armour
  spawn. Neutral flags in the middle can be captured to win vehicle spawns.

### 4. Conquest tension
- Ticket bleed puts constant pressure on both teams. Holding the majority of
  flags slowly wins the match.
- Captures can flip a match: taking a flag gives you a new spawn point and
  vehicles.
- A 20–40 minute match should have comebacks, not just stomps.

### 5. Readable, arcade-leaning combat
- Fast time-to-kill for infantry, chunky health pools for vehicles,
  satisfying explosions and physics.
- Clear silhouettes, tracers and audio cues so players can read the
  battlefield at a glance from the ground or the air.
- Modern-military setting (USMC vs OPFOR) with original vehicle and weapon
  designs, built from our own models.

## Gap Analysis vs. Reference

*Updated 2026-11-27, end of Sprint 4.2.*

| Pillar | Already built | Missing |
|---|---|---|
| Combined arms | Infantry, Humvee, attack helicopter, jet, tank; 4 kits | Kit weapons and gadgets (all kits carry the same rifle + RPG; only health and speed differ), AA vehicle/emplacement, transport helicopter, multi-seat vehicles, AT mines/C4 |
| Air superiority | Helicopter + rockets; jet (lift/stall model, cannon, bombs, runway takeoff) | AA counter, OPFOR airframes, landing/rearm on the runway |
| Big desert maps | 8 × 8 km flat test map with two main bases 400 m apart and two flags | Heightmap terrain, an original large map, map overview / minimap, out-of-bounds |
| Conquest tension | Red vs blue teams; flags that neutralise then capture; uncapturable main bases; spawning at held flags; vehicles that belong to flags; ticket bleed and death cost; respawn timer; per-player score | Opponents (bots, multiplayer), scoreboard, end-of-round screen, bleed that grows with the flag lead (it is a flat 1 ticket/s today) |
| Readable combat | Team-coloured flags and uniforms, capture HUD, tracers, explosion flashes | Particles, audio, soldier and vehicle models with clear silhouettes, IFF markers, minimap |

**Counter-loop status** (pillar 1):

| Counter | Status |
|---|---|
| AA beats air | ❌ No AA yet |
| Air beats armour | ✅ Helicopter rockets, jet bombs |
| Armour beats infantry | ❌ The tank cannon can't hit soldiers and has no splash |
| Infantry beats armour | ✅ RPG-7 (AT mines / C4 not yet) |
| Infantry vs infantry | ❌ The rifle's ray can't hit soldiers |

## Asset Sourcing

| Need | Approach |
|---|---|
| Vehicles & weapons | Original low/mid-poly models (Blender), or CC0 bases (e.g. Kenney, Quaternius) modified for ODC |
| Terrain | Procedurally generated or hand-sculpted heightmaps; CC0 textures (e.g. Poly Haven, ambientCG) |
| Audio | Self-recorded / synthesised, or CC0 / CC-BY libraries with attribution tracked in an `ASSETS.md` credits file |
| Maps | Original layouts designed around these pillars, not traced from existing games |
