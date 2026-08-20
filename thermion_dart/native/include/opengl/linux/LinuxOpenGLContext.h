#pragma once

#include <cstdint>
#include <memory>

#include "SurfaceExportInfo.h"

namespace thermion::opengl::linux_platform {

/**
 * Manages an EGL display/context, GBM device, and rendering surfaces for the
 * OpenGL backend on Linux. Analogous to LinuxVulkanContext.
 *
 * The EGL context created here is returned via GetSharedContext() so Filament's
 * PlatformEGL can create its own context in the same share group — GL texture
 * IDs are then valid in both contexts.
 *
 * GetPlatform() returns Thermion's EGLHeadless platform bound to the same
 * EGLDisplay as the producer context.
 */
class LinuxOpenGLContext {
public:
    // If eglDisplay is non-null, it is borrowed and must already be
    // initialized. This is the preferred Flutter path: Filament gets a
    // desktop-GL context on Flutter's existing EGLDisplay without starting a
    // second NVIDIA EGL display alongside the raster thread.
    explicit LinuxOpenGLContext(void* eglDisplay = nullptr);
    ~LinuxOpenGLContext();

    bool IsValid() const;
    const char* GetLastError() const;

    int64_t CreateRenderingSurface(uint32_t width, uint32_t height);
    void DestroyRenderingSurface(int64_t surfaceId);

    uint32_t GetGLTextureId(int64_t surfaceId);
    SurfaceExportInfo GetSurfaceExportInfo(int64_t surfaceId);

    void* GetSharedContext();   // Returns our EGLContext for Filament sharing
    void* GetPlatform();        // Returns ThermionPlatformEGLHeadless

private:
    class Impl;
    std::unique_ptr<Impl> pImpl;
};

} // namespace thermion::opengl::linux_platform
