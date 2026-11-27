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
- Every frame the sidecar snapshots Thermion's offscreen frame and calls
  `engine.display.present(render)`, which runs a registered
  `Display.addPostProcess` pass **on the shared device**: it blends the
  tone-mapped path-traced image over the Thermion snapshot in linear space,
  and `present()` draws the composite on the visible `#thermion_canvas`.
  The path-traced image follows MuTracer's interactive policy: while the
  camera moves, a cheap **preview** `Render` (reduced resolution, adaptive
  scale, 1 spp) is refined for the new view and shown every frame; once the
  camera is stable the full `Render` (`?samples`) converges and takes over
  as soon as it has its first sample for that view.
- An **orbit camera** (drag = orbit, wheel = dolly) drives Thermion's camera,
  and the very same view matrix is pushed to the sidecar **every frame**
  (`window.thermionSidecarCamera`); the sidecar applies it to the MuTracer
  camera and restarts the accumulation, so both renderers always show the
  same view. A **mode toggle** (`R` key or the on-screen button) switches
  between `raytrace` (the composite above) and `viewport` (Thermion's raster
  frame passed through unchanged, no path tracing); both modes are presented
  by the sidecar on the shared device.
- A **mode-aware screenshot** (`C` key or the Capture button) saves the
  current frame as a PNG: in raytrace mode the sidecar reads back the frame
  it presents (`window.thermionSidecarCapture()`), in viewport mode Thermion's
  own capture API is used (`app.capture()`, with a fallback to the sidecar
  readback — see [Screenshot capture](#screenshot-capture)).

```
Thermion (Dart/WASM)                     MuTracer sidecar (JS)
  WebGPU backend ── GPUDevice ──────────── Engine({ device })   (same object)
  createOffscreenSwapChain()               Render.refine() (preview|final)
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
drag=orbit · wheel=zoom · R=toggle`) and the sidecar's progress next to it
(`camera moving, preview N spp at WxH` during a drag, then `N/M samples…`
and `N samples on Thermion's GPUDevice` once converged). Everything in `web/`
except `index.html` and `main.dart` is a build artifact (see `.gitignore`).

## Controls and modes

| Input               | Action                                                      |
| ------------------- | ----------------------------------------------------------- |
| drag on the canvas  | orbit around the focus point (yaw, pitch clamped to ±86°)    |
| mouse wheel         | dolly (distance 1.5–30 scene units)                          |
| `R` key / button    | toggle `raytrace` ↔ `viewport`                               |
| `C` key / button    | save the current frame as a PNG download                       |

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
  MuTracer camera's camera-to-world `transform`, both renders restart, and
  the frame loop applies MuTracer's interactive policy (`changing ? preview :
  final`, the default of its `RenderLoop`):
  - *camera moving* (a new revision, or within 150 ms of one): the preview
    `Render` — canvas-relative, half resolution with `adaptiveResolution`
    down to 1/8 at an 80 ms frame target, 2 bounces, no bevel, one
    wavelength, two light candidates, at most 4 spp — is refined until it
    has a complete sample for the new view (the first `trace()` after a
    reset may be a hidden timing probe and a slow sample is split into
    tiles, so "restart, refine once" can legitimately yield 0 samples; the
    loop is capped at 6 refines per frame). `display.present(render)` then
    shows the preview, because it is `render`'s `fallback`. The full render
    is not refined while the camera moves, so no full-resolution sample is
    started that the next move would discard.
  - *camera stable*: the full `render` converges (`refine()` per frame until
    `?samples`), the preview stays on screen only until the full image has
    its first sample for the current view, and `display.present()` is
    called every frame (if neither render has a complete sample for the
    current camera it presents nothing and the canvas keeps the previous
    image — it never blanks).
  The per-frame `engine.update()` still runs: a camera edit is expected to
  report a change (it never touches the BLAS), and any *other* change would
  trip the "scene re-committed" warning in the status line.
- **viewport** — no `refine()` at all. The sidecar still snapshots Thermion's
  offscreen frame (the single present-skip swapchain is kept in both modes)
  and draws that snapshot **unchanged** to the visible canvas' current
  swapchain texture with a fullscreen pass-through pass on the shared device
  (same WebGPU context MuTracer presents to). No blend, no re-encoding, no
  path tracing; the accumulation is reset on the mode switch so switching back
  restarts from 0 samples.
- Switching modes resets the accumulation too, so samples are never mixed
  across views or modes.

`window.thermionSidecarDebug.snapshot()` exposes the sidecar's counters for
headless checks: `mode`, `cameraRevision`, `restarts` (one per camera
revision or mode toggle; it restarts both renders), `refineCalls` (full
image), `previewRefines`, `previewFrames` / `finalFrames` (which image
`present()` showed), `changing`, `viewportFrames`, `unexpectedCommits`,
`samples` / `converged` / `maxSamples` (full image) and `preview`
(`samples`, `maxSamples`, `resolutionScale`, `width`, `height`), plus the
screenshot counters `screenshotRequests` / `screenshotReadbacks` /
`screenshotFailures` and `screenshot` (`format`, `width`, `height`, `bytes`
of the last readback).

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

## Screenshot capture

One Dart-facing API, `capture()` in `web/main.dart` (bound to the **Capture**
button and the `C` key), returns the current frame as RGBA8, top-left origin,
`canvas.width × canvas.height × 4` bytes; `saveCapture()` encodes it with
Thermion's `pixelBufferToPng` and downloads it as
`mutracer_<mode>_<WxH>_<timestamp>.png`. The status line reports mode,
dimensions, the path that produced the pixels and the PNG byte count, and the
button is disabled while a capture is in flight.

- **raytrace** — `window.thermionSidecarCapture()` (JS → `Promise<Uint8Array>`,
  `js/mutracer_sidecar.js`). Thermion's `app.capture()` is a Filament
  `readPixels` on a Filament target and cannot see MuTracer's textures, so
  the sidecar reads back what it presents: a request is queued and served in
  the frame loop **in the same frame as the present**, right after
  `engine.display.present(render)` (the preview while the camera moves, the
  full image once it has a sample). The visible canvas' current swapchain
  texture — the one `present()` just drew into — is copied with
  `copyTextureToBuffer` into a `MAP_READ | COPY_DST` buffer (rows padded to
  256 bytes), submitted on the shared queue after the present draw, then
  `mapAsync` + `getMappedRange`; the padding is stripped and R/B are swapped
  when the canvas format is BGRA. The texture format is the preferred canvas
  format (`rgba8unorm` on the headless Chromium used for verification;
  `bgra8unorm` on most desktop platforms). The canvas context is configured
  by MuTracer for rendering only, so the sidecar reconfigures it once with
  `RENDER_ATTACHMENT | COPY_SRC` (same format and alpha mode). Requests wait
  for a frame that actually presented (never a blank texture), are rejected
  with a clear `Error` when the device is lost or before the sidecar is up,
  and are also served after the viewport pass-through present.
- **viewport** — Thermion's `app.capture(swapChain, view, pixelDataType:
  UBYTE)` on the offscreen swapchain, i.e. the raster frame the sidecar passes
  through. Filament's WebGPU `readPixels` copies rows in texture order
  (row 0 = top), the same top-left origin as the sidecar, so no flip is
  applied. Two things are driven for it from the example:
  - *Admission.* Filament admits a frame only once the previous one has
    signalled completion (a poll it flushes on rejection). The render pump
    submits a frame every animation frame and is always admitted on its
    retry; a capture arriving behind it is rejected and, on a software
    adapter, fails with `Failed to begin frame`. While a viewport capture is
    in flight the pump therefore renders only every 4th frame (the sidecar
    keeps presenting the last raster frame, so nothing visibly changes).
  - *Completion, and the fallback.* The readback is a GPU buffer map whose
    callback the engine must deliver to Dart. On the Emscripten (main-thread)
    WebGPU engine build this spike runs on it is never delivered: the
    capture does not complete (checked headlessly for 20 s), and
    `Engine_flushAndWait` is no way out — `WebGPUDriver::finish` waits for
    the readback without processing events on Emscripten and hangs the page.
    So the viewport capture waits up to 2 s for Thermion's result and then
    reads back the presented frame through the same sidecar path instead —
    in viewport mode that is the same raster frame, passed through
    unchanged. The status line names the source (`[Thermion app.capture()]`
    or `[sidecar readback]`). On an engine build that delivers the readback,
    the Thermion path is used.

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

Drag motion in raytrace mode (same headless setup, Playwright script not
committed; `?samples=8`, 480x320): after the static view converged, an
in-page drag dispatches `pointerdown` and then one `pointermove` (3 px) per
animation frame on `#thermion_canvas` for ~9 s **without `pointerup`**
(SwiftShader runs the page at ~8 fps under the path tracer). The canvas is
captured four times during the drag, together with the debug snapshot:

| capture | t after first move | camera revision | presented | pixels changed vs previous capture (>24/channel) |
| ------- | ------------------ | --------------- | --------- | ------------------------------------------------ |
| D1      | 1.1 s              | 7               | preview, 1 spp @ 64x48 | 10.0% (vs the converged pre-drag frame) |
| D2      | 2.5 s              | 14              | preview, 1 spp @ 64x48 | 9.0%  |
| D3      | 3.3 s              | 21              | preview, 1 spp @ 64x48 | 1.9%  |
| D4      | 4.0 s              | 28              | preview, 1 spp @ 64x48 | 2.5%  |

All four captures are non-blank and every consecutive pair differs (idle
noise floor between two converged frames: 0.000%); `previewFrames` advanced
by exactly one per camera revision and `refineCalls` stayed flat while the
camera moved (`changing: true`). Before the fix the same drag left D1–D4
pixel-identical (0.00% change, `samples` 0 throughout) and the image only
jumped on release. With the button still held and the pointer idle, the full
render resumed by itself (`changing: false`, `refineCalls` 246 → 271,
`samples` 1); after `pointerup` it reached `8 samples on Thermion's GPUDevice
(shared, BLAS built once)` with `unexpectedCommits == 0`. The viewport
pass-through was re-checked in the same run (non-blank, 0.000% change between
idle frames, 99% different from the composite), and `?blend=0`, `?blend=1`,
the default blend and `?samples=1` still reach `N samples on Thermion's
GPUDevice`. On SwiftShader the preview adapts to the 1/8 scale floor (60x40
requested, 64x48 internal) because a half-resolution sample exceeds the
80 ms target there; the composite crops nothing for it (scale 1) and the
Thermion snapshot is sampled 1:1, so the upscaled preview lines up with the
raster frame.

Cube mirror (same headless setup): one screenshot pair per cube face with the
camera orbited onto that face's outward normal (the pitch clamp leaves the top
and bottom views ~3° off), checking a 16x16 px box on the face centre in the
raster (viewport) frame and in the path-traced image (`?blend=1`). All six
faces are drawn. The `-Z` back face depends on `cubeGeometry()` keeping
cube.dart's reversed index order (`5,4,7` / `5,7,6`): with the generic quad
pattern on every face its box was exactly the sky colour (the ray passed
through the culled face; cube-silhouette IoU raster vs path-traced 0.10),
with the reversal it is the cube's (IoU 0.81). The `-Y` underside is drawn but
black in both renderers (nothing lights it in this scene); its silhouette
still matches the raster frame (IoU 0.99).

