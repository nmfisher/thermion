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

The gate extraction is reused by the web worker in #301. Forwarding scheduler
timestamps through Flutter into rendering is in #319. Normalizing native scheduler output alone does not replace the existing
Dart wall-clock render timestamp. Browser dispatch/lifetime fixtures land in #301.

## Nonblocking render controls

The optional render-control test holds a plugin update inside a frame until
the caller issues `setPaused()`. Pausing must not wait for the frame to finish:
on web, a frame can itself be waiting for an upload callback on the browser
main thread. The test fails against the old locking implementation and also
checks subsequent pause/resume behavior.

This test runs natively without a GPU context. It compiles the current
`RenderManager` and uses an existing native Thermion library for its Filament
and animation dependencies. Supply that library and matching Filament headers:

```sh
cmake -S thermion_dart/native/test/rendering -B /tmp/thermion-render-controls \
  -DTHERMION_TEST_LIBRARY=/absolute/path/to/libthermion_dart.dylib \
  -DFILAMENT_TEST_INCLUDE_DIR=/absolute/path/to/filament/include
cmake --build /tmp/thermion-render-controls --config Release
ctest --test-dir /tmp/thermion-render-controls -C Release --output-on-failure
```

For browser validation, run quickstart with its matching web module, set the
batch size to four, then repeatedly add, remove, and replace the viewers with
skybox/IBL loading enabled. Verify all four viewers finish loading, and test
pause/resume while uploads are pending. The native tests isolate the mutex
cycle; they do not test browser worker reuse or WASM memory capacity.

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

## Render-manager destruction

Render-manager attachment, detachment and deletion run on its owning worker.
Await `RenderManager.destroy()` before destroying its animation managers,
renderer or engine. `FilamentApp.destroy()` handles this ordering. The manager
remains registered to its worker until deletion, including after a separate
`RenderManager_detachFromJobThread()` call.

This patch uses the existing animation-frame command loop and callback delivery.
Main-thread web builds run the same operations directly on the calling thread.
The callback-delivery and worker-shutdown changes are separate dependent patches.

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

## Web callback delivery

Web worker completions are posted through a module-lifetime proxy queue. Dart
awaits each completion without polling a worker's queue. Main-thread web builds
still call completions directly.

Dart owns string output buffers. `View_getNameJobThread()` takes a `char*` buffer
and its capacity in bytes. It checks the size and copies the name in one queued
job. Its callback reports the required UTF-8 byte count, including the null
terminator. Zero means null; an empty string needs one byte. An undersized buffer
is left unchanged. A null buffer with zero capacity can query the required size.

`readString()` allocates the buffer in native/Wasm heap memory. It waits for
completion, decodes only the returned text bytes and frees the buffer in
`finally`. If more space is needed, it frees that attempt and retries with the
reported capacity. Native code never owns or frees the caller's buffer. Each
request must complete exactly once, after native code has stopped using it.
A dispatch error must occur before native code accepts the buffer or callback.

The source must stay alive and unchanged across retries. `FFIView` orders name
reads and renames. `destroy()` rejects new name operations and waits for accepted
ones, including retries, before deleting the view. A failed read reports its
error to its caller and still allows later reads and destruction to proceed.
Direct C API callers must arrange the same ordering themselves.

The JavaScript tests check output-buffer lifetime, resizing, empty and Unicode
text, null results, invalid UTF-8 and cleanup after dispatch errors. Run from
`thermion_dart/`:

```sh
dart test -p node test/js_pointer_callback_test.dart
```

The native tests check exact and insufficient capacities with guard bytes.
They await a queued rename or deletion before decoding the caller-owned buffer,
so the view's original name is no longer needed when Dart reads the result.
Separate public view tests verify long-name retries finish before rename/deletion,
and that a decode error cannot block destruction. These tests use the existing
native APIs and run through Dart without an extra fixture or environment setup.
CI runs them on Linux, Windows and macOS. Run from `thermion_dart/`:

```sh
dart test test/ffi_string_callback_test.dart
```

The full-module browser fixture checks pointer, void and string callbacks,
public view-name reads, KTX upload/release, skybox/IBL loading and four engine
lifecycles. It uses the shared runner introduced with the manager regression.
Build and prepare it from the repository root with matching web Filament libraries:

```sh
emcmake cmake -S thermion_dart/native/web -B /tmp/thermion-web-callbacks \
  -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/thermion-web-callbacks -j 4
cp thermion_dart/native/test/rendering/web_api_test.html /tmp/thermion-web-callbacks/build/out/index.html
cp examples/assets/materials_studio_ibl.ktx /tmp/thermion-web-callbacks/build/out/texture.ktx
cp examples/assets/default_env_skybox.ktx /tmp/thermion-web-callbacks/build/out/skybox.ktx
cd thermion_dart
dart compile js native/test/rendering/web_api_test.dart -o /tmp/thermion-web-callbacks/build/out/test.js
dart run native/test/rendering/run_web_dispatch_test.dart /tmp/thermion-web-callbacks/build/out
```

Run the same fixture with `-DTHERMION_WEB_MAIN_THREAD=ON` in a separate build
folder to check synchronous callback delivery. Worker command processing still
uses animation frames in this patch; independent wakeups and worker shutdown
remain in #347.
