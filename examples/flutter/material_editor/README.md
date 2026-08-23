# material_editor

A Flutter project demonstrating **runtime material compilation and
hot-reload** in Thermion: edit Filament `.mat` source in a text field and see
the change on a live-rendered sphere, without restarting the app.

The top half of the window is a `ViewerWidget` rendering a sphere; the bottom
half is a plain `TextField` holding `.mat` source. Every edit (debounced, or
via the **Apply** button) is compiled to a `.filamat` package *inside the
running engine* and hot-swapped onto the sphere.

## How it works

Two APIs from `thermion_dart` drive the whole loop:

1. **`FilamentApp.compileMaterial(source)`** (runtime compile) — parses and
   compiles `.mat` source through the same `matp` + `filamat` pipeline the
   offline `matc` tool uses, returning the compiled `.filamat` bytes. On
   failure it throws `MaterialCompileException` with the compiler's message,
   which the editor shows inline under the text field.

2. **`FilamentApp.reloadMaterialFromBytes(material, bytes)`** (hot-reload) —
   builds a new `Material` from the compiled bytes, creates a replacement
   `MaterialInstance`, re-points every renderable that used the old instance,
   replays recorded instance state (parameters like `baseTint` below) onto the
   replacement, and destroys the old material. The sphere never leaves the
   scene; only the material under it changes.

Startup (`_onViewerAvailable`) compiles `materials/starter.mat` — a lit
material with `baseTint` / `roughness` / `metallic` parameters — creates an
instance, sets those parameters, and creates the sphere geometry with that
instance. Subsequent compiles go through `reloadMaterialFromBytes`, so the
parameter values set at startup survive every edit: change `shadingModel` to
`unlit`, delete `prepareMaterial`, or introduce a syntax error — the sphere
keeps rendering the last good material while the error is shown inline.

The starter source is a good place to experiment:

- change `material.baseColor = materialParams.baseTint;` to a constant
  `float4(1.0, 0.3, 0.1, 1.0)`;
- add `material.clearCoat = 1.0;` after `prepareMaterial(material);`;
- set `shadingModel : unlit` (and drop the roughness/metallic lines) to see
  flat unshaded color;
- delete a `}` to see the inline error report.

## Platform support

Runtime compilation is linked into **desktop** engine builds only (Linux,
macOS, Windows). On web `compileMaterial` throws `UnsupportedError`, and on
Android/iOS the native engine reports "not supported" via
`MaterialCompileException`. The example handles both: the sphere still
renders with the default material and the status bar explains why.

## Running

```sh
flutter pub get
flutter run -d linux   # or -d macos / -d windows
```

The example targets desktop platforms only (runtime compilation is not
available elsewhere).
