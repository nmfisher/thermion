# MuTracer sidecar spike (shared-device rendering)

Proof that a second WebGPU renderer can run **on Thermion's own browser
`GPUDevice`** and composite with Thermion's output — no second device, no
readback round-trip through the CPU.

- **Thermion** (Dart, WebGPU backend) renders a small static scene into an
  **offscreen (present-skip) swapchain** (`app.createOffscreenSwapChain()` from
  `package:thermion_dart/thermion_dart_web.dart`): its frames land on a hidden
  canvas the engine owns — reported by `app.offscreenCanvasSelector` — and are
  never presented.
- The engine exports its device to JavaScript on
  `Module['thermionWebGPUDevice']` (`Thermion_exportWebGPUDevice`; on the Dart
  side `app.webGPUDevice`). Both the export and the offscreen swapchain are the
  API merged into `develop` by PR #521. This is the JS-object side of
  Emscripten's `WebGPU.importJsDevice`/`getJsObject` handle table: the sidecar
  receives the *same* `GPUDevice` object Thermion submits to.
- **[@meimu/mutracer](https://www.npmjs.com/package/@meimu/mutracer)** (JS path
  tracer) is constructed with `new Engine({ device })` — its caller-owned
  device mode, which hands the JS object to the engine through
  `WebGPU.importJsDevice`, so both engines submit to the same device and
  queues. The Dart side publishes the whole static scene as JSON
  (`window.thermionSidecarScene`), together with the resolved offscreen canvas
  selector so the sidecar reads the very canvas Thermion renders into; the
  sidecar mirrors meshes, materials, sun and camera into MuTracer, commits it
  with a single `Engine.update()` and builds the static BLAS **once**
  (`engine.prepare(scene)`; the per-frame `update()` afterwards must keep
  reporting "no changes").
- Every frame the sidecar accumulates path-traced samples (`Render.refine`),
  snapshots Thermion's offscreen frame and calls `engine.display.present(render)`,
  which runs a registered `Display.addPostProcess` pass **on the shared
  device**: it blends the tone-mapped path-traced image over the Thermion
  snapshot in linear space, and `present()` draws the composite on the visible
  `#thermion_canvas`.

```
Thermion (Dart/WASM)                     MuTracer sidecar (JS)
  WebGPU backend ── GPUDevice ──────────── Engine({ device })   (same object)
  createOffscreenSwapChain()               Render.refine() samples
  hidden offscreen canvas ── texture ─────► composite post-process
                               copy         display.present() ──► visible canvas
```

## Prerequisites

- Dart SDK ≥ 3.9 (`web/index.html` boots with the `dart2wasm_runtime`
  `compileStreaming` / `CompiledApp.instantiate` API), Node.js ≥ 18, and emsdk
  (Emscripten) on the machine that builds the engine.
- The **WebGPU engine build from `develop`** (the device-export /
  offscreen-swapchain API of PR #521). The published web artifacts predate
  `Thermion_createOffscreenSwapChain` / `Thermion_exportWebGPUDevice`, so the
  example's `pubspec.yaml` sets `web_local: true` and `tool/stage_engine.dart`
  copies the engine from `thermion_dart/native/web/build-webgpu/build/out`
  (it refuses an engine that lacks those exports).

## Run steps

From the repository root:

```sh
# 1. Build the WebGPU web engine (needs emsdk; see the script for the
#    Filament WebGPU archive it expects in native/web/lib/release).
scripts/verify_webgpu_prep_build.sh webgpu

# 2. Bundle the JS sidecar into web/ (esbuild; also emits MuTracer's BVH
#    worker chunk the bundle references).
cd examples/dart/mutracer_sidecar
npm install
npm run build

# 3. Resolve packages and stage the engine (thermion_dart.js/.wasm) into
#    web/. Only `flutter build web` makes Thermion's build hook stage a web
#    engine, and the hook's published engine predates the merged API anyway,
#    so tool/stage_engine.dart copies the engine from step 1 instead.
dart pub get
dart run tool/stage_engine.dart

# 4. Compile the Dart entry to WASM.
dart compile wasm web/main.dart -o web/main.wasm

# 5. Serve web/ with cross-origin isolation (COOP/COEP): the engine module
#    transfers SharedArrayBuffers to its worker, so the page needs
#    crossOriginIsolated or it fails to boot.
dart run tool/serve.dart
```

Open http://localhost:8080 in a WebGPU-capable browser (Chrome/Edge; on Linux
without a GPU add `--enable-unsafe-webgpu`). The status line at the bottom
reports sample progress and confirms the shared device + BLAS-once contract.
Everything in `web/` except `index.html` and `main.dart` is a build artifact
(see `.gitignore`).

