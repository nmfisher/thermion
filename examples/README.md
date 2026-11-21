# Thermion Examples

This repository contains example Dart and Flutter projects for the Thermion rendering toolkit.

## Effects Lab

[`flutter/effects_showcase/`](flutter/effects_showcase/) — a standalone Flutter
app combining weather, sky, cloth, glass, fur, and iridescence in one scene.
Includes camera controls, quality presets, effect toggles, and a repeatable
performance recording. The scene also runs in the native headless runner and
web gallery. See its [README](flutter/effects_showcase/README.md) for platform
status and benchmark commands.

## flutter_zero

[`flutter_zero/`](flutter_zero/) — a "Flutter Zero" app: a plain Dart process with no Flutter engine, using raw SDL3 for windowing/input and `thermion_dart` directly for rendering. Demonstrates native-surface acquisition (CAMetalLayer on macOS, X11 on Linux) and port-based `FrameScheduler` frame pacing. See [flutter_zero/README.md](flutter_zero/README.md).
