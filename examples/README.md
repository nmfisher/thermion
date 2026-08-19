# Thermion Examples

This repository contains example Dart and Flutter projects for the Thermion rendering toolkit.

## Dart examples

Shared scene setups live in `dart/examples_lib`; each is registered in
`dart/examples_lib/lib/src/registry.dart`. Render any of them offscreen with
the headless CLI runner:

```sh
cd dart/headless_runner
dart run bin/run_example.dart <name> [width] [height]   # PNG lands in output/
```

`physics_basics` (ReactPhysics3D simulation rendered with Thermion) also runs
in the WASM web gallery as the `physics` scene (`?example=physics`):
ReactPhysics3D is compiled into the same `thermion_dart.wasm` as Thermion
itself -- see `scripts/build_reactphysics3d_web.sh` and
`docs/research/web-physics-scope.md`.

