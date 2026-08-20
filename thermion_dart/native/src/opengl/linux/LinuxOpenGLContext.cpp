#include "opengl/linux/LinuxOpenGLContext.h"
#include "opengl/linux/LinuxOpenGLTexture.h"

#include <iostream>
#include <unordered_map>
#include <memory>

#include <fcntl.h>
#include <unistd.h>
#include <xf86drm.h>
#include <gbm.h>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>

#include "opengl/linux/ThermionPlatformEGLHeadlessAPI.h"
#include "Log.hpp"

namespace thermion::opengl::linux_platform {

class LinuxOpenGLContext::Impl {
public:
    ~Impl() {
        _surfaces.clear();

        if (_platform) {
            ThermionPlatformEGLHeadless_Destroy(_platform);
            _platform = nullptr;
        }

        if (_context != EGL_NO_CONTEXT && _display != EGL_NO_DISPLAY) {
            eglMakeCurrent(_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
            eglDestroyContext(_display, _context);
            _context = EGL_NO_CONTEXT;
        }

        if (_ownsDisplay && _display != EGL_NO_DISPLAY) {
            eglTerminate(_display);
        }
        _display = EGL_NO_DISPLAY;

        if (_gbmDevice) {
            gbm_device_destroy(_gbmDevice);
            _gbmDevice = nullptr;
        }

        if (_drmFd >= 0) {
            close(_drmFd);
            _drmFd = -1;
        }
    }

    explicit Impl(void* borrowedDisplay) {
        std::cerr << "[ThermionGL:Context] Initializing EGL/GBM..." << std::endl;

        // Step 1: Open DRM render node
        _drmFd = open("/dev/dri/renderD128", O_RDWR);
        if (_drmFd < 0) {
            LOG_ERROR("Failed to open /dev/dri/renderD128");
            return;
        }
        std::cerr << "[ThermionGL:Context] DRM fd=" << _drmFd << std::endl;

        // Step 2: Create GBM device
        _gbmDevice = gbm_create_device(_drmFd);
        if (!_gbmDevice) {
            LOG_ERROR("Failed to create GBM device");
            close(_drmFd);
            _drmFd = -1;
            return;
        }
        std::cerr << "[ThermionGL:Context] GBM device created OK" << std::endl;

        // Step 3: Get EGL display from the GBM device.
        // Using eglGetPlatformDisplay(EGL_PLATFORM_GBM_KHR, ...) ties the
        // display to the GPU that owns the render node. On NVIDIA systems
        // this selects NVIDIA's EGL instead of Mesa's software fallback.
        _display = static_cast<EGLDisplay>(borrowedDisplay);
        if (_display == EGL_NO_DISPLAY) {
            _ownsDisplay = true;
            PFNEGLGETPLATFORMDISPLAYEXTPROC eglGetPlatformDisplayEXT =
                (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
            if (eglGetPlatformDisplayEXT) {
                _display = eglGetPlatformDisplayEXT(EGL_PLATFORM_GBM_KHR,
                        _gbmDevice, nullptr);
            }
            if (_display == EGL_NO_DISPLAY) {
                // Fallback to default display
                std::cerr << "[ThermionGL:Context] GBM platform display failed, "
                          << "trying default" << std::endl;
                _display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
            }
        } else {
            std::cerr << "[ThermionGL:Context] Reusing Flutter EGLDisplay"
                      << std::endl;
        }
        if (_display == EGL_NO_DISPLAY) {
            LOG_ERROR("Failed to get EGL display");
            return;
        }
        {
            EGLint major, minor;
            if (!eglInitialize(_display, &major, &minor)) {
                LOG_ERROR("Failed to initialize EGL display");
                _display = EGL_NO_DISPLAY;
                return;
            }
            std::cerr << "[ThermionGL:Context] EGL initialized: "
                      << major << "." << minor << std::endl;
        }

        // Step 4: Choose EGL config
        // Must bind EGL_OPENGL_API (not ES) to match Filament's PlatformEGLHeadless
        // which uses full OpenGL 4.1 on Linux desktop.
        eglBindAPI(EGL_OPENGL_API);

        EGLint configAttribs[] = {
            EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
            EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
            EGL_RED_SIZE, 8,
            EGL_GREEN_SIZE, 8,
            EGL_BLUE_SIZE, 8,
            EGL_ALPHA_SIZE, 8,
            EGL_NONE
        };

        EGLConfig config;
        EGLint numConfigs;
        if (!eglChooseConfig(_display, configAttribs, &config, 1, &numConfigs) || numConfigs == 0) {
            LOG_ERROR("Failed to choose EGL config");
            return;
        }

        // Step 5: Create EGL context (OpenGL 4.1 to match Filament's PlatformEGLHeadless)
        EGLint contextAttribs[] = {
            EGL_CONTEXT_MAJOR_VERSION, 4,
            EGL_CONTEXT_MINOR_VERSION, 1,
            EGL_NONE
        };

        _context = eglCreateContext(_display, config, EGL_NO_CONTEXT, contextAttribs);
        if (_context == EGL_NO_CONTEXT) {
            EGLint err = eglGetError();
            std::cerr << "[ThermionGL:Context] Failed to create EGL context, error: 0x"
                      << std::hex << err << std::dec << std::endl;
            return;
        }

        // Verify the context works by briefly making it current, then restore
        // whatever context was active (likely Flutter/GDK's).
        EGLDisplay prevDisplay = eglGetCurrentDisplay();
        EGLContext prevContext = eglGetCurrentContext();
        EGLSurface prevDraw = eglGetCurrentSurface(EGL_DRAW);
        EGLSurface prevRead = eglGetCurrentSurface(EGL_READ);

        if (!eglMakeCurrent(_display, EGL_NO_SURFACE, EGL_NO_SURFACE, _context)) {
            // Some drivers require a pbuffer surface
            EGLint pbufferAttribs[] = {
                EGL_WIDTH, 1,
                EGL_HEIGHT, 1,
                EGL_NONE
            };
            EGLSurface pbuffer = eglCreatePbufferSurface(_display, config, pbufferAttribs);
            if (pbuffer != EGL_NO_SURFACE) {
                eglMakeCurrent(_display, pbuffer, pbuffer, _context);
            }
        }

        std::cerr << "[ThermionGL:Context] EGL context created OK" << std::endl;

        // Restore the previous context so we don't clobber Flutter/GDK's state
        if (prevContext != EGL_NO_CONTEXT && prevDisplay != EGL_NO_DISPLAY) {
            eglMakeCurrent(prevDisplay, prevDraw, prevRead, prevContext);
        } else {
            eglMakeCurrent(_display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        }
    }

    int64_t CreateRenderingSurface(uint32_t width, uint32_t height) {
        auto texture = LinuxOpenGLTexture::create(_display, _context, _gbmDevice, width, height);
        if (!texture) {
            LOG_ERROR("Failed to create OpenGL rendering surface");
            return -1;
        }

        int64_t surfaceId = _nextSurfaceId++;
        std::cerr << "[ThermionGL:Context] Surface " << surfaceId
                  << ": created " << width << "x" << height
                  << " glTextureId=" << texture->GetGLTextureId()
                  << std::endl;

        _surfaces[surfaceId] = std::move(texture);
        return surfaceId;
    }

    void DestroyRenderingSurface(int64_t surfaceId) {
        _surfaces.erase(surfaceId);
    }

    uint32_t GetGLTextureId(int64_t surfaceId) {
        auto it = _surfaces.find(surfaceId);
        return it != _surfaces.end() ? it->second->GetGLTextureId() : 0;
    }

    SurfaceExportInfo GetSurfaceExportInfo(int64_t surfaceId) {
        auto it = _surfaces.find(surfaceId);
        if (it == _surfaces.end()) {
            return {-1, 0, 0, 0, 0, 0, 0};
        }
        auto& s = it->second;
        return {
            s->GetDmaBufFd(),
            s->GetStride(),
            s->GetOffset(),
            s->GetDrmFormat(),
            s->GetDrmModifier(),
            s->GetWidth(),
            s->GetHeight()
        };
    }

    void* GetSharedContext() {
        return _context;
    }

    void* GetPlatform() {
        if (!_platform) {
            _platform = ThermionPlatformEGLHeadless_Create(_display);
        }
        return _platform;
    }

private:
    EGLDisplay _display = EGL_NO_DISPLAY;
    bool _ownsDisplay = false;
    EGLContext _context = EGL_NO_CONTEXT;
    struct gbm_device* _gbmDevice = nullptr;
    int _drmFd = -1;
    ThermionPlatformEGLHeadlessHandle _platform = nullptr;

    std::unordered_map<int64_t, std::unique_ptr<LinuxOpenGLTexture>> _surfaces;
    int64_t _nextSurfaceId = 1;
};

// Public API delegates to Impl

LinuxOpenGLContext::LinuxOpenGLContext(void* eglDisplay)
    : pImpl(std::make_unique<LinuxOpenGLContext::Impl>(eglDisplay)) {}

LinuxOpenGLContext::~LinuxOpenGLContext() = default;

int64_t LinuxOpenGLContext::CreateRenderingSurface(uint32_t width, uint32_t height) {
    return pImpl->CreateRenderingSurface(width, height);
}

void LinuxOpenGLContext::DestroyRenderingSurface(int64_t surfaceId) {
    pImpl->DestroyRenderingSurface(surfaceId);
}

uint32_t LinuxOpenGLContext::GetGLTextureId(int64_t surfaceId) {
    return pImpl->GetGLTextureId(surfaceId);
}

SurfaceExportInfo LinuxOpenGLContext::GetSurfaceExportInfo(int64_t surfaceId) {
    return pImpl->GetSurfaceExportInfo(surfaceId);
}

void* LinuxOpenGLContext::GetSharedContext() {
    return pImpl->GetSharedContext();
}

void* LinuxOpenGLContext::GetPlatform() {
    return pImpl->GetPlatform();
}

} // namespace thermion::opengl::linux_platform
