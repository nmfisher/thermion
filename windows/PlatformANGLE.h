#ifndef _POLYVOX_FILAMENT_PLATFORM_ANGLE_H
#define _POLYVOX_FILAMENT_PLATFORM_ANGLE_H

#include <d3d.h>
#include <d3d11.h>

#include <EGL/egl.h>
#include <EGL/eglext.h>


#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#include <GLES3/gl31.h>

#include "backend/DriverEnums.h"
#include "backend/platforms/OpenGLPlatform.h"
#include "backend/Platform.h"

#define FILAMENT_USE_EXTERNAL_GLES3

#include "gl_headers.h"

namespace filament::backend {

/**
 * A concrete implementation of OpenGLPlatform that supports EGL with a headless swapchain and external D3D texture support.
 */
class PlatformANGLE : public OpenGLPlatform {
public:
    PlatformANGLE(HANDLE d3dTextureHandle, uint32_t width, uint32_t height) noexcept;

    Driver* createDriver(void* sharedContext,
            const Platform::DriverConfig& driverConfig) noexcept override;

    Platform::SwapChain* createSwapChain(void* nativewindow, uint64_t flags) noexcept override;

    Platform::SwapChain* createSwapChain(uint32_t width, uint32_t height, uint64_t flags)  noexcept override;

    GLuint glTextureId = 0;
    EGLSurface mCurrentDrawSurface = EGL_NO_SURFACE;
    EGLSurface mCurrentReadSurface = EGL_NO_SURFACE;
    EGLDisplay mEGLDisplay = EGL_NO_DISPLAY;
    EGLContext mEGLContext = EGL_NO_CONTEXT;
    EGLConfig mEGLConfig = EGL_NO_CONFIG_KHR;
private:
    /**
     * This returns zero. This method can be overridden to return something more useful.
     * @return zero
     */
    int getOSVersion() const noexcept override;

    // --------------------------------------------------------------------------------------------
    // OpenGLPlatform Interface

    void terminate() noexcept override;

    bool isSRGBSwapChainSupported() const noexcept override;
    void destroySwapChain(SwapChain* swapChain) noexcept override;
    void makeCurrent(SwapChain* drawSwapChain, SwapChain* readSwapChain) noexcept override;
    void commit(SwapChain* swapChain) noexcept override;

    bool canCreateFence() noexcept override;
    Fence* createFence() noexcept override;
    void destroyFence(Fence* fence) noexcept override;
    FenceStatus waitFence(Fence* fence, uint64_t timeout) noexcept override;

    OpenGLPlatform::ExternalTexture* createExternalImageTexture() noexcept override;
    void destroyExternalImage(ExternalTexture* texture) noexcept override;
    bool setExternalImage(void* externalImage, ExternalTexture* texture) noexcept override;

    /**
     * Logs glGetError() to slog.e
     * @param name a string giving some context on the error. Typically __func__.
     */
    static void logEglError(const char* name) noexcept;

    /**
     * Calls glGetError() to clear the current error flags. logs a warning to log.w if
     * an error was pending.
     */
    static void clearGlError() noexcept;

    /**
     * Always use this instead of eglMakeCurrent().
     */
    EGLBoolean makeCurrent(EGLSurface drawSurface, EGLSurface readSurface) noexcept;

    // TODO: this should probably use getters instead.
    
    EGLSurface mEGLDummySurface = EGL_NO_SURFACE;
    
    HANDLE mD3DTextureHandle = nullptr;
    uint32_t mWidth = 0;
    uint32_t mHeight = 0;

    // supported extensions detected at runtime
    struct {
        struct {
            bool OES_EGL_image_external_essl3 = false;
        } gl;
        struct {
            bool KHR_no_config_context = false;
            bool KHR_gl_colorspace = false;
        } egl;
    } ext;

private:
    void initializeGlExtensions() noexcept;
    EGLConfig findSwapChainConfig(uint64_t flags) const;

};

} // namespace filament

#endif // _POLYVOX_FILAMENT_PLATFORM_ANGLE_H
