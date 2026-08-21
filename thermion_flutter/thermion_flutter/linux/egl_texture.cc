#include "egl_texture.h"
#include "Log.hpp"

#include <chrono>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <vector>

#ifndef GL_TEXTURE_EXTERNAL_OES
#define GL_TEXTURE_EXTERNAL_OES 0x8D65
#endif

// Flutter's render context, captured during the first deferred populate().
EGLContext thermion_flutter_render_context = EGL_NO_CONTEXT;
EGLDisplay thermion_flutter_render_display = EGL_NO_DISPLAY;
EGLenum thermion_flutter_render_api = EGL_NONE;
EGLint thermion_flutter_render_gl_major = 0;
EGLint thermion_flutter_render_gl_minor = 0;

// EGL function pointers (resolved at runtime)
static PFNEGLCREATEIMAGEKHRPROC s_eglCreateImageKHR = nullptr;
static PFNEGLDESTROYIMAGEKHRPROC s_eglDestroyImageKHR = nullptr;
static PFNGLEGLIMAGETARGETTEXTURE2DOESPROC s_glEGLImageTargetTexture2DOES = nullptr;

struct DeferredReadyResponse {
    FlMethodCall* method_call;
    int64_t texture_id;
};

static gboolean respond_texture_ready(gpointer user_data) {
    auto* response = static_cast<DeferredReadyResponse*>(user_data);
    g_autoptr(FlValue) result = fl_value_new_int(response->texture_id);
    fl_method_call_respond(
        response->method_call,
        FL_METHOD_RESPONSE(fl_method_success_response_new(result)), nullptr);
    g_object_unref(response->method_call);
    delete response;
    return G_SOURCE_REMOVE;
}

