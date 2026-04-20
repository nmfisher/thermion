// Standalone OpenGLPlatform implementation for Linux EGL + desktop GL.
//
// Inherits OpenGLPlatform directly, manages its own EGL state,
// and accepts the GDK EGL display from the Flutter plugin. 

#include <backend/platforms/OpenGLPlatform.h>
#include <backend/DriverEnums.h>

#include <EGL/egl.h>
#include <EGL/eglext.h>

#include <bluegl/BlueGL.h>

#include <algorithm>
#include <cstring>
#include <iostream>
#include <vector>

#include "opengl/linux/ThermionPlatformEGLHeadlessAPI.h"

#ifndef EGL_NO_CONFIG_KHR
#define EGL_NO_CONFIG_KHR ((EGLConfig)0)
#endif

using namespace filament::backend;

namespace thermion {

class ThermionPlatformEGLHeadless final : public OpenGLPlatform {
public:
    explicit ThermionPlatformEGLHeadless(EGLDisplay gdkDisplay)
        : mGdkDisplay(gdkDisplay) {}

    // Platform
    Driver* createDriver(void* sharedContext,
            const Platform::DriverConfig& driverConfig) override;

    // OpenGLPlatform — pure virtuals
    void terminate() noexcept override;
    SwapChain* createSwapChain(void* nativeWindow, uint64_t flags) override;
    SwapChain* createSwapChain(uint32_t width, uint32_t height,
            uint64_t flags) override;
    void destroySwapChain(SwapChain* swapChain) noexcept override;
    bool makeCurrent(ContextType type, SwapChain* drawSwapChain,
            SwapChain* readSwapChain) override;
    void commit(SwapChain* swapChain) noexcept override;

    // Platform — required
    int getOSVersion() const noexcept override { return 0; }

    // OpenGLPlatform — optional overrides
    ContextType getCurrentContextType() const noexcept override {
        return mCurrentContextType;
    }
    bool isExtraContextSupported() const noexcept override;
    void createContext(bool shared) override;
    void releaseContext() noexcept override;
    bool canCreateFence() noexcept override;
    Fence* createFence() noexcept override;
    void destroyFence(Fence* fence) noexcept override;
    FenceStatus waitFence(Fence* fence, uint64_t timeout) noexcept override;

private:
    struct SwapChainImpl : public Platform::SwapChain {
        EGLSurface surface = EGL_NO_SURFACE;
        EGLConfig config = nullptr;
        uint64_t flags = 0;
    };

    EGLConfig findConfig(bool pbuffer) const;

    // State-tracking wrapper — avoids redundant eglMakeCurrent calls and
    // ensures eglBindAPI(EGL_OPENGL_API) on every actual context switch.
    EGLBoolean eglMakeCurrentTracked(EGLContext ctx,
            EGLSurface draw, EGLSurface read);

    EGLDisplay mGdkDisplay;
    EGLDisplay mDisplay = EGL_NO_DISPLAY;
    EGLContext mContext = EGL_NO_CONTEXT;
    EGLConfig mConfig = nullptr;
    EGLSurface mDummySurface = EGL_NO_SURFACE;
    ContextType mCurrentContextType = ContextType::NONE;

    std::vector<EGLint> mContextAttribs;
    std::vector<EGLContext> mAdditionalContexts;

    bool mSurfacelessContext = false;
    bool mNoConfigContext = false;

    PFNEGLCREATESYNCKHRPROC mCreateSync = nullptr;
    PFNEGLDESTROYSYNCKHRPROC mDestroySync = nullptr;
    PFNEGLCLIENTWAITSYNCKHRPROC mClientWaitSync = nullptr;

