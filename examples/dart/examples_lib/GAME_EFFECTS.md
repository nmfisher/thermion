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