static void ensure_egl_procs() {
    if (!s_eglCreateImageKHR) {
        s_eglCreateImageKHR = (PFNEGLCREATEIMAGEKHRPROC)eglGetProcAddress("eglCreateImageKHR");
        s_eglDestroyImageKHR = (PFNEGLDESTROYIMAGEKHRPROC)eglGetProcAddress("eglDestroyImageKHR");
        s_glEGLImageTargetTexture2DOES = (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)eglGetProcAddress("glEGLImageTargetTexture2DOES");
    }
}

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
    static auto lastPopulate = std::chrono::high_resolution_clock::now();
    static int popCount = 0;
    static int popJank = 0;
    static double popMaxMs = 0;
    static double popSumMs = 0;
    auto now = std::chrono::high_resolution_clock::now();
    double intervalMs = std::chrono::duration_cast<std::chrono::microseconds>(now - lastPopulate).count() / 1000.0;
    lastPopulate = now;
    popCount++;
    popSumMs += intervalMs;
    if (intervalMs > popMaxMs) popMaxMs = intervalMs;
    if (intervalMs > 20.0) popJank++;
    if (intervalMs > 20.0) {
        TRACE( "[POPULATE] #%d JANK interval=%.1fms\n", popCount, intervalMs);
    }
    if (popCount % 120 == 0) {
        double avgMs = popSumMs / 120.0;
        TRACE( "[POPULATE] 120-frame avg=%.1fms max=%.1fms jank=%d\n",
                avgMs, popMaxMs, popJank);
        popJank = 0;
        popMaxMs = 0;
        popSumMs = 0;
    }

    ThermionTextureGL *self = THERMION_TEXTURE_GL(texture);

    // Direct sharing path: texture is directly visible from Flutter's context.
    // If gl_texture_id == 0, this is a deferred texture — create it now on
    // Flutter's render context (which is guaranteed current during populate).
    if (self->use_direct_sharing) {
        if (self->gl_texture_id == 0) {
            EGLContext flutterContext = eglGetCurrentContext();
            EGLDisplay flutterDisplay = eglGetCurrentDisplay();
            if (flutterContext == EGL_NO_CONTEXT ||
                flutterDisplay == EGL_NO_DISPLAY) {
                g_set_error(error, g_quark_from_static_string("thermion"), 1,
                            "Flutter did not make an EGL context current");
                return FALSE;
            }

            // First populate — create a transparent GL texture on Flutter's
            // raster context. Its purpose is to import the actual context, not
            // to display application content.
            std::vector<uint8_t> pixels(self->width * self->height * 4, 0);
            while (glGetError() != GL_NO_ERROR) {}
            glGenTextures(1, &self->gl_texture_id);
            glBindTexture(GL_TEXTURE_2D, self->gl_texture_id);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, self->width, self->height, 0,
                         GL_RGBA, GL_UNSIGNED_BYTE, pixels.data());
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            glBindTexture(GL_TEXTURE_2D, 0);
            GLenum glError = glGetError();
            if (self->gl_texture_id == 0 || glError != GL_NO_ERROR) {
                if (self->gl_texture_id != 0) {
                    glDeleteTextures(1, &self->gl_texture_id);
                    self->gl_texture_id = 0;
                }
                g_set_error(
                    error, g_quark_from_static_string("thermion"), 2,
                    "Failed to create Flutter context bootstrap texture "
                    "(GL error 0x%x)",
                    glError);
                return FALSE;
            }
            self->surface_id = static_cast<int64_t>(self->gl_texture_id);

            TRACE( "[DirectPop] Created bootstrap GL texture %u (%ux%u) on ctx=%p\n",
                    self->gl_texture_id, self->width, self->height,
                    (void*)flutterContext);

            // Capture Flutter's render context for Filament initialization.
            // This is the ONLY place where Flutter's render context is current.
            thermion_flutter_render_context = flutterContext;
            thermion_flutter_render_display = flutterDisplay;
            thermion_flutter_render_api = eglQueryAPI();

            const char* version = reinterpret_cast<const char*>(
                glGetString(GL_VERSION));
            if (version) {
                if (std::sscanf(version, "OpenGL ES %d.%d",
                                &thermion_flutter_render_gl_major,
                                &thermion_flutter_render_gl_minor) != 2) {
                    std::sscanf(version, "%d.%d",
                                &thermion_flutter_render_gl_major,
                                &thermion_flutter_render_gl_minor);
                }
            }
            TRACE( "[DirectPop] Captured Flutter render context=%p display=%p API=0x%x version=%d.%d\n",
                    (void*)thermion_flutter_render_context,
                    (void*)thermion_flutter_render_display,
                    thermion_flutter_render_api,
                    thermion_flutter_render_gl_major,
                    thermion_flutter_render_gl_minor);

            // Do not resolve awaitTextureReady from inside populate(). Dart
            // may immediately initialize another EGL client API when the
            // Future completes. Queue the response on Flutter's platform loop
            // so this raster callback has fully returned first.
            if (self->pending_ready_call) {
                auto* response = new DeferredReadyResponse{
                    self->pending_ready_call,
                    static_cast<int64_t>(self->gl_texture_id),
                };
                self->pending_ready_call = nullptr;
                g_idle_add_full(
                    G_PRIORITY_DEFAULT_IDLE, respond_texture_ready, response,
                    nullptr);
            }
        }

        *target = GL_TEXTURE_2D;
        *name   = self->gl_texture_id;
        *width  = self->width;
        *height = self->height;
        return TRUE;
    }

    // EGLImage bridge path: the source texture lives on Filament's desktop
    // context. On first populate, bind its EGLImage to a Flutter-owned texture
    // name on Flutter's current context.
    if (self->use_egl_image) {
        if (!self->initialized) {
            ensure_egl_procs();
            if (!s_glEGLImageTargetTexture2DOES) {
                g_set_error(error, g_quark_from_string("thermion"), 1,
                            "glEGLImageTargetTexture2DOES not available");
                return FALSE;
            }

            if (self->egl_image == EGL_NO_IMAGE_KHR) {
                g_set_error(error, g_quark_from_string("thermion"), 2,
                            "No EGLImage available");
                return FALSE;
            }

            // Create a new texture on Flutter's context and bind the EGLImage
            glGenTextures(1, &self->flutter_gl_texture_id);
            glBindTexture(GL_TEXTURE_2D, self->flutter_gl_texture_id);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

            while (glGetError() != GL_NO_ERROR) {}

            s_glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, self->egl_image);

            GLenum glErr = glGetError();
            if (glErr != GL_NO_ERROR) {
                std::cerr << "[ThermionEGL] GL error after EGLImage import: 0x"
                          << std::hex << glErr << std::dec << std::endl;
            }

            glBindTexture(GL_TEXTURE_2D, 0);
            self->initialized = TRUE;
        }

        *target = GL_TEXTURE_2D;
        *name = self->flutter_gl_texture_id;
        *width = self->width;
        *height = self->height;
        return TRUE;
    }

    // DMA-BUF path (fallback): lazy-init EGLImage import on first populate
    if (!self->initialized) {
        ensure_egl_procs();

        if (!s_eglCreateImageKHR || !s_eglDestroyImageKHR || !s_glEGLImageTargetTexture2DOES) {
            std::cerr << "[ThermionEGL] Failed to resolve EGL extension functions" << std::endl;
            g_set_error(error, g_quark_from_string("thermion"), 1,
                        "Failed to resolve EGL extension functions");
            return FALSE;
        }

        EGLDisplay display = eglGetCurrentDisplay();
        if (display == EGL_NO_DISPLAY) {
            g_set_error(error, g_quark_from_string("thermion"), 2,
                        "No EGL display available");
            return FALSE;
        }

        // Split the 64-bit DRM modifier into lo/hi 32-bit parts for EGL
        EGLint modLo = (EGLint)(self->drm_modifier & 0xFFFFFFFF);
        EGLint modHi = (EGLint)(self->drm_modifier >> 32);

        // Create EGLImage from dmabuf fd with the actual DRM modifier
        EGLint attribs[] = {
            EGL_WIDTH, (EGLint)self->width,
            EGL_HEIGHT, (EGLint)self->height,
            EGL_LINUX_DRM_FOURCC_EXT, (EGLint)self->drm_format,
            EGL_DMA_BUF_PLANE0_FD_EXT, self->dmabuf_fd,
            EGL_DMA_BUF_PLANE0_OFFSET_EXT, (EGLint)self->offset,
            EGL_DMA_BUF_PLANE0_PITCH_EXT, (EGLint)self->stride,
            EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT, modLo,
            EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT, modHi,
            EGL_NONE
        };

        self->egl_image = s_eglCreateImageKHR(display, EGL_NO_CONTEXT,
                                               EGL_LINUX_DMA_BUF_EXT,
                                               nullptr, attribs);
        if (self->egl_image == EGL_NO_IMAGE_KHR) {
            EGLint eglError = eglGetError();
            std::cerr << "[ThermionEGL] Failed to create EGLImage from dmabuf, EGL error: 0x"
                      << std::hex << eglError << std::dec
                      << " (modifier=0x" << std::hex << self->drm_modifier << std::dec << ")"
                      << std::endl;
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
    }

    *target = GL_TEXTURE_EXTERNAL_OES;
    *name = self->gl_texture_id;
    *width = self->width;
    *height = self->height;
    return TRUE;
}

