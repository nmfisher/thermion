# PR318 callback benchmarks

These are manual benchmarks. They do not add a workflow or disable error
handling in release builds.

The recorded results compare `6b0511732` with `87b9d280a`. They predate the
subsequent callback and KTX upload lifetime fixes and do not measure the final
PR implementation. Use the same procedure to compare later revisions.

Benchmark implementations, this report, and raw results live in
`test/benchmarks/`. The two small launchers in `bin/` are required because
`dart build cli` only accepts entry points in that directory.

## Reproduce

Use the same benchmark sources and dependency lockfile in two checkouts: the
PR's base (`6b0511732`) and the reviewed PR (`87b9d280a`). Run from each
checkout's `thermion_dart` directory. Dart 3.12.1 was used for the recorded run.

```sh
dart pub get
dart build cli -t bin/task_error_benchmark.dart -o /tmp/thermion-bench-VERSION
dart build cli -t bin/task_error_frame_benchmark.dart -o /tmp/thermion-frame-bench-VERSION
```

Replace VERSION with `base` or `pr`. `dart build cli` creates an AOT executable
and bundles its native library; `dart compile exe` alone does not bundle this
package's native assets. The native build hook defaults to release mode; verify
`-O3` in `.dart_tool/thermion_dart/log/build.log` and leave tracing disabled.

After both builds finish, run each pair sequentially, reversing their order on
alternate pairs. Do not build or run other benchmarks at the same time.

```sh
/usr/bin/time -l /tmp/thermion-bench-base/bundle/bin/task_error_benchmark 65536
/usr/bin/time -l /tmp/thermion-bench-pr/bundle/bin/task_error_benchmark 65536
/usr/bin/time -l /tmp/thermion-frame-bench-base/bundle/bin/task_error_frame_benchmark 3
/usr/bin/time -l /tmp/thermion-frame-bench-pr/bundle/bin/task_error_frame_benchmark 3
```

The supplied programs use Metal and require GPU access. `/usr/bin/time -l` is
the macOS command used to record process CPU time and peak resident memory.
The last stdout line is machine-readable JSON. The base retains an idle Dart
listener, so both programs explicitly exit after native shutdown.

## Method

- Hardware/software: Apple M2 Pro, macOS 26.6.2, Apple clang 21.0.0, Dart 3.12.1
  AOT, Filament 1.75.0 release libraries. Both checkouts used identical lockfiles
  and benchmark sources. Native tracing was off.
- Callback runs: eight pairs; 2,048 warm-up requests and 65,536 measured requests
  per scenario/concurrency setting. Five operations, each with one or 32 requests
  in flight. Concurrent requests run in bounded batches of 32.
- Each callback sample includes Dart dispatch, native queueing/work where
  applicable, listener delivery, and Future completion. Per-request timing and
  sample collection are enabled equally in both versions. Throughput includes
  this measurement overhead and batch coordination.
- Immediate callbacks bypass the native worker. Image-width queries and parent
  updates use wrappers converted from packaged tasks to detached tasks by the
  PR. Transform updates and empty frame submissions already used detached tasks
  on the base. Empty frames have no attached views or GPU rendering work.
- Headless scene: six pairs; one unlit cube at 512x512, post-processing disabled. Dart
  timers pace submissions at 60/120 Hz. Each case warms up for one second and
  measures three seconds. The update-heavy case submits 100 transforms to 100
  separate entities in one concurrent batch before each frame. Those entities
  have transform components but are not additional renderables.
- Frame samples measure the updates plus `app.render()` completion, excluding
  the pacing wait. This is CPU submission latency, not GPU completion or physical
  presentation time. The harness flushes the engine after measurements and
  releases its material before destroying the engine.

## Callback results

Median of the eight per-run averages, in microseconds per operation. Lower is
better. With 32 requests, this is elapsed batch time divided by request count,
not the latency experienced by each individual request.

| Operation | In flight | Base µs/op | PR µs/op | Change |
|---|---:|---:|---:|---:|
| Immediate void callback | 1 | 1.00 | 1.42 | +42.3% |
| Image width query | 1 | 10.18 | 10.92 | +7.2% |
| Parent update | 1 | 9.59 | 9.98 | +4.0% |
| Transform update | 1 | 9.44 | 10.11 | +7.0% |
| Empty frame submission | 1 | 9.73 | 10.27 | +5.6% |
| Immediate void callback | 32 | 0.86 | 1.41 | +64.2% |
| Image width query | 32 | 2.42 | 2.71 | +12.0% |
| Parent update | 32 | 1.95 | 1.68 | -13.8% |
| Transform update | 32 | 1.78 | 2.14 | +20.4% |
| Empty frame submission | 32 | 1.81 | 1.76 | -2.7% |

The native sequential operations add approximately 0.4–0.7 µs/op when comparing
these medians. The immediate callback isolates a clear cost in the Dart/FFI
completion machinery. Removing packaged tasks offsets that cost for concurrent
parent updates. The small apparent concurrent empty-frame improvement is within
run-to-run variation and should not be treated as a demonstrated speedup.

Median process CPU time for the full callback workload (655,360 measured requests
plus warm-up/setup/teardown) rose from 3.81 to 4.09 seconds, approximately 7.2%.
Median peak RSS was 74.56 versus 74.61 MiB. RSS does not measure allocation rate
or garbage-collection frequency; neither was profiled here.

Raw results, including per-run p50/p95/p99 latencies, executable hashes, and
process resource statistics: [callback JSON](pr318-macos-arm64-micro.json).

## Headless frame results

Median of six per-run percentiles, in microseconds. Each version measured
1,080 frames per 60 Hz case and 2,160 frames per 120 Hz case.

| Target | Updates/frame | Base p50 | PR p50 | Base p95 | PR p95 | Base p99 | PR p99 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 60 Hz | 0 | 82.58 | 82.33 | 147.13 | 130.83 | 354.73 | 298.54 |
| 60 Hz | 100 | 269.15 | 273.35 | 461.42 | 533.21 | 735.13 | 765.67 |
| 120 Hz | 0 | 62.56 | 62.77 | 133.77 | 111.10 | 260.29 | 180.42 |
| 120 Hz | 100 | 237.46 | 216.50 | 532.35 | 446.54 | 1290.48 | 727.06 |

There was no consistent frame-submission regression in this small scene. At
60 Hz with 100 updates, median work rose by about 4 µs and p95 by 72 µs; the
120 Hz case moved in the opposite direction. These mixed results do not prove
an improvement and are compatible with background scheduling noise obscuring
the smaller request-tracking cost.

The scheduled completion deadline was missed 15 times on the base and 9 times
on the PR across 6,480 measured frames per version. This includes timer wake-up
lateness, so it is not a count of dropped display frames. The largest median
p95 submission time was 0.53 ms, compared with an 8.33 ms budget at 120 Hz.

Raw results: [frame JSON](pr318-macos-arm64-frame.json).

## Limits

These are measurements on one desktop Mac, with normal background OS activity.
Repeating and alternating runs reduces drift but does not eliminate scheduling
noise. Tail latency and small differences need particular caution. No mobile
device, Emscripten/browser, battery, GPU-timing, or display-presentation benchmark
was run. No FPS claim can be inferred from the empty-frame microbenchmark.

Error delivery is required behavior in release builds. These measurements can
guide reducing request bookkeeping or batching updates; turning error delivery
off would reintroduce requests that hang when native work throws.
