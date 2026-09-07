# Matrix buffer API tests

## Buffer API integration

The buffer API passes 16 column-major doubles. Native Dart borrows
`Matrix4.storage` during a leaf FFI call; C++ copies into or out of a `mat4`
without constructing a `double4x4`. Web uses a 128-byte WASM stack buffer and
bulk typed-array copies, with stack restoration before returning. Queued
transform setters snapshot the values before returning, so the caller can
immediately reuse its input. No pointer into Dart storage survives the call.

`TransformManager.getLocalTransformInto(entity, out)` and
`getWorldTransformInto(entity, out)` fill a reusable `Matrix4`. Camera provides
`getModelMatrixInto`, `getViewMatrixInto`, `getProjectionMatrixInto`, and
`getCullingProjectionMatrixInto`. Existing getters still return independent
snapshots. These methods keep the existing threading requirements; the buffer
API does not serialize synchronous access to Filament or change its internal
transform precision.

The private native declarations and `.address` call sites deliberately live in
one Dart library. Using `.address` with an imported generated declaration can
leave its synthetic pointer trampoline unresolved under `package:test`.

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

## Boundary microbenchmark

Example measurements on Apple M2 Pro (native Dart JIT and Chrome/dart2js `-O2`),
in microseconds per operation, median of seven 20,000-call samples after warmup:

| Operation | Native | Browser |
| --- | ---: | ---: |
| Existing struct setter | 0.034 | 0.282 |
| Buffer setter | 0.017 | 0.213 |
| Existing struct getter | 0.082 | 0.515 |
| Buffer getter returning a snapshot | 0.020 | 0.537 |
| Buffer getter reusing output | 0.014 | 0.171 |

These timings measure one entity's boundary overhead, not frame time, task
queue throughput, or a guarantee of smoother rendering. Browser snapshot
getters showed no clear speedup in this run; callers that reuse output avoid
allocating a new matrix and its backing storage. The buffer paths also remove
the explicit struct packing and intermediate Dart list from the old helpers.
Allocation counts were not profiled, and JIT optimizations can eliminate some
source-level allocations in the old path.
