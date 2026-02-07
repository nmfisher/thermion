#include "egl_texture.h"

#include <iostream>

#ifndef GL_TEXTURE_EXTERNAL_OES
#define GL_TEXTURE_EXTERNAL_OES 0x8D65
#endif

// EGL function pointers (resolved at runtime)
static PFNEGLCREATEIMAGEKHRPROC s_eglCreateImageKHR = nullptr;
static PFNEGLDESTROYIMAGEKHRPROC s_eglDestroyImageKHR = nullptr;
static PFNGLEGLIMAGETARGETTEXTURE2DOESPROC s_glEGLImageTargetTexture2DOES = nullptr;

G_DEFINE_TYPE(ThermionTextureGL,
              thermion_texture_gl,
              fl_texture_gl_get_type())

static gboolean
thermion_texture_populate(FlTextureGL *texture,
                          uint32_t *target,
                          uint32_t *name,
                          uint32_t *width,
                          uint32_t *height,
                          GError **error) {
    ThermionTextureGL *self = THERMION_TEXTURE_GL(texture);

    // Lazy initialization: create EGL image and GL texture on first call
    // This ensures we're on Flutter's render thread with an active GL context
    if (!self->initialized) {
        // Resolve EGL extension functions
        if (!s_eglCreateImageKHR) {
            s_eglCreateImageKHR = (PFNEGLCREATEIMAGEKHRPROC)eglGetProcAddress("eglCreateImageKHR");
            s_eglDestroyImageKHR = (PFNEGLDESTROYIMAGEKHRPROC)eglGetProcAddress("eglDestroyImageKHR");
            s_glEGLImageTargetTexture2DOES = (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)eglGetProcAddress("glEGLImageTargetTexture2DOES");
        }

        if (!s_eglCreateImageKHR || !s_eglDestroyImageKHR || !s_glEGLImageTargetTexture2DOES) {
            std::cerr << "[ThermionEGL] Failed to resolve EGL extension functions" << std::endl;
            g_set_error(error, g_quark_from_string("thermion"), 1,
                        "Failed to resolve EGL extension functions");
            return FALSE;
        }

        EGLDisplay display = eglGetCurrentDisplay();
        if (display == EGL_NO_DISPLAY) {
            std::cerr << "[ThermionEGL] No EGL display available" << std::endl;
            g_set_error(error, g_quark_from_string("thermion"), 2,
                        "No EGL display available");
            return FALSE;
        }

        // Create EGLImage from dmabuf fd
        // DRM_FORMAT_MOD_LINEAR = 0; specify explicitly so NVIDIA knows the layout
        EGLint attribs[] = {
            EGL_WIDTH, (EGLint)self->width,
            EGL_HEIGHT, (EGLint)self->height,
            EGL_LINUX_DRM_FOURCC_EXT, (EGLint)self->drm_format,
            EGL_DMA_BUF_PLANE0_FD_EXT, self->dmabuf_fd,
            EGL_DMA_BUF_PLANE0_OFFSET_EXT, (EGLint)self->offset,
            EGL_DMA_BUF_PLANE0_PITCH_EXT, (EGLint)self->stride,
            EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT, 0,
            EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT, 0,
            EGL_NONE
        };

        self->egl_image = s_eglCreateImageKHR(display, EGL_NO_CONTEXT,
                                               EGL_LINUX_DMA_BUF_EXT,
                                               nullptr, attribs);
        if (self->egl_image == EGL_NO_IMAGE_KHR) {
            EGLint eglError = eglGetError();
            std::cerr << "[ThermionEGL] Failed to create EGLImage from dmabuf, EGL error: 0x"
                      << std::hex << eglError << std::dec << std::endl;
            g_set_error(error, g_quark_from_string("thermion"), 3,
                        "Failed to create EGLImage from dmabuf");
            return FALSE;
        }

        // Create GL texture and bind EGLImage to it.
        // DMA-BUF EGLImages require GL_TEXTURE_EXTERNAL_OES on NVIDIA.
        glGenTextures(1, &self->gl_texture_id);
        glBindTexture(GL_TEXTURE_EXTERNAL_OES, self->gl_texture_id);
        glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_EXTERNAL_OES, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        // Clear any stale GL errors before the EGLImage call
        while (glGetError() != GL_NO_ERROR) {}

        s_glEGLImageTargetTexture2DOES(GL_TEXTURE_EXTERNAL_OES, self->egl_image);

        GLenum glError = glGetError();
        if (glError != GL_NO_ERROR) {
            std::cerr << "[ThermionEGL] GL error after EGLImage target: 0x"
                      << std::hex << glError << std::dec << std::endl;
        }

        self->initialized = TRUE;
        std::cout << "[ThermionEGL] Initialized GL texture " << self->gl_texture_id
                  << " from dmabuf fd " << self->dmabuf_fd
                  << " (" << self->width << "x" << self->height << ")" << std::endl;
    }

    *target = GL_TEXTURE_EXTERNAL_OES;
    *name = self->gl_texture_id;
    *width = self->width;
    *height = self->height;
    return TRUE;
}

static void thermion_texture_gl_dispose(GObject* object) {
    ThermionTextureGL *self = THERMION_TEXTURE_GL(object);

    if (self->gl_texture_id != 0) {
        glDeleteTextures(1, &self->gl_texture_id);
        self->gl_texture_id = 0;
    }

    if (self->egl_image != EGL_NO_IMAGE_KHR && s_eglDestroyImageKHR) {
        EGLDisplay display = eglGetCurrentDisplay();
        if (display != EGL_NO_DISPLAY) {
            s_eglDestroyImageKHR(display, self->egl_image);
        }
        self->egl_image = EGL_NO_IMAGE_KHR;
    }

    G_OBJECT_CLASS(thermion_texture_gl_parent_class)->dispose(object);
}

void thermion_texture_gl_class_init(ThermionTextureGLClass* klass) {
    G_OBJECT_CLASS(klass)->dispose = thermion_texture_gl_dispose;
    FL_TEXTURE_GL_CLASS(klass)->populate = thermion_texture_populate;
}

void thermion_texture_gl_init(ThermionTextureGL* self) {
    self->gl_texture_id = 0;
    self->width = 0;
    self->height = 0;
    self->registrar = nullptr;
    self->dmabuf_fd = -1;
    self->stride = 0;
    self->offset = 0;
    self->drm_format = 0;
    self->egl_image = EGL_NO_IMAGE_KHR;
    self->initialized = FALSE;
    self->surface_id = -1;
}

ThermionTextureGL* thermion_texture_gl_create(
    uint32_t width, uint32_t height,
    int dmabuf_fd, uint32_t stride, uint32_t offset, uint32_t drm_format,
    int64_t surface_id,
    FlTextureRegistrar* registrar)
{
    auto textureGL = THERMION_TEXTURE_GL(g_object_new(thermion_texture_gl_get_type(), nullptr));
    textureGL->width = width;
    textureGL->height = height;
    textureGL->registrar = registrar;
    textureGL->dmabuf_fd = dmabuf_fd;
    textureGL->stride = stride;
    textureGL->offset = offset;
    textureGL->drm_format = drm_format;
    textureGL->surface_id = surface_id;

    return textureGL;
}

void thermion_texture_gl_destroy(ThermionTextureGL* texture) {
    if (texture && texture->registrar) {
        fl_texture_registrar_unregister_texture(texture->registrar, FL_TEXTURE(texture));
    }
}
