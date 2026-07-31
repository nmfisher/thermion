# quickstart

A Flutter project demonstrating how to use the Thermion rendering toolkit to load a 3D model, skybox and set the camera position.

This example mounts **multiple** `ViewerWidget`s at once, arranged in a grid.
The footer's primary button embeds a batch stepper (`−` / `+`) that sets how
many viewers to mount at a time; tapping the button body mounts that many
cells in a single frame (each cell owns an independent `ThermionViewer`).
Clicking it again removes that many, so the control doubles as a toggle for
the concurrent mount/dispose stress path. Use the **×** on a cell to remove
it individually. On web, each viewer runs its own engine and canvas, and the
batch is capped by `WebOptions.maxViewers`.

> Note: the grid is rebuilt from a fresh list on every add/remove (see
> `_MyHomePageState`). Mutating the list in place will leave new cells latent
> until a layout pass (e.g. a window resize) forces the `GridView` to
> re-inflate — always assign a new list in `setState`.

## Driving via MCP

This example is set up to be driven from an AI code harness through the
[Dart/Flutter MCP server](https://docs.flutter.dev/ai/mcp-server). See that
page for how to set up and activate the MCP server in your harness (e.g.
Claude Code).

Two things make it drivable:

1. `flutter_driver` is a `dev_dependency` (dev-only; not part of the runtime).
2. `main()` gates `enableFlutterDriverExtension()` behind a compile-time flag:

   ```dart
   if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
     enableFlutterDriverExtension();
   }
   ```

Run it with the flag enabled:

```sh
flutter run -d macos --dart-define=ENABLE_FLUTTER_DRIVER=true
```

The harness can then discover the app via the Dart Tooling Daemon
(`dtd` → `connect`) and drive it (`flutter_driver_command`, `widget_inspector`).

Known limitations on desktop (macOS) when driving this particular app:

- Foreground the window before driving — the native frame scheduler is
  suspended while the app is hidden, so nothing pumps until it's on screen.
- `tap`/gesture commands tend to hang, because the live render loop keeps
  transient callbacks perpetually pending. `screenshot` and `widget_inspector`
  work; for interactions, drive state from app code rather than synthesised
  taps.
- `flutter_driver` screenshots do not capture the native Filament texture
  (the cube renders blank). For real pixels, use an OS-level screenshot.
