# Darwin IOSurface leak (per-`CVMetalTextureCache` allocation) — root cause

## Symptom

Repeated mount/unmount of a Thermion view on macOS leaked ~one screen-sized
IOSurface per cycle (`phys_footprint` grew ~1.7 MB per 768×576 cycle), even
though the wrapped `MTLTexture`/`CVPixelBuffer` objects were correctly released.

## Root cause

`MetalTextureWrapper.allocate()` created a **fresh `CVMetalTextureCache` per
texture** via `CVMetalTextureCacheCreate`, then called
`CVMetalTextureCacheCreateTextureFromImage` on it.

`CVMetalTextureCache` caches the `CVPixelBuffer`→`MTLTexture` mappings it
produces, and **releasing the cache object does not synchronously free the
IOSurfaces those mappings pin.** So every `MetalTextureWrapper` allocated a new
cache, and when that cache (and its wrapper) was released on teardown, the
IOSurface backing the last `CVMetalTextureCacheCreateTextureFromImage` call was
left stranded — roughly one IOSurface per texture allocation.

## Fix

Use **one process-wide `CVMetalTextureCache`**, created lazily and keyed off the
system default device, instead of one per `MetalTextureWrapper`. Reusing a
single long-lived cache and flushing it on teardown (with
`kCVMetalTextureCacheMaximumTextureAgeKey: 0`) lets the cache evict and return
aged buffer→texture mappings (and their IOSurfaces).

`MetalTextureWrapper.flushCache()` now flushes that shared cache.

## Verification

A standalone macOS Flutter app (no Thermion dependency) mirrors the exact
`copyPixelBuffer` +1 contract and the full `CVPixelBuffer` → `CVMetalTextureCache`
→ `CVMetalTexture` → `MTLTexture` stack. Cycling register → render → unregister:

| Mode | phys_footprint drift / cycle |
|---|---|
| plain CVPixelBuffer | flat |
| CV+Metal stack, **fresh cache per texture** | ~1 IOSurface (leak) |
| CV+Metal stack, **shared cache + flush** | flat |

The shared-cache mode is flat; the per-texture-cache mode reproduces the leak.

In Thermion, the mount/unmount regression test does NOT assert that
`phys_footprint` stays flat across sessions. Even with the leak fixed, repeated
mount/unmount shows `phys_footprint` rising then plateauing: the darwin texture
teardown is correct (create/destroy of the descriptor, Flutter adapter, and
Filament render target are all balanced), but GPU memory is reclaimed
asynchronously and Metal returns freed texture memory to its own pool rather
than to the OS immediately. That is bounded allocator churn — it plateaus, it
does not keep growing — not a leak.

Distinguishing the two in the test: a genuine per-session leak grows LINEARLY
(~one surface every session, no deceleration); bounded churn decelerates toward
a plateau well under one surface per session. The test therefore asserts that
the steady-state (trailing-sessions) average `phys_footprint` growth stays
below one BGRA surface per session. The original per-`CVMetalTextureCache` leak
(~one surface/session) fails that; the shared-cache fix's churn plateau passes
it with margin.

## Notes

- The leak is in CoreVideo/Metal's `CVMetalTextureCache` lifecycle, not in
  Flutter's external-texture path and not in Filament's texture import (Filament
  takes ownership of the imported `MTLTexture` via a balanced `CFBridgingRelease`
  and releases it on texture destroy).
- `CVMetalTextureCacheCreateTextureFromImage` is not documented as safe for
  concurrent use on a single cache; Thermion allocates and tears down textures on
  its serialized texture-mutation path, satisfying that requirement. See the
  thread-safety comment in `MetalTextureWrapper.swift`.
- No texture pool is required to fix this. The pool used on an earlier branch
  only masked the async reclamation by reusing one texture; the correct, minimal
  fix is the shared `CVMetalTextureCache`.
