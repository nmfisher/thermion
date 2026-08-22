#include "opengl/linux/LinuxOpenGLTexture.h"

#include <iostream>
#include <unistd.h>

#include <gbm.h>
#include <drm_fourcc.h>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

// EGL extension function pointers
static PFNEGLCREATEIMAGEKHRPROC s_eglCreateImageKHR = nullptr;
static PFNEGLDESTROYIMAGEKHRPROC s_eglDestroyImageKHR = nullptr;
static PFNGLEGLIMAGETARGETTEXTURE2DOESPROC s_glEGLImageTargetTexture2DOES = nullptr;

static void ensureExtensionFunctions() {
    if (!s_eglCreateImageKHR) {
        s_eglCreateImageKHR = (PFNEGLCREATEIMAGEKHRPROC)eglGetProcAddress("eglCreateImageKHR");
        s_eglDestroyImageKHR = (PFNEGLDESTROYIMAGEKHRPROC)eglGetProcAddress("eglDestroyImageKHR");
        s_glEGLImageTargetTexture2DOES = (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)eglGetProcAddress("glEGLImageTargetTexture2DOES");
    }
}

namespace thermion::opengl::linux_platform {

class ScopedEglContext {
public:
    ScopedEglContext(
        EGLDisplay display, EGLContext context, EGLSurface surface)
        : _targetDisplay(display),
          _targetSurface(surface),
          _previousDisplay(eglGetCurrentDisplay()),
          _previousContext(eglGetCurrentContext()),
          _previousDraw(eglGetCurrentSurface(EGL_DRAW)),
          _previousRead(eglGetCurrentSurface(EGL_READ)),
          _previousApi(eglQueryAPI()) {
        if (_previousContext != EGL_NO_CONTEXT &&
            _previousDisplay != EGL_NO_DISPLAY) {
            eglMakeCurrent(_previousDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE,
                           EGL_NO_CONTEXT);
        }
        eglBindAPI(EGL_OPENGL_API);
        _current = eglMakeCurrent(
            _targetDisplay, _targetSurface, _targetSurface, context);
    }

    ~ScopedEglContext() {
        if (_targetDisplay != EGL_NO_DISPLAY) {
            eglMakeCurrent(_targetDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE,
                           EGL_NO_CONTEXT);
        }
        eglBindAPI(_previousApi);
        if (_previousContext != EGL_NO_CONTEXT &&
            _previousDisplay != EGL_NO_DISPLAY) {
            eglMakeCurrent(_previousDisplay, _previousDraw, _previousRead,
                           _previousContext);
        }
    }

    bool current() const { return _current == EGL_TRUE; }

    ScopedEglContext(const ScopedEglContext&) = delete;
    ScopedEglContext& operator=(const ScopedEglContext&) = delete;

private:
    EGLDisplay _targetDisplay;
    EGLSurface _targetSurface;
    EGLDisplay _previousDisplay;
    EGLContext _previousContext;
    EGLSurface _previousDraw;
    EGLSurface _previousRead;
    EGLenum _previousApi;
    EGLBoolean _current = EGL_FALSE;
};

LinuxOpenGLTexture::~LinuxOpenGLTexture() {
    if (_glTextureId != 0) {
        ScopedEglContext context(_display, _context, _surface);
        if (context.current()) {
            glDeleteTextures(1, &_glTextureId);
        } else {
            std::cerr
                << "[ThermionGL:Texture] Failed to make owner context current "
                   "while deleting texture "
                << _glTextureId << ", EGL error: 0x" << std::hex
                << eglGetError() << std::dec << std::endl;
        }
        _glTextureId = 0;
    }

    if (_eglImage != EGL_NO_IMAGE && s_eglDestroyImageKHR && _display != EGL_NO_DISPLAY) {
        s_eglDestroyImageKHR(_display, _eglImage);
        _eglImage = EGL_NO_IMAGE;
    }

    if (_dmaBufFd >= 0) {
        close(_dmaBufFd);
        _dmaBufFd = -1;
    }

    if (_gbmBo) {
        gbm_bo_destroy(_gbmBo);
        _gbmBo = nullptr;
    }
}

std::unique_ptr<LinuxOpenGLTexture> LinuxOpenGLTexture::create(
    EGLDisplay display, EGLContext context, EGLSurface surface,
    struct gbm_device* gbm, uint32_t width, uint32_t height)
{
    ensureExtensionFunctions();

    if (!s_eglCreateImageKHR || !s_eglDestroyImageKHR || !s_glEGLImageTargetTexture2DOES) {
        std::cerr << "[ThermionGL:Texture] Failed to resolve EGL extension functions" << std::endl;
        return nullptr;
    }

    // Step 1: Create GBM buffer object
    // Try LINEAR first for maximum compatibility with DMA-BUF consumers
    struct gbm_bo* bo = gbm_bo_create(gbm, width, height,
        GBM_FORMAT_ABGR8888,
        GBM_BO_USE_RENDERING | GBM_BO_USE_LINEAR);

