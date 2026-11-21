# Thermion Effects Lab

A standalone Flutter showcase for desktop and mobile. **Storm Observatory**
combines aurora, a distant tornado, silk and woven banners, rain-streaked glass,
an iridescent relic, and shell fur in one lit scene.

The renderer and scene are shared with the native headless runner and Dart web
gallery. The Flutter app owns the window, input, clock, lifecycle, and controls;
the scene controller has no Flutter or browser dependency.

## Run

From this directory:

```sh
flutter pub get
flutter run -d macos --profile
```

Use `-d windows`, `-d linux`, or a connected Android/iOS device ID on a host with
the corresponding Flutter toolchain. macOS/Metal is validated; the other
platform runners are scaffolded but have not been built or tested here. iOS
device signing needs your own development team. Native dependencies must be
available for the target platform, as with the other Thermion examples.

`assets` is a relative symlink to `examples/assets`, matching the other example
apps. On Windows, enable Git symlink checkout support (Developer Mode), or
replace the link with a local copy of that directory. Only the assets explicitly
listed in `pubspec.yaml` are bundled.

After editing materials, rebuild them **from the repository root** with
`make materials`. The material compiler must match the runtime's version (75
for the libraries used here). `FILAMENT_PATH` can select the directory holding
`matc`. No FFI bindings changed for this showcase.

## Explore

- Drag to orbit; scroll or pinch to zoom. Camera buttons frame individual
  subjects, and the camera tour follows a repeatable orbit.
- Toggle effect groups to remove their renderables and animation work.
- Change wind, rain, and quality. Pause motion to inspect a fixed simulation
  time while retaining camera control.
- Narrow windows and phones put the controls in a drawer.

| Preset | Linear resolution | Aurora samples | Storm samples | Fur shells | Shadows |
| --- | ---: | ---: | ---: | ---: | --- |
| Low | 65% | 24 | 16 | 8 | Off |
| Balanced | 85% | 48 | 32 | 16 | On |
| High | 100% | 96 | 56 | 28 | On |

Resolution scales relative to the Flutter surface's physical pixel size. Fur
layers span the full length at every quality level. Quality changes reuse the
existing geometry and material instances. Disabled groups remain allocated so
they can be enabled without rebuilding the scene.

## Measure

See the [M2 Pro / Metal sample report](docs/performance.md) for measured costs,
verification results, and outstanding validation limits.

Run a **profile or release** build. The HUD shows render-request cadence,
the 95th-percentile interval, and the time spent updating effects and camera.
It does not measure GPU timestamps or frames presented by the compositor.
The render loop is capped at 60 fps.

**Record 10-second tour** warms up for two seconds, then follows the same route
and simulation time for every recording. Controls lock during the recording.
**Copy JSON report** includes the settings, viewport, build mode, sample count,
mean, median, p95, and maximum. Resizing or backgrounding cancels the recording;
long frame stalls are retained in the samples. A short recording is a comparison
tool, not a sustained mobile thermal test.

For a fixed-resolution, uncapped native comparison, use the headless runner:

```sh
cd ../../dart/headless_runner
dart run bin/benchmark_showcase.dart --backend=metal --width=960 --height=640 \
  --frames=300 --warmup=120 --ablate --capture --verify
```

Choose `--backend=default`, `vulkan`, or `opengl` where supported.
`--ablate` measures each effect disabled in turn and a sequential uniform-update
reference. `--capture` saves each case as a PNG. `--verify` checks finite pixels,
animation, frozen time, reversible toggles, quality changes, disabled animation,
and equivalent images from the two update paths. A failed check exits nonzero.

Timing includes scene updates, native submission, and GPU completion through
`renderSingleFrame` / `flushAndWait`. Pixel readback and PNG encoding happen
outside the measured section. This intentionally serializes CPU and GPU work:
the results are **wall-clock frame costs**, not isolated GPU timings or expected
interactive FPS. All CLI quality levels use the same framebuffer size; the
Flutter resolution scaling is excluded. Keep other GPU work stopped when
comparing runs. Results go to `output/showcase_performance.json` by default.

## Development

```sh
flutter analyze
flutter test
flutter build macos --profile
```

The shared scene is in
[`game_effects_showcase.dart`](../../dart/examples_lib/lib/src/game_effects_showcase.dart).
Headless still: `dart run bin/run_example.dart game_effects_showcase 1200 800`.
Web gallery entry: `?example=showcase`.

The tornado uses its existing bounded ray-march material and is staged beyond
the courtyard. It does not clip its march against arbitrary scene depth, so
free-camera intersections with architecture can expose that limitation.
This scene selects representative effects; the standalone demos retain the
other material variants and the specialized fog/light-shaft scene.