URL parameters:

| Query        | Default | Meaning                                        |
| ------------ | ------- | ---------------------------------------------- |
| `?samples=N` | `256`   | path-traced samples to accumulate              |
| `?blend=F`   | `0.85`  | 0..1 weight of the traced image over Thermion's |
| `?exposure=E`| `1`     | linear exposure of the traced image            |

`?blend=0` shows Thermion's raw offscreen output alone; `?blend=1` shows the
path-traced image alone — both still presented by the sidecar on the shared
device.

## How the composite gets Thermion's frame

WebGPU cannot import a canvas as an external texture (`importExternalTexture`
accepts video only), and Thermion's offscreen target is the hidden canvas'
swapchain, which only exists for the duration of a frame. So every frame,
after `app.render()` and before `present()`, the sidecar asks the hidden
canvas' `GPUCanvasContext` (created by Emscripten for the present-skip
swapchain) for `getCurrentTexture()` — the texture Thermion just rendered into
— and copies it with `copyTextureToTexture` into a sampleable texture,
submitted on the shared queue. The post-process pass samples that copy. The
cost is one fullscreen texture copy per frame; nothing leaves the GPU.

## Verification

```sh
cd examples/dart/mutracer_sidecar
dart analyze                      # No issues found
```

Checked headlessly with Chromium + SwiftShader (`--enable-unsafe-webgpu
--enable-unsafe-swiftshader --use-angle=swiftshader`) against the steps above:

- the console shows `Created offscreen (present-skip) swapchain rendering into
  #thermion_canvas__thermion_offscreen` (the selector reported by
  `offscreenCanvasSelector`, resolved by the engine), then the status line
  reaches `N samples on Thermion's GPUDevice (shared, BLAS built once)` with no
  "scene re-committed" warning;
- `?blend=0` and `?blend=1` screenshots show the same geometry (cube, ground
  plane, sky) from the rasterized and the path-traced image respectively, and
  the default blend is a mix of the two — so the scene mirror lines up with
  Thermion's camera and the composite reads Thermion's frame.

## Files

- `web/main.dart` — Thermion scene + offscreen swapchain
  (`createOffscreenSwapChain`) + device export (`webGPUDevice`) + JSON scene
  bridge (including `offscreenCanvasSelector`); pumps `app.render()` every
  animation frame.
- `js/mutracer_sidecar.js` — device import, scene mirror, BLAS-once commit,
  path tracing, compositing post-process, presentation.
- `tool/build_sidecar.mjs` — esbuild bundle script (`npm run build`).
- `tool/stage_engine.dart` — copies the local WebGPU engine into `web/`.
- `tool/serve.dart` — COOP/COEP dev server for `web/`.
- `web/index.html` — loads the engine module first, then the sidecar bundle,
  then the Dart WASM entry.

## Notes / limits (spike scope)

- Photometric parity is approximate: Filament lux and MuTracer irradiance use
  different conventions, and the two tone mappers differ (Thermion runs with
  post-processing off; MuTracer uses ACES). The point is the shared-device
  plumbing, not matched shading.
- The composite blends two display-encoded images in linear space; it is not
  a physically merged render (no shared G-buffer).
- Static scene only: the BLAS-once contract is asserted by the per-frame
  `engine.update()` returning false. Editing the scene would re-commit and
  rebuild BLASes, which is out of scope here.
- WebGPU only. On WebGL2 engines `createOffscreenSwapChain()` throws
  `UnsupportedError`; `offscreenCanvasSelector` and `webGPUDevice` are null.
