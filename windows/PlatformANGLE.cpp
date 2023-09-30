/*
 * Copyright (C) 2022 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")

#include "PlatformANGLE.h"

#include <Windows.h>
#include <wrl.h>

#include <thread>

#include <string_view>
#include <unordered_set>
#include <iostream>
#include <string.h>

#include <utils/compiler.h>
#include <utils/Log.h>
#include <utils/Panic.h>

using namespace utils;

PROC wglGetProcAddress(LPCSTR name) {
    // PANIC
    return nullptr;
}

namespace filament::backend::GLUtils {
    class unordered_string_set : public std::unordered_set<std::string_view> {
    public:
        bool has(std::string_view str) const noexcept;
    };

    unordered_string_set split(const char* extensions) noexcept;
}

namespace filament {

using namespace backend;

namespace glext {
UTILS_PRIVATE PFNEGLCREATESYNCKHRPROC eglCreateSyncKHR = {};
UTILS_PRIVATE PFNEGLDESTROYSYNCKHRPROC eglDestroySyncKHR = {};
UTILS_PRIVATE PFNEGLCLIENTWAITSYNCKHRPROC eglClientWaitSyncKHR = {};
UTILS_PRIVATE PFNEGLCREATEIMAGEKHRPROC eglCreateImageKHR = {};
UTILS_PRIVATE PFNEGLDESTROYIMAGEKHRPROC eglDestroyImageKHR = {};
}
using namespace glext;


void PlatformANGLE::logEglError(const char* name) noexcept {
    const char* err;
    switch (eglGetError()) {
        case EGL_NOT_INITIALIZED:       err = "EGL_NOT_INITIALIZED";    break;
        case EGL_BAD_ACCESS:            err = "EGL_BAD_ACCESS";         break;
        case EGL_BAD_ALLOC:             err = "EGL_BAD_ALLOC";          break;
        case EGL_BAD_ATTRIBUTE:         err = "EGL_BAD_ATTRIBUTE";      break;
        case EGL_BAD_CONTEXT:           err = "EGL_BAD_CONTEXT";        break;
        case EGL_BAD_CONFIG:            err = "EGL_BAD_CONFIG";         break;
        case EGL_BAD_CURRENT_SURFACE:   err = "EGL_BAD_CURRENT_SURFACE";break;
        case EGL_BAD_DISPLAY:           err = "EGL_BAD_DISPLAY";        break;
        case EGL_BAD_SURFACE:           err = "EGL_BAD_SURFACE";        break;
        case EGL_BAD_MATCH:             err = "EGL_BAD_MATCH";          break;
        case EGL_BAD_PARAMETER:         err = "EGL_BAD_PARAMETER";      break;
        case EGL_BAD_NATIVE_PIXMAP:     err = "EGL_BAD_NATIVE_PIXMAP";  break;
        case EGL_BAD_NATIVE_WINDOW:     err = "EGL_BAD_NATIVE_WINDOW";  break;
        case EGL_CONTEXT_LOST:          err = "EGL_CONTEXT_LOST";       break;
        default:                        err = "unknown";                break;
    }
    slog.e << name << " failed with " << err << io::endl;
}

void PlatformANGLE::clearGlError() noexcept {
    // clear GL error that may have been set by previous calls
    GLenum const error = glGetError();
    if (error != GL_NO_ERROR) {
        slog.w << "Ignoring pending GL error " << io::hex << error << io::endl;
    }
}


int PlatformANGLE::getOSVersion() const noexcept {
    return 0;
}

// ---------------------------------------------------------------------------------------------

PlatformANGLE::PlatformANGLE(
    HANDLE d3dTextureHandle, 
    uint32_t width, 
    uint32_t height
) noexcept : mD3DTextureHandle(d3dTextureHandle), mWidth(width), mHeight(height), OpenGLPlatform() {        

}


backend::Driver* PlatformANGLE::createDriver(void* sharedContext,
        const Platform::DriverConfig& driverConfig) noexcept {

    if (UTILS_UNLIKELY(sharedContext)) {
        slog.e << "Cannot provide shared context with PlatformANGLE" << io::endl;
        return nullptr;
    }

    EGLBoolean bindAPI = eglBindAPI(EGL_OPENGL_ES_API);
    if (UTILS_UNLIKELY(!bindAPI)) {
        slog.e << "eglBindAPI EGL_OPENGL_ES_API failed" << io::endl;
        return nullptr;
    }

    // Copied from the base class and modified slightly. Should be cleaned up/improved later.
    mEGLDisplay = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    assert_invariant(mEGLDisplay != EGL_NO_DISPLAY);

    EGLint major, minor;
    EGLBoolean initialized = false; // = eglInitialize(mEGLDisplay, &major, &minor);

    // if (!initialized) {
      EGLDeviceEXT eglDevice;
      EGLint numDevices;

    if(auto* getPlatformDisplay = reinterpret_cast<PFNEGLGETPLATFORMDISPLAYEXTPROC>(
              eglGetProcAddress("eglGetPlatformDisplayEXT"))) {

        EGLint kD3D11DisplayAttributes[] = {
            EGL_PLATFORM_ANGLE_TYPE_ANGLE,
            EGL_PLATFORM_ANGLE_TYPE_D3D11_ANGLE,
            EGL_PLATFORM_ANGLE_ENABLE_AUTOMATIC_TRIM_ANGLE,
            EGL_TRUE,
            EGL_NONE,
        };
        mEGLDisplay = getPlatformDisplay(EGL_PLATFORM_ANGLE_ANGLE, EGL_DEFAULT_DISPLAY, kD3D11DisplayAttributes);
        initialized = eglInitialize(mEGLDisplay, &major, &minor);
    }

    std::cout << "Got major " << major << " and minor " << minor << std::endl;

    if (UTILS_UNLIKELY(!initialized)) {
        slog.e << "eglInitialize failed" << io::endl;
        return nullptr;
    }

    importGLESExtensionsEntryPoints();

    auto extensions = GLUtils::split(eglQueryString(mEGLDisplay, EGL_EXTENSIONS));

    eglCreateSyncKHR = (PFNEGLCREATESYNCKHRPROC) eglGetProcAddress("eglCreateSyncKHR");
    eglDestroySyncKHR = (PFNEGLDESTROYSYNCKHRPROC) eglGetProcAddress("eglDestroySyncKHR");
    eglClientWaitSyncKHR = (PFNEGLCLIENTWAITSYNCKHRPROC) eglGetProcAddress("eglClientWaitSyncKHR");

    eglCreateImageKHR = (PFNEGLCREATEIMAGEKHRPROC) eglGetProcAddress("eglCreateImageKHR");
    eglDestroyImageKHR = (PFNEGLDESTROYIMAGEKHRPROC) eglGetProcAddress("eglDestroyImageKHR");

    EGLint configsCount;

    // EGLint configAttribs[] = {
    //        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
    //        EGL_RED_SIZE, 8,
    //        EGL_GREEN_SIZE, 8,
    //        EGL_BLUE_SIZE, 8,
    //        EGL_ALPHA_SIZE,  0,
    //        EGL_DEPTH_SIZE, 32,
    //        EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
    //        EGL_NONE
    // };

    EGLint configAttribs[] = {
      EGL_RED_SIZE,   8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE,    8,
      EGL_ALPHA_SIZE, 8, EGL_DEPTH_SIZE, 8, EGL_STENCIL_SIZE, 8,
      EGL_NONE,
  };

    EGLint contextAttribs[] = {
            EGL_CONTEXT_CLIENT_VERSION, 3,
            EGL_NONE, EGL_NONE, // reserved for EGL_CONTEXT_OPENGL_NO_ERROR_KHR below
            EGL_NONE
    };

    EGLint pbufferAttribs[] = {
      EGL_WIDTH,          mWidth,         EGL_HEIGHT,         mHeight,
      EGL_TEXTURE_TARGET, EGL_TEXTURE_2D, EGL_TEXTURE_FORMAT, EGL_TEXTURE_RGBA,
      EGL_NONE,
    };

    EGLConfig eglConfig = nullptr;
    EGLConfig mEGLTransparentConfig = nullptr;

    char const* version;

    // find an opaque config
    if (!eglChooseConfig(mEGLDisplay, configAttribs, &mEGLConfig, 1, &configsCount)) {
        logEglError("eglChooseConfig");
        goto error;
    }

    // fallback to a 24-bit depth buffer
    if (configsCount == 0) {
        configAttribs[10] = EGL_DEPTH_SIZE;
        configAttribs[11] = 24;

        if (!eglChooseConfig(mEGLDisplay, configAttribs, &mEGLConfig, 1, &configsCount)) {
            logEglError("eglChooseConfig");
            goto error;
        }
    }

    // find a transparent config
    configAttribs[8] = EGL_ALPHA_SIZE;
    configAttribs[9] = 8;
    if (!eglChooseConfig(mEGLDisplay, configAttribs, &mEGLTransparentConfig, 1, &configsCount) ||
            (configAttribs[13] == EGL_DONT_CARE && configsCount == 0)) {
        logEglError("eglChooseConfig");
        goto error;
    }

    if (!extensions.has("EGL_KHR_no_config_context")) {
         // if we have the EGL_KHR_no_config_context, we don't need to worry about the config
         // when creating the context, otherwise, we must always pick a transparent config.
         eglConfig = mEGLConfig = mEGLTransparentConfig;
    }

    mEGLContext = eglCreateContext(mEGLDisplay, eglConfig, EGL_NO_CONTEXT, contextAttribs);

    if (UTILS_UNLIKELY(mEGLContext == EGL_NO_CONTEXT)) {
        // eglCreateContext failed
        logEglError("eglCreateContext");
        goto error;
    }

    mCurrentDrawSurface = mCurrentReadSurface = eglCreatePbufferFromClientBuffer(
        mEGLDisplay, EGL_D3D_TEXTURE_2D_SHARE_HANDLE_ANGLE, mD3DTextureHandle,
      mEGLTransparentConfig, pbufferAttribs);

    if (mCurrentDrawSurface == EGL_NO_SURFACE) {
        logEglError("eglCreatePbufferSurface");
        goto error;
    }

    if (!eglMakeCurrent(mEGLDisplay, mCurrentDrawSurface, mCurrentDrawSurface, mEGLContext)) {
        // eglMakeCurrent failed
        logEglError("eglMakeCurrent");
        goto error;
    }

    glGenTextures(1, &glTextureId);
    glBindTexture(GL_TEXTURE_2D, glTextureId);
    eglBindTexImage(mEGLDisplay, mCurrentReadSurface, EGL_BACK_BUFFER);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    initializeGlExtensions();

    clearGlError();

    version = (char const*)glGetString(GL_VERSION);
    std::cout << "Got version " << version << std::endl;
    glGetIntegerv(GL_MAJOR_VERSION, &major);
    glGetIntegerv(GL_MINOR_VERSION, &minor);

    // success!!
    return OpenGLPlatform::createDefaultDriver(this, sharedContext, driverConfig);

error:
    // if we're here, we've failed
    if (mCurrentDrawSurface) {
        eglDestroySurface(mEGLDisplay, mCurrentDrawSurface);
    }
    if (mEGLContext) {
        eglDestroyContext(mEGLDisplay, mEGLContext);
    }

    mCurrentDrawSurface = mCurrentReadSurface = EGL_NO_SURFACE;
    mEGLContext = EGL_NO_CONTEXT;

    eglTerminate(mEGLDisplay);
    eglReleaseThread();

    return nullptr;
}


EGLBoolean PlatformANGLE::makeCurrent(EGLSurface drawSurface, EGLSurface readSurface) noexcept {
    // if (UTILS_UNLIKELY((drawSurface != mCurrentDrawSurface || readSurface != mCurrentReadSurface))) {
        mCurrentDrawSurface = drawSurface;
        mCurrentReadSurface = readSurface;
        return eglMakeCurrent(mEGLDisplay, drawSurface, readSurface, mEGLContext);
    // }
    return EGL_TRUE;
}

void PlatformANGLE::terminate() noexcept {
    eglMakeCurrent(mEGLDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroyContext(mEGLDisplay, mEGLContext);
    eglTerminate(mEGLDisplay);
    eglReleaseThread();
}

EGLConfig PlatformANGLE::findSwapChainConfig(uint64_t flags) const {
    EGLConfig config = EGL_NO_CONFIG_KHR;
    EGLint configsCount;
    EGLint configAttribs[] = {
            EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT_KHR,
            EGL_RED_SIZE, 8,
            EGL_GREEN_SIZE, 8,
            EGL_BLUE_SIZE, 8,
            EGL_ALPHA_SIZE, (flags & SWAP_CHAIN_CONFIG_TRANSPARENT) ? 8 : 0,
            EGL_DEPTH_SIZE, 24,
            EGL_RECORDABLE_ANDROID, 1,
            EGL_NONE
    };

    if (UTILS_UNLIKELY(
            !eglChooseConfig(mEGLDisplay, configAttribs, &config, 1, &configsCount))) {
        logEglError("eglChooseConfig");
            return EGL_NO_CONFIG_KHR;
    }

    if (UTILS_UNLIKELY(configsCount == 0)) {
        // warn and retry without EGL_RECORDABLE_ANDROID
        logEglError(
                "eglChooseConfig(..., EGL_RECORDABLE_ANDROID) failed. Continuing without it.");
        configAttribs[12] = EGL_RECORDABLE_ANDROID;
        configAttribs[13] = EGL_DONT_CARE;
        if (UTILS_UNLIKELY(
                !eglChooseConfig(mEGLDisplay, configAttribs, &config, 1, &configsCount) ||
                configsCount == 0)) {
            logEglError("eglChooseConfig");
                return EGL_NO_CONFIG_KHR;
        }
    }
    return config;
}

bool PlatformANGLE::isSRGBSwapChainSupported() const noexcept {
    return ext.egl.KHR_gl_colorspace;
}

void PlatformANGLE::destroySwapChain(Platform::SwapChain* swapChain) noexcept {
    EGLSurface sur = (EGLSurface) swapChain;
    if (sur != EGL_NO_SURFACE) {
        makeCurrent(EGL_NO_SURFACE, EGL_NO_SURFACE);
        eglDestroySurface(mEGLDisplay, sur);
    }
}

void PlatformANGLE::makeCurrent(Platform::SwapChain* drawSwapChain,
                              Platform::SwapChain* readSwapChain) noexcept {
    EGLSurface drawSur = (EGLSurface) drawSwapChain;
    EGLSurface readSur = (EGLSurface) readSwapChain;
    if (drawSur != EGL_NO_SURFACE || readSur != EGL_NO_SURFACE) {
        makeCurrent(drawSur, readSur);
    }
}
    using namespace std::chrono_literals;

void PlatformANGLE::commit(Platform::SwapChain* swapChain) noexcept {
    EGLSurface sur = (EGLSurface) swapChain;
    if (sur != EGL_NO_SURFACE) {
        eglSwapBuffers(mEGLDisplay, sur);
    }  
}

bool PlatformANGLE::canCreateFence() noexcept {
    return true;
}

Platform::Fence* PlatformANGLE::createFence() noexcept {
    Fence* f = nullptr;
#ifdef EGL_KHR_reusable_sync
    f = (Fence*) eglCreateSyncKHR(mEGLDisplay, EGL_SYNC_FENCE_KHR, nullptr);
#endif
    return f;
}

void PlatformANGLE::destroyFence(Platform::Fence* fence) noexcept {
#ifdef EGL_KHR_reusable_sync
    EGLSyncKHR sync = (EGLSyncKHR) fence;
    if (sync != EGL_NO_SYNC_KHR) {
        eglDestroySyncKHR(mEGLDisplay, sync);
    }
#endif
}

FenceStatus PlatformANGLE::waitFence(
        Platform::Fence* fence, uint64_t timeout) noexcept {
#ifdef EGL_KHR_reusable_sync
    EGLSyncKHR sync = (EGLSyncKHR) fence;
    if (sync != EGL_NO_SYNC_KHR) {
        EGLint status = eglClientWaitSyncKHR(mEGLDisplay, sync, 0, (EGLTimeKHR)timeout);
        if (status == EGL_CONDITION_SATISFIED_KHR) {
            return FenceStatus::CONDITION_SATISFIED;
        }
        if (status == EGL_TIMEOUT_EXPIRED_KHR) {
            return FenceStatus::TIMEOUT_EXPIRED;
        }
    }
#endif
    return FenceStatus::ERROR;
}

#define GL_TEXTURE_EXTERNAL_OES           0x8D65

OpenGLPlatform::ExternalTexture* PlatformANGLE::createExternalImageTexture() noexcept {
    ExternalTexture* outTexture = new ExternalTexture{};
    // glGenTextures(1, &outTexture->id);
    // if (UTILS_LIKELY(ext.gl.OES_EGL_image_external_essl3)) {
    //     outTexture->target = GL_TEXTURE_EXTERNAL_OES;
    // } else {
    //     // if texture external is not supported, revert to texture 2d
    //     outTexture->target = GL_TEXTURE_2D;
    // }
    return outTexture;
}

void PlatformANGLE::destroyExternalImage(ExternalTexture* texture) noexcept {
    // glDeleteTextures(1, &texture->id);
    delete texture;
}

bool PlatformANGLE::setExternalImage(void* externalImage,
        UTILS_UNUSED_IN_RELEASE ExternalTexture* texture) noexcept {
    if (UTILS_LIKELY(ext.gl.OES_EGL_image_external_essl3)) {
        assert_invariant(texture->target == GL_TEXTURE_EXTERNAL_OES);
        // the texture is guaranteed to be bound here.
#ifdef GL_OES_EGL_image
        glEGLImageTargetTexture2DOES(GL_TEXTURE_EXTERNAL_OES,
                static_cast<GLeglImageOES>(externalImage));
#endif
    }
    return true;
}

void PlatformANGLE::initializeGlExtensions() noexcept {
    GLUtils::unordered_string_set glExtensions;
    GLint n;
    glGetIntegerv(GL_NUM_EXTENSIONS, &n);
    for (GLint i = 0; i < n; ++i) {
        const char* const extension = (const char*)glGetStringi(GL_EXTENSIONS, (GLuint)i);
        glExtensions.insert(extension);
    }
    ext.gl.OES_EGL_image_external_essl3 = glExtensions.has("GL_OES_EGL_image_external_essl3");
}

Platform::SwapChain* PlatformANGLE::createSwapChain(void* nativewindow, uint64_t flags) noexcept {
    return (Platform::SwapChain*) mCurrentDrawSurface;
}

Platform::SwapChain* PlatformANGLE::createSwapChain(uint32_t width, uint32_t height, uint64_t flags)  noexcept    {
    return (Platform::SwapChain*) mCurrentDrawSurface;
}



} // namespace filament

// ---------------------------------------------------------------------------------------------