Screenshot capture (same headless setup, `?samples=8`, 480x320, Playwright
script not committed; the PNGs are taken from the actual `C`-key / button
downloads and the canvas screenshot is compared over the rows without the
button and status overlays):

| capture                                                 | PNG                                           | vs canvas screenshot (mean abs diff / vertically flipped) | vs the other captures                   |
| ------------------------------------------------------- | --------------------------------------------- | -------------------------------------------------------- | --------------------------------------- |
| A raytrace, converged (`C` key)                         | `89 50 4E 47 0D 0A 1A 0A`, 480x320, non-blank | **1.41** / 31.03                                         | —                                       |
| B viewport (Capture button)                             | 480x320, non-blank                            | **3.95** / 45.27                                         | 100.00% of pixels differ from A         |
| C raytrace, mid-drag (pointer held, `changing: true`)   | 480x320, non-blank                            | —                                                        | 9.38% of pixels differ from the pre-drag A |

- A: `screenshotRequests` and `screenshotReadbacks` each advanced by 1,
  `screenshot = { format: "rgba8unorm", width: 480, height: 320, bytes:
  614400 }` (W×H×4), `screenshotFailures: 0`; the download is named
  `mutracer_raytrace_480x320_<timestamp>.png` and the status line reads
  `captured raytrace 480x320 [sidecar readback] → 90336 bytes PNG (…)`.
  The capture is the presented composite, in the same orientation as the
  canvas (the flipped comparison differs by a factor of 20).
