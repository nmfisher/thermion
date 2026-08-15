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

`physics_basics` (ReactPhysics3D simulation rendered with Thermion) is
native/headless only -- it is not wired into the WASM web gallery. See the
note at the top of `dart/examples_lib/lib/src/physics_basics.dart`.

