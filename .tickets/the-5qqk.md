---
id: the-5qqk
status: open
deps: []
links: []
created: 2026-08-12T11:55:19Z
type: feature
priority: 2
assignee: Nick Fisher
tags: [android, vulkan, rendering]
---
# Add Vulkan rendering backend on Android via Filament

Enable the Vulkan backend on Android. Thermion renders on Android through OpenGL ES only
today; `_resolveBackend()` forbids Vulkan off-Windows/Linux and defaults Android to OpenGL.
Vulkan is desirable for performance, feature parity with the Linux/Windows Vulkan paths, and as
a workaround for device-specific OpenGL driver bugs. OpenGL stays the default; Vulkan is opt-in.

## Context — almost all the hard work is already done

- Filament v1.74.0's shipped Android artifact (`libbackend.a`) already contains the full Vulkan
  backend, incl. `filament::backend::VulkanPlatformAndroid`. Verified by `nm` (1434 Vulkan symbols).
- Filament's `PlatformFactory::create()` returns `new VulkanPlatformAndroid()` when
  `Backend::VULKAN` is requested with a `nullptr` platform — same pattern thermion's Android OpenGL
  path already uses (passes `nullptr`, gets `PlatformEGLAndroid`).
- `VulkanPlatformAndroid::createVkSurfaceKHR(void* nativeWindow, ...)` casts that pointer to
  `ANativeWindow*` and calls `vkCreateAndroidSurfaceKHR`. That is the **same `ANativeWindow*`**
  thermion already hands Filament for OpenGL via `_replaceSwapChain()`.
- `bluevk` is already linked on Android and `dlopen("libvulkan.so")` at runtime via the
  already-linked `"dl"` — so `build.dart` needs **no** new `-lvulkan`.
- The C++ `Engine_create` (`thermion_dart/native/src/c_api/TEngine.cpp:60-86`) already forwards the
  `TBackend` enum straight to `filament::Engine::create()` — no hardcoded backend.

Net: native C++, `scripts/build_android.sh`, Gradle, and the prebuilt artifacts are untouched. The
change is confined to the Dart/Flutter layer.

## Changes

### 1. (required) Allow Vulkan on Android — `_resolveBackend()`
`thermion_flutter/thermion_flutter/lib/src/platform/src/thermion_flutter_plugin_native.dart:107-112`

```dart
case Backend.VULKAN:
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isAndroid) {
    throw UnsupportedError(
      'Vulkan is only supported on Windows, Linux, and Android',
    );
  }
```

Line 131 (`if (Platform.isAndroid || Platform.isLinux) return Backend.OPENGL;`) is **unchanged** —
OpenGL stays the Android default. Vulkan is selected explicitly via
`NativeOptions(backend: Backend.VULKAN)`.

### 2. (recommended, defensive) Don't assume Vulkan == desktop external-image path
`thermion_flutter/thermion_flutter/lib/src/platform/src/native_texture_surface_manager.dart:303-304`

```dart
final useExternalImage =
    Platform.isWindows || (Platform.isLinux && options.backend == Backend.VULKAN);
```

Android never reaches this path today (`AndroidPlatformTextureDescriptor.bindToView()` returns
`managesFilamentSurface = true`, so `_createFilamentResources` is skipped — verified by tracing
`createTextureAndBindToView` → `_textureSurfaces.createAndBind`). This is dead-code hygiene: it
prevents a future refactor from dropping Android Vulkan into the Linux DMA-BUF / Windows D3D
external-image interop path, which doesn't apply to Android's swapchain-direct model.

### No changes required (verified)
- `thermion_dart/hook/build.dart` — `bluevk` + `"dl"` already linked; `libvulkan.so` is dlopened.
- `ThermionFlutterPlugin.kt` — `getDriverPlatform`/`getSharedContext` returning `null` is correct
  (Filament builds `VulkanPlatformAndroid` internally).
- `TEngine.cpp` — already passes backend through.
- `android_platform_texture_descriptor.dart` — swapchain-direct flow
  (`createSwapChain(ANativeWindow)` → Filament `createVkSurfaceKHR`) works unchanged.
- `scripts/build_android.sh` / Gradle / prebuilt artifacts — Vulkan backend already present.

### Optional (out of scope, follow-up ticket if wanted)
Runtime capability check + automatic OpenGL fallback. Vulkan needs API 24+ (practically 26+).
A guard querying `android.os.Build.VERSION.SDK_INT` / `FEATURE_VULKAN_HARDWARE_LEVEL` that warns and
falls back to OpenGL would harden the opt-in path. Defer until the manual opt-in works.

## Verification
Run on a Vulkan-capable device (API 26+, e.g. Pixel). Check
`adb logcat | grep -iE "filament|vulkan"` for the driver-selection line.

1. **Zero-code smoke test first.** Without applying any change, force Vulkan at runtime via
   Filament's system-property override (read at process start):
   ```bash
   adb shell setprop debug.filament.backend 2   # 2 = Backend::VULKAN
   adb shell am force-stop <quickstart package>
   flutter run -d <device>        # from examples/flutter/quickstart
   ```
   If quickstart renders correctly, the native backend, bluevk dlopen, and the swapchain-direct
   Android flow all work end-to-end. This is the highest-signal first step.
2. **Code-path test.** Apply changes 1 + 2. In `examples/flutter/quickstart/lib/main.dart`, pass
   `ThermionFlutterOptions(nativeOptions: NativeOptions(backend: Backend.VULKAN))`. Run and confirm
   rendering matches the OpenGL output. Run `flutter analyze`.
3. **Broader coverage.** Run `examples/flutter/gallery` and `examples/flutter/viewer` with Vulkan to
   exercise multiple viewers, resize, texture loading. Test on at least two OEM devices (esp. Adreno).

## Risks / gotchas
- **Vulkan driver variability.** Min API 24 (7.0), but API 24-25 often ship broken drivers; API 26+
  is the practical floor. Document for opt-in users.
- **Adreno sync bugs.** Qualcomm Adreno drivers have a history of Vulkan sync issues. Filament
  mitigates most internally, but Adreno testing is essential.
- **Swapchain lifecycle.** `_replaceSwapChain()` creates a fresh `VkSurfaceKHR` per SurfaceTexture;
  Filament handles invalidation on surface destroy (same lifecycle it handles for OpenGL today).
- **No external-image interop needed.** Swapchain-direct rendering means no
  `AHardwareBuffer`/`VK_ANDROID_external_memory_android_hardware_buffer` import — avoids an API 26+
  requirement and the bulk of the Linux/Windows-style Vulkan context code.
- If the zero-code test fails to render, likely culprits: device lacks Vulkan
  (`dumpsys SurfaceFlinger | grep -i vulkan`), or a driver bug — fall back to OpenGL to confirm the
  rest of the pipeline is intact.

## Reference paths
- Filament source (local checkout): `/Volumes/T7/projects/filament` —
  `filament/backend/src/PlatformFactory.cpp:130-146`,
  `filament/backend/src/vulkan/platform/VulkanPlatformAndroid.cpp:670-677`,
  `libs/bluevk/src/BlueVKLinuxAndroid.cpp` (dlopen).
- Android artifact: `thermion_dart/.dart_tool/thermion_dart/lib/v1.74.0/android/release/arm64-v8a/libbackend.a`.

