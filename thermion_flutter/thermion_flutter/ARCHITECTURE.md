This document is a work-in-progress.

# Architecture

This document goes through implementation details for constructing rendering surfaces, frame synchronization, and rendering backends. 

It's important to remember that most of the below is *specific to the Flutter plugin*.  If you want to use `thermion_dart` as a standalone Dart-only renderer outside a Flutter application, you are free to create your own rendering surface/frame render loop/etc. The details below will be useful as a reference but there's nothing forcing you to follow this exactly.  

## Rendering surface 

On macOS, iOS, Windows, and Linux, Thermion creates a hardware texture. Flutter can composite these textures inside the widget hierarchy via a `Texture` widget. This means the Filament view can be manipulated entirely within the Flutter hierarchy; i.e. you could rotate/scale/translate the ThermionWidget in Flutter if you wanted, or insert other widgets above/below.

The same hardware texture can be imported and used as the backing surface for a Filament `RenderTarget`. Multi-view rendering may be possible but is not thoroughly tested (one render target per view, each render target getting its own texture). When the application window is resized, the textures are destroyed and recreated.

On Android, we create multiple `SurfaceTexture` (each having their own ANativeWindow), and use multiple Filament swapchains. I'm not sure if this is the most efficient approach, so this may change in future.

[See the web section below](#web) for the web implementation details.

## Threading / Task Queue

Filament requires certain tasks to be performed on the same thread that created an `Engine`. Since Dart/Flutter applications cannot (currently) pin isolates to threads, we need to create our own thread and task queue (see `RenderThread.hpp`). On the Dart side, we never call Filament methods directly, we always call the binding method to enqueue the task on the render thread (see `ThermionDartRenderThreadApi.cpp`).

Tasks drain FIFO, one per `iter()`, so there is no preemption: a slow FFI call queued just before a render will delay that render until it finishes.
The deque is lock-protected (`_taskMutex`); `iter()` holds the lock only long enough to pop, releases it to run the task, then re-acquires. This means Dart can enqueue new work while a render is in flight — it just won't run until the current task yields.

Every Dart → Filament call (e.g. moving a camera, adding an entity) goes through a `*_RenderThread` shim that queues a task onto the same `RenderThread::_tasks` deque used by `RenderManager_renderRenderThread`.  Most FFI operations complete in microseconds so this is rarely visible, but bulk operations (e.g. loading a large glTF) can cause a single dropped frame because `_rendering` is still `true` when the next vsync fires.

## Frame synchronization

At a high level, Flutter renders its own UI frames like so:

PlatformDispatcher.scheduleFrame ---> VSYNC ---> handleBeginFrame ---> drawFrame

Since Thermion/Filament renders off the main thread into a texture which is then composited by Flutter, we are racing Flutter's own render sequence. 


        |
        -----> FrameScheduler

> A simpler method is to use the embedding API, which will be explained elsewhere.


On macOS, iOS, Windows, Android, Thermion use the platform vsync signal to synchronize rendering: 

- `CVDisplayLinkScheduler` (macOS)
- `CADisplayLinkScheduler` (iOS)
- `DXGIFrameScheduler` (DXGI `WaitForVBlank`)  (Windows)
- `AChoreographerFrameScheduler` (Android)

On Linux, vsync is not reliably available, so Thermion uses Flutter's own `SchedulerBinding`. Its persistent frame callback feeds the same Dart `FrameScheduler` callback pipeline used by the other platforms. This keeps Thermion in lockstep with Flutter's Skia compositor without introducing a separate Linux render loop: request-frame hooks, `FilamentApp.render()`, and post-render texture notification run in the same order everywhere.

The `FrameScheduler` dispatches its callback to Dart in one of two ways:

- **Release**: a raw C function pointer (`ffi.NativeCallable`) — minimum latency.
- **Debug** (hot-restart safe): `Dart_PostCObject_DL` onto a `ReceivePort`. `Dart_PostCObject` silently drops messages to dead ports, so stale native schedulers created in a previous isolate can't crash the new one.

Linux does not need either native-to-Dart transport because Flutter invokes the persistent frame callback in Dart directly. It still uses the same active, pause, in-flight, diagnostics, and render callback logic after that platform-specific entry point.

Android intentionally keeps render admission on these Dart callback paths.
Flutter's `ImageReaderSurfaceProducer` receives images through a listener on
Android's main looper. A fully native producer loop can continue submitting
buffers while that consumer is delayed, filling the ImageReader pipeline and
blocking `acquireLatestImage()` on the main thread. The Dart in-flight guard
provides the required backpressure.

### Framerate limiting

By default the viewer renders on **every vsync** — i.e. at the display's native refresh rate (60 fps on a 60 Hz panel, 120 on a 120 Hz panel, etc.). Nothing pins it to 60.

`FilamentApp.instance.setTargetFramerate(fps)` caps the rate *below* the display refresh by skipping vsyncs at the source, so dropped native frames never wake Dart. It's an engine-level API — the same native scheduler paces the headless CLI path — and it cannot raise the rate above the refresh. An absolute target deadline preserves the requested average on displays whose refresh is not an integer multiple of the target. For example, 60 fps on a 90 Hz display alternates one- and two-vsync presentation intervals rather than falling to 45 fps. That cadence necessarily has some judder; exact, evenly spaced 60 fps is physically impossible on a fixed 90 Hz presentation clock.

The native display-link sources apply the cap in `FrameScheduler::dispatchFrame`, fed by `FrameScheduler_setTargetFps`. Linux applies the same absolute-deadline algorithm to Flutter's frame timestamps before entering the common callback pipeline. Web applies it directly in its `requestAnimationFrame` loop.

Framerate is a property of the **shared render loop**, not of any one viewer. All viewers on the same engine are pace-locked to the same rate (one scheduler drives a single `renderManager.render()` that renders every attached view each tick), so there is no per-view pacing — the last `setTargetFramerate` call wins for all viewers.

Values less than or equal to zero remove the cap. The in-flight guards still drop work when rendering takes longer than the available frame budget, so the configured value is an upper bound rather than a guarantee that the renderer can sustain that rate.

### Per-frame sequence

On each vsync tick, the following runs:

1. **`_onFrame(frameTimeNanos)`** (`thermion_flutter_plugin_native.dart`) — the Dart-side entry point.
   - Returns early if `_schedulerActive`, `FilamentApp.instance`, `_rendering`, `_resizing`, or `_renderPaused` are set. The `_rendering` re-entrancy guard is what protects against frame pile-up if a render runs long — late frames are **dropped**, not queued.
2. **`_renderFrame()`** (async) awaits `FilamentApp.instance.render()`.
3. **`FFIFilamentApp.render()`** (`thermion_dart/lib/src/filament/src/implementation/ffi_filament_app.dart`) runs registered render hooks, then on the native branch:
   ```dart
   await withVoidCallback((requestId, cb) =>
       RenderManager_renderRenderThread(renderManager, frameTimeInNanos, requestId, cb));
   ```
   This packages a `std::packaged_task` onto `RenderThread::_tasks` and returns a Dart future that resolves when the callback proxies back.
4. **`RenderThread::iter()`** (non-emscripten branch) pops one task from the deque, runs it, then `condition_variable::wait_for(2000μs)` for the next. No polling.
5. **`RenderManager::render()`** runs synchronously on the render thread under `mMutex`:
   - `updateAnimationsAndPlugins(frameTimeInNanos)`
   - for each attached swapchain: `Renderer::beginFrame` → `Renderer::render(view)` per view → `Renderer::endFrame`
   - returns `true` if any swapchain committed a frame
6. The task's completion callback fires `onComplete(requestId)` back on the main thread via the proxying queue; `withVoidCallback`'s future resolves.
7. Back in `_renderFrame`, for each `PlatformTextureDescriptor` we call **`markTextureFrameAvailable()`**.
8. The Texture widget schedules a repaint; Flutter's compositor samples the updated hardware texture on its next frame.

Steps 3–6 are a single Dart `await`: the Flutter frame callback does not return until `endFrame` has completed on the render thread. The render does **not** run on the platform thread — it runs on the dedicated `RenderThread` — so the UI isolate isn't blocked on GPU work beyond the round-trip wait.

### `markTextureFrameAvailable`

`markTextureFrameAvailable` is how we tell Flutter "the texture you imported has new contents; please sample it on the next compositor pass." It is called **after** `endFrame` returns on the render thread (i.e. after the callback has crossed back to the main thread). Implementations:

- **Darwin**: direct Objective-C call — `SwiftThermionFlutterPluginObjCAPI.markTextureFrameAvailableWithFlutterTextureId_` (`darwin_platform_texture_descriptor.dart`).
- **Android/Windows**: platform channel — `channel.invokeMethod("markTextureFrameAvailable", flutterTextureId)` (`method_channel_platform_texture_descriptor.dart`).
- **Linux**: after the common Dart render future completes, one direct FFI call to `thermion_flutter_mark_textures` marks every registered external texture. This keeps texture presentation platform-specific without making rendering platform-specific.

### Composite path

The Flutter side is a standard `Texture(textureId: descriptor.flutterTextureId, filterQuality: none, freeze: false)` widget. The hardware texture backing it is platform-specific:

- **Metal** (macOS/iOS): Filament writes into a Metal texture whose handle is passed in via `importedTextureHandle`.
- **Vulkan** (Windows, Linux fallback): see [Linux § Vulkan](#vulkan) — either a single exportable `VkImage` or a Filament→Flutter blit pair.
- **OpenGL** (Android, Linux preferred): imported GL texture handle.

Compositing itself is Flutter's responsibility — the Texture widget participates in the normal widget tree, so transforms/opacity/clipping all work. The trade-off is one extra texture sample per frame versus drawing directly into the Flutter surface (which Thermion does not do).

### Pause/resume

**The invariant (both platforms): pause stops rendering only. The task queue keeps draining.**

`pauseFrameScheduler()` / `resumeFrameScheduler()` gate the **render pipeline** — on native, Dart's `_onFrame` short-circuits (so no `RenderManager_render` task is queued); on web, `RenderManager::tick()` skips `updateAnimationsAndPlugins` + the swapchain loop. Neither path touches `RenderThread::_tasks`, so every `*_RenderThread` FFI call (`setTransform`, `addEntity`, material/camera updates, etc.) continues to queue and execute exactly as it does when running. `await`-ing an FFI call during pause will not hang; state accumulated during pause is visible on the first render after resume.

App lifecycle suspension is separate from an explicit caller pause. `hidden`,
`paused`, and `detached` suspend rendering; `inactive` does not, because the app
can remain visible while unfocused. Native platforms stop their scheduler while
hidden, except Linux, whose persistent Flutter-synchronized callback remains
registered but paused. Web keeps its requestAnimationFrame loop available so
backend tasks can drain, while pausing the render pipeline. A `resumed`
transition restores rendering without overriding an explicit caller pause or a
resize already in progress.

On native this means:

- the platform `FrameScheduler` keeps ticking — Dart just ignores the callbacks. Scheduler vsync subscription stays warm so resume is free. If you need the scheduler itself stopped (e.g. to avoid penalties from active display-link subscriptions when backgrounded), call `FrameScheduler_stop` explicitly.
- `_renderPaused` (`thermion_flutter_plugin_native.dart`) is the Dart-side gate. It is checked only in `_onFrame`; nothing else in the plugin reads it.

On web this means:

- `mRenderPaused` on `RenderManager` is flipped via `RenderManager_setPaused`. `tick()` consults it around the animation + render block; `mEngine->execute()` stays unconditional so the Filament WebGL backend command buffer keeps draining (otherwise GL-queuing tasks like texture uploads would pile up and burst on resume).
- animations freeze during pause because `updateAnimationsAndPlugins` is part of the render pipeline. This matches native (where `render()` is not called at all, so animations also don't advance). Callers who need the animation clock to keep running without visible frames should not use pause — render into an offscreen swapchain instead.
- the worker rAF itself can't be cleanly cancelled from another thread under emscripten's main loop, so the per-rAF wakeup still happens; pause is a flag-check, not a subscription cancel.

### Diagnostics

`_onFrame` wraps each frame in a `Stopwatch` and logs `[DART] 120-frame avg/max/jank/drop` at 120-frame intervals. A frame > 20ms counts as jank; a vsync that arrives while `_rendering` is still `true` counts as a drop. In port mode (debug), port transit latency is measured separately and logged when it exceeds 2ms.

## Linux

Flutter on Linux/Wayland uses EGL/GDK for rendering with Skia. 

Thermion will create an "EGL-compatible" texture that is passed to Flutter for compositing. Both Vulkan and OpenGL backends are available, but patchy driver support means performance characteristics may vary. EGL + OpenGL is the recommended pathway. This will change when Impeller is stable on Linux.

### Vulkan

My current understanding* is that, with the Skia backend, Flutter can register/import a `VkImage` as a texture provided it was created with the following flags:
- `VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT`
- `VK_IMAGE_TILING_DRM_FORMAT_MODIFIER_EXT`
- `VK_FORMAT_R8G8B8A8_UNORM`
- `VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_SAMPLED_BIT`

* may not be 100% correct, if you have any input feel free to correct me.

However, Filament also requires `VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT` for this to be used as a render target. This combination may not be supported by all drivers.

#### Zero-copy (DMA-BUF only) vs Blit 

The preferred pathway is to use a single `VkImage` for Filament rendering and importing into Flutter (i.e. with `VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT`). See `createExportable` in `LinuxVulkanTexture.cpp`.

If this fails, Thermion allocates two `VkImage`:
- the first is passed to Filament as the backing texture for the render target
- the second is imported into Flutter as the imported texture 
- on every frame, we blit from the first to the second.

See `createWithBlit` in `LinuxVulkanTexture.cpp`.

### EGL/OpenGL

The EGL/OpenGL backend has two pathways for context acquisition:

1. **Flutter context sharing** (preferred): When the Flutter render context is available via deferred populate, Thermion shares that EGL context. This uses the same EGL display as Flutter's Skia renderer, avoiding driver mismatches.

2. **DMA-BUF/GBM fallback**: When no Flutter render context is available yet, Thermion creates its own EGL context via a GBM device (`eglGetPlatformDisplayEXT(EGL_PLATFORM_GBM_KHR, ...)`). On NVIDIA systems, this selects NVIDIA's EGL implementation (via egl-wayland) rather than Mesa's software fallback. A `ThermionPlatformEGLHeadless` is provided to Filament's `GetPlatform()` so it uses this NVIDIA-backed display instead of creating its own default `PlatformEGL`.

Context acquisition from the Flutter plugin side is deterministic: if no deferred populate has fired, a GDK GL context is explicitly created and made current before querying EGL state (rather than relying on `eglGetCurrentContext()`, which is non-deterministic since GDK may or may not have its context active on the platform thread).

The previous EGL context is saved and restored after Thermion's initialization to avoid clobbering Flutter/GDK state.

`ThermionPlatformEGLHeadless` also has a surfaceless swapchain fallback for EGL configs that only support window surfaces (e.g. Mesa/llvmpipe on Wayland) — when pbuffer creation fails, it proceeds with a surfaceless swapchain instead.


## macOS

TODO

## iOS

TODO

## Android

TODO

## Web

On web, Thermion compiles to a single emscripten pthread + WebGL build. Native C++ (`thermion_dart.wasm`) runs inside the browser, Flutter's Dart code calls into it via generated JS-interop bindings, and rendering happens on a separate WebWorker thread that owns the canvas.

### Build-time artifacts

The emscripten build produces two files — `thermion_dart.js` and `thermion_dart.wasm` — that need to sit alongside the Flutter app's `web/index.html`. In normal use, `thermion_dart`'s build hook (`hook/build.dart`, `_downloadWebArtifacts`) reads `native/web/web.version`, downloads the matching zip from Cloudflare R2, caches it under `.dart_tool/thermion_dart/web/<sha>/`, and copies the two files into the consuming package's `web/` directory. CI rebuilds and uploads these artifacts when `web.version` is bumped.

For local iteration on native C++ that needs to ship to web: add `web_local: true` under `hooks.user_defines.thermion_dart` in the consuming app's pubspec.yaml, build the emscripten target (`native/web/build/build/out/thermion_dart.{js,wasm}`), and the build hook will copy from that local path instead of hitting R2. See `_downloadWebArtifacts` in `hook/build.dart`.

### Single-swapchain invariant

Web is fundamentally single-swapchain. `emscripten_pthread_attr_settransferredcanvases(&attr, "#thermion_canvas")` transfers exactly one canvas to the render worker, and the WebGL context lives on that canvas. There is no second canvas to bind a second swapchain to without re-architecting the worker model. The `RenderManager::tick()` loop over `mViewAttachments` is therefore always a one-iteration loop in practice — the generality is kept for parity with the native `render()` path, not because multiple swapchains are expected. Anything that would require a second render target on web (picture-in-picture, offscreen capture) has to be built on views + RTT into a texture, not additional swapchains.

### Threading model

Two threads matter:

- **Main browser thread**: where Dart executes (Flutter's engine runs on the main thread on web). All `FilamentApp` method calls originate here.
- **Render worker**: a pthread spun up at startup by `RenderThread::RenderThread()` via `pthread_create` with `emscripten_pthread_attr_settransferredcanvases(&attr, "#thermion_canvas")`. This transfers ownership of the OffscreenCanvas to the worker, which then owns the WebGL context for the lifetime of the app. The worker's entry point installs `emscripten_set_main_loop_arg(&mainLoop, ...)` so that `RenderThread::iter()` is called on the worker's own `requestAnimationFrame` cadence.

Dart and the worker communicate via emscripten's proxying queue + a lock-protected task deque (`RenderThread::_tasks`). Dart never calls Filament directly from the main thread — every call crosses the thread boundary as a packaged task.

### Dart → worker call pattern

Every generated FFI binding that needs to touch Filament takes the `*_RenderThread` shape — e.g. `Renderer_beginFrameRenderThread(..., requestId, onComplete)`. The Dart side wraps these with `withVoidCallback` / `withPointerCallback` / etc., which:

1. Register a callback port keyed by a fresh `requestId`.
2. Call the `*_RenderThread` FFI function. The C wrapper packages the target call + a capture of `(requestId, onComplete)` into a `std::packaged_task`, pushes it onto `RenderThread::_tasks`, and returns immediately.
3. Dart awaits the completer associated with `requestId`.

On the worker side, `RenderThread::iter()` (emscripten branch) drains every queued task synchronously, each of which runs its underlying Filament call and then fires `onComplete(requestId)`. The callback is proxied back to the main thread via `emscripten::ProxyingQueue::proxySync` (the `PROXY(...)` macro in `ThermionDartRenderThreadApi.cpp`), which resolves the Dart future.

The net effect is that Dart code can `await` a Filament call as if it were synchronous, but the actual GL work happens on the worker where the canvas lives.

### Render loop

Unlike the native path, Dart on web does **not** await individual renders. `FFIFilamentApp.render()` branches on `FILAMENT_SINGLE_THREADED`:

- **Native** queues a `RenderManager_renderRenderThread` task and awaits its completion. `RenderManager::render()` runs the whole pipeline (animations + plugins + all swapchains' beginFrame/render/endFrame + `mEngine->execute()`) as one synchronous task.
- **Web** calls `RenderManager_requestRender(renderManager)` — fire-and-forget. This flips `mRenderRequested = true` but is effectively a no-op (see [Why `mRenderRequested` is bypassed on web](#why-mrenderrequested-is-bypassed-on-web) below).

Rendering is driven entirely from the worker's mainLoop. Each worker rAF, `RenderThread::iter()` drains the task queue and calls `RenderManager::tick(now)`. `tick()`:

1. Runs `updateAnimationsAndPlugins(now)`.
2. For each attached swapchain: `renderSwapChainAt(i)` (beginFrame → render each view → endFrame).
3. **Always** calls `mEngine->execute()` — even if every `beginFrame` rejected.

All three steps happen in a single `tick()` invocation, matching the pre-refactor `RenderTicker::render()` pattern exactly. One frame per worker rAF = ~60fps at display vsync.

### Render loop invariants 

Two things about this loop are load-bearing and easy to break accidentally. Both were discovered through failed attempts to restructure it:

1. **`mEngine->execute()` runs every rAF, unconditionally.** Filament's WebGL backend queues commands in a backend command buffer; `execute()` drains it on the GL context. Skipping `execute()` when every `beginFrame` rejected (which seems like it should be a safe optimization — nothing was queued) stalls the backend entirely after startup. The command buffer needs to be drained each rAF regardless of whether a visible frame was produced.

2. **`beginFrame`, `endFrame`, and `execute` must all happen in the same `tick()` invocation.** Earlier attempts split these across ticks to fit a clean state machine ("tick N renders, tick N+1 executes"), to pipeline across frames (execute previous at top of tick, render next at bottom), or to schedule execute as a `setTimeout(0)` microtask. Every variation either hung, rejected every `beginFrame` after the first, or dropped rendering entirely. The pre-refactor shape — begin/render/end/execute inline under the RenderManager mutex — is the only arrangement empirically shown to work on this combination of emscripten pthreads + OffscreenCanvas + Filament WebGL backend. Don't try to pipeline or split these phases without first understanding why it broke before.

### Why `mRenderRequested` is bypassed on web

The flag was originally intended to gate rendering so Dart could control when frames are produced. In practice, both Dart's main-thread `_tick` and the worker's `mainLoop` run at 60Hz but are **not phase-locked** — they're independent rAFs on different threads. When the worker rAF fires slightly before Dart's has set the flag, the worker finds it clear and skips, losing that frame. Over a second, phase drift costs ~5-10 fps (measured: ~50-55 fps instead of 60).

The fix is to render unconditionally on every worker rAF and let Dart's flag-setting be a no-op. This matches pre-refactor semantics (the `RenderTicker` also ran every worker rAF once it was requested). The flag is kept in the API for symmetry with native but is not gating on the web path.

### Pause/resume on web

See [Pause/resume](#pauseresume) in the native lifecycle section — the invariant and the web-specific notes (`mRenderPaused`, `mEngine->execute()` staying unconditional, animation freeze) are documented together.

### Key files

- `thermion_dart/native/src/rendering/RenderThread.cpp` — pthread + emscripten mainLoop, task queue.
- `thermion_dart/native/src/rendering/RenderManager.cpp` — `render()` (native), `requestRender()`/`tick()` (web).
- `thermion_dart/native/src/c_api/ThermionDartRenderThreadApi.cpp` — `*_RenderThread` C shims + proxy-back callbacks.
- `thermion_dart/lib/src/filament/src/implementation/ffi_filament_app.dart` — `FFIFilamentApp.render()` branches on `FILAMENT_SINGLE_THREADED`.
- `thermion_dart/hook/build.dart` — web artifact download + `THERMION_WEB_LOCAL` override.

## Windows

TODO
