# Matrix buffer API tests

## Buffer API integration

The buffer API passes 16 column-major doubles. Native Dart borrows
`Matrix4.storage` during a leaf FFI call; C++ copies into or out of a `mat4`
without constructing a `double4x4`. Web uses a 128-byte WASM stack buffer and
bulk typed-array copies, with stack restoration before returning. Queued
transform setters snapshot the values before returning, so the caller can
immediately reuse its input. No pointer into Dart storage survives the call.

Public `Camera` and `TransformManager` keep their existing matrix APIs. Their
getters use internal buffer calls and return independent snapshots. Reusable
output methods (`...Into`), shared native methods (`...Native` / `...NativeInto`),
and `NativeMatrix4` are confined to unexported FFI implementation libraries.
The new low-level matrix binding symbols are also hidden from the package's
main export. Tests explicitly import the implementation libraries to exercise
these paths.

The buffer paths keep the existing threading requirements; they do not serialize
synchronous access to Filament or change its internal transform precision.

All native declarations come from ffigen through `make bindings` and live in
`thermion_dart_ffi.g.dart`. Handwritten Dart adapters in `matrix_buffers_native.dart`
check buffer lengths and pass `.address` directly to those generated leaf calls.
No custom generator, handwritten native signatures, or duplicated asset/symbol
annotations are needed. The adapters retain typed-data borrowing for ordinary
`Matrix4` calls; shared `NativeMatrix4` storage is unchanged.

From `thermion_dart`, run the native regressions and optional benchmark:

```sh
dart test test/matrix_buffer_test.dart
dart run test/matrix_buffer_benchmark.dart
flutter analyze lib test/matrix_buffer_checks.dart test/matrix_buffer_test.dart
```

These tests cover offset input/output views, output bounds, missing components,
local/world transforms, independent snapshots, camera matrices, exact double
projection values, and queued submissions that reuse one input matrix. The
engine tests require a working graphics backend.

For the full-module browser test, with Emscripten activated and the Filament
web libraries installed in `native/web/lib/release`:

```sh
emcmake cmake -S native/web -B /tmp/thermion-matrix-web -DCMAKE_BUILD_TYPE=Release
cmake --build /tmp/thermion-matrix-web -j8
dart compile js -O2 native/test/math/matrix_buffers_web.dart \
  -o /tmp/thermion-matrix-web/build/out/matrix_buffers_web.dart.js
cp native/test/math/matrix_buffers_web.html /tmp/thermion-matrix-web/build/out/index.html
dart run native/test/math/run_web_matrix_test.dart /tmp/thermion-matrix-web/build/out
```

The runner starts a local server with COOP/COEP and headless Chrome. Its optional
second argument overrides the Chrome executable (the default is macOS Chrome).

## Internal shared native matrices

`NativeMatrix4` owns a constructed Filament `mat4` and exposes a `Matrix4` view
of its component storage. Native Dart uses an external typed list; web uses a
persistent view into WASM memory. Editing the view changes the same bytes that
C++ reads, and native output getters update the same view. No boundary copy is
needed by the `...Native` methods.

This storage owner lives in `src/filament/src/implementation/native_matrix4.dart`.
It is an internal building block, with explicit lifetime management; it is not
part of the public `Camera` or `TransformManager` contract. The shared-storage
regression fixture demonstrates its use through `FFICamera` and
`FFITransformManager`.

Allocation happens once when creating the owner. `NativeMatrix4.copy(other)`
performs an explicit initial copy; subsequent edits through `.matrix` and native
submissions share that storage. `FFICamera` has corresponding native projection
setters and model/view/projection output getters.

Ownership is explicit: call `dispose()` when all Dart views are finished
(repeated disposal is harmless). Accessing an escaped Matrix4, its storage, or a
derived view after disposal is invalid. The wrapper rejects subsequent API calls
and requests for its view. There is no automatic finalizer that could free the
allocation while an escaped view is still in use; forgetting to dispose leaks
that allocation.

A queued native setter retains shared C++ ownership before returning, so its
Dart owner may be disposed immediately after submission. Do not modify shared
values while a submission is pending. The ordinary `setTransformAsync` still
snapshots its input, including when given a shared matrix view. Use that path when
immediate mutation is required.

Filament continues to store/convert transforms internally and compute getter
results. This eliminates the Dart/C++ boundary copy, not Filament's own state
updates or work needed to produce a matrix.

The shared native regressions run in the same native/browser fixtures above.
They verify Dart writes observed by C++, C++ output observed through an existing
Dart view, camera precision, missing components, disposal checks, queued ownership
after immediate disposal, and the ordinary setter's preserved snapshot semantics.

## Boundary microbenchmark

Example measurements on Apple M2 Pro (native Dart JIT and Chrome/dart2js `-O2`),
in microseconds per operation, median of seven 20,000-call samples after warmup:

| Operation | Native | Browser |
| --- | ---: | ---: |
| Existing struct setter | 0.039 | 0.241 |
| Buffer setter | 0.018 | 0.221 |
| Shared native matrix setter | 0.017 | 0.034 |
| Existing struct getter | 0.095 | 0.585 |
| Buffer getter returning a snapshot | 0.020 | 0.506 |
| Buffer getter reusing output | 0.014 | 0.174 |
| Shared native matrix output getter | 0.033 | 0.026 |

These timings measure one entity's boundary overhead, not frame time, task
queue throughput, or a guarantee of smoother rendering. Browser snapshot
getters showed no clear speedup in this run; callers that reuse output avoid
allocating a new matrix and its backing storage. The buffer paths also remove
the explicit struct packing and intermediate Dart list from the old helpers.
Allocation counts were not profiled, and JIT optimizations can eliminate some
source-level allocations in the old path.

Shared native setters were approximately equal to buffer setters on the native
VM in this run, and the shared native output getter was slower there. The web
path benefited substantially from avoiding the per-call WASM buffer and bulk
copy. Zero boundary copies do not guarantee a faster call on every platform.
