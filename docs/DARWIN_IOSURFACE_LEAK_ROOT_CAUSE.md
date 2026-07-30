# Root cause: thermion MetalTextureWrapper IOSurface leak (issue #178)

## Status: ROOT CAUSE FOUND AND VERIFIED STANDALONE

The earlier hypothesis ("a bug in Flutter's macOS external-texture path") is
**REFUTED**. A standalone Flutter app with no thermion dependency reproduces the
leak and isolates it to a single CoreVideo call inside thermion's
`MetalTextureWrapper`. Flutter is exonerated.

## The leak, pinned to one call

`MetalTextureWrapper` builds, for every texture:

```
CVPixelBuffer (IOSurface)
  └─ CVMetalTextureCacheCreate              (per device — but recreated per texture)
       └─ CVMetalTextureCacheCreateTextureFromImage   <-- LEAKS ~1 IOSurface/cycle
            └─ CVMetalTextureGetTexture (MTLTexture)
```

Measured in the standalone repro (`/Users/nickfisher/Documents/flutter_texture_leak_repro`,
Flutter 3.44.2, macOS), register→render→unregister→release cycles, phys_footprint:

| Mode | CV/Metal components built | drift/cycle | surfaces/cycle |
|---|---|---|---|
| plain            | CVPixelBuffer only | ~0.26 MB | ~0.15 (noise) |
| metal-cache      | + CVMetalTextureCacheCreate | ~0.28 MB | ~0.17 (no leak) |
| **metal-cvtext** | + **CVMetalTextureCacheCreateTextureFromImage** | **~1.24 MB** | **~0.73 (leaks)** |
| metal-noflush    | + CVMetalTextureGetTexture | ~1.09 MB | ~0.65 |
| metal            | + CVMetalTextureCacheFlush | ~1.82 MB | ~1.08 |

The leak appears **exactly when `CVMetalTextureCacheCreateTextureFromImage` is
called.** Creating the cache alone is as flat as plain.

### Flutter is not the cause (proven)

- `plain` mode (same `copyPixelBuffer` `Unmanaged.passRetained` +1 contract as
  thermion, same register/render/unregister cycle) is flat.
- `track` mode (fresh CVPixelBuffer per `copyPixelBuffer` with a release
  callback): `created == released == 18`, `pinned == 0`. Flutter releases every
  buffer it is handed. The +1 contract is honored.
- Varying `copyPixelBuffer` call count (0/1/4/16 frames) does not scale the
  drift. So it is neither a per-call retain mismatch nor a per-registration pin
  in Flutter.

## Why it leaks

`CVMetalTextureCache` is designed to be a **long-lived, per-MTLDevice** object.
It retains the buffer→texture mappings it creates (that is its purpose: cheap
re-wrapping of the same buffer) and evicts them via `CVMetalTextureCacheFlush`,
gated by `kCVMetalTextureCacheMaximumTextureAgeKey`.

`MetalTextureWrapper` instead creates a **fresh cache + fresh CVMetalTexture per
texture** and drops them on destroy. That defeats the cache and leaks the cached
IOSurface: releasing the `CVMetalTextureCache` object does **not** synchronously
free the IOSurfaces it has cached, so ~one surface per
`CreateTextureFromImage` sticks around.

This is exactly why thermion's texture pool (reuse one `MetalTextureWrapper`)
"much improved" the symptom: the CV/Metal stack is built once and reused, so
`CreateTextureFromImage` is not called every cycle. The pool masks the bug; it
does not fix the underlying per-creation leak.

## Fix direction (verifiable in the standalone repro)

1. **Share one `CVMetalTextureCache` per `MTLDevice`** for the process/instance
   lifetime, instead of one per `MetalTextureWrapper`. This is the documented
   usage.
2. For textures that are torn down, flush the **shared** cache
   (`CVMetalTextureCacheFlush`) so the aged IOSurface mappings are evicted.
   `MaximumTextureAge: 0` + a real flush at teardown, not a per-instance cache.
3. The existing texture pool should stay (it is the right mitigation and also
   cuts latency), but it should not be load-bearing for correctness.

### How to prove the fix in the standalone app

Add a `metal-sharedcache` mode that uses one process-wide `CVMetalTextureCache`
plus an explicit `CVMetalTextureCacheFlush` on unregister. Expected: drift/cycle
drops to the `plain`/`metal-cache` floor (~0.27 MB/cycle, ~0.15 surfaces).
If it does, the fix is confirmed with zero thermion or Flutter dependency.

## Reproducer

Standalone app: `/Users/nickfisher/Documents/flutter_texture_leak_repro`
- `macos/Runner/MainFlutterWindow.swift` — `LeakTexture` (modes: plain / track /
  metal-cache / metal-cvtext / metal-noflush / metal) + `LeakTexturePlugin`
  exposing register/frame/unregister/physFootprint/counters over a method
  channel.
- `integration_test/leak_test.dart` — drives cycles + the component-split probes.

Run:
```bash
cd /Users/nickfisher/Documents/flutter_texture_leak_repro
flutter test integration_test/leak_test.dart -d macos
```
Grep `[repro]` for per-mode `TOTAL drift` and `track mode` counter lines.

Note: the older `docs/FLUTTER_DARWIN_TEXTURE_LEAK_INVESTIGATION.md` handoff doc
predates this finding and its "the bug is in Flutter" premise is wrong; this file
supersedes it.
