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
 * GetPlatform() returns nullptr so Filament auto-creates a default PlatformEGL.
 */
class LinuxOpenGLContext {
public:
    // When provided, eglDisplay is borrowed from Flutter and is never
    // terminated by this context.
    explicit LinuxOpenGLContext(void* eglDisplay = nullptr);
    ~LinuxOpenGLContext();

    int64_t CreateRenderingSurface(uint32_t width, uint32_t height);
    void DestroyRenderingSurface(int64_t surfaceId);

    uint32_t GetGLTextureId(int64_t surfaceId);
    SurfaceExportInfo GetSurfaceExportInfo(int64_t surfaceId);

    void* GetSharedContext();   // Returns our EGLContext for Filament sharing
    void* GetPlatform();        // Returns nullptr (Filament creates default PlatformEGL)

private:
    class Impl;
    std::unique_ptr<Impl> pImpl;
};

} // namespace thermion::opengl::linux_platform