    // Tracked EGL state (for the optimizing wrapper)
    EGLContext mTrackedCtx = EGL_NO_CONTEXT;
    EGLSurface mTrackedDraw = EGL_NO_SURFACE;
    EGLSurface mTrackedRead = EGL_NO_SURFACE;
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

EGLBoolean ThermionPlatformEGLHeadless::eglMakeCurrentTracked(
        EGLContext ctx, EGLSurface draw, EGLSurface read) {
    if (ctx == mTrackedCtx && draw == mTrackedDraw && read == mTrackedRead) {
        return EGL_TRUE;
    }
    eglBindAPI(EGL_OPENGL_API);
    EGLBoolean ok = eglMakeCurrent(mDisplay, draw, read, ctx);
    if (ok) {
        mTrackedCtx = ctx;
        mTrackedDraw = draw;
        mTrackedRead = read;
    }
    return ok;
}

EGLConfig ThermionPlatformEGLHeadless::findConfig(bool pbuffer) const {
    EGLint attribs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
        EGL_SURFACE_TYPE, pbuffer ? EGL_PBUFFER_BIT : (EGLint)EGL_WINDOW_BIT,
        EGL_RED_SIZE,   8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE,  8,
        EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 24,
        EGL_NONE
    };
    EGLConfig config;
    EGLint count = 0;
    if (!eglChooseConfig(mDisplay, attribs, &config, 1, &count) || count == 0) {
        return EGL_NO_CONFIG_KHR;
    }
    return config;
}

// ---------------------------------------------------------------------------
// createDriver — full EGL initialisation
// ---------------------------------------------------------------------------

Driver* ThermionPlatformEGLHeadless::createDriver(
        void* sharedContext, const Platform::DriverConfig& driverConfig) {

    // Desktop OpenGL API (not ES)
    eglBindAPI(EGL_OPENGL_API);

    // BlueGL: load desktop-GL function pointers for headless rendering
    if (bluegl::bind() != 0) {
        std::cerr << "[ThermionEGLHeadless] bluegl::bind() failed" << std::endl;
        return nullptr;
    }

    mDisplay = mGdkDisplay;

    EGLint major, minor;
    if (!eglInitialize(mDisplay, &major, &minor)) {
        std::cerr << "[ThermionEGLHeadless] eglInitialize failed: 0x"
                  << std::hex << eglGetError() << std::dec << std::endl;
        return nullptr;
    }

    // ---- extension detection ------------------------------------------------
    char const* exts = eglQueryString(mDisplay, EGL_EXTENSIONS);
    if (exts) {
        mNoConfigContext   = strstr(exts, "EGL_KHR_no_config_context") != nullptr;
        mSurfacelessContext = strstr(exts, "EGL_KHR_surfaceless_context") != nullptr;
    }

    // ---- sync function pointers ---------------------------------------------
    mCreateSync     = (PFNEGLCREATESYNCKHRPROC)     eglGetProcAddress("eglCreateSyncKHR");
    mDestroySync    = (PFNEGLDESTROYSYNCKHRPROC)    eglGetProcAddress("eglDestroySyncKHR");
    mClientWaitSync = (PFNEGLCLIENTWAITSYNCKHRPROC) eglGetProcAddress("eglClientWaitSyncKHR");

    // ---- EGL config ---------------------------------------------------------
    // When sharing with the GDK context, query its EGL_CONFIG_ID so that NVIDIA
    // drivers accept the shared context (they reject EGL_NO_CONFIG_KHR).
    EGLConfig eglConfig = EGL_NO_CONFIG_KHR;
    if (sharedContext) {
        EGLint configId = 0;
        if (eglQueryContext(mDisplay, (EGLContext)sharedContext,
                EGL_CONFIG_ID, &configId) && configId != 0) {
            EGLint matchAttribs[] = { EGL_CONFIG_ID, configId, EGL_NONE };
            EGLint numConfigs = 0;
            eglChooseConfig(mDisplay, matchAttribs, &eglConfig, 1, &numConfigs);
            if (numConfigs > 0) {
                mConfig = eglConfig;
            }
        }
    }

    if (eglConfig == EGL_NO_CONFIG_KHR && !mNoConfigContext) {
        eglConfig = findConfig(/*pbuffer=*/true);
        if (eglConfig == EGL_NO_CONFIG_KHR) {
            std::cerr << "[ThermionEGLHeadless] no suitable EGL config" << std::endl;
            return nullptr;
        }
        mConfig = eglConfig;
    }

    // ---- context creation ---------------------------------------------------
    mContextAttribs = {
        EGL_CONTEXT_MAJOR_VERSION, 4,
        EGL_CONTEXT_MINOR_VERSION, 1,
        EGL_NONE
    };

    mContext = eglCreateContext(mDisplay, eglConfig,
            (EGLContext)sharedContext, mContextAttribs.data());
    if (mContext == EGL_NO_CONTEXT) {
        std::cerr << "[ThermionEGLHeadless] eglCreateContext failed: 0x"
                  << std::hex << eglGetError() << std::dec << std::endl;
        return nullptr;
    }

    // ---- surfaceless test ---------------------------------------------------
    if (mSurfacelessContext) {
        if (!eglMakeCurrent(mDisplay,
                EGL_NO_SURFACE, EGL_NO_SURFACE, mContext)) {
            if (eglGetError() == EGL_BAD_MATCH) {
                mSurfacelessContext = false;
            }
        }
    }

    // ---- dummy pbuffer (fallback when surfaceless isn't supported) -----------
    if (!mSurfacelessContext) {
        EGLint pbAttribs[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
        mDummySurface = eglCreatePbufferSurface(mDisplay, mConfig, pbAttribs);
        if (mDummySurface == EGL_NO_SURFACE) {
            std::cerr << "[ThermionEGLHeadless] eglCreatePbufferSurface failed"
                      << std::endl;
            eglDestroyContext(mDisplay, mContext);
            mContext = EGL_NO_CONTEXT;
            return nullptr;
        }
    }

    // ---- make current -------------------------------------------------------
    if (eglMakeCurrentTracked(mContext,
            mDummySurface, mDummySurface) == EGL_FALSE) {
        std::cerr << "[ThermionEGLHeadless] initial eglMakeCurrent failed"
                  << std::endl;
        if (mDummySurface != EGL_NO_SURFACE) {
            eglDestroySurface(mDisplay, mDummySurface);
            mDummySurface = EGL_NO_SURFACE;
        }
        eglDestroyContext(mDisplay, mContext);
        mContext = EGL_NO_CONTEXT;
        return nullptr;
    }

    mCurrentContextType = ContextType::UNPROTECTED;

    return createDefaultDriver(this, sharedContext, driverConfig);
}

// ---------------------------------------------------------------------------
// terminate
// ---------------------------------------------------------------------------

void ThermionPlatformEGLHeadless::terminate() noexcept {
    eglMakeCurrent(mDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);

    if (mDummySurface != EGL_NO_SURFACE) {
        eglDestroySurface(mDisplay, mDummySurface);
        mDummySurface = EGL_NO_SURFACE;
    }

    eglDestroyContext(mDisplay, mContext);
    mContext = EGL_NO_CONTEXT;

    for (auto ctx : mAdditionalContexts) {
        eglDestroyContext(mDisplay, ctx);
    }
    mAdditionalContexts.clear();

    // Do NOT call eglTerminate — the display is owned by GDK.
    eglReleaseThread();
    bluegl::unbind();
}

// ---------------------------------------------------------------------------
// SwapChain
// ---------------------------------------------------------------------------

Platform::SwapChain* ThermionPlatformEGLHeadless::createSwapChain(
        void* nativeWindow, uint64_t flags) {
    EGLConfig config = mNoConfigContext
            ? findConfig(/*pbuffer=*/false) : mConfig;
    if (config == EGL_NO_CONFIG_KHR) {
        return nullptr;
    }

    auto* sc = new SwapChainImpl();
    sc->config = config;
    sc->flags  = flags;
    sc->surface = eglCreateWindowSurface(mDisplay, config,
            (EGLNativeWindowType)nativeWindow, nullptr);
    if (sc->surface == EGL_NO_SURFACE) {
        delete sc;
        return nullptr;
    }
    return sc;
}

Platform::SwapChain* ThermionPlatformEGLHeadless::createSwapChain(
        uint32_t width, uint32_t height, uint64_t flags) {
    EGLConfig config = mNoConfigContext
            ? findConfig(/*pbuffer=*/true) : mConfig;
    if (config == EGL_NO_CONFIG_KHR) {
        config = mConfig;
    }

    EGLint attribs[] = {
        EGL_WIDTH,  (EGLint)width,
        EGL_HEIGHT, (EGLint)height,
        EGL_NONE
    };

    auto* sc = new SwapChainImpl();
    sc->config  = config;
    sc->flags   = flags;
    sc->surface = eglCreatePbufferSurface(mDisplay, config, attribs);
    if (sc->surface == EGL_NO_SURFACE) {
        if (mSurfacelessContext) {
            // EGL configs (e.g. Mesa/llvmpipe on Wayland) may only support
            // window surfaces. Fall back to a surfaceless swapchain — the
            // dummy 1x1 swapchain doesn't need a real surface.
            std::cerr << "[ThermionEGLHeadless] pbuffer failed, using surfaceless"
                      << std::endl;
            return sc;
        }
        delete sc;
        return nullptr;
    }
    return sc;
}

void ThermionPlatformEGLHeadless::destroySwapChain(
        SwapChain* swapChain) noexcept {
    auto* sc = static_cast<SwapChainImpl*>(swapChain);
    if (sc) {
        if (sc->surface != EGL_NO_SURFACE) {
            // Unbind the surface before destroying it.
            eglMakeCurrentTracked(mContext, mDummySurface, mDummySurface);
            eglDestroySurface(mDisplay, sc->surface);
        }
        delete sc;
    }
}

// ---------------------------------------------------------------------------
// Context management
// ---------------------------------------------------------------------------

bool ThermionPlatformEGLHeadless::makeCurrent(
        ContextType type,
        SwapChain* drawSwapChain,
        SwapChain* readSwapChain) {
    auto* dsc = static_cast<SwapChainImpl*>(drawSwapChain);
    auto* rsc = static_cast<SwapChainImpl*>(readSwapChain);
    EGLSurface draw = dsc ? dsc->surface : mDummySurface;
    EGLSurface read = rsc ? rsc->surface : mDummySurface;
    EGLBoolean ok = eglMakeCurrentTracked(mContext, draw, read);
    return ok == EGL_TRUE;
}

void ThermionPlatformEGLHeadless::commit(SwapChain* swapChain) noexcept {
    // Flush GL commands so rendered content is visible from other contexts
    // in the same EGL share group (e.g. Flutter's context reading the texture).
    glFlush();

    // Diagnostic: check what's currently bound and read back a pixel
    static int commitCount = 0;
    commitCount++;
    if (commitCount <= 5 || commitCount % 300 == 0) {
        GLint currentFbo = 0;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &currentFbo);

        // Query the color attachment of the currently bound FBO (if any)
        GLint attachType = 0, attachName = 0;
        if (currentFbo != 0) {
            glGetFramebufferAttachmentParameteriv(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE, &attachType);
            glGetFramebufferAttachmentParameteriv(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME, &attachName);
        }
        TRACE("[Commit] #%d fbo=%d attachType=0x%x attachName=%d\n",
                commitCount, currentFbo, attachType, attachName);

        // If there's a texture attached, try to read a pixel
        if (attachType == GL_TEXTURE && attachName != 0) {
            GLenum fbStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
            if (fbStatus == GL_FRAMEBUFFER_COMPLETE) {
                uint8_t pixel[4] = {0};
                glReadPixels(640, 360, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);
                TRACE("[Commit]   pixel at (640,360): R=%d G=%d B=%d A=%d\n",
                        pixel[0], pixel[1], pixel[2], pixel[3]);
            } else {
                TRACE("[Commit]   FBO status: 0x%x\n", fbStatus);
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Extra (worker-thread) contexts
// ---------------------------------------------------------------------------

bool ThermionPlatformEGLHeadless::isExtraContextSupported() const noexcept {
    return mSurfacelessContext;
}

void ThermionPlatformEGLHeadless::createContext(bool shared) {
    // eglBindAPI is thread-local; worker threads default to ES, not desktop GL.
    eglBindAPI(EGL_OPENGL_API);

    // Always use the same config as the main context.
    // We forced a real config for NVIDIA compatibility, so EGL_NO_CONFIG_KHR
    // would cause EGL_BAD_MATCH here.
    EGLContext ctx = eglCreateContext(mDisplay, mConfig,
            shared ? mContext : EGL_NO_CONTEXT, mContextAttribs.data());
    if (ctx == EGL_NO_CONTEXT) {
        std::cerr << "[ThermionEGLHeadless] createContext failed: 0x"
                  << std::hex << eglGetError() << std::dec << std::endl;
        return;
    }
    eglMakeCurrent(mDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, ctx);
    mAdditionalContexts.push_back(ctx);
}

void ThermionPlatformEGLHeadless::releaseContext() noexcept {
    EGLContext ctx = eglGetCurrentContext();
    eglMakeCurrent(mDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    if (ctx != EGL_NO_CONTEXT) {
        eglDestroyContext(mDisplay, ctx);
    }
    mAdditionalContexts.erase(
            std::remove(mAdditionalContexts.begin(),
                    mAdditionalContexts.end(), ctx),
            mAdditionalContexts.end());
    eglReleaseThread();
}

// ---------------------------------------------------------------------------
// Fences (EGL sync objects for frame pacing)
// ---------------------------------------------------------------------------

bool ThermionPlatformEGLHeadless::canCreateFence() noexcept {
    return mCreateSync != nullptr;
}

Platform::Fence* ThermionPlatformEGLHeadless::createFence() noexcept {
    if (mCreateSync) {
        return reinterpret_cast<Fence*>(
                mCreateSync(mDisplay, EGL_SYNC_FENCE_KHR, nullptr));
    }
    return nullptr;
}

void ThermionPlatformEGLHeadless::destroyFence(Fence* fence) noexcept {
    if (mDestroySync && fence) {
        mDestroySync(mDisplay, reinterpret_cast<EGLSyncKHR>(fence));
    }
}

FenceStatus ThermionPlatformEGLHeadless::waitFence(
        Fence* fence, uint64_t timeout) noexcept {
    if (mClientWaitSync && fence) {
        EGLint status = mClientWaitSync(mDisplay,
                reinterpret_cast<EGLSyncKHR>(fence),
                0, (EGLTimeKHR)timeout);
        if (status == EGL_CONDITION_SATISFIED_KHR) {
            return FenceStatus::CONDITION_SATISFIED;
        }
        if (status == EGL_TIMEOUT_EXPIRED_KHR) {
            return FenceStatus::TIMEOUT_EXPIRED;
        }
    }
    return FenceStatus::ERROR;
}

} // namespace thermion

// ---------------------------------------------------------------------------
// C API
// ---------------------------------------------------------------------------

extern "C" {

ThermionPlatformEGLHeadlessHandle ThermionPlatformEGLHeadless_Create(
        void* eglDisplay) {
    return new thermion::ThermionPlatformEGLHeadless(
            static_cast<EGLDisplay>(eglDisplay));
}

void ThermionPlatformEGLHeadless_Destroy(
        ThermionPlatformEGLHeadlessHandle handle) {
    delete static_cast<thermion::ThermionPlatformEGLHeadless*>(handle);
}

} // extern "C"
