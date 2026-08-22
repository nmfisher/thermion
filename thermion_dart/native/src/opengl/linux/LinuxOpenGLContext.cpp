#include "opengl/linux/LinuxOpenGLContext.h"
#include "opengl/linux/LinuxOpenGLTexture.h"

#include <condition_variable>
#include <deque>
#include <functional>
#include <future>
#include <iostream>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>
#include <unordered_map>

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

class ScopedEglThreadState {
public:
    ScopedEglThreadState()
        : _display(eglGetCurrentDisplay()),
          _context(eglGetCurrentContext()),
          _draw(eglGetCurrentSurface(EGL_DRAW)),
          _read(eglGetCurrentSurface(EGL_READ)),
          _api(eglQueryAPI()) {
        if (_context != EGL_NO_CONTEXT && _display != EGL_NO_DISPLAY) {
            eglMakeCurrent(
                _display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        }
    }

    ~ScopedEglThreadState() {
        EGLDisplay currentDisplay = eglGetCurrentDisplay();
        if (currentDisplay != EGL_NO_DISPLAY) {
            eglMakeCurrent(currentDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE,
                           EGL_NO_CONTEXT);
        }
        eglBindAPI(_api);
        if (_context != EGL_NO_CONTEXT && _display != EGL_NO_DISPLAY) {
            eglMakeCurrent(_display, _draw, _read, _context);
        }
    }

    ScopedEglThreadState(const ScopedEglThreadState&) = delete;
    ScopedEglThreadState& operator=(const ScopedEglThreadState&) = delete;

private:
    EGLDisplay _display;
    EGLContext _context;
    EGLSurface _draw;
    EGLSurface _read;
    EGLenum _api;
};

static std::string ResolveDrmDevicePath(EGLDisplay display) {
    if (display != EGL_NO_DISPLAY) {
        auto queryDisplayAttrib =
            reinterpret_cast<PFNEGLQUERYDISPLAYATTRIBEXTPROC>(
                eglGetProcAddress("eglQueryDisplayAttribEXT"));
        auto queryDeviceString =
            reinterpret_cast<PFNEGLQUERYDEVICESTRINGEXTPROC>(
                eglGetProcAddress("eglQueryDeviceStringEXT"));
        EGLAttrib deviceAttribute = 0;
        if (queryDisplayAttrib && queryDeviceString &&
            queryDisplayAttrib(
                display, EGL_DEVICE_EXT, &deviceAttribute)) {
            auto device = reinterpret_cast<EGLDeviceEXT>(deviceAttribute);
            const char* path = queryDeviceString(
                device, EGL_DRM_RENDER_NODE_FILE_EXT);
            if (!path || path[0] == '\0') {
                path = queryDeviceString(device, EGL_DRM_DEVICE_FILE_EXT);
            }
            if (path && path[0] != '\0') {
                return path;
            }
        }
    }

    // Retain the historic default for non-Flutter/headless EGL stacks that do
    // not expose EGL_EXT_device_query.
    return "/dev/dri/renderD128";
}

class LinuxOpenGLContext::Impl {
public:
    ~Impl() {
        // The desktop producer context never becomes current on Flutter's
        // platform or raster threads. Keep destruction on an isolated EGL
        // thread for the same reason as initialization and texture creation.
        if (_eglThread.joinable()) {
            RunOnEglThread([this]() {
                _surfaces.clear();
            });
        }

        if (_eglThread.joinable()) {
            RunOnEglThread([this]() {
                if (_platform) {
                    ThermionPlatformEGLHeadless_Destroy(_platform);
                    _platform = nullptr;
                }
                if (_context != EGL_NO_CONTEXT &&
                    _display != EGL_NO_DISPLAY) {
                    eglBindAPI(EGL_OPENGL_API);
                    eglMakeCurrent(
                        _display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                        EGL_NO_CONTEXT);
                    if (_producerSurface != EGL_NO_SURFACE) {
                        eglDestroySurface(_display, _producerSurface);
                        _producerSurface = EGL_NO_SURFACE;
                    }
                    eglDestroyContext(_display, _context);
                    _context = EGL_NO_CONTEXT;
                }
                if (_ownsDisplay && _display != EGL_NO_DISPLAY) {
                    eglTerminate(_display);
                }
                _display = EGL_NO_DISPLAY;
            });
            StopEglThread();
        }

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

        // Step 1: Open the render node backing Flutter's EGLDisplay. Hardcoding
        // renderD128 can select a different GPU on multi-GPU systems, making
        // the exported DMA-BUF impossible for Flutter to import.
        const std::string drmDevicePath = ResolveDrmDevicePath(
            static_cast<EGLDisplay>(borrowedDisplay));
        _drmFd = open(drmDevicePath.c_str(), O_RDWR);
        if (_drmFd < 0) {
            _lastError = "Failed to open " + drmDevicePath;
            std::cerr << "[ThermionGL:Context] " << _lastError << std::endl;
            return;
        }
        std::cerr << "[ThermionGL:Context] DRM device=" << drmDevicePath
                  << " fd=" << _drmFd << std::endl;

        // Step 2: Create GBM device
        _gbmDevice = gbm_create_device(_drmFd);
        if (!_gbmDevice) {
            _lastError = "Failed to create GBM device";
            LOG_ERROR("Failed to create GBM device");
            close(_drmFd);
            _drmFd = -1;
            return;
        }
        std::cerr << "[ThermionGL:Context] GBM device created OK" << std::endl;

        // Step 3: Reuse Flutter's initialized display when available. NVIDIA's
        // EGL implementation can corrupt the concurrently rendering Flutter
        // context if another platform display is initialized in-process.
        _display = static_cast<EGLDisplay>(borrowedDisplay);
        if (_display != EGL_NO_DISPLAY) {
            _ownsDisplay = false;
        } else {
            // Non-Flutter fallback: obtain a display tied to the GBM device.
            PFNEGLGETPLATFORMDISPLAYEXTPROC eglGetPlatformDisplayEXT =
                (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress(
                    "eglGetPlatformDisplayEXT");
            if (eglGetPlatformDisplayEXT) {
                _display = eglGetPlatformDisplayEXT(
                    EGL_PLATFORM_GBM_KHR, _gbmDevice, nullptr);
            }
            if (_display == EGL_NO_DISPLAY) {
                std::cerr
                    << "[ThermionGL:Context] GBM platform display failed, "
                       "trying default"
                    << std::endl;
                _display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
            }
            if (_display == EGL_NO_DISPLAY) {
                _lastError = "Failed to obtain an EGLDisplay";
                LOG_ERROR("Failed to get EGL display");
                return;
            }
            _ownsDisplay = true;
        }

        // Initialize desktop EGL on an isolated thread. Flutter's platform
        // thread can retain GTK/GDK EGL state, and NVIDIA returns
        // EGL_BAD_ACCESS when a second client API is activated there.
        StartEglThread();
        RunOnEglThread([this]() {
            EGLint major = 0;
            EGLint minor = 0;
            if (!eglInitialize(_display, &major, &minor)) {
                _lastError = _ownsDisplay
                    ? "Failed to initialize EGLDisplay"
                    : "Failed to initialize Flutter's captured EGLDisplay";
                LOG_ERROR("Failed to initialize EGL display");
                _display = EGL_NO_DISPLAY;
                return;
            }
            std::cerr << "[ThermionGL:Context] Using "
                      << (_ownsDisplay ? "GBM" : "Flutter")
                      << " EGL display=" << _display << " (" << major << "."
                      << minor << ")" << std::endl;

            // Step 4: Choose EGL config
            // Must bind EGL_OPENGL_API (not ES) to match Filament's
            // PlatformEGLHeadless which uses full OpenGL 4.1 on Linux desktop.
            ScopedEglThreadState eglThreadState;
            if (!eglBindAPI(EGL_OPENGL_API)) {
                _lastError = "Failed to bind desktop OpenGL";
                LOG_ERROR("Failed to bind desktop OpenGL");
                return;
            }

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
            if (!eglChooseConfig(
                    _display, configAttribs, &config, 1, &numConfigs) ||
                numConfigs == 0) {
                _lastError = "Failed to choose a desktop OpenGL EGLConfig";
                LOG_ERROR("Failed to choose EGL config");
                return;
            }

            // Step 5: Create EGL context (OpenGL 4.1 to match Filament's
            // PlatformEGLHeadless).
            EGLint contextAttribs[] = {
                EGL_CONTEXT_MAJOR_VERSION, 4,
                EGL_CONTEXT_MINOR_VERSION, 1,
                EGL_NONE
            };

            _context = eglCreateContext(
                _display, config, EGL_NO_CONTEXT, contextAttribs);
            if (_context == EGL_NO_CONTEXT) {
                _lastError = "Failed to create desktop OpenGL 4.1 EGLContext";
                EGLint err = eglGetError();
                std::cerr
                    << "[ThermionGL:Context] Failed to create EGL context, "
                       "error: 0x"
                    << std::hex << err << std::dec << std::endl;
                return;
            }

            EGLint surfacelessError = EGL_SUCCESS;
            if (!eglMakeCurrent(
                    _display, EGL_NO_SURFACE, EGL_NO_SURFACE, _context)) {
                surfacelessError = eglGetError();
                // Some drivers require a pbuffer surface.
                EGLint pbufferAttribs[] = {
                    EGL_WIDTH, 1,
                    EGL_HEIGHT, 1,
                    EGL_NONE
                };
                _producerSurface =
                    eglCreatePbufferSurface(_display, config, pbufferAttribs);
                if (_producerSurface == EGL_NO_SURFACE) {
                    EGLint pbufferError = eglGetError();
                    std::ostringstream message;
                    message
                        << "Failed to create desktop OpenGL producer pbuffer "
                        << "(surfaceless error 0x" << std::hex
                        << surfacelessError << ", pbuffer error 0x"
                        << pbufferError << ")";
                    _lastError = message.str();
                    LOG_ERROR("Failed to create EGL producer pbuffer");
                    eglDestroyContext(_display, _context);
                    _context = EGL_NO_CONTEXT;
                    return;
                }
                if (!eglMakeCurrent(
                        _display, _producerSurface, _producerSurface,
                        _context)) {
                    EGLint pbufferCurrentError = eglGetError();
                    std::ostringstream message;
                    message
                        << "Failed to make desktop OpenGL producer context "
                           "current (surfaceless error 0x"
                        << std::hex << surfacelessError
                        << ", pbuffer error 0x" << pbufferCurrentError << ")";
                    _lastError = message.str();
                    LOG_ERROR("Failed to make EGL context current");
                    eglDestroySurface(_display, _producerSurface);
                    _producerSurface = EGL_NO_SURFACE;
                    eglDestroyContext(_display, _context);
                    _context = EGL_NO_CONTEXT;
                    return;
                }
            }

            std::cerr << "[ThermionGL:Context] EGL context created OK"
                      << std::endl;
        });
    }

    bool IsValid() const {
        return _display != EGL_NO_DISPLAY &&
               _context != EGL_NO_CONTEXT &&
               _gbmDevice != nullptr;
    }

    const char* GetLastError() const {
        return _lastError.c_str();
    }

    int64_t CreateRenderingSurface(uint32_t width, uint32_t height) {
        std::unique_ptr<LinuxOpenGLTexture> texture;
        RunOnEglThread([&]() {
            texture = LinuxOpenGLTexture::create(
                _display, _context, _producerSurface, _gbmDevice, width,
                height);
        });
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
        RunOnEglThread([this, surfaceId]() {
            _surfaces.erase(surfaceId);
        });
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
        RunOnEglThread([this]() {
            if (!_platform) {
                _platform = ThermionPlatformEGLHeadless_Create(_display);
            }
        });
        return _platform;
    }

private:
    void StartEglThread() {
        _eglThread = std::thread([this]() {
            while (true) {
                std::function<void()> task;
                {
                    std::unique_lock<std::mutex> lock(_taskMutex);
                    _taskReady.wait(lock, [this]() {
                        return _stopEglThread || !_tasks.empty();
                    });
                    if (_stopEglThread && _tasks.empty()) {
                        break;
                    }
                    task = std::move(_tasks.front());
                    _tasks.pop_front();
                }
                task();
            }
            eglReleaseThread();
        });
    }

    void RunOnEglThread(std::function<void()> task) {
        auto completed = std::make_shared<std::promise<void>>();
        auto result = completed->get_future();
        {
            std::lock_guard<std::mutex> lock(_taskMutex);
            _tasks.emplace_back(
                [task = std::move(task), completed = std::move(completed)]() {
                    try {
                        task();
                        completed->set_value();
                    } catch (...) {
                        completed->set_exception(std::current_exception());
                    }
                });
        }
        _taskReady.notify_one();
        result.get();
    }

    void StopEglThread() {
        {
            std::lock_guard<std::mutex> lock(_taskMutex);
            _stopEglThread = true;
        }
        _taskReady.notify_one();
        _eglThread.join();
    }

    EGLDisplay _display = EGL_NO_DISPLAY;
    EGLContext _context = EGL_NO_CONTEXT;
    EGLSurface _producerSurface = EGL_NO_SURFACE;
    bool _ownsDisplay = false;
    std::string _lastError;
    struct gbm_device* _gbmDevice = nullptr;
    int _drmFd = -1;
    ThermionPlatformEGLHeadlessHandle _platform = nullptr;
    std::thread _eglThread;
    std::mutex _taskMutex;
    std::condition_variable _taskReady;
    std::deque<std::function<void()>> _tasks;
    bool _stopEglThread = false;

    std::unordered_map<int64_t, std::unique_ptr<LinuxOpenGLTexture>> _surfaces;
    int64_t _nextSurfaceId = 1;
};

// Public API delegates to Impl

LinuxOpenGLContext::LinuxOpenGLContext(void* eglDisplay)
    : pImpl(std::make_unique<LinuxOpenGLContext::Impl>(eglDisplay)) {}

LinuxOpenGLContext::~LinuxOpenGLContext() = default;

bool LinuxOpenGLContext::IsValid() const {
    return pImpl->IsValid();
}

const char* LinuxOpenGLContext::GetLastError() const {
    return pImpl->GetLastError();
}

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
