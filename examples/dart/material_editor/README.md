# Thermion Material Editor (web, Dart-only)

A live GLSL material editor running entirely in the browser: edit a Filament
`material()` function, and it is compiled on-device with
[filamat](https://github.com/google/filament/tree/main/libs/filamat) (the same
compiler behind `matc`) and applied to a mesh in real time. No Flutter, no
server — one Dart WASM entry plus the Thermion engine.

```
dart run tool/serve.dart        # http://localhost:8080
```

Then edit the shader on the right; changes compile ~600 ms after you stop
typing (or press Ctrl/Cmd+Enter to compile immediately). Compile errors show
in the status box and outline the editor in red — the mesh keeps the last
good material.

## How it works

- The pubspec sets `runtime_materials: true` under
  `hooks.user_defines.thermion_dart`. On a web build, Thermion's build hook
  fetches the **runtime-materials engine variant**
  (`thermion_dart-<sha>-web-runtime-materials.zip`) instead of the default
  wasm — that build links `libfilamat`, which is what makes
  `FilamentApp.compileMaterialSource` work in the browser.
- The pubspec also sets `web_variant: main_thread`, so the hook actually
  fetches the **combined main-thread runtime-materials variant**
  (`thermion_dart-<sha>-web-main-thread-runtime-materials.zip`): worker-mode
  pthread spawn fails in this environment, while main-thread mode runs
  everything inline — which also pairs naturally with the inline material
  compile (see Notes).
- `compileMaterialSource` dispatches the compile to the engine's job thread on
  native, which drives `MaterialBuilder::build` and returns a validated
  `.filamat`-equivalent package. On web it runs inline on the main thread (see
  Notes below). The editor creates a `MaterialInstance`, swaps it onto the mesh
  with `setMaterialInstanceForAll`, and destroys the previous material.
- The default engine variant stays small precisely because it never
  references filamat symbols — the linker drops them. This variant is ~20 MB
  bigger because it actually contains the compiler.

## Prerequisites

The engine files (`thermion_dart.js` / `thermion_dart.wasm`) land in `web/`
automatically on the first `dart pub get` / `dart run` / `dart compile wasm`
(the build hook downloads them from the Thermion artifact bucket). The Dart
entry itself is compiled with:

```
dart run tool/build.dart
```

## Notes

- The page must be served with COOP/COEP headers (cross-origin isolation) —
  `tool/serve.dart` sets them; any static host must too.
- Compile cost is real CPU work (glslang + SPIRV passes); on a slow machine a
  complex shader can take a second or two. On **native** the UI stays
  responsive because the compile runs on the engine's job thread. On **web**
  the engine is single-threaded (no worker/JobSystem threads), so the compile
  runs inline on the main thread and the page blocks for its duration
  (~1s) — clicks and animation freeze until it finishes.
- Shading model and mesh are switchable in the toolbar; the shading model is
  passed straight to `compileMaterialSource`.
