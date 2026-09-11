# Scheduling regressions

Run from the repository root with CMake 3.22+ and a C++17 compiler. The suite
needs no Filament, Dart, or Flutter installation. It targets desktop Linux,
macOS, and Windows. Run it manually using the commands below.

```sh
cmake -S thermion_dart/native/test/rendering -B /tmp/thermion-scheduling
cmake --build /tmp/thermion-scheduling --config Release
ctest --test-dir /tmp/thermion-scheduling -C Release --output-on-failure
```

Coverage:

- Gate totals under regular 60, 90, 120, and 144 Hz source ticks; alternating
  1/2-vsync gaps for 60 fps on 90 Hz; the 1 ms early-admission boundary; zero
  timestamps, stalls, rate changes, unlimited mode, and reset.
- Clock mapping with distinct epochs, missing/future timestamps, underflow,
  recovery without backwards time, and a changed clock offset after sleep.
- On macOS, preceding-vsync estimates with missing or invalid CVDisplayLink
  metadata, measured rate adjustment, and overflow-safe Mach tick conversion.
- Generic timer rate increases/decreases and prompt stop while waiting. On
  Windows, the same checks force a failed VBlank wait through DXGI's fallback,
  assert that it stops retrying VBlank, and exercise the shared timer loop.

The clock mapper estimates frame age from nearby source-clock and steady-clock
samples. Sampling delay introduces error. Missing or implausible Apple timing
data falls back to delivery time, as the timer source does; recovery is clamped
to nondecreasing time. The fallback is not a measured hardware vsync.

These tests do not measure physical presentation intervals, animation
smoothness, Android looper behavior, live Apple display-link callbacks, or
successful DXGI hardware waits. Stopping DXGI's timer wait is interruptible;
an in-progress hardware `WaitForVBlank` must still return before stop completes.

Native Android callbacks remain registered at display frequency even when the
gate rejects rendering work. Device validation should check the cadence and
wakeup cost at low target rates and during display refresh changes.

## KTX upload lifetime tests

The caller owns the KTX bundle. `destroy()` immediately deletes it and its data;
calling it while queued creation or an upload still uses the data is invalid.
Texture creation returns before buffer release is guaranteed. Keep the bundle
alive until the upload-release callback arrives, then destroy it explicitly.
Created textures have their own lifetime and must be destroyed separately.

Skybox and IBL loaders keep setup and buffer-release Futures separate. Setup
errors reach the public Future; bundle cleanup waits for buffer release even
when setup fails. Successful loads do not add a GPU-completion wait. Removal
and disposal flush pending work and wait for bundle cleanup, as before.

Native partial-submission failure handling is a separate change. This PR does
not guarantee release notification if Filament fails during submission.
Run the Dart integration tests from `thermion_dart/`:

```sh
THERMION_UPLOAD_LIFETIME_FIXTURE=/tmp/thermion-scheduling/libupload_lifetime_fixture.dylib \
  dart test --concurrency=1 test/ktx_upload_lifetime_test.dart test/skybox_tests.dart
```

The fixture is built by the CMake commands above. On Linux use
`libupload_lifetime_fixture.so`; on Windows use `Release/upload_lifetime_fixture.dll`
and set the variable using your shell's syntax. The tests require a working GPU
backend (Metal on macOS). They gate the worker to verify release is still pending,
exercise cubemap/mipmapped/2D uploads followed by explicit bundle destruction,
and check public skybox/IBL failure delivery. Dart's native build hook builds
Thermion and obtains Filament.

## Web command processing and shutdown

Web drawing still runs on animation-frame callbacks. Commands wake the render
worker independently, so an upload does not have to wait for another frame.
The worker checks a two-millisecond budget between commands and yields between
batches. Commands remain FIFO, but drawing may happen between batches: several
commands are not an atomic transaction. A long command or backend operation can
exceed that budget. Browsers can still throttle or suspend a whole page/worker;
this removes the dependency on animation frames, not browser scheduling limits.

Render-manager attachment, detachment, and destruction run on the worker.
Await `RenderManager.destroy()` before destroying its animation managers,
renderer, or engine. The app handles this ordering during `destroy()`.
Manager destruction means deletion has finished, not that the worker has exited.
After engine cleanup, `RenderThread_destroy` releases the registry's ownership
and asks the web worker to drain and delete itself. Native destruction joins
synchronously. Do not use the worker handle after requesting destruction.

