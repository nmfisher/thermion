# Additional game effects

The following setups are exported by `examples_lib.dart` and registered for
the headless runner. They use procedural materials and geometry; no additional
texture downloads are required. They share `default_env_ibl.ktx` and, for the
cryogenic shards, the existing `crystal_ice.filamat`.

| Registry name | Setup | Materials |
| --- | --- | --- |
| `game_effects_thruster` | `setupThruster` | `thruster_exhaust` |
| `game_effects_cryogenic_blast` | `setupCryogenicBlast` | `cryogenic_ground`, `cryogenic_vapor`, `crystal_ice` |
| `game_effects_black_hole` | `setupBlackHole` | `black_hole` |
| `game_effects_teleportation` | `setupTeleportation` | `teleport_surface`, `teleport_particles`, `teleport_field` |
| `game_effects_meteor_impact` | `setupMeteorImpact` | `meteor_rock`, `meteor_flare`, `impact_ground`, `interaction_vapor` |
| `game_effects_corrosive_acid` | `setupCorrosiveAcid` | `corrosive_acid`, `acid_bubble`, `interaction_vapor` |

## Capture

From `examples/dart/headless_runner`:

```sh
dart run bin/run_example.dart game_effects_thruster 768 768 --time 2.2
dart run bin/run_example.dart game_effects_cryogenic_blast 768 768 --video 6 30
dart run bin/run_example.dart game_effects_black_hole 768 768 --video 6 30
```

Use `--time 2.2` for a developed cryogenic blast; it starts dormant at zero.
The six-second cycle spreads frost, grows crystals, ejects chips, holds, and
then retracts/fades before resetting. The thruster varies throttle on a
six-second cycle. The black hole rotates continuously rather than looping
exactly at the end of a six-second capture.

For supersampled previews, capture at `1536 1536`, then encode the PNG sequence
with `ffmpeg -vf scale=768:768:flags=lanczos`. Keep the original frame sequence
as the source instead of recompressing an intermediate video.

Setups register closures in `effectAnimators`. A live host must call and await
these once per frame with elapsed seconds; a setup alone shows its initial
preview pose. Clear the callbacks when disposing the scene. The headless
runner already advances them before every capture. These individual examples
are not entries in the web gallery's separate composite-scene selector.

## Rendering scope

- Thruster: analytically projected conical shock sheets, advected shear-layer
  detail, nozzle geometry, and throttle-driven lighting (no depth-march loop).
  The plume is a view-oriented approximation, not a freely orbitable volume.
- Cryogenic blast: actual 3D shards/chips and a surface frost material, with
  translucent vapor cards oriented for the showcase camera. Chip trajectories
  are deterministic animation, not collision simulation.
- Black hole: an opaque procedural starfield/disk composite with an occluding
  horizon, photon ring, approximate lensed disk arcs, and orbiting debris.
  It does not refract arbitrary scene geometry or integrate relativistic rays.

Bloom is deliberately modest. The materials target the existing Filament
pipeline and compile through the repository's `make materials` target. The
local compiler supports Metal, OpenGL, and Vulkan; WebGPU requires a
WebGPU-enabled Filament build. Mobile performance and live browser rendering
need separate device validation before production use.

## Teleportation, impact, and acid

Use the same capture commands with the registry names above. Useful still
times are `--time 2.65` for teleportation, `--time 1.65` for impact, and
`--time 2.2` for acid. Six-second videos show their full presentation sequences.

- Teleportation transfers a segmented sentinel between pads. A height/noise
  dissolve and 800 camera-facing surface samples create departure, travel,
  and reassembly. The final half-second resets the display for the next cycle.
  This uses emissive flashes, not a scene-color refraction pass.
- Meteor impact combines an incoming rock/trail, a brief flash, displaced
  terrain, cooling fissures, ballistic debris, and expanding dust. Debris
  paths and crater shape are authored, not physics-driven destruction.
  The rock accelerates into contact and sinks beneath the flash; the trail
  dissipates over 0.42 seconds, the crater forms over 0.62 seconds, and debris
  emission is staggered. Run `dart run tool/check_meteor_timeline.dart` from
  `examples_lib` to check envelope bounds, overlap, contact velocity, and reset.
- Acid has animated surface flow, 16 bubble sites synchronized with ripple
  rings and ejected droplets, vapor, and a masked/pitted metal specimen.
  Corrosion is a material approximation rather than a chemical simulation;
  the pool does not flow through arbitrary geometry.
- Shared vapor uses soft card borders and fades near the showcase ground
  at world `y=0`. Vapor and particle cards do not cast rectangular shadows.
  Vapor and meteor trail orientation are authored for the showcase cameras.
  Light-only additive layers output zero alpha so overlapping quads do not
  accumulate opacity and darken the background in the post-processing stack.
