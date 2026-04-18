# Architecture

This document explains Flutter-specific implementation details, mostly about how the rendering surface is constructed, how the Flutter plugin communicates with the Filament renderer and which rendering backends we use. If you are looking to extend the plugin or contribute code upstream, start here.

## Rendering surface

On all platforms except Android, we create Filament with a headless swapchain, then render into a (hardware accelerated) texture that Flutter imports into its own widget hierarchy via a Texture widget. This allows the Filament viewport to be transformed/composed completely within the Flutter hierarchy (i.e. you could rotate/scale/translate the ThermionWidget in Flutter if you wanted, or insert other widgets above/below).

## Linux

Flutter on Linux/Wayland uses EGL/GDK for rendering with Skia. 

Thermion will create an "EGL-compatible" texture that is passed to Flutter for compositing. Both Vulkan and OpenGL backends are available, but patchy driver support means performance characteristics may vary. EGL + OpenGL is the recommended pathway. This will change when Impeller is stable on Linux.

### Vulkan

My current understanding* is that, with the Skia backend, Flutter can register/import a `VkImage` as a texture provided it was created with the following flags:
- `VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT`
- `VK_IMAGE_TILING_DRM_FORMAT_MODIFIER_EXT`
- `VK_FORMAT_R8G8B8A8_UNORM`
- `VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_SAMPLED_BIT`

* may not be 100% correct, if you have any input feel free to correct me.

However, Filament also requires `VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT` for this to be used as a render target. This combination may not be supported by all drivers.

#### Zero-copy (DMA-BUF only) vs Blit 

The preferred pathway is to use a single `VkImage` for Filament rendering and importing into Flutter (i.e. with `VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT`). See `createExportable` in `LinuxVulkanTexture.cpp`.

If this fails, Thermion allocates two `VkImage`:
- the first is passed to Filament as the backing texture for the render target
- the second is imported into Flutter as the imported texture 
- on every frame, we blit from the first to the second.

See `createWithBlit` in `LinuxVulkanTexture.cpp`.

### EGL/OpenGL

The EGL/OpenGL backend has two pathways for context acquisition:

1. **Flutter context sharing** (preferred): When the Flutter render context is available via deferred populate, Thermion shares that EGL context. This uses the same EGL display as Flutter's Skia renderer, avoiding driver mismatches.

2. **DMA-BUF/GBM fallback**: When no Flutter render context is available yet, Thermion creates its own EGL context via a GBM device (`eglGetPlatformDisplayEXT(EGL_PLATFORM_GBM_KHR, ...)`). On NVIDIA systems, this selects NVIDIA's EGL implementation (via egl-wayland) rather than Mesa's software fallback. A `ThermionPlatformEGLHeadless` is provided to Filament's `GetPlatform()` so it uses this NVIDIA-backed display instead of creating its own default `PlatformEGL`.

Context acquisition from the Flutter plugin side is deterministic: if no deferred populate has fired, a GDK GL context is explicitly created and made current before querying EGL state (rather than relying on `eglGetCurrentContext()`, which is non-deterministic since GDK may or may not have its context active on the platform thread).

The previous EGL context is saved and restored after Thermion's initialization to avoid clobbering Flutter/GDK state.

`ThermionPlatformEGLHeadless` also has a surfaceless swapchain fallback for EGL configs that only support window surfaces (e.g. Mesa/llvmpipe on Wayland) — when pbuffer creation fails, it proceeds with a surfaceless swapchain instead.


## macOS

TODO

## iOS

TODO

## Android

TODO

## Web

TODO

## Windows

TODO
