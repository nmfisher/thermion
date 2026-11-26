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
  (`engine.prepare(scene)`; the per-frame `update()` afterwards must only ever
  report the camera, never the scene).
- Every frame the sidecar accumulates path-traced samples (`Render.refine`),
  snapshots Thermion's offscreen frame and calls `engine.display.present(render)`,
  which runs a registered `Display.addPostProcess` pass **on the shared
  device**: it blends the tone-mapped path-traced image over the Thermion
  snapshot in linear space, and `present()` draws the composite on the visible
  `#thermion_canvas`.
- An **orbit camera** (drag = orbit, wheel = dolly) drives Thermion's camera,
  and the very same view matrix is pushed to the sidecar **every frame**
  (`window.thermionSidecarCamera`); the sidecar applies it to the MuTracer
  camera and restarts the accumulation, so both renderers always show the
  same view. A **mode toggle** (`R` key or the on-screen button) switches
  between `raytrace` (the composite above) and `viewport` (Thermion's raster
  frame passed through unchanged, no path tracing); both modes are presented
  by the sidecar on the shared device.

```
Thermion (Dart/WASM)                     MuTracer sidecar (JS)
  WebGPU backend ── GPUDevice ──────────── Engine({ device })   (same object)
  createOffscreenSwapChain()               Render.refine() samples   (raytrace)
  hidden offscreen canvas ── texture ─────► composite post-process
                               copy         display.present() ──► visible canvas
  orbit camera ── viewMatrix/revision ───► camera.transform + restart
  mode (R / button) ──────────────────────► raytrace | viewport pass-through
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
shows the current mode and the controls hint on the left (`mode: … ·
drag=orbit · wheel=zoom · R=toggle`) and the sidecar's sample progress next to
it. Everything in `web/` except `index.html` and `main.dart` is a build
artifact (see `.gitignore`).

## Controls and modes

| Input               | Action                                                      |
| ------------------- | ----------------------------------------------------------- |
| drag on the canvas  | orbit around the focus point (yaw, pitch clamped to ±86°)    |
| mouse wheel         | dolly (distance 1.5–30 scene units)                          |
| `R` key / button    | toggle `raytrace` ↔ `viewport`                               |

The camera is a spherical orbit around the scene's focus point
(`web/main.dart`, `_OrbitState`). Pointer coordinates are read as **doubles**
through JS interop (`_clientCoords`), not through package:web's `clientX` /
`clientY` getters: those are typed `int`, but browsers deliver fractional
coordinates on trackpads and high-DPI/zoomed displays, and dart2wasm's int
conversion at the boundary throws on any non-integral value (the first drag on
such a device raised an uncaught exception). Every change is applied to the
Thermion camera (`getActiveCamera()` → `lookAt(position, focus: focus)`) and the
resulting view matrix is republished to the sidecar every animation frame:

- `window.thermionSidecarCamera` — `{ viewMatrix, position, focus, revision }`
  (the same JS object, mutated in place). `viewMatrix` is the column-major
  world→camera matrix (`makeViewMatrix`, f32); `revision` only increments when
  the camera actually moved. The Dart pump publishes it **before** calling
  `app.render()`, and the sidecar's rAF callback runs after Dart's in the same
  frame, so the sidecar always sees the matrix Thermion just rendered with.
- `window.thermionSidecarMode` — `'raytrace'` (default) or `'viewport'`,
  written on every toggle.

The sidecar reacts as follows:

- **raytrace** — a new `revision` is inverted (rigid inverse) into the
  MuTracer camera's camera-to-world `transform` and `render.restart()` drops
  the accumulated samples; then `Render.refine()` and the composite
  `display.present()` continue as before. The per-frame `engine.update()`
  still runs: a camera edit is expected to report a change (it never touches
  the BLAS), and any *other* change would trip the "scene re-committed"
  warning in the status line.
- **viewport** — no `refine()` at all. The sidecar still snapshots Thermion's
  offscreen frame (the single present-skip swapchain is kept in both modes)
  and draws that snapshot **unchanged** to the visible canvas' current
  swapchain texture with a fullscreen pass-through pass on the shared device
  (same WebGPU context MuTracer presents to). No blend, no re-encoding, no
  path tracing; the accumulation is reset on the mode switch so switching back
  restarts from 0 samples.
- Switching modes resets the accumulation too, so samples are never mixed
  across views or modes.

`window.thermionSidecarDebug.snapshot()` exposes the sidecar's counters
(`mode`, `cameraRevision`, `restarts`, `refineCalls`, `viewportFrames`,
`unexpectedCommits`, `samples`) for headless checks.

URL parameters:

| Query            | Default    | Meaning                                        |
| ---------------- | ---------- | ---------------------------------------------- |
| `?samples=N`     | `256`      | path-traced samples to accumulate              |
| `?blend=F`       | `0.85`     | 0..1 weight of the traced image over Thermion's |
| `?exposure=E`    | `1`        | linear exposure of the traced image            |
| `?mode=viewport` | `raytrace` | initial mode (`raytrace` or `viewport`)         |

`?blend=0` shows Thermion's raw offscreen output alone through the composite
pass; `?blend=1` shows the path-traced image alone — both still presented by
the sidecar on the shared device. `?mode=viewport` is the same frame without
the composite pass at all.

## How both modes get Thermion's frame

WebGPU cannot import a canvas as an external texture (`importExternalTexture`
accepts video only), and Thermion's offscreen target is the hidden canvas'
swapchain, which only exists for the duration of a frame. So every frame,
after `app.render()` and before presenting, the sidecar asks the hidden
canvas' `GPUCanvasContext` (created by Emscripten for the present-skip
swapchain) for `getCurrentTexture()` — the texture Thermion just rendered into
— and copies it with `copyTextureToTexture` into a sampleable texture,
submitted on the shared queue. The raytrace post-process pass and the viewport
pass-through pass both sample that copy. The cost is one fullscreen texture
copy per frame; nothing leaves the GPU.

One subtlety the spike ran into: **Filament does not render every animation
frame.** Its `beginFrame` rejects a frame while the previous frame's GPU work
is still pending — on the headless SwiftShader run that is every other frame
— and Blink still hands a fresh, *blank* texture to the first
`getCurrentTexture()` caller of every frame. A sidecar that snapshots "the
current texture" unconditionally therefore copies blank frames on the skipped
ones (a composite flickering 15% darker in raytrace mode; a black canvas every
other frame in viewport mode). Within a frame `getCurrentTexture()` returns
the same texture to every caller, so the sidecar wraps the hidden canvas'
`getCurrentTexture` (instance level) to remember the texture *Thermion*
acquired — Thermion's Emscripten surface code calls that very method — and
snapshots only when the current texture is that one. On a skipped frame the
previous snapshot remains the latest Thermion frame for both modes. The
debug snapshot exposes `captures` and `skippedFrames` counters.

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

Orbit camera + mode toggle (headless Playwright script, not committed):
`window.thermionSidecarDebug.snapshot()` counters plus screenshots at 480x320:

- **raytrace (default):** the status reaches `N samples on Thermion's
  GPUDevice (shared, BLAS built once)`, `refineCalls >= N`,
  `unexpectedCommits == 0`.
- **viewport (R key):** `window.thermionSidecarMode` and the sidecar agree,
  the label/button flip, `refineCalls` stays flat (no path tracing),
  `restarts` increments and `samples` drops to 0; three screenshots 350 ms
  apart are identical and non-blank (no blank-frame flicker). The viewport
  screenshot matches a `?blend=0` reference (Thermion's raw frame) within a
  few units per channel and differs clearly from the default composite.
- **camera:** a 90x40 px drag raises `thermionSidecarCamera.revision` and
  moves the eye position; the sidecar's `cameraRevision` follows and
  `restarts` increments once per revision, in both modes. The viewport
  (raster) screenshot changes after the drag, and so does the path-traced
  screenshot after toggling back with the button; the sky/horizon mask of the
  two (same camera, different renderers) overlaps with IoU > 0.85, while the
  mask of the pre-drag screenshot does not — i.e. both renderers moved to the
  same new view.
- Toggling back with the button resets the accumulation again and
  `refineCalls`/`samples` resume from 0.

Cannot be checked headlessly here: perceived smoothness of the orbit on a
real GPU (SwiftShader path-traces ~1 sample/s at 480x320), so each drag step
resets the accumulation to a 1-sample image there.

## Files

- `web/main.dart` — Thermion scene + offscreen swapchain
  (`createOffscreenSwapChain`) + device export (`webGPUDevice`) + JSON scene
  bridge (including `offscreenCanvasSelector`); orbit camera (pointer/wheel
  on the visible canvas → `camera.lookAt`) and the mode toggle (R key +
  button); pumps `app.render()` every animation frame and publishes the
  per-frame camera channel.
- `js/mutracer_sidecar.js` — device import, scene mirror, BLAS-once commit,
  per-frame camera sync, frame snapshot (skipped-frame aware), path tracing,
  compositing post-process, viewport pass-through, presentation.
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
- Static geometry only: the BLAS-once contract is asserted by the per-frame
  `engine.update()` reporting changes only on frames with a camera edit
  (`unexpectedCommits` stays 0). Editing the scene would re-commit and
  rebuild BLASes, which is out of scope here.
- The snapshot relies on Blink's contract that `getCurrentTexture()` returns
  the same texture to every caller within a frame and on Emscripten's surface
  code calling the context method (it does, via `getCurrentTexture()` on the
  JS context). Both are implementation details of the engine build; if either
  changes, the wrapper in `makeCompositor` is the place to revisit.
- WebGPU only. On WebGL2 engines `createOffscreenSwapChain()` throws
  `UnsupportedError`; `offscreenCanvasSelector` and `webGPUDevice` are null.
