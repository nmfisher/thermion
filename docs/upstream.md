# Upstream Issues

## Filament WebGPU Blitter: blending enabled on non-blendable formats

**Repository:** google/filament
**Status:** Unfiled
**Date:** 2026-06-07

### Summary

The WebGPU `WebGPUBlitter::createRenderPipeline` creates render pipelines with blending enabled unconditionally. When the destination texture format is non-blendable (e.g. `RGBA32Float`), Dawn rejects the pipeline with:

```
VALIDATION Blending is enabled but color format (TextureFormat::RGBA32Float) is not blendable.
 - While validating targets[0] framebuffer output.
 - While validating fragment state.
 - While calling [Device "graphics_device"].CreateRenderPipeline([RenderPipelineDescriptor ""blitLow""]).
```

This invalidates the command buffer, causing any subsequent operations in the same encoder (including `CopyTextureToBuffer` for `readPixels`) to be silently discarded.

### Affected Code

- `filament/backend/src/webgpu/WebGPUBlitter.cpp` — `createRenderPipeline()` constructs `wgpu::ColorTargetState` without disabling blending for non-blendable destination formats.

### Reproduction

1. Create a headless WebGPU swapchain (format: `RGBA8Unorm`).
2. Request `readPixels` with `PixelDataType::FLOAT` (maps to `RGBA32Float`).
3. `conversionNecessary()` detects format mismatch (`RGBA8Unorm` != `RGBA32Float`).
4. Blitter creates an intermediate `RGBA32Float` staging texture and attempts to create a render pipeline with blending enabled against it.
5. Dawn validation rejects the pipeline → command encoder becomes invalid → staging buffer stays empty → pixel buffer is all zeros.

Also reproducible when reading from an `RGBA32Float` render target (e.g. a user-created `TextureFormat.RGBA32F` used as a color attachment), since the blit destination inherits the non-blendable format.

### Suggested Fix

In `WebGPUBlitter::createRenderPipeline()`, check whether the destination format supports blending using `wgpu::TextureFormat::supportsBlend()` (or check `wgpu::TextureFormat` capabilities). When the format is not blendable, set `colorTargetState.blend = nullptr` (no blending) instead of the default blended state.

Alternatively, the readback path in `readTextureToBuffer` could avoid the blit entirely when the only difference is the channel type (e.g., normalized vs. float) by using `CopyTextureToBuffer` directly and handling the type conversion on the CPU side.

### Workaround

Match the pixel data format/type to the source texture format to avoid triggering the conversion blit:
- For headless swapchains (RGBA8Unorm): use `PixelDataFormat::RGBA` + `PixelDataType::UBYTE`.
- Avoid `PixelDataType::FLOAT` when reading from non-float textures.
- Avoid RGBA32Float render targets when readback is needed.
