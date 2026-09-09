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

- Ordered task dispatch, exception reporting, nested error scopes, and repeated
  worker shutdown.

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

The gate extraction is reused by the web worker in #301. Task-error propagation
is in #318; forwarding scheduler timestamps through Flutter into rendering is
in #319. Normalizing native scheduler output alone does not replace the existing
Dart wall-clock render timestamp. Browser dispatch/lifetime fixtures land in #301.

## Task error tests

Callback-based C API operations queue ordinary tasks. If their work throws a C++
exception before the success callback, the worker reports the captured request ID
and Dart completes its Future with a `StateError`. C++ callers that use
`std::packaged_task` still receive errors in their C++ futures. Neither path
recovers from crashes or process termination.

Each callback helper represents one native operation with one terminal success
or error callback. Queue that operation synchronously inside the dispatch
closure. Native requests after an `await` need their own callback helper and
scope. A native error completes only its own scope; awaiting a child Future
propagates its error through Dart without invalidating a parent's callback.

Popping a native scope returns the number of tasks it queued. If Dart setup
fails after queueing work, the helper waits for native completion before
rethrowing the setup error. This keeps typed callbacks and caller-owned buffers
alive while native code can still use them. Web keeps pumping completions during
that wait. Async setup is also observed to completion before cleanup. Tasks
retain their existing FIFO order; this does not wait for GPU completion.

The shared native error/void listeners remain allocated for the isolate's lifetime
so late callbacks cannot call a closed trampoline. They keep the isolate alive
only while requests are pending. Applications must stop native workers before
explicitly killing the isolate. Late errors are ignored by request ID, but their
message buffers are still freed.

Run the Dart regressions from `thermion_dart/`:

```sh
dart test test/task_error_registry_test.dart
THERMION_TASK_ERROR_FIXTURE=/tmp/thermion-scheduling/libtask_error_fixture.dylib \
  dart test --concurrency=1 test/native_task_errors_test.dart test/ffi_void_callback_test.dart \
    test/ktx_task_errors_test.dart
```

The CMake build above produces the fixture library. On Linux use
`libtask_error_fixture.so`; on Windows use `Release/task_error_fixture.dll` and
set the environment variable using your shell's syntax. The native integration
test skips when the variable is absent. Dart's native build hook also builds
Thermion and obtains its Filament dependencies for these tests.

The fixture throws inside the production `RenderThread_addTask` path, checks
typed/void error delivery and subsequent worker progress, and tests that a child
process exits naturally after shutdown. Queued callbacks are also checked after
Dart dispatch throws, to verify that callback cleanup waits for native work.
A nested failure must leave a separate upload-release callback pending. The KTX
error test uses a real engine and verifies Filament texture creation failure reports both the
creation error and buffer release before the caller destroys the bundle.
Pure-Dart tests cover polling with sync
and async setup, setup/pump errors, nested scopes, duplicate errors, and listener
keep-alive transitions. These are manual tests; no workflow is added.

For the release-mode callback and headless frame performance comparison, see
the [benchmark report and reproduction instructions](../../../test/benchmarks/README.md).

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
Native C++ exception delivery to Dart is handled separately in #318.

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

## Native KTX upload completion

Thermion submits KTX mip buffers itself so that completion counts buffers that
were actually constructed, including when later submission throws. This replaces
the call to Filament's `Ktx1Reader::createTexture`; it continues to use Filament's
format mapping, texture builder, and upload API. The cost is maintaining the upload
loop here. Fixing completion in Filament's reader and updating the dependency is
an alternative that would avoid this duplication.

The completion record owns no bundle or pixel data. An initial token covers
submission; each constructed pixel buffer adds one token before submission. The
release callback runs after submission ends and every buffer releases its token.
An exception destroys the incomplete texture but leaves release tracking alive
until outstanding buffers finish. There are no smart pointers or per-buffer
allocations for this tracking.

The C++ suite above covers zero buffers, partial submission failure, and a buffer
finishing before later buffers are submitted. The Dart upload suite covers real
2D, cubemap, and mipmapped uploads. Native exception delivery to Dart additionally
requires the task-error change; completion tracking itself does not deliver errors.

## KTX input validation

KTX preflight rejects zero dimensions, mip counts that do not fit the texture
builder's 8-bit argument, empty mip data, and mismatched or noncontiguous cubemap
faces before submitting pixel data. Bundle decoding catches native exceptions
and returns null, which the Dart wrapper reports as a decode error. This is input
validation, separate from upload completion and skybox/IBL cleanup.

With the same GPU and task-error setup above, run:

```sh
THERMION_TASK_ERROR_FIXTURE=/tmp/thermion-scheduling/libtask_error_fixture.dylib \
  dart test --concurrency=1 test/ktx_input_validation_test.dart test/ktx_task_errors_test.dart
```

These regressions cover a truncated header and zero width/height, including
release before caller cleanup. They do not directly exercise the mip-count bound
or malformed in-memory cubemap layout.
