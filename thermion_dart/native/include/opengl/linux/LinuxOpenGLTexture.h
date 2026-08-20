#pragma once

#include <cstdint>
#include <memory>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>

struct gbm_device;
struct gbm_bo;

namespace thermion::opengl::linux_platform {

/**
 * GL texture owned by the isolated desktop-OpenGL producer context.
 *
 * The preferred transport exposes a regular GL_TEXTURE_2D as an EGLImage.
 * Flutter imports that image into its GLES/GL share group. The compatibility
 * transport backs the texture with a GBM buffer and exports DMA-BUF metadata.
 *
 * In both cases the GL texture ID is valid in Filament's producer share group.
 */
class LinuxOpenGLTexture {
public:
    ~LinuxOpenGLTexture();

    static std::unique_ptr<LinuxOpenGLTexture> createEglImage(
        EGLDisplay display, EGLContext context, EGLSurface surface,
        uint32_t width, uint32_t height);

    static std::unique_ptr<LinuxOpenGLTexture> createDmaBuf(
        EGLDisplay display, EGLContext context, EGLSurface surface,
        struct gbm_device* gbm, uint32_t width, uint32_t height);

    GLuint GetGLTextureId() const { return _glTextureId; }
    EGLImage GetEGLImage() const { return _eglImage; }
    int GetDmaBufFd() const { return _dmaBufFd; }
    uint32_t GetStride() const { return _stride; }
    uint32_t GetOffset() const { return _offset; }
    uint32_t GetWidth() const { return _width; }
    uint32_t GetHeight() const { return _height; }
    uint32_t GetDrmFormat() const { return _drmFormat; }
    uint64_t GetDrmModifier() const { return _drmModifier; }

private:
    LinuxOpenGLTexture() = default;

    GLuint _glTextureId = 0;
    struct gbm_bo* _gbmBo = nullptr;
    EGLImage _eglImage = EGL_NO_IMAGE;
    int _dmaBufFd = -1;
    uint32_t _stride = 0;
    uint32_t _offset = 0;
    uint32_t _width = 0;
    uint32_t _height = 0;
    uint32_t _drmFormat = 0;
    uint64_t _drmModifier = 0;

    // Store display for cleanup
    EGLDisplay _display = EGL_NO_DISPLAY;
    EGLContext _context = EGL_NO_CONTEXT;
    EGLSurface _surface = EGL_NO_SURFACE;
};

} // namespace thermion::opengl::linux_platform