- B: `app.capture()` did not complete within the 2 s bound on this engine
  build (see above), so the image came from the sidecar readback of the
  passed-through frame (`[sidecar readback]` in the status line). It is the
  raster frame (not the composite: every pixel differs from A) and matches
  the canvas with the same top-left orientation.
- C: captured while the pointer was still down and the camera moving
  (`changing: true`, `previewFrames` advanced): the on-screen preview,
  non-blank and different from the converged pre-drag frame.
- The button is disabled synchronously on click and re-enabled when the
  capture finishes; the button click downloads a PNG as well. Convergence
  (8/8 samples before and after the drag), `unexpectedCommits == 0`, no
  console errors and no uncaught page errors still hold in the same run.

Cannot be checked headlessly here: perceived smoothness of the orbit on a
real GPU. SwiftShader path-traces ~1 sample/s at 480x320 and each headless
screenshot takes 0.7–1.9 s, so the mid-drag captures above prove that a new
preview image is presented for every camera revision, not the frame rate a
real GPU gets (half-resolution 1 spp previews there).

## Files

- `web/main.dart` — Thermion scene + offscreen swapchain
  (`createOffscreenSwapChain`) + device export (`webGPUDevice`) + JSON scene
  bridge (including `offscreenCanvasSelector`); orbit camera (pointer/wheel
  on the visible canvas → `camera.lookAt`) and the mode toggle (R key +
  button); the mode-aware screenshot (`capture()`, C key + Capture button →
  PNG download); pumps `app.render()` every animation frame (throttled while
  a viewport capture is in flight) and publishes the per-frame camera
  channel.
- `js/mutracer_sidecar.js` — device import, scene mirror, BLAS-once commit,
  per-frame camera sync, frame snapshot (skipped-frame aware), the
  preview/final interactive policy (preview `Render` as the full render's
  `fallback`, present every frame), compositing post-process, viewport
  pass-through, presentation, and the presented-frame readback behind
  `window.thermionSidecarCapture()`.
- `tool/build_sidecar.mjs` — esbuild bundle script (`npm run build`).
- `tool/stage_engine.dart` — copies the local WebGPU engine into `web/`.
- `tool/serve.dart` — COOP/COEP dev server for `web/`.
- `web/index.html` — loads the engine module first, then the sidecar bundle,
  then the Dart WASM entry; the Capture button and the `#capture_status`
  status span live here.

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
