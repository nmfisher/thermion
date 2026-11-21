# Effects Lab performance baseline

Recorded 2026-09-26 on Apple M2 Pro, Metal, macOS 26.6.2, Dart 3.12.1.
The [complete JSON report](metal-m2-pro.json) includes settings, percentiles,
effect-disable cases, and the image verification results.

```sh
cd examples/dart/headless_runner
dart run bin/benchmark_showcase.dart --backend=metal --width=960 --height=640 \
  --frames=300 --warmup=120 --ablate --capture --verify
```

Each case samples the same 20-second camera route at fixed simulation times,
after 120 warm-up frames. All presets render at **960 × 640** here, so these
numbers exclude the Flutter app's additional resolution scaling.

| Preset | Mean serialized frame | p95 serialized frame |
| --- | ---: | ---: |
| Low | 6.09 ms | 8.55 ms |
| Balanced | 9.31 ms | 12.49 ms |
| High | 10.52 ms | 12.16 ms |

These are one run's wall-clock costs, including scene updates, native
submission, and a wait for GPU completion. They are neither isolated GPU times
nor presented frame rates. Readback and PNG encoding are outside the timed
region. The interactive macOS profile app was also visually checked at its
60 fps render-request cap, with an 816 × 648 Balanced render surface.

The effect-disable cases were noisy: some measured slower than the full scene.
They do not establish a reliable ranking of individual effects. Likewise,
grouping Dart uniform futures showed no clear native advantage over sequential
awaits, and does not combine native calls. Repeat comparisons on an otherwise
idle target device before choosing further optimizations. A longer sustained
run is needed for mobile power and thermal behavior.

The concrete reductions in this pass are adjustable volume samples, fewer fur
shells distributed over the full fur length, lower surface resolution, optional
shadows, no rendering or time updates for disabled groups, and no redundant
time updates while paused. Quality switches reuse the existing resources.
Material parameter-name strings are now freed after synchronous native calls,
eliminating an allocation leak from continuous animation updates.

## Validation

- All 16 native image comparisons passed after the allocation fix: animation,
  fixed time, equivalent update paths, six disable/restore pairs, and the
  all-disabled scene. Restored images had zero mean absolute difference.
- Every quality level produced finite pixels and the expected visible shell
  count; the ten benchmark/capture cases completed.
- Flutter analysis and the clock/statistics tests passed. The macOS profile
  application built and rendered successfully.
- Material rebuilding passed for Metal, Vulkan, and OpenGL. The Dart web
  gallery compiled to WASM; browser runtime validation was not performed.
  This compiler does not support WebGPU material output.
- The broader native unlit/ubershader regression command timed out, then hit
  retained-swapchain errors in later unlit tests. It was stopped without a
  passing result. This remains unresolved and is tracked as ticket `tge-145k`;
  its cause has not been attributed to this change or established as pre-existing.
- Windows, Linux, Android, and iOS runners are provided but remain untested.
