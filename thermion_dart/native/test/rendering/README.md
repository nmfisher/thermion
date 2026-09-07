# Scheduling regressions

Run these commands from the repository root. Set `FILAMENT_INCLUDE_DIR` to the
headers for the installed native Filament distribution.

```sh
cmake -S thermion_dart/native/test/rendering -B /tmp/thermion-scheduling \
  -DFILAMENT_INCLUDE_DIR="$FILAMENT_INCLUDE_DIR"
cmake --build /tmp/thermion-scheduling
ctest --test-dir /tmp/thermion-scheduling --output-on-failure
```

This covers fractional refresh-rate cadence, timer changes and prompt stop.

The RenderThread worker-queue and task-error tests, plus the standalone browser
fixtures for web dispatch and shutdown lifetimes, land with the RenderThread
rework in #301.

These tests do not measure physical display presentation intervals or perceived
animation smoothness.
