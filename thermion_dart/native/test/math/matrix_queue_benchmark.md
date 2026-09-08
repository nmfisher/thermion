# Matrix task queue workload

The buffer and native matrix queued setters use `RenderThread::addDetachedTask`.
Their completion is already delivered to Dart through the existing request-ID
callback, so they do not need a `packaged_task`, an unused C++ future, or the
shared pointer used by `addTask`. The native path captures the borrowed matrix
pointer. The ordinary path snapshots a real `mat4` at submission and passes that
snapshot directly to Filament when executed.

Snapshot semantics, FIFO queue insertion and completion callbacks are preserved,
including callbacks for entities without a transform component. Native owner
retention and pending-use guards remain on the Dart side. Filament's instance
lookup and transform setter are `noexcept`; no throwing application work is added
to these detached task bodies. Other task APIs and the legacy struct setter are
unchanged. A snapshot task can still allocate for its `std::function` capture,
and Dart still creates a future/completion record for each submission.

## Reproduce

From `thermion_dart`, on a machine with a working native graphics backend:

```sh
dart run test/matrix_queue_benchmark.dart detached /tmp/matrix-queue.json
```

For a baseline, copy the same benchmark file into a checkout of
`8003403ca2851dd61d98ec46dd926da67ec653e0` (PR #305 before the queue changes) and run
it with label `packaged`. Labels only annotate output; they do not select an
implementation. The native build hook compiles the checked-out C++ implementation.

The workload uses 256 and 1,024 independent transform-only entities alongside a
single cube rendered to a 256×256 headless swapchain. Each path gets 30 warmup
cycles and 150 measured cycles; snapshot/native order is deterministically
shuffled each cycle. Each cycle prepares inputs outside timing, queues one
transform per entity, waits for every callback, and then awaits `app.render()`.
Every element of every entity's resulting transform is verified outside timing.
Native owners are preallocated and reused only after completion. All native
resources and the engine are destroyed before the CLI explicitly exits (the
process-wide FFI listener otherwise keeps an idle CLI isolate alive).

The JSON output contains all samples, with columns in milliseconds:

- Submission: the loop issuing all setter calls, including Dart futures and
  native enqueue work; the render thread can execute concurrently.
- Completion: time from that loop's start until all setter futures complete.
- CPU render cycle: time from that loop's start through `app.render()` completion.

## Recorded comparison

Apple M2 Pro, Metal, Dart 3.12.1 JIT. Three baseline processes were run before
three modified processes using the same Dart fixture. The tables show medians
of the three per-process percentile values. Per-process summaries are checked
in at [`results/matrix_queue_m2_pro.json`](results/matrix_queue_m2_pro.json).
The runner saves raw samples in the caller-selected output file.

| Transforms | Path | Submission p50 before → after (ms) | Submission p95 before → after (ms) |
| ---: | --- | ---: | ---: |
| 256 | Snapshot | 0.205 → 0.138 | 0.305 → 0.250 |
| 256 | Native | 0.212 → 0.157 | 0.314 → 0.248 |
| 1,024 | Snapshot | 0.638 → 0.414 | 1.019 → 0.766 |
| 1,024 | Native | 0.661 → 0.499 | 1.034 → 0.889 |

| Transforms | Path | CPU cycle p50 before → after (ms) | CPU cycle p95 before → after (ms) |
| ---: | --- | ---: | ---: |
| 256 | Snapshot | 1.390 → 1.421 | 1.664 → 1.627 |
| 256 | Native | 1.389 → 1.411 | 1.763 → 1.609 |
| 1,024 | Snapshot | 6.532 → 6.602 | 8.052 → 7.474 |
| 1,024 | Native | 6.600 → 6.495 | 7.883 → 7.721 |

Submission medians fell by about 35% for snapshots and 24% for native matrices at
1,024 entities. Full-cycle medians were roughly unchanged. Tail results vary
between processes; no claim of smoother rendering follows from these runs.

This is an unpaced headless workload, not an on-screen frame scheduler test.
Render completion is not a GPU fence or presentation timestamp, and a render
request can be skipped by Filament's frame admission. The scene has minimal GPU
load; the updated entities are not renderables and have no hierarchy. No native
AOT, mobile, browser timing, allocation profiling, or statistical significance
analysis is included. The source removes unused future machinery and explicit
matrix reconstruction; it does not establish exact runtime allocation/copy counts.

Native Metal and full-module Chrome regressions pass after the change, covering
snapshots, repeated writes in FIFO order, missing components, overlapping uses,
disposal rejection, and callback completion. Flutter analysis passes for the
library and benchmark/regression fixtures.