Web completions are posted asynchronously through a module-lifetime proxy queue.
They remain deliverable after their worker exits, without Dart polling. A view
name is copied for callback delivery because a later queued rename/destruction
may otherwise invalidate its storage. These changes do not introduce an error
transport, change buffer ownership, or change the no-exceptions build settings.

The native `worker_queue` test above checks packaged results, FIFO ordering,
worker affinity, nested completion work, and 25 drain/join cycles.

### Commands with animation frames disabled

The standalone fixture uses the production worker queue and a stub RenderManager.
It checks 25 shutdown cycles, FIFO ordering, yielding, and callbacks delivered
after worker exit. It deliberately keeps the browser busy during shutdown to
check that the worker can finish without synchronous browser callbacks.
Use an activated Emscripten SDK and the web Filament headers installed by `make wasm`:

```sh
mkdir -p /tmp/thermion-web-dispatch
em++ -O1 -g -std=c++17 -pthread -fno-exceptions \
  -sASSERTIONS=2 -sPTHREAD_POOL_SIZE=2 -sMALLOC=mimalloc \
  -sINITIAL_MEMORY=134217728 -sOFFSCREENCANVAS_SUPPORT=1 \
  -sALLOW_BLOCKING_ON_MAIN_THREAD=0 \
  --pre-js thermion_dart/native/test/rendering/disable_worker_frames.js \
  -I thermion_dart/native/include -I thermion_dart/native/web/lib/release/include \
  thermion_dart/native/test/rendering/web_dispatch_test.cpp \
  thermion_dart/native/src/rendering/RenderThread.cpp \
  -o /tmp/thermion-web-dispatch/test.js
dart run thermion_dart/native/test/rendering/run_web_dispatch_test.dart /tmp/thermion-web-dispatch
```

The runner serves COOP/COEP headers and launches headless Chrome. An optional
second argument selects the Chrome executable; the default is its macOS path.

The full-module fixture checks generated Dart bindings, pointer/void/string
callbacks, KTX upload and buffer release with animation frames disabled, public
skybox/IBL loading, and four engine lifecycles. Missing resources fail through
Dart's resource loader; it does not test recovery from a native panic.

```sh
emcmake cmake -S thermion_dart/native/web -B /tmp/thermion-web-api \
  -DCMAKE_BUILD_TYPE=Release \
  "-DCMAKE_EXE_LINKER_FLAGS=--pre-js $PWD/thermion_dart/native/test/rendering/disable_worker_frames.js"
cmake --build /tmp/thermion-web-api -j 4
cp thermion_dart/native/test/rendering/web_api_test.html /tmp/thermion-web-api/build/out/index.html
cp examples/assets/materials_studio_ibl.ktx /tmp/thermion-web-api/build/out/texture.ktx
cp examples/assets/default_env_skybox.ktx /tmp/thermion-web-api/build/out/skybox.ktx
cd thermion_dart
dart compile js native/test/rendering/web_api_test.dart -o /tmp/thermion-web-api/build/out/test.js
dart run native/test/rendering/run_web_dispatch_test.dart /tmp/thermion-web-api/build/out
```

### Teardown while drawing

The drawing-enabled fixture creates two real engines and 32×32 views. It checks
that both draw, one can pause/resume independently, and destroying one leaves the
other drawing. It waits for both workers to exit. Frame histories establish
progress, not physical presentation intervals or a particular FPS limit.
Its native helpers are opt-in test sources, excluded from normal builds.
Run from the repository root, using a separate build directory:

```sh
emcmake cmake -S thermion_dart/native/web -B /tmp/thermion-web-frames \
  -DCMAKE_BUILD_TYPE=Release \
  "-DEXTERNAL_PROJECTS=$PWD/thermion_dart/native/test/rendering/web_frame_fixture.cmake"
cmake --build /tmp/thermion-web-frames -j 4
cp thermion_dart/native/test/rendering/web_frame_test.html /tmp/thermion-web-frames/build/out/index.html
cd thermion_dart
dart compile js native/test/rendering/web_frame_test.dart -o /tmp/thermion-web-frames/build/out/test.js
dart run native/test/rendering/run_web_dispatch_test.dart /tmp/thermion-web-frames/build/out
```

These manual tests cover headless Chrome. They do not establish behavior under
full browser suspension, mobile browser policies, or other browser engines.