static void thermion_texture_gl_dispose(GObject* object) {
    ThermionTextureGL *self = THERMION_TEXTURE_GL(object);

    // Clean up any pending deferred method call
    if (self->pending_ready_call) {
        fl_method_call_respond(self->pending_ready_call,
            FL_METHOD_RESPONSE(fl_method_error_response_new(
                "DESTROYED", "Texture destroyed before populate", nullptr)), nullptr);
        g_object_unref(self->pending_ready_call);
        self->pending_ready_call = nullptr;
    }

    if (self->use_direct_sharing) {
        // Direct sharing: texture is owned by the plugin (deleted on utility context).
        // Nothing to clean up here — just zero out.
        self->gl_texture_id = 0;
        G_OBJECT_CLASS(thermion_texture_gl_parent_class)->dispose(object);
        return;
    }

    if (self->use_egl_image) {
        // EGLImage path: clean up the Flutter-side texture (created on Flutter's context)
        if (self->flutter_gl_texture_id != 0) {
            glDeleteTextures(1, &self->flutter_gl_texture_id);
            self->flutter_gl_texture_id = 0;
        }
        // The source texture (gl_texture_id) is cleaned up by the plugin.
        self->gl_texture_id = 0;
    } else {
        if (self->gl_texture_id != 0) {
            glDeleteTextures(1, &self->gl_texture_id);
            self->gl_texture_id = 0;
        }
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
    self->flutter_gl_texture_id = 0;
    self->width = 0;
    self->height = 0;
    self->registrar = nullptr;
    self->dmabuf_fd = -1;
    self->stride = 0;
    self->offset = 0;
    self->drm_format = 0;
    self->drm_modifier = 0;
    self->egl_image = EGL_NO_IMAGE_KHR;
    self->initialized = FALSE;
    self->surface_id = -1;
    self->use_egl_image = FALSE;
    self->use_direct_sharing = FALSE;
    self->is_context_bootstrap = FALSE;
    self->pending_ready_call = nullptr;
}

ThermionTextureGL* thermion_texture_gl_create(
    const SurfaceExportInfo& info,
    int64_t surface_id,
    FlTextureRegistrar* registrar)
{
    auto textureGL = THERMION_TEXTURE_GL(g_object_new(thermion_texture_gl_get_type(), nullptr));
    textureGL->width = info.width;
    textureGL->height = info.height;
    textureGL->registrar = registrar;
    textureGL->dmabuf_fd = info.dmabuf_fd;
    textureGL->stride = info.stride;
    textureGL->offset = info.offset;
    textureGL->drm_format = info.drm_format;
    textureGL->drm_modifier = info.drm_modifier;
    textureGL->surface_id = surface_id;

    return textureGL;
}

ThermionTextureGL* thermion_texture_gl_create_shared(
    uint32_t width, uint32_t height,
    GLuint gl_texture_id,
    EGLImage egl_image,
    int64_t surface_id,
    FlTextureRegistrar* registrar)
{
    auto textureGL = THERMION_TEXTURE_GL(g_object_new(thermion_texture_gl_get_type(), nullptr));
    textureGL->width = width;
    textureGL->height = height;
    textureGL->gl_texture_id = gl_texture_id;
    textureGL->egl_image = egl_image;
    textureGL->surface_id = surface_id;
    textureGL->registrar = registrar;
    textureGL->use_egl_image = TRUE;
    // initialized = FALSE so populate() will import the EGLImage on first call

    return textureGL;
}

ThermionTextureGL* thermion_texture_gl_create_context_bootstrap(
    uint32_t width, uint32_t height,
    FlTextureRegistrar* registrar)
{
    auto textureGL = THERMION_TEXTURE_GL(
        g_object_new(thermion_texture_gl_get_type(), nullptr));
    textureGL->width = width;
    textureGL->height = height;
    textureGL->registrar = registrar;
    textureGL->use_direct_sharing = TRUE;
    textureGL->is_context_bootstrap = TRUE;
    // populate() creates gl_texture_id while Flutter's raster context is
    // current and resolves the pending awaitTextureReady call.
    textureGL->gl_texture_id = 0;

    return textureGL;
}

void thermion_texture_gl_destroy(ThermionTextureGL* texture) {
    if (texture && texture->registrar) {
        fl_texture_registrar_unregister_texture(texture->registrar, FL_TEXTURE(texture));
    }
}