    if (!bo) {
        // Retry without LINEAR — some drivers don't support it
        std::cerr << "[ThermionGL:Texture] LINEAR allocation failed, retrying without LINEAR" << std::endl;
        bo = gbm_bo_create(gbm, width, height,
            GBM_FORMAT_ABGR8888,
            GBM_BO_USE_RENDERING);
    }

    if (!bo) {
        std::cerr << "[ThermionGL:Texture] Failed to create GBM buffer " << width << "x" << height << std::endl;
        return nullptr;
    }

    // Step 2: Export DMA-BUF parameters
    int dmaBufFd = gbm_bo_get_fd(bo);
    if (dmaBufFd < 0) {
        std::cerr << "[ThermionGL:Texture] Failed to get DMA-BUF fd from GBM buffer" << std::endl;
        gbm_bo_destroy(bo);
        return nullptr;
    }

    uint32_t stride = gbm_bo_get_stride(bo);
    uint32_t offset = gbm_bo_get_offset(bo, 0);
    uint32_t drmFormat = gbm_bo_get_format(bo);
    uint64_t drmModifier = gbm_bo_get_modifier(bo);

    std::cerr << "[ThermionGL:Texture] GBM buffer created: "
              << width << "x" << height
              << " fd=" << dmaBufFd
              << " stride=" << stride
              << " offset=" << offset
              << " format=0x" << std::hex << drmFormat
              << " modifier=0x" << drmModifier << std::dec
              << std::endl;

    // Step 3: Create EGLImage from DMA-BUF
    EGLint modLo = (EGLint)(drmModifier & 0xFFFFFFFF);
    EGLint modHi = (EGLint)(drmModifier >> 32);

    EGLint attribs[] = {
        EGL_WIDTH, (EGLint)width,
        EGL_HEIGHT, (EGLint)height,
        EGL_LINUX_DRM_FOURCC_EXT, (EGLint)drmFormat,
        EGL_DMA_BUF_PLANE0_FD_EXT, dmaBufFd,
        EGL_DMA_BUF_PLANE0_OFFSET_EXT, (EGLint)offset,
        EGL_DMA_BUF_PLANE0_PITCH_EXT, (EGLint)stride,
        EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT, modLo,
        EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT, modHi,
        EGL_NONE
    };

    EGLImage eglImage = s_eglCreateImageKHR(display, EGL_NO_CONTEXT,
        EGL_LINUX_DMA_BUF_EXT, nullptr, attribs);

    if (eglImage == EGL_NO_IMAGE) {
        EGLint err = eglGetError();
        std::cerr << "[ThermionGL:Texture] Failed to create EGLImage, error: 0x"
                  << std::hex << err << std::dec << std::endl;
        close(dmaBufFd);
        gbm_bo_destroy(bo);
        return nullptr;
    }

    // Step 4: Make our context current so we can create GL objects.
    ScopedEglContext scopedContext(display, context, surface);
    if (!scopedContext.current()) {
        std::cerr << "[ThermionGL:Texture] Failed to make owner context "
                     "current, EGL error: 0x"
                  << std::hex << eglGetError() << std::dec << std::endl;
        s_eglDestroyImageKHR(display, eglImage);
        close(dmaBufFd);
        gbm_bo_destroy(bo);
        return nullptr;
    }

    // Step 5: Create GL texture and bind EGLImage to it
    GLuint glTextureId = 0;
    glGenTextures(1, &glTextureId);
    glBindTexture(GL_TEXTURE_2D, glTextureId);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    // Clear stale GL errors
    while (glGetError() != GL_NO_ERROR) {}

    s_glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, eglImage);

    GLenum glError = glGetError();
    if (glError != GL_NO_ERROR) {
        std::cerr << "[ThermionGL:Texture] GL error after EGLImageTargetTexture2D: 0x"
                  << std::hex << glError << std::dec << std::endl;
        glDeleteTextures(1, &glTextureId);
        s_eglDestroyImageKHR(display, eglImage);
        close(dmaBufFd);
        gbm_bo_destroy(bo);
        return nullptr;
    }

    glBindTexture(GL_TEXTURE_2D, 0);

    std::cerr << "[ThermionGL:Texture] GL texture created: id=" << glTextureId
              << " " << width << "x" << height << std::endl;

    // Build the texture object
    auto texture = std::unique_ptr<LinuxOpenGLTexture>(new LinuxOpenGLTexture());
    texture->_glTextureId = glTextureId;
    texture->_gbmBo = bo;
    texture->_eglImage = eglImage;
    texture->_dmaBufFd = dmaBufFd;
    texture->_stride = stride;
    texture->_offset = offset;
    texture->_width = width;
    texture->_height = height;
    texture->_drmFormat = drmFormat;
    texture->_drmModifier = drmModifier;
    texture->_display = display;
    texture->_context = context;
    texture->_surface = surface;

    return texture;
}

} // namespace thermion::opengl::linux_platform
