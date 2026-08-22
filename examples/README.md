# Thermion Examples

This repository contains example Dart and Flutter projects for the Thermion rendering toolkit.

## flutter_zero

[`flutter_zero/`](flutter_zero/) — a "Flutter Zero" app: a plain Dart process with no Flutter engine, using raw SDL3 for windowing/input and `thermion_dart` directly for rendering. Demonstrates native-surface acquisition (CAMetalLayer on macOS, X11 on Linux) and port-based `FrameScheduler` frame pacing. See [flutter_zero/README.md](flutter_zero/README.md).